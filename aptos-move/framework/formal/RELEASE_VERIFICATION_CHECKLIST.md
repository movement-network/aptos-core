# Release Verification Checklist

**Purpose:** Complete pre-release verification checklist ensuring Confidential Assets formal verification is production-ready.

**Audience:** Release managers, QA leads, formal verification team leads.

**Scope:** All verification artifacts, reproducibility, documentation, performance, security review.

---

## Table of Contents

1. [Release Criteria](#1-release-criteria)
2. [Pre-Release Verification](#2-pre-release-verification)
3. [Verification Artifact Checklist](#3-verification-artifact-checklist)
4. [Reproducibility Validation](#4-reproducibility-validation)
5. [Performance Validation](#5-performance-validation)
6. [Security Review](#6-security-review)
7. [Documentation Review](#7-documentation-review)
8. [Deployment Checklist](#8-deployment-checklist)
9. [Post-Release Validation](#9-post-release-validation)
10. [Rollback Plan](#10-rollback-plan)

---

## 1. Release Criteria

### 1.1 Must-Have Criteria (Blocking)

**All must be ✅ before release:**

- [ ] All three verification stacks green (Lean, MSL, Difftest)
- [ ] Zero `sorry` in Lean proofs
- [ ] Zero temporary axioms (only permanent 21 crypto axioms)
- [ ] Zero `pragma verify = false` in MSL (unless documented)
- [ ] Difftest coverage ≥95% (97/102 scenarios minimum)
- [ ] All abort codes consistent across stacks
- [ ] Performance within budget (all operations)
- [ ] `verify-ca.sh` passes from fresh clone (<45 min)
- [ ] Docker image builds and runs verification
- [ ] External security audit complete with no critical findings
- [ ] All high/critical audit findings remediated
- [ ] All documentation up to date

### 1.2 Nice-to-Have Criteria (Non-Blocking)

**Desirable but not blocking:**

- [ ] PBT framework implemented (160K tests)
- [ ] Difftest coverage 100% (102/102 scenarios)
- [ ] All medium audit findings remediated
- [ ] Performance 20% better than budget
- [ ] Zero non-permanent axioms

---

## 2. Pre-Release Verification

### 2.1 Verification Freeze (T-14 days)

**Two weeks before release, freeze verification:**

**Actions:**
- [ ] Announce verification freeze in #engineering
- [ ] Create release branch `release/ca-v1.0`
- [ ] Tag verification snapshot `verification-freeze-v1.0`
- [ ] Run full verification suite on freeze snapshot
- [ ] Archive verification artifacts

**During freeze:**
- ❌ No new operations
- ❌ No verification refactoring
- ❌ No axiom changes
- ✅ Critical bug fixes only (with approval)
- ✅ Documentation updates
- ✅ Reproducibility fixes

### 2.2 Comprehensive Verification Run (T-10 days)

**Run on frozen snapshot:**

```bash
# Fresh clone
git clone --branch release/ca-v1.0 <repo>
cd aptos-core/aptos-move/framework/formal

# Full verification suite
./scripts/run_verification_suite.sh --mode comprehensive

# Must complete in <15 min, all green
```

**Capture results:**
```bash
# Save verification logs
./audit/verify-ca.sh --mode comprehensive > release-verification-v1.0.log

# Save axiom snapshot
./scripts/check_axioms.sh > release-axioms-v1.0.txt

# Save performance baseline
./scripts/benchmark_verification.sh --output release-benchmark-v1.0.json
```

---

## 3. Verification Artifact Checklist

### 3.1 Lean Artifacts

**Files to verify:**
- [ ] All `*/EvalEquiv.lean` files build cleanly
- [ ] All `*/Phase6Composition.lean` theorems have no `sorry`
- [ ] Axiom count: exactly 21 permanent (no temporary)
- [ ] Build time: each file <180s, full tree <600s
- [ ] No `set_option maxHeartbeats` overrides

**Verification:**
```bash
cd lean
lake clean
lake build MovementFormal

# Check no sorry
find MovementFormal/Experimental/ConfidentialAsset -name "*.lean" -exec grep -l "sorry" {} \;
# Should return empty

# Check axioms
lake build MovementFormal
./scripts/check_axioms.sh
# Should show exactly 21 axioms (all permanent)

# Check build time
time lake build MovementFormal
# Should complete in <600s
```

### 3.2 MSL Artifacts

**Files to verify:**
- [ ] All `*.spec.move` files compile cleanly
- [ ] All specs generate expected VCs (when unblocked)
- [ ] No `pragma verify = false` (unless documented)
- [ ] No `pragma aborts_if_is_partial`
- [ ] All abort codes match difftest

**Verification:**
```bash
# Compile specs
movement move build --package-dir aptos-move/framework/aptos-experimental
# Should succeed

# Check pragmas
grep -r "pragma verify = false" aptos-experimental/sources/confidential_asset/
# Should return empty or only documented cases

# Verify (when ristretto255 patches land)
movement move prove --package-dir aptos-experimental --filter confidential_asset
# Should generate ~75 VCs, all proved
```

### 3.3 Difftest Artifacts

**Files to verify:**
- [ ] All tests pass (87 current, 97+ target)
- [ ] Coverage ≥95% (97/102 scenarios)
- [ ] All abort codes match MSL/Lean
- [ ] No flaky tests (run 100x)

**Verification:**
```bash
# Run all tests
cargo test --release
# Should pass all 87 tests (or 97+ when expanded)

# Check coverage
./scripts/check_difftest_coverage.sh
# Should show ≥95%

# Flaky test check (run tests 100 times)
for i in {1..100}; do
  cargo test --release || echo "FAILED on iteration $i"
done
# Should succeed all 100 times
```

---

## 4. Reproducibility Validation

### 4.1 Fresh Clone Test

**Goal:** Verify anyone can reproduce verification from scratch.

**Process:**
```bash
# Step 1: Fresh clone (no cached artifacts)
git clone --branch release/ca-v1.0 <repo> /tmp/ca-fresh-clone
cd /tmp/ca-fresh-clone/aptos-move/framework/formal

# Step 2: Follow setup docs exactly
# Lean setup (lean/README.md)
lake exe cache get
lake build MovementFormal
# Should succeed in <600s

# Move Prover setup (plan §5.1)
movement update prover-dependencies --assume-yes
movement move prove --package-dir aptos-experimental --filter vector
# Smoke test should pass

# Difftest setup (difftest/README.md)
cd difftest
cargo test --release test_register_happy_path
# Should pass

# Step 3: Run full verification
cd ../formal
./audit/verify-ca.sh
# Should complete in <45 min, all green
```

**Acceptance:** If fresh clone fails, fix setup docs and retest until it works.

### 4.2 Docker Reproducibility Test

**Goal:** Verify Docker image produces identical results.

**Process:**
```bash
# Build Docker image
cd audit
docker build -t ca-verification:v1.0 -f Dockerfile .

# Run verification in container
docker run --rm ca-verification:v1.0 /audit/verify-ca.sh

# Should complete in <45 min, all green
```

**Acceptance:** Docker verification must match local verification exactly.

### 4.3 Multi-Platform Test

**Test on all supported platforms:**
- [ ] macOS (ARM64, M1/M2)
- [ ] macOS (x86_64, Intel)
- [ ] Linux (Ubuntu 22.04, x86_64)
- [ ] Linux (Ubuntu 22.04, ARM64)

**For each platform:**
```bash
# Fresh clone + setup + verify
git clone ...
./audit/verify-ca.sh

# Should pass on all platforms
```

---

## 5. Performance Validation

### 5.1 Build Time Validation

**All operations must be within budget:**

| Operation | Budget | Measured | Status |
|-----------|--------|----------|--------|
| Lean per-file | ≤180s | <measure> | ✅/❌ |
| Lean full tree | ≤600s | <measure> | ✅/❌ |
| MSL per-op | ≤60s | <measure> | ✅/❌ |
| Difftest per-test | ≤5s | <measure> | ✅/❌ |
| Full suite | ≤45min | <measure> | ✅/❌ |

**Measure:**
```bash
./scripts/benchmark_verification.sh --output release-benchmark.json

# Compare to budget
./scripts/compare_benchmarks.sh \
  audit/performance-budget.json \
  release-benchmark.json \
  --threshold 0  # Strict comparison

# All operations must be ≤ budget
```

### 5.2 Performance Regression Check

**Compare to previous release:**

```bash
./scripts/compare_benchmarks.sh \
  releases/v0.9-benchmark.json \
  release-benchmark.json \
  --threshold 20  # Alert if >20% slower

# No operation should be >20% slower (unless justified)
```

---

## 6. Security Review

### 6.1 External Audit Completion

**Must be complete before release:**

- [ ] Audit firm engaged (≥2 months before release)
- [ ] Audit report received
- [ ] All critical findings remediated
- [ ] All high findings remediated (or accepted with documented risk)
- [ ] Auditor sign-off on fixes
- [ ] Final audit report published

**See `SECURITY_AUDIT_PREPARATION_GUIDE.md` for full audit process.**

### 6.2 Internal Security Review

**Even with external audit, run internal review:**

- [ ] Axiom inventory reviewed (all 21 axioms justified)
- [ ] Trust boundaries reviewed (all assumptions documented)
- [ ] Crypto assumptions validated (DLog, Bulletproofs, etc.)
- [ ] Abort code security review (no information leakage)
- [ ] Frame conditions reviewed (no unauthorized mutations)

**Review meeting:**
- Attendees: Security lead, FV lead, Crypto lead
- Duration: 2 hours
- Deliverable: Sign-off or list of blockers

### 6.3 Cryptographic Review

**Specific crypto checks:**

- [ ] Ristretto255 DLog assumption: standard, accepted
- [ ] Bulletproofs soundness: external audit confirmed
- [ ] Sigma protocol implementation: matches specification
- [ ] Transcript handling: Fiat-Shamir correctly applied
- [ ] RNG usage: all proofs use cryptographic RNG

---

## 7. Documentation Review

### 7.1 User-Facing Documentation

**All must be accurate and up to date:**

- [ ] `README.md` (repo root) mentions CA verification
- [ ] `audit/README.md` (audit package overview)
- [ ] `audit/AUDITOR_GUIDE.md` (external auditor onboarding)
- [ ] `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` (master plan)
- [ ] Setup guides (Lean, MSL, Difftest)

**Test:** Fresh team member can verify one operation in <1 hour using only docs.

### 7.2 Technical Documentation

**All must be accurate:**

- [ ] `audit/CLAIMS.md` (all verified properties)
- [ ] `audit/TRUST_BOUNDARIES.md` (all assumptions)
- [ ] `audit/AXIOM_INVENTORY.md` (all axioms cataloged)
- [ ] `audit/COMPOSITION_CLAIMS.md` (end-to-end claims)
- [ ] Coverage docs (MSL, Lean, Difftest)

**Test:** Spot-check 10 random claims from `CLAIMS.md`:
```bash
# For each claim, run the verify command and check it passes
./audit/verify-ca.sh --claim "<claim name>"
```

### 7.3 Maintenance Documentation

**All guides reviewed:**

- [ ] `VERIFICATION_MAINTENANCE_HANDBOOK.md`
- [ ] `DEVELOPER_WORKFLOW_GUIDE.md`
- [ ] `CI_TROUBLESHOOTING_GUIDE.md`
- [ ] `EMERGENCY_RESPONSE_PLAYBOOK.md`
- [ ] All other comprehensive guides

**Test:** No broken links, all code examples compile.

---

## 8. Deployment Checklist

### 8.1 Pre-Deployment (T-7 days)

- [ ] Verification frozen (no changes allowed)
- [ ] All checklists above complete
- [ ] Release notes drafted
- [ ] Deployment plan reviewed
- [ ] Rollback plan prepared (§10)
- [ ] Staging deployment tested

### 8.2 Deployment Day (T-0)

**Morning (before deployment):**
- [ ] Final `verify-ca.sh` run (should be green)
- [ ] Final axiom check (should match baseline)
- [ ] Final performance check (within budget)
- [ ] Deployment team briefed

**Deployment:**
- [ ] Tag release: `git tag v1.0.0-verification`
- [ ] Push tag: `git push origin v1.0.0-verification`
- [ ] Publish Docker image: `docker push ca-verification:v1.0.0`
- [ ] Publish audit report: `audit/AUDIT_REPORT_v1.0.pdf`
- [ ] Publish release notes

**Post-Deployment:**
- [ ] Verify deployment matches tag
- [ ] Run post-deployment validation (§9)
- [ ] Monitor for issues (first 24 hours)

---

## 9. Post-Release Validation

### 9.1 Deployment Validation (Within 1 hour)

**Verify deployed code matches verification:**

```bash
# Clone deployed commit
git clone --branch v1.0.0-verification <repo> /tmp/verify-deployed
cd /tmp/verify-deployed/aptos-move/framework/formal

# Run verification
./audit/verify-ca.sh

# Should pass identically to pre-deployment run
```

### 9.2 Smoke Tests (Within 4 hours)

**Run subset of critical tests:**

```bash
# Lean: Registration (most complex)
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

# MSL: Transfer (most critical)
movement move prove --filter confidential_asset::confidential_transfer_internal

# Difftest: Happy path tests
cargo test test_register_happy_path test_transfer_happy_path test_withdraw_happy_path

# All should pass
```

### 9.3 Monitoring (First 24 hours)

**Watch for:**
- Verification build failures on CI
- Performance regressions reported
- Axiom drift alerts
- User reports of verification issues

**If issues found:** Follow `EMERGENCY_RESPONSE_PLAYBOOK.md`.

---

## 10. Rollback Plan

### 10.1 Rollback Criteria

**Rollback if ANY of:**
- Critical security vulnerability discovered
- Verification completely broken (not recoverable in <4 hours)
- Performance regression >100% (2× slower)
- Axiom count unexpectedly increased
- External audit finding invalidates verification

### 10.2 Rollback Process

**Execute within 1 hour of decision:**

```bash
# Step 1: Revert to previous release
git checkout v0.9.0-verification

# Step 2: Verify previous release still works
./audit/verify-ca.sh
# Should pass

# Step 3: Communicate rollback
# Post in #engineering, #formal-verification

# Step 4: Root cause analysis
# Follow EMERGENCY_RESPONSE_PLAYBOOK.md
```

### 10.3 Rollback Testing

**Test rollback procedure 1 week before release:**

```bash
# Simulate rollback
git checkout v0.9.0-verification
./audit/verify-ca.sh

# Verify: passes in <45 min
# If fails: fix rollback procedure before release
```

---

## Appendix A: Release Checklist Summary

**Copy-paste checklist for release manager:**

```markdown
## Pre-Release (T-14 days)
- [ ] Verification freeze announced
- [ ] Release branch created
- [ ] Comprehensive verification run green
- [ ] Artifacts archived

## Verification (T-10 days)
- [ ] All Lean proofs green (no sorry, 21 axioms)
- [ ] All MSL specs compile (no pragma verify=false)
- [ ] All difftest tests pass (≥95% coverage)
- [ ] Cross-stack consistency validated
- [ ] Performance within budget

## Reproducibility (T-7 days)
- [ ] Fresh clone test passed
- [ ] Docker test passed
- [ ] Multi-platform test passed (macOS, Linux, x86/ARM)

## Security (T-5 days)
- [ ] External audit complete, all critical/high fixed
- [ ] Internal security review complete
- [ ] Cryptographic review complete

## Documentation (T-3 days)
- [ ] All user docs up to date
- [ ] All technical docs accurate
- [ ] All maintenance guides reviewed
- [ ] No broken links

## Deployment (T-0)
- [ ] Final verification run green
- [ ] Release tagged and pushed
- [ ] Docker image published
- [ ] Audit report published

## Post-Deployment
- [ ] Deployment validation passed
- [ ] Smoke tests passed
- [ ] Monitoring active (24h)
- [ ] Rollback plan tested
```

---

## Appendix B: Sign-Off Template

```markdown
# CA Verification Release Sign-Off: v1.0.0

**Date:** YYYY-MM-DD

**Release Manager:** <Name>

## Verification Status

- Lean: ✅ Green (21 axioms, 0 sorry, <600s build)
- MSL: ✅ Green (15 specs, 75 VCs proved)
- Difftest: ✅ Green (97 tests, 95% coverage)

## Reproducibility

- Fresh clone: ✅ Passed
- Docker: ✅ Passed
- Multi-platform: ✅ Passed (macOS/Linux, x86/ARM)

## Security

- External audit: ✅ Complete (0 critical, 0 high open)
- Internal review: ✅ Signed off
- Crypto review: ✅ Signed off

## Documentation

- User docs: ✅ Up to date
- Technical docs: ✅ Accurate
- Maintenance docs: ✅ Reviewed

## Performance

- Build times: ✅ Within budget
- Regression: ✅ No regressions vs v0.9.0

## Sign-Offs

- [ ] Formal Verification Lead: ___________
- [ ] Security Lead: ___________
- [ ] Engineering Lead: ___________
- [ ] Release Manager: ___________

**Approved for release:** YES / NO

**Release authorized:** YYYY-MM-DD HH:MM UTC
```

---

**END OF CHECKLIST**

**Critical:** Do NOT release until ALL must-have criteria are ✅. Verification integrity is non-negotiable.

**Timeline:** Allow minimum 2 weeks from verification freeze to release. External audit adds 2-4 weeks (start early).

**Questions?** Escalate to Formal Verification Lead or Security Lead immediately.
