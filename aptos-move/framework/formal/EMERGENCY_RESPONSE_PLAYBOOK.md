# Emergency Response Playbook

**Purpose:** Rapid response procedures for critical failures in Confidential Assets formal verification or deployment.

**Audience:** On-call engineers, formal verification team leads, security incident responders.

**Scope:** Security-critical failures, verification compromises, critical bugs in production.

---

## Table of Contents

1. [Severity Classification](#1-severity-classification)
2. [SEV-1: Security Compromise](#2-sev-1-security-compromise)
3. [SEV-2: Verification Integrity Failure](#3-sev-2-verification-integrity-failure)
4. [SEV-3: Critical Bug in Production](#4-sev-3-critical-bug-in-production)
5. [SEV-4: Major Verification Breakage](#5-sev-4-major-verification-breakage)
6. [Communication Protocols](#6-communication-protocols)
7. [Post-Incident Review](#7-post-incident-review)
8. [Contact Directory](#8-contact-directory)

---

## 1. Severity Classification

| Severity | Description | Response Time | Escalation |
|----------|-------------|---------------|------------|
| **SEV-1** | Security compromise, cryptographic vulnerability, production exploit | Immediate | Security team + Exec |
| **SEV-2** | Verification integrity failure (false positive), axiom breach | 1 hour | Formal verification lead + Security team |
| **SEV-3** | Critical bug in production affecting funds/privacy, no exploit yet | 4 hours | Engineering lead + Security team |
| **SEV-4** | Major verification breakage (main branch red), CI completely broken | 8 hours | Formal verification lead |

**How to classify:**
- **Does it affect production?** → SEV-1/SEV-3
- **Does it affect verification integrity?** → SEV-2
- **Does it block all development?** → SEV-4
- **None of the above?** → Not an emergency, use normal processes

---

## 2. SEV-1: Security Compromise

### 2.1 Definition

Any of the following:
- **Cryptographic vulnerability:** Sigma protocol broken, Bulletproofs soundness violated, discrete log compromised
- **Production exploit:** Funds stolen, privacy breached, freeze bypass exploited
- **Verification bypass:** Verified code doesn't match deployed bytecode
- **Axiom invalidated:** Trusted cryptographic assumption proven false

### 2.2 Immediate Actions (0-15 minutes)

**Step 1: Declare incident (within 5 minutes)**

```bash
# Post in #incidents Slack channel (or equivalent)
Subject: [SEV-1] CA Security Incident - <brief description>

Incident type: [Crypto compromise | Production exploit | Verification bypass | Axiom invalidated]
Affected operations: [register | withdraw | transfer | normalize | rotate | ALL]
Deployment: [Testnet | Mainnet | Both]
On-call: @<your-name>
Status: Investigating

DO NOT MERGE any CA PRs until further notice.
```

**Step 2: Notify security team (within 5 minutes)**

- Security team lead: [Contact from §8]
- Formal verification lead: [Contact from §8]
- Engineering VP: [Contact from §8]

**Step 3: Collect evidence (within 15 minutes)**

```bash
# Capture current state
./audit/verify-ca.sh --mode comprehensive > incident-verification-$(date +%Y%m%d%H%M).log

# Dump axiom count
./scripts/check_axioms.sh > incident-axioms-$(date +%Y%m%d%H%M).txt

# Check deployed bytecode hash
movement account show --address 0x<CA_ADDRESS> --query resources | jq '.code_hash'

# Save to incident folder
mkdir -p incidents/sev1-$(date +%Y%m%d%H%M)
mv incident-* incidents/sev1-$(date +%Y%m%d%H%M)/
```

**Step 4: Immediate containment (within 15 minutes)**

- [ ] Freeze CA contract if possible (coordinate with ops team)
- [ ] Disable new registrations/transfers (if exploit vector identified)
- [ ] Alert users via status page (if public-facing)

### 2.3 Investigation (15 min - 4 hours)

**Step 1: Determine root cause**

**If cryptographic compromise:**
- [ ] Which crypto assumption was violated? (Sigma, Bulletproofs, Ristretto DLog, SHA-2/3)
- [ ] Is it theoretical or practical exploit?
- [ ] What operations are affected?
- [ ] Can we reproduce locally?

**If production exploit:**
- [ ] What operation was exploited?
- [ ] What funds/data were affected?
- [ ] Is the exploit still possible?
- [ ] Was verification bypassed or did verification have a gap?

**If verification bypass:**
- [ ] Does deployed bytecode match source?
- [ ] Was there a compilation issue?
- [ ] Was deployment process compromised?

**Step 2: Determine if verification was at fault**

```bash
# Check if the exploit scenario was covered by verification
grep -r "<exploit pattern>" audit/CLAIMS.md
grep -r "<exploit pattern>" audit/COMPOSITION_CLAIMS.md

# Check if axioms were relevant
./scripts/check_axioms.sh --verbose | grep "<affected_operation>"

# Check if MSL specs covered the failure mode
movement move prove --filter <affected_operation> --verbose
```

**Questions to answer:**
- Did verification claim to prove the property that was violated? (If yes → SEV-2, verification integrity failure)
- Was the property outside verification scope? (If yes → not a verification failure, but need to expand scope)
- Was there a soundness bug in Lean/Move Prover? (If yes → critical, escalate to tool vendors)

### 2.4 Mitigation (4 hours - 24 hours)

**Option 1: Deploy hotfix**

```bash
# If fix is straightforward
git checkout -b emergency/sev1-hotfix

# Apply minimal fix to Move source
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/<affected_file>.move

# Update verification
# - MSL specs
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/<affected_file>.spec.move
movement move prove --filter <affected_operation>

# - Lean proofs (if bytecode changed)
vim lean/MovementFormal/Experimental/ConfidentialAsset/<OPERATION>/EvalEquiv.lean
lake build MovementFormal

# - Difftest
cargo test test_<affected_operation>_<exploit_scenario>

# Verify fix closes exploit
./test_exploit_repro.sh  # Should fail after fix

# Fast-track review (security team + FV lead sign-off)
git push origin emergency/sev1-hotfix
# Create PR with [SEV-1 HOTFIX] prefix
```

**Option 2: Disable affected operations**

```move
// If fix is non-obvious, disable temporarily
public entry fun withdraw_to(...) {
    abort ETEMPORARILY_DISABLED;  // Emergency disable
}
```

**Option 3: Rollback deployment**

```bash
# If hotfix not possible in <24 hours
# Coordinate with ops to rollback to last-known-good version
```

### 2.5 Communication (ongoing)

**Hourly updates (first 8 hours):**
```
[SEV-1 UPDATE - HH:MM UTC]

Status: [Investigating | Mitigating | Resolved]
Root cause: <brief summary>
Impact: <number of users/funds affected>
Mitigation: <what actions taken>
Next steps: <what's being worked on>
ETA: <when expect resolution>
```

**Resolution announcement (when fixed):**
```
[SEV-1 RESOLVED - HH:MM UTC]

Incident: <brief description>
Root cause: <final determination>
Fix: <what was deployed>
Verification updates: <what verification improvements landed>
Post-mortem: <link to full writeup>

All-clear: CA PRs may resume after verification review.
```

---

## 3. SEV-2: Verification Integrity Failure

### 3.1 Definition

Verification claimed to prove a property that turned out to be false.

**Examples:**
- "Transfer preserves balance" verified, but balance loss occurred
- "Freeze prevents withdrawal" verified, but frozen withdrawal succeeded
- Lean proof has `sorry` that was missed in review
- MSL spec has `pragma verify = false` on critical property
- False axiom introduced and used in composition proof

**NOT a SEV-2:**
- Property was never claimed to be verified (verification scope gap)
- Verification correct, but deployment process bypassed it

### 3.2 Immediate Actions (0-1 hour)

**Step 1: Confirm false positive (within 30 minutes)**

```bash
# Re-run verification on alleged failing case
./audit/verify-ca.sh --op <affected_operation>

# Check for sorry/axioms
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/<OPERATION>/
./scripts/check_axioms.sh --verbose | grep <OPERATION>

# Check MSL pragmas
grep -r "pragma verify = false" aptos-move/framework/aptos-experimental/sources/confidential_asset/
```

**Step 2: Isolate the gap (within 1 hour)**

Determine which stack failed:
- **Lean:** Bytecode verification claimed property, but bytecode doesn't satisfy it
- **MSL:** Source-level spec claimed property, but source doesn't satisfy it
- **Difftest:** Test corpus missed the failing scenario
- **Composition:** Individual stacks correct, but composition claim was wrong

**Step 3: Declare incident**

```bash
# Post in #formal-verification Slack
Subject: [SEV-2] Verification Integrity Failure - <affected property>

Property claimed: <what we said we verified>
Actual behavior: <what actually happened>
Affected operation: <operation>
Stack at fault: [Lean | MSL | Difftest | Composition]
Status: Investigating root cause

STOP ALL VERIFICATION WORK until investigation complete.
```

### 3.3 Investigation (1-4 hours)

**Step 1: Find the error**

**If Lean proof at fault:**
```bash
# Check proof for sorry
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/<OPERATION>/

# Check for axioms used
lake build MovementFormal.Experimental.ConfidentialAsset.<OPERATION>.Phase6Composition
# Then in Lean REPL:
#print axioms <failed_theorem>

# Check for logical error
# Manual review of proof with fresh eyes (get second opinion)
```

**If MSL spec at fault:**
```bash
# Check for pragma escapes
grep "pragma verify = false" <spec_file>
grep "pragma aborts_if_is_partial" <spec_file>

# Check if spec actually covers the property
movement move prove --filter <operation> --verbose
# Review generated VCs — does any VC actually encode the failed property?
```

**If composition claim at fault:**
```bash
# Check COMPOSITION_CLAIMS.md
vim audit/COMPOSITION_CLAIMS.md
# Find claim for affected operation

# Check if claim accurately reflects what each stack proved
# E.g., MSL proved "balance preserved on non-abort paths"
#       But claim said "balance always preserved" (missing abort case)
```

**Step 2: Classify the error**

| Error Type | Description | Fix Time | Severity |
|------------|-------------|----------|----------|
| **Admitted sorry** | `sorry` was left in proof, missed in review | 1-2 days | High (process failure) |
| **False axiom** | Axiom used in proof is actually false | 1-4 weeks | Critical (soundness bug) |
| **Spec escape** | Pragma disabled verification on critical property | 1 day | High (review failure) |
| **Composition error** | Individual stacks correct, but claim overstated | 1 day | Medium (documentation issue) |
| **Logic error** | Proof has subtle mistake | 1-4 weeks | Critical (verification bug) |

### 3.4 Remediation (4 hours - 4 weeks)

**Immediate (within 4 hours):**
- [ ] Update `audit/CLAIMS.md` to remove false claim
- [ ] Add warning to docs that property is NOT verified
- [ ] Update `audit/TRUST_BOUNDARIES.md` to document the gap
- [ ] File GitHub issue to track fix

**Short-term (within 1 week):**
- [ ] Fix the proof/spec
- [ ] Add difftest test case for the missed scenario
- [ ] Update CI to catch this type of error in the future
- [ ] Review all other proofs for similar pattern

**Long-term (within 1 month):**
- [ ] Improve code review checklist to catch this
- [ ] Add automated check (e.g., CI job to grep for `sorry`)
- [ ] Consider additional verification (external audit if soundness bug)
- [ ] Update onboarding docs to prevent recurrence

### 3.5 Process Improvements

**After SEV-2, mandate:**
- [ ] Dual verification (two people independently verify same property)
- [ ] External audit of affected component
- [ ] Automated `sorry` detection in CI (if not already present)
- [ ] Quarterly axiom review (if axiom was involved)

---

## 4. SEV-3: Critical Bug in Production

### 4.1 Definition

Critical bug found in production CA code that affects funds or privacy, but not yet exploited.

**Examples:**
- Balance calculation bug (funds at risk)
- Freeze bypass (security control broken)
- Privacy leak (encrypted balance exposed)
- Abort code mismatch (wrong error handling)

**Difference from SEV-1:** No active exploit, window of opportunity to patch before exploit.

### 4.2 Immediate Actions (0-4 hours)

**Step 1: Assess blast radius (within 1 hour)**

```bash
# How many users affected?
# How much value at risk?
# Is the bug exploitable by any user or only privileged accounts?
# How long has the bug been in production?
```

**Step 2: Determine if verification should have caught it (within 2 hours)**

```bash
# Check if property was claimed to be verified
grep -r "<bug description>" audit/CLAIMS.md

# If verified → SEV-2 (upgrade severity)
# If not verified → Continue as SEV-3
```

**Step 3: Develop and test fix (within 4 hours)**

```bash
git checkout -b hotfix/sev3-<bug-description>

# Apply fix to Move source
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/<affected_file>.move

# Update verification to cover the bug
# MSL spec
spec <affected_function> {
    ensures <property that was violated>;  // Add missing property
}

# Lean proof (if needed)
# Difftest (add test case for bug scenario)
cargo test test_<bug>_prevented

# Verify fix
./audit/verify-ca.sh --op <affected_operation>
```

**Step 4: Deploy hotfix (within 8 hours)**

- Fast-track PR review (engineering + formal verification leads)
- Deploy to testnet first
- Verify fix on testnet (run exploit attempt, should fail)
- Deploy to mainnet

### 4.3 Post-Fix Analysis (8-24 hours)

**Questions to answer:**
- Why didn't verification catch this?
- Was the property outside scope?
- Was there a verification gap?
- Should we expand verification scope?
- What process failed?

**Deliverable:** Incident report with:
- Root cause
- Why verification missed it
- Plan to expand verification scope
- Process improvements

---

## 5. SEV-4: Major Verification Breakage

### 5.1 Definition

Main branch verification completely broken, blocking all development.

**Examples:**
- Lean toolchain update broke mathlib
- Movement CLI update broke Move Prover
- All three stacks red simultaneously
- CI infrastructure down

**Difference from SEV-1/2/3:** Doesn't affect production, "only" blocks development.

### 5.2 Immediate Actions (0-8 hours)

**Step 1: Rollback to last-known-good (within 1 hour)**

```bash
# Find last green commit
git log --oneline --all --decorate --graph | head -20

# Rollback toolchains
git checkout <last-green-commit> -- lean-toolchain rust-toolchain movement.toml
git commit -m "Rollback toolchains to last-known-good"
git push origin movement

# Verify CI goes green
# If not green → deeper issue, escalate
```

**Step 2: Identify breaking change (within 4 hours)**

```bash
# Bisect to find breaking commit
git bisect start
git bisect bad HEAD
git bisect good <last-known-good-commit>

# For each commit, check:
./audit/verify-ca.sh --mode quick
# Respond with: git bisect good | git bisect bad

git bisect reset  # After finding culprit
```

**Step 3: Fix or disable breaking change (within 8 hours)**

**Option 1: Fix upstream issue**
- File issue with Lean team / Movement team / Rust team
- Apply workaround patch locally

**Option 2: Pin to last-good version**
- Update `lean-toolchain` / `rust-toolchain` / `movement.toml`
- Commit pinned versions
- Plan to re-enable when upstream fixed

**Option 3: Disable affected component temporarily**
```bash
# E.g., if Transfer proof is broken
# In CI workflow:
# matrix:
#   op: [register, withdraw, normalization, rotation]  # Skip transfer
```

### 5.3 Communication (ongoing)

**Hourly updates in #engineering:**
```
[SEV-4 UPDATE]
Status: <investigating | fixing | resolved>
Cause: <brief description>
Impact: <which operations broken>
ETA: <when expect fix>
Workaround: <how to work around locally>
```

---

## 6. Communication Protocols

### 6.1 Incident Channels

| Severity | Primary Channel | Escalation Channel |
|----------|-----------------|-------------------|
| SEV-1 | #incidents | @security-team, @exec-team |
| SEV-2 | #formal-verification | @fv-lead, @security-team |
| SEV-3 | #engineering | @eng-lead, @security-team |
| SEV-4 | #formal-verification | @fv-lead |

### 6.2 Update Cadence

| Severity | Update Frequency | Update Until |
|----------|------------------|--------------|
| SEV-1 | Every hour (first 8h), then every 4h | Resolved |
| SEV-2 | Every 4 hours | Root cause identified |
| SEV-3 | Every 8 hours | Fix deployed |
| SEV-4 | Daily | Fix merged to main |

### 6.3 Update Template

```
[SEV-<N> UPDATE - YYYY-MM-DD HH:MM UTC]

**Status:** [Investigating | Mitigating | Resolved]

**Summary:** <1-2 sentences>

**Root Cause:** <brief description or "still investigating">

**Impact:**
- Affected operations: <list>
- Affected users: <number or "TBD">
- Funds at risk: <amount or "none">

**Actions Taken:**
1. <action 1>
2. <action 2>

**Next Steps:**
1. <next action 1>
2. <next action 2>

**ETA to Resolution:** <best estimate>

**Blockers:** <anything preventing faster resolution>
```

---

## 7. Post-Incident Review

### 7.1 Timeline (within 1 week of resolution)

**Required attendees:**
- Incident commander (person who declared incident)
- Formal verification lead
- Engineering lead (if production affected)
- Security lead (if SEV-1/SEV-2/SEV-3)

**Agenda:**
1. Timeline review (what happened when)
2. Root cause analysis (why it happened)
3. Lessons learned (what went well, what didn't)
4. Action items (how to prevent recurrence)

### 7.2 Post-Mortem Template

```markdown
# Post-Mortem: <Incident Name>

**Date:** YYYY-MM-DD
**Severity:** SEV-<N>
**Incident Commander:** <Name>
**Duration:** <HH:MM from detection to resolution>

## Summary

<2-3 paragraph summary of incident>

## Timeline (all times UTC)

| Time | Event |
|------|-------|
| HH:MM | Incident detected |
| HH:MM | SEV-<N> declared |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed |
| HH:MM | Incident resolved |

## Root Cause

<Detailed analysis of what caused the incident>

**5 Whys:**
1. Why did X happen? Because Y.
2. Why did Y happen? Because Z.
3. Why did Z happen? Because ...
4. ...
5. Root cause: ...

## Impact

- **Users affected:** <number>
- **Funds affected:** <amount>
- **Downtime:** <duration>
- **Verification claims affected:** <list>

## What Went Well

- <thing 1>
- <thing 2>

## What Went Poorly

- <thing 1>
- <thing 2>

## Action Items

| Action | Owner | Deadline | Status |
|--------|-------|----------|--------|
| <action 1> | <name> | YYYY-MM-DD | Open |
| <action 2> | <name> | YYYY-MM-DD | Open |

## Lessons Learned

<Key takeaways, process improvements, system changes>
```

---

## 8. Contact Directory

**Formal Verification Team:**
- FV Lead: <Name> — Slack: @fv-lead, Phone: +1-XXX-XXX-XXXX
- Lean Expert: <Name> — Slack: @lean-expert
- MSL Expert: <Name> — Slack: @msl-expert

**Security Team:**
- Security Lead: <Name> — Slack: @security-lead, Phone: +1-XXX-XXX-XXXX
- Cryptography: <Name> — Slack: @crypto-expert

**Engineering:**
- Engineering VP: <Name> — Slack: @eng-vp, Phone: +1-XXX-XXX-XXXX
- On-call rotation: PagerDuty schedule link

**External:**
- Lean Team (Zulip): https://leanprover.zulipchat.com/
- Movement Team (Discord/Slack): <link>

**Escalation Path:**
```
SEV-1: Immediate → Security Lead → Engineering VP → Exec Team
SEV-2: 1 hour → FV Lead → Security Lead → Engineering VP
SEV-3: 4 hours → Engineering Lead → Security Lead
SEV-4: 8 hours → FV Lead → Engineering Lead
```

---

## Appendix A: Pre-Incident Preparation

**Every quarter:**
- [ ] Review and update this playbook
- [ ] Drill SEV-1 scenario (tabletop exercise)
- [ ] Verify contact directory up to date
- [ ] Test rollback procedures
- [ ] Review axiom inventory (could any axiom be invalidated?)

**Every release:**
- [ ] Verify `verify-ca.sh` runs green
- [ ] Backup current verification state (axiom count, build times)
- [ ] Document what's new in this release (for incident diagnosis)

---

## Appendix B: Quick Reference Commands

**Declare incident:**
```bash
./scripts/declare_incident.sh \
  --severity [1|2|3|4] \
  --type [crypto|exploit|verification|infra] \
  --affected <operation> \
  --description "<brief description>"
```

**Capture evidence:**
```bash
mkdir -p incidents/sev<N>-$(date +%Y%m%d%H%M)
./audit/verify-ca.sh --mode comprehensive > incidents/.../verification.log
./scripts/check_axioms.sh > incidents/.../axioms.txt
git log -10 > incidents/.../recent-commits.txt
```

**Rollback:**
```bash
git checkout <last-green-commit> -- lean-toolchain rust-toolchain movement.toml
git commit -m "Emergency rollback: <reason>"
git push origin movement
```

**Fast-track hotfix:**
```bash
git checkout -b emergency/sev<N>-<description>
# ... apply fix ...
git push origin emergency/sev<N>-<description>
# Create PR with prefix: [SEV-<N> HOTFIX]
```

---

**END OF PLAYBOOK**

**Last Updated:** 2026-04-22
**Next Review:** 2026-07-22 (Quarterly)

**Questions?** Contact FV Lead or Security Lead immediately for any emergency.
