#!/bin/bash

# Setup Script for 8x RTX 4090 Competitive Prover Dependencies
# Fixes system limits, installs dependencies, and configures environment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_rtx4090() {
    echo -e "${PURPLE}[RTX4090]${NC} $1"
}

print_performance() {
    echo -e "${CYAN}[PERFORMANCE]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to fix system limits
fix_system_limits() {
    print_status "Fixing system limits for 8x RTX 4090 competitive proving..."
    
    # Check current limits
    print_status "Current limits:"
    ulimit -n
    ulimit -u
    
    # Set higher limits for current session
    print_status "Setting higher limits for current session..."
    ulimit -n 65536
    ulimit -u 65536
    
    # Create systemd limits file for permanent fix
    print_status "Creating permanent system limits..."
    cat > /etc/security/limits.d/99-rtx4090.conf << EOF
# 8x RTX 4090 Competitive Prover Limits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
root soft nofile 65536
root hard nofile 65536
root soft nproc 65536
root hard nproc 65536
EOF

    # Update sysctl for higher limits
    print_status "Updating sysctl limits..."
    cat > /etc/sysctl.d/99-rtx4090.conf << EOF
# 8x RTX 4090 Competitive Prover System Limits
fs.file-max = 65536
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
kernel.pid_max = 65536
kernel.threads-max = 65536
vm.max_map_count = 262144
EOF

    # Apply sysctl changes
    sysctl -p /etc/sysctl.d/99-rtx4090.conf
    
    print_success "System limits updated for 8x RTX 4090 competitive proving"
}

# Function to install system dependencies
install_system_dependencies() {
    print_status "Installing system dependencies for 8x RTX 4090..."
    
    # Update package list
    apt update
    
    # Install essential packages
    apt install -y \
        build-essential \
        cmake \
        pkg-config \
        libssl-dev \
        libclang-dev \
        clang \
        llvm \
        git \
        curl \
        wget \
        htop \
        nvtop \
        bc \
        jq \
        tmux \
        screen \
        vim \
        nano \
        tree \
        unzip \
        zip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release
    
    print_success "System dependencies installed"
}

# Function to install Rust
install_rust() {
    print_status "Installing Rust for 8x RTX 4090 competitive proving..."
    
    if ! command_exists rustc; then
        print_status "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # Source Rust environment
        source ~/.cargo/env
        
        # Install additional Rust components
        rustup component add rust-src
        rustup component add rust-analysis
        rustup component add rust-std
        
        # Install useful Rust tools
        cargo install cargo-watch
        cargo install cargo-audit
        cargo install cargo-outdated
        cargo install cargo-tree
        
        print_success "Rust installed successfully"
    else
        print_status "Rust already installed, updating..."
        rustup update
        print_success "Rust updated"
    fi
}

# Function to configure Cargo for 8x RTX 4090
configure_cargo() {
    print_status "Configuring Cargo for 8x RTX 4090 competitive proving..."
    
    # Create Cargo config for better performance
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << EOF
[build]
# Optimize for 8x RTX 4090 competitive proving
jobs = 16
rustc-wrapper = ""
rustc = "rustc"

[target.x86_64-unknown-linux-gnu]
# Optimize for 8x RTX 4090
rustflags = [
    "-C", "target-cpu=native",
    "-C", "target-feature=+avx2,+fma,+bmi2,+popcnt",
    "-C", "link-arg=-Wl,-rpath,/usr/local/cuda/lib64",
    "-C", "link-arg=-L/usr/local/cuda/lib64",
    "-C", "link-arg=-lcudart",
    "-C", "link-arg=-lcublas",
    "-C", "link-arg=-lcurand",
    "-C", "link-arg=-lcusolver",
    "-C", "link-arg=-lcusparse",
    "-C", "link-arg=-lnvrtc",
    "-C", "link-arg=-lnvml",
    "-C", "link-arg=-lnvidia-ml",
]

[net]
# Optimize for competitive proving network
git-fetch-with-cli = true
retry = 3
timeout = 300

[profile.release]
# Optimize for 8x RTX 4090 performance
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"
strip = true
debug = false
overflow-checks = false

[profile.dev]
# Faster development builds
opt-level = 1
debug = true
overflow-checks = true
EOF

    print_success "Cargo configured for 8x RTX 4090 competitive proving"
}

# Function to install CUDA dependencies
install_cuda_dependencies() {
    print_status "Installing CUDA dependencies for 8x RTX 4090..."
    
    # Check if CUDA is already installed
    if command_exists nvcc; then
        print_status "CUDA already installed"
        nvcc --version
    else
        print_warning "CUDA not found. Please install CUDA manually:"
        echo "1. Download CUDA from: https://developer.nvidia.com/cuda-downloads"
        echo "2. Install CUDA toolkit"
        echo "3. Set CUDA environment variables"
    fi
    
    # Install CUDA development libraries (with error handling)
    print_status "Installing CUDA packages..."
    
    # Try to install available packages
    local cuda_packages=(
        "nvidia-cuda-toolkit"
        "nvidia-cuda-dev"
        "nvidia-cuda-gdb"
    )
    
    # Check which packages are available
    for package in "${cuda_packages[@]}"; do
        if apt-cache show "$package" >/dev/null 2>&1; then
            print_status "Installing $package..."
            apt install -y "$package" || print_warning "Failed to install $package"
        else
            print_warning "Package $package not available"
        fi
    done
    
    # Try to install documentation package
    if apt-cache show "nvidia-cuda-toolkit-doc" >/dev/null 2>&1; then
        print_status "Installing nvidia-cuda-toolkit-doc..."
        apt install -y nvidia-cuda-toolkit-doc || print_warning "Failed to install nvidia-cuda-toolkit-doc"
    else
        print_warning "nvidia-cuda-toolkit-doc not available"
    fi
    
    # Try to install samples if available
    if apt-cache show "nvidia-cuda-samples" >/dev/null 2>&1; then
        print_status "Installing nvidia-cuda-samples..."
        apt install -y nvidia-cuda-samples || print_warning "Failed to install nvidia-cuda-samples"
    else
        print_warning "nvidia-cuda-samples not available"
    fi
    
    # Set CUDA environment variables
    print_status "Setting CUDA environment variables..."
    cat >> ~/.bashrc << EOF

# 8x RTX 4090 CUDA Environment
export CUDA_HOME=/usr/local/cuda
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
export CUDA_UNIFIED_MEMORY=1
export CUDA_PEER_MEMORY_POOL_SIZE=0
EOF

    # Check if CUDA is working
    if command_exists nvcc; then
        print_success "CUDA toolkit found: $(nvcc --version | head -1)"
    else
        print_warning "CUDA toolkit not found. You may need to install it manually."
        print_status "To install CUDA manually:"
        echo "1. Visit: https://developer.nvidia.com/cuda-downloads"
        echo "2. Select your Linux distribution"
        echo "3. Follow installation instructions"
        echo "4. Restart this script after installation"
    fi
    
    print_success "CUDA dependencies configured"
}

# Function to configure environment for 8x RTX 4090
configure_environment() {
    print_status "Configuring environment for 8x RTX 4090 competitive proving..."
    
    # Create environment file
    cat > ~/.rtx4090_env << EOF
# 8x RTX 4090 Competitive Prover Environment
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export SP1_PROVER=cuda

# 8x RTX 4090 performance tuning
export CUDA_LAUNCH_BLOCKING=0
export CUDA_CACHE_DISABLE=0
export CUDA_MEMORY_POOL_SIZE=0

# 8x RTX 4090 specific optimizations
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
export CUDA_UNIFIED_MEMORY=1
export CUDA_PEER_MEMORY_POOL_SIZE=0

# 8x RTX 4090 competitive prover settings
export SPN_RTX4090_MODE=true
export SPN_SHARDED_PROCESSING=true
export SPN_NUM_GPUS=8
export SPN_SHARDS_PER_GPU=4
export SPN_TOTAL_SHARDS=32
export SPN_MIN_CYCLES_PER_SHARD=2000000
export SPN_MAX_CYCLES_PER_SHARD=20000000
export SPN_ENABLE_CHECKPOINTING=true
export SPN_CHECKPOINT_INTERVAL=2000000

# 8x RTX 4090 sharding configuration
export SPN_SHARDING_ENABLED=true
export SPN_RECURSION_ENABLED=true
export SPN_PARALLEL_SHARDS=true

# 8x RTX 4090 memory allocation
export SPN_MEMORY_PER_SHARD_MB=5120
export SPN_TOTAL_AVAILABLE_MEMORY_MB=196512

# 8x RTX 4090 performance monitoring
export SPN_PERFORMANCE_MONITORING=true
export SPN_GPU_UTILIZATION_MONITORING=true

# 8x RTX 4090 specific settings
export SPN_8X_RTX4090_MODE=true
export SPN_OPTIMAL_SHARDING=true
export SPN_MAX_PERFORMANCE_MODE=true

# System limits for 8x RTX 4090
ulimit -n 65536
ulimit -u 65536
EOF

    # Source environment
    source ~/.rtx4090_env
    
    print_success "Environment configured for 8x RTX 4090 competitive proving"
}

# Function to clean and prepare build environment
clean_build_environment() {
    print_status "Cleaning and preparing build environment..."
    
    # Clean previous builds
    if [ -d "target" ]; then
        print_status "Cleaning previous builds..."
        cargo clean
    fi
    
    # Clear cargo cache if needed
    if [ "$1" = "--full" ]; then
        print_status "Clearing Cargo cache..."
        cargo clean
        rm -rf ~/.cargo/registry/cache
        rm -rf ~/.cargo/registry/index
    fi
    
    # Set build environment
    export RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma,+bmi2,+popcnt"
    export CARGO_BUILD_JOBS=16
    
    print_success "Build environment prepared"
}

# Function to test build environment
test_build_environment() {
    print_status "Testing build environment..."
    
    # Test Rust
    if command_exists rustc; then
        print_success "Rust: $(rustc --version)"
    else
        print_error "Rust not found"
        return 1
    fi
    
    # Test Cargo
    if command_exists cargo; then
        print_success "Cargo: $(cargo --version)"
    else
        print_error "Cargo not found"
        return 1
    fi
    
    # Test CUDA
    if command_exists nvcc; then
        print_success "CUDA: $(nvcc --version | head -1)"
    else
        print_warning "CUDA not found"
    fi
    
    # Test system limits
    local file_limit=$(ulimit -n)
    local proc_limit=$(ulimit -u)
    
    if [ "$file_limit" -ge 65536 ]; then
        print_success "File limit: $file_limit"
    else
        print_warning "File limit: $file_limit (should be >= 65536)"
    fi
    
    if [ "$proc_limit" -ge 65536 ]; then
        print_success "Process limit: $proc_limit"
    else
        print_warning "Process limit: $proc_limit (should be >= 65536)"
    fi
    
    print_success "Build environment test completed"
}

# Function to build with optimizations
build_with_optimizations() {
    print_status "Building with 8x RTX 4090 optimizations..."
    
    # Source environment
    source ~/.rtx4090_env
    
    # Set build flags
    export RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma,+bmi2,+popcnt"
    export CARGO_BUILD_JOBS=16
    
    # Build with optimizations
    print_status "Building competitive prover..."
    if cargo build --release -p spn-node; then
        print_success "8x RTX 4090 competitive prover built successfully"
    else
        print_error "Build failed"
        return 1
    fi
}

# Function to display setup summary
display_setup_summary() {
    echo ""
    echo "=========================================="
    print_rtx4090 "8x RTX 4090 Dependencies Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Setup Summary:"
    echo "• System limits increased for competitive proving"
    echo "• Rust toolchain installed and configured"
    echo "• CUDA dependencies configured"
    echo "• Environment optimized for 8x RTX 4090"
    echo "• Build system configured for maximum performance"
    echo ""
    echo "Next steps:"
    echo "1. Source environment: source ~/.rtx4090_env"
    echo "2. Test build: cargo build --release -p spn-node"
    echo "3. Run competitive prover: ./start_8x_rtx4090.sh start"
    echo ""
    echo "Environment file: ~/.rtx4090_env"
    echo "Cargo config: ~/.cargo/config.toml"
    echo "System limits: /etc/security/limits.d/99-rtx4090.conf"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "8x RTX 4090 Dependencies Setup Script"
    echo "=========================================="
    echo ""
    echo "This script will setup all dependencies for 8x RTX 4090 competitive proving"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
    
    # Parse arguments
    case "${1:-setup}" in
        "setup")
            print_status "Starting full setup..."
            fix_system_limits
            install_system_dependencies
            install_rust
            configure_cargo
            install_cuda_dependencies
            configure_environment
            clean_build_environment
            test_build_environment
            ;;
        "limits")
            print_status "Fixing system limits only..."
            fix_system_limits
            ;;
        "deps")
            print_status "Installing dependencies only..."
            install_system_dependencies
            install_rust
            configure_cargo
            ;;
        "cuda")
            print_status "Configuring CUDA only..."
            install_cuda_dependencies
            ;;
        "env")
            print_status "Configuring environment only..."
            configure_environment
            ;;
        "clean")
            print_status "Cleaning build environment..."
            clean_build_environment "$2"
            ;;
        "test")
            print_status "Testing build environment..."
            test_build_environment
            ;;
        "build")
            print_status "Building with optimizations..."
            build_with_optimizations
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  setup    - Full setup (default)"
            echo "  limits   - Fix system limits only"
            echo "  deps     - Install dependencies only"
            echo "  cuda     - Configure CUDA only"
            echo "  env      - Configure environment only"
            echo "  clean    - Clean build environment"
            echo "  test     - Test build environment"
            echo "  build    - Build with optimizations"
            echo "  help     - Show this help"
            echo ""
            exit 0
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    # Display summary
    display_setup_summary
}

# Run main function
main "$@"
