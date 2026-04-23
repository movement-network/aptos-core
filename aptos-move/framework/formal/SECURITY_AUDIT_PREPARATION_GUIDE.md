# Security Audit Preparation Guide

**Purpose:** Complete guide for preparing Confidential Assets formal verification for external security audits.

**Audience:** Security team leads, formal verification team leads, external auditors.

**Scope:** Audit package preparation, auditor onboarding, audit execution support, post-audit verification updates.

---

## Table of Contents

1. [Audit Objectives](#1-audit-objectives)
2. [Pre-Audit Preparation (4-6 weeks)](#2-pre-audit-preparation-4-6-weeks)
3. [Audit Package Assembly](#3-audit-package-assembly)
4. [Auditor Onboarding](#4-auditor-onboarding)
5. [During the Audit](#5-during-the-audit)
6. [Post-Audit Process](#6-post-audit-process)
7. [Audit Artifacts](#7-audit-artifacts)
8. [Common Auditor Questions](#8-common-auditor-questions)

---

## 1. Audit Objectives

### 1.1 What We're Asking Auditors to Verify

**Primary objective:** Confirm that Confidential Assets formal verification claims are accurate and that verification is sound.

**Specific questions for auditors:**
1. **Coverage:** Do the verified properties cover the security-critical behavior?
2. **Soundness:** Are the proofs/specs correct (no hidden axioms, no false positives)?
3. **Completeness:** Are there verification gaps that need to be closed?
4. **Trust boundaries:** Are all unproved assumptions documented and reasonable?
5. **Reproducibility:** Can the verification be reproduced independently?

### 1.2 Out of Scope

**NOT asking auditors to:**
- Re-prove the theorems (trust Lean kernel / Move Prover soundness)
- Review cryptographic primitives (Ristretto, Bulletproofs — separate crypto audit)
- Review upstream frameworks (FA, object, signer — upstream responsibility)
- Find bugs in Move VM (separate VM audit)

**Boundary:** Auditors verify that our claims match our proofs, and that proofs are sound. They don't verify the tools we used (Lean, Z3, Move VM) — those have their own trust bases.

### 1.3 Success Criteria

**Audit is successful if:**
- [ ] All claims in `CLAIMS.md` confirmed accurate
- [ ] All trust boundaries in `TRUST_BOUNDARIES.md` confirmed reasonable
- [ ] No false positives found (verified property actually holds)
- [ ] No critical verification gaps found
- [ ] Verification reproducible by auditor from scratch
- [ ] Auditor report confirms "CA formal verification is sound for claimed properties"

---

## 2. Pre-Audit Preparation (4-6 weeks)

### 2.1 Verification Freeze (6 weeks before audit)

**Purpose:** Ensure audit targets stable codebase.

**Actions:**
- [ ] **Week -6:** Announce verification freeze in #engineering
- [ ] No new operations added during freeze
- [ ] Only critical bug fixes allowed (with FV lead approval)
- [ ] All verification stacks green on main branch
- [ ] Performance within budget (no regressions)

**Freeze announcement template:**
```
[VERIFICATION FREEZE - Audit Preparation]

Effective: YYYY-MM-DD
Duration: 6 weeks (until audit completion)

During freeze:
❌ No new CA operations
❌ No verification refactoring
❌ No axiom changes (unless critical)
✅ Critical bug fixes only (with FV lead approval)
✅ Documentation improvements
✅ Test coverage improvements (difftest only, no new properties)

Reason: External security audit starting <date>
Contact: @fv-lead for exceptions
```

### 2.2 Verification Health Check (5 weeks before)

**Run comprehensive health check:**

```bash
# 1. All three stacks green
./scripts/run_verification_suite.sh --mode comprehensive
# Must complete in <15 min, all checks green

# 2. Axiom count at baseline
./scripts/check_axioms.sh
diff audit/axiom-baseline.txt <(./scripts/check_axioms.sh --output)
# Must show no diff (or only documented axioms)

# 3. No sorry, no pragma verify=false
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/
grep -r "pragma verify = false" aptos-move/framework/aptos-experimental/sources/confidential_asset/
# Both should return empty (or only documented escapes)

# 4. Trust boundaries reconciled
./scripts/reconcile_trust_boundaries.sh
# Must pass

# 5. Cross-stack consistency
./scripts/reconcile_abort_codes.sh
./scripts/check_state_transition_consistency.sh
# Both must pass

# 6. Performance within budget
./scripts/benchmark_verification.sh
# All operations <budget (Lean <180s per file, MSL <60s per op, difftest <5s per test)

# 7. Documentation complete
# Check all docs exist and are up to date:
# - CLAIMS.md
# - TRUST_BOUNDARIES.md
# - AXIOM_INVENTORY.md
# - COMPOSITION_CLAIMS.md
# - All coverage docs
```

**If any check fails:** Fix before proceeding. Audit cannot start with failing checks.

### 2.3 Documentation Review (4 weeks before)

**Review all audit documentation for accuracy:**

**CLAIMS.md:**
- [ ] Every public CA function has an entry
- [ ] Every claim has exact file:line pointers
- [ ] Every claim has working verify command
- [ ] Claims match actual proofs (spot-check 10 random claims)

**TRUST_BOUNDARIES.md:**
- [ ] All axioms listed (reconcile with `check_axioms.sh` output)
- [ ] All `pragma opaque` listed (reconcile with grep output)
- [ ] All crypto assumptions documented with citations
- [ ] Trust boundary count matches reality

**AXIOM_INVENTORY.md:**
- [ ] All axioms classified (A/B/C/D)
- [ ] All axioms have justification
- [ ] All temporary axioms have elimination plan
- [ ] No undocumented axioms

**COMPOSITION_CLAIMS.md:**
- [ ] End-to-end claims for all 5 operations
- [ ] Claims reference all three stacks correctly
- [ ] Composition logic explained

**Coverage docs:**
- [ ] `MSL_SPEC_COVERAGE.md` lists all specs
- [ ] `BYTECODE_VERIFICATION_COVERAGE.md` lists all Lean proofs
- [ ] `DIFFTEST_COVERAGE.md` lists corpus size (≥95% coverage)

### 2.4 Docker Image Preparation (4 weeks before)

**Build and test reproducibility image:**

```bash
cd audit

# Build Docker image
docker build -t ca-verification:audit -f Dockerfile .

# Test image (should run full verification from scratch)
docker run --rm ca-verification:audit /audit/verify-ca.sh

# Should complete in <45 min, all checks green
```

**If Docker build fails or verification fails in container:**
- Fix until Docker verification green
- Publish image to registry
- Document image tag in `audit/DOCKER_REPRODUCIBILITY_GUIDE.md`

### 2.5 Smoke Test with Fresh Contributor (3 weeks before)

**Purpose:** Validate auditor onboarding process.

**Process:**
1. Find engineer unfamiliar with CA verification (ideally new hire or intern)
2. Give them only `audit/AUDITOR_GUIDE.md`
3. Ask them to verify one operation (e.g., Register) from scratch
4. Time how long it takes
5. Note any confusion, missing documentation, broken links

**Success criteria:**
- [ ] Fresh contributor can verify one operation in <1 hour
- [ ] No missing documentation
- [ ] No broken links
- [ ] All commands work as documented

**If smoke test fails:**
- Fix all documentation gaps
- Re-run smoke test until it passes

### 2.6 Auditor Selection (3 weeks before)

**Ideal auditor profile:**
- **Must have:**
  - Formal verification experience (Coq, Isabelle, Lean, or similar)
  - Cryptographic protocols knowledge (sigma protocols, zero-knowledge proofs)
  - Smart contract security experience
- **Nice to have:**
  - Prior Lean 4 experience
  - Move language familiarity
  - Prior blockchain audit experience

**Avoid:**
- Auditors with only manual code review experience (no formal methods background)
- Auditors unfamiliar with theorem provers
- Auditors without crypto background (won't understand sigma protocol axioms)

**Pre-audit call (2 weeks before):**
- Share `audit/AUDITOR_GUIDE.md`
- Demo `verify-ca.sh` end-to-end
- Answer preliminary questions
- Set expectations (audit duration: 2-4 weeks, deliverable: written report)

---

## 3. Audit Package Assembly

### 3.1 Package Contents

**Core audit package (everything in `audit/` directory):**

```
audit/
  README.md                           — Audit package overview, where to start
  AUDITOR_GUIDE.md                    — Step-by-step audit workflow
  
  ## What's Verified
  CLAIMS.md                           — All verified properties
  COMPOSITION_CLAIMS.md               — End-to-end composition claims
  TRUST_BOUNDARIES.md                 — All assumptions (axioms, pragmas, natives)
  AXIOM_INVENTORY.md                  — Detailed axiom catalog
  
  ## Coverage
  MSL_SPEC_COVERAGE.md                — MSL spec coverage report
  BYTECODE_VERIFICATION_COVERAGE.md   — Lean bytecode coverage report
  DIFFTEST_COVERAGE.md                — Difftest corpus coverage report
  TEST_MATRIX.md                      — Test case matrix
  
  ## Execution
  verify-ca.sh                        — Single-command reproducer
  Dockerfile                          — Reproducible build environment
  DOCKER_REPRODUCIBILITY_GUIDE.md     — Docker usage instructions
  toolchain.lock                      — Pinned tool versions
  
  ## Supporting
  axiom-baseline.txt                  — Expected axiom list
  performance-baseline.json           — Performance baseline
  UPSTREAM_FA_SPEC_AUDIT.md           — Upstream dependency review
  PROOF_FLOW.md                       — How verification stacks connect
  
  ## Guides (for reference)
  <all comprehensive guides>          — For deep-dive questions
```

**Supplementary (repo-wide):**
```
aptos-move/framework/aptos-experimental/sources/confidential_asset/
  *.move                              — Move source code
  *.spec.move                         — MSL specs

lean/MovementFormal/Experimental/ConfidentialAsset/
  */EvalEquiv.lean                    — Lean bytecode proofs
  */Phase6Composition.lean            — End-to-end theorems

difftest/corpus/
  confidential_asset_e2e.rs           — Difftest test corpus

.github/workflows/
  *ca*.yaml                           — CI workflows
```

### 3.2 Package Snapshot

**Create immutable snapshot for audit:**

```bash
# Tag audit snapshot
git tag audit-snapshot-$(date +%Y%m%d)
git push origin audit-snapshot-$(date +%Y%m%d)

# Create tarball
git archive --format=tar.gz --prefix=ca-audit/ audit-snapshot-$(date +%Y%m%d) > ca-audit-snapshot.tar.gz

# SHA256 hash for integrity
shasum -a 256 ca-audit-snapshot.tar.gz > ca-audit-snapshot.tar.gz.sha256

# Share with auditor
# - Upload to secure file share
# - Include SHA256 in email
```

### 3.3 Auditor Credentials

**Grant auditor read-only access:**
- GitHub repo: read-only collaborator
- CI logs: read-only access (if needed)
- Slack #formal-verification: guest access (for questions)

**Do NOT grant:**
- Write access to repo
- Merge permissions
- CI trigger permissions

---

## 4. Auditor Onboarding

### 4.1 Onboarding Call (Week 0)

**Agenda (1 hour):**
1. **Introduction (10 min)**
   - CA overview: what it does, why formal verification matters
   - Audit objectives and scope
   - Expected timeline (2-4 weeks)

2. **Audit package walkthrough (20 min)**
   - Start with `audit/README.md`
   - Show `AUDITOR_GUIDE.md` workflow
   - Demo `verify-ca.sh --op register` end-to-end

3. **Tool setup (20 min)**
   - Docker approach (recommended for auditors)
   - Local setup (if auditor prefers)
   - Q&A on tool versions, dependencies

4. **Communication (10 min)**
   - Slack #formal-verification for questions
   - Weekly sync meetings (30 min each)
   - Issue tracking: GitHub issues for findings

### 4.2 Week 1 Goals for Auditor

**Suggested milestones:**
- [ ] Reproduce full verification (`verify-ca.sh`)
- [ ] Verify one operation from scratch (Register recommended)
- [ ] Read all core audit docs (CLAIMS, TRUST_BOUNDARIES, AXIOM_INVENTORY)
- [ ] Ask clarifying questions
- [ ] Identify any documentation gaps

### 4.3 Supporting the Auditor

**Assign liaison (formal verification team member) to:**
- Answer technical questions (response time: <4 hours during business hours)
- Clarify documentation (update docs in real-time if ambiguous)
- Reproduce any issues auditor encounters
- Weekly sync meeting with auditor

**Communication protocol:**
- **Urgent questions:** Slack DM to liaison
- **General questions:** Post in #formal-verification
- **Findings:** Create GitHub issue with label `audit-finding`

---

## 5. During the Audit

### 5.1 Weekly Sync Meetings

**Schedule:** Every Monday, 30 min

**Agenda:**
1. **Progress update (5 min)**
   - Which operations reviewed so far
   - How many claims verified
   - Any blockers

2. **Findings review (15 min)**
   - Any issues found since last week
   - Severity classification
   - Action items

3. **Next week plan (5 min)**
   - Which operations to review next
   - Any deep-dive areas
   - Any needed clarifications

4. **Q&A (5 min)**
   - Open floor for questions

### 5.2 Handling Findings

**Finding severity classification:**

| Severity | Description | Response Time | Example |
|----------|-------------|---------------|---------|
| **Critical** | Soundness bug, false positive | Immediate | Verified property doesn't actually hold |
| **High** | Major verification gap | 24 hours | Security-critical property not covered |
| **Medium** | Documentation inaccuracy, minor gap | 1 week | Claim doesn't match proof exactly |
| **Low** | Typo, broken link, process improvement | 2 weeks | Broken link in docs, suggested process change |

**Response process:**

**For Critical findings:**
1. Liaison escalates to FV lead immediately
2. FV lead convenes emergency meeting (within 2 hours)
3. Determine if it's true critical (soundness bug) or misunderstanding
4. If soundness bug: follow `EMERGENCY_RESPONSE_PLAYBOOK.md` SEV-2
5. If misunderstanding: clarify and update docs

**For High/Medium findings:**
1. Liaison creates GitHub issue with finding details
2. FV team triages and assigns
3. Fix applied within SLA
4. Auditor notified when fixed

**For Low findings:**
1. Create GitHub issue, tag for next sprint
2. Fix when convenient

### 5.3 Progress Tracking

**Audit progress dashboard (update weekly):**

| Operation | Claims Reviewed | Trust Boundaries Checked | Reproducibility Verified | Status |
|-----------|-----------------|--------------------------|--------------------------|--------|
| Register | 5/5 | ✅ | ✅ | Complete |
| Withdraw | 3/4 | ✅ | ❌ | In Progress |
| Transfer | 0/6 | ❌ | ❌ | Not Started |
| Normalize | 0/3 | ❌ | ❌ | Not Started |
| Rotate | 0/3 | ❌ | ❌ | Not Started |

**Share with stakeholders weekly.**

---

## 6. Post-Audit Process

### 6.1 Audit Report Review (Within 1 week of completion)

**Audit report should include:**
- **Executive summary:** High-level findings, overall assessment
- **Methodology:** How auditor approached verification
- **Findings:** All issues found, severity-classified
- **Recommendations:** Process improvements, verification gaps to close
- **Conclusion:** "CA formal verification is sound for claimed properties" (or caveats)

**Review process:**
1. FV lead + security lead review report (within 2 days)
2. Address any misunderstandings (schedule call with auditor if needed)
3. Prioritize findings (critical → high → medium → low)
4. Create remediation plan with timelines

### 6.2 Remediation (2-4 weeks)

**For each finding:**

**Critical (within 1 week):**
```bash
# Fix soundness bug immediately
git checkout -b audit-fix/critical-<finding-id>

# Apply fix
# - Update proof/spec
# - Add test case for missed scenario
# - Verify fix closes gap

# Fast-track PR (no normal review wait)
git push origin audit-fix/critical-<finding-id>
# Merge immediately after FV lead + security lead sign-off
```

**High (within 2 weeks):**
- Fix verification gap
- Add missing property
- Update documentation

**Medium (within 4 weeks):**
- Fix documentation inaccuracies
- Update claims to match proofs exactly
- Clarify ambiguous trust boundaries

**Low (when convenient):**
- Fix typos
- Update process docs
- Add nice-to-have improvements

### 6.3 Re-Audit (If Critical Findings)

**If audit found critical soundness bugs:**
- Fix all critical findings
- Re-run full verification suite (must be green)
- Send updated audit package to auditor
- Auditor re-reviews fixes (1 week)
- Auditor issues addendum to report confirming fixes

**If only High/Medium/Low findings:**
- No re-audit needed
- Include remediation in audit report appendix

### 6.4 Public Disclosure

**Audit report publication:**
- [ ] Auditor approves final report
- [ ] All critical/high findings remediated (or accepted with documented risk)
- [ ] Publish report to public repo (`audit/AUDIT_REPORT_<AUDITOR>_<DATE>.pdf`)
- [ ] Announce in blog post / Twitter / documentation

**Report should NOT be published if:**
- Critical findings not remediated
- Auditor doesn't sign off on final version
- Legal review pending (if applicable)

---

## 7. Audit Artifacts

### 7.1 Auditor Report Template

**Suggested structure (provide to auditor):**

```markdown
# Confidential Assets Formal Verification Audit Report

**Auditor:** <Name / Firm>
**Date:** YYYY-MM-DD
**Version:** 1.0
**Scope:** Confidential Assets formal verification (Lean, MSL, Difftest)

## Executive Summary

<2-3 paragraph summary>

**Overall Assessment:** [Sound | Sound with caveats | Unsound]

**Key Findings:** <X> critical, <Y> high, <Z> medium, <W> low

**Recommendation:** [Approve | Approve with fixes | Reject]

## Scope

**In-scope:**
- Lean bytecode proofs (5 operations: Register, Withdraw, Transfer, Normalize, Rotate)
- MSL source-level specs (all public CA functions)
- Difftest corpus (87 tests)
- Trust boundaries (axioms, pragma opaque, natives)

**Out-of-scope:**
- Cryptographic primitives (Ristretto, Bulletproofs)
- Upstream frameworks (FA, object, signer)
- Move VM implementation

## Methodology

<How auditor approached verification>

1. Reproducibility: Verified all claims from `verify-ca.sh`
2. Coverage: Checked all properties in `CLAIMS.md` are verified
3. Soundness: Spot-checked 20% of proofs for correctness
4. Trust boundaries: Verified all axioms/pragmas in `TRUST_BOUNDARIES.md`
5. Cross-stack consistency: Checked abort codes, state transitions

## Findings

### Critical

<None found>

### High

**[H-1] Missing property: Transfer doesn't verify balance non-negativity**

**Description:** ...
**Impact:** ...
**Recommendation:** ...

### Medium

**[M-1] CLAIMS.md line 123 doesn't match actual proof**

**Description:** ...
**Impact:** ...
**Recommendation:** ...

### Low

**[L-1] Broken link in AUDITOR_GUIDE.md**

**Description:** ...
**Impact:** ...
**Recommendation:** ...

## Trust Boundary Review

**Axioms reviewed:** 23 total
- 12 group theory: Acceptable (standard EdDSA assumptions)
- 4 Ristretto: Acceptable (RFC 9496 cited)
- 5 Bulletproofs: Acceptable (external audit cited)
- 2 CA-specific: 1 temporary (acceptable), 1 permanent (acceptable)

**Pragma opaque reviewed:** 89 total
- All justified and documented

**Overall:** Trust boundaries are reasonable and well-documented.

## Reproducibility

**Docker image:** Verified from scratch in 42 minutes (within 45 min budget)

**Per-operation:** All operations verified in <3 min (within budget)

**Conclusion:** Verification is fully reproducible.

## Recommendations

1. Close H-1 finding (add missing property)
2. Fix documentation inaccuracies (M-1)
3. Consider expanding difftest corpus (nice-to-have)
4. Update onboarding docs (L-1)

## Conclusion

Confidential Assets formal verification is **sound** for the claimed properties, subject to the documented trust boundaries. The verification is comprehensive, well-documented, and reproducible.

Recommend approval after remediation of high-severity findings.

**Signature:** <Auditor name>
**Date:** YYYY-MM-DD
```

---

## 8. Common Auditor Questions

### 8.1 "How do I verify the Lean proofs are correct?"

**Answer:**
```
Lean proofs are checked by the Lean kernel (small trusted base, ~10K lines of C++).
You don't need to re-check them manually — the kernel does that.

Your job as auditor is to verify:
1. The theorem statement matches the claim (e.g., "transfer preserves balance sum")
2. The theorem conclusion isn't trivial (e.g., not just "true = true")
3. The axioms used are reasonable (check `#print axioms`)

To verify theorem statement:
```lean
#check transfer_is_formally_verified
-- Should show full type signature
```

To verify axioms:
```lean
#print axioms transfer_is_formally_verified
-- Should show only documented crypto axioms
```
```

### 8.2 "What if I find an axiom that's not documented?"

**Answer:**
```
That's a finding! Report it as High severity.

All axioms must be in `TRUST_BOUNDARIES.md` and `AXIOM_INVENTORY.md`.

Process:
1. Create GitHub issue: "Undocumented axiom: <name>"
2. Tag as `audit-finding` with severity `high`
3. FV team will either:
   a. Document it (if it's a crypto axiom that was missed)
   b. Eliminate it (if it shouldn't be an axiom)
```

### 8.3 "How do I know the Move Prover specs are strong enough?"

**Answer:**
```
Check that the `ensures` clauses cover the security-critical properties.

For balance preservation:
```move
spec withdraw_to_internal {
    ensures sum_balance(result.balance) == old(sum_balance(store.balance)) - amount;
}
```

If the property is claimed in `CLAIMS.md` but not in the spec, that's a gap (report as finding).

You can also check which VCs the prover generated:
```bash
movement move prove --filter withdraw_to_internal --verbose
# Shows all VCs — read them to confirm property is encoded
```
```

### 8.4 "What if verify-ca.sh fails for me?"

**Answer:**
```
This is a blocker — report immediately.

Verification must be reproducible.

Steps:
1. Capture full error output: `./audit/verify-ca.sh > verify-output.log 2>&1`
2. Share `verify-output.log` with liaison
3. If Docker: share Docker version, host OS
4. If local: share tool versions (lean --version, movement --version, rustc --version)

FV team will reproduce and fix within 4 hours.
```

### 8.5 "Are the difftest tests comprehensive?"

**Answer:**
```
Check `audit/DIFFTEST_COVERAGE.md`.

Current coverage: 87 tests, ~95% coverage (102 total meaningful scenarios).

Coverage is measured as:
(Tested Scenarios / Total Meaningful Scenarios) × 100%

Missing scenarios are documented in `DIFFTEST_CORPUS_EXPANSION_GUIDE.md`.

If you find a security-critical scenario not covered, report as High finding.
```

### 8.6 "How do the three stacks (Lean, MSL, Difftest) connect?"

**Answer:**
```
See `audit/PROOF_FLOW.md` for detailed diagram.

Summary:
- Lean proves: Bytecode ↔ Mathematical model (for crypto functions)
- MSL proves: Source code ↔ Spec (for state properties)
- Difftest proves: VM output matches both models (for concrete inputs)

Composition: All three agree on the same operations.

Cross-stack consistency checked by:
- `./scripts/reconcile_abort_codes.sh` (abort codes match)
- `./scripts/check_state_transition_consistency.sh` (state transitions match)
```

### 8.7 "What's the trust base?"

**Answer:**
```
See `TRUST_BOUNDARIES.md` §1 "Kernel / solver trust".

Three independent trust bases:
1. **Lean kernel** (for bytecode proofs)
   - ~10K lines of C++ (de Bruijn type theory)
   - Soundness: Lean has never had a soundness bug in 10+ years

2. **Boogie + Z3** (for MSL specs)
   - Boogie: intermediate verification language
   - Z3: SMT solver
   - Both widely used, well-tested

3. **Move VM** (ground truth)
   - VM implementation is trusted (separate audit)
   - Difftest pins VM output byte-for-byte

Plus crypto axioms (Ristretto DLog, Bulletproofs soundness, etc.) documented in `AXIOM_INVENTORY.md`.
```

---

## Appendix A: Audit Timeline

**Typical 4-week audit schedule:**

| Week | Auditor Activities | FV Team Activities |
|------|-------------------|-------------------|
| **Week 1** | Tool setup, reproduce verification, read docs | Answer questions, fix any doc gaps |
| **Week 2** | Review Register + Withdraw (2 operations) | Weekly sync, triage any findings |
| **Week 3** | Review Transfer + Normalize + Rotate (3 ops) | Weekly sync, triage findings |
| **Week 4** | Cross-stack consistency, trust boundaries, write report | Weekly sync, prepare for remediation |
| **Week 5-6** | Report delivery, Q&A on findings | Remediation (if needed) |

---

## Appendix B: Audit Budget

**Estimated effort:**

| Activity | Auditor Hours | FV Team Hours |
|----------|---------------|---------------|
| Pre-audit prep | 0 | 80 (6 weeks part-time) |
| Auditor onboarding | 4 | 4 |
| Verification reproduction | 8 | 2 (support) |
| Claim review (5 ops × 4 claims avg) | 40 | 4 (Q&A) |
| Trust boundary review | 8 | 2 |
| Cross-stack consistency | 4 | 2 |
| Report writing | 16 | 0 |
| **Total** | **80 hours** | **94 hours** |

**Cost estimate:**
- Auditor: 80 hours × $300/hour = $24,000
- FV team (internal): 94 hours × loaded cost

**Timeline:** 6 weeks prep + 4 weeks audit + 2 weeks remediation = **12 weeks total**

---

## Appendix C: Pre-Audit Checklist

**Complete this checklist before audit starts:**

**Verification:**
- [ ] All three stacks green on main branch
- [ ] `./scripts/run_verification_suite.sh --mode comprehensive` passes
- [ ] Axiom count at baseline (23 total, 0 new)
- [ ] No `sorry` in Lean files
- [ ] No `pragma verify = false` in MSL (unless documented)
- [ ] Trust boundaries reconciled
- [ ] Cross-stack consistency checks pass
- [ ] Performance within budget

**Documentation:**
- [ ] `CLAIMS.md` complete and accurate
- [ ] `TRUST_BOUNDARIES.md` complete and accurate
- [ ] `AXIOM_INVENTORY.md` complete and accurate
- [ ] `COMPOSITION_CLAIMS.md` complete
- [ ] All coverage docs up to date
- [ ] `AUDITOR_GUIDE.md` tested with fresh contributor
- [ ] All broken links fixed
- [ ] All code examples compile

**Reproducibility:**
- [ ] `verify-ca.sh` runs green from fresh clone
- [ ] Docker image builds and runs verification
- [ ] `toolchain.lock` pinned to exact versions
- [ ] Audit snapshot tagged and tarball created

**Process:**
- [ ] Verification freeze announced
- [ ] Auditor selected and onboarded
- [ ] Liaison assigned
- [ ] Weekly sync meetings scheduled
- [ ] Communication channels set up

---

**END OF GUIDE**

**Last Updated:** 2026-04-22

**Questions?** Contact FV Lead or Security Lead for audit coordination.
