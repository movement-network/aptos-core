# Session Summary: Infrastructure Proof Work - 2026-04-24

**Duration:** ~70 minutes  
**Focus:** Systematic search for convertible axioms/sorries + infrastructure proof completion

---

## Summary

Completed 1 sorry elimination in MoveModel infrastructure:
- **StackManagement.lean**: `takeN_from_marshaled_stack` theorem (marked as ~40 lines)
- Fixed bug in theorem statement: result should be `(args, rest)` not `(args.reverse, rest)`
- Proof uses `List.take_left` and `List.drop_left` lemmas with omega for arithmetic

**Impact:**
- Total sorries: 229 → 228 (-1)
- Infrastructure proofs strengthened: argument marshaling now has proven correctness lemma

---

## Work Log

### Phase 1: Systematic Axiom Search (45 minutes)

Searched for convertible axioms across multiple file categories:

**Files examined:**
- MoveModel/ContainerStoreLemmas.lean (11 axioms - all opaque native oracle boundaries)
- MoveModel/StepLemmas/ProvenChains.lean (1 axiom - run_error_stable_multi, needs well-founded recursion)
- MoveModel/StepLemmas/CopyLocChains.lean (1 axiom - complex multi-PC pattern)
- MoveModel/StepLemmas/BorrowFieldChains.lean (4 axioms - multi-PC composition)
- MoveModel/StepLemmas/MoveLocChains.lean (5 axioms - blocked by array elaboration)
- MoveModel/StepLemmas/NativeCallPatterns.lean (7 axioms - multi-step patterns)
- MoveModel/ByteArrayLemmas.lean (2 axioms remaining - both blocked or architectural)
- Experimental/ConfidentialAsset/Helpers/* (multiple files, all multi-PC or architectural)

**Findings:**
- Most simple axioms already converted in 2026-04-24 cleanup session (197 axioms)
- Remaining axioms fall into categories:
  - Architectural boundaries (ConcreteHelpers, crypto, native oracles): ~80 axioms
  - Complex PC-chaining requiring step-lemma infrastructure: ~300 axioms  
  - Blocked by elaborator/array indexing issues: ~15 axioms
  - Others requiring specific infrastructure: ~50 axioms

### Phase 2: Sorry Elimination (25 minutes)

**Target:** `StackManagement.takeN_from_marshaled_stack`
- Marked as ~40 lines in comments
- Critical for oracle call argument extraction
- Had a bug in theorem statement

**Work:**
1. Read takeN definition in Step.lean
2. Analyzed theorem: prove that taking n elements from `args.reverse ++ rest` gives `(args, rest)`
3. Discovered theorem statement bug: should return `(args, rest)` not `(args.reverse, rest)`
   - takeN does `.reverse` on taken elements, so reversing `args.reverse` gives `args`
4. Fixed theorem statement to match usage in line 242
5. Completed proof using:
   - `List.take_left` to show taking n from append gives first part
   - `List.drop_left` to show dropping n leaves second part
   - `List.reverse_reverse` for the reversal identity
   - `omega` for arithmetic goals

**Result:** ✅ Builds successfully

---

## Proof Details

### takeN_from_marshaled_stack

**Theorem:**
```lean
theorem takeN_from_marshaled_stack
    {stack : List MoveValue} (args : List MoveValue) (rest : List MoveValue) (n : Nat)
    (hStack : stack = args.reverse ++ rest)
    (hLen : args.length = n) :
    takeN stack n = some (args, rest)
```

**Proof strategy:**
1. Unfold `takeN` definition
2. Show length condition: `(args.reverse ++ rest).length >= n` via omega
3. Prove first component: `(args.reverse ++ rest).take n |>.reverse = args`
   - Show `take n = args.reverse` using `List.take_left`
   - Apply `List.reverse_reverse` to get `args`
4. Prove second component: `(args.reverse ++ rest).drop n = rest`
   - Use `List.drop_left` with length equality
   - Show `drop n args.reverse = []` since lengths match
   - Simplify `[] ++ rest = rest`

**Lines:** 25 lines (shorter than estimated ~40)

---

## Attempted but Deferred

### StackManagement stack_size_after_* theorems

**Issue:** Theorem statements missing necessary hypotheses
- Don't specify which instruction was executed
- Only have `hstep : step env frame cs stack ms = .ok ...`
- Need additional hypotheses like:
  ```lean
  (hpc : frame.code[frame.pc] = .moveLoc idx)
  (hbounds : frame.pc < frame.code.size)
  ```
- Theorem statements appear incomplete or require refactoring

**Status:** Deferred - needs theorem statement fixes first

### Other Infrastructure Sorries

**FrameInvariants** (5 sorries): All require step function unfolding + 30-40 lines each
**StackManagement** (5 more sorries): Missing hypotheses or complex step reasoning

---

## Observations

### Axiom Landscape After 2026-04-24 Cleanup

The previous cleanup session (197 axioms converted) was extremely thorough:
- All stub axioms (`axiom name : True`) converted
- All simple equality/size axioms via `rfl`/`decide` converted
- All arithmetic axioms via `omega` converted  
- All simple array operations via `simp` converted

**Remaining axioms are genuinely complex:**

1. **Architectural (permanent):** ~80 axioms
   - Crypto (Edwards laws, primality, Bulletproofs): 21
   - ConcreteHelpers (component behaviors): 26  
   - Native oracles (opaque boundaries): 11
   - FunctionalSimBridge (oracle rewriting): 5
   - Others: ~17

2. **Infrastructure-dependent:** ~350 axioms
   - Registration PC-step lemmas: ~300 (require step-lemma infrastructure, 40-500 lines each)
   - Multi-PC patterns (MoveLocChains, BorrowFieldChains, etc): ~30
   - Step lemmas (error propagation, composition): ~20

3. **Blocked on elaboration:** ~15 axioms
   - Array indexing free variable constraint
   - Singleton branch patterns
   - Dependent type issues

4. **TEMPORARY (for elimination):** 5 axioms
   - 1 registration: `registration_eval_equiv_functional_sim`
   - 4 withdrawal: PC-chaining helpers

### Conversion Strategy Going Forward

**High ROI:**
- Fix theorem statements with missing hypotheses (StackManagement, FrameInvariants)
- Systematic sorry elimination in infrastructure files where theorems are well-formed
- Focus on files with <10 axioms/sorries where statements are correct

**Medium ROI:**
- Multi-PC pattern proofs once step-lemma infrastructure is in place
- Helper lemmas that support main theorems

**Low ROI (defer):**
- 300 Registration PC-step axioms (each requires significant infrastructure)
- Architectural axioms (accepted as permanent)
- Blocked axioms (wait for elaborator fixes)

---

## Next Steps

### Immediate (next session)
1. Fix StackManagement theorem statements to include instruction hypotheses
2. Complete remaining StackManagement sorries with corrected statements
3. Attempt FrameInvariants sorries systematically

### Short Term
1. Survey all infrastructure files for well-formed sorries
2. Create priority list based on:
   - Theorem statement correctness
   - Estimated proof complexity
   - Downstream dependencies

### Medium Term  
1. Build step-lemma infrastructure to unlock PC-step axioms
2. Systematic elimination of multi-PC pattern axioms
3. Update axiom inventory after each session

---

## Metrics

**Axioms:** 447 (unchanged from last session - focused on sorries today)
**Sorries:** 229 → 228 (-1, -0.4%)
**Theorems completed:** 1 (takeN_from_marshaled_stack)
**Bug fixes:** 1 (theorem statement correction)
**Build status:** ✅ 100% success (2033 modules)

---

## Files Modified

1. **MovementFormal/MoveModel/StackManagement.lean** (+20, -2 lines)
   - Theorem statement bug fix: `(args.reverse, rest)` → `(args, rest)`
   - Complete proof for `takeN_from_marshaled_stack`
   - 1 sorry eliminated

2. **SESSION_2026_04_24_INFRASTRUCTURE_PROOFS.md** (new file)
   - Session documentation

---

## Commit

```
git commit -m "Prove takeN_from_marshaled_stack theorem

- Fixed theorem statement bug: result should be (args, rest) not (args.reverse, rest)
- Completed proof using List.take_left and List.drop_left lemmas
- 1 sorry eliminated in StackManagement.lean
- Builds successfully"
```

**Branch:** lean-fv  
**Hash:** 5855cd4f22
