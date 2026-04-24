# Work Session - 2026-04-24 Axiom Elimination

**Duration:** ~30 minutes  
**Focus:** Systematic axiom elimination using existing infrastructure

---

## Summary

**Axioms Converted:** 8  
**Commits:** 2  
**Build Status:** ✅ All passing  
**Axiom Count:** 447 → 439 total (-8, -1.8%)

---

## Axioms Converted

### ByteArray Infrastructure (4 axioms)

**File:** `MovementFormal/MoveModel/ByteArrayLemmas.lean`

**Strategy:** Import `MovementFormal.Std.ByteArrayAppend` which contains complete
proofs of ByteArray.toList behavior (loop induction already done). Reuse those
proofs to discharge the MoveModel-level axioms.

**Conversions:**
1. `ByteArray.toList_length_eq_size`
   - **Proof:** `rw [Std.byteArray_toList_eq_data_toList, Array.length_toList]; rfl`
   - **Key:** ByteArray.toList agrees with data.toList

2. `ByteArray.append_size`
   - **Proof:** Via `byteArray_data_append` + `Array.size_append`
   - **Key:** ++ notation equals .append, data concatenation proven in Std module

3. `ByteArray.toList_append`
   - **Proof:** Direct application of `Std.byteArray_toList_append`
   - **Key:** Already proven in infrastructure

4. `ByteArray.empty_toList`
   - **Proof:** `simp [Std.byteArray_toList_eq_data_toList, ByteArray.empty_data]`
   - **Key:** Empty data proven, toList equivalence applies

### Frame Operations (4 axioms)

**File:** `MovementFormal/MoveModel/OpaqueFrames.lean`

**Strategy:** The axioms were marked as "should be provable from Array.set lemmas
but the required lemma doesn't exist." However, `Array.get_set` does exist and works
with a split on the equality case.

**Conversions:**
1. `frameAfterMoveLoc_locals_at_idx`
   - **Proof:** `simp [frameAfterMoveLoc]`
   - **Key:** Definitional unfolding + simp solves immediately

2. `frameAfterMoveLoc_locals_at_other`
   - **Proof:** `Array.get_set` + split on idx = j, contradiction with j ≠ idx
   - **Key:** Split handles both cases, contradiction eliminates impossible case

3. `frameAfterStLoc_locals_at_idx`
   - **Proof:** `simp [frameAfterStLoc]`
   - **Key:** Same as moveLoc case

4. `frameAfterStLoc_locals_at_other`
   - **Proof:** `Array.get_set` + split on idx = j, contradiction with j ≠ idx
   - **Key:** Same pattern as moveLoc case

---

## Build Verification

All conversions verified:
- `ByteArrayLemmas.lean`: ✅ Builds successfully
- `OpaqueFrames.lean`: ✅ Builds with deprecation warnings (Array.get_set → Array.get_set, but proof still valid)
- Downstream files: ✅ `PC20_43_message_assembly.lean` builds successfully

Total impact: 0 errors, 0 sorries added, pure axiom elimination.

---

## Attempted But Deferred

### ByteArray.eq_of_toList_eq
- **Attempted:** Prove from `byteArray_toList_eq_data_toList` + Array extensionality
- **Blocker:** Array extensionality from list equality requires careful handling of dependent bounds
- **Status:** Deferred for future work, kept as axiom

### run_error_stable_multi (ProvenChains.lean)
- **Attempted:** Prove by induction that error stability holds across fuel increments
- **Blocker:** Requires well-founded recursion through execution trace, not just structural recursion on fuel
- **Status:** Deferred, requires deeper proof infrastructure

---

## Pattern Analysis

### Successful Pattern: Infrastructure Reuse
**When it works:**
- Existing module has the hard proof (loop induction, recursive structure)
- MoveModel axiom is a wrapper/convenience lemma
- Can import and apply directly

**Examples:** All 4 ByteArray conversions

### Successful Pattern: Definitional Unfolding
**When it works:**
- Definition is concrete (not opaque)
- simp or rfl can close goal after unfolding
- No complex reasoning needed

**Examples:** `frameAfterMoveLoc_locals_at_idx`, `frameAfterStLoc_locals_at_idx`

### Successful Pattern: Split + Contradiction
**When it works:**
- Goal has conditional (if idx = j then ... else ...)
- Hypothesis contradicts one branch
- Other branch is trivial (rfl)

**Examples:** `frameAfterMoveLoc_locals_at_other`, `frameAfterStLoc_locals_at_other`

### Blocked Pattern: Well-Founded Recursion
**When it fails:**
- Proof requires recursion through transformed state
- Not structural recursion on simple nat parameter
- Needs fuel/termination reasoning across execution steps

**Examples:** `run_error_stable_multi`

---

## Session Impact

**Cumulative axiom reduction:**
- Session start: 447 axioms
- Session end: 439 axioms
- Session delta: -8 axioms (-1.8%)
- From baseline (643): -204 axioms (-31.7% total reduction)

**Quality metrics:**
- 100% build success rate
- 0 sorry additions
- 0 reverts needed
- 2 clean commits

**Time efficiency:**
- ~30 minutes for 8 axioms
- ~3.75 minutes per axiom
- Mix of simple (1-line proofs) and moderate (5-line proofs) conversions

---

## Remaining Work

**Easy targets exhausted:** Most "infrastructure wrapper" and "trivial unfold" axioms
have been converted. Remaining 439 axioms are predominantly:
- Complex PC-chaining lemmas (~200+)
- Architectural boundaries (ConcreteHelpers, crypto, ByteArray protocol constraints)
- Infrastructure-dependent (ContainerStore, StepLemmas)

**Next opportunities:**
1. Look for more infrastructure reuse patterns in other MoveModel files
2. Consider attempting some simpler ContainerStore axioms with focused effort
3. Document remaining axioms as architectural vs convertible

---

## Conclusion

Session successfully eliminated 8 axioms through systematic application of two strategies:
1. **Infrastructure reuse** (ByteArray from Std module)
2. **Direct proof** (OpaqueFrames from Array lemmas)

Both commits build cleanly with downstream verification passing. Progress continues
toward Phase 8 axiom closure goals.
