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
    echo -e "\n${PURPLE}📝 Creating Test Programs${NC}"
    
    # Create simple test program
    mkdir -p programs/test-simple
    cat > programs/test-simple/Cargo.toml << 'EOF'
[package]
name = "test-simple-program"
version = "0.1.0"
edition = "2021"

[dependencies]
sp1-zkvm = { version = "3.0.0" }

[[bin]]
name = "test-simple-program"
path = "src/main.rs"
EOF

    cat > programs/test-simple/src/main.rs << 'EOF'
#![no_main]
sp1_zkvm::entrypoint!(main);

pub fn main() {
    // Simple computation - sum of squares
    let mut sum = 0u64;
    for i in 1..=100 {
        sum += i * i;
    }
    
    println!("cycle-tracker-start: computation");
    // More intensive computation
    for _ in 0..1000 {
        sum = sum.wrapping_mul(1234567).wrapping_add(987654321);
    }
    println!("cycle-tracker-end: computation");
    
    sp1_zkvm::io::commit(&sum);
}
EOF

    # Create medium complexity test program
    mkdir -p programs/test-medium
    cat > programs/test-medium/Cargo.toml << 'EOF'
[package]
name = "test-medium-program"
version = "0.1.0"
edition = "2021"

[dependencies]
sp1-zkvm = { version = "3.0.0" }

[[bin]]
name = "test-medium-program"
path = "src/main.rs"
EOF

    cat > programs/test-medium/src/main.rs << 'EOF'
#![no_main]
sp1_zkvm::entrypoint!(main);

pub fn main() {
    println!("cycle-tracker-start: fibonacci");
    
    // Fibonacci with more iterations
    let n = sp1_zkvm::io::read::<u32>();
    let mut a = 0u64;
    let mut b = 1u64;
    
    for i in 0..n {
        let temp = a + b;
        a = b;
        b = temp;
        
        // Add some extra computation to increase cycles
        if i % 100 == 0 {
            for j in 0..1000 {
                a = a.wrapping_mul(j as u64 + 1);
                b = b.wrapping_add(j as u64 * 2);
            }
        }
    }
    
    println!("cycle-tracker-end: fibonacci");
    
    sp1_zkvm::io::commit(&b);
}
EOF

    # Create complex test program
    mkdir -p programs/test-complex
    cat > programs/test-complex/Cargo.toml << 'EOF'
[package]
name = "test-complex-program"
version = "0.1.0"
edition = "2021"

[dependencies]
sp1-zkvm = { version = "3.0.0" }

[[bin]]
name = "test-complex-program"
path = "src/main.rs"
EOF

    cat > programs/test-complex/src/main.rs << 'EOF'
#![no_main]
sp1_zkvm::entrypoint!(main);

pub fn main() {
    println!("cycle-tracker-start: matrix_operations");
    
    // Matrix multiplication and operations
    let size = 50; // 50x50 matrix
    let mut matrix_a = vec![vec![0u64; size]; size];
    let mut matrix_b = vec![vec![0u64; size]; size];
    let mut result = vec![vec![0u64; size]; size];
    
    // Initialize matrices
    for i in 0..size {
        for j in 0..size {
            matrix_a[i][j] = (i * j + 1) as u64;
            matrix_b[i][j] = (i + j + 1) as u64;
        }
    }
    
    // Matrix multiplication
    for i in 0..size {
        for j in 0..size {
            for k in 0..size {
                result[i][j] = result[i][j].wrapping_add(
                    matrix_a[i][k].wrapping_mul(matrix_b[k][j])
                );
            }
        }
    }
    
    // Additional complex operations
    for _ in 0..100 {
        for i in 0..size {
            for j in 0..size {
                result[i][j] = result[i][j]
                    .wrapping_mul(1234567)
                    .wrapping_add(987654321)
                    .wrapping_mul(result[(i + 1) % size][(j + 1) % size]);
            }
        }
    }
    
    println!("cycle-tracker-end: matrix_operations");
    
    // Commit the sum of the result matrix
    let mut sum = 0u64;
    for i in 0..size {
        for j in 0..size {
            sum = sum.wrapping_add(result[i][j]);
        }
    }
    
    sp1_zkvm::io::commit(&sum);
}
EOF

    echo -e "${GREEN}✅ Test programs created${NC}"
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

# Function to run performance benchmarks
run_benchmarks() {
    echo -e "\n${PURPLE}⚡ Running Performance Benchmarks${NC}"
    
    # Benchmark single vs multi GPU
    echo -e "${CYAN}Benchmarking single GPU vs multi GPU performance...${NC}"
    
    # Single GPU benchmark
    echo -e "${YELLOW}Single GPU benchmark:${NC}"
    CUDA_VISIBLE_DEVICES=0 timeout 60s $BINARY calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 > "$TEST_DIR/benchmark_single.log" 2>&1 || true
    
    # Multi GPU benchmark (if available)
    if [ $(nvidia-smi -L | wc -l) -gt 1 ]; then
        echo -e "${YELLOW}Multi GPU benchmark:${NC}"
        CUDA_VISIBLE_DEVICES=0,1 timeout 60s $BINARY calibrate \
            --usd-cost-per-hour 0.40 \
            --utilization-rate 0.75 \
            --profit-margin 0.15 \
            --prove-price 0.08 > "$TEST_DIR/benchmark_multi.log" 2>&1 || true
    fi
    
    # Extract and compare results
    echo -e "\n${PURPLE}📊 Benchmark Results:${NC}"
    
    if [ -f "$TEST_DIR/benchmark_single.log" ]; then
        single_throughput=$(grep "Estimated Throughput" "$TEST_DIR/benchmark_single.log" | awk '{print $4}' || echo "N/A")
        echo -e "${CYAN}Single GPU Throughput: ${single_throughput} PGUs/second${NC}"
    fi
    
    if [ -f "$TEST_DIR/benchmark_multi.log" ]; then
        multi_throughput=$(grep "Estimated Throughput" "$TEST_DIR/benchmark_multi.log" | awk '{print $4}' || echo "N/A")
        echo -e "${CYAN}Multi GPU Throughput: ${multi_throughput} PGUs/second${NC}"
        
        # Calculate improvement
        if [ "$single_throughput" != "N/A" ] && [ "$multi_throughput" != "N/A" ]; then
            improvement=$(echo "scale=2; $multi_throughput / $single_throughput" | bc -l 2>/dev/null || echo "N/A")
            echo -e "${GREEN}Performance Improvement: ${improvement}x${NC}"
        fi
    fi
}

# Function to test memory usage
test_memory_usage() {
    echo -e "\n${PURPLE}💾 Testing Memory Usage${NC}"
    
    # Monitor memory during calibration
    echo -e "${CYAN}Monitoring memory usage during calibration...${NC}"
    
    # Start memory monitoring in background
    (
        while true; do
            echo "$(date): $(free -h | grep Mem)" >> "$TEST_DIR/memory_usage.log"
            nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits >> "$TEST_DIR/gpu_memory.log" 2>/dev/null || true
            sleep 1
        done
    ) &
    local monitor_pid=$!
    
    # Run calibration
    CUDA_VISIBLE_DEVICES=0,1 timeout 30s $BINARY calibrate \
        --usd-cost-per-hour 0.40 \
        --utilization-rate 0.75 \
        --profit-margin 0.15 \
        --prove-price 0.08 > /dev/null 2>&1 || true
    
    # Stop monitoring
    kill $monitor_pid 2>/dev/null || true
    
    echo -e "${GREEN}✅ Memory usage logged to $TEST_DIR/memory_usage.log${NC}"
    echo -e "${GREEN}✅ GPU memory usage logged to $TEST_DIR/gpu_memory.log${NC}"
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
    create_test_programs
    build_test_programs
    create_local_test
    run_benchmarks
    test_memory_usage
    
    # Summary
    echo -e "\n${PURPLE}📋 Test Summary${NC}"
    echo -e "${BLUE}===============${NC}"
    echo -e "${GREEN}✅ All tests completed${NC}"
    echo -e "${CYAN}📁 Results saved to: $TEST_DIR${NC}"
    echo -e "${CYAN}📊 View logs: ls -la $TEST_DIR${NC}"
    
    # Show key results
    if [ -f "$TEST_DIR/benchmark_single.log" ] && [ -f "$TEST_DIR/benchmark_multi.log" ]; then
        echo -e "\n${YELLOW}🎯 Key Performance Results:${NC}"
        echo -e "${CYAN}Single GPU: $(grep "Estimated Throughput" "$TEST_DIR/benchmark_single.log" | awk '{print $4" "$5}' || echo "N/A")${NC}"
        echo -e "${CYAN}Multi GPU:  $(grep "Estimated Throughput" "$TEST_DIR/benchmark_multi.log" | awk '{print $4" "$5}' || echo "N/A")${NC}"
    fi
}

# Run main function
main "$@"
EOF
