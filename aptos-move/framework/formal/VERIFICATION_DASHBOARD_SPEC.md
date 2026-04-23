# Verification Dashboard Specification

**Purpose:** Real-time visibility into CA formal verification health  
**Audience:** Developers, reviewers, project managers  
**Status:** Design specification (implementation in Phase 7)

This document specifies a comprehensive verification dashboard that aggregates metrics from all three verification stacks (Lean, Move Prover, difftest) and provides actionable insights.

---

## Table of Contents

1. [Overview](#overview)
2. [Data Sources](#data-sources)
3. [Metrics & KPIs](#metrics--kpis)
4. [Dashboard Sections](#dashboard-sections)
5. [Implementation Plan](#implementation-plan)
6. [Technical Architecture](#technical-architecture)
7. [Mockups](#mockups)

---

## Overview

### Goals

1. **Single source of truth** for verification status across all stacks
2. **Early warning system** for regressions (performance, coverage, axiom drift)
3. **Progress tracking** toward phase completion milestones
4. **Team transparency** (stakeholders can check status without asking)

### Non-Goals

- **Not a CI dashboard** (GitHub Actions UI handles that)
- **Not a code browser** (VSCode/GitHub handles that)
- **Not a project management tool** (Linear/Jira handles that)

### Key Features

- **Real-time metrics** (updated on every CI run)
- **Historical trends** (30-day / 90-day / 1-year views)
- **Drill-down capability** (summary → operation → file → theorem)
- **Export/sharing** (Markdown report, JSON API, embeddable badges)

---

## Data Sources

### 1. Lean Verification

**Source:** `lake build` output + `check_axioms.sh` + build timings

**Metrics collected:**
- Theorem count (total, per operation, per file)
- Sorry count (outstanding work)
- Axiom count (trust base size)
- Build time (per file, full tree)
- File size (lines of code)
- Proof complexity (heartbeats, if available)

**Collection method:**
- Parse `lake build` output for timings
- Run `check_axioms.sh` for axiom inventory
- Count theorems via `grep "^theorem " *.lean`
- Count sorry's via `grep "sorry" *.lean`

### 2. Move Prover Verification

**Source:** `movement move prove` output + spec file analysis

**Metrics collected:**
- Spec block count (total, per module)
- VC count (verification conditions generated)
- VC status (proved, failed, timeout)
- Prover time (per function, per module)
- Pragma count (opaque, verify=false, aborts_if_is_partial)
- Spec coverage (functions with specs vs total functions)

**Collection method:**
- Parse `movement move prove --json` output
- Analyze `.spec.move` files for pragma usage
- Count functions with specs vs total functions in `.move` files

### 3. Difftest Verification

**Source:** Difftest corpus + `difftest.sh` output

**Metrics collected:**
- Test case count (total, per operation, per type)
- Pass rate (passing tests / total tests)
- Coverage (happy path, error path, edge cases)
- Test execution time
- New tests added (per week/month)

**Collection method:**
- Parse corpus JSON files for test count
- Parse `difftest.sh` output for pass/fail results
- Track git history for test addition rate

### 4. Phase Progress

**Source:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md` §0 Progress Tracker

**Metrics collected:**
- Phase status (pending, in progress, done, blocked)
- Measured cost vs budget (build time, theorem count, etc.)
- Blockers (ristretto255 patches, upstream FA specs, etc.)
- Completion percentage (per phase, overall)

**Collection method:**
- Parse unified plan markdown table (§0)
- Extract status marks (☐, 🟡, ✅, ⚠️)
- Extract measured cost values

---

## Metrics & KPIs

### Top-Level KPIs (Dashboard Hero Section)

| KPI | Current | Target | Status | Description |
|-----|---------|--------|--------|-------------|
| **Overall Completion** | 72% | 100% | 🟡 In Progress | Weighted average of all phases |
| **Lean Theorems** | 197 | 250 | ✅ On Track | Total proved theorems (excl sorry) |
| **Axiom Count** | 23 | ≤25 | ✅ Within Budget | Total axioms (incl crypto) |
| **Build Time** | 3.2s | ≤180s | ✅ Fast | Full CA Lean tree (cold build) |
| **Difftest Pass Rate** | 87/87 | 100% | ✅ All Pass | VM ↔ Model agreement |
| **MSL Spec Coverage** | 88% | 100% | 🟡 In Progress | Functions with specs |

**Status icons:**
- ✅ On track (within 10% of target)
- 🟡 In progress (10-30% from target)
- ⚠️ At risk (30-50% from target)
- ❌ Blocked (>50% from target or external blocker)

### Per-Stack Metrics

**Lean Stack:**
- Theorem count (trend chart: last 30 days)
- Sorry count (target: 0)
- Axiom count (target: ≤25)
- Build time per file (bar chart, budget line at 180s)
- Full tree build time (trend chart: last 90 days)
- Lines of code (total, per module)

**Move Prover Stack:**
- Spec block count
- VC proved / total VC (percentage)
- Prover time per module (bar chart, budget line at 60s)
- Pragma usage breakdown (pie chart: opaque, verify=false, etc.)
- Spec coverage (functions with specs / total functions)

**Difftest Stack:**
- Test case count (stacked bar: happy path, error path, edge cases)
- Pass rate (trend chart: last 30 days)
- Coverage gaps (per operation)
- Test execution time (total, per operation)

### Per-Operation Metrics

**For each operation (Register, Transfer, Withdraw, Normalize, Rotation):**

| Metric | Lean | Move Prover | Difftest | Notes |
|--------|------|-------------|----------|-------|
| **Status** | ✅ Done | 🟡 In Progress | ✅ Pass | Overall health |
| **Theorems** | 55 | N/A | N/A | Proved theorems |
| **Spec blocks** | N/A | 12 | N/A | MSL spec coverage |
| **Tests** | N/A | N/A | 15 | Difftest corpus size |
| **Build time** | 0.5s | 1.2s | 0.3s | Time to verify |
| **Blockers** | None | ristretto255 | None | External dependencies |

---

## Dashboard Sections

### Section 1: Hero / Overview (Above the Fold)

**Layout:** Single row, 6 KPI cards

```
┌─────────────────────────────────────────────────────────────────┐
│  Overall Completion    Lean Theorems     Axiom Count            │
│  ████████░░ 72%        197 / 250         23 / 25                │
│  🟡 In Progress        ✅ On Track        ✅ Within Budget       │
├─────────────────────────────────────────────────────────────────┤
│  Build Time            Difftest Pass     MSL Coverage           │
│  3.2s / 180s           87 / 87           88%                    │
│  ✅ Fast               ✅ All Pass        🟡 In Progress         │
└─────────────────────────────────────────────────────────────────┘
```

**Action buttons:**
- "View Details" (scroll to stack sections)
- "Download Report" (generate Markdown snapshot)
- "Export JSON" (API access)

### Section 2: Phase Progress Tracker

**Layout:** Horizontal progress bar + phase cards

```
┌─────────────────────────────────────────────────────────────────┐
│  Phase Progress                                                 │
│  ████████████████████████░░░░ 72% Complete                      │
│                                                                 │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐       │
│  │Phase 0 │ │Phase 1 │ │Phase 2 │ │Phase 3 │ │Phase 4 │       │
│  │   ✅   │ │   🟡   │ │   🟡   │ │   🟡   │ │   ✅   │       │
│  │ Done   │ │ 90%    │ │ 60%    │ │ 50%    │ │ Done   │       │
│  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘       │
│  ... (Phases 5-8)                                               │
└─────────────────────────────────────────────────────────────────┘
```

**Per-phase card (on hover/click):**
- Status (pending, in progress, done, blocked)
- Completion percentage
- Measured cost vs budget
- Blockers (if any)
- Last updated date
- Link to plan section (§6)

### Section 3: Lean Verification Stack

**Layout:** 2 columns (metrics + charts)

```
┌──────────────────────────┬──────────────────────────────────────┐
│ **Metrics**              │ **Charts**                           │
│ - Theorems: 197          │ [Theorem Count Trend] (30-day)       │
│ - Sorry: 0               │ ████████████                         │
│ - Axioms: 23             │                                      │
│ - Build time: 3.2s       │ [Build Time by File] (bar chart)     │
│ - LoC: 12,500            │ ████                                 │
│                          │ ████████                             │
│ **Per-operation**        │ ███                                  │
│ - Registration: 0.5s     │                                      │
│ - Transfer: 0.7s         │ [Axiom Breakdown] (pie chart)        │
│ - Withdrawal: 0.5s       │ 🔵 Crypto (18)                       │
│ - Normalization: 0.5s    │ 🟢 Temp (1)                          │
│ - Rotation: 0.5s         │ 🟡 Other (4)                         │
└──────────────────────────┴──────────────────────────────────────┘
```

**Drill-down:**
- Click operation → show per-file breakdown
- Click file → show theorem list + build time
- Click theorem → show source location + axioms used

### Section 4: Move Prover Stack

**Layout:** Similar to Lean stack

```
┌──────────────────────────┬──────────────────────────────────────┐
│ **Metrics**              │ **Charts**                           │
│ - Spec blocks: 88        │ [VC Status] (stacked bar)            │
│ - VC proved: 0 / 0       │ ████████████                         │
│   (blocked on ristretto) │ 🟢 Proved 🔴 Failed 🟡 Timeout        │
│ - Prover time: 5.2s      │                                      │
│ - Pragma opaque: 89      │ [Spec Coverage by Module] (bar)      │
│                          │ ████████░░ 88%                       │
│ **Per-module**           │                                      │
│ - confidential_asset     │ [Pragma Usage] (pie chart)           │
│   12 specs, 1.2s         │ 🔵 Opaque (89)                       │
│ - confidential_balance   │ 🟢 Verify=false (1)                  │
│   8 specs, 0.8s          │                                      │
└──────────────────────────┴──────────────────────────────────────┘
```

**Status indicator:**
- If blocked (ristretto255), show blocker banner
- Link to blocker issue (GitHub or plan §8)

### Section 5: Difftest Stack

**Layout:** Test matrix + pass rate trend

```
┌──────────────────────────┬──────────────────────────────────────┐
│ **Metrics**              │ **Charts**                           │
│ - Total tests: 87        │ [Pass Rate Trend] (30-day)           │
│ - Pass rate: 100%        │ ████████████ 100%                    │
│ - Coverage:              │                                      │
│   Happy: 15              │ [Test Count by Operation] (stacked)  │
│   Error: 48              │ ████████                             │
│   Edge: 24               │ ███████                              │
│                          │ ██████                               │
│ **Per-operation**        │ █████                                │
│ - Register: 15 tests     │ ████                                 │
│ - Transfer: 18 tests     │                                      │
│ - Withdraw: 17 tests     │ [Coverage Gaps] (heatmap)            │
│ - Normalize: 18 tests    │ Op    | Happy | Error | Edge         │
│ - Rotation: 19 tests     │ Reg   |  ✅   |  ✅   |  ✅          │
│                          │ Xfer  |  ✅   |  ✅   |  🟡          │
└──────────────────────────┴──────────────────────────────────────┘
```

**Coverage heatmap:**
- ✅ Green: On target (within goal range)
- 🟡 Yellow: Below goal (but >50%)
- 🔴 Red: Missing (0 tests or <50% of goal)

### Section 6: Historical Trends

**Layout:** 3-4 key charts, selectable time range (30d / 90d / 1y)

```
┌─────────────────────────────────────────────────────────────────┐
│  Time Range: [30d] [90d] [1y]                                   │
├─────────────────────────────────────────────────────────────────┤
│  [Theorem Count Over Time]                                      │
│  200 ┤                                              ⬤ (197)     │
│  150 ┤                                   ⬤                       │
│  100 ┤                        ⬤                                  │
│   50 ┤             ⬤                                             │
│    0 └──────────────────────────────────────────────────────    │
│      Jan      Feb      Mar      Apr                             │
├─────────────────────────────────────────────────────────────────┤
│  [Build Time Trend]                                             │
│   10s┤                                                           │
│    5s┤                                                           │
│    3s┤ ──────────────────────────────────────────── ⬤ (3.2s)    │
│    0s└──────────────────────────────────────────────────────    │
│      Jan      Feb      Mar      Apr                             │
└─────────────────────────────────────────────────────────────────┘
```

**Charts:**
1. Theorem count over time (line chart)
2. Build time over time (line chart with budget line)
3. Difftest pass rate over time (line chart)
4. Axiom count over time (line chart)

### Section 7: Recent Activity Feed

**Layout:** Timeline of recent events

```
┌─────────────────────────────────────────────────────────────────┐
│  Recent Activity                                                │
├─────────────────────────────────────────────────────────────────┤
│  ⬤ 2 hours ago                                                  │
│    Phase 4 Transfer proof complete (24 PCs, 0.7s build)         │
│    Commit: e9f7b29                                              │
│                                                                 │
│  ⬤ 1 day ago                                                    │
│    Added 12 new difftest cases (Withdrawal error paths)         │
│    Coverage: 88% → 92%                                          │
│    Commit: ee81d52                                              │
│                                                                 │
│  ⬤ 3 days ago                                                   │
│    Performance baseline updated (3.2s → 3.0s)                   │
│    Speedup: 6.7%                                                │
│    Commit: 3241960                                              │
│                                                                 │
│  [View All Activity]                                            │
└─────────────────────────────────────────────────────────────────┘
```

**Event types:**
- Theorem added/completed
- Performance change (±10% or more)
- Difftest coverage change
- Phase status change
- Blocker resolved
- Axiom added/removed

---

## Implementation Plan

### Phase 7.1: Data Collection Scripts (Week 1-2)

**Deliverables:**
- `scripts/collect_lean_metrics.sh` — theorem count, sorry count, axiom count, build time
- `scripts/collect_msl_metrics.sh` — spec count, VC status, pragma usage
- `scripts/collect_difftest_metrics.sh` — test count, pass rate, coverage gaps
- `scripts/collect_phase_progress.sh` — parse unified plan §0
- `scripts/aggregate_metrics.sh` — combine all into single JSON output

**Output format:** JSON
```json
{
  "timestamp": "2026-04-22T17:00:00Z",
  "commit": "e9f7b29dde",
  "branch": "lean-fv",
  "lean": {
    "theorems": 197,
    "sorry": 0,
    "axioms": 23,
    "build_time_tree": 3.2,
    "build_time_per_file": { "Registration": 0.5, ... }
  },
  "msl": {
    "spec_blocks": 88,
    "vc_proved": 0,
    "vc_total": 0,
    "pragma_opaque": 89,
    "spec_coverage": 0.88
  },
  "difftest": {
    "tests_total": 87,
    "tests_pass": 87,
    "tests_fail": 0,
    "coverage": { "happy": 15, "error": 48, "edge": 24 }
  },
  "phases": {
    "0": { "status": "done", "completion": 1.0 },
    "1": { "status": "in_progress", "completion": 0.9 },
    ...
  }
}
```

### Phase 7.2: Historical Storage (Week 2)

**Deliverables:**
- `audit/metrics_history/` directory (git-tracked)
- `scripts/store_metrics.sh` — append current metrics to `metrics_YYYY_MM.jsonl`
- CI integration: run after every successful build

**Storage format:** JSONL (one JSON object per line, one file per month)
```
metrics_2026_04.jsonl
metrics_2026_03.jsonl
metrics_2026_02.jsonl
...
```

**Retention:** Keep 1 year of history (12 files × ~30 entries = ~360 data points).

### Phase 7.3: Dashboard Generation (Week 3)

**Deliverables:**
- `scripts/generate_dashboard.sh` — generate HTML dashboard from metrics
- `audit/dashboard.html` — static HTML (no server required)
- `audit/dashboard.css` — styling (clean, mobile-responsive)
- `audit/dashboard.js` — charts (using Chart.js or similar lightweight library)

**Features:**
- All sections from §4 (hero, phase progress, per-stack metrics, trends, activity feed)
- Drilldown (click operation → see details)
- Export (download Markdown report, export JSON)
- Auto-refresh (if hosted, check for new metrics every 5 min)

**Deployment:**
- Option 1: Static file in repo (`audit/dashboard.html`) — open in browser
- Option 2: GitHub Pages — publish on every commit
- Option 3: Self-hosted — upload to internal web server

### Phase 7.4: CI Integration (Week 4)

**Deliverables:**
- `.github/workflows/metrics-collection.yaml` — run metrics collection on every CI build
- Store metrics to `audit/metrics_history/`
- Generate dashboard and commit to repo (or publish to GitHub Pages)
- Badge generation (for README)

**Badges (embeddable in README):**
```markdown
![Lean Theorems](https://img.shields.io/badge/Theorems-197-green)
![Build Time](https://img.shields.io/badge/Build%20Time-3.2s-green)
![Difftest Pass](https://img.shields.io/badge/Difftest-87%2F87-green)
```

---

## Technical Architecture

### Tech Stack

**Data collection:**
- Bash scripts (parse CLI output, grep files)
- jq (JSON processing)
- Python (optional, for complex parsing)

**Storage:**
- Git-tracked JSONL files (`audit/metrics_history/`)
- No database required (keep it simple)

**Dashboard:**
- Static HTML + CSS + JS (no server-side rendering)
- Chart.js or similar for visualizations
- No frameworks (vanilla JS for simplicity)

**Hosting:**
- Option 1: Local file (open `dashboard.html` in browser)
- Option 2: GitHub Pages (static site, auto-deploy)
- Option 3: Self-hosted web server

### Data Flow

```
┌────────────────────────────────────────────────────────────┐
│  CI Build                                                  │
│  ├─ lake build                                             │
│  ├─ movement move prove                                    │
│  ├─ ./difftest.sh                                          │
│  └─ CI pass ✅                                             │
└────────────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────────────┐
│  Metrics Collection (scripts/aggregate_metrics.sh)         │
│  ├─ collect_lean_metrics.sh                                │
│  ├─ collect_msl_metrics.sh                                 │
│  ├─ collect_difftest_metrics.sh                            │
│  └─ collect_phase_progress.sh                              │
│  → Output: metrics.json                                    │
└────────────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────────────┐
│  Storage (scripts/store_metrics.sh)                        │
│  ├─ Append to metrics_YYYY_MM.jsonl                        │
│  └─ Commit to repo                                         │
└────────────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────────────┐
│  Dashboard Generation (scripts/generate_dashboard.sh)      │
│  ├─ Load latest metrics.json                               │
│  ├─ Load metrics_history/*.jsonl (for trends)              │
│  ├─ Generate HTML (dashboard.html)                         │
│  └─ Commit to repo or publish to GitHub Pages              │
└────────────────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────────────────┐
│  Dashboard (audit/dashboard.html)                          │
│  ├─ Hero section (KPIs)                                    │
│  ├─ Phase progress                                         │
│  ├─ Per-stack metrics                                      │
│  ├─ Historical trends                                      │
│  └─ Activity feed                                          │
└────────────────────────────────────────────────────────────┘
```

### API (Optional)

If hosted, provide JSON API endpoints:

- `GET /api/metrics` — latest metrics (metrics.json)
- `GET /api/metrics/history` — historical data (all JSONL files merged)
- `GET /api/metrics/operation/:name` — per-operation metrics
- `GET /api/metrics/phase/:id` — per-phase metrics

---

## Mockups

### Mockup 1: Hero Section (Desktop)

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Confidential Assets Formal Verification Dashboard                      │
│  Last Updated: 2026-04-22 17:00 UTC • Branch: lean-fv • Commit: e9f7b29 │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │   Overall    │  │     Lean     │  │    Axiom     │                  │
│  │  Completion  │  │   Theorems   │  │    Count     │                  │
│  │              │  │              │  │              │                  │
│  │  ████████░░  │  │   197 / 250  │  │   23 / 25    │                  │
│  │     72%      │  │              │  │              │                  │
│  │              │  │  ✅ On Track │  │ ✅ Within    │                  │
│  │ 🟡 In Prog.  │  │              │  │    Budget    │                  │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                  │
│  │  Build Time  │  │   Difftest   │  │     MSL      │                  │
│  │              │  │  Pass Rate   │  │   Coverage   │                  │
│  │              │  │              │  │              │                  │
│  │  3.2s / 180s │  │   87 / 87    │  │     88%      │                  │
│  │              │  │              │  │              │                  │
│  │   ✅ Fast    │  │ ✅ All Pass  │  │ 🟡 In Prog.  │                  │
│  │              │  │              │  │              │                  │
│  └──────────────┘  └──────────────┘  └──────────────┘                  │
│                                                                          │
│  [View Details ↓]  [Download Report]  [Export JSON]                    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

### Mockup 2: Phase Progress (Mobile)

```
┌───────────────────────────────────┐
│  Phase Progress                   │
│  ████████████████████░░░░ 72%     │
├───────────────────────────────────┤
│  ┌───────────┐                    │
│  │  Phase 0  │                    │
│  │  Unblock  │                    │
│  │   ✅ Done │                    │
│  └───────────┘                    │
│                                   │
│  ┌───────────┐                    │
│  │  Phase 1  │                    │
│  │  Registr. │                    │
│  │  🟡 90%   │                    │
│  │  Blocker: │                    │
│  │  Singleton│                    │
│  └───────────┘                    │
│                                   │
│  ┌───────────┐                    │
│  │  Phase 2  │                    │
│  │  MSL Int. │                    │
│  │  🟡 60%   │                    │
│  │  Blocker: │                    │
│  │  rist255  │                    │
│  └───────────┘                    │
│                                   │
│  ... (more phases)                │
└───────────────────────────────────┘
```

---

## Conclusion

**Dashboard value:**
- **Visibility:** Single source of truth for verification health
- **Accountability:** Clear metrics, no ambiguity on status
- **Early warning:** Trends show regressions before they become critical
- **Stakeholder communication:** Share dashboard link instead of status emails

**Implementation effort:**
- Phase 7.1: 1-2 weeks (data collection scripts)
- Phase 7.2: 3-5 days (historical storage)
- Phase 7.3: 1-2 weeks (dashboard generation)
- Phase 7.4: 3-5 days (CI integration)
- **Total: 4-6 weeks** (part of Phase 7 budget)

**Maintenance:**
- Automated data collection (CI)
- Quarterly review (verify metrics still relevant)
- Update as new phases/operations added

---

**File:** `VERIFICATION_DASHBOARD_SPEC.md`  
**Lines:** ~650  
**Purpose:** Design specification for real-time verification metrics dashboard  
**Audience:** Developers implementing Phase 7, stakeholders reviewing verification status  
**Cross-references:** `CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`, `scripts/generate_verification_report.sh`
