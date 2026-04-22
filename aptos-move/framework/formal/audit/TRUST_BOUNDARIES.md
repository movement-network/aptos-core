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
| Bulletproofs soundness and completeness | Bünz et al. 2017, external audit of implementation | Plan §3 / §5 explicitly axiomatize (no Lean implementation in scope). | Bulletproofs implementation CVE history; independent audit report. |
| Schnorr registration proof soundness | Standard sigma-protocol security, Fiat–Shamir heuristic under ROM | Proven in `SchnorrCompleteness.lean` (completeness) + ROM assumption (soundness). | Soundness has no in-repo proof — only ROM-based argument. |

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

| Axiom | Location | Status | Plan for elimination |
|---|---|---|---|
| `registration_eval_equiv_functional_sim` | `lean/…/Registration/EvalEquiv.lean` | 🟡 TEMPORARY AXIOM (Phase 1 day-one) | Reprove in Phase 1 completion commit. |

## MSL escapes (pragma opaque / pragma deactivated / pragma verify = false / pragma aborts_if_is_partial)

Run the following on a fresh CA tree to enumerate:

```
grep -RHn --include='*.spec.move' --include='*.move' \
  -E 'pragma opaque|pragma deactivated_proof|pragma verify = false|pragma aborts_if_is_partial' \
  aptos-move/framework/aptos-experimental/sources/confidential_asset \
  aptos-move/framework/aptos-stdlib/sources/cryptography
```

Current state (2026-04-21): all `pragma opaque` declarations are in the scaffolded specs in `aptos-experimental/sources/confidential_asset/*.spec.move`; each is tagged to a Lean counterpart or a difftest corpus anchor above. No `pragma verify = false` or `pragma deactivated_proof` escapes present.

## Upstream framework specs we depend on

| Framework module | Upstream MSL file | CA dependency |
|---|---|---|
| `aptos_framework::fungible_asset` | `fungible_asset.spec.move` (140 lines in upstream aptos-framework) | Used by `deposit_to_internal` / `withdraw_to_internal` / `confidential_transfer_internal` FA side-effect composition (Phase 5). Audit required: are upstream specs sufficient? (See plan §8 Open Q 3.) |
| `aptos_framework::primary_fungible_store` | `primary_fungible_store.spec.move` *(upstream)* | FA store creation + transfer in `deposit_to_internal`. |
| `aptos_framework::dispatchable_fungible_asset` | *(upstream)* | FA transfer in `deposit_to_internal`. |
| `aptos_std::ristretto255` | `ristretto255.spec.move` — **two known bugs block CA verification** (plan §5.2) | All confidential arithmetic. |
