use sp1_sdk::{ProverClient, SP1Stdin, SP1ProofMode};
use spn_node_core::{ShardedProver, ShardingConfig};
use std::time::Instant;
use tokio;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("🚀 Multi-GPU Proving Test");
    println!("========================");
    
    // Test 1: Standard SP1 ProverClient (baseline)
    test_standard_prover().await?;
    
    // Test 2: ShardedProver with multi-GPU
    test_sharded_prover().await?;
    
    println!("\n🎉 Multi-GPU proving tests completed!");
    Ok(())
}

async fn test_standard_prover() -> Result<(), Box<dyn std::error::Error>> {
    println!("\n🔬 Testing Standard SP1 ProverClient (Baseline)");
    println!("===============================================");
    
    let client = ProverClient::from_env();
    
    // Use simple program for consistent testing
    let elf = include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-simple-program");
    let stdin = SP1Stdin::new();
    
    println!("📊 Generating proof with standard prover...");
    let start = Instant::now();
    
    match client.prove(elf, &stdin).mode(SP1ProofMode::Core).run() {
        Ok(proof_with_pv) => {
            let duration = start.elapsed();
            println!("✅ Standard proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof_with_pv.proof.bytes().len());
        }
        Err(e) => {
            println!("❌ Standard proof failed: {}", e);
        }
    }
    
    Ok(())
}

async fn test_sharded_prover() -> Result<(), Box<dyn std::error::Error>> {
    println!("\n🔬 Testing ShardedProver (Multi-GPU)");
    println!("===================================");
    
    // Initialize ShardedProver with auto-detected GPU count
    let mut config = ShardingConfig::default();
    
    // Override with RTX 3080 optimized settings if available
    if std::env::var("GPU_TYPE").unwrap_or_default() == "rtx3080" {
        config = ShardingConfig::rtx3080_optimized();
    }
    
    println!("🔧 Initializing ShardedProver with {} GPUs", config.num_gpus);
    
    let prover = match ShardedProver::new(config).await {
        Ok(p) => p,
        Err(e) => {
            println!("❌ Failed to initialize ShardedProver: {}", e);
            return Ok(());
        }
    };
    
    // Use simple program for testing
    let elf = include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-simple-program");
    let stdin = SP1Stdin::new();
    
    println!("📊 Generating proof with ShardedProver...");
    let start = Instant::now();
    
    match prover.process_proof_request(
        elf.to_vec(),
        stdin,
        SP1ProofMode::Core,
    ).await {
        Ok(proof) => {
            let duration = start.elapsed();
            println!("✅ Sharded proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof.bytes().len());
            
            // Test verification
            let client = ProverClient::from_env();
            let (_, vk) = client.setup(elf);
            match client.verify(&proof, &vk) {
                Ok(_) => println!("✅ Sharded proof verification successful"),
                Err(e) => println!("❌ Sharded proof verification failed: {}", e),
            }
        }
        Err(e) => {
            println!("❌ Sharded proof failed: {}", e);
        }
    }
    
    Ok(())
}

// Test with different complexity levels
async fn test_performance_comparison() -> Result<(), Box<dyn std::error::Error>> {
    println!("\n🔬 Performance Comparison Test");
    println!("=============================");
    
    let programs = [
        ("Simple", include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-simple-program")),
        ("Medium", include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-medium-program")),
        ("Complex", include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-complex-program")),
    ];
    
    for (name, elf) in programs.iter() {
        println!("\n📊 Testing {} program", name);
        
        // Standard prover test
        let client = ProverClient::from_env();
        let mut stdin = SP1Stdin::new();
        
        // Add input for medium program
        if *name == "Medium" {
            stdin.write(&100u32); // Smaller fibonacci for faster testing
        }
        
        let start = Instant::now();
        match client.prove(*elf, &stdin).mode(SP1ProofMode::Core).run() {
            Ok(_) => {
                let duration = start.elapsed();
                println!("  Standard: {:.2}s", duration.as_secs_f64());
            }
            Err(e) => {
                println!("  Standard: Failed - {}", e);
            }
        }
        
        // ShardedProver test
        let config = ShardingConfig::default();
        if let Ok(prover) = ShardedProver::new(config).await {
            let start = Instant::now();
            match prover.process_proof_request(
                elf.to_vec(),
                stdin.clone(),
                SP1ProofMode::Core,
            ).await {
                Ok(_) => {
                    let duration = start.elapsed();
                    println!("  Sharded:  {:.2}s", duration.as_secs_f64());
                }
                Err(e) => {
                    println!("  Sharded:  Failed - {}", e);
                }
            }
        }
    }
    
    Ok(())
}
