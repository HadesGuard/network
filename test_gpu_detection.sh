#!/bin/bash

# Simple GPU Detection and Multi-GPU Test
# Tests if the ShardedProver correctly detects and uses multiple GPUs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}🔍 GPU Detection and Multi-GPU Test${NC}"
echo -e "${BLUE}===================================${NC}"

# Function to test GPU detection
test_gpu_detection() {
    echo -e "\n${YELLOW}1. Testing GPU Detection${NC}"
    
    # Check nvidia-smi
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✅ nvidia-smi available${NC}"
        echo -e "${CYAN}Available GPUs:${NC}"
        nvidia-smi -L
        
        local gpu_count=$(nvidia-smi -L | wc -l)
        echo -e "${CYAN}Total GPUs detected: $gpu_count${NC}"
        
        if [ $gpu_count -gt 1 ]; then
            echo -e "${GREEN}✅ Multiple GPUs available for testing${NC}"
        else
            echo -e "${YELLOW}⚠️  Only 1 GPU available${NC}"
        fi
    else
        echo -e "${RED}❌ nvidia-smi not available${NC}"
        return 1
    fi
}

# Function to test CUDA environment
test_cuda_environment() {
    echo -e "\n${YELLOW}2. Testing CUDA Environment${NC}"
    
    # Check CUDA installation
    if [ -d "/usr/local/cuda" ]; then
        echo -e "${GREEN}✅ CUDA installation found at /usr/local/cuda${NC}"
    else
        echo -e "${YELLOW}⚠️  CUDA not found at /usr/local/cuda${NC}"
    fi
    
    # Check CUDA_VISIBLE_DEVICES
    if [ -n "$CUDA_VISIBLE_DEVICES" ]; then
        echo -e "${GREEN}✅ CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES${NC}"
    else
        echo -e "${CYAN}ℹ️  CUDA_VISIBLE_DEVICES not set (will use all GPUs)${NC}"
    fi
    
    # Test different CUDA_VISIBLE_DEVICES settings
    echo -e "\n${CYAN}Testing different GPU configurations:${NC}"
    
    # Single GPU test
    echo -e "${YELLOW}Single GPU (GPU 0):${NC}"
    CUDA_VISIBLE_DEVICES=0 nvidia-smi -L 2>/dev/null || echo "Failed to query GPU 0"
    
    # Multi GPU test (if available)
    local gpu_count=$(nvidia-smi -L | wc -l)
    if [ $gpu_count -gt 1 ]; then
        echo -e "${YELLOW}Multi GPU (GPU 0,1):${NC}"
        CUDA_VISIBLE_DEVICES=0,1 nvidia-smi -L 2>/dev/null || echo "Failed to query GPUs 0,1"
    fi
}

# Function to test calibration with different GPU configurations
test_calibration_configs() {
    echo -e "\n${YELLOW}3. Testing Calibration with Different GPU Configs${NC}"
    
    local binary="./target/release/spn-node"
    
    if [ ! -f "$binary" ]; then
        echo -e "${YELLOW}Binary not found, building...${NC}"
        cargo build --release -p spn-node
    fi
    
    # Test single GPU calibration
    echo -e "\n${CYAN}Testing single GPU calibration...${NC}"
    CUDA_VISIBLE_DEVICES=0 timeout 30s $binary calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 > single_gpu_test.log 2>&1 || true
    
    if grep -q "Detected.*GPU" single_gpu_test.log; then
        local detected=$(grep "Detected.*GPU" single_gpu_test.log | head -1)
        echo -e "${GREEN}✅ $detected${NC}"
    fi
    
    if grep -q "Estimated Throughput" single_gpu_test.log; then
        local throughput=$(grep "Estimated Throughput" single_gpu_test.log | awk '{print $4" "$5}')
        echo -e "${GREEN}✅ Single GPU Throughput: $throughput${NC}"
    fi
    
    # Test multi GPU calibration (if available)
    local gpu_count=$(nvidia-smi -L | wc -l)
    if [ $gpu_count -gt 1 ]; then
        echo -e "\n${CYAN}Testing multi GPU calibration...${NC}"
        CUDA_VISIBLE_DEVICES=0,1 timeout 30s $binary calibrate \
            --usd-cost-per-hour 0.40 \
            --utilization-rate 0.75 \
            --profit-margin 0.15 \
            --prove-price 0.08 > multi_gpu_test.log 2>&1 || true
        
        if grep -q "Detected.*GPU" multi_gpu_test.log; then
            local detected=$(grep "Detected.*GPU" multi_gpu_test.log | head -1)
            echo -e "${GREEN}✅ $detected${NC}"
        fi
        
        if grep -q "Estimated Throughput" multi_gpu_test.log; then
            local throughput=$(grep "Estimated Throughput" multi_gpu_test.log | awk '{print $4" "$5}')
            echo -e "${GREEN}✅ Multi GPU Throughput: $throughput${NC}"
        fi
        
        # Compare results
        if [ -f single_gpu_test.log ] && [ -f multi_gpu_test.log ]; then
            echo -e "\n${PURPLE}📊 Performance Comparison:${NC}"
            
            local single_val=$(grep "Estimated Throughput" single_gpu_test.log | awk '{print $4}' | head -1)
            local multi_val=$(grep "Estimated Throughput" multi_gpu_test.log | awk '{print $4}' | head -1)
            
            if [ -n "$single_val" ] && [ -n "$multi_val" ]; then
                echo -e "${CYAN}Single GPU: $single_val PGUs/second${NC}"
                echo -e "${CYAN}Multi GPU:  $multi_val PGUs/second${NC}"
                
                # Calculate improvement
                local improvement=$(echo "scale=2; $multi_val / $single_val" | bc -l 2>/dev/null || echo "N/A")
                echo -e "${GREEN}Improvement: ${improvement}x${NC}"
                
                # Check if improvement is significant
                if [ "$improvement" != "N/A" ]; then
                    local is_better=$(echo "$improvement > 1.2" | bc -l 2>/dev/null || echo "0")
                    if [ "$is_better" = "1" ]; then
                        echo -e "${GREEN}✅ Multi-GPU shows significant improvement!${NC}"
                    else
                        echo -e "${YELLOW}⚠️  Multi-GPU improvement is minimal${NC}"
                    fi
                fi
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Only 1 GPU available, skipping multi-GPU test${NC}"
    fi
}

# Function to test GPU memory usage
test_gpu_memory() {
    echo -e "\n${YELLOW}4. Testing GPU Memory Usage${NC}"
    
    echo -e "${CYAN}Current GPU memory usage:${NC}"
    nvidia-smi --query-gpu=index,name,memory.used,memory.total --format=csv,noheader,nounits | \
    while IFS=, read -r index name used total; do
        local usage_percent=$(echo "scale=1; $used * 100 / $total" | bc -l 2>/dev/null || echo "N/A")
        echo -e "${CYAN}GPU $index ($name): ${used}MB / ${total}MB (${usage_percent}%)${NC}"
    done
}

# Function to show system information
show_system_info() {
    echo -e "\n${YELLOW}5. System Information${NC}"
    
    echo -e "${CYAN}NVIDIA Driver Version:${NC}"
    nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1
    
    echo -e "\n${CYAN}GPU Details:${NC}"
    nvidia-smi --query-gpu=index,name,compute_cap,memory.total --format=csv,noheader | \
    while IFS=, read -r index name compute_cap memory; do
        echo -e "${CYAN}GPU $index: $name (Compute $compute_cap, ${memory})${NC}"
    done
    
    echo -e "\n${CYAN}CUDA Version (if available):${NC}"
    if command -v nvcc &> /dev/null; then
        nvcc --version | grep "release" || echo "nvcc not available"
    else
        echo "nvcc not available"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting GPU detection and multi-GPU tests...${NC}"
    
    test_gpu_detection
    test_cuda_environment  
    test_calibration_configs
    test_gpu_memory
    show_system_info
    
    echo -e "\n${PURPLE}📋 Test Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    
    # Show key results
    if [ -f single_gpu_test.log ]; then
        echo -e "${GREEN}✅ Single GPU test completed${NC}"
    fi
    
    if [ -f multi_gpu_test.log ]; then
        echo -e "${GREEN}✅ Multi GPU test completed${NC}"
    fi
    
    # Cleanup
    rm -f single_gpu_test.log multi_gpu_test.log 2>/dev/null || true
    
    echo -e "\n${GREEN}🎉 All tests completed!${NC}"
}

# Run main function
main "$@"