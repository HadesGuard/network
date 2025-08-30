# 🚀 ShardedProver Multi-GPU Setup

## ✅ One-Click Setup

Chỉ cần chạy một script duy nhất để setup tất cả:

```bash
./setup.sh
```

## 📋 What the script does

1. **Clean source code** - Xóa build artifacts cũ
2. **Install system dependencies** - Cài packages cần thiết
3. **Install Rust** - Cài Rust và components
4. **Install CUDA 12.5+** - Cài CUDA toolkit
5. **Fix Cargo config** - Optimize Cargo configuration
6. **Increase system limits** - Tăng file descriptors
7. **Build ShardedProver** - Build binary optimized
8. **Test binary** - Verify binary hoạt động
9. **Create deployment scripts** - Tạo scripts deploy

## 🎯 Supported GPU Types

- **RTX 4090**: 24GB VRAM, 6 shards per GPU
- **RTX 4080**: 16GB VRAM, 4 shards per GPU
- **RTX 3090**: 24GB VRAM, 6 shards per GPU
- **RTX 3080**: 10GB VRAM, 3 shards per GPU
- **A100**: 40GB VRAM, 8 shards per GPU
- **Auto-detect**: Tự động detect GPU type

## 🚀 Quick Commands

```bash
# Complete setup
./setup.sh

# Clean only
./setup.sh clean

# Install dependencies only
./setup.sh deps

# Build only
./setup.sh build

# Help
./setup.sh help
```

## 📦 After Setup

Script sẽ tạo:
- `target/release/spn-node` - Binary đã build
- `deploy.sh` - Script deploy lên server
- `test.sh` - Script test trên server

## 🎯 Usage

```bash
# Deploy to server
./deploy.sh <server-ip>

# Test on server
./test.sh <server-ip>

# Run with specific GPU
export GPU_TYPE=rtx4090
./spn-node prove --rpc-url https://rpc.succinct.xyz --private-key YOUR_PRIVATE_KEY --throughput 1000000 --bid 1000000000000000000 --prover YOUR_PROVER_ADDRESS
```

## 🎉 That's it!

Chỉ cần chạy `./setup.sh` và mọi thứ sẽ được setup tự động!
