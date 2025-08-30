#!/bin/bash

# Simple Deploy Script for 8x RTX 4090 Server
# Usage: ./deploy_simple.sh <server-ip>

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

echo "🚀 Deploying to server: $SERVER_IP"

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
echo "3. ./spn-node calibrate --usd-cost-per-hour 0.50 --utilization-rate 0.80 --profit-margin 0.20 --prove-price 0.10"
echo ""
