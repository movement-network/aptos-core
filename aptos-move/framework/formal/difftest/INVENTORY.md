# Difftest inventory & methodology (Phase 0)

This document is the **hub** for planning and extending **Move VM ↔ Lean** differential tests (`move-lean-difftest` + `lake exe difftest`). It applies to **any** Move package you later wire into the harness (stdlib wrappers, framework modules, confidential assets, …).

## 1. Source of truth — tests are allowed to fail

- The **JSON oracle** is produced by running the **real Move VM** (Rust) on concrete inputs. Those outputs are treated as **ground truth for that run**.
- The **Lean** side **re-computes** the same case using `MovementFormal.MoveModel` and **compares** to the oracle.
- **If Move code is wrong** but Lean matches a *correct* spec, the VM oracle will still record what Move *actually* did — a **later** Lean change to match buggy Move would show as “passing” while being wrong. The intended discipline is:
  - **Independent** expectations for high-value cases (e.g. golden vectors from crypto reviews, or second tooling), **or**
  - **Regression**: when you **intentionally fix** Move, the oracle **must be regenerated**; Lean should then match the **new** VM behavior — a **failure** before regen catches drift.
- **If Lean is wrong** (transcription, missing instruction, wrong native), comparison **fails** — that is the point of difftest.

Neither implementation is assumed correct **by construction**; agreement is **evidence** on the oracle set only.

## 2. Suite registry (generic harness)

- **Rust:** one implementation of `DiffTestSuite` per logical area; register in [`src/suites/mod.rs`](src/suites/mod.rs) (`all_suites` + `suites_filtered` match arms — **keep match arms in sync** with `all_suites()`).
- **List ids:** `cargo run -p move-lean-difftest -- --list-suites` or `./aptos-move/framework/formal/difftest.sh --list-suites`.
- **Lean:** extend `MovementFormal.DiffTest.Runner` (`funcNameToMapping` / case dispatch) and `Move` `ModuleEnv` / natives for each **new** function you add to an oracle.

See [`README.md`](README.md) § *Adding coverage* for the file-level checklist.

## 3. Inventory artifacts (Phase 0 deliverables)

| Document | Purpose |
| -------- | ------- |
| [`STUB_POLICY.md`](STUB_POLICY.md) | Lean column: bytecode vs natives vs abstract globals (CA plan §3). |
| [`inventory/README.md`](inventory/README.md) | Index of per-package inventories. |
| [`inventory/confidential_assets.md`](inventory/confidential_assets.md) | **Confidential assets (experimental)** — public API surface, difftest mode per symbol, native/transitive deps. Independent vectors (checklist §4.3 iii): [`corpora/confidential_assets/README.md`](corpora/confidential_assets/README.md). |
| [`inventory/confidential_native_matrix.md`](inventory/confidential_native_matrix.md) | **CA native / crypto matrix** — `aptos_std` Ristretto/BP/hash vs Lean status (FV plan Workstream A). |
| [`inventory/move_framework_template.md`](inventory/move_framework_template.md) | Blank template for **other** Move framework packages. |

## 4. Difftest modes (per function / case)

Use these labels in inventory tables:

| Mode | Meaning |
| ---- | ------- |
| **VM↔Lean** | Full differential: oracle from VM, Lean `eval` must match. |
| **VM-only** | Oracle recorded from VM; Lean column **skipped** until model exists (document reason). |
| **Blocked** | Cannot run in harness yet (missing compiler support, storage, …). |

## 5. When you add a new suite (checklist)

1. Add `src/suites/<name>.rs` implementing `DiffTestSuite`.
2. Register in `all_suites()` **and** the `suites_filtered` match in [`mod.rs`](src/suites/mod.rs).
3. Run `cargo run -p move-lean-difftest -- --list-suites` and confirm the new id appears.
4. Extend Lean `DiffTest` runner + `ModuleEnv` for each `TestCase` you emit.
5. Add an **`inventory/<topic>.md`** row or standalone doc for long-term tracking.

## 6. Related plans

- Confidential assets **difftest-only** roadmap: [`../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md`](../CONFIDENTIAL_ASSETS_DIFFERENTIAL_TESTING_PLAN.md) (Phase 0 marked complete there with pointer here).
- Full formal verification (refinement + globals): [`../CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md`](../CONFIDENTIAL_ASSETS_FORMAL_VERIFICATION_PLAN.md).
