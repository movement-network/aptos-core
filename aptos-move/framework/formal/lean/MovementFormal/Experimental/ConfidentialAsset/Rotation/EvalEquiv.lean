import MovementFormal.MoveModel.Programs.Rotation
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Structs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.ExecResultDropMs
import MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
import MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition
import MovementFormal.Experimental.ConfidentialAsset.Rotation.ConcreteHelpers
import MovementFormal.Experimental.ConfidentialAsset.Rotation.BytecodeLemmas
import MovementFormal.Experimental.ConfidentialAsset.Helpers.FunctionalSimBridge
import Mathlib.Tactic.Common
import Mathlib.Tactic.Set

/-!
# Bytecode eval ≡ functional simulation for `verify_rotation_proof` — Phase 4

Proves that the `verify_rotation_proof` bytecode (15 instructions dispatching to
`verify_rotation_sigma_proof` + `verify_new_balance_range_proof`) evaluates to the
functional simulation result under the module oracle.

Same architecture as `Normalization/EvalEquiv.lean` — 15 PCs instead of 14,
8 params instead of 7. The extra param is `new_ek` at local 4.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Programs.Rotation

def rotationArgs (chainId : UInt8) (sender contract : ByteArray)
    (curEkRef newEkRef curBalRef newBalRef proofRef : MoveValue) : List MoveValue :=
  [.u8 chainId, .address sender, .address contract,
   curEkRef, newEkRef, curBalRef, newBalRef, proofRef]

/-! ## Module environment simp lemmas -/

@[simp] theorem rotationModuleEnv_functions_size (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions.size = 3 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].numParams = 8 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_numReturns (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].numReturns = 0 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn0_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[0].body = .nativeRef o.verifySigmaProof := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].numParams = 2 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_numReturns (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].numReturns = 0 := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn1_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[1].body = .nativeRef o.verifyRangeProof := by
  unfold rotationModuleEnv; rfl

@[simp] theorem rotationModuleEnv_fn2_numParams (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[2].numParams = 8 := by
  unfold rotationModuleEnv verifyRotationProofDesc; rfl

@[simp] theorem rotationModuleEnv_fn2_body (o : RotationModuleOracle) :
    (rotationModuleEnv o).functions[2].body = .bytecode verifyRotationProofCode 8 := by
  unfold rotationModuleEnv verifyRotationProofDesc; rfl

/-! ## Bytecode access lemmas (extracted to BytecodeLemmas.lean) -/

-- Aliases for backwards compatibility with existing proof code
private abbrev rot_code_pc0  := BytecodeLemmas.instr0_eq
private abbrev rot_code_pc1  := BytecodeLemmas.instr1_eq
private abbrev rot_code_pc2  := BytecodeLemmas.instr2_eq
private abbrev rot_code_pc3  := BytecodeLemmas.instr3_eq
private abbrev rot_code_pc4  := BytecodeLemmas.instr4_eq
private abbrev rot_code_pc5  := BytecodeLemmas.instr5_eq
private abbrev rot_code_pc6  := BytecodeLemmas.instr6_eq
private abbrev rot_code_pc7  := BytecodeLemmas.instr7_eq
private abbrev rot_code_pc8  := BytecodeLemmas.instr8_eq
private abbrev rot_code_pc9  := BytecodeLemmas.instr9_eq
private abbrev rot_code_pc10 := BytecodeLemmas.instr10_eq
private abbrev rot_code_pc11 := BytecodeLemmas.instr11_eq
private abbrev rot_code_pc12 := BytecodeLemmas.instr12_eq
private abbrev rot_code_pc13 := BytecodeLemmas.instr13_eq
private abbrev rot_code_pc14 := BytecodeLemmas.instr14_eq

/-! ## `eval` → `run` entry-point unfolding -/

theorem eval_rotation_eq_run (o : RotationModuleOracle)
    (args : List MoveValue) (fuel : Nat) (initMs : MachineState) :
    eval (rotationModuleEnv o) verifyRotationProofIdx args fuel initMs =
      run (rotationModuleEnv o)
        { code := verifyRotationProofCode,
          pc := 0,
          locals := (args.map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel := by
  unfold eval verifyRotationProofIdx
  simp only [rotationModuleEnv_functions_size, show (2 : Nat) < 3 from by decide, dif_pos,
             rotationModuleEnv_fn2_body, rotationModuleEnv_fn2_numParams]
  simp [List.replicate]

/-! ## Per-PC step theorems (moveLoc PCs 0–5) -/

private def moveLocStep (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (idx nextPc : Nat) (v : MoveValue)
    (_hcode : frame.code = verifyRotationProofCode)
    (hpc : frame.pc = idx)
    (hpc_lt : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc_lt = .moveLoc idx)
    (hlt : idx < frame.locals.size)
    (hv : frame.locals[idx]'hlt = some v)
    (hRefNone : ¬ idx < frame.localRefs.size ∨
        ∃ (h : idx < frame.localRefs.size), frame.localRefs[idx]'h = none)
    (hnext : idx + 1 = nextPc) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := nextPc, locals := frame.locals.set idx none (by omega) }
           cs (v :: stack) ms := by
  have h := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    idx v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = nextPc from by omega] at h; exact h

theorem step_rotation_pc0 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 0)
    (v : MoveValue) (hlt : 0 < frame.locals.size) (hv : frame.locals[0]'hlt = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨ ∃ h : 0 < frame.localRefs.size, frame.localRefs[0]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 1, locals := frame.locals.set 0 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; exact rot_code_pc0
  exact moveLocStep o frame cs stack ms 0 1 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc1 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 1)
    (v : MoveValue) (hlt : 1 < frame.locals.size) (hv : frame.locals[1]'hlt = some v)
    (hRefNone : ¬ 1 < frame.localRefs.size ∨ ∃ h : 1 < frame.localRefs.size, frame.localRefs[1]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 2, locals := frame.locals.set 1 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 1 := by simp only [hcode, hpc]; exact rot_code_pc1
  exact moveLocStep o frame cs stack ms 1 2 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc2 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 2)
    (v : MoveValue) (hlt : 2 < frame.locals.size) (hv : frame.locals[2]'hlt = some v)
    (hRefNone : ¬ 2 < frame.localRefs.size ∨ ∃ h : 2 < frame.localRefs.size, frame.localRefs[2]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 3, locals := frame.locals.set 2 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 2 := by simp only [hcode, hpc]; exact rot_code_pc2
  exact moveLocStep o frame cs stack ms 2 3 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc3 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 3)
    (v : MoveValue) (hlt : 3 < frame.locals.size) (hv : frame.locals[3]'hlt = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨ ∃ h : 3 < frame.localRefs.size, frame.localRefs[3]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 4, locals := frame.locals.set 3 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; exact rot_code_pc3
  exact moveLocStep o frame cs stack ms 3 4 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc4 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 4)
    (v : MoveValue) (hlt : 4 < frame.locals.size) (hv : frame.locals[4]'hlt = some v)
    (hRefNone : ¬ 4 < frame.localRefs.size ∨ ∃ h : 4 < frame.localRefs.size, frame.localRefs[4]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 5, locals := frame.locals.set 4 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 4 := by simp only [hcode, hpc]; exact rot_code_pc4
  exact moveLocStep o frame cs stack ms 4 5 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

theorem step_rotation_pc5 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 5)
    (v : MoveValue) (hlt : 5 < frame.locals.size) (hv : frame.locals[5]'hlt = some v)
    (hRefNone : ¬ 5 < frame.localRefs.size ∨ ∃ h : 5 < frame.localRefs.size, frame.localRefs[5]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 6, locals := frame.locals.set 5 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 5 := by simp only [hcode, hpc]; exact rot_code_pc5
  exact moveLocStep o frame cs stack ms 5 6 v hcode hpc hpc_lt hc hlt hv hRefNone rfl

/-! ## copyLoc PCs 6–7 -/

theorem step_rotation_pc6 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 6)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms = .ok { frame with pc := 7 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 6 := by simp only [hcode, hpc]; exact rot_code_pc6
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 7 from by omega] at h; exact h

theorem step_rotation_pc7 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 7)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms = .ok { frame with pc := 8 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 7 := by simp only [hcode, hpc]; exact rot_code_pc7
  have h := StepLemmas.step_copyLoc_noRef
    (frame := frame) (env := rotationModuleEnv o) (cs := cs) (stack := stack) (ms := ms)
    7 v hpc_lt hc hlt hv hRefNone
  rw [show frame.pc + 1 = 8 from by omega] at h; exact h

/-! ## PC 8 — immBorrowField 0 (proof.sigma_proof) -/

theorem step_rotation_pc8 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 8)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 0 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[0]'hlt) = (containers', fid)) :
    step (rotationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 9 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 0 := by simp only [hcode, hpc]; exact rot_code_pc8
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 9 from by omega]

/-! ## PC 9 — call 0 (verifySigmaProof, 8 args) -/

theorem step_rotation_pc9 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some ([], containers')) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 10 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact rot_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn0_numParams, htake, rotationModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  simp only [rotationModuleEnv_fn0_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 10 from by omega]

theorem step_rotation_pc9_multi (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = some (v :: vs, containers')) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact rot_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn0_numParams, htake, rotationModuleEnv_fn0_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [rotationModuleEnv_fn0_numReturns]
  | cons w ws => simp [rotationModuleEnv_fn0_numReturns]

theorem step_rotation_pc9_none (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 9)
    (args rest : List MoveValue)
    (htake : takeN stack 8 = some (args, rest))
    (himpl : o.verifySigmaProof ms.containers args = none) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; exact rot_code_pc9
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 0 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn0_numParams, htake, rotationModuleEnv_fn0_body, himpl]

/-! ## moveLoc PCs 10–11 (after sigma call) -/

theorem step_rotation_pc10 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 10)
    (v : MoveValue) (hlt : 6 < frame.locals.size) (hv : frame.locals[6]'hlt = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨ ∃ h : 6 < frame.localRefs.size, frame.localRefs[6]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 11, locals := frame.locals.set 6 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by simp only [hcode, hpc]; exact rot_code_pc10
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 11 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 11 from by omega]

theorem step_rotation_pc11 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 11)
    (v : MoveValue) (hlt : 7 < frame.locals.size) (hv : frame.locals[7]'hlt = some v)
    (hRefNone : ¬ 7 < frame.localRefs.size ∨ ∃ h : 7 < frame.localRefs.size, frame.localRefs[7]'h = none) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 12, locals := frame.locals.set 7 none (by omega) } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 7 := by simp only [hcode, hpc]; exact rot_code_pc11
  simp only [step, dif_pos hpc_lt, hc, dif_pos hlt, hv]
  rcases hRefNone with hSz | ⟨hSz, hNone⟩
  · simp only [dif_neg hSz]; rw [show frame.pc + 1 = 12 from by omega]
  · simp only [dif_pos hSz, hNone]; rw [show frame.pc + 1 = 12 from by omega]

/-! ## PC 12 — immBorrowField 1 (proof.zkrp_new_balance) -/

theorem step_rotation_pc12 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (rest : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 12)
    (rid : RefId) (proofFields : List MoveValue) (containers' : ContainerStore) (fid : RefId)
    (ref : MoveValue)
    (hRef : getRefId ref = some rid)
    (hread : ms.containers.read rid = some (.struct_ proofFields))
    (hlt : 1 < proofFields.length)
    (halloc : ms.containers.alloc (proofFields[1]'hlt) = (containers', fid)) :
    step (rotationModuleEnv o) frame cs (ref :: rest) ms =
      .ok { frame with pc := 13 } cs (.immRef fid :: rest) { ms with containers := containers' } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowField 1 := by simp only [hcode, hpc]; exact rot_code_pc12
  simp only [step, dif_pos hpc_lt, hc, hRef, hread, dif_pos hlt, halloc]
  rw [show frame.pc + 1 = 13 from by omega]

/-! ## PC 13 — call 1 (verifyRangeProof, 2 args) -/

theorem step_rotation_pc13 (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some ([], containers')) :
    step (rotationModuleEnv o) frame cs stack ms =
      .ok { frame with pc := 14 } cs rest { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact rot_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn1_numParams, htake, rotationModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  simp only [rotationModuleEnv_fn1_numReturns, beq_self_eq_true, ↓reduceIte]
  rw [show frame.pc + 1 = 14 from by omega]

theorem step_rotation_pc13_multi (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue) (v : MoveValue) (vs : List MoveValue)
    (containers' : ContainerStore)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = some (v :: vs, containers')) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact rot_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn1_numParams, htake, rotationModuleEnv_fn1_body, himpl]
  unfold handleNativeResult
  cases vs with
  | nil => simp [rotationModuleEnv_fn1_numReturns]
  | cons w ws => simp [rotationModuleEnv_fn1_numReturns]

theorem step_rotation_pc13_none (o : RotationModuleOracle)
    (frame : Frame) (cs : List Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 13)
    (args rest : List MoveValue)
    (htake : takeN stack 2 = some (args, rest))
    (himpl : o.verifyRangeProof ms.containers args = none) :
    step (rotationModuleEnv o) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; exact rot_code_pc13
  simp only [step, dif_pos hpc_lt, hc, dif_pos (show 1 < (rotationModuleEnv o).functions.size by simp)]
  simp only [rotationModuleEnv_fn1_numParams, htake, rotationModuleEnv_fn1_body, himpl]

/-! ## PC 14 — ret -/

theorem step_rotation_pc14 (o : RotationModuleOracle)
    (frame : Frame) (stack : List MoveValue) (ms : MachineState)
    (hcode : frame.code = verifyRotationProofCode) (hpc : frame.pc = 14) :
    step (rotationModuleEnv o) frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by rw [hpc, hcode]; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by simp only [hcode, hpc]; exact rot_code_pc14
  exact StepLemmas.step_ret_top hpc_lt hc

/-! ## Functional simulation — Phase 6

The functional simulation captures the high-level behavior of `verify_rotation_proof`:
wires chain_id, sender, contract, current_ek, new_ek, current_balance, new_balance,
and the proof's sigma_proof field (via ImmBorrowField) to the sigma verifier (proving
dual knowledge of the secret key under both current_ek and new_ek), then new_balance
and the proof's zkrp_new_balance field to the range verifier.

The result is `.returned [] ms_final` on success (both sub-calls return `some`) or
`.error` if either sub-call fails. -/

inductive RotationBytecodeResult where
  | returned (ms : MachineState)
  | error

def verifyRotationBytecodeResult
    (o : RotationModuleOracle) (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef : MoveValue)
    (_proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length) : RotationBytecodeResult :=
  let (cs1, sigmaFid) := initMs.containers.alloc (proofFields[0]'(by omega))
  let sigmaArgs := [.u8 chainId, .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
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
theorem verifyRotationBytecodeResult_sigmaFails
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hsigmaFail : ∀ cs args, o.verifySigmaProof cs args = none) :
    verifyRotationBytecodeResult o chainId sender contract
        currentEkRef newEkRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyRotationBytecodeResult
  simp [hsigmaFail]

/-- Functional simulation shape lemma: range failure → .error -/
theorem verifyRotationBytecodeResult_rangeFails
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs : ContainerStore)
    (hsigmaOk : o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'(by omega))).1
                    [.u8 chainId, .address sender, .address contract,
                     currentEkRef, newEkRef, curBalRef, newBalRef,
                     .immRef (initMs.containers.alloc (proofFields[0]'(by omega))).2] =
                 some ([], sigmaCs))
    (hrangeFail : ∀ cs args, o.verifyRangeProof cs args = none) :
    verifyRotationBytecodeResult o chainId sender contract
        currentEkRef newEkRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .error := by
  unfold verifyRotationBytecodeResult
  simp only [hsigmaOk, hrangeFail]

/-- Functional simulation shape lemma: happy path → .returned -/
theorem verifyRotationBytecodeResult_success
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (sigmaCs rangeCs : ContainerStore)
    (sigmaFid : RefId)
    (halloc0 : initMs.containers.alloc (proofFields[0]'(by omega)) = (sigmaCs, sigmaFid))
    (hsigmaOk : o.verifySigmaProof sigmaCs
                    [.u8 chainId, .address sender, .address contract,
                     currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] =
                 some ([], rangeCs))
    (hrange : o.verifyRangeProof (rangeCs.alloc (proofFields[1]'hFieldCount)).1
                  [newBalRef, .immRef (rangeCs.alloc (proofFields[1]'hFieldCount)).2] =
               some ([], (rangeCs.alloc (proofFields[1]'hFieldCount)).1)) :
    verifyRotationBytecodeResult o chainId sender contract
        currentEkRef newEkRef curBalRef newBalRef proofRid proofFields initMs hFieldCount =
    .returned { initMs with containers := (rangeCs.alloc (proofFields[1]'hFieldCount)).1 } := by
  unfold verifyRotationBytecodeResult
  simp only [halloc0, hsigmaOk, hrange]

/-! ## Top-level composition theorem (Phase 6)

The full eval↔functional-sim equivalence. Structure:
1. Unfold eval to run via `eval_rotation_eq_run`
2. Chain PCs 0-9 (argument marshaling) using individual step theorems
3. At PC 10, split on sigma oracle outcome
4. On sigma success, chain PCs 11-12
5. At PC 13, split on range oracle outcome
6. On range success, execute PC 14 (ret)
7. Apply shape lemmas to connect to functional sim

The proof requires ~300 lines of frame manipulation and oracle case splitting.
Currently structured with sorry placeholders for incremental completion. -/

/-! ## Error-path PC chain helpers (analogous to Withdrawal/EvalEquiv.lean) -/

/-- When sigma oracle returns none on the rotation proof, run produces error.

Chains PCs 0-9 — 6 moveLoc (PCs 0-5), 2 copyLoc (PCs 6-7), immBorrowField (PC 8),
sigma call returning none (PC 9) — into a single `.error` result. -/
theorem rot_run_to_sigma_fail_produces_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 : ContainerStore) (sigmaFid : RefId)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 10)
    (hsigmaFail : o.verifySigmaProof cs1 [.u8 chainId, .address sender, .address contract,
                                          currentEkRef, newEkRef, curBalRef, newBalRef,
                                          .immRef sigmaFid] = none) :
    run (rotationModuleEnv o)
        { code := verifyRotationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  -- Initial frame f0 with 8 args.
  set f0 : Frame :=
      { code := verifyRotationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  -- PC 0: moveLoc 0 (chainId)
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_rotation_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  -- f1 at PC 1 (sender)
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_rotation_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  -- f2 at PC 2 (contract)
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_rotation_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  -- f3 at PC 3 (currentEkRef)
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some currentEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_rotation_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl currentEkRef hf3_lt3 hf3_v3 hf3_ref3
  -- f4 at PC 4 (newEkRef)
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some newEkRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_rotation_pc4 o f4 []
                  [currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newEkRef hf4_lt4 hf4_v4 hf4_ref4
  -- f5 at PC 5 (curBalRef)
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_rotation_pc5 o f5 []
                  [newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  -- f6 at PC 6 (copyLoc 6 → newBalRef, doesn't clear locals[6])
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_rotation_pc6 o f6 []
                  [curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  -- f7 at PC 7 (copyLoc 7 → proofRef, locals unchanged)
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_rotation_pc7 o f7 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  -- f8 at PC 8 (immBorrowField 0 — alloc sigma_proof, push .immRef sigmaFid, pop proofRef)
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_rotation_pc8 o f8 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  -- f9 at PC 9 (sigma call, none)
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract,
               currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_rotation_pc9_none o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] htake hsigmaFail
  -- Compose: 9 OK steps + 1 error step.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 10 := ⟨fuel - 10, by omega⟩
  rw [hef]
  rw [show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step1,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step2,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step3,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step4,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step5,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step6,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step7,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step8,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step9,
      StepLemmas.run_succ_error_of_step ef step10]

/-- When sigma oracle returns a non-empty result list (arity mismatch),
    run produces error.

Same first 9 OK steps as `rot_run_to_sigma_fail_produces_error`; final step uses
`step_rotation_pc9_multi` (numReturns=0 vs result length ≥ 1 in handleNativeResult). -/
theorem rot_run_to_sigma_arity_mismatch_produces_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (cs1 cs2 : ContainerStore) (sigmaFid : RefId)
    (sigmaResultHead : MoveValue) (sigmaResultTail : List MoveValue)
    (hFieldCount : 0 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (halloc : initMs.containers.alloc (proofFields[0]'hFieldCount) = (cs1, sigmaFid))
    (fuel : Nat)
    (hfuel : fuel ≥ 10)
    (hsigmaArityMismatch :
       o.verifySigmaProof cs1
         [.u8 chainId, .address sender, .address contract,
          currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some (sigmaResultHead :: sigmaResultTail, cs2)) :
    run (rotationModuleEnv o)
        { code := verifyRotationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyRotationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_rotation_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_rotation_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_rotation_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some currentEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_rotation_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl currentEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some newEkRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_rotation_pc4 o f4 []
                  [currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_rotation_pc5 o f5 []
                  [newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_rotation_pc6 o f6 []
                  [curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_rotation_pc7 o f7 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_rotation_pc8 o f8 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread hFieldCount halloc
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract,
               currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_rotation_pc9_multi o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] sigmaResultHead sigmaResultTail cs2 htake hsigmaArityMismatch
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 10 := ⟨fuel - 10, by omega⟩
  rw [hef]
  rw [show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step1,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step2,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step3,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step4,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step5,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step6,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step7,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step8,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step9,
      StepLemmas.run_succ_error_of_step ef step10]

/-- When sigma succeeds but range oracle returns none, run produces error.

Chains PCs 0-13: 6 moveLoc + 2 copyLoc + immBorrowField (sigma alloc) +
sigma-call-OK + 2 moveLoc + immBorrowField (range alloc) + range-call-none → `.error`. -/
theorem rot_run_to_range_fail_produces_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
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
          currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeFail : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = none)
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    run (rotationModuleEnv o)
        { code := verifyRotationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyRotationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  -- PC 0: moveLoc 0 (chainId)
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_rotation_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_rotation_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_rotation_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some currentEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_rotation_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl currentEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some newEkRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_rotation_pc4 o f4 []
                  [currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_rotation_pc5 o f5 []
                  [newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_rotation_pc6 o f6 []
                  [curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_rotation_pc7 o f7 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_rotation_pc8 o f8 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  -- After step9: pc=9, stack=[.immRef sigmaFid, newBalRef, curBalRef, newEkRef, currentEkRef, contract, sender, chainId], containers=cs1
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract,
               currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_rotation_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake9 hsigmaOk
  -- After step10: pc=10, stack=[], containers=cs2
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  -- PC 10: moveLoc 6 → push newBalRef. Locals[6] still has newBalRef (untouched by copyLoc/immBorrowField).
  have hf10_size : f10.locals.size = 8 := hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_rotation_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                  hf10_lt6 hf10_v6 hf10_ref6
  -- After step11: pc=11, stack=[newBalRef], locals[6] := none
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf10_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]; exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_rotation_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                  hf11_lt7 hf11_v7 hf11_ref7
  -- After step12: pc=12, stack=[proofRef, newBalRef], locals[7] := none
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  -- PC 12: immBorrowField 1, consumes proofRef, allocates proofFields[1] in cs2 → cs3, pushes .immRef zkrpFid
  have step13 := step_rotation_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields
                  cs3 zkrpFid proofRef hproofRef
                  (by show ms10.containers.read proofRid = _; exact hread2)
                  hFieldCount halloc1
  -- After step13: pc=13, stack=[.immRef zkrpFid, newBalRef], containers=cs3
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  -- PC 13: range call (numParams=2), takeN 2 → ([newBalRef, .immRef zkrpFid], []), returns none → error
  have htake13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_rotation_pc13_none o f13 [] [(.immRef zkrpFid : MoveValue), newBalRef]
                  ms13 rfl rfl
                  [newBalRef, .immRef zkrpFid] [] htake13 hrangeFail
  -- Compose: 13 OK steps + 1 error step.
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
      StepLemmas.run_succ_error_of_step ef step14]

/-- When sigma succeeds but range oracle returns a non-empty result list (arity mismatch),
    run produces error.

Same first 13 OK steps as `rot_run_to_range_fail_produces_error`; final step uses
`step_rotation_pc13_multi`. -/
theorem rot_run_to_range_arity_mismatch_produces_error
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
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
          currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeArityMismatch :
       o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] =
         some (rangeResultHead :: rangeResultTail, cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 14) :
    run (rotationModuleEnv o)
        { code := verifyRotationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel = .error := by
  set f0 : Frame :=
      { code := verifyRotationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_rotation_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_rotation_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_rotation_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some currentEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_rotation_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl currentEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some newEkRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_rotation_pc4 o f4 []
                  [currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_rotation_pc5 o f5 []
                  [newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_rotation_pc6 o f6 []
                  [curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_rotation_pc7 o f7 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_rotation_pc8 o f8 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract,
               currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_rotation_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake9 hsigmaOk
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  have hf10_size : f10.locals.size = 8 := hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_rotation_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                  hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf10_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]; exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_rotation_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                  hf11_lt7 hf11_v7 hf11_ref7
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  have step13 := step_rotation_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields
                  cs3 zkrpFid proofRef hproofRef
                  (by show ms10.containers.read proofRid = _; exact hread2)
                  hFieldCount halloc1
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  have htake13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_rotation_pc13_multi o f13 [] [(.immRef zkrpFid : MoveValue), newBalRef]
                  ms13 rfl rfl
                  [newBalRef, .immRef zkrpFid] []
                  rangeResultHead rangeResultTail cs4 htake13 hrangeArityMismatch
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
      StepLemmas.run_succ_error_of_step ef step14]

/-- Happy path: sigma succeeds, range succeeds, ret. Run produces `.returned [] ms_final`.

Chains PCs 0-14: 6 moveLoc + 2 copyLoc + immBorrowField (sigma alloc) +
sigma-call-OK + 2 moveLoc + immBorrowField (range alloc) + range-call-OK + ret. -/
theorem rot_run_to_success_produces_returned
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
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
          currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] =
         some ([], cs2))
    (halloc1 : cs2.alloc (proofFields[1]'hFieldCount) = (cs3, zkrpFid))
    (hrangeOk : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] = some ([], cs4))
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    run (rotationModuleEnv o)
        { code := verifyRotationProofCode, pc := 0,
          locals := ([.u8 chainId, .address sender, .address contract,
                      currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
          localRefs := (List.replicate 8 none).toArray }
        [] [] initMs fuel =
    .returned [] { initMs with containers := cs4, globals := initMs.globals } := by
  set f0 : Frame :=
      { code := verifyRotationProofCode, pc := 0,
        locals := ([(.u8 chainId : MoveValue), .address sender, .address contract,
                    currentEkRef, newEkRef, curBalRef, newBalRef, proofRef].map some).toArray,
        localRefs := (List.replicate 8 none).toArray }
    with hf0_def
  have hf0_size : f0.locals.size = 8 := by simp [f0]
  have hf0_lt0 : 0 < f0.locals.size := by rw [hf0_size]; decide
  have hf0_v0 : f0.locals[0]'hf0_lt0 = some (.u8 chainId) := by simp [f0]
  have hf0_ref0 : ¬ 0 < f0.localRefs.size ∨
                  ∃ h : 0 < f0.localRefs.size, f0.localRefs[0]'h = none := by
    right; refine ⟨by simp [f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[0]'(by simp) = none; decide
  have step1 := step_rotation_pc0 o f0 [] [] initMs rfl rfl (.u8 chainId)
                  hf0_lt0 hf0_v0 hf0_ref0
  set f1 := { f0 with pc := 1, locals := f0.locals.set 0 none hf0_lt0 } with hf1_def
  have hf1_size : f1.locals.size = 8 := by
    show (f0.locals.set 0 none hf0_lt0).size = 8; rw [Array.size_set]; exact hf0_size
  have hf1_lt1 : 1 < f1.locals.size := by rw [hf1_size]; decide
  have hf1_v1 : f1.locals[1]'hf1_lt1 = some (.address sender) := by
    show (f0.locals.set 0 none hf0_lt0)[1]'hf1_lt1 = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 1)]; simp [f0]
  have hf1_ref1 : ¬ 1 < f1.localRefs.size ∨
                  ∃ h : 1 < f1.localRefs.size, f1.localRefs[1]'h = none := by
    right; refine ⟨by simp [f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[1]'(by simp) = none; decide
  have step2 := step_rotation_pc1 o f1 [] [(.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address sender) hf1_lt1 hf1_v1 hf1_ref1
  set f2 := { f1 with pc := 2, locals := f1.locals.set 1 none hf1_lt1 } with hf2_def
  have hf2_size : f2.locals.size = 8 := by
    show (f1.locals.set 1 none hf1_lt1).size = 8; rw [Array.size_set]; exact hf1_size
  have hf2_lt2 : 2 < f2.locals.size := by rw [hf2_size]; decide
  have hf2_v2 : f2.locals[2]'hf2_lt2 = some (.address contract) := by
    show (f1.locals.set 1 none hf1_lt1)[2]'hf2_lt2 = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 2)]
    show (f0.locals.set 0 none hf0_lt0)[2]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 2)]; simp [f0]
  have hf2_ref2 : ¬ 2 < f2.localRefs.size ∨
                  ∃ h : 2 < f2.localRefs.size, f2.localRefs[2]'h = none := by
    right; refine ⟨by simp [f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[2]'(by simp) = none; decide
  have step3 := step_rotation_pc2 o f2 []
                  [(.address sender : MoveValue), (.u8 chainId : MoveValue)] initMs rfl rfl
                  (.address contract) hf2_lt2 hf2_v2 hf2_ref2
  set f3 := { f2 with pc := 3, locals := f2.locals.set 2 none hf2_lt2 } with hf3_def
  have hf3_size : f3.locals.size = 8 := by
    show (f2.locals.set 2 none hf2_lt2).size = 8; rw [Array.size_set]; exact hf2_size
  have hf3_lt3 : 3 < f3.locals.size := by rw [hf3_size]; decide
  have hf3_v3 : f3.locals[3]'hf3_lt3 = some currentEkRef := by
    show (f2.locals.set 2 none hf2_lt2)[3]'hf3_lt3 = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 3)]
    show (f1.locals.set 1 none hf1_lt1)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 3)]
    show (f0.locals.set 0 none hf0_lt0)[3]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 3)]; simp [f0]
  have hf3_ref3 : ¬ 3 < f3.localRefs.size ∨
                  ∃ h : 3 < f3.localRefs.size, f3.localRefs[3]'h = none := by
    right; refine ⟨by simp [f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[3]'(by simp) = none; decide
  have step4 := step_rotation_pc3 o f3 []
                  [(.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl currentEkRef hf3_lt3 hf3_v3 hf3_ref3
  set f4 := { f3 with pc := 4, locals := f3.locals.set 3 none hf3_lt3 } with hf4_def
  have hf4_size : f4.locals.size = 8 := by
    show (f3.locals.set 3 none hf3_lt3).size = 8; rw [Array.size_set]; exact hf3_size
  have hf4_lt4 : 4 < f4.locals.size := by rw [hf4_size]; decide
  have hf4_v4 : f4.locals[4]'hf4_lt4 = some newEkRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[4]'(by simp) = none; decide
  have step5 := step_rotation_pc4 o f4 []
                  [currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newEkRef hf4_lt4 hf4_v4 hf4_ref4
  set f5 := { f4 with pc := 5, locals := f4.locals.set 4 none hf4_lt4 } with hf5_def
  have hf5_size : f5.locals.size = 8 := by
    show (f4.locals.set 4 none hf4_lt4).size = 8; rw [Array.size_set]; exact hf4_size
  have hf5_lt5 : 5 < f5.locals.size := by rw [hf5_size]; decide
  have hf5_v5 : f5.locals[5]'hf5_lt5 = some curBalRef := by
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[5]'(by simp) = none; decide
  have step6 := step_rotation_pc5 o f5 []
                  [newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl curBalRef hf5_lt5 hf5_v5 hf5_ref5
  set f6 := { f5 with pc := 6, locals := f5.locals.set 5 none hf5_lt5 } with hf6_def
  have hf6_size : f6.locals.size = 8 := by
    show (f5.locals.set 5 none hf5_lt5).size = 8; rw [Array.size_set]; exact hf5_size
  have hf6_lt6 : 6 < f6.locals.size := by rw [hf6_size]; decide
  have hf6_v6 : f6.locals[6]'hf6_lt6 = some newBalRef := by
    show (f5.locals.set 5 none hf5_lt5)[6]'hf6_lt6 = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 6)]
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
    show ((List.replicate 8 (none : Option RefId)).toArray)[6]'(by simp) = none; decide
  have step7 := step_rotation_pc6 o f6 []
                  [curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl newBalRef hf6_lt6 hf6_v6 hf6_ref6
  set f7 := { f6 with pc := 7 } with hf7_def
  have hf7_size : f7.locals.size = 8 := hf6_size
  have hf7_lt7 : 7 < f7.locals.size := by rw [hf7_size]; decide
  have hf7_v7 : f7.locals[7]'hf7_lt7 = some proofRef := by
    show f6.locals[7]'_ = _
    show (f5.locals.set 5 none hf5_lt5)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (5 : Nat) ≠ 7)]
    show (f4.locals.set 4 none hf4_lt4)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (4 : Nat) ≠ 7)]
    show (f3.locals.set 3 none hf3_lt3)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (3 : Nat) ≠ 7)]
    show (f2.locals.set 2 none hf2_lt2)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (2 : Nat) ≠ 7)]
    show (f1.locals.set 1 none hf1_lt1)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (1 : Nat) ≠ 7)]
    show (f0.locals.set 0 none hf0_lt0)[7]'_ = _
    rw [Array.getElem_set, if_neg (by decide : (0 : Nat) ≠ 7)]; simp [f0]
  have hf7_ref7 : ¬ 7 < f7.localRefs.size ∨
                  ∃ h : 7 < f7.localRefs.size, f7.localRefs[7]'h = none := by
    right; refine ⟨by simp [f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step8 := step_rotation_pc7 o f7 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRef hf7_lt7 hf7_v7 hf7_ref7
  set f8 := { f7 with pc := 8 } with hf8_def
  have step9 := step_rotation_pc8 o f8 []
                  [newBalRef, curBalRef, newEkRef, currentEkRef, (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  initMs rfl rfl proofRid proofFields cs1 sigmaFid proofRef
                  hproofRef hread (by omega : 0 < proofFields.length) halloc0
  set f9 := { f8 with pc := 9 } with hf9_def
  set ms9 : MachineState := { initMs with containers := cs1 } with hms9_def
  have htake9 :
      takeN [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
              (.address contract : MoveValue), (.address sender : MoveValue),
              (.u8 chainId : MoveValue)] 8 =
        some ([.u8 chainId, .address sender, .address contract,
               currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid], []) := rfl
  have step10 := step_rotation_pc9 o f9 []
                  [(.immRef sigmaFid : MoveValue), newBalRef, curBalRef, newEkRef, currentEkRef,
                    (.address contract : MoveValue), (.address sender : MoveValue), (.u8 chainId : MoveValue)]
                  ms9 rfl rfl
                  [.u8 chainId, .address sender, .address contract,
                   currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid]
                  [] cs2 htake9 hsigmaOk
  set f10 := { f9 with pc := 10 } with hf10_def
  set ms10 : MachineState := { ms9 with containers := cs2, globals := ms9.globals } with hms10_def
  have hf10_size : f10.locals.size = 8 := hf6_size
  have hf10_lt6 : 6 < f10.locals.size := by rw [hf10_size]; decide
  have hf10_v6 : f10.locals[6]'hf10_lt6 = some newBalRef := hf6_v6
  have hf10_ref6 : ¬ 6 < f10.localRefs.size ∨
                   ∃ h : 6 < f10.localRefs.size, f10.localRefs[6]'h = none := hf6_ref6
  have step11 := step_rotation_pc10 o f10 [] [] ms10 rfl rfl newBalRef
                  hf10_lt6 hf10_v6 hf10_ref6
  set f11 := { f10 with pc := 11, locals := f10.locals.set 6 none hf10_lt6 } with hf11_def
  have hf11_size : f11.locals.size = 8 := by
    show (f10.locals.set 6 none hf10_lt6).size = 8; rw [Array.size_set]; exact hf10_size
  have hf11_lt7 : 7 < f11.locals.size := by rw [hf11_size]; decide
  have hf11_v7 : f11.locals[7]'hf11_lt7 = some proofRef := by
    show (f10.locals.set 6 none hf10_lt6)[7]'hf11_lt7 = _
    rw [Array.getElem_set, if_neg (by decide : (6 : Nat) ≠ 7)]; exact hf7_v7
  have hf11_ref7 : ¬ 7 < f11.localRefs.size ∨
                   ∃ h : 7 < f11.localRefs.size, f11.localRefs[7]'h = none := by
    right; refine ⟨by simp [f11, f10, f9, f8, f7, f6, f5, f4, f3, f2, f1, f0], ?_⟩
    show ((List.replicate 8 (none : Option RefId)).toArray)[7]'(by simp) = none; decide
  have step12 := step_rotation_pc11 o f11 [] [newBalRef] ms10 rfl rfl proofRef
                  hf11_lt7 hf11_v7 hf11_ref7
  set f12 := { f11 with pc := 12, locals := f11.locals.set 7 none hf11_lt7 } with hf12_def
  have step13 := step_rotation_pc12 o f12 [] [newBalRef] ms10 rfl rfl proofRid proofFields
                  cs3 zkrpFid proofRef hproofRef
                  (by show ms10.containers.read proofRid = _; exact hread2)
                  hFieldCount halloc1
  set f13 := { f12 with pc := 13 } with hf13_def
  set ms13 : MachineState := { ms10 with containers := cs3 } with hms13_def
  have htake13 :
      takeN [(.immRef zkrpFid : MoveValue), newBalRef] 2 =
        some ([newBalRef, .immRef zkrpFid], []) := rfl
  have step14 := step_rotation_pc13 o f13 [] [(.immRef zkrpFid : MoveValue), newBalRef]
                  ms13 rfl rfl
                  [newBalRef, .immRef zkrpFid] [] cs4 htake13 hrangeOk
  set f14 := { f13 with pc := 14 } with hf14_def
  set ms14 : MachineState := { ms13 with containers := cs4, globals := ms13.globals } with hms14_def
  have step15 := step_rotation_pc14 o f14 [] ms14 rfl rfl
  -- Compose: 14 OK steps + 1 returned step.
  obtain ⟨ef, hef⟩ : ∃ ef, fuel = ef + 15 := ⟨fuel - 15, by omega⟩
  rw [hef]
  rw [show ef + 15 = (ef + 14) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 14) _ _ _ _ step1,
      show ef + 14 = (ef + 13) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 13) _ _ _ _ step2,
      show ef + 13 = (ef + 12) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 12) _ _ _ _ step3,
      show ef + 12 = (ef + 11) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 11) _ _ _ _ step4,
      show ef + 11 = (ef + 10) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 10) _ _ _ _ step5,
      show ef + 10 = (ef + 9) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 9) _ _ _ _ step6,
      show ef + 9 = (ef + 8) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 8) _ _ _ _ step7,
      show ef + 8 = (ef + 7) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 7) _ _ _ _ step8,
      show ef + 7 = (ef + 6) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 6) _ _ _ _ step9,
      show ef + 6 = (ef + 5) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 5) _ _ _ _ step10,
      show ef + 5 = (ef + 4) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 4) _ _ _ _ step11,
      show ef + 4 = (ef + 3) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 3) _ _ _ _ step12,
      show ef + 3 = (ef + 2) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 2) _ _ _ _ step13,
      show ef + 2 = (ef + 1) + 1 from rfl,
      StepLemmas.run_succ_ok_of_step (ef + 1) _ _ _ _ step14,
      StepLemmas.run_succ_returned_of_step ef [] ms14 step15]

/-! ## Top-level equivalence theorem (Phase 4 closure) -/

/-- The verifier oracle's frame condition w.r.t. the proof struct read:
    if sigma succeeds (returns `some ([], cs2)`) on the rotation argument shape,
    then `cs2` still resolves `proofRid` to the original `proofFields` struct.

This is a real semantic precondition — without it, the bytecode (which reads
`proofFields[1]` from the post-sigma container store) and the functional sim
(which reads from the pre-sigma store) cannot agree. In a production deployment
this is enforced by the native Move VM: `verify_*_sigma_proof` natives only
allocate, never mutate or remove existing container slots. -/
abbrev RotationSigmaPreservesProofRead
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState) (hFieldCount : 0 < proofFields.length) : Prop :=
  ∀ cs2,
    o.verifySigmaProof (initMs.containers.alloc (proofFields[0]'hFieldCount)).1
        [.u8 chainId, .address sender, .address contract,
         currentEkRef, newEkRef, curBalRef, newBalRef,
         .immRef (initMs.containers.alloc (proofFields[0]'hFieldCount)).2] =
        some ([], cs2) →
    cs2.read proofRid = some (.struct_ proofFields)

theorem rotation_eval_equiv_functional_sim
    (o : RotationModuleOracle)
    (chainId : UInt8) (sender contract : ByteArray)
    (currentEkRef newEkRef curBalRef newBalRef proofRef : MoveValue)
    (proofRid : RefId) (proofFields : List MoveValue)
    (initMs : MachineState)
    (hFieldCount : 1 < proofFields.length)
    (hread : initMs.containers.read proofRid = some (.struct_ proofFields))
    (hproofRef : getRefId proofRef = some proofRid)
    (hSigmaPreserves :
       RotationSigmaPreservesProofRead o chainId sender contract
         currentEkRef newEkRef curBalRef newBalRef proofRid proofFields initMs
         (by omega : 0 < proofFields.length))
    (fuel : Nat)
    (hfuel : fuel ≥ 15) :
    let args := [.u8 chainId, .address sender, .address contract,
                 currentEkRef, newEkRef, curBalRef, newBalRef, proofRef]
    (eval (rotationModuleEnv o) verifyRotationProofIdx args fuel initMs).dropMs =
    match verifyRotationBytecodeResult o chainId sender contract currentEkRef newEkRef curBalRef newBalRef
            proofRid proofFields initMs hFieldCount with
    | .returned _ => .returned [] MachineState.empty
    | .error => .error := by
  -- Unfold eval → run, then dispatch on the alloc and oracle outcomes.
  show (eval (rotationModuleEnv o) verifyRotationProofIdx
          [.u8 chainId, .address sender, .address contract,
           currentEkRef, newEkRef, curBalRef, newBalRef, proofRef]
          fuel initMs).dropMs = _
  rw [eval_rotation_eq_run]
  -- First destructure the sigma alloc result (used by both sides). Capture the equation.
  rcases hSigmaPair : initMs.containers.alloc (proofFields[0]'(by omega : 0 < proofFields.length))
    with ⟨cs1, sigmaFid⟩
  -- Dispatch on the sigma oracle outcome.
  match hsigma : o.verifySigmaProof cs1
                    [.u8 chainId, .address sender, .address contract,
                     currentEkRef, newEkRef, curBalRef, newBalRef, .immRef sigmaFid] with
  | none =>
    have hRun := rot_run_to_sigma_fail_produces_error o chainId sender contract
                  currentEkRef newEkRef curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 sigmaFid (by omega : 0 < proofFields.length)
                  hread hproofRef hSigmaPair fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, verifyRotationBytecodeResult, hSigmaPair, hsigma]
  | some (sHead :: sTail, cs2) =>
    have hRun := rot_run_to_sigma_arity_mismatch_produces_error o chainId sender contract
                  currentEkRef newEkRef curBalRef newBalRef proofRef proofRid proofFields
                  initMs cs1 cs2 sigmaFid sHead sTail
                  (by omega : 0 < proofFields.length) hread hproofRef hSigmaPair
                  fuel (by omega) hsigma
    rw [hRun]
    simp only [ExecResult.dropMs_error, verifyRotationBytecodeResult, hSigmaPair, hsigma]
  | some ([], cs2) =>
    have hread2 : cs2.read proofRid = some (.struct_ proofFields) := by
      apply hSigmaPreserves cs2
      rw [hSigmaPair]; exact hsigma
    rcases hRangePair : cs2.alloc (proofFields[1]'hFieldCount) with ⟨cs3, zkrpFid⟩
    match hrange : o.verifyRangeProof cs3 [newBalRef, .immRef zkrpFid] with
    | none =>
      have hRun := rot_run_to_range_fail_produces_error o chainId sender contract
                    currentEkRef newEkRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 sigmaFid zkrpFid hFieldCount hread hread2
                    hproofRef hSigmaPair hsigma hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, verifyRotationBytecodeResult,
                 hSigmaPair, hsigma, hRangePair, hrange]
    | some (rHead :: rTail, cs4) =>
      have hRun := rot_run_to_range_arity_mismatch_produces_error o chainId sender contract
                    currentEkRef newEkRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid rHead rTail hFieldCount
                    hread hread2 hproofRef hSigmaPair hsigma hRangePair hrange
                    fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_error, verifyRotationBytecodeResult,
                 hSigmaPair, hsigma, hRangePair, hrange]
    | some ([], cs4) =>
      have hRun := rot_run_to_success_produces_returned o chainId sender contract
                    currentEkRef newEkRef curBalRef newBalRef proofRef proofRid proofFields
                    initMs cs1 cs2 cs3 cs4 sigmaFid zkrpFid hFieldCount hread hread2
                    hproofRef hSigmaPair hsigma hRangePair hrange fuel (by omega)
      rw [hRun]
      simp only [ExecResult.dropMs_returned, verifyRotationBytecodeResult,
                 hSigmaPair, hsigma, hRangePair, hrange]

end MovementFormal.Experimental.ConfidentialAsset.Rotation.EvalEquiv
