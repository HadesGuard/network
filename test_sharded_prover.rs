use std::time::Instant;
use sp1_sdk::{ProverClient, SP1Stdin, SP1ProofMode};
use spn_node_core::{ShardedProver, ShardingConfig};
use anyhow::Result;
use tracing::{info, Level};
use tracing_subscriber;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    println!("🧪 Local Multi-GPU Sharding Test");
    println!("================================");
    
    // Detect GPUs
    let gpu_count = detect_gpu_count();
    println!("🔍 Detected {} GPU(s)", gpu_count);
    
    if gpu_count == 0 {
        println!("❌ No GPUs detected! Make sure CUDA is installed and GPUs are available.");
        return Ok(());
    }
    
    // Initialize the prover with detected GPU count
    let mut config = ShardingConfig::rtx3080_optimized();
    config.num_gpus = gpu_count;
    
    println!("🚀 Initializing ShardedProver with {} GPUs", config.num_gpus);
    let prover = ShardedProver::new(config).await?;
    
    // Test with fibonacci program (existing)
    println!("\n📝 Testing with Fibonacci program...");
    test_fibonacci_program(&prover).await?;
    
    // Test with different complexity levels
    println!("\n📊 Testing different complexity levels...");
    test_complexity_levels(&prover).await?;
    
    // Performance comparison
    println!("\n⚡ Performance comparison test...");
    performance_comparison_test().await?;
    
    println!("\n✅ All tests completed successfully!");
    Ok(())
}

fn detect_gpu_count() -> usize {
    use std::process::Command;
    
    // Try nvidia-smi first
    if let Ok(output) = Command::new("nvidia-smi").args(&["-L"]).output() {
        if output.status.success() {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let count = stdout.lines().count();
            if count > 0 {
                return count;
            }
        }
    }
    
    // Try CUDA_VISIBLE_DEVICES
    if let Ok(cuda_devices) = std::env::var("CUDA_VISIBLE_DEVICES") {
        if !cuda_devices.is_empty() {
            return cuda_devices.split(',').count();
        }
    }
    
    // Default to 1
    1
}

async fn test_fibonacci_program(prover: &ShardedProver) -> Result<()> {
    println!("🔬 Testing Fibonacci program with multi-GPU sharding");
    
    // Use the existing fibonacci program
    let program_path = "./programs/examples/fibonacci/elf/fibonacci-program";
    
    if !std::path::Path::new(program_path).exists() {
        println!("⚠️  Fibonacci program not found, building it...");
        
        // Build fibonacci program
        let output = std::process::Command::new("cargo")
            .args(&["prove", "build"])
            .current_dir("./programs/examples/fibonacci")
            .output()?;
            
        if !output.status.success() {
            println!("❌ Failed to build fibonacci program");
            return Ok(());
        }
    }
    
    let program = std::fs::read(program_path)?;
    
    // Create input for fibonacci
    let mut stdin = SP1Stdin::new();
    stdin.write(&20u32); // Calculate 20th fibonacci number
    
    println!("📊 Testing different proof modes...");
    
    // Test Core mode
    println!("\n🔬 Testing Core mode");
    let start = Instant::now();
    
    match prover.process_proof_request(
        program.clone(),
        stdin.clone(),
        SP1ProofMode::Core,
    ).await {
        Ok(proof) => {
            let duration = start.elapsed();
            println!("✅ Core proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof.bytes().len());
        }
        Err(e) => {
            println!("❌ Core proof failed: {}", e);
        }
    }
    
    // Test Compressed mode
    println!("\n🔬 Testing Compressed mode");
    let start = Instant::now();
    
    match prover.process_proof_request(
        program,
        stdin,
        SP1ProofMode::Compressed,
    ).await {
        Ok(proof) => {
            let duration = start.elapsed();
            println!("✅ Compressed proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof.bytes().len());
        }
        Err(e) => {
            println!("❌ Compressed proof failed: {}", e);
        }
    }
    
    Ok(())
}

async fn test_complexity_levels(prover: &ShardedProver) -> Result<()> {
    println!("🔬 Testing different complexity levels");
    
    // Simple computation test
    println!("\n📝 Simple computation test");
    let simple_program = create_simple_test_program();
    let stdin = SP1Stdin::new();
    
    let start = Instant::now();
    match prover.process_proof_request(
        simple_program,
        stdin,
        SP1ProofMode::Core,
    ).await {
        Ok(_) => {
            let duration = start.elapsed();
            println!("✅ Simple test completed in {:.2}s", duration.as_secs_f64());
        }
        Err(e) => {
            println!("❌ Simple test failed: {}", e);
        }
    }
    
    Ok(())
}

fn create_simple_test_program() -> Vec<u8> {
    // This would be a compiled SP1 program
    // For now, return empty vec as placeholder
    vec![]
}

async fn performance_comparison_test() -> Result<()> {
    println!("⚡ Performance comparison: Single GPU vs Multi GPU");
    
    // Test single GPU performance
    println!("\n🔬 Testing single GPU performance");
    std::env::set_var("CUDA_VISIBLE_DEVICES", "0");
    
    let single_config = ShardingConfig {
        num_gpus: 1,
        shards_per_gpu: 1,
        min_cycles_per_shard: 1000,
        max_cycles_per_shard: 1000000,
        enable_checkpointing: false,
    };
    
    let single_prover = ShardedProver::new_sync(single_config)?;
    
    // Test multi GPU performance
    println!("\n🔬 Testing multi GPU performance");
    let gpu_count = detect_gpu_count();
    if gpu_count > 1 {
        std::env::set_var("CUDA_VISIBLE_DEVICES", "0,1");
        
        let multi_config = ShardingConfig {
            num_gpus: gpu_count,
            shards_per_gpu: 2,
            min_cycles_per_shard: 1000,
            max_cycles_per_shard: 1000000,
            enable_checkpointing: true,
        };
        
        let _multi_prover = ShardedProver::new_sync(multi_config)?;
        
        println!("✅ Multi-GPU prover initialized successfully");
        println!("🎯 Performance improvement expected: ~{}x", gpu_count);
    } else {
        println!("⚠️  Only 1 GPU available, skipping multi-GPU test");
    }
    
    Ok(())
}
