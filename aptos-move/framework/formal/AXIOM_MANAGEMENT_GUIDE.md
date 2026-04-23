# Axiom Management Guide

**Last updated:** 2026-04-22

Complete guide to managing axioms throughout the CA formal verification lifecycle. Covers axiom philosophy, when to accept vs eliminate axioms, documentation requirements, and long-term tracking.

## Table of Contents

1. [Axiom Philosophy](#axiom-philosophy)
2. [Axiom Categories](#axiom-categories)
3. [When to Accept an Axiom](#when-to-accept-an-axiom)
4. [When to Eliminate an Axiom](#when-to-eliminate-an-axiom)
5. [Documentation Requirements](#documentation-requirements)
6. [Axiom Lifecycle](#axiom-lifecycle)
7. [Quarterly Axiom Review](#quarterly-axiom-review)
8. [Emergency Procedures](#emergency-procedures)

---

## Axiom Philosophy

### Core Principle

**Minimize axioms, document the rest.** Every axiom is a trust-me claim. The fewer we have, the stronger the verification.

**But:** Some axioms are unavoidable (crypto primitives, trusted kernels). The goal is to distinguish:
- **Necessary axioms** (crypto, kernels) — accept and document
- **Laziness axioms** (unfinished proofs) — eliminate
- **Temporary axioms** (work-in-progress scaffolds) — mark for removal

### Trust Boundary

Axioms define the **trust boundary**: what you must believe for the verification to hold. A verification with 100 axioms is not "formally verified" — it's "conditionally verified under 100 assumptions."

**Target for CA:** ≤22 permanent axioms (all crypto-related), 0 TEMPORARY axioms at release.

**Current (2026-04-22):** 27 total (10 CA code, 17 crypto deps), 1 TEMPORARY (`registration_eval_equiv_functional_sim` during Phase 1 rebuild).

---

## Axiom Categories

### 1. TEMPORARY Axioms

**Definition:** Work-in-progress scaffolds that will be replaced with theorems.

**Examples:**
- `registration_eval_equiv_functional_sim` (Phase 1 singleton branch outstanding)

**Markers:**
- Doc-comment: `-- TEMPORARY AXIOM: will be proved in <milestone>`
- Entry in `AXIOM_INVENTORY.md` §1 TEMPORARY category
- GitHub issue tracking elimination

**Acceptance criteria:** NEVER in production releases. Only acceptable on development branches.

**Process:**
1. Mark axiom with TEMPORARY comment
2. Add to `AXIOM_INVENTORY.md` §1
3. Create GitHub issue: "Eliminate TEMPORARY axiom: <name>"
4. Track in `COMPLETION_ROADMAP.md`
5. Replace with theorem before release

### 2. Crypto Axioms (PERMANENT)

**Definition:** Externally audited cryptographic primitives out of scope for this verification effort.

**Examples:**
- Ristretto255 discrete-log hardness
- SHA-2/SHA-3 collision resistance
- Bulletproofs soundness and completeness
- Schnorr signature soundness
- Edwards curve group laws

**Markers:**
- Doc-comment: `-- CRYPTO AXIOM: <primitive> <property> (external audit: <citation>)`
- Entry in `AXIOM_INVENTORY.md` §2-4 (crypto categories)
- Entry in `TRUST_BOUNDARIES.md` §2 "Crypto axioms"

**Acceptance criteria:** Acceptable in production if:
1. Externally audited (cite paper or audit report)
2. Standard primitive (not novel cryptography)
3. Documented in both `AXIOM_INVENTORY.md` and `TRUST_BOUNDARIES.md`

**Process:**
1. Verify axiom is actually necessary (can't be proved from existing axioms)
2. Find external audit or cryptographic proof (cite paper)
3. Add to `AXIOM_INVENTORY.md` with rationale
4. Add to `TRUST_BOUNDARIES.md` §2
5. Add to axiom baseline: `./scripts/check_axioms.sh > audit/axiom-baseline.txt`

### 3. Kernel Trust (PERMANENT)

**Definition:** Trusted proof kernels and solvers.

**Examples:**
- Lean 4 kernel soundness
- Boogie soundness
- Z3 4.11.2 SMT solver soundness
- Move VM implementation correctness

**Markers:**
- Not Lean axioms (these are meta-level trust, not in-proof axioms)
- Documented in `TRUST_BOUNDARIES.md` §1 "Kernel / solver trust"

**Acceptance criteria:** Always acceptable (unavoidable).

**Process:** Document in `TRUST_BOUNDARIES.md`, no action needed in Lean code.

### 4. Native Oracles (PERMANENT)

**Definition:** Lean `@[opaque]` definitions bound to Move native functions, verified by difftest not ∀-proof.

**Examples:**
- `ristretto255::point_mul`
- `aptos_hash::sha3_512`
- All Bulletproofs natives

**Markers:**
- Lean: `@[opaque] def oraclePointMul : ... := ...`
- MSL: `pragma opaque` on `spec fun spec_point_mul`
- Entry in `TRUST_BOUNDARIES.md` §3 "Native-function assumptions"

**Acceptance criteria:** Acceptable if:
1. Backed by difftest corpus rows (concrete I/O pairs validated)
2. Documented in `TRUST_BOUNDARIES.md` §3
3. MSL has matching `pragma opaque`

**Process:**
1. Add Lean `@[opaque]` definition
2. Add difftest corpus rows (≥3: happy path + 2 error cases)
3. Add MSL `pragma opaque` (if MSL spec exists)
4. Document in `TRUST_BOUNDARIES.md` §3
5. Run `./scripts/reconcile_trust_boundaries.sh` to validate

---

## When to Accept an Axiom

### Decision Tree

```
Is this a crypto primitive (DL, collision resistance, etc.)?
├─ YES → Is it externally audited?
│         ├─ YES → ACCEPT as CRYPTO axiom (category 2)
│         └─ NO  → REJECT (implement or find audit)
└─ NO  → Is this a trusted kernel (Lean, Z3, VM)?
          ├─ YES → ACCEPT as KERNEL trust (category 3)
          └─ NO  → Is this a native oracle with difftest coverage?
                    ├─ YES → ACCEPT as NATIVE oracle (category 4)
                    └─ NO  → Is this temporary scaffolding?
                              ├─ YES → ACCEPT as TEMPORARY (category 1)
                              │        with GitHub issue + deadline
                              └─ NO  → REJECT (prove it)
```

### Red Flags (Probably Should Prove, Not Axiomatize)

- "This is too hard to prove" — investigate proof automation first
- "I don't understand the proof" — ask for help, don't axiomatize
- "This is obviously true" — if obvious, it's probably provable
- "The proof is repetitive" — extract a parametric lemma
- "I'm on a deadline" — use `sorry` + FIXME, not axiom

### Acceptable Rationales

- **Crypto:** "Ristretto255 discrete-log hardness is NP-hard, external audit cited"
- **Oracle:** "SHA3-512 is a black-box native, difftest validates concrete outputs"
- **Kernel:** "Lean 4 kernel is trusted, audited by independent researchers"
- **Temporary:** "Phase 1 singleton branch proof is in progress, ETA 1 week, tracked in #123"

---

## When to Eliminate an Axiom

### Elimination Triggers

1. **TEMPORARY axiom completed:** Replace with theorem when work finishes
2. **Proof automation improves:** What was hard is now tractable
3. **Upstream theorem available:** New Mathlib lemma covers the axiom
4. **Difftest coverage added:** Native oracle can be validated concretely
5. **Quarterly review:** Routine audit flags stale axiom

### Elimination Process

**Step 1: Verify axiom is still in use**

```bash
cd lean
lake env lean --run ../scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.<Module>
# Check if axiom appears in output
```

If not in output: axiom is dead code, safe to delete.

**Step 2: Replace axiom with theorem**

```lean
-- Before:
axiom my_axiom : P → Q

-- After:
theorem my_axiom : P → Q := by
  intro h
  -- ... (proof)
```

**Step 3: Rebuild and check dependencies**

```bash
lake build MovementFormal.Experimental.ConfidentialAsset.<Module>
# Ensure theorem proof compiles

# Check what else depends on it
lake build  # Full tree
```

**Step 4: Update documentation**

```bash
# Remove from AXIOM_INVENTORY.md
vim audit/AXIOM_INVENTORY.md

# Regenerate baseline
./scripts/check_axioms.sh > audit/axiom-baseline.txt

# Verify reconciliation
./scripts/reconcile_trust_boundaries.sh
```

**Step 5: Commit**

```bash
git add lean/MovementFormal/... audit/AXIOM_INVENTORY.md audit/axiom-baseline.txt
git commit -m "Eliminate TEMPORARY axiom: my_axiom

Replaced axiom with theorem. Proof uses <technique>.
Build time: <X>s. No new dependencies.

Fixes: #<issue-number>
"
```

---

## Documentation Requirements

### For Every Axiom

**In Lean code:**

```lean
-- <CATEGORY> AXIOM: <one-line description>
-- Rationale: <why this axiom is acceptable>
-- External audit: <citation> (if crypto)
-- Tracked in: <GitHub issue or AXIOM_INVENTORY.md section>
axiom my_axiom : P → Q
```

**In AXIOM_INVENTORY.md:**

```markdown
### `my_axiom` (<Module>.lean:LINE)

**Category:** TEMPORARY | CRYPTO | NATIVE

**Statement:** <mathematical claim>

**Rationale:** <why we accept this axiom>

**How a skeptic challenges it:** <what would break if axiom is wrong>

**Elimination plan:** <timeline or "N/A - permanent"> 

**Tracked in:** <GitHub issue #123 or "N/A">
```

**In TRUST_BOUNDARIES.md:**

Add entry to appropriate section (§1 kernel, §2 crypto, §3 native, §4 residual).

**In axiom baseline:**

```bash
./scripts/check_axioms.sh > audit/axiom-baseline.txt
git add audit/axiom-baseline.txt
```

### For TEMPORARY Axioms (Additional Requirements)

**GitHub issue:**

```
Title: Eliminate TEMPORARY axiom: my_axiom

Description:
Phase: <1/4/6/8>
Module: MovementFormal.Experimental.ConfidentialAsset.<Module>
Line: <file.lean:LINE>

This axiom is a work-in-progress scaffold for <goal>.

Elimination plan:
1. <step 1>
2. <step 2>
3. Replace axiom with theorem

ETA: <date or milestone>
Blocker: <none or describe>
```

**Label:** `axiom-elimination`, `phase-<N>`

---

## Axiom Lifecycle

### 1. Introduction (New Axiom)

**Trigger:** Developer adds `axiom` declaration in Lean code.

**Pre-commit hook check:**
- Fails if axiom added without `AXIOM_INVENTORY.md` update
- Warning: "New axiom detected, ensure documented"

**Developer workflow:**
1. Add axiom to Lean code with doc-comment
2. Categorize: TEMPORARY, CRYPTO, or NATIVE
3. Add to `AXIOM_INVENTORY.md`
4. Add to `TRUST_BOUNDARIES.md` (if CRYPTO or NATIVE)
5. Create GitHub issue (if TEMPORARY)
6. Regenerate baseline
7. Commit all changes together

**CI check:**
- `axiom-diff-ca.yaml` workflow fails on new axiom
- Requires `AXIOM_INVENTORY.md` and baseline update in same PR

### 2. Active Use (Axiom in Codebase)

**Quarterly review:**
- Check if axiom still necessary
- Check if elimination plan on track (TEMPORARY axioms)
- Check if external audit still cited correctly (CRYPTO axioms)

**Dependency tracking:**
```bash
# See which theorems depend on this axiom
lake env lean --run ../scripts/print_axioms.lean MovementFormal.Experimental.ConfidentialAsset.<Module>
```

**Difftest validation (NATIVE oracles):**
- Corpus rows must remain green
- Add more corpus rows if coverage gaps found

### 3. Elimination (Replace with Theorem)

**Trigger:** Work completes, proof automation improves, or quarterly review flags stale axiom.

**Process:** See "Elimination Process" above.

**Verification:**
- CI `axiom-diff-ca` shows 1 axiom removed
- `AXIOM_INVENTORY.md` updated
- Baseline regenerated
- `TRUST_BOUNDARIES.md` reconciles

**Close GitHub issue** (if TEMPORARY).

### 4. Archival (Historical Record)

**Git history preserves:**
- When axiom was added (commit SHA)
- When axiom was eliminated (commit SHA)
- Rationale for both (commit messages)

**No need to keep commented-out axioms** — `git log` is the source of truth.

---

## Quarterly Axiom Review

**Frequency:** Every 3 months (Q1, Q2, Q3, Q4)

**Checklist:**

1. **Count axioms:**
   ```bash
   ./scripts/check_axioms.sh | grep -c "axiom"
   ```
   Target: ≤22 permanent + 0 TEMPORARY at release

2. **Categorize:**
   - How many TEMPORARY? (Should trend to 0)
   - How many CRYPTO? (Should be stable)
   - How many NATIVE? (Should be stable or decrease as difftest coverage grows)

3. **Review TEMPORARY axioms:**
   - Check GitHub issue: is elimination on track?
   - If blocked: update issue with blocker details
   - If overdue: escalate to formal verification team lead

4. **Review CRYPTO axioms:**
   - Verify external audits still cited correctly
   - Check if any can be eliminated (new Mathlib theorem available?)

5. **Review NATIVE axioms:**
   - Check difftest corpus coverage (≥3 rows per oracle)
   - Add more corpus rows if coverage gaps found

6. **Update documentation:**
   - Regenerate `AXIOM_INVENTORY.md` if categories changed
   - Regenerate baseline
   - Run `./scripts/reconcile_trust_boundaries.sh`

**Output:** Quarterly axiom review report (Markdown file in `audit/`)

**Use automation:**
```bash
./scripts/quarterly_audit.sh
# Includes axiom health checks
```

---

## Emergency Procedures

### Emergency 1: New Axiom Detected in Production

**Symptom:** CI fails on `axiom-diff-ca` workflow after merge to `lean-fv`.

**Diagnosis:**
```bash
./scripts/check_axioms.sh --diff
# Shows which axiom was added
```

**Resolution:**

**If axiom is acceptable (CRYPTO or NATIVE):**
1. Add to `AXIOM_INVENTORY.md` with rationale
2. Add to `TRUST_BOUNDARIES.md`
3. Regenerate baseline
4. Commit documentation update
5. Push to unblock CI

**If axiom is unacceptable (laziness or TEMPORARY without plan):**
1. Revert commit that introduced axiom
2. Contact author: "Replace axiom with theorem or provide rationale"
3. Do NOT merge until resolved

### Emergency 2: Axiom Drift Without Documentation

**Symptom:** Axiom-diff CI passes but axiom count increased.

**Diagnosis:**
```bash
# Compare current against last release
git diff v<last-release> audit/axiom-baseline.txt
```

**Resolution:**
1. Identify which axiom was added (and when)
2. Check if documented in `AXIOM_INVENTORY.md`
3. If not: add documentation retroactively
4. If axiom is unacceptable: create elimination issue and timeline

### Emergency 3: TEMPORARY Axiom Missed Release Deadline

**Symptom:** Release validation fails because TEMPORARY axiom still present.

**Diagnosis:**
```bash
grep "TEMPORARY" audit/AXIOM_INVENTORY.md
# Check GitHub issue for elimination plan
```

**Resolution:**

**If elimination is close (≤2 days):**
- Delay release until axiom eliminated
- Fast-track elimination PR

**If elimination is blocked (>1 week):**
- Decide: downgrade to non-release milestone OR accept as permanent
- If permanent: recategorize as CRYPTO or NATIVE with rationale
- If downgrade: skip release until ready

**Never release with TEMPORARY axioms** — this is a hard requirement.

### Emergency 4: External Audit Citation Broken

**Symptom:** Link to external audit (paper, report) is 404 or stale.

**Diagnosis:**
```bash
grep "External audit" audit/AXIOM_INVENTORY.md
# Check each link
```

**Resolution:**
1. Find archived version of paper (Wayback Machine, arXiv, etc.)
2. Update citation to stable URL
3. If paper is retracted or found unsound: **REMOVE AXIOM** (or find alternative audit)
4. Commit updated citations

---

## Best Practices

### Do's

- **Document every axiom** (no exceptions)
- **Mark TEMPORARY axioms** with GitHub issue + deadline
- **Use difftest** to validate native oracles (concrete > abstract)
- **Regenerate baseline** after every axiom change
- **Run reconcile script** to catch drift early
- **Review quarterly** to prevent axiom accumulation

### Don'ts

- **Don't axiomatize laziness** ("too hard to prove" is not a rationale)
- **Don't skip documentation** ("I'll document it later" → never happens)
- **Don't accept novel crypto** without external audit (stick to standards)
- **Don't release with TEMPORARY axioms** (hard blocker)
- **Don't delete axioms without checking dependents** (break downstream proofs)
- **Don't bypass axiom-diff CI** (it exists for a reason)

---

## Summary

**Axiom management = trust management.** Every axiom weakens the verification claim. Our goal:

1. **Minimize:** Prove what we can, axiomatize only what we must
2. **Categorize:** TEMPORARY (eliminate) vs PERMANENT (document)
3. **Document:** Every axiom in inventory, trust boundaries, baseline
4. **Track:** GitHub issues for TEMPORARY, quarterly review for all
5. **Validate:** CI guards against drift, difftest validates oracles

**Target:** ≤22 permanent axioms (all crypto), 0 TEMPORARY at release.

**Current:** 27 total (1 TEMPORARY during Phase 1, 26 permanent).

**For questions:** See `FAQ.md` §Trust & Security or ask in #formal-verification Slack.
