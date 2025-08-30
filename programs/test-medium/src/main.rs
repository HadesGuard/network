#![no_main]
sp1_zkvm::entrypoint!(main);

pub fn main() {
    println!("cycle-tracker-start: fibonacci");
    
    // Fibonacci with more iterations
    let n = sp1_zkvm::io::read::<u32>();
    let mut a = 0u64;
    let mut b = 1u64;
    
    for i in 0..n {
        let temp = a + b;
        a = b;
        b = temp;
        
        // Add some extra computation to increase cycles
        if i % 100 == 0 {
            for j in 0..1000 {
                a = a.wrapping_mul(j as u64 + 1);
                b = b.wrapping_add(j as u64 * 2);
            }
        }
    }
    
    println!("cycle-tracker-end: fibonacci");
    
    sp1_zkvm::io::commit(&b);
}
