# CA Formal Verification — Performance Benchmarking Guide

**Last updated:** 2026-04-23

This guide explains how to measure, track, and optimize verification performance for the CA formal verification suite.

## Current Performance Baseline

### Lean Stack (as of 2026-04-22)

**Full verification matrix:**
```
Total time: 6s (budget: 2700s, utilization: 0.2%)
```

**Per-operation breakdown:**
| Operation | Time | Theorems | Budget | Utilization | Status |
|-----------|------|----------|--------|-------------|--------|
| register  | 1-2s | 206      | 180s   | 0.6-1.1%    | ✅     |
| withdraw  | 1s   | 27       | 180s   | 0.6%        | ✅     |
| transfer  | 1-2s | 33       | 180s   | 0.6-1.1%    | ✅     |
| normalize | 1s   | 22       | 180s   | 0.6%        | ✅     |
| rotate    | 1s   | 22       | 180s   | 0.6%        | ✅     |

**Build characteristics:**
- Full tree: 1896 jobs
- Incremental builds: 1-2s typical
- Cold build (no mathlib cache): 10-30 minutes
- Warm build (with mathlib cache): 1-6s

### Move Prover Stack (pending Z3 setup)

**Status:** Not yet measured (blocked on Z3_EXE setup)

**Expected performance:**
- Per-operation: 5-30 seconds (based on plan estimates)
- Full run: 5-10 minutes (all operations)

### Difftest Stack (pending harness setup)

**Status:** Not yet measured (blocked on difftest harness)

**Expected performance:**
- Per-operation: 2-10 seconds
- Full run: 2-5 minutes

## Measuring Performance

### Basic Timing

Use `verify-ca.sh` built-in timing:

```bash
# Single operation
./verify-ca.sh --op register --stack lean

# Output includes timing:
# Lean: OK (1s)
# Total time: 1s
# ✓ Within per-op budget (≤180s)
```

### Detailed Timing with `time`

For more granular measurement:

```bash
# Full matrix with detailed timing
time ./verify-ca.sh --stack lean

# Per-operation with system resources
/usr/bin/time -l ./verify-ca.sh --op transfer --stack lean

# Output includes:
# - Real time (wall-clock)
# - User time (CPU time)
# - System time (kernel time)
# - Maximum resident set size (memory)
```

### Lake Build Timing

Direct Lean build timing:

```bash
cd aptos-move/framework/formal/lean

# Time full build
time lake build

# Time specific module
time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv

# Time with job count
time lake build -j8  # Use 8 parallel jobs
```

### Profiling Lean Builds

For detailed profiling:

```bash
# Enable profiling
lake build --profile

# View profiling data
cat .lake/build/lib/MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.trace

# Analyze slow parts
lake exe cache get  # Ensure cache is warm
lake build --profile MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
```

## Performance Optimization

### Mathlib Cache

**Critical:** Always fetch mathlib cache before building.

```bash
cd aptos-move/framework/formal/lean
lake exe cache get
```

**Impact:** 
- Without cache: 10-30 minutes for first build
- With cache: 1-6 seconds for incremental builds

**Freshness:** 
- Cache TTL: ~1 week (check `lake-manifest.json` changes)
- Update when mathlib version changes
- CI should cache `~/.cache/mathlib4` directory

### Parallel Builds

Lean supports parallel compilation:

```bash
# Use all cores
lake build -j $(nproc)

# Limit to 8 jobs (good for 8-core machines)
lake build -j8

# Default: lake decides automatically
lake build
```

**Trade-offs:**
- More jobs: faster build, higher memory usage
- Fewer jobs: slower build, lower memory usage
- Optimal: match physical core count

### Incremental Builds

Only rebuild changed modules:

```bash
# Modify a file
vim MovementFormal/Experimental/ConfidentialAsset/Transfer/EvalEquiv.lean

# Only rebuilds affected modules
lake build

# Force clean build
lake clean
lake build
```

**Typical incremental times:**
- Change 1 file: 1-5 seconds
- Change 5 files: 5-20 seconds
- Change core library: 30-60 seconds (if downstream is large)

### Caching Strategies

**CI caching:**
```yaml
- name: Cache mathlib
  uses: actions/cache@v3
  with:
    path: ~/.cache/mathlib4
    key: mathlib4-${{ hashFiles('**/lake-manifest.json') }}
    restore-keys: mathlib4-

- name: Cache build artifacts
  uses: actions/cache@v3
  with:
    path: aptos-move/framework/formal/lean/.lake/build
    key: lean-build-${{ github.sha }}
    restore-keys: lean-build-
```

**Local caching:**
- Mathlib cache: automatic via `lake exe cache get`
- Build artifacts: automatic in `.lake/build/`
- Clear cache: `lake clean` or `rm -rf .lake/build`

## Performance Tracking

### Automated Tracking

Track verification time over commits:

```bash
#!/bin/bash
# performance-tracker.sh

COMMIT=$(git rev-parse --short HEAD)
TIMESTAMP=$(date -Iseconds)

# Run verification and capture timing
OUTPUT=$(./verify-ca.sh --stack lean 2>&1)
TOTAL_TIME=$(echo "$OUTPUT" | grep "Total time:" | awk '{print $3}' | sed 's/s//')

# Log to CSV
echo "$TIMESTAMP,$COMMIT,$TOTAL_TIME" >> performance-log.csv

echo "Performance logged: $TOTAL_TIME seconds at commit $COMMIT"
```

**Usage in CI:**
```yaml
- name: Track performance
  run: |
    cd aptos-move/framework/formal/audit
    ./performance-tracker.sh

- name: Upload performance log
  uses: actions/upload-artifact@v3
  with:
    name: performance-log
    path: performance-log.csv
    retention-days: 90
```

### Performance Regression Detection

Alert on significant slowdowns:

```bash
#!/bin/bash
# performance-regression-check.sh

CURRENT_TIME=$1  # From verify-ca.sh output
BASELINE=6       # Baseline from 2026-04-22

# Calculate increase percentage
INCREASE=$(echo "scale=2; (($CURRENT_TIME - $BASELINE) / $BASELINE) * 100" | bc)

# Alert if >50% slower
if (( $(echo "$INCREASE > 50" | bc -l) )); then
    echo "⚠️  Performance regression detected!"
    echo "Current: ${CURRENT_TIME}s"
    echo "Baseline: ${BASELINE}s"
    echo "Increase: ${INCREASE}%"
    exit 1
fi

echo "✅ Performance within acceptable range"
exit 0
```

### Visualization

Plot performance over time:

```python
# visualize-performance.py
import pandas as pd
import matplotlib.pyplot as plt

# Load performance log
df = pd.read_csv('performance-log.csv', 
                 names=['timestamp', 'commit', 'time_seconds'])
df['timestamp'] = pd.to_datetime(df['timestamp'])

# Plot
plt.figure(figsize=(12, 6))
plt.plot(df['timestamp'], df['time_seconds'], marker='o')
plt.axhline(y=180, color='r', linestyle='--', label='Per-op budget (180s)')
plt.axhline(y=2700, color='orange', linestyle='--', label='Full-run budget (2700s)')
plt.xlabel('Time')
plt.ylabel('Verification Time (seconds)')
plt.title('CA Formal Verification Performance Over Time')
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig('performance-trend.png', dpi=150)
print("Saved performance-trend.png")
```

## Performance Budgets

### Plan §10.6 Budgets

| Metric | Budget | Current | Margin | Status |
|--------|--------|---------|--------|--------|
| Per-operation | ≤180s | 1-2s | 99%+ | ✅ |
| Full run | ≤2700s | 6s | 99.8% | ✅ |

### Enforcement

`verify-ca.sh` automatically checks budgets:
- Per-op >180s: Warning message, but doesn't fail
- Full run >2700s: Warning message
- Exit code always 0 if proofs pass, non-zero if proofs fail

**CI enforcement:**
```yaml
- name: Run verification
  run: ./verify-ca.sh --stack lean

- name: Check timing
  run: |
    TIME=$(./verify-ca.sh --stack lean 2>&1 | grep "Total time:" | awk '{print $3}' | sed 's/s//')
    if [ "$TIME" -gt 180 ]; then
      echo "⚠️  Warning: Verification took ${TIME}s (budget: 180s per-op)"
      # Don't fail, just warn
    fi
```

### Adaptive Budgets

For operations with >100 theorems, scale budget:

| Theorems | Budget Scale | Example |
|----------|--------------|---------|
| 1-50     | 1.0x (180s)  | withdraw (27 theorems) → 180s |
| 51-100   | 1.5x (270s)  | — |
| 101-200  | 2.0x (360s)  | register (206 theorems) → 360s |
| 201+     | 3.0x (540s)  | (future large proofs) |

**Justification:** Larger proofs take longer proportionally, but still well under budget.

## Common Performance Issues

### Issue 1: Slow First Build

**Symptom:** Initial build takes 10-30 minutes

**Cause:** No mathlib cache

**Fix:**
```bash
cd aptos-move/framework/formal/lean
lake exe cache get
lake build
```

**Prevention:** Always run `lake exe cache get` before first build

### Issue 2: Slow Incremental Builds

**Symptom:** Builds take 10-30s even for small changes

**Cause:** Core library changes force downstream rebuilds

**Diagnosis:**
```bash
# Check what's rebuilding
lake build --verbose

# See dependency graph
lake exe cache get --verbose
```

**Fix:** Minimize changes to heavily-imported modules

### Issue 3: High Memory Usage

**Symptom:** Build crashes with out-of-memory error

**Cause:** Too many parallel jobs

**Fix:**
```bash
# Reduce parallelism
lake build -j4  # Use only 4 jobs

# Or limit to 1 job (slowest but lowest memory)
lake build -j1
```

**System requirements:**
- Minimum: 8GB RAM (use -j4)
- Recommended: 16GB RAM (use -j8)
- Optimal: 32GB+ RAM (use -j16)

### Issue 4: Cache Thrashing

**Symptom:** Builds are inconsistent (sometimes fast, sometimes slow)

**Cause:** Mathlib cache is stale or corrupted

**Fix:**
```bash
# Clear and re-fetch cache
rm -rf ~/.cache/mathlib4
lake exe cache get

# Rebuild
lake clean
lake build
```

### Issue 5: Slow CI Builds

**Symptom:** CI builds take 10-20 minutes consistently

**Cause:** No cache reuse across runs

**Fix:** Add proper caching (see "Caching Strategies" above)

**Verification:**
```yaml
- name: Check cache hit
  run: |
    if [ -d ~/.cache/mathlib4 ]; then
      echo "✅ Mathlib cache restored"
    else
      echo "❌ Mathlib cache miss - will be slow"
    fi
```

## Optimization Checklist

When performance degrades:

- [ ] Check mathlib cache is fresh (`lake exe cache get`)
- [ ] Check for core library changes (affects many files)
- [ ] Profile slow modules (`lake build --profile`)
- [ ] Check memory usage (`/usr/bin/time -l`)
- [ ] Reduce parallelism if high memory usage
- [ ] Clear stale caches (`lake clean`)
- [ ] Check for filesystem issues (slow disk)
- [ ] Check for background processes (high CPU load)

## Performance Goals

### Short-term (Phase 7 completion)

- [ ] Maintain <10s full Lean run
- [ ] Measure Move Prover performance (pending Z3 setup)
- [ ] Measure difftest performance (pending harness)
- [ ] Establish 3-stack performance baseline

### Medium-term (Post-Phase 7)

- [ ] Optimize slowest operations to <1s
- [ ] Parallelize full-matrix run (target: 2s total)
- [ ] Add performance regression CI guard
- [ ] Create performance dashboard

### Long-term (Continuous improvement)

- [ ] Monitor performance trends over time
- [ ] Optimize proof tactics for speed
- [ ] Consider proof caching across commits
- [ ] Investigate incremental verification

## Benchmarking Toolkit

### Quick Benchmarks

```bash
# Benchmark full matrix (5 runs)
for i in {1..5}; do
    echo "Run $i:"
    time ./verify-ca.sh --stack lean 2>&1 | grep "Total time"
done

# Benchmark single operation (10 runs)
for i in {1..10}; do
    time lake build MovementFormal.Experimental.ConfidentialAsset.Transfer.EvalEquiv
done | grep real
```

### Statistical Analysis

```bash
# Collect timing data
for i in {1..20}; do
    TIME=$( (time lake build 2>&1) 2>&1 | grep real | awk '{print $2}')
    echo $TIME
done > timing-samples.txt

# Calculate statistics
awk '{sum+=$1; sumsq+=$1*$1} END {
    print "Mean:", sum/NR;
    print "StdDev:", sqrt(sumsq/NR - (sum/NR)^2)
}' timing-samples.txt
```

### Comparative Benchmarks

Compare performance across commits:

```bash
#!/bin/bash
# benchmark-compare.sh

# Checkout baseline
git checkout baseline-commit
lake clean && lake exe cache get && lake build
BASELINE_TIME=$(./verify-ca.sh --stack lean 2>&1 | grep "Total time" | awk '{print $3}')

# Checkout current
git checkout current-commit
lake clean && lake exe cache get && lake build
CURRENT_TIME=$(./verify-ca.sh --stack lean 2>&1 | grep "Total time" | awk '{print $3}')

# Compare
echo "Baseline: ${BASELINE_TIME}"
echo "Current: ${CURRENT_TIME}"
DIFF=$(echo "$CURRENT_TIME - $BASELINE_TIME" | bc)
echo "Difference: ${DIFF}s"
```

## Summary

**Current performance (2026-04-22):**
- ✅ Full Lean verification: ~6s (0.2% of budget)
- ✅ Per-operation: 1-2s (0.6-1.1% of budget)
- ✅ Well within all plan budgets

**Key optimization:**
- Always fetch mathlib cache before building
- Use parallel builds (-j8 for 8-core machines)
- Cache mathlib and build artifacts in CI
- Track performance over time for regression detection

**Performance is excellent** - no optimization needed currently. Focus on maintaining performance as codebase grows.
