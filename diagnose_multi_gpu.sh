#!/bin/bash

# Multi-GPU Diagnostic Script
# Diagnose why multi-GPU performance improvement is minimal

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}🔍 Multi-GPU Performance Diagnostic${NC}"
echo -e "${BLUE}===================================${NC}"

BINARY="./target/release/spn-node"

# Function to run calibration with detailed output
run_detailed_calibration() {
    local gpu_config=$1
    local description=$2
    
    echo -e "\n${YELLOW}🔬 Testing: $description${NC}"
    echo -e "${CYAN}GPU Config: $gpu_config${NC}"
    
    echo -e "${BLUE}Running calibration with verbose output...${NC}"
    
    CUDA_VISIBLE_DEVICES=$gpu_config RUST_LOG=info $BINARY calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 2>&1 | tee "diagnostic_${description// /_}.log"
}

# Function to analyze calibration type
analyze_calibration_type() {
    local log_file=$1
    local description=$2
    
    echo -e "\n${PURPLE}📊 Analyzing $description${NC}"
    
    if grep -q "Using single-GPU calibration" "$log_file"; then
        echo -e "${YELLOW}⚠️  Using single-GPU calibration${NC}"
    elif grep -q "Using multi-GPU calibration" "$log_file"; then
        echo -e "${GREEN}✅ Using multi-GPU calibration${NC}"
        gpu_count=$(grep "multi-GPU calibration with" "$log_file" | awk '{print $5}')
        echo -e "${CYAN}   GPU count: $gpu_count${NC}"
    else
        echo -e "${RED}❌ Calibration type not detected${NC}"
    fi
    
    # Check for ShardedCalibrator usage
    if grep -q "ShardedCalibrator" "$log_file"; then
        echo -e "${GREEN}✅ ShardedCalibrator being used${NC}"
    elif grep -q "SinglePassCalibrator" "$log_file"; then
        echo -e "${YELLOW}⚠️  SinglePassCalibrator being used${NC}"
    fi
    
    # Extract performance metrics
    if grep -q "Estimated Throughput" "$log_file"; then
        throughput=$(grep "Estimated Throughput" "$log_file" | awk '{print $4}')
        echo -e "${CYAN}   Throughput: $throughput PGUs/second${NC}"
    fi
}

# Function to check GPU utilization during calibration
monitor_gpu_utilization() {
    echo -e "\n${PURPLE}📈 Monitoring GPU Utilization${NC}"
    
    echo -e "${CYAN}Starting GPU monitoring...${NC}"
    
    # Start monitoring in background
    (
        for i in {1..30}; do
            echo "Sample $i:" >> gpu_utilization.log
            nvidia-smi --query-gpu=index,utilization.gpu,memory.used --format=csv,noheader,nounits >> gpu_utilization.log 2>/dev/null || true
            sleep 2
        done
    ) &
    local monitor_pid=$!
    
    # Run a quick calibration
    echo -e "${CYAN}Running calibration while monitoring...${NC}"
    CUDA_VISIBLE_DEVICES=0,1 $BINARY calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 > /dev/null 2>&1 || true
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    # Analyze utilization
    if [ -f gpu_utilization.log ]; then
        echo -e "${CYAN}GPU utilization analysis:${NC}"
        
        # Get max utilization for each GPU
        gpu0_max=$(grep -A1 "Sample" gpu_utilization.log | grep "^0," | awk -F, '{print $2}' | sort -n | tail -1)
        gpu1_max=$(grep -A1 "Sample" gpu_utilization.log | grep "^1," | awk -F, '{print $2}' | sort -n | tail -1)
        
        echo -e "${CYAN}   GPU 0 max utilization: ${gpu0_max}%${NC}"
        echo -e "${CYAN}   GPU 1 max utilization: ${gpu1_max}%${NC}"
        
        if [ "$gpu0_max" -gt 50 ] && [ "$gpu1_max" -gt 50 ]; then
            echo -e "${GREEN}✅ Both GPUs showing significant utilization${NC}"
        elif [ "$gpu0_max" -gt 50 ] || [ "$gpu1_max" -gt 50 ]; then
            echo -e "${YELLOW}⚠️  Only one GPU showing significant utilization${NC}"
        else
            echo -e "${RED}❌ Low GPU utilization detected${NC}"
        fi
    fi
}

# Function to check implementation details
check_implementation() {
    echo -e "\n${PURPLE}🔧 Checking Implementation Details${NC}"
    
    # Check if ShardedProver is being used
    echo -e "${CYAN}Checking prover type in logs...${NC}"
    
    if [ -f "diagnostic_Multi_GPU.log" ]; then
        if grep -q "ShardedProver" "diagnostic_Multi_GPU.log"; then
            echo -e "${GREEN}✅ ShardedProver detected in logs${NC}"
        else
            echo -e "${YELLOW}⚠️  ShardedProver not detected in logs${NC}"
        fi
        
        if grep -q "Detected.*GPU" "diagnostic_Multi_GPU.log"; then
            detected_gpus=$(grep "Detected.*GPU" "diagnostic_Multi_GPU.log" | head -1)
            echo -e "${CYAN}   $detected_gpus${NC}"
        fi
    fi
}

# Function to provide recommendations
provide_recommendations() {
    echo -e "\n${PURPLE}💡 Recommendations${NC}"
    echo -e "${BLUE}=================${NC}"
    
    echo -e "${CYAN}Based on the diagnostic results:${NC}"
    
    # Check if both calibrations used same method
    if [ -f "diagnostic_Single_GPU.log" ] && [ -f "diagnostic_Multi_GPU.log" ]; then
        single_type=$(grep -o "Using.*calibration" "diagnostic_Single_GPU.log" || echo "unknown")
        multi_type=$(grep -o "Using.*calibration" "diagnostic_Multi_GPU.log" || echo "unknown")
        
        if [ "$single_type" = "$multi_type" ]; then
            echo -e "${RED}❌ Issue: Both tests using same calibration method${NC}"
            echo -e "${YELLOW}   Recommendation: Ensure ShardedCalibrator is used for multi-GPU${NC}"
        fi
    fi
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "${CYAN}1. Check if ShardedCalibrator is properly implemented${NC}"
    echo -e "${CYAN}2. Verify GPU detection logic in main.rs${NC}"
    echo -e "${CYAN}3. Ensure CUDA_VISIBLE_DEVICES is properly handled${NC}"
    echo -e "${CYAN}4. Test with actual proof generation (not just calibration)${NC}"
}

# Main diagnostic execution
main() {
    echo -e "${BLUE}Starting diagnostic at $(date)${NC}"
    
    # Check if binary exists
    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}❌ Binary not found: $BINARY${NC}"
        exit 1
    fi
    
    # Run detailed calibrations
    run_detailed_calibration "0" "Single GPU"
    run_detailed_calibration "0,1" "Multi GPU"
    
    # Analyze results
    analyze_calibration_type "diagnostic_Single_GPU.log" "Single GPU"
    analyze_calibration_type "diagnostic_Multi_GPU.log" "Multi GPU"
    
    # Monitor GPU utilization
    monitor_gpu_utilization
    
    # Check implementation
    check_implementation
    
    # Provide recommendations
    provide_recommendations
    
    echo -e "\n${GREEN}🎉 Diagnostic completed!${NC}"
    echo -e "${CYAN}📁 Log files: diagnostic_*.log, gpu_utilization.log${NC}"
}

# Run main function
main "$@"
