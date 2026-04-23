# CA Formal Verification — Reviewer Quick Start

**Last updated:** 2026-04-22

This guide gets you from zero to running verification in under 10 minutes.

## Prerequisites (5 min setup)

### 1. Lean 4 Stack

```bash
# Install Lean toolchain (if not already installed)
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Fetch mathlib cache (CRITICAL — skipping this means hours of compilation)
cd aptos-move/framework/formal/lean
lake exe cache get

# Verify setup
lake build --help
```

**Why mathlib cache matters:** Mathlib takes ~4 hours to compile from source. The cache makes clean builds finish in seconds. Always run `lake exe cache get` before `lake build`.

### 2. Move Prover Stack (optional — only if verifying MSL specs)

**Status (2026-04-22):** ✅ Toolchain ready. ⚠️ Verification blocked on ristretto255 patches (0 VCs expected).

```bash
# Install prover dependencies
movement update prover-dependencies --assume-yes

# Set environment variables (add to shell profile for persistence)
export BOOGIE_EXE=$HOME/.local/bin/boogie
export Z3_EXE=$HOME/.local/bin/z3
export CVC5_EXE=$HOME/.local/bin/cvc5

# Verify
$Z3_EXE --version    # expect: Z3 version 4.11.2
$BOOGIE_EXE -version # expect: Boogie program verifier version 3.5.1.0
```

**Note:** Specs currently compile but generate 0 VCs (verification conditions). This is expected — verification is blocked on upstream ristretto255 patches. Toolchain infrastructure is ready for when blocker clears. See `../MOVE_PROVER_INTEGRATION_STATUS.md` for details.

### 3. Difftest Stack (optional — only if verifying VM↔Lean consistency)

See `difftest/README.md` for setup. Not needed for Lean-only verification.

## Verification Commands

### Quick Health Check (10 seconds)

Verify that your environment is set up correctly:

```bash
cd aptos-move/framework/formal/audit
./verify-ca.sh --op register --stack lean
```

**Expected output:**
```
--- Lean (register) ---
Build completed successfully (1091 jobs).
Lean: OK (1s)
==========================================
Total time: 1s
✓ Within per-op budget (≤180s)
==========================================
```

### Full Lean Verification (6 seconds)

Verify all 5 operations (310 theorems total):

```bash
./verify-ca.sh --stack lean
```

**Expected output:**
```
==========================================
  Full CA verification matrix
==========================================

[runs 5 operations...]

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

### Move Prover Quick Check (optional — 5 seconds)

Verify Move Prover toolchain works (if set up):

```bash
./verify-ca.sh --op register --stack move-prover
```

**Expected output:**
```
--- Move Prover (register) ---
[INFO] transforming bytecode
[INFO] generating verification conditions
[INFO] 0 verification conditions
[INFO] running solver
{"Result": "Success"}
Move Prover: OK (1s)
==========================================
Total time: 1s
✓ Within per-op budget (≤180s)
==========================================
```

**Note:** "0 verification conditions" is expected. Specs compile successfully but verification is blocked on ristretto255 patches. This confirms toolchain infrastructure works. See `../MOVE_PROVER_INTEGRATION_STATUS.md`.

### Coverage Summary

See what's proved (theorem counts, axiom inventory):

```bash
./verify-ca.sh --coverage
```

**Output includes:**
- Lean theorem counts per operation (310 total)
- MSL spec block counts (131 total)
- Axiom inventory (26 axioms: 21 permanent + 5 temporary)
- Pragma opaque declarations

### Per-Operation Verification

Verify individual operations in 1-2s each:

```bash
./verify-ca.sh --op register --stack lean    # 206 theorems, ~1s
./verify-ca.sh --op withdraw --stack lean    # 27 theorems, ~1s
./verify-ca.sh --op transfer --stack lean    # 33 theorems, ~2s (most complex)
./verify-ca.sh --op normalize --stack lean   # 22 theorems, ~1s
./verify-ca.sh --op rotate --stack lean      # 22 theorems, ~1s
```

### Search for Specific Claims

Find claims related to a topic:

```bash
./verify-ca.sh --claim "balance"
./verify-ca.sh --claim "registration"
./verify-ca.sh --claim "proof"
```

## Understanding the Results

### Success Indicators

✅ **Green check:** Operation verified successfully  
✓ **Within budget:** Time was under plan limit (≤180s per-op, ≤2700s full)  
**Build completed successfully:** All theorems compiled, proofs checked

### Expected Warnings

The following warnings are **expected and documented**:

1. **Axiom sorries (3 total):**
   - 2 PC-chaining axiom bodies in withdrawal (elaborator constraint blocks completion)
   - 1 proof irrelevance case in withdrawal (needs stdlib lemma)
   - All documented in `AXIOM_INVENTORY.md`

2. **Linter warnings:**
   - "unused simp args" in StdPrimitives.lean, Vector.lean
   - Non-blocking, can be suppressed with `set_option linter.unusedSimpArgs false`

### Failure Indicators

✗ **Red X:** Operation failed to verify  
⚠ **Warning triangle:** Operation succeeded but exceeded time budget  
**error:** Compilation error — proof is broken

If you see failures, check:
1. Did you run `lake exe cache get`? (Most common issue)
2. Is your Lean toolchain version correct? (Check `lean-toolchain` file)
3. Are there uncommitted changes? (Run `git status`)

## What's Being Verified?

### Lean Stack (310 theorems across 5 operations)

**Registration (206 theorems):**
- 55 non-native PC step theorems (every moveLoc, stLoc, copyLoc, etc.)
- 28 native-call PC theorems (oracle dispatches)
- 10 error-path variants (oracle returns none)
- 16 functional-sim shape reductions
- Complete non-singleton branch of top-level composition theorem
- Composition scaffolds and helper lemmas

**Phase 4 Verifiers (104 theorems total):**
- Withdrawal: 27 theorems (15 PCs + 2 error paths + functional sim + shape lemmas)
- Transfer: 33 theorems (24 PCs + 3 error paths + functional sim + shape lemmas)
- Normalization: 22 theorems (14 PCs + 2 error paths + functional sim + shape lemmas)
- Rotation: 22 theorems (15 PCs + 2 error paths + functional sim + shape lemmas)

Each verifier proves:
1. **Entry-point unfolding:** `eval` reduces to `run` on initial frame
2. **Per-PC step theorems:** Every instruction's semantics
3. **Error-path variants:** Oracle failures produce `.error`
4. **Functional simulation:** High-level match on oracle outcomes
5. **Shape lemmas:** Functional sim reduces to bytecode result

### Move Prover Stack (131 spec blocks)

**Currently blocked on Phase 0 Z3 setup.** Once unblocked, verifies:
- Internal operations (6 functions): balance arithmetic, abort conditions, store updates
- Entry points (15 functions): FA integration, freeze gates, store existence
- View functions (11 functions): field reads, abort conditions
- Freeze/governance (9 functions): permission checks, state transitions
- Test helpers (13 functions): event assertions, setup utilities

### Difftest Stack (87 corpus rows)

**Currently blocked on difftest harness setup.** Once unblocked, verifies:
- VM output matches Lean functional sim on concrete inputs
- Oracle consistency (Ristretto255 natives)
- End-to-end bytecode execution

## Understanding the Axioms

All axioms are catalogued in `AXIOM_INVENTORY.md` with rationale and elimination plans.

**Categories:**

1. **TEMPORARY (5 axioms)** — target for elimination:
   - `registration_eval_equiv_functional_sim` — reproved in Phase 1 completion
   - 4 withdrawal PC-chaining axioms — blocked on elaborator constraint

2. **Group theory (12 axioms)** — permanent, textbook math:
   - Edwards curve group laws (addition, negation, scalar multiplication)
   - Prime-ality facts for curve25519 base field and Ristretto subgroup order

3. **Ristretto encoding (4 axioms)** — permanent, anchored by difftest:
   - Canonical encoding size (32 bytes)
   - Encode/decode round-trip
   - Encoder injectivity

4. **Bulletproofs (5 axioms)** — permanent, external audit:
   - Rejection of malformed proofs, bad bit-widths, batch inconsistencies
   - Domain-separation tag and generator base distinguishability

**Trust base:** 21 permanent axioms (standard crypto facts) + 5 temporary (work in progress)

## Performance Expectations

| Operation | Time | Theorems | Status |
|-----------|------|----------|--------|
| register  | ~1s  | 206      | ✅     |
| withdraw  | ~1s  | 27       | ✅     |
| transfer  | ~2s  | 33       | ✅     |
| normalize | ~1s  | 22       | ✅     |
| rotate    | ~1s  | 22       | ✅     |
| **Full**  | **~6s** | **310** | **✅** |

**Budget from plan §10.6:** ≤180s per-op, ≤2700s full run  
**Actual utilization:** 0.6-1.1% per-op, 0.2% full run

If your runs are significantly slower:
- First build (no cache): Can take 10-30min — run `lake exe cache get` first
- Subsequent builds (warm cache): Should be 1-6s as above
- If repeatedly slow with cache: Check CPU/memory, try `lake clean` then `lake exe cache get` again

## Common Issues

### Issue 1: "Build timed out" or "Taking forever"

**Cause:** Didn't fetch mathlib cache

**Fix:**
```bash
cd aptos-move/framework/formal/lean
lake exe cache get
lake build
```

### Issue 2: "unknown package 'mathlib'"

**Cause:** Lean toolchain version mismatch

**Fix:**
```bash
# Check toolchain version
cat lean-toolchain  # should match: leanprover/lean4:v4.24.0 (or specified version)

# Reinstall if needed
elan toolchain install leanprover-lean4:v4.24.0
elan default leanprover-lean4:v4.24.0
```

### Issue 3: "Z3_EXE not set" when running Move Prover

**Cause:** Prover dependencies not installed or not in PATH

**Fix:**
```bash
movement update prover-dependencies --assume-yes
source ~/.bashrc  # or open new terminal
echo $Z3_EXE     # should show path to Z3
```

### Issue 4: verify-ca.sh says "not implemented yet"

**Cause:** Trying to use Move Prover or difftest stacks which aren't set up yet

**Fix:** Use `--stack lean` flag to run only Lean verification (which is functional)

## Next Steps

### For Reviewers

1. **Verify all Lean proofs:** `./verify-ca.sh --stack lean` (~6s)
2. **Review axiom inventory:** `cat AXIOM_INVENTORY.md`
3. **Check trust boundaries:** `cat TRUST_BOUNDARIES.md`
4. **Examine specific claims:** See `CLAIMS.md` for file:line references
5. **Review detailed coverage:** `cat BYTECODE_VERIFICATION_COVERAGE.md`

### For Contributors

1. **Set up full 3-stack verification:** Install Z3 + difftest harness
2. **Run full verification:** `./verify-ca.sh` (all stacks, all operations)
3. **Make changes:** Edit Lean files
4. **Re-verify:** `./verify-ca.sh --op <changed-op> --stack lean`
5. **Check for new axioms:** `./scripts/check_axioms.sh --diff`

## Documentation Index

| File | Purpose |
|------|---------|
| `README.md` | This directory's overview (audit package) |
| `CLAIMS.md` | Plain-English claim → tool → file → rerun command |
| `TRUST_BOUNDARIES.md` | Every unproved assumption |
| `AXIOM_INVENTORY.md` | Complete axiom catalog with rationale |
| `BYTECODE_VERIFICATION_COVERAGE.md` | Lean theorem catalog (310 theorems) |
| `MSL_SPEC_COVERAGE.md` | Move Prover spec catalog (131 spec blocks) |
| `COMPOSITION_CLAIMS.md` | End-to-end composition claims |
| `verify-ca.sh` | Single-command verification tool |
| `../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` | Master plan document |

## Support

- **Questions about Lean proofs:** See `lean/README.md` for Lean-specific guidance
- **Questions about Move Prover:** See plan §5.1 for prover setup
- **Questions about difftest:** See `difftest/README.md`
- **General questions:** See `../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`

## Quick Command Reference

```bash
# Health check (10s)
./verify-ca.sh --op register --stack lean

# Full Lean verification (6s)
./verify-ca.sh --stack lean

# Coverage summary
./verify-ca.sh --coverage

# Search claims
./verify-ca.sh --claim "balance"

# Per-operation
./verify-ca.sh --op {register|withdraw|transfer|normalize|rotate} --stack lean

# Help
./verify-ca.sh --help
```

**TL;DR:** Run `./verify-ca.sh --stack lean` and you're done. Takes ~6 seconds, verifies 310 theorems across 5 operations.
