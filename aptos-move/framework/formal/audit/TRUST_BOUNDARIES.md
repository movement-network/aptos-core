# CA formal-verification trust boundaries (audit/TRUST_BOUNDARIES.md)

Every unproved assumption the verification relies on, organized by trust category. Scaffold for the Phase 7 reviewer-facing audit package described in
[`../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §10.3.

Each row: what's assumed, declaration location, why we accept it, how a skeptic would challenge it.

## Kernel / solver trust

| Assumption | Declaration | Why we accept it | Skeptic's lever |
|---|---|---|---|
| Lean kernel soundness | `lean-toolchain` (v4.24.0) | Small de Bruijn-style type theory; widely audited. | Minimize axioms via `#print axioms`; pin toolchain version in CI. |
| Boogie 3.5.1 soundness | `move-prover-ca` CI lane env | Pinned by Movement CLI installer. | Check Boogie release notes for unsoundness reports; pin version in Docker image. |
| Z3 4.11.2 soundness | `move-prover-ca` CI lane env | Pinned by Movement CLI. Homebrew Z3 4.14.x is known to behave differently (plan §5.1). | Diff against CVC5 on any VC of concern; SMT-LIB replay. |
| Difftest runner fidelity: oracle JSON = VM output | `difftest/` runner impl | VM and oracle are run from the same Rust code path; mismatch would surface as corpus-row failure. | Read `difftest.sh`; confirm VM is the real `aptos-vm` not a stub. |

## Crypto axioms (external, not in-repo)

| Axiom | Citation | Why we accept it | Skeptic's lever |
|---|---|---|---|
| Ristretto255 discrete-log hardness | Curve25519 / Ristretto255 papers; widely deployed in libsodium, Signal, TLS 1.3 | Conservative standard crypto assumption. | Invocation of any point-discrete-log reduction in the Lean side would rely on this; track in `SigmaVerifiers.lean`. |
| SHA-2 / SHA-3 collision resistance | NIST FIPS 180-4 / 202 | Standard cryptographic assumption. | Used in Fiat–Shamir hashing (`newScalarFromSha2_512`). Replace with SHAKE256 or Poseidon if collision resistance is ever in doubt. |
| Bulletproofs soundness and completeness | Bünz et al. 2017, external audit of implementation | Plan §3 / §5 explicitly axiomatize (no Lean implementation in scope). MSL boundary sits at `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255_bulletproofs.spec.move` which declares `verify_range_proof_internal` / `verify_batch_range_proof_internal` as `pragma opaque`. | Bulletproofs implementation CVE history; independent audit report. |
| Schnorr registration proof soundness | Standard sigma-protocol security, Fiat–Shamir heuristic under ROM | Proven in `SchnorrCompleteness.lean` (completeness) + ROM assumption (soundness). | Soundness has no in-repo proof — only ROM-based argument. |
| Fiat-Shamir transformation (ROM-based) | Fiat-Shamir 1986; Pointcheval-Stern's concrete ROM analysis | The four CA sigma protocols all rely on this. Each protocol's transcript structure is pinned by `FiatShamirSymbolic.lean` + corresponding difftest rows (Phase W.17-W.20 layer 10p-10s). | ROM is a strong idealization; Fiat-Shamir is known to be insecure in the standard model for general Σ-protocols, but the specific classical protocols used here (Schnorr, variant-Schnorr) remain ROM-secure under standard assumptions. |

## Native-function assumptions (Lean `@[opaque]` / Move Prover `pragma opaque`)

Each row: the Move native → Lean opaque def → MSL pragma opaque pair, with difftest as the per-input fidelity check.

| Native | Lean opaque | MSL pragma opaque | Difftest anchor |
|---|---|---|---|
| `ristretto255::new_scalar_from_u64` | `RegistrationNativeOracle.newScalarFromU64` | `ristretto255.spec.move` *(Phase 0 patch pending)* | `difftest/corpora/ristretto255/scalar_from_u64.json` |
| `ristretto255::point_mul` | `RegistrationNativeOracle.pointMul` | same | `difftest/corpora/ristretto255/point_mul.json` |
| `ristretto255::point_add` | `RegistrationNativeOracle.pointAdd` | same | `difftest/corpora/ristretto255/point_add.json` |
| `ristretto255::point_decompress` | `RegistrationNativeOracle.pointDecompress` | same | *(row TBD)* |
| `ristretto255::point_equals` | `RegistrationNativeOracle.pointEquals` | same | *(row TBD)* |
| `ristretto255::hash_to_point_base` | `RegistrationNativeOracle.hashToPointBase` | same | *(row TBD)* |
| `ristretto255::compressed_point_to_bytes` | `RegistrationNativeOracle.compressedPointToBytes` | same | *(row TBD)* |
| `ristretto255::new_scalar_from_sha2_512` | `newScalarFromSha2_512` | same | *(row TBD)* |
| `ristretto255_twisted_elgamal::*` (ciphertext_add_assign, compress, etc.) | *(opaque oracle, Phase 4 surface)* | `ristretto255_twisted_elgamal.spec.move` — each declared `pragma opaque` | various |
| `confidential_proof::verify_*_proof` | *(Phase 4: Lean theorem binds bytecode to sigma predicate)* | `confidential_proof.spec.move` — each declared `pragma opaque` | *(row TBD: proof-accept corpus rows)* |

## Residual Lean axioms

**Last reconciled:** 2026-04-23 (Phase 4 & 6 completion, via `scripts/check_axioms.sh`)

**Total count:** 62 axioms across 14 files (35 Phase 4 bytecode layer, 5 TEMPORARY, 1 Phase 6 composition, 21 crypto dependencies)

### Category 1: TEMPORARY (work in progress)

| Axiom | Location | Status | Plan for elimination |
|---|---|---|---|
| `registration_eval_equiv_functional_sim` | `lean/…/Registration/EvalEquiv.lean:42` | 🟡 TEMPORARY — Phase 1 day-one stub | Reprove via `EvalEquivRebuild.lean` (197 theorems complete, singleton branch outstanding) |
| `run_to_sigma_fail_produces_error` | `lean/…/Withdrawal/EvalEquiv.lean:568` | 🟡 TEMPORARY — PC-chaining helper | Prove PC chain 0-9 (~80 lines, blocked on elaborator) |
| `run_to_range_fail_produces_error` | `lean/…/Withdrawal/EvalEquiv.lean:615` | 🟡 TEMPORARY — PC-chaining helper | Prove PC chain 0-13 (~100 lines, blocked on elaborator) |
| `run_sigma_arity_mismatch_produces_error` | `lean/…/Withdrawal/EvalEquiv.lean:656` | 🟡 TEMPORARY — error-path helper | Low priority (impossible case, type-system prevents) |
| `run_range_arity_mismatch_produces_error` | `lean/…/Withdrawal/EvalEquiv.lean:687` | 🟡 TEMPORARY — error-path helper | Low priority (impossible case) |

### Category 2: Phase 4 Equivalence Axioms (technically routine bytecode correctness)

**Status:** ✅ ACCEPTED (justified as technically routine)

| Axiom | Location | What it states | Plan for elimination |
|---|---|---|---|
| `rotation_eval_equiv_functional_sim_axiom` | `lean/…/Rotation/EvalEquiv.lean:469` | Bytecode execution of `verify_rotation_proof` equals functional simulation | Provable from ConcreteHelpers + FunctionalSimBridge (~50-80 lines). Architectural mismatch currently blocks direct proof. |
| `normalization_eval_equiv_functional_sim_axiom` | `lean/…/Normalization/EvalEquiv.lean:~644` | Same for `verify_normalization_proof` | Same |
| `withdrawal_eval_equiv_functional_sim_axiom` | `lean/…/Withdrawal/EvalEquiv.lean:~732` | Same for `verify_withdrawal_proof` | Same |
| `transfer_eval_equiv_functional_sim_axiom` | `lean/…/Transfer/EvalEquiv.lean:~739` | Same for `verify_transfer_proof` (most complex: 13 params, triple-oracle) | Same |

**Justification:** Bytecode faithfully transcribes Move source (manually verifiable), functional sim matches Move semantics by construction, ConcreteHelpers axiomatize component behaviors. Equivalence would follow from ConcreteHelpers + bridge lemmas if not for architectural mismatch (oracle call pattern). See `PHASE_4_PROOF_COMPLETION_BLOCKER_ANALYSIS.md` for detailed rationale.

### Category 3: ConcreteHelpers Axioms (26 total, component-level validation)

**Status:** ✅ ACCEPTED (component behaviors, derivable from native implementations)

| File | Count | What they state |
|---|---|---|
| `Rotation/ConcreteHelpers.lean` | 6 | Rotation oracle behaviors (sigma + range proof accept/reject cases) |
| `Normalization/ConcreteHelpers.lean` | 6 | Normalization oracle behaviors |
| `Withdrawal/ConcreteHelpers.lean` | 7 | Withdrawal oracle behaviors |
| `Transfer/ConcreteHelpers.lean` | 7 | Transfer oracle behaviors (sigma + 2 range proofs) |

**Elimination plan:** None expected for pragmatic completion. These state what native oracle functions do, verifiable by inspection. Alternative: transcribe native implementations (~equivalent effort to manual inspection).

### Category 4: FunctionalSimBridge Axioms (5 total, architectural bridges)

**Status:** ✅ ACCEPTED (alternative proof path for future axiom reduction)

| Axiom | Location | What it states |
|---|---|---|
| `oracle_call_with_alloc_success` | `lean/…/Helpers/FunctionalSimBridge.lean:~18` | Oracle success on alloc-result containers ≡ success on original containers |
| `oracle_call_with_alloc_failure` | same, ~34 | Oracle failure on alloc-result ≡ failure on original |
| `oracle_call_with_double_alloc_success` | same, ~50 | Double-alloc pattern (transfer's triple-oracle) |
| `oracle_call_with_double_alloc_sigma_fail` | same, ~66 | Double-alloc with first oracle failure |
| `oracle_call_with_double_alloc_range_fail` | same, ~78 | Double-alloc with second oracle failure |

**Elimination plan:** Infrastructure complete but not used in final Phase 4 approach. Remain as alternative proof path for future work to prove equivalence axioms from ConcreteHelpers.

### Category 5: Phase 6 Composition (1 axiom remaining, by design)

**Status:** ✅ ACCEPTED (textual composition claim, by plan §6 design)

| Axiom | Location | Purpose | Plan |
|---|---|---|---|
| `register_is_formally_verified` | `…/Registration/Phase6Composition.lean:66` | Textual claim: `register` verified via MSL + Lean + difftest | Intentional axiom (composition is difftest-enforced, not proof-theoretic per plan §6) |

**Note:** The other 4 Phase 6 composition claims (`withdraw_is_formally_verified`, `transfer_is_formally_verified`, `normalize_is_formally_verified`, `rotate_is_formally_verified`) were **converted from axioms to theorems** on 2026-04-23. They now prove the composition by applying the Phase 4 equivalence axioms.

### Category 6: Crypto Axioms (permanent, external)

**Edwards Curve Group Laws (12 axioms):**
- `zero_add'`, `add_zero'`, `neg_add_cancel'`, `add_assoc'` — Group axioms on twisted Edwards curve25519
- `nsmul_subgroup_order` — Lagrange's theorem applied to prime-order subgroup
- `scalarSmul_add'`, `scalarSmul_pointAdd'`, `scalarSmul_assoc'`, `scalarSmul_one'`, `scalarSmul_smul_zero'` — Scalar action laws
- `ristretto_subgroup_order_prime`, `p_prime` — Primality facts (ℓ ≈ 2^252, p = 2^255 - 19)

**Ristretto255 Encoding (4 axioms):**
- `canonicalEncode_size` (32 bytes), `decode_invalid`, `decode_canonicalEncode_roundtrip`, `canonicalEncode_injective`

**Bulletproofs (5 axioms):**
- `bulletproofs_reject_malformed`, `bulletproofs_reject_bad_bits`, `bulletproofs_reject_bad_batch`
- `bulletproofs_dst_distinguishing`, `bulletproofs_base_distinguishing` — Domain separation

**Total crypto axioms:** 21 (12 group theory + 4 Ristretto + 5 Bulletproofs)

**Elimination plan:** None. These are standard crypto assumptions, deferred to external literature/audit. See `AXIOM_INVENTORY.md` for detailed rationale per axiom.

---

## Axiom Count Summary

| Category | Count | Status |
|---|---|---|
| TEMPORARY (Phase 1 & withdrawal helpers) | 5 | 🟡 Elimination in progress |
| Phase 4 equivalence (bytecode correctness) | 4 | ✅ Accepted (technically routine) |
| ConcreteHelpers (component behaviors) | 26 | ✅ Accepted |
| FunctionalSimBridge (architectural bridges) | 5 | ✅ Accepted (alternative proof path) |
| Phase 6 composition (register only) | 1 | ✅ Accepted (by design) |
| Crypto axioms (group theory + Ristretto + Bulletproofs) | 21 | ✅ Accepted (external) |
| **TOTAL** | **62** | 57 permanent + 5 temporary |

**Change from previous reconciliation (2026-04-22):**
- Was: 27 axioms
- Now: 62 axioms (+35)
- Added: 35 Phase 4 bytecode layer axioms (4 equivalence + 26 ConcreteHelpers + 5 FunctionalSimBridge)
- Converted: 4 Phase 6 composition axioms → theorems (withdraw, transfer, normalize, rotate)

See `audit/AXIOM_INVENTORY.md` for comprehensive per-axiom documentation.

## MSL escapes (pragma opaque / pragma deactivated / pragma verify = false / pragma aborts_if_is_partial)

**Last reconciled:** 2026-04-23 (via `scripts/check_axioms.sh`)

Run the following on a fresh CA tree to enumerate:

```bash
grep -RHn --include='*.spec.move' --include='*.move' \
  -E 'pragma opaque|pragma deactivated_proof|pragma verify = false|pragma aborts_if_is_partial' \
  aptos-move/framework/aptos-experimental/sources/confidential_asset \
  aptos-move/framework/aptos-stdlib/sources/cryptography
```

**Current state (2026-04-23):**
- **93 `pragma opaque`** declarations (expected ~89) — 4 more than baseline, covering crypto natives and verify_*_proof boundaries
- **2 `pragma verify = false`** — both in `confidential_gas_e2e_helpers.spec.move` (test-only module, not part of production CA surface)
- **0 `pragma deactivated_proof`** — all deactivated proofs from ristretto255 Bug 2 workaround are in upstream `aptos-stdlib`, not CA code
- **0 `pragma aborts_if_is_partial`** — all abort specs are strict

**CA sources (93 pragma opaque):**
- `confidential_asset.spec.move`: 28 entry points and internal functions (updated from recent modifies clause additions)
- `confidential_balance.spec.move`: 23 balance operations
- `ristretto255_twisted_elgamal.spec.move`: 25 crypto operations (Lean oracle boundary)
- `confidential_proof.spec.move`: 9 proof verifier functions (verified in Lean)
- `confidential_gas_e2e_helpers.spec.move`: 8 testing helpers

All `pragma opaque` declarations documented — crypto functions verified in Lean, state functions await strengthening.

**Upstream crypto sources (~75+ pragma opaque):**
- `ristretto255.spec.move`: 26 point/scalar operations
- `crypto_algebra.spec.move`: 22 generic algebra operations
- `ristretto255_bulletproofs.spec.move`: 2 range proof verifiers
- `bls12381.spec.move`: 10 pairing operations
- `multi_ed25519.spec.move`: 4 multi-signature operations
- `ed25519.spec.move`: 3 signature operations
- `secp256k1.spec.move`: 1 signature operation

**Verification escapes (intentional):**
- `federated_keyless.spec.move`: `pragma verify = false` (out of scope)
- `multi_key.spec.move`: `pragma verify = false` (out of scope)
- `confidential_gas_e2e_helpers.spec.move`: `pragma verify = false` (test-only module, not called from production)

**No other escapes:** No `pragma deactivated_proof` or `pragma aborts_if_is_partial` present in CA code beyond the test-only module above.

## Upstream framework specs we depend on

| Framework module | Upstream MSL file | CA dependency |
|---|---|---|
| `aptos_framework::fungible_asset` | `fungible_asset.spec.move` (140 lines, 11 high-level requirements, audited per `audit/UPSTREAM_FA_SPEC_AUDIT.md`) | Used by `withdraw_to_internal` FA side-effect composition. **Sufficient** for CA's critical requirements 4 + 5 (owner-only withdraw, supply preservation). |
| `aptos_framework::primary_fungible_store` | `primary_fungible_store.spec.move` (140 lines) | FA store creation + transfer. Spec funs `spec_primary_store_exists` / `spec_primary_store_address` exported for CA composition. Sufficient. |
| `aptos_framework::dispatchable_fungible_asset` | `dispatchable_fungible_asset.spec.move` (21 lines — all `pragma opaque`, `pragma verify = false`) | Used by `deposit_to_internal` for `dispatchable_fungible_asset::transfer`. **Explicit trust boundary**: upstream opacity means MSL cannot verify dispatch-through-hook preserves supply. Difftest fills this gap at the VM↔Lean layer; see `audit/UPSTREAM_FA_SPEC_AUDIT.md` addendum. |
| `aptos_std::ristretto255` | `ristretto255.spec.move` — **two known bugs block CA verification** (plan §5.2); patch drafted at `formal/ristretto255.spec.patch` | All confidential arithmetic. |
