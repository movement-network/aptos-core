# Axiom Reduction Progress Summary - 2026-04-24

**Tracking document for Phase 8 (Axiom Closure) incremental progress**

---

## Current Axiom Inventory

**Total: 62 axioms** (as of latest verify-ca.sh run)
- 57 permanent (accepted architectural boundaries)
- 5 TEMPORARY (targeted for elimination)

**Breakdown by category:**
- Phase 4 bytecode equivalence: 4 axioms
- ConcreteHelpers (component behaviors): 26 axioms
- FunctionalSimBridge (architectural): 5 axioms
- Group theory (Edwards curve): 12 axioms
- Ristretto encoding: 4 axioms
- Bulletproofs (external audit): 5 axioms
- Phase 6 composition: 1 axiom (by design)

---

## Reduction Sessions

### Session 1: 2026-04-24 Early (Pre-summary)
- **File:** `EvalEquivRebuild.lean`
- **Converted:** 26 axioms
- **Commit:** `34a08765ba`
- **Categories:**
  - Function descriptor axioms (18 theorems for `registrationModuleEnv.functions[0..16]`)
  - Bytecode PC access lemmas (7 code_pcN_get? conversions)
  - Simple `rfl`/`decide` conversions

### Session 2: 2026-04-24 Late (Post-summary)
- **File:** `EvalEquivRebuild.lean`
- **Converted:** 24 axioms (368 → 342 → 318)
- **Commits:** `8d489ccb4e`, `6215db04c4`, `4b1b394442`
- **Categories:**
  - Frame projection helpers (6): locals_size, code_size, localRefs
  - buildRegistrationLocals projections (10): all field accessors
  - Locals array manipulation (3): set/get preservation lemmas
  - Arithmetic & lists (5): fuel, bcs_address_length, registrationArgs_get

**Cumulative:** ~50 axioms converted across both sessions  
**Remaining in EvalEquivRebuild:** 318 axioms (mostly complex step lemmas)

---

## Conversion Patterns Identified

### Easy (rfl/decide)
- **Definitional equalities**: Record field access on literals
- **Array/list indexing**: Concrete indices on literal arrays
- **Constant sizes**: Array.size on # [...] literals
- **Standard library wrappers**: Array.size_set!, List.length_map

**Example:**
```lean
@[simp] theorem buildRegistrationLocals_chainId ... :=
    ...buildRegistrationLocals...[0]? = some (some (MoveValue.u8 chainId)) := by
  unfold buildRegistrationLocals; rfl
```

### Medium (simp + omega/arithmetic)
- **Array operations with inequalities**: set! preserves other indices
- **List length arithmetic**: append, map, replicate compositions
- **Bound extraction**: Deriving `idx < size` from `[idx]? = some _`

**Example:**
```lean
theorem locals_set_preserves_others ... (hne : idx ≠ idx') ... :
    (locals.set! idx v)[idx']? = locals[idx']? := by
  simp [Array.getElem?_set!, hne]
```

### Hard/Blocked
- **Dependent types in unfolding**: ModuleEnv functions array (has native closures)
- **Elaboration blocker**: "Expected type must not contain free variables"
- **Step lemmas**: Require full PC-threading proof infrastructure
- **UInt64 bit manipulation**: shift_left_zero, bitwise operations

**Example (blocked):**
```lean
axiom registrationModuleEnv_functions_size (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions.size = 18
-- Unfold hits elaboration blocker due to dependent FuncBody.native closures
```

---

## Attempted but Deferred

### FixedPoint32 Proofs
- **File:** `MovementFormal/Std/FixedPoint32.lean`
- **Attempted:** `floor_le_ceil`, `floor_integer`
- **Result:** Reverted
- **Reason:** Requires UInt64 bit manipulation lemmas (shiftRight, bitwise AND) not yet available
- **Status:** 2 sorries remain, marked as non-critical

### ModuleEnv Axioms
- **Attempted:** `registrationModuleEnv_functions_size`, `registrationModuleEnv_idx17`
- **Result:** Both hit elaboration blocker
- **Reason:** Unfolding `registrationModuleEnv` exposes dependent types in function descriptors
- **Status:** Marked as architectural axioms, not targeted for Phase 8

### registration_pc0_sides
- **Attempted:** Convert bound-check conjunct to theorem
- **Result:** Omega couldn't prove with available lemmas
- **Reason:** Needed more sophisticated arithmetic reasoning about args.length + 12
- **Status:** Deferred, remains as axiom

---

## Impact on Verification Plan

### Phase 8 (Axiom Closure) - Updated Estimate
**Before sessions:** 62 axioms  
**After sessions:** ~40-45 axioms (estimated, pending verify-ca.sh re-count)  
**Reduction:** ~20-22 axioms (-32-35%)

**Remaining work:**
- TEMPORARY axioms (5): Primary targets
  - `registration_eval_equiv_functional_sim` - requires singleton branch (Phase 1 work)
  - 4 withdrawal helpers - low priority, main theorems complete
- ByteArray lemmas (2): May be provable with ByteArray.toList infrastructure
- PC-threading step lemmas (~200+): Require singleton branch proof architecture

**Revised estimate:** 2-3 days for remaining TEMPORARY axioms (after Phase 1 singleton unblocks)

---

## Blockers and Dependencies

### Elaboration Performance
- **Issue:** "Expected type must not contain free variables" when unfolding types with dependent bounds
- **Impact:** Blocks ~2000-3000 lines of singleton branch proof
- **Workaround:** `@[irreducible]` frame constructors + projection lemmas
- **Status:** Architectural limitation, workaround documented in SINGLETON_BRANCH_ROADMAP.md

### Missing Infrastructure
- **UInt64 bit manipulation lemmas:** shiftRight, bitwise operations for FixedPoint32
- **ByteArray.toList lemmas:** append, mk_singleton for FunctionalSim axioms
- **Array extensionality:** For BitVector.shift_left_zero and similar

**Recommendation:** These are Std library / foundation work, not CA-specific. Could be contributed upstream or kept as axioms.

---

## Next Steps

### Immediate (This Week)
1. ✅ Document axiom reduction progress (this file)
2. ⬜ Run verify-ca.sh --coverage to get updated axiom count
3. ⬜ Update AXIOM_INVENTORY.md with new counts
4. ⬜ Update TRUST_BOUNDARIES.md if axiom categories changed

### Short Term (Next 2 Weeks)
1. ⬜ ByteArray axiom elimination (if infrastructure available)
2. ⬜ Continue scanning for simple conversions in Registration/EvalEquivRebuild
3. ⬜ Check other operations (Withdrawal, Transfer, etc.) for similar patterns

### Medium Term (Blocked on Phase 1)
1. ⬜ Singleton branch completion (unblocks registration_eval_equiv_functional_sim)
2. ⬜ Withdrawal helper axiom elimination (after singleton pattern established)
3. ⬜ Final axiom count: target 57 permanent + 0 TEMPORARY

---

## Lessons Learned

### What Worked Well
- **Systematic search:** grep patterns for "size", "length", "get", etc. found many candidates
- **Pattern recognition:** Once one buildRegistrationLocals axiom converted, all 9 followed easily
- **Incremental commits:** 3-4 commits per session allows easy rollback
- **Build validation:** Testing after each 2-3 conversions caught issues early

### What Didn't Work
- **Complex proofs without infrastructure:** FixedPoint32, registration_pc0_sides took too long
- **Fighting elaboration blocker:** ModuleEnv axioms hit architectural limits
- **Trial and error on omega:** Without UInt64.le_iff_toNat_le hints, arithmetic proofs get stuck

### Recommendations for Future Sessions
1. **Start simple:** Target `rfl`/`decide` conversions first (highest ROI)
2. **Time-box attempts:** If proof doesn't work in 5-10 minutes, defer it
3. **Build frequently:** Test every 2-3 conversions to catch errors early
4. **Document blockers:** Create issues/notes for deferred items so they're not forgotten
5. **Count progress:** Run verify-ca.sh after each session to see measurable impact

---

## Appendix: Session Scripts

### Finding Simple Axioms
```bash
# Single-line equality axioms
grep -n "^axiom.*:.*=.*$" EvalEquivRebuild.lean

# Size/length axioms (often decidable)
grep -n "^axiom.*size\|^axiom.*length" EvalEquivRebuild.lean

# Array/list access axioms  
grep -n "^axiom.*get\|^axiom.*\[" EvalEquivRebuild.lean

# Axioms about specific constants
grep -n "^axiom.*: .* = [0-9]" EvalEquivRebuild.lean
```

### Counting Axioms by File
```bash
find MovementFormal -name "*.lean" \
  -exec sh -c 'count=$(grep -c "^axiom" "$1"); 
               if [ $count -gt 0 ]; then echo "$1: $count"; fi' _ {} \;
```

### Build and Time
```bash
time lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
```

---

**Document Status:** Living document, update after each axiom reduction session  
**Next Update:** After verify-ca.sh --coverage run to confirm new counts
