# AptosFormal (Lean 4)

Machine-checked definitions and proofs for **Aptos Move framework** behavior, structured for growth
beyond a single package.

| Prefix | Role |
| ------ | ---- |
| `AptosFormal.Std.Hash.*` | SHA3-512 tagged hash vs `aptos_std::aptos_hash` |
| `AptosFormal.AptosStd.Crypto.*` | Ristretto scalar / wire types vs `aptos_std::ristretto255` |
| `AptosFormal.Std.Bcs.*` | BCS primitives |
| `AptosFormal.Std.MoveStdlibGoldens` | Byte-level golden tests for hash/BCS/vector |
| `AptosFormal.Experimental.ConfidentialAsset.Registration.*` | `verify_registration_proof` spec + proofs |

Auditor-oriented narrative: [`../REGISTRATION_VERIFY_REVIEW.md`](../REGISTRATION_VERIFY_REVIEW.md).

## Prerequisites

| Dependency | Version | Notes |
| ---------- | ------- | ----- |
| [elan](https://github.com/leanprover/elan) | latest | Lean version manager (like `rustup` for Lean) |
| Lean 4 | **4.24.0** | Pinned in `lean-toolchain`; `elan` installs it automatically |
| [Mathlib](https://github.com/leanprover-community/mathlib4) | **v4.24.0** | Fetched by Lake on first build |

Install `elan` (macOS/Linux):

```bash
curl https://elan.dev/install.sh -sSf | sh
```

## Building the proofs

```bash
cd aptos-move/framework/formal/lean
lake build
```

**First build** downloads the Mathlib toolchain cache (~1 GB) and compiles all modules.
Subsequent builds are incremental and fast.

**Expected output on success:** no errors, no warnings (other than potential Mathlib `simp` linter
notes which do not affect soundness). The build exits with code 0.

## Verifying there are no `sorry`

A `sorry` in Lean is an axiom that lets you skip a proof — it makes the entire file unsound.
After building, check that none exist:

```bash
cd aptos-move/framework/formal/lean
grep -r "sorry" AptosFormal/ --include="*.lean"
```

This should return **no matches**. (The word "sorry" may appear in comments explaining what
*could* be sorry'd; `grep` for `sorry` outside comments if you want to be precise, or run
`lake env printPaths` and inspect the `.olean` files for `sorryAx` usage.)

You can also check what axioms any theorem depends on. Create a file `_check_axioms.lean`:

```lean
import AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd
import AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity
import AptosFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic

open AptosFormal.Experimental.ConfidentialAsset.Registration.EndToEnd
open AptosFormal.Experimental.ConfidentialAsset.Registration.CryptoSecurity
open AptosFormal.Experimental.ConfidentialAsset.Registration.FiatShamirSymbolic

#print axioms registration_verification_iff_schnorr
#print axioms registration_honest_prover_accepted
#print axioms registrationSchnorr_witness_extraction
#print axioms registrationSchnorr_simulate_accepts
#print axioms fiatShamir_forking_extraction
#print axioms fiatShamir_challenge_binding
#print axioms fiatShamir_completeness
#print axioms fiatShamir_nizk_simulate_accepts
```

Then run it:

```bash
lake env lean _check_axioms.lean
```

Expected output:

```
'...registration_verification_iff_schnorr' depends on axioms: [propext, Quot.sound]
'...registration_honest_prover_accepted' depends on axioms: [propext, Quot.sound]
'...registrationSchnorr_witness_extraction' depends on axioms: [propext, Classical.choice, Quot.sound, ...ristretto_subgroup_order_prime]
'...registrationSchnorr_simulate_accepts' depends on axioms: [propext, Quot.sound]
```

| Axiom | What it is | Concern |
|-------|-----------|---------|
| `propext` | Propositional extensionality | Built-in; universally accepted |
| `Quot.sound` | Quotient soundness | Built-in; universally accepted |
| `Classical.choice` | Law of excluded middle | Standard classical logic; used by Mathlib |
| `ristretto_subgroup_order_prime` | ℓ is prime | **Our only custom axiom** — see §6.5 of review doc |

If you see `sorryAx` in the output, something is wrong — a proof has been bypassed.

## Companion Move golden tests

These Move test files provide empirical evidence for assumptions that Lean cannot check
(native crypto operations, BCS encoding). Run them from the repo root:

| Test file | What it checks | Run command |
| --------- | -------------- | ----------- |
| `move-stdlib/tests/formal_goldens_bcs.move` | BCS encoding of primitives | `aptos move test --package-dir aptos-move/framework/move-stdlib` |
| `move-stdlib/tests/formal_goldens_hash.move` | SHA3-256/512 + keccak golden bytes | same as above |
| `move-stdlib/tests/formal_goldens_vector.move` | Vector operations | same as above |
| `move-stdlib/tests/formal_goldens_bcs_address.move` | BCS address → 32 raw bytes (§6.3) | same as above |
| `aptos-experimental/tests/confidential_asset/formal_goldens_registration.move` | Fiat-Shamir transcript bytes | `aptos move test --package-dir aptos-move/framework/aptos-experimental` |
| `aptos-experimental/tests/confidential_asset/formal_goldens_ristretto.move` | Ristretto group-law properties (§6.2) | same as above |
| `aptos-experimental/tests/confidential_asset/formal_goldens_verification_equation.move` | Full verification equation: honest proof passes, corrupted/wrong-dk rejected (§6.1) | same as above |

Run all formal golden tests at once:

```bash
aptos move test --package-dir aptos-move/framework/move-stdlib --filter formal_goldens
aptos move test --package-dir aptos-move/framework/aptos-experimental --filter formal_goldens
```

## Differential tests (Lean evaluator vs real Move VM)

**One command** (from repo root): `./aptos-move/framework/formal/difftest.sh` — runs the Rust oracle (all suites), then Lean, using **`difftest/difftest_oracle.json`**. Per-suite runs and CLI flags: **[`../difftest/README.md`](../difftest/README.md)**.

## Checking Move / Lean golden consistency

Golden byte constants (SHA3 digests, BCS addresses, FS transcript messages) are duplicated
between Move test files and Lean source. A consistency check script verifies they haven't drifted:

```bash
bash aptos-move/framework/formal/check_golden_consistency.sh
```

Expected output: `All golden bytes consistent.` with exit code 0.
Run this after modifying any golden test or Lean byte constant. Requires `python3`.

## Editor setup

**Project root for Lean:** this directory (`aptos-move/framework/formal/lean`).

If your editor workspace is the `aptos-core` repo root, use **"Open Local Project"** (or
**"Lean 4: Select Toolchain"**) in the VS Code Lean 4 extension and point it at this directory.
Alternatively, open this directory directly as a workspace.
