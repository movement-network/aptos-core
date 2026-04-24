# Axiom Elimination Session - 2026-04-24

**Duration:** ~90 minutes  
**Focus:** Converting simple axioms to theorems in EvalEquivRebuild.lean  
**Result:** 24 axioms converted (342 → 318, -7% reduction)

---

## Summary

Systematic pass through EvalEquivRebuild.lean converting axioms provable by rfl/simp/decide to theorems. All conversions maintain clean builds with no performance regression.

**Build metrics:**
- Full tree: 1094 jobs, ~2.1s for EvalEquivRebuild
- Zero new errors or warnings
- All downstream files still build cleanly

---

## Axioms Converted (24 total)

### Frame Projection Helpers (6 axioms)
1. **registrationInitFrame_locals_size** - Size of locals array
   - Proof: `unfold registrationInitFrame; simp [List.length_append, List.length_map]`
   - Simple list length arithmetic

2. **registrationInitFrame_localRefs_eq** - LocalRefs field equality
   - Proof: `unfold registrationInitFrame; rfl`
   - Direct definitional equality

3. **registrationInitFrame_localRefs_size** - LocalRefs size is 19
   - Proof: `simp [registrationInitFrame_localRefs_eq]`
   - Follows from _eq lemma

4. **registrationInitFrame_localRefs_get?** - LocalRefs indexing
   - Proof: `simp [registrationInitFrame_localRefs_eq]`
   - Follows from _eq lemma

5. **registrationInitFrame7_locals_size** - Concrete 7-arg case size is 19
   - Proof: `simp [registrationArgs]`
   - Uses generic locals_size + concrete args

6. **registrationInitFrame_code_size** - Code array has 84 instructions
   - Proof: `simp [registrationInitFrame_code]; decide`
   - Decidable equality on concrete array

### buildRegistrationLocals Helpers (10 axioms)
7. **buildRegistrationLocals_size** - Array size is 19
   - Proof: `unfold buildRegistrationLocals; decide`
   - Array literal size

8-16. **buildRegistrationLocals_{field}** - Index access for 9 fields
   - Fields: chainId (0), sender (1), contract (2), token (3), ekBa (4), commitBa (5), respBa (6), v (7), 8_none
   - Proof: `unfold buildRegistrationLocals; rfl` for each
   - Array literal indexing

### Locals Array Manipulation (3 axioms)
17. **locals_set_preserves_size** - Array.set! preserves size
   - Proof: `simp [Array.size_set!]`
   - Standard library lemma

18. **locals_set_preserves_others** - set! at idx doesn't affect idx'
   - Proof: `simp [Array.getElem?_set!, hne]`
   - Standard array lemma with inequality

19. **locals_get_after_set_same** - Reading just-written index
   - Proof: `simp [Array.getElem?_set!, hbounds]`
   - Standard array lemma

20. **moveLoc_clears_local** - set! idx none followed by read
   - Proof: Extract bound from hypothesis, then simp
   - Slightly more complex array manipulation

### Arithmetic and List Operations (4 axioms)
21. **fuel_for_n_steps** - Nat arithmetic about fuel consumption
   - Proof: `exact ⟨fuel - n, rfl, Nat.sub_add_cancel h⟩`
   - Simple Nat.sub_add_cancel application

22. **bcs_address_length** - Mapped list preserves length
   - Proof: `simp [List.length_map, h]`
   - Standard list lemma

23-24. **registrationArgs_get_{5,6}** - Index access to concrete list
   - Proof: `unfold registrationArgs; rfl` for each
   - List literal indexing

---

## Attempted but Deferred

### Elaboration Blockers (2 axioms)
1. **registrationModuleEnv_functions_size** - ModuleEnv functions.size = 18
   - Error: "Expected type must not contain free variables" when unfolding
   - Reason: ModuleEnv contains dependent types in function descriptors
   - Status: Deferred, marked as architectural axiom

2. **registrationModuleEnv_idx17** - ModuleEnv function descriptor access
   - Error: Same elaboration issue as above
   - Reason: Array indexing with dependent bound proof
   - Status: Deferred, related to singleton branch blocker

These demonstrate the fundamental elaboration issue blocking ~2000-3000 lines of singleton branch proof work.

---

## Commits

1. **8d489ccb4e** - First batch (21 axioms): frame projections, buildRegistrationLocals, locals helpers, fuel arithmetic
2. **6215db04c4** - Second batch (1 axiom): bcs_address_length
3. **4b1b394442** - Third batch (2 axioms): registrationArgs_get_{5,6}

All commits include Co-Authored-By: Claude Sonnet 4.5

---

## Impact on Axiom Inventory

**Before session:** 62 total axioms (57 permanent + 5 TEMPORARY)  
**After session:** ~60 total axioms (estimated, EvalEquivRebuild reduced by 24)

Note: The 62 count in AXIOM_INVENTORY.md tracks CA-specific axioms, not all axioms in the MoveModel infrastructure. Full codebase has ~647 axioms total, most in core MoveModel libraries.

**EvalEquivRebuild specifically:**
- Before: 342 axioms
- After: 318 axioms
- Reduction: 24 axioms (-7%)
- Remaining: Mostly step lemmas (complex, require PC-threading proofs) and architectural boundaries

---

## Pattern Recognition

**Easy conversions (rfl/decide):**
- Definitional equalities: fields of record literals
- Array/list literal indexing with concrete indices
- Concrete array sizes (decidable)
- Standard library lemmas (Array.size_set!, List.length_map, etc.)

**Medium conversions (simp with hints):**
- Array operations with inequality proofs
- List length arithmetic (append, map, replicate)
- Bound extraction from hypotheses

**Hard/blocked conversions:**
- Anything requiring unfolding types with dependent bounds
- ModuleEnv functions array (has native oracle closures)
- Step lemmas (need full PC-threading infrastructure)

---

## Recommendations

1. **Continue axiom elimination incrementally** - Look for more rfl/decide patterns in EvalEquivRebuild
2. **Document architectural axioms** - registrationModuleEnv axioms should be marked as "elaboration-blocked, architectural"
3. **Update AXIOM_INVENTORY.md** - Reduce count by 22-24 after next verify-ca.sh run
4. **Focus on high-value work** - Singleton branch (when unblocked) has 10x impact vs incremental axiom elimination

---

## Next Steps

1. Search for more simple axioms in other operations (Withdrawal, Transfer, etc.)
2. Check if ByteArray axioms in MoveModel can be proven
3. Look for other infrastructure axioms that might be convertible
4. Update status documents to reflect progress
