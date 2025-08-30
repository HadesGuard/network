#!/bin/bash

echo "=== Testing GPU Detection ==="

echo "1. nvidia-smi -L output:"
nvidia-smi -L

echo ""
echo "2. CUDA_VISIBLE_DEVICES test:"
export CUDA_VISIBLE_DEVICES=0,1
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

echo ""
echo "3. Testing calibration with RTX 3080 config:"
export GPU_TYPE=rtx3080
echo "GPU_TYPE=$GPU_TYPE"

echo ""
echo "4. Running calibration (will show detected GPU count):"
./target/release/spn-node calibrate \
  --usd-cost-per-hour 0.40 \
  --utilization-rate 0.75 \
  --profit-margin 0.15 \
  --prove-price 0.08
