# Move Prover Integration Status — CA Formal Verification

**Last updated:** 2026-04-22
**Phase:** 7 (audit package) + Phase 2/3/5 (MSL specs)

## Executive Summary

Move Prover toolchain is now **installed and integrated** into `verify-ca.sh`. All CA specs compile successfully, and the verification pipeline runs end-to-end. However, meaningful verification is currently **blocked on ristretto255 upstream patches** (Phase 0).

**Current state:**
- ✅ Toolchain installed: Z3 4.11.2, Boogie 3.5.1, CVC5 0.0.3
- ✅ verify-ca.sh integration: `--stack move-prover` functional
- ✅ Spec compilation: All 6 CA spec files compile cleanly
- ⚠️ Verification: 0 VCs generated (specs are scaffolded/opaque)
- ⚠️ Blocked: ristretto255 verification failures prevent real VC generation

**Timeline:**
- 2026-04-22: Toolchain setup complete, verify-ca.sh integration complete
- Pending: Complete ristretto255 patches (Phase 0 blocker)
- Next: Strengthen specs to generate VCs once ristretto255 unblocked

## Toolchain Setup

### Installation

Prover dependencies installed via Movement CLI:

```bash
movement update prover-dependencies --assume-yes
```

**Installed versions:**
- Boogie: 3.5.1 (`/Users/andygmove/.local/bin/boogie`)
- Z3: 4.11.2 (`/Users/andygmove/.local/bin/z3`)
- CVC5: 0.0.3 (`/Users/andygmove/.local/bin/cvc5`)

**Environment variables:**
```bash
export BOOGIE_EXE=/Users/andygmove/.local/bin/boogie
export Z3_EXE=/Users/andygmove/.local/bin/z3
export CVC5_EXE=/Users/andygmove/.local/bin/cvc5
```

These match the versions specified in `audit/toolchain.lock`.

### Verification Status

**Compilation:** ✅ All CA spec files compile successfully

```bash
movement move compile \
    --package-dir aptos-move/framework/aptos-experimental \
    --named-addresses aptos_experimental=0x7 \
    --skip-fetch-latest-git-deps
# Result: {"Result": [...]} ✅
```

**Compiled modules:**
- `ristretto255_twisted_elgamal` (crypto boundary, pragma opaque)
- `confidential_balance` (balance operations)
- `confidential_proof` (proof verification)
- `confidential_asset` (entry points + internal functions)

**Per-operation verification via verify-ca.sh:**

| Operation | Command | Status | VCs | Time | Notes |
|-----------|---------|--------|-----|------|-------|
| register  | `./verify-ca.sh --op register --stack move-prover` | ✅ | 0 | ~1s | Spec scaffolded |
| withdraw  | `./verify-ca.sh --op withdraw --stack move-prover` | ✅ | 0 | ~1s | Spec scaffolded |
| transfer  | `./verify-ca.sh --op transfer --stack move-prover` | ✅ | 0 | ~1s | Spec scaffolded |
| normalize | `./verify-ca.sh --op normalize --stack move-prover` | ✅ | 0 | ~1s | Spec scaffolded |
| rotate    | `./verify-ca.sh --op rotate --stack move-prover` | ✅ | 0 | ~1s | Spec scaffolded |

**Interpretation:** "✅ 0 VCs" means the tool chain works, but specs don't generate meaningful verification conditions yet. This is expected at this stage — the specs are structural scaffolds with `pragma opaque` on crypto functions.

## Integration Status

### verify-ca.sh

Move Prover is now integrated into the Phase 7 single-command verification tool.

**Usage:**
```bash
# Single operation
./verify-ca.sh --op register --stack move-prover

# Full matrix (all operations)
./verify-ca.sh --stack move-prover

# Combined with other stacks
./verify-ca.sh --op transfer  # runs Lean + Move Prover + difftest
```

**Implementation:**
- `run_move_prover_for_op()` function dispatches to appropriate `*_internal` filter
- Environment check: warns if `Z3_EXE` not set, provides setup instructions
- Error handling: distinguishes "tool not set up" from "verification failed"
- Timing tracking: per-operation time reported against ≤180s budget

**Current behavior:**
- If Z3_EXE set: runs `movement move prove`, reports success/failure
- If Z3_EXE not set: skips with helpful error message
- Full matrix run: Move Prover treated as optional (doesn't fail if skipped)

## Current Blockers

### Blocker 1: ristretto255 Verification Failures

**Status:** Blocking all meaningful CA spec verification

**Manifestation:**
When running Move Prover on modules that use ristretto255 crypto (e.g., `confidential_balance`), verification fails with:

```
error: abort condition never happens
    at aptos-stdlib/sources/cryptography/ristretto255.move:234:19
    abort happened here with code 0xB
```

**Root cause:**
Per plan Phase 0, two upstream bugs in `ristretto255.spec.move`:
1. ~~Bug 1: bv/int type mismatch in `scalar_from_u64_internal`~~ ✅ RESOLVED (plan says "ensures clauses removed")
2. Bug 2: Vector monomorphization issue ⚠️ PARTIALLY RESOLVED (plan says "applied via deactivated invariants")

**Evidence of remaining issues:**
- `confidential_balance` module verification fails with ristretto255 aborts
- `ristretto255_twisted_elgamal` module verification fails despite `pragma opaque`
- Even `pragma opaque` functions trigger upstream ristretto255 verification

**Impact:**
- Phase 2 (MSL specs for `*_internal` functions): Structurally complete, but can't verify
- Phase 3 (store-only ops): Structurally complete, but can't verify
- Phase 5 (entry point specs): Structurally complete, but can't verify

**What works despite this:**
- Spec compilation (all specs parse and type-check)
- verify-ca.sh infrastructure (tool chain runs)
- Lean stack (completely independent, unaffected)

### Blocker 2: Incomplete Spec Strengthening

**Status:** Expected (work in progress)

**Current state:**
Most CA specs use `pragma opaque` or have minimal `aborts_if` clauses. This is the correct first step (structural scaffolding), but doesn't generate VCs.

**Examples:**

`confidential_asset.spec.move`:
```move
spec register_internal {
    pragma aborts_if_is_strict = false;
    // TODO: Add ensures clauses for:
    // - ConfidentialAssetStore created with correct initial state
    // - Event emitted
    // - FA metadata recorded
}
```

`ristretto255_twisted_elgamal.spec.move`:
```move
spec ciphertext_add {
    pragma opaque;
    aborts_if false;
    // TODO: State homomorphic property (blocked on Lean oracle integration)
}
```

**Next steps:**
1. Wait for ristretto255 blocker to clear
2. Strengthen `ensures` clauses with balance invariants, abort conditions, frame conditions
3. Remove `pragma opaque` from non-crypto functions
4. Add store invariants, permission checks, FA integration specs

**Timeline:**
- Blocker 1 must clear first (otherwise specs can't verify even if strengthened)
- Estimate: 1-2 weeks after blocker cleared

## Spec Coverage Summary

### Spec Files Created (Phase 2/3/5)

1. **`confidential_asset.spec.move`** (Phase 2 + 5)
   - 6 internal function specs (`register_internal`, `deposit_to_internal`, `withdraw_to_internal`, `confidential_transfer_internal`, `rotate_encryption_key_internal`, `normalize_internal`)
   - 15 entry point specs (`register`, `deposit`, `withdraw`, `confidential_transfer`, etc.)
   - Status: Compiled ✅, VCs generated ⚠️ (blocked on ristretto255)

2. **`confidential_balance.spec.move`** (Phase 3)
   - Balance operation specs (`add`, `sub`, `equals`, `split`)
   - Length invariant specs
   - Status: Compiled ✅, VCs blocked on ristretto255

3. **`confidential_proof.spec.move`** (Phase 3)
   - Proof verification specs (opaque boundary)
   - Status: Compiled ✅, intentionally opaque (no VCs expected)

4. **`ristretto255_twisted_elgamal.spec.move`** (Phase 3)
   - Crypto boundary specs (all `pragma opaque`)
   - Status: Compiled ✅, intentionally opaque

5. **`confidential_gas_e2e_helpers.spec.move`** (testing)
   - E2E testing helper specs
   - Status: Compiled ✅

6. **`benchmark_utils.spec.move`** (placeholder)
   - Benchmark utilities
   - Status: Compiled ✅

**Total:** 6 spec files, 40+ spec blocks, all compile cleanly.

### What's Verified vs. Scaffolded

| Component | Compilation | VCs Generated | VCs Passed | Notes |
|-----------|-------------|---------------|------------|-------|
| Internal functions (Phase 2) | ✅ | ⚠️ | ⚠️ | Blocked on ristretto255 |
| Store-only ops (Phase 3) | ✅ | ⚠️ | ⚠️ | Blocked on ristretto255 |
| Entry points (Phase 5) | ✅ | ⚠️ | ⚠️ | Blocked on ristretto255 |
| Crypto boundary | ✅ | ⚠️ | ⚠️ | Intentionally opaque, but still triggers ristretto255 issues |

## Testing Procedures

### Quick Smoke Test

Verify Move Prover is working:

```bash
# Set environment variables
export BOOGIE_EXE=/Users/andygmove/.local/bin/boogie
export Z3_EXE=/Users/andygmove/.local/bin/z3
export CVC5_EXE=/Users/andygmove/.local/bin/cvc5

# Test single operation
cd aptos-move/framework/formal/audit
./verify-ca.sh --op register --stack move-prover

# Expected output:
# Move Prover: OK (1s)
# ✓ Within per-op budget
```

### Full Testing

Test all operations:

```bash
./verify-ca.sh --stack move-prover

# Expected: All operations pass (with 0 VCs)
# Time: ~5s total
```

### Direct Testing (without verify-ca.sh)

```bash
cd aptos-move/framework/aptos-experimental

# Test compilation
movement move compile \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --skip-fetch-latest-git-deps

# Test single function
movement move prove \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --filter 'register_internal' \
    --vc-timeout 120 \
    --skip-fetch-latest-git-deps

# Expected: {"Result": "Success"} with 0 VCs
```

## CI Integration Status

### What's Ready

- ✅ Toolchain setup script: `movement update prover-dependencies`
- ✅ verify-ca.sh integration: `./verify-ca.sh --stack move-prover`
- ✅ Environment validation: checks for Z3_EXE, BOOGIE_EXE
- ✅ Error reporting: distinguishes "not set up" from "verification failed"

### What's Pending

- ⚠️ CI workflow: `.github/workflows/move-prover-ca.yaml` exists but not enabled
- ⚠️ Cache strategy: Boogie/Z3 binaries should be cached
- ⚠️ Performance baseline: Once VCs generate, measure actual verification time

### Recommended CI Setup

```yaml
name: Move Prover CA Verification

on:
  push:
    branches: [main, lean-fv]
    paths:
      - 'aptos-move/framework/aptos-experimental/sources/confidential_asset/**'
  pull_request:
    paths:
      - 'aptos-move/framework/aptos-experimental/sources/confidential_asset/**'

jobs:
  move-prover:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v3

      - name: Install Movement CLI
        run: |
          curl -sSfL https://get.movementlabs.xyz | bash
          echo "$HOME/.movement/bin" >> $GITHUB_PATH

      - name: Cache prover tools
        uses: actions/cache@v3
        with:
          path: ~/.local/bin
          key: prover-tools-${{ runner.os }}-v1

      - name: Install prover dependencies
        run: |
          movement update prover-dependencies --assume-yes
          echo "BOOGIE_EXE=$HOME/.local/bin/boogie" >> $GITHUB_ENV
          echo "Z3_EXE=$HOME/.local/bin/z3" >> $GITHUB_ENV
          echo "CVC5_EXE=$HOME/.local/bin/cvc5" >> $GITHUB_ENV

      - name: Run Move Prover verification
        run: |
          cd aptos-move/framework/formal/audit
          ./verify-ca.sh --stack move-prover
```

**Status:** Ready to enable once ristretto255 blocker clears.

## Performance Characteristics

### Current Performance (Scaffolded Specs)

| Metric | Value | Notes |
|--------|-------|-------|
| Compilation time | ~2-3s | All 6 CA spec files |
| Per-operation time | ~1s | 0 VCs, mostly overhead |
| Full matrix time | ~5s | All 5 operations |
| VCs generated | 0 | Specs scaffolded |
| VCs passed | N/A | No VCs to verify |

### Expected Performance (After Blocker Clears)

Based on plan §10.6 budgets:

| Metric | Budget | Estimate | Confidence |
|--------|--------|----------|------------|
| Per-operation | ≤180s | 10-30s | Medium (depends on spec complexity) |
| Full matrix | ≤2700s | 5-10min | Medium |
| VCs generated | Unknown | 50-200 | Low (depends on spec strength) |

**Assumptions:**
- ristretto255 patches applied
- Specs strengthened with balance invariants
- FA integration specs complete
- Z3 4.11.2 performance (not 4.14.x regression)

## Next Steps

### Immediate (Phase 7 completion)

1. ✅ **DONE:** Install Move Prover toolchain
2. ✅ **DONE:** Integrate into verify-ca.sh
3. ✅ **DONE:** Document current status (this file)
4. **TODO:** Add Move Prover section to TESTING_AND_VALIDATION_GUIDE.md
5. **TODO:** Update REVIEWER_QUICK_START.md with Move Prover smoke test

### Short-term (unblock verification)

1. **CRITICAL:** Complete ristretto255 patches (Phase 0)
   - Resolve vector monomorphization issues
   - Test upstream ristretto255.spec.move in isolation
   - Verify CA specs generate VCs once patches applied

2. **High priority:** Strengthen CA specs (Phases 2/3/5)
   - Add balance invariant ensures clauses
   - Add abort condition specifications
   - Add frame conditions (what's NOT modified)
   - Remove `pragma opaque` where appropriate

3. **Medium priority:** Measure real performance
   - Run full verification with VCs
   - Compare against 180s per-op budget
   - Optimize slow specs if needed

### Medium-term (complete 3-stack verification)

1. Enable Move Prover CI workflow
2. Add performance regression detection
3. Create dashboard showing Lean + Move Prover + difftest status
4. Document composition story (how all 3 stacks fit together)

## Related Documentation

- **Plan:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` (Phases 0/2/3/5)
- **Toolchain:** `audit/toolchain.lock` (pinned versions)
- **Testing:** `audit/TESTING_AND_VALIDATION_GUIDE.md` (test procedures)
- **CI:** `audit/CI_INTEGRATION_GUIDE.md` (GitHub Actions setup)
- **Specs:** `aptos-experimental/sources/confidential_asset/*.spec.move` (source files)

## Questions and Contact

**Q: Why 0 VCs if specs compile?**
A: Specs are structural scaffolds. Most use `pragma opaque` or have minimal ensures clauses, which don't generate VCs. This is the correct first step.

**Q: When will real verification work?**
A: After ristretto255 patches complete (Phase 0 blocker). Then we strengthen specs (Phases 2/3/5).

**Q: Can I test Move Prover now?**
A: Yes! Run `./verify-ca.sh --op register --stack move-prover`. It will pass (with 0 VCs), confirming toolchain works.

**Q: Is this blocking Phase 7 completion?**
A: No. Phase 7 is the audit package (verify-ca.sh, documentation, CI setup). Move Prover *integration* is complete; meaningful *verification* is Phase 2/3/5 work.

---

**Conclusion:** Move Prover toolchain is operational and integrated into verify-ca.sh. Infrastructure is complete and ready for meaningful verification once ristretto255 blocker clears. Current status (0 VCs) is expected and not a failure — it confirms the tool chain works and specs compile correctly.
