#!/bin/bash

# Quick Multi-GPU Benchmark for macOS (no timeout command)
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}⚡ Quick Multi-GPU Performance Test${NC}"
echo -e "${BLUE}==================================${NC}"

BINARY="./target/release/spn-node"

# Check if binary exists
if [ ! -f "$BINARY" ]; then
    echo -e "${RED}❌ Binary not found: $BINARY${NC}"
    exit 1
fi

# Function to extract throughput
extract_throughput() {
    echo "$1" | grep "Estimated Throughput" | awk '{print $4}'
}

# Function to extract bid price
extract_bid_price() {
    echo "$1" | grep "Estimated Bid Price" | awk '{print $4}'
}

echo -e "\n${YELLOW}🔬 Testing Single GPU Performance${NC}"
echo -e "${CYAN}Running calibration with GPU 0 only...${NC}"

single_output=$(CUDA_VISIBLE_DEVICES=0 $BINARY calibrate \
    --usd-cost-per-hour 0.40 \
    --utilization-rate 0.75 \
    --profit-margin 0.15 \
    --prove-price 0.08 2>&1)

single_throughput=$(extract_throughput "$single_output")
single_bid=$(extract_bid_price "$single_output")

echo -e "${GREEN}✅ Single GPU Results:${NC}"
echo -e "${CYAN}   Throughput: ${single_throughput} PGUs/second${NC}"
echo -e "${CYAN}   Bid Price: ${single_bid} \$PROVE per 1B PGUs${NC}"

echo -e "\n${YELLOW}🔬 Testing Multi GPU Performance${NC}"
echo -e "${CYAN}Running calibration with GPU 0,1...${NC}"

multi_output=$(CUDA_VISIBLE_DEVICES=0,1 $BINARY calibrate \
    --usd-cost-per-hour 0.40 \
    --utilization-rate 0.75 \
    --profit-margin 0.15 \
    --prove-price 0.08 2>&1)

multi_throughput=$(extract_throughput "$multi_output")
multi_bid=$(extract_bid_price "$multi_output")

echo -e "${GREEN}✅ Multi GPU Results:${NC}"
echo -e "${CYAN}   Throughput: ${multi_throughput} PGUs/second${NC}"
echo -e "${CYAN}   Bid Price: ${multi_bid} \$PROVE per 1B PGUs${NC}"

# Calculate improvement
if [ -n "$single_throughput" ] && [ -n "$multi_throughput" ]; then
    improvement=$(echo "scale=2; $multi_throughput / $single_throughput" | bc -l 2>/dev/null || echo "N/A")
    bid_improvement=$(echo "scale=2; $single_bid / $multi_bid" | bc -l 2>/dev/null || echo "N/A")
    
    echo -e "\n${PURPLE}📊 Performance Summary${NC}"
    echo -e "${BLUE}=====================${NC}"
    echo -e "${CYAN}Single GPU: ${single_throughput} PGUs/second${NC}"
    echo -e "${CYAN}Multi GPU:  ${multi_throughput} PGUs/second${NC}"
    echo -e "${GREEN}Throughput Improvement: ${improvement}x${NC}"
    echo -e "${GREEN}Bid Competitiveness: ${bid_improvement}x better${NC}"
    
    # Determine success
    if [ "$improvement" != "N/A" ]; then
        threshold=$(echo "$improvement > 1.5" | bc -l 2>/dev/null || echo "0")
        if [ "$threshold" = "1" ]; then
            echo -e "${GREEN}🎉 SUCCESS: Multi-GPU sharding is working excellently!${NC}"
            echo -e "${GREEN}   Your 2x RTX 3080 setup is ${improvement}x faster with multi-GPU${NC}"
        else
            echo -e "${YELLOW}⚠️  Multi-GPU improvement is less than expected${NC}"
        fi
    fi
    
    # Performance recommendations
    echo -e "\n${PURPLE}🎯 Recommendations:${NC}"
    if [ "$improvement" != "N/A" ]; then
        recommended_throughput=$(echo "scale=0; $multi_throughput * 0.8" | bc -l 2>/dev/null || echo "N/A")
        echo -e "${CYAN}• Use throughput: ${recommended_throughput} PGUs/second (80% of max)${NC}"
        echo -e "${CYAN}• Use bid price: ${multi_bid} \$PROVE per 1B PGUs${NC}"
        echo -e "${CYAN}• Monitor GPU utilization with: watch -n 1 nvidia-smi${NC}"
    fi
fi

echo -e "\n${GREEN}✅ Benchmark completed!${NC}"
