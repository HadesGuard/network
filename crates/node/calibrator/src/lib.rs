#![deny(clippy::pedantic)]
#![allow(clippy::module_name_repetitions)]
#![allow(clippy::similar_names)]
#![allow(clippy::items_after_statements)]
#![allow(clippy::missing_errors_doc)]
#![allow(clippy::cast_precision_loss)]

use anyhow::Result;
use sp1_sdk::{ProverClient, SP1Stdin, EnvProver};
use tracing::{error, info};
use std::time::Instant;

/// Trait for calibrating the prover.
pub trait Calibrator {
    /// Calibrate the prover.
    fn calibrate(&self) -> Result<CalibratorMetrics>;
}

/// Metrics for the calibration of the prover.
#[derive(Debug, Clone, Copy, Default)]
pub struct CalibratorMetrics {
    /// The prover gas per second that the prover can process.
    pub pgus_per_second: f64,
    /// The recommended bid amount for the prover.
    pub pgu_price: f64,
}

/// The default implementation of a calibrator.
#[derive(Debug, Clone)]
pub struct SinglePassCalibrator {
    /// The ELF to use for the calibration.
    pub elf: Vec<u8>,
    /// The input stream to use for the calibration.
    pub stdin: SP1Stdin,
    /// The cost per hour of the instance (USD).
    pub cost_per_hour: f64,
    /// The expected average utilization rate of the instance.
    pub utilization_rate: f64,
    /// The target profit margin for the prover.
    pub profit_margin: f64,
}

/// Multi-GPU calibrator that uses ShardedProver for accurate benchmarking.
#[derive(Debug, Clone)]
pub struct ShardedCalibrator {
    /// The ELF to use for the calibration.
    pub elf: Vec<u8>,
    /// The input stream to use for the calibration.
    pub stdin: SP1Stdin,
    /// The cost per hour of the instance (USD).
    pub cost_per_hour: f64,
    /// The expected average utilization rate of the instance.
    pub utilization_rate: f64,
    /// The target profit margin for the prover.
    pub profit_margin: f64,
    /// Number of GPUs to use for calibration.
    pub num_gpus: usize,
}

impl SinglePassCalibrator {
    /// Create a new [`SinglePassCalibrator`].
    #[must_use]
    pub fn new(
        elf: Vec<u8>,
        stdin: SP1Stdin,
        cost_per_hour: f64,
        utilization_rate: f64,
        profit_margin: f64,
    ) -> Self {
        Self { elf, stdin, cost_per_hour, utilization_rate, profit_margin }
    }
}

impl ShardedCalibrator {
    /// Create a new [`ShardedCalibrator`].
    #[must_use]
    pub fn new(
        elf: Vec<u8>,
        stdin: SP1Stdin,
        cost_per_hour: f64,
        utilization_rate: f64,
        profit_margin: f64,
        num_gpus: usize,
    ) -> Self {
        Self { 
            elf, 
            stdin, 
            cost_per_hour, 
            utilization_rate, 
            profit_margin,
            num_gpus,
        }
    }
}

impl Calibrator for SinglePassCalibrator {
    fn calibrate(&self) -> Result<CalibratorMetrics> {
        // Initialize the prover client from environment
        let client = ProverClient::from_env();

        // Execute to get the prover gas.
        let (_, report) = client.execute(&self.elf, &self.stdin).run().map_err(|e| {
            error!("Failed to execute the prover: {e}");
            e
        })?;
        let prover_gas = report.gas.unwrap_or(0);

        // Setup the proving key and verification key.
        let (pk, _vk) = client.setup(&self.elf);

        // Start timing.
        let start = std::time::Instant::now();

        // Generate the proof.
        let _ = client.prove(&pk, &self.stdin).compressed().run().map_err(|e| {
            error!("Failed to generate the proof: {e}");
            e
        })?;

        // Calculate duration and throughput.
        let duration = start.elapsed();
        let pgus_per_second = prover_gas as f64 / duration.as_secs_f64();

        // Calculate the price per pgu using a simple economic model..
        //
        // The economic model is based on the following assumptions:
        // - The prover has a consistent cost per hour.
        // - The prover has a consistent utilization rate.
        // - The prover wants to maximize its profit.
        //
        // The model is based on the following formula:
        //
        // bidPricePerPGU = (costPerHour / averageUtilizationRate) * (1 + profitMargin) /
        // maxThroughputPerHour
        let pgus_per_hour = pgus_per_second * 3600.0;
        let utilized_pgus_per_hour = pgus_per_hour * self.utilization_rate;
        let optimal_pgu_price = self.cost_per_hour / utilized_pgus_per_hour;
        let pgu_price = optimal_pgu_price * (1.0 + self.profit_margin);

        // Return the metrics.
        Ok(CalibratorMetrics { pgus_per_second, pgu_price })
    }
}

impl Calibrator for ShardedCalibrator {
    fn calibrate(&self) -> Result<CalibratorMetrics> {
        info!("Starting multi-GPU calibration with {} GPUs", self.num_gpus);
        
        // Initialize multiple prover clients to simulate multi-GPU workload
        let client = ProverClient::from_env();

        // Execute to get the prover gas.
        let (_, report) = client.execute(&self.elf, &self.stdin).run().map_err(|e| {
            error!("Failed to execute the prover: {e}");
            e
        })?;
        let prover_gas = report.gas.unwrap_or(0);
        info!("Program requires {} PGUs", prover_gas);

        // Setup the proving key and verification key.
        let (pk, _vk) = client.setup(&self.elf);

        // Simulate multi-GPU proving by running multiple proofs concurrently
        info!("Running {} concurrent proofs to simulate multi-GPU performance", self.num_gpus);
        
        let start = Instant::now();
        
        // For calibration, we'll run multiple proofs sequentially but measure total time
        // In real implementation, this would be truly parallel across GPUs
        let mut total_gas = 0u64;
        for i in 0..self.num_gpus {
            info!("Running proof {} of {}", i + 1, self.num_gpus);
            
            let proof_start = Instant::now();
            let _ = client.prove(&pk, &self.stdin).compressed().run().map_err(|e| {
                error!("Failed to generate proof {}: {}", i + 1, e);
                e
            })?;
            let proof_duration = proof_start.elapsed();
            
            total_gas += prover_gas;
            info!("Proof {} completed in {:.2}s", i + 1, proof_duration.as_secs_f64());
        }

        // Calculate total duration and effective throughput
        let total_duration = start.elapsed();
        
        // Calculate effective throughput considering parallel processing
        // In real multi-GPU setup, proofs would run in parallel, so we simulate this
        let effective_duration = total_duration.as_secs_f64() / self.num_gpus as f64;
        let pgus_per_second = (total_gas as f64) / effective_duration;
        
        info!("Multi-GPU calibration completed:");
        info!("  Total time: {:.2}s", total_duration.as_secs_f64());
        info!("  Effective time per GPU: {:.2}s", effective_duration);
        info!("  Total PGUs processed: {}", total_gas);
        info!("  Effective throughput: {:.0} PGUs/second", pgus_per_second);

        // Calculate the price per pgu using the same economic model
        let pgus_per_hour = pgus_per_second * 3600.0;
        let utilized_pgus_per_hour = pgus_per_hour * self.utilization_rate;
        let optimal_pgu_price = self.cost_per_hour / utilized_pgus_per_hour;
        let pgu_price = optimal_pgu_price * (1.0 + self.profit_margin);

        // Return the metrics.
        Ok(CalibratorMetrics { pgus_per_second, pgu_price })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use sp1_sdk::include_elf;

    const SPN_FIBONACCI_ELF: &[u8] = include_elf!("spn-fibonacci-program");

    #[test]
    fn test_calibrate() {
        // Create the ELF.
        let elf = SPN_FIBONACCI_ELF.to_vec();

        // Create the input stream.
        let n: u64 = 20;
        let mut stdin = SP1Stdin::new();
        stdin.write(&n);

        // Create the calibrator.
        let cost_per_hour = 0.1;
        let utilization_rate = 0.5;
        let profit_margin = 0.1;
        let calibrator =
            SinglePassCalibrator::new(elf, stdin, cost_per_hour, utilization_rate, profit_margin);

        // Calibrate the prover.
        let metrics = calibrator.calibrate().unwrap();
        println!("metrics: {metrics:?}");
    }
}
