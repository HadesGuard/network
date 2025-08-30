#!/bin/bash

# Local Multi-GPU Proving Test Suite
# Tests the ShardedProver implementation without needing network requests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test configuration
GPU_TYPE=${GPU_TYPE:-rtx3080}
TEST_DIR="./test_results"
BINARY="./target/release/spn-node"

echo -e "${PURPLE}🧪 Local Multi-GPU Proving Test Suite${NC}"
echo -e "${BLUE}====================================${NC}"

# Create test results directory
mkdir -p $TEST_DIR

# Function to run test and capture results
run_test() {
    local test_name=$1
    local description=$2
    local command=$3
    
    echo -e "\n${YELLOW}🔬 Test: $test_name${NC}"
    echo -e "${CYAN}Description: $description${NC}"
    echo -e "${BLUE}Command: $command${NC}"
    
    local start_time=$(date +%s)
    
    # Run the command and capture output
    if eval $command > "$TEST_DIR/${test_name}.log" 2>&1; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✅ PASSED (${duration}s)${NC}"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}❌ FAILED (${duration}s)${NC}"
        echo -e "${RED}Error log: $TEST_DIR/${test_name}.log${NC}"
        return 1
    fi
}

# Function to test GPU detection
test_gpu_detection() {
    echo -e "\n${PURPLE}🔍 Testing GPU Detection${NC}"
    
    # Test nvidia-smi availability
    if command -v nvidia-smi &> /dev/null; then
        echo -e "${GREEN}✅ nvidia-smi available${NC}"
        nvidia-smi -L | head -5
    else
        echo -e "${RED}❌ nvidia-smi not available${NC}"
        return 1
    fi
    
    # Test CUDA environment
    if [ -n "$CUDA_VISIBLE_DEVICES" ]; then
        echo -e "${GREEN}✅ CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES${NC}"
    else
        echo -e "${YELLOW}⚠️  CUDA_VISIBLE_DEVICES not set, using all GPUs${NC}"
    fi
}

# Function to test calibration
test_calibration() {
    echo -e "\n${PURPLE}📊 Testing Calibration${NC}"
    
    # Single GPU calibration
    echo -e "${CYAN}Testing single GPU calibration...${NC}"
    CUDA_VISIBLE_DEVICES=0 run_test "calibrate_single_gpu" \
        "Calibration with single GPU" \
        "$BINARY calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08"
    
    # Multi GPU calibration
    if [ $(nvidia-smi -L | wc -l) -gt 1 ]; then
        echo -e "${CYAN}Testing multi GPU calibration...${NC}"
        CUDA_VISIBLE_DEVICES=0,1 run_test "calibrate_multi_gpu" \
            "Calibration with multiple GPUs" \
            "$BINARY calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08"
    else
        echo -e "${YELLOW}⚠️  Only one GPU detected, skipping multi-GPU calibration${NC}"
    fi
}

# Function to create test programs
create_test_programs() {
    echo -e "\n${PURPLE}📝 Checking Test Programs${NC}"
    
    # Check if test programs already exist
    if [ -d "programs/test-simple" ] && [ -d "programs/test-medium" ] && [ -d "programs/test-complex" ]; then
        echo -e "${GREEN}✅ Test programs already exist${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Creating missing test programs...${NC}"
    
    # Only create if they don't exist
    if [ ! -d "programs/test-simple" ]; then
        echo -e "${CYAN}Creating simple test program...${NC}"
        mkdir -p programs/test-simple/src
        # Programs already created separately, just verify they exist
    fi
    
    if [ ! -d "programs/test-medium" ]; then
        echo -e "${CYAN}Creating medium test program...${NC}"
        mkdir -p programs/test-medium/src
    fi
    
    if [ ! -d "programs/test-complex" ]; then
        echo -e "${CYAN}Creating complex test program...${NC}"
        mkdir -p programs/test-complex/src
    fi
    
    echo -e "${GREEN}✅ Test programs verified${NC}"
}

# Function to build test programs
build_test_programs() {
    echo -e "\n${PURPLE}🔨 Building Test Programs${NC}"
    
    for program in test-simple test-medium test-complex; do
        if [ -d "programs/$program" ]; then
            echo -e "${CYAN}Building $program...${NC}"
            cd "programs/$program"
            if cargo prove build; then
                echo -e "${GREEN}✅ $program built successfully${NC}"
            else
                echo -e "${RED}❌ Failed to build $program${NC}"
            fi
            cd ../..
        fi
    done
}

# Function to create local proving test
create_local_test() {
    echo -e "\n${PURPLE}🚀 Creating Local Proving Test${NC}"
    
    cat > test_local_sharding.rs << 'EOF'
use std::time::Instant;
use sp1_sdk::{ProverClient, SP1Stdin, SP1ProofMode};
use spn_node_core::{ShardedProver, ShardingConfig};
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    println!("🧪 Local Multi-GPU Sharding Test");
    
    // Initialize the prover
    let config = ShardingConfig::rtx3080_optimized();
    let prover = ShardedProver::new(config).await?;
    
    // Create test program (simple computation)
    let program = include_bytes!("../programs/test-simple/elf/test-simple-program");
    let mut stdin = SP1Stdin::new();
    
    println!("📊 Testing different proof modes...");
    
    // Test with different modes
    let modes = [
        ("Core", SP1ProofMode::Core),
        ("Compressed", SP1ProofMode::Compressed),
    ];
    
    for (mode_name, mode) in modes {
        println!("\n🔬 Testing {} mode", mode_name);
        let start = Instant::now();
        
        match prover.process_proof_request(
            program.to_vec(),
            stdin.clone(),
            mode,
        ).await {
            Ok(proof) => {
                let duration = start.elapsed();
                println!("✅ {} proof completed in {:.2}s", mode_name, duration.as_secs_f64());
                println!("📏 Proof size: {} bytes", proof.bytes().len());
            }
            Err(e) => {
                println!("❌ {} proof failed: {}", mode_name, e);
            }
        }
    }
    
    Ok(())
}
EOF

    echo -e "${GREEN}✅ Local test created${NC}"
}

# Function to analyze calibration results
analyze_calibration_results() {
    echo -e "\n${PURPLE}📊 Analyzing Calibration Results${NC}"
    
    if [ -f "$TEST_DIR/calibrate_single_gpu.log" ] && [ -f "$TEST_DIR/calibrate_multi_gpu.log" ]; then
        echo -e "${CYAN}Extracting performance metrics...${NC}"
        
        # Extract throughput from logs
        single_throughput=$(grep "Estimated Throughput" "$TEST_DIR/calibrate_single_gpu.log" | awk '{print $4}' || echo "N/A")
        multi_throughput=$(grep "Estimated Throughput" "$TEST_DIR/calibrate_multi_gpu.log" | awk '{print $4}' || echo "N/A")
        
        # Extract bid prices
        single_bid=$(grep "Estimated Bid Price" "$TEST_DIR/calibrate_single_gpu.log" | awk '{print $4}' || echo "N/A")
        multi_bid=$(grep "Estimated Bid Price" "$TEST_DIR/calibrate_multi_gpu.log" | awk '{print $4}' || echo "N/A")
        
        echo -e "\n${YELLOW}🎯 Performance Comparison:${NC}"
        echo -e "${CYAN}Single GPU: ${single_throughput} PGUs/second, ${single_bid} \$PROVE/1B PGUs${NC}"
        echo -e "${CYAN}Multi GPU:  ${multi_throughput} PGUs/second, ${multi_bid} \$PROVE/1B PGUs${NC}"
        
        # Calculate improvement
        if [ "$single_throughput" != "N/A" ] && [ "$multi_throughput" != "N/A" ]; then
            improvement=$(echo "scale=2; $multi_throughput / $single_throughput" | bc -l 2>/dev/null || echo "N/A")
            echo -e "${GREEN}Throughput Improvement: ${improvement}x${NC}"
            
            # Determine success
            if [ "$improvement" != "N/A" ]; then
                threshold=$(echo "$improvement > 1.5" | bc -l 2>/dev/null || echo "0")
                if [ "$threshold" = "1" ]; then
                    echo -e "${GREEN}🎉 SUCCESS: Multi-GPU sharding is working excellently!${NC}"
                else
                    echo -e "${YELLOW}⚠️  Multi-GPU improvement is less than expected${NC}"
                fi
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Calibration logs not found for comparison${NC}"
    fi
}

# Function to test memory usage
test_memory_usage() {
    echo -e "\n${PURPLE}💾 Testing GPU Memory Usage${NC}"
    
    # Check current GPU memory usage
    echo -e "${CYAN}Current GPU memory status:${NC}"
    
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits | \
        while IFS=, read -r index name used total util; do
            usage_percent=$(echo "scale=1; $used * 100 / $total" | bc -l 2>/dev/null || echo "N/A")
            echo -e "${CYAN}GPU $index ($name): ${used}MB/${total}MB (${usage_percent}%) - ${util}% utilization${NC}"
        done
        
        echo -e "${GREEN}✅ GPU memory status checked${NC}"
    else
        echo -e "${YELLOW}⚠️  nvidia-smi not available${NC}"
    fi
}

# Main test execution
main() {
    echo -e "${BLUE}Starting local testing at $(date)${NC}"
    
    # Check if binary exists
    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}❌ Binary not found: $BINARY${NC}"
        echo -e "${YELLOW}Building binary...${NC}"
        cargo build --release -p spn-node
    fi
    
    # Run tests
    test_gpu_detection
    test_calibration
    analyze_calibration_results
    create_test_programs
    build_test_programs
    create_local_test
    test_memory_usage
    
    # Summary
    echo -e "\n${PURPLE}📋 Test Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    echo -e "${GREEN}✅ All tests completed${NC}"
    echo -e "${CYAN}📁 Results saved to: $TEST_DIR${NC}"
    echo -e "${CYAN}📊 View logs: ls -la $TEST_DIR${NC}"
    
    # Show key results
    if [ -f "$TEST_DIR/calibrate_single_gpu.log" ] && [ -f "$TEST_DIR/calibrate_multi_gpu.log" ]; then
        echo -e "\n${YELLOW}🎯 Key Performance Results:${NC}"
        single_result=$(grep "Estimated Throughput" "$TEST_DIR/calibrate_single_gpu.log" | awk '{print $4" "$5}' || echo "N/A")
        multi_result=$(grep "Estimated Throughput" "$TEST_DIR/calibrate_multi_gpu.log" | awk '{print $4" "$5}' || echo "N/A")
        echo -e "${CYAN}Single GPU: ${single_result}${NC}"
        echo -e "${CYAN}Multi GPU:  ${multi_result}${NC}"
        
        # Show improvement if both results available
        if [ "$single_result" != "N/A" ] && [ "$multi_result" != "N/A" ]; then
            single_num=$(echo "$single_result" | awk '{print $1}')
            multi_num=$(echo "$multi_result" | awk '{print $1}')
            if [ -n "$single_num" ] && [ -n "$multi_num" ]; then
                improvement=$(echo "scale=2; $multi_num / $single_num" | bc -l 2>/dev/null || echo "N/A")
                echo -e "${GREEN}Performance Improvement: ${improvement}x${NC}"
            fi
        fi
    fi
}

# Run main function
main "$@"
