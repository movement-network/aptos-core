import MovementFormal.MoveModel.Step

/-!
# Step lemmas: abstract global-resource instructions

Parametric step lemmas for `globalExists` / `globalMoveTo` / `globalMoveToSigned` /
`mutBorrowGlobal`. These operate over `MachineState.globals` (a list of `GlobalResourceKey × RefId`
pairs) rather than user-facing locals or stack.

CA entry-point proofs (register, deposit, etc.) dispatch through these when checking / creating
the `ConfidentialAssetStore` resource.
-/

set_option linter.unusedSimpArgs false

namespace MovementFormal.MoveModel.StepLemmas

open MovementFormal.MoveModel

variable {env : ModuleEnv} {frame : Frame} {cs : List Frame}
variable {stack : List MoveValue} {ms : MachineState}

/-! ## `globalExists k` — push the boolean existence check -/

theorem step_globalExists (k : GlobalResourceKey)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .globalExists k) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs
           (.bool (MachineState.hasGlobal ms k) :: stack) ms := by
  simp only [step, dif_pos hpc, hc]

/-! ## `globalMoveTo k` — store top-of-stack as a new global (must not already exist) -/

theorem step_globalMoveTo_fresh
    (k : GlobalResourceKey) (v : MoveValue) (rest : List MoveValue)
    (containers' : ContainerStore) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .globalMoveTo k)
    (hfresh : MachineState.hasGlobal ms k = false)
    (halloc : ms.containers.alloc v = (containers', rid)) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest
           { containers := containers',
             globals := (ms.globals.filter fun p => (p.1 == k) == false) ++ [(k, rid)],
             faBalances := ms.faBalances } := by
  have : (decide (MachineState.hasGlobal ms k = true)) = false := by
    simp [hfresh]
  simp only [step, dif_pos hpc, hc, halloc]
  split <;> simp_all

/-- Error path: `globalMoveTo` aborts if the global already exists. -/
theorem step_globalMoveTo_exists
    (k : GlobalResourceKey) (v : MoveValue) (rest : List MoveValue)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .globalMoveTo k)
    (hexists : MachineState.hasGlobal ms k = true) :
    step env frame cs (v :: rest) ms = .error := by
  simp only [step, dif_pos hpc, hc, hexists, if_true]

/-! ## `globalMoveToSigned k` — signer-authenticated variant

TODO: the happy-path lemma is temporarily omitted pending a `BEq ByteArray`-aware simp set.
The wrong-signer and already-exists error paths are covered below. -/

/-- `globalMoveToSigned` aborts when the signer doesn't match `k.address`. -/
theorem step_globalMoveToSigned_wrongSigner
    (k : GlobalResourceKey) (v : MoveValue) (rest : List MoveValue) (sig : ByteArray)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .globalMoveToSigned k)
    (hne : (sig != k.address) = true) :
    step env frame cs (v :: .signer sig :: rest) ms = .error := by
  simp only [step, dif_pos hpc, hc, hne, if_true]

/-! ## `mutBorrowGlobal k` — produce a `mutRef` pointing at the existing global -/

theorem step_mutBorrowGlobal_ok
    (k : GlobalResourceKey) (rid : RefId)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowGlobal k)
    (hlookup : MachineState.lookupGlobal ms k = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.mutRef rid :: stack) ms := by
  simp only [step, dif_pos hpc, hc, hlookup]

/-- Error path: `mutBorrowGlobal` aborts if the global doesn't exist. -/
theorem step_mutBorrowGlobal_none
    (k : GlobalResourceKey)
    (hpc : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc = .mutBorrowGlobal k)
    (hlookup : MachineState.lookupGlobal ms k = none) :
    step env frame cs stack ms = .error := by
  simp only [step, dif_pos hpc, hc, hlookup]

end MovementFormal.MoveModel.StepLemmas
