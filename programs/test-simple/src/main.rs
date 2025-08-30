#![no_main]
sp1_zkvm::entrypoint!(main);

pub fn main() {
    // Simple computation - sum of squares
    let mut sum = 0u64;
    for i in 1..=100 {
        sum += i * i;
    }
    
    println!("cycle-tracker-start: computation");
    // More intensive computation
    for _ in 0..1000 {
        sum = sum.wrapping_mul(1234567).wrapping_add(987654321);
    }
    println!("cycle-tracker-end: computation");
    
    sp1_zkvm::io::commit(&sum);
}
