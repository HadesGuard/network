#!/bin/bash

# Check CUDA Installation Status for 8x RTX 4090
# This script checks if CUDA is properly installed and configured

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

# Function to check CUDA installation
check_cuda_installation() {
    echo "=========================================="
    print_rtx4090 "CUDA Installation Check for 8x RTX 4090"
    echo "=========================================="
    echo ""
    
    # Check nvcc (CUDA compiler)
    print_status "Checking CUDA compiler (nvcc)..."
    if command_exists nvcc; then
        print_success "CUDA compiler found:"
        nvcc --version
    else
        print_error "CUDA compiler (nvcc) not found"
        echo ""
        print_status "To install CUDA:"
        echo "1. Visit: https://developer.nvidia.com/cuda-downloads"
        echo "2. Select Ubuntu and your version"
        echo "3. Follow installation instructions"
        echo "4. Restart this script after installation"
        echo ""
    fi
    
    # Check nvidia-smi
    print_status "Checking NVIDIA driver (nvidia-smi)..."
    if command_exists nvidia-smi; then
        print_success "NVIDIA driver found:"
        nvidia-smi --version
        echo ""
        print_status "GPU Status:"
        nvidia-smi --query-gpu=index,name,memory.total,driver_version --format=csv,noheader,nounits
    else
        print_error "NVIDIA driver (nvidia-smi) not found"
        echo ""
        print_status "To install NVIDIA driver:"
        echo "1. sudo apt update"
        echo "2. sudo apt install nvidia-driver-xxx (replace xxx with version)"
        echo "3. Reboot system"
        echo ""
    fi
    
    # Check CUDA libraries
    print_status "Checking CUDA libraries..."
    local cuda_libs=(
        "/usr/local/cuda/lib64/libcudart.so"
        "/usr/lib/x86_64-linux-gnu/libcudart.so"
        "/usr/local/cuda/lib64/libcublas.so"
        "/usr/lib/x86_64-linux-gnu/libcublas.so"
    )
    
    local found_libs=0
    for lib in "${cuda_libs[@]}"; do
        if [ -f "$lib" ]; then
            print_success "Found: $lib"
            found_libs=$((found_libs + 1))
        fi
    done
    
    if [ $found_libs -eq 0 ]; then
        print_warning "No CUDA libraries found in standard locations"
    fi
    
    # Check CUDA environment variables
    print_status "Checking CUDA environment variables..."
    local cuda_vars=(
        "CUDA_HOME"
        "CUDA_VISIBLE_DEVICES"
        "LD_LIBRARY_PATH"
    )
    
    for var in "${cuda_vars[@]}"; do
        if [ -n "${!var}" ]; then
            print_success "$var is set: ${!var}"
        else
            print_warning "$var is not set"
        fi
    done
    
    # Check CUDA packages
    print_status "Checking CUDA packages..."
    local cuda_packages=(
        "nvidia-cuda-toolkit"
        "nvidia-cuda-dev"
        "nvidia-cuda-gdb"
    )
    
    for package in "${cuda_packages[@]}"; do
        if dpkg -l | grep -q "$package"; then
            print_success "$package is installed"
        else
            print_warning "$package is not installed"
        fi
    done
    
    echo ""
}

# Function to check system requirements
check_system_requirements() {
    print_status "Checking system requirements..."
    
    # Check system limits
    local file_limit=$(ulimit -n)
    local proc_limit=$(ulimit -u)
    
    print_status "System limits:"
    echo "File limit: $file_limit"
    echo "Process limit: $proc_limit"
    
    if [ "$file_limit" -ge 65536 ]; then
        print_success "File limit is sufficient"
    else
        print_warning "File limit should be >= 65536"
    fi
    
    if [ "$proc_limit" -ge 65536 ]; then
        print_success "Process limit is sufficient"
    else
        print_warning "Process limit should be >= 65536"
    fi
    
    # Check available memory
    local total_mem=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    print_status "Total memory: ${total_mem}MB"
    
    if [ "$total_mem" -ge 32768 ]; then
        print_success "Memory is sufficient for 8x RTX 4090"
    else
        print_warning "Memory might be insufficient for 8x RTX 4090"
    fi
    
    echo ""
}

# Function to provide installation guidance
provide_installation_guidance() {
    echo "=========================================="
    print_rtx4090 "Installation Guidance"
    echo "=========================================="
    echo ""
    
    if ! command_exists nvcc; then
        print_status "CUDA Installation Steps:"
        echo ""
        echo "1. Add NVIDIA repository:"
        echo "   wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb"
        echo "   sudo dpkg -i cuda-keyring_1.0-1_all.deb"
        echo "   sudo apt-get update"
        echo ""
        echo "2. Install CUDA toolkit:"
        echo "   sudo apt-get install cuda-toolkit-12-3"
        echo ""
        echo "3. Set environment variables:"
        echo "   echo 'export PATH=/usr/local/cuda/bin:\$PATH' >> ~/.bashrc"
        echo "   echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH' >> ~/.bashrc"
        echo "   source ~/.bashrc"
        echo ""
        echo "4. Verify installation:"
        echo "   nvcc --version"
        echo ""
    fi
    
    if ! command_exists nvidia-smi; then
        print_status "NVIDIA Driver Installation Steps:"
        echo ""
        echo "1. Install NVIDIA driver:"
        echo "   sudo apt update"
        echo "   sudo apt install nvidia-driver-535"
        echo ""
        echo "2. Reboot system:"
        echo "   sudo reboot"
        echo ""
        echo "3. Verify installation:"
        echo "   nvidia-smi"
        echo ""
    fi
    
    print_status "After installation, run this script again to verify."
    echo ""
}

# Function to test CUDA functionality
test_cuda_functionality() {
    print_status "Testing CUDA functionality..."
    
    if command_exists nvcc; then
        # Create a simple CUDA test program
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
        printf("Device %d: %s\n", i, prop.name);
    }
    
    return 0;
}
EOF

        # Compile and run test
        if nvcc -o cuda_test cuda_test.cu; then
            print_success "CUDA compilation successful"
            if ./cuda_test; then
                print_success "CUDA runtime test successful"
            else
                print_error "CUDA runtime test failed"
            fi
        else
            print_error "CUDA compilation failed"
        fi
        
        # Clean up
        rm -f cuda_test cuda_test.cu
    else
        print_warning "Cannot test CUDA - nvcc not found"
    fi
    
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "CUDA Installation Check for 8x RTX 4090"
    echo "=========================================="
    echo ""
    
    check_cuda_installation
    check_system_requirements
    test_cuda_functionality
    provide_installation_guidance
    
    echo "=========================================="
    print_rtx4090 "Check Complete!"
    echo "=========================================="
    echo ""
    
    # Summary
    if command_exists nvcc && command_exists nvidia-smi; then
        print_success "CUDA appears to be properly installed!"
        echo "You can now continue with the competitive prover setup."
    else
        print_warning "CUDA installation incomplete."
        echo "Please follow the installation guidance above."
    fi
    
    echo ""
}

# Run main function
main "$@"
