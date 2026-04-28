# Aptos Move — formal methods (`MovementFormal`)

This directory holds **Lean 4** proofs for the Aptos framework, structured so **`MovementFormal.Std.*`**
tracks **stdlib**-aligned primitives (`aptos-stdlib`, `move-stdlib`, …) and
**`MovementFormal.Experimental.*`** tracks **package-specific** specs (e.g. confidential assets).

| Path | Contents |
| ---- | -------- |
| [`lean/`](lean/) | Lake project root — see [`lean/README.md`](lean/README.md) for **prerequisites and build instructions** |
| [`lean/MovementFormal/MoveModel/README.md`](lean/MovementFormal/MoveModel/README.md) | **Bytecode model + implementation roadmap** — phases 1–9 with progress summary, instruction set, evaluator, refinement proofs |
| [`REGISTRATION_VERIFY_REVIEW.md`](REGISTRATION_VERIFY_REVIEW.md) | Auditor-facing review note for `verify_registration_proof` |
| [`CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md) | Roadmap for confidential-asset **formal verification** (L0–L5 levels, workstreams A–F) |
| [`CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md) | Roadmap for confidential-asset **difftest-only** track (Phases 0–5); Option **B** for globals-free slices |
| [`CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md`](CONFIDENTIAL_ASSETS_MOVE_AUDIT_NOTES.md) | CA Move source audit notes — API semantics, `#[test_only]` preconditions, wire format observations |
| [`difftest/INVENTORY.md`](difftest/INVENTORY.md) | **Phase 0** hub: difftest methodology, `--list-suites`, per-package inventories (e.g. confidential assets) |
| [`difftest.sh`](difftest.sh) | **Differential** tests: VM → `difftest/difftest_oracle.json` → Lean. Set **`DIFTEST_MERGE_CA_E2E=1`** for merged CA e2e. See [`difftest/README.md`](difftest/README.md). |
| `../move-stdlib/tests/formal_goldens_*.move` | Curated Move stdlib tests (hash / BCS / vector) aligned with `MovementFormal.Std.MoveStdlibGoldens` |
| `../aptos-experimental/tests/confidential_asset/formal_goldens_*.move` | Move golden tests for Ristretto group laws, Fiat–Shamir transcript bytes, and verification equation |
| [`check_golden_consistency.sh`](check_golden_consistency.sh) | Script to verify Move and Lean golden bytes haven't drifted apart |

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
`MovementFormal.Std.*` modules are **shared across the entire framework**, not specific to any one
package.

Add future formal trees alongside the same pattern, e.g. `MovementFormal.Framework.*` for
`aptos-framework` modules, reusing `MovementFormal.Std.*` where Move calls into `aptos_std`.

## `move-stdlib` coverage (snapshot)

The Lake package was renamed from **`AptosFormal`** to **`MovementFormal`**, and the Lean namespace
for Move stdlib specs from **`AptosFormal.Std`** to **`MovementFormal.Std`**. Full
**refinement proofs** (`bytecode eval` ↔ **Lean spec**) plus **difftest** rows for *every* `std::*`
module and function is a **long-running** goal; below is an honest snapshot of what exists in-tree
today (`lake build` succeeds).

| Move module (`third_party/move/move-stdlib/sources`) | Lean specs | Difftest / goldens | Refinement notes |
| ---------------------------------------------------- | ---------- | ------------------ | ---------------- |
| `bcs` | `Std.Bcs` (`uleb128`, `vectorU8Bcs`, …), `MoveModel.BcsCatalog` (indices 0–17), `Refinement.Std.Bcs` | `formal_goldens_bcs.move` + `difftest` `bcs` suite (39 oracle rows: `to_bytes`, `serialized_size`, `constant_serialized_size`) | `bcsU64_correct` in `Refinement/Std/Core`; catalog `rfl` lemmas in `Refinement/Std/Bcs` |
| `hash` | `Std.Hash` (Keccak + SHA3-256) | `formal_goldens_hash.move` | partial vs full `std::hash` surface |
| `vector` | `Std.Vector` | goldens + difftest suites | `contains` / `index_of` proved; `reverse` proof sketch |
| `option` | `Std.Option` | `SmokeTests.StdPrimitives` | exercised via `Native/StdPrimitives` |
| `error` | `Std.Error` | — | `Refinement.Std.StdPrimitives` (`rfl` for canonical + categories) |
| `signer` | `Std.Signer` | — | native model in `Native/StdPrimitives` |
| `fixed_point32` | `Std.FixedPoint32` | — | native model; some auxiliary `sorry` in spec file |
| `bit_vector` | `Std.BitVector` | — | `bit_vector::length` refinement + natives |
| `string` | `Std.String` (`utf8_bytes_well_formed` via `String.fromUTF8?`) | `formal_goldens_string.move` | UTF-8 predicate smoke tests; full `internal_*` **natives** not modeled in `eval` |
| `type_name` | `Std.TypeName` (accessors + `TypeName` record) | — | `get<T>()` is **native** and not in the packaged framework `move-stdlib` sources — accessors only |
| `unit_test` | — | — | intentionally out of scope for production proofs |

**VM↔Lean difftest:** extending `string` goldens to the JSON harness follows the `bcs` / `vector` suite pattern (harness module + `RunnerFuncMappingAux` indices).
