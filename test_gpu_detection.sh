#!/bin/bash

echo "=== Testing Multi-GPU Calibration ==="

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
echo "4. Running MULTI-GPU calibration:"
echo "   - Will detect 2 GPUs"
echo "   - Will run 2 proofs to simulate multi-GPU performance"
echo "   - Should show much higher throughput than single GPU"
echo ""

./target/release/spn-node calibrate \
  --usd-cost-per-hour 0.40 \
  --utilization-rate 0.75 \
  --profit-margin 0.15 \
  --prove-price 0.08

echo ""
echo "=== Comparison Test ==="
echo "5. Testing single GPU for comparison:"
export CUDA_VISIBLE_DEVICES=0
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES (single GPU)"

./target/release/spn-node calibrate \
  --usd-cost-per-hour 0.40 \
  --utilization-rate 0.75 \
  --profit-margin 0.15 \
  --prove-price 0.08
