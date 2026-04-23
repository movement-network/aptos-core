# Verification Metrics Dashboard Guide

**Purpose:** Tracking, measuring, and reporting verification health and progress for Confidential Assets.

**Audience:** FV leads, project managers, engineering leadership, auditors.

**Scope:** Metrics definitions, collection methods, dashboard design, reporting workflows.

**Status:** Production-ready metrics framework for CA verification.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Core Metrics](#2-core-metrics)
3. [Collection Methods](#3-collection-methods)
4. [Dashboard Design](#4-dashboard-design)
5. [Reporting Workflows](#5-reporting-workflows)
6. [Trend Analysis](#6-trend-analysis)
7. [Alerts and Thresholds](#7-alerts-and-thresholds)
8. [Integration with CI](#8-integration-with-ci)

---

## 1. Overview

### 1.1 Why Measure Verification?

**Verification is invisible without metrics:**
- Can't see progress (how close to done?)
- Can't detect degradation (axiom drift, performance regression)
- Can't justify investment (ROI unclear)
- Can't identify bottlenecks (where to optimize?)

**Metrics make verification visible:**
- **For developers:** Am I on track? What's blocking me?
- **For managers:** Is the team making progress? Where to allocate resources?
- **For auditors:** What's verified? What's assumed? What's the confidence level?
- **For executives:** Is verification worth the cost? What's the risk?

### 1.2 Metrics Philosophy

**Good metrics are:**

**Actionable** — Lead to concrete decisions
- ❌ Bad: "Verification progress: 73%" (what does this mean?)
- ✅ Good: "Registration: 95% complete (5% remaining: PC 47-52 chaining)"

**Measurable** — Can be automatically collected
- ❌ Bad: "Code quality is good" (subjective)
- ✅ Good: "Axiom count: 21 permanent + 2 temporary"

**Understandable** — Clear to all stakeholders
- ❌ Bad: "VC discharge rate: 87%" (jargon)
- ✅ Good: "MSL verification success: 75 of 75 properties proven"

**Trendable** — Trackable over time
- ❌ Bad: One-time snapshot
- ✅ Good: Weekly progress chart

### 1.3 Metrics Categories

**CA verification tracks four categories:**

**1. Completeness metrics** (How much is verified?)
- Proof coverage (% of operations verified)
- Property coverage (% of claims proven)
- Test coverage (% of scenarios covered)

**2. Quality metrics** (How rigorous is verification?)
- Axiom count (permanent vs temporary)
- Sorry count (unproven placeholders)
- Cross-stack consistency (MSL-Lean-Difftest alignment)

**3. Performance metrics** (How fast is verification?)
- Build times (Lean, MSL, Difftest)
- Proof elaboration time
- CI pipeline duration

**4. Health metrics** (Is verification sustainable?)
- Maintenance burden (time spent on upkeep)
- Regression frequency (proofs breaking)
- Technical debt (temporary workarounds)

---

## 2. Core Metrics

### 2.1 Completeness Metrics

**Metric: Proof Coverage**

**Definition:** Percentage of CA operations fully verified (zero sorry, axioms justified).

**Formula:**
```
Proof Coverage = (Fully Verified Operations) / (Total Operations) × 100%
```

**Current value:**
- Registration: 95% (Phase 1 nearly complete)
- Transfer: 70% (Phase 6 PC-chaining in progress)
- Withdrawal: 60% (Phase 6 PC-chaining planned)
- Rotation: 60% (Phase 6 PC-chaining planned)
- Normalization: 80% (Phase 6 simplest, fastest)

**Overall: 73%** (weighted by complexity)

**Target:** 100% by end of Phase 6 (~23-32 hours remaining).

**Collection:**
```bash
# Count sorry placeholders
grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/ | wc -l

# Manual assessment of completion
# Registration: step lemmas complete, PC-chaining 95% done
# Transfer: step lemmas complete, PC-chaining 70% done
# etc.
```

---

**Metric: Property Coverage**

**Definition:** Percentage of claimed properties with formal proof.

**Formula:**
```
Property Coverage = (Proven Properties) / (Claimed Properties) × 100%
```

**Breakdown:**

| Property Category | Claimed | Proven | Coverage |
|-------------------|---------|--------|----------|
| Balance preservation | 4 | 4 | 100% |
| Proof verification | 4 | 4 | 100% |
| Abort codes | 16 | 16 | 100% |
| Frame conditions | 4 | 3 | 75% |
| Composition | 4 | 2 | 50% |
| **Total** | **32** | **29** | **91%** |

**Target:** 100% (all properties proven).

**Collection:**
```bash
# Extract claims from CLAIMS.md
grep "^- \[.\]" audit/CLAIMS.md | wc -l  # Total claims

grep "^- \[x\]" audit/CLAIMS.md | wc -l  # Proven claims

# Calculate coverage
# Coverage = Proven / Total × 100%
```

---

**Metric: Test Coverage**

**Definition:** Percentage of test scenarios passing (difftest corpus).

**Formula:**
```
Test Coverage = (Passing Tests) / (Total Tests) × 100%
```

**Current value:**
- Current tests: 87 passing
- Target tests: 102 (95% of all scenarios)
- Coverage: 85% (87/102)

**Breakdown:**

| Operation | Scenarios | Passing | Coverage |
|-----------|-----------|---------|----------|
| Registration | 20 | 20 | 100% |
| Transfer | 30 | 27 | 90% |
| Withdrawal | 25 | 20 | 80% |
| Rotation | 15 | 10 | 67% |
| Normalization | 12 | 10 | 83% |

**Target:** ≥95% (97 of 102 tests).

**Collection:**
```bash
# Run difftest
cd difftest
cargo test --release 2>&1 | tee test_output.txt

# Parse results
passing=$(grep "test result: ok" test_output.txt | \
          sed 's/.*ok. \([0-9]*\) passed.*/\1/')
total=$(grep "running" test_output.txt | sed 's/.*running \([0-9]*\) tests/\1/')

echo "Test Coverage: $passing / $total = $(($passing * 100 / $total))%"
```

---

### 2.2 Quality Metrics

**Metric: Axiom Count**

**Definition:** Number of axioms (permanent vs temporary).

**Formula:**
```
Axiom Count = Permanent Axioms + Temporary Axioms
```

**Current value:**
- Permanent: 21 (crypto assumptions, justified)
- Temporary: 2 (ristretto255 patches, Move Prover limitations)
- **Total: 23**

**Target:**
- Permanent: 21 (fixed, well-justified)
- Temporary: 0 (all removed when blockers resolved)

**Trend:** Temporary axioms should decrease over time.

**Collection:**
```bash
cd lean
lake build MovementFormal
./scripts/check_axioms.sh

# Output:
# Axioms (21 permanent + 2 temporary):
# 1. dlog_hard (permanent, crypto assumption)
# 2. bulletproofs_soundness (permanent, crypto assumption)
# ...
# 22. ristretto255_add_assoc (temporary, waiting for patches)
# 23. ristretto255_scalar_mul_correct (temporary, waiting for patches)
```

---

**Metric: Sorry Count**

**Definition:** Number of `sorry` placeholders (unproven theorems).

**Formula:**
```
Sorry Count = total sorry placeholders in Lean proofs
```

**Current value:**
- Phase 1 (Registration): 5 sorry (final 5% of PC-chaining)
- Phase 6 (Transfer/Withdrawal/Rotation/Normalization): ~50 sorry

**Target:** 0 sorry (all proofs complete).

**Trend:** Should monotonically decrease as proofs completed.

**Collection:**
```bash
# Count all sorry
find lean/MovementFormal/Experimental/ConfidentialAsset -name "*.lean" \
     -exec grep -c "sorry" {} \; | \
     awk '{sum += $1} END {print "Sorry count:", sum}'

# Breakdown by operation
for op in Registration Transfer Withdrawal Rotation Normalization; do
  count=$(grep -r "sorry" lean/MovementFormal/Experimental/ConfidentialAsset/$op/ | wc -l)
  echo "$op: $count sorry"
done
```

---

**Metric: Cross-Stack Consistency**

**Definition:** Agreement rate between MSL, Lean, and Difftest on abort codes.

**Formula:**
```
Consistency = (Matching Abort Codes) / (Total Abort Conditions) × 100%
```

**Current value:** 100% (all abort codes match).

**Target:** 100% (mandatory for correctness).

**Collection:**
```bash
./scripts/check_abort_code_consistency.sh

# Output:
# Checking EVERIFY_FAILED (65537)...
#   MSL: ✓ found
#   Lean: ✓ found
#   Difftest: ✓ found
# Checking EINVALID_PROOF_FORMAT (524289)...
#   MSL: ✓ found
#   Lean: ✓ found
#   Difftest: ✓ found
# ...
# Consistency: 16/16 = 100%
```

---

### 2.3 Performance Metrics

**Metric: Lean Build Time**

**Definition:** Time to build all Lean proofs (per-file and full tree).

**Formula:**
```
Lean Build Time = max(per-file build times) [for CI parallelism]
Full Tree Build Time = total build time [for sequential build]
```

**Current value:**
- Registration: ~150s (within 180s budget)
- Transfer: ~120s (within budget)
- Full tree: ~450s (within 600s budget)

**Target:**
- Per-file: ≤180s
- Full tree: ≤600s

**Trend:** Should remain stable (no performance regressions).

**Collection:**
```bash
cd lean
lake clean

# Time per-file build
for file in MovementFormal/Experimental/ConfidentialAsset/*/*.lean; do
  time lake build ${file%.lean} 2>&1 | tee -a build_times.log
done

# Parse times
grep "real" build_times.log | \
  awk '{print $2}' | \
  sort -n | \
  tail -1  # Max time (bottleneck)

# Time full tree
time lake build MovementFormal 2>&1 | grep "real"
```

---

**Metric: CI Pipeline Duration**

**Definition:** End-to-end time for full verification suite in CI.

**Formula:**
```
CI Duration = max(Lean build, MSL verify, Difftest run, Axiom check)
```

**Current value:**
- Lean build: ~10 min
- MSL verify: ~5 min (when unblocked)
- Difftest: ~30 sec
- Axiom check: ~10 sec
- **Total: ~15 min** (parallelized)

**Target:** ≤45 min (full suite including PBT in future).

**Collection:**
```yaml
# GitHub Actions timing
# Check workflow run time in Actions UI
# Or parse workflow logs:
curl -H "Authorization: token $GITHUB_TOKEN" \
     "https://api.github.com/repos/ORG/REPO/actions/runs/$RUN_ID" | \
     jq '.run_duration_ms / 1000 / 60'  # Convert to minutes
```

---

### 2.4 Health Metrics

**Metric: Regression Frequency**

**Definition:** Number of proof breakages per month (proofs that previously passed now fail).

**Formula:**
```
Regression Frequency = (Proof Breakages) / (Time Period)
```

**Current value:** ~2 regressions per month (acceptable).

**Target:** ≤1 regression per month.

**Collection:**
```bash
# Track CI failures over time
# Manual log: when did a previously passing proof fail?

# Example log entry:
# 2026-04-15: Registration EvalEquiv failed (Move stdlib update broke step lemma)
# 2026-04-22: Transfer step lemma failed (Lean 4 upgrade changed elaboration)

# Count entries per month
```

---

**Metric: Maintenance Burden**

**Definition:** Engineer-hours per week spent on verification upkeep (not new proofs).

**Formula:**
```
Maintenance Burden = (Hours fixing regressions + Hours updating for changes) / Week
```

**Current value:** ~5 hours/week (sustainable).

**Target:** ≤8 hours/week.

**Collection:**
```
# Manual time tracking
# Log hours spent on:
# - Fixing broken proofs (regressions)
# - Updating proofs for Move changes
# - Updating MSL specs
# - Syncing Lean transcriptions

# Weekly total
```

---

**Metric: Technical Debt**

**Definition:** Number of temporary workarounds (temporary axioms, TODO comments, known issues).

**Formula:**
```
Technical Debt = Temporary Axioms + TODO Count + Known Issues
```

**Current value:**
- Temporary axioms: 2
- TODOs: 8 (documented in code)
- Known issues: 3 (tracked in GitHub)
- **Total: 13**

**Target:** <10 (manageable debt).

**Collection:**
```bash
# Temporary axioms
./scripts/check_axioms.sh | grep "temporary" | wc -l

# TODOs
grep -r "TODO" lean/MovementFormal/Experimental/ConfidentialAsset/ | wc -l

# Known issues
gh issue list --label "verification" --json number | jq 'length'

# Sum
echo "Technical Debt: $((temp_axioms + todos + issues))"
```

---

## 3. Collection Methods

### 3.1 Automated Collection Scripts

**Script: collect_metrics.sh**

```bash
#!/bin/bash
# Collect all CA verification metrics

set -e

OUTPUT_DIR="metrics/$(date +%Y-%m-%d)"
mkdir -p "$OUTPUT_DIR"

echo "=== Collecting Verification Metrics ==="

# Completeness Metrics
echo "1. Proof Coverage..."
sorry_count=$(find lean/MovementFormal/Experimental/ConfidentialAsset \
              -name "*.lean" -exec grep -l "sorry" {} \; | wc -l)
total_files=$(find lean/MovementFormal/Experimental/ConfidentialAsset \
              -name "EvalEquiv*.lean" | wc -l)
proof_coverage=$((100 - (sorry_count * 100 / total_files)))
echo "Proof Coverage: $proof_coverage%" > "$OUTPUT_DIR/proof_coverage.txt"

echo "2. Property Coverage..."
total_props=$(grep "^- \[.\]" audit/CLAIMS.md | wc -l)
proven_props=$(grep "^- \[x\]" audit/CLAIMS.md | wc -l)
property_coverage=$((proven_props * 100 / total_props))
echo "Property Coverage: $property_coverage%" > "$OUTPUT_DIR/property_coverage.txt"

echo "3. Test Coverage..."
cd difftest
cargo test --release 2>&1 | tee "$OUTPUT_DIR/difftest_output.txt"
cd ..
passing=$(grep "test result: ok" "$OUTPUT_DIR/difftest_output.txt" | \
          sed 's/.*ok. \([0-9]*\) passed.*/\1/')
total=$(grep "running" "$OUTPUT_DIR/difftest_output.txt" | \
        sed 's/.*running \([0-9]*\) tests/\1/')
test_coverage=$((passing * 100 / total))
echo "Test Coverage: $test_coverage%" > "$OUTPUT_DIR/test_coverage.txt"

# Quality Metrics
echo "4. Axiom Count..."
cd lean
lake build MovementFormal 2>&1 | tee "$OUTPUT_DIR/lean_build.txt"
../scripts/check_axioms.sh > "$OUTPUT_DIR/axiom_count.txt"
cd ..

echo "5. Sorry Count..."
find lean/MovementFormal/Experimental/ConfidentialAsset -name "*.lean" \
     -exec grep -c "sorry" {} \; | \
     awk '{sum += $1} END {print "Sorry count:", sum}' > "$OUTPUT_DIR/sorry_count.txt"

echo "6. Cross-Stack Consistency..."
./scripts/check_abort_code_consistency.sh > "$OUTPUT_DIR/consistency.txt"

# Performance Metrics
echo "7. Build Times..."
cd lean
time lake clean
time lake build MovementFormal 2>&1 | tee "$OUTPUT_DIR/build_time.txt"
cd ..

# Summary
echo "=== Metrics Summary ===" > "$OUTPUT_DIR/summary.txt"
cat "$OUTPUT_DIR/proof_coverage.txt" >> "$OUTPUT_DIR/summary.txt"
cat "$OUTPUT_DIR/property_coverage.txt" >> "$OUTPUT_DIR/summary.txt"
cat "$OUTPUT_DIR/test_coverage.txt" >> "$OUTPUT_DIR/summary.txt"
grep "Axioms" "$OUTPUT_DIR/axiom_count.txt" >> "$OUTPUT_DIR/summary.txt"
cat "$OUTPUT_DIR/sorry_count.txt" >> "$OUTPUT_DIR/summary.txt"

echo "Metrics collected in $OUTPUT_DIR"
```

**Run weekly:**

```bash
# Cron job (runs every Monday at 9am)
0 9 * * 1 cd /path/to/repo && ./scripts/collect_metrics.sh
```

### 3.2 Manual Collection Procedures

**For metrics requiring human judgment:**

**Proof Completion Assessment:**

```
For each operation (Registration, Transfer, Withdrawal, Rotation, Normalization):
  1. Check EvalEquiv*.lean for sorry count
  2. Estimate % complete based on:
     - Step lemmas: how many done vs total?
     - PC-chaining: which paths complete?
     - Composition: is final theorem proven?
  3. Record in spreadsheet:
     Operation | Total Steps | Complete Steps | % Complete
     Registration | 120 | 114 | 95%
     Transfer | 180 | 126 | 70%
     ...
```

**Property Coverage Assessment:**

```
Review CLAIMS.md:
  1. For each claimed property:
     - Is there a Lean theorem proving it? → Mark [x]
     - Is there an MSL spec for it? → Mark [x]
     - Is there a difftest case? → Mark [x]
  2. Count total claims and proven claims
  3. Calculate coverage
```

### 3.3 Data Storage

**Metrics database:**

```
metrics/
├── 2026-04-01/
│   ├── summary.txt
│   ├── proof_coverage.txt
│   ├── property_coverage.txt
│   ├── test_coverage.txt
│   ├── axiom_count.txt
│   ├── sorry_count.txt
│   └── consistency.txt
├── 2026-04-08/
│   └── ... (same structure)
├── 2026-04-15/
│   └── ...
└── historical.csv  (aggregated for charting)
```

**historical.csv format:**

```csv
Date,Proof Coverage,Property Coverage,Test Coverage,Axiom Count,Sorry Count,Build Time,CI Duration
2026-04-01,68,88,82,23,62,480,18
2026-04-08,71,89,83,23,58,475,17
2026-04-15,73,91,85,23,55,450,16
2026-04-22,75,91,87,23,50,445,15
```

---

## 4. Dashboard Design

### 4.1 Text-Based Dashboard

**For terminal/CI output:**

```
╔════════════════════════════════════════════════════════════════╗
║         CONFIDENTIAL ASSETS VERIFICATION DASHBOARD            ║
║                    Updated: 2026-04-22                         ║
╠════════════════════════════════════════════════════════════════╣
║ COMPLETENESS                                                   ║
║   Proof Coverage       █████████████████░░░  75%  (⬆ +2%)    ║
║   Property Coverage    █████████████████████  91%  (⬆ +0%)    ║
║   Test Coverage        ███████████████████░░  87%  (⬆ +2%)    ║
╠════════════════════════════════════════════════════════════════╣
║ QUALITY                                                        ║
║   Axiom Count          21 permanent + 2 temporary = 23 total   ║
║   Sorry Count          50 (⬇ -5 since last week)              ║
║   Consistency          100% (16/16 abort codes match)          ║
╠════════════════════════════════════════════════════════════════╣
║ PERFORMANCE                                                    ║
║   Lean Build (max)     145s / 180s budget  (80% utilization)   ║
║   Full Tree Build      450s / 600s budget  (75% utilization)   ║
║   CI Duration          15min / 45min budget (33% utilization)  ║
╠════════════════════════════════════════════════════════════════╣
║ HEALTH                                                         ║
║   Regressions/Month    2  (⬇ -1 since last month)             ║
║   Maintenance Burden   5 hrs/week  (within 8hr budget)        ║
║   Technical Debt       13 items (2 axioms + 8 TODOs + 3 issues)║
╠════════════════════════════════════════════════════════════════╣
║ OPERATIONS STATUS                                              ║
║   Registration         ████████████████████░  95% (Phase 1)    ║
║   Transfer             ██████████████░░░░░░  70% (Phase 6)     ║
║   Withdrawal           ████████████░░░░░░░░  60% (Phase 6)     ║
║   Rotation             ████████████░░░░░░░░  60% (Phase 6)     ║
║   Normalization        ████████████████░░░░  80% (Phase 6)     ║
╠════════════════════════════════════════════════════════════════╣
║ NEXT MILESTONES                                                ║
║   □ Complete Registration Phase 1 (5% remaining, ETA: 1 week)  ║
║   □ Complete Phase 6 PC-chaining (30% remaining, ETA: 4 weeks) ║
║   □ Remove temporary axioms (blocked on upstream patches)      ║
║   □ Reach 100% test coverage (15 tests remaining)              ║
╚════════════════════════════════════════════════════════════════╝
```

**Generation script:**

```bash
#!/bin/bash
# generate_dashboard.sh

# Read metrics
proof_cov=$(cat metrics/latest/proof_coverage.txt | sed 's/.*: \([0-9]*\)%.*/\1/')
prop_cov=$(cat metrics/latest/property_coverage.txt | sed 's/.*: \([0-9]*\)%.*/\1/')
test_cov=$(cat metrics/latest/test_coverage.txt | sed 's/.*: \([0-9]*\)%.*/\1/')
# ... (read all metrics)

# Draw progress bars
draw_bar() {
  local percentage=$1
  local width=20
  local filled=$((percentage * width / 100))
  local empty=$((width - filled))
  printf "█%.0s" $(seq 1 $filled)
  printf "░%.0s" $(seq 1 $empty)
}

# Output dashboard
cat <<EOF
╔════════════════════════════════════════════════════════════════╗
║         CONFIDENTIAL ASSETS VERIFICATION DASHBOARD            ║
║                    Updated: $(date +%Y-%m-%d)                         ║
╠════════════════════════════════════════════════════════════════╣
║ COMPLETENESS                                                   ║
║   Proof Coverage       $(draw_bar $proof_cov)  ${proof_cov}%    ║
║   Property Coverage    $(draw_bar $prop_cov)  ${prop_cov}%    ║
║   Test Coverage        $(draw_bar $test_cov)  ${test_cov}%    ║
╠════════════════════════════════════════════════════════════════╣
...
EOF
```

### 4.2 Web Dashboard (Future)

**For browser-based visualization:**

**Dashboard sections:**

**1. Overview (top of page)**
- Current overall verification health: 🟢 Green / 🟡 Yellow / 🔴 Red
- Key metrics: Proof coverage, axiom count, build time
- Trend indicator: ⬆ Improving / ⬌ Stable / ⬇ Degrading

**2. Completeness Charts**
- Stacked bar chart: Proven vs unproven properties by operation
- Line chart: Proof coverage over time (weekly)
- Pie chart: Test coverage by operation

**3. Quality Indicators**
- Gauge: Axiom count (21 target, 23 current)
- Counter: Sorry count (decreasing over time)
- Badge: Cross-stack consistency (✅ 100%)

**4. Performance Trends**
- Line chart: Lean build time over time (detect regressions)
- Horizontal bar: CI duration breakdown (Lean, MSL, Difftest, Axiom check)

**5. Operation Details**
- Table: Per-operation metrics (Registration, Transfer, etc.)
- Click operation → drill down to step-level detail

**Tech stack:**
- Data: JSON exports from collect_metrics.sh
- Frontend: Static HTML + Chart.js (no backend needed)
- Hosting: GitHub Pages (auto-deploy from metrics branch)

**Example HTML snippet:**

```html
<!DOCTYPE html>
<html>
<head>
  <title>CA Verification Dashboard</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
  <h1>Confidential Assets Verification Dashboard</h1>
  
  <div class="overview">
    <div class="metric">
      <h2>Proof Coverage</h2>
      <div class="value">75%</div>
      <div class="trend">⬆ +2% this week</div>
    </div>
    <div class="metric">
      <h2>Axiom Count</h2>
      <div class="value">23</div>
      <div class="trend">⬌ Stable</div>
    </div>
    <div class="metric">
      <h2>Build Time</h2>
      <div class="value">450s</div>
      <div class="trend">⬆ -5s this week</div>
    </div>
  </div>
  
  <canvas id="proofCoverageChart"></canvas>
  
  <script>
    const ctx = document.getElementById('proofCoverageChart').getContext('2d');
    const chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: ['Apr 1', 'Apr 8', 'Apr 15', 'Apr 22'],
        datasets: [{
          label: 'Proof Coverage (%)',
          data: [68, 71, 73, 75],
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: false,
            min: 60,
            max: 100
          }
        }
      }
    });
  </script>
</body>
</html>
```

### 4.3 Slack/Discord Integration

**For team notifications:**

**Weekly summary bot:**

```python
#!/usr/bin/env python3
# post_metrics_to_slack.py

import json
import requests
from datetime import date

# Read latest metrics
with open('metrics/latest/summary.txt') as f:
    summary = f.read()

# Format for Slack
slack_message = {
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"📊 CA Verification Report - {date.today()}"
            }
        },
        {
            "type": "section",
            "fields": [
                {
                    "type": "mrkdwn",
                    "text": f"*Proof Coverage:*\n75% (+2%)"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Sorry Count:*\n50 (-5)"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*Build Time:*\n450s (-5s)"
                },
                {
                    "type": "mrkdwn",
                    "text": f"*CI Duration:*\n15min (-1min)"
                }
            ]
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Progress This Week:*\n• Registration: 95% complete (Phase 1)\n• Transfer PC-chaining: 70% complete\n• Removed 5 sorry placeholders"
            }
        },
        {
            "type": "actions",
            "elements": [
                {
                    "type": "button",
                    "text": {
                        "type": "plain_text",
                        "text": "View Full Dashboard"
                    },
                    "url": "https://verification-dashboard.example.com"
                }
            ]
        }
    ]
}

# Post to Slack
webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
response = requests.post(webhook_url, json=slack_message)

if response.status_code == 200:
    print("✓ Posted to Slack")
else:
    print(f"✗ Failed: {response.text}")
```

**Run weekly:**

```bash
# Cron: Every Monday at 9:30am (after metrics collection)
30 9 * * 1 cd /path/to/repo && python3 scripts/post_metrics_to_slack.py
```

---

## 5. Reporting Workflows

### 5.1 Weekly Progress Report

**Audience:** Engineering team, FV lead.

**Format:** Slack/Discord message + text file.

**Content:**

```markdown
# CA Verification Weekly Report - 2026-04-22

## Summary
✅ Good progress this week: +2% proof coverage, -5 sorry placeholders
⚠️  Build time stable, no regressions

## Metrics
- Proof Coverage: 75% (+2% vs last week)
- Property Coverage: 91% (stable)
- Test Coverage: 87% (+2% vs last week)
- Axiom Count: 23 (stable: 21 perm + 2 temp)
- Sorry Count: 50 (-5 vs last week)
- Build Time: 450s (stable)

## Completed This Week
- Registration Phase 1: 90% → 95% (step lemmas 110-114 complete)
- Transfer PC-chaining: 65% → 70% (success path complete)
- Difftest: Added 2 new edge case tests

## In Progress
- Registration Phase 1: Final 5% (PC 47-52 chaining)
- Transfer Phase 6: PC-chaining for failure paths
- Withdrawal Phase 6: Step lemma library

## Blockers
- None (temporary axioms still waiting for upstream patches, non-blocking)

## Next Week Goals
- Complete Registration Phase 1 (target: 100%)
- Transfer Phase 6: Reach 75% (complete all abort paths)
- Add 5 more difftest cases

## Help Needed
- None
```

**Generation:**

```bash
./scripts/generate_weekly_report.sh > reports/weekly_$(date +%Y-%m-%d).md
```

### 5.2 Monthly Executive Summary

**Audience:** Engineering leadership, product management.

**Format:** PDF or slide deck.

**Content:**

**Slide 1: Executive Summary**
- Verification is 75% complete (on track)
- No critical blockers
- Expected completion: 4 weeks (Phase 6 PC-chaining)

**Slide 2: Progress Chart**
- Line chart: Proof coverage over 3 months (showing steady increase)
- Milestone markers: Phase 1 complete, Phase 6 in progress

**Slide 3: Quality Indicators**
- Axiom count: 23 (within budget, 2 temporary will be removed)
- Cross-stack consistency: 100% (high confidence)
- Regression rate: 2/month (acceptable)

**Slide 4: ROI and Risk**
- Investment: 200 engineer-hours over 3 months
- Value: Formal guarantee of correctness, audit-ready
- Risk mitigation: Prevents production bugs (potential multi-million dollar impact)

**Slide 5: Next Month Plan**
- Complete Phase 6 PC-chaining (all 4 operations)
- Remove temporary axioms (when upstream patches land)
- Prepare for external audit

**Generation:**

```bash
# Export metrics to CSV for charting
./scripts/export_metrics_for_executive_report.sh

# Create slides (manual, using data from CSV)
# Or automate with Python + matplotlib for charts
```

### 5.3 Audit Report Package

**Audience:** External security auditors.

**Format:** Complete documentation bundle.

**Contents:**

```
audit-package/
├── README.md                          (Overview, how to navigate)
├── EXECUTIVE_SUMMARY.md               (High-level claims and confidence)
├── VERIFICATION_CLAIMS.md             (All verified properties)
├── TRUST_BOUNDARIES.md                (What's assumed vs proven)
├── AXIOM_INVENTORY.md                 (All axioms with justifications)
├── metrics/
│   ├── current_metrics.txt            (Latest metrics snapshot)
│   └── historical_trends.csv          (3-month trend data)
├── proofs/
│   ├── Registration/                  (All Lean files)
│   ├── Transfer/
│   ├── Withdrawal/
│   ├── Rotation/
│   └── Normalization/
├── specs/
│   └── confidential_asset.spec.move   (MSL specifications)
├── tests/
│   └── difftest/                      (Test corpus)
└── scripts/
    ├── verify-ca.sh                   (One-command verification)
    └── check_axioms.sh                (Axiom count checker)
```

**Generation:**

```bash
./scripts/prepare_audit_package.sh

# Output:
# Created audit-package/
# Copying proofs... ✓
# Copying specs... ✓
# Copying tests... ✓
# Generating metrics snapshot... ✓
# Creating tarball... ✓
# audit-package.tar.gz ready for distribution
```

**See:** `SECURITY_AUDIT_PREPARATION_GUIDE.md` for complete audit preparation.

---

## 6. Trend Analysis

### 6.1 Proof Coverage Trend

**Goal:** Ensure steady progress toward 100% coverage.

**Expected trend:** Linear increase (~5% per week during active development).

**Chart:**

```
Proof Coverage (%)
100 |                                    * (target)
 90 |                              *
 80 |                        *
 70 |                  *
 60 |            *
 50 |      *
 40 |*
    +----+----+----+----+----+----+----+----
    Week Week Week Week Week Week Week Week
     1    2    3    4    5    6    7    8
```

**Interpretation:**

- **Steady climb:** Good progress, on track
- **Plateau:** Development stalled, investigate blockers
- **Decline:** Regression or scope increase, urgent action needed

**Alerts:**

- ⚠️  If coverage unchanged for 2 weeks → investigate
- 🔴 If coverage decreases → critical, find root cause

### 6.2 Axiom Count Trend

**Goal:** Minimize temporary axioms (permanent axioms should stay constant).

**Expected trend:** Temporary axioms decrease over time (as blockers resolved).

**Chart:**

```
Axiom Count
25 |
   |  Temporary
23 |  ════════╗
   |          ║
21 |          ╚═══════════════  (target: 21 permanent)
   |  Permanent
19 |  ════════════════════════
   +----+----+----+----+----+----
   Jan  Feb  Mar  Apr  May  Jun
```

**Interpretation:**

- **Temporary axioms decreasing:** Good, blockers being resolved
- **Temporary axioms increasing:** Bad, accumulating tech debt
- **Permanent axioms increasing:** Red flag, investigate why

**Alerts:**

- 🔴 If permanent axioms increase → justify or reject
- ⚠️  If temporary axioms increase → review necessity

### 6.3 Build Time Trend

**Goal:** Keep build times within budget, prevent performance regressions.

**Expected trend:** Stable or slight improvement (as proofs optimized).

**Chart:**

```
Build Time (seconds)
600 |                          Budget ─────────────
    |
500 |
    |
400 |  ●───●───●───●───●───●   Actual (stable)
    |
300 |
    +----+----+----+----+----+----
    Week Week Week Week Week Week
     1    2    3    4    5    6
```

**Interpretation:**

- **Stable:** Good, no performance regressions
- **Increasing:** Warning, investigate elaboration bottlenecks
- **Decreasing:** Great, optimizations working

**Alerts:**

- ⚠️  If build time >10% above budget → optimize
- 🔴 If build time >20% above budget → urgent, likely blocking dev

### 6.4 Regression Frequency Trend

**Goal:** Minimize proof breakages over time (proofs should stabilize).

**Expected trend:** Decreasing (as proofs mature, fewer changes trigger breakage).

**Chart:**

```
Regressions per Month
10 |  ●
   |
 8 |
   |      ●
 6 |
   |          ●
 4 |
   |              ●
 2 |                  ●───●  (target: ≤1)
   |
 0 +----+----+----+----+----+----
   Jan  Feb  Mar  Apr  May  Jun
```

**Interpretation:**

- **Decreasing:** Good, proofs stabilizing
- **Stable at low level:** Good, mature verification
- **Increasing:** Bad, instability or frequent changes

**Alerts:**

- ⚠️  If regressions >3/month → investigate root causes
- 🔴 If regressions >5/month → major instability, urgent fix needed

---

## 7. Alerts and Thresholds

### 7.1 Alert Definitions

**Green 🟢 (Healthy):**
- Proof coverage increasing steadily
- Axiom count stable (only permanent axioms)
- Build time within budget
- Zero cross-stack inconsistencies
- Regressions ≤1/month

**Yellow 🟡 (Warning):**
- Proof coverage plateau (unchanged for 2 weeks)
- Temporary axioms >2
- Build time 10-20% above budget
- 1-2 cross-stack inconsistencies
- Regressions 2-3/month

**Red 🔴 (Critical):**
- Proof coverage decreasing
- Permanent axioms increased
- Build time >20% above budget
- >2 cross-stack inconsistencies
- Regressions >3/month

### 7.2 Alert Routing

**Alert severity → notification channel:**

| Severity | Notification | Action | Response Time |
|----------|--------------|--------|---------------|
| 🟢 Green | Weekly report | None | N/A |
| 🟡 Yellow | Slack mention | Investigate | 1 week |
| 🔴 Red | Slack @channel + email | Urgent fix | 24 hours |

**Example alerts:**

**Yellow alert:**

```
⚠️  [CA Verification Alert - Yellow]

Metric: Proof Coverage
Status: Plateau detected (unchanged for 2 weeks: 75%)
Expected: +5% per week during active development
Action: Review blockers, adjust resources if needed
Owner: @fv-lead
```

**Red alert:**

```
🔴 [CA Verification Alert - RED]

Metric: Cross-Stack Consistency
Status: 3 abort codes mismatched between MSL and Lean
Impact: Verification unsound, production risk
Action: URGENT - halt other work, fix inconsistencies immediately
Owner: @fv-lead @engineering-lead
```

### 7.3 Automatic Alerts in CI

**CI workflow triggers alerts:**

```yaml
# .github/workflows/verification-alerts.yaml

name: Verification Alerts

on:
  schedule:
    - cron: '0 9 * * 1'  # Weekly on Monday 9am

jobs:
  check_metrics:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Collect Metrics
        run: ./scripts/collect_metrics.sh
      
      - name: Check Thresholds
        run: |
          # Check proof coverage plateau
          current=$(cat metrics/latest/proof_coverage.txt | grep -oP '\d+')
          last_week=$(cat metrics/$(date -d '7 days ago' +%Y-%m-%d)/proof_coverage.txt | grep -oP '\d+')
          
          if [ "$current" -eq "$last_week" ]; then
            echo "⚠️  ALERT: Proof coverage plateau detected"
            echo "alert=yellow" >> $GITHUB_ENV
          fi
          
          # Check axiom count increase
          current_axioms=$(./scripts/check_axioms.sh | wc -l)
          if [ "$current_axioms" -gt 23 ]; then
            echo "🔴 ALERT: Axiom count increased"
            echo "alert=red" >> $GITHUB_ENV
          fi
      
      - name: Post Alert to Slack
        if: env.alert != ''
        run: |
          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"${{ env.alert }} alert in CA verification"}' \
            ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 8. Integration with CI

### 8.1 Metrics in CI Pipeline

**Add metrics collection to verification CI:**

```yaml
# .github/workflows/verification.yaml

name: Verification Suite

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Verification
        run: ./audit/verify-ca.sh
      
      - name: Collect Metrics
        if: always()
        run: ./scripts/collect_metrics.sh
      
      - name: Upload Metrics
        uses: actions/upload-artifact@v3
        with:
          name: verification-metrics
          path: metrics/latest/
      
      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const summary = fs.readFileSync('metrics/latest/summary.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Verification Metrics\n\n\`\`\`\n${summary}\n\`\`\``
            });
```

**Result:** Every PR shows verification metrics in comments.

### 8.2 Metrics Visualization in CI

**GitHub Actions summary:**

```yaml
- name: Generate Summary
  if: always()
  run: |
    cat >> $GITHUB_STEP_SUMMARY <<EOF
    ## Verification Metrics
    
    | Metric | Value | Trend |
    |--------|-------|-------|
    | Proof Coverage | 75% | ⬆ +2% |
    | Axiom Count | 23 | ⬌ Stable |
    | Build Time | 450s | ⬆ -5s |
    | Test Coverage | 87% | ⬆ +2% |
    
    [View Full Dashboard](https://verification-dashboard.example.com)
    EOF
```

**Result:** Metrics visible directly in GitHub Actions UI.

### 8.3 Fail CI on Metric Thresholds

**Enforce quality gates:**

```yaml
- name: Check Quality Gates
  run: |
    # Fail if axiom count exceeds budget
    if [ $(./scripts/check_axioms.sh | wc -l) -gt 23 ]; then
      echo "❌ FAILED: Axiom count exceeds budget (23)"
      exit 1
    fi
    
    # Fail if cross-stack consistency broken
    if ! ./scripts/check_abort_code_consistency.sh; then
      echo "❌ FAILED: Abort codes inconsistent across stacks"
      exit 1
    fi
    
    # Fail if build time exceeds budget by >20%
    build_time=$(grep "real" metrics/latest/build_time.txt | awk '{print $2}')
    if [ "$build_time" -gt 720 ]; then  # 600s budget + 20%
      echo "❌ FAILED: Build time exceeds budget by >20%"
      exit 1
    fi
    
    echo "✅ All quality gates passed"
```

**Result:** CI fails if metrics degrade beyond thresholds.

---

**END OF GUIDE**

**Key takeaways:**

1. **Metrics make verification visible** — progress, quality, performance all trackable
2. **Automate collection** — scripts run weekly, no manual effort
3. **Dashboard shows health at a glance** — green/yellow/red status
4. **Trends reveal issues early** — plateau, regression, debt accumulation
5. **Alerts drive action** — yellow = investigate, red = urgent fix
6. **Integrate with CI** — metrics on every build, quality gates enforced
7. **Report regularly** — weekly team updates, monthly exec summaries, audit packages

**Next steps:**

- Set up automated metric collection (cron job)
- Create text-based dashboard (generate_dashboard.sh)
- Configure Slack integration (weekly reports)
- Add CI quality gates (fail on threshold violations)
- Track trends over time (accumulate historical.csv)

**Questions?** See `VERIFICATION_MAINTENANCE_HANDBOOK.md` for operational procedures.
