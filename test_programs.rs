use sp1_sdk::{ProverClient, SP1Stdin, SP1ProofMode};
use std::time::Instant;

fn main() {
    println!("🧪 Testing SP1 Programs with Multi-GPU ShardedProver");
    println!("==================================================");
    
    // Initialize prover client
    let client = ProverClient::from_env();
    
    // Test 1: Simple Program
    test_simple_program(&client);
    
    // Test 2: Medium Program  
    test_medium_program(&client);
    
    // Test 3: Complex Program
    test_complex_program(&client);
    
    println!("\n🎉 All program tests completed!");
}

fn test_simple_program(client: &ProverClient) {
    println!("\n🔬 Testing Simple Program");
    println!("========================");
    
    // Load the program
    let elf = include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-simple-program");
    
    // Setup input
    let stdin = SP1Stdin::new();
    
    // Generate proof
    println!("📊 Generating proof...");
    let start = Instant::now();
    
    match client.prove(elf, &stdin).mode(SP1ProofMode::Core).run() {
        Ok(proof_with_pv) => {
            let duration = start.elapsed();
            println!("✅ Simple program proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof_with_pv.proof.bytes().len());
            
            // Verify proof
            let (_, vk) = client.setup(elf);
            match client.verify(&proof_with_pv.proof, &vk) {
                Ok(_) => println!("✅ Proof verification successful"),
                Err(e) => println!("❌ Proof verification failed: {}", e),
            }
        }
        Err(e) => {
            println!("❌ Simple program proof failed: {}", e);
        }
    }
}

fn test_medium_program(client: &ProverClient) {
    println!("\n🔬 Testing Medium Program (Fibonacci)");
    println!("====================================");
    
    // Load the program
    let elf = include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-medium-program");
    
    // Setup input - fibonacci number to calculate
    let mut stdin = SP1Stdin::new();
    stdin.write(&1000u32); // Calculate 1000th fibonacci number
    
    // Generate proof
    println!("📊 Generating proof for fibonacci(1000)...");
    let start = Instant::now();
    
    match client.prove(elf, &stdin).mode(SP1ProofMode::Core).run() {
        Ok(proof_with_pv) => {
            let duration = start.elapsed();
            println!("✅ Medium program proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof_with_pv.proof.bytes().len());
            
            // Verify proof
            let (_, vk) = client.setup(elf);
            match client.verify(&proof_with_pv.proof, &vk) {
                Ok(_) => println!("✅ Proof verification successful"),
                Err(e) => println!("❌ Proof verification failed: {}", e),
            }
        }
        Err(e) => {
            println!("❌ Medium program proof failed: {}", e);
        }
    }
}

fn test_complex_program(client: &ProverClient) {
    println!("\n🔬 Testing Complex Program (Matrix Operations)");
    println!("=============================================");
    
    // Load the program
    let elf = include_bytes!("../target/elf-compilation/riscv32im-succinct-zkvm-elf/release/test-complex-program");
    
    // Setup input
    let stdin = SP1Stdin::new();
    
    // Generate proof
    println!("📊 Generating proof for 50x50 matrix operations...");
    let start = Instant::now();
    
    match client.prove(elf, &stdin).mode(SP1ProofMode::Core).run() {
        Ok(proof_with_pv) => {
            let duration = start.elapsed();
            println!("✅ Complex program proof completed in {:.2}s", duration.as_secs_f64());
            println!("📏 Proof size: {} bytes", proof_with_pv.proof.bytes().len());
            
            // Verify proof
            let (_, vk) = client.setup(elf);
            match client.verify(&proof_with_pv.proof, &vk) {
                Ok(_) => println!("✅ Proof verification successful"),
                Err(e) => println!("❌ Proof verification failed: {}", e),
            }
        }
        Err(e) => {
            println!("❌ Complex program proof failed: {}", e);
        }
    }
}
