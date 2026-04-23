# Bytecode Transcription Quick Start

**Purpose:** Fast guide to transcribing Move bytecode to Lean for EvalEquiv proofs  
**Audience:** Developers writing Phase 4 proofs  
**Time:** 30 minutes to transcribe a typical 15-instruction function

---

## Overview

**What is bytecode transcription?**  
Converting Move bytecode (from `movement move compile --dump-bytecode`) into Lean function definitions that the EvalEquiv proof reasons about.

**Why do we need it?**  
EvalEquiv proofs show that bytecode execution matches functional simulation. We need Lean representations of the bytecode to state and prove these theorems.

**Where does it go?**  
`lean/MovementFormal/Experimental/ConfidentialAsset/<Operation>/Bytecode.lean` (or inline in EvalEquiv.lean)

---

## Step-by-Step Process

### Step 1: Get the Bytecode (5 min)

```bash
cd aptos-move/framework/aptos-experimental

# Compile with bytecode dump
movement move compile --dump-bytecode

# Find your function's bytecode
# Look in build/aptos-experimental/bytecode_modules/confidential_asset.mv
# Or use movement move disassemble
```

**Example output (verify_withdrawal_proof):**
```
public fun verify_withdrawal_proof(proof: &vector<u8>, public_inputs: &vector<u8>): bool {
B0:
  0: ImmBorrowLoc[0](proof: &vector<u8>)
  1: ImmBorrowLoc[1](public_inputs: &vector<u8>)
  2: Call verify_withdrawal_proof_internal(&vector<u8>, &vector<u8>): bool
  3: Ret
}
```

### Step 2: Count Instructions (1 min)

Count total PCs (0 through N).

**Withdrawal example:** 4 instructions (PC 0-3)  
**Transfer example:** 24 instructions (PC 0-23)  
**Registration example:** 55 instructions (PC 0-54)

**Estimate build time:** ~0.02s per instruction (4 inst → 0.08s, 55 inst → 1.1s base)

### Step 3: Create PC Lookup Function (10 min)

**Pattern:**
```lean
def withdrawalProofPCs : Nat → Option Instruction
  | 0 => some (.immBorrowLoc 0)
  | 1 => some (.immBorrowLoc 1)
  | 2 => some (.call verifyWithdrawalProofInternalIndex)
  | 3 => some .ret
  | _ => none
```

**Instruction translation table:**

| Bytecode | Lean |
|----------|------|
| `ImmBorrowLoc[K]` | `.immBorrowLoc K` |
| `MoveLoc[K]` | `.moveLoc K` |
| `StLoc[K]` | `.stLoc K` |
| `Call <func>` | `.call <funcIndex>` |
| `Ret` | `.ret` |
| `ImmBorrowField[K]` | `.immBorrowField K` |
| `Pack[K]` | `.pack K` |
| `Unpack[K]` | `.unpack K` |

**Where to get function indices?**
- Look up in module definition: `confidential_asset.functions[N]`
- Or use pattern from existing proofs (e.g., Transfer.lean)

### Step 4: Classify Instructions (5 min)

Group instructions by type to choose step lemmas:

**Categories:**
1. **Load/Store:** ImmBorrowLoc, MoveLoc, StLoc
2. **Struct ops:** ImmBorrowField, Pack, Unpack
3. **Calls:** Call (native or Move function)
4. **Control flow:** Ret, Branch, Abort

**Withdrawal example:**
- PC 0-1: Load (ImmBorrowLoc) → use `step_immBorrowLoc_frame`
- PC 2: Call → use `step_call_frame`
- PC 3: Ret → inline

### Step 5: Write Per-PC Theorems (10 min for simple ops, 30 min for complex)

**Template (Load instruction):**
```lean
theorem step_pc0
    {env : ModuleEnvironment}
    {proofRef publicInputsRef : RefValue}
    {locals : Locals}
    {cs : CallStack}
    {ms : MemoryStore}
    : step env (WithdrawalState 0 proofRef publicInputsRef locals []) cs ms =
      StepResult.continue
        (WithdrawalState 1 proofRef publicInputsRef locals [.ref proofRef])
        cs ms := by
  simp only [step, WithdrawalState]
  rw [step_immBorrowLoc_frame]
  rfl
```

**Key points:**
- Name theorem `step_pcN` where N is the PC
- Before state: `WithdrawalState N ... stackBefore`
- After state: `WithdrawalState (N+1) ... stackAfter`
- Stack changes: push reference for ImmBorrowLoc, pop for MoveLoc, etc.
- Proof: `simp only [step, OperationState]`, `rw [step_LEMMA]`, `rfl`

**Call instruction (more complex):**
```lean
theorem step_pc2_call
    {env : ModuleEnvironment}
    {proofRef publicInputsRef : RefValue}
    {locals : Locals}
    {cs : CallStack}
    {ms : MemoryStore}
    {proof publicInputs : Vector UInt8 _}
    (h_proof : readRef ms proofRef = some (.vector proof))
    (h_inputs : readRef ms publicInputsRef = some (.vector publicInputs))
    : step env (WithdrawalState 2 proofRef publicInputsRef locals [.ref publicInputsRef, .ref proofRef]) cs ms =
      StepResult.continue
        (WithdrawalState 3 proofRef publicInputsRef locals [.bool (withdrawalOracle proof publicInputs)])
        cs ms := by
  simp only [step, WithdrawalState]
  rw [step_call_frame]
  simp [h_proof, h_inputs, withdrawalOracle]
  rfl
```

**Key: hypotheses for memory reads** (`h_proof`, `h_inputs`)

---

## Quick Reference

### Common Instruction Patterns

**ImmBorrowLoc (push reference to local K):**
```lean
step (OperationState N ... []) = OperationState (N+1) ... [.ref (locals[K])]
-- Proof: rw [step_immBorrowLoc_frame]; rfl
```

**MoveLoc (move local K to stack):**
```lean
step (OperationState N ... []) = OperationState (N+1) ... [locals[K]]
-- Proof: rw [step_moveLoc_frame]; rfl
```

**Call (native function):**
```lean
step (OperationState N ... [args]) = OperationState (N+1) ... [oracle_result]
-- Proof: rw [step_call_frame]; simp [oracle]; rfl
-- Hypotheses needed for args in memory
```

**Ret (return top of stack):**
```lean
step (OperationState N ... [result]) = StepResult.returned [result]
-- Proof: simp only [step, OperationState]; rfl
```

### Build Time Budget

| Instructions | Expected Build Time | Status if Exceeded |
|--------------|---------------------|---------------------|
| 1-10 | 0.1-0.3s | ✅ Normal |
| 11-20 | 0.3-0.7s | ✅ Normal |
| 21-30 | 0.7-1.5s | ✅ Acceptable |
| 31-50 | 1.5-3.0s | 🟡 Review architecture |
| 51-70 | 3.0-5.0s | 🟡 Use step-lemma library |
| >70 | >5.0s | 🔴 Refactor or split |

**If build time exceeds budget:**
1. Check for chained state definitions → use symbolic state
2. Check for bound proofs in statements → use Array.get?
3. Check for bare `simp` → use `simp only [...]`
4. Add `@[irreducible]` to state definition

---

## Examples

### Simple Operation (Normalization, 14 PCs)

**Bytecode structure:**
- 0-1: Load arguments (ImmBorrowLoc × 2)
- 2-12: Preparation (MoveLoc, ImmBorrowField, etc.)
- 13: Call verify_normalization_proof_internal
- 14: Ret

**Transcription time:** ~20 min  
**Build time:** 0.5s

### Medium Operation (Withdrawal, 15 PCs)

**Bytecode structure:**
- 0-1: Load arguments
- 2-13: Preparation + oracle call
- 14: Ret

**Transcription time:** ~20 min  
**Build time:** 0.5s

### Complex Operation (Transfer, 24 PCs)

**Bytecode structure:**
- 0-5: Load sender/recipient arguments
- 6-15: Sender verification sub-call
- 16-22: Recipient verification sub-call
- 23: Ret

**Transcription time:** ~40 min  
**Build time:** 0.7s

### Very Complex Operation (Registration, 55 PCs)

**Bytecode structure:**
- 0-10: Load arguments
- 11-25: Schnorr verification sub-call
- 26-40: HMAC verification sub-call
- 41-50: Container creation
- 51-55: Return

**Transcription time:** ~90 min  
**Build time:** 3.0s

---

## Troubleshooting

### Error: "Type mismatch in stack"

**Symptom:**
```
expected: [.ref proofRef, .ref inputsRef]
got:      [.ref inputsRef, .ref proofRef]
```

**Cause:** Stack order is LIFO (last-in-first-out).

**Fix:** Reverse stack order in theorem statement.

### Error: "Failed to unify Locals"

**Symptom:**
```
expected: locals.set 0 val
got:      locals
```

**Cause:** Forgot to update locals after StLoc.

**Fix:** Add locals update in after-state.

### Build Time Exceeds 3s

**Symptoms:**
- File takes >3s to build
- Heartbeat warnings
- `(deterministic) timeout` errors

**Causes:**
1. Chained state definitions (O(N²))
2. Bound proofs in statements
3. Bare `simp` (unpredictable)

**Fixes:**
1. Use symbolic state with @[irreducible]
2. Use Array.get? instead of Array.get with bounds
3. Use `simp only [explicit list]`

---

## Checklist

### Before Starting
- [ ] Get bytecode (movement move compile --dump-bytecode)
- [ ] Count instructions (determine N)
- [ ] Estimate build time (N × 0.02s base)

### During Transcription
- [ ] Create PC lookup function (0 through N)
- [ ] Write step_pc0
- [ ] Write step_pc1
- [ ] ... (continue for all PCs)
- [ ] Write oracle call theorem (if any)
- [ ] Write return theorem

### After Transcription
- [ ] Build: lake build <Module>
- [ ] Check build time (should be ≤3s)
- [ ] Run: ./audit/verify-ca.sh --op <operation> --stack lean
- [ ] Check axioms: ./scripts/check_axioms.sh

---

**Time estimate:** 30-90 minutes depending on instruction count  
**Build time target:** ≤3s  
**See:** WITHDRAWAL_PROOF_WORKED_EXAMPLE.md for complete example
