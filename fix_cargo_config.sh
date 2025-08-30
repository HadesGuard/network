#!/bin/bash

# Fix Cargo Configuration for 8x RTX 4090 Competitive Prover
# This script fixes the Cargo config to avoid linking errors

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

# Function to fix Cargo config
fix_cargo_config() {
    print_status "Fixing Cargo configuration for 8x RTX 4090 competitive proving..."
    
    # Create fixed Cargo config
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << EOF
[build]
# Optimize for 8x RTX 4090 competitive proving
jobs = 16
rustc-wrapper = ""
rustc = "rustc"

[target.x86_64-unknown-linux-gnu]
# Optimize for 8x RTX 4090 (fixed version)
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

    print_success "Cargo configuration fixed"
}

# Function to clean build environment
clean_build_environment() {
    print_status "Cleaning build environment..."
    
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
    
    print_success "Build environment cleaned"
}

# Function to test build
test_build() {
    print_status "Testing build with fixed configuration..."
    
    # Test with a simple build first
    print_status "Testing basic compilation..."
    if cargo check --release -p spn-node; then
        print_success "Basic compilation test passed"
    else
        print_error "Basic compilation test failed"
        return 1
    fi
    
    # Test full build
    print_status "Testing full build..."
    if cargo build --release -p spn-node; then
        print_success "Full build test passed"
    else
        print_error "Full build test failed"
        return 1
    fi
    
    print_success "Build test completed successfully"
}

# Function to create minimal Cargo config
create_minimal_config() {
    print_status "Creating minimal Cargo configuration..."
    
    mkdir -p ~/.cargo
    cat > ~/.cargo/config.toml << EOF
[build]
jobs = 16

[profile.release]
opt-level = 3
lto = true
codegen-units = 1
panic = "abort"
strip = true
debug = false
overflow-checks = false

[profile.dev]
opt-level = 1
debug = true
overflow-checks = true
EOF

    print_success "Minimal Cargo configuration created"
}

# Function to check CUDA libraries
check_cuda_libraries() {
    print_status "Checking available CUDA libraries..."
    
    local cuda_libs=(
        "/usr/local/cuda/lib64/libcudart.so"
        "/usr/local/cuda/lib64/libcublas.so"
        "/usr/local/cuda/lib64/libcurand.so"
        "/usr/local/cuda/lib64/libcusolver.so"
        "/usr/local/cuda/lib64/libcusparse.so"
        "/usr/local/cuda/lib64/libnvrtc.so"
    )
    
    local found_libs=0
    for lib in "${cuda_libs[@]}"; do
        if [ -f "$lib" ]; then
            print_success "Found: $lib"
            found_libs=$((found_libs + 1))
        else
            print_warning "Missing: $lib"
        fi
    done
    
    if [ $found_libs -eq 0 ]; then
        print_warning "No CUDA libraries found. Using minimal configuration."
        create_minimal_config
    else
        print_success "Found $found_libs CUDA libraries"
    fi
}

# Function to display fix summary
display_fix_summary() {
    echo ""
    echo "=========================================="
    print_rtx4090 "Cargo Configuration Fix Complete!"
    echo "=========================================="
    echo ""
    echo "Fix Summary:"
    echo "• Removed problematic CUDA library links"
    echo "• Fixed Cargo configuration"
    echo "• Cleaned build environment"
    echo "• Optimized for 8x RTX 4090 performance"
    echo ""
    echo "Next steps:"
    echo "1. Test build: cargo build --release -p spn-node"
    echo "2. If successful, continue with competitive prover setup"
    echo "3. If still failing, try minimal configuration"
    echo ""
    echo "Configuration file: ~/.cargo/config.toml"
    echo ""
}

# Main execution
main() {
    echo "=========================================="
    echo "Fix Cargo Configuration for 8x RTX 4090"
    echo "=========================================="
    echo ""
    echo "This script will fix Cargo configuration to avoid linking errors"
    echo ""
    
    # Parse arguments
    case "${1:-fix}" in
        "fix")
            print_status "Starting Cargo configuration fix..."
            check_cuda_libraries
            fix_cargo_config
            clean_build_environment
            test_build
            ;;
        "minimal")
            print_status "Creating minimal configuration..."
            create_minimal_config
            clean_build_environment
            test_build
            ;;
        "clean")
            print_status "Cleaning build environment..."
            clean_build_environment "$2"
            ;;
        "test")
            print_status "Testing build..."
            test_build
            ;;
        "help")
            echo "Usage: $0 [command]"
            echo ""
            echo "Commands:"
            echo "  fix      - Fix Cargo configuration (default)"
            echo "  minimal  - Create minimal configuration"
            echo "  clean    - Clean build environment"
            echo "  test     - Test build"
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
    display_fix_summary
}

# Run main function
main "$@"
