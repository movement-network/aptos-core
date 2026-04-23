# verify-ca.sh Enhancements — 2026-04-22

## Summary

Completed implementation of previously-scaffolded features in `audit/verify-ca.sh`, the Phase 7 reviewer entry point for CA formal verification. The script now provides full-stack verification with timing tracking against plan budgets.

## Changes Made

### 1. Full-Stack Matrix Run (Previously Unimplemented)

**Before:** Exited with "Full-stack run not implemented yet. Use --op for now; see --help."

**After:** Runs all 5 operations (register, withdraw, transfer, normalize, rotate) across specified stack(s), with:
- Per-operation timing
- Per-stack success/failure tracking
- Budget tracking against plan §10.6 limits (≤180s per-op, ≤2700s full run)
- Colored status indicators (✓/✗/⚠)
- Summary table showing timing for each operation
- Exit code 0 on all-pass, non-zero on any failure

**Usage:**
```bash
./verify-ca.sh                  # All ops, all stacks
./verify-ca.sh --stack lean    # All ops, Lean only
```

**Example output:**
```
==========================================
  Full CA verification matrix
==========================================

Running all operations across all stacks...
Budget: ≤2700s (45 min) full run per plan §10.6

--- register ---
  Lean...
  Lean: ✓ (1s)
  Time: 1s

--- withdraw ---
  Lean...
  Lean: ✓ (1s)
  Time: 1s

[...]

==========================================
Summary:
  Verified:  register withdraw transfer normalize rotate

Per-operation times:
  register: 1s
  withdraw: 1s
  transfer: 2s
  normalize: 1s
  rotate: 1s

Total time: 6s
  ✓ Within full-run budget (≤2700s)

  Status: ✓ All operations verified
==========================================
```

### 2. Per-Operation Timing Tracking

Added timing to single-operation runs (`--op <name>`):
- Start/end timestamps for each stack
- Total elapsed time
- Warning if time exceeds per-op budget (180s per plan §10.6)
- Clear budget status indicator

**Example:**
```bash
./verify-ca.sh --op withdraw --stack lean
```
```
--- Lean (withdraw) ---
Build completed successfully (15 jobs).
Lean: OK (1s)

==========================================
Total time: 1s
✓ Within per-op budget (≤180s)
==========================================
```

### 3. Enhanced Claim-Level Dispatch

**Before:** Exited with "Claim-level dispatch not implemented yet (Phase 7 scope)."

**After:** Searches CLAIMS.md for matching claims and displays results with guidance:
- Grep-based fuzzy matching
- Filtered output (no table headers)
- Clear messaging that full dispatch is Phase 7 work
- Fallback instructions to use `--op` and `--stack`

**Usage:**
```bash
./verify-ca.sh --claim "balance"
./verify-ca.sh --claim "registration"
```

### 4. Improved run_lean_for_op Function

- Added optional `quiet` parameter for full-matrix runs
- Updated comments to reflect current theorem counts (206 for Registration, 27/33/22/22 for Phase 4 ops)
- Added output filtering for cleaner full-matrix display
- Piped stderr to stdout for unified output handling

### 5. Coverage Mode Already Functional

Verified that `--coverage` mode works correctly:
- Counts theorems in all EvalEquiv files
- Counts MSL spec blocks
- Runs check_axioms.sh
- Provides comprehensive summary

**Output:**
```
Lean EvalEquivRebuild theorems (Registration, 84-PC bytecode):
206

Lean Phase 4 EvalEquiv theorems:
  Withdrawal: 27 theorems
  Transfer: 33 theorems
  Normalization: 22 theorems
  Rotation: 22 theorems

MSL spec blocks in CA source tree:
  TOTAL: 131

[axiom inventory follows...]
```

## Build & Test Status

All enhancements tested and working:

✅ Single-operation verification with timing (`--op <name> --stack lean`)
✅ Full-stack matrix run (`--stack lean`)
✅ Coverage summary (`--coverage`)
✅ Claim search (`--claim <text>`)
✅ Per-operation budget tracking (≤180s)
✅ Full-run budget tracking (≤2700s)
✅ Exit code handling (0 on success, non-zero on failure)

**Performance:** Full Lean matrix (5 operations) completes in ~6 seconds, well within budget.

## Remaining Work (Phase 7 Scope)

Per plan §10, the following are documented as future work:

1. **Move Prover integration:** Requires Z3_EXE setup (plan §5.1). Scaffolding in place via `run_move_prover_for_op()`, but currently skipped gracefully if Z3_EXE not set.

2. **Difftest integration:** Requires difftest harness at `formal/difftest.sh`. Scaffolding in place via `run_difftest_for_op()`, currently skipped if harness not found.

3. **Claim-level dispatch to specific theorems:** Currently searches and displays matching claims from CLAIMS.md, but doesn't yet dispatch to the minimal verification command for each claim. Requires per-claim command mapping in CLAIMS.md (plan §10.2).

4. **JSON status output:** Plan §10.1 mentions writing status to `audit/last-run.json` for CI integration. Not yet implemented.

5. **Docker/Nix pinning:** Plan §10.4 requires pinned reproducible toolchain. Currently relies on user's local environment.

## Files Modified

- `aptos-move/framework/formal/audit/verify-ca.sh` (~100 lines added/modified)

## Next Steps

1. Set up Move Prover locally (Z3_EXE via `movement update prover-dependencies`)
2. Set up difftest harness
3. Run full 3-stack verification (`./verify-ca.sh` without flags)
4. Document actual timings for Move Prover and Difftest stacks
5. Add JSON output for CI integration
6. Create per-claim command mapping in CLAIMS.md

## Impact

**Immediate value:**
- Reviewers can now verify all Lean proofs with a single command
- Budget tracking makes performance regressions visible immediately
- Full-matrix run validates consistency across all operations

**Phase 7 progress:**
- Plan §10.1 "single-command reproducer" ✓ functional for Lean stack
- Plan §10.6 "per-op ≤3 min, full run ≤45 min" ✓ measured and enforced
- Move Prover and Difftest scaffolding ready for Phase 7 completion

## Measured Performance Against Plan Budgets

| Operation | Lean Time | Budget | Status |
|-----------|-----------|--------|--------|
| register  | 1s        | ≤180s  | ✓      |
| withdraw  | 1s        | ≤180s  | ✓      |
| transfer  | 2s        | ≤180s  | ✓      |
| normalize | 1s        | ≤180s  | ✓      |
| rotate    | 1s        | ≤180s  | ✓      |
| **Full**  | **6s**    | **≤2700s** | **✓** |

All operations are **well within budget**. The Lean stack is performant and ready for reviewer use.
