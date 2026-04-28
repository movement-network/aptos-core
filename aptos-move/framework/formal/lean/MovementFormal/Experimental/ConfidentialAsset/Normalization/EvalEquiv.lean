import MovementFormal.MoveModel.Programs.Normalization
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.Experimental.ConfidentialAsset.Normalization.BytecodeLemmas
import Mathlib.Tactic.Common
import Mathlib.Tactic.Set

/-!
# Bytecode eval ≡ functional simulation for `verify_normalization_proof` — Phase 4

Proves that the `verify_normalization_proof` bytecode (14 instructions dispatching to
`verify_normalization_sigma_proof` + `verify_new_balance_range_proof`) evaluates to the
functional simulation result under the module oracle.

The proof follows the architecture from `Registration/EvalEquivRebuild.lean`:
- Per-PC step-lemma dispatch from `MovementFormal.MoveModel.StepLemmas.*`.
- `run_succ_ok_of_step` to thread fuel through each PC.

The dispatcher is short (14 PCs) — the interesting proof content is in the oracle
behavior, not in the bytecode threading. The sigma-verifier and Bulletproofs
range-proof sub-calls are opaque (`NormalizationModuleOracle`); the bytecode-level
proof here shows the dispatcher correctly wires arguments and field borrows.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Normalization

/-! ## Entry point args helper -/

def normalizationArgs (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   ekRef, curBalRef, newBalRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem normalizationModuleEnv_functions_size (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions.size = 3 := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn0_numParams (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[0].numParams = 7 := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn0_numReturns (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[0].numReturns = 0 := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn0_body (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn1_numParams (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[1].numParams = 2 := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn1_numReturns (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[1].numReturns = 0 := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn1_body (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[1].body = .nativeRef o.verifyRangeProof := by
  unfold normalizationModuleEnv; rfl

@[simp] theorem normalizationModuleEnv_fn2_body (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[2].body =
      .bytecode verifyNormalizationProofCode 7 := by
  unfold normalizationModuleEnv verifyNormalizationProofDesc; rfl

@[simp] theorem normalizationModuleEnv_fn2_numParams (o : NormalizationModuleOracle) :
    (normalizationModuleEnv o).functions[2].numParams = 7 := by
  unfold normalizationModuleEnv verifyNormalizationProofDesc; rfl

/-! ## Bytecode access lemmas

All 14 instruction lookups proved by `rfl` after unfolding. -/

-- Bytecode lemmas extracted to BytecodeLemmas.lean
private abbrev code_size := BytecodeLemmas.code_size
private abbrev code_pc0  := BytecodeLemmas.instr0_eq
private abbrev code_pc1  := BytecodeLemmas.instr1_eq
private abbrev code_pc2  := BytecodeLemmas.instr2_eq
private abbrev code_pc3  := BytecodeLemmas.instr3_eq
private abbrev code_pc4  := BytecodeLemmas.instr4_eq
private abbrev code_pc5  := BytecodeLemmas.instr5_eq
private abbrev code_pc6  := BytecodeLemmas.instr6_eq
private abbrev code_pc7  := BytecodeLemmas.instr7_eq
private abbrev code_pc8  := BytecodeLemmas.instr8_eq
private abbrev code_pc9  := BytecodeLemmas.instr9_eq
private abbrev code_pc10 := BytecodeLemmas.instr10_eq
private abbrev code_pc11 := BytecodeLemmas.instr11_eq
private abbrev code_pc12 := BytecodeLemmas.instr12_eq
private abbrev code_pc13 := BytecodeLemmas.instr13_eq

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_normalization_eq_run (o : NormalizationModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (normalizationModuleEnv o) verifyNormalizationProofIdx args fuel initMs =
      run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyNormalizationProofIdx
  simp only [normalizationModuleEnv_functions_size,
             show (2 : Nat) < 3 from by decide, dif_pos,
             normalizationModuleEnv_fn2_body,
             normalizationModuleEnv_fn2_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems

Each theorem proves one instruction step for arbitrary frame state satisfying the
code and PC constraints. -/

theorem step_normalization_pc0
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 0)
    (v0 : MoveValue)
    (hlt : 0 < frame.locals.size)
    (hv : frame.locals[0]'hlt = some v0)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨
      ∃ (h : 0 < frame.localRefs.size), frame.localRefs[0]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) }
           cs (v0 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by
    simp only [hcode, hpc]; exact code_pc0
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    0 v0 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 1 from by omega] at h; exact h

theorem step_normalization_pc1
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 1)
    (v1 : MoveValue)
    (hlt : 1 < frame.locals.size)
    (hv : frame.locals[1]'hlt = some v1)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨
      ∃ (h : 1 < frame.localRefs.size), frame.localRefs[1]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) }
           cs (v1 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by
    simp only [hcode, hpc]; exact code_pc1
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    1 v1 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 2 from by omega] at h; exact h

theorem step_normalization_pc2
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 2)
    (v2 : MoveValue)
    (hlt : 2 < frame.locals.size)
    (hv : frame.locals[2]'hlt = some v2)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨
      ∃ (h : 2 < frame.localRefs.size), frame.localRefs[2]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) }
           cs (v2 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by
    simp only [hcode, hpc]; exact code_pc2
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    2 v2 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 3 from by omega] at h; exact h

theorem step_normalization_pc3
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 3)
    (v3 : MoveValue)
    (hlt : 3 < frame.locals.size)
    (hv : frame.locals[3]'hlt = some v3)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨
      ∃ (h : 3 < frame.localRefs.size), frame.localRefs[3]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) }
           cs (v3 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by
    simp only [hcode, hpc]; exact code_pc3
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    3 v3 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 4 from by omega] at h; exact h

theorem step_normalization_pc4
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 4)
    (v4 : MoveValue)
    (hlt : 4 < frame.locals.size)
    (hv : frame.locals[4]'hlt = some v4)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨
      ∃ (h : 4 < frame.localRefs.size), frame.localRefs[4]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) }
           cs (v4 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by
    simp only [hcode, hpc]; exact code_pc4
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    4 v4 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 5 from by omega] at h; exact h

theorem step_normalization_pc5
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 5)
    (v5 : MoveValue)
    (hlt : 5 < frame.locals.size)
    (hv : frame.locals[5]'hlt = some v5)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨
      ∃ (h : 5 < frame.localRefs.size), frame.localRefs[5]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6 } cs (v5 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 5 := by
    simp only [hcode, hpc]; exact code_pc5
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    5 v5 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 6 from by omega] at h; exact h

theorem step_normalization_pc6
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 6)
    (v6 : MoveValue)
    (hlt : 6 < frame.locals.size)
    (hv : frame.locals[6]'hlt = some v6)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨
      ∃ (h : 6 < frame.localRefs.size), frame.localRefs[6]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 7 } cs (v6 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by
    simp only [hcode, hpc]; exact code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := normalizationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v6 hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

theorem step_normalization_pc7
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 7)
    (rid : RefId) (proofFields : List MoveValue)
    (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (normalizationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 8 } cs (.immRef fid :: rest)
           { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by
    simp only [hcode, hpc]; exact code_pc7
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 8 from by omega]

theorem step_normalization_pc8
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 8)
    (args : List MoveValue) (rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 7 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 9 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by
    simp only [hcode, hpc]; exact code_pc8
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn0_numParams, htake, normalizationModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [normalizationModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 9 from by omega]

theorem step_normalization_pc8_multi
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 8)
    (args : List MoveValue) (rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 7 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some (v :: vs, containers')) :
    step (normalizationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by
    simp only [hcode, hpc]; exact code_pc8
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn0_numParams, htake, normalizationModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [normalizationModuleEnv_fn0_numReturns]
  | cons w ws => simp [normalizationModuleEnv_fn0_numReturns]

theorem step_normalization_pc8_none
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 8)
    (args : List MoveValue) (rest : List MoveValue)
    (htake : takeN stack 7 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (normalizationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by
    simp only [hcode, hpc]; exact code_pc8
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn0_numParams, htake, normalizationModuleEnv_fn0_body, himpl]

theorem step_normalization_pc9
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 9)
    (v5 : MoveValue)
    (hlt : 5 < frame.locals.size)
    (hv : frame.locals[5]'hlt = some v5)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨
      ∃ (h : 5 < frame.localRefs.size), frame.localRefs[5]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10, locals := frame.locals.set 5 none (by omega) }
           cs (v5 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by
    simp only [hcode, hpc]; exact code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 10 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 10 from by omega]

theorem step_normalization_pc10
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 10)
    (v6 : MoveValue)
    (hlt : 6 < frame.locals.size)
    (hv : frame.locals[6]'hlt = some v6)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨
      ∃ (h : 6 < frame.localRefs.size), frame.localRefs[6]'h = none) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 6 none (by omega) }
           cs (v6 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by
    simp only [hcode, hpc]; exact code_pc10
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 11 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 11 from by omega]

theorem step_normalization_pc11
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 11)
    (rid : RefId) (proofFields : List MoveValue)
    (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (normalizationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 12 } cs (.immRef fid :: rest)
           { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by
    simp only [hcode, hpc]; exact code_pc11
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 12 from by omega]

theorem step_normalization_pc12
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 12)
    (args : List MoveValue) (rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some ([], containers')) :
    step (normalizationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 13 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by
    simp only [hcode, hpc]; exact code_pc12
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn1_numParams, htake, normalizationModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [normalizationModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 13 from by omega]

theorem step_normalization_pc12_multi
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 12)
    (args : List MoveValue) (rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some (v :: vs, containers')) :
    step (normalizationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by
    simp only [hcode, hpc]; exact code_pc12
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn1_numParams, htake, normalizationModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [normalizationModuleEnv_fn1_numReturns]
  | cons w ws => simp [normalizationModuleEnv_fn1_numReturns]

theorem step_normalization_pc12_none
    (o : NormalizationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 12)
    (args : List MoveValue) (rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = none) :
    step (normalizationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by
    simp only [hcode, hpc]; exact code_pc12
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (normalizationModuleEnv o).functions.size by simp)]
  simp only [normalizationModuleEnv_fn1_numParams, htake, normalizationModuleEnv_fn1_body, himpl]

theorem step_normalization_pc13
    (o : NormalizationModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyNormalizationProofCode) (hpc : frame.pc = 13) :
    step (normalizationModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by
    simp only [hcode, hpc]; exact code_pc13
  exact StepLemmas.step_ret_top hpc_lt hc

/-! ## Functional simulation

The functional simulation captures the high-level behavior of the dispatcher:
it wires chain_id, sender, contract, ek, current_balance, new_balance, and the
proof's sigma_proof field (via ImmBorrowField) to the sigma verifier, then
new_balance and the proof's zkrp_new_balance field to the range verifier.

The result is `.returned [] ms_final` on success (both sub-calls return `some`)
or `.error` if either sub-call fails. -/

inductive NormalizationBytecodeResult where
  | returned (ms : MachineState)
  | error

def verifyNormalizationBytecodeResult
    (o : NormalizationModuleOracle) (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef : MoveValue) (_proofRid : RefId)
    (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length) : NormalizationBytecodeResult :=
  let (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
  let sigmaArgs := [.u8 chainId, .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, .immRef sigmaFid]
  match o.verifySigmaProof cs1 sigmaArgs with
  | none => .error
  | some ([], cs2) =>
    let (cs3, zkrpFid) := cs2.alloc (proofFields[1]'hFieldCount)
    let rangeArgs := [newBalRef, .immRef zkrpFid]
    match o.verifyRangeProof cs3 rangeArgs with
    | none => .error
    | some ([], cs4) => .returned { initMs with containers := cs4, globals := initMs.globals }
    | some (_ :: _, _) => .error
  | some (_ :: _, _) => .error

/-! ## Functional simulation shape lemmas -/

/-- Functional simulation shape lemma: sigma failure → .error -/
theorem verifyNormalizationBytecodeResult_sigmaFails
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hsigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    verifyNormalizationBytecodeResult o chainId sender contract
        ekRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyNormalizationBytecodeResult
  simp [hsigmaFail]

/-- Functional simulation shape lemma: range failure → .error -/
theorem verifyNormalizationBytecodeResult_rangeFails
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs : ContainerStore)
    (sigmaFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
                 some ([], sigmaCs))
    (hrangeFail : ∀ cs args, o.verifyRangeProof cs args = none) :
    verifyNormalizationBytecodeResult o chainId sender contract
        ekRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyNormalizationBytecodeResult
  simp only [halloc0, hsigmaOk, hrangeFail]

/-- Functional simulation shape lemma: happy path → .returned -/
theorem verifyNormalizationBytecodeResult_success
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs rangeCs : ContainerStore)
    (sigmaFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
                 some ([], rangeCs))
    (hrange : o.verifyRangeProof (rangeCs.alloc (proofFields[1]'hFieldCount)).1
                  [newBalRef, .immRef (rangeCs.alloc (proofFields[1]'hFieldCount)).2] =
               some ([], (rangeCs.alloc (proofFields[1]'hFieldCount)).1)) :
    verifyNormalizationBytecodeResult o chainId sender contract
        ekRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .returned { initMs with containers := (rangeCs.alloc (proofFields[1]'hFieldCount)).1, globals := initMs.globals } := by
  unfold verifyNormalizationBytecodeResult
  simp only [halloc0, hsigmaOk, hrange]

/-! ## Helper lemmas: Multi-PC composition

These helpers chain consecutive PCs to reduce boilerplate in the main proof. -/

/-- Chain PCs 0-4: moveLoc instructions loading chainId, sender, contract, ekRef, curBalRef onto stack.

This chains 5 consecutive moveLoc instructions:
- PC 0: moveLoc 0 (chainId) - pushes chainId, clears locals[0]
- PC 1: moveLoc 1 (sender) - pushes sender, clears locals[1]
- PC 2: moveLoc 2 (contract) - pushes contract, clears locals[2]
- PC 3: moveLoc 3 (ekRef) - pushes ekRef, clears locals[3]
- PC 4: moveLoc 4 (curBalRef) - pushes curBalRef, clears locals[4]

Final state: stack has [curBalRef, ekRef, contract, sender, chainId], locals[0-4] are none. -/
-- Temporarily keep as axiom due to array manipulation complexity in tactic mode.
-- The proof structure is clear (5 consecutive moveLoc steps), but Lean's
-- "Expected type must not contain free variables" constraint blocks completion
-- of array indexing proofs in by-tactic context. Next steps: research workarounds
-- (term-mode construction, revert/intro patterns, or alternative proof structuring).
theorem norm_run_pc0_to_pc5
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (initMs : MachineState)
    (fuel : Nat)
    (hfuel : fuel ≥ 5) :
    let args := normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef
    ∃ (locals5 : Array (Option MoveValue)),
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel =
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 5,
          locals := locals5,
          localRefs := (List.replicate 7 none).toArray }
        []
        [curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
        initMs
        (fuel - 5) := by
  intro args
  -- Initial frame
  let f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := (args.map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
  have hf0_size : f0.locals.size = 7 := by
    show (args.map some).toArray.size = 7; simp [args, normalizationArgs]
  -- Step 1 at PC 0 (moveLoc 0 → push chainId, locals[0] := none)
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by
    show (args.map some).toArray[0]'hf0_lt0 = _; simp [args, normalizationArgs]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  -- f1 frame derived from step1's RHS
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7
    rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]
    show (args.map some).toArray[1]'_ = _; simp [args, normalizationArgs]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7
    rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]
    show (args.map some).toArray[2]'_ = _; simp [args, normalizationArgs]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7
    rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]
    show (args.map some).toArray[3]'_ = _; simp [args, normalizationArgs]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7
    rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]
    show (args.map some).toArray[4]'_ = _; simp [args, normalizationArgs]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  -- Provide the witness for the existential and chain 5 steps.
  refine ⟨f4.locals.set 4 none hf4_lt4, ?_⟩
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 5 := ⟨fuel - 5, by omega⟩
  rw [hef]
  rw [show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step1,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step2,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step3,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step4,
      StepLemmas.run_succ_ok_of_step ef _ _ _ _ step5]
  -- After 5 unfolds, fuel arithmetic and frame structure both need normalization.
  show run (normalizationModuleEnv o)
        { code := f4.code, pc := 5, locals := f4.locals.set 4 none hf4_lt4,
          localRefs := f4.localRefs } []
        [curBalRef, ekRef, .address contract, .address sender, .u8 chainId] initMs
        (ef + 1 + 1 + 1 + 1 + 1 - 5) = _
  have hf4_code : f4.code = verifyNormalizationProofCode := rfl
  have hf4_refs : f4.localRefs = (List.replicate 7 none).toArray := rfl
  rw [hf4_code, hf4_refs, show (ef + 1 + 1 + 1 + 1 + 1 - 5) = ef from by omega]

/-- Chain PCs 5-7: copyLoc 5 (newBalRef), copyLoc 6 (proofRef), immBorrowField 0
    (allocate ref to sigma_proof field of the proof struct).

PC 7 consumes the proofRef from the top of the stack and replaces it with `.immRef sigmaFid`.
The locals don't change across these three steps (copyLoc and immBorrowField are
non-destructive on locals). -/
theorem norm_run_pc5_to_pc8
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (locals5 : Array (Option MoveValue))
    (hSize : locals5.size = 7)
    (hLocal5 : locals5[5]'(by rw [hSize]; decide) = some newBalRef)
    (hLocal6 : locals5[6]'(by rw [hSize]; decide) = some proofRef)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 3) :
    let (sigmaCs, sigmaFid) := initMs.containers.alloc (proofFields[0]'hFieldCount)
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 5,
          locals := locals5,
          localRefs := (List.replicate 7 none).toArray }
        []
        [curBalRef, ekRef, .address contract, .address sender, .u8 chainId]
        initMs fuel =
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 8,
          locals := locals5,
          localRefs := (List.replicate 7 none).toArray }
        []
        [.immRef sigmaFid, newBalRef, curBalRef, ekRef,
         .address contract, .address sender, .u8 chainId]
        { initMs with containers := sigmaCs }
        (fuel - 3) := by
  set f5 : Frame :=
      { code := verifyNormalizationProofCode, pc := 5,
        locals := locals5,
        localRefs := (List.replicate 7 none).toArray } with hf5_def
  -- PC 5: copyLoc 5 (newBalRef)
  have hf5_lt5 : 5 < f5.locals.size := by show 5 < locals5.size; rw [hSize]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := hLocal5
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step1 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue),
                   (.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  newBalRef hf5_lt5 hf5_v5 hf5_ref5
  -- f6 frame at PC 6: same locals, just pc bumped
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_lt6 : 6 < f6.locals.size := by show 6 < locals5.size; rw [hSize]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := hLocal6
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step2 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue),
                   (.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  proofRef hf6_lt6 hf6_v6 hf6_ref6
  -- f7 frame at PC 7: still same locals, pc bumped to 7
  set f7 := { f6 with pc := 7 } with hf7_def
  have step3 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue),
                   (.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  proofRid proofFields
                  (initMs.containers.alloc (proofFields[0]'hFieldCount)).1
                  (initMs.containers.alloc (proofFields[0]'hFieldCount)).2
                  proofRef hproofRef hread hFieldCount rfl
  -- Chain three steps via run_succ_ok_of_step
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 3 := ⟨fuel - 3, by omega⟩
  show run (normalizationModuleEnv o) f5 [] _ initMs fuel = _
  rw [hef]
  rw [show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step1,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step2,
      StepLemmas.run_succ_ok_of_step ef _ _ _ _ step3]
  rw [show (ef + 1 + 1 + 1 - 3) = ef from by omega]
  rfl
/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence. Currently deferred with architectural notes.

**Completion roadmap**:
1. Chain PCs 0-7 using helper axioms `norm_run_pc0_to_pc5` and `norm_run_pc5_to_pc8`
2. At PC 8, split on sigma oracle outcome (`some ([], cs')` vs `none`/wrong-arity)
3. On sigma success: chain PCs 9-11 using individual step theorems
4. At PC 12, split on range oracle outcome
5. On range success: execute PC 13 (ret), connect to `.returned` branch via shape lemma
6. On failures: connect to `.error` branch via failure shape lemmas

**Remaining work**:
- Prove locals state properties from helper axioms to feed into step theorems
- Thread container store evolution through native calls
- Handle oracle wrong-arity cases (non-empty return that's not `[]`)
- Eliminate helper axioms by proving explicit PC-chains for PCs 0-7

**Estimated**: 150-200 additional lines to complete main proof body.
-/

/-! ## Error- and success-path PC chain helpers (Phase-4 closure scaffolding) -/

/-- When sigma oracle returns none, normalization run produces error. -/
theorem norm_run_to_sigma_fail_produces_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 : ContainerStore) (sigmaFid : RefId)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 9)
    (hsigmaFail :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                ekRef, curBalRef, newBalRef,
                                .immRef sigmaFid] = none) :
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 7 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  -- f5 at PC 5 (copyLoc 5 newBalRef — locals unchanged after this OK step)
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 7 := by
    show (f4.locals.set 4 none hf4_lt4).size = 7; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf5_lt5 hf5_v5 hf5_ref5
  -- f6 at PC 6 (copyLoc unchanged locals)
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_size : f6.locals.size = 7 := hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := by
    show f5.locals[6]'_ = _
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf6_lt6 hf6_v6 hf6_ref6
  -- f7 at PC 7 (immBorrowField 0 — alloc sigmaFid, consume proofRef)
  set f7 := { f6 with pc := 7 } with hf7_def
  have step8 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  -- f8 at PC 8 (sigma call, none → error)
  set f8 := { f7 with pc := 8 } with hf8_def
  set ms8 : MachineState := { initMs with containers := cs1 } with hms8_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 7 =
        some ([.u8 chainId, .address sender, .address contract,
               ekRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step9 := step_normalization_pc8_none o f8 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms8 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] htake hsigmaFail
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 9 := ⟨fuel - 9, by omega⟩
  rw [hef]
  rw [show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step1,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step2,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step3,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step4,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step5,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step6,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step7,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step8,
      StepLemmas.run_succ_error_of_step ef step9]

/-- When sigma oracle returns a non-empty result list (arity mismatch), run produces error. -/
theorem norm_run_to_sigma_arity_mismatch_produces_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 : ContainerStore) (sigmaFid : RefId)
    (sigmaResultHead : MoveValue) (sigmaResultTail : List MoveValue)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 9)
    (hsigmaArityMismatch :
       o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some (sigmaResultHead :: sigmaResultTail, cs2)) :
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 7 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 7 := by
    show (f4.locals.set 4 none hf4_lt4).size = 7; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_size : f6.locals.size = 7 := hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := by
    show f5.locals[6]'_ = _
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have step8 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  set f8 := { f7 with pc := 8 } with hf8_def
  set ms8 : MachineState := { initMs with containers := cs1 } with hms8_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 7 =
        some ([.u8 chainId, .address sender, .address contract,
               ekRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step9 := step_normalization_pc8_multi o f8 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms8 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] sigmaResultHead sigmaResultTail cs2 htake hsigmaArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 9 := ⟨fuel - 9, by omega⟩
  rw [hef]
  rw [show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step1,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step2,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step3,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step4,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step5,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step6,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step7,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step8,
      StepLemmas.run_succ_error_of_step ef step9]

/-- When sigma succeeds but range oracle returns none, run produces error. -/
theorem norm_run_to_range_fail_produces_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 : ContainerStore) (sigmaFid zkrpFid : RefId)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1
         [.u8 chainId, .address sender, .address contract,
          ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeFail : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = none)
    (fuel : Nat)
    (hfuel : fuel ≥ 13) :
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 7 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 7 := by
    show (f4.locals.set 4 none hf4_lt4).size = 7; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_size : f6.locals.size = 7 := hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := by
    show f5.locals[6]'_ = _
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have step8 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f8 := { f7 with pc := 8 } with hf8_def
  set ms8 : MachineState := { initMs with containers := cs1 } with hms8_def
  have htake_pc8 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 7 =
        some ([.u8 chainId, .address sender, .address contract,
               ekRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step9 := step_normalization_pc8 o f8 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms8 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc8 hsigmaOk
  -- After step9: pc=9, stack=[], containers=cs2.
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { ms8 with containers := cs2, globals := ms8.globals } with hms9_def
  have hf9_lt5 : 5 < f9.locals.size := hf5_lt5
  have hf9_v5 : f9.locals[5]'hf9_lt5 = some newBalRef := hf5_v5
  have hf9_ref5 : ¬ 5 < f9.localRefs.size ∨
                  ∃ h : 5 < f9.localRefs.size, f9.localRefs[5]'h = none := hf5_ref5
  have step10 := step_normalization_pc9 o f9 [] [] ms9 rfl rfl newBalRef
                   hf9_lt5 hf9_v5 hf9_ref5
  -- After step10: pc=10, stack=[newBalRef], locals[5]:=none.
  set f10 := { f9 with pc := 10, locals := f9.locals.set 5 none hf9_lt5 } with hf10_def
  have hf10_size : f10.locals.size = 7 := by
    show (f9.locals.set 5 none hf9_lt5).size = 7; rw [Array.size_set]; exact hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some proofRef := by
    show (f9.locals.set 5 none hf9_lt5)[6]'hf10_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]; exact hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step11 := step_normalization_pc10 o f10 [] [newBalRef] ms9 rfl rfl proofRef
                   hf10_lt6 hf10_v6 hf10_ref6
  -- After step11: pc=11, stack=[proofRef, newBalRef], locals[6]:=none.
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hms9_read : ms9.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step12 := step_normalization_pc11 o f11 [] [newBalRef] ms9 rfl rfl proofRid proofFields
                   cs3 zkrpFid proofRef hproofRef hms9_read hFieldCount
                   (show ms9.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  -- After step12: pc=12, stack=[.immRef zkrpFid, newBalRef], containers=cs3.
  set f12 := { f11 with pc := 12 } with hf12_def
  set ms12 : MachineState := { ms9 with containers := cs3 } with hms12_def
  have htake_pc12 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step13 := step_normalization_pc12_none o f12 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms12 rfl rfl
                   [newBalRef, .immRef zkrpFid] [] htake_pc12 hrangeFail
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 13 := ⟨fuel - 13, by omega⟩
  rw [hef]
  rw [show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step1,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step2,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step3,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step4,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step5,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step6,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step7,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step8,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step9,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step10,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step11,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step12,
      StepLemmas.run_succ_error_of_step ef step13]

/-- When sigma succeeds but range oracle returns a non-empty result list, run produces error. -/
theorem norm_run_to_range_arity_mismatch_produces_error
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 : ContainerStore) (sigmaFid zkrpFid : RefId)
    (rangeResultHead : MoveValue) (rangeResultTail : List MoveValue)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1
         [.u8 chainId, .address sender, .address contract,
          ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeArityMismatch :
       o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] =
         some (rangeResultHead :: rangeResultTail, cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 13) :
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 7 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 7 := by
    show (f4.locals.set 4 none hf4_lt4).size = 7; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_size : f6.locals.size = 7 := hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := by
    show f5.locals[6]'_ = _
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have step8 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f8 := { f7 with pc := 8 } with hf8_def
  set ms8 : MachineState := { initMs with containers := cs1 } with hms8_def
  have htake_pc8 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 7 =
        some ([.u8 chainId, .address sender, .address contract,
               ekRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step9 := step_normalization_pc8 o f8 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms8 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc8 hsigmaOk
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { ms8 with containers := cs2, globals := ms8.globals } with hms9_def
  have hf9_lt5 : 5 < f9.locals.size := hf5_lt5
  have hf9_v5 : f9.locals[5]'hf9_lt5 = some newBalRef := hf5_v5
  have hf9_ref5 : ¬ 5 < f9.localRefs.size ∨
                  ∃ h : 5 < f9.localRefs.size, f9.localRefs[5]'h = none := hf5_ref5
  have step10 := step_normalization_pc9 o f9 [] [] ms9 rfl rfl newBalRef
                   hf9_lt5 hf9_v5 hf9_ref5
  set f10 := { f9 with pc := 10, locals := f9.locals.set 5 none hf9_lt5 } with hf10_def
  have hf10_size : f10.locals.size = 7 := by
    show (f9.locals.set 5 none hf9_lt5).size = 7; rw [Array.size_set]; exact hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some proofRef := by
    show (f9.locals.set 5 none hf9_lt5)[6]'hf10_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]; exact hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step11 := step_normalization_pc10 o f10 [] [newBalRef] ms9 rfl rfl proofRef
                   hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hms9_read : ms9.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step12 := step_normalization_pc11 o f11 [] [newBalRef] ms9 rfl rfl proofRid proofFields
                   cs3 zkrpFid proofRef hproofRef hms9_read hFieldCount
                   (show ms9.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  set f12 := { f11 with pc := 12 } with hf12_def
  set ms12 : MachineState := { ms9 with containers := cs3 } with hms12_def
  have htake_pc12 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step13 := step_normalization_pc12_multi o f12 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms12 rfl rfl
                   [newBalRef, .immRef zkrpFid] []
                   rangeResultHead rangeResultTail cs4 htake_pc12 hrangeArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 13 := ⟨fuel - 13, by omega⟩
  rw [hef]
  rw [show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step1,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step2,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step3,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step4,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step5,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step6,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step7,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step8,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step9,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step10,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step11,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step12,
      StepLemmas.run_succ_error_of_step ef step13]

/-- Happy path: sigma succeeds, range succeeds, ret. Run produces `.returned [] ms_final`. -/
theorem norm_run_to_success_produces_returned
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 cs3 cs4 : ContainerStore) (sigmaFid zkrpFid : RefId)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hread2 : cs2.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc0 : initMs.containers.alloc
                  (proofFields[0]'(by omega : 0 < proofFields.length)) = (cs1, sigmaFid))
    (hsigmaOk :
       o.verifySigmaProof cs1
         [.u8 chainId, .address sender, .address contract,
          ekRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeOk : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = some ([], cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    run (normalizationModuleEnv o)
        { code := verifyNormalizationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 7 none).toArray }
        [] [] initMs fuel =
    .returned [] { initMs with containers := cs4, globals := initMs.globals } := by
  set f0 : Frame :=
      { code := verifyNormalizationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    ekRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 7 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 7 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_normalization_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 7 := by
    show (f0.locals.set 0 none hf0_lt0).size = 7; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_normalization_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 7 := by
    show (f1.locals.set 1 none hf1_lt1).size = 7; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_normalization_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 7 := by
    show (f2.locals.set 2 none hf2_lt2).size = 7; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some ekRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_normalization_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl ekRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 7 := by
    show (f3.locals.set 3 none hf3_lt3).size = 7; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some curBalRef := by
    show (f3.locals.set 3 none hf3_lt3)[4]'hf4_lt4 = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 4)]
    show (f2.locals.set 2 none hf2_lt2)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 4)]
    show (f1.locals.set 1 none hf1_lt1)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 4)]
    show (f0.locals.set 0 none hf0_lt0)[4]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 4)]; simp [f0]
  have hf4_ref4 : ¬ 4 < f4.localRefs.size ∨
                  ∃ h : 4 < f4.localRefs.size, f4.localRefs[4]'h = none := by
    right; refine ⟨by simp [f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_normalization_pc4 o f4 []
                  [ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 7 := by
    show (f4.locals.set 4 none hf4_lt4).size = 7; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some newBalRef := by
    show (f4.locals.set 4 none hf4_lt4)[5]'hf5_lt5 = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 5)]
    show (f3.locals.set 3 none hf3_lt3)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 5)]
    show (f2.locals.set 2 none hf2_lt2)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 5)]
    show (f1.locals.set 1 none hf1_lt1)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 5)]
    show (f0.locals.set 0 none hf0_lt0)[5]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 5)]; simp [f0]
  have hf5_ref5 : ¬ 5 < f5.localRefs.size ∨
                  ∃ h : 5 < f5.localRefs.size, f5.localRefs[5]'h = none := by
    right; refine ⟨by simp [f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_normalization_pc5 o f5 []
                  [curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6 } with hf6_def
  have hf6_size : f6.locals.size = 7 := hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some proofRef := by
    show f5.locals[6]'_ = _
    show (f4.locals.set 4 none hf4_lt4)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 6)]
    show (f3.locals.set 3 none hf3_lt3)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 6)]
    show (f2.locals.set 2 none hf2_lt2)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 6)]
    show (f1.locals.set 1 none hf1_lt1)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 6)]
    show (f0.locals.set 0 none hf0_lt0)[6]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 6)]; simp [f0]
  have hf6_ref6 : ¬ 6 < f6.localRefs.size ∨
                  ∃ h : 6 < f6.localRefs.size, f6.localRefs[6]'h = none := by
    right; refine ⟨by simp [f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_normalization_pc6 o f6 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have step8 := step_normalization_pc7 o f7 []
                  [newBalRef, curBalRef, ekRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f8 := { f7 with pc := 8 } with hf8_def
  set ms8 : MachineState := { initMs with containers := cs1 } with hms8_def
  have htake_pc8 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 7 =
        some ([.u8 chainId, .address sender, .address contract,
               ekRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step9 := step_normalization_pc8 o f8 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, ekRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms8 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   ekRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake_pc8 hsigmaOk
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { ms8 with containers := cs2, globals := ms8.globals } with hms9_def
  have hf9_lt5 : 5 < f9.locals.size := hf5_lt5
  have hf9_v5 : f9.locals[5]'hf9_lt5 = some newBalRef := hf5_v5
  have hf9_ref5 : ¬ 5 < f9.localRefs.size ∨
                  ∃ h : 5 < f9.localRefs.size, f9.localRefs[5]'h = none := hf5_ref5
  have step10 := step_normalization_pc9 o f9 [] [] ms9 rfl rfl newBalRef
                   hf9_lt5 hf9_v5 hf9_ref5
  set f10 := { f9 with pc := 10, locals := f9.locals.set 5 none hf9_lt5 } with hf10_def
  have hf10_size : f10.locals.size = 7 := by
    show (f9.locals.set 5 none hf9_lt5).size = 7; rw [Array.size_set]; exact hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some proofRef := by
    show (f9.locals.set 5 none hf9_lt5)[6]'hf10_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]; exact hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := by
    right; refine ⟨by simp [f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 7 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step11 := step_normalization_pc10 o f10 [] [newBalRef] ms9 rfl rfl proofRef
                   hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hms9_read : ms9.containers.read proofRid = some (.struct_ proofFields) := by
    show cs2.read proofRid = _; exact hread2
  have step12 := step_normalization_pc11 o f11 [] [newBalRef] ms9 rfl rfl proofRid proofFields
                   cs3 zkrpFid proofRef hproofRef hms9_read hFieldCount
                   (show ms9.containers.alloc _ = (cs3, zkrpFid) from
                     show cs2.alloc _ = (cs3, zkrpFid) from halloc1)
  set f12 := { f11 with pc := 12 } with hf12_def
  set ms12 : MachineState := { ms9 with containers := cs3 } with hms12_def
  have htake_pc12 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step13 := step_normalization_pc12 o f12 []
                   [(.immRef zkrpFid : MoveValue), newBalRef]
                   ms12 rfl rfl
                   [newBalRef, .immRef zkrpFid] [] cs4 htake_pc12 hrangeOk
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms12 with containers := cs4, globals := ms12.globals } with hms13_def
  have step14 := step_normalization_pc13 o f13 [] ms13 rfl rfl
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 14 := ⟨fuel - 14, by omega⟩
  rw [hef]
  rw [show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step1,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step2,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step3,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step4,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step5,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step6,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step7,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step8,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step9,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step10,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step11,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step12,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step13,
      StepLemmas.run_succ_returned_of_step ef [] ms13 step14]

/-! ## Top-level equivalence theorem (Phase 4 closure) -/

/-- The normalization sigma oracle's frame condition. Same rationale as Rotation/Withdrawal. -/
abbrev NormalizationSigmaPreservesProofRead
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState) (hFieldCount : 0 < proofFields.length) : Prop :=
  ∀ cs2,
    o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'hFieldCount)).1
        [.u8 chainId, .address sender, .address contract,
         ekRef, curBalRef, newBalRef,
         .immRef (initMs.containers.alloc (proofFields[0]'hFieldCount)).2] =
        some ([], cs2) →
    cs2.read proofRid = some (.struct_ proofFields)

theorem normalization_eval_equiv_functional_sim
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (hSigmaPreserves :
       NormalizationSigmaPreservesProofRead o chainId sender contract
         ekRef curBalRef newBalRef proofRid proofFields initMs
         (by omega : 0 < proofFields.length))
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    let args := normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef
    (eval (normalizationModuleEnv o) verifyNormalizationProofIdx args fuel initMs).dropMs =
    match verifyNormalizationBytecodeResult o chainId sender contract ekRef curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned _ => .returned [] MachineState.empty
    | .error => .error := by
  show (eval (normalizationModuleEnv o) verifyNormalizationProofIdx
          (normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef)
          fuel initMs).dropMs = _
  rw [eval_normalization_eq_run]
  unfold normalizationArgs verifyNormalizationBytecodeResult
  rcases hSigmaPair : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length))
    with ⟨cs1, sigmaFid⟩
  match hsigma : o.verifySigmaProof cs1
                    [.u8 chainId, .address sender, .address contract,
                     ekRef, curBalRef, newBalRef, .immRef sigmaFid] with
  | none =>
    have hRun := norm_run_to_sigma_fail_produces_error o chainId sender contract
                  ekRef curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 sigmaFid (by omega : 0 < proofFields.length)
                  hread hproofRef hSigmaPair fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hsigma]
  | some (sHead :: sTail, cs2) =>
    have hRun := norm_run_to_sigma_arity_mismatch_produces_error o chainId sender contract
                  ekRef curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 cs2 sigmaFid sHead sTail
                  (by omega : 0 < proofFields.length) hread hproofRef hSigmaPair
                  fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, hsigma]
  | some ([], cs2) =>
    have hread2 : cs2.read proofRid = some (.struct_ proofFields) := by
      apply hSigmaPreserves cs2
      rw [hSigmaPair]; exact hsigma
    rcases hRangePair : cs2.alloc (proofFields[1]'hFieldCount) with ⟨cs3, zkrpFid⟩
    match hrange : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] with
    | none =>
      have hRun := norm_run_to_range_fail_produces_error o chainId sender contract
                    ekRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 sigmaFid zkrpFid hFieldCount hread hread2
                    hproofRef hSigmaPair hsigma hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hsigma, hRangePair, hrange]
    | some (rHead :: rTail, cs4) =>
      have hRun := norm_run_to_range_arity_mismatch_produces_error o chainId sender contract
                    ekRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid rHead rTail hFieldCount
                    hread hread2 hproofRef hSigmaPair hsigma hRangePair hrange
                    fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, hsigma, hRangePair, hrange]
    | some ([], cs4) =>
      have hRun := norm_run_to_success_produces_returned o chainId sender contract
                    ekRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid hFieldCount hread hread2
                    hproofRef hSigmaPair hsigma hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_returned, hsigma, hRangePair, hrange]

end MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
