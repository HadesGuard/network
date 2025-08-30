use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};
use tokio::sync::Mutex;
use tracing::{info, warn, error};
use anyhow::{Result, anyhow};
use serde::{Serialize, Deserialize};

/// Comprehensive monitoring system for competitive proving
#[derive(Debug)]
pub struct ProverMonitor {
    metrics: Arc<Mutex<ProverMetrics>>,
    alerts: Arc<Mutex<Vec<Alert>>>,
    start_time: Instant,
}

/// Detailed metrics for prover performance
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProverMetrics {
    // Performance metrics
    pub total_proofs_completed: u64,
    pub total_proofs_failed: u64,
    pub average_proof_time: Duration,
    pub fastest_proof_time: Duration,
    pub slowest_proof_time: Duration,
    
    // GPU metrics per device
    pub gpu_metrics: HashMap<usize, GpuMetrics>,
    
    // Network metrics
    pub network_latency: Duration,
    pub requests_received: u64,
    pub requests_missed: u64,
    pub deadline_misses: u64,
    
    // Resource utilization
    pub cpu_usage: f64,
    pub memory_usage: u64,
    pub memory_total: u64,
    
    // Economic metrics
    pub total_earnings: f64,
    pub average_bid_price: f64,
    pub profit_margin: f64,
    
    // Reliability metrics
    pub uptime_percentage: f64,
    pub error_rate: f64,
    pub success_rate: f64,
    
    // Competitive metrics
    pub market_share: f64,
    pub ranking: u32,
    pub throughput_vs_network: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuMetrics {
    pub device_id: usize,
    pub name: String,
    pub utilization: f64,
    pub memory_used: u64,
    pub memory_total: u64,
    pub temperature: f64,
    pub power_usage: f64,
    pub clock_speed: u32,
    pub memory_clock: u32,
    pub proofs_processed: u64,
    pub average_processing_time: Duration,
    pub error_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Alert {
    pub timestamp: SystemTime,
    pub level: AlertLevel,
    pub category: AlertCategory,
    pub message: String,
    pub device_id: Option<usize>,
    pub acknowledged: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AlertLevel {
    Info,
    Warning,
    Critical,
    Emergency,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AlertCategory {
    Performance,
    Hardware,
    Network,
    Economic,
    Reliability,
}

impl ProverMonitor {
    /// Create new prover monitor
    pub fn new() -> Self {
        const MONITOR_TAG: &str = "\x1b[34m[Monitor]\x1b[0m";
        
        info!("{MONITOR_TAG} Initializing prover monitoring system");
        
        Self {
            metrics: Arc::new(Mutex::new(ProverMetrics::default())),
            alerts: Arc::new(Mutex::new(Vec::new())),
            start_time: Instant::now(),
        }
    }
    
    /// Start monitoring loop
    pub async fn start_monitoring(&self) -> Result<()> {
        const MONITOR_TAG: &str = "\x1b[34m[Monitor]\x1b[0m";
        
        info!("{MONITOR_TAG} Starting monitoring loop");
        
        let metrics = self.metrics.clone();
        let alerts = self.alerts.clone();
        let start_time = self.start_time;
        
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(Duration::from_secs(10));
            
            loop {
                interval.tick().await;
                
                // Update system metrics
                if let Err(e) = Self::update_system_metrics(&metrics, start_time).await {
                    error!("{MONITOR_TAG} Failed to update system metrics: {}", e);
                }
                
                // Update GPU metrics
                if let Err(e) = Self::update_gpu_metrics(&metrics).await {
                    error!("{MONITOR_TAG} Failed to update GPU metrics: {}", e);
                }
                
                // Check for alerts
                if let Err(e) = Self::check_alerts(&metrics, &alerts).await {
                    error!("{MONITOR_TAG} Failed to check alerts: {}", e);
                }
                
                // Log periodic status
                if let Err(e) = Self::log_status(&metrics).await {
                    error!("{MONITOR_TAG} Failed to log status: {}", e);
                }
            }
        });
        
        Ok(())
    }
    
    /// Update system-level metrics
    async fn update_system_metrics(
        metrics: &Arc<Mutex<ProverMetrics>>,
        start_time: Instant,
    ) -> Result<()> {
        let mut m = metrics.lock().await;
        
        // Update uptime
        let uptime = start_time.elapsed();
        m.uptime_percentage = 99.9; // Simplified calculation
        
        // Update CPU and memory usage
        m.cpu_usage = Self::get_cpu_usage().await?;
        let (memory_used, memory_total) = Self::get_memory_usage().await?;
        m.memory_usage = memory_used;
        m.memory_total = memory_total;
        
        // Update success rate
        let total_attempts = m.total_proofs_completed + m.total_proofs_failed;
        if total_attempts > 0 {
            m.success_rate = (m.total_proofs_completed as f64 / total_attempts as f64) * 100.0;
            m.error_rate = (m.total_proofs_failed as f64 / total_attempts as f64) * 100.0;
        }
        
        Ok(())
    }
    
    /// Update GPU metrics for all devices
    async fn update_gpu_metrics(metrics: &Arc<Mutex<ProverMetrics>>) -> Result<()> {
        let mut m = metrics.lock().await;
        
        // Update metrics for each GPU
        for device_id in 0..2 { // Assuming 2 GPUs
            let gpu_metrics = GpuMetrics {
                device_id,
                name: format!("RTX 3080 #{}", device_id),
                utilization: Self::get_gpu_utilization(device_id).await?,
                memory_used: Self::get_gpu_memory_used(device_id).await?,
                memory_total: 10 * 1024 * 1024 * 1024, // 10GB
                temperature: Self::get_gpu_temperature(device_id).await?,
                power_usage: Self::get_gpu_power(device_id).await?,
                clock_speed: 1800, // MHz
                memory_clock: 9500, // MHz
                proofs_processed: m.gpu_metrics.get(&device_id)
                    .map(|g| g.proofs_processed)
                    .unwrap_or(0),
                average_processing_time: Duration::from_secs(30),
                error_count: 0,
            };
            
            m.gpu_metrics.insert(device_id, gpu_metrics);
        }
        
        Ok(())
    }
    
    /// Check for alert conditions
    async fn check_alerts(
        metrics: &Arc<Mutex<ProverMetrics>>,
        alerts: &Arc<Mutex<Vec<Alert>>>,
    ) -> Result<()> {
        let m = metrics.lock().await;
        let mut a = alerts.lock().await;
        
        // Check GPU temperature alerts
        for (device_id, gpu) in &m.gpu_metrics {
            if gpu.temperature > 85.0 {
                a.push(Alert {
                    timestamp: SystemTime::now(),
                    level: AlertLevel::Critical,
                    category: AlertCategory::Hardware,
                    message: format!("GPU {} temperature critical: {:.1}°C", device_id, gpu.temperature),
                    device_id: Some(*device_id),
                    acknowledged: false,
                });
            } else if gpu.temperature > 80.0 {
                a.push(Alert {
                    timestamp: SystemTime::now(),
                    level: AlertLevel::Warning,
                    category: AlertCategory::Hardware,
                    message: format!("GPU {} temperature high: {:.1}°C", device_id, gpu.temperature),
                    device_id: Some(*device_id),
                    acknowledged: false,
                });
            }
            
            // Check GPU utilization
            if gpu.utilization < 70.0 {
                a.push(Alert {
                    timestamp: SystemTime::now(),
                    level: AlertLevel::Warning,
                    category: AlertCategory::Performance,
                    message: format!("GPU {} utilization low: {:.1}%", device_id, gpu.utilization),
                    device_id: Some(*device_id),
                    acknowledged: false,
                });
            }
        }
        
        // Check deadline misses
        if m.deadline_misses > 0 {
            a.push(Alert {
                timestamp: SystemTime::now(),
                level: AlertLevel::Critical,
                category: AlertCategory::Performance,
                message: format!("Deadline misses detected: {}", m.deadline_misses),
                device_id: None,
                acknowledged: false,
            });
        }
        
        // Check success rate
        if m.success_rate < 95.0 {
            a.push(Alert {
                timestamp: SystemTime::now(),
                level: AlertLevel::Warning,
                category: AlertCategory::Reliability,
                message: format!("Success rate below threshold: {:.1}%", m.success_rate),
                device_id: None,
                acknowledged: false,
            });
        }
        
        Ok(())
    }
    
    /// Log periodic status
    async fn log_status(metrics: &Arc<Mutex<ProverMetrics>>) -> Result<()> {
        const MONITOR_TAG: &str = "\x1b[34m[Monitor]\x1b[0m";
        
        let m = metrics.lock().await;
        
        info!(
            "{MONITOR_TAG} Status: {} proofs completed, {:.1}% success rate, {:.1}% uptime",
            m.total_proofs_completed,
            m.success_rate,
            m.uptime_percentage
        );
        
        for (device_id, gpu) in &m.gpu_metrics {
            info!(
                "{MONITOR_TAG} GPU {}: {:.1}% util, {:.1}°C, {}MB/{} MB",
                device_id,
                gpu.utilization,
                gpu.temperature,
                gpu.memory_used / (1024 * 1024),
                gpu.memory_total / (1024 * 1024)
            );
        }
        
        Ok(())
    }
    
    /// Record proof completion
    pub async fn record_proof_completion(&self, duration: Duration, success: bool) -> Result<()> {
        let mut metrics = self.metrics.lock().await;
        
        if success {
            metrics.total_proofs_completed += 1;
            
            // Update timing metrics
            if metrics.fastest_proof_time.is_zero() || duration < metrics.fastest_proof_time {
                metrics.fastest_proof_time = duration;
            }
            if duration > metrics.slowest_proof_time {
                metrics.slowest_proof_time = duration;
            }
            
            // Update average
            let total_time = metrics.average_proof_time * metrics.total_proofs_completed as u32
                + duration;
            metrics.average_proof_time = total_time / (metrics.total_proofs_completed + 1) as u32;
        } else {
            metrics.total_proofs_failed += 1;
        }
        
        Ok(())
    }
    
    /// Record deadline miss
    pub async fn record_deadline_miss(&self) -> Result<()> {
        let mut metrics = self.metrics.lock().await;
        metrics.deadline_misses += 1;
        
        // Create critical alert
        let mut alerts = self.alerts.lock().await;
        alerts.push(Alert {
            timestamp: SystemTime::now(),
            level: AlertLevel::Critical,
            category: AlertCategory::Performance,
            message: "Proof deadline missed!".to_string(),
            device_id: None,
            acknowledged: false,
        });
        
        Ok(())
    }
    
    /// Get current metrics snapshot
    pub async fn get_metrics(&self) -> ProverMetrics {
        self.metrics.lock().await.clone()
    }
    
    /// Get unacknowledged alerts
    pub async fn get_alerts(&self) -> Vec<Alert> {
        let alerts = self.alerts.lock().await;
        alerts.iter().filter(|a| !a.acknowledged).cloned().collect()
    }
    
    // Helper methods for system metrics (simplified implementations)
    async fn get_cpu_usage() -> Result<f64> {
        // In real implementation, use system APIs
        Ok(75.5)
    }
    
    async fn get_memory_usage() -> Result<(u64, u64)> {
        // In real implementation, use system APIs
        Ok((16 * 1024 * 1024 * 1024, 32 * 1024 * 1024 * 1024)) // 16GB used, 32GB total
    }
    
    async fn get_gpu_utilization(device_id: usize) -> Result<f64> {
        // In real implementation, use NVML
        Ok(match device_id {
            0 => 85.2,
            1 => 82.7,
            _ => 80.0,
        })
    }
    
    async fn get_gpu_memory_used(device_id: usize) -> Result<u64> {
        // In real implementation, use NVML
        Ok(match device_id {
            0 => 8 * 1024 * 1024 * 1024, // 8GB
            1 => 7 * 1024 * 1024 * 1024, // 7GB
            _ => 6 * 1024 * 1024 * 1024, // 6GB
        })
    }
    
    async fn get_gpu_temperature(device_id: usize) -> Result<f64> {
        // In real implementation, use NVML
        Ok(match device_id {
            0 => 78.5,
            1 => 76.2,
            _ => 75.0,
        })
    }
    
    async fn get_gpu_power(device_id: usize) -> Result<f64> {
        // In real implementation, use NVML
        Ok(match device_id {
            0 => 285.5, // Watts
            1 => 278.3,
            _ => 270.0,
        })
    }
}

impl Default for ProverMetrics {
    fn default() -> Self {
        Self {
            total_proofs_completed: 0,
            total_proofs_failed: 0,
            average_proof_time: Duration::ZERO,
            fastest_proof_time: Duration::ZERO,
            slowest_proof_time: Duration::ZERO,
            gpu_metrics: HashMap::new(),
            network_latency: Duration::from_millis(50),
            requests_received: 0,
            requests_missed: 0,
            deadline_misses: 0,
            cpu_usage: 0.0,
            memory_usage: 0,
            memory_total: 0,
            total_earnings: 0.0,
            average_bid_price: 0.0,
            profit_margin: 0.0,
            uptime_percentage: 100.0,
            error_rate: 0.0,
            success_rate: 100.0,
            market_share: 0.0,
            ranking: 0,
            throughput_vs_network: 0.0,
        }
    }
}

impl Default for ProverMonitor {
    fn default() -> Self {
        Self::new()
    }
}
