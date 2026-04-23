# CA Formal Verification Release Checklist (RELEASE_CHECKLIST.md)

Complete pre-release validation checklist for CA formal verification. Run before each release to ensure all verification is current, documented, and reproducible.

**Last updated:** 2026-04-22

---

## Quick Reference

```bash
# Run full release checklist (automated where possible)
./scripts/release_check.sh

# Or manual step-by-step (below)
```

---

## Pre-Release Checklist

### Phase 1: Verification Status

#### Lean Verification
- [ ] Run `cd lean && lake build` - completes with zero errors
- [ ] Check build time: `time lake build` - each file ≤3 min, full tree ≤10 min
- [ ] Zero sorry: `grep -r sorry lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean"` returns nothing
- [ ] Run `./audit/verify-ca.sh --stack lean` - all 5 operations pass
- [ ] Check coverage: `./audit/verify-ca.sh --coverage` - reports 310+ theorems

**Expected:**
```
✅ Lean tree builds in ~4s (warm cache)
✅ Zero sorry in all theorems
✅ 310+ theorems, 27 axioms (10 CA, 17 crypto deps)
✅ All 5 operations verify in 1-2s each
```

#### Move Prover Verification
- [ ] Check Z3 version: `$Z3_EXE --version` - must be 4.11.2 (NOT 4.14.x)
- [ ] Compile specs: `cd ../aptos-experimental && movement move compile` - zero errors
- [ ] Run Move Prover: `./audit/verify-ca.sh --stack move-prover` - all 5 operations pass
- [ ] Check for escapes: `grep -r "pragma verify = false" ../aptos-experimental/sources/confidential_asset/ --include="*.spec.move"` - only test-only module

**Expected:**
```
✅ Z3 4.11.2 (exact version)
✅ All specs compile cleanly
✅ 0 VCs (expected due to ristretto255 blocker, acceptable for now)
✅ Only 1 test-only pragma verify = false
```

#### Difftest Verification
- [ ] Check harness status: Implemented? (currently pending)
- [ ] If implemented: `./audit/verify-ca.sh --stack difftest` - all 87+ rows pass
- [ ] Check corpus coverage: `ls -1 difftest/corpora/confidential_asset/*.json | wc -l` - ≥87

**Expected (once harness lands):**
```
✅ Difftest harness implemented
✅ All 87+ corpus rows pass
✅ VM output matches Lean eval byte-for-byte
```

#### Trust Boundaries & Axioms
- [ ] Run `./scripts/reconcile_trust_boundaries.sh` - passes
- [ ] Run `./scripts/check_axioms.sh` - axiom count ≤30
- [ ] Run `./scripts/check_axioms.sh --diff` - no drift vs baseline
- [ ] Check AXIOM_INVENTORY.md - all axioms documented with rationale

**Expected:**
```
✅ TRUST_BOUNDARIES.md reconciled (10 CA axioms, 89 pragma opaque)
✅ Axiom count: 27 (10 CA, 17 crypto deps)
✅ No axiom drift vs baseline
✅ All axioms documented in AXIOM_INVENTORY.md
```

### Phase 2: Documentation

#### Core Documentation
- [ ] CLAIMS.md - has entry for every public function
- [ ] TRUST_BOUNDARIES.md - "Last reconciled" date is current (<30 days)
- [ ] AXIOM_INVENTORY.md - rationale complete for all 27 axioms
- [ ] PHASE_7_STATUS.md - completion % is accurate
- [ ] COMPLETION_ROADMAP.md - estimates are realistic, updated

**Expected:**
```
✅ CLAIMS.md: 40+ claims covering all public functions
✅ TRUST_BOUNDARIES.md: Last reconciled within 30 days
✅ AXIOM_INVENTORY.md: All 27 axioms documented
✅ PHASE_7_STATUS.md: 90%+ complete
✅ COMPLETION_ROADMAP.md: Estimates accurate
```

#### Comprehensive Guides
- [ ] REVIEWER_QUICK_START.md - "Last updated" is current (<90 days)
- [ ] THREE_STACK_VERIFICATION_STORY.md - current
- [ ] TROUBLESHOOTING_GUIDE.md - covers common issues
- [ ] AUDITOR_GUIDE.md - workflow is accurate
- [ ] MAINTENANCE_GUIDE.md - procedures are up-to-date

**Expected:**
```
✅ All guides have "Last updated" within 90 days
✅ Content is accurate (no stale references)
✅ Covers current tool versions
```

#### Technical Documentation
- [ ] MSL_SPEC_COVERAGE.md - matches actual spec blocks (41+ blocks)
- [ ] BYTECODE_VERIFICATION_COVERAGE.md - matches actual theorems (310+ theorems)
- [ ] MOVE_PROVER_INTEGRATION_STATUS.md - blocker status current
- [ ] DOCKER_REPRODUCIBILITY_GUIDE.md - Docker commands work

**Expected:**
```
✅ MSL_SPEC_COVERAGE.md: 41+ spec blocks documented
✅ BYTECODE_VERIFICATION_COVERAGE.md: 310+ theorems documented
✅ Guides are tested and accurate
```

### Phase 3: Performance

#### Timing Budgets
- [ ] Run `./scripts/benchmark_verification.sh` - capture baseline
- [ ] Per-operation budget: Each op ≤3 min (180s)
  - [ ] register: `./audit/verify-ca.sh --op register` ≤180s
  - [ ] withdraw: `./audit/verify-ca.sh --op withdraw` ≤180s
  - [ ] transfer: `./audit/verify-ca.sh --op transfer` ≤180s
  - [ ] normalize: `./audit/verify-ca.sh --op normalize` ≤180s
  - [ ] rotate: `./audit/verify-ca.sh --op rotate` ≤180s
- [ ] Full-run budget: `./audit/verify-ca.sh` ≤45 min (2700s)

**Expected:**
```
✅ register: ~1-2s (100x under budget)
✅ withdraw: ~1-2s (100x under budget)
✅ transfer: ~1-2s (100x under budget)
✅ normalize: ~1-2s (100x under budget)
✅ rotate: ~1-2s (100x under budget)
✅ Full run: ~6-11s (450x under budget)
```

#### Regression Check
- [ ] Compare to previous baseline: `diff benchmarks/baseline-current.txt benchmarks/baseline-previous.txt`
- [ ] If >20% slower on any operation: Investigate (acceptable if new proofs added, not acceptable if silent regression)

**Expected:**
```
✅ No operation >20% slower than previous release
✅ If slower: documented reason (new proofs, strengthened specs, etc.)
```

### Phase 4: CI/CD

#### CI Status
- [ ] `.github/workflows/lean-ca.yaml` - passing on main
- [ ] `.github/workflows/axiom-diff-ca.yaml` - passing on main
- [ ] `.github/workflows/ca-verification-suite.yaml` - passing on main (if enabled)
- [ ] Check recent PR: All workflows green before merge

**Expected:**
```
✅ All enabled workflows passing on main
✅ No flaky tests (check last 10 runs)
✅ Workflow timing within expected range (~15 min for full suite)
```

#### Docker Status
- [ ] Dockerfile builds: `docker build -t ca-fv -f audit/Dockerfile .` - succeeds
- [ ] Toolchain verification: Image build validates all tool versions
- [ ] Docker image published: Check `docker pull ghcr.io/movement-labs/ca-formal-verification:latest` (once published)
- [ ] Digest pinned: `audit/toolchain.lock` has docker-digest entry

**Expected:**
```
✅ Dockerfile builds successfully (~20 min)
✅ Toolchain verification passes during build
✅ Image published to registry (once published)
✅ Digest pinned in toolchain.lock
```

### Phase 5: Reproducibility

#### Toolchain Pins
- [ ] `lean/lean-toolchain` - Lean 4.24.0
- [ ] `audit/toolchain.lock` - all versions documented
- [ ] Z3 exact version enforced: Movement CLI installs 4.11.2
- [ ] Boogie version pinned: 3.5.1
- [ ] Docker pins all tools

**Expected:**
```
✅ Lean 4.24.0 (pinned in lean-toolchain)
✅ Z3 4.11.2 (pinned by Movement CLI, verified in CI)
✅ Boogie 3.5.1 (pinned by Movement CLI)
✅ All versions in toolchain.lock match reality
```

#### Fresh Clone Test
- [ ] Clone repo on clean machine: `git clone https://github.com/movementlabsxyz/aptos-core.git`
- [ ] Run setup: Install Lean, Movement CLI, prover dependencies
- [ ] Run verification: `./audit/verify-ca.sh` - passes
- [ ] Time to green: ≤1 hour from clone to verified (manual setup) or ≤30 min (Docker)

**Expected:**
```
✅ Fresh clone on clean machine verifies successfully
✅ Manual setup: ≤1 hour to green
✅ Docker setup: ≤30 min to green (build ~20 min, verify ~6s)
```

### Phase 6: Regression Testing

#### No New Axioms
- [ ] Run `./scripts/check_axioms.sh` - count ≤27
- [ ] Compare to baseline: `./scripts/check_axioms.sh --diff` - no new axioms
- [ ] If new axiom: Documented in AXIOM_INVENTORY.md with rationale

**Expected:**
```
✅ Axiom count ≤27 (10 CA, 17 crypto deps)
✅ No new axioms vs previous release (or documented if intentional)
```

#### No New Escapes
- [ ] Check pragma verify=false: `grep -r "pragma verify = false" ../aptos-experimental/sources/confidential_asset/ --include="*.spec.move"` - count ≤1
- [ ] Check pragma deactivated: `grep -r "pragma deactivated_proof" ../aptos-experimental/sources/confidential_asset/ --include="*.spec.move"` - count = 0 (except ristretto255 workaround)

**Expected:**
```
✅ Only 1 pragma verify=false (test-only module)
✅ Zero pragma deactivated_proof in CA code (ristretto255 workaround in upstream is OK)
```

#### No New Sorry
- [ ] Check Lean: `grep -r sorry lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean"` - count = 0
- [ ] Compare to previous release: No increase

**Expected:**
```
✅ Zero sorry in all CA Lean files
✅ No increase vs previous release
```

### Phase 7: Release Artifacts

#### Git State
- [ ] Working directory clean: `git status` - no uncommitted changes
- [ ] All changes committed: `git diff` returns nothing
- [ ] All changes pushed: `git log origin/main..main` returns nothing
- [ ] Tag created: `git tag v1.x.y -m "CA formal verification vX.Y.Z"`

**Expected:**
```
✅ Working directory clean
✅ All changes committed and pushed
✅ Release tag created
```

#### Release Notes
- [ ] Create `RELEASE_NOTES_vX.Y.Z.md` with:
  - [ ] Version number and date
  - [ ] Summary of changes (new proofs, strengthened specs, doc updates)
  - [ ] Performance vs previous release (benchmark comparison)
  - [ ] Known issues / blockers (e.g., ristretto255, difftest harness pending)
  - [ ] Breaking changes (tool version updates, axiom changes)
  - [ ] Acceptance criteria met (7/7 for Phase 7, etc.)

**Template:**
```markdown
# CA Formal Verification Release vX.Y.Z

**Release date:** YYYY-MM-DD
**Git tag:** vX.Y.Z
**Commit:** <sha>

## Summary

[Brief summary of what's in this release]

## Changes

### Proofs
- [New theorems, reproved axioms, etc.]

### Specifications
- [Strengthened MSL specs, new spec blocks, etc.]

### Documentation
- [New guides, updated docs, etc.]

### Infrastructure
- [CI improvements, new scripts, Docker updates, etc.]

## Performance

| Operation | Previous | Current | Change |
|-----------|----------|---------|--------|
| register  | Xs       | Ys      | +/-Z%  |
| ...       | ...      | ...     | ...    |

## Acceptance Criteria

- [X] Phase 7 §10.6: 7/7 criteria met
- [ ] Phase 1: Singleton branch (95%, outstanding)
- ...

## Known Issues

- Ristretto255 blocker: Move Prover generates 0 VCs (expected, workaround applied)
- Difftest harness: Pending integration (~1 day estimated)
- ...

## Breaking Changes

- None (or list if any)

## Contributors

- [List of people who contributed to this release]
```

#### Benchmark Baseline
- [ ] Run `./scripts/benchmark_verification.sh --baseline > benchmarks/baseline-vX.Y.Z.txt`
- [ ] Commit baseline to repo
- [ ] Compare to previous release: `diff benchmarks/baseline-v1.2.3.txt benchmarks/baseline-v1.2.4.txt`

**Expected:**
```
✅ Baseline captured and committed
✅ Comparison shows no unexpected regressions
```

---

## Automated Check (Quick)

Run comprehensive automated check:

```bash
cd aptos-move/framework/formal
./scripts/run_verification_suite.sh --comprehensive

# Or step-by-step:
./scripts/run_verification_suite.sh --quick           # 2 min, essential checks
./scripts/run_verification_suite.sh                   # 5 min, standard checks
./scripts/run_verification_suite.sh --comprehensive   # 15 min, full suite
```

**Pass criteria:** All checks pass (exit code 0)

---

## Manual Verification (Thorough)

For major releases, run full manual verification:

### Day Before Release

1. **Full verification suite** (~15 min)
   ```bash
   ./scripts/run_verification_suite.sh --comprehensive
   ```

2. **Fresh clone test** (~1 hour)
   ```bash
   # On clean machine (or clean Docker container)
   git clone https://github.com/movementlabsxyz/aptos-core.git
   cd aptos-core/aptos-move/framework/formal
   # Follow REVIEWER_QUICK_START.md
   ./audit/verify-ca.sh
   ```

3. **Docker build test** (~30 min)
   ```bash
   docker build -t ca-fv-test -f audit/Dockerfile .
   docker run --rm ca-fv-test
   ```

4. **Benchmark capture** (~5 min)
   ```bash
   ./scripts/benchmark_verification.sh --baseline > benchmarks/baseline-vX.Y.Z.txt
   git add benchmarks/baseline-vX.Y.Z.txt
   git commit -m "Add benchmark baseline for vX.Y.Z"
   ```

5. **Documentation review** (~30 min)
   - Read through PHASE_7_STATUS.md (confirm % accurate)
   - Read through COMPLETION_ROADMAP.md (confirm estimates realistic)
   - Spot-check 3 random guides (confirm no stale content)

### Day of Release

1. **Final verification** (~5 min)
   ```bash
   ./scripts/run_verification_suite.sh
   ```

2. **Git tag** (~1 min)
   ```bash
   git tag v1.x.y -m "CA formal verification vX.Y.Z release"
   git push origin v1.x.y
   ```

3. **Docker publish** (once, ~30 min)
   ```bash
   docker build -t ca-formal-verification:vX.Y.Z -f audit/Dockerfile .
   docker tag ca-formal-verification:vX.Y.Z ghcr.io/movement-labs/ca-formal-verification:vX.Y.Z
   docker tag ca-formal-verification:vX.Y.Z ghcr.io/movement-labs/ca-formal-verification:latest
   docker push ghcr.io/movement-labs/ca-formal-verification:vX.Y.Z
   docker push ghcr.io/movement-labs/ca-formal-verification:latest
   
   # Capture digest
   DIGEST=$(docker inspect ghcr.io/movement-labs/ca-formal-verification:vX.Y.Z | jq -r '.[0].RepoDigests[0]')
   echo "docker-digest=$DIGEST" >> audit/toolchain.lock
   git add audit/toolchain.lock
   git commit -m "Pin Docker digest for vX.Y.Z"
   git push
   ```

4. **Release notes** (~30 min)
   - Draft RELEASE_NOTES_vX.Y.Z.md (use template above)
   - Review with team
   - Publish on GitHub releases page

---

## Post-Release

### Immediate (same day)

1. **Verify release artifacts**
   ```bash
   # Check tag
   git tag | grep vX.Y.Z
   
   # Check Docker image
   docker pull ghcr.io/movement-labs/ca-formal-verification:vX.Y.Z
   docker run --rm ghcr.io/movement-labs/ca-formal-verification:vX.Y.Z
   
   # Check release notes
   curl https://github.com/movementlabsxyz/aptos-core/releases/tag/vX.Y.Z
   ```

2. **Update documentation pointers**
   - REVIEWER_QUICK_START.md: Update "Latest release: vX.Y.Z"
   - AUDITOR_GUIDE.md: Update "Last verified: vX.Y.Z"

### Week 1 Post-Release

1. **Monitor CI** - Check workflows still green on main
2. **Monitor issues** - Any regression reports from users?
3. **Update roadmap** - Mark completed items, update estimates based on actual

### Month 1 Post-Release

1. **Quarterly audit** (see MAINTENANCE_GUIDE.md §9)
   - Axiom review (any drift?)
   - Documentation drift check (stale references?)
   - Upstream sync (FA specs changed?)
   - Performance regression check (compare baselines)
   - Tool version check (new Lean/Z3/Boogie releases?)

---

## Common Release Blockers

### Blocker 1: Axiom Drift

**Symptom:** `./scripts/check_axioms.sh --diff` fails

**Fix:**
1. Check if new axiom is intentional
2. If yes: Update `audit/axiom-baseline.txt` and `audit/AXIOM_INVENTORY.md`
3. If no: Remove axiom, fix proof
4. Re-run check

### Blocker 2: Build Time Regression

**Symptom:** Lean build >10 min (was ~4s)

**Fix:**
1. Identify slow file: `time lake build MovementFormal.Experimental.ConfidentialAsset.<Module>`
2. Profile with `set_option profiler true`
3. Add `@[irreducible]` to large intermediate states
4. Break monolithic proofs into smaller lemmas

### Blocker 3: Fresh Clone Fails

**Symptom:** Verification fails on clean machine

**Cause:** Usually tool version mismatch (Z3 4.14.x instead of 4.11.2)

**Fix:**
1. Check Z3 version: `$Z3_EXE --version`
2. If wrong: `movement update prover-dependencies --assume-yes`
3. Verify: `$Z3_EXE --version` should be 4.11.2

### Blocker 4: Docker Build Fails

**Symptom:** Dockerfile build fails at toolchain verification step

**Cause:** Upstream tool release changed version

**Fix:**
1. Check which tool failed (Lean? Z3? Boogie?)
2. Update Dockerfile to pin new version (or revert to old version)
3. Update `audit/toolchain.lock` to match
4. Test on clean machine

---

## Release Checklist Summary

**Quick checklist (15 min):**
- [ ] `./scripts/run_verification_suite.sh --comprehensive` passes
- [ ] `./scripts/reconcile_trust_boundaries.sh` passes
- [ ] `./scripts/check_axioms.sh --diff` passes
- [ ] Zero sorry, axiom count ≤27, only 1 pragma verify=false
- [ ] All docs have current "Last updated" dates
- [ ] Git state clean, all changes committed/pushed

**Thorough checklist (2 hours):**
- [ ] All of quick checklist
- [ ] Fresh clone test on clean machine passes
- [ ] Docker build test passes
- [ ] Benchmark baseline captured
- [ ] Release notes drafted
- [ ] Tag created and pushed
- [ ] Docker image published (once)

**Post-release (ongoing):**
- [ ] Monitor CI (week 1)
- [ ] Monitor issues (week 1)
- [ ] Update roadmap (week 1)
- [ ] Quarterly audit (month 1)

---

**Last updated:** 2026-04-22  
**Next update:** After first release or quarterly audit  
**Owner:** Release manager
