# Quick Start Guide for 8x RTX 4090 Competitive Prover

Hướng dẫn nhanh để start và test competitive prover trên server 8x RTX 4090.

## Prerequisites

### Server Requirements
- ✅ 8x RTX 4090 GPUs
- ✅ NVIDIA drivers 555+
- ✅ CUDA runtime 11.0+
- ✅ Rust/Cargo installed
- ✅ SSH access configured

### Code Requirements
- ✅ Competitive prover code deployed
- ✅ 8x RTX 4090 configuration ready
- ✅ Private key và prover address

## Quick Start

### Step 1: Configure Parameters

Edit `start_8x_rtx4090.sh`:

```bash
# Configuration - MODIFY THESE FOR YOUR SETUP
RPC_URL="https://rpc.succinct.xyz"
THROUGHPUT="1000000"
BID="1000000000000000000"
PRIVATE_KEY="your-private-key"  # ← Change this
PROVER_ADDRESS="your-prover-address"  # ← Change this
```

### Step 2: Start Competitive Prover

```bash
# Start competitive prover with monitoring
./start_8x_rtx4090.sh start
```

Script này sẽ:
- ✅ Check 8x RTX 4090 setup
- ✅ Verify competitive prover build
- ✅ Start competitive prover
- ✅ Monitor performance real-time

### Step 3: Monitor Performance

```bash
# Monitor performance separately (optional)
./monitor_8x_rtx4090.sh monitor
```

## Alternative Commands

### Start Only (No Monitoring)
```bash
# Start competitive prover in background
./start_8x_rtx4090.sh start &
```

### Check Status
```bash
# Check current status
./start_8x_rtx4090.sh status
./monitor_8x_rtx4090.sh status
```

### View Logs
```bash
# View recent logs
./start_8x_rtx4090.sh logs
./monitor_8x_rtx4090.sh logs
```

### Stop Prover
```bash
# Stop competitive prover
./start_8x_rtx4090.sh stop
```

## Expected Performance

### 8x RTX 4090 Setup
```
Total GPUs: 8
Total Memory: 192GB
Total Shards: 32 (4 per GPU)
Memory per Shard: 6GB
Expected Latency Reduction: 12.0x
Expected Throughput: 9.6x
Competitive Advantage: MAXIMUM
```

### Real-time Monitoring
```
GPU Status: Individual GPU utilization, memory, temperature
Prover Status: Process status, CPU usage, runtime
Performance Metrics: Overall memory usage, average utilization
Alerts: High temperature, low utilization, memory issues
```

## Performance Indicators

### Good Performance
- ✅ GPU utilization > 80%
- ✅ Memory usage > 70%
- ✅ Temperature < 80°C
- ✅ Competitive prover running
- ✅ Sharding logs visible

### Issues to Watch
- ⚠️ GPU utilization < 20% (underutilized)
- ⚠️ Memory usage > 95% (memory pressure)
- ⚠️ Temperature > 80°C (thermal throttling)
- ⚠️ Competitive prover not running
- ⚠️ Error logs in output

## Troubleshooting

### Common Issues

#### 1. "Competitive prover not running"
```bash
# Check if process exists
ps aux | grep spn-node

# Check logs for errors
tail -20 logs/competitive_prover.log

# Restart prover
./start_8x_rtx4090.sh stop
./start_8x_rtx4090.sh start
```

#### 2. "Low GPU utilization"
```bash
# Check if proof requests are being received
tail -f logs/competitive_prover.log | grep "request"

# Check network connectivity
curl -s https://rpc.succinct.xyz

# Verify prover address and private key
```

#### 3. "High temperature"
```bash
# Check GPU temperature
nvidia-smi --query-gpu=temperature.gpu --format=csv

# Reduce shards per GPU if needed
export SPN_SHARDS_PER_GPU=3
```

#### 4. "Memory issues"
```bash
# Check memory usage
nvidia-smi --query-gpu=memory.used,memory.free --format=csv

# Reduce memory per shard if needed
export SPN_MEMORY_PER_SHARD_MB=4096
```

## Monitoring Commands

### Real-time GPU Monitoring
```bash
# Basic GPU monitoring
watch -n 1 nvidia-smi

# Detailed GPU monitoring
nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu,temperature.gpu,power.draw --format=csv,noheader,nounits
```

### Log Monitoring
```bash
# Follow competitive prover logs
tail -f logs/competitive_prover.log

# Search for specific patterns
grep "ShardedProver" logs/competitive_prover.log
grep "RTX4090" logs/competitive_prover.log
grep "ERROR" logs/competitive_prover.log
```

### Performance History
```bash
# View performance trends
./monitor_8x_rtx4090.sh trends

# Check performance history
tail -20 logs/performance_history.log
```

## Optimization Tips

### Environment Variables
```bash
# RTX 4090 specific optimizations
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
export CUDA_UNIFIED_MEMORY=1

# Competitive prover settings
export SPN_RTX4090_MODE=true
export SPN_SHARDED_PROCESSING=true
export SPN_SHARDS_PER_GPU=4
export SPN_OPTIMAL_SHARDING=true
```

### Performance Tuning
```bash
# Increase shards per GPU (if memory allows)
export SPN_SHARDS_PER_GPU=5

# Increase memory per shard (if needed)
export SPN_MEMORY_PER_SHARD_MB=6144

# Enable aggressive checkpointing
export SPN_ENABLE_CHECKPOINTING=true
export SPN_CHECKPOINT_INTERVAL=1000000
```

## Success Indicators

### When Everything is Working
- ✅ All 8 GPUs showing utilization > 80%
- ✅ Memory usage > 70% across all GPUs
- ✅ Competitive prover logs showing sharding activity
- ✅ No error messages in logs
- ✅ Temperature < 80°C on all GPUs
- ✅ Proof requests being processed

### Performance Metrics
- ✅ Latency reduction: 10-12x faster than single GPU
- ✅ Throughput: 8-10x higher than single GPU
- ✅ Memory efficiency: > 90% utilization
- ✅ GPU efficiency: > 85% utilization

## Next Steps

### After Successful Start
1. **Monitor performance** for 1-2 hours
2. **Check proof completion** rates
3. **Verify competitive advantage** on network
4. **Optimize parameters** based on performance
5. **Scale up** if needed

### Long-term Monitoring
1. **Set up automated monitoring**
2. **Track performance trends**
3. **Monitor network competition**
4. **Optimize for different proof sizes**
5. **Plan for scaling**

## Support

### Logs Location
- Competitive prover logs: `logs/competitive_prover.log`
- Performance history: `logs/performance_history.log`
- PID file: `logs/competitive_prover.pid`

### Key Commands
```bash
# Start competitive prover
./start_8x_rtx4090.sh start

# Monitor performance
./monitor_8x_rtx4090.sh monitor

# Check status
./start_8x_rtx4090.sh status

# View logs
./start_8x_rtx4090.sh logs

# Stop prover
./start_8x_rtx4090.sh stop
```

### Emergency Stop
```bash
# Force stop all prover processes
pkill -9 -f spn-node

# Clear PID file
rm -f logs/competitive_prover.pid
```

**Bây giờ bạn có thể start competitive prover trên 8x RTX 4090 và monitor performance real-time!** 🚀
