#!/bin/bash

# Competitive Prover Setup Script for Succinct Prover Network
# This script configures sharded multi-GPU processing for competitive proving

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_competitive() {
    echo -e "${PURPLE}[COMPETITIVE]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check NVIDIA driver and CUDA
check_nvidia_cuda() {
    print_status "Checking NVIDIA driver and CUDA support for competitive proving..."
    
    if ! command_exists nvidia-smi; then
        print_error "nvidia-smi not found. Please install NVIDIA drivers."
        return 1
    fi
    
    # Check driver version
    local driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | cut -d. -f1)
    if [ -z "$driver_version" ] || [ "$driver_version" -lt 555 ]; then
        print_error "NVIDIA driver version too old. Need version 555 or higher for competitive proving."
        return 1
    fi
    
    print_success "NVIDIA driver version: $driver_version"
    
    # Check CUDA support
    if command_exists nvcc; then
        print_success "CUDA toolkit found: $(nvcc --version | grep 'release' | awk '{print $6}')"
    else
        print_warning "CUDA toolkit not found, but runtime support may be available"
    fi
    
    return 0
}

# Function to detect and display GPU information for competitive setup
detect_competitive_gpus() {
    print_status "Detecting GPUs for competitive sharded proving..."
    
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    
    if [ "$gpu_count" -eq 0 ]; then
        print_error "No CUDA GPUs detected"
        return 1
    fi
    
    print_competitive "Found $gpu_count GPU(s) for competitive proving"
    
    echo ""
    echo "Competitive GPU Configuration:"
    echo "============================="
    
    # Display detailed GPU information
    nvidia-smi --query-gpu=index,name,memory.total,memory.free,utilization.gpu,temperature.gpu \
               --format=csv,noheader,nounits | while IFS=',' read -r index name memory_total memory_free utilization temp; do
        echo "GPU $index: $name"
        echo "  Memory: ${memory_free}MB free / ${memory_total}MB total"
        echo "  Utilization: ${utilization}%"
        echo "  Temperature: ${temp}°C"
        echo ""
    done
    
    # Calculate total memory and performance metrics
    local total_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    local total_free_memory=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    
    echo "Competitive Performance Summary:"
    echo "==============================="
    echo "Total GPUs: $gpu_count"
    echo "Total Memory: ${total_memory}MB"
    echo "Total Free Memory: ${total_free_memory}MB"
    echo "Estimated Shards: $((gpu_count * 2))"  # 2 shards per GPU default
    echo "Processing Type: Sharded Multi-GPU (Competitive)"
    echo ""
    
    return 0
}

# Function to check competitive memory requirements
check_competitive_memory() {
    print_status "Checking memory requirements for competitive sharded proving..."
    
    local min_memory_mb=4096  # 4GB minimum per GPU for competitive proving
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    
    nvidia-smi --query-gpu=index,memory.free --format=csv,noheader,nounits | while IFS=',' read -r index memory_free; do
        if [ "$memory_free" -lt "$min_memory_mb" ]; then
            print_warning "GPU $index has insufficient memory for competitive proving: ${memory_free}MB (need ${min_memory_mb}MB)"
        else
            print_success "GPU $index has sufficient memory for competitive proving: ${memory_free}MB"
        fi
    done
}

# Function to test competitive GPU access
test_competitive_gpu_access() {
    print_status "Testing competitive GPU access for sharding..."
    
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    
    # Test individual GPU access for sharding
    for ((i=0; i<gpu_count; i++)); do
        local visible_count=$(CUDA_VISIBLE_DEVICES=$i nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
        if [ "$visible_count" -eq 1 ]; then
            print_success "GPU $i accessible for sharding"
        else
            print_error "GPU $i not accessible for sharding"
            return 1
        fi
    done
    
    # Test multi-GPU access for coordination
    local device_list=$(seq -s, 0 $((gpu_count-1)))
    local visible_count=$(CUDA_VISIBLE_DEVICES=$device_list nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    if [ "$visible_count" -eq "$gpu_count" ]; then
        print_success "All $gpu_count GPUs accessible for coordination"
    else
        print_error "Only $visible_count of $gpu_count GPUs accessible for coordination"
        return 1
    fi
    
    return 0
}

# Function to create competitive configuration
create_competitive_config() {
    print_status "Creating competitive prover configuration..."
    
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    local device_list=$(seq -s, 0 $((gpu_count-1)))
    local total_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    local total_free_memory=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    
    cat > competitive_config.env << EOF
# Competitive Prover Configuration for Succinct Prover Network
# Generated on $(date)
# This configuration enables sharded multi-GPU processing for competitive proving

# Number of available GPUs
GPU_COUNT=$gpu_count

# CUDA device IDs for sharding (comma-separated)
CUDA_DEVICES=$device_list

# Total memory for competitive processing
TOTAL_MEMORY_MB=$total_memory
TOTAL_FREE_MEMORY_MB=$total_free_memory

# Environment variables for competitive proving
export CUDA_VISIBLE_DEVICES=\$CUDA_DEVICES
export SP1_PROVER=cuda

# Performance tuning for competitive proving
export CUDA_LAUNCH_BLOCKING=0
export CUDA_CACHE_DISABLE=0

# Memory management for sharding
export CUDA_MEMORY_POOL_SIZE=0
export CUDA_UNIFIED_MEMORY=1
export CUDA_PEER_MEMORY_POOL_SIZE=0

# Competitive prover settings
export SPN_COMPETITIVE_MODE=true
export SPN_SHARDED_PROCESSING=true
export SPN_NUM_GPUS=$gpu_count
export SPN_SHARDS_PER_GPU=2
export SPN_MIN_CYCLES_PER_SHARD=1000000
export SPN_MAX_CYCLES_PER_SHARD=10000000
export SPN_ENABLE_CHECKPOINTING=true
export SPN_CHECKPOINT_INTERVAL=1000000

# Sharding configuration
export SPN_SHARDING_ENABLED=true
export SPN_RECURSION_ENABLED=true
export SPN_PARALLEL_SHARDS=true
EOF

    print_success "Competitive configuration saved to competitive_config.env"
    echo ""
    echo "Configuration Summary:"
    echo "====================="
    echo "GPUs: $gpu_count"
    echo "Device List: $device_list"
    echo "Total Memory: ${total_memory}MB"
    echo "Free Memory: ${total_free_memory}MB"
    echo "Shards per GPU: 2"
    echo "Processing Type: Sharded Multi-GPU"
    echo ""
    echo "To use this configuration:"
    echo "  source competitive_config.env"
    echo ""
}

# Function to run competitive performance test
run_competitive_performance_test() {
    print_status "Running competitive performance test..."
    
    if ! command_exists cargo; then
        print_warning "Cargo not found, skipping compilation test"
        return 0
    fi
    
    # Check if we're in the right directory
    if [ ! -f "Cargo.toml" ]; then
        print_warning "Not in project root, skipping compilation test"
        return 0
    fi
    
    print_status "Building competitive prover with sharding support..."
    
    # Build the project
    if cargo build --release -p spn-node; then
        print_success "Competitive prover build completed successfully"
    else
        print_error "Competitive prover build failed"
        return 1
    fi
    
    print_competitive "Competitive prover setup is ready!"
}

# Function to display competitive prover information
display_competitive_info() {
    echo ""
    echo "=========================================="
    print_competitive "Competitive Prover Setup Complete!"
    echo "=========================================="
    echo ""
    echo "This setup enables competitive proving with:"
    echo "• Multi-GPU sharding for reduced latency"
    echo "• Parallel processing of proof shards"
    echo "• Recursion prover for combining shards"
    echo "• Checkpointing for VM state management"
    echo "• Performance monitoring and metrics"
    echo ""
    echo "Next steps:"
    echo "1. Source configuration: source competitive_config.env"
    echo "2. Run competitive prover: cargo run --bin spn-node prove [options]"
    echo "3. Monitor performance: watch -n 1 nvidia-smi"
    echo "4. Check logs for sharding information"
    echo ""
    echo "Expected performance improvements:"
    echo "• Reduced latency for large proofs"
    echo "• Better GPU utilization"
    echo "• Competitive advantage on the network"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Competitive Prover Setup for Succinct Network"
    echo "=========================================="
    echo ""
    echo "This setup configures sharded multi-GPU processing"
    echo "for competitive proving with reduced latency."
    echo ""
    
    # Check if running as root (optional)
    if [ "$EUID" -eq 0 ]; then
        print_warning "Running as root - this is not recommended for normal operation"
    fi
    
    # Step 1: Check NVIDIA driver and CUDA
    if ! check_nvidia_cuda; then
        print_error "NVIDIA/CUDA check failed. Please install proper drivers."
        exit 1
    fi
    
    echo ""
    
    # Step 2: Detect GPUs for competitive processing
    if ! detect_competitive_gpus; then
        print_error "GPU detection failed."
        exit 1
    fi
    
    echo ""
    
    # Step 3: Check competitive memory requirements
    check_competitive_memory
    
    echo ""
    
    # Step 4: Test competitive GPU access
    test_competitive_gpu_access
    
    echo ""
    
    # Step 5: Create competitive configuration
    create_competitive_config
    
    echo ""
    
    # Step 6: Run competitive performance test
    run_competitive_performance_test
    
    echo ""
    
    # Step 7: Display competitive information
    display_competitive_info
}

# Run main function
main "$@"
