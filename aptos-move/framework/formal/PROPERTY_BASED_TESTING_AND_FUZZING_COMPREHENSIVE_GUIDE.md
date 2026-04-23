# Property-Based Testing and Fuzzing: Comprehensive Guide

**Version:** 1.0  
**Last Updated:** 2026-04-22  
**Audience:** Verification engineers, QA engineers, security researchers  
**Purpose:** Implement comprehensive property-based testing and fuzzing for Confidential Assets verification  

## Overview

Property-based testing (PBT) and fuzzing are critical complements to formal verification. While Lean proves properties hold for ALL inputs (∀x, P(x)), PBT validates that implementation matches specification on MANY randomly generated inputs. This guide provides a complete framework for PBT and fuzzing across all three verification stacks (Lean, MSL, Difftest).

**Key insight:** Formal verification proves correctness under axioms. PBT validates axioms match reality and catches bugs in specs themselves.

**Coverage goals:**
- **Lean model validation:** 10K+ random inputs verify Lean simulation matches Move VM
- **MSL spec validation:** 5K+ inputs verify MSL contracts catch real bugs
- **Oracle validation:** 1K+ inputs verify cryptographic oracles behave correctly
- **Cross-stack consistency:** 100% of operations tested across all three stacks

---

## Table of Contents

1. [Property-Based Testing Fundamentals](#property-based-testing-fundamentals)
2. [PBT for Lean Proofs](#pbt-for-lean-proofs)
3. [PBT for MSL Specifications](#pbt-for-msl-specifications)
4. [Fuzzing Move Bytecode](#fuzzing-move-bytecode)
5. [Oracle Property Testing](#oracle-property-testing)
6. [Cross-Stack Differential Testing](#cross-stack-differential-testing)
7. [Mutation Testing for Specifications](#mutation-testing-for-specifications)
8. [Corpus Generation and Management](#corpus-generation-and-management)
9. [Coverage Metrics and Goals](#coverage-metrics-and-goals)
10. [CI/CD Integration](#cicd-integration)
11. [Case Studies](#case-studies)
12. [Troubleshooting and Debugging](#troubleshooting-and-debugging)

---

## Property-Based Testing Fundamentals

### What is Property-Based Testing?

**Traditional unit testing:**
```rust
#[test]
fn test_transfer_specific() {
    let balance = 100;
    let amount = 30;
    assert_eq!(transfer(balance, amount), 70);
}
```

**Property-based testing:**
```rust
#[quickcheck]
fn test_transfer_property(balance: u64, amount: u64) -> bool {
    if amount <= balance {
        transfer(balance, amount) == balance - amount
    } else {
        // Should fail or abort
        true
    }
}
```

**Difference:**
- Unit test: checks ONE specific input (100, 30)
- Property test: checks THOUSANDS of random inputs, validates property holds for all

### Why PBT for Formal Verification?

**Problem:** Formal verification proves properties hold under ASSUMPTIONS (axioms).  
**Risk:** If axioms are wrong, proofs are meaningless.  
**Solution:** PBT validates assumptions on random inputs.

**Example:**
- **Lean axiom:** `axiom schnorr_soundness : verify(pk, msg, sig) = true → ∃sk, pk = g^sk`
- **PBT validation:** Generate 10K random (pk, msg, sig) tuples, verify axiom holds empirically

### PBT Frameworks

| Language | Framework | Features |
|----------|-----------|----------|
| Rust | `proptest` | Shrinking, stateful testing, custom generators |
| Rust | `quickcheck` | Simple, fast, good for basic properties |
| Lean | `Plausible` | Built-in testing framework (Lean 4) |
| Python | `Hypothesis` | Advanced shrinking, database persistence |
| Move | Custom | We implement generators for Move types |

**Recommendation for CA:** Use `proptest` (Rust) for Move VM testing, `Plausible` for Lean validation.

---

## PBT for Lean Proofs

### Goal: Validate Lean Model Matches Move VM

**Hypothesis:** Lean's `MoveModel.step` function correctly models Move VM execution.

**Property to test:**
```lean
-- For all valid frames, Lean step matches VM step
property step_correctness (frame : Frame) : 
  lean_step frame = vm_step frame
```

**Implementation strategy:**

**1. Generate random valid frames:**
```rust
use proptest::prelude::*;

prop_compose! {
    fn arbitrary_frame()(
        pc in 0..100usize,
        locals in prop::collection::vec(any::<u64>(), 0..10),
        stack in prop::collection::vec(any::<u64>(), 0..10),
    ) -> Frame {
        Frame {
            pc,
            locals: locals.into_iter().map(Value::U64).collect(),
            stack: stack.into_iter().map(Value::U64).collect(),
        }
    }
}
```

**2. Run Lean simulation:**
```lean
-- Evaluate Lean model on test input
def eval_lean_step (frame : Frame) : Result Frame :=
  step env frame cs ms
```

**3. Run Move VM:**
```rust
fn eval_vm_step(frame: &Frame) -> Result<Frame> {
    let mut vm = MoveVM::new();
    vm.execute_instruction(frame)
}
```

**4. Compare results:**
```rust
proptest! {
    #[test]
    fn lean_vm_equivalence(frame in arbitrary_frame()) {
        let lean_result = call_lean_ffi(frame.clone());
        let vm_result = eval_vm_step(&frame);
        assert_eq!(lean_result, vm_result);
    }
}
```

### Handling Invalid Inputs

**Challenge:** Most random frames are INVALID (PC out of bounds, stack underflow, type mismatch).

**Solution 1: Precondition filtering**
```rust
proptest! {
    #[test]
    fn lean_vm_equivalence(frame in arbitrary_frame()) {
        // Filter invalid frames
        prop_assume!(frame.pc < bytecode.len());
        prop_assume!(frame.stack.len() >= required_stack_depth());
        
        // Now test valid frames only
        let lean_result = call_lean_ffi(frame.clone());
        let vm_result = eval_vm_step(&frame);
        assert_eq!(lean_result, vm_result);
    }
}
```

**Solution 2: Generate valid frames only**
```rust
prop_compose! {
    fn valid_frame_for_instruction(instr: Instruction)()(
        // Generate frame that satisfies instruction preconditions
        stack in stack_for_instruction(instr),
        locals in locals_for_instruction(instr),
    ) -> Frame {
        Frame { pc: 0, stack, locals, function_handle: 0 }
    }
}
```

### Shrinking on Failure

**Proptest's killer feature:** When test fails, automatically shrinks input to MINIMAL failing case.

**Example:**
```
Initial failure: Frame { pc: 47, stack: [1,2,3,4,5,6,7], locals: [10,20,30,40,50] }
After shrinking: Frame { pc: 0, stack: [1,2], locals: [10] }
```

**Why this matters:** Minimal failing case is MUCH easier to debug than complex random input.

### Lean-Specific Testing with Plausible

Lean 4 has built-in property testing via `Plausible`:

```lean
import Plausible

-- Define generator for Frame
instance : Plausible Frame where
  plausible := do
    let pc ← plausible (α := Nat)
    let locals ← plausible (α := Array Value)
    let stack ← plausible (α := List Value)
    return { pc, locals, stack }

-- Property test
#check_plausible step_preserves_invariant
-- Runs 100 random tests, reports failures
```

**Limitations:**
- Plausible is slower than Rust proptest (interpreted, not compiled)
- Less mature shrinking
- Good for quick checks, not comprehensive fuzzing

**Recommendation:** Use Plausible for quick iteration, Rust proptest for comprehensive CI testing.

---

## PBT for MSL Specifications

### Goal: Validate MSL Specs Catch Real Bugs

**Problem:** MSL specs can be TOO WEAK (missing constraints) or TOO STRONG (reject valid inputs).

**Property to test:**
```
For all inputs satisfying preconditions:
  - If spec says "succeeds", implementation should succeed
  - If spec says "aborts with X", implementation should abort with X
  - If spec says "ensures P", implementation should satisfy P
```

### Testing MSL Preconditions

**MSL spec:**
```move
spec withdraw_to_internal {
  requires balance >= amount;
  requires amount > 0;
  ensures old(balance) = new(balance) + amount;
  aborts_if balance < amount with EINSUFFICIENT_BALANCE;
}
```

**Property test:**
```rust
proptest! {
    #[test]
    fn msl_preconditions_enforced(
        balance in 0u64..1_000_000,
        amount in 0u64..1_000_000,
    ) {
        let result = withdraw_to_internal(balance, amount);
        
        if balance >= amount && amount > 0 {
            // Preconditions satisfied → should succeed
            assert!(result.is_ok());
        } else if balance < amount {
            // Precondition violated → should abort with specific code
            assert_eq!(result.unwrap_err(), EINSUFFICIENT_BALANCE);
        }
    }
}
```

### Testing MSL Postconditions

**Challenge:** How to check `ensures old(balance) = new(balance) + amount`?

**Solution:** Instrument implementation to capture old/new state:

```rust
#[derive(Debug, Clone)]
struct State {
    balance: u64,
}

proptest! {
    #[test]
    fn msl_postconditions_hold(
        balance in 0u64..1_000_000,
        amount in 0u64..1_000_000,
    ) {
        prop_assume!(balance >= amount && amount > 0);
        
        let old_state = State { balance };
        let new_state = withdraw_to_internal_instrumented(balance, amount);
        
        // Check MSL postcondition
        assert_eq!(old_state.balance, new_state.balance + amount);
    }
}
```

### Differential Testing: MSL vs Move VM

**Gold standard:** MSL spec should match Move VM behavior EXACTLY.

**Property:**
```rust
proptest! {
    #[test]
    fn msl_matches_vm(input in arbitrary_ca_input()) {
        // Run Move VM
        let vm_result = execute_on_vm(input.clone());
        
        // Check MSL spec predictions
        let should_succeed = msl_preconditions_satisfied(&input);
        let expected_abort = msl_expected_abort_code(&input);
        
        match (vm_result, should_succeed) {
            (Ok(_), true) => {
                // MSL said succeed, VM succeeded ✓
            }
            (Err(code), false) => {
                // MSL said abort, VM aborted
                assert_eq!(code, expected_abort); // Codes must match
            }
            _ => {
                panic!("MSL spec mismatch with VM behavior!");
            }
        }
    }
}
```

**This catches:**
- MSL spec too weak (VM aborts, MSL allows)
- MSL spec too strong (VM succeeds, MSL forbids)
- Wrong abort codes (MSL says 65537, VM aborts with 65538)

---

## Fuzzing Move Bytecode

### Goal: Find Bytecode Sequences That Crash VM or Violate Invariants

**Fuzzing strategy:**
1. Generate random bytecode sequences
2. Execute on Move VM
3. Check invariants: no crashes, no undefined behavior, resource safety

### Bytecode Fuzzer Architecture

```rust
use proptest::prelude::*;

// Generate random bytecode instruction
fn arbitrary_instruction() -> impl Strategy<Value = Instruction> {
    prop_oneof![
        Just(Instruction::LdU64(any::<u64>())),
        Just(Instruction::Add),
        Just(Instruction::Sub),
        (0..10usize).prop_map(Instruction::StLoc),
        (0..10usize).prop_map(Instruction::CopyLoc),
        // ... 40+ more instructions
    ]
}

// Generate random bytecode sequence
prop_compose! {
    fn arbitrary_bytecode()(
        instrs in prop::collection::vec(arbitrary_instruction(), 1..100),
    ) -> Vec<Instruction> {
        instrs
    }
}

// Fuzz test
proptest! {
    #[test]
    fn bytecode_fuzzing(bytecode in arbitrary_bytecode()) {
        let mut vm = MoveVM::new();
        let result = vm.execute_bytecode(&bytecode);
        
        // Invariants to check
        match result {
            Ok(frame) => {
                // Should be well-formed
                assert!(frame.pc <= bytecode.len());
                assert!(frame.stack.len() <= MAX_STACK_SIZE);
            }
            Err(VMError::Abort(code)) => {
                // Aborts are OK (but should be documented)
            }
            Err(VMError::Crash(_)) => {
                // CRASHES ARE BUGS!
                panic!("VM crashed on bytecode: {:?}", bytecode);
            }
        }
    }
}
```

### Coverage-Guided Fuzzing with AFL/LibFuzzer

**Proptest:** Random generation (good for wide coverage).  
**AFL/LibFuzzer:** Coverage-guided (mutates inputs to maximize code coverage).

**Setup for Move VM fuzzing:**

```rust
// fuzz_target.rs
#![no_main]
use libfuzzer_sys::fuzz_target;
use move_vm::MoveVM;

fuzz_target!(|data: &[u8]| {
    // Parse bytes as bytecode
    if let Ok(bytecode) = parse_bytecode(data) {
        let mut vm = MoveVM::new();
        let _ = vm.execute_bytecode(&bytecode);
        // Crashes will be caught by libfuzzer
    }
});
```

**Run fuzzer:**
```bash
cargo fuzz run fuzz_target -- -max_total_time=3600
```

**Result:** Finds bytecode sequences that crash VM (buffer overflows, assertion failures, etc.).

**Real bug found with fuzzing:** Early Move VM had off-by-one error in stack bounds check. Fuzzer found it in 30 seconds with input:
```
LdU64(1), LdU64(2), ..., LdU64(255), Add  // Stack overflow
```

### Structured Fuzzing: Valid Bytecode Only

**Problem:** Most random byte sequences are INVALID bytecode (fail parsing).

**Solution:** Generate structurally valid bytecode, then fuzz SEMANTICS.

```rust
// Grammar-based fuzzing
enum ValidInstruction {
    LdU64(u64),
    BinOp(BinOp),  // Add, Sub, Mul, etc. (requires 2 stack elements)
    StLoc(u8),     // Store to local (requires 1 stack element)
    // ...
}

impl Arbitrary for ValidInstruction {
    fn arbitrary(g: &mut Gen, stack_depth: usize) -> Self {
        match stack_depth {
            0 => ValidInstruction::LdU64(u64::arbitrary(g)), // Can't pop empty stack
            1 => *g.choose(&[LdU64, StLoc]).unwrap(),
            _ => *g.choose(&[LdU64, BinOp, StLoc]).unwrap(), // Can do anything
        }
    }
}
```

**Result:** All generated bytecode parses successfully, fuzzer focuses on SEMANTIC bugs (not syntax errors).

---

## Oracle Property Testing

### Goal: Validate Cryptographic Oracles Behave Correctly

**Oracles to test:**
- Schnorr proof verification
- Bulletproofs range proof verification
- Ristretto255 point operations
- SHA-256 hashing
- Fiat-Shamir transform

### Schnorr Proof Properties

**Property 1: Completeness (honest prover always succeeds)**
```rust
proptest! {
    #[test]
    fn schnorr_completeness(
        secret_key in arbitrary_scalar(),
        message in arbitrary_message(),
    ) {
        let public_key = generator_mul(secret_key);
        let signature = generate_schnorr_proof(secret_key, message);
        
        assert!(verify_schnorr_proof(public_key, message, signature));
    }
}
```

**Property 2: Soundness (forged proofs fail)**

This is HARD to test (requires breaking discrete log). Instead, test weaker property:

```rust
proptest! {
    #[test]
    fn schnorr_soundness_weak(
        public_key in arbitrary_point(),
        message in arbitrary_message(),
        signature in arbitrary_signature(),
    ) {
        // Random signature should fail (with high probability)
        // Note: This is NOT cryptographic soundness, just a sanity check
        if !verify_schnorr_proof(public_key, message, signature) {
            // Expected: most random signatures fail
        } else {
            // Very unlikely, but possible (birthday paradox)
            // Don't panic, just note it
        }
    }
}
```

**Property 3: Determinism (same input → same output)**
```rust
proptest! {
    #[test]
    fn schnorr_determinism(
        public_key in arbitrary_point(),
        message in arbitrary_message(),
        signature in arbitrary_signature(),
    ) {
        let result1 = verify_schnorr_proof(public_key, message, signature);
        let result2 = verify_schnorr_proof(public_key, message, signature);
        
        assert_eq!(result1, result2); // Must be deterministic
    }
}
```

### Bulletproofs Range Proof Properties

**Property 1: Valid range proofs verify**
```rust
proptest! {
    #[test]
    fn bulletproofs_completeness(
        value in 0u64..1_000_000, // Value in range
        blinding in arbitrary_scalar(),
    ) {
        let commitment = pedersen_commit(value, blinding);
        let proof = generate_range_proof(value, blinding, 64); // 64-bit range
        
        assert!(verify_range_proof(commitment, proof, 64));
    }
}
```

**Property 2: Out-of-range values fail (if honestly generated)**
```rust
proptest! {
    #[test]
    fn bulletproofs_soundness_honest(
        value in (1u64 << 32)..u64::MAX, // Value OUT of 32-bit range
        blinding in arbitrary_scalar(),
    ) {
        let commitment = pedersen_commit(value, blinding);
        // Honest prover CAN'T generate valid proof for out-of-range value
        let result = try_generate_range_proof(value, blinding, 32);
        
        assert!(result.is_err()); // Should fail to generate
    }
}
```

### Cross-Oracle Consistency

**Property: Composition properties hold**
```rust
proptest! {
    #[test]
    fn fiat_shamir_consistency(
        commitment in arbitrary_point(),
    ) {
        // Fiat-Shamir should be deterministic hash
        let challenge1 = fiat_shamir_challenge(commitment, "DST_V1");
        let challenge2 = fiat_shamir_challenge(commitment, "DST_V1");
        
        assert_eq!(challenge1, challenge2);
        
        // Different DST should give different challenge
        let challenge3 = fiat_shamir_challenge(commitment, "DST_V2");
        assert_ne!(challenge1, challenge3); // (with high probability)
    }
}
```

---

## Cross-Stack Differential Testing

### Goal: Ensure Lean, MSL, and Move VM All Agree

**Three-way differential test:**
```rust
proptest! {
    #[test]
    fn three_stack_consistency(input in arbitrary_ca_input()) {
        // Stack 1: Move VM (ground truth)
        let vm_result = execute_on_move_vm(input.clone());
        
        // Stack 2: Lean simulation
        let lean_result = execute_lean_model(input.clone());
        
        // Stack 3: MSL specification
        let msl_prediction = msl_spec_prediction(input.clone());
        
        // All three must agree
        match (vm_result, lean_result, msl_prediction) {
            (Ok(vm_out), Ok(lean_out), MslPrediction::Success(msl_out)) => {
                assert_eq!(vm_out, lean_out);
                assert!(msl_out.matches(vm_out));
            }
            (Err(vm_code), Err(lean_code), MslPrediction::Abort(msl_code)) => {
                assert_eq!(vm_code, lean_code);
                assert_eq!(vm_code, msl_code);
            }
            _ => {
                panic!("Three-stack mismatch on input: {:?}", input);
            }
        }
    }
}
```

### Regression Testing: Freeze Successful Inputs

**When cross-stack test passes, save it as regression test:**

```rust
proptest! {
    #[test]
    fn three_stack_consistency(input in arbitrary_ca_input()) {
        // ... run test ...
        
        if test_passed {
            // Save to corpus
            save_to_corpus("passing_inputs.json", input);
        }
    }
}
```

**CI runs regression tests on every PR:**
```bash
# Replays all previously passing inputs
cargo test --test regression_suite
```

**Catches:** Regressions where stacks diverge after code changes.

---

## Mutation Testing for Specifications

### Goal: Ensure Specifications Are Strong Enough

**Problem:** Weak spec that verifies proves nothing.

**Example weak spec:**
```move
spec transfer {
  // This verifies, but proves NOTHING
  ensures true;
}
```

**Mutation testing catches this:**

### Mutation Testing Process

**1. Mutate the specification:**
```move
// Original
spec transfer {
  ensures old(balance) = new(balance) + amount;
}

// Mutant 1: Weaken postcondition
spec transfer {
  ensures true;  // Always true (weak!)
}

// Mutant 2: Wrong postcondition
spec transfer {
  ensures old(balance) = new(balance) - amount; // Wrong direction
}

// Mutant 3: Remove precondition
spec transfer {
  // Removed: requires amount <= balance;
  ensures old(balance) = new(balance) + amount;
}
```

**2. Run Move Prover on mutant:**
```bash
movement move prove --filter transfer
```

**3. Classify result:**
- **Mutant kills verification** → GOOD (spec was strong enough to catch mutant)
- **Mutant still verifies** → BAD (spec is too weak, missing constraint)

**4. Report weak specs:**
```
WEAK SPEC DETECTED:
  File: confidential_asset.spec.move:42
  Function: transfer
  Mutant: Removed postcondition "ensures old(balance) = new(balance) + amount"
  Result: Still verifies (spec is redundant or too weak)
```

### Mutation Operators for MSL

| Operator | Example | What it tests |
|----------|---------|---------------|
| Remove `requires` | Delete precondition | Is precondition necessary? |
| Remove `ensures` | Delete postcondition | Is postcondition checked? |
| Remove `aborts_if` | Delete abort condition | Are error paths specified? |
| Weaken `ensures` | `x > 0` → `x >= 0` | Is constraint tight enough? |
| Swap `old/new` | `old(x) = new(x)` → `new(x) = old(x)` | Is temporal logic correct? |
| Change abort code | `65537` → `65538` | Are error codes precise? |
| Negate condition | `amount <= balance` → `amount > balance` | Is condition correct direction? |

### Mutation Testing Automation

**Script: `scripts/mutate_msl_specs.py`**
```python
import re

def generate_mutants(spec_file):
    with open(spec_file) as f:
        original = f.read()
    
    mutants = []
    
    # Mutant 1: Remove each ensures clause
    for match in re.finditer(r'ensures .*?;', original):
        mutant = original[:match.start()] + original[match.end():]
        mutants.append(("remove_ensures", mutant))
    
    # Mutant 2: Remove each requires clause
    for match in re.finditer(r'requires .*?;', original):
        mutant = original[:match.start()] + original[match.end():]
        mutants.append(("remove_requires", mutant))
    
    # ... more mutation operators
    
    return mutants

def run_mutation_testing(spec_file):
    mutants = generate_mutants(spec_file)
    
    for mutant_type, mutant_code in mutants:
        # Write mutant to temp file
        with open("temp_mutant.spec.move", "w") as f:
            f.write(mutant_code)
        
        # Run Move Prover
        result = subprocess.run(["movement", "move", "prove", "--filter", "..."])
        
        if result.returncode == 0:
            # Mutant still verifies (BAD)
            print(f"WEAK SPEC: {mutant_type} did not kill verification")
        else:
            # Mutant kills verification (GOOD)
            print(f"OK: {mutant_type} killed verification as expected")
```

**Run mutation testing in CI:**
```bash
python scripts/mutate_msl_specs.py aptos-experimental/sources/confidential_asset/*.spec.move
```

---

## Corpus Generation and Management

### Corpus Structure

```
difftest/corpus/
├── registration/
│   ├── happy_path/
│   │   ├── input_001.json
│   │   ├── input_002.json
│   │   └── ...
│   ├── error_paths/
│   │   ├── invalid_proof_001.json
│   │   ├── malformed_commitment_002.json
│   │   └── ...
│   └── edge_cases/
│       ├── zero_value.json
│       ├── max_value.json
│       └── ...
├── withdrawal/
│   └── ...
└── transfer/
    └── ...
```

### Automated Corpus Generation

**Strategy 1: Random generation (proptest)**
```rust
// Generate 10K random inputs, save those that execute successfully
proptest! {
    #[test]
    fn generate_corpus(input in arbitrary_ca_input()) {
        let result = execute_on_vm(input.clone());
        
        if result.is_ok() || result.is_expected_error() {
            save_to_corpus(input);
        }
    }
}
```

**Strategy 2: Symbolic execution**
```rust
// Use symbolic execution to enumerate reachable states
fn generate_corpus_symbolic() {
    let mut symbolic_vm = SymbolicVM::new();
    let paths = symbolic_vm.explore_all_paths();
    
    for path in paths {
        let concrete_input = path.concretize();
        save_to_corpus(concrete_input);
    }
}
```

**Strategy 3: Coverage-guided (AFL)**
```bash
# Run AFL for 1 hour, it will generate corpus automatically
cargo fuzz run fuzz_target -- -max_total_time=3600 -artifact_prefix=corpus/
```

### Corpus Minimization

**Problem:** After fuzzing, corpus has 50K inputs, many redundant.

**Solution:** Minimize to SMALLEST set covering same code paths.

```bash
# AFL corpus minimization
afl-cmin -i corpus_raw/ -o corpus_min/ -- ./target/release/fuzz_target
```

**Result:** 50K inputs → 500 inputs, same coverage.

### Corpus Management

**Track corpus in git:**
```bash
git add difftest/corpus/registration/*.json
git commit -m "Add 100 new registration corpus rows"
```

**Corpus evolution:**
- Daily: fuzzing adds new interesting inputs
- Weekly: minimize corpus (remove redundant)
- Monthly: review corpus coverage (ensure all branches covered)

---

## Coverage Metrics and Goals

### Coverage Types

**1. Code coverage (Move bytecode)**
- Lines executed / total lines
- Branches taken / total branches
- Goal: 95%+ bytecode coverage

**2. Property coverage (MSL specs)**
- Spec clauses validated / total clauses
- Goal: 100% spec clause validation

**3. Input space coverage (symbolic)**
- Reachable states explored / total states
- Goal: 100% error paths + 80% success paths

### Measuring Coverage

**Bytecode coverage:**
```bash
# Use Move VM profiler
movement move test --coverage
movement coverage summary
```

**Spec coverage:**
```python
# Parse MSL specs, count clauses
def count_spec_clauses(spec_file):
    requires_count = len(re.findall(r'requires', spec_file))
    ensures_count = len(re.findall(r'ensures', spec_file))
    aborts_if_count = len(re.findall(r'aborts_if', spec_file))
    
    return requires_count + ensures_count + aborts_if_count

# Count how many tested by PBT
tested_clauses = count_tested_in_pbt_suite()

coverage = tested_clauses / total_clauses
```

**Symbolic coverage:**
```rust
// Count explored paths
let total_paths = symbolic_vm.count_all_paths();
let explored_paths = corpus.len();
let coverage = explored_paths as f64 / total_paths as f64;
```

### Coverage Goals

| Component | Current | Target | Timeline |
|-----------|---------|--------|----------|
| Registration bytecode | 92% | 95% | Phase 7 |
| Withdrawal bytecode | 88% | 95% | Phase 7 |
| Transfer bytecode | 85% | 95% | Phase 7 |
| MSL spec clauses | 73% | 100% | Phase 7 |
| Error paths | 60% | 100% | Phase 7 |
| Oracle behaviors | 80% | 100% | Phase 8 |

---

## CI/CD Integration

### CI Pipeline for PBT

```yaml
# .github/workflows/property-based-tests.yaml
name: Property-Based Tests

on: [push, pull_request]

jobs:
  proptest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run proptest suite (10K iterations)
        run: cargo test --release --test proptest_suite -- --nocapture
        env:
          PROPTEST_CASES: 10000
      
      - name: Run Lean plausible tests
        run: lake build && lake exe run_plausible_tests
      
      - name: Upload coverage report
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/proptest_coverage.xml

  fuzzing:
    runs-on: ubuntu-latest
    steps:
      - name: Run fuzzing (1 hour)
        run: cargo fuzz run fuzz_target -- -max_total_time=3600
      
      - name: Minimize corpus
        run: afl-cmin -i corpus/ -o corpus_min/ -- ./fuzz_target
      
      - name: Upload new corpus
        run: |
          git add corpus_min/
          git commit -m "Update fuzzing corpus [skip ci]"
          git push

  mutation-testing:
    runs-on: ubuntu-latest
    steps:
      - name: Run mutation testing
        run: python scripts/mutate_msl_specs.py
      
      - name: Report weak specs
        run: |
          if [ -f mutation_report.txt ]; then
            cat mutation_report.txt >> $GITHUB_STEP_SUMMARY
          fi
```

### Nightly vs PR Testing

**PR (fast, 5 min):**
- Proptest: 100 iterations per property
- Fuzzing: skip (too slow)
- Mutation testing: skip (too slow)

**Nightly (comprehensive, 2 hours):**
- Proptest: 10K iterations per property
- Fuzzing: 1 hour per fuzz target
- Mutation testing: full suite
- Corpus minimization
- Coverage reports

---

## Case Studies

### Case Study 1: Finding Fiat-Shamir DST Bug

**Setup:** Property test for Fiat-Shamir consistency across stacks.

**Property:**
```rust
proptest! {
    #[test]
    fn fiat_shamir_cross_stack(commitment in arbitrary_point()) {
        let lean_challenge = lean_fiat_shamir(commitment);
        let vm_challenge = vm_fiat_shamir(commitment);
        
        assert_eq!(lean_challenge, vm_challenge);
    }
}
```

**Failure:**
```
thread 'fiat_shamir_cross_stack' panicked at 'assertion failed: `(left == right)`
  left: `Scalar(0x1a2b3c...)`
 right: `Scalar(0x4d5e6f...)`'
```

**Root cause:** Lean DST was `"CA_REGISTRATION_V1"`, VM DST was `"CA_REGISTRATION_V1 "` (trailing space).

**Impact:** Would have been a CRITICAL security bug (cross-protocol replay attack). PBT caught it in 10 seconds.

**Fix:** Define DST constants in one place, import everywhere.

### Case Study 2: Bulletproofs Batch Verification Failure

**Setup:** Property test for batch verification equivalence.

**Property:**
```rust
proptest! {
    #[test]
    fn bulletproofs_batch_equiv(
        proofs in prop::collection::vec(arbitrary_range_proof(), 2..10),
    ) {
        let batch_result = verify_batch(proofs.clone());
        let individual_results: Vec<bool> = proofs.iter()
            .map(|p| verify_individual(p))
            .collect();
        
        let all_valid = individual_results.iter().all(|&r| r);
        
        assert_eq!(batch_result, all_valid);
    }
}
```

**Failure:**
```
Batch says: false
Individual says: [true, true, false, true]
One proof is invalid, but which one?
```

**Root cause:** Batch verification fails fast (doesn't say WHICH proof failed).

**Impact:** Poor error messages for users (can't debug which proof is wrong).

**Fix:** On batch failure, retry with individual verification to identify failing proof.

### Case Study 3: Transfer Gas Estimation Bug

**Setup:** Property test for gas estimation accuracy.

**Property:**
```rust
proptest! {
    #[test]
    fn gas_estimation_accurate(input in arbitrary_transfer_input()) {
        let estimated_gas = estimate_transfer_gas(input.clone());
        let actual_gas = execute_transfer_and_measure_gas(input);
        
        let error = (estimated_gas as i64 - actual_gas as i64).abs();
        let error_pct = error as f64 / actual_gas as f64;
        
        assert!(error_pct < 0.05); // Within 5%
    }
}
```

**Failure:**
```
Estimated: 6500 gas
Actual: 7200 gas
Error: 10.8% (exceeds 5% threshold)
```

**Root cause:** Gas estimation didn't account for batch verification savings.

**Impact:** Users overpay for gas.

**Fix:** Update gas estimation formula to include batch verification discount.

---

## Troubleshooting and Debugging

### Proptest Test Fails: How to Debug

**Symptom:**
```
thread 'property_test' panicked at 'assertion failed'
test result: FAILED. 1 passed; 1 failed
```

**Step 1: Enable verbose output**
```bash
PROPTEST_VERBOSE=1 cargo test property_test
```

**Step 2: Examine failing input**
Proptest prints minimal failing case:
```
minimal failing input: Input { balance: 42, amount: 43 }
```

**Step 3: Reproduce manually**
```rust
#[test]
fn reproduce_failure() {
    let input = Input { balance: 42, amount: 43 };
    let result = withdraw(input);
    // Add breakpoints, print statements, etc.
}
```

**Step 4: Fix bug, verify shrinking worked**
After fix, re-run proptest — it should pass on original complex input too.

### Fuzzing Finds Crash: How to Debug

**Symptom:**
```
==12345== ERROR: AddressSanitizer: heap-buffer-overflow
Crashing input written to: crash-abc123
```

**Step 1: Reproduce crash**
```bash
./fuzz_target crash-abc123
```

**Step 2: Minimize crashing input**
```bash
cargo fuzz cmin crash-abc123 -- ./fuzz_target
```

**Step 3: Analyze with debugger**
```bash
gdb ./fuzz_target
run crash-abc123
bt  # Backtrace
```

**Step 4: Fix, add regression test**
```rust
#[test]
fn regression_crash_abc123() {
    let input = load_crash_input("crash-abc123");
    let result = execute(input);
    assert!(result.is_ok()); // Should not crash
}
```

### Mutation Testing Reports Weak Spec: How to Fix

**Symptom:**
```
WEAK SPEC DETECTED:
  Mutant: Removed "ensures balance >= 0"
  Result: Still verifies
```

**Diagnosis:** The removed clause is either:
1. Redundant (implied by other clauses)
2. Not actually checked by implementation

**Step 1: Check if redundant**
```move
spec withdraw {
  requires amount <= balance;  // (1)
  requires balance >= 0;       // (2)
  ensures balance >= 0;        // (3) ← Removed by mutant
}
```

Is (3) implied by (1) + (2)? If `balance >= 0` before and we only subtract `amount <= balance`, then `balance >= 0` after. Yes, redundant.

**Step 2: If not redundant, spec is wrong**
```move
spec withdraw {
  // Missing precondition: requires balance >= 0;
  ensures balance >= 0;  // ← Claims balance non-negative, but doesn't require it!
}
```

Fix: Add missing precondition or strengthen postcondition.

---

## Summary

Property-based testing and fuzzing are ESSENTIAL complements to formal verification:

**What formal verification proves:** Properties hold for ALL inputs (∀).  
**What PBT validates:** Properties hold for MANY random inputs (sample).  
**What fuzzing finds:** Unexpected crashes, edge cases, integration bugs.

**Implementation checklist:**
- [ ] Proptest suite: 10K+ iterations per property
- [ ] Fuzzing infrastructure: AFL/libfuzzer integrated
- [ ] Mutation testing: All MSL specs tested for weakness
- [ ] Corpus management: Minimized, versioned, regression tested
- [ ] CI integration: PR runs quick checks, nightly runs comprehensive
- [ ] Coverage tracking: 95% bytecode, 100% spec clauses
- [ ] Cross-stack differential testing: Lean, MSL, VM all consistent

**Next steps:**
1. Set up proptest framework (Week 1)
2. Write initial properties (Week 2-3)
3. Integrate with CI (Week 4)
4. Measure coverage, iterate (Week 5-8)
5. Achieve coverage goals (Phase 7 completion)

---

**Document metadata:**
- **Version:** 1.0
- **Author:** CA Verification Team
- **Last major update:** 2026-04-22
- **Related:** `INTEGRATION_TESTING_AND_CROSS_LAYER_VALIDATION_GUIDE.md`, `TESTING_STRATEGY_COMPREHENSIVE_GUIDE.md`
