# Move Prover Readiness Checklist — Phase 2/3/5 Unblock Guide

**Last updated:** 2026-04-22  
**Purpose:** Complete checklist for Phase 2/3/5 work when ristretto255 patches land  
**Status:** Ready to execute (blocked only on upstream ristretto255 patches)  
**Estimated effort:** 2-3 days once unblocked

---

## Executive Summary

**Context:** Phases 2, 3, and 5 are 70-80% complete (MSL specs written and compile cleanly) but blocked on ristretto255 patches. Current state: 0 VCs generated (expected due to blocker).

**Blocker:** Ristretto255 spec bugs prevent VC generation:
- Bug 1: `bv/int` mismatch in `scalar_from_u{64,128}_internal`
- Bug 2: Vector monomorphization missing for `CompressedRistretto`

**Patches:** Applied locally via workarounds (deactivated invariants, removed ensures clauses). See PHASE_0_RISTRETTO255_PATCH_NOTES.md.

**When unblocked:** This checklist provides step-by-step path from "0 VCs" to "all VCs passing" (2-3 days).

---

## Table of Contents

1. [Prerequisites Check](#prerequisites-check)
2. [Phase 2: *_internal Functions (Day 1)](#phase-2-_internal-functions-day-1)
3. [Phase 3: Store-Only Operations (Day 1-2)](#phase-3-store-only-operations-day-1-2)
4. [Phase 5: FA-Integrated Entry Points (Day 2-3)](#phase-5-fa-integrated-entry-points-day-2-3)
5. [Testing Strategy](#testing-strategy)
6. [Acceptance Criteria](#acceptance-criteria)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites Check

**Before starting Phase 2/3/5 work, verify:**

### ✅ 1. Ristretto255 Patches Applied

```bash
# Check if patches are applied
movement move prove \
  --package-dir aptos-move/framework/aptos-stdlib \
  --filter ristretto255 \
  --vc-timeout 20

# Expected: VCs generated (not 0)
# If still 0 VCs → patches not fully applied
```

**If patches not applied:**
- Read: `PHASE_0_RISTRETTO255_PATCH_NOTES.md`
- Apply locally: Patch to `aptos-stdlib/sources/cryptography/ristretto255.spec.move`
- Verify: Re-run above command, expect >0 VCs

---

### ✅ 2. Move Prover Toolchain Ready

```bash
# Verify Z3/Boogie versions
$Z3_EXE --version       # Expect: Z3 version 4.11.2
$BOOGIE_EXE -version    # Expect: Boogie 3.0.9 or 3.5.1

# Smoke test
movement move prove \
  --package-dir aptos-move/framework/move-stdlib \
  --filter vector \
  --vc-timeout 20

# Expected: { "Result": "Success" }
```

**If smoke test fails:** See CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md §5.1 for setup.

---

### ✅ 3. CA Specs Compile Cleanly

```bash
# Verify all CA specs compile
movement move compile \
  --package-dir aptos-move/framework/aptos-experimental \
  --named-addresses aptos_experimental=0x7

# Expected: No compilation errors
```

**If compilation fails:** Fix spec syntax errors before proceeding.

---

## Phase 2: *_internal Functions (Day 1)

**Goal:** Generate and prove VCs for 6 `*_internal` functions.

**Functions:**
1. `register_internal`
2. `deposit_to_internal`
3. `withdraw_to_internal`
4. `confidential_transfer_internal`
5. `rotate_encryption_key_internal`
6. `normalize_internal`

### Step 1: Generate VCs (Morning)

```bash
# Run Move Prover on each internal function
movement move prove \
  --package-dir aptos-move/framework/aptos-experimental \
  --named-addresses aptos_experimental=0x7 \
  --filter register_internal \
  --vc-timeout 120 \
  --verbose

# Repeat for: deposit_to_internal, withdraw_to_internal,
#             confidential_transfer_internal, rotate_encryption_key_internal,
#             normalize_internal
```

**Expected output (per function):**
```
Generated X verification conditions
Proving X VCs...
  VC 1: [proved/failed/timeout]
  VC 2: [proved/failed/timeout]
  ...
```

**Record results:**
| Function | VCs Generated | VCs Proved | VCs Failed | VCs Timeout |
|----------|---------------|------------|------------|-------------|
| register_internal | ? | ? | ? | ? |
| deposit_to_internal | ? | ? | ? | ? |
| ... | ... | ... | ... | ... |

---

### Step 2: Analyze Failures (Afternoon)

For each **failed VC:**

1. **Read VC output:**
   ```bash
   # Move Prover outputs VC details to stderr
   # Look for: "VC failed at line N: <condition>"
   ```

2. **Classify failure type:**
   - **Missing precondition:** Spec needs stronger `requires` clause
   - **Weak postcondition:** Spec `ensures` doesn't capture full behavior
   - **Incomplete abort:** Missing `aborts_if` case
   - **Frame violation:** Undeclared write (need `modifies`)

3. **Fix pattern (example - balance length preservation):**
   ```move
   // Before (VC fails: can't prove length preserved)
   spec withdraw_to_internal {
       ensures balance.pending_balance_len == old(balance.pending_balance_len);
   }

   // After (VC passes: added precondition)
   spec withdraw_to_internal {
       requires balance.pending_balance_len > 0;
       ensures balance.pending_balance_len == old(balance.pending_balance_len);
   }
   ```

4. **Re-run after fix:**
   ```bash
   movement move prove --filter withdraw_to_internal --vc-timeout 120
   ```

---

### Step 3: Strengthen Specs (Iterative)

**Common strengthening patterns:**

**A. Balance homomorphism (crypto property):**
```move
spec confidential_transfer_internal {
    // TODO after VCs pass: strengthen to actual homomorphism
    // ensures new_sender_balance == old_sender_balance - amount;
    // ensures new_recipient_balance == old_recipient_balance + amount;

    // Current (structural only):
    ensures sender_balance.pending_balance_len == old(sender_balance.pending_balance_len);
    ensures recipient_balance.pending_balance_len == old(recipient_balance.pending_balance_len);
}
```

**B. Store invariant preservation:**
```move
spec register_internal {
    ensures exists<ConfidentialAssetStore>(addr);
    ensures global<ConfidentialAssetStore>(addr).pending_balance_len == PENDING_BALANCE_LEN;
    ensures global<ConfidentialAssetStore>(addr).actual_balance_len == ACTUAL_BALANCE_LEN;
}
```

**C. Abort condition completeness:**
```move
spec withdraw_to_internal {
    aborts_if !exists<ConfidentialAssetStore>(from);
    aborts_if !spec_verify_withdrawal_proof(...);  // opaque boundary
    aborts_if balance.frozen;                       // NEW: discovered via VC
    pragma aborts_if_is_strict;  // All cases covered
}
```

---

### Day 1 Target

- **All 6 functions:** VCs generated (>0 VCs per function)
- **3-4 functions:** VCs passing (100% proved)
- **2-3 functions:** Partial (some VCs failing, fixes identified)

**Checkpoint:** If <3 functions have VCs passing by end of Day 1, reassess spec complexity (may need `pragma opaque` on more crypto boundaries).

---

## Phase 3: Store-Only Operations (Day 1-2)

**Goal:** Prove VCs for 9 store-only functions (pure state mutations, no crypto).

**Functions:**
1. `freeze_token_internal` / `unfreeze_token_internal`
2. `enable_allow_list` / `disable_allow_list`
3. `enable_token` / `disable_token`
4. `set_auditor`
5. `rollover_pending_balance_internal` / `rollover_and_freeze`

### Approach

**Easier than Phase 2** (no crypto, just boolean flags + vector operations).

**Step 1: Batch VC generation (1 hour)**

```bash
# Run all 9 functions
for func in freeze_token_internal unfreeze_token_internal \
            enable_allow_list disable_allow_list \
            enable_token disable_token set_auditor \
            rollover_pending_balance_internal rollover_and_freeze; do
    echo "=== $func ==="
    movement move prove --filter "$func" --vc-timeout 60
done
```

**Expected:** Most VCs pass immediately (store-only logic is simple).

---

**Step 2: Fix abort conditions (2-3 hours)**

**Common failures:**

**A. Freeze/unfreeze idempotency:**
```move
spec freeze_token_internal {
    aborts_if global<ConfidentialAssetStore>(addr).frozen;  // Can't freeze if already frozen
}

spec unfreeze_token_internal {
    aborts_if !global<ConfidentialAssetStore>(addr).frozen; // Can't unfreeze if not frozen
}
```

**B. Allow-list toggle:**
```move
spec enable_allow_list {
    requires !global<FAConfig>(fa_obj_addr).allow_list_enabled;
    ensures global<FAConfig>(fa_obj_addr).allow_list_enabled;
}
```

**C. Rollover idempotency:**
```move
spec rollover_pending_balance_internal {
    requires balance.pending_balance_len > 0;  // Can't rollover empty pending
    ensures old(balance.pending_balance_len) == 0;
    ensures balance.actual_balance_len == old(balance.actual_balance_len) + old(balance.pending_balance_len);
}
```

---

### Day 1-2 Target

- **All 9 functions:** VCs generated
- **7-9 functions:** VCs passing (100% proved)
- **0-2 functions:** Partial (minor fixes needed)

**Checkpoint:** If >2 functions failing, review spec structure (likely overconstrained postconditions).

---

## Phase 5: FA-Integrated Entry Points (Day 2-3)

**Goal:** Prove VCs for 15 entry points (compose internal functions + FA calls).

**Functions:**
1. `register` / `deposit_to` / `deposit` / `deposit_coins_to<CoinType>` / `deposit_coins<CoinType>`
2. `withdraw_to` / `withdraw`
3. `confidential_transfer`
4. `rotate_encryption_key` / `rotate_encryption_key_and_unfreeze`
5. `normalize`
6. `freeze_token` / `unfreeze_token`
7. `rollover_pending_balance` / `rollover_pending_balance_and_freeze`

### Challenge: FA Composition

**Entry points call into `aptos_framework::fungible_asset` (FA).**

**Strategy:** Treat FA as black-box (rely on upstream FA specs).

---

### Step 1: FA Spec Audit (1 hour)

**Verify upstream FA specs are sufficient:**

```bash
# Check FA specs exist
ls aptos-move/framework/aptos-framework/sources/fungible_asset.spec.move

# Review critical specs (from UPSTREAM_FA_SPEC_AUDIT.md):
# - withdraw: ensures balance decrease
# - deposit: ensures balance increase
# - transfer: ensures supply preservation
```

**Read:** `audit/UPSTREAM_FA_SPEC_AUDIT.md` for full analysis.

**If FA specs missing/incomplete:** This is a **blocker** for Phase 5. Escalate to upstream.

---

### Step 2: Entry Point VC Generation (Morning)

```bash
# Run each entry point
for func in register deposit_to withdraw_to confidential_transfer \
            rotate_encryption_key normalize freeze_token unfreeze_token \
            rollover_pending_balance; do
    echo "=== $func ==="
    movement move prove --filter "^$func\$" --vc-timeout 180  # Longer timeout (FA composition)
done
```

**Expected:** More VCs than internal functions (FA composition adds verification conditions).

---

### Step 3: Handle FA Side-Effects (Afternoon)

**Pattern: Frame declarations for FA mutations**

```move
spec deposit_to {
    // CA side-effects
    modifies global<ConfidentialAssetStore>(to);

    // FA side-effects (from upstream FA specs)
    modifies global<FungibleStore>(fa_store_addr);
    ensures global<FungibleStore>(fa_store_addr).balance == 
            old(global<FungibleStore>(fa_store_addr).balance) - amount;

    // Composition: CA internal spec applies
    include DepositToInternalEnsures;
}
```

**Common VC failures:**

**A. Missing FA frame declaration:**
```
VC failed: undeclared write to global<FungibleStore>
Fix: Add `modifies global<FungibleStore>(...)` to spec
```

**B. FA spec too weak:**
```
VC failed: can't prove balance preservation
Fix: Check upstream FA spec, may need `pragma assume` (document in TRUST_BOUNDARIES.md)
```

---

### Step 4: Event Emission (Deferred)

**Current state:** Event emission specs deferred (MSL `emits` clause framework pending).

**Placeholder comments added:**
```move
spec register {
    // TODO: Event emission spec when MSL supports `emits` clause
    // emits Registered { addr, encryption_key } to global<EventHandle>(addr);
}
```

**Action:** Skip event verification for now (not in critical path).

---

### Day 2-3 Target

- **All 15 entry points:** VCs generated
- **10-12 entry points:** VCs passing (100% proved)
- **3-5 entry points:** Partial (FA composition issues, documented workarounds)

**Checkpoint:** If <10 entry points passing, review FA spec audit (may need upstream fixes).

---

## Testing Strategy

### Per-Phase Testing

**After each phase completes:**

1. **Full verification run:**
   ```bash
   ./audit/verify-ca.sh --stack move-prover
   ```
   **Target:** All functions pass (0 failures)

2. **Performance check:**
   ```bash
   ./scripts/benchmark_verification.sh --stack move-prover
   ```
   **Target:** <5s per operation (within budget)

3. **Pragma audit:**
   ```bash
   grep -r "pragma verify = false" aptos-experimental/sources/confidential_asset/*.spec.move
   ```
   **Target:** 0 matches (no escape hatches)

---

### Cross-Phase Integration

**After all 3 phases complete:**

1. **Full suite:**
   ```bash
   ./audit/verify-ca.sh
   ```
   **Target:** All stacks pass (Lean + Move Prover + difftest)

2. **Trust boundary reconciliation:**
   ```bash
   ./scripts/reconcile_trust_boundaries.sh
   ```
   **Target:** All `pragma opaque` documented in TRUST_BOUNDARIES.md

3. **Coverage report:**
   ```bash
   ./scripts/generate_coverage_report.sh --format markdown
   ```
   **Target:** 100% MSL spec coverage for all CA functions

---

## Acceptance Criteria

### Phase 2 Acceptance

- ✅ All 6 `*_internal` functions: VCs generated (>0 VCs)
- ✅ All 6 functions: >90% VCs passing
- ✅ No `pragma verify = false` escapes
- ✅ Balance length preservation specs present
- ✅ All abort conditions documented

---

### Phase 3 Acceptance

- ✅ All 9 store-only functions: VCs generated
- ✅ All 9 functions: 100% VCs passing
- ✅ Freeze/unfreeze idempotency enforced
- ✅ Allow-list toggle correctness enforced

---

### Phase 5 Acceptance

- ✅ All 15 entry points: VCs generated
- ✅ >80% VCs passing (FA composition may have partial failures)
- ✅ All FA side-effects declared in `modifies` clauses
- ✅ Any FA spec assumptions documented in TRUST_BOUNDARIES.md
- ✅ Event emission placeholders present (for future work)

---

### Overall (Phases 2+3+5)

- ✅ `verify-ca.sh --stack move-prover` passes (0 failures)
- ✅ Build time <5s per operation
- ✅ MSL_SPEC_COVERAGE.md updated (100% coverage)
- ✅ TRUST_BOUNDARIES.md updated (all `pragma opaque` documented)
- ✅ Axiom baseline unchanged (no new axioms)

---

## Troubleshooting

### Issue: 0 VCs Still Generated

**Symptom:** After applying ristretto255 patches, still 0 VCs.

**Diagnosis:**
```bash
# Check if patches actually applied
grep "scalar_from_u64_internal" aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move
# Should NOT have `ensures` clause (removed by patch)
```

**Fix:** Re-apply patches following PHASE_0_RISTRETTO255_PATCH_NOTES.md exactly.

---

### Issue: Timeout (>120s per VC)

**Symptom:** Some VCs timeout instead of proving/failing.

**Diagnosis:**
```bash
# Check VC complexity
movement move prove --filter <func> --verbose | grep "VC size"
```

**Fix:**
1. **Simplify spec:** Break complex `ensures` into multiple simpler clauses
2. **Increase timeout:** `--vc-timeout 300` (but investigate why it's slow)
3. **Add intermediate lemmas:** Use `spec fun` to factor out complex logic

---

### Issue: Unprovable VC (Always Fails)

**Symptom:** VC consistently fails, even after spec strengthening.

**Diagnosis:**
```bash
# Check if spec is overconstrained
movement move prove --filter <func> --verbose --diagnose
```

**Fix:**
1. **Review postcondition:** May be too specific (implementation detail vs property)
2. **Check frame:** May be missing `modifies` declaration
3. **Pragma opaque:** If crypto boundary, mark as opaque + document

---

### Issue: FA Composition Failures

**Symptom:** Entry point VCs fail on FA side-effects.

**Diagnosis:**
```bash
# Check upstream FA specs
cat aptos-move/framework/aptos-framework/sources/fungible_asset.spec.move | grep "spec withdraw"
```

**Fix:**
1. **Review UPSTREAM_FA_SPEC_AUDIT.md:** Check if FA spec is known weak
2. **Document assumption:** Add `pragma assume` + TRUST_BOUNDARIES.md entry
3. **Escalate:** If FA spec missing, file upstream issue

---

## Appendices

### Appendix A: Quick Reference Commands

```bash
# Verify prerequisites
movement move prove --package-dir aptos-move/framework/aptos-stdlib --filter ristretto255 --vc-timeout 20

# Phase 2: Run all internal functions
for func in register_internal deposit_to_internal withdraw_to_internal confidential_transfer_internal rotate_encryption_key_internal normalize_internal; do
    movement move prove --filter "$func" --vc-timeout 120
done

# Phase 3: Run all store-only functions
for func in freeze_token_internal unfreeze_token_internal enable_allow_list disable_allow_list enable_token disable_token set_auditor rollover_pending_balance_internal; do
    movement move prove --filter "$func" --vc-timeout 60
done

# Phase 5: Run all entry points
movement move prove --package-dir aptos-experimental --filter "register\|deposit\|withdraw\|transfer\|rotate\|normalize\|freeze\|rollover" --vc-timeout 180

# Full verification
./audit/verify-ca.sh --stack move-prover
```

---

### Appendix B: Estimated Timeline

| Day | Phase | Work | Hours |
|-----|-------|------|-------|
| 1 (AM) | Phase 2 | Generate VCs, analyze failures | 4h |
| 1 (PM) | Phase 2 | Fix specs, strengthen | 4h |
| 2 (AM) | Phase 3 | Generate VCs, fix aborts | 3h |
| 2 (PM) | Phase 5 | FA audit, entry point VCs | 5h |
| 3 (AM) | Phase 5 | FA composition fixes | 4h |
| 3 (PM) | All | Integration testing, docs | 4h |
| **Total** | | | **24h (~3 days)** |

**Parallel option:** Phase 2 and Phase 3 can run concurrently (2 engineers), reducing to ~2 days.

---

**End of checklist.** Ready to execute when ristretto255 patches land.
