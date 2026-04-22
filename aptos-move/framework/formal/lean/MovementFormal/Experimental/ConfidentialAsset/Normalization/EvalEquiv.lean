import MovementFormal.MoveModel.Programs.Normalization
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs

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

private theorem code_size : verifyNormalizationProofCode.size = 14 := by
  unfold verifyNormalizationProofCode; rfl

private theorem code_pc0 : verifyNormalizationProofCode[0]'(by decide) = .moveLoc 0 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc1 : verifyNormalizationProofCode[1]'(by decide) = .moveLoc 1 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc2 : verifyNormalizationProofCode[2]'(by decide) = .moveLoc 2 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc3 : verifyNormalizationProofCode[3]'(by decide) = .moveLoc 3 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc4 : verifyNormalizationProofCode[4]'(by decide) = .moveLoc 4 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc5 : verifyNormalizationProofCode[5]'(by decide) = .copyLoc 5 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc6 : verifyNormalizationProofCode[6]'(by decide) = .copyLoc 6 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc7 : verifyNormalizationProofCode[7]'(by decide) = .immBorrowField 0 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc8 : verifyNormalizationProofCode[8]'(by decide) = .call 0 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc9 : verifyNormalizationProofCode[9]'(by decide) = .moveLoc 5 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc10 : verifyNormalizationProofCode[10]'(by decide) = .moveLoc 6 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc11 : verifyNormalizationProofCode[11]'(by decide) = .immBorrowField 1 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc12 : verifyNormalizationProofCode[12]'(by decide) = .call 1 := by
  unfold verifyNormalizationProofCode; rfl
private theorem code_pc13 : verifyNormalizationProofCode[13]'(by decide) = .ret := by
  unfold verifyNormalizationProofCode; rfl

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

/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence. Structure:
1. Unfold eval to run via `eval_normalization_eq_run`
2. Chain PCs 0-7 (argument marshaling) using individual step theorems
3. At PC 8, split on sigma oracle outcome
4. On sigma success, chain PCs 9-11
5. At PC 12, split on range oracle outcome
6. On range success, execute PC 13 (ret)
7. Apply shape lemmas to connect to functional sim

The proof requires ~300 lines of frame manipulation and oracle case splitting.
Currently structured with sorry placeholders for incremental completion. -/

theorem normalization_eval_equiv_functional_sim
    (o : NormalizationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (ekRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    let args := normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef
    (eval (normalizationModuleEnv o) verifyNormalizationProofIdx args fuel initMs).dropMs =
    match verifyNormalizationBytecodeResult o chainId sender contract ekRef curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned ms => .returned [] ms
    | .error => .error := by
  -- Unfold eval to run
  show (eval (normalizationModuleEnv o) verifyNormalizationProofIdx
          (normalizationArgs chainId sender contract ekRef curBalRef newBalRef proofRef)
          fuel initMs).dropMs = _
  rw [eval_normalization_eq_run]

  -- TODO Phase 6: Chain all 14 PCs using run_succ_ok_of_step
  -- Pattern from Registration: apply step theorems sequentially, split on oracle outcomes
  -- at PC 8 (sigma) and PC 12 (range), apply shape lemmas to connect to functional sim
  sorry

end MovementFormal.Experimental.ConfidentialAsset.Normalization.EvalEquiv
