# Difftest inventory — `<PACKAGE_NAME>` (template)

**Move root (relative to repo):** `aptos-move/framework/<…>/sources/…`  
**Rust suite id (when implemented):** `<suite_id>`  
**Lean module / `ModuleEnv`:** `<LeanPrograms.*>`

## Methodology

- **VM↔Lean:** Oracle bytes come from **VM execution**; Lean must **independently** reproduce them. A **mismatch** means Move bytecode, Lean transcription, Lean `Step`, or Lean natives disagree — **investigate**; do not “fix” the test to match Lean without VM evidence.
- **VM-only:** Oracle for regression / tooling; Lean skipped until wired.
- **Blocked:** Document blocker (e.g. globals, missing `MoveInstr`).

## Native / dependency closure

*(List `use` lines and any `native fun` in transitive modules the VM will execute for your cases.)*

| Module | Role |
| ------ | ---- |
| | |

## Public surface inventory

| Symbol | Kind | Observable outcome | Planned mode | Notes / priority |
| ------ | ---- | -------------------- | ------------ | ---------------- |
| | | | Blocked | |

## Oracle cases (concrete)

| Case id | Entry | Inputs (summary) | Expected | Mode |
| ------- | ----- | ------------------ | -------- | ---- |
| | | | | Blocked |

## Skipped / out of scope

- 

## Changelog

| Date | Change |
| ---- | ------ |
| | Created from template. |
