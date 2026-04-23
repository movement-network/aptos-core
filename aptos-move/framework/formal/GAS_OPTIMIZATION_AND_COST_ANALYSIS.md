# Gas Optimization and Cost Analysis for Confidential Assets

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Protocol developers, gas optimizers, verification engineers  
**Estimated Read Time**: 75 minutes  
**Prerequisites**: Understanding of Move bytecode, VM execution  

---

## Table of Contents

1. [Overview](#overview)
2. [Gas Cost Model](#gas-cost-model)
3. [Profiling and Measurement](#profiling-and-measurement)
4. [Bytecode-Level Optimizations](#bytecode-level-optimizations)
5. [Cryptographic Operation Costs](#cryptographic-operation-costs)
6. [Storage Access Optimization](#storage-access-optimization)
7. [Vector and Data Structure Costs](#vector-and-data-structure-costs)
8. [Function Call Overhead](#function-call-overhead)
9. [Verification-Preserving Optimizations](#verification-preserving-optimizations)
10. [Cost-Benefit Analysis](#cost-benefit-analysis)
11. [Benchmarking and Testing](#benchmarking-and-testing)
12. [Cost Budgets and Monitoring](#cost-budgets-and-monitoring)

---

## Overview

### Why Gas Optimization Matters

**User Impact:**
- **Transaction costs**: Users pay gas fees
- **Affordability**: Lower costs = wider adoption
- **Throughput**: Lower gas = more transactions per block

**Protocol Impact:**
- **Computational load**: Gas limits prevent DoS
- **Network scalability**: Efficient operations = higher TPS
- **Competitive advantage**: Cheaper than alternatives

### Gas vs. Verification Trade-Off

**Optimization Constraints:**
1. **Must preserve correctness**: Can't break verified properties
2. **Must preserve security**: No new attack vectors
3. **Must maintain readability**: Code must remain maintainable

**This Guide's Approach:**
- Measure before optimizing
- Optimize hot paths only
- Verify optimizations preserve properties
- Document cost/benefit trade-offs

---

## Gas Cost Model

### Base Gas Costs

**Instruction Categories:**

**1. Cheap Operations (1-2 gas):**
```lean
def cheapInstructions : List (Instruction × Nat) :=
  [ (Instruction.CopyLoc _, 1)
  , (Instruction.StLoc _, 1)
  , (Instruction.LdU64 _, 1)
  , (Instruction.LdTrue, 1)
  , (Instruction.LdFalse, 1)
  , (Instruction.Add, 1)
  , (Instruction.Sub, 1)
  , (Instruction.Lt, 1)
  , (Instruction.Eq, 1)
  ]
```

**2. Moderate Operations (3-10 gas):**
```lean
def moderateInstructions : List (Instruction × Nat) :=
  [ (Instruction.Mul, 3)
  , (Instruction.Div, 10)
  , (Instruction.Mod, 10)
  , (Instruction.MoveLoc _, 2)
  , (Instruction.ImmBorrowLoc _, 3)
  , (Instruction.MutBorrowLoc _, 3)
  ]
```

**3. Expensive Operations (50-1000 gas):**
```lean
def expensiveInstructions : List (Instruction × Nat) :=
  [ (Instruction.BorrowGlobal _, 50)
  , (Instruction.MoveFrom _, 100)
  , (Instruction.MoveTo _, 100)
  , (Instruction.Call _, 100)
  , (Instruction.CallNative _, 500)  -- Varies by function
  ]
```

### Native Function Costs

**Cryptographic Functions:**
```lean
def nativeGasCosts : NativeFunction → Nat
  | NativeFunction.SHA512 => 500
  | NativeFunction.Ristretto255Add => 100
  | NativeFunction.Ristretto255ScalarMult => 300
  | NativeFunction.Ristretto255ScalarMultBase => 200  -- Optimized
  | NativeFunction.VerifySchnorrProof => 1000
  | NativeFunction.VerifyRangeProof => 2000
  | NativeFunction.ElGamalEncrypt => 400
  | NativeFunction.ElGamalAdd => 150
```

**Why These Costs:**
- **SHA512**: ~500 CPU cycles per block, multiple blocks
- **Scalar mult**: ~200K CPU cycles (constant-time)
- **Schnorr verify**: ~3 scalar mults + hash
- **Range proof**: Much more complex (bulletproofs)

### Storage Costs

**Read Costs:**
```lean
def storagReadCost (item_size : Nat) : Nat :=
  50 + (item_size / 100)  -- Base + per-byte
```

**Write Costs:**
```lean
def storageWriteCost (item_size : Nat) : Nat :=
  100 + (item_size / 50)  -- Higher base + per-byte
```

**Example:**
```move
// Reading 1KB resource
borrow_global<Balance>(addr)  // 50 + 1000/100 = 60 gas

// Writing 1KB resource
move_to(account, balance)  // 100 + 1000/50 = 120 gas
```

---

## Profiling and Measurement

### Gas Profiling Tools

**Method 1: Difftest with Gas Tracking**

**Implementation:**
```rust
// gas_profiler.rs

pub struct GasProfiler {
    instruction_costs: HashMap<Instruction, u64>,
    native_costs: HashMap<NativeFunction, u64>,
    total_gas: u64,
}

impl GasProfiler {
    pub fn profile_transaction(tx: Transaction) -> GasProfile {
        let mut profiler = GasProfiler::new();
        let vm = VM::new_with_profiler(&mut profiler);
        
        vm.execute(tx);
        
        GasProfile {
            total: profiler.total_gas,
            breakdown: profiler.get_breakdown(),
            hot_spots: profiler.find_hot_spots(),
        }
    }
    
    fn get_breakdown(&self) -> GasBreakdown {
        GasBreakdown {
            instructions: self.instruction_costs.iter()
                .map(|(instr, cost)| (instr.clone(), *cost))
                .collect(),
            natives: self.native_costs.iter()
                .map(|(func, cost)| (func.clone(), *cost))
                .collect(),
            storage: self.storage_cost,
        }
    }
}
```

**Usage:**
```rust
#[test]
fn profile_transfer_gas() {
    let tx = create_transfer_transaction(sender, receiver, 1000);
    let profile = GasProfiler::profile_transaction(tx);
    
    println!("Total gas: {}", profile.total);
    println!("Breakdown:");
    println!("  Instructions: {}", profile.breakdown.instructions.values().sum());
    println!("  Natives: {}", profile.breakdown.natives.values().sum());
    println!("  Storage: {}", profile.breakdown.storage);
    
    println!("\nHot spots:");
    for (func, gas) in profile.hot_spots {
        println!("  {}: {} gas ({:.1}%)", func, gas, gas as f64 / profile.total as f64 * 100.0);
    }
}
```

**Method 2: Bytecode Analysis**

**Static Cost Estimation:**
```python
# estimate_gas.py

def estimate_bytecode_gas(bytecode):
    """Estimate gas cost from bytecode (no execution)"""
    total_gas = 0
    
    for pc, instruction in enumerate(bytecode):
        base_cost = INSTRUCTION_COSTS.get(instruction.opcode, 1)
        
        if instruction.opcode == 'CallNative':
            # Add native function cost
            native_cost = NATIVE_COSTS.get(instruction.function, 500)
            total_gas += native_cost
        elif instruction.opcode in ['BorrowGlobal', 'MoveFrom', 'MoveTo']:
            # Add storage cost (estimated)
            total_gas += 50
        else:
            total_gas += base_cost
    
    return total_gas

# Usage
bytecode = load_compiled_bytecode('transfer.mv')
estimated_gas = estimate_bytecode_gas(bytecode)
print(f"Estimated gas: {estimated_gas}")
```

### Benchmark Framework

**Test Harness:**
```move
// benchmark_framework.move

module benchmark {
    use std::vector;
    
    public fun measure_gas<F>(f: F): u64 {
        let gas_before = get_remaining_gas();
        f();
        let gas_after = get_remaining_gas();
        gas_before - gas_after
    }
    
    #[test]
    public fun benchmark_transfer() {
        let gas = measure_gas(|| {
            confidential_asset::transfer(sender, receiver, 1000, proof);
        });
        
        assert!(gas < 10000, gas);  // Budget: 10K gas
        print(&gas);
    }
}
```

---

## Bytecode-Level Optimizations

### Optimization 1: Eliminate Redundant Loads

**Before:**
```move
public fun transfer(sender: &signer, receiver: address, amount: u64) {
    let sender_addr = signer::address_of(sender);
    let sender_balance = borrow_global_mut<Balance>(sender_addr);
    // ... use sender_addr again later
    let sender_addr2 = signer::address_of(sender);  // REDUNDANT!
}
```

**Bytecode (Before):**
```
0:  CopyLoc[0]              // sender
1:  Call(signer::address_of)
2:  StLoc[3]                // sender_addr
... (use sender_addr)
10: CopyLoc[0]              // sender (REDUNDANT)
11: Call(signer::address_of)  // 100 gas wasted
12: StLoc[4]
```

**After:**
```move
public fun transfer(sender: &signer, receiver: address, amount: u64) {
    let sender_addr = signer::address_of(sender);
    let sender_balance = borrow_global_mut<Balance>(sender_addr);
    // ... use sender_addr multiple times
    // No redundant call
}
```

**Bytecode (After):**
```
0:  CopyLoc[0]
1:  Call(signer::address_of)
2:  StLoc[3]                // sender_addr
... (use sender_addr)
10: CopyLoc[3]              // Reuse from local (1 gas)
```

**Savings:** 99 gas per redundant call

### Optimization 2: Hoist Loop-Invariant Code

**Before:**
```move
let i = 0;
while (i < n) {
    let constant_value = expensive_computation();  // LOOP-INVARIANT!
    process(i, constant_value);
    i = i + 1;
}
```

**Cost:** `expensive_computation()` executed `n` times

**After:**
```move
let constant_value = expensive_computation();  // Hoist out of loop
let i = 0;
while (i < n) {
    process(i, constant_value);
    i = i + 1;
}
```

**Cost:** `expensive_computation()` executed once

**Savings:** `(n - 1) * cost(expensive_computation)`

### Optimization 3: Strength Reduction

**Before:**
```move
let result = value * 8;  // Multiplication (3 gas)
```

**After:**
```move
let result = value << 3;  // Left shift (1 gas)
```

**Savings:** 2 gas per operation

**Verification Requirement:**
```lean
theorem shift_equals_mul : value << 3 = value * 8 := by
  simp [Nat.shiftLeft_eq]
```

**Caution:** Only works for powers of 2.

### Optimization 4: Minimize Stack Operations

**Before:**
```move
let a = x + y;
let b = a + z;
let c = b + w;
return c;
```

**Bytecode (Before):**
```
0:  CopyLoc[0]  // x
1:  CopyLoc[1]  // y
2:  Add
3:  StLoc[2]    // a
4:  CopyLoc[2]  // a
5:  CopyLoc[3]  // z
6:  Add
7:  StLoc[4]    // b
8:  CopyLoc[4]  // b
9:  CopyLoc[5]  // w
10: Add
11: StLoc[6]    // c
12: MoveLoc[6]
13: Ret
```

**After:**
```move
return ((x + y) + z) + w;  // No intermediate variables
```

**Bytecode (After):**
```
0:  CopyLoc[0]  // x
1:  CopyLoc[1]  // y
2:  Add
3:  CopyLoc[2]  // z
4:  Add
5:  CopyLoc[3]  // w
6:  Add
7:  Ret
```

**Savings:** 6 instructions eliminated

---

## Cryptographic Operation Costs

### Expensive: Proof Verification

**Cost Breakdown (Schnorr proof):**
```lean
def schnorrVerifyCost : Nat :=
  let hash_cost := 500              -- SHA-512
  let scalar_mult_base := 200       -- g^response
  let scalar_mult := 300            -- pubkey^challenge
  let point_add := 100              -- commitment + pubkey^challenge
  let comparison := 1               -- Equality check
  hash_cost + scalar_mult_base + scalar_mult + point_add + comparison
  -- Total: 1101 gas
```

**Cannot Optimize:** Cryptographic correctness required.

**Mitigation: Batch Verification**

**Before:**
```move
// Verify 5 proofs individually
verify_proof(proof1);  // 1101 gas
verify_proof(proof2);  // 1101 gas
verify_proof(proof3);  // 1101 gas
verify_proof(proof4);  // 1101 gas
verify_proof(proof5);  // 1101 gas
// Total: 5505 gas
```

**After:**
```move
// Batch verify 5 proofs
batch_verify_proofs(vec![proof1, proof2, proof3, proof4, proof5]);
// Total: ~3000 gas (45% savings)
```

**Batch Verification Algorithm:**
```rust
// Batch Schnorr verification
pub fn batch_verify(proofs: &[SchnorrProof], pubkeys: &[PublicKey]) -> bool {
    // Instead of verifying: g^r_i = A_i + e_i * P_i for each i
    // Verify: g^(Σ r_i) = Σ A_i + Σ (e_i * P_i)
    // Saves: (n-1) scalar base multiplications
    
    let total_response: Scalar = proofs.iter().map(|p| p.response).sum();
    let lhs = scalar_mult_base(total_response);  // One base mult
    
    let rhs = proofs.iter().zip(pubkeys)
        .map(|(proof, pk)| proof.commitment + scalar_mult(pk, proof.challenge))
        .sum();  // n scalar mults, n additions
    
    lhs == rhs
}
```

**Savings:** `(n - 1) * 200` gas for n proofs

### Moderate: Elliptic Curve Operations

**Cost Comparison:**
```lean
def curveCosts : List (Operation × Nat) :=
  [ (ScalarMultBase, 200)      -- Fastest (precomputed table)
  , (ScalarMult, 300)          -- General scalar mult
  , (PointAdd, 100)            -- Point addition
  , (PointSub, 100)            -- Point subtraction
  , (PointDouble, 80)          -- Point doubling (optimized)
  ]
```

**Optimization: Use ScalarMultBase When Possible**

**Before:**
```move
let point = scalar_mult(generator, scalar);  // 300 gas
```

**After:**
```move
let point = scalar_mult_base(scalar);  // 200 gas
```

**Savings:** 100 gas

**Verification:**
```lean
axiom scalarMultBase_correct :
  ∀ s, scalarMultBase s = scalarMult generator s
```

### Cheap: Hashing

**SHA-512 Cost:** ~500 gas

**Optimization: Minimize Hash Inputs**

**Before:**
```move
let hash = sha512(data1 || data2 || data3 || data4);
// If data contains 1KB total: 500 + 1000/100 = 510 gas
```

**After:**
```move
// Pre-hash constant parts
let constant_hash = sha512(data3 || data4);  // Done once
let hash = sha512(data1 || data2 || constant_hash);
// If reused 10 times: saves 9 * 500 = 4500 gas
```

---

## Storage Access Optimization

### Optimization 1: Minimize Global Storage Access

**Expensive:** BorrowGlobal, MoveFrom, MoveTo

**Before:**
```move
public fun update_balance(addr: address) {
    let balance = borrow_global_mut<Balance>(addr);  // 50 gas
    balance.value = balance.value + 1;
    // ... more operations
    let balance2 = borrow_global_mut<Balance>(addr);  // 50 gas REDUNDANT
    balance2.value = balance2.value + 1;
}
```

**After:**
```move
public fun update_balance(addr: address) {
    let balance = borrow_global_mut<Balance>(addr);  // 50 gas
    balance.value = balance.value + 1;
    // ... more operations
    balance.value = balance.value + 1;  // Reuse reference (0 gas)
}
```

**Savings:** 50 gas

### Optimization 2: Batch Storage Updates

**Before:**
```move
public fun update_many(addrs: vector<address>) {
    let i = 0;
    while (i < vector::length(&addrs)) {
        let addr = *vector::borrow(&addrs, i);
        let balance = borrow_global_mut<Balance>(addr);  // 50 gas per
        balance.value = balance.value + 1;
        i = i + 1;
    }
}
// Cost: n * 50 gas for storage access
```

**After (if possible):**
```move
// Store increments, apply in batch
public fun update_many_batched(addrs: vector<address>) {
    // Collect all borrows first
    let refs = vector::empty();
    let i = 0;
    while (i < vector::length(&addrs)) {
        let addr = *vector::borrow(&addrs, i);
        vector::push_back(&mut refs, borrow_global_mut<Balance>(addr));
        i = i + 1;
    }
    
    // Update all
    i = 0;
    while (i < vector::length(&refs)) {
        let balance = vector::borrow_mut(&mut refs, i);
        balance.value = balance.value + 1;
        i = i + 1;
    }
}
```

**Savings:** Reduces redundant borrow overhead

### Optimization 3: Pack Data Structures

**Before:**
```move
struct Balance has key {
    encrypted_value_c1: vector<u8>,     // 32 bytes
    encrypted_value_c2: vector<u8>,     // 32 bytes
    public_key: vector<u8>,             // 32 bytes
    nonce: u64,                         // 8 bytes
    proof_history: vector<vector<u8>>,  // Variable
}
// Storage cost: 100 + (104 + history)/50 gas to write
```

**After:**
```move
struct Balance has key {
    // Pack fixed-size fields into single vector
    packed_data: vector<u8>,  // 104 bytes (includes all fixed fields)
    proof_history: vector<vector<u8>>,
}

// Pack/unpack helpers
public fun pack_balance_data(c1: vector<u8>, c2: vector<u8>, pk: vector<u8>, nonce: u64): vector<u8> {
    let data = vector::empty();
    vector::append(&mut data, c1);
    vector::append(&mut data, c2);
    vector::append(&mut data, pk);
    append_u64(&mut data, nonce);
    data
}
```

**Savings:** Reduced struct overhead (marginal, ~5-10 gas)

---

## Vector and Data Structure Costs

### Vector Operations

**Cost Model:**
```lean
def vectorCost (op : VectorOp) (size : Nat) : Nat :=
  match op with
  | Push => 5 + size / 100           -- Amortized O(1)
  | Pop => 3
  | Borrow => 1
  | BorrowMut => 2
  | Length => 1
  | Empty => 1
  | Append => 5 + size / 50          -- O(n) in appended size
  | Reverse => 3 * size              -- O(n)
  | Contains => 1 * size             -- O(n) search
```

### Optimization: Avoid Unnecessary Copies

**Before:**
```move
let vec1 = vector::empty();
vector::push_back(&mut vec1, item1);
vector::push_back(&mut vec1, item2);

let vec2 = vec1;  // COPIES entire vector!
vector::push_back(&mut vec2, item3);
```

**Cost:** Copy = `size * 1` gas

**After:**
```move
let vec1 = vector::empty();
vector::push_back(&mut vec1, item1);
vector::push_back(&mut vec1, item2);
vector::push_back(&mut vec1, item3);
// Use vec1 directly, no copy
```

### Optimization: Pre-allocate Vectors

**Before:**
```move
let vec = vector::empty();
let i = 0;
while (i < 1000) {
    vector::push_back(&mut vec, i);  // May resize multiple times
    i = i + 1;
}
```

**After:**
```move
let vec = vector::empty_with_capacity(1000);  // Pre-allocate
let i = 0;
while (i < 1000) {
    vector::push_back(&mut vec, i);  // No resizing
    i = i + 1;
}
```

**Savings:** Avoids reallocation costs

---

## Function Call Overhead

### Inline Small Functions

**Before:**
```move
fun add_one(x: u64): u64 {
    x + 1
}

public fun process(values: vector<u64>) {
    let i = 0;
    while (i < vector::length(&values)) {
        let val = *vector::borrow(&values, i);
        let result = add_one(val);  // 100 gas per call!
        i = i + 1;
    }
}
// Cost: n * 100 gas for calls
```

**After:**
```move
public fun process(values: vector<u64>) {
    let i = 0;
    while (i < vector::length(&values)) {
        let val = *vector::borrow(&values, i);
        let result = val + 1;  // Inlined (1 gas)
        i = i + 1;
    }
}
// Cost: n * 1 gas
```

**Savings:** 99 gas per call

**Note:** Move compiler may inline automatically, but explicit is guaranteed.

### Reduce Native Call Frequency

**Before:**
```move
while (i < n) {
    let hash = sha512(data);  // 500 gas per iteration
    process(hash);
    i = i + 1;
}
// Cost: n * 500 gas
```

**After:**
```move
let hash = sha512(data);  // Hoist out if data doesn't change
while (i < n) {
    process(hash);
    i = i + 1;
}
// Cost: 500 gas total
```

**Savings:** `(n - 1) * 500` gas

---

## Verification-Preserving Optimizations

### Principle: Optimization Must Not Break Proofs

**Safe Optimizations:**
1. **Constant folding**: `5 + 3` → `8`
2. **Dead code elimination**: Remove unreachable code
3. **Common subexpression elimination**: Reuse computed values
4. **Inlining**: Small functions inlined

**Unsafe Without Re-Verification:**
1. **Changing algorithm**: Different implementation
2. **Reordering operations**: May break assumptions
3. **Removing checks**: Security implications

### Example: Safe Optimization

**Original (Verified):**
```lean
theorem transfer_correct :
    let sender_balance' := sender_balance - amount
    let receiver_balance' := receiver_balance + amount
    transfer_result = (sender_balance', receiver_balance') := by
  sorry -- Verified
```

**Optimized:**
```move
// Before: Two separate operations
let sender_balance' = sender_balance - amount;
let receiver_balance' = receiver_balance + amount;

// After: Combine computations (same result)
let (sender_balance', receiver_balance') = (sender_balance - amount, receiver_balance + amount);
```

**Verification:**
```lean
theorem optimized_correct :
    transfer_result_optimized = transfer_result_original := by
  unfold transfer_result_optimized transfer_result_original
  rfl  -- Definitionally equal
```

### Example: Unsafe Optimization (Without Re-Verification)

**Original:**
```move
// Checked subtraction
let result = checked_sub(balance, amount);
assert!(result.is_some(), UNDERFLOW);
```

**Unsafe Optimization:**
```move
// Unchecked subtraction (BREAKS VERIFICATION!)
let result = balance - amount;  // May underflow!
```

**Why Unsafe:**
Verified property assumes overflow checking. Removing check invalidates proof.

---

## Cost-Benefit Analysis

### Optimization Decision Framework

**Questions:**
1. **What's the gas savings?** Measure precisely.
2. **What's the implementation cost?** Hours of engineering.
3. **What's the verification cost?** Hours of proof work.
4. **What's the maintenance cost?** Complexity increase.
5. **What's the risk?** Probability of introducing bugs.

**Decision Matrix:**

| Gas Savings | Implementation Cost | Verification Cost | Decision |
|-------------|-------------------|-------------------|----------|
| >1000 gas | <1 day | <1 day | ✅ Do it |
| >500 gas | <3 days | <3 days | ✅ Do it |
| >100 gas | <1 day | <1 day | ✅ Do it |
| <100 gas | >1 day | >1 day | ❌ Not worth it |
| <50 gas | Any | Any | ❌ Skip |

### Example: Batch Verification Analysis

**Savings:**
- Single proof: 1101 gas
- Batch of 5: ~600 gas each → 501 gas saved per proof
- Expected use: 1000 transactions/day with 5 proofs each
- Annual savings: 1000 * 5 * 501 * 365 = ~914M gas

**Costs:**
- Implementation: 2 days (Rust + Move)
- Verification: 3 days (Lean proofs for batch algorithm)
- Maintenance: Low (well-studied algorithm)
- Risk: Low (standard cryptographic technique)

**Decision:** ✅ High-priority optimization

### Example: Vector Pre-allocation Analysis

**Savings:**
- ~5 gas per allocation avoided
- Expected: 10 vectors created per transaction
- Annual savings: 1000 * 10 * 5 * 365 = ~18M gas

**Costs:**
- Implementation: 2 hours (add `empty_with_capacity`)
- Verification: 1 day (prove capacity doesn't affect correctness)
- Maintenance: Low
- Risk: Very low

**Decision:** ✅ Low-hanging fruit

---

## Benchmarking and Testing

### Regression Testing

**Benchmark Suite:**
```move
module gas_benchmarks {
    #[test]
    public fun bench_registration() {
        let gas = measure_gas(|| {
            confidential_asset::register(account, pubkey, proof);
        });
        assert!(gas < 5000, gas);  // Budget: 5K gas
    }
    
    #[test]
    public fun bench_transfer() {
        let gas = measure_gas(|| {
            confidential_asset::transfer(sender, receiver, 1000, proof);
        });
        assert!(gas < 8000, gas);  // Budget: 8K gas
    }
    
    #[test]
    public fun bench_withdrawal() {
        let gas = measure_gas(|| {
            confidential_asset::withdraw(account, 500, proof);
        });
        assert!(gas < 7000, gas);  // Budget: 7K gas
    }
}
```

### Continuous Monitoring

**CI/CD Integration:**
```yaml
name: Gas Benchmarks

on: [push, pull_request]

jobs:
  gas-benchmarks:
    runs-on: ubuntu-latest
    steps:
      - name: Run benchmarks
        run: |
          cargo test --package gas-benchmarks --release -- --nocapture > gas_results.txt
      
      - name: Check regressions
        run: |
          python3 scripts/check_gas_regression.py \
            --baseline gas_baseline.json \
            --current gas_results.txt \
            --threshold 5  # 5% regression tolerance
      
      - name: Update baseline (if on main)
        if: github.ref == 'refs/heads/main'
        run: |
          cp gas_results.txt gas_baseline.json
          git add gas_baseline.json
          git commit -m "Update gas baseline"
```

---

## Cost Budgets and Monitoring

### Budget Allocation

**Per-Operation Budgets:**
```lean
def operationGasBudgets : List (Operation × Nat) :=
  [ (Registration, 5000)
  , (Transfer, 8000)
  , (Withdrawal, 7000)
  , (Normalization, 6000)
  , (KeyRotation, 5500)
  ]
```

**Budget Breakdown (Transfer):**
```
Transfer (8000 gas budget):
├─ Proof verification: 4000 gas (50%)
├─ Storage access: 2000 gas (25%)
├─ Balance updates: 1500 gas (19%)
└─ Overhead: 500 gas (6%)
```

### Monitoring Dashboard

**Metrics:**
```python
# gas_monitoring.py

class GasMetrics:
    def track_operation(self, op_type, gas_used):
        self.metrics[op_type].append(gas_used)
    
    def check_budget(self, op_type, gas_used):
        budget = BUDGETS[op_type]
        if gas_used > budget:
            alert(f"{op_type} exceeded budget: {gas_used} > {budget}")
    
    def percentile(self, op_type, p):
        return numpy.percentile(self.metrics[op_type], p)
    
    def report(self):
        for op_type in OPERATION_TYPES:
            print(f"{op_type}:")
            print(f"  Mean: {self.mean(op_type)}")
            print(f"  P50: {self.percentile(op_type, 50)}")
            print(f"  P95: {self.percentile(op_type, 95)}")
            print(f"  P99: {self.percentile(op_type, 99)}")
            print(f"  Budget: {BUDGETS[op_type]}")
```

---

## Cross-References

### Related Documentation

**Implementation:**
- `MOVE_BYTECODE_AND_VM_EXECUTION_DEEP_DIVE.md` - VM execution details
- `SIGMA_PROTOCOL_THEORY_AND_PRACTICE.md` - Cryptographic costs

**Verification:**
- `ADVANCED_LEAN_PROOF_TECHNIQUES_GUIDE.md` - Optimization verification
- `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md` - Testing

**Monitoring:**
- `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md` - Continuous monitoring
- `QUARTERLY_VERIFICATION_MAINTENANCE_AND_REVIEW_PROCEDURES.md` - Reviews

---

## Maintenance

### Document Ownership

- **Author**: Performance team, Protocol team
- **Reviewers**: Gas optimization experts, Verification team
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Feedback

Gas optimization questions or new techniques?
- **Performance**: performance-team@movementlabs.xyz
- **Verification**: verification-team@movementlabs.xyz

---

**End of Guide**

Total pages: ~33 (~27K characters)
