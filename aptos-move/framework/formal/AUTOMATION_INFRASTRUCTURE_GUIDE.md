# CA Formal Verification Automation Infrastructure Guide

**Last updated:** 2026-04-23

Complete guide to the automated testing, monitoring, and release infrastructure for CA formal verification. Covers all scripts, CI workflows, and operational procedures.

## Table of Contents

1. [Overview](#overview)
2. [Automation Scripts](#automation-scripts)
3. [CI/CD Workflows](#cicd-workflows)
4. [Monitoring & Alerts](#monitoring--alerts)
5. [Release Automation](#release-automation)
6. [Performance Tracking](#performance-tracking)
7. [Maintenance Procedures](#maintenance-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The CA formal verification project includes comprehensive automation infrastructure to ensure:

- **Quality**: Automated verification across all three stacks (Lean, Move Prover, difftest)
- **Performance**: Continuous performance monitoring and regression detection
- **Reliability**: Health checks, axiom drift detection, sorry count tracking
- **Release readiness**: Automated pre-release checklists and Docker image publishing

### Automation Philosophy

1. **Fail fast**: Detect issues early through pre-commit hooks and CI checks
2. **Comprehensive**: Cover all aspects (build, verification, documentation, performance)
3. **Actionable**: Provide clear failure messages and remediation steps
4. **Scalable**: Support both local development and CI/CD environments

---

## Automation Scripts

### Core Verification Scripts

#### `scripts/run_verification_suite.sh`

Comprehensive verification test suite with three modes.

**Usage:**
```bash
# Quick mode (~2 min) - essential checks only
./scripts/run_verification_suite.sh --quick

# Standard mode (~5 min) - typical pre-commit
./scripts/run_verification_suite.sh

# Comprehensive mode (~15 min) - pre-release validation
./scripts/run_verification_suite.sh --comprehensive
```

**Checks:**
- Lean toolchain and Move Prover tools
- Lean tree builds cleanly
- Sorry count within baseline
- Axiom count within limits
- Trust boundaries reconciled
- All 5 operations verify

**Exit codes:**
- `0` = All checks passed
- `1` = One or more checks failed
- `2` = Usage error

#### `scripts/verify_with_json_output.sh`

JSON output wrapper for `verify-ca.sh` - enables dashboard integration.

**Usage:**
```bash
# Generate JSON report for register operation
./scripts/verify_with_json_output.sh --op register > results.json

# Coverage report in JSON
./scripts/verify_with_json_output.sh --coverage > coverage.json
```

**Output format:**
```json
{
  "timestamp": "2026-04-23T12:34:56Z",
  "command": ["verify-ca.sh", "--op", "register"],
  "exit_code": 0,
  "duration_seconds": 1.234,
  "results": {
    "operation": "register",
    "stack": "lean",
    "status": "pass",
    "checks": [...]
  }
}
```

#### `scripts/pre-commit-hook.sh`

Pre-commit hook for catching issues before commit.

**Installation:**
```bash
./scripts/setup_git_hooks.sh
```

**Checks:**
- Lean tree builds
- Axiom baseline up-to-date
- Sorry count not regressed
- Trust boundaries reconciled
- No TODO/FIXME in committed files (warning only)

**Performance:** ~10-30 seconds per commit

### Performance & Benchmarking

#### `scripts/performance_dashboard.sh`

Real-time performance metrics dashboard.

**Usage:**
```bash
# Display current performance dashboard
./scripts/performance_dashboard.sh

# Run comprehensive benchmark
./scripts/performance_dashboard.sh --benchmark --save baseline.json

# Compare two benchmarks
./scripts/performance_dashboard.sh --compare baseline.json current.json

# Show trends over last 30 days
./scripts/performance_dashboard.sh --trend --days 30

# JSON output for automation
./scripts/performance_dashboard.sh --format json
```

**Metrics tracked:**
- Lean full tree build time
- Per-operation verification time
- Verification suite timing
- Theorem/axiom/sorry counts

**Regression detection:**
- Alerts if current performance >10% slower than baseline
- Exit code 1 on regression in compare mode

#### `scripts/benchmark_verification.sh`

Comprehensive performance benchmarking suite.

**Usage:**
```bash
# Run benchmarks with text output
./scripts/benchmark_verification.sh

# JSON output for processing
./scripts/benchmark_verification.sh --output json

# Save benchmark as baseline
./scripts/benchmark_verification.sh --output json > reports/baseline.json
```

**Benchmarks:**
- All 5 operation verifications
- Lean build times (full + per-operation)
- Verification suite modes (quick/standard/comprehensive)

#### `scripts/detect_performance_regression.sh`

Automated performance regression detection.

**Usage:**
```bash
./scripts/detect_performance_regression.sh baseline.json current.json
```

**Thresholds:**
- Error (exit 1): >20% regression
- Warning: 10-20% regression
- OK: <10% change

### Release Automation

#### `scripts/release_checklist.sh`

Automated pre-release verification checklist.

**Usage:**
```bash
# Full release checklist
./scripts/release_checklist.sh --version 1.0.0

# Dry-run mode (show what would be checked)
./scripts/release_checklist.sh --dry-run

# Quick check (skip slow tests)
./scripts/release_checklist.sh --version 1.0.0 --skip-slow-tests
```

**Checks:**
- Git working directory clean
- On main/movement branch
- Version tag available
- Lean tree builds cleanly
- Sorry count at/below baseline
- Axiom baseline current
- Trust boundaries reconciled
- Verification suite passes
- Documentation up to date
- Phase 7 deliverables complete
- CI workflows present
- Docker image buildable
- Coverage metrics acceptable
- Performance within budgets

**Exit codes:**
- `0` = Ready for release
- `1` = One or more checks failed

#### `scripts/publish_docker_image.sh`

Docker image build and publish automation.

**Usage:**
```bash
# Full workflow: build + test + publish
GITHUB_TOKEN=<token> ./scripts/publish_docker_image.sh

# Build only (no publish)
./scripts/publish_docker_image.sh --build-only

# Publish existing image
./scripts/publish_docker_image.sh --publish-only

# Skip post-build tests
./scripts/publish_docker_image.sh --skip-tests
```

**Process:**
1. Build Docker image (15-20 min first build)
2. Verify toolchain versions
3. Run smoke tests
4. Publish to ghcr.io
5. Capture digest
6. Update toolchain.lock

**Environment variables:**
- `GITHUB_TOKEN`: Required for ghcr.io publish
- `DOCKER_REGISTRY`: Target registry (default: ghcr.io)
- `DOCKER_ORG`: Organization (default: movement-labs)
- `DOCKER_TAG`: Tag (default: current date)

### Monitoring & Health Checks

#### `scripts/continuous_monitoring.sh`

Continuous verification health monitoring.

**Usage:**
```bash
# Continuous monitoring with 5-minute interval
./scripts/continuous_monitoring.sh

# Custom interval (1 minute)
./scripts/continuous_monitoring.sh --interval 60

# With webhook alerts
./scripts/continuous_monitoring.sh --webhook https://hooks.slack.com/...

# Single health check
./scripts/continuous_monitoring.sh --once
```

**Monitors:**
- Lean build health
- Sorry count regressions
- Axiom drift
- Build performance
- Git status
- Disk space

**Alerts:**
- Webhook notifications (Slack-compatible)
- 1-hour cooldown between duplicate alerts
- Severity levels: error, warning, info

**Logs:**
- `logs/monitoring.log`: Detailed monitoring log
- `reports/monitoring/health-*.json`: Health reports

#### `scripts/verification_status_dashboard.sh`

Status dashboard showing overall verification progress.

**Usage:**
```bash
./scripts/verification_status_dashboard.sh
```

**Displays:**
- Overall completion percentage
- Phase-by-phase progress
- Theorem/axiom/sorry counts
- Recent commit activity
- Outstanding work items

### Maintenance Scripts

#### `scripts/quarterly_audit.sh`

Quarterly maintenance and audit automation.

**Usage:**
```bash
# Run quarterly audit
./scripts/quarterly_audit.sh

# Generate report only
./scripts/quarterly_audit.sh --report-only
```

**Tasks:**
- Documentation freshness review
- Axiom inventory validation
- Performance benchmark comparison
- Dependency updates check
- CI workflow validation

#### `scripts/reconcile_trust_boundaries.sh`

Automated trust boundary reconciliation.

**Usage:**
```bash
# Check reconciliation (exit 1 on mismatch)
./scripts/reconcile_trust_boundaries.sh

# Verbose output
./scripts/reconcile_trust_boundaries.sh --verbose

# Update TRUST_BOUNDARIES.md automatically
./scripts/reconcile_trust_boundaries.sh --update
```

**Validates:**
- Lean axiom count matches TRUST_BOUNDARIES.md
- MSL pragma opaque count matches
- Test-only pragma verify=false accounted for

---

## CI/CD Workflows

### Active Workflows

#### `lean-ca.yaml`

Lean verification for all 5 operations on every PR and push to main.

**Triggers:**
- Pull requests affecting formal verification files
- Push to main/movement branches

**Jobs:**
- Lean toolchain setup
- Mathlib cache fetch
- Full tree build
- Per-operation verification (5 parallel jobs)

**Timing:** ~15 min timeout, ~1-2 min actual with cache

**Artifacts:**
- Build logs
- Verification reports

#### `axiom-diff-ca.yaml`

Axiom baseline drift detection on every PR.

**Triggers:**
- Pull requests affecting Lean files

**Jobs:**
- Build Lean tree
- Generate axiom list
- Diff against baseline
- Fail on new axioms without baseline update

**Timing:** <1 minute

#### `ca-verification-suite.yaml`

Comprehensive verification suite (all stacks).

**Triggers:**
- Pull requests (comprehensive mode)
- Push to main (standard mode)
- Manual dispatch

**Jobs:**
1. `lean-verification`: All 5 operations
2. `axiom-verification`: Baseline check
3. `trust-boundaries`: Reconciliation
4. `documentation`: Freshness check
5. `performance`: Benchmark and regression check

**Timing:** ~13 min total (jobs run in parallel)

**Artifacts:**
- Verification reports
- Performance benchmarks
- Documentation audit results

#### `ca-nightly-verification.yaml`

Nightly comprehensive verification and health monitoring.

**Triggers:**
- Schedule: 2 AM UTC daily
- Manual dispatch

**Jobs:**
1. `nightly-verification`: Full comprehensive suite
2. `axiom-drift-check`: Baseline validation
3. `sorry-count-tracking`: Regression detection
4. `documentation-freshness`: Stale doc detection

**Features:**
- Creates GitHub issues on failure
- Uploads detailed reports
- Performance regression detection
- 90-day artifact retention

**Alerts:**
- Auto-creates issue on failure
- Includes run logs and remediation steps

### Workflow Configuration

All workflows use:
- Ubuntu latest runners
- Lean 4.24.0 toolchain
- Mathlib cache for fast builds
- Artifact upload for debugging

### Workflow Monitoring

**View status:**
```bash
gh workflow list
gh run list --workflow=lean-ca.yaml
```

**Download artifacts:**
```bash
gh run download <run-id>
```

---

## Monitoring & Alerts

### Health Monitoring

**Local monitoring:**
```bash
# Continuous (Ctrl+C to stop)
./scripts/continuous_monitoring.sh

# With Slack alerts
./scripts/continuous_monitoring.sh --webhook $SLACK_WEBHOOK
```

**CI monitoring:**
- Nightly comprehensive verification
- Auto-issue creation on failures
- Performance trend tracking

### Alert Types

**Critical (exit 1, create issue):**
- Lean build failure
- Verification suite failure
- Sorry count regression >5
- Axiom drift >10

**Warning (log, webhook notification):**
- Performance regression 10-20%
- Documentation stale >90 days
- Disk space >90%

**Info (log only):**
- Sorry count improvement
- Performance improvement
- Successful verification passes

### Alert Channels

1. **GitHub Issues**: Auto-created on nightly failures
2. **Webhooks**: Slack/Discord/custom integrations
3. **Logs**: `logs/monitoring.log`
4. **Reports**: `reports/monitoring/health-*.json`

---

## Release Automation

### Pre-Release Checklist

**Run comprehensive checks:**
```bash
./scripts/release_checklist.sh --version 1.0.0
```

**Checklist includes:**
- [ ] Git working directory clean
- [ ] On release branch
- [ ] Version tag available
- [ ] Lean tree builds
- [ ] Sorry count ≤ baseline
- [ ] Axiom baseline current
- [ ] Trust boundaries reconciled
- [ ] Verification suite passes (comprehensive)
- [ ] Documentation up to date
- [ ] Phase 7 deliverables complete
- [ ] CI workflows valid
- [ ] Docker image buildable
- [ ] Coverage metrics acceptable
- [ ] Performance within budgets

### Docker Image Release

**Build and publish:**
```bash
# Set GitHub token
export GITHUB_TOKEN=<your-token>

# Build, test, and publish
./scripts/publish_docker_image.sh

# Or build only first
./scripts/publish_docker_image.sh --build-only
# ... test manually ...
./scripts/publish_docker_image.sh --publish-only
```

**Image tags:**
- `ghcr.io/movement-labs/ca-formal-verification:2026-04-23` (date-based)
- `ghcr.io/movement-labs/ca-formal-verification:latest`

**Digest capture:**
- Automatically updates `audit/toolchain.lock`
- Ensures reproducible pulls

### Release Process

1. **Pre-release checks:**
   ```bash
   ./scripts/release_checklist.sh --version X.Y.Z
   ```

2. **Build Docker image:**
   ```bash
   ./scripts/publish_docker_image.sh
   ```

3. **Create release tag:**
   ```bash
   git tag -a vX.Y.Z -m "CA Formal Verification vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Generate release notes:**
   - Use `audit/PHASE_7_STATUS.md` as template
   - Include verification metrics from `verify-ca.sh --coverage`
   - List resolved issues

5. **Publish GitHub release:**
   - Attach Docker digest from `toolchain.lock`
   - Include `verify-ca.sh` usage instructions
   - Link to documentation

---

## Performance Tracking

### Benchmarking

**Run benchmarks:**
```bash
# Save baseline
./scripts/benchmark_verification.sh --output json > reports/baseline.json

# Compare current against baseline
./scripts/benchmark_verification.sh --output json > reports/current.json
./scripts/detect_performance_regression.sh reports/baseline.json reports/current.json
```

**Automated in CI:**
- Every PR: performance check
- Nightly: trend analysis
- Release: comprehensive benchmark

### Metrics Tracked

**Build times:**
- Lean full tree
- Per-operation (register, withdraw, transfer, normalize, rotate)
- Verification suite (quick, standard, comprehensive)

**Verification times:**
- Per-stack per-operation
- Full matrix timing

**Coverage:**
- Theorem count
- MSL spec count
- Axiom count
- Sorry count

### Performance Budgets

| Metric | Budget | Current | Status |
|--------|--------|---------|--------|
| Lean full tree | 10 min | ~4s | ✅ Well within |
| Registration rebuild | 3 min | ~3s | ✅ Within |
| Per-operation verify | 3 min | 1-2s | ✅ Within |
| Quick suite | 2 min | <2 min | ✅ Within |
| Standard suite | 5 min | <5 min | ✅ Within |
| Comprehensive suite | 15 min | <15 min | ✅ Within |

### Regression Detection

**Thresholds:**
- **Error (exit 1)**: >20% slower
- **Warning**: 10-20% slower
- **OK**: <10% change

**Automated actions:**
- CI fails on error threshold
- Webhook alert on warning
- Trend report generated

---

## Maintenance Procedures

### Daily

**Automated (CI):**
- Lean verification on PRs
- Axiom drift detection
- Sorry count tracking

**Manual:**
- Review PR verification results
- Address failed CI checks

### Weekly

**Automated:**
- Nightly verification reports
- Performance trend analysis

**Manual:**
- Review nightly failures
- Update baselines if legitimate changes
- Performance optimization if regressions

### Monthly

**Automated:**
- Documentation freshness check

**Manual:**
- Review and update stale docs
- Dependency updates
- Performance benchmark comparison

### Quarterly

**Automated:**
```bash
./scripts/quarterly_audit.sh
```

**Manual:**
- Comprehensive verification review
- Axiom reduction initiatives
- Sorry elimination push
- Documentation consolidation
- Tool version updates

### Before Release

**Automated:**
```bash
./scripts/release_checklist.sh --version X.Y.Z
./scripts/publish_docker_image.sh
```

**Manual:**
- Review Phase 7 deliverables
- Update CLAIMS.md and TRUST_BOUNDARIES.md
- Generate release notes
- Tag and publish release

---

## Troubleshooting

### Common Issues

#### Build Failures

**Symptom:** `lake build` fails

**Causes:**
1. Mathlib cache missing
   ```bash
   cd lean && lake exe cache get
   ```

2. Lean version mismatch
   ```bash
   lean --version  # Should be 4.24.0
   elan default v4.24.0
   ```

3. Corrupted build artifacts
   ```bash
   cd lean && lake clean && lake build
   ```

#### Verification Suite Failures

**Symptom:** `run_verification_suite.sh` fails

**Common failures:**
- **Move Prover tools not set**: Run `movement update prover-dependencies`
- **Z3 version mismatch**: Use 4.11.2, not Homebrew's 4.14.x
- **Axiom drift**: Run `./scripts/check_axioms.sh --diff`
- **Trust boundary mismatch**: Run `./scripts/reconcile_trust_boundaries.sh`

#### Performance Regressions

**Symptom:** Build times exceed budgets

**Diagnosis:**
```bash
./scripts/performance_dashboard.sh --benchmark
./scripts/detect_performance_regression.sh baseline.json current.json
```

**Common causes:**
- Mathlib cache miss → Re-fetch cache
- Heartbeat limit increase → Optimize proof
- New dependencies → Review and optimize
- System load → Run on dedicated machine

#### Docker Build Failures

**Symptom:** Docker image build fails

**Common issues:**
1. Docker daemon not running
2. Network issues downloading dependencies
3. Insufficient disk space
4. Mathlib cache fetch timeout

**Resolution:**
```bash
# Clean Docker cache
docker system prune -a

# Build with --no-cache
docker build --no-cache -f audit/Dockerfile .
```

### Debug Mode

**Enable verbose output:**
```bash
# Bash scripts
bash -x ./scripts/run_verification_suite.sh

# Docker
docker build --progress=plain -f audit/Dockerfile .
```

### Getting Help

**Resources:**
- `TROUBLESHOOTING_GUIDE.md`: Comprehensive troubleshooting
- `FAQ.md`: Frequently asked questions
- GitHub Issues: Report bugs or ask questions
- Team chat: Real-time support

**Logs:**
- `logs/monitoring.log`: Monitoring history
- `/tmp/*_release.log`: Release checklist details
- CI artifacts: Downloadable via GitHub UI

---

## Summary

The automation infrastructure provides:

1. **Comprehensive verification** across all three stacks
2. **Continuous monitoring** with alert capabilities
3. **Performance tracking** with regression detection
4. **Release automation** with pre-release checklists
5. **Maintenance procedures** for ongoing health

**Key scripts:**
- `run_verification_suite.sh`: Comprehensive verification
- `performance_dashboard.sh`: Performance metrics
- `release_checklist.sh`: Pre-release validation
- `continuous_monitoring.sh`: Health monitoring
- `publish_docker_image.sh`: Docker automation

**Key workflows:**
- `lean-ca.yaml`: PR verification
- `axiom-diff-ca.yaml`: Drift detection
- `ca-verification-suite.yaml`: Comprehensive checks
- `ca-nightly-verification.yaml`: Daily health monitoring

All automation is designed to fail fast, provide actionable feedback, and support both local development and CI/CD environments.
