# Integration Testing and Cross-Layer Validation Guide

**Version**: 1.0  
**Last Updated**: 2026-04-22  
**Status**: Production  
**Audience**: Verification engineers, QA engineers, CI/CD maintainers  
**Estimated Read Time**: 85 minutes  
**Prerequisites**: Understanding of Lean, MSL, and Difftest individually  

---

## Table of Contents

1. [Overview](#overview)
2. [Three-Layer Verification Architecture](#three-layer-verification-architecture)
3. [Cross-Layer Consistency Requirements](#cross-layer-consistency-requirements)
4. [Lean-MSL Integration](#lean-msl-integration)
5. [MSL-Difftest Integration](#msl-difftest-integration)
6. [Lean-Difftest Integration](#lean-difftest-integration)
7. [Bytecode Transcription Validation](#bytecode-transcription-validation)
8. [Oracle Consistency Verification](#oracle-consistency-verification)
9. [End-to-End Integration Tests](#end-to-end-integration-tests)
10. [Automated Consistency Checks](#automated-consistency-checks)
11. [Debugging Cross-Layer Issues](#debugging-cross-layer-issues)
12. [CI/CD Integration Testing Pipeline](#cicd-integration-testing-pipeline)

---

## Overview

### The Integration Challenge

**Three Verification Layers:**
1. **Lean 4 Proofs**: Mathematical correctness of symbolic execution
2. **MSL Specifications**: Functional correctness of Move code
3. **Difftest Corpus**: Empirical validation against VM execution

**Challenge:**
Each layer verifies different aspects using different tools. How do we ensure they're **consistent** and together provide **end-to-end correctness**?

### Integration Testing Goals

**G1: Consistency**
All three layers agree on:
- What operations do (functional behavior)
- When operations succeed/fail (abort conditions)
- What state changes (frame conditions)

**G2: Completeness**
Together, the three layers cover:
- All code paths (branches, oracles, aborts)
- All input ranges (boundary cases, overflow)
- All state transitions

**G3: Soundness**
No false confidence:
- Lean proofs verify actual deployed code (not different version)
- MSL specs match real Move semantics
- Difftest oracles match native implementations

### Document Structure

This guide is organized by **integration interface**:
1. Lean ↔ MSL: Do symbolic proofs match specification logic?
2. MSL ↔ Difftest: Do specifications match VM execution?
3. Lean ↔ Difftest: Do proofs match empirical behavior?
4. All Three: End-to-end validation

Each section provides:
- Consistency requirements
- Validation techniques
- Automated checks
- Debugging strategies

---

## Three-Layer Verification Architecture

### Layer 1: Lean 4 Proofs

**What it Verifies:**
- Symbolic execution correctness
- PC-chaining through bytecode
- Frame conditions (unchanged state)
- Equivalence to high-level specification

**Assurance:**
- **Mathematical proof**: If verified, properties hold for all inputs
- **Assumptions**: Relies on 23 axioms (cryptographic, oracle behavior)

**Limitations:**
- Symbolic model may not match real bytecode (transcription gap)
- Axioms must be validated externally
- No execution testing (purely static)

**Files:**
```
lean/MovementFormal/Experimental/ConfidentialAsset/
  Registration/EvalEquiv.lean
  Withdrawal/EvalEquiv.lean
  Transfer/EvalEquiv.lean
  Normalization/EvalEquiv.lean
  Rotation/EvalEquiv.lean
```

### Layer 2: MSL Specifications

**What it Verifies:**
- Functional correctness (preconditions → postconditions)
- Abort conditions (all error paths)
- Balance invariants (supply conservation)
- Resource ownership (Move semantics)

**Assurance:**
- **Automated verification**: Move Prover generates verification conditions
- **Boogie backend**: SMT solver checks properties

**Limitations:**
- Specifications must be complete (missing specs = unverified code)
- `pragma opaque` hides crypto implementations (trusted)
- Timeout on complex proofs (may need manual intervention)

**Files:**
```
sources/confidential_asset/
  confidential_asset.spec.move
  confidential_balance.spec.move
  confidential_proof.spec.move
```

### Layer 3: Difftest Corpus

**What it Verifies:**
- Real VM execution behavior
- Oracle implementations (Rust native functions)
- End-to-end scenarios (full transaction flows)
- Boundary cases (edge inputs, errors)

**Assurance:**
- **Empirical testing**: Executes real code on real VM
- **Concrete inputs**: Tests specific scenarios

**Limitations:**
- Finite test coverage (can't test all inputs)
- No mathematical proof (just examples)
- Oracles are mocked (may differ from production)

**Files:**
```
difftest/scenarios/
  registration/
  withdrawal/
  transfer/
  normalization/
  rotation/
difftest/oracles/
  schnorr_verify.rs
  sha512.rs
  ristretto255.rs
```

### How Layers Compose

**Verification Stack:**
```
┌─────────────────────────────────────────┐
│  Lean 4 Proofs (Mathematical)           │
│  - Symbolic execution                   │
│  - All inputs (quantified)              │
│  - Axiomatic oracles                    │
└──────────────┬──────────────────────────┘
               │ Consistency
               │ (Bytecode transcription,
               │  Specification alignment)
               ▼
┌─────────────────────────────────────────┐
│  MSL Specifications (Logical)           │
│  - Functional correctness               │
│  - SMT-based verification               │
│  - Opaque crypto                        │
└──────────────┬──────────────────────────┘
               │ Consistency
               │ (Spec-to-implementation,
               │  Oracle behavior)
               ▼
┌─────────────────────────────────────────┐
│  Difftest (Empirical)                   │
│  - VM execution                         │
│  - Concrete scenarios                   │
│  - Real oracles                         │
└─────────────────────────────────────────┘
```

**Trust Model:**
- **Lean** trusts axioms + bytecode transcription
- **MSL** trusts Move Prover + Boogie + SMT solvers
- **Difftest** trusts VM implementation + oracle mocks
- **Integration** validates that trust assumptions align

---

## Cross-Layer Consistency Requirements

### Requirement C1: Abort Conditions Agree

**Statement:**
An operation aborts in Lean ⇔ it aborts in MSL ⇔ it aborts in Difftest.

**Why Important:**
- Lean proof assumes operation succeeds under certain preconditions
- MSL spec lists abort conditions
- Difftest tests both success and abort paths

**Inconsistency Example:**
```lean
-- Lean: assumes operation succeeds if balance ≥ amount
theorem withdrawal_success (h : balance ≥ amount) : ... := ...
```

```move
// MSL: aborts if balance < amount OR proof invalid
ensures balance >= amount;
aborts_if balance < amount;
aborts_if !valid_proof(proof);  // MISSING IN LEAN!
```

```rust
// Difftest: tests both aborts
#[test] fn test_withdrawal_insufficient_balance() { ... }
#[test] fn test_withdrawal_invalid_proof() { ... }  // Would fail in Lean!
```

**Validation:**
- [ ] For each operation, enumerate abort conditions in all three layers
- [ ] Check they're equivalent (same conditions, same orderings)
- [ ] Difftest has negative test for each abort condition

### Requirement C2: State Changes Agree

**Statement:**
Final state in Lean = final state in MSL = final state in Difftest (for same inputs).

**Why Important:**
- Lean proves state updates correctly
- MSL specifies exactly what changes
- Difftest executes and checks results

**Inconsistency Example:**
```lean
-- Lean: sender balance decreases by amount
theorem transfer_sender_balance :
    finalState.balance(sender) = initialState.balance(sender) - amount := ...
```

```move
// MSL: sender balance decreases by amount + fee (FEE MISSING IN LEAN!)
ensures old(balance(sender)) == balance(sender) + amount + fee;
```

```rust
// Difftest: expects fee deduction
assert_eq!(final_balance, initial_balance - amount - fee);  // Would fail in Lean!
```

**Validation:**
- [ ] List all state modifications in each layer
- [ ] Check they're identical (same fields, same values)
- [ ] Frame conditions in Lean match MSL ensures clauses
- [ ] Difftest assertions check all modified fields

### Requirement C3: Oracle Behavior Agrees

**Statement:**
Oracle axioms in Lean = oracle specs in MSL = oracle implementations in Difftest.

**Why Important:**
- Lean axiomatizes oracle behavior (soundness, completeness)
- MSL declares oracles as `pragma opaque` (interface)
- Difftest mocks oracles (concrete implementation)

**Inconsistency Example:**
```lean
-- Lean: oracle always deterministic
axiom verifySchnorrProof_deterministic :
  ∀ proof pk, ∃! witness, verifySchnorrProof proof pk = some witness
```

```move
// MSL: oracle is opaque (no determinism specified)
pragma opaque;
native fun verify_schnorr_proof(proof: Proof, pk: PublicKey): Option<Witness>;
```

```rust
// Difftest: oracle uses randomness (NON-DETERMINISTIC!)
pub fn verify_schnorr_proof(proof: &Proof, pk: &PublicKey) -> Option<Witness> {
    let random_salt = thread_rng().gen();  // VIOLATES LEAN AXIOM!
    ...
}
```

**Validation:**
- [ ] For each oracle, document expected behavior in all layers
- [ ] Lean axioms match oracle specifications
- [ ] Difftest oracle implementations satisfy axioms
- [ ] Determinism properties consistent across layers

### Requirement C4: Bytecode Matches Lean Model

**Statement:**
Deployed bytecode corresponds exactly to Lean symbolic execution model.

**Why Important:**
- Lean proves properties about symbolic bytecode
- If real bytecode differs, proofs are meaningless

**Inconsistency Example:**
```lean
-- Lean: models PC 5 as "Load u64(100)"
theorem step_pc5 : step (state_at_pc 5) = load_constant 100 := ...
```

```
// Real bytecode (deployed): PC 5 is "Load u64(200)"  (WRONG CONSTANT!)
PC 5: LdU64(200)
```

**Validation:**
- [ ] Bytecode transcription reviewed by two engineers
- [ ] Automated diff between deployed bytecode and Lean model
- [ ] Hash of bytecode recorded in audit trail
- [ ] No manual bytecode modifications (compile from Move source)

### Requirement C5: Coverage Completeness

**Statement:**
Difftest covers all code paths proven in Lean and specified in MSL.

**Why Important:**
- Lean proves all paths correct
- MSL specifies all paths
- Difftest should test all paths to validate layers agree

**Inconsistency Example:**
```lean
-- Lean: proves both oracle success and failure paths
theorem oracle_success : ... := ...
theorem oracle_failure : ... := ...
```

```move
// MSL: specifies both paths
aborts_if verify_proof(proof) == none;
ensures verify_proof(proof) == some(witness);
```

```rust
// Difftest: only tests success path (MISSING FAILURE TEST!)
#[test] fn test_proof_success() { ... }
// MISSING: #[test] fn test_proof_failure() { ... }
```

**Validation:**
- [ ] List all code paths in Lean proofs
- [ ] List all abort conditions in MSL specs
- [ ] Check Difftest has test for each path
- [ ] Coverage metrics: ≥95% of scenarios

---

## Lean-MSL Integration

### Integration Point 1: Specification Equivalence

**Lean Side:**
Theorems state functional properties:
```lean
theorem transfer_correct :
    run_transfer initialState = some finalState →
    finalState.balance(sender) = initialState.balance(sender) - amount ∧
    finalState.balance(receiver) = initialState.balance(receiver) + amount := by
  ...
```

**MSL Side:**
Specifications state same properties:
```move
spec transfer {
    ensures old(balance(sender)) == balance(sender) + amount;
    ensures old(balance(receiver)) == balance(receiver) - amount;
}
```

**Consistency Check:**
Do Lean theorem and MSL spec say the same thing?

**Validation Technique:**
**Manual Review Checklist:**
```
For each public function:
[ ] Lean theorem exists
[ ] MSL spec exists
[ ] Preconditions match (Lean hypotheses = MSL requires)
[ ] Postconditions match (Lean conclusion = MSL ensures)
[ ] Abort conditions match (Lean failure branch = MSL aborts_if)
[ ] Frame conditions match (Lean preservation = MSL unchanged fields)
```

**Automated Check:**
```bash
#!/bin/bash
# compare_lean_msl_specs.sh

echo "Checking Lean-MSL specification consistency..."

# Extract Lean theorems
lean_theorems=$(grep "theorem.*_correct" lean/**/*.lean | cut -d: -f2)

# Extract MSL specs
msl_specs=$(grep "spec fun" sources/**/*.spec.move | cut -d: -f2)

# Compare counts
lean_count=$(echo "$lean_theorems" | wc -l)
msl_count=$(echo "$msl_specs" | wc -l)

if [ "$lean_count" -ne "$msl_count" ]; then
    echo "❌ Mismatch: $lean_count Lean theorems, $msl_count MSL specs"
    exit 1
fi

echo "✅ Specification counts match: $lean_count"
```

### Integration Point 2: Abort Condition Alignment

**Lean Side:**
Proofs handle both success and abort:
```lean
theorem withdrawal_complete :
    (balance ≥ amount → run_withdrawal = some final_state) ∧
    (balance < amount → run_withdrawal = none) := by
  ...
```

**MSL Side:**
Specs enumerate aborts:
```move
spec withdrawal {
    aborts_if balance < amount;
    aborts_if !verify_proof(proof);
    ensures balance >= amount ==> success;
}
```

**Consistency Check:**
Do abort conditions match?

**Validation:**
```lean
-- For each abort condition in MSL, there should be a Lean theorem
theorem withdrawal_aborts_insufficient_balance :
    balance < amount → run_withdrawal = none := by ...

theorem withdrawal_aborts_invalid_proof :
    verify_proof(proof) = none → run_withdrawal = none := by ...
```

**Automated Check:**
```python
# check_abort_consistency.py

import re

def extract_lean_aborts(lean_file):
    """Extract abort conditions from Lean theorems"""
    with open(lean_file) as f:
        content = f.read()
    # Pattern: theorem <name>_aborts_<condition> : <condition> → ... = none
    return re.findall(r'theorem \w+_aborts_(\w+)', content)

def extract_msl_aborts(msl_file):
    """Extract abort conditions from MSL specs"""
    with open(msl_file) as f:
        content = f.read()
    # Pattern: aborts_if <condition>;
    return re.findall(r'aborts_if ([^;]+);', content)

def check_consistency(lean_aborts, msl_aborts):
    """Check if abort sets are equivalent"""
    lean_set = set(lean_aborts)
    msl_set = set(msl_aborts)
    
    missing_in_lean = msl_set - lean_set
    missing_in_msl = lean_set - msl_set
    
    if missing_in_lean:
        print(f"❌ MSL aborts missing in Lean: {missing_in_lean}")
    if missing_in_msl:
        print(f"❌ Lean aborts missing in MSL: {missing_in_msl}")
    
    if not missing_in_lean and not missing_in_msl:
        print(f"✅ Abort conditions consistent")
    
    return len(missing_in_lean) == 0 and len(missing_in_msl) == 0

# Run check
lean_aborts = extract_lean_aborts('lean/Withdrawal/EvalEquiv.lean')
msl_aborts = extract_msl_aborts('sources/confidential_asset.spec.move')
check_consistency(lean_aborts, msl_aborts)
```

### Integration Point 3: Frame Condition Verification

**Lean Side:**
Frame conditions prove state unchanged:
```lean
theorem transfer_preserves_sender_pubkey :
    (run_transfer final).getPublicKey(sender) = 
    initial.getPublicKey(sender) := by
  frame_auto
```

**MSL Side:**
Ensures clauses for unchanged fields:
```move
spec transfer {
    ensures public_key(sender) == old(public_key(sender));
    ensures nonce(sender) == old(nonce(sender));
}
```

**Consistency Check:**
Do frame conditions cover same fields?

**Validation:**
```bash
#!/bin/bash
# check_frame_conditions.sh

echo "Checking frame condition coverage..."

# Extract Lean frame conditions
lean_frames=$(grep "preserves" lean/**/*.lean | grep -o "preserves_\w*" | cut -d_ -f2 | sort | uniq)

# Extract MSL ensures clauses for unchanged fields
msl_frames=$(grep "ensures.*== old(" sources/**/*.spec.move | grep -o "\w*(" | tr -d '(' | sort | uniq)

# Compare
comm -3 <(echo "$lean_frames") <(echo "$msl_frames")
# Output: fields in one but not the other
```

---

## MSL-Difftest Integration

### Integration Point 1: Spec-to-Implementation Validation

**MSL Side:**
Specification describes behavior:
```move
spec transfer {
    requires balance(sender) >= amount;
    ensures balance(sender) == old(balance(sender)) - amount;
    aborts_if balance(sender) < amount;
}
```

**Difftest Side:**
Test validates behavior:
```rust
#[test]
fn test_transfer_success() {
    let initial_balance = 1000;
    let amount = 300;
    
    // Setup
    let sender = create_account(initial_balance);
    let receiver = create_account(0);
    
    // Execute
    transfer(&sender, &receiver, amount);
    
    // Validate (matches MSL postcondition)
    assert_eq!(get_balance(&sender), initial_balance - amount);
    assert_eq!(get_balance(&receiver), amount);
}

#[test]
#[should_panic]
fn test_transfer_insufficient_balance() {
    let sender = create_account(100);
    let receiver = create_account(0);
    
    // Should abort (matches MSL aborts_if)
    transfer(&sender, &receiver, 200);
}
```

**Consistency Check:**
Does Difftest test cover all MSL spec cases?

**Validation Checklist:**
```
For each MSL spec:
[ ] Difftest has happy path test (requires → ensures)
[ ] Difftest has test for each aborts_if clause
[ ] Test assertions match MSL ensures clauses
[ ] Test setup satisfies MSL requires clauses
```

### Integration Point 2: Oracle Specification vs. Implementation

**MSL Side:**
Oracle declared as opaque:
```move
pragma opaque;
native fun verify_schnorr_proof(
    proof: SchnorrProof,
    public_key: PublicKey
): Option<Witness>;

spec verify_schnorr_proof {
    pragma opaque;
    ensures result == some(w) ==> valid_schnorr_witness(proof, public_key, w);
}
```

**Difftest Side:**
Oracle implemented (mocked):
```rust
pub fn verify_schnorr_proof(
    proof: &SchnorrProof,
    public_key: &PublicKey
) -> Option<Witness> {
    // Implementation must satisfy MSL spec
    let commitment = proof.commitment;
    let challenge = proof.challenge;
    let response = proof.response;
    
    // Check: g^response == commitment * pubkey^challenge
    if scalar_mult_base(response) == add(commitment, scalar_mult(public_key, challenge)) {
        Some(Witness { ... })
    } else {
        None
    }
}
```

**Consistency Check:**
Does oracle implementation satisfy MSL spec?

**Validation:**
**Property-Based Testing:**
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn oracle_satisfies_msl_spec(
        proof in arbitrary_proof(),
        public_key in arbitrary_public_key()
    ) {
        let result = verify_schnorr_proof(&proof, &public_key);
        
        // MSL property: result == some(w) ==> valid_witness
        if let Some(witness) = result {
            assert!(valid_schnorr_witness(&proof, &public_key, &witness));
        }
    }
}
```

### Integration Point 3: Abort Condition Testing

**MSL Side:**
All abort paths specified:
```move
spec withdrawal {
    aborts_if balance < amount;
    aborts_if !verify_proof(proof);
    aborts_if amount > MAX_WITHDRAWAL;
}
```

**Difftest Side:**
Negative tests for each abort:
```rust
#[test]
#[should_panic(expected = "INSUFFICIENT_BALANCE")]
fn test_withdrawal_insufficient_balance() {
    let account = create_account(100);
    withdrawal(&account, 200);  // Should abort
}

#[test]
#[should_panic(expected = "INVALID_PROOF")]
fn test_withdrawal_invalid_proof() {
    let account = create_account(1000);
    let invalid_proof = create_invalid_proof();
    withdrawal_with_proof(&account, 100, invalid_proof);  // Should abort
}

#[test]
#[should_panic(expected = "EXCEEDS_MAX_WITHDRAWAL")]
fn test_withdrawal_exceeds_max() {
    let account = create_account(1000000);
    withdrawal(&account, MAX_WITHDRAWAL + 1);  // Should abort
}
```

**Consistency Check:**
One Difftest negative test per MSL aborts_if clause?

**Automated Check:**
```python
# check_abort_coverage.py

def extract_msl_aborts(spec_file):
    """Extract all aborts_if clauses from MSL spec"""
    aborts = []
    with open(spec_file) as f:
        for line in f:
            if 'aborts_if' in line:
                condition = line.split('aborts_if')[1].split(';')[0].strip()
                aborts.append(condition)
    return aborts

def extract_difftest_negative_tests(test_file):
    """Extract all #[should_panic] tests"""
    tests = []
    with open(test_file) as f:
        content = f.read()
    # Find all #[should_panic] test functions
    import re
    tests = re.findall(r'#\[should_panic.*?\]\s*fn (\w+)', content)
    return tests

def check_coverage(msl_aborts, difftest_tests):
    """Check if each abort has corresponding test"""
    if len(difftest_tests) < len(msl_aborts):
        print(f"❌ Coverage gap: {len(msl_aborts)} aborts, {len(difftest_tests)} tests")
        return False
    print(f"✅ Abort coverage complete: {len(msl_aborts)} conditions tested")
    return True
```

---

## Lean-Difftest Integration

### Integration Point 1: Symbolic vs. Concrete Execution

**Lean Side:**
Symbolic execution over all inputs:
```lean
theorem transfer_correct (amount : Nat) (h : amount ≤ sender_balance) :
    run_transfer amount = some (final_state amount) := by
  -- Proof holds for ALL amounts satisfying h
  ...
```

**Difftest Side:**
Concrete execution with specific inputs:
```rust
#[test]
fn test_transfer_amount_100() {
    let result = execute_transfer(100);
    assert!(result.is_ok());
}

#[test]
fn test_transfer_amount_max() {
    let result = execute_transfer(u64::MAX);
    assert!(result.is_ok());
}
```

**Consistency Check:**
Do Difftest concrete cases align with Lean symbolic proof?

**Validation:**
**Test Generation from Lean:**
```lean
-- Generate test cases from Lean proof
#eval generate_test_cases [0, 1, 100, 1000, u64_max]
-- Output: Rust test code for each value
```

**Property-Based Testing:**
```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn transfer_matches_lean_spec(
        amount in 0u64..=1000000,
        sender_balance in amount..=u64::MAX
    ) {
        // Setup
        let sender = create_account(sender_balance);
        let receiver = create_account(0);
        
        // Execute
        let result = transfer(&sender, &receiver, amount);
        
        // Check (Lean theorem says this should succeed)
        assert!(result.is_ok());
        assert_eq!(get_balance(&sender), sender_balance - amount);
    }
}
```

### Integration Point 2: Oracle Axiom Validation

**Lean Side:**
Oracle axiomatized:
```lean
axiom verifySchnorrProof : Proof → PublicKey → Option Witness
axiom verifySchnorrProof_sound :
  ∀ proof pk witness,
    verifySchnorrProof proof pk = some witness →
    SchnorrRelation proof pk witness
```

**Difftest Side:**
Oracle implemented:
```rust
pub fn verify_schnorr_proof(proof: &Proof, pk: &PublicKey) -> Option<Witness> {
    // Must satisfy Lean axiom: if returns Some(w), then SchnorrRelation holds
    ...
}
```

**Consistency Check:**
Does Difftest oracle satisfy Lean axioms?

**Validation:**
**Oracle Property Testing:**
```rust
proptest! {
    #[test]
    fn schnorr_oracle_satisfies_soundness_axiom(
        proof in arbitrary_proof(),
        pk in arbitrary_public_key()
    ) {
        let result = verify_schnorr_proof(&proof, &pk);
        
        // Lean axiom: if Some(witness), then relation holds
        if let Some(witness) = result {
            assert!(schnorr_relation_holds(&proof, &pk, &witness));
        }
    }
}
```

**Test Against Reference Implementation:**
```rust
#[test]
fn oracle_matches_reference() {
    // Use external trusted crypto library as reference
    let proof = create_valid_proof();
    let pk = create_public_key();
    
    let our_result = verify_schnorr_proof(&proof, &pk);
    let reference_result = reference_schnorr_verify(&proof, &pk);
    
    assert_eq!(our_result.is_some(), reference_result);
}
```

### Integration Point 3: Bytecode Execution Match

**Lean Side:**
Models bytecode execution:
```lean
def step (state : Frame) : Option Frame :=
  match state.pc with
  | 0 => some (state with pc := 1, locals := locals.updated 0 value)
  | 1 => some (state with pc := 2, stack := stack.push (locals.get 0))
  | ...
```

**Difftest Side:**
Executes real bytecode:
```rust
#[test]
fn test_bytecode_execution() {
    let mut vm = VM::new();
    let bytecode = load_compiled_bytecode("transfer.mv");
    
    let result = vm.execute(bytecode);
    
    // Check execution trace matches Lean model
    assert_eq!(vm.final_pc, 50);  // Lean: terminates at PC 50
    assert_eq!(vm.final_locals[0], expected_value);  // Lean: locals[0] = ...
}
```

**Consistency Check:**
Does VM execution trace match Lean symbolic execution?

**Validation:**
**Trace Comparison:**
```rust
#[test]
fn execution_trace_matches_lean() {
    let mut vm = VM::new();
    vm.enable_tracing();
    
    vm.execute(bytecode);
    let trace = vm.get_trace();
    
    // Load expected trace from Lean
    let lean_trace = load_lean_trace("Transfer/execution_trace.json");
    
    for (step, (vm_state, lean_state)) in trace.iter().zip(lean_trace.iter()).enumerate() {
        assert_eq!(vm_state.pc, lean_state.pc, "PC mismatch at step {}", step);
        assert_eq!(vm_state.locals, lean_state.locals, "Locals mismatch at step {}", step);
    }
}
```

---

## Bytecode Transcription Validation

### The Transcription Problem

**Challenge:**
Lean proofs verify a **symbolic model** of bytecode. Real execution uses **compiled bytecode**. Gap between model and reality must be validated.

**Transcription Steps:**
1. Write Move source code
2. Compile to Move bytecode
3. Manually transcribe bytecode to Lean symbolic representation
4. Prove properties about Lean model
5. Deploy compiled bytecode

**Risk:**
Step 3 (manual transcription) can introduce errors. If Lean model doesn't match real bytecode, proofs are meaningless.

### Automated Bytecode Comparison

**Strategy:**
Generate Lean model from compiled bytecode automatically, then diff against manual transcription.

**Tool:**
```python
# bytecode_to_lean.py

def parse_bytecode(bytecode_file):
    """Parse compiled Move bytecode"""
    with open(bytecode_file, 'rb') as f:
        bytecode = deserialize_move_bytecode(f.read())
    return bytecode

def generate_lean_model(bytecode):
    """Generate Lean symbolic execution model from bytecode"""
    lean_code = "def transferBytecode : List Instruction :=\n  ["
    
    for pc, instruction in enumerate(bytecode.instructions):
        if instruction.opcode == Opcode.LdU64:
            lean_code += f"\n    Instruction.LoadU64 {instruction.value},"
        elif instruction.opcode == Opcode.StLoc:
            lean_code += f"\n    Instruction.StoreLocal {instruction.index},"
        elif instruction.opcode == Opcode.Add:
            lean_code += f"\n    Instruction.Add,"
        # ... (all opcodes)
    
    lean_code += "\n  ]"
    return lean_code

def compare_with_manual(generated, manual_file):
    """Compare generated Lean model with manual transcription"""
    with open(manual_file) as f:
        manual = f.read()
    
    if generated.strip() == manual.strip():
        print("✅ Bytecode transcription matches")
        return True
    else:
        print("❌ Bytecode transcription mismatch")
        # Show diff
        import difflib
        diff = difflib.unified_diff(manual.splitlines(), generated.splitlines(), lineterm='')
        for line in diff:
            print(line)
        return False
```

**CI Integration:**
```yaml
# .github/workflows/bytecode-validation.yaml

name: Bytecode Transcription Validation

on: [push, pull_request]

jobs:
  validate-bytecode:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Compile Move source
        run: |
          cd aptos-move/framework/aptos-experimental
          aptos move compile --save-metadata
      
      - name: Generate Lean model from bytecode
        run: |
          python3 scripts/bytecode_to_lean.py \
            build/aptos-experimental/bytecode-scripts/transfer.mv \
            > generated_transfer_model.lean
      
      - name: Compare with manual transcription
        run: |
          diff generated_transfer_model.lean \
               lean/MovementFormal/MoveModel/Bytecode/Transfer.lean
      
      - name: Record bytecode hash
        run: |
          sha256sum build/aptos-experimental/bytecode-scripts/*.mv \
            > audit/bytecode_hashes.txt
```

### Manual Review Checklist

Even with automated checks, manual review is critical:

```
Bytecode Transcription Review Checklist:
[ ] Compiled bytecode loaded in hex viewer
[ ] Lean model has same number of instructions
[ ] Each instruction opcode matches
[ ] Each instruction operands match (constants, indices)
[ ] Control flow matches (branches, jumps)
[ ] Function calls match (native functions, other functions)
[ ] PC numbering consistent
[ ] Comments in Lean model match bytecode structure
[ ] Two engineers reviewed transcription independently
[ ] Bytecode hash recorded in audit trail
```

---

## Oracle Consistency Verification

### Oracle Layers

**Three Representations of Each Oracle:**

1. **Lean Axiom:**
   ```lean
   axiom verifySchnorrProof : Proof → PublicKey → Option Witness
   axiom verifySchnorrProof_sound : ...
   ```

2. **Move Native Declaration:**
   ```move
   native fun verify_schnorr_proof(proof: Proof, pk: PublicKey): Option<Witness>;
   ```

3. **Rust Implementation (Difftest Mock):**
   ```rust
   pub fn verify_schnorr_proof(proof: &Proof, pk: &PublicKey) -> Option<Witness> { ... }
   ```

4. **Rust Implementation (Production):**
   ```rust
   // In aptos-core/aptos-vm/src/natives/confidential_asset.rs
   pub fn verify_schnorr_proof_native(...) -> NativeResult { ... }
   ```

**Consistency Requirement:**
All four representations must agree on behavior.

### Oracle Consistency Checks

**Check 1: Signature Match**
```bash
#!/bin/bash
# check_oracle_signatures.sh

echo "Checking oracle signature consistency..."

# Extract Lean axiom signature
lean_sig=$(grep "axiom verifySchnorrProof" lean/**/*.lean)

# Extract Move native signature
move_sig=$(grep "native fun verify_schnorr_proof" sources/**/*.move)

# Extract Rust signature (Difftest)
difftest_sig=$(grep "pub fn verify_schnorr_proof" difftest/oracles/*.rs)

# Extract Rust signature (Production)
prod_sig=$(grep "pub fn verify_schnorr_proof_native" aptos-vm/src/natives/*.rs)

# Compare parameter counts
# (More sophisticated: compare types)
echo "Lean: $lean_sig"
echo "Move: $move_sig"
echo "Difftest: $difftest_sig"
echo "Production: $prod_sig"
```

**Check 2: Property Match**
```python
# check_oracle_properties.py

import re

def extract_lean_properties(lean_file):
    """Extract oracle property axioms from Lean"""
    properties = {}
    with open(lean_file) as f:
        content = f.read()
    
    # Find all axioms related to oracle
    for axiom in re.findall(r'axiom (\w+) :.*', content):
        if 'verifySchnorrProof' in axiom:
            properties[axiom] = True
    
    return properties

def check_difftest_satisfies_properties(test_file, properties):
    """Check if Difftest tests validate all Lean properties"""
    with open(test_file) as f:
        content = f.read()
    
    validated = {}
    
    # Check for soundness test
    if 'soundness' in properties and 'test_schnorr_soundness' in content:
        validated['soundness'] = True
    
    # Check for completeness test
    if 'completeness' in properties and 'test_schnorr_completeness' in content:
        validated['completeness'] = True
    
    # Check for determinism test
    if 'deterministic' in properties and 'test_schnorr_deterministic' in content:
        validated['deterministic'] = True
    
    return validated

# Run check
lean_props = extract_lean_properties('lean/MoveModel/Native/Registration.lean')
difftest_validation = check_difftest_satisfies_properties('difftest/tests/oracle_properties.rs', lean_props)

for prop in lean_props:
    if prop in difftest_validation:
        print(f"✅ {prop} validated in Difftest")
    else:
        print(f"❌ {prop} NOT validated in Difftest")
```

**Check 3: Behavior Match**
```rust
// Integration test comparing Difftest oracle vs. Production oracle

#[test]
fn difftest_oracle_matches_production() {
    // Setup
    let proof = create_test_proof();
    let pk = create_test_public_key();
    
    // Call Difftest oracle
    let difftest_result = difftest::verify_schnorr_proof(&proof, &pk);
    
    // Call production oracle (via VM execution)
    let vm_result = execute_native_call("verify_schnorr_proof", vec![proof, pk]);
    
    // Results must match
    assert_eq!(difftest_result.is_some(), vm_result.is_ok());
    
    if let (Some(witness1), Ok(witness2)) = (difftest_result, vm_result) {
        assert_eq!(witness1, witness2);
    }
}
```

---

## End-to-End Integration Tests

### E2E Test Structure

**Goal:**
Execute complete transaction flows that exercise all three verification layers.

**Example: Full Transfer Flow**

**Test:**
```rust
#[test]
fn e2e_transfer_full_flow() {
    // 1. Setup accounts (like Difftest)
    let alice = create_account_with_balance(1000);
    let bob = create_account_with_balance(0);
    
    // 2. Generate transfer proof (calls oracles)
    let transfer_proof = generate_transfer_proof(&alice, &bob, 300);
    
    // 3. Execute transfer (VM execution)
    let result = execute_transfer(&alice, &bob, 300, transfer_proof);
    
    // 4. Validate results (check against Lean/MSL specs)
    assert!(result.is_ok());
    
    // Check postconditions (from MSL spec)
    assert_eq!(get_balance(&alice), 700);  // 1000 - 300
    assert_eq!(get_balance(&bob), 300);
    
    // Check frame conditions (from Lean proof)
    assert_eq!(get_public_key(&alice), original_alice_pubkey);
    assert_eq!(get_nonce(&alice), original_alice_nonce);
    
    // Check events (from MSL spec)
    assert_eq!(get_events().len(), 1);
    assert!(get_events()[0].is_transfer_event());
}
```

**Coverage:**
- Lean: Proves transfer correctness symbolically
- MSL: Specifies transfer behavior
- Difftest: Executes real transfer on VM
- E2E: Validates all three layers agree

### Multi-Operation E2E Tests

**Test Scenario: Register → Transfer → Withdraw**
```rust
#[test]
fn e2e_full_lifecycle() {
    // 1. Register confidential balance
    let alice = create_account();
    let registration_proof = generate_registration_proof(&alice);
    register_confidential_balance(&alice, registration_proof)?;
    assert_eq!(get_confidential_balance(&alice), 0);
    
    // 2. Deposit to confidential balance
    deposit(&alice, 1000)?;
    assert_eq!(decrypt_balance(&alice), 1000);
    
    // 3. Transfer to Bob
    let bob = create_account();
    register_confidential_balance(&bob, generate_registration_proof(&bob))?;
    
    let transfer_proof = generate_transfer_proof(&alice, &bob, 300);
    transfer(&alice, &bob, 300, transfer_proof)?;
    
    assert_eq!(decrypt_balance(&alice), 700);
    assert_eq!(decrypt_balance(&bob), 300);
    
    // 4. Withdraw from confidential balance
    let withdrawal_proof = generate_withdrawal_proof(&bob, 100);
    withdraw(&bob, 100, withdrawal_proof)?;
    
    assert_eq!(decrypt_balance(&bob), 200);
    assert_eq!(get_public_balance(&bob), 100);
}
```

**Validation Points:**
- Each operation proven in Lean
- Each operation specified in MSL
- Each operation tested in Difftest
- E2E test validates composition

---

## Automated Consistency Checks

### CI/CD Consistency Pipeline

**Job 1: Lean-MSL Consistency**
```yaml
lean-msl-consistency:
  runs-on: ubuntu-latest
  steps:
    - name: Check specification alignment
      run: |
        python3 scripts/check_spec_consistency.py \
          --lean lean/MovementFormal/Experimental/ConfidentialAsset/ \
          --msl sources/confidential_asset/*.spec.move \
          --report consistency_report.json
    
    - name: Validate abort conditions
      run: |
        python3 scripts/check_abort_consistency.py
    
    - name: Check frame conditions
      run: |
        ./scripts/check_frame_conditions.sh
```

**Job 2: MSL-Difftest Consistency**
```yaml
msl-difftest-consistency:
  runs-on: ubuntu-latest
  steps:
    - name: Check test coverage
      run: |
        python3 scripts/check_difftest_coverage.py \
          --specs sources/confidential_asset/*.spec.move \
          --tests difftest/scenarios/ \
          --min-coverage 95
    
    - name: Validate oracle implementations
      run: |
        cargo test --package difftest -- oracle_properties
```

**Job 3: Bytecode Transcription**
```yaml
bytecode-transcription:
  runs-on: ubuntu-latest
  steps:
    - name: Compile Move source
      run: |
        cd aptos-move/framework/aptos-experimental
        aptos move compile --save-metadata
    
    - name: Compare bytecode with Lean model
      run: |
        python3 scripts/bytecode_to_lean.py build/*.mv \
          | diff - lean/MoveModel/Bytecode/Transfer.lean
    
    - name: Record bytecode hash
      run: |
        sha256sum build/*.mv > audit/bytecode_hashes_$(git rev-parse HEAD).txt
```

**Job 4: E2E Integration**
```yaml
e2e-integration:
  runs-on: ubuntu-latest
  steps:
    - name: Run end-to-end tests
      run: |
        cargo test --package integration-tests -- e2e
```

### Consistency Report Dashboard

**Script:**
```python
# generate_consistency_report.py

import json

def generate_report():
    report = {
        "timestamp": datetime.now().isoformat(),
        "commit": subprocess.check_output(["git", "rev-parse", "HEAD"]).decode().strip(),
        "checks": []
    }
    
    # Check 1: Lean-MSL consistency
    lean_msl_result = check_lean_msl_consistency()
    report["checks"].append({
        "name": "Lean-MSL Specification Alignment",
        "status": "PASS" if lean_msl_result else "FAIL",
        "details": lean_msl_result
    })
    
    # Check 2: MSL-Difftest coverage
    coverage_result = check_difftest_coverage()
    report["checks"].append({
        "name": "Difftest Coverage",
        "status": "PASS" if coverage_result >= 0.95 else "FAIL",
        "details": f"Coverage: {coverage_result*100:.1f}%"
    })
    
    # Check 3: Oracle consistency
    oracle_result = check_oracle_consistency()
    report["checks"].append({
        "name": "Oracle Consistency",
        "status": "PASS" if oracle_result else "FAIL",
        "details": oracle_result
    })
    
    # Check 4: Bytecode match
    bytecode_result = check_bytecode_match()
    report["checks"].append({
        "name": "Bytecode Transcription",
        "status": "PASS" if bytecode_result else "FAIL",
        "details": bytecode_result
    })
    
    # Overall status
    report["overall"] = "PASS" if all(c["status"] == "PASS" for c in report["checks"]) else "FAIL"
    
    # Save report
    with open("consistency_report.json", "w") as f:
        json.dump(report, f, indent=2)
    
    return report

if __name__ == "__main__":
    report = generate_report()
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["overall"] == "PASS" else 1)
```

---

## Debugging Cross-Layer Issues

### Debugging Workflow

**Symptom:** Verification passes in one layer but fails in another.

**Step 1: Isolate the Discrepancy**
```
Questions:
1. Which layers agree? Which disagree?
   - Lean + MSL agree, Difftest fails → Implementation bug
   - Lean + Difftest agree, MSL fails → Specification bug
   - MSL + Difftest agree, Lean fails → Proof bug or model mismatch

2. On which operation? Which inputs?
   - Specific test case or general?
   - Success path or abort path?
```

**Step 2: Reproduce Minimally**
```rust
// Minimize failing case
#[test]
fn minimal_repro() {
    // Simplest inputs that trigger discrepancy
    let alice = create_account(100);  // Minimal balance
    let result = transfer(&alice, &bob, 50);  // Minimal transfer
    
    // Should succeed per Lean/MSL
    assert!(result.is_ok());  // FAILS - why?
}
```

**Step 3: Trace Execution**
```rust
// Enable tracing in all layers

// Difftest trace
#[test]
fn trace_execution() {
    enable_vm_tracing();
    transfer(&alice, &bob, 50);
    let trace = get_vm_trace();
    println!("VM trace: {:?}", trace);
}
```

```lean
-- Lean trace
set_option trace.Meta.Tactic.simp true
theorem transfer_debug : ... := by
  trace "Step 1: {state}"
  rw [lemma1]
  trace "Step 2: {state}"
  ...
```

**Step 4: Compare States**
```python
# compare_states.py

def load_lean_state(file):
    # Extract state from Lean proof
    ...

def load_difftest_state(file):
    # Extract state from VM trace
    ...

def compare(lean_state, vm_state):
    if lean_state.pc != vm_state.pc:
        print(f"PC mismatch: Lean={lean_state.pc}, VM={vm_state.pc}")
    
    if lean_state.locals != vm_state.locals:
        print(f"Locals mismatch: Lean={lean_state.locals}, VM={vm_state.locals}")
    
    # ... compare all fields
```

### Common Cross-Layer Bugs

**Bug 1: Bytecode Mismatch**
```
Symptom: Lean proof works, Difftest fails
Diagnosis: Lean model doesn't match compiled bytecode
Example: Lean models PC 5 as "Load 100", bytecode has "Load 200"
Fix: Regenerate Lean model from bytecode, or fix bytecode compilation
```

**Bug 2: Oracle Behavior Mismatch**
```
Symptom: Lean + MSL pass, Difftest fails on oracle call
Diagnosis: Difftest oracle implementation differs from axiom
Example: Lean axiom says deterministic, Difftest uses randomness
Fix: Update Difftest oracle to match axiom, or update axiom if intentional
```

**Bug 3: Abort Condition Missing**
```
Symptom: Lean proof assumes success, Difftest aborts
Diagnosis: Lean proof missing abort case
Example: Lean doesn't handle invalid proof case
Fix: Add abort theorem in Lean, update proof structure
```

**Bug 4: Frame Condition Violation**
```
Symptom: MSL frame condition fails, Difftest shows unexpected modification
Diagnosis: Code modifies field that spec says is unchanged
Example: Transfer unexpectedly updates nonce
Fix: Update code to preserve field, or update spec if intentional
```

---

## CI/CD Integration Testing Pipeline

### Pipeline Structure

```yaml
# .github/workflows/integration-verification.yaml

name: Integration Verification

on: [push, pull_request]

jobs:
  # Stage 1: Individual layer verification
  lean-verification:
    runs-on: ubuntu-latest
    steps:
      - name: Build Lean proofs
        run: lake build MovementFormal.Experimental.ConfidentialAsset
      - name: Check for sorry
        run: ./scripts/check_axioms.sh
  
  msl-verification:
    runs-on: ubuntu-latest
    steps:
      - name: Run Move Prover
        run: |
          cd aptos-move/framework/aptos-experimental
          aptos move prove --filter confidential_asset
  
  difftest:
    runs-on: ubuntu-latest
    steps:
      - name: Run Difftest corpus
        run: |
          cd aptos-move/framework/formal/difftest
          cargo test --release
  
  # Stage 2: Cross-layer consistency
  lean-msl-consistency:
    needs: [lean-verification, msl-verification]
    runs-on: ubuntu-latest
    steps:
      - name: Check specification alignment
        run: python3 scripts/check_spec_consistency.py
      - name: Check abort conditions
        run: python3 scripts/check_abort_consistency.py
  
  msl-difftest-consistency:
    needs: [msl-verification, difftest]
    runs-on: ubuntu-latest
    steps:
      - name: Check test coverage
        run: python3 scripts/check_difftest_coverage.py
      - name: Validate oracles
        run: cargo test -- oracle_properties
  
  bytecode-transcription:
    runs-on: ubuntu-latest
    steps:
      - name: Compile and compare
        run: |
          aptos move compile
          python3 scripts/bytecode_to_lean.py build/*.mv | diff - lean/Bytecode/*.lean
  
  # Stage 3: End-to-end integration
  e2e-integration:
    needs: [lean-msl-consistency, msl-difftest-consistency, bytecode-transcription]
    runs-on: ubuntu-latest
    steps:
      - name: Run E2E tests
        run: cargo test --package integration-tests -- e2e
  
  # Stage 4: Generate report
  integration-report:
    needs: [e2e-integration]
    runs-on: ubuntu-latest
    if: always()
    steps:
      - name: Generate consistency report
        run: python3 scripts/generate_consistency_report.py
      
      - name: Upload report
        uses: actions/upload-artifact@v2
        with:
          name: integration-report
          path: consistency_report.json
      
      - name: Post to PR
        uses: actions/github-script@v5
        with:
          script: |
            const report = require('./consistency_report.json');
            const comment = `## Integration Verification Report\n\n${report.overall}\n\nDetails: ${report.checks.map(c => `- ${c.name}: ${c.status}`).join('\n')}`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### Performance Budgets

**Total Pipeline Time:** <15 minutes

**Individual Budgets:**
- Lean verification: <6 min
- MSL verification: <2 min
- Difftest: <3 min
- Consistency checks: <2 min
- E2E tests: <2 min

---

## Cross-References

### Related Documentation

**Individual Layers:**
- `PHASE_6_PC_CHAINING_DETAILED_TUTORIAL.md` - Lean proof implementation
- `MSL_DEBUGGING_AND_VERIFICATION_GUIDE.md` - MSL specification
- `DIFFTEST_CORPUS_EXPANSION_STRATEGY_GUIDE.md` - Difftest testing

**Quality Assurance:**
- `REGRESSION_PREVENTION_AND_CONTINUOUS_VERIFICATION_GUIDE.md` - Ongoing verification
- `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md` - Automation infrastructure
- `SECURITY_REVIEW_AND_THREAT_MODEL_GUIDE.md` - Security validation

**Audit:**
- `COMPOSITION_CLAIMS.md` - How layers compose for security
- `TRUST_BOUNDARIES.md` - What each layer assumes
- `BYTECODE_TRANSCRIPTION_GUIDE.md` - Transcription procedures

---

## Maintenance

### Document Ownership

- **Author**: Verification team, QA team
- **Reviewers**: All verification engineers
- **Approver**: Tech lead
- **Last Review**: 2026-04-22
- **Next Review**: 2026-07-22 (quarterly)

### Feedback

Questions or issues with integration testing?
- **Integration bugs**: verification-team@movementlabs.xyz
- **CI/CD issues**: devops@movementlabs.xyz
- **Cross-layer discrepancies**: File GitHub issue with "integration" label

---

**End of Guide**

Total pages: ~38 (~33K characters)
