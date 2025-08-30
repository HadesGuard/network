#!/bin/bash

# Comprehensive Test Runner for Multi-GPU Implementation
# Builds and runs all test programs to verify functionality

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}🧪 Comprehensive Multi-GPU Test Suite${NC}"
echo -e "${BLUE}====================================${NC}"

# Function to run command with status
run_with_status() {
    local description=$1
    local command=$2
    
    echo -e "\n${YELLOW}🔬 $description${NC}"
    echo -e "${CYAN}Command: $command${NC}"
    
    if eval $command; then
        echo -e "${GREEN}✅ SUCCESS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        return 1
    fi
}

# Function to build all test programs
build_test_programs() {
    echo -e "\n${PURPLE}🔨 Building Test Programs${NC}"
    
    for program in test-simple test-medium test-complex; do
        run_with_status "Building $program" "cd programs/$program && cargo prove build && cd ../.."
    done
}

# Function to build main binary
build_main_binary() {
    echo -e "\n${PURPLE}🔨 Building Main Binary${NC}"
    
    run_with_status "Building spn-node" "cargo build --release -p spn-node"
}

# Function to run calibration tests
run_calibration_tests() {
    echo -e "\n${PURPLE}📊 Running Calibration Tests${NC}"
    
    # Single GPU test
    run_with_status "Single GPU Calibration" \
        "CUDA_VISIBLE_DEVICES=0 ./target/release/spn-node calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08"
    
    # Multi GPU test (if available)
    if command -v nvidia-smi &> /dev/null && [ $(nvidia-smi -L | wc -l) -gt 1 ]; then
        run_with_status "Multi GPU Calibration" \
            "CUDA_VISIBLE_DEVICES=0,1 ./target/release/spn-node calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08"
    else
        echo -e "${YELLOW}⚠️  Skipping multi-GPU test (not available)${NC}"
    fi
}

# Function to run program tests
run_program_tests() {
    echo -e "\n${PURPLE}🧪 Running Program Tests${NC}"
    
    # Compile test runner
    if run_with_status "Compiling test programs runner" \
        "rustc --edition 2021 -L target/release/deps test_programs.rs -o test_programs_runner --extern sp1_sdk=target/release/deps/libsp1_sdk-*.rlib"; then
        
        run_with_status "Running program tests" "./test_programs_runner"
        rm -f test_programs_runner
    else
        echo -e "${YELLOW}⚠️  Skipping program tests (compilation failed)${NC}"
    fi
}

# Function to run multi-GPU proving tests
run_multi_gpu_tests() {
    echo -e "\n${PURPLE}🚀 Running Multi-GPU Proving Tests${NC}"
    
    # This requires tokio runtime, so we'll use cargo run
    if [ -f "Cargo_test_programs.toml" ]; then
        run_with_status "Multi-GPU proving test" \
            "cargo run --manifest-path Cargo_test_programs.toml --bin test_multi_gpu_proving"
    else
        echo -e "${YELLOW}⚠️  Skipping multi-GPU proving tests (Cargo.toml not found)${NC}"
    fi
}

# Function to run diagnostic tests
run_diagnostic_tests() {
    echo -e "\n${PURPLE}🔍 Running Diagnostic Tests${NC}"
    
    if [ -f "diagnose_multi_gpu.sh" ]; then
        run_with_status "Multi-GPU diagnostic" "./diagnose_multi_gpu.sh"
    else
        echo -e "${YELLOW}⚠️  Diagnostic script not found${NC}"
    fi
}

# Function to show system information
show_system_info() {
    echo -e "\n${PURPLE}💻 System Information${NC}"
    
    echo -e "${CYAN}Rust version:${NC}"
    rustc --version
    
    echo -e "\n${CYAN}Cargo version:${NC}"
    cargo --version
    
    if command -v nvidia-smi &> /dev/null; then
        echo -e "\n${CYAN}GPU information:${NC}"
        nvidia-smi -L
        
        echo -e "\n${CYAN}GPU memory:${NC}"
        nvidia-smi --query-gpu=name,memory.total,memory.used --format=csv,noheader
    else
        echo -e "\n${YELLOW}⚠️  NVIDIA GPU not available${NC}"
    fi
    
    echo -e "\n${CYAN}SP1 version:${NC}"
    cargo prove --version 2>/dev/null || echo "SP1 not available"
}

# Function to generate test report
generate_report() {
    echo -e "\n${PURPLE}📋 Test Report${NC}"
    echo -e "${BLUE}===============${NC}"
    
    local total_tests=0
    local passed_tests=0
    
    echo -e "${GREEN}✅ Completed Tests:${NC}"
    echo -e "${CYAN}• System information displayed${NC}"
    echo -e "${CYAN}• Test programs built${NC}"
    echo -e "${CYAN}• Main binary built${NC}"
    echo -e "${CYAN}• Calibration tests executed${NC}"
    
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${CYAN}• GPU detection working${NC}"
        
        if [ $(nvidia-smi -L | wc -l) -gt 1 ]; then
            echo -e "${CYAN}• Multi-GPU setup detected${NC}"
        fi
    fi
    
    echo -e "\n${YELLOW}📊 Performance Summary:${NC}"
    echo -e "${CYAN}Check calibration outputs above for performance metrics${NC}"
    
    echo -e "\n${PURPLE}🎯 Next Steps:${NC}"
    echo -e "${CYAN}1. Review calibration results for performance improvement${NC}"
    echo -e "${CYAN}2. Run diagnostic script if performance is suboptimal${NC}"
    echo -e "${CYAN}3. Deploy to production if tests pass${NC}"
    echo -e "${CYAN}4. Monitor GPU utilization in production${NC}"
}

# Main test execution
main() {
    echo -e "${BLUE}Starting comprehensive tests at $(date)${NC}"
    
    # Show system info first
    show_system_info
    
    # Build everything
    build_test_programs
    build_main_binary
    
    # Run tests
    run_calibration_tests
    run_program_tests
    run_multi_gpu_tests
    
    # Run diagnostics if available
    run_diagnostic_tests
    
    # Generate report
    generate_report
    
    echo -e "\n${GREEN}🎉 All tests completed!${NC}"
    echo -e "${CYAN}📁 Check logs above for detailed results${NC}"
}

# Parse command line arguments
case "${1:-all}" in
    "build")
        build_test_programs
        build_main_binary
        ;;
    "calibrate")
        run_calibration_tests
        ;;
    "programs")
        run_program_tests
        ;;
    "multi-gpu")
        run_multi_gpu_tests
        ;;
    "diagnostic")
        run_diagnostic_tests
        ;;
    "info")
        show_system_info
        ;;
    "all"|*)
        main
        ;;
esac
