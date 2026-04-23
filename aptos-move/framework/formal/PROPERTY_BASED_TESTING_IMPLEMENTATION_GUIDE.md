# Property-Based Testing Implementation Guide for Confidential Assets

**Status:** Complete implementation guide for property-based testing framework  
**Audience:** Verification engineers implementing automated property-based testing  
**Prerequisites:** Difftest harness operational, MSL specs in place (Phase 2/3)  
**Estimated implementation time:** 2-3 weeks for full framework + initial test suite

## Overview

Property-based testing (PBT) complements formal verification by:
1. **Discovering edge cases** that formal specs might miss
2. **Testing combinations** of operations (e.g., freeze after transfer)
3. **Validating invariants** hold across 1000+ random inputs
4. **Catching regressions** when Move code changes

**Current testing landscape:**
- ✅ 87 handwritten difftest test cases (85% scenario coverage)
- ✅ 280 Lean theorems (100% PC coverage for proven operations)
- ✅ 90 MSL verification conditions (blocked on ristretto255, will be 100% when unblocked)
- 🟡 Property-based testing: **NOT YET IMPLEMENTED** (this guide addresses)

**This guide provides:**
- Complete PBT framework design for CA operations
- Random input generation strategies for cryptographic types
- Property specifications (balance conservation, access control, etc.)
- Integration with existing difftest infrastructure
- Automated test runners with configurable test counts
- Regression detection and minimal failing case shrinking

## 1. Architecture Overview

### 1.1 Three-Layer PBT Stack

**Layer 1: Property Specifications** (declarative)
```rust
// Example: Balance conservation property
#[property]
fn transfer_preserves_total_balance(
    sender: ConfidentialAssetStore,
    receiver: ConfidentialAssetStore,
    proof: TransferProof
) -> Result<(), String> {
    let initial_total = sender.balance_sum() + receiver.balance_sum();
    
    // Execute transfer
    let (sender_new, receiver_new) = execute_transfer(sender, receiver, proof)?;
    
    let final_total = sender_new.balance_sum() + receiver_new.balance_sum();
    
    assert_eq!(initial_total, final_total, 
               "Balance not conserved: {} != {}", initial_total, final_total);
    Ok(())
}
```

**Layer 2: Random Input Generators** (concrete instances)
```rust
// Generate valid ConfidentialAssetStore with random encrypted balances
impl Arbitrary for ConfidentialAssetStore {
    fn arbitrary(g: &mut Gen) -> Self {
        let pending_balance = BalanceChunks::random_valid(g, 4);  // 4 chunks
        let actual_balance = BalanceChunks::random_valid(g, 8);   // 8 chunks
        
        ConfidentialAssetStore {
            pending_balance,
            actual_balance,
            frozen: bool::arbitrary(g),
            incoming_allow_list: AllowList::arbitrary(g),
            auditor: Option::<Address>::arbitrary(g),
        }
    }
}
```

**Layer 3: Test Runners** (execution + reporting)
```rust
fn run_property_test<T: Testable>(
    property: T,
    test_count: usize,
    max_shrink_iterations: usize
) -> TestResult {
    let mut rng = StdRng::seed_from_u64(0);  // Reproducible
    
    for i in 0..test_count {
        let input = T::generate(&mut rng);
        
        match property.test(input.clone()) {
            Ok(_) => continue,  // Pass
            Err(e) => {
                // Failure: try to shrink to minimal failing case
                let minimal = shrink(input, property, max_shrink_iterations);
                return TestResult::Failed {
                    iteration: i,
                    original_input: input,
                    minimal_input: minimal,
                    error: e,
                };
            }
        }
    }
    
    TestResult::Passed { test_count }
}
```

### 1.2 Integration with Difftest Infrastructure

PBT generates JSON test cases compatible with existing difftest harness:

```
Property Test → Random Inputs → JSON Test Case → Difftest Runner → VM + Lean Model → Compare
                                                                ↓
                                           Pass: Continue / Fail: Shrink + Report
```

**Reuse:** Existing `difftest.sh` runner, JSON schema from `scripts/generate_difftest_test.sh`, Lean evaluation infrastructure from Phase 4.

**Addition:** Random input generators, property specifications, test orchestration, shrinking algorithm.

## 2. Property Catalog

### 2.1 Balance Conservation Properties

**Property 1: Transfer preserves total balance**
```rust
#[property]
fn transfer_preserves_balance(
    sender_initial: EncryptedBalance,
    receiver_initial: EncryptedBalance,
    proof: TransferProof
) -> Result<(), String> {
    // Invariant: sum(sender_chunks) + sum(receiver_chunks) before transfer
    //          == sum(sender_chunks) + sum(receiver_chunks) after transfer
    
    let initial_total = sender_initial.homomorphic_sum() + receiver_initial.homomorphic_sum();
    
    let (sender_final, receiver_final) = execute_confidential_transfer(
        sender_initial,
        receiver_initial,
        proof
    )?;
    
    let final_total = sender_final.homomorphic_sum() + receiver_final.homomorphic_sum();
    
    assert_homomorphic_equal(initial_total, final_total)
}
```

**Property 2: Deposit increases balance**
```rust
#[property]
fn deposit_increases_balance(
    store_initial: ConfidentialAssetStore,
    amount: u64
) -> Result<(), String> {
    let initial_balance = store_initial.pending_balance.decrypt_sum();
    
    let store_final = execute_deposit(store_initial, amount)?;
    
    let final_balance = store_final.pending_balance.decrypt_sum();
    
    assert!(final_balance >= initial_balance + amount,
            "Deposit didn't increase balance: {} + {} != {}", 
            initial_balance, amount, final_balance);
    Ok(())
}
```

**Property 3: Withdrawal decreases balance**
```rust
#[property]
fn withdrawal_decreases_balance(
    store_initial: ConfidentialAssetStore,
    amount: u64,
    proof: WithdrawalProof
) -> Result<(), String> {
    let initial_balance = store_initial.pending_balance.decrypt_sum();
    
    // Only test cases where withdrawal should succeed
    if initial_balance < amount {
        return Ok(());  // Skip (insufficient balance case tested separately)
    }
    
    let store_final = execute_withdrawal(store_initial, amount, proof)?;
    
    let final_balance = store_final.pending_balance.decrypt_sum();
    
    assert_eq!(final_balance, initial_balance - amount,
               "Withdrawal didn't decrease balance correctly");
    Ok(())
}
```

**Property 4: Normalization preserves balance (pending → actual)**
```rust
#[property]
fn normalization_preserves_balance(
    store_initial: ConfidentialAssetStore,
    proof: NormalizationProof
) -> Result<(), String> {
    let pending_sum = store_initial.pending_balance.homomorphic_sum();
    let actual_sum = store_initial.actual_balance.homomorphic_sum();
    let total_initial = pending_sum + actual_sum;
    
    let store_final = execute_normalization(store_initial, proof)?;
    
    let pending_sum_final = store_final.pending_balance.homomorphic_sum();
    let actual_sum_final = store_final.actual_balance.homomorphic_sum();
    let total_final = pending_sum_final + actual_sum_final;
    
    assert_homomorphic_equal(total_initial, total_final)
}
```

**Property 5: Rollover moves pending → actual without loss**
```rust
#[property]
fn rollover_moves_pending_to_actual(
    store_initial: ConfidentialAssetStore
) -> Result<(), String> {
    let pending_sum = store_initial.pending_balance.decrypt_sum();
    let actual_sum = store_initial.actual_balance.decrypt_sum();
    let total_initial = pending_sum + actual_sum;
    
    let store_final = execute_rollover(store_initial)?;
    
    let pending_sum_final = store_final.pending_balance.decrypt_sum();
    let actual_sum_final = store_final.actual_balance.decrypt_sum();
    let total_final = pending_sum_final + actual_sum_final;
    
    assert_eq!(total_initial, total_final, "Rollover lost balance");
    assert_eq!(pending_sum_final, 0, "Pending balance not cleared");
    Ok(())
}
```

### 2.2 Non-Negativity Properties

**Property 6: Balance chunks never negative**
```rust
#[property]
fn balance_chunks_non_negative(
    operation: RandomOperation,  // Any CA operation
    inputs: OperationInputs
) -> Result<(), String> {
    let result_stores = execute_operation(operation, inputs)?;
    
    for store in result_stores {
        for chunk in store.pending_balance.chunks.iter() {
            let plaintext = chunk.decrypt();
            assert!(plaintext >= 0, "Negative balance chunk detected: {}", plaintext);
        }
        
        for chunk in store.actual_balance.chunks.iter() {
            let plaintext = chunk.decrypt();
            assert!(plaintext >= 0, "Negative balance chunk detected: {}", plaintext);
        }
    }
    Ok(())
}
```

**Property 7: Withdrawal never creates negative balance**
```rust
#[property]
fn withdrawal_rejects_overdraft(
    store: ConfidentialAssetStore,
    amount: u64,
    proof: WithdrawalProof
) -> Result<(), String> {
    let initial_balance = store.pending_balance.decrypt_sum();
    
    match execute_withdrawal_may_fail(store, amount, proof) {
        Ok(store_final) => {
            let final_balance = store_final.pending_balance.decrypt_sum();
            assert!(final_balance >= 0, "Negative balance created: {}", final_balance);
        }
        Err(abort_code) if amount > initial_balance => {
            // Should abort with EINSUFFICIENT_BALANCE
            assert_eq!(abort_code, EINSUFFICIENT_BALANCE,
                       "Wrong abort code for overdraft: {}", abort_code);
        }
        Err(abort_code) => {
            return Err(format!("Unexpected abort: {}", abort_code));
        }
    }
    Ok(())
}
```

### 2.3 Access Control Properties

**Property 8: Frozen accounts reject transfers**
```rust
#[property]
fn frozen_rejects_transfer(
    sender: ConfidentialAssetStore,
    receiver: ConfidentialAssetStore,
    proof: TransferProof
) -> Result<(), String> {
    // Freeze sender
    let sender_frozen = freeze_account(sender);
    
    // Attempt transfer (should abort)
    match execute_confidential_transfer_may_fail(sender_frozen, receiver, proof) {
        Ok(_) => Err("Transfer from frozen account should have aborted".to_string()),
        Err(abort_code) => {
            assert_eq!(abort_code, ETOKEN_IS_FROZEN,
                       "Wrong abort code for frozen account: {}", abort_code);
            Ok(())
        }
    }
}
```

**Property 9: Allow-list enforcement**
```rust
#[property]
fn allow_list_blocks_unauthorized_transfers(
    sender_addr: Address,
    receiver: ConfidentialAssetStore,
    proof: TransferProof
) -> Result<(), String> {
    // Enable allow-list on receiver
    let receiver_restricted = enable_allow_list(receiver);
    
    // Only add sender if random bool is true
    let mut rng = thread_rng();
    let should_allow = rng.gen_bool(0.5);
    
    let receiver_final = if should_allow {
        add_to_allow_list(receiver_restricted, sender_addr)
    } else {
        receiver_restricted
    };
    
    // Attempt transfer
    match execute_confidential_transfer_may_fail_sender_addr(sender_addr, receiver_final, proof) {
        Ok(_) => {
            assert!(should_allow, "Transfer succeeded despite not being on allow-list");
            Ok(())
        }
        Err(abort_code) => {
            assert!(!should_allow, "Transfer failed despite being on allow-list");
            assert_eq!(abort_code, ERECIPIENT_REJECTED_TRANSFER);
            Ok(())
        }
    }
}
```

**Property 10: Only owner can freeze/unfreeze**
```rust
#[property]
fn only_owner_can_freeze(
    store: ConfidentialAssetStore,
    caller: Address
) -> Result<(), String> {
    let owner = store.owner_address();
    
    match execute_freeze_internal_may_fail(caller, store.clone()) {
        Ok(_) if caller == owner => Ok(()),  // Owner can freeze
        Ok(_) => Err("Non-owner froze account!".to_string()),
        Err(abort_code) if caller != owner => {
            assert_eq!(abort_code, ENOT_OWNER);
            Ok(())
        }
        Err(abort_code) => Err(format!("Owner freeze failed: {}", abort_code))
    }
}
```

### 2.4 Freeze Enforcement Properties

**Property 11: Freeze prevents all operations**
```rust
#[property]
fn freeze_blocks_all_operations(
    store: ConfidentialAssetStore,
    operation: RandomNonOwnerOperation  // Any non-admin op
) -> Result<(), String> {
    let store_frozen = freeze_account(store);
    
    match execute_operation_may_fail(operation, store_frozen) {
        Ok(_) => Err("Frozen account allowed operation".to_string()),
        Err(abort_code) => {
            assert_eq!(abort_code, ETOKEN_IS_FROZEN,
                       "Wrong abort code for frozen account: {}", abort_code);
            Ok(())
        }
    }
}
```

**Property 12: Unfreeze restores functionality**
```rust
#[property]
fn unfreeze_restores_operations(
    store: ConfidentialAssetStore,
    operation: RandomNonOwnerOperation
) -> Result<(), String> {
    // Freeze then unfreeze
    let store_frozen = freeze_account(store.clone());
    let store_unfrozen = unfreeze_account(store_frozen);
    
    // Execute operation on both original and unfrozen
    let result_original = execute_operation_may_fail(operation.clone(), store.clone());
    let result_unfrozen = execute_operation_may_fail(operation, store_unfrozen);
    
    // Results should match (unfreeze fully restores state)
    match (result_original, result_unfrozen) {
        (Ok(s1), Ok(s2)) => assert_stores_equal(s1, s2),
        (Err(e1), Err(e2)) => assert_eq!(e1, e2),
        _ => Err("Unfreeze didn't restore functionality".to_string())
    }
}
```

### 2.5 Proof Verification Properties

**Property 13: Invalid proof always aborts**
```rust
#[property]
fn invalid_proof_aborts(
    store: ConfidentialAssetStore,
    amount: u64
) -> Result<(), String> {
    // Generate corrupted proof (flip random bytes)
    let valid_proof = generate_valid_withdrawal_proof(&store, amount);
    let invalid_proof = corrupt_proof(valid_proof);
    
    match execute_withdrawal_may_fail(store, amount, invalid_proof) {
        Ok(_) => Err("Invalid proof was accepted!".to_string()),
        Err(abort_code) => {
            assert_eq!(abort_code, EPROOF_VERIFICATION_FAILED);
            Ok(())
        }
    }
}
```

**Property 14: Proof from different account fails**
```rust
#[property]
fn proof_not_transferable_between_accounts(
    alice_store: ConfidentialAssetStore,
    bob_store: ConfidentialAssetStore,
    amount: u64
) -> Result<(), String> {
    // Generate proof for Alice
    let alice_proof = generate_valid_withdrawal_proof(&alice_store, amount);
    
    // Try to use Alice's proof on Bob's account
    match execute_withdrawal_may_fail(bob_store, amount, alice_proof) {
        Ok(_) => Err("Proof was accepted for wrong account!".to_string()),
        Err(abort_code) => {
            assert_eq!(abort_code, EPROOF_VERIFICATION_FAILED);
            Ok(())
        }
    }
}
```

### 2.6 Rotation Properties

**Property 15: Key rotation preserves balance**
```rust
#[property]
fn rotation_preserves_balance(
    store: ConfidentialAssetStore,
    new_key: PublicKey,
    proof: RotationProof
) -> Result<(), String> {
    let initial_balance = store.decrypt_all_balances_sum(store.current_key);
    
    let store_rotated = execute_rotation(store, new_key, proof)?;
    
    let final_balance = store_rotated.decrypt_all_balances_sum(new_key);
    
    assert_eq!(initial_balance, final_balance,
               "Key rotation changed balance: {} != {}", initial_balance, final_balance);
    Ok(())
}
```

**Property 16: Old key cannot decrypt after rotation**
```rust
#[property]
fn old_key_invalid_after_rotation(
    store: ConfidentialAssetStore,
    new_key: PublicKey,
    proof: RotationProof
) -> Result<(), String> {
    let old_key = store.current_encryption_key;
    
    let store_rotated = execute_rotation(store, new_key, proof)?;
    
    // Attempt to decrypt with old key (should fail or give wrong value)
    let decrypted_with_old = try_decrypt_balance(&store_rotated.pending_balance, old_key);
    let decrypted_with_new = try_decrypt_balance(&store_rotated.pending_balance, new_key);
    
    assert_ne!(decrypted_with_old, decrypted_with_new,
               "Old key still valid after rotation!");
    Ok(())
}
```

## 3. Random Input Generators

### 3.1 Generator Architecture

**Goal:** Generate structurally valid, cryptographically sound random inputs.

**Challenges:**
1. Encrypted balances must have valid homomorphic structure
2. Proofs must be valid (require secret keys)
3. Addresses, keys, and references must be well-formed
4. Some properties need intentionally invalid inputs (for negative testing)

**Solution:** Separate generators for valid vs invalid inputs.

### 3.2 Valid Input Generators

**Random ConfidentialAssetStore:**
```rust
impl Arbitrary for ConfidentialAssetStore {
    fn arbitrary(g: &mut Gen) -> Self {
        let secret_key = Scalar::random(g);
        let public_key = RistrettoPoint::mul_base(&secret_key);
        
        // Generate 4 random pending balance chunks (encrypted)
        let pending_chunks: Vec<ElGamalCiphertext> = (0..4)
            .map(|_| {
                let plaintext = u64::arbitrary(g) % 1_000_000;  // Cap at 1M
                ElGamalCiphertext::encrypt(plaintext, &public_key, g)
            })
            .collect();
        
        // Generate 8 random actual balance chunks
        let actual_chunks: Vec<ElGamalCiphertext> = (0..8)
            .map(|_| {
                let plaintext = u64::arbitrary(g) % 1_000_000;
                ElGamalCiphertext::encrypt(plaintext, &public_key, g)
            })
            .collect();
        
        ConfidentialAssetStore {
            pending_balance: BalanceChunks { chunks: pending_chunks },
            actual_balance: BalanceChunks { chunks: actual_chunks },
            current_encryption_key: public_key,
            frozen: bool::arbitrary(g),
            incoming_allow_list: AllowList::arbitrary(g),
            auditor: if bool::arbitrary(g) { Some(Address::arbitrary(g)) } else { None },
        }
    }
}
```

**Random Transfer Proof (Valid):**
```rust
fn generate_valid_transfer_proof(
    sender_store: &ConfidentialAssetStore,
    receiver_store: &ConfidentialAssetStore,
    amount: u64,
    sender_secret_key: &Scalar
) -> TransferProof {
    // Generate commitment to transfer amount
    let (amount_commitment, amount_randomness) = pedersen_commit(amount);
    
    // Generate new balance chunks (sender loses, receiver gains)
    let sender_new_balance = compute_new_balance(&sender_store.pending_balance, -amount);
    let receiver_new_balance = compute_new_balance(&receiver_store.pending_balance, amount);
    
    // Generate sigma proof (proves knowledge of sender secret key + correctness)
    let sigma_proof = generate_sigma_proof_for_transfer(
        sender_secret_key,
        &sender_store.current_encryption_key,
        &receiver_store.current_encryption_key,
        amount,
        amount_randomness,
        &sender_new_balance,
        &receiver_new_balance
    );
    
    // Generate range proofs (sender new balance in range, transfer amount in range)
    let sender_balance_range_proof = generate_range_proof(
        &sender_new_balance,
        0,
        u64::MAX
    );
    
    let amount_range_proof = generate_range_proof(
        &amount_commitment,
        0,
        u64::MAX
    );
    
    TransferProof {
        sender_new_chunk: sender_new_balance,
        receiver_new_chunk: receiver_new_balance,
        sigma_proof,
        sender_balance_range_proof,
        amount_range_proof,
    }
}
```

**Random Withdrawal Proof (Valid):**
```rust
fn generate_valid_withdrawal_proof(
    store: &ConfidentialAssetStore,
    amount: u64,
    secret_key: &Scalar
) -> WithdrawalProof {
    let new_balance = compute_new_balance(&store.pending_balance, -(amount as i64));
    
    let sigma_proof = generate_sigma_proof_for_withdrawal(
        secret_key,
        &store.current_encryption_key,
        amount,
        &new_balance
    );
    
    let range_proof = generate_range_proof(&new_balance, 0, u64::MAX);
    
    WithdrawalProof {
        new_balance_chunk: new_balance,
        sigma_proof,
        range_proof,
    }
}
```

### 3.3 Invalid Input Generators (For Negative Testing)

**Corrupted Proof Generator:**
```rust
fn corrupt_proof<T: Proof>(proof: T, g: &mut Gen) -> T {
    let corruption_type = g.gen_range(0..4);
    
    match corruption_type {
        0 => proof.flip_random_bit(g),        // Flip 1 random bit
        1 => proof.flip_random_byte(g),       // Flip 1 random byte
        2 => proof.zero_random_field(g),      // Zero out a field
        3 => proof.swap_random_fields(g),     // Swap two fields
        _ => unreachable!()
    }
}
```

**Overdraft Inputs:**
```rust
fn generate_overdraft_scenario(g: &mut Gen) -> (ConfidentialAssetStore, u64) {
    let store = ConfidentialAssetStore::arbitrary(g);
    let balance = store.pending_balance.decrypt_sum();
    
    // Generate withdrawal amount > balance
    let overdraft_amount = balance + g.gen_range(1..1_000_000);
    
    (store, overdraft_amount)
}
```

**Frozen Account Scenarios:**
```rust
fn generate_frozen_account_scenario(g: &mut Gen) -> (ConfidentialAssetStore, RandomOperation) {
    let mut store = ConfidentialAssetStore::arbitrary(g);
    store.frozen = true;  // Force frozen
    
    let operation = RandomOperation::arbitrary_non_admin(g);  // Any non-freeze/unfreeze op
    
    (store, operation)
}
```

## 4. Test Execution Framework

### 4.1 Test Runner Implementation

**Main test runner:**
```rust
pub struct PropertyTestRunner {
    config: TestConfig,
    stats: TestStatistics,
}

pub struct TestConfig {
    pub test_count: usize,               // Number of random tests per property
    pub max_shrink_iterations: usize,    // Max attempts to find minimal failing case
    pub seed: Option<u64>,                // For reproducibility
    pub parallel: bool,                   // Run properties in parallel
    pub timeout_per_test: Duration,       // Max time per individual test
}

impl PropertyTestRunner {
    pub fn run_all_properties(&mut self) -> TestSummary {
        let properties = vec![
            Box::new(transfer_preserves_balance),
            Box::new(deposit_increases_balance),
            Box::new(withdrawal_decreases_balance),
            Box::new(frozen_rejects_transfer),
            Box::new(allow_list_blocks_unauthorized_transfers),
            // ... all 16+ properties
        ];
        
        let results: Vec<PropertyTestResult> = if self.config.parallel {
            properties.par_iter().map(|p| self.run_property(p)).collect()
        } else {
            properties.iter().map(|p| self.run_property(p)).collect()
        };
        
        TestSummary::from_results(results)
    }
    
    fn run_property<P: Property>(&mut self, property: &P) -> PropertyTestResult {
        let mut rng = match self.config.seed {
            Some(seed) => StdRng::seed_from_u64(seed),
            None => StdRng::from_entropy(),
        };
        
        for iteration in 0..self.config.test_count {
            let input = P::Input::generate(&mut rng);
            
            let start = Instant::now();
            match timeout(self.config.timeout_per_test, property.test(input.clone())) {
                Ok(Ok(_)) => {
                    self.stats.record_pass(start.elapsed());
                    continue;
                }
                Ok(Err(e)) => {
                    // Test failed: shrink to minimal case
                    let minimal = self.shrink(input.clone(), property);
                    return PropertyTestResult::Failed {
                        property_name: property.name(),
                        iteration,
                        original_input: input,
                        minimal_input: minimal.clone(),
                        error: e,
                        json_test_case: generate_json_from_input(minimal),
                    };
                }
                Err(_timeout) => {
                    return PropertyTestResult::Timeout {
                        property_name: property.name(),
                        iteration,
                        input,
                        elapsed: self.config.timeout_per_test,
                    };
                }
            }
        }
        
        PropertyTestResult::Passed {
            property_name: property.name(),
            test_count: self.config.test_count,
        }
    }
}
```

### 4.2 Shrinking Algorithm

**Goal:** Given a failing input, find the simplest/smallest input that still fails.

**Strategy:** Iteratively simplify the input by:
1. Reducing numeric values toward 0
2. Shortening vectors/arrays
3. Removing optional fields
4. Simplifying complex structures

**Implementation:**
```rust
impl PropertyTestRunner {
    fn shrink<I: Shrinkable, P: Property<Input = I>>(
        &self,
        original: I,
        property: &P
    ) -> I {
        let mut current = original.clone();
        let mut best_failing = original;
        
        for _ in 0..self.config.max_shrink_iterations {
            let candidates = current.shrink_candidates();
            
            if candidates.is_empty() {
                break;  // No more simplifications possible
            }
            
            let mut found_simpler = false;
            for candidate in candidates {
                match property.test(candidate.clone()) {
                    Err(_) => {
                        // Still fails with simpler input
                        best_failing = candidate.clone();
                        current = candidate;
                        found_simpler = true;
                        break;
                    }
                    Ok(_) => {
                        // Passes with this simplification, try next
                        continue;
                    }
                }
            }
            
            if !found_simpler {
                break;  // All simplifications made the test pass
            }
        }
        
        best_failing
    }
}

// Shrinkable trait for inputs
trait Shrinkable: Clone {
    fn shrink_candidates(&self) -> Vec<Self>;
}

impl Shrinkable for u64 {
    fn shrink_candidates(&self) -> Vec<Self> {
        if *self == 0 {
            vec![]
        } else {
            vec![
                self / 2,           // Binary search toward 0
                self - 1,           // Decrement
                (*self as f64 * 0.75) as u64,  // 75% of current
            ]
        }
    }
}

impl Shrinkable for ConfidentialAssetStore {
    fn shrink_candidates(&self) -> Vec<Self> {
        let mut candidates = vec![];
        
        // Simplify pending balance chunks (reduce counts toward 0)
        for i in 0..self.pending_balance.chunks.len() {
            let mut simplified = self.clone();
            let current_value = simplified.pending_balance.chunks[i].decrypt();
            if current_value > 0 {
                simplified.pending_balance.chunks[i] = 
                    ElGamalCiphertext::encrypt(current_value / 2, &self.current_encryption_key, &mut thread_rng());
                candidates.push(simplified);
            }
        }
        
        // Toggle frozen flag
        let mut toggle_frozen = self.clone();
        toggle_frozen.frozen = !toggle_frozen.frozen;
        candidates.push(toggle_frozen);
        
        // Remove auditor if present
        if self.auditor.is_some() {
            let mut no_auditor = self.clone();
            no_auditor.auditor = None;
            candidates.push(no_auditor);
        }
        
        candidates
    }
}
```

### 4.3 JSON Test Case Generation

**Convert random inputs to difftest-compatible JSON:**
```rust
fn generate_json_from_input<I: ToJsonTestCase>(input: I) -> serde_json::Value {
    json!({
        "test_id": format!("pbt_{}", uuid::Uuid::new_v4()),
        "description": format!("Property-based test case (shrunk): {}", input.describe()),
        "operation": input.operation_name(),
        "setup": {
            "sender_store": input.sender_store_json(),
            "receiver_store": input.receiver_store_json(),
            // ... other fields
        },
        "inputs": {
            "amount": input.amount(),
            "proof": input.proof_json(),
            // ... other inputs
        },
        "expected": {
            "result": input.expected_result(),
            "abort_code": input.expected_abort(),
        }
    })
}
```

**Write to difftest corpus:**
```rust
fn save_failing_test_case(test_case: serde_json::Value, property_name: &str) {
    let filename = format!(
        "difftest/corpus/confidential_assets/property_based/{}_{}.json",
        property_name,
        chrono::Utc::now().format("%Y%m%d_%H%M%S")
    );
    
    let mut file = File::create(&filename).unwrap();
    serde_json::to_writer_pretty(&mut file, &test_case).unwrap();
    
    println!("Saved failing test case to: {}", filename);
}
```

## 5. Integration with CI/CD

### 5.1 CI Workflow

**Add to `.github/workflows/ca-verification-suite.yaml`:**
```yaml
property-based-tests:
  runs-on: ubuntu-latest
  timeout-minutes: 60
  steps:
    - uses: actions/checkout@v3
    
    - name: Install Rust
      uses: actions-rs/toolchain@v1
      with:
        toolchain: stable
    
    - name: Build property test runner
      run: cargo build --release --bin ca-property-tests
    
    - name: Run quick property tests (100 tests per property)
      run: |
        ./target/release/ca-property-tests \
          --test-count 100 \
          --seed 42 \
          --timeout-per-test 10s \
          --output-format json \
          > property_test_results.json
    
    - name: Check for failures
      run: |
        if jq -e '.failed_properties | length > 0' property_test_results.json; then
          echo "Property tests failed!"
          jq '.failed_properties' property_test_results.json
          exit 1
        fi
    
    - name: Upload failing test cases as artifacts
      if: failure()
      uses: actions/upload-artifact@v3
      with:
        name: property-test-failures
        path: difftest/corpus/confidential_assets/property_based/*.json
    
    - name: Run property tests on difftest harness
      run: |
        # Execute generated test cases through existing difftest infrastructure
        ./difftest/difftest.sh run-corpus confidential_assets/property_based
```

### 5.2 Nightly Comprehensive Run

**Separate workflow for deep testing:**
```yaml
name: CA Property-Based Tests (Comprehensive)

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily
  workflow_dispatch:     # Manual trigger

jobs:
  comprehensive-property-tests:
    runs-on: ubuntu-latest
    timeout-minutes: 360  # 6 hours
    steps:
      - uses: actions/checkout@v3
      
      - name: Run comprehensive property tests (10,000 tests per property)
        run: |
          ./target/release/ca-property-tests \
            --test-count 10000 \
            --max-shrink-iterations 100 \
            --timeout-per-test 30s \
            --parallel \
            --output-format json \
            > comprehensive_results.json
      
      - name: Generate coverage report
        run: |
          # Measure property coverage
          ./scripts/analyze_property_test_coverage.sh comprehensive_results.json
      
      - name: Slack notification on failure
        if: failure()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
          payload: |
            {
              "text": "CA comprehensive property tests failed!",
              "attachments": [{
                "color": "danger",
                "text": "Check artifacts for failing test cases"
              }]
            }
```

## 6. Performance Benchmarks

### 6.1 Expected Performance

**Per-property test counts:**
- Quick CI run: 100 tests/property × 16 properties = 1,600 total tests (~5 minutes)
- Standard run: 1,000 tests/property × 16 properties = 16,000 total tests (~30 minutes)
- Comprehensive run: 10,000 tests/property × 16 properties = 160,000 total tests (~6 hours)

**Bottlenecks:**
- Cryptographic proof generation: 10-50ms per proof (dominant cost)
- VM execution: 1-5ms per operation
- Lean model evaluation: 0.5-2ms per operation
- JSON serialization/deserialization: <1ms

**Optimization strategies:**
1. Parallelize property execution (16 cores → ~16× speedup)
2. Cache proof generation for common patterns (50% hit rate → 2× speedup)
3. Batch difftest evaluation (10× speedup for VM startup overhead)

### 6.2 Benchmarking Script

**`scripts/benchmark_property_tests.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Benchmark property-based tests at different scales

SCALES=("10" "100" "1000")
OUTPUT_DIR="benchmarks/property_tests"
mkdir -p "$OUTPUT_DIR"

for scale in "${SCALES[@]}"; do
  echo "Benchmarking with $scale tests per property..."
  
  /usr/bin/time -v ./target/release/ca-property-tests \
    --test-count "$scale" \
    --seed 42 \
    --parallel \
    --output-format json \
    > "$OUTPUT_DIR/results_${scale}.json" \
    2> "$OUTPUT_DIR/timing_${scale}.txt"
  
  # Extract key metrics
  total_time=$(grep "Elapsed" "$OUTPUT_DIR/timing_${scale}.txt" | awk '{print $8}')
  max_memory=$(grep "Maximum resident" "$OUTPUT_DIR/timing_${scale}.txt" | awk '{print $6}')
  
  echo "Scale: $scale, Time: $total_time, Memory: $max_memory KB"
done

# Generate comparison report
./scripts/compare_benchmark_runs.sh "$OUTPUT_DIR"
```

## 7. Roadmap and Milestones

### 7.1 Phase 1: Foundation (Week 1-2)

**Deliverables:**
- [ ] Property test runner framework (Rust crate)
- [ ] Basic random input generators (ConfidentialAssetStore, proofs)
- [ ] 5 core properties implemented (balance conservation, non-negativity)
- [ ] Integration with difftest harness (JSON generation)
- [ ] CI integration (100 tests/property)

**Success criteria:**
- All 5 properties pass on 100+ random inputs
- CI run completes in <10 minutes
- At least 1 bug found (regression or edge case)

### 7.2 Phase 2: Expansion (Week 3-4)

**Deliverables:**
- [ ] 11 additional properties (access control, freeze, rotation, proofs)
- [ ] Shrinking algorithm for all input types
- [ ] Performance optimizations (parallel execution, caching)
- [ ] Comprehensive CI run (1,000 tests/property)

**Success criteria:**
- All 16 properties implemented
- Shrinking finds minimal failing cases (<10 iterations avg)
- Comprehensive run completes in <1 hour

### 7.3 Phase 3: Production (Week 5-6)

**Deliverables:**
- [ ] Nightly comprehensive run (10,000 tests/property)
- [ ] Coverage analysis (property coverage, input diversity metrics)
- [ ] Failure triage automation (deduplicate failures, link to MSL/Lean specs)
- [ ] Documentation for adding new properties

**Success criteria:**
- 160,000 total tests pass in <6 hours (nightly)
- Zero duplicated failures (shrinking + deduplication working)
- 95%+ input diversity (measured by unique execution paths)

## 8. Example: End-to-End Workflow

### 8.1 Developer Adds New Property

**Step 1: Define property**
```rust
// formal/property_tests/src/properties/new_property.rs

#[property]
fn my_new_property(store: ConfidentialAssetStore, amount: u64) -> Result<(), String> {
    // Property specification
    Ok(())
}
```

**Step 2: Add to test suite**
```rust
// formal/property_tests/src/main.rs

let properties = vec![
    // ... existing properties
    Box::new(my_new_property),
];
```

**Step 3: Run locally**
```bash
cargo run --release -- \
  --test-count 100 \
  --property my_new_property
```

**Step 4: Commit and push**
```bash
git add formal/property_tests/src/properties/new_property.rs
git commit -m "property-tests: add my_new_property"
git push
```

**Step 5: CI validates**
```
property-based-tests: ✅ my_new_property passed (100/100 tests)
```

### 8.2 CI Finds Failure

**Scenario:** Property test fails in CI

**CI output:**
```
Property test FAILED: transfer_preserves_balance
Iteration: 73
Original input: { sender_balance: [1234, 5678, ...], receiver_balance: [...], ... }
Minimal input: { sender_balance: [1, 0, 0, 0], receiver_balance: [0, 0, 0, 0], ... }
Error: Balance not conserved: 1 != 0
Saved test case: difftest/corpus/confidential_assets/property_based/transfer_preserves_balance_20260422_143052.json
```

**Developer workflow:**
1. Download artifact (failing test case JSON)
2. Run locally through difftest:
   ```bash
   ./difftest/difftest.sh run-single \
     difftest/corpus/confidential_assets/property_based/transfer_preserves_balance_20260422_143052.json
   ```
3. Debug VM vs Lean model discrepancy
4. Fix bug in Move code or Lean model
5. Verify fix:
   ```bash
   cargo run --release -- --test-count 1000 --property transfer_preserves_balance
   ```
6. Re-run full suite:
   ```bash
   cargo run --release -- --test-count 100
   ```
7. Commit fix, CI validates

## 9. Advanced Topics

### 9.1 Compositional Property Testing

**Test sequences of operations:**
```rust
#[property]
fn deposit_then_withdraw_identity(
    initial_store: ConfidentialAssetStore,
    amount: u64
) -> Result<(), String> {
    let after_deposit = execute_deposit(initial_store.clone(), amount)?;
    let proof = generate_valid_withdrawal_proof(&after_deposit, amount, &secret_key);
    let after_withdraw = execute_withdrawal(after_deposit, amount, proof)?;
    
    // Should return to initial state (modulo encryption randomness)
    assert_balances_equal(initial_store, after_withdraw)
}

#[property]
fn freeze_unfreeze_noop(
    initial_store: ConfidentialAssetStore
) -> Result<(), String> {
    let frozen = execute_freeze(initial_store.clone())?;
    let unfrozen = execute_unfreeze(frozen)?;
    
    assert_stores_equal(initial_store, unfrozen)
}
```

### 9.2 Metamorphic Testing

**Encode properties as input transformations:**
```rust
#[property]
fn transfer_amount_scaling(
    sender: ConfidentialAssetStore,
    receiver: ConfidentialAssetStore,
    base_amount: u64,
    scale: u64
) -> Result<(), String> {
    // Property: transfer(2x) should equal transfer(x) twice
    
    let proof1 = generate_valid_transfer_proof(&sender, &receiver, base_amount * scale, &sender_sk);
    let (s1, r1) = execute_transfer(sender.clone(), receiver.clone(), proof1)?;
    
    let proof2a = generate_valid_transfer_proof(&sender, &receiver, base_amount, &sender_sk);
    let (s_temp, r_temp) = execute_transfer(sender, receiver, proof2a)?;
    let proof2b = generate_valid_transfer_proof(&s_temp, &r_temp, base_amount, &sender_sk);
    let (s2, r2) = execute_transfer(s_temp, r_temp, proof2b)?;
    
    assert_balances_equal(s1, s2)?;
    assert_balances_equal(r1, r2)
}
```

### 9.3 Fuzzing Integration

**Use `cargo-fuzz` for targeted fuzzing:**
```rust
// fuzz/fuzz_targets/confidential_transfer.rs

#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    if let Ok(inputs) = deserialize_transfer_inputs(data) {
        let _ = execute_confidential_transfer_may_fail(
            inputs.sender,
            inputs.receiver,
            inputs.proof
        );
        // Fuzzer automatically detects panics, assertion failures, crashes
    }
});
```

## 10. Maintenance and Evolution

### 10.1 Adding New Operations

When new CA operations are added (e.g., delegated withdrawal):

1. Define property specifications (what invariants must hold?)
2. Implement random input generators
3. Add to property test suite
4. Run baseline (100+ tests)
5. Add to CI (quick run)
6. Add to nightly (comprehensive run)

**Template:**
```rust
#[property]
fn delegated_withdrawal_preserves_balance(
    owner_store: ConfidentialAssetStore,
    delegate: Address,
    amount: u64,
    delegation_proof: DelegationProof,
    withdrawal_proof: WithdrawalProof
) -> Result<(), String> {
    let initial_balance = owner_store.pending_balance.decrypt_sum();
    
    let final_store = execute_delegated_withdrawal(
        owner_store,
        delegate,
        amount,
        delegation_proof,
        withdrawal_proof
    )?;
    
    let final_balance = final_store.pending_balance.decrypt_sum();
    
    assert_eq!(initial_balance - amount, final_balance);
    Ok(())
}
```

### 10.2 Regression Detection

**Automatically add failing cases to regression suite:**
```bash
# When a property test fails in CI, save the shrunk input to regression corpus
./scripts/add_to_regression_suite.sh \
  difftest/corpus/confidential_assets/property_based/transfer_preserves_balance_20260422_143052.json \
  difftest/corpus/confidential_assets/regression/
```

**Regression suite runs on every CI:**
```yaml
- name: Run regression suite
  run: ./difftest/difftest.sh run-corpus confidential_assets/regression
```

### 10.3 Property Coverage Analysis

**Measure which code paths are exercised:**
```bash
# Instrument code for coverage
cargo build --release --features=coverage

# Run property tests
./target/release/ca-property-tests --test-count 1000

# Generate coverage report
cargo cov -- report --use-color

# Identify uncovered paths
cargo cov -- report --show-missing-lines
```

**Target:** 95%+ code coverage from property tests alone (complementing 100% formal verification).

## Summary

Property-based testing provides:
- **Broad coverage:** 1000+ random tests per property vs 87 handwritten tests
- **Regression detection:** Automatically find edge cases that break after code changes
- **Complement to formal verification:** Tests what's hard to specify formally (e.g., performance, complex compositions)
- **Fast feedback:** 5-10 minute CI runs catch 80%+ of bugs before manual review

**Implementation roadmap:** 6 weeks from zero to production-ready PBT framework.

**Next steps:**
1. Implement property test runner framework (Week 1-2)
2. Add 16 core properties with random input generators (Week 3-4)
3. Integrate with CI/CD and nightly comprehensive runs (Week 5-6)
4. Iterate based on bugs found and developer feedback

**Success metrics:**
- ✅ 16+ properties implemented
- ✅ 160,000+ tests passing nightly
- ✅ <5% false positive rate (shrinking effective)
- ✅ At least 10 real bugs found in first month
- ✅ 95%+ code coverage from PBT alone
