# RTX 4090 Multi-GPU Competitive Prover

Hướng dẫn tối ưu **ShardedProver** cho **RTX 4090 multi-GPU** để đạt hiệu suất tối đa cho competitive proving.

## Tổng quan RTX 4090

**RTX 4090** là GPU mạnh nhất cho competitive proving với:

- **24GB VRAM** (lớn nhất trong consumer GPU)
- **1008 GB/s memory bandwidth** (cao nhất)
- **Advanced CUDA features** (graph capture, unified memory)
- **Excellent scaling** cho multi-GPU setups

### RTX 4090 vs Other GPUs

| GPU | VRAM | Bandwidth | Shards/GPU | Performance |
|-----|------|-----------|------------|-------------|
| RTX 3080 | 10GB | 760 GB/s | 2 | Baseline |
| RTX 3090 | 24GB | 936 GB/s | 3 | 1.2x |
| RTX 4090 | 24GB | 1008 GB/s | 4 | 1.5x |

## Cài đặt RTX 4090 Optimization

### 1. Setup RTX 4090 specific

```bash
./rtx4090_setup.sh
```

Script này sẽ:
- Kiểm tra RTX 4090 specific requirements
- Phát hiện RTX 4090 GPUs
- Tối ưu memory management cho 24GB VRAM
- Cấu hình CUDA graph capture
- Tạo `rtx4090_config.env`

### 2. Sử dụng RTX 4090 configuration

```bash
source rtx4090_config.env
```

### 3. Chạy RTX 4090 optimized prover

```bash
cargo run --bin spn-node prove [options]
```

## RTX 4090 Performance Expectations

### Single RTX 4090 (24GB VRAM)
```
Shards: 6 (6 per GPU)
Memory per Shard: 4GB
Expected Latency Reduction: 1.5x
Expected Throughput: 1.2x
```

### Dual RTX 4090 (48GB VRAM)
```
Shards: 8 (4 per GPU)
Memory per Shard: 5.5GB
Expected Latency Reduction: 3.0x
Expected Throughput: 2.4x
```

### Triple RTX 4090 (72GB VRAM)
```
Shards: 9 (3 per GPU)
Memory per Shard: 7.3GB
Expected Latency Reduction: 4.5x
Expected Throughput: 3.6x
```

### Quad RTX 4090 (96GB VRAM)
```
Shards: 12 (3 per GPU)
Memory per Shard: 7.3GB
Expected Latency Reduction: 6.0x
Expected Throughput: 4.8x
```

## RTX 4090 Specific Optimizations

### 1. Memory Management (24GB VRAM)

```rust
// RTX 4090 specific memory allocation
pub struct RTX4090MemorySettings {
    pub total_vram_gb: u32,        // 24GB
    pub reserved_vram_gb: u32,     // 2GB for system
    pub available_vram_gb: u32,    // 22GB for proving
    pub allocation_strategy: MemoryAllocationStrategy,
}
```

### 2. Sharding Configuration

```rust
// RTX 4090 optimized sharding
impl Default for ShardingConfig {
    fn default() -> Self {
        Self {
            num_gpus: 4,
            shards_per_gpu: 4,              // RTX 4090 can handle 4 shards
            min_cycles_per_shard: 2_000_000, // 2M cycles (tăng vì 4090 mạnh hơn)
            max_cycles_per_shard: 20_000_000, // 20M cycles (tăng vì 4090 mạnh hơn)
            enable_checkpointing: true,
            checkpoint_interval: 2_000_000,   // 2M cycles
        }
    }
}
```

### 3. CUDA Optimizations

```bash
# RTX 4090 specific environment variables
export CUDA_DEVICE_MAX_CONNECTIONS=32      # RTX 4090 supports more connections
export CUDA_GRAPH_CAPTURE_MODE=1           # Enable graph capture
export CUDA_MEMORY_FRACTION=0.95           # Use 95% of 24GB VRAM
export CUDA_MEMORY_GROWTH=1                # Allow memory growth
export CUDA_UNIFIED_MEMORY=1               # Enable unified memory
```

## RTX 4090 Configuration File

### rtx4090_config.env

```bash
# RTX 4090 Multi-GPU Configuration
GPU_COUNT=4
CUDA_DEVICES=0,1,2,3

# RTX 4090 specific optimizations
export SPN_RTX4090_MODE=true
export SPN_SHARDS_PER_GPU=4
export SPN_TOTAL_SHARDS=16
export SPN_MEMORY_PER_SHARD_MB=5120

# RTX 4090 performance tuning
export CUDA_DEVICE_MAX_CONNECTIONS=32
export CUDA_GRAPH_CAPTURE_MODE=1
export CUDA_MEMORY_FRACTION=0.95
export CUDA_MEMORY_GROWTH=1
```

## RTX 4090 Performance Monitoring

### Monitor RTX 4090 Performance

```bash
# Real-time RTX 4090 monitoring
watch -n 1 nvidia-smi

# Monitor RTX 4090 specific logs
tail -f logs/prover.log | grep "RTX4090"

# Check RTX 4090 memory usage
nvidia-smi --query-gpu=memory.used,memory.free --format=csv
```

### RTX 4090 Performance Metrics

```rust
pub struct RTX4090PerformanceMetrics {
    pub total_gpus: usize,
    pub total_shards: usize,
    pub total_memory_gb: f32,
    pub memory_per_shard_gb: f32,
    pub estimated_throughput_multiplier: f32,
    pub estimated_latency_reduction: f32,
}
```

## RTX 4090 Troubleshooting

### Common RTX 4090 Issues

#### 1. "Insufficient memory for RTX 4090 competitive proving"
```bash
# Kiểm tra RTX 4090 memory
nvidia-smi --query-gpu=name,memory.free --format=csv

# Giảm shards per GPU nếu cần
export SPN_SHARDS_PER_GPU=3
```

#### 2. "RTX 4090 graph capture failed"
```bash
# Disable graph capture nếu có vấn đề
export CUDA_GRAPH_CAPTURE_MODE=0

# Kiểm tra CUDA version
nvcc --version
```

#### 3. "RTX 4090 unified memory error"
```bash
# Disable unified memory nếu có vấn đề
export CUDA_UNIFIED_MEMORY=0

# Kiểm tra driver version
nvidia-smi --query-gpu=driver_version --format=csv
```

### RTX 4090 Debug Mode

```bash
# Enable RTX 4090 debug logging
export RUST_LOG=debug
export SPN_RTX4090_DEBUG=true

cargo run --bin spn-node prove [options]
```

## RTX 4090 Best Practices

### 1. Memory Management
- Sử dụng 95% VRAM (22.8GB của 24GB)
- Reserve 2GB cho system operations
- Monitor memory usage với `nvidia-smi`

### 2. Sharding Strategy
- 4 shards per RTX 4090 (optimal)
- 5GB memory per shard
- Dynamic allocation based on workload

### 3. Performance Tuning
- Enable CUDA graph capture
- Use unified memory for multi-GPU
- Monitor temperature (RTX 4090 có thể nóng)

### 4. Scaling Strategy
- Linear scaling với số lượng RTX 4090
- Peer memory access giữa GPUs
- Load balancing across shards

## RTX 4090 vs Other Competitive Setups

### RTX 4090 vs RTX 3090
```
RTX 3090: 24GB VRAM, 936 GB/s bandwidth
RTX 4090: 24GB VRAM, 1008 GB/s bandwidth (+7.7%)

RTX 4090 advantage: Better bandwidth, newer CUDA features
```

### RTX 4090 vs RTX 3080
```
RTX 3080: 10GB VRAM, 760 GB/s bandwidth
RTX 4090: 24GB VRAM, 1008 GB/s bandwidth (+32.6%)

RTX 4090 advantage: 2.4x more VRAM, 32.6% more bandwidth
```

### RTX 4090 vs A100 (Data Center)
```
A100: 40GB VRAM, 1555 GB/s bandwidth
RTX 4090: 24GB VRAM, 1008 GB/s bandwidth

A100 advantage: More VRAM, higher bandwidth
RTX 4090 advantage: Cost-effective, consumer-grade
```

## RTX 4090 Cost Analysis

### Setup Costs
```
1x RTX 4090: $1,600
2x RTX 4090: $3,200
3x RTX 4090: $4,800
4x RTX 4090: $6,400
```

### Performance per Dollar
```
RTX 4090: 24GB VRAM / $1,600 = 15MB/$
RTX 3090: 24GB VRAM / $1,500 = 16MB/$
RTX 3080: 10GB VRAM / $700 = 14.3MB/$
```

## RTX 4090 Future Considerations

### Next-Gen RTX 5000 Series
- Expected 2024-2025
- Potential 32GB+ VRAM
- Higher memory bandwidth
- Better CUDA features

### RTX 4090 Longevity
- 24GB VRAM sufficient for 2-3 years
- Excellent for competitive proving
- Good investment for multi-GPU setups

## Support và Resources

### RTX 4090 Documentation
- [NVIDIA RTX 4090 Specifications](https://www.nvidia.com/en-us/geforce/graphics-cards/40-series/rtx-4090/)
- [CUDA Programming Guide](https://docs.nvidia.com/cuda/)
- [NVIDIA Driver Downloads](https://www.nvidia.com/Download/index.aspx)

### Community Resources
- [NVIDIA Developer Forums](https://forums.developer.nvidia.com/)
- [CUDA Programming Community](https://stackoverflow.com/questions/tagged/cuda)

### Performance Benchmarks
- Monitor performance với `nvidia-smi`
- Track sharding efficiency
- Compare với baseline performance

## Changelog

### Version 1.0.0 (RTX 4090 Optimization)
- RTX 4090 specific memory management
- Optimized sharding for 24GB VRAM
- CUDA graph capture support
- Unified memory optimization
- Performance monitoring và metrics
- RTX 4090 specific configuration
- Multi-GPU coordination improvements
