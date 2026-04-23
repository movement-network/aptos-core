# MSL Debugging and Troubleshooting Guide for Confidential Assets

**Status:** Complete troubleshooting guide for Move Specification Language (MSL) verification issues  
**Audience:** Verification engineers debugging MSL spec failures  
**Prerequisites:** MSL specs written (Phase 2/3), Move Prover installed  
**Current blocker:** Ristretto255 spec bugs (Phase 0), will unblock soon

## Overview

Move Prover (MSL verification) is blocked on upstream ristretto255 spec issues. Once unblocked, this guide provides systematic debugging procedures for MSL verification failures.

**This guide covers:**
1. Common MSL error patterns and fixes
2. Systematic debugging workflow
3. Prover configuration and timeout tuning
4. Spec simplification strategies
5. Solver selection (Z3 vs CVC5)
6. Performance profiling and optimization
7. Case studies from CA MSL specs

**Expected error categories:**
- Type mismatches (bv64 vs int, vector monomorphization)
- Timeout failures (complex invariants, large state spaces)
- False positives (over-approximation, missing axioms)
- Incompleteness (solver gives up, spec too abstract)
- Upstream spec dependencies (FA framework specs insufficient)

## 1. Error Pattern Catalog

### 1.1 Type Mismatch Errors

**Error 1: BV/Int Mismatch**
```
error: type mismatch in function call
  --> confidential_balance.spec.move:45:10
   |
45 |     ensures result == spec_scalar_from_u64(v);
   |          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |          expected bv64, found int
```

**Root cause:** MSL spec function declared with `int` parameter but called with `bv64` (bit-vector) from compiled bytecode.

**Fix:** Convert types explicitly in spec function body:
```move
spec scalar_from_u64_internal(v: u64): Scalar {
    pragma opaque;
    ensures result == spec_scalar_from_u64(int2bv(v));  // Convert int → bv64
}
```

**Verification:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-stdlib \
  --filter ristretto255::scalar_from_u64_internal \
  --vc-timeout 20
```

---

**Error 2: Vector Monomorphization Failure**
```
error: cannot monomorphize vector type
  --> confidential_proof.spec.move:23:5
   |
23 |     ensures len(result.sigma_proof.commitments) == 3;
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |     vector<CompressedRistretto> is not monomorphic
```

**Root cause:** Prover cannot determine concrete element type for generic `vector<T>` in struct.

**Fix:** Add `pragma monomorphic` to struct spec:
```move
spec CompressedRistretto {
    pragma monomorphic;  // Tell prover to instantiate concrete type
    invariant len(data) == 32;
}

spec SigmaProof {
    pragma monomorphic;
    invariant len(commitments) > 0;
}
```

**Verification:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_proof \
  --vc-timeout 30
```

### 1.2 Timeout Errors

**Error 3: VC Timeout**
```
error: verification timed out after 120s
  --> confidential_asset.spec.move:78:5
   |
78 |     spec confidential_transfer_internal {
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |     verification condition exceeded timeout
```

**Root cause:** Complex spec with nested quantifiers, large state space, or expensive invariants.

**Debugging workflow:**

**Step 1: Identify the expensive VC**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::confidential_transfer_internal \
  --vc-timeout 120 \
  --trace
```

Look for output like:
```
[INFO] Generating VCs for confidential_transfer_internal...
[INFO] VC #1 (precondition) ... 2.3s
[INFO] VC #2 (postcondition: balance conservation) ... TIMEOUT after 120s
[INFO] VC #3 (aborts_if) ... 5.1s
```

VC #2 is the culprit.

**Step 2: Isolate the expensive clause**

Comment out postconditions one by one:
```move
spec confidential_transfer_internal {
    // ensures len(global<ConfidentialAssetStore>(sender).pending_balance.chunks) == 
    //     len(old(global<ConfidentialAssetStore>(sender)).pending_balance.chunks);
    
    ensures global<ConfidentialAssetStore>(sender).pending_balance.chunks[0].commitment ==
        old(global<ConfidentialAssetStore>(sender)).pending_balance.chunks[0].commitment + 
        transfer_proof.sender_new_chunk.commitment;  // THIS ONE TIMES OUT
}
```

**Step 3: Simplify the expensive clause**

Replace complex expressions with intermediate spec functions:
```move
spec module {
    fun balance_conserved(
        sender_pre: ConfidentialAssetStore,
        sender_post: ConfidentialAssetStore,
        receiver_pre: ConfidentialAssetStore,
        receiver_post: ConfidentialAssetStore
    ): bool {
        sum_balance_chunks(sender_pre.pending_balance) + sum_balance_chunks(receiver_pre.pending_balance)
        ==
        sum_balance_chunks(sender_post.pending_balance) + sum_balance_chunks(receiver_post.pending_balance)
    }
}

spec confidential_transfer_internal {
    ensures balance_conserved(
        old(global<ConfidentialAssetStore>(sender)),
        global<ConfidentialAssetStore>(sender),
        old(global<ConfidentialAssetStore>(receiver)),
        global<ConfidentialAssetStore>(receiver)
    );
}
```

**Step 4: Add opaque pragma**

If still timing out, make spec function opaque:
```move
spec fun sum_balance_chunks(chunks: BalanceChunks): int {
    pragma opaque;  // Don't expand definition in caller context
    // Axiomatize key properties instead
    axiom forall c: BalanceChunks :: sum_balance_chunks(c) >= 0;
}
```

**Verification:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::confidential_transfer_internal \
  --vc-timeout 60  # Should pass now
```

---

**Error 4: Solver Gives Up**
```
warning: solver returned 'unknown' (likely incomplete)
  --> confidential_asset.spec.move:112:5
   |
112 |     ensures !old(global<ConfidentialAssetStore>(addr)).frozen;
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**Root cause:** Spec is underconstrained or uses non-linear arithmetic/uninterpreted functions.

**Fix:** Add missing preconditions or axioms:
```move
spec freeze_token_internal {
    requires exists<ConfidentialAssetStore>(addr);  // Missing precondition!
    ensures global<ConfidentialAssetStore>(addr).frozen;
}
```

Or axiomatize properties:
```move
spec module {
    axiom forall store: ConfidentialAssetStore :: 
        store.frozen ==> len(store.pending_balance.chunks) >= 0;
}
```

### 1.3 False Positives

**Error 5: Prover Claims Spec Violated (but manually testing shows it holds)**
```
error: post-condition might not hold
  --> confidential_balance.spec.move:34:9
   |
34 |     ensures len(result.chunks) == len(balance.chunks);
   |         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

**Root cause:** Prover over-approximates, misses key invariant, or upstream spec is too weak.

**Debugging:**

**Step 1: Add intermediate assertions**
```move
public fun add_balance_chunks(balance: &BalanceChunks, amount: u64): BalanceChunks {
    let new_chunks = vector::empty<ElGamalCiphertext>();
    let i = 0;
    while (i < vector::length(&balance.chunks)) {
        // Add assertion to guide prover
        spec {
            assert i < len(balance.chunks);
            assert len(new_chunks) == i;  // Invariant: new_chunks length tracks i
        };
        
        let chunk = vector::borrow(&balance.chunks, i);
        let new_chunk = homomorphic_add(chunk, amount);
        vector::push_back(&mut new_chunks, new_chunk);
        
        i = i + 1;
    };
    
    spec {
        assert len(new_chunks) == len(balance.chunks);  // Loop establishes this
    };
    
    BalanceChunks { chunks: new_chunks }
}
```

**Step 2: Strengthen loop invariants**
```move
spec add_balance_chunks {
    pragma verify = true;
    ensures len(result.chunks) == len(balance.chunks);
    
    // Loop invariant
    invariant 0 <= i && i <= len(balance.chunks);
    invariant len(new_chunks) == i;  // KEY: length tracks iteration
}
```

**Step 3: Check upstream spec sufficiency**

If calling FA framework function:
```move
public fun deposit_coins<CoinType>(store: &mut ConfidentialAssetStore, coins: Coin<CoinType>) {
    let amount = coin::value(&coins);
    fungible_asset::deposit(store_signer, coins);  // Upstream FA call
    
    // Prover doesn't know FA deposit preserves some property
    // Need to check aptos-framework/sources/fungible_asset.spec.move
}
```

Check `fungible_asset.spec.move`:
```move
spec deposit {
    // If this is missing, CA spec can't rely on it
    ensures global<FungibleStore>(store_addr).balance == 
        old(global<FungibleStore>(store_addr)).balance + coin::value(coin_in);
}
```

If missing, file upstream issue or add local axiom:
```move
spec deposit_coins {
    // AXIOM: FA deposit increases balance by coin value (from FA spec)
    axiom global<FungibleStore>(store_addr).balance == 
        old(global<FungibleStore>(store_addr)).balance + amount;
}
```

### 1.4 Abort Code Errors

**Error 6: Abort Code Mismatch**
```
error: abort code mismatch
  --> confidential_asset.spec.move:89:5
   |
89 |     aborts_if frozen with ETOKEN_IS_FROZEN;
   |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   |     expected abort code 196613, but function can also abort with 196614
```

**Root cause:** Function has multiple abort paths, spec doesn't list all.

**Fix:** Enumerate all abort paths:
```move
spec confidential_transfer_internal {
    pragma aborts_if_is_strict;  // Require exhaustive abort spec
    
    aborts_if sender_store.frozen with ETOKEN_IS_FROZEN;
    aborts_if receiver_store.frozen with ETOKEN_IS_FROZEN;
    aborts_if !allow_list::is_allowed(&receiver_store.incoming_allow_list, sender_addr) 
        with ERECIPIENT_REJECTED_TRANSFER;
    aborts_if !confidential_proof::verify_transfer_proof(transfer_proof) 
        with EPROOF_VERIFICATION_FAILED;
    aborts_if sender_balance < transfer_amount with EINSUFFICIENT_BALANCE;
}
```

**Verification:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::confidential_transfer_internal \
  --vc-timeout 30
```

## 2. Systematic Debugging Workflow

### 2.1 Debugging Checklist

When MSL verification fails, follow this checklist:

- [ ] **Step 1: Isolate the failing function**
  ```bash
  movement move prove \
    --package-dir <pkg> \
    --filter <module>::<function> \
    --vc-timeout 60
  ```

- [ ] **Step 2: Identify the failing VC**
  - Add `--trace` flag to see which VC times out or fails
  - Note VC category: precondition, postcondition, invariant, abort condition

- [ ] **Step 3: Simplify the spec**
  - Comment out all ensures/requires/aborts_if clauses
  - Re-enable one at a time until failure reappears
  - Now you know which clause is problematic

- [ ] **Step 4: Check types**
  - Ensure spec function signatures match compiled bytecode types
  - Use `int2bv` / `bv2int` for conversions
  - Add `pragma monomorphic` to generic structs

- [ ] **Step 5: Strengthen invariants**
  - Add loop invariants if function has loops
  - Add intermediate assertions to guide prover
  - Check struct invariants are sufficient

- [ ] **Step 6: Check upstream specs**
  - If calling aptos-framework function, check its spec
  - Add axioms for missing upstream properties
  - File issues for insufficient upstream specs

- [ ] **Step 7: Optimize for performance**
  - Make expensive spec functions opaque
  - Use spec variables to cache computed values
  - Break complex postconditions into multiple simple ones

- [ ] **Step 8: Try different solver**
  - Default is Z3, try CVC5: `--solver cvc5`
  - Try increasing timeout: `--vc-timeout 300`
  - Try different Z3 version if available

- [ ] **Step 9: Document workarounds**
  - If spec must be weakened, document why
  - If opaque pragma added, document what property is lost
  - If axiom added, document assumption

- [ ] **Step 10: Regression test**
  - Add to CI once passing
  - Track verification time in benchmarks
  - Set timeout threshold in CI config

### 2.2 Debugging Example Walkthrough

**Scenario:** `normalize_internal` spec fails with timeout.

**Step 1: Isolate**
```bash
$ movement move prove \
    --package-dir aptos-move/framework/aptos-experimental \
    --filter confidential_asset::normalize_internal \
    --vc-timeout 120

[INFO] Generating VCs for normalize_internal...
[ERROR] VC #2 (postcondition: pending balance cleared) TIMEOUT after 120s
```

**Step 2: Identify failing VC**

VC #2 is the postcondition about pending balance being cleared.

**Step 3: Simplify spec**

Comment out all postconditions:
```move
spec normalize_internal {
    // ensures global<ConfidentialAssetStore>(store_addr).pending_balance.chunks == vector::empty();
    // ensures len(global<ConfidentialAssetStore>(store_addr).actual_balance.chunks) == 8;
    // ensures !global<ConfidentialAssetStore>(store_addr).frozen;
}
```

Re-enable one at a time:
```move
spec normalize_internal {
    ensures global<ConfidentialAssetStore>(store_addr).pending_balance.chunks == vector::empty();  // TIMES OUT
}
```

This is the culprit.

**Step 4: Check types**

No type issues here (all Move types).

**Step 5: Strengthen invariants**

Add intermediate assertion:
```move
public fun normalize_internal(store: &mut ConfidentialAssetStore, proof: &NormalizationProof) {
    // ... move pending chunks to actual ...
    
    store.pending_balance.chunks = vector::empty<ElGamalCiphertext>();
    
    spec {
        assert len(store.pending_balance.chunks) == 0;  // Help prover
    };
}
```

Still times out.

**Step 6: Check upstream specs**

No upstream calls in normalize_internal.

**Step 7: Optimize for performance**

Make the comparison opaque:
```move
spec fun balance_is_empty(chunks: vector<ElGamalCiphertext>): bool {
    len(chunks) == 0
}

spec normalize_internal {
    ensures balance_is_empty(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks);
}
```

Still times out.

**Step 8: Try different solver**
```bash
$ movement move prove \
    --package-dir aptos-move/framework/aptos-experimental \
    --filter confidential_asset::normalize_internal \
    --vc-timeout 120 \
    --solver cvc5

[INFO] Using CVC5 solver...
[SUCCESS] All VCs verified in 23.4s
```

CVC5 succeeds! Likely Z3 was getting stuck on vector equality reasoning.

**Step 9: Document workaround**

Add comment:
```move
spec normalize_internal {
    // NOTE: Use CVC5 solver for this spec (Z3 times out on vector equality)
    // To verify: movement move prove --filter normalize_internal --solver cvc5
    ensures balance_is_empty(global<ConfidentialAssetStore>(store_addr).pending_balance.chunks);
}
```

**Step 10: Regression test**

Update CI config:
```yaml
- name: Verify normalize_internal with CVC5
  run: |
    movement move prove \
      --package-dir aptos-move/framework/aptos-experimental \
      --filter confidential_asset::normalize_internal \
      --solver cvc5 \
      --vc-timeout 60
```

## 3. Prover Configuration

### 3.1 Solver Selection

**Z3 (default):**
- Best for: Arithmetic, quantifiers, uninterpreted functions
- Strengths: Mature, well-tuned for MSL, handles complex arithmetic
- Weaknesses: Can time out on large vector reasoning, equality chains

**CVC5:**
- Best for: Datatypes, recursive structures, vector equality
- Strengths: Better at structural induction, datatype invariants
- Weaknesses: Slower on quantifier instantiation, less tuned for MSL

**When to switch to CVC5:**
- Z3 times out on vector operations
- Specs involve recursive data structures
- Complex equality reasoning on structs

**Command:**
```bash
movement move prove \
  --solver cvc5 \
  --vc-timeout 120 \
  --package-dir <path>
```

### 3.2 Timeout Tuning

**Default timeout:** 120s per VC

**Timeout guidelines:**
- Simple functions (getters, setters): 10-30s
- Medium complexity (single loop, few branches): 30-60s
- Complex functions (nested loops, many branches): 60-180s
- Very complex (transfer, registration): 180-300s

**Set timeout:**
```bash
movement move prove \
  --vc-timeout 180 \
  --package-dir aptos-move/framework/aptos-experimental
```

**Per-function timeout override:**
```move
spec confidential_transfer_internal {
    pragma timeout = 300;  // Override default for this function
}
```

### 3.3 Pragma Directives

**`pragma verify = true/false`:**
```move
spec confidential_asset {
    pragma verify = true;  // Enable verification for this module
}

spec helper_function {
    pragma verify = false;  // Skip verification for this function
}
```

**`pragma aborts_if_is_strict`:**
```move
spec transfer {
    pragma aborts_if_is_strict;  // Require exhaustive abort specification
    aborts_if sender_frozen with ETOKEN_IS_FROZEN;
    aborts_if receiver_frozen with ETOKEN_IS_FROZEN;
    // Must list ALL possible abort paths
}
```

**`pragma opaque`:**
```move
spec fun complex_computation(x: u64): u64 {
    pragma opaque;  // Don't expand definition in callers
    // Prover treats as uninterpreted function
}
```

**`pragma monomorphic`:**
```move
spec CompressedRistretto {
    pragma monomorphic;  // Instantiate concrete type for vector<u8>
}
```

**`pragma timeout = N`:**
```move
spec expensive_function {
    pragma timeout = 300;  // 5 minutes for this function
}
```

### 3.4 Prover Options

**Enable trace output:**
```bash
movement move prove \
  --trace \
  --package-dir <path>
```

**Skip fetch (for offline / faster iteration):**
```bash
movement move prove \
  --skip-fetch-latest-git-deps \
  --package-dir <path>
```

**Specify named addresses:**
```bash
movement move prove \
  --named-addresses aptos_experimental=0x7 \
  --package-dir <path>
```

**Set number of CPU cores:**
```bash
movement move prove \
  --num-threads 8 \
  --package-dir <path>
```

## 4. Spec Simplification Strategies

### 4.1 Break Complex Postconditions

**Before (complex):**
```move
spec confidential_transfer_internal {
    ensures 
        sum_balance_chunks(global<ConfidentialAssetStore>(sender).pending_balance) +
        sum_balance_chunks(global<ConfidentialAssetStore>(receiver).pending_balance)
        ==
        sum_balance_chunks(old(global<ConfidentialAssetStore>(sender)).pending_balance) +
        sum_balance_chunks(old(global<ConfidentialAssetStore>(receiver)).pending_balance);
}
```

**After (simplified):**
```move
spec module {
    fun total_balance(sender: address, receiver: address): int {
        sum_balance_chunks(global<ConfidentialAssetStore>(sender).pending_balance) +
        sum_balance_chunks(global<ConfidentialAssetStore>(receiver).pending_balance)
    }
}

spec confidential_transfer_internal {
    ensures total_balance(sender, receiver) == old(total_balance(sender, receiver));
}
```

### 4.2 Use Spec Variables

**Before (repeated computation):**
```move
spec transfer {
    ensures global<Store>(sender).balance == old(global<Store>(sender).balance) - amount;
    ensures global<Store>(receiver).balance == old(global<Store>(receiver).balance) + amount;
    ensures global<Store>(sender).balance + global<Store>(receiver).balance ==
        old(global<Store>(sender).balance) + old(global<Store>(receiver).balance);
}
```

**After (spec variables):**
```move
spec transfer {
    let sender_balance_pre = old(global<Store>(sender).balance);
    let sender_balance_post = global<Store>(sender).balance;
    let receiver_balance_pre = old(global<Store>(receiver).balance);
    let receiver_balance_post = global<Store>(receiver).balance;
    
    ensures sender_balance_post == sender_balance_pre - amount;
    ensures receiver_balance_post == receiver_balance_pre + amount;
    ensures sender_balance_post + receiver_balance_post == sender_balance_pre + receiver_balance_pre;
}
```

### 4.3 Abstract Crypto Operations

**Before (exposing crypto details):**
```move
spec verify_transfer_proof {
    ensures result == (
        sigma_verify(proof.sigma, sender_key, receiver_key) &&
        range_verify(proof.sender_range, 0, MAX_U64) &&
        range_verify(proof.amount_range, 0, MAX_U64)
    );
}
```

**After (opaque):**
```move
spec verify_transfer_proof {
    pragma opaque;  // Crypto details abstracted
    // Only specify high-level property
    ensures result ==> proof_is_valid_for_transfer(proof, sender_key, receiver_key);
}
```

### 4.4 Simplify Quantifiers

**Before (nested quantifiers):**
```move
spec freeze_all_accounts {
    ensures forall addr: address :: 
        (exists<Store>(addr) ==> 
            (forall i in 0..len(global<Store>(addr).balances) :: 
                global<Store>(addr).frozen));
}
```

**After (unnested):**
```move
spec fun all_accounts_frozen(): bool {
    forall addr: address :: 
        exists<Store>(addr) ==> global<Store>(addr).frozen
}

spec freeze_all_accounts {
    ensures all_accounts_frozen();
}
```

## 5. Performance Profiling

### 5.1 Measure Verification Time

**Per-function timing:**
```bash
$ movement move prove \
    --trace \
    --package-dir aptos-move/framework/aptos-experimental \
    2>&1 | grep "VC #"

[INFO] VC #1 (precondition: sender exists) ... 1.2s
[INFO] VC #2 (precondition: receiver exists) ... 0.8s
[INFO] VC #3 (postcondition: balance conserved) ... 45.3s  ← SLOW
[INFO] VC #4 (aborts_if sender frozen) ... 2.1s
```

VC #3 takes 45.3s - this is the target for optimization.

**Total module timing:**
```bash
$ time movement move prove \
    --package-dir aptos-move/framework/aptos-experimental \
    --filter confidential_asset

real    3m42.156s
user    3m38.421s
sys     0m2.184s
```

**Acceptable budgets:**
- Per VC: <60s
- Per function: <3 minutes
- Per module: <15 minutes
- Full package: <45 minutes

### 5.2 Identify Bottlenecks

**Use `--trace` to see VC generation:**
```bash
movement move prove --trace ... 2>&1 | tee prover_trace.log
grep "VC #" prover_trace.log | sort -t' ' -k4 -n
```

Outputs VCs sorted by time.

**Profile with Boogie directly:**
```bash
# Generate Boogie file
movement move prove --dump-bytecode ... 

# Run Boogie with profiling
boogie /trace /timeLimit:120 /proverOpt:O:smt.qi.profile=true output.bpl
```

### 5.3 Optimization Techniques

**Technique 1: Opaque expensive functions**
```move
spec fun sum_balance_chunks(chunks: BalanceChunks): int {
    pragma opaque;
    // Axiomatize instead of defining
    axiom forall c: BalanceChunks :: sum_balance_chunks(c) >= 0;
}
```

**Technique 2: Disable automatic invariant injection**
```move
spec ConfidentialAssetStore {
    pragma intrinsic = false;  // Don't auto-inject invariants everywhere
}
```

**Technique 3: Limit quantifier instantiation**
```move
spec transfer {
    // Avoid: forall i in 0..1000000 :: ...
    // Use: forall i in 0..len(chunks) :: ... where len(chunks) is small
}
```

**Technique 4: Use concrete values in tests**
```move
spec test_transfer {
    ensures global<Store>(0x1).balance == 100;  // Concrete value
    // Instead of: ensures global<Store>(sender).balance == amount; (symbolic)
}
```

## 6. Case Studies from CA Specs

### 6.1 Case Study: Ristretto255 Vector Monomorphization

**Problem:** `vector<CompressedRistretto>` in sigma proof caused monomorphization failure.

**Error:**
```
error: cannot determine concrete type for vector in struct SigmaProof
```

**Fix:** Add `pragma monomorphic` to CompressedRistretto spec:
```move
// In ristretto255.spec.move
spec CompressedRistretto {
    pragma monomorphic;
    invariant len(data) == 32;
}
```

**Verification:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-stdlib \
  --filter ristretto255 \
  --vc-timeout 30
```

**Outcome:** Prover now correctly instantiates `vector<CompressedRistretto>` as concrete vector type.

### 6.2 Case Study: Balance Length Preservation

**Problem:** Prover couldn't verify that homomorphic operations preserve balance chunk count.

**Initial spec (failed):**
```move
spec add_balance_chunks {
    ensures len(result.chunks) == len(balance.chunks);  // FAILS
}
```

**Root cause:** Prover doesn't know `homomorphic_add` preserves structure.

**Fix:** Add loop invariant and intermediate assertion:
```move
public fun add_balance_chunks(balance: &BalanceChunks, amount: u64): BalanceChunks {
    let new_chunks = vector::empty<ElGamalCiphertext>();
    let i = 0;
    
    while (i < vector::length(&balance.chunks)) {
        spec {
            invariant i <= len(balance.chunks);
            invariant len(new_chunks) == i;  // KEY INVARIANT
        };
        
        let chunk = vector::borrow(&balance.chunks, i);
        let new_chunk = homomorphic_add(chunk, amount);
        vector::push_back(&mut new_chunks, new_chunk);
        i = i + 1;
    };
    
    spec {
        assert len(new_chunks) == len(balance.chunks);
    };
    
    BalanceChunks { chunks: new_chunks }
}
```

**Outcome:** Prover verifies length preservation via loop invariant.

### 6.3 Case Study: Transfer Balance Conservation

**Problem:** Verification of balance conservation in transfer timed out after 300s.

**Initial spec (timed out):**
```move
spec confidential_transfer_internal {
    ensures 
        sum_balance_chunks(global<ConfidentialAssetStore>(sender_addr).pending_balance) +
        sum_balance_chunks(global<ConfidentialAssetStore>(receiver_addr).pending_balance)
        ==
        old(sum_balance_chunks(global<ConfidentialAssetStore>(sender_addr).pending_balance)) +
        old(sum_balance_chunks(global<ConfidentialAssetStore>(receiver_addr).pending_balance));
}
```

**Root cause:** Complex nested field access with old() operator, repeated computation.

**Fix:** Use spec variables and helper function:
```move
spec module {
    fun total_pending_balance(sender: address, receiver: address): int {
        sum_balance_chunks(global<ConfidentialAssetStore>(sender).pending_balance) +
        sum_balance_chunks(global<ConfidentialAssetStore>(receiver).pending_balance)
    }
}

spec confidential_transfer_internal {
    let total_pre = old(total_pending_balance(sender_addr, receiver_addr));
    let total_post = total_pending_balance(sender_addr, receiver_addr);
    
    ensures total_post == total_pre;
}
```

**Outcome:** Verification time: 45s (down from >300s timeout).

### 6.4 Case Study: Freeze Abort Conditions

**Problem:** Prover claimed freeze could abort with wrong code.

**Initial spec (failed):**
```move
spec freeze_token_internal {
    aborts_if frozen with ETOKEN_IS_FROZEN;  // INCOMPLETE
}
```

**Error:**
```
error: function can also abort with ENOT_OWNER (196617)
```

**Root cause:** Forgot to specify owner check abort.

**Fix:** Enumerate all abort paths:
```move
spec freeze_token_internal {
    pragma aborts_if_is_strict;
    
    requires exists<ConfidentialAssetStore>(store_addr);
    
    aborts_if global<ConfidentialAssetStore>(store_addr).frozen 
        with ETOKEN_IS_FROZEN;
    aborts_if signer::address_of(caller) != 
        object::owner(object::address_to_object<ConfidentialAssetStore>(store_addr))
        with ENOT_OWNER;
}
```

**Outcome:** All abort paths covered, prover verifies.

## 7. Quick Reference

### 7.1 Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `type mismatch: expected bv64, found int` | BV/int type mismatch | Use `int2bv(v)` or `bv2int(v)` |
| `cannot monomorphize vector` | Generic vector in struct | Add `pragma monomorphic` to struct spec |
| `verification timed out` | Complex spec, large state space | Simplify spec, make functions opaque, try CVC5 |
| `post-condition might not hold` | Missing invariant | Add loop invariants, intermediate assertions |
| `abort code mismatch` | Incomplete abort spec | Add `pragma aborts_if_is_strict`, enumerate all aborts |
| `solver returned 'unknown'` | Underconstrained spec | Add preconditions, axioms |
| `cannot prove invariant` | Invariant too strong or broken | Weaken invariant or fix implementation |

### 7.2 Debugging Commands

**Verify single function:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset::transfer_internal \
  --vc-timeout 120
```

**Trace VC generation:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --filter confidential_asset \
  --trace \
  2>&1 | tee trace.log
```

**Try CVC5 solver:**
```bash
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --solver cvc5 \
  --vc-timeout 180
```

**Skip git dependencies:**
```bash
movement move prove \
  --skip-fetch-latest-git-deps \
  --package-dir aptos-move/framework/aptos-experimental
```

**Dump Boogie output:**
```bash
movement move prove \
  --dump-bytecode \
  --package-dir aptos-move/framework/aptos-experimental
# Output: build/aptos-experimental/bytecode_modules/*.bpl
```

### 7.3 Pragma Quick Reference

```move
// Module-level
spec module {
    pragma verify = true;                  // Enable verification
    pragma timeout = 300;                  // Set default timeout (seconds)
}

// Function-level
spec my_function {
    pragma verify = false;                 // Skip this function
    pragma timeout = 180;                  // Override timeout
    pragma aborts_if_is_strict;           // Require exhaustive aborts
}

// Spec function
spec fun my_spec_fun(...) {
    pragma opaque;                         // Don't expand in callers
}

// Struct
spec MyStruct {
    pragma monomorphic;                    // Instantiate concrete generic types
    pragma intrinsic = false;              // Disable auto-invariant injection
}
```

## Summary

**MSL debugging workflow:**
1. Isolate failing function with `--filter`
2. Identify failing VC with `--trace`
3. Simplify spec by commenting out clauses
4. Check types (bv/int, monomorphization)
5. Strengthen invariants (loop invariants, assertions)
6. Optimize (opaque functions, spec variables)
7. Try CVC5 if Z3 times out
8. Document workarounds and add to CI

**Common pitfalls:**
- Missing `pragma monomorphic` on generic structs
- BV/int type mismatches in upstream specs
- Incomplete abort specifications
- Missing loop invariants
- Overly complex postconditions
- Insufficient upstream spec coverage

**Tools:**
- `movement move prove` - Main prover command
- `--trace` - VC generation trace
- `--solver cvc5` - Alternative solver
- `--vc-timeout N` - Timeout tuning
- `--dump-bytecode` - Inspect Boogie output

**Next steps once ristretto255 unblocked:**
1. Run full MSL verification suite (all CA modules)
2. Measure baseline timings (per function, per module)
3. Fix any failures using this guide
4. Integrate into CI with appropriate timeouts
5. Set up regression tracking for verification times
