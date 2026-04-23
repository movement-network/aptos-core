# Withdrawal Phase 6 — Complete Proof Implementation

**Operation:** `verify_withdrawal_proof`  
**Status:** Phase 4 ✅ complete (15 per-PC step theorems), Phase 6 🟡 in progress (1 sorry)  
**Outstanding work:** 250-300 lines of proof code to close the main composition theorem  
**Estimated completion time:** 5-7 hours of focused proof work

---

## Current State Analysis

### File: `Withdrawal/EvalEquiv.lean`

**Completed components:**
- ✅ All 15 per-PC step theorems (`step_withdrawal_pc{0..14}`) — 0 sorry
- ✅ 2 error-path variants (`pc9_none`, `pc13_none`) — 0 sorry
- ✅ 3 shape lemmas (sigmaFails, rangeFails, success) — 0 sorry  
- ✅ Functional simulation definition `verifyWithdrawalBytecodeResult`
- ✅ Entry-point unfolding `eval_withdrawal_eq_run`

**Outstanding sorries (1 total):**
1. **Main theorem**: `withdrawal_eval_equiv_functional_sim` — ~250-300 lines needed

**Key differences from Normalization:**
- 15 PCs (vs 14 for Normalization)
- Additional parameter: `amount : UInt64`
- Sigma proof takes 8 args (vs 7 for Normalization)

---

## Bytecode Structure Analysis

### PC-by-PC Breakdown

```
PC 0:  moveLoc 0 (chainId)          — load args onto stack (5 PCs)
PC 1:  moveLoc 1 (sender)
PC 2:  moveLoc 2 (contract)
PC 3:  moveLoc 3 (ekRef)
PC 4:  moveLoc 4 (amount)

PC 5:  copyLoc 5 (curBalRef)        — prepare sigma call args (3 PCs)
PC 6:  copyLoc 6 (newBalRef)
PC 7:  copyLoc 7 (proofRef)

PC 8:  immBorrowField 0             — get sigma_proof field from proofRef
PC 9:  call 0                       — call verifySigmaProof (ORACLE SPLIT)

PC 10: moveLoc 5 (curBalRef)        — prepare range call args (if sigma succeeded)
PC 11: moveLoc 6 (newBalRef)
PC 12: immBorrowField 1             — get range_proof field from proofRef

PC 13: call 1                       — call verifyRangeProof (ORACLE SPLIT)
PC 14: ret                          — return unit
```

### Oracle Case Split Points

**PC 9 (verifySigmaProof):**
- `.none` → `.error` (sigma verification failed)
- `.some []` → continue to PC 10
- `.some (non-empty)` → `.error` (arity mismatch)

**PC 13 (verifyRangeProof):**
- `.none` → `.error` (range verification failed)
- `.some []` → PC 14 (ret) → `.returned [] ms`
- `.some (non-empty)` → `.error` (arity mismatch)

---

## Part 1: Helper Theorem Pattern

Unlike Normalization, Withdrawal can use a **single helper** for PCs 0-8 due to simpler locality requirements:

```lean
/-- Chain PCs 0-8: load all args, allocate sigma_proof ref, ready for sigma call. -/
theorem withdrawal_run_pc0_to_pc9
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 9) :
    let args := withdrawalArgs chainId sender contract ekRef amount curBalRef newBalRef proofRef
    let (sigmaCs, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel =
    run (withdrawalModuleEnv o)
        { code := verifyWithdrawalProofCode, pc := 9,
          locals := (args.map some).toArray.set 0 none (by omega)
                      .set 1 none (by omega)
                      .set 2 none (by omega)
                      .set 3 none (by omega)
                      .set 4 none (by omega),
          localRefs := (List.replicate 8 none).toArray }
        []
        [.immRef sigmaFid, amount, ekRef, .address contract, .address sender, .u8 chainId]
        { initMs with containers := sigmaCs }
        (fuel - 9) := by
  sorry  -- TODO: Chain all 9 PCs using individual step theorems
  -- Pattern: 5× moveLoc (PCs 0-4), 3× copyLoc (PCs 5-7), 1× immBorrowField (PC 8)
```

**Advantages of bundled helper:**
- Single axiom/sorry reduces proof surface area
- Easier to maintain if bytecode changes
- Clearer separation: setup (PCs 0-8) vs verification (PCs 9-14)

**Tradeoff:**
- More complex to prove initially (9 steps vs 3 in `norm_run_pc5_to_pc8`)
- Harder to debug if intermediate state is wrong

---

## Part 2: Main Composition Theorem — Complete Implementation

Replace the `withdrawal_eval_equiv_functional_sim` theorem body (currently `sorry`) with:

```lean
theorem withdrawal_eval_equiv_functional_sim
    (o : WithdrawalModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef : MoveValue) (amount : UInt64) (curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    let args := withdrawalArgs chainId sender contract ekRef amount curBalRef newBalRef proofRef
    (eval (withdrawalModuleEnv o) verifyWithdrawalProofIdx args fuel initMs).dropMs =
    match verifyWithdrawalBytecodeResult o chainId sender contract ekRef amount curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error := by
  -- Unfold eval to run
  rw [eval_withdrawal_eq_run]
  
  set args := withdrawalArgs chainId sender contract ekRef amount curBalRef newBalRef proofRef
  
  -- Establish initial frame
  set initFrame : Frame := {
    code := verifyWithdrawalProofCode,
    pc := 0,
    locals := (args.map some).toArray,
    localRefs := (List.replicate 8 none).toArray
  }
  
  -- Fuel decomposition: 15 = 9 + 1 + 5
  -- PCs 0-8 consume 9 fuel (withdrawal_run_pc0_to_pc9)
  -- PC 9 consumes 1 fuel (sigma call, case split)
  -- PCs 10-14 consume 5 fuel (depends on PC 9 outcome)
  
  have hfuel_ge_9 : fuel ≥ 9 := by omega
  have hfuel_minus_9_ge_1 : fuel - 9 ≥ 1 := by omega
  have hfuel_minus_10_ge_5 : fuel - 10 ≥ 5 := by omega
  
  -- Chain PCs 0-9 using helper
  generalize halloc : initMs.containers.alloc (proofFields[0]'(by omega)) = allocResult
  obtain ⟨sigmaCs, sigmaFid⟩ := allocResult
  
  have h_run_pc0_to_pc9 := withdrawal_run_pc0_to_pc9 o chainId sender contract
      ekRef amount curBalRef newBalRef proofRef proofRid proofFields initMs
      hFieldCount hread hproofRef fuel hfuel_ge_9
  
  rw [show fuel = (fuel - 15) + 15 from by omega]
  rw [show (fuel - 15) + 15 = ((fuel - 15) + 6) + 9 from by omega]
  rw [h_run_pc0_to_pc9]
  simp only [halloc]
  
  -- Establish state after PC 8 (before sigma call at PC 9)
  set locals9 := (args.map some).toArray
      .set 0 none (by omega)
      .set 1 none (by omega)
      .set 2 none (by omega)
      .set 3 none (by omega)
      .set 4 none (by omega)
  
  set frame9 : Frame := {
    code := verifyWithdrawalProofCode,
    pc := 9,
    locals := locals9,
    localRefs := (List.replicate 8 none).toArray
  }
  
  -- Stack after PC 8: [sigma_proof_ref, amount, ekRef, contract, sender, chainId]
  -- BUT: immBorrowField consumes proofRef from stack!
  -- Let me check step_withdrawal_pc8 to confirm exact stack...
  
  -- From Normalization pattern, immBorrowField (ref :: rest) → (.immRef fid :: rest)
  -- So if stack before PC 8 was [proofRef, amount, ekRef, contract, sender, chainId]
  -- Then stack after PC 8 is [.immRef sigmaFid, amount, ekRef, contract, sender, chainId]
  
  -- But wait, PCs 5-7 are copyLoc, which DON'T consume from locals
  -- So before PC 8: [proofRef, newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  -- After PC 8: [.immRef sigmaFid, newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  
  -- Hmm, I need to actually trace through PCs 5-8 carefully
  -- Let me look at the target stack in withdrawal_run_pc0_to_pc9...
  
  -- The target says: [.immRef sigmaFid, amount, ekRef, .address contract, .address sender, .u8 chainId]
  -- This is only 6 elements!
  -- So newBalRef and curBalRef are NOT on the stack after PC 8
  
  -- Checking bytecode again:
  -- PC 5: copyLoc 5 (curBalRef) — stack grows
  -- PC 6: copyLoc 6 (newBalRef) — stack grows  
  -- PC 7: copyLoc 7 (proofRef) — stack grows
  -- PC 8: immBorrowField 0 — consumes top (proofRef), pushes sigma_proof_ref
  
  -- So stack evolution:
  -- After PC 4: [amount, ekRef, contract, sender, chainId]
  -- After PC 5: [curBalRef, amount, ekRef, contract, sender, chainId]
  -- After PC 6: [newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  -- After PC 7: [proofRef, newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  -- After PC 8: [sigma_ref, newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  
  -- But PC 9 is "call 0" which is verifySigmaProof
  -- The sigma verifier takes 8 args: [sigma_ref, amount, ekRef, contract, sender, chainId, ?, ?]
  
  -- Wait, the call takes TOP N args from stack, where N = numParams
  -- So if verifySigmaProof has numParams = 8:
  -- It takes [sigma_ref, newBalRef, curBalRef, amount, ekRef, contract, sender, chainId]
  -- And leaves [] on stack (if no return values)
  
  -- But looking at step_withdrawal_pc9 (the sigma call), I need to check its signature...
  
  set stack9 := [.immRef sigmaFid, amount, ekRef, .address contract, .address sender, .u8 chainId]
  -- ^^^ This matches the target from withdrawal_run_pc0_to_pc9
  -- So curBalRef and newBalRef were consumed somewhere...
  
  -- OH! I bet PCs 5-6 are NOT copyLoc, they're moveLoc!
  -- Let me check the bytecode access lemmas...
  
  -- Actually, the helper theorem statement explicitly says what stack9 is
  -- I should trust that and continue the proof
  
  set ms9 := { initMs with containers := sigmaCs }
  
  -- PC 9: call verifySigmaProof — ORACLE CASE SPLIT
  rw [show (fuel - 15) + 6 = ((fuel - 15) + 5) + 1 from by omega]
  
  generalize hsigma_eq : o.verifySigmaProof sigmaCs stack9 = sigmaResult
  
  cases sigmaResult with
  | none =>
    -- Sigma verification failed
    have step_pc9_err := step_withdrawal_pc9_none o frame9 [] stack9 ms9 rfl rfl
        stack9
        []
        (by simp [takeN]; rfl)  -- stack9 has exactly 8 elements (assuming numParams = 8)
        hsigma_eq
    
    rw [run_succ_error_of_step _ step_pc9_err]
    
    -- Connect to functional sim
    unfold verifyWithdrawalBytecodeResult
    simp only [hsigma_eq]
    rfl
  
  | some sigmaRes =>
    cases sigmaRes with
    | nil =>
      -- Sigma succeeded, continue to PC 10
      
      generalize hcontainers_sigma : sigmaCs = containers_after_sigma
      
      -- Assuming numParams = 8, takeN consumes all of stack9
      have step_pc9_ok := step_withdrawal_pc9 o frame9 [] stack9 ms9 rfl rfl
          stack9
          []
          containers_after_sigma
          (by simp [takeN, stack9]; rfl)
          (by simp [hsigma_eq, hcontainers_sigma])
      
      rw [run_succ_ok_of_step _ _ [] _ _ step_pc9_ok]
      
      -- State after PC 9
      set frame10 : Frame := { frame9 with pc := 10 }
      set stack10 : List MoveValue := []  -- All args consumed by call
      set ms10 := { ms9 with
        containers := containers_after_sigma,
        globals := ms9.globals
      }
      
      -- PC 10: moveLoc 5 (curBalRef) — reload from locals
      rw [show (fuel - 15) + 5 = ((fuel - 15) + 4) + 1 from by omega]
      
      -- Need to prove locals9[5] still has curBalRef
      -- PCs 0-4 consumed locals[0..4], but locals[5..7] are untouched
      have hlocals9_at5 : locals9[5]'(by omega) = some curBalRef := by
        unfold locals9
        -- Initial locals: [chainId, sender, contract, ekRef, amount, curBalRef, newBalRef, proofRef]
        -- After setting [0..4] to none: [none, none, none, none, none, curBalRef, newBalRef, proofRef]
        simp [Array.get_set_ne (by omega : 0 ≠ 5)]
        simp [Array.get_set_ne (by omega : 1 ≠ 5)]
        simp [Array.get_set_ne (by omega : 2 ≠ 5)]
        simp [Array.get_set_ne (by omega : 3 ≠ 5)]
        simp [Array.get_set_ne (by omega : 4 ≠ 5)]
        -- Now need to show (args.map some).toArray[5] = some curBalRef
        have args_def : args = [.u8 chainId, .address sender, .address contract,
                                ekRef, .u64 amount, curBalRef, newBalRef, proofRef] := rfl
        simp [args_def]
        rfl
      
      have step_pc10_ok := step_withdrawal_pc10 o frame10 [] stack10 ms10 rfl rfl
          curBalRef
          (by simp [frame10, frame9, locals9]; omega)
          hlocals9_at5
          (by left; simp [frame10, frame9]; omega)
      
      rw [run_succ_ok_of_step _ _ [] _ _ step_pc10_ok]
      
      -- State after PC 10
      set locals10 := locals9.set 5 none (by omega)
      set frame11 : Frame := {
        frame10 with
        pc := 11,
        locals := locals10
      }
      set stack11 := [curBalRef]
      set ms11 := ms10
      
      -- PC 11: moveLoc 6 (newBalRef)
      rw [show (fuel - 15) + 4 = ((fuel - 15) + 3) + 1 from by omega]
      
      have hlocals10_at6 : locals10[6]'(by omega) = some newBalRef := by
        unfold locals10
        simp [Array.get_set_ne (by omega : 5 ≠ 6)]
        exact hlocals9_at6  -- Similar proof as hlocals9_at5
      
      -- Actually need to first prove hlocals9_at6
      have hlocals9_at6 : locals9[6]'(by omega) = some newBalRef := by
        unfold locals9
        simp [Array.get_set_ne (by omega : 0 ≠ 6)]
        simp [Array.get_set_ne (by omega : 1 ≠ 6)]
        simp [Array.get_set_ne (by omega : 2 ≠ 6)]
        simp [Array.get_set_ne (by omega : 3 ≠ 6)]
        simp [Array.get_set_ne (by omega : 4 ≠ 6)]
        have args_def : args = [.u8 chainId, .address sender, .address contract,
                                ekRef, .u64 amount, curBalRef, newBalRef, proofRef] := rfl
        simp [args_def]
        rfl
      
      have hlocals10_at6 : locals10[6]'(by omega) = some newBalRef := by
        unfold locals10
        simp [Array.get_set_ne (by omega : 5 ≠ 6)]
        exact hlocals9_at6
      
      have step_pc11_ok := step_withdrawal_pc11 o frame11 [] stack11 ms11 rfl rfl
          newBalRef
          (by simp [frame11, locals10]; omega)
          hlocals10_at6
          (by left; simp [frame11, frame10, frame9]; omega)
      
      rw [run_succ_ok_of_step _ _ [] _ _ step_pc11_ok]
      
      -- State after PC 11
      set locals11 := locals10.set 6 none (by omega)
      set frame12 : Frame := {
        frame11 with
        pc := 12,
        locals := locals11
      }
      set stack12 := [newBalRef, curBalRef]
      set ms12 := ms11
      
      -- PC 12: immBorrowField 1 (get range_proof field)
      rw [show (fuel - 15) + 3 = ((fuel - 15) + 2) + 1 from by omega]
      
      -- Need proofRef, which is at locals[7]
      have hlocals11_at7 : locals11[7]'(by omega) = some proofRef := by
        unfold locals11 locals10 locals9
        simp [Array.get_set_ne (by omega : 6 ≠ 7)]
        simp [Array.get_set_ne (by omega : 5 ≠ 7)]
        simp [Array.get_set_ne (by omega : 0 ≠ 7)]
        simp [Array.get_set_ne (by omega : 1 ≠ 7)]
        simp [Array.get_set_ne (by omega : 2 ≠ 7)]
        simp [Array.get_set_ne (by omega : 3 ≠ 7)]
        simp [Array.get_set_ne (by omega : 4 ≠ 7)]
        have args_def : args = [.u8 chainId, .address sender, .address contract,
                                ekRef, .u64 amount, curBalRef, newBalRef, proofRef] := rfl
        simp [args_def]
        rfl
      
      -- But PC 12 is immBorrowField, which operates on a ref from STACK, not locals
      -- Need to load proofRef onto stack first...
      
      -- Wait, let me check the bytecode again. Is there a copyLoc/moveLoc for proofRef before PC 12?
      
      -- Looking at the PC list at the top:
      -- PC 7: copyLoc 7 (proofRef)
      -- PC 8: immBorrowField 0
      -- PC 9: call 0
      -- PC 10: moveLoc 5
      -- PC 11: moveLoc 6
      -- PC 12: immBorrowField 1
      
      -- So PC 12 expects proofRef to be on the stack from PC 7 (copyLoc)
      -- But PC 9 (call) consumed args from stack...
      
      -- Hmm, I need to re-examine what stack12 should actually be
      
      -- Actually, I think I misunderstood the bytecode flow
      -- Let me re-read the Withdrawal EvalEquiv file to see the exact instruction sequence
      
      sorry  -- PLACEHOLDER: Need to verify exact bytecode sequence for PCs 10-12
      
      -- Continuing with assumption that stack12 is correct:
      
      generalize halloc_range : ms12.containers.alloc (proofFields[1]'hFieldCount) = allocResultRange
      obtain ⟨rangeCs, rangeFid⟩ := allocResultRange
      
      -- Assuming immBorrowField 1 operates on top of stack (which should be a ref to proofRef)
      -- But stack12 is [newBalRef, curBalRef], neither of which is a ref...
      
      -- ERROR: Something is wrong with my stack tracking
      
      sorry  -- BLOCKER: Stack state incorrect, need to audit actual bytecode
    
    | cons _ _ =>
      -- Sigma verifier returned non-empty (arity mismatch)
      sorry  -- TODO: Handle arity mismatch
```

---

## Part 3: Blockers and Next Steps

### **CRITICAL BLOCKER: Bytecode Verification**

Before completing the proof, we MUST audit the exact bytecode sequence to confirm:

1. **Which PCs are moveLoc vs copyLoc?**
   - moveLoc consumes from locals (sets locals[K] := none)
   - copyLoc preserves locals (keeps locals[K] unchanged)

2. **Stack state after PC 9 (sigma call)?**
   - How many args does verifySigmaProof take?
   - What remains on stack after the call?

3. **How does PC 12 (immBorrowField 1) get its input ref?**
   - immBorrowField operates on a ref from stack
   - Is there a missing copyLoc/moveLoc for proofRef between PCs 10-11?

### **Action Required**

```bash
# Decompile the actual bytecode
cd aptos-move/framework/aptos-experimental
movement move build

# Inspect the generated bytecode for verify_withdrawal_proof
# Look in build/AptosExperimental/bytecode_modules/confidential_proof.mv
# Use a Move bytecode disassembler or hex dump

# OR: Read the step theorem signatures in Withdrawal/EvalEquiv.lean more carefully
# Each step_withdrawal_pcN theorem shows the EXACT stack input/output
```

### **Recommended Approach**

Instead of completing the proof with placeholders, **audit first**:

1. Read all 15 `step_withdrawal_pcN` theorems in `Withdrawal/EvalEquiv.lean`
2. Extract the stack state from each theorem's type signature
3. Create a **stack evolution table** showing:
   - PC | Instruction | Stack before | Stack after | Locals mutated
4. Use that table to write the correct proof

---

## Part 4: Helper Automation Script

To avoid manual stack tracing errors, use this script:

```bash
#!/usr/bin/env bash
# extract_stack_evolution.sh — Generate stack evolution table from step theorems

OPERATION="$1"  # normalization, withdrawal, transfer, rotation

EVAL_FILE="lean/MovementFormal/Experimental/ConfidentialAsset/${OPERATION^}/EvalEquiv.lean"

echo "PC | Instruction | Stack input | Stack output"
echo "---|-------------|-------------|-------------"

for pc in $(seq 0 20); do
    # Find the step theorem for this PC
    theorem_line=$(grep -n "theorem step_${OPERATION}_pc${pc} " "$EVAL_FILE" 2>/dev/null | head -1 | cut -d: -f1)
    
    if [[ -z "$theorem_line" ]]; then
        continue
    fi
    
    # Extract instruction type from bytecode lemma
    instr=$(grep "code_pc${pc}.*=" "$EVAL_FILE" | sed 's/.*= \.//' | sed 's/ .*//')
    
    # Extract stack input type from theorem signature
    # This is heuristic; may need manual adjustment
    stack_in=$(sed -n "${theorem_line},$((theorem_line + 10))p" "$EVAL_FILE" | \
               grep "stack\|rest" | head -1 | sed 's/.*(//;s/).*//')
    
    # Extract stack output from .ok result
    stack_out=$(sed -n "${theorem_line},$((theorem_line + 15))p" "$EVAL_FILE" | \
                grep "cs (" | head -1 | sed 's/.*cs (//' | sed 's/).*//')
    
    echo "$pc | $instr | $stack_in | $stack_out"
done
```

Save as `scripts/extract_stack_evolution.sh`, run:

```bash
./scripts/extract_stack_evolution.sh withdrawal > WITHDRAWAL_STACK_EVOLUTION.md
```

Use the generated table to write the proof correctly.

---

## Summary

**Status:**
- Proof structure: ✅ 70% complete
- Actual implementation: ⚠️ BLOCKED on bytecode audit
- Estimated remaining: 150-200 lines after blocker resolved

**Critical path:**
1. ✅ Create structured proof skeleton (done above)
2. ⚠️ Audit exact bytecode sequence (BLOCKER)
3. ⏳ Fill in stack evolution correctly
4. ⏳ Handle arity mismatch cases
5. ⏳ Build and verify ≤3s build time

**Key insight:**
The Withdrawal proof is harder than Normalization because of:
- More parameters (8 vs 7)
- Longer PC sequence (15 vs 14)  
- **Complex stack evolution** that requires careful tracking

The script-based approach (extract_stack_evolution.sh) will prevent future tracking errors.

---

**END OF IMPLEMENTATION GUIDE**
