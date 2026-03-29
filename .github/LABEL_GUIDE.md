# GitHub Labels & CI/CD Workflow Trigger Guide

This document explains all GitHub labels used in the CI/CD workflows and which tests or jobs they trigger when added to a pull request.

## Labels Overview

### 1. `CICD:run-e2e-tests`
**Purpose:** Trigger end-to-end smoke tests and related validation.

**When to use:** Add this label when you want to run comprehensive end-to-end tests on your PR.

**Workflows/Jobs triggered:**
- `rust-smoke-tests` — Runs all rust smoke tests (comprehensive smoke test suite)
- `rust-doc-tests` — Runs rust documentation tests
- `rust-build-cached-packages` — Builds and tests cached packages

**How to add:**
```bash
gh pr edit <PR_NUMBER> --add-label "CICD:run-e2e-tests"
```

---

### 2. `CICD:run-all-unit-tests`
**Purpose:** Trigger all rust unit tests (instead of just targeted/changed tests).

**When to use:** Add this label when you want to ensure all unit tests pass, not just those related to your changes. Useful before major merges or releases.

**Workflows/Jobs triggered:**
- `rust-unit-tests` — Runs the full rust unit test suite across the entire workspace

**How to add:**
```bash
gh pr edit <PR_NUMBER> --add-label "CICD:run-all-unit-tests"
```

---

### 3. `CICD:build-consensus-only-image`
**Purpose:** Trigger consensus-only builds and tests (performance testing mode).

**When to use:** Add this label when testing consensus-layer changes in isolation or for performance/perf-test builds.

**Workflows/Jobs triggered:**
- `rust-consensus-only-unit-test` — Runs unit tests with consensus-only feature flag
- `rust-consensus-only-smoke-test` — Runs smoke tests with consensus-only feature flag

**How to add:**
```bash
gh pr edit <PR_NUMBER> --add-label "CICD:build-consensus-only-image"
```

---

### 4. `CICD:non-required-tests`
**Purpose:** Trigger optional, non-required CI checks that are skipped by default.

**When to use:** Add this label when you want to run additional checks that are not part of the standard PR validation (e.g., crypto hasher domain separation checks).

**Workflows/Jobs triggered:**
- `rust-cryptohasher-domain-separation-check` — Validates cryptohasher symbols and domain separation

**How to add:**
```bash
gh pr edit <PR_NUMBER> --add-label "CICD:non-required-tests"
```

---

## Alternative: Use PR Body Text

Some workflows also support triggering tests via text in the PR body:

- **`#e2e`** in the PR description will trigger `rust-smoke-tests` (same as `CICD:run-e2e-tests` label)

**Example PR body:**
```
## Description
This PR fixes the transaction validator.

#e2e
```

---

## Create Labels in Bulk

If labels don't exist yet, create them all at once:

```bash
# Define labels
labels=(
  "CICD:non-required-tests|ffcc00|Non-required CI tests"
  "CICD:run-e2e-tests|ff0000|Run e2e smoke tests"
  "CICD:run-all-unit-tests|00aaff|Run all unit tests"
  "CICD:build-consensus-only-image|00cc66|Build consensus-only image"
)

# Create them
for entry in "${labels[@]}"; do
  IFS='|' read -r name color desc <<< "$entry"
  gh label create "$name" --color "$color" --description "$desc"
done

# Verify
gh label list | grep "CICD:"
```

---

## Workflow Conditions Summary

| Label | Triggers Job | Related To |
|-------|-------------|-----------|
| `CICD:run-e2e-tests` | `rust-smoke-tests`, `rust-doc-tests`, `rust-build-cached-packages` | End-to-end validation |
| `CICD:run-all-unit-tests` | `rust-unit-tests` | Full unit test suite |
| `CICD:build-consensus-only-image` | `rust-consensus-only-unit-test`, `rust-consensus-only-smoke-test` | Consensus layer testing |
| `CICD:non-required-tests` | `rust-cryptohasher-domain-separation-check` | Optional validation checks |

---

## Checking Label Status

View all labels in the repository:
```bash
gh label list
```

View labels on a specific PR:
```bash
gh pr view <PR_NUMBER> --json labels
```

---

## Notes

- Labels are **case-sensitive** and must match exactly (including colons and capitalization).
- Multiple labels can be added to a single PR; all matching workflows will trigger.
- Some jobs have additional conditions (e.g., not running on release branches), so adding a label is not 100% guaranteed to run a job in all contexts.
- If you encounter permission issues creating labels, ensure your GitHub token has `repo` scope.
