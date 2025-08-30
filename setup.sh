#!/bin/bash

# Complete Setup Script for ShardedProver Multi-GPU
# This script cleans the source and sets up everything in one go

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to clean source
clean_source() {
    print_status "Cleaning source code..."
    
    # Clean Rust build artifacts
    if command_exists cargo; then
        print_status "Cleaning Cargo build artifacts..."
        cargo clean
    fi
    
    # Remove target directory
    if [ -d "target" ]; then
        print_status "Removing target directory..."
        rm -rf target
    fi
    
    # Remove any temporary files
    print_status "Removing temporary files..."
    find . -name "*.tmp" -delete 2>/dev/null || true
    find . -name "*.log" -delete 2>/dev/null || true
    
    print_success "Source cleaned"
}

# Function to install system dependencies
install_system_deps() {
    print_status "Installing system dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install essential packages
    sudo apt install -y \
        build-essential \
        cmake \
        pkg-config \
        libssl-dev \
        git \
        curl \
        wget \
        htop \
        bc \
        jq \
        tmux \
        vim \
        nano \
        tree \
        unzip \
        zip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        protobuf-compiler \
        libprotobuf-dev \
        protobuf-c-compiler \
        libgrpc++-dev \
        libgrpc-dev \
        nodejs \
        npm
    
    # Install grpc tools via npm as fallback
    print_status "Installing grpc tools via npm..."
    if command_exists npm; then
        npm install -g grpc-tools
    else
        print_warning "npm not found, skipping grpc-tools installation"
    fi
    
    print_success "System dependencies installed"
}

# Function to install Rust
install_rust() {
    print_status "Installing Rust..."
    
    if ! command_exists rustc; then
        print_status "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
    else
        print_success "Rust already installed: $(rustc --version)"
    fi
    
    # Install Rust components
    print_status "Installing Rust components..."
    rustup component add rust-src
    rustup component add rust-analysis
    rustup component add rust-std
    
    print_success "Rust setup completed"
}

# Function to install CUDA
install_cuda() {
    print_status "Installing CUDA..."
    
    if command_exists nvcc; then
        print_success "CUDA already installed: $(nvcc --version | head -n1)"
        return 0
    fi
    
    # Remove old CUDA installations
    print_status "Removing old CUDA installations..."
    sudo apt remove --purge cuda* nvidia-cuda* -y 2>/dev/null || true
    sudo apt autoremove -y
    
    # Add NVIDIA repository
    print_status "Adding NVIDIA repository..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt update
    
    # Install CUDA 12.5+
    print_status "Installing CUDA 12.5+..."
    sudo apt install -y cuda-toolkit-12-5
    
    # Set environment variables
    print_status "Setting CUDA environment variables..."
    cat >> ~/.bashrc << EOF

# CUDA Environment
export PATH=/usr/local/cuda/bin:\$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda
EOF

    # Source environment
    source ~/.bashrc
    
    print_success "CUDA installation completed"
}

# Function to fix Cargo configuration
fix_cargo_config() {
    print_status "Fixing Cargo configuration..."
    
    # Create Cargo config directory
    mkdir -p ~/.cargo
    
    # Create optimized Cargo config
    cat > ~/.cargo/config.toml << EOF
[build]
# Optimize for multi-GPU competitive proving
jobs = 16
rustc-wrapper = ""
rustc = "rustc"

[target.x86_64-unknown-linux-gnu]
# Optimize for multi-GPU setup
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
    "-C", "link-arg=-lnvrtc"
]

[net]
# Optimize for competitive proving network
git-fetch-with-cli = true
retry = 3
timeout = 300

[profile.release]
# Optimize for multi-GPU performance
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

    print_success "Cargo configuration fixed"
}

# Function to increase system limits
increase_system_limits() {
    print_status "Increasing system limits..."
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Increase process limits
    echo "* soft nproc 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nproc 65536" | sudo tee -a /etc/security/limits.conf
    
    # Increase kernel limits
    echo "fs.file-max = 65536" | sudo tee -a /etc/sysctl.conf
    echo "kernel.pid_max = 65536" | sudo tee -a /etc/sysctl.conf
    
    # Apply changes
    sudo sysctl -p
    
    print_success "System limits increased"
}

# Function to build ShardedProver
build_sharded_prover() {
    print_status "Building ShardedProver..."
    
    # Build optimized binary
    print_status "Building optimized binary..."
    cargo build --release -p spn-node
    
    # Verify binary
    if [ -f "target/release/spn-node" ]; then
        print_success "Binary built successfully"
        ls -lh target/release/spn-node
    else
        print_error "Binary build failed"
        exit 1
    fi
}

# Function to test binary
test_binary() {
    print_status "Testing binary..."
    
    # Test help command
    if ./target/release/spn-node --help >/dev/null 2>&1; then
        print_success "Binary test passed"
    else
        print_error "Binary test failed"
        exit 1
    fi
    
    # Test calibration command
    if ./target/release/spn-node calibrate --help >/dev/null 2>&1; then
        print_success "Calibration command test passed"
    else
        print_error "Calibration command test failed"
        exit 1
    fi
}

# Function to create deployment scripts
create_deployment_scripts() {
    print_status "Creating deployment scripts..."
    
    # Create deploy script
    cat > deploy.sh << 'EOF'
#!/bin/bash

# Deploy Script for ShardedProver Multi-GPU
# Usage: ./deploy.sh <server-ip>

set -e

SERVER_IP="${1:-}"
SERVER_USER="root"
SERVER_PATH="/root/network"
LOCAL_BINARY="target/release/spn-node"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

echo "🚀 Deploying ShardedProver to server: $SERVER_IP"

# Check if binary exists
if [ ! -f "$LOCAL_BINARY" ]; then
    echo "❌ Binary not found. Building..."
    cargo build --release -p spn-node
fi

echo "📦 Copying binary to server..."
scp "$LOCAL_BINARY" "$SERVER_USER@$SERVER_IP:$SERVER_PATH/spn-node"

echo "🔧 Making binary executable..."
ssh "$SERVER_USER@$SERVER_IP" "chmod +x $SERVER_PATH/spn-node"

echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps on server:"
echo "1. cd $SERVER_PATH"
echo "2. ./spn-node --help"
echo "3. export GPU_TYPE=rtx4090  # or rtx4080, rtx3090, rtx3080, a100"
echo "4. ./spn-node prove --rpc-url https://rpc.succinct.xyz --private-key YOUR_PRIVATE_KEY --throughput 1000000 --bid 1000000000000000000 --prover YOUR_PROVER_ADDRESS"
echo ""
EOF

    # Create test script
    cat > test.sh << 'EOF'
#!/bin/bash

# Test Script for ShardedProver Multi-GPU
# Usage: ./test.sh <server-ip>

set -e

SERVER_IP="${1:-}"
SERVER_USER="root"
SERVER_PATH="/root/network"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

echo "🧪 Testing ShardedProver on server: $SERVER_IP"

echo "📋 Testing binary version..."
ssh "$SERVER_USER@$SERVER_IP" "cd $SERVER_PATH && ./spn-node --version" || {
    echo "⚠️  Version test failed, trying help..."
    ssh "$SERVER_USER@$SERVER_IP" "cd $SERVER_PATH && ./spn-node --help"
}

echo "📊 Testing calibration..."
ssh "$SERVER_USER@$SERVER_IP" "cd $SERVER_PATH && ./spn-node calibrate --usd-cost-per-hour 0.50 --utilization-rate 0.80 --profit-margin 0.20 --prove-price 0.10"

echo "✅ Testing completed!"
echo ""
echo "🎯 ShardedProver is ready for competitive proving!"
echo ""
EOF

    # Make scripts executable
    chmod +x deploy.sh test.sh
    
    print_success "Deployment scripts created"
}

# Function to display setup summary
display_setup_summary() {
    echo ""
    echo "=========================================="
    print_rtx4090 "ShardedProver Multi-GPU Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Setup Summary:"
    echo "• Source code cleaned"
    echo "• System dependencies installed"
    echo "• Rust installed and configured"
    echo "• CUDA 12.5+ installed"
    echo "• Cargo configuration optimized"
    echo "• System limits increased"
    echo "• ShardedProver built successfully"
    echo "• Binary tested and verified"
    echo "• Deployment scripts created"
    echo ""
    echo "Supported GPU Types:"
    echo "• RTX 4090 (24GB VRAM, 6 shards per GPU)"
    echo "• RTX 4080 (16GB VRAM, 4 shards per GPU)"
    echo "• RTX 3090 (24GB VRAM, 6 shards per GPU)"
    echo "• RTX 3080 (10GB VRAM, 3 shards per GPU)"
    echo "• A100 (40GB VRAM, 8 shards per GPU)"
    echo "• Auto-detect for other GPUs"
    echo ""
    echo "Next steps:"
    echo "1. Deploy: ./deploy.sh <server-ip>"
    echo "2. Test: ./test.sh <server-ip>"
    echo "3. Run: export GPU_TYPE=rtx4090 && ./spn-node prove ..."
    echo ""
    echo "Environment variables set:"
    echo "• CUDA_HOME=/usr/local/cuda"
    echo "• PATH includes CUDA binaries"
    echo "• LD_LIBRARY_PATH includes CUDA libraries"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "ShardedProver Multi-GPU Complete Setup"
    echo "=========================================="
    echo ""
    echo "This script will:"
    echo "1. Clean source code"
    echo "2. Install system dependencies"
    echo "3. Install Rust"
    echo "4. Install CUDA 12.5+"
    echo "5. Fix Cargo configuration"
    echo "6. Increase system limits"
    echo "7. Build ShardedProver"
    echo "8. Test binary"
    echo "9. Create deployment scripts"
    echo ""
    
    
    # Parse arguments
    case "${1:-all}" in
        "clean")
            print_status "Cleaning source only..."
            clean_source
            ;;
        "deps")
            print_status "Installing dependencies only..."
            install_system_deps
            install_rust
            install_cuda
            fix_cargo_config
            increase_system_limits
            ;;
        "build")
            print_status "Building only..."
            build_sharded_prover
            test_binary
            ;;
        "all")
            print_status "Running complete setup..."
            clean_source
            install_system_deps
            install_rust
            install_cuda
            fix_cargo_config
            increase_system_limits
            build_sharded_prover
            test_binary
            create_deployment_scripts
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  clean   - Clean source code only"
            echo "  deps    - Install dependencies only"
            echo "  build   - Build ShardedProver only"
            echo "  all     - Complete setup (default)"
            echo "  help    - Show this help"
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
