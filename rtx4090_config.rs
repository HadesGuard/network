// RTX 4090 specific configuration for competitive proving
// This file contains optimizations specifically for RTX 4090 multi-GPU setups

use std::collections::HashMap;

/// RTX 4090 specific configuration
#[derive(Debug, Clone)]
pub struct RTX4090Config {
    /// Number of RTX 4090 GPUs
    pub num_gpus: usize,
    
    /// Shards per RTX 4090 (24GB VRAM allows more shards)
    pub shards_per_gpu: usize,
    
    /// Memory allocation per shard (in MB)
    pub memory_per_shard_mb: u64,
    
    /// Maximum concurrent shards per GPU
    pub max_concurrent_shards: usize,
    
    /// RTX 4090 specific performance settings
    pub performance_settings: RTX4090PerformanceSettings,
    
    /// Memory management settings
    pub memory_settings: RTX4090MemorySettings,
}

/// RTX 4090 performance optimization settings
#[derive(Debug, Clone)]
pub struct RTX4090PerformanceSettings {
    /// Enable CUDA graph capture for better performance
    pub enable_graph_capture: bool,
    
    /// Maximum number of CUDA connections per device
    pub max_connections_per_device: u32,
    
    /// Enable unified memory for better memory management
    pub enable_unified_memory: bool,
    
    /// Memory fraction to use (0.0 - 1.0)
    pub memory_fraction: f32,
    
    /// Enable memory growth
    pub enable_memory_growth: bool,
    
    /// Enable peer memory access between GPUs
    pub enable_peer_memory: bool,
}

/// RTX 4090 memory management settings
#[derive(Debug, Clone)]
pub struct RTX4090MemorySettings {
    /// Total VRAM per RTX 4090 (24GB)
    pub total_vram_gb: u32,
    
    /// Reserved VRAM for system (in GB)
    pub reserved_vram_gb: u32,
    
    /// Available VRAM for proving (in GB)
    pub available_vram_gb: u32,
    
    /// Memory allocation strategy
    pub allocation_strategy: MemoryAllocationStrategy,
}

/// Memory allocation strategy for RTX 4090
#[derive(Debug, Clone)]
pub enum MemoryAllocationStrategy {
    /// Allocate memory per shard
    PerShard,
    
    /// Allocate memory per GPU
    PerGPU,
    
    /// Dynamic allocation based on workload
    Dynamic,
}

impl Default for RTX4090Config {
    fn default() -> Self {
        Self {
            num_gpus: 4,
            shards_per_gpu: 4, // RTX 4090 can handle 4 shards with 24GB VRAM
            memory_per_shard_mb: 5120, // 5GB per shard (24GB / 4 shards = 6GB, reserve 1GB)
            max_concurrent_shards: 4,
            performance_settings: RTX4090PerformanceSettings::default(),
            memory_settings: RTX4090MemorySettings::default(),
        }
    }
}

impl Default for RTX4090PerformanceSettings {
    fn default() -> Self {
        Self {
            enable_graph_capture: true,
            max_connections_per_device: 32, // RTX 4090 supports more connections
            enable_unified_memory: true,
            memory_fraction: 0.95, // Use 95% of available VRAM
            enable_memory_growth: true,
            enable_peer_memory: true,
        }
    }
}

impl Default for RTX4090MemorySettings {
    fn default() -> Self {
        Self {
            total_vram_gb: 24,
            reserved_vram_gb: 2, // Reserve 2GB for system
            available_vram_gb: 22, // 22GB available for proving
            allocation_strategy: MemoryAllocationStrategy::Dynamic,
        }
    }
}

impl RTX4090Config {
    /// Create configuration for specific number of RTX 4090 GPUs
    pub fn for_gpu_count(num_gpus: usize) -> Self {
        let mut config = Self::default();
        config.num_gpus = num_gpus;
        
        // Adjust shards per GPU based on number of GPUs
        config.shards_per_gpu = match num_gpus {
            1 => 6,  // Single RTX 4090: 6 shards
            2 => 4,  // Dual RTX 4090: 4 shards each
            3 => 3,  // Triple RTX 4090: 3 shards each
            4 => 3,  // Quad RTX 4090: 3 shards each
            _ => 2,  // 5+ RTX 4090: 2 shards each
        };
        
        // Adjust memory per shard
        config.memory_per_shard_mb = config.memory_settings.available_vram_gb as u64 * 1024 / config.shards_per_gpu as u64;
        
        config
    }
    
    /// Get total number of shards
    pub fn total_shards(&self) -> usize {
        self.num_gpus * self.shards_per_gpu
    }
    
    /// Get total available memory (in MB)
    pub fn total_available_memory_mb(&self) -> u64 {
        self.num_gpus as u64 * self.memory_settings.available_vram_gb as u64 * 1024
    }
    
    /// Get memory per shard (in MB)
    pub fn memory_per_shard_mb(&self) -> u64 {
        self.memory_per_shard_mb
    }
    
    /// Check if configuration is valid for RTX 4090
    pub fn is_valid(&self) -> bool {
        self.num_gpus > 0 
            && self.shards_per_gpu > 0 
            && self.memory_per_shard_mb > 0
            && self.total_shards() <= 32 // Reasonable limit
    }
    
    /// Get environment variables for RTX 4090 optimization
    pub fn get_environment_variables(&self) -> HashMap<String, String> {
        let mut env_vars = HashMap::new();
        
        // CUDA settings
        env_vars.insert("CUDA_LAUNCH_BLOCKING".to_string(), "0".to_string());
        env_vars.insert("CUDA_CACHE_DISABLE".to_string(), "0".to_string());
        env_vars.insert("CUDA_MEMORY_POOL_SIZE".to_string(), "0".to_string());
        env_vars.insert("CUDA_UNIFIED_MEMORY".to_string(), 
            if self.performance_settings.enable_unified_memory { "1" } else { "0" }.to_string());
        env_vars.insert("CUDA_PEER_MEMORY_POOL_SIZE".to_string(), "0".to_string());
        
        // RTX 4090 specific optimizations
        env_vars.insert("CUDA_DEVICE_MAX_CONNECTIONS".to_string(), 
            self.performance_settings.max_connections_per_device.to_string());
        env_vars.insert("CUDA_GRAPH_CAPTURE_MODE".to_string(), 
            if self.performance_settings.enable_graph_capture { "1" } else { "0" }.to_string());
        
        // Memory management
        env_vars.insert("CUDA_MEMORY_FRACTION".to_string(), 
            self.performance_settings.memory_fraction.to_string());
        env_vars.insert("CUDA_MEMORY_GROWTH".to_string(), 
            if self.performance_settings.enable_memory_growth { "1" } else { "0" }.to_string());
        
        // RTX 4090 specific settings
        env_vars.insert("SPN_RTX4090_MODE".to_string(), "1".to_string());
        env_vars.insert("SPN_RTX4090_SHARDS_PER_GPU".to_string(), self.shards_per_gpu.to_string());
        env_vars.insert("SPN_RTX4090_MEMORY_PER_SHARD_MB".to_string(), self.memory_per_shard_mb.to_string());
        
        env_vars
    }
    
    /// Apply environment variables to current process
    pub fn apply_environment(&self) {
        for (key, value) in self.get_environment_variables() {
            std::env::set_var(key, value);
        }
    }
    
    /// Get performance metrics for RTX 4090 setup
    pub fn get_performance_metrics(&self) -> RTX4090PerformanceMetrics {
        RTX4090PerformanceMetrics {
            total_gpus: self.num_gpus,
            total_shards: self.total_shards(),
            total_memory_gb: self.total_available_memory_mb() as f32 / 1024.0,
            memory_per_shard_gb: self.memory_per_shard_mb as f32 / 1024.0,
            estimated_throughput_multiplier: self.estimated_throughput_multiplier(),
            estimated_latency_reduction: self.estimated_latency_reduction(),
        }
    }
    
    /// Estimate throughput multiplier compared to single GPU
    fn estimated_throughput_multiplier(&self) -> f32 {
        // RTX 4090 has excellent scaling
        let base_multiplier = self.num_gpus as f32;
        let sharding_efficiency = 0.85; // 85% efficiency due to sharding overhead
        let rtx4090_efficiency = 1.2; // RTX 4090 is 20% more efficient than reference
        
        base_multiplier * sharding_efficiency * rtx4090_efficiency
    }
    
    /// Estimate latency reduction compared to single GPU
    fn estimated_latency_reduction(&self) -> f32 {
        // Latency reduction is more dramatic with RTX 4090
        let base_reduction = self.num_gpus as f32;
        let rtx4090_advantage = 1.3; // RTX 4090 provides 30% better latency reduction
        
        1.0 / (base_reduction * rtx4090_advantage)
    }
}

/// Performance metrics for RTX 4090 setup
#[derive(Debug, Clone)]
pub struct RTX4090PerformanceMetrics {
    pub total_gpus: usize,
    pub total_shards: usize,
    pub total_memory_gb: f32,
    pub memory_per_shard_gb: f32,
    pub estimated_throughput_multiplier: f32,
    pub estimated_latency_reduction: f32,
}

impl RTX4090PerformanceMetrics {
    /// Display performance metrics in a human-readable format
    pub fn display(&self) {
        println!("=== RTX 4090 Performance Metrics ===");
        println!("Total GPUs: {}", self.total_gpus);
        println!("Total Shards: {}", self.total_shards);
        println!("Total Memory: {:.1} GB", self.total_memory_gb);
        println!("Memory per Shard: {:.1} GB", self.memory_per_shard_gb);
        println!("Estimated Throughput: {:.1}x faster", self.estimated_throughput_multiplier);
        println!("Estimated Latency: {:.1}x faster", 1.0 / self.estimated_latency_reduction);
        println!("=====================================");
    }
}

/// RTX 4090 specific utilities
pub mod utils {
    use super::*;
    
    /// Detect RTX 4090 GPUs and create optimal configuration
    pub fn detect_rtx4090_setup() -> Option<RTX4090Config> {
        // This would integrate with nvidia-smi to detect RTX 4090s
        // For now, return a default configuration
        Some(RTX4090Config::default())
    }
    
    /// Validate RTX 4090 setup
    pub fn validate_rtx4090_setup(config: &RTX4090Config) -> Result<(), String> {
        if !config.is_valid() {
            return Err("Invalid RTX 4090 configuration".to_string());
        }
        
        // Check if we have enough memory
        let required_memory_mb = config.total_shards() as u64 * config.memory_per_shard_mb;
        let available_memory_mb = config.total_available_memory_mb();
        
        if required_memory_mb > available_memory_mb {
            return Err(format!(
                "Insufficient memory: need {} MB, have {} MB",
                required_memory_mb, available_memory_mb
            ));
        }
        
        Ok(())
    }
    
    /// Get recommended configuration for proof size
    pub fn get_recommended_config_for_proof_size(proof_size_mb: u64) -> RTX4090Config {
        match proof_size_mb {
            0..=100 => RTX4090Config::for_gpu_count(1),   // Small proof: 1 RTX 4090
            101..=500 => RTX4090Config::for_gpu_count(2), // Medium proof: 2 RTX 4090
            501..=1000 => RTX4090Config::for_gpu_count(3), // Large proof: 3 RTX 4090
            _ => RTX4090Config::for_gpu_count(4),         // Very large proof: 4 RTX 4090
        }
    }
}
