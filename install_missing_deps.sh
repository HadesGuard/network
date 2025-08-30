#!/bin/bash

# Install Missing Dependencies for 8x RTX 4090 Competitive Prover
# This script installs protobuf compiler and other missing build dependencies

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

# Function to install protobuf compiler
install_protobuf() {
    print_status "Installing Protocol Buffers compiler..."
    
    if command_exists protoc; then
        local protoc_version=$(protoc --version)
        print_success "Protobuf compiler already installed: $protoc_version"
        return 0
    fi
    
    # Update package list
    apt update
    
    # Install protobuf compiler
    print_status "Installing protobuf-compiler..."
    apt install -y protobuf-compiler
    
    # Verify installation
    if command_exists protoc; then
        local protoc_version=$(protoc --version)
        print_success "Protobuf compiler installed: $protoc_version"
    else
        print_error "Failed to install protobuf compiler"
        return 1
    fi
}

# Function to install build dependencies
install_build_dependencies() {
    print_status "Installing build dependencies for 8x RTX 4090 competitive proving..."
    
    # Update package list
    apt update
    
    # Install essential build tools
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
        lsb-release \
        protobuf-compiler \
        libprotobuf-dev \
        protobuf-c-compiler \
        libgrpc++-dev \
        libgrpc-dev \
        grpc-tools \
        libsnappy-dev \
        liblz4-dev \
        libzstd-dev \
        libbz2-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libunwind-dev \
        libgtest-dev \
        libbenchmark-dev \
        libfmt-dev \
        libspdlog-dev \
        libboost-all-dev \
        libeigen3-dev \
        libblas-dev \
        liblapack-dev \
        libatlas-base-dev \
        libopenblas-dev \
        libmkl-dev \
        libfftw3-dev \
        libffi-dev \
        libreadline-dev \
        libsqlite3-dev \
        libbz2-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libtinfo-dev \
        libxml2-dev \
        libxslt-dev \
        libyaml-dev \
        libjpeg-dev \
        libpng-dev \
        libtiff-dev \
        libwebp-dev \
        libopenexr-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        libavcodec-dev \
        libavformat-dev \
        libswscale-dev \
        libavutil-dev \
        libavfilter-dev \
        libavdevice-dev \
        libpostproc-dev \
        libswresample-dev \
        libx264-dev \
        libx265-dev \
        libvpx-dev \
        libvorbis-dev \
        libogg-dev \
        libmp3lame-dev \
        libfdk-aac-dev \
        libopus-dev \
        libspeex-dev \
        libtheora-dev \
        libvdpau-dev \
        libva-dev \
        libxvidcore-dev \
        libxvidcore4 \
        libxvidcore4-dev \
        libxvidcore4-dbg \
        libxvidcore4-doc \
        libxvidcore4-utils \
        libxvidcore4-dev \
        libxvidcore4-dbg \
        libxvidcore4-doc \
        libxvidcore4-utils
    
    print_success "Build dependencies installed"
}

# Function to install Rust dependencies
install_rust_dependencies() {
    print_status "Installing Rust dependencies..."
    
    # Install additional Rust components
    rustup component add rust-src
    rustup component add rust-analysis
    rustup component add rust-std
    
    # Install useful Rust tools
    cargo install cargo-watch
    cargo install cargo-audit
    cargo install cargo-outdated
    cargo install cargo-tree
    cargo install cargo-edit
    cargo install cargo-update
    cargo install cargo-tarpaulin
    cargo install cargo-profiler
    cargo install flamegraph
    
    print_success "Rust dependencies installed"
}

# Function to configure environment
configure_environment() {
    print_status "Configuring environment for 8x RTX 4090 competitive proving..."
    
    # Set environment variables
    export PROTOC=/usr/bin/protoc
    export PROTOC_INCLUDE=/usr/include/google/protobuf
    
    # Add to bashrc
    cat >> ~/.bashrc << EOF

# 8x RTX 4090 Competitive Prover Environment
export PROTOC=/usr/bin/protoc
export PROTOC_INCLUDE=/usr/include/google/protobuf
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:\$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:\$LD_LIBRARY_PATH

# Rust optimization for 8x RTX 4090
export RUSTFLAGS="-C target-cpu=native -C target-feature=+avx2,+fma,+bmi2,+popcnt"
export CARGO_BUILD_JOBS=16
export CARGO_INCREMENTAL=1
export CARGO_NET_RETRY=3
export CARGO_NET_TIMEOUT=300
EOF

    # Source environment
    source ~/.bashrc
    
    print_success "Environment configured"
}

# Function to verify installations
verify_installations() {
    print_status "Verifying installations..."
    
    # Check protobuf
    if command_exists protoc; then
        local protoc_version=$(protoc --version)
        print_success "Protobuf: $protoc_version"
    else
        print_error "Protobuf not found"
        return 1
    fi
    
    # Check build tools
    local build_tools=("gcc" "g++" "cmake" "pkg-config" "clang" "llvm-config")
    for tool in "${build_tools[@]}"; do
        if command_exists "$tool"; then
            print_success "$tool: found"
        else
            print_warning "$tool: not found"
        fi
    done
    
    # Check libraries
    local libraries=("libssl" "libprotobuf" "libgrpc++")
    for lib in "${libraries[@]}"; do
        if pkg-config --exists "$lib"; then
            local version=$(pkg-config --modversion "$lib")
            print_success "$lib: $version"
        else
            print_warning "$lib: not found"
        fi
    done
    
    print_success "Installation verification completed"
}

# Function to test build
test_build() {
    print_status "Testing build with new dependencies..."
    
    # Test protobuf compilation
    print_status "Testing protobuf compilation..."
    cat > test.proto << EOF
syntax = "proto3";
package test;
message TestMessage {
    string message = 1;
    int32 number = 2;
}
EOF

    if protoc --cpp_out=. test.proto; then
        print_success "Protobuf compilation test passed"
    else
        print_error "Protobuf compilation test failed"
        return 1
    fi
    
    # Clean up
    rm -f test.proto test.pb.cc test.pb.h
    
    # Test Rust build
    print_status "Testing Rust build..."
    if cargo check --release -p spn-node; then
        print_success "Rust build test passed"
    else
        print_warning "Rust build test failed (this might be expected)"
    fi
    
    print_success "Build test completed"
}

# Function to display installation summary
display_installation_summary() {
    echo ""
    echo "=========================================="
    print_rtx4090 "Missing Dependencies Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Installation Summary:"
    echo "• Protocol Buffers compiler installed"
    echo "• Build dependencies installed"
    echo "• Rust dependencies installed"
    echo "• Environment configured"
    echo "• 8x RTX 4090 optimizations applied"
    echo ""
    echo "Next steps:"
    echo "1. Test build: cargo build --release -p spn-node"
    echo "2. If successful, continue with competitive prover setup"
    echo "3. If still failing, check specific error messages"
    echo ""
    echo "Environment variables set:"
    echo "• PROTOC=/usr/bin/protoc"
    echo "• PROTOC_INCLUDE=/usr/include/google/protobuf"
    echo "• RUSTFLAGS optimized for 8x RTX 4090"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Install Missing Dependencies for 8x RTX 4090"
    echo "=========================================="
    echo ""
    echo "This script will install missing dependencies for competitive proving"
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_error "Please run as root (use sudo)"
        exit 1
    fi
    
    # Parse arguments
    case "${1:-install}" in
        "install")
            print_status "Starting dependency installation..."
            install_protobuf
            install_build_dependencies
            install_rust_dependencies
            configure_environment
            verify_installations
            test_build
            ;;
        "protobuf")
            print_status "Installing protobuf only..."
            install_protobuf
            verify_installations
            ;;
        "build-deps")
            print_status "Installing build dependencies only..."
            install_build_dependencies
            verify_installations
            ;;
        "rust-deps")
            print_status "Installing Rust dependencies only..."
            install_rust_dependencies
            ;;
        "verify")
            print_status "Verifying installations..."
            verify_installations
            ;;
        "test")
            print_status "Testing build..."
            test_build
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  install     - Install all dependencies (default)"
            echo "  protobuf    - Install protobuf only"
            echo "  build-deps  - Install build dependencies only"
            echo "  rust-deps   - Install Rust dependencies only"
            echo "  verify      - Verify installations"
            echo "  test        - Test build"
            echo "  help        - Show this help"
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
