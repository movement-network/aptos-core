# Ristretto255 Blocker Investigation and Resolution Plan

**Date:** 2026-04-23  
**Blocking:** Phases 2, 3, 5 (Move Prover verification)  
**Impact:** 88+ MSL spec blocks can't be verified  
**Status:** Workarounds applied for compilation, but meaningful verification blocked

---

## Problem Statement

CA MSL specs compile successfully but generate 0 verification conditions (VCs). The root cause is that ristretto255 upstream spec verification fails, preventing downstream CA modules from being verified even though their specs are well-formed.

**Current state:**
- ✅ Move Prover toolchain installed and operational
- ✅ All CA spec files compile cleanly
- ✅ verify-ca.sh integration functional
- ⚠️ 0 VCs generated (specs don't trigger verification)
- ⚠️ Ristretto255 verification errors prevent meaningful CA verification

---

## Root Cause Analysis

### Bug 1: BV/Int Type Mismatch

**Location:** `aptos-stdlib/sources/cryptography/ristretto255.spec.move`

**Symptom:** `scalar_from_u64_internal` and `scalar_from_u128_internal` specs declare `int` types but are called with `bv64`/`bv128` in Boogie translation

**Workaround applied:**
- Removed `ensures` clauses from both functions
- Result: Compilation succeeds, but no verification of scalar conversion

**Status:** ✅ Workaround applied (allows compilation)  
**Impact:** Partial (allows compilation but doesn't enable verification)

---

### Bug 2: Vector Monomorphization

**Location:** `aptos-stdlib/sources/cryptography/ristretto255.spec.move`

**Symptom:** `vector<CompressedRistretto>::length` monomorphization missing, breaks modules using `SigmaProofXs`/similar vector-of-compressed types

**Workaround applied:**
- Deactivated invariants that trigger monomorphization
- Result: Compilation succeeds, but invariants not checked

**Status:** ✅ Workaround applied (allows compilation)  
**Impact:** Partial (allows compilation but doesn't enable verification)

---

### Missing: Complete Patches for Meaningful Verification

**Current gap:** Workarounds allow compilation but don't enable verification. To generate meaningful VCs, we need complete ristretto255 specs that:

1. Type-check correctly (no bv/int mismatches)
2. Monomorphize correctly (vector operations on compressed points)
3. Actually verify (don't fail with "abort condition never happens")
4. Compose with downstream CA specs

**Evidence of the gap:**
- Move Prover runs: ✅ (compilation succeeds)
- VCs generated: ⚠️ 0 (specs don't trigger verification)
- Verification result: N/A (no VCs to verify)

---

## Complete Fix Requirements

### What "patches applied" means now

The current workarounds (deactivated invariants + removed ensures clauses) achieve:
- ✅ Boogie compilation succeeds
- ✅ All CA modules compile
- ⚠️ But: No meaningful verification (0 VCs)

### What "patches complete" would mean

Complete patches would achieve:
- ✅ Boogie compilation succeeds
- ✅ All CA modules compile
- ✅ VCs generated for CA specs
- ✅ VCs verify (or fail with actionable error messages)
- ✅ CA verification composes with ristretto255 specs

### Patch components needed

Based on `PHASE_0_RISTRETTO255_PATCH_NOTES.md`, the complete fix requires:

1. **Type consistency fixes:**
   - Replace `int` with `bv64`/`bv128` in spec functions
   - OR add companion bv-typed spec functions
   - OR use module-level `pragma bv_implementation = false`

2. **Monomorphization fixes:**
   - Complete vector operation specs for `vector<CompressedRistretto>`
   - Ensure `len()` and other operations monomorphize correctly

3. **Verification-ready specs:**
   - Ensure ristretto255 module itself verifies (or has explicit `pragma verify = false`)
   - Ensure invariants don't cause "abort condition never happens" errors
   - Ensure downstream composition works

---

## Investigation Plan

### Phase 1: Understand Current State (1-2 hours)

**Goal:** Document exact current behavior

**Tasks:**
1. Run Move Prover on ristretto255 module in isolation
2. Capture exact error messages (if any)
3. Run Move Prover on CA modules with verbose output
4. Confirm 0 VCs vs expected VCs
5. Document what "compilation succeeds" actually means

**Commands:**
```bash
# Test ristretto255 module in isolation
cd aptos-move/framework/aptos-stdlib
movement move prove \
    --package-dir . \
    --named-addresses aptos_std=0x1 \
    --filter ristretto255 \
    --verbose \
    --vc-timeout 120 \
    --skip-fetch-latest-git-deps \
    2>&1 | tee /tmp/ristretto255_prove.log

# Test CA module
cd aptos-move/framework/aptos-experimental
movement move prove \
    --package-dir . \
    --named-addresses aptos_experimental=0x7 \
    --filter confidential_asset \
    --verbose \
    --vc-timeout 120 \
    --skip-fetch-latest-git-deps \
    2>&1 | tee /tmp/ca_prove.log

# Compare VC counts
grep "VC" /tmp/ristretto255_prove.log
grep "VC" /tmp/ca_prove.log
```

**Expected outcome:**
- Exact error messages documented
- VC count baseline established
- Current workaround limitations understood

---

### Phase 2: Locate Ristretto255 Specs (30 min)

**Goal:** Find and read current ristretto255 spec state

**Tasks:**
1. Locate `ristretto255.spec.move`
2. Identify which invariants are deactivated
3. Identify which ensures clauses are removed
4. Compare against patch notes recommendations

**Commands:**
```bash
# Find ristretto255 spec files
find aptos-move/framework/aptos-stdlib -name "*ristretto255*.move" -o -name "*ristretto255*.spec.move"

# Check for deactivated pragmas
grep -n "pragma deactivated" aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move

# Check scalar_from_u* specs
grep -A10 "spec scalar_from_u64_internal" aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move
grep -A10 "spec scalar_from_u128_internal" aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move
```

**Expected outcome:**
- Current spec state documented
- Workarounds identified
- Gaps vs complete patches clarified

---

### Phase 3: Test Complete Patches Locally (2-3 hours)

**Goal:** Apply complete patches and test VC generation

**Tasks:**
1. Create backup of current ristretto255.spec.move
2. Apply complete patches from patch notes
3. Test ristretto255 module verification
4. Test CA module VC generation
5. Measure verification time
6. Document results

**Approach:**
```bash
# Backup current state
cp aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move \
   aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.spec.move.backup

# Apply patches (manual editing based on PHASE_0_RISTRETTO255_PATCH_NOTES.md)
# Edit ristretto255.spec.move:
# 1. Add module-level pragma bv_implementation = false (Candidate Patch A)
# 2. OR Add companion bv-typed spec functions (Candidate Patch B)
# 3. Fix vector monomorphization (add explicit spec for vector<CompressedRistretto>)

# Test
cd aptos-move/framework/aptos-stdlib
movement move prove --package-dir . --filter ristretto255 --verbose

# If successful, test CA
cd aptos-move/framework/aptos-experimental
movement move prove --package-dir . --filter confidential_asset --verbose

# Count VCs
grep "VC" /tmp/ca_prove_patched.log
```

**Success criteria:**
- ristretto255 module verifies (or has explicit verify = false)
- CA modules generate > 0 VCs
- VCs either verify or fail with actionable errors

---

### Phase 4: Document Findings (1 hour)

**Goal:** Create actionable report for next steps

**Deliverables:**
1. Test results log
2. Exact VC counts (before/after patches)
3. Error messages (if any)
4. Recommendation: apply locally vs upstream PR vs wait

**Report structure:**
```markdown
# Ristretto255 Patch Test Results

## Current State (Before Patches)
- VC count: 0
- Error messages: [exact errors]
- Compilation: [success/failure]

## After Patches
- VC count: [number]
- Error messages: [exact errors]
- Compilation: [success/failure]
- Verification time: [per-function timing]

## Recommendation
[Apply locally | Submit upstream PR | Wait for upstream]

## Next Steps
[Concrete actions with commands]
```

---

## Alternative Approaches

### Option A: Apply Patches Locally

**Pros:**
- Immediate unblocking (2-3 days)
- Full control over patch content
- Can iterate quickly

**Cons:**
- Diverges from upstream (maintenance burden)
- Needs documentation for reproducibility
- May conflict with future upstream changes

**When to use:** If upstream timeline unknown or >1 month

---

### Option B: Submit Upstream PR

**Pros:**
- Benefits entire Aptos ecosystem
- Upstream maintenance
- Canonical fix

**Cons:**
- Slower (review/merge timeline)
- Less control over implementation
- Blocks progress until merged

**When to use:** If upstream receptive and timeline reasonable (<2 weeks)

---

### Option C: Hybrid Approach

**Pros:**
- Immediate progress (local patches)
- Long-term benefit (upstream PR)
- Best of both worlds

**Cons:**
- Dual maintenance temporarily
- More complex

**Recommended approach:**
1. Apply patches locally for immediate unblocking
2. Submit upstream PR in parallel
3. Migrate to upstream once merged
4. Document both states in toolchain.lock

---

## Timeline Estimate

| Phase | Time | Dependencies |
|-------|------|--------------|
| 1. Understand current state | 1-2 hours | Move Prover toolchain set up |
| 2. Locate specs | 30 min | None |
| 3. Test complete patches | 2-3 hours | Phase 1 complete |
| 4. Document findings | 1 hour | Phase 3 complete |
| **Total** | **4-6 hours** | Move Prover toolchain |

**Follow-on work (if patches successful):**
- Strengthen CA specs: 1-2 weeks
- Measure verification time: 1-2 days
- Optimize slow specs: As needed
- Update documentation: 1-2 days

---

## Success Criteria

### Minimum (Compilation)
- ✅ Already achieved

### Target (Verification)
- ✅ VCs generated for CA specs (> 0)
- ✅ VCs verify or fail with actionable errors
- ✅ Per-operation verification time ≤ 180s

### Stretch (Full Green)
- ✅ All CA specs verify successfully
- ✅ Compose with upstream FA specs
- ✅ CI green for Move Prover stack

---

## Contingency Plans

### If patches don't work

**Fallback 1:** Strengthen CA specs within current limitations
- Use `pragma opaque` more aggressively
- Focus on store-level properties that don't depend on ristretto255
- Document crypto-layer verification as "future work"

**Fallback 2:** Wait for upstream fix
- Document blocker clearly
- Focus on Lean side (Phases 1, 4, 6)
- Revisit Move Prover side when upstream ready

**Fallback 3:** Accept limited verification
- Verify store-only operations (Phase 3)
- Mark crypto-dependent operations as `pragma verify = false`
- Document limitation in TRUST_BOUNDARIES.md

---

## Next Actions

### Immediate (If Move Prover set up)
1. Run Phase 1 investigation (1-2 hours)
2. Document current VC count and error messages
3. Create test results log

### Short-term (This week)
1. Run Phase 3 patch testing (2-3 hours)
2. Document findings
3. Make go/no-go decision on local patches

### Medium-term (This month)
1. If patches successful: Apply locally + submit upstream PR
2. If patches unsuccessful: Revisit with upstream or accept limitation
3. Update all documentation with findings

---

## Open Questions

1. **What is the upstream timeline for ristretto255 spec fixes?**
   - Action: Check Aptos GitHub for related issues/PRs
   - Fallback: Assume unknown, proceed with local patches

2. **Are there other ristretto255 spec dependencies we haven't discovered?**
   - Action: Full dependency analysis of CA → ristretto255
   - Fallback: Discover incrementally during verification

3. **What is the minimum ristretto255 spec sufficiency for CA verification?**
   - Action: Catalog which ristretto255 functions CA actually uses
   - Fallback: Patch only what's needed, leave rest for later

4. **Should we verify ristretto255 module itself or mark it `pragma verify = false`?**
   - Action: Test both approaches
   - Recommendation: Likely `pragma verify = false` (crypto-primitive boundary)

---

## Related Documentation

- `PHASE_0_RISTRETTO255_PATCH_NOTES.md` - Candidate patches (3 options)
- `MOVE_PROVER_INTEGRATION_STATUS.md` - Current integration state
- `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` - Phase 0 requirements
- `CURRENT_STATE_ANALYSIS_2026_04_23.md` - Overall blocker analysis

---

## Conclusion

The ristretto255 blocker is well-understood and has clear resolution paths. The investigation can be completed in 4-6 hours, and complete patches can likely be applied locally in 2-3 days. The main decision point is: apply locally vs wait for upstream. Recommendation: hybrid approach (local + upstream PR in parallel).

**Bottom line:** This blocker is unblocking-able with focused investigation and patch application. Not a fundamental limitation, just upstream dependency management.
