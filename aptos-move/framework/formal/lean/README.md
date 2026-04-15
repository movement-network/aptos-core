# AptosFormal (Lean 4)

Machine-checked definitions and proofs for **Aptos Move framework** behavior, structured for growth
beyond a single package.


| Prefix                                                      | Role                                                                                                                                                                                                                                         |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AptosFormal.Std.Hash.`*                                    | SHA3-512/256 vs `aptos_std::aptos_hash`; SHA2-512 for Fiat-Shamir challenges                                                                                                                                                                 |
| `AptosFormal.AptosStd.Crypto.*`                             | Ristretto scalar / wire types vs `aptos_std::ristretto255`                                                                                                                                                                                   |
| `AptosFormal.Std.Bcs.*`                                     | BCS primitives                                                                                                                                                                                                                               |
| `AptosFormal.Std.MoveStdlibGoldens`                         | Byte-level golden tests for hash/BCS/vector                                                                                                                                                                                                  |
| `AptosFormal.Move.*`                                        | Move bytecode interpreter (`Step`, `Programs`, natives → specs); roadmap: `[AptosFormal/Move/README.md](AptosFormal/Move/README.md)`                                                                                                         |
| `AptosFormal.Refinement.*`                                  | Proofs that selected bytecode matches `Std.*` specs (e.g. `vector::contains`, `vector::index_of`, `std::error` functions, `bit_vector::length`)                                                                                              |
| `AptosFormal.Std.Error`                                     | Lean spec for `std::error` — `canonical` + 13 category wrappers; all `@[simp]` lemmas                                                                                                                                                        |
| `AptosFormal.Std.FixedPoint32`                              | Lean spec for `std::fixed_point32` — `multiply_u64`, `divide_u64`, `create_from_rational`, `floor`/`ceil`/`round` (overflow-safe via `Nat`)                                                                                                  |
| `AptosFormal.Std.BitVector`                                 | Lean spec for `std::bit_vector` — `new`, `set`, `unset`, `is_index_set`, `shift_left`; `shift_left_zero` proved                                                                                                                              |
| `AptosFormal.Std.Option`                                    | Lean spec for `std::option` — all functions including `swap_or_fill` (correct displaced-value semantics)                                                                                                                                     |
| `AptosFormal.Std.Signer`                                    | Lean spec for `std::signer` — native `borrow_address` / `address_of`                                                                                                                                                                         |
| `AptosFormal.Move.Programs.StdPrimitives`                   | Bytecode programs for `std::error` (canonical + 13 wrappers) and `bit_vector::length`                                                                                                                                                        |
| `AptosFormal.Move.Native.StdPrimitives`                     | Native bindings for `std::signer`, `std::fixed_point32`, `std::bit_vector`, `std::option`                                                                                                                                                    |
| `AptosFormal.Refinement.StdPrimitives`                      | `rfl`-proved refinement theorems: bytecode ↔ Lean spec for all error functions and `bit_vector::length`                                                                                                                                      |
| `AptosFormal.Tests.StdPrimitives`                           | `native_decide` smoke tests for all five stdlib modules                                                                                                                                                                                      |
| `AptosFormal.DiffTest.*`                                    | Lean side of VM ↔ Lean differential tests (JSON oracles); see `[../difftest/README.md](../difftest/README.md)`                                                                                                                               |
| `AptosFormal.Tests.*`                                       | Concrete smoke tests (`native_decide`) on the evaluator                                                                                                                                                                                      |
| `AptosFormal.Experimental.ConfidentialAsset.Registration.*` | `verify_registration_proof`: crypto proofs (L0), operational spec (L1), functional simulation (L1.5), bytecode refinement (L2), `native_decide` difftest proofs. See `[../REGISTRATION_VERIFY_REVIEW.md](../REGISTRATION_VERIFY_REVIEW.md)`. |


### Confidential assets: difftest (L1) vs formal verification (L0–L2+)

- **Difftest (alignment, not a proof):** real Move VM JSON oracles vs Lean `eval` on the same cases. CA adds a **transactional** fragment from `e2e-move-tests` merged in CI; many rows use **witness** bytecode in Lean (`RunnerFuncMappingAux` / `Programs.Confidential`), not a full FA + storage replay. **Roadmap / Option B (globals):** `[../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md](../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md)`. **Inventory log:** `[../difftest/inventory/confidential_assets.md](../difftest/inventory/confidential_assets.md)`. **Local CI-shaped run:** `DIFTEST_MERGE_CA_E2E=1 ./aptos-move/framework/formal/difftest.sh` (from repo root; see `[../difftest/README.md](../difftest/README.md)` § “CI parity”).
- **Formal verification:** registration **crypto / transcript** story in `AptosFormal.Experimental.ConfidentialAsset.Registration.`* (L0-heavy); bytecode **refinement** and constant views in `AptosFormal.Refinement.Confidential` + `Move.State` / `Move.Step` scaffolding toward L2–L4. **Program bar (A)/(B)/(C) and levels L0–L5:** `[../CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md](../CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md)`.

**Auditor-oriented narrative** (Confidential Asset registration / `**verify_registration_proof` only**):
`[../REGISTRATION_VERIFY_REVIEW.md](../REGISTRATION_VERIFY_REVIEW.md)`.

**CA Move audit notes** (API semantics / `#[test_only]` prover preconditions — formal-track review):
`[../CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md](../CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md)`.

## Prerequisites


| Dependency                                                  | Version     | Notes                                                        |
| ----------------------------------------------------------- | ----------- | ------------------------------------------------------------ |
| [elan](https://github.com/leanprover/elan)                  | latest      | Lean version manager (like `rustup` for Lean)                |
| Lean 4                                                      | **4.24.0**  | Pinned in `lean-toolchain`; `elan` installs it automatically |
| [Mathlib](https://github.com/leanprover-community/mathlib4) | **v4.24.0** | Fetched by Lake on first build                               |


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

This should return **no matches** for the core stdlib specs (`Std.`*, `Move.Programs.StdPrimitives`, `Refinement.StdPrimitives`).

> **Note:** `Refinement/Vector.lean` contains a `sorry` in the `vector::reverse` proof sketch only;
> the `vector::contains` and `vector::index_of` refinements are fully kernel-checked (no `sorry`).
> `Std/FixedPoint32.lean` and `Std/BitVector.lean` have a small number of `sorry` on auxiliary
> lemmas tracked for future work.
> `Experimental/ConfidentialAsset/` contains flagged `sorry`s on abstract bytecode stepping
> — see inline comments for status. (The word "sorry" may appear in comments explaining what
> *could* be sorry'd; `grep` for `sorry` outside comments if you want to be precise, or run
> `lake env printPaths` and inspect the `.olean` files for `sorryAx` usage.)

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


| Axiom                            | What it is                   | Concern                                            |
| -------------------------------- | ---------------------------- | -------------------------------------------------- |
| `propext`                        | Propositional extensionality | Built-in; universally accepted                     |
| `Quot.sound`                     | Quotient soundness           | Built-in; universally accepted                     |
| `Classical.choice`               | Law of excluded middle       | Standard classical logic; used by Mathlib          |
| `ristretto_subgroup_order_prime` | ℓ is prime                   | **Our only custom axiom** — see §6.5 of review doc |


If you see `sorryAx` in the output, something is wrong — a proof has been bypassed.

## Differential tests (Lean evaluator vs real Move VM)

The primary validation layer. The Rust Move VM runs concrete inputs, produces a JSON oracle
of return values / aborts, then the Lean bytecode evaluator replays the same inputs and
compares. This validates that Lean's `step`/`eval` execution model — the foundation all
refinement proofs are built on — tracks the real VM.

**One command** (from repo root):

```bash
./aptos-move/framework/formal/difftest.sh
```

Runs the Rust oracle (all suites), then Lean, using **`difftest/difftest_oracle.json`**.
Per-suite runs and CLI flags: [**`../difftest/README.md`**](../difftest/README.md).

## Companion Move golden tests

These Move tests run specific inputs through the **real Move VM** (native Rust crypto) and
assert expected byte outputs. They complement difftests in two ways:

- **Ristretto / verification equation goldens:** Test native group operations that Lean
  **axiomatizes** (e.g. `ristretto_subgroup_order_prime`). Difftests can't validate these
  because Lean doesn't execute the real crypto — these goldens are the only check that
  Lean's axioms match the VM's natives.
- **Fiat-Shamir transcript / BCS / hash goldens:** Supplementary byte-level checks.
  `verify_registration_proof` already has full bytecode refinement (L2) and difftests,
  so these are a lightweight cross-check on the specific transcript constants, not the
  primary evidence. For stdlib (BCS, hash, vector), difftests are the stronger check.

| Test file | What it checks | Run command |
|-----------|---------------|-------------|
| `aptos-experimental/tests/.../formal_goldens_ristretto.move` | Ristretto group-law properties (§6.2) — **axiom boundary** | `movement move test --package-dir aptos-move/framework/aptos-experimental` |
| `aptos-experimental/tests/.../formal_goldens_verification_equation.move` | Full verification equation (§6.1) — **axiom boundary** | same as above |
| `aptos-experimental/tests/.../formal_goldens_registration.move` | Fiat-Shamir transcript bytes — supplementary to L2 refinement | same as above |
| `move-stdlib/tests/formal_goldens_bcs.move` | BCS encoding of primitives — supplementary to difftests | `movement move test --package-dir aptos-move/framework/move-stdlib` |
| `move-stdlib/tests/formal_goldens_hash.move` | SHA3-256/512 + keccak golden bytes — supplementary to difftests | same as above |
| `move-stdlib/tests/formal_goldens_vector.move` | Vector operations — supplementary to difftests | same as above |
| `move-stdlib/tests/formal_goldens_bcs_address.move` | BCS address → 32 raw bytes (§6.3) — supplementary to difftests | same as above |

```bash
movement move test --package-dir aptos-move/framework/move-stdlib --filter formal_goldens
movement move test --package-dir aptos-move/framework/aptos-experimental --filter formal_goldens
```

### Checking Move / Lean golden consistency

Golden byte constants (SHA2/SHA3 digests, BCS addresses, FS transcript messages) are duplicated
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