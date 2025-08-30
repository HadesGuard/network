#!/bin/bash

# Start Script for 8x RTX 4090 Competitive Prover
# This script starts the competitive prover and monitors performance

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

# Configuration - MODIFY THESE FOR YOUR SETUP
RPC_URL="https://rpc.succinct.xyz"
THROUGHPUT="1000000"
BID="1000000000000000000"
PRIVATE_KEY="your-private-key"
PROVER_ADDRESS="your-prover-address"

# Check if configuration is set
check_configuration() {
    if [ "$PRIVATE_KEY" = "your-private-key" ] || [ "$PROVER_ADDRESS" = "your-prover-address" ]; then
        print_error "Please configure PRIVATE_KEY and PROVER_ADDRESS in this script first!"
        echo ""
        echo "Edit start_8x_rtx4090.sh and set:"
        echo "  PRIVATE_KEY=\"your-actual-private-key\""
        echo "  PROVER_ADDRESS=\"your-actual-prover-address\""
        echo ""
        exit 1
    fi
}

# Function to check 8x RTX 4090 setup
check_8x_rtx4090_setup() {
    print_status "Checking 8x RTX 4090 setup..."
    
    if ! command -v nvidia-smi >/dev/null 2>&1; then
        print_error "nvidia-smi not found. Please install NVIDIA drivers."
        exit 1
    fi
    
    local gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    print_rtx4090 "Detected $gpu_count GPU(s)"
    
    if [ "$gpu_count" -lt 8 ]; then
        print_warning "Only $gpu_count GPUs detected (expected 8 for optimal performance)"
    fi
    
    # Check RTX 4090 specifically
    local rtx4090_count=$(nvidia-smi --query-gpu=name --format=csv,noheader | grep -c "RTX 4090" || echo "0")
    
    if [ "$rtx4090_count" -eq 8 ]; then
        print_success "Perfect! All 8 GPUs are RTX 4090"
    elif [ "$rtx4090_count" -gt 0 ]; then
        print_success "Detected $rtx4090_count RTX 4090 GPU(s)"
    else
        print_warning "No RTX 4090 GPUs detected. Performance may be suboptimal."
    fi
    
    # Check memory
    local total_memory=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    print_performance "Total GPU Memory: ${total_memory}MB (${total_memory}GB)"
    
    # Check free memory
    local total_free_memory=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
    print_performance "Total Free Memory: ${total_free_memory}MB (${total_free_memory}GB)"
    
    echo ""
}

# Function to check competitive prover build
check_competitive_prover() {
    print_status "Checking competitive prover build..."
    
    if [ ! -f "target/release/spn-node" ]; then
        print_error "Competitive prover binary not found. Building..."
        cargo build --release -p spn-node
    else
        print_success "Competitive prover binary found"
    fi
    
    # Check configuration
    if [ ! -f "8x_rtx4090_config.env" ]; then
        print_warning "8x RTX 4090 configuration not found. Creating..."
        ./test_8x_rtx4090.sh
    else
        print_success "8x RTX 4090 configuration found"
    fi
    
    echo ""
}

# Function to start competitive prover
start_competitive_prover() {
    print_status "Starting 8x RTX 4090 competitive prover..."
    
    # Create logs directory
    mkdir -p logs
    
    # Source configuration
    source 8x_rtx4090_config.env
    
    # Start competitive prover in background
    print_rtx4090 "Starting competitive prover with 8x RTX 4090 optimization..."
    
    nohup cargo run --bin spn-node prove \
        --rpc-url "$RPC_URL" \
        --throughput "$THROUGHPUT" \
        --bid "$BID" \
        --private-key "$PRIVATE_KEY" \
        --prover "$PROVER_ADDRESS" > logs/competitive_prover.log 2>&1 &
    
    local prover_pid=$!
    echo $prover_pid > logs/competitive_prover.pid
    
    print_success "Competitive prover started with PID: $prover_pid"
    print_rtx4090 "Logs: logs/competitive_prover.log"
    print_rtx4090 "PID file: logs/competitive_prover.pid"
    
    echo ""
}

# Function to monitor performance
monitor_performance() {
    print_status "Starting performance monitoring..."
    
    echo "=========================================="
    print_performance "8x RTX 4090 Performance Monitoring"
    echo "=========================================="
    echo ""
    
    # Function to display GPU status
    display_gpu_status() {
        echo "GPU Status:"
        nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu,temperature.gpu \
                   --format=csv,noheader,nounits | while IFS=',' read -r index name memory_used memory_free utilization temp; do
            echo "  GPU $index: ${memory_used}MB used, ${memory_free}MB free, ${utilization}% util, ${temp}°C"
        done
        echo ""
    }
    
    # Function to display competitive prover status
    display_prover_status() {
        if [ -f "logs/competitive_prover.pid" ]; then
            local pid=$(cat logs/competitive_prover.pid)
            if ps -p $pid > /dev/null 2>&1; then
                print_success "Competitive prover running (PID: $pid)"
                
                # Show recent logs
                echo "Recent logs:"
                tail -5 logs/competitive_prover.log | while read line; do
                    echo "  $line"
                done
            else
                print_error "Competitive prover not running"
            fi
        else
            print_error "PID file not found"
        fi
        echo ""
    }
    
    # Function to display performance metrics
    display_performance_metrics() {
        echo "Performance Metrics:"
        
        # Calculate total memory usage
        local total_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
        local total_free=$(nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum}')
        local total_memory=$((total_used + total_free))
        local memory_usage_percent=$((total_used * 100 / total_memory))
        
        echo "  Memory Usage: ${total_used}MB / ${total_memory}MB (${memory_usage_percent}%)"
        
        # Calculate average utilization
        local avg_utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum/NR}')
        echo "  Average GPU Utilization: ${avg_utilization}%"
        
        # Calculate average temperature
        local avg_temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits | awk '{sum+=$1} END {print sum/NR}')
        echo "  Average Temperature: ${avg_temperature}°C"
        
        echo ""
    }
    
    # Initial status
    display_gpu_status
    display_prover_status
    display_performance_metrics
    
    # Continuous monitoring
    print_status "Starting continuous monitoring (Ctrl+C to stop)..."
    echo ""
    
    while true; do
        clear
        echo "=========================================="
        print_performance "8x RTX 4090 Performance Monitoring"
        echo "=========================================="
        echo "Last updated: $(date)"
        echo ""
        
        display_gpu_status
        display_prover_status
        display_performance_metrics
        
        echo "Press Ctrl+C to stop monitoring"
        sleep 5
    done
}

# Function to show help
show_help() {
    echo "=========================================="
    echo "8x RTX 4090 Competitive Prover Start Script"
    echo "=========================================="
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  start     Start competitive prover and monitor performance"
    echo "  stop      Stop competitive prover"
    echo "  status    Show current status"
    echo "  logs      Show recent logs"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start     # Start prover and monitor"
    echo "  $0 stop      # Stop prover"
    echo "  $0 status    # Check status"
    echo "  $0 logs      # View logs"
    echo ""
}

# Function to stop competitive prover
stop_competitive_prover() {
    print_status "Stopping 8x RTX 4090 competitive prover..."
    
    if [ -f "logs/competitive_prover.pid" ]; then
        local pid=$(cat logs/competitive_prover.pid)
        if ps -p $pid > /dev/null 2>&1; then
            print_status "Stopping process $pid..."
            kill $pid
            
            # Wait for process to stop
            sleep 2
            
            if ps -p $pid > /dev/null 2>&1; then
                print_warning "Process still running, force killing..."
                kill -9 $pid
            fi
            
            print_success "Competitive prover stopped"
        else
            print_warning "Process $pid not running"
        fi
        
        rm -f logs/competitive_prover.pid
    else
        print_warning "PID file not found, trying to kill by name..."
        pkill -f "spn-node prove" || true
        print_success "Competitive prover stopped"
    fi
    
    echo ""
}

# Function to show status
show_status() {
    print_status "8x RTX 4090 Competitive Prover Status"
    echo "=========================================="
    echo ""
    
    # Check if prover is running
    if [ -f "logs/competitive_prover.pid" ]; then
        local pid=$(cat logs/competitive_prover.pid)
        if ps -p $pid > /dev/null 2>&1; then
            print_success "Competitive prover is running (PID: $pid)"
        else
            print_error "Competitive prover is not running (PID file exists but process dead)"
        fi
    else
        print_error "Competitive prover is not running (no PID file)"
    fi
    
    echo ""
    
    # Show GPU status
    print_status "GPU Status:"
    nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu \
               --format=csv,noheader,nounits | while IFS=',' read -r index name memory_used memory_free utilization; do
        echo "  GPU $index: ${memory_used}MB used, ${memory_free}MB free, ${utilization}% util"
    done
    
    echo ""
}

# Function to show logs
show_logs() {
    print_status "Recent 8x RTX 4090 competitive prover logs:"
    echo "=========================================="
    echo ""
    
    if [ -f "logs/competitive_prover.log" ]; then
        tail -20 logs/competitive_prover.log
    else
        print_warning "No log file found"
    fi
    
    echo ""
}

# Main execution
main() {
    case "${1:-start}" in
        "start")
            check_configuration
            check_8x_rtx4090_setup
            check_competitive_prover
            start_competitive_prover
            monitor_performance
            ;;
        "stop")
            stop_competitive_prover
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
