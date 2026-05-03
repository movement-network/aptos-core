# Move formalization (stdlib-focused branch)

- **Lean:** `lean/` — `MovementFormal` (MoveModel, `move-stdlib` specs, `lake exe difftest`).
- **VM oracle:** `difftest/` — `move-lean-difftest` crate; stdlib-only driver: `difftest-stdlib.sh` (repo root).

```bash
./aptos-move/framework/formal/difftest-stdlib.sh
```

Prereqs: `elan` + Lean 4.24 (see `lean/lean-toolchain`), network once for `lake`/`mathlib` fetch.

**Difftest methodology** (what the oracle is, how suites are registered, checklists): [`difftest/INVENTORY.md`](difftest/INVENTORY.md).

## Docs (under `difftest/`)

| File | What it is |
|------|------------|
| [`difftest/README.md`](difftest/README.md) | Harness overview: oracle JSON, `merge`, adding suites (parts are **CA-era**; stdlib-only workflow is `difftest-stdlib.sh` + `lake exe difftest`). |
| [`difftest/INVENTORY.md`](difftest/INVENTORY.md) | How VM↔Lean difftest is meant to work (source of truth, suite registry checklist). |
| [`difftest/ORACLE_CHANGELOG.md`](difftest/ORACLE_CHANGELOG.md) | JSON `schema_version` and compatible extensions (still the contract for parsers). |
| [`difftest/STUB_POLICY.md`](difftest/STUB_POLICY.md) | Lean column policy (bytecode / natives / globals); **heavy confidential-asset context** — read for model background, not required for stdlib-only runs. |
