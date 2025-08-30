#!/bin/bash

# Multi-GPU Performance Benchmark Script
# Compares single GPU vs multi GPU performance

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}⚡ Multi-GPU Performance Benchmark${NC}"
echo -e "${BLUE}=================================${NC}"

# Configuration
BINARY="./target/release/spn-node"
RESULTS_DIR="./benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create results directory
mkdir -p $RESULTS_DIR

# Function to extract throughput from calibration output
extract_throughput() {
    local log_file=$1
    grep "Estimated Throughput" "$log_file" | awk '{print $4}' | head -1
}

# Function to extract bid price from calibration output
extract_bid_price() {
    local log_file=$1
    grep "Estimated Bid Price" "$log_file" | awk '{print $5}' | head -1
}

# Function to run calibration benchmark
run_calibration_benchmark() {
    local gpu_config=$1
    local description=$2
    local log_file=$3
    
    echo -e "${CYAN}🔬 Testing: $description${NC}"
    echo -e "${YELLOW}GPU Config: $gpu_config${NC}"
    
    local start_time=$(date +%s)
    
    # Run calibration with timeout
    CUDA_VISIBLE_DEVICES=$gpu_config timeout 120s $BINARY calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 > "$log_file" 2>&1 || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ -f "$log_file" ] && grep -q "Estimated Throughput" "$log_file"; then
        local throughput=$(extract_throughput "$log_file")
        local bid_price=$(extract_bid_price "$log_file")
        echo -e "${GREEN}✅ Completed in ${duration}s${NC}"
        echo -e "${GREEN}   Throughput: ${throughput} PGUs/second${NC}"
        echo -e "${GREEN}   Bid Price: ${bid_price} \$PROVE per 1B PGUs${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed or incomplete in ${duration}s${NC}"
        return 1
    fi
}

# Function to detect available GPUs
detect_gpus() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi -L | wc -l
    else
        echo 0
    fi
}

# Main benchmark function
run_benchmark() {
    local gpu_count=$(detect_gpus)
    
    echo -e "${BLUE}🔍 Detected $gpu_count GPU(s)${NC}"
    
    if [ $gpu_count -eq 0 ]; then
        echo -e "${RED}❌ No GPUs detected! Make sure NVIDIA drivers are installed.${NC}"
        exit 1
    fi
    
    # Show GPU information
    echo -e "\n${PURPLE}📊 GPU Information:${NC}"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | nl -v0 -s": "
    
    echo -e "\n${PURPLE}🚀 Starting Benchmark Tests${NC}"
    
    # Test 1: Single GPU (GPU 0)
    echo -e "\n${YELLOW}═══ Test 1: Single GPU Performance ═══${NC}"
    run_calibration_benchmark "0" "Single GPU (GPU 0)" "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log"
    
    # Test 2: Multi GPU (if available)
    if [ $gpu_count -gt 1 ]; then
        echo -e "\n${YELLOW}═══ Test 2: Multi GPU Performance ═══${NC}"
        
        # Test with 2 GPUs
        run_calibration_benchmark "0,1" "Dual GPU (GPU 0,1)" "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log"
        
        # Test with all GPUs if more than 2
        if [ $gpu_count -gt 2 ]; then
            local all_gpus=$(seq -s, 0 $((gpu_count-1)))
            run_calibration_benchmark "$all_gpus" "All GPUs ($all_gpus)" "$RESULTS_DIR/all_gpu_${TIMESTAMP}.log"
        fi
    else
        echo -e "\n${YELLOW}⚠️  Only 1 GPU available, skipping multi-GPU tests${NC}"
    fi
    
    # Generate comparison report
    generate_report
}

# Function to generate performance report
generate_report() {
    echo -e "\n${PURPLE}📊 Performance Report${NC}"
    echo -e "${BLUE}===================${NC}"
    
    local report_file="$RESULTS_DIR/performance_report_${TIMESTAMP}.txt"
    
    {
        echo "Multi-GPU Performance Benchmark Report"
        echo "Generated: $(date)"
        echo "======================================"
        echo
        
        # Single GPU results
        if [ -f "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log" ]; then
            local single_throughput=$(extract_throughput "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log")
            local single_bid=$(extract_bid_price "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log")
            echo "Single GPU Performance:"
            echo "  Throughput: ${single_throughput} PGUs/second"
            echo "  Bid Price: ${single_bid} \$PROVE per 1B PGUs"
            echo
        fi
        
        # Dual GPU results
        if [ -f "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log" ]; then
            local dual_throughput=$(extract_throughput "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log")
            local dual_bid=$(extract_bid_price "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log")
            echo "Dual GPU Performance:"
            echo "  Throughput: ${dual_throughput} PGUs/second"
            echo "  Bid Price: ${dual_bid} \$PROVE per 1B PGUs"
            
            # Calculate improvement
            if [ -n "$single_throughput" ] && [ -n "$dual_throughput" ]; then
                local improvement=$(echo "scale=2; $dual_throughput / $single_throughput" | bc -l 2>/dev/null || echo "N/A")
                echo "  Improvement: ${improvement}x over single GPU"
            fi
            echo
        fi
        
        # All GPU results
        if [ -f "$RESULTS_DIR/all_gpu_${TIMESTAMP}.log" ]; then
            local all_throughput=$(extract_throughput "$RESULTS_DIR/all_gpu_${TIMESTAMP}.log")
            local all_bid=$(extract_bid_price "$RESULTS_DIR/all_gpu_${TIMESTAMP}.log")
            echo "All GPU Performance:"
            echo "  Throughput: ${all_throughput} PGUs/second"
            echo "  Bid Price: ${all_bid} \$PROVE per 1B PGUs"
            
            # Calculate improvement
            if [ -n "$single_throughput" ] && [ -n "$all_throughput" ]; then
                local improvement=$(echo "scale=2; $all_throughput / $single_throughput" | bc -l 2>/dev/null || echo "N/A")
                echo "  Improvement: ${improvement}x over single GPU"
            fi
            echo
        fi
        
    } > "$report_file"
    
    # Display report
    cat "$report_file"
    
    echo -e "${GREEN}📁 Full report saved to: $report_file${NC}"
    
    # Show summary
    echo -e "\n${PURPLE}🎯 Summary${NC}"
    if [ -f "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log" ] && [ -f "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log" ]; then
        local single=$(extract_throughput "$RESULTS_DIR/single_gpu_${TIMESTAMP}.log")
        local dual=$(extract_throughput "$RESULTS_DIR/dual_gpu_${TIMESTAMP}.log")
        
        if [ -n "$single" ] && [ -n "$dual" ]; then
            local improvement=$(echo "scale=2; $dual / $single" | bc -l 2>/dev/null || echo "N/A")
            echo -e "${CYAN}Single GPU: ${single} PGUs/second${NC}"
            echo -e "${CYAN}Dual GPU:   ${dual} PGUs/second${NC}"
            echo -e "${GREEN}Performance Gain: ${improvement}x${NC}"
            
            # Determine if multi-GPU is working effectively
            if [ "$improvement" != "N/A" ]; then
                local threshold=$(echo "$improvement > 1.5" | bc -l 2>/dev/null || echo "0")
                if [ "$threshold" = "1" ]; then
                    echo -e "${GREEN}✅ Multi-GPU sharding is working effectively!${NC}"
                else
                    echo -e "${YELLOW}⚠️  Multi-GPU improvement is less than expected. Check implementation.${NC}"
                fi
            fi
        fi
    fi
}

# Function to run stress test
run_stress_test() {
    echo -e "\n${PURPLE}🔥 Running Stress Test${NC}"
    
    local gpu_count=$(detect_gpus)
    if [ $gpu_count -gt 1 ]; then
        echo -e "${CYAN}Running continuous calibration for 5 minutes...${NC}"
        
        local stress_log="$RESULTS_DIR/stress_test_${TIMESTAMP}.log"
        local start_time=$(date +%s)
        local end_time=$((start_time + 300)) # 5 minutes
        local iteration=0
        
        while [ $(date +%s) -lt $end_time ]; do
            iteration=$((iteration + 1))
            echo -e "${YELLOW}Stress test iteration $iteration${NC}"
            
            CUDA_VISIBLE_DEVICES=0,1 timeout 60s $BINARY calibrate \
                --usd-cost-per-hour 0.40 \
                --utilization-rate 0.75 \
                --profit-margin 0.15 \
                --prove-price 0.08 >> "$stress_log" 2>&1 || true
            
            sleep 5
        done
        
        echo -e "${GREEN}✅ Stress test completed. Results in $stress_log${NC}"
    else
        echo -e "${YELLOW}⚠️  Stress test requires multiple GPUs${NC}"
    fi
}

# Main execution
main() {
    # Check if binary exists
    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}❌ Binary not found: $BINARY${NC}"
        echo -e "${YELLOW}Building binary...${NC}"
        cargo build --release -p spn-node
    fi
    
    # Run benchmark
    run_benchmark
    
    # Ask if user wants stress test
    echo -e "\n${YELLOW}Would you like to run a 5-minute stress test? (y/N)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        run_stress_test
    fi
    
    echo -e "\n${GREEN}🎉 Benchmark completed!${NC}"
    echo -e "${CYAN}📁 All results saved in: $RESULTS_DIR${NC}"
}

# Run main function
main "$@"
