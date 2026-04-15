# Aptos Move — formal methods (`AptosFormal`)

This directory holds **Lean 4** proofs for the Aptos framework, structured so **`AptosFormal.Std.*`**
tracks **stdlib**-aligned primitives (`aptos-stdlib`, `move-stdlib`, …) and
**`AptosFormal.Experimental.*`** tracks **package-specific** specs (e.g. confidential assets).

| Path | Contents |
| ---- | -------- |
| [`lean/`](lean/) | Lake project root — see [`lean/README.md`](lean/README.md) for **prerequisites and build instructions** (stdlib specs, bytecode refinement for `vector::contains` / `vector::index_of` / `std::error` / `bit_vector::length`, CA formal work) |
| [`REGISTRATION_VERIFY_REVIEW.md`](REGISTRATION_VERIFY_REVIEW.md) | Auditor-facing review note for `verify_registration_proof` |
| `../move-stdlib/tests/formal_goldens_*.move` | Curated Move stdlib tests (hash / BCS / vector) aligned with `AptosFormal.Std.MoveStdlibGoldens` |
| `../aptos-experimental/tests/confidential_asset/formal_goldens_*.move` | Move golden tests for Ristretto group laws, Fiat–Shamir transcript bytes, and verification equation |
| [`check_golden_consistency.sh`](check_golden_consistency.sh) | Script to verify Move and Lean golden bytes haven't drifted apart |
| [`difftest.sh`](difftest.sh) | **Differential** tests: VM → `difftest/difftest_oracle.json` → Lean. Set **`DIFTEST_MERGE_CA_E2E=1`** to also export the CA e2e fragment, merge into `difftest_ci_merged.json`, and run Lean on the merged oracle (matches CI). See [`difftest/README.md`](difftest/README.md). |
| [`difftest/INVENTORY.md`](difftest/INVENTORY.md) | **Phase 0** hub: difftest methodology, `--list-suites`, per-package inventories (e.g. confidential assets) |
| [`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md) | Roadmap for confidential-asset **difftest-only** track (Phases 0–5); Option **B** for globals-free slices |

## Quick start

Requires [elan](https://github.com/leanprover/elan) (Lean version manager). The toolchain
(Lean 4.24.0 + Mathlib 4.24.0) is pinned in `lean/lean-toolchain` and `lean/lakefile.lean`.

```bash
cd aptos-move/framework/formal/lean
lake build
```

See [`lean/README.md`](lean/README.md) for full details on verifying no `sorry` exists, checking
axioms, running companion Move golden tests, differential tests (`difftest.sh`), and editor setup.

## Directory design

The formal directory lives at `framework/formal/` (not inside `aptos-experimental/`) because
`AptosFormal.Std.*` modules are **shared across the entire framework**, not specific to any one
package.

Add future formal trees alongside the same pattern, e.g. `AptosFormal.Framework.*` for
`aptos-framework` modules, reusing `AptosFormal.Std.*` where Move calls into `aptos_std`.
