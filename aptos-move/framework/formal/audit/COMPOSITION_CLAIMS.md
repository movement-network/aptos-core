# CA formal-verification composition claims (audit/COMPOSITION_CLAIMS.md)

Per-operation end-to-end claim statements for Phase 6 of the unified verification plan.

For each CA operation, the "what does verified mean" story has three parts:

1. **Move Prover** pins the store-side semantics (abort conditions, store pre/post, frame
   conditions). MSL specs in `aptos-experimental/sources/confidential_asset/*.spec.move`.
2. **Lean** pins the crypto-verifier bytecode theorem: the compiled verifier accepts iff the
   mathematical sigma predicate holds (for `register` / `withdraw` / `transfer` / `normalize` /
   `rotate`). Bytecode-level proofs in `lean/MovementFormal/Experimental/ConfidentialAsset/*`.
3. **Difftest** pins the VM↔Lean agreement on concrete inputs. 87-row CA corpus in
   `difftest/corpora/confidential_assets/`.

**Status legend:**
- ✅ All three layers proved (or axiomatized with documented trust base).
- 🟡 One or two layers proved; others scaffolded.
- ☐ Layer not started.

---

## `register`

**Claim:** Calling `register(sender, token, ek, commit, resp)` succeeds iff (a) the signer owns a valid
Twisted ElGamal keypair `(dk, ek)` and (b) `(commit, resp)` is a valid Schnorr proof-of-knowledge
of `dk` against Fiat-Shamir challenge `e = H(ctx ‖ ek ‖ commit)` with context `ctx` binding
chain-id / sender / contract / token. On success, a `ConfidentialAssetStore` is created at
`get_user_address(sender, token)` with zero balances, normalized=true, frozen=false, and the
given `ek`.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover — store-side | `confidential_asset.spec.move` → `spec register` + `spec register_internal` | 🟡 spec landed, verification blocked on Phase 0 ristretto255 patches |
| Lean — sigma-predicate binding | `Registration/EvalEquiv.lean` → `registration_eval_equiv_functional_sim` (axiom) + `Registration/EvalEquivRebuild.lean` (PC-level, **~185 theorems**) | 🟡 TEMPORARY AXIOM still covers the top-level; rebuild body has all 83 per-PC step theorems + happy-path 2/3-PC compositions + **complete non-singleton branch** of the top-level theorem (all 3 non-singleton oracle cases `none` / `some []` / `some (multi)` closed via `_compressedPoint_{none,empty,multi,nonSingleton}`). Remaining: `some [mv]` singleton success path. |
| Difftest — VM↔Lean | `confidential_asset` corpus + `BytecodeDifftestBridge.lean` | ✅ 87-row corpus green |
| Overall | | 🟡 in progress |

---

## `withdraw_to` / `withdraw`

**Claim:** Calling `withdraw_to(sender, token, to, amount, new_balance_bytes, zkrp, sigma_proof)`
succeeds iff (a) the signer has a published `ConfidentialAssetStore` with actual balance
`current`; (b) `sigma_proof` proves `new_balance` is a valid re-encryption of `current - amount`
under the signer's `ek`; (c) `zkrp` is a valid Bulletproofs range proof that `new_balance`'s
chunks all fit in 16 bits. On success, the actual balance is updated to `new_balance`,
`normalized = true` is set, and an FA transfer of `amount` from the protocol's primary store
to `to` is dispatched.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover — store-side | `spec withdraw_to_internal` + `spec withdraw_to`/`spec withdraw` | 🟡 spec landed, verification blocked |
| Lean — sigma-predicate binding | `Withdrawal/EvalEquiv.lean` (scaffold) + `Withdrawal/FunctionalSim.lean` (oracle + stub sim) | ☐ needs `Programs.Withdrawal` bytecode + real sim |
| Difftest — VM↔Lean | existing `verify_withdrawal_proof_zero_sigma_aborts` negative row | 🟡 negative path bound, happy path deferred |
| Overall | | 🟡 early stage |

---

## `confidential_transfer`

**Claim:** Similar to `withdraw_to` but extended with: (a) recipient-side sigma subproof binding
`recipient_amount` to `amount` under recipient `ek`; (b) optional auditor-list where each auditor
has a ciphertext that must decrypt to `amount` under its own `ek`. Abort if any subproof fails.
On success, sender's actual balance updates to `new_balance`, recipient's pending balance adds
`recipient_amount`, recipient's `pending_counter` increments, each auditor's balance updates in
parallel.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover — store-side | `spec confidential_transfer_internal` + `spec confidential_transfer` | 🟡 spec landed |
| Lean — sigma-predicate binding | `Transfer/EvalEquiv.lean` + `Transfer/FunctionalSim.lean` scaffolds | ☐ needs transcription |
| Difftest — VM↔Lean | `verify_transfer_proof_zero_sigma_aborts` negative row | 🟡 negative only |
| Overall | | 🟡 early stage |

---

## `normalize`

**Claim:** `normalize(sender, token, new_balance, proof)` succeeds iff (a) the store is
currently not normalized (aborts otherwise); (b) `proof` verifies that `new_balance` encrypts
the same plaintext as the old actual balance and that every chunk of `new_balance` fits in 16
bits. Post: actual balance replaced with `new_balance`, `normalized = true`.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover — store-side | `spec normalize_internal` + `spec normalize` | 🟡 spec landed |
| Lean | `Normalization/EvalEquiv.lean` + `Normalization/FunctionalSim.lean` | ☐ needs transcription |
| Difftest | `verify_normalization_proof_zero_sigma_aborts` | 🟡 negative only |
| Overall | | 🟡 early stage |

---

## `rotate_encryption_key` / `rotate_encryption_key_and_unfreeze`

**Claim:** `rotate_encryption_key(sender, token, new_ek, new_balance, zkrp, sigma)` succeeds iff
(a) the current pending balance is zero (enforced by caller via `rollover_pending_balance_and_freeze`);
(b) `sigma` proves both `ek` and `new_ek` commit to the same secret key `dk`; (c) `new_balance`
encrypts the same plaintext as the old actual balance under `new_ek`. Post: `ek` replaced with
`new_ek`, actual balance replaced with `new_balance`, `normalized = true`.

The `_and_unfreeze` variant also clears `frozen`.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover — store-side | `spec rotate_encryption_key_internal` + entry specs | 🟡 spec landed |
| Lean | `Rotation/EvalEquiv.lean` + `Rotation/FunctionalSim.lean` | ☐ needs transcription |
| Difftest | `verify_rotation_proof_zero_sigma_aborts` | 🟡 negative only |
| Overall | | 🟡 early stage |

---

## `freeze_token` / `unfreeze_token`

**Claim:** Store-only toggles: flip `frozen` bit, preserve all other fields. Abort if already
in the target state.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover | `spec freeze_token_internal` / `spec unfreeze_token_internal` + entry specs | 🟡 spec landed |
| Lean | *(N/A — no crypto content)* | ✅ not applicable |
| Difftest | e2e corpus rows `e2e_freeze_twice` / `e2e_unfreeze_not_frozen` | ✅ green |
| Overall | | 🟡 pending MSL verification |

---

## `rollover_pending_balance` / `_and_freeze`

**Claim:** Add pending balance into actual balance, reset pending to zero, set pending_counter=0,
clear normalized. `_and_freeze` additionally sets frozen=true.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover | `spec rollover_pending_balance_internal` + entry specs | 🟡 spec landed |
| Lean | *(N/A)* | ✅ not applicable |
| Difftest | e2e corpus | ✅ green |
| Overall | | 🟡 pending MSL verification |

---

## Governance — `enable_allow_list` / `disable_allow_list` / `enable_token` / `disable_token` / `set_auditor`

**Claim:** Under governance-signer authority (`@aptos_framework`), these flip controller/config
flags. Abort if unauthorized or already in target state.

| Layer | Artifact | Status |
|---|---|---|
| Move Prover | specs landed | 🟡 blocked on Phase 0 |
| Lean | *(N/A)* | ✅ not applicable |
| Difftest | e2e corpus | ✅ green |
| Overall | | 🟡 pending MSL verification |

---

## Aggregate progress

| Operation | MSL | Lean | Difftest | Combined |
|---|---|---|---|---|
| register | 🟡 | 🟡 (TEMP AXIOM; 127 PC theorems) | ✅ | 🟡 |
| withdraw* | 🟡 | ☐ (scaffold only) | 🟡 (negative) | 🟡 |
| transfer | 🟡 | ☐ (scaffold only) | 🟡 (negative) | 🟡 |
| normalize | 🟡 | ☐ (scaffold only) | 🟡 (negative) | 🟡 |
| rotate_* | 🟡 | ☐ (scaffold only) | 🟡 (negative) | 🟡 |
| freeze/unfreeze | 🟡 | N/A | ✅ | 🟡 (MSL only) |
| rollover | 🟡 | N/A | ✅ | 🟡 (MSL only) |
| governance | 🟡 | N/A | ✅ | 🟡 (MSL only) |
| view funcs | 🟡 | N/A | ✅ | 🟡 (MSL only) |
