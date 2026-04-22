# CA formal-verification claims (audit/CLAIMS.md)

Per-claim index mapping "what do you want to know" → "where is it proved" → "command to re-check."
Scaffold for the Phase 7 reviewer-facing audit package described in
[`../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §10.2.

Each claim row has: plain-English property, tool (Move Prover / Lean / difftest), file + theorem/spec location, rerun command, and a `Relies on:` line back-pointing to axioms / pragma opaque boundaries in [`TRUST_BOUNDARIES.md`](TRUST_BOUNDARIES.md).

**Status:** scaffold. Entries will fill in as each phase lands. A phase is not "done" (§0 tracker) until its claims have a row here with a working rerun command.

## Registration

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `verify_registration_proof` bytecode matches the functional sigma predicate on the honest oracle (up to MachineState) | Lean | `lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquiv.lean` → `registration_eval_equiv_functional_sim` | `./verify-ca.sh --op register --stack lean` | TEMPORARY AXIOM `registration_eval_equiv_functional_sim` (reproved in Phase 1 completion) |
| `eval (registrationModuleEnv o) verifyRegistrationProofIdx args fuel initMs` reduces to `run` on the initial frame (entry-point unfolding) | Lean | `Registration/EvalEquivRebuild.lean` → `eval_registration_eq_run` | `cd lean && lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild` | — (no axioms) |
| All 55 non-native PC step theorems — every `stLoc`/`moveLoc`/`copyLoc`/`immBorrowLoc`/`mutBorrowLoc`/`brFalse`/`ldConst`/`ldU64`/`pop`/`ret`/`abort` instruction in the 84-PC registration bytecode | Lean | `EvalEquivRebuild.lean` → `step_registration_pc{0,2,3,5,5_notTaken,6,8,9,11,12,14,14_notTaken,15,17,18,19,20,21,23,24,27,28,31,32,35,36,39,40,43,45,47,48,50,51,52,54,55,56,57,59,60,62,63,65,66,67,69,69_notTaken,70,71,73,74,75,76,78,79,80,81,83}` | same | — |
| All 28 native-call PC step theorems (happy paths) — every `.call N` dispatches to the concrete stdlib/oracle native with the right arity and return count | Lean | `EvalEquivRebuild.lean` → `step_registration_pc{1,4,7,10,13,16,22,25,26,29,30,33,34,37,38,41,42,44,46,49,53,58,61,64,68,72,77,82}` | same | oracle coherence (RegistrationNativeOracle) |
| 10 native-call `_none` error-path variants — oracle returning `none` produces `.error` at PCs 1, 10, 41, 44, 46, 49, 53, 61, 64, 68 | Lean | `EvalEquivRebuild.lean` → `step_registration_pc{1,10,41,44,46,49,53,61,64,68}_none` | same | — |
| Early-error composition: commitment-bytes oracle `none` ⇒ `eval` and `run` produce `.error` (two-step run unfolding) | Lean | `EvalEquivRebuild.lean` → `registration_early_error_compressedPoint_none`, `eval_registration_early_error_compressedPoint_none` | same | — |
| `register_internal` creates a `ConfidentialAssetStore` with canonical init (frozen=false, normalized=true, pending_counter=0, ek=ek) | Move Prover | `confidential_asset.spec.move` → `spec register_internal` | `movement move prove --filter register_internal` | *blocked on Phase 0* |
| `register` entry — after registration-proof acceptance, store exists with canonical init (composes `register_internal` frame) | Move Prover | `confidential_asset.spec.move` → `spec register` | `movement move prove --filter '^register$'` | *blocked on Phase 0* + registration bytecode theorem |
| Registration VM output matches Lean functional sim on 87-row corpus | difftest | `difftest/corpora/confidential_asset/`, `BytecodeDifftestBridge.lean` | `./difftest.sh register` *(pending unified runner)* | VM↔Lean oracle consistency (Ristretto255 natives) |

## Withdrawal

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| *TBD* — `verify_withdrawal_proof` bytecode matches sigma predicate | Lean | Phase 4 target: `lean/MovementFormal/Experimental/ConfidentialAsset/Withdrawal/EvalEquiv.lean` (scaffold only) | — | — |
| `withdraw_to_internal` preserves `ConfidentialAssetStore` frame conditions (normalized = true, balance actually updated, no mutation of frozen/ek/pending_counter) | Move Prover | `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move` → `spec withdraw_to_internal` | `movement move prove --filter withdraw_to_internal` | *blocked on Phase 0 ristretto255 patches* |
| `withdraw_to` / `withdraw` entry points set `normalized = true` on sender store; delegate to `_internal` | Move Prover | same file → `spec withdraw_to`, `spec withdraw` | `movement move prove --filter 'withdraw_to\|^withdraw$'` | *blocked on Phase 0* |

## Transfer

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| *TBD* — `verify_transfer_proof` bytecode matches sigma predicate | Lean | Phase 4 target | — | — |
| `confidential_transfer_internal` increments recipient `pending_counter` by 1, respects freeze gate on recipient | Move Prover | `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move` → `spec confidential_transfer_internal` | `movement move prove --filter confidential_transfer_internal` | *blocked on Phase 0* |
| `confidential_transfer` entry composes `_internal` spec with FA transfer | Move Prover | same file → `spec confidential_transfer` | `movement move prove --filter confidential_transfer` | *blocked on Phase 0* |
| `deposit_to` / `deposit` entry points increment recipient pending_counter, require store exists + not frozen | Move Prover | same file → `spec deposit_to`, `spec deposit` | `movement move prove --filter 'deposit_to\|^deposit$'` | *blocked on Phase 0* |

## Normalization

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| *TBD* — `verify_normalization_proof` bytecode matches sigma predicate | Lean | Phase 4 target: `lean/MovementFormal/Experimental/ConfidentialAsset/Normalization/EvalEquiv.lean` (scaffold only) | — | — |
| `normalize_internal` sets `normalized = true`, aborts if already normalized, preserves `ek`/`frozen`/`pending_counter`/`pending_balance` | Move Prover | `confidential_asset.spec.move` → `spec normalize_internal` | `movement move prove --filter normalize_internal` | *blocked on Phase 0 ristretto255 patches* |

## Rotation

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| *TBD* — `verify_rotation_proof` bytecode matches sigma predicate | Lean | Phase 4 target: `lean/MovementFormal/Experimental/ConfidentialAsset/Rotation/EvalEquiv.lean` (scaffold only) | — | — |
| `rotate_encryption_key_internal` updates `ek` to the new key, sets `normalized = true`, preserves `frozen`/`pending_counter`/`pending_balance` | Move Prover | `confidential_asset.spec.move` → `spec rotate_encryption_key_internal` | `movement move prove --filter rotate_encryption_key_internal` | *blocked on Phase 0* |

## Freeze / unfreeze

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `freeze_token_internal` sets `frozen = true`, aborts if already frozen, preserves all other fields | Move Prover | `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move` → `spec freeze_token_internal` | `movement move prove --filter freeze_token_internal` | *blocked on Phase 0* |
| `unfreeze_token_internal` — symmetric to freeze | Move Prover | same file → `spec unfreeze_token_internal` | `movement move prove --filter unfreeze_token_internal` | *blocked on Phase 0* |
| `freeze_token` / `unfreeze_token` entry points — wrap `_internal` | Move Prover | same file → `spec freeze_token`, `spec unfreeze_token` | `movement move prove --filter '^(un)?freeze_token$'` | *blocked on Phase 0* |

## Rollover

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `rollover_pending_balance_internal` resets `pending_counter` to 0, clears `normalized` flag, preserves `frozen` and `ek` | Move Prover | `aptos-experimental/sources/confidential_asset/confidential_asset.spec.move` → `spec rollover_pending_balance_internal` | `movement move prove --filter rollover_pending_balance_internal` | *blocked on Phase 0* |
| `rollover_pending_balance` entry — wraps `_internal` | Move Prover | same file → `spec rollover_pending_balance` | `movement move prove --filter '^rollover_pending_balance$'` | *blocked on Phase 0* |
| `rollover_pending_balance_and_freeze` entry — combined effect: pending_counter = 0 and frozen = true | Move Prover | same file → `spec rollover_pending_balance_and_freeze` | `movement move prove --filter rollover_pending_balance_and_freeze` | *blocked on Phase 0* |
| `rotate_encryption_key` / `rotate_encryption_key_and_unfreeze` entry — rotate key and (optionally) unfreeze | Move Prover | same file → `spec rotate_encryption_key`, `spec rotate_encryption_key_and_unfreeze` | `movement move prove --filter 'rotate_encryption_key'` | *blocked on Phase 0* |
| `normalize` entry — sets `normalized = true` after proof acceptance | Move Prover | same file → `spec normalize` | `movement move prove --filter '^normalize$'` | *blocked on Phase 0* |

## Governance (allow-list / token gates / auditor)

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `enable_allow_list` / `disable_allow_list` toggle `FAController.allow_list_enabled` only under governance-signer authority | Move Prover | same file → `spec enable_allow_list` / `spec disable_allow_list` | `movement move prove --filter 'enable_allow_list\|disable_allow_list'` | *blocked on Phase 0* |
| `enable_token` / `disable_token` / `set_auditor` require governance-signer authority | Move Prover | same file | `movement move prove --filter 'enable_token\|disable_token\|set_auditor'` | *blocked on Phase 0* |

## View functions

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `pending_balance` / `actual_balance` / `encryption_key` / `is_normalized` / `is_frozen` read the named field from `ConfidentialAssetStore` and abort if store is absent | Move Prover | same file | `movement move prove --filter 'pending_balance\|actual_balance\|encryption_key\|is_normalized\|is_frozen'` | *blocked on Phase 0* |

## Confidential balance (chunk-count invariants)

| Claim | Tool | Location | Rerun | Relies on |
|---|---|---|---|---|
| `new_pending_balance_no_randomness` produces a 4-chunk balance; `new_actual_balance_no_randomness` produces an 8-chunk balance | Move Prover | `confidential_balance.spec.move` | `movement move prove --filter 'confidential_balance'` | *blocked on Phase 0* |
| `add_balances_mut` / `sub_balances_mut` preserve `lhs.chunks.length()`; abort when lhs has fewer chunks than rhs | Move Prover | same file | same | *blocked on Phase 0* |
| `split_into_chunks_u64` returns length 4; `split_into_chunks_u128` returns length 8 | Move Prover | same file | same | *blocked on Phase 0* |
