#!/bin/bash

# Install CUDA 12.5+ for 8x RTX 4090 Competitive Prover
# This script installs the latest CUDA toolkit for optimal performance

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

# Function to detect Ubuntu version
detect_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Function to install CUDA 12.5+
install_cuda_12_5_plus() {
    print_status "Installing CUDA 12.5+ for 8x RTX 4090 competitive proving..."
    
    # Check if already installed
    if command_exists nvcc; then
        local cuda_version=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
        print_status "CUDA version detected: $cuda_version"
        
        if [[ "$cuda_version" > "12.5" ]] || [[ "$cuda_version" == "12.5" ]]; then
            print_success "CUDA $cuda_version already installed (meets requirement)"
            return 0
        else
            print_warning "CUDA $cuda_version installed but needs upgrade to 12.5+"
        fi
    fi
    
    # Detect Ubuntu version
    local ubuntu_version=$(detect_ubuntu_version)
    print_status "Detected Ubuntu version: $ubuntu_version"
    
    # Set repository based on Ubuntu version
    local repo_version
    case $ubuntu_version in
        "22.04")
            repo_version="ubuntu2204"
            ;;
        "20.04")
            repo_version="ubuntu2004"
            ;;
        "18.04")
            repo_version="ubuntu1804"
            ;;
        *)
            print_error "Unsupported Ubuntu version: $ubuntu_version"
            print_status "Please use Ubuntu 18.04, 20.04, or 22.04"
            exit 1
            ;;
    esac
    
    print_status "Using repository: $repo_version"
    
    # Remove old CUDA installations
    print_status "Removing old CUDA installations..."
    apt remove --purge -y cuda* nvidia-cuda* || true
    apt autoremove -y || true
    
    # Add NVIDIA repository
    print_status "Adding NVIDIA CUDA repository..."
    wget https://developer.download.nvidia.com/compute/cuda/repos/$repo_version/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i cuda-keyring_1.1-1_all.deb
    apt-get update
    
    # Install CUDA toolkit 12.5+
    print_status "Installing CUDA toolkit 12.5+..."
    apt-get install -y cuda-toolkit-12-5
    
    # Install additional CUDA packages
    print_status "Installing additional CUDA packages..."
    apt-get install -y \
        cuda-libraries-12-5 \
        cuda-libraries-dev-12-5 \
        cuda-runtime-12-5 \
        cuda-drivers \
        nvidia-driver-535
    
    # Set environment variables
    print_status "Setting CUDA environment variables..."
    cat >> ~/.bashrc << EOF

# CUDA 12.5+ Environment for 8x RTX 4090
export CUDA_HOME=/usr/local/cuda-12.5
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7

# 8x RTX 4090 specific CUDA optimizations
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
export CUDA_UNIFIED_MEMORY=1
export CUDA_PEER_MEMORY_POOL_SIZE=0
export CUDA_LAUNCH_BLOCKING=0
export CUDA_CACHE_DISABLE=0
export CUDA_MEMORY_POOL_SIZE=0
EOF

    # Create symlink for compatibility
    ln -sf /usr/local/cuda-12.5 /usr/local/cuda
    
    # Source environment
    source ~/.bashrc
    
    print_success "CUDA 12.5+ installed successfully"
}

# Function to verify CUDA installation
verify_cuda_installation() {
    print_status "Verifying CUDA 12.5+ installation..."
    
    # Check nvcc
    if command_exists nvcc; then
        local cuda_version=$(nvcc --version | grep "release" | awk '{print $6}' | cut -d',' -f1)
        print_success "CUDA compiler version: $cuda_version"
        
        if [[ "$cuda_version" > "12.5" ]] || [[ "$cuda_version" == "12.5" ]]; then
            print_success "CUDA version meets requirement (12.5+)"
        else
            print_error "CUDA version $cuda_version does not meet requirement (need 12.5+)"
            return 1
        fi
    else
        print_error "CUDA compiler (nvcc) not found"
        return 1
    fi
    
    # Check nvidia-smi
    if command_exists nvidia-smi; then
        print_success "NVIDIA driver found:"
        nvidia-smi --version
    else
        print_error "NVIDIA driver (nvidia-smi) not found"
        return 1
    fi
    
    # Check CUDA libraries
    local cuda_libs=(
        "/usr/local/cuda/lib64/libcudart.so"
        "/usr/local/cuda/lib64/libcublas.so"
        "/usr/local/cuda/lib64/libcurand.so"
    )
    
    for lib in "${cuda_libs[@]}"; do
        if [ -f "$lib" ]; then
            print_success "Found: $lib"
        else
            print_warning "Missing: $lib"
        fi
    done
    
    # Test CUDA compilation
    print_status "Testing CUDA compilation..."
    cat > cuda_test.cu << 'EOF'
#include <stdio.h>
#include <cuda_runtime.h>

int main() {
    int deviceCount;
    cudaGetDeviceCount(&deviceCount);
    printf("Found %d CUDA device(s)\n", deviceCount);
    
    for (int i = 0; i < deviceCount; i++) {
        cudaDeviceProp prop;
        cudaGetDeviceProperties(&prop, i);
        printf("Device %d: %s (Compute Capability: %d.%d)\n", 
               i, prop.name, prop.major, prop.minor);
    }
    
    return 0;
}
EOF

    if nvcc -o cuda_test cuda_test.cu; then
        print_success "CUDA compilation test passed"
        if ./cuda_test; then
            print_success "CUDA runtime test passed"
        else
            print_error "CUDA runtime test failed"
            return 1
        fi
    else
        print_error "CUDA compilation test failed"
        return 1
    fi
    
    # Clean up
    rm -f cuda_test cuda_test.cu
    
    print_success "CUDA 12.5+ verification completed successfully"
}

# Function to configure for 8x RTX 4090
configure_for_8x_rtx4090() {
    print_status "Configuring CUDA for 8x RTX 4090 competitive proving..."
    
    # Create 8x RTX 4090 specific configuration
    cat > /etc/profile.d/cuda-rtx4090.sh << EOF
# 8x RTX 4090 CUDA Configuration
export CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
export CUDA_UNIFIED_MEMORY=1
export CUDA_PEER_MEMORY_POOL_SIZE=0
export CUDA_LAUNCH_BLOCKING=0
export CUDA_CACHE_DISABLE=0
export CUDA_MEMORY_POOL_SIZE=0

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
EOF

    # Make it executable
    chmod +x /etc/profile.d/cuda-rtx4090.sh
    
    # Source the configuration
    source /etc/profile.d/cuda-rtx4090.sh
    
    print_success "8x RTX 4090 CUDA configuration applied"
}

# Function to display installation summary
display_installation_summary() {
    echo ""
    echo "=========================================="
    print_rtx4090 "CUDA 12.5+ Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Installation Summary:"
    echo "• CUDA 12.5+ toolkit installed"
    echo "• NVIDIA drivers installed"
    echo "• Environment variables configured"
    echo "• 8x RTX 4090 optimizations applied"
    echo ""
    echo "Next steps:"
    echo "1. Reboot system: sudo reboot"
    echo "2. Verify installation: nvcc --version"
    echo "3. Check GPUs: nvidia-smi"
    echo "4. Continue with competitive prover setup"
    echo ""
    echo "Environment files:"
    echo "• ~/.bashrc (CUDA environment)"
    echo "• /etc/profile.d/cuda-rtx4090.sh (8x RTX 4090 config)"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "CUDA 12.5+ Installation for 8x RTX 4090"
    echo "=========================================="
    echo ""
    echo "This script will install CUDA 12.5+ for optimal 8x RTX 4090 performance"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
    
    # Parse arguments
    case "${1:-install}" in
        "install")
            print_status "Starting CUDA 12.5+ installation..."
            install_cuda_12_5_plus
            verify_cuda_installation
            configure_for_8x_rtx4090
            ;;
        "verify")
            print_status "Verifying CUDA installation..."
            verify_cuda_installation
            ;;
        "configure")
            print_status "Configuring for 8x RTX 4090..."
            configure_for_8x_rtx4090
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  install   - Install CUDA 12.5+ (default)"
            echo "  verify    - Verify CUDA installation"
            echo "  configure - Configure for 8x RTX 4090"
            echo "  help      - Show this help"
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
    display_installation_summary
}

# Run main function
main "$@"
