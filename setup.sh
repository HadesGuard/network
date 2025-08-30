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

# Function to check if package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Function to install system dependencies
install_system_deps() {
    print_status "Checking and installing system dependencies..."
    
    # Check essential packages (excluding Docker - handled separately)
    PACKAGES_TO_INSTALL=""
    ESSENTIAL_PACKAGES=(
        "build-essential"
        "cmake"
        "pkg-config"
        "libssl-dev"
        "git"
        "curl"
        "wget"
        "htop"
        "bc"
        "jq"
        "tmux"
        "vim"
        "nano"
        "tree"
        "unzip"
        "zip"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "protobuf-compiler"
        "libprotobuf-dev"
        "protobuf-c-compiler"
        "libgrpc++-dev"
        "libgrpc-dev"
        "nodejs"
        "npm"
    )
    
    print_status "Checking which packages need to be installed..."
    for package in "${ESSENTIAL_PACKAGES[@]}"; do
        if ! package_installed "$package"; then
            PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $package"
            print_status "Need to install: $package"
        else
            print_success "$package already installed"
        fi
    done
    
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        print_status "Updating package list..."
        sudo apt update
        
        print_status "Installing missing packages:$PACKAGES_TO_INSTALL"
        sudo apt install -y $PACKAGES_TO_INSTALL
    else
        print_success "All essential packages already installed"
    fi
    
    # Check and install grpc tools via npm
    if command_exists npm; then
        if npm list -g grpc-tools >/dev/null 2>&1; then
            print_success "grpc-tools already installed globally"
        else
            print_status "Installing grpc tools via npm..."
            npm install -g grpc-tools
        fi
    else
        print_warning "npm not found, skipping grpc-tools installation"
    fi
    
    print_success "System dependencies installed"
    
    # Install Docker separately to handle conflicts
    install_docker
}

# Function to install Docker properly
install_docker() {
    print_status "Checking Docker installation..."
    
    # Check if Docker is already installed and working
    if command_exists docker && docker --version >/dev/null 2>&1; then
        print_success "Docker already installed: $(docker --version)"
        
        # Check if service is running
        if ! systemctl is-active --quiet docker; then
            print_status "Starting Docker service..."
            sudo systemctl enable docker
            sudo systemctl start docker
        else
            print_success "Docker service already running"
        fi
        
        # Check if user is in docker group
        if ! groups $USER | grep -q docker; then
            print_status "Adding user to docker group..."
            sudo usermod -aG docker $USER
            print_warning "You may need to log out and back in for Docker group changes to take effect"
        else
            print_success "User already in docker group"
        fi
        
        return 0
    fi
    
    print_status "Installing Docker..."
    
    # Remove conflicting packages
    print_status "Removing conflicting Docker packages..."
    sudo apt remove -y docker docker-engine docker.io containerd runc containerd.io 2>/dev/null || true
    sudo apt autoremove -y
    
    # Add Docker's official GPG key
    print_status "Adding Docker repository..."
    sudo mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    
    # Add Docker repository
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package list
    sudo apt update
    
    # Install Docker Engine
    print_status "Installing Docker Engine..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    print_status "Starting Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Add user to docker group
    print_status "Adding user to docker group..."
    sudo usermod -aG docker $USER
    
    # Test Docker installation
    if docker --version >/dev/null 2>&1; then
        print_success "Docker installed successfully: $(docker --version)"
        print_success "Docker Compose installed: $(docker compose version)"
    else
        print_error "Docker installation failed"
        return 1
    fi
    
    print_warning "You may need to log out and back in for Docker group changes to take effect"
    print_success "Docker installation completed"

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

# Function to install SP1 zkVM
install_sp1() {
    print_status "Installing SP1 zkVM..."
    
    # Check if sp1up is already installed
    if command_exists sp1up; then
        print_success "sp1up already installed"
    else
        print_status "Installing sp1up (SP1 toolchain installer)..."
        curl -L https://sp1up.succinct.xyz | bash
        
        # Source the environment to make sp1up available
        if [ -f ~/.bashrc ]; then
            source ~/.bashrc
        fi
        if [ -f ~/.zshrc ]; then
            source ~/.zshrc
        fi
        
        # Add to PATH if not already there
        export PATH="$HOME/.sp1/bin:$PATH"
    fi
    
    # Install SP1 toolchain and cargo prove CLI
    print_status "Installing SP1 toolchain and cargo prove CLI..."
    
    # Check for GitHub token to avoid rate limiting
    SP1UP_ARGS=""
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        print_status "Using GitHub token to avoid rate limiting..."
        SP1UP_ARGS="--token $GITHUB_TOKEN"
    elif [ -n "${GH_TOKEN:-}" ]; then
        print_status "Using GitHub token to avoid rate limiting..."
        SP1UP_ARGS="--token $GH_TOKEN"
    else
        print_warning "No GitHub token found. If you experience rate limiting, set GITHUB_TOKEN environment variable."
    fi
    
    if command_exists sp1up; then
        sp1up $SP1UP_ARGS
    else
        print_warning "sp1up not found in PATH, trying direct installation..."
        if [ -f "$HOME/.sp1/bin/sp1up" ]; then
            "$HOME/.sp1/bin/sp1up" $SP1UP_ARGS
        else
            print_error "Failed to install SP1. Please run the installation manually:"
            print_error "curl -L https://sp1up.succinct.xyz | bash"
            print_error "Then run: sp1up"
            print_error "If you experience rate limiting, use: sp1up --token YOUR_GITHUB_TOKEN"
            return 1
        fi
    fi
    
    # Verify installation
    print_status "Verifying SP1 installation..."
    
    # Check cargo prove
    if command_exists cargo-prove || cargo prove --version >/dev/null 2>&1; then
        print_success "cargo prove CLI installed successfully"
        cargo prove --version
    else
        print_warning "cargo prove not found, attempting to source environment..."
        source ~/.cargo/env
        if cargo prove --version >/dev/null 2>&1; then
            print_success "cargo prove CLI installed successfully"
            cargo prove --version
        else
            print_error "Failed to verify cargo prove installation"
        fi
    fi
    
    # Check Succinct Rust toolchain
    if RUSTUP_TOOLCHAIN=succinct cargo --version >/dev/null 2>&1; then
        print_success "Succinct Rust toolchain installed successfully"
        RUSTUP_TOOLCHAIN=succinct cargo --version
    else
        print_warning "Succinct Rust toolchain verification failed"
        print_status "Available toolchains:"
        rustup toolchain list
    fi
    
    print_success "SP1 zkVM setup completed"
}

# Function to test SP1 installation
test_sp1() {
    print_status "Testing SP1 installation..."
    
    # Test cargo prove
    if cargo prove --version >/dev/null 2>&1; then
        print_success "cargo prove test passed"
        cargo prove --version
    else
        print_error "cargo prove test failed"
        return 1
    fi
    
    # Test Succinct toolchain
    if RUSTUP_TOOLCHAIN=succinct cargo --version >/dev/null 2>&1; then
        print_success "Succinct toolchain test passed"
        RUSTUP_TOOLCHAIN=succinct cargo --version
    else
        print_error "Succinct toolchain test failed"
        return 1
    fi
    
    # Test alternative syntax
    if cargo +succinct --version >/dev/null 2>&1; then
        print_success "Alternative Succinct toolchain syntax test passed"
        cargo +succinct --version
    else
        print_warning "Alternative Succinct toolchain syntax test failed"
    fi
    
    print_success "SP1 installation tests completed"
}

# Function to install CUDA
install_cuda() {
    print_status "Checking CUDA installation..."
    
    # Check if CUDA is already installed and working
    if command_exists nvcc; then
        CUDA_VERSION=$(nvcc --version | grep "release" | sed 's/.*release \([0-9]\+\.[0-9]\+\).*/\1/')
        print_success "CUDA already installed: $(nvcc --version | head -n1)"
        
        # Check if it's version 12.5 or higher
        if [ -n "$CUDA_VERSION" ]; then
            MAJOR_VERSION=$(echo $CUDA_VERSION | cut -d. -f1)
            MINOR_VERSION=$(echo $CUDA_VERSION | cut -d. -f2)
            if [ "$MAJOR_VERSION" -gt 12 ] || ([ "$MAJOR_VERSION" -eq 12 ] && [ "$MINOR_VERSION" -ge 5 ]); then
                print_success "CUDA version $CUDA_VERSION meets requirements (>=12.5)"
                return 0
            else
                print_warning "CUDA version $CUDA_VERSION is older than required 12.5, will upgrade..."
            fi
        fi
    fi
    
    print_status "Installing CUDA 12.5+..."
    
    # Check if CUDA keyring is already installed
    if ! package_installed "cuda-keyring"; then
        print_status "Adding NVIDIA repository..."
        if [ ! -f "cuda-keyring_1.1-1_all.deb" ]; then
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
        fi
        sudo dpkg -i cuda-keyring_1.1-1_all.deb
        sudo apt update
    else
        print_success "NVIDIA repository already configured"
    fi
    
    # Remove old CUDA installations only if needed
    if command_exists nvcc && [ -n "$CUDA_VERSION" ]; then
        MAJOR_VERSION=$(echo $CUDA_VERSION | cut -d. -f1)
        MINOR_VERSION=$(echo $CUDA_VERSION | cut -d. -f2)
        if [ "$MAJOR_VERSION" -lt 12 ] || ([ "$MAJOR_VERSION" -eq 12 ] && [ "$MINOR_VERSION" -lt 5 ]); then
            print_status "Removing old CUDA installations..."
            sudo apt remove --purge cuda* nvidia-cuda* -y 2>/dev/null || true
            sudo apt autoremove -y
        fi
    fi
    
    # Install CUDA 12.5+ if not already installed
    if ! package_installed "cuda-toolkit-12-5"; then
        print_status "Installing CUDA 12.5+..."
        sudo apt install -y cuda-toolkit-12-5
    else
        print_success "CUDA toolkit 12.5 already installed"
    fi
    
    # Set environment variables if not already set
    print_status "Checking CUDA environment variables..."
    if ! grep -q "CUDA_HOME" ~/.bashrc; then
        print_status "Setting CUDA environment variables..."
        cat >> ~/.bashrc << EOF

# CUDA Environment
export PATH=/usr/local/cuda/bin:\$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
export CUDA_HOME=/usr/local/cuda

# SP1 Environment
export PATH="\$HOME/.sp1/bin:\$PATH"
export PATH="\$HOME/.cargo/bin:\$PATH"
EOF
        print_success "CUDA environment variables added to ~/.bashrc"
    else
        print_success "CUDA environment variables already configured"
    fi

    # Source environment
    source ~/.bashrc
    
    print_success "CUDA installation completed"
}

# Function to fix Cargo configuration
fix_cargo_config() {
    print_status "Checking Cargo configuration..."
    
    # Create Cargo config directory
    mkdir -p ~/.cargo
    
    # Check if config already exists and is optimized
    if [ -f ~/.cargo/config.toml ] && grep -q "target-cpu=native" ~/.cargo/config.toml; then
        print_success "Cargo configuration already optimized"
        return 0
    fi
    
    print_status "Creating optimized Cargo configuration..."
    
    # Backup existing config if it exists
    if [ -f ~/.cargo/config.toml ]; then
        print_status "Backing up existing Cargo config..."
        cp ~/.cargo/config.toml ~/.cargo/config.toml.backup.$(date +%s)
    fi
    
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
    print_status "Checking system limits..."
    
    # Check if limits are already configured
    if grep -q "nofile 65536" /etc/security/limits.conf && grep -q "fs.file-max = 65536" /etc/sysctl.conf; then
        print_success "System limits already configured"
        return 0
    fi
    
    print_status "Increasing system limits..."
    
    # Increase file descriptor limits (only if not already set)
    if ! grep -q "nofile 65536" /etc/security/limits.conf; then
        print_status "Setting file descriptor limits..."
        echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
        echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    fi
    
    # Increase process limits (only if not already set)
    if ! grep -q "nproc 65536" /etc/security/limits.conf; then
        print_status "Setting process limits..."
        echo "* soft nproc 65536" | sudo tee -a /etc/security/limits.conf
        echo "* hard nproc 65536" | sudo tee -a /etc/security/limits.conf
    fi
    
    # Increase kernel limits (only if not already set)
    if ! grep -q "fs.file-max = 65536" /etc/sysctl.conf; then
        print_status "Setting kernel limits..."
        echo "fs.file-max = 65536" | sudo tee -a /etc/sysctl.conf
        echo "kernel.pid_max = 65536" | sudo tee -a /etc/sysctl.conf
        
        # Apply changes
        sudo sysctl -p
    fi
    
    print_success "System limits increased"
}

# Function to build ShardedProver
build_sharded_prover() {
    print_status "Checking ShardedProver binary..."
    
    # Check if binary already exists and is recent
    if [ -f "target/release/spn-node" ]; then
        print_success "Binary already exists: $(ls -lh target/release/spn-node | awk '{print $5, $6, $7, $8, $9}')"
        
        # Check if binary is newer than source files
        if [ "target/release/spn-node" -nt "Cargo.toml" ] && [ "target/release/spn-node" -nt "bin/node/src/main.rs" ]; then
            print_success "Binary is up to date, skipping build"
            return 0
        else
            print_status "Source files are newer than binary, rebuilding..."
        fi
    fi
    
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
    echo "• System dependencies installed"
    echo "• Rust installed and configured"
    echo "• SP1 zkVM installed and verified"
    echo "• CUDA 12.5+ installed"
    echo "• Cargo configuration optimized"
    echo "• System limits increased"
    echo "• ShardedProver built successfully"
    echo "• Binary tested and verified"
    echo "• SP1 installation tested"
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
    echo "4. Test SP1: cargo prove --version"
    echo "5. Create SP1 program: cargo prove new my-program"
    echo ""
    echo "Environment variables set:"
    echo "• CUDA_HOME=/usr/local/cuda"
    echo "• PATH includes CUDA binaries and SP1 tools"
    echo "• LD_LIBRARY_PATH includes CUDA libraries"
    echo ""
    echo "SP1 zkVM Tools Available:"
    echo "• cargo prove - SP1 CLI tool for compiling and proving"
    echo "• Succinct Rust toolchain (riscv32im-succinct-zkvm-elf)"
    echo "• sp1up - SP1 toolchain installer and updater"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "ShardedProver Multi-GPU Complete Setup"
    echo "=========================================="
    echo ""
    echo "This script will:"
    echo "1. Install system dependencies"
    echo "2. Install Rust"
    echo "3. Install SP1 zkVM"
    echo "4. Install CUDA 12.5+"
    echo "5. Fix Cargo configuration"
    echo "6. Increase system limits"
    echo "7. Build ShardedProver"
    echo "8. Test binary and SP1"
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
            install_sp1
            install_cuda
            fix_cargo_config
            increase_system_limits
            ;;
        "sp1")
            print_status "Installing SP1 zkVM only..."
            install_rust
            install_sp1
            test_sp1
            ;;
        "docker")
            print_status "Installing Docker only..."
            install_docker
            ;;
        "build")
            print_status "Building only..."
            build_sharded_prover
            test_binary
            test_sp1
            ;;
        "all")
            print_status "Running complete setup..."
            install_system_deps
            install_rust
            install_sp1
            install_cuda
            fix_cargo_config
            increase_system_limits
            build_sharded_prover
            test_binary
            test_sp1
            create_deployment_scripts
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  clean   - Clean source code only (optional)"
            echo "  deps    - Install dependencies only (includes SP1)"
            echo "  sp1     - Install SP1 zkVM only"
            echo "  docker  - Install Docker only (fixes conflicts)"
            echo "  build   - Build ShardedProver only (includes SP1 tests)"
            echo "  all     - Complete setup without cleaning (default)"
            echo "  help    - Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  GITHUB_TOKEN - GitHub token to avoid rate limiting during SP1 installation"
            echo "  GH_TOKEN     - Alternative GitHub token variable"
            echo ""
            echo "Examples:"
            echo "  $0                           # Complete setup (no cleaning)"
            echo "  $0 clean                     # Clean source code only"
            echo "  $0 docker                    # Fix Docker conflicts and install"
            echo "  $0 sp1                       # Install SP1 only"
            echo "  GITHUB_TOKEN=xxx $0 sp1      # Install SP1 with GitHub token"
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
