# Regression Prevention and Continuous Verification Guide

**Audience:** Verification engineers, CI/CD maintainers, release managers  
**Prerequisites:** Understanding of verification plan, CI infrastructure  
**Related:** `CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md`, `VERIFICATION_METRICS_DASHBOARD_GUIDE.md`

## Purpose

This guide provides systematic strategies for preventing verification regressions and maintaining continuous verification health:
- Early detection of proof breakage
- Pre-commit hooks and local checks
- Automated regression detection in CI
- Blame tracking and rollback procedures
- Verification-aware development workflows
- Release gates and verification SLOs

## Table of Contents

1. [Regression Types](#regression-types)
2. [Prevention Strategies](#prevention-strategies)
3. [Detection Mechanisms](#detection-mechanisms)
4. [Response Procedures](#response-procedures)
5. [Development Workflows](#development-workflows)
6. [Release Management](#release-management)
7. [Metrics and Monitoring](#metrics-and-monitoring)
8. [Case Studies](#case-studies)

---

## Regression Types

### 1.1 Proof Breakage

**Definition:** Previously-proved theorem no longer compiles or builds

**Symptoms:**
```
error: type mismatch
  eval ... = ...
has type
  ExecResult
but is expected to have type
  Bool
```

**Impact:** Blocks development, may indicate bug in code or proof

**Example causes:**
- Move source changed (function signature, control flow)
- Lean API changed (MoveModel.step semantics)
- Upstream mathlib change (tactic behavior)

**Detection time:** Immediate (CI build failure)

**Severity:** High (blocks merge)

### 1.2 Performance Regression

**Definition:** Build time exceeds budget (>3 min per file, >10 min full tree)

**Symptoms:**
```
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
# Takes 6 minutes (was 3 minutes last week)
```

**Impact:** Slows CI, frustrates developers, compounds over time

**Example causes:**
- New `@[simp]` lemma (increases simp set size)
- Removed `@[irreducible]` (expensive unfolds)
- Inefficient tactic (bare `simp` instead of `simp only`)

**Detection time:** Per-PR (performance benchmark job)

**Severity:** Medium (warning → error if >100% budget)

### 1.3 Axiom Creep

**Definition:** New axiom introduced without documentation/justification

**Symptoms:**
```
axiom-diff-ca.yaml: ❌ Failed
  New axioms detected: foo_bar_axiom
```

**Impact:** Weakens verification guarantees, expands trust base

**Example causes:**
- Incomplete proof landed with `axiom` stub
- Upstream dependency introduced axiom
- Temporary axiom not marked TEMPORARY

**Detection time:** Per-PR (axiom-diff job)

**Severity:** High (requires explicit justification + docs update)

### 1.4 Spec Weakening

**Definition:** MSL spec becomes less precise (fewer guarantees)

**Symptoms:**
```diff
- aborts_if balance < amount with EINSUFFICIENT_BALANCE;
+ pragma aborts_if_is_partial;
```

**Impact:** Bugs may slip through (spec no longer catches them)

**Example causes:**
- Developer frustrated by verification failure, weakens spec instead of fixing code
- Upstream spec incomplete, marked `pragma opaque`

**Detection time:** Manual code review (no automated check)

**Severity:** Medium-High (depends on weakened property)

### 1.5 Coverage Regression

**Definition:** Proof coverage or test coverage decreases

**Symptoms:**
```
Difftest coverage: 82% (was 87% last release)
Sorry count: 12 (was 5 last week)
```

**Impact:** Incomplete verification, known gaps

**Example causes:**
- New feature added without proofs
- Existing proof replaced with `sorry` during refactor
- Difftest corpus not updated for new operation

**Detection time:** Per-PR (sorry check, difftest coverage report)

**Severity:** Medium (acceptable temporarily during development, must resolve before release)

---

## Prevention Strategies

### 2.1 Pre-Commit Hooks

**Goal:** Catch regressions before they reach CI (faster feedback)

**Hook script:** `scripts/pre-commit-hook.sh`

**Checks (in order, fail-fast):**
1. **No sorry in critical files** (5 seconds):
   ```bash
   if grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "TEMPORARY" ; then
       echo "❌ Found sorry in ConfidentialAsset proofs"
       exit 1
   fi
   ```

2. **No bare simp in hot-path** (5 seconds):
   ```bash
   if git diff --cached | grep -E "^\+.*by simp$" ; then
       echo "⚠️ Warning: bare 'simp' detected (prefer 'simp only')"
       # Warning only, not blocking
   fi
   ```

3. **Lean syntax check** (10 seconds):
   ```bash
   lake build --no-build MovementFormal.Experimental.ConfidentialAsset > /dev/null 2>&1
   if [ $? -ne 0 ]; then
       echo "❌ Lean syntax errors detected"
       lake build MovementFormal.Experimental.ConfidentialAsset  # Show errors
       exit 1
   fi
   ```

4. **Move syntax check** (5 seconds):
   ```bash
   movement move compile --package-dir aptos-experimental > /dev/null 2>&1
   if [ $? -ne 0 ]; then
       echo "❌ Move syntax errors detected"
       exit 1
   fi
   ```

5. **Quick performance check** (30 seconds):
   ```bash
   time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild 2>&1 | grep "real"
   # If >4 min, warn (soft limit)
   ```

**Total time:** <1 minute (fast enough for pre-commit)

**Installation:**
```bash
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Escape hatch (emergency only):**
```bash
git commit --no-verify  # Skips hook
```

### 2.2 Branch Protection Rules

**Goal:** Enforce verification before merge

**GitHub branch protection (on `main`, `movement`):**
- ✅ Require status checks:
  - `quick-check`
  - `lean-verification`
  - `move-prover-compilation`
  - `axiom-diff-ca`
- ✅ Require PR reviews (1 approver minimum)
- ✅ Require linear history (no merge commits)
- ✅ Block force push

**Why:** Prevents accidental merge of broken verification

**Override:** Only admins, only for emergency fixes

### 2.3 Local Development Guard Rails

**Goal:** Make it easy to do the right thing

**Developer workflow:**
1. **Before starting work:**
   ```bash
   # Ensure clean baseline
   git checkout main
   git pull
   cd aptos-move/framework/formal/lean
   lake exe cache get  # Warm mathlib cache
   lake build  # Should pass
   ```

2. **During development:**
   ```bash
   # Incremental check after each change
   lake build MovementFormal.Experimental.ConfidentialAsset.<Module>
   # Should stay fast (<3 min)
   ```

3. **Before committing:**
   ```bash
   # Pre-commit hook runs automatically, but can run manually:
   ./scripts/pre-commit-hook.sh
   ```

4. **Before opening PR:**
   ```bash
   # Full local CI simulation
   ./scripts/run_verification_suite.sh --standard
   # ~5 min, catches most CI failures
   ```

**Automation:** VS Code task for "Verify current file":
```json
{
    "label": "Verify Lean file",
    "type": "shell",
    "command": "lake build ${relativeFileDirname}.${fileBasenameNoExtension}",
    "group": {
        "kind": "build",
        "isDefault": true
    }
}
```

**Keybinding:** `Ctrl+Shift+B` → verify current file

### 2.4 Proactive Architecture Patterns

**Pattern 1: Design for stability**
- Use `@[irreducible]` from day 1 (prevents accidental unfold)
- Use `@[simp only]` (explicit lemma list, not affected by new simp lemmas)
- Minimize dependencies (fewer upstream changes to break on)

**Pattern 2: Explicit error messages**
```lean
-- BAD (generic error):
theorem foo : ... := by sorry

-- GOOD (explicit TODO):
theorem foo : ... := by
  -- TODO(Phase 6): Prove via PC-chaining
  -- Blocked on: run_succ_ok_of_step lemma for CallGeneric
  sorry
```

**Pattern 3: Incremental proof development**
```lean
-- Step 1: Axiom stub (compiles, fails axiom-diff)
axiom foo : P

-- Step 2: Theorem with sorry (compiles, fails sorry check)
theorem foo : P := by sorry

-- Step 3: Partial proof (compiles, fails sorry check)
theorem foo : P := by
  have h1 : Q := by omega
  have h2 : R := by sorry
  exact combine h1 h2

-- Step 4: Complete proof (compiles, passes all checks)
theorem foo : P := by
  have h1 : Q := by omega
  have h2 : R := by simp only [...]
  exact combine h1 h2
```

**Pattern 4: Test-driven verification**
1. Write difftest scenario FIRST (expected behavior)
2. Write functional simulation (mathematical spec)
3. Write MSL spec (state-level properties)
4. Write Lean proof (bytecode correctness)

**Why:** Catching bugs early (at spec level) cheaper than catching late (at proof level)

---

## Detection Mechanisms

### 3.1 CI Check Matrix

**Comprehensive detection across all regression types:**

| Regression Type | Detection Mechanism | Latency | Blocking? |
|-----------------|---------------------|---------|-----------|
| Proof breakage | `lean-verification` job | Per-PR (6 min) | ✅ Yes |
| Performance | `performance-benchmarks` job | Per-PR (2 min) | ⚠️ >100% budget |
| Axiom creep | `axiom-diff-ca` job | Per-PR (1 min) | ✅ Yes |
| Sorry count | `sorry-check` step in lean-verification | Per-PR (10 sec) | ✅ Yes |
| Spec weakening | Code review (manual) | Per-PR (human) | ⚠️ Reviewer discretion |
| Coverage drop | Difftest coverage report | Nightly (20 min) | ❌ No (alerts only) |

**Why nightly for coverage:** Full difftest corpus slow (20 min), not suitable for per-PR

**Alert thresholds:**
- Performance: >50% budget → yellow, >100% → red
- Sorry count: >0 in critical files → red
- Coverage: -5% → yellow, -10% → red

### 3.2 Automated Blame Tracking

**Goal:** Identify which commit caused regression

**Git bisect automation:**
```bash
#!/bin/bash
# scripts/bisect_performance_regression.sh

# Usage: ./bisect_performance_regression.sh <good-commit> <bad-commit> <file> <threshold>

git bisect start $2 $1

git bisect run sh -c "
    cd aptos-move/framework/formal/lean
    lake clean
    time lake build $3 2>&1 | grep 'real' | awk '{print \$2}' | \
    awk -F'm' '{print \$1 * 60 + substr(\$2, 1, length(\$2)-1)}' | \
    awk '{exit (\$1 > $4) ? 1 : 0}'
"

git bisect reset
```

**Example:**
```bash
./scripts/bisect_performance_regression.sh v1.0.0 HEAD \
    MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild \
    180  # 3 minutes in seconds
# Output: First bad commit: abc123def
```

**When to use:** When performance regression detected but cause unclear

### 3.3 Continuous Monitoring

**Metrics tracked over time:**
1. **Build time trend** (per-operation, per-file)
2. **Axiom count trend** (total, by category)
3. **Sorry count trend** (total, by file)
4. **Difftest coverage trend** (% scenarios passing)
5. **MSL VC count trend** (verification conditions generated/proved)

**Alerting rules:**
- Build time: 2-week plateau above 75% budget → investigate
- Axiom count: Any increase → manual review required
- Sorry count: 1-week plateau → ping assignee
- Coverage: 2-week declining trend → prioritize corpus expansion

**Grafana dashboard:** (future, Phase 7 deliverable)
- Real-time verification health
- Historical trends
- Per-operation drill-down

---

## Response Procedures

### 4.1 Proof Breakage Response (SLA: <1 hour)

**When:** CI `lean-verification` job fails on main branch

**Owner:** On-call verification engineer

**Procedure:**
1. **Assess severity** (<5 min):
   ```bash
   # Check if blocking deploys
   git log -1 --oneline  # What commit broke?
   git diff HEAD~1 HEAD  # What changed?
   ```

2. **Quick fix attempt** (<30 min):
   ```bash
   cd aptos-move/framework/formal/lean
   lake build <broken-file>
   # Read error, attempt obvious fix
   ```

3. **If quick fix works:**
   ```bash
   git commit -m "fix: restore proof broken by <commit>"
   git push
   ```

4. **If quick fix doesn't work:**
   - Revert breaking commit:
     ```bash
     git revert <commit>
     git push
     ```
   - File issue for proper fix
   - Notify breaking commit author

5. **If revert not possible (breaking commit needed for release):**
   - Replace proof with `axiom` stub (temporary):
     ```lean
     axiom foo : P  -- TEMPORARY: broken by commit abc123, fix in #1234
     ```
   - File high-priority issue
   - Schedule fix for next sprint

**Post-incident:**
- Document in `PROOF_BREAKAGE_LOG.md`
- If recurring pattern, update pre-commit hook to catch

### 4.2 Performance Regression Response (SLA: <1 day)

**When:** Performance benchmark >75% of budget

**Owner:** Author of PR introducing regression

**Procedure:**
1. **Measure exactly** (<10 min):
   ```bash
   ./scripts/benchmark_verification.sh --format json > /tmp/benchmark.json
   jq '.operations[] | select(.time_seconds > 135)' /tmp/benchmark.json
   # Shows which operation(s) regressed
   ```

2. **Profile slow operation** (<20 min):
   ```bash
   lake build --profile MovementFormal.Experimental.ConfidentialAsset.<Operation>.EvalEquiv
   # Read profile output, identify hotspot
   ```

3. **Apply optimization** (see [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md)):
   - Replace `simp` → `simp only`
   - Add `@[irreducible]` if missing
   - Use step-lemma library

4. **Verify fix:**
   ```bash
   time lake build MovementFormal.Experimental.ConfidentialAsset.<Operation>.EvalEquiv
   # Should be <3 min
   ```

5. **If can't fix quickly:**
   - Request design review (may need architecture change)
   - Escalate to verification team lead

**Post-incident:**
- Update `LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md` with new pattern (if novel)
- Consider adding pre-commit hook check

### 4.3 Axiom Creep Response (SLA: immediate)

**When:** `axiom-diff-ca` job fails

**Owner:** Author of PR introducing axiom

**Procedure:**
1. **Check if axiom is justified** (<5 min):
   - Temporary (proof incomplete)? → Mark `-- TEMPORARY:` + issue number
   - Crypto assumption? → Document in `TRUST_BOUNDARIES.md`
   - Framework (upstream)? → Document source + justification

2. **If justified:**
   ```bash
   # Update baseline
   ./audit/verify-ca.sh --coverage > audit/axiom-baseline.txt
   
   # Update TRUST_BOUNDARIES.md
   vim audit/TRUST_BOUNDARIES.md
   # Add entry in appropriate section
   
   git add audit/axiom-baseline.txt audit/TRUST_BOUNDARIES.md
   git commit -m "docs: document new axiom <name>"
   ```

3. **If NOT justified (accidental):**
   - Revert commit OR
   - Complete proof (remove axiom)

**Never acceptable:**
- Unmarked temporary axiom (must have `-- TEMPORARY:` comment)
- Undocumented crypto axiom
- Axiom introduced to "unblock" without justification

---

## Development Workflows

### 5.1 Feature Development with Verification

**Scenario:** Adding new CA operation (e.g., `batch_transfer`)

**Workflow:**

**Phase 1: Specification** (Day 1-2)
1. Write Move implementation
2. Write MSL spec (complete `ensures`, `aborts_if`)
3. Write difftest scenarios (happy path + error cases)
4. Run `movement move prove` (expect failures, spec may be incomplete)

**Phase 2: Functional Simulation** (Day 3-4)
5. Write Lean functional simulation
6. Write oracle interface
7. Test oracle via difftest (mock oracle first, real oracle later)

**Phase 3: Bytecode Verification** (Day 5-10)
8. Transcribe bytecode to Lean
9. Prove per-PC step lemmas
10. Chain PCs via `run`
11. Prove `eval_equiv_functional_sim` (may have `sorry` placeholders)

**Phase 4: Completion** (Day 11-15)
12. Complete all `sorry` proofs
13. Run full verification suite
14. Update `CLAIMS.md`, `COMPREHENSIVE_GUIDES_INDEX.md`
15. Open PR

**Checkpoints (blockers if failed):**
- End of Phase 1: MSL spec compiles, difftest scenarios defined
- End of Phase 2: Functional simulation type-checks
- End of Phase 3: Bytecode transcription complete, all PCs proved
- End of Phase 4: Zero `sorry`, zero new axioms, all tests pass

**If checkpoint fails:** Fix before proceeding (don't accumulate debt)

### 5.2 Refactoring with Verification

**Scenario:** Performance optimization (e.g., switching from chained state to `@[irreducible]`)

**Workflow:**

**Phase 1: Snapshot** (30 min)
1. Capture current axiom baseline:
   ```bash
   ./audit/verify-ca.sh --coverage > /tmp/axioms-before.txt
   ```

2. Capture current performance:
   ```bash
   ./scripts/benchmark_verification.sh > /tmp/perf-before.txt
   ```

3. Identify proofs that will break:
   ```bash
   grep -r "chained_state" lean/ --include="*.lean"
   ```

**Phase 2: Refactor** (Days 1-5)
4. Make architectural change
5. Fix proof breakage (may temporarily use `sorry`)
6. Ensure builds complete (even with `sorry`)

**Phase 3: Repair** (Days 6-10)
7. Replace `sorry` with actual proofs
8. Verify axiom count unchanged:
   ```bash
   ./audit/verify-ca.sh --coverage > /tmp/axioms-after.txt
   diff /tmp/axioms-before.txt /tmp/axioms-after.txt
   # Should be empty (no new axioms)
   ```

9. Verify performance improvement:
   ```bash
   ./scripts/benchmark_verification.sh > /tmp/perf-after.txt
   diff /tmp/perf-before.txt /tmp/perf-after.txt
   # Should show improvement
   ```

**Phase 4: Cleanup** (Day 11)
10. Remove dead code (old chained definitions)
11. Update guides (e.g., `BYTECODE_TRANSCRIPTION_WORKFLOW_GUIDE.md`)
12. Open PR

**If axiom count increases:** Investigate, fix, or document

**If performance doesn't improve:** Revert, try different approach

### 5.3 Debugging Verification Failures

**Scenario:** Proof fails after upstream change

**Workflow:**

1. **Isolate failure** (<5 min):
   ```bash
   lake build MovementFormal.Experimental.ConfidentialAsset.<Module>
   # Read error message, identify failing theorem
   ```

2. **Check if upstream change** (<5 min):
   ```bash
   git log -p -- lean/MovementFormal/MoveModel/
   # Did MoveModel change recently?
   ```

3. **Minimal reproduction** (<15 min):
   ```lean
   -- In scratch file
   import MovementFormal.MoveModel.Step
   
   #check step  -- Changed signature?
   
   example : step env frame cs stack ms = ... := by
     unfold step
     -- Where does it fail?
   ```

4. **Fix strategies:**
   - **Signature change:** Update theorem statement
   - **Tactic change:** Replace tactic (e.g., `simp` → `simp only`)
   - **Lemma removed:** Re-prove lemma locally or find replacement

5. **Verify fix:**
   ```bash
   lake build MovementFormal.Experimental.ConfidentialAsset
   # Should pass
   ```

**Escalation:** If can't fix in 1 hour, ping verification team (Slack `#formal-verification`)

---

## Release Management

### 6.1 Verification Release Gates

**Definition:** Criteria that MUST pass before release

**Gate 1: Zero sorry in critical files**
```bash
SORRY_COUNT=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ --include="*.lean" | grep -v "TEMPORARY" | wc -l)
if [ $SORRY_COUNT -ne 0 ]; then
    echo "❌ Blocking release: $SORRY_COUNT sorry placeholders"
    exit 1
fi
```

**Gate 2: Axiom inventory reviewed**
```bash
./audit/verify-ca.sh --coverage > /tmp/axioms.txt
# Manual review: every axiom has justification in TRUST_BOUNDARIES.md
```

**Gate 3: All verification jobs green**
```bash
# CI status for release branch
gh run list --branch release-v1.0 --workflow ca-verification-suite.yaml --json conclusion
# Must be: [{"conclusion": "success"}]
```

**Gate 4: Difftest coverage ≥95%**
```bash
COVERAGE=$(./difftest/difftest.sh --all --quiet | grep "Coverage:" | awk '{print $2}' | sed 's/%//')
if [ $COVERAGE -lt 95 ]; then
    echo "❌ Blocking release: Coverage $COVERAGE% < 95%"
    exit 1
fi
```

**Gate 5: Performance within budget**
```bash
./scripts/benchmark_verification.sh --exit-code-on-regression
# Exit 0: within budget, Exit 1: exceeds budget
```

**Enforcement:** Automated in `release-gate.yaml` workflow (runs on release branches)

**Override:** Requires VP approval + documented exception

### 6.2 Verification SLOs (Service Level Objectives)

**SLO 1: CI feedback latency**
- **Target:** 95% of PRs get verification result in <15 min
- **Measurement:** `time_to_first_green` metric (PR opened → all checks green)
- **Why 15 min:** Fast enough for synchronous development (developer waits for CI)

**SLO 2: Proof coverage**
- **Target:** 100% of critical operations (register, withdraw, transfer, normalize, rotate) have completed Lean proofs
- **Measurement:** Sorry count in `ConfidentialAsset/` directory
- **Why 100%:** Critical path must be fully verified

**SLO 3: Axiom stability**
- **Target:** ≤23 axioms (21 permanent crypto + 2 temporary)
- **Measurement:** `#print axioms` output length
- **Why ≤23:** Current baseline; any increase requires justification

**SLO 4: Build performance**
- **Target:** 90% of files build in <3 min
- **Measurement:** `lake build --profile` output
- **Why 90%:** Allows headroom for occasional complex proofs (10% can be 3-5 min)

**SLO 5: Test coverage**
- **Target:** ≥95% scenario coverage in difftest corpus
- **Measurement:** Difftest coverage report
- **Why 95%:** High confidence, allows 5% edge cases deferred

**Reporting:** SLO dashboard (Grafana, future)

**Breach response:**
- SLO missed 1 week → Yellow alert, investigate
- SLO missed 2 weeks → Red alert, escalate to team lead
- SLO missed 1 month → Incident, root cause analysis required

---

## Metrics and Monitoring

### 7.1 Key Metrics

**Build Health:**
- Time to build full tree (target: <10 min cold)
- Time to build per operation (target: <3 min)
- Cache hit rate (target: >80%)

**Proof Health:**
- Sorry count (target: 0)
- Axiom count (target: ≤23)
- Proof coverage % (target: 100% for critical ops)

**Test Health:**
- Difftest pass rate (target: 100%)
- Difftest coverage % (target: ≥95%)
- MSL VC count (target: all proved, 0 timeouts)

**Velocity:**
- Theorems proved per week
- Lines of proof per week
- Operations verified per month

**Incidents:**
- Proof breakages per week (target: <1)
- Performance regressions per week (target: <1)
- Axiom creep incidents per month (target: 0)

### 7.2 Dashboard Design

**Text-based dashboard** (current, generated by `scripts/verification_status.sh`):
```
╔══════════════════════════════════════════════════════════════╗
║ Confidential Assets Verification Status (2026-04-22)        ║
╠══════════════════════════════════════════════════════════════╣
║ Build Health                                                 ║
║   Full tree build: 1.6s (1886 jobs) ✅                      ║
║   Registration:    3.0s ⚠️ (at budget)                      ║
║   Withdrawal:      0.5s ✅                                   ║
║   Transfer:        0.7s ✅                                   ║
║   Normalization:   0.5s ✅                                   ║
║   Rotation:        0.5s ✅                                   ║
╠══════════════════════════════════════════════════════════════╣
║ Proof Health                                                 ║
║   Sorry count:     0 ✅                                      ║
║   Axiom count:     23 (21 permanent + 2 temporary) ✅        ║
║   Coverage:        100% critical ops ✅                      ║
╠══════════════════════════════════════════════════════════════╣
║ Test Health                                                  ║
║   Difftest pass:   97/102 (95%) ✅                          ║
║   MSL VCs:         0/0 proved ⚠️ (ristretto255 blocked)    ║
╠══════════════════════════════════════════════════════════════╣
║ Incidents (Last 7 Days)                                      ║
║   Proof breakages: 0 ✅                                      ║
║   Perf regressions: 1 ⚠️ (Registration +0.2s)              ║
║   Axiom creep:     0 ✅                                      ║
╚══════════════════════════════════════════════════════════════╝
```

**Future (Grafana):**
- Time-series graphs (build time over 30 days)
- Heatmap (which operations slow down when)
- Alert history (incidents over time)
- SLO burn-down (how close to breach)

---

## Case Studies

### Case Study 1: Registration Performance Regression (Hypothetical)

**Timeline:**
- **Day 1, 10am:** PR #456 merged (adds 5 new `@[simp]` lemmas)
- **Day 1, 10:05am:** CI `performance-benchmarks` job shows Registration 3.0s → 4.5s (+50%)
- **Day 1, 10:10am:** Auto-comment on PR #456 alerts regression
- **Day 1, 10:30am:** Author investigates, finds: new simp lemmas used in Registration proofs
- **Day 1, 11:00am:** Author opens PR #457 replacing `simp` → `simp only` in Registration
- **Day 1, 11:30am:** PR #457 merged, build time back to 3.0s

**Lessons:**
- Fast detection (5 min via CI)
- Fast fix (1 hour total)
- Prevention: Could pre-commit hook warn on new `@[simp]` in hot-path?

### Case Study 2: Axiom Creep Caught by CI (Real)

**Timeline:**
- **Week 1:** Developer working on Phase 6 composition proofs
- **Week 2:** Developer stuck on `transfer_eval_equiv_functional_sim`, uses `axiom` stub
- **Week 2, Fri:** Developer opens PR with axiom (forgotten to remove)
- **Week 2, Fri, 5pm:** CI `axiom-diff-ca` job fails: "New axiom detected: transfer_eval_equiv_functional_sim"
- **Week 2, Fri, 5:05pm:** Developer sees failure, adds `-- TEMPORARY:` comment + issue #789
- **Week 2, Fri, 5:10pm:** Developer updates `audit/axiom-baseline.txt`, documents in `TRUST_BOUNDARIES.md`
- **Week 2, Fri, 5:20pm:** PR approved (temporary axiom acceptable with tracking)

**Lessons:**
- Axiom-diff gate effective (caught undocumented axiom)
- Fast remediation (15 min to document)
- Process: Temporary axioms OK if explicitly marked + tracked

### Case Study 3: Spec Weakening Caught in Review (Real)

**Timeline:**
- **Week 1:** Developer adding MSL spec for `withdraw_to_internal`
- **Week 1, Day 3:** Move Prover times out on balance conservation property
- **Week 1, Day 4:** Developer frustrated, changes `pragma aborts_if_is_strict` → `pragma aborts_if_is_partial`
- **Week 1, Day 5:** PR opened
- **Week 1, Day 6:** Reviewer notices spec weakening, comments: "Why partial? Spec should be complete."
- **Week 1, Day 7:** Developer explains timeout issue
- **Week 1, Day 8:** Reviewer suggests simplifying spec (break into smaller `ensures` clauses)
- **Week 1, Day 9:** Developer refactors spec, Move Prover succeeds with strict aborts
- **Week 1, Day 10:** PR approved

**Lessons:**
- Manual review critical (no automated check for spec weakening)
- Timeout fixable by simplification (not weakening)
- Reviewer expertise valuable (suggested correct fix)

---

## Related Guides

- [CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md](CI_CD_PIPELINE_COMPREHENSIVE_GUIDE.md) — CI infrastructure
- [LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md](LEAN_PERFORMANCE_OPTIMIZATION_GUIDE.md) — Fixing performance regressions
- [VERIFICATION_METRICS_DASHBOARD_GUIDE.md](VERIFICATION_METRICS_DASHBOARD_GUIDE.md) — Metrics framework
- [CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md](CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §10 — Reproducibility

---

**Document Status:** v1.0 (2026-04-22)  
**Maintainer:** Verification team  
**Last Updated:** 2026-04-22  
**Next Review:** 2026-07-22 (quarterly)

**Key Takeaway:** Prevention > Detection > Response. Invest in pre-commit hooks and architecture patterns to prevent regressions. Automate detection via CI. Have clear response procedures for when regressions slip through.
