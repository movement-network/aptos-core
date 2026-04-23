# MSL-Lean Bridging Patterns Guide: Cross-Stack Verification Architecture

## Executive Summary

The Confidential Assets verification uses **two independent proof stacks** — Move Specification Language (MSL) for source-level properties and Lean 4 for bytecode-level crypto theorems. This guide catalogs the patterns and principles for ensuring these stacks work together without mixing proof terms, connected through difftest as the common ground truth.

**Core principle**: MSL and Lean **never directly compose**. They prove different properties at different abstraction levels, bound together by the Move VM as witnessed by difftest.

**Three-stack architecture**:
```
MSL (Move Prover)          Lean 4                  Difftest
     ↓                        ↓                       ↓
Source-level            Bytecode-level         Concrete I/O
correctness             crypto theorems         validation
     ↓                        ↓                       ↓
Balance conservation    verify_*_proof ≡       Same bytes
Store invariants        sigma-predicate        through all
Abort conditions        PC-chaining proofs     three stacks
     ↓                        ↓                       ↓
        ← ← ← ← Bound by VM execution → → → →
```

---

## 1. Why Two Stacks Don't Mix (By Design)

### 1.1 Trust Base Separation

**MSL stack**:
- Trust base: Boogie verifier + Z3 SMT solver
- Proves: Source-level predicates about Move code
- Scope: Resource invariants, arithmetic, control flow

**Lean stack**:
- Trust base: Lean 4 kernel (small, de Bruijn-style)
- Proves: Bytecode-level theorems about `MoveModel.step`
- Scope: Crypto oracles, precise PC semantics, functional equivalence

**Why separate**: Different trust assumptions, different proof logics (first-order SMT vs dependent type theory). Trying to unify them would require:
1. Modeling all of MSL's semantics in Lean (multi-year effort)
2. OR extracting Lean proofs to SMT (loses precision)
3. AND trusting that the translation is correct (new TCB)

**Better**: Keep them separate, prove complementary properties, bind via VM.

### 1.2 Complementary Scope

| Property | MSL (✅) | Lean (✅) | Why Split? |
|----------|---------|----------|------------|
| Balance sum = constant | ✅ | ❌ | SMT great at arithmetic invariants |
| `frozen` flag propagates | ✅ | ❌ | Source-level control flow |
| Sigma verifier bytecode correct | ❌ | ✅ | Crypto semantics too complex for SMT |
| PC 17 → PC 18 preserves stack | ❌ | ✅ | Bytecode detail irrelevant at source level |
| `deposit` calls `deposit_to_internal` | ✅ | ❌ | Source-level call graph |
| Native oracle matches math spec | ❌ | ✅ | Requires modeling crypto primitives |

**Observation**: MSL sees source, Lean sees bytecode. They're proving **different theorems** about the **same execution**, not competing to prove the same theorem.

---

## 2. The Binding Mechanism: Difftest as Common Witness

### 2.1 How Difftest Connects the Stacks

Difftest **does not prove** anything. It **witnesses** that both stacks' models match the VM on concrete inputs.

```
Input: (user_addr, token, ek, amount, proof_bytes)
   ↓
MSL model executes (in Boogie/Z3 abstract interpretation)
   → Result_MSL: balance' = balance + enc(amount)
   ↓
Lean model executes (MoveModel.run in Lean)
   → Result_Lean: final_state.store.balance = <ciphertext>
   ↓
VM executes (real Move VM via aptos CLI)
   → Result_VM: JSON{store: {balance: 0x4f3a...}}
   ↓
Difftest assertion: 
   Result_MSL ≡ Result_Lean ≡ Result_VM  (byte-for-byte)
```

If any stack disagrees, **CI fails** — even though MSL and Lean never talk to each other.

### 2.2 What Difftest Does NOT Prove

**Difftest is finite**: 87 CA corpus rows + ~200 additional sigma/crypto rows. It witnesses agreement on **those 287 inputs**, not ∀ inputs.

**The ∀-claims come from**:
- **MSL**: "For all deposit amounts, balance sum is preserved" (SMT proves ∀)
- **Lean**: "For all proofs, PC-chaining produces functional sim result" (Lean proves ∀)
- **Difftest**: "On these 287 concrete inputs, both models match VM"

**Gap closure**: If MSL proves P(∀x) and Lean proves Q(∀y), and difftest shows MSL_model(x₁...x₂₈₇) = Lean_model(y₁...y₂₈₇) = VM(z₁...z₂₈₇), then we have:
1. ∀-correctness from MSL and Lean separately
2. Model fidelity from difftest
3. **Trust**: The models are faithful, so the ∀-theorems apply to the VM

This is **not a proof** that the models are correct (that would require proving the VM in Lean). It's **evidence** + **independent verification** + **runtime checks**.

---

## 3. Pattern 1: Crypto Boundary (MSL `pragma opaque` ↔ Lean Native Oracle)

### 3.1 Pattern Description

**Use case**: Functions that perform cryptographic operations (Ristretto point math, SHA hashing, Bulletproofs verification) that SMT solvers cannot reason about.

**MSL side**:
```move
module confidential_proof {
    spec verify_normalization_proof {
        pragma opaque;
        aborts_if false;
        ensures result == <some value>;
    }
}
```

**Lean side**:
```lean
-- In Native/Registration.lean
def verifyRegistrationProofOracle (proof : Bytes) : Option VerifyResult :=
  -- Axiomatized: models native Rust implementation
  sorry  -- Replaced by oracle implementation in runtime

axiom verifyRegistrationProofOracle_correct :
  ∀ proof ek comm,
  verifyRegistrationProofOracle proof = .some (.success ek comm) ↔
  schnorr_sigma_verify (parse_proof proof) ek comm = true
```

**Difftest side**:
```rust
// difftest/tests/registration_proof_verification.rs
#[test]
fn test_registration_proof_happy() {
    let input = TestInput::load("registration_happy_001.json");
    let vm_result = execute_on_vm(input);
    let lean_result = lean_model_eval(input);
    assert_eq!(vm_result.store.ek, lean_result.ek);
    assert_eq!(vm_result.success, lean_result.success);
}
```

### 3.2 Bridging Invariants

**MSL obligation**: "I don't know what this function does, but I know it doesn't crash (aborts_if false) and returns a value I can use in postconditions."

**Lean obligation**: "I model this as an oracle with specified input/output types, and assert its result matches the mathematical predicate (via axiom)."

**Difftest obligation**: "On these 40 test inputs (20 happy, 10 invalid proof, 10 malformed), MSL's opaque result matches Lean's oracle result matches VM's actual execution."

**Gap**: Neither MSL nor Lean proves the **crypto is correct** (that's external audit territory — Ristretto255 DL assumption, Bulletproofs paper). They prove **the code correctly implements the interface** modulo the crypto axioms.

### 3.3 Example: `verify_transfer_proof`

**MSL** (`confidential_proof.spec.move`):
```move
spec verify_transfer_proof {
    pragma opaque;
    aborts_if false;
    ensures std::option::spec_is_some(result) ==> <properties of returned data>;
}
```

**Lean** (`Native/Transfer.lean`):
```lean
def verifyTransferProofOracle 
    (proof : Bytes) (sender_ek : Point) (recipient_ek : Point) 
    : Option (TransferVerifyResult) :=
  -- Oracle implementation (axiomatized)
  sorry

axiom verifyTransferProofOracle_semantics :
  verifyTransferProofOracle proof sender_ek recipient_ek = .some res ↔
  sigma_transfer_predicate proof sender_ek recipient_ek = true ∧
  res.sender_balance_diff = <extracted from proof> ∧
  res.recipient_balance_add = <extracted from proof>
```

**Difftest** (corpus row `e2e_transfer_happy_001.json`):
```json
{
  "operation": "confidential_transfer",
  "sender": "0xA11CE",
  "recipient": "0xB0B",
  "proof": "0x3a4f...",
  "expected_vm_result": {
    "success": true,
    "sender_balance_after": "0x7f3b...",
    "recipient_pending_after": "0x9e2c..."
  }
}
```

Difftest runs this through:
1. MSL model (Boogie interprets `pragma opaque` as unconstrained function returning result per spec)
2. Lean model (`MoveModel.run` calls `verifyTransferProofOracle`)
3. VM (actual `aptos move run`)

All three produce `expected_vm_result` → test passes → binding holds for this input.

---

## 4. Pattern 2: Source-to-Bytecode Correspondence (Entry Point Delegation)

### 4.1 Pattern Description

**Use case**: Public entry functions that delegate to `*_internal` functions. MSL proves the entry point's source-level correctness; Lean proves the bytecode faithfully executes.

**MSL side** (`confidential_asset.spec.move`):
```move
spec withdraw_to {
    let sender_store = global<ConfidentialAssetStore>(signer::address_of(sender));
    
    aborts_if !exists<ConfidentialAssetStore>(...);
    
    ensures global<ConfidentialAssetStore>(sender_addr).normalized == true;
    ensures global<ConfidentialAssetStore>(sender_addr).frozen == old(global<...>.frozen);
    
    modifies global<ConfidentialAssetStore>(sender_addr);
}
```

**Lean side** (Phase 6 composition theorem):
```lean
theorem withdraw_to_eval_equiv_functional_sim 
    (st : State) (args : WithdrawArgs) :
  eval_withdraw_to st args = run st withdraw_to_bytecode TOTAL_PCS
```

**No direct connection**: MSL proves properties of the **source code** (balance conservation, freeze preservation). Lean proves the **bytecode execution** matches the functional simulation. They're different theorems.

**Binding**: Difftest witnesses that executing the **source** (which MSL verified) via the **compiler** produces the **bytecode** (which Lean verified) produces the **same result** as the **VM**.

### 4.2 Why Not Prove Compiler Correctness?

**Question**: Why not prove `source_semantics ≡ bytecode_semantics` and compose MSL + Lean?

**Answer**: 
1. **Compiler correctness is multi-year** — requires modeling the entire Move compiler in Lean
2. **Difftest is sufficient** — if compiler produces wrong bytecode, difftest fails (VM result ≠ models)
3. **Independent verification is valuable** — MSL and Lean catching different bugs is a feature, not a bug

**Example**: Suppose Move compiler has a bug that drops a `frozen` check from bytecode but MSL spec still requires it. Then:
- MSL: Proves source code checks `frozen` ✅
- Lean: Proves bytecode... doesn't check `frozen` (but proves bytecode correctly)
- Difftest: Runs input with `frozen=true`, expects abort, **VM allows** → **TEST FAILS** → compiler bug caught

If we tried to compose MSL + Lean, we'd prove "source-correct bytecode is correct" but miss that the **actual bytecode isn't source-correct**.

---

## 5. Pattern 3: Store Invariant Layering

### 5.1 Pattern Description

**Use case**: Properties that span multiple abstraction levels (e.g., "balance chunks always have length 4 or 8").

**MSL layer** (structural invariants):
```move
spec confidential_balance {
    spec add_balances_mut {
        aborts_if len(lhs.chunks) < len(rhs.chunks);
        ensures len(lhs.chunks) == len(old(lhs).chunks);
    }
}
```

**Lean layer** (bytecode preserves structure):
```lean
theorem normalize_preserves_balance_length 
    (st : State) (args : NormalizeArgs) :
  (run st normalize_bytecode N).store.actual_balance.chunks.length =
  st.store.actual_balance.chunks.length
```

**Difftest layer** (runtime check):
```rust
assert_eq!(
    result.actual_balance.chunks.len(), 
    8,  // Expected length
    "Balance chunk count violated"
);
```

### 5.2 Three-Level Guarantee

| Level | Proves | Example |
|-------|--------|---------|
| MSL | "Source code preserves len(chunks)" | `ensures len(lhs.chunks) == len(old(lhs).chunks)` |
| Lean | "Bytecode execution preserves len(chunks)" | Theorem about `run` output |
| Difftest | "On input X, actual len = 8" | Concrete assertion on VM output |

**Composition**: MSL + Lean together give ∀ guarantee at their respective levels. Difftest gives ∃ witness. Trust that models are faithful → combined guarantee.

### 5.3 When Invariants Diverge (Red Flag)

**Scenario**: MSL proves `pending_counter ≤ MAX` but Lean model doesn't track `pending_counter`.

**Detection**: Difftest input with `pending_counter = MAX + 1`:
- MSL model: Aborts (per spec)
- Lean model: Succeeds (counter not modeled)
- VM: Aborts
- **Difftest fails**: Lean ≠ VM

**Fix**: Add `pending_counter` to Lean's `State` model and update PC-chaining proofs to preserve counter invariant.

**Lesson**: Diverging invariants surface as difftest failures, not as logical inconsistencies (because the stacks don't talk).

---

## 6. Pattern 4: Abort Code Reconciliation

### 6.1 Pattern Description

**Challenge**: MSL uses error codes (e.g., `65537` = VERIFY_FAILED), Lean uses algebraic types (`.aborted 65537`), VM uses numeric exit codes.

**MSL** (`confidential_asset.spec.move`):
```move
spec normalize_internal {
    aborts_if already_normalized with ESIGMA_PROTOCOL_VERIFY_FAILED;
    aborts_if !exists<ConfidentialAssetStore>(...) with ESTORE_NOT_FOUND;
}

const ESIGMA_PROTOCOL_VERIFY_FAILED: u64 = 65537;
const ESTORE_NOT_FOUND: u64 = 5;
```

**Lean** (`Normalization/Phase6Composition.lean`):
```lean
theorem normalization_eval_equiv_functional_sim :
  eval_normalization st args =
  match run st bytecode N with
  | .aborted 65537 => .verifyFailed
  | .aborted code => .error code
  | .returned [] store' => .success store'
  | .error msg => .error INTERNAL_ERROR
```

**Difftest** (`e2e_normalize_already_normalized.json`):
```json
{
  "expected_abort_code": 65537,
  "expected_result": "verify_failed"
}
```

### 6.2 Bridging Strategy

**Constants as source of truth**: Define abort codes in Move source, reference in MSL specs, mirror in Lean:

```move
// In confidential_asset.move
const ESIGMA_PROTOCOL_VERIFY_FAILED: u64 = 65537;
```

```move
// In confidential_asset.spec.move
spec normalize_internal {
    aborts_if ... with ESIGMA_PROTOCOL_VERIFY_FAILED;
}
```

```lean
-- In Lean
def ESIGMA_PROTOCOL_VERIFY_FAILED : Nat := 65537

theorem normalization_abort_code_correct :
  eval_normalization st args = .verifyFailed →
  ∃ st', run st bytecode N = .aborted ESIGMA_PROTOCOL_VERIFY_FAILED
```

**Difftest validates**: On corpus row with "verify failed" scenario, check VM exits with code 65537, MSL model aborts with 65537, Lean model produces `.aborted 65537`.

### 6.3 Abort Code Catalog

Maintain a single source of truth for all CA abort codes:

| Code | Constant Name | MSL | Lean | Difftest Corpus Rows |
|------|---------------|-----|------|----------------------|
| 65537 | ESIGMA_PROTOCOL_VERIFY_FAILED | ✅ | ✅ | 12 rows |
| 65538 | EBULLETPROOF_VERIFY_FAILED | ✅ | ✅ | 6 rows |
| 196609 | ESTORE_NOT_FOUND | ✅ | ✅ | 8 rows |
| 196610 | ESTORE_ALREADY_EXISTS | ✅ | ✅ | 3 rows |
| 196611 | EFROZEN | ✅ | ✅ | 10 rows |
| 196615 | EALREADY_FROZEN | ✅ | ✅ | 2 rows |
| 196616 | ENOT_FROZEN | ✅ | ✅ | 2 rows |

**CI check**: Script that greps MSL specs for `aborts_if ... with`, Lean for abort code constants, and difftest corpus for `expected_abort_code`, and asserts they're all present and consistent.

---

## 7. Pattern 5: Frame Reasoning Across Stacks

### 7.1 The Frame Problem

**MSL**: Uses `modifies global<T>(addr)` to specify which resources change.
**Lean**: Uses explicit state before/after in theorems.
**Both must agree on**: What **doesn't** change.

**Example**: `withdraw_to` should NOT modify recipient's store, only sender's.

**MSL** (`confidential_asset.spec.move`):
```move
spec withdraw_to {
    modifies global<ConfidentialAssetStore>(sender_addr);
    
    // Frame: recipient unchanged
    ensures global<ConfidentialAssetStore>(recipient_addr) == 
            old(global<ConfidentialAssetStore>(recipient_addr));
}
```

**Lean** (Phase 6 composition):
```lean
theorem withdraw_to_frame_recipient 
    (st : State) (args : WithdrawArgs) 
    (h_sender_ne_recipient : args.sender ≠ args.recipient) :
  (run st withdraw_to_bytecode N).store[args.recipient] =
  st.store[args.recipient]
```

**Difftest**:
```rust
let recipient_store_before = get_store(&vm_state, recipient_addr);
execute_withdraw_to(&mut vm_state, sender, recipient, ...);
let recipient_store_after = get_store(&vm_state, recipient_addr);
assert_eq!(recipient_store_before, recipient_store_after);
```

### 7.2 Frame Violations as Bugs

**Scenario**: Developer forgets to add `modifies` clause for a field MSL should track.

**MSL**: Proves nothing (field not mentioned in spec)
**Lean**: Proves bytecode updates the field (because it does)
**Difftest**: VM updates the field

**Detection**: Difftest passes (Lean model matches VM), but **MSL spec is incomplete**. This is a **spec bug**, not a code bug.

**Mitigation**: Code review checklist — for every `modifies global<T>(addr)`, ensure all fields of `T` that change are mentioned in `ensures` clauses.

---

## 8. Pattern 6: Event Emission (MSL Future, Lean Ignore, Difftest Validate)

### 8.1 Current Status

**MSL**: No `emits` clause support yet (see MSL_SPEC_COVERAGE.md §2.3 "Event Emission Documentation"). Placeholder comments added:
```move
spec register {
    // TODO: Add emits clause when MSL supports it
    // emits Registered {
    //   user: signer::address_of(account),
    //   token: token_addr,
    //   ek: ek
    // }
}
```

**Lean**: Does NOT model event emission (out of scope for bytecode-level crypto proofs).

**Difftest**: Validates events in E2E tests:
```rust
#[test]
fn test_register_emits_event() {
    let result = execute_register(&vm, ...);
    assert_eq!(result.events.len(), 1);
    assert_eq!(result.events[0].type_tag, "Registered");
    assert_eq!(result.events[0].data.user, expected_user);
}
```

### 8.2 Bridging Strategy (When MSL Adds `emits`)

Once MSL supports `emits` clauses:

**MSL**:
```move
spec register {
    emits Registered { user: signer::address_of(account), token, ek } 
        to global<EventHandle<Registered>>(...);
}
```

**Lean**: Still ignores events (crypto layer doesn't care about events).

**Difftest**: Keeps existing event assertions.

**Binding**: MSL proves "source emits event" + difftest proves "VM emits event" → transitivity (assuming compiler is correct, which difftest also checks).

**No Lean involvement needed** — events are source-level observables, not bytecode-level crypto properties.

---

## 9. Anti-Patterns (What NOT to Do)

### 9.1 ❌ Trying to Import MSL Specs Into Lean

**Bad idea**:
```lean
-- DON'T DO THIS
import MoveProverSpecs.ConfidentialAsset

theorem deposit_combines_msl_and_lean :
  msl_spec_deposit ∧ lean_bytecode_deposit := ...
```

**Why bad**:
1. MSL specs are not Lean terms (they're Boogie/SMT)
2. Parsing Boogie into Lean would require a verified Boogie → Lean translator (doesn't exist)
3. Even if it existed, you'd just be re-proving what MSL already proved (wasted effort)

**Right approach**: MSL and Lean prove **different things**. Let them stay separate.

### 9.2 ❌ Axiomatizing MSL Results in Lean

**Bad idea**:
```lean
-- DON'T DO THIS
axiom msl_proved_balance_conservation :
  ∀ st args, (deposit st args).balance_sum = st.balance_sum
```

**Why bad**:
1. You're **trusting MSL** in Lean's kernel (mixing trust bases)
2. If MSL has a bug, Lean inherits it
3. Defeats the purpose of independent verification

**Right approach**: If Lean needs to know balance is conserved, **prove it in Lean** (or accept that Lean doesn't prove source-level properties — that's MSL's job).

### 9.3 ❌ Using Difftest Results as Proof

**Bad idea**:
```lean
-- DON'T DO THIS
theorem transfer_correct_because_difftest_passed :
  difftest_ran_87_rows → transfer_is_correct
```

**Why bad**:
1. Difftest is finite (87 rows ≠ ∀ inputs)
2. "Test passed" ≠ "proof"
3. Soundness gap: Difftest could pass on 87 rows and fail on row 88

**Right approach**: Difftest is **evidence**, not proof. The proofs are in MSL and Lean. Difftest validates model fidelity.

### 9.4 ❌ Duplicating Invariants Across Stacks

**Bad idea**:
```move
// MSL
spec deposit {
    ensures global<Store>(addr).balance.chunks.len() == 4;
}
```

```lean
-- Lean (duplicating same invariant)
theorem deposit_preserves_chunk_length :
  (deposit st args).balance.chunks.length = 4
```

**Why bad if they're identical**:
1. Maintenance burden (change one, must change the other)
2. No added assurance (both proving the same property)

**When duplication is OK**:
- MSL proves at **source level**, Lean at **bytecode level** (complementary)
- Invariant is **load-bearing** for both stacks (balance length needed for MSL arithmetic, Lean oracle interface)

**Rule of thumb**: Duplicate only if the invariant is needed at both levels and proves different things (source vs bytecode).

---

## 10. Difftest Corpus Design for Cross-Stack Validation

### 10.1 Coverage Dimensions

Design corpus rows to maximize coverage across **three orthogonal dimensions**:

| Dimension | Example Variations | Why Both Stacks Care |
|-----------|-------------------|----------------------|
| **Happy paths** | Valid proof, sufficient balance, not frozen | MSL proves correctness, Lean proves bytecode matches functional sim |
| **Abort paths** | Invalid proof, insufficient balance, frozen | MSL proves abort conditions complete, Lean proves error propagation |
| **Boundary values** | balance=0, counter=MAX, empty pending | Expose off-by-one bugs in both models |
| **Crypto edge cases** | Malformed proof bytes, invalid curve points | Lean oracle must reject, MSL treats as opaque failure |

### 10.2 Example: Transfer Operation Corpus

**Happy path** (5 rows):
- Small amount transfer
- Large amount transfer
- Transfer with auditor hint
- Transfer to self (if allowed)
- Transfer with exactly MAX pending counter - 1

**Abort paths** (8 rows):
- Sender not normalized
- Sender store doesn't exist
- Recipient frozen
- Recipient counter = MAX
- Invalid transfer proof
- Malformed proof bytes
- Sender and recipient both fail (if possible)

**Boundary values** (4 rows):
- Transfer amount = 0 (if allowed)
- Transfer amount = u64::MAX
- Sender balance = exact transfer amount (becomes zero)
- Recipient counter = 0 → 1 (first transfer)

**Total**: 17 rows for transfer (vs current 87 rows for all 5 operations → transfer gets ~15 rows, consistent)

### 10.3 Cross-Stack Assertions

For each difftest row, assert:

```rust
// MSL model check
let msl_result = move_prover_model_eval(input);

// Lean model check
let lean_result = lean_model_eval(input);

// VM execution
let vm_result = aptos_vm_execute(input);

// Assertions
assert_eq!(msl_result.success, vm_result.success, "MSL ≠ VM");
assert_eq!(lean_result.success, vm_result.success, "Lean ≠ VM");
assert_eq!(msl_result.store, vm_result.store, "MSL store ≠ VM");
assert_eq!(lean_result.store, vm_result.store, "Lean store ≠ VM");
assert_eq!(msl_result.abort_code, vm_result.abort_code, "MSL abort ≠ VM");
assert_eq!(lean_result.abort_code, vm_result.abort_code, "Lean abort ≠ VM");
```

**If any assertion fails**: One of the models diverges from VM → model bug (or VM bug, or compiler bug).

---

## 11. Maintenance: Keeping Stacks in Sync

### 11.1 When Move Code Changes

**Scenario**: Developer adds a new abort condition to `withdraw_to` (e.g., "reject if amount > MAX_WITHDRAWAL").

**Required updates**:
1. **Move source**: Add `assert!(amount <= MAX_WITHDRAWAL, EAMOUNT_TOO_LARGE)`
2. **MSL spec**: Add `aborts_if amount > MAX_WITHDRAWAL with EAMOUNT_TOO_LARGE`
3. **Lean model**: Update `eval_withdraw_to` functional sim to return `.error EAMOUNT_TOO_LARGE` for large amounts
4. **Lean bytecode**: Add PC-chaining proof for new abort branch
5. **Difftest corpus**: Add row with `amount = MAX_WITHDRAWAL + 1`, expect abort 196620

**CI catches**:
- Missing MSL spec → Move Prover aborts-if incomplete warning
- Missing Lean functional sim update → Difftest fails (Lean model allows, VM aborts)
- Missing Lean bytecode proof → `lake build` fails (PC-chaining proof incomplete)
- Missing difftest row → Coverage gap (not caught automatically, code review should catch)

### 11.2 Sync Checklist

For any CA code change, verify:

✅ **MSL spec updated**: All new abort conditions in `aborts_if`, all new postconditions in `ensures`

✅ **Lean functional sim updated**: `eval_*` functions match new source semantics

✅ **Lean bytecode proofs updated**: PC-chaining proofs cover new instruction sequences

✅ **Difftest corpus updated**: At least one row for new happy path, one for new abort path

✅ **CI green**: `move-prover-ca` + `lean-ca` + `difftest-ca` all pass

**Time budget**: Simple changes (add abort condition) ~1-2 hours across all stacks. Complex changes (new operation) ~1-2 weeks.

---

## 12. Debugging Cross-Stack Failures

### 12.1 Failure Mode: Difftest Fails, MSL and Lean Build Green

**Symptom**:
```
FAILED: test_transfer_happy_001
Expected: success=true, store.balance=0x4f3a...
Actual:   success=true, store.balance=0x7b2e...
```

**Diagnosis**:
1. MSL model and Lean model both **internally consistent** (proofs pass)
2. But one or both **diverge from VM reality**

**Debug steps**:
1. Run input on VM manually: `aptos move run --function-id transfer --args ...`
2. Extract actual VM state: `aptos account get-resources --address ...`
3. Compare VM state to MSL model output (check which fields differ)
4. Compare VM state to Lean model output
5. Identify which model is wrong (or if VM has a bug)

**Common causes**:
- **Modeling error**: Lean's `eval_transfer` has wrong balance arithmetic
- **Opaque spec error**: MSL's `pragma opaque` for crypto function doesn't match actual native behavior
- **Compiler bug**: Move source → bytecode translation is wrong (rare, but difftest would catch this)

### 12.2 Failure Mode: MSL Proof Fails, Difftest Passes

**Symptom**:
```
Move Prover error: postcondition `ensures balance_sum == old(balance_sum)` might not hold
Difftest: ALL TESTS PASSED (87/87)
```

**Diagnosis**:
1. MSL found a **potential bug** in source code
2. Difftest didn't catch it (corpus doesn't cover the failing case)

**Debug steps**:
1. Read Move Prover counterexample (if available)
2. Identify input values that violate postcondition
3. Add difftest row with those input values
4. Run difftest — expect it to **fail** (confirming the bug)
5. Fix Move source code
6. Verify MSL proof passes + difftest passes

**Lesson**: MSL proves ∀, difftest proves ∃. MSL failure with difftest pass means **incomplete corpus**, not wrong proof.

### 12.3 Failure Mode: Lean Proof Fails, MSL and Difftest Pass

**Symptom**:
```
Lean error: type mismatch at PC 17, expected Stack [U64, Reference], got Stack [U64]
MSL: Verification succeeded
Difftest: 87/87 passed
```

**Diagnosis**:
1. Lean's bytecode model is **too precise** and caught a stack imbalance
2. MSL doesn't model stack (source-level only)
3. Difftest didn't expose it (lucky inputs, or bug in non-crypto path)

**Debug steps**:
1. Examine Lean's `run` trace at PC 17
2. Check if bytecode listing (via `aptos move disassemble`) matches Lean's transcription
3. If mismatch: Fix Lean bytecode transcription
4. If match: Bytecode is wrong → file compiler bug
5. Add difftest row that exercises PC 17 path (should fail if bytecode is wrong)

**Lesson**: Lean's bytecode precision can catch bugs MSL and difftest miss. This is a **feature** — independent verification working as intended.

---

## 13. Advanced: Compositional Reasoning

### 13.1 MSL Composition (Internal → Entry Point)

**Pattern**: Entry point delegates to `*_internal` function. MSL spec for entry composes with internal spec.

```move
spec deposit_to_internal {
    requires exists<ConfidentialAssetStore>(recipient_addr);
    ensures global<...>(recipient_addr).pending_counter == old(...) + 1;
    modifies global<ConfidentialAssetStore>(recipient_addr);
}

spec deposit_to {
    // Composes with deposit_to_internal automatically
    aborts_if !exists<ConfidentialAssetStore>(recipient_addr);
    ensures global<...>(recipient_addr).pending_counter == old(...) + 1;
}
```

**MSL handles composition**: When `deposit_to` calls `deposit_to_internal`, Move Prover substitutes the internal spec's `requires` / `ensures` into the entry point's proof context.

**Lean does NOT compose this way**: Lean proves each function's bytecode independently, then chains via PC-linking.

### 13.2 Lean Composition (Functional Sim → Bytecode)

**Pattern**: Phase 6 composition theorem chains functional sim to bytecode execution.

```lean
-- L1: Functional sim
def eval_deposit_to (st : State) (args : DepositArgs) : Result := ...

-- L2: Bytecode execution
theorem deposit_to_eval_equiv :
  eval_deposit_to st args = run st deposit_to_bytecode TOTAL_PCS
```

**No MSL involvement**: This theorem is purely within Lean — bytecode matches functional sim.

**MSL proved separately**: `deposit_to` source preserves balance (independent theorem).

**Binding**: Difftest witnesses that bytecode (Lean verified) ≡ VM ≡ MSL model.

### 13.3 Cross-Stack Non-Composition (By Design)

**MSL theorem**: `deposit_to` source preserves balance sum (∀ executions)
**Lean theorem**: `deposit_to` bytecode ≡ functional sim (∀ executions)

**Question**: Can we compose these into "deposit_to VM execution preserves balance sum"?

**Answer**: **Not directly**. Would require:
1. Proving compiler correctness (source → bytecode translation preserves semantics)
2. Proving Lean's `MoveModel` matches VM (full VM verification in Lean)
3. Proving MSL's interpretation matches source semantics (MSL → Move semantics proof)

All three are **multi-year efforts** individually.

**Practical answer**: Difftest + independent verification gives **strong evidence**:
- MSL proves source property (balance conserved)
- Lean proves bytecode property (execution correct)
- Difftest witnesses models match VM on 287 inputs
- Trust: Compiler is correct, models are faithful

This is **not a formal proof** of end-to-end correctness, but it's **industry-best-practice** for production crypto (e.g., similar to how seL4, CompCert approach verification).

---

## 14. Summary: The Three-Stack Verification Philosophy

### 14.1 Core Principles

1. **Separation of concerns**: MSL proves source properties, Lean proves bytecode properties, difftest witnesses runtime behavior. Each does what it does best.

2. **Independent verification**: MSL and Lean can catch different bugs precisely because they don't share proof terms. A bug that passes MSL might fail Lean, and vice versa.

3. **VM as ground truth**: When MSL and Lean disagree, VM execution via difftest adjudicates. If both match VM, trust the models.

4. **Crypto boundary**: Axiomatize crypto primitives (Ristretto, Bulletproofs) in both stacks, rely on external audits + difftest corpus for crypto correctness.

5. **Maintenance discipline**: Every code change updates MSL spec, Lean functional sim, Lean bytecode proof, and difftest corpus in lockstep.

### 14.2 What This Architecture Achieves

✅ **Source-level correctness**: MSL proves balance conservation, freeze enforcement, abort conditions (Phases 2/3/5)

✅ **Bytecode-level correctness**: Lean proves crypto verifier bytecode matches sigma predicates (Phases 4/6)

✅ **Runtime validation**: Difftest proves models match VM on 287 concrete inputs (ongoing corpus expansion)

✅ **Independent trust bases**: Lean kernel + Boogie/Z3 must both be sound; if one has a bug, the other might catch it

✅ **Auditable**: External reviewer can check MSL specs (readable), Lean proofs (kernel-checkable), difftest corpus (executable), without trusting our claims

### 14.3 What This Architecture Does NOT Achieve (By Design)

❌ **Full formal proof of VM execution**: Would require verifying Move VM in Lean (out of scope)

❌ **Compiler correctness proof**: Trusts Move compiler via difftest witnessing (acceptable trade-off)

❌ **Zero axioms**: Crypto axioms (23 total) remain, pinned by external audits (Bulletproofs paper, Ristretto255 spec)

❌ **Complete coverage**: Difftest is finite (287 rows), not ∀ (relies on MSL/Lean ∀-proofs + model fidelity)

### 14.4 When to Use Which Stack

| Task | Use MSL | Use Lean | Use Difftest |
|------|---------|----------|--------------|
| Prove balance conserved | ✅ | ❌ | Validate |
| Prove PC 17 → PC 18 correct | ❌ | ✅ | Validate |
| Prove crypto verifier accepts iff sigma holds | ❌ | ✅ (via axiom) | Validate |
| Prove frozen flag propagates | ✅ | ❌ | Validate |
| Prove abort code 65537 means verify failed | Both | Both | Validate |
| Prove new operation correct | ✅ (source) | ✅ (bytecode) | Add rows |
| Debug why test fails | Check MSL | Check Lean | **Start here** |

---

## 15. Future Enhancements

### 15.1 Potential Tighter Coupling (If Needed)

**Current**: MSL and Lean completely independent, bound by difftest.

**Future possibility**: Shared property specification language that both stacks prove against.

Example:
```
// Properties.spec (hypothetical shared language)
property balance_conservation {
    forall op : Operation,
    sum(state_after(op).balances) == sum(state_before(op).balances)
}

// MSL proves at source level
msl_proof: balance_conservation ← msl_spec_deposit

// Lean proves at bytecode level  
lean_proof: balance_conservation ← lean_bytecode_deposit
```

**Benefit**: Single source of truth for properties, both stacks prove the same claim.

**Cost**: Requires designing and implementing the shared spec language, integrating with both MSL and Lean (estimated 6-12 months).

**Verdict**: Not needed for Phase 0-8. Consider for Phase 9+ if cross-stack property drift becomes a maintenance burden.

### 15.2 Automated Difftest Corpus Generation

**Current**: Difftest rows are manually written JSON files.

**Future**: Property-based testing generates inputs, runs through MSL + Lean + VM, auto-adds rows that expose disagreements.

**Benefit**: Corpus grows automatically, higher coverage.

**Cost**: Requires integrating QuickCheck-style random testing with all three stacks (estimated 2-3 months).

**Verdict**: High value for Phase 7 "comprehensive testing" work. See separate guide on property-based testing.

---

*This guide is the authoritative reference for MSL-Lean bridging patterns. Update as new patterns emerge or existing patterns are refined.*
