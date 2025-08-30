# Competitive Prover for Succinct Prover Network

Hướng dẫn này giải thích cách sử dụng **ShardedProver** - một competitive prover với multi-GPU sharding để giảm latency cho proof lớn, theo đúng hướng dẫn của Succinct Labs.

## Tổng quan

**ShardedProver** là một competitive prover implementation theo hướng dẫn của Succinct Labs về **multi-GPU parallelization**:

> "Competitive provers regularly utilize 20-40 GPUs per proving request to maximize throughput. This requires:
> - Writing custom code to split proving work across multiple GPUs
> - Coordinating the RISC-V executor across the GPU cluster
> - Creating checkpoints of the virtual machine state
> - Distributing execution artifacts to different GPUs for parallel proving
> - Orchestrating the recursion prover to combine sharded proofs into a single final proof"
>
> — [Optimize Your Prover - Succinct Docs](https://docs.succinct.xyz/docs/provers/building-a-prover/performance-optimizations)

### Cách hoạt động:
- **Sharding**: Chia workload của 1 proof thành nhiều phần nhỏ (shards)
- **Multi-GPU Processing**: Mỗi shard được xử lý song song trên 1 GPU
- **Recursion**: Hợp nhất các proof nhỏ thành proof cuối cùng
- **Checkpointing**: Lưu trữ VM state để có thể resume/progress song song

## Yêu cầu hệ thống

### Phần cứng
- **GPU**: NVIDIA GPU với CUDA support (khuyến nghị 4+ GPU)
- **Memory**: Tối thiểu 4GB VRAM per GPU cho competitive proving
- **Driver**: NVIDIA driver version 555 trở lên

### Phần mềm
- **CUDA Runtime**: Version 11.0 trở lên
- **nvidia-smi**: Để monitor GPU
- **Rust**: Version 1.70 trở lên

## Cài đặt và cấu hình

### 1. Setup competitive prover

Chạy script setup để cấu hình competitive prover:

```bash
./competitive_setup.sh
```

Script này sẽ:
- Kiểm tra NVIDIA driver và CUDA support
- Phát hiện số lượng GPU có sẵn
- Kiểm tra memory requirements cho competitive proving
- Test GPU access cho sharding
- Tạo file cấu hình `competitive_config.env`

### 2. Sử dụng cấu hình

Source file cấu hình để set environment variables:

```bash
source competitive_config.env
```

### 3. Chạy competitive prover

```bash
# Build project
cargo build --release -p spn-node

# Run competitive prover với sharding
cargo run --bin spn-node prove \
  --rpc-url <your-rpc-url> \
  --throughput <your-throughput> \
  --bid <your-bid> \
  --private-key <your-private-key> \
  --prover <your-prover-address>
```

## Kiến trúc ShardedProver

### Sharding Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proof Request                            │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                Cycle Estimation                             │
│         (Estimate total cycles for proof)                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                Shard Creation                               │
│  (Split workload into N shards, N = GPUs × shards_per_gpu) │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Parallel Shard Processing                      │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Shard 0   │  │   Shard 1   │  │   Shard 2   │         │
│  │   → GPU 0   │  │   → GPU 0   │  │   → GPU 1   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Shard 3   │  │   Shard 4   │  │   Shard 5   │         │
│  │   → GPU 1   │  │   → GPU 2   │  │   → GPU 2   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                Recursion Prover                             │
│      (Combine shard results into final proof)              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Final Proof                              │
└─────────────────────────────────────────────────────────────┘
```

### Sharding Configuration

```rust
pub struct ShardingConfig {
    pub num_gpus: usize,                    // Số GPU sử dụng
    pub shards_per_gpu: usize,              // Số shard per GPU
    pub min_cycles_per_shard: u64,          // Min cycles per shard
    pub max_cycles_per_shard: u64,          // Max cycles per shard
    pub enable_checkpointing: bool,         // Enable checkpointing
    pub checkpoint_interval: u64,           // Checkpoint interval
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SPN_COMPETITIVE_MODE` | Enable competitive mode | true |
| `SPN_SHARDED_PROCESSING` | Enable sharded processing | true |
| `SPN_NUM_GPUS` | Number of GPUs to use | Auto-detected |
| `SPN_SHARDS_PER_GPU` | Shards per GPU | 2 |
| `SPN_MIN_CYCLES_PER_SHARD` | Min cycles per shard | 1,000,000 |
| `SPN_MAX_CYCLES_PER_SHARD` | Max cycles per shard | 10,000,000 |
| `SPN_ENABLE_CHECKPOINTING` | Enable checkpointing | true |
| `SPN_CHECKPOINT_INTERVAL` | Checkpoint interval | 1,000,000 |

## Monitoring và Debugging

### Monitor Sharding Performance

```bash
# Real-time GPU monitoring
watch -n 1 nvidia-smi

# Monitor sharding logs
tail -f logs/prover.log | grep "ShardedProver"
```

### Log Analysis

ShardedProver sẽ log các thông tin sau:

```
[ShardedProver] Detected 4 GPUs for sharded proving
[ShardedProver] Initialized ShardedProver with 4 GPUs, 2 shards per GPU
[ShardedProver] Created 8 shards for proof request
[ShardedProver] Processing shard 0 on GPU 0
[ShardedProver] Processing shard 1 on GPU 0
[ShardedProver] Processing shard 2 on GPU 1
[ShardedProver] Shard 0 completed on GPU 0
[ShardedProver] Combining 8 shard results into final proof
[ShardedProver] Sharded proof generation complete
```

### Performance Metrics

- **Total Shards**: Số shard được tạo cho mỗi proof
- **Shard Processing Time**: Thời gian xử lý từng shard
- **GPU Utilization**: % GPU usage per device
- **Recursion Time**: Thời gian hợp nhất shards
- **Total Latency**: Tổng thời gian từ start đến finish

## Troubleshooting

### Common Issues

#### 1. "Insufficient memory for competitive proving"
```bash
# Kiểm tra memory per GPU
nvidia-smi --query-gpu=memory.free --format=csv,noheader,nounits

# Giảm shards per GPU
export SPN_SHARDS_PER_GPU=1
```

#### 2. "Shard processing failed"
```bash
# Kiểm tra GPU access
CUDA_VISIBLE_DEVICES=0 nvidia-smi
CUDA_VISIBLE_DEVICES=1 nvidia-smi

# Kiểm tra logs
tail -f logs/prover.log | grep "Shard.*failed"
```

#### 3. "Recursion prover failed"
```bash
# Kiểm tra shard results
tail -f logs/prover.log | grep "Combining.*shard results"

# Enable debug logging
export RUST_LOG=debug
```

### Debug Mode

Enable debug logging:

```bash
export RUST_LOG=debug
cargo run --bin spn-node prove [options]
```

## Performance Optimization

### Best Practices

1. **Shard Size Optimization**
   - Điều chỉnh `SPN_MIN_CYCLES_PER_SHARD` và `SPN_MAX_CYCLES_PER_SHARD`
   - Cân bằng giữa shard size và GPU utilization

2. **GPU Configuration**
   - Sử dụng GPU có cùng model để đồng nhất performance
   - Monitor temperature và memory usage

3. **Checkpointing**
   - Enable checkpointing cho proof lớn
   - Điều chỉnh checkpoint interval

4. **Recursion Optimization**
   - Tối ưu recursion prover để giảm overhead
   - Monitor recursion time

### Expected Performance

Với competitive prover (sharded multi-GPU):

| GPU Count | Shards | Expected Latency Reduction | Processing Type |
|-----------|--------|---------------------------|-----------------|
| 1 GPU     | 2 shards | 1.5x faster | Sharded Single GPU |
| 2 GPUs    | 4 shards | 2.5x faster | Sharded Multi-GPU |
| 4 GPUs    | 8 shards | 4.0x faster | Sharded Multi-GPU |
| 8 GPUs    | 16 shards | 6.0x faster | Sharded Multi-GPU |

*Baseline = performance với 1 GPU, 1 shard*

## Migration từ SerialProver

### Automatic Migration

ShardedProver sẽ tự động thay thế SerialProver trong main.rs:

```rust
// Old code
let prover = SerialProver::new();

// New code (automatic)
let prover = ShardedProver::new();
```

### Manual Configuration

Nếu muốn cấu hình thủ công:

```rust
use spn_node_core::ShardedProver;

let prover = ShardedProver::new();
```

## Advanced Configuration

### Custom Sharding Configuration

```rust
use spn_node_core::{ShardedProver, ShardingConfig};

let config = ShardingConfig {
    num_gpus: 8,
    shards_per_gpu: 3,
    min_cycles_per_shard: 2_000_000,
    max_cycles_per_shard: 20_000_000,
    enable_checkpointing: true,
    checkpoint_interval: 2_000_000,
};

let prover = ShardedProver::with_config(config);
```

### Performance Tuning

```bash
# Tăng shards per GPU
export SPN_SHARDS_PER_GPU=4

# Tăng min cycles per shard
export SPN_MIN_CYCLES_PER_SHARD=2000000

# Enable aggressive checkpointing
export SPN_ENABLE_CHECKPOINTING=true
export SPN_CHECKPOINT_INTERVAL=500000
```

## Support và Feedback

Nếu gặp vấn đề hoặc có câu hỏi:

1. Kiểm tra logs với `RUST_LOG=debug`
2. Chạy `./competitive_setup.sh` để diagnose
3. Monitor GPU usage với `nvidia-smi`
4. Report issues với đầy đủ system information

## Tài liệu tham khảo

- [Optimize Your Prover - Succinct Docs](https://docs.succinct.xyz/docs/provers/building-a-prover/performance-optimizations)
- [Succinct Prover Network](https://docs.succinct.xyz/docs/provers/introduction)

## Changelog

### Version 1.0.0
- Initial competitive prover implementation
- Multi-GPU sharding support
- Recursion prover for combining shards
- Checkpointing for VM state management
- Performance monitoring and metrics
- Automatic GPU detection and configuration
