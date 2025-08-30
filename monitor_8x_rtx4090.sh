#!/bin/bash

# Performance Monitor for 8x RTX 4090 Competitive Prover
# Real-time monitoring of GPU performance and competitive prover status

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

# Function to get GPU information
get_gpu_info() {
    nvidia-smi --query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw \
               --format=csv,noheader,nounits
}

# Function to calculate performance metrics
calculate_metrics() {
    local gpu_info="$1"
    
    # Calculate total memory
    local total_memory=$(echo "$gpu_info" | awk -F',' '{sum+=$3} END {print sum}')
    local used_memory=$(echo "$gpu_info" | awk -F',' '{sum+=$4} END {print sum}')
    local free_memory=$(echo "$gpu_info" | awk -F',' '{sum+=$5} END {print sum}')
    
    # Calculate average utilization
    local avg_utilization=$(echo "$gpu_info" | awk -F',' '{sum+=$6} END {print sum/NR}')
    
    # Calculate average temperature
    local avg_temperature=$(echo "$gpu_info" | awk -F',' '{sum+=$7} END {print sum/NR}')
    
    # Calculate total power
    local total_power=$(echo "$gpu_info" | awk -F',' '{sum+=$8} END {print sum}')
    
    # Calculate memory usage percentage
    local memory_usage_percent=$((used_memory * 100 / total_memory))
    
    echo "$total_memory,$used_memory,$free_memory,$avg_utilization,$avg_temperature,$total_power,$memory_usage_percent"
}

# Function to display GPU status
display_gpu_status() {
    local gpu_info=$(get_gpu_info)
    local metrics=$(calculate_metrics "$gpu_info")
    
    IFS=',' read -r total_memory used_memory free_memory avg_utilization avg_temperature total_power memory_usage_percent <<< "$metrics"
    
    echo "=========================================="
    print_performance "8x RTX 4090 Performance Dashboard"
    echo "=========================================="
    echo "Last updated: $(date)"
    echo ""
    
    # Overall metrics
    echo "Overall Performance Metrics:"
    echo "  Total Memory: ${total_memory}MB (${total_memory}GB)"
    echo "  Used Memory: ${used_memory}MB (${memory_usage_percent}%)"
    echo "  Free Memory: ${free_memory}MB"
    echo "  Average GPU Utilization: ${avg_utilization}%"
    echo "  Average Temperature: ${avg_temperature}°C"
    echo "  Total Power Draw: ${total_power}W"
    echo ""
    
    # Individual GPU status
    echo "Individual GPU Status:"
    echo "$gpu_info" | while IFS=',' read -r index name total used free util temp power; do
        local gpu_memory_percent=$((used * 100 / total))
        local status_color=""
        
        # Color coding based on utilization
        if [ "$util" -gt 80 ]; then
            status_color="${GREEN}"
        elif [ "$util" -gt 50 ]; then
            status_color="${YELLOW}"
        else
            status_color="${RED}"
        fi
        
        echo -e "  ${status_color}GPU $index: ${name}${NC}"
        echo -e "    Memory: ${used}MB/${total}MB (${gpu_memory_percent}%) | Util: ${util}% | Temp: ${temp}°C | Power: ${power}W"
    done
    
    echo ""
}

# Function to check competitive prover status
check_prover_status() {
    echo "Competitive Prover Status:"
    
    if [ -f "logs/competitive_prover.pid" ]; then
        local pid=$(cat logs/competitive_prover.pid)
        if ps -p $pid > /dev/null 2>&1; then
            print_success "✅ Competitive prover running (PID: $pid)"
            
            # Get process info
            local cpu_usage=$(ps -p $pid -o %cpu --no-headers 2>/dev/null || echo "N/A")
            local mem_usage=$(ps -p $pid -o %mem --no-headers 2>/dev/null || echo "N/A")
            local runtime=$(ps -p $pid -o etime --no-headers 2>/dev/null || echo "N/A")
            
            echo "  CPU Usage: ${cpu_usage}%"
            echo "  Memory Usage: ${mem_usage}%"
            echo "  Runtime: ${runtime}"
        else
            print_error "❌ Competitive prover not running (PID file exists but process dead)"
        fi
    else
        print_error "❌ Competitive prover not running (no PID file)"
    fi
    
    echo ""
}

# Function to show recent logs
show_recent_logs() {
    echo "Recent Competitive Prover Logs:"
    
    if [ -f "logs/competitive_prover.log" ]; then
        # Show last 5 lines with highlighting
        tail -5 logs/competitive_prover.log | while read line; do
            if [[ "$line" == *"ERROR"* ]]; then
                echo -e "  ${RED}$line${NC}"
            elif [[ "$line" == *"WARN"* ]]; then
                echo -e "  ${YELLOW}$line${NC}"
            elif [[ "$line" == *"ShardedProver"* ]] || [[ "$line" == *"RTX4090"* ]]; then
                echo -e "  ${PURPLE}$line${NC}"
            else
                echo "  $line"
            fi
        done
    else
        print_warning "No log file found"
    fi
    
    echo ""
}

# Function to show performance trends
show_performance_trends() {
    echo "Performance Trends:"
    
    # Check if we have historical data
    if [ -f "logs/performance_history.log" ]; then
        local recent_data=$(tail -10 logs/performance_history.log)
        echo "  Recent performance data available"
        echo "  Check logs/performance_history.log for detailed trends"
    else
        echo "  No historical data available yet"
        echo "  Performance tracking will start automatically"
    fi
    
    echo ""
}

# Function to save performance data
save_performance_data() {
    local gpu_info=$(get_gpu_info)
    local metrics=$(calculate_metrics "$gpu_info")
    
    # Create logs directory if it doesn't exist
    mkdir -p logs
    
    # Save to performance history
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$metrics" >> logs/performance_history.log
    
    # Keep only last 1000 entries
    if [ -f "logs/performance_history.log" ]; then
        tail -1000 logs/performance_history.log > logs/performance_history.tmp
        mv logs/performance_history.tmp logs/performance_history.log
    fi
}

# Function to show alerts
show_alerts() {
    local gpu_info=$(get_gpu_info)
    local alerts=()
    
    # Check for high temperature
    echo "$gpu_info" | while IFS=',' read -r index name total used free util temp power; do
        if [ "$temp" -gt 80 ]; then
            alerts+=("GPU $index temperature high: ${temp}°C")
        fi
    done
    
    # Check for high memory usage
    local total_memory=$(echo "$gpu_info" | awk -F',' '{sum+=$3} END {print sum}')
    local used_memory=$(echo "$gpu_info" | awk -F',' '{sum+=$4} END {print sum}')
    local memory_usage_percent=$((used_memory * 100 / total_memory))
    
    if [ "$memory_usage_percent" -gt 95 ]; then
        alerts+=("High memory usage: ${memory_usage_percent}%")
    fi
    
    # Check for low utilization
    local avg_utilization=$(echo "$gpu_info" | awk -F',' '{sum+=$6} END {print sum/NR}')
    if [ "$avg_utilization" -lt 20 ]; then
        alerts+=("Low GPU utilization: ${avg_utilization}%")
    fi
    
    # Display alerts
    if [ ${#alerts[@]} -gt 0 ]; then
        echo "⚠️  Alerts:"
        for alert in "${alerts[@]}"; do
            echo -e "  ${YELLOW}$alert${NC}"
        done
        echo ""
    fi
}

# Function to show help
show_help() {
    echo "=========================================="
    echo "8x RTX 4090 Performance Monitor"
    echo "=========================================="
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  monitor   Start continuous monitoring (default)"
    echo "  status    Show current status once"
    echo "  logs      Show recent logs"
    echo "  trends    Show performance trends"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 monitor  # Start continuous monitoring"
    echo "  $0 status   # Show current status"
    echo "  $0 logs     # View recent logs"
    echo ""
}

# Function to start continuous monitoring
start_monitoring() {
    print_status "Starting 8x RTX 4090 performance monitoring..."
    print_status "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Save initial performance data
    save_performance_data
    
    # Continuous monitoring loop
    while true; do
        clear
        
        # Display all information
        display_gpu_status
        check_prover_status
        show_recent_logs
        show_performance_trends
        show_alerts
        
        # Save performance data
        save_performance_data
        
        # Wait before next update
        sleep 5
    done
}

# Function to show status once
show_status_once() {
    display_gpu_status
    check_prover_status
    show_recent_logs
    show_alerts
}

# Function to show logs
show_logs_only() {
    show_recent_logs
}

# Function to show trends
show_trends_only() {
    show_performance_trends
}

# Main execution
main() {
    case "${1:-monitor}" in
        "monitor")
            start_monitoring
            ;;
        "status")
            show_status_once
            ;;
        "logs")
            show_logs_only
            ;;
        "trends")
            show_trends_only
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
