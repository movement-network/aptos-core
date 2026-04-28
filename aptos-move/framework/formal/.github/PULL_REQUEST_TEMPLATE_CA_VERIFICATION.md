# CA Formal Verification Pull Request

**Type:** <!-- Choose one: Lean Proof | MSL Spec | Difftest | Documentation | Infrastructure -->

**Phase:** <!-- Choose one: Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 | Phase 6 | Phase 7 | Phase 8 -->

**Operation:** <!-- If applicable: register | withdraw | transfer | normalize | rotate -->

---

## Summary

<!-- Brief description of what this PR accomplishes (1-3 sentences) -->

---

## Changes Made

### Lean Proofs

<!-- If this PR includes Lean proofs, list: -->
- [ ] New theorems added: <!-- count -->
- [ ] Files modified: <!-- list .lean files -->
- [ ] Build time impact: <!-- e.g., "+2s on Registration/EvalEquiv.lean" -->
- [ ] Axioms added/removed: <!-- count, or "none" -->

### MSL Specs

<!-- If this PR includes MSL specs, list: -->
- [ ] Spec blocks added: <!-- count -->
- [ ] Files modified: <!-- list .spec.move files -->
- [ ] VCs generated: <!-- count, or "N/A (ristretto255 blocked)" -->
- [ ] Pragma opaque used: <!-- yes/no, if yes list in Trust Boundaries section -->

### Difftest

<!-- If this PR includes difftest work, list: -->
- [ ] Corpus rows added: <!-- count -->
- [ ] Test suites modified: <!-- list suite names -->
- [ ] VM↔Lean pass rate: <!-- e.g., "87/87 passing" -->

### Documentation

<!-- If this PR includes documentation, list: -->
- [ ] Files created/modified: <!-- list .md files -->
- [ ] Lines added: <!-- count -->
- [ ] Cross-references updated: <!-- yes/no -->

### Infrastructure

<!-- If this PR includes scripts/automation, list: -->
- [ ] Scripts added/modified: <!-- list .sh files -->
- [ ] CI workflows modified: <!-- list .yaml files -->
- [ ] Dependencies added: <!-- list new tools/versions -->

---

## Verification Checklist

### Build & Tests

- [ ] **Lean build passes:** `cd lean && lake build` (target: <10 min)
- [ ] **Move Prover compiles:** `movement move compile --package-dir aptos-experimental` (or N/A)
- [ ] **verify-ca.sh passes:** `./audit/verify-ca.sh --op <operation>` (target: <3 min)
- [ ] **No sorry in proofs:** `grep -r 'sorry' lean/MovementFormal/Experimental/ConfidentialAsset/` returns 0 matches
- [ ] **Pre-commit hooks pass:** All checks green

### Axiom Hygiene

- [ ] **Axiom count unchanged:** `./scripts/check_axioms.sh --diff` shows no additions
  - OR if axioms added: Count increased by <!-- N -->, documented in AXIOM_INVENTORY.md
- [ ] **TEMPORARY axioms justified:** All new TEMPORARY axioms have GitHub issue links
- [ ] **Baseline updated:** If axioms approved, `./scripts/track_axiom_drift.sh --baseline` run

### Trust Boundaries

- [ ] **Pragma opaque documented:** All `pragma opaque` in this PR listed in TRUST_BOUNDARIES.md
- [ ] **Pragma verify=false justified:** No `pragma verify = false` (or if present, test-only module)
- [ ] **Reconciliation passes:** `./scripts/reconcile_trust_boundaries.sh` succeeds

### Documentation

- [ ] **CLAIMS.md updated:** If new claims proved, added to audit/CLAIMS.md
- [ ] **Coverage report updated:** `./scripts/generate_coverage_report.sh` reflects changes
- [ ] **Phase status updated:** Relevant PHASE_*_STATUS.md files reflect progress
- [ ] **README updated:** If new commands/workflows added

### Performance

- [ ] **Build time within budget:** Per-file builds <3 min, full tree <10 min
- [ ] **No performance regression:** `./scripts/detect_performance_regression.sh` passes
- [ ] **Benchmark updated:** If significant performance change, baseline updated

---

## Metrics

<!-- Fill in actual metrics after running checks -->

| Metric | Before | After | Change | Target |
|--------|--------|-------|--------|--------|
| Lean theorems | | | | |
| MSL spec blocks | | | | |
| Axiom count (total) | | | | ≤28 |
| Axiom count (TEMPORARY) | | | | 0 |
| Lean build time | | | | <10 min |
| verify-ca.sh time | | | | <3 min |
| Documentation lines | | | | |

---

## Trust Boundaries Impact

<!-- If this PR adds/removes trust boundaries (axioms, pragma opaque, etc.), list here: -->

### New Axioms

<!-- List any new axioms with category (TEMPORARY/CRYPTO/KERNEL/NATIVE) and justification -->
- None

### Removed Axioms

<!-- List any axioms eliminated -->
- None

### New Pragma Opaque

<!-- List any new `pragma opaque` declarations with module::function and justification -->
- None

---

## Testing Evidence

### Lean Build Output

```
<!-- Paste relevant build output showing success -->
$ cd lean && lake build
Build completed successfully
Elapsed time: X.Xs
```

### verify-ca.sh Output

```
<!-- Paste verify-ca.sh output for relevant operation(s) -->
$ ./audit/verify-ca.sh --op <operation>
✅ All checks passed
Elapsed time: X.Xs
```

### Axiom Check Output

```
<!-- Paste check_axioms.sh --diff output -->
$ ./scripts/check_axioms.sh --diff
No axiom drift detected
```

---

## Phase Progress Impact

<!-- How does this PR advance phase completion? -->

**Phase X:** <!-- e.g., "Phase 1: 95% → 100% (singleton branch complete)" -->

**Critical path impact:** <!-- e.g., "Unblocks Phase 6" or "No critical path impact" -->

---

## Reviewer Notes

<!-- Any specific areas reviewers should focus on? -->

### Key Files to Review

<!-- List 3-5 most important files for reviewers to check -->
1. 
2. 
3. 

### Known Issues / Limitations

<!-- Any known issues or TODOs left for future work? -->
- None

### Follow-up Work

<!-- Any follow-up PRs planned? -->
- None

---

## Pre-Merge Checklist

- [ ] All CI checks passing
- [ ] At least 1 reviewer approval
- [ ] Documentation updated (if applicable)
- [ ] Axiom baseline updated (if axioms changed)
- [ ] Squash commits before merge (or keep meaningful commit history)
- [ ] Merge commit message includes metrics (see template below)

### Suggested Merge Commit Message

```
<Title from PR>

<Summary from PR>

Metrics:
- Lean theorems: +X
- MSL spec blocks: +X
- Axioms: ±X (total: X)
- Build time: X.Xs
- verify-ca.sh: X.Xs

Phase impact: <Phase X: Y% → Z%>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

---

**Reminder:** This PR template is for CA formal verification work. For general Aptos PRs, use the standard template.
