#!/bin/bash

# Test Script for 8x RTX 4090 Server
# Usage: ./test_on_server.sh <server-ip>

set -e

SERVER_IP="${1:-}"
SERVER_USER="root"
SERVER_PATH="/root/network"

if [ -z "$SERVER_IP" ]; then
    echo "Usage: $0 <server-ip>"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

echo "🧪 Testing on server: $SERVER_IP"

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
