# 🧪 Local Multi-GPU Testing Guide

Hướng dẫn test multi-GPU sharding implementation mà không cần network requests thực.

## 🚀 **Quick Start**

### **1. Simple GPU Detection Test**
```bash
# Test cơ bản để verify GPU detection và calibration
./test_gpu_detection.sh
```

### **2. Performance Benchmark**  
```bash
# So sánh performance single GPU vs multi GPU
./benchmark_multi_gpu.sh
```

### **3. Comprehensive Test Suite**
```bash
# Full test suite với nhiều scenarios
./test_local_proving.sh
```

## 📋 **Test Scripts Overview**

### **🔍 `test_gpu_detection.sh`**
**Mục đích:** Verify GPU detection và basic functionality

**Tests:**
- ✅ GPU detection với `nvidia-smi`
- ✅ CUDA environment setup
- ✅ Single vs Multi GPU calibration
- ✅ GPU memory usage monitoring
- ✅ System information display

**Usage:**
```bash
./test_gpu_detection.sh
```

**Expected Output:**
```
🔍 GPU Detection and Multi-GPU Test
===================================

1. Testing GPU Detection
✅ nvidia-smi available
Available GPUs:
GPU 0: NVIDIA GeForce RTX 3080 (UUID: GPU-xxx)
GPU 1: NVIDIA GeForce RTX 3080 (UUID: GPU-yyy)
Total GPUs detected: 2
✅ Multiple GPUs available for testing

📊 Performance Comparison:
Single GPU: 6283 PGUs/second
Multi GPU:  12566 PGUs/second  
Improvement: 2.00x
✅ Multi-GPU shows significant improvement!
```

### **⚡ `benchmark_multi_gpu.sh`**
**Mục đích:** Comprehensive performance benchmarking

**Features:**
- 🔬 Single GPU performance baseline
- 🔬 Dual GPU performance test
- 🔬 All GPU performance test (if >2 GPUs)
- 📊 Performance comparison report
- 🔥 Optional 5-minute stress test

**Usage:**
```bash
./benchmark_multi_gpu.sh
```

**Sample Results:**
```
⚡ Multi-GPU Performance Benchmark
=================================

🔬 Testing: Single GPU (GPU 0)
✅ Completed in 45s
   Throughput: 6283 PGUs/second
   Bid Price: 12.48 $PROVE per 1B PGUs

🔬 Testing: Dual GPU (GPU 0,1)  
✅ Completed in 25s
   Throughput: 12566 PGUs/second
   Bid Price: 6.24 $PROVE per 1B PGUs

🎯 Summary
Single GPU: 6283 PGUs/second
Dual GPU:   12566 PGUs/second
Performance Gain: 2.00x
✅ Multi-GPU sharding is working effectively!
```

### **🧪 `test_local_proving.sh`**
**Mục đích:** Full test suite với multiple scenarios

**Features:**
- 🔍 GPU detection và system info
- 📊 Calibration tests (single/multi GPU)
- 📝 Test program creation và building
- 🚀 Local proving tests
- ⚡ Performance benchmarks
- 💾 Memory usage monitoring

**Usage:**
```bash
./test_local_proving.sh
```

## 🎯 **Test Scenarios**

### **Scenario 1: Verify Multi-GPU Detection**
```bash
# Test if ShardingConfig correctly detects your 2x RTX 3080
export GPU_TYPE=rtx3080
./test_gpu_detection.sh
```

**Expected:** Should detect 2 GPUs và show `rtx3080_optimized()` config

### **Scenario 2: Performance Comparison**
```bash
# Compare single vs dual GPU performance
export CUDA_VISIBLE_DEVICES=0     # Single GPU
./target/release/spn-node calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08

export CUDA_VISIBLE_DEVICES=0,1   # Dual GPU  
./target/release/spn-node calibrate --usd-cost-per-hour 0.40 --utilization-rate 0.75 --profit-margin 0.15 --prove-price 0.08
```

**Expected:** Dual GPU should show ~2x improvement

### **Scenario 3: Stress Test**
```bash
# Run continuous calibration for reliability testing
./benchmark_multi_gpu.sh
# Choose 'y' when prompted for stress test
```

**Expected:** Should run stable for 5 minutes without crashes

### **Scenario 4: Memory Monitoring**
```bash
# Monitor GPU memory usage during operation
watch -n 1 nvidia-smi

# In another terminal
./benchmark_multi_gpu.sh
```

**Expected:** Should see memory usage on both GPUs during multi-GPU test

## 📊 **Expected Performance Results**

### **For 2x RTX 3080 Setup:**

| Configuration | Expected Throughput | Expected Improvement |
|---------------|-------------------|---------------------|
| Single RTX 3080 | ~6,000-8,000 PGUs/sec | Baseline |
| Dual RTX 3080 | ~12,000-16,000 PGUs/sec | ~2x |
| Optimized Dual | ~14,000-18,000 PGUs/sec | ~2.5x |

### **Performance Indicators:**

✅ **Good Performance:**
- Multi-GPU throughput > 1.8x single GPU
- GPU utilization > 80% on both GPUs
- Memory usage balanced across GPUs
- No significant temperature throttling

⚠️ **Potential Issues:**
- Multi-GPU improvement < 1.5x
- Uneven GPU utilization
- High memory usage (>90%)
- Temperature > 85°C

## 🔧 **Troubleshooting**

### **Issue: "No GPUs detected"**
```bash
# Check NVIDIA driver
nvidia-smi

# Check CUDA installation
ls /usr/local/cuda

# Verify environment
echo $CUDA_VISIBLE_DEVICES
echo $PATH | grep cuda
```

### **Issue: "Multi-GPU improvement is minimal"**
```bash
# Check if both GPUs are being used
nvidia-smi dmon -s u

# Verify CUDA_VISIBLE_DEVICES
export CUDA_VISIBLE_DEVICES=0,1
echo $CUDA_VISIBLE_DEVICES

# Check GPU memory usage
nvidia-smi --query-gpu=memory.used --format=csv
```

### **Issue: "Calibration fails or times out"**
```bash
# Increase timeout
timeout 180s ./target/release/spn-node calibrate ...

# Check logs for errors
tail -f ~/.sp1/logs/prover.log

# Verify SP1 installation
cargo prove --version
```

### **Issue: "Build failures"**
```bash
# Clean and rebuild
cargo clean
cargo build --release -p spn-node

# Check Rust toolchain
rustup show
```

## 📈 **Interpreting Results**

### **Calibration Output Explained:**
```
Detected 2 GPU(s) for proving (GPU_TYPE: rtx3080)
Using multi-GPU calibration with 2 GPUs

Calibration Results:
┌──────────────────────┬──────────────────────────┐
│ Metric               │ Value                    │
├──────────────────────┼──────────────────────────┤
│ Estimated Throughput │ 12283 PGUs/second        │  ← Total throughput
├──────────────────────┼──────────────────────────┤
│ Estimated Bid Price  │ 12.48 $PROVE per 1B PGUs │  ← Competitive bid price
└──────────────────────┴──────────────────────────┘
```

### **Key Metrics:**
- **Throughput:** Higher = better performance
- **Bid Price:** Lower = more competitive
- **GPU Utilization:** Should be >80% for both GPUs
- **Temperature:** Should be <85°C under load

## 🎯 **Success Criteria**

### **✅ Multi-GPU Implementation Working If:**
1. **Detection:** Correctly detects 2 GPUs
2. **Performance:** Multi-GPU shows >1.8x improvement
3. **Utilization:** Both GPUs show >80% utilization
4. **Stability:** Runs stable for >5 minutes
5. **Memory:** Balanced memory usage across GPUs

### **🚀 Ready for Production If:**
1. All success criteria met
2. Performance improvement >2x
3. No crashes during stress test
4. GPU temperatures stable <80°C
5. Consistent results across multiple runs

## 📝 **Test Logs Location**

```bash
# Test results
./test_results/
./benchmark_results/

# SP1 logs  
~/.sp1/logs/

# System logs
/var/log/nvidia/
```

## 🎉 **Next Steps After Testing**

1. **If tests pass:** Deploy to production server
2. **If performance good:** Join competitive proving network
3. **If issues found:** Debug using logs và monitoring
4. **Optimization:** Fine-tune sharding parameters

---

**Happy Testing! 🚀**

Với các test scripts này, bạn có thể verify toàn bộ multi-GPU implementation mà không cần network requests thực!
