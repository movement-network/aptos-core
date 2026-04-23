# CA Formal Verification Maintenance Guide (MAINTENANCE_GUIDE.md)

Complete guide for maintaining the CA formal verification as the codebase evolves. Covers: updating proofs when Move code changes, keeping docs current, managing axiom drift, and responding to upstream framework changes.

**Audience:** Developers modifying CA code, formal verification engineers, release managers

**Last updated:** 2026-04-22

---

## Quick Reference: "I Just Changed CA Code, What Do I Update?"

```
┌─────────────────────────────────────────────────────────────┐
│ DECISION TREE                                               │
├─────────────────────────────────────────────────────────────┤
│ Changed Move source (.move file)?                           │
│   YES → Update MSL specs + Lean proofs (see §1-§2)         │
│   NO  → Skip to next question                               │
│                                                              │
│ Changed MSL spec (.spec.move file)?                         │
│   YES → Re-run Move Prover + update docs (see §3)          │
│   NO  → Skip to next question                               │
│                                                              │
│ Changed Lean proof (.lean file)?                            │
│   YES → Re-run lake build + check axioms (see §4)          │
│   NO  → Skip to next question                               │
│                                                              │
│ Added new public function?                                  │
│   YES → Update CLAIMS.md + tool assignment (see §5)        │
│   NO  → Skip to next question                               │
│                                                              │
│ Changed native function signature?                          │
│   YES → Update Lean oracle + difftest corpus (see §6)      │
│   NO  → Done (no verification impact)                       │
└─────────────────────────────────────────────────────────────┘
```

**Golden rule:** If `verify-ca.sh` fails after your change, the verification needs updating. If it still passes, you're likely fine (but check acceptance criteria below to be sure).

---

## §1. Maintaining Move Source (.move Files)

### When to Update

**You MUST update verification if:**
- Changed function signature (added/removed parameters, changed types)
- Changed function body logic (new branches, different math, control flow)
- Added new function (especially public/entry)
- Changed abort conditions (new `assert!`, different error codes)
- Modified native function calls (different natives, different parameters)

**You MAY skip update if:**
- Pure refactoring (renamed variables, extracted private helpers, no logic change)
- Documentation/comment changes
- Whitespace/formatting changes

**How to tell:** Run `./audit/verify-ca.sh --op <affected-operation>`. If it fails, you MUST update. If it passes, verify coverage didn't silently drop (check `--coverage` output).

### Update Checklist

| Step | Action | Tool | Acceptance |
|------|--------|------|------------|
| 1 | Recompile Move code | `movement move compile` | Zero errors |
| 2 | Update MSL specs | Edit `*.spec.move` | Specs reflect new logic |
| 3 | Re-run Move Prover | `./audit/verify-ca.sh --stack move-prover` | VCs prove (or 0 VCs if ristretto255 blocked) |
| 4 | Update Lean proofs if bytecode changed | `lake build` in `lean/` | Zero sorry, builds in ≤3 min per file |
| 5 | Update difftest corpus if new cases | Edit `difftest/corpora/...` | New rows for edge cases |
| 6 | Update CLAIMS.md | Add/modify claim for changed function | Every function has claim |
| 7 | Run full verification | `./audit/verify-ca.sh` | All 3 stacks pass |

### Example: Adding New Abort Condition

**Scenario:** You add `assert!(amount > 0, EZERO_AMOUNT)` to `withdraw_to_internal`.

**Impact:**
- MSL: Add `aborts_if amount == 0 with EZERO_AMOUNT` to `confidential_asset.spec.move`
- Lean: No change (bytecode execution unchanged, only new error path)
- Difftest: Add corpus row `withdraw_zero_amount.json` → expected abort

**Steps:**
```bash
# 1. Update MSL spec
vim aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_asset.spec.move
# Add: aborts_if amount == 0 with EZERO_AMOUNT;

# 2. Re-run Move Prover
./audit/verify-ca.sh --op withdraw --stack move-prover
# Expect: VC proves (or 0 VCs if ristretto255 blocked)

# 3. Add difftest row
echo '{"amount": 0, "expected": {"aborted": 196618}}' > difftest/corpora/confidential_asset/withdraw_zero_amount.json

# 4. Update CLAIMS.md
vim audit/CLAIMS.md
# Update withdraw claim: "aborts with EZERO_AMOUNT if amount == 0"

# 5. Verify
./audit/verify-ca.sh --op withdraw
# All 3 stacks pass
```

---

## §2. Maintaining MSL Specs (.spec.move Files)

### When to Update

**You MUST update MSL specs if:**
- Move function signature changed (§1 triggered this)
- New abort condition added (§1 example above)
- Frame condition changed (which state fields are modified?)
- Balance invariant strengthened (new `ensures` clause for balance conservation)

**You MAY skip if:**
- Move source logic unchanged
- Only Lean proofs changed (MSL specs are independent)

### Update Checklist

| Step | Action | Tool | Acceptance |
|------|--------|------|------------|
| 1 | Edit spec file | `vim *.spec.move` | Spec matches new Move logic |
| 2 | Compile specs | `movement move compile --package-dir aptos-experimental` | Zero errors |
| 3 | Run Move Prover | `./audit/verify-ca.sh --stack move-prover` | VCs prove (or 0 VCs if blocked) |
| 4 | Update MSL_SPEC_COVERAGE.md | Document new/changed specs | Coverage table current |
| 5 | Update CLAIMS.md | Reflect new spec claims | Claims match specs |

### Common Pitfalls

**Pitfall 1: Spec compiles but doesn't verify**
- **Symptom:** `movement move compile` succeeds, `movement move prove` fails with VC timeout or unproved
- **Cause:** Spec is too strong (claims something untrue) or too weak (solver can't prove it)
- **Fix:** Adjust spec strength, add intermediate `assert` in Move code to help solver, or increase `--vc-timeout`

**Pitfall 2: `pragma opaque` silently disables verification**
- **Symptom:** All VCs prove instantly (suspicious)
- **Cause:** Too many `pragma opaque` declarations → Move Prover treats everything as uninterpreted
- **Fix:** Only use `pragma opaque` for crypto natives (documented in TRUST_BOUNDARIES.md). Remove from regular functions.

**Pitfall 3: Spec uses undefined spec functions**
- **Symptom:** Compile error: `undeclared function spec_foo`
- **Cause:** Spec function not declared in `spec module` block
- **Fix:** Declare `spec fun spec_foo(...): ReturnType { ... }` before use

### Spec Strengthening Strategy

Start weak, strengthen incrementally:

1. **Weak (day-one):** `aborts_if false;` (claims never aborts — usually wrong, but compiles)
2. **Medium (first pass):** `aborts_if <condition> with <code>;` (pin abort conditions)
3. **Strong (final):** Add `ensures` clauses for balance conservation, state preservation, frame conditions

**Don't jump to strong immediately** — it's easier to debug one new `ensures` at a time than 10 simultaneously.

---

## §3. Maintaining Lean Proofs (.lean Files)

### When to Update

**You MUST update Lean proofs if:**
- Move bytecode changed (recompile → new `.mv` → different bytecode)
- Native function signature changed (affects oracle type)
- Functional-sim predicate changed (rare, but possible)

**You MAY skip if:**
- Only MSL specs changed (Lean is independent of MSL)
- Move source changed but bytecode identical (rare — usually bytecode changes)

### Update Checklist

| Step | Action | Tool | Acceptance |
|------|--------|------|------------|
| 1 | Rebuild Lean tree | `cd lean && lake build` | Zero errors, zero sorry |
| 2 | Check affected files | Identify which `.lean` files need updates | Usually `*/EvalEquiv.lean` or `*/FunctionalSim.lean` |
| 3 | Update per-PC proofs | Fix broken step theorems | Proofs close (no `sorry`) |
| 4 | Check axiom count | `./scripts/check_axioms.sh` | No new axioms vs baseline |
| 5 | Update AXIOM_INVENTORY.md if new axioms | Document rationale | Every axiom has entry |
| 6 | Run verify-ca.sh | `./audit/verify-ca.sh --stack lean` | Builds in ≤3 min per op |

### Common Breakage Patterns

**Pattern 1: PC count changed**
- **Symptom:** Lean compilation error: `pc out of bounds`
- **Cause:** Move recompilation added/removed instructions
- **Fix:** Update `numPCs` constant, add/remove per-PC step theorems

**Example:**
```lean
-- Old: 83 PCs
def numPCs := 83

-- New: 85 PCs (added 2 instructions)
def numPCs := 85

-- Add 2 new step theorems: step_pc83, step_pc84
```

**Pattern 2: Native call signature changed**
- **Symptom:** Type mismatch in native oracle call
- **Cause:** Native function gained/lost parameter
- **Fix:** Update oracle type in `Native/Registration.lean` (or analogous file)

**Example:**
```lean
-- Old: newScalarFromU64 takes 1 param
def newScalarFromU64 (x : UInt64) : Scalar := ...

-- New: newScalarFromU64 takes 2 params (added domain separator)
def newScalarFromU64 (x : UInt64) (dst : Vector UInt8) : Scalar := ...

-- Update all call sites: newScalarFromU64 val → newScalarFromU64 val dst
```

**Pattern 3: Functional-sim predicate changed**
- **Symptom:** eval↔functional-sim equivalence theorem fails
- **Cause:** Move logic changed, functional-sim model needs update to match
- **Fix:** Update `FunctionalSim.lean` to reflect new logic, reprove equivalence

**This is rare** — functional-sim changes usually require architect review (affects end-to-end claim).

### Performance Regression

**Watch for:** Build time >3 min per file (Phase 1 acceptance criterion)

**If it regresses:**
1. Check if new proof is O(N²) in proof size (bad — refactor with smaller lemmas)
2. Use `@[irreducible]` aggressively on intermediate states
3. Avoid `.locals[K]'<bound>` idiom in theorem statements (use `Array.get?` instead)
4. Consult `CLAUDE.md` memory: [feedback_fv_heartbeats.md](../../../../../../.claude/projects/-Users-andygmove-Downloads-repos-aptos-core/memory/feedback_fv_heartbeats.md) — lifting heq-rfl bridges alone doesn't help, bound-proof elaboration in theorem statement is the real cost

---

## §4. Maintaining Difftest Corpus

### When to Update

**You MUST add difftest rows if:**
- New public function added (need corpus row for happy path + error paths)
- New abort condition added (need row that triggers it)
- Native function signature changed (need row with new parameters)
- Edge case discovered (add row to prevent regression)

**You MAY skip if:**
- Only spec/proof changes (corpus exercises VM, not specs/proofs)
- Pure refactoring (no observable behavior change)

### Update Checklist

| Step | Action | Tool | Acceptance |
|------|--------|------|------------|
| 1 | Identify new test cases | What inputs weren't covered before? | Edge cases + error paths covered |
| 2 | Generate oracle JSON | Run VM, capture output | JSON matches VM output byte-for-byte |
| 3 | Add to corpus | `echo '{...}' > difftest/corpora/.../new_case.json` | Corpus row format correct |
| 4 | Run difftest | `./audit/verify-ca.sh --stack difftest` (once harness lands) | Row passes |
| 5 | Update DIFFTEST_CA_INVENTORY.md | Document new row | Inventory complete |

### Corpus Row Format

**Standard format:**
```json
{
  "input": {
    "param1": "0x123...",
    "param2": 42
  },
  "expected": {
    "returned": ["0xabc..."],
    "state": { ... }
  }
}
```

**Error-path format:**
```json
{
  "input": { "amount": 0 },
  "expected": {
    "aborted": 196618
  }
}
```

**How to generate:** Run VM with input, capture output:
```bash
movement move run --function-id 0x1::confidential_asset::withdraw_to \
  --args <input> \
  --output-format json > oracle.json
```

Then extract relevant fields into corpus JSON.

### Coverage Strategy

**Minimum coverage per function:**
- 1 happy-path row (typical valid input)
- 1 row per abort condition (triggers each error)
- 1 edge-case row (boundary value, e.g., amount = U64_MAX)

**Comprehensive coverage:**
- Combinatorial coverage (all parameter combinations that matter)
- Adversarial inputs (malformed proofs, invalid ciphertexts)
- State-dependent cases (frozen account, allow-list enabled, etc.)

**Current:** 87+ rows (good baseline). Add 5-10 rows per new function.

---

## §5. Keeping Documentation Current

### Documentation Update Matrix

| Doc File | Update Trigger | Frequency | Owner |
|----------|----------------|-----------|-------|
| CLAIMS.md | New function, changed spec | Per change | Developer |
| TRUST_BOUNDARIES.md | New axiom, new pragma opaque | Per change | Verification engineer |
| AXIOM_INVENTORY.md | New axiom | Per change | Verification engineer |
| MSL_SPEC_COVERAGE.md | New spec block | Per change | Developer |
| BYTECODE_VERIFICATION_COVERAGE.md | New Lean theorem | Per change | Verification engineer |
| PHASE_7_STATUS.md | Phase 7 progress | Weekly or per milestone | Project manager |
| COMPLETION_ROADMAP.md | Estimates/blockers change | Monthly or per phase | Architect |
| CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md | Phase completion | Per phase landing | Architect |

### Automated Checks

**CI enforces:**
- `TRUST_BOUNDARIES.md` reconciles with reality (`./scripts/reconcile_trust_boundaries.sh`)
- Axiom count matches baseline (`.github/workflows/axiom-diff-ca.yaml`)

**Manual checks (pre-release):**
- CLAIMS.md has entry for every public function (grep for `public` / `entry` in Move source, cross-check CLAIMS.md)
- Documentation dates are current (Last updated: <within 1 month of release date>)
- Performance numbers in docs match reality (re-run benchmarks, update if >10% drift)

### Documentation Debt

**Watch for:**
- Claims in CLAIMS.md that reference removed functions (stale)
- Axioms in AXIOM_INVENTORY.md that no longer appear in `#print axioms` (stale)
- Specs in MSL_SPEC_COVERAGE.md that no longer exist in `.spec.move` files (stale)

**Prevention:**
- Update docs in **same PR** as code change (not separate "doc cleanup" PR later)
- Run `./scripts/reconcile_trust_boundaries.sh` pre-commit (catches stale trust boundaries)
- Quarterly doc audit: grep for file paths in docs, check if they still exist

---

## §6. Managing Axiom Drift

### Axiom Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ AXIOM LIFECYCLE                                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Axiom introduced (temporary stub or crypto primitive)    │
│    → Document in AXIOM_INVENTORY.md with rationale         │
│    → Add to audit/axiom-baseline.txt                        │
│    → CI axiom-diff passes (new axiom is documented)         │
│                                                              │
│ 2. Axiom lives (acceptable if TEMPORARY or crypto)          │
│    → Monitored by axiom-diff CI (no silent growth)          │
│    → AXIOM_INVENTORY.md kept current                        │
│                                                              │
│ 3. Axiom eliminated (TEMPORARY axioms only)                 │
│    → Reprove theorem (closes `sorry`, removes `axiom` decl) │
│    → Remove from AXIOM_INVENTORY.md                         │
│    → Update audit/axiom-baseline.txt                        │
│    → CI axiom-diff passes (axiom count decreased, OK)       │
└─────────────────────────────────────────────────────────────┘
```

### Axiom-Diff CI Workflow

**Triggered:** Every PR  
**Check:** `./scripts/check_axioms.sh --diff`  
**Passes if:** Axiom count unchanged OR (axiom count changed AND axiom-baseline.txt + AXIOM_INVENTORY.md updated in same PR)  
**Fails if:** New axiom appears without documentation update

**How to bypass (when intentional):**
1. Add new axiom to Lean code (e.g., `axiom foo : Bar`)
2. Update `audit/axiom-baseline.txt`: `./scripts/check_axioms.sh > audit/axiom-baseline.txt`
3. Update `audit/AXIOM_INVENTORY.md`: Add entry with rationale (TEMPORARY? Crypto? Why needed?)
4. Commit all 3 files in same PR
5. CI passes (axiom count changed, but documentation updated)

**Red flags:**
- Axiom count increases without AXIOM_INVENTORY.md update → **CI fails** (correct)
- Many axioms marked TEMPORARY but never eliminated → **technical debt** (revisit quarterly)
- Crypto axiom added without literature citation → **review required** (may be unsound)

### Target Axiom Count

**Current:** 27 (10 CA, 17 crypto deps)  
**Target:** ≤22 (eliminate 1 TEMPORARY + 4 Phase 6 textual axioms, leave 21 crypto + 1 composition if textual axioms remain per plan)

**Acceptable permanent axioms:**
- Edwards Curve Group Laws (12) — standard group theory
- Ristretto255 Encoding (4) — compression/roundtrip, external literature
- Bulletproofs (5) — soundness/completeness, external audit

**Unacceptable permanent axioms:**
- TEMPORARY axioms (phase-specific stubs) — must be eliminated
- Axioms without rationale — must be documented or removed
- Axioms that could be proved but aren't — lazy, eliminate

---

## §7. Responding to Upstream Changes

### Upstream Framework Changes (aptos-framework)

**Watch for:**
- `aptos_framework::fungible_asset` spec changes
- `aptos_framework::dispatchable_fungible_asset` spec changes
- New FA-related modules that CA depends on

**How to detect:**
- Diff upstream FA specs: `git diff upstream/main -- aptos-move/framework/aptos-framework/sources/fungible_asset.spec.move`
- Check FA spec audit: Re-read `audit/UPSTREAM_FA_SPEC_AUDIT.md` if upstream changed

**Impact assessment:**
1. **FA spec weakened** (e.g., supply preservation removed):
   - **Impact:** HIGH — CA's Phase 5 composition may break
   - **Action:** File upstream issue, add CA-local spec strengthening if needed, update UPSTREAM_FA_SPEC_AUDIT.md
2. **FA spec strengthened** (e.g., new ensures clauses):
   - **Impact:** LOW — CA benefits from stronger guarantees
   - **Action:** Update UPSTREAM_FA_SPEC_AUDIT.md to reflect, verify CA still verifies
3. **FA implementation changed but spec unchanged**:
   - **Impact:** NONE — CA composes against spec, not implementation
   - **Action:** No change needed (but monitor for behavioral differences)

**Process:**
- Quarterly upstream sync: Check FA spec diffs
- Update UPSTREAM_FA_SPEC_AUDIT.md if changes found
- Re-run `./audit/verify-ca.sh --stack move-prover` to confirm composition still holds

### Upstream Crypto Changes (ristretto255, bulletproofs)

**Watch for:**
- `aptos_std::ristretto255` spec changes
- `aptos_std::ristretto255_bulletproofs` spec changes
- Native function signature changes (breaking)

**How to detect:**
- Diff upstream crypto specs: `git diff upstream/main -- aptos-move/framework/aptos-stdlib/sources/cryptography/`
- Check native function signatures: `grep "native public" aptos-stdlib/sources/cryptography/ristretto255.move`

**Impact assessment:**
1. **Ristretto255 patches land upstream**:
   - **Impact:** HIGH — Unblocks Phase 2/3/5 Move Prover verification (currently 0 VCs)
   - **Action:** Remove local patches, re-run Move Prover, expect meaningful VCs
2. **Native signature changed** (e.g., `point_mul` gains domain separator):
   - **Impact:** HIGH — Breaks Lean oracle, difftest corpus
   - **Action:** Update Lean oracle types, regenerate difftest corpus, update all call sites
3. **Spec strengthened** (new ensures clauses):
   - **Impact:** MEDIUM — May help CA verification or may make VCs unprovable
   - **Action:** Re-run Move Prover, adjust CA specs if needed

**Process:**
- Monitor upstream PRs touching crypto modules
- Test CA verification against upstream changes before merging
- Coordinate with upstream on breaking changes (prefer additive changes)

### Tool Version Changes (Lean, Z3, Boogie)

**Watch for:**
- Lean toolchain updates (v4.24.0 → v4.25.0)
- Z3 version changes (4.11.2 → 4.12.0)
- Boogie version changes (3.5.1 → 3.6.0)

**How to detect:**
- Check `lean-toolchain` file: `cat lean/lean-toolchain`
- Check Movement CLI default Z3: `movement update prover-dependencies` output
- Check Docker base image: `grep "FROM ubuntu" audit/Dockerfile`

**Impact assessment:**
1. **Lean version change**:
   - **Impact:** MEDIUM — May break elaborator (common in Lean 4.x), may fix performance
   - **Action:** Test `lake build` on new version, fix broken proofs, update `lean-toolchain` + `audit/toolchain.lock` if adopting
2. **Z3 version change**:
   - **Impact:** HIGH — Z3 behavior varies across versions (VCs that proved before may timeout)
   - **Action:** Test Move Prover on new version, compare VC solve times, revert if regression
3. **Boogie version change**:
   - **Impact:** LOW — Boogie is relatively stable
   - **Action:** Test Move Prover compilation, verify VCs still generate

**Process:**
- Pin tool versions in `audit/toolchain.lock` + `audit/Dockerfile` (reproducibility)
- Test tool updates in CI before merging (branch with new version, run full verification)
- Document version changes in release notes (breaking if proofs break)

---

## §8. Pre-Release Checklist

Before each release, verify all verification is current:

### Verification Checklist
- [ ] `./audit/verify-ca.sh` passes (all 3 stacks, or 2 if difftest harness pending)
- [ ] `./scripts/reconcile_trust_boundaries.sh` passes (TRUST_BOUNDARIES.md current)
- [ ] `./scripts/check_axioms.sh --diff` passes (no new axioms vs baseline)
- [ ] Zero sorry in all Lean files (`grep -r sorry lean/` finds zero)
- [ ] Axiom count ≤ 27 (10 CA, 17 crypto deps) via `#print axioms`

### Documentation Checklist
- [ ] CLAIMS.md has entry for every public function
- [ ] TRUST_BOUNDARIES.md "Last reconciled" date is <1 month old
- [ ] AXIOM_INVENTORY.md rationale complete for all axioms
- [ ] PHASE_7_STATUS.md updated with current completion %
- [ ] COMPLETION_ROADMAP.md estimates are realistic
- [ ] All "Last updated" dates in docs are <3 months old

### Performance Checklist
- [ ] Lean build time ≤3 min per file (Phase 1 acceptance criterion)
- [ ] verify-ca.sh per-op time ≤3 min (Phase 7 acceptance criterion)
- [ ] verify-ca.sh full run ≤45 min (Phase 7 acceptance criterion)

### CI Checklist
- [ ] lean-ca.yaml passing (Lean verification all 5 ops)
- [ ] axiom-diff-ca.yaml passing (no axiom drift)
- [ ] move-prover-ca.yaml ready (may be blocked on ristretto255, acceptable)
- [ ] formal-difftest.yaml ready (may be pending harness, acceptable)

### Regression Checklist
- [ ] No new `sorry` introduced since last release
- [ ] No new axioms introduced without rationale
- [ ] No new `pragma verify = false` escapes (except test-only)
- [ ] No verification slowdown >20% (re-benchmark if unsure)

**If any fail:** Fix before release or document known issue in release notes

---

## §9. Quarterly Audit (Ongoing Maintenance)

Every 3 months, run comprehensive health check:

### Axiom Review
1. Run `./scripts/check_axioms.sh`
2. Compare to `audit/axiom-baseline.txt` (should match or be lower)
3. For each axiom:
   - Is it still justified? (reread AXIOM_INVENTORY.md rationale)
   - Can it be eliminated now? (TEMPORARY axioms should shrink over time)
   - Is the rationale still correct? (citations valid, assumptions still hold)
4. Update AXIOM_INVENTORY.md if any rationale changed
5. Target: Axiom count trending down (or stable if only crypto axioms remain)

### Documentation Drift Check
1. CLAIMS.md: For each claim, verify function still exists (grep in Move source)
2. TRUST_BOUNDARIES.md: Run `./scripts/reconcile_trust_boundaries.sh`, check for drift
3. MSL_SPEC_COVERAGE.md: For each spec block, verify file:line still exists (grep in .spec.move)
4. COMPLETION_ROADMAP.md: Re-estimate remaining work (are old estimates still accurate?)
5. Fix stale docs immediately (don't defer to "doc cleanup sprint")

### Upstream Sync
1. Diff FA specs: `git diff upstream/main -- aptos-move/framework/aptos-framework/sources/fungible_asset*.spec.move`
2. Diff crypto specs: `git diff upstream/main -- aptos-move/framework/aptos-stdlib/sources/cryptography/`
3. Re-read UPSTREAM_FA_SPEC_AUDIT.md: Does it still reflect upstream reality?
4. Update if upstream changed (see §7)

### Performance Regression Check
1. Re-run benchmarks: `./audit/verify-ca.sh` and time each operation
2. Compare to PHASE_7_STATUS.md performance table
3. If >20% slower: Investigate (new proofs added? Elaborator regression? Solver timeout?)
4. Update performance docs if numbers changed significantly

### Tool Version Check
1. Check for new Lean releases: https://github.com/leanprover/lean4/releases
2. Check for new Z3 releases: https://github.com/Z3Prover/z3/releases
3. Test CA verification on new versions (in branch, don't merge yet)
4. Decide: upgrade (if beneficial), stay (if stable), revert (if regression)
5. Document decision in release notes

---

## §10. Emergency Procedures

### Verification Breaks After Merge

**Symptom:** `./audit/verify-ca.sh` passes in PR, fails on main after merge

**Likely causes:**
1. Merge conflict silently broke proofs
2. Upstream change landed between PR creation and merge
3. Flaky CI (rare, but possible)

**Procedure:**
1. **Immediate:** Revert the breaking commit
2. **Investigate:** Reproduce failure locally, identify root cause
3. **Fix:** Update proofs/specs to match new code
4. **Re-verify:** Ensure `./audit/verify-ca.sh` passes before re-merge
5. **Post-mortem:** Why didn't CI catch this? (improve CI if needed)

### New Axiom Introduced Accidentally

**Symptom:** axiom-diff CI fails, reports new axiom

**Procedure:**
1. **Check intent:** Was this axiom intended? (read commit message)
2. **If unintended:** Fix the proof (close `sorry`, remove `axiom` decl)
3. **If intended:** Update `audit/axiom-baseline.txt` + `AXIOM_INVENTORY.md` with rationale
4. **Re-verify:** CI should pass once docs updated

### Trust Boundary Drifted

**Symptom:** `./scripts/reconcile_trust_boundaries.sh` fails

**Procedure:**
1. **Read output:** Script reports what drifted (axiom count? pragma opaque count? verification escapes?)
2. **Check if intentional:** Did someone add pragma opaque legitimately?
3. **If unintentional:** Remove the escape, restore verification
4. **If intentional:** Update `TRUST_BOUNDARIES.md` to reflect, document rationale
5. **Re-verify:** Script should pass once TRUST_BOUNDARIES.md updated

### Performance Regressed Severely

**Symptom:** Lean build time >10 min (was ~4s), or verify-ca.sh >5 min per op (was ~1-2s)

**Procedure:**
1. **Identify:** Which file regressed? (run `lake build <Module>` individually)
2. **Profile:** Use Lean profiler (`set_option profiler true`), identify hot spot
3. **Fix:** Common fixes:
   - Add `@[irreducible]` to large intermediate states
   - Break monolithic proof into smaller lemmas
   - Avoid `.locals[K]'<bound>` in theorem statements (use `Array.get?`)
4. **Validate:** Build time back to ≤3 min per file

### Upstream Broke CA

**Symptom:** Upstream merge breaks CA verification (VCs fail, specs don't compile)

**Procedure:**
1. **Revert locally:** `git revert <upstream-merge-commit>` to get back to green
2. **File upstream issue:** Describe what broke, provide minimal reproducer
3. **Workaround:** Add CA-local patch (temporary), document in TRUST_BOUNDARIES.md
4. **Monitor:** Track upstream issue, remove workaround once fixed upstream

---

## Summary

**Golden rules:**
1. **Update verification in same PR as code change** (not later)
2. **Keep docs current** (CLAIMS.md, TRUST_BOUNDARIES.md, AXIOM_INVENTORY.md)
3. **Monitor axiom drift** (axiom-diff CI enforces)
4. **Test before merging** (`./audit/verify-ca.sh` must pass)
5. **Quarterly audit** (catch doc drift, performance regression, upstream changes)

**Common tasks:**
- Move code changed → Update MSL specs + Lean proofs + difftest corpus
- MSL spec changed → Re-run Move Prover + update docs
- Lean proof changed → Re-run lake build + check axioms
- New function added → Update CLAIMS.md + tool assignment matrix

**Emergency contacts:**
- Verification breaks after merge → Revert immediately, investigate, fix, re-merge
- New axiom introduced → Update axiom-baseline.txt + AXIOM_INVENTORY.md or remove
- Trust boundary drifted → Run `./scripts/reconcile_trust_boundaries.sh`, update TRUST_BOUNDARIES.md
- Performance regressed → Profile with Lean profiler, add `@[irreducible]`, break into smaller lemmas

**Metrics to track:**
- Axiom count (target: ≤22, trending down)
- Build time per file (target: ≤3 min)
- verify-ca.sh per-op time (target: ≤3 min)
- Documentation freshness (target: "Last updated" <3 months)

**Quarterly audit checklist:**
- [ ] Axiom review (justified? eliminable? rationale current?)
- [ ] Documentation drift check (CLAIMS.md, TRUST_BOUNDARIES.md, specs)
- [ ] Upstream sync (FA specs, crypto specs)
- [ ] Performance regression check (re-benchmark, compare to docs)
- [ ] Tool version check (Lean, Z3, Boogie releases)

---

**Last updated:** 2026-04-22  
**Next update:** After Phase 1/6/7 completion or Q2 2026 audit  
**Owner:** Formal verification team lead
