import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Locals
import MovementFormal.MoveModel.StepLemmas.Refs
import MovementFormal.MoveModel.StepLemmas.Calls
import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

/-!
# Phase 1 body — Registration EvalEquiv rebuild (in progress)

**Scope:** this file is the work-in-progress rebuild of
`registration_eval_equiv_functional_sim` on the new architecture described in
[`CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../../../../../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §4.
It is NOT the final answer — it is scaffolding that lands the architectural decisions in-tree so
the rest of the rebuild can proceed from a concrete starting point.

## Architectural commitments (locked by this file)

1. **Symbolic state record.** `RegistrationState` is a flat record of named fields mirroring the
   subset of `Frame.locals` / operand stack the proof cares about. The frame itself stays an
   abstract `Frame` — we never unfold its definition, which is the key divergence from the old
   `EvalEquiv/Part3.lean` chain-of-`{ ... with pc := N, locals := ...set ... }` idiom that drove
   the O(N²) whnf cost.

2. **`@[irreducible]` from day one.** The frame-construction helpers below are marked
   `@[irreducible]` so `whnf` stops at the construction boundary instead of traversing the full
   chain. Projection lemmas are exposed as `@[simp]` where needed.

3. **`Array.get?` in statements.** Hypotheses about `frame.code[pc]` use `.get?` + an equality
   rather than `.code[pc]'<bound_proof>`. The bound proof becomes a separate `have` term proved
   by `decide` rather than a type-elaboration cost at statement parse time.

4. **Per-PC step-lemma dispatch.** Each PC step is discharged by one application of a step-lemma
   from `MovementFormal.MoveModel.StepLemmas.*` — no raw `simp only [step, dif_pos, ...]` rewrites
   on the whole frame.

## Status

Currently proved:
- `eval_registration_eq_run` — `eval` on `verifyRegistrationProofIdx` reduces to `run` on the
  initial frame constructed from 7 args. This is the entry-point unfolding; the rest of the
  rebuild threads through this equality.

Sorried:
- `registration_eval_equiv_functional_sim` — the top-level theorem itself. The axiom stub in
  `EvalEquiv.lean` still owns the public name; this file is a standalone sketch that will
  graduate to the real proof as more fragments close.

See the TEMPORARY AXIOM in `EvalEquiv.lean` for the live dependency. When enough fragments here
close, inline the proof into `EvalEquiv.lean` and drop the axiom.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.Experimental.ConfidentialAsset.Registration.FunctionalSim

/-! ## Initial-frame construction

The frame `eval` builds when dispatching to `verifyRegistrationProofIdx` is pure data:
19-slot locals array (7 initialized from args, 12 `none`), `code := verifyRegistrationProofCode`,
`pc := 0`, `localRefs` all `none`. Packaging this as an `@[irreducible]` helper prevents `simp`
from forcing whnf on the literal 19-element `List.replicate` / `.toArray` expression at every
statement. -/

/-- The initial-frame construction for `eval (registrationModuleEnv o) verifyRegistrationProofIdx args`. -/
@[irreducible]
def registrationInitFrame (args : List MoveValue) : Frame :=
  { code := verifyRegistrationProofCode,
    pc := 0,
    locals := (args.map some ++ List.replicate (19 - 7) none).toArray,
    localRefs := (List.replicate 19 none).toArray }

/-- Exposed form of the initial-frame definition so `simp` can reduce uses when desired. -/
theorem registrationInitFrame_def (args : List MoveValue) :
    registrationInitFrame args =
      { code := verifyRegistrationProofCode,
        pc := 0,
        locals := (args.map some ++ List.replicate 12 none).toArray,
        localRefs := (List.replicate 19 none).toArray } := by
  unfold registrationInitFrame
  rfl

/-! ## `eval` entry-point unfolding

The first rebuild lemma — `eval` on the registration entry point reduces to `run` on the initial
frame. This is the boundary between "top-level entry" and "per-PC bytecode trace"; every further
rebuild lemma operates on `run` outputs, not on `eval`. -/

/-- `(registrationModuleEnv o).functions` has 18 entries (indices 0..17). -/
theorem registrationModuleEnv_functions_size (o : RegistrationNativeOracle) :
    (registrationModuleEnv o).functions.size = 18 := by
  unfold registrationModuleEnv
  rfl

/-- The function at index 17 in `registrationModuleEnv` is `verifyRegistrationProofDesc`. -/
theorem registrationModuleEnv_idx17 (o : RegistrationNativeOracle)
    (h : verifyRegistrationProofIdx < (registrationModuleEnv o).functions.size) :
    (registrationModuleEnv o).functions[verifyRegistrationProofIdx]'h =
      verifyRegistrationProofDesc := by
  unfold registrationModuleEnv verifyRegistrationProofIdx
  rfl

/-- `eval` on the registration entry point reduces to `run` on `registrationInitFrame args`.

Observation: the proof does **not** depend on `args.length = 7`. The initial-frame locals array
is `args.map some ++ List.replicate 12 none`; any mismatch in `args.length` propagates through
`registrationInitFrame` but is irrelevant to this equality (both sides use the same `args.map
some` expression). Callers that need `args.length = 7` will thread that hypothesis through
downstream lemmas instead of this boundary. -/
theorem eval_registration_eq_run (o : RegistrationNativeOracle) (args : List MoveValue)
    (fuel : Nat) (initMs : MachineState) :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx args fuel initMs =
      run (registrationModuleEnv o) (registrationInitFrame args) [] [] initMs fuel := by
  have hlt : verifyRegistrationProofIdx < (registrationModuleEnv o).functions.size := by
    rw [registrationModuleEnv_functions_size]
    unfold verifyRegistrationProofIdx
    decide
  have hidx := registrationModuleEnv_idx17 o hlt
  unfold eval
  simp only [dif_pos hlt, hidx]
  -- `verifyRegistrationProofDesc.body = .bytecode verifyRegistrationProofCode 19` with numParams = 7.
  show run _ _ _ _ _ _ = run _ (registrationInitFrame args) _ _ _ _
  congr 1
  unfold registrationInitFrame verifyRegistrationProofDesc
  simp

/-! ## Frame projection helpers

Lightweight lemmas that expose fields of `registrationInitFrame args` without forcing whnf on
the full 19-slot locals array. These let per-PC step lemmas thread through without paying the
elaboration cost the old `Part*.lean` chain incurred. -/

/-- `code` of the registration initial frame is `verifyRegistrationProofCode`. -/
@[simp] theorem registrationInitFrame_code (args : List MoveValue) :
    (registrationInitFrame args).code = verifyRegistrationProofCode := by
  unfold registrationInitFrame; rfl

/-- `pc` of the registration initial frame is 0. -/
@[simp] theorem registrationInitFrame_pc (args : List MoveValue) :
    (registrationInitFrame args).pc = 0 := by
  unfold registrationInitFrame; rfl

/-- `localRefs` of the registration initial frame is 19 `none`s. -/
theorem registrationInitFrame_localRefs_eq (args : List MoveValue) :
    (registrationInitFrame args).localRefs =
      ((List.replicate 19 none).toArray : Array (Option RefId)) := by
  unfold registrationInitFrame; rfl

/-- `localRefs` size of the registration initial frame is 19. -/
theorem registrationInitFrame_localRefs_size (args : List MoveValue) :
    (registrationInitFrame args).localRefs.size = 19 := by
  rw [registrationInitFrame_localRefs_eq]
  simp

/-- `.get?` form of `localRefs[i]` for the initial frame — always `none` when in bounds.

Stated with `.get?` rather than `.get]'<bound_proof>` to sidestep the dependent-type motive
issue `rw` hits on the bound form (see plan §4's "Array.get? in theorem statements" guidance). -/
theorem registrationInitFrame_localRefs_get? (args : List MoveValue) (i : Nat) :
    (registrationInitFrame args).localRefs[i]? =
      ((List.replicate 19 none).toArray : Array (Option RefId))[i]? := by
  rw [registrationInitFrame_localRefs_eq]

/-! ## Step 0 — `moveLoc 5` at PC 0 moves the commitment bytes onto the stack

This is the first per-PC step lemma of the rebuild. It consumes the initial frame, pops nothing
off the stack (moveLoc only writes, doesn't consume), and produces a frame at PC 1 with
`locals[5] = none` and the original args[5] pushed onto the stack. -/

/-- The first bytecode instruction is `moveLoc 5` — committed by the `verifyRegistrationProofCode`
constant, independent of the args. -/
theorem registrationCode_pc0 :
    verifyRegistrationProofCode[0]'(by unfold verifyRegistrationProofCode; decide) =
      .moveLoc 5 := rfl

/-! ## Locals facts at PC 0

When `args = [chainId, sender, contract, ekStruct, tokenAddr, commitBa, respBa]` (length 7),
the initial frame's locals are `args.map some ++ 12×none`, so `locals[5] = some commitBa`.

The bound-proof dance uses `List.getElem` rather than the `.get]'` idiom, matching plan §4's
guidance on avoiding dependent-type motive issues during rewrite. -/

/-- `locals[i] = some args[i]` when `i < args.length`, stated via `List.get?` to sidestep
dependent bound-proof motive issues. -/
theorem registrationInitFrame_locals_get? (args : List MoveValue) (i : Nat)
    (h : i < args.length) :
    (registrationInitFrame args).locals[i]? = some (some args[i]) := by
  have hLoc : (registrationInitFrame args).locals =
      (args.map some ++ List.replicate (19 - 7) none).toArray := by
    unfold registrationInitFrame; rfl
  have hMap : i < (args.map some).length := by simpa using h
  rw [hLoc]
  simp [List.getElem?_append_left hMap, List.getElem?_eq_getElem hMap]

/-! ## Top-level theorem — sketched, not yet proved

The full `registration_eval_equiv_functional_sim` threads `eval_registration_eq_run` with a
chain of step-lemma applications across all 84 PCs. Each PC is a one-line application of a
lemma from `MovementFormal.MoveModel.StepLemmas.*`, following the template demonstrated in
`MovementFormal.MoveModel.StepLemmas.Example`.

The case-structure follows the old `Part4.lean`:
- `o.newCompressedPointFromBytes [...] = none` → early error path (short).
- `o.newCompressedPointFromBytes [...] = some [mv]` → singleton success continues to PC 2.
- Other lengths → functional sim also errors (by `single?` none-case), both sides match.

The happy-path branch (singleton success) further case-splits on `newScalarFromBytes` and the
subsequent `o.pointEquals` result. The old proof closed this via
`registration_eval_equiv_singleton_tail` (a now-deleted axiom). The rebuild lands the same case
analysis but discharges each block via the new step-lemma dispatch instead of the chain-based
idiom that made the old `Part3.lean` expensive.

**TODO:** reprove `registration_eval_equiv_functional_sim` here, then inline the result into
`EvalEquiv.lean` and drop the TEMPORARY AXIOM. -/

/-! ## Specialization to the 7-element args shape

The top-level theorem `registration_eval_equiv_functional_sim` instantiates args as a concrete
7-element list `[chainId, sender, contract, ekStruct, token, commitBa, respBa]`. Per-PC step
lemmas are stated against this shape so `rfl`-style proofs handle bound checks and locals
accesses concretely.

`registrationArgs` below packages the 7-element canonical list so statements stay short. -/

/-- Canonical 7-element args list for `verify_registration_proof`. -/
@[reducible] def registrationArgs
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    List MoveValue :=
  [.u8 chainId,
   .address sender,
   .address contract,
   .struct_ [.vector .u8 (ekBa.toList.map .u8)],
   .address token,
   .vector .u8 (commitBa.toList.map .u8),
   .vector .u8 (respBa.toList.map .u8)]

/-- The 7-element args list has length 7. -/
@[simp] theorem registrationArgs_length
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (registrationArgs chainId sender contract token ekBa commitBa respBa).length = 7 := rfl

/-- `args[5]` is the commitment-bytes vector. -/
theorem registrationArgs_get_5
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (registrationArgs chainId sender contract token ekBa commitBa respBa)[5] =
      .vector .u8 (commitBa.toList.map .u8) := rfl

/-- `args[6]` is the response-bytes vector. -/
theorem registrationArgs_get_6
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (registrationArgs chainId sender contract token ekBa commitBa respBa)[6] =
      .vector .u8 (respBa.toList.map .u8) := rfl

/-! ## Initial-frame facts on the 7-element args

Bound checks and locals accesses become `rfl` / `decide` when args is the canonical 7-element
literal, because `(args.map some ++ 12×none).toArray` is then fully concrete. -/

/-- Size of `locals` on any initial frame is `args.length + 12`. -/
theorem registrationInitFrame_locals_size (args : List MoveValue) :
    (registrationInitFrame args).locals.size = args.length + 12 := by
  unfold registrationInitFrame
  simp [List.length_append, List.length_map]

/-- Size of `locals` on the 7-element initial frame is 19. -/
theorem registrationInitFrame7_locals_size
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    (registrationInitFrame
      (registrationArgs chainId sender contract token ekBa commitBa respBa)).locals.size = 19 := by
  rw [registrationInitFrame_locals_size, registrationArgs_length]

/-- Size of `code` on the initial frame is 84 (the bytecode length). -/
theorem registrationInitFrame_code_size (args : List MoveValue) :
    (registrationInitFrame args).code.size = 84 := by
  rw [registrationInitFrame_code]
  unfold verifyRegistrationProofCode
  decide

/-! ## PC 0 — moveLoc 5

The first bytecode step moves `commitBa` from `locals[5]` onto the stack.
Stated against the canonical 7-element args shape where every side condition reduces by `rfl`. -/

/-- Side-condition bundle for PC-0 step (`moveLoc 5`). Packaged as a lemma so the step-rule
    application can invoke it without re-deriving the bound proofs. -/
theorem registration_pc0_sides (args : List MoveValue) (hargs6 : 6 ≤ args.length) :
    (registrationInitFrame args).pc < (registrationInitFrame args).code.size ∧
    5 < (registrationInitFrame args).locals.size ∧
    5 < (registrationInitFrame args).localRefs.size := by
  refine ⟨?_, ?_, ?_⟩
  · rw [registrationInitFrame_pc, registrationInitFrame_code_size]; decide
  · rw [registrationInitFrame_locals_size]; omega
  · rw [registrationInitFrame_localRefs_size]; decide

/-- PC-0 code lookup: `(initFrame args).code[0]` = `.moveLoc 5`. Stated via `.get?` to sidestep
the dependent-motive issue on `.get]'<bound>`. -/
theorem registrationInitFrame_code_pc0_get? (args : List MoveValue) :
    (registrationInitFrame args).code[0]? = some (.moveLoc 5) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-1 code lookup. -/
theorem registrationInitFrame_code_pc1_get? (args : List MoveValue) :
    (registrationInitFrame args).code[1]? = some (.call 0) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-2 code lookup. -/
theorem registrationInitFrame_code_pc2_get? (args : List MoveValue) :
    (registrationInitFrame args).code[2]? = some (.stLoc 7) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-3 code lookup. -/
theorem registrationInitFrame_code_pc3_get? (args : List MoveValue) :
    (registrationInitFrame args).code[3]? = some (.immBorrowLoc 7) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-4 code lookup. -/
theorem registrationInitFrame_code_pc4_get? (args : List MoveValue) :
    (registrationInitFrame args).code[4]? = some (.call 1) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-5 code lookup: the first abort-guard branch. -/
theorem registrationInitFrame_code_pc5_get? (args : List MoveValue) :
    (registrationInitFrame args).code[5]? = some (.brFalse 79) := by
  rw [registrationInitFrame_code]
  rfl

/-- PC-83 code lookup: the final `abort_` instruction. -/
theorem registrationInitFrame_code_pc83_get? (args : List MoveValue) :
    (registrationInitFrame args).code[83]? = some .abort_ := by
  rw [registrationInitFrame_code]
  rfl

/-! ## PC 0 — the `moveLoc 5` step fully discharged for the canonical 7-args shape

This is the **first real bytecode step** of the rebuild: one application of `step` on the
initial frame reduces to a concrete ok-result. Stated only for the canonical 7-args shape so
every bound check reduces by `rfl` — no dependent-motive `rw` issues.

The proof mirrors the pattern that each of the 84 per-PC rebuild lemmas will follow:
unfold `step`, dispatch on the opcode (here `.moveLoc 5`), feed the locals lookup,
discharge the localRefs-none case, and the result is `rfl`. -/

/-- After one step on the 7-args initial frame, PC moves to 1 and `commitBa` is pushed onto
the stack. This is the first concrete per-PC step theorem of the rebuild. -/
theorem step_registration_pc0_7args (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray) :
    step env
      (registrationInitFrame
        (registrationArgs chainId sender contract token ekBa commitBa respBa)) cs stack ms =
      .ok
        { code := verifyRegistrationProofCode,
          pc := 1,
          locals := (((registrationArgs chainId sender contract token ekBa commitBa respBa).map some ++
                      List.replicate 12 none).toArray).set 5 none (by
            show 5 < ((registrationArgs chainId sender contract token ekBa commitBa respBa).map some ++
                      List.replicate 12 none).length
            simp [registrationArgs]),
          localRefs := (List.replicate 19 none).toArray }
        cs
        (.vector .u8 (commitBa.toList.map .u8) :: stack) ms := by
  unfold registrationInitFrame
  unfold step
  -- PC 0 is in bounds, instruction is `.moveLoc 5`, locals[5] = some commitBa, localRefs[5] = none.
  -- Every side condition reduces by `rfl` once the initFrame is unfolded to its literal form.
  rfl

/-! ## PC 2 — `stLoc 7` (store r_point)

PC-2's step is generic: for any frame with `code := verifyRegistrationProofCode`, `pc := 2`,
and `locals.size ≥ 8`, the `.stLoc 7` consumes the top of stack and stores it to locals[7].

The lemma is stated against an arbitrary frame so it composes with PC 1's `.call 0` native
result (the frame at PC 2 is produced by the native call, not by `registrationInitFrame`
directly). This is the pattern the remaining PC lemmas will follow. -/

/-- PC-2 step: consume `v` off the stack and store to `locals[7]`. Frame-agnostic — takes
any frame whose code matches `verifyRegistrationProofCode` at PC 2 and whose locals fit. -/
theorem step_registration_pc2 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 2)
    (hlocals : 7 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with
              pc := 3,
              locals := frame.locals.set 7 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 7 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    7 v rest hpc_lt hc hlocals
  -- `frame.pc + 1 = 3` since `frame.pc = 2`.
  rw [show frame.pc + 1 = 3 from by omega] at this
  exact this

/-! ## PC 3 — `immBorrowLoc 7`

Borrows an immutable reference to local 7 (r_point). Generic over frame. -/

theorem step_registration_pc3_existingRef (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 3)
    (hlocals : 7 < frame.locals.size)
    (hv : frame.locals[7]'hlocals = some v)
    (hltRef : 7 < frame.localRefs.size)
    (hRef : frame.localRefs[7]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 4 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 7 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    7 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 4 from by omega] at this
  exact this

/-! ## PC 5 — `brFalse 79` (guard on option::is_some result)

Conditional branch: if top of stack is `.bool false`, jump to PC 79 (abort path); if `.bool true`,
fall through to PC 6 (continue). Two variants. -/

theorem step_registration_pc5_taken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 5) :
    step env frame cs (.bool false :: rest) ms =
      .ok { frame with pc := 79 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 79 := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_brFalse_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    79 rest hpc_lt hc

theorem step_registration_pc5_notTaken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 5) :
    step env frame cs (.bool true :: rest) ms =
      .ok { frame with pc := 6 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 79 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_brFalse_not_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    79 rest hpc_lt hc
  rw [show frame.pc + 1 = 6 from by omega] at this
  exact this

/-! ## PC 6 — `mutBorrowLoc 7` (&mut r_point) -/

theorem step_registration_pc6_existingRef (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 6)
    (hlocals : 7 < frame.locals.size)
    (hv : frame.locals[7]'hlocals = some v)
    (hltRef : 7 < frame.localRefs.size)
    (hRef : frame.localRefs[7]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 7 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 7 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_mutBorrowLoc_existing
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    7 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 7 from by omega] at this
  exact this

/-! ## PC 8 — `stLoc 8` (store r_compressed) -/

theorem step_registration_pc8 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 8)
    (hlocals : 8 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with
              pc := 9,
              locals := frame.locals.set 8 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 8 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    8 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 9 from by omega] at this
  exact this

/-! ## PC 9 — `moveLoc 6` (push response_bytes) -/

theorem step_registration_pc9 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 9)
    (hlocals : 6 < frame.locals.size)
    (hv : frame.locals[6]'hlocals = some v)
    (hRefNone : ¬ 6 < frame.localRefs.size ∨
        ∃ (h : 6 < frame.localRefs.size), frame.localRefs[6]'h = none) :
    step env frame cs stack ms =
      .ok { frame with
              pc := 10,
              locals := frame.locals.set 6 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 6 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    6 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 10 from by omega] at this
  exact this

/-! ## PC 11 — `stLoc 9` (store s_opt) -/

theorem step_registration_pc11 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 11)
    (hlocals : 9 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with
              pc := 12,
              locals := frame.locals.set 9 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 9 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    9 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 12 from by omega] at this
  exact this

/-! ## PC 14 — `brFalse 74` (guard on option::is_some for scalar deserialization) -/

theorem step_registration_pc14_taken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 14) :
    step env frame cs (.bool false :: rest) ms =
      .ok { frame with pc := 74 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 74 := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_brFalse_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    74 rest hpc_lt hc

theorem step_registration_pc14_notTaken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 14) :
    step env frame cs (.bool true :: rest) ms =
      .ok { frame with pc := 15 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 74 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_brFalse_not_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    74 rest hpc_lt hc
  rw [show frame.pc + 1 = 15 from by omega] at this
  exact this

/-! ## PC 69 — `brFalse 71` (guard on final `point_equals` result) -/

theorem step_registration_pc69_taken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 69) :
    step env frame cs (.bool false :: rest) ms =
      .ok { frame with pc := 71 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 71 := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_brFalse_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    71 rest hpc_lt hc

theorem step_registration_pc69_notTaken (env : ModuleEnv) (cs : List Frame)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 69) :
    step env frame cs (.bool true :: rest) ms =
      .ok { frame with pc := 70 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .brFalse 71 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_brFalse_not_taken (frame := frame) (env := env) (cs := cs) (ms := ms)
    71 rest hpc_lt hc
  rw [show frame.pc + 1 = 70 from by omega] at this
  exact this

/-! ## PC 70 — `ret` (successful return with empty callStack) -/

theorem step_registration_pc70 (env : ModuleEnv) (stack : List MoveValue) (ms : MachineState)
    (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 70) :
    step env frame [] stack ms = .returned stack ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ret := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_ret_top (frame := frame) (env := env) hpc_lt hc

/-! ## PC 71 / 76 / 81 — `ldU64 1` (push abort code 1 before `error::invalid_argument`) -/

theorem step_registration_pc71 (env : ModuleEnv) (cs : List Frame) (stack : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 71) :
    step env frame cs stack ms =
      .ok { frame with pc := 72 } cs (.u64 1 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ldU64 1 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_ldU64 (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 1 hpc_lt hc
  rw [show frame.pc + 1 = 72 from by omega] at this
  exact this

theorem step_registration_pc76 (env : ModuleEnv) (cs : List Frame) (stack : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 76) :
    step env frame cs stack ms =
      .ok { frame with pc := 77 } cs (.u64 1 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ldU64 1 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_ldU64 (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 1 hpc_lt hc
  rw [show frame.pc + 1 = 77 from by omega] at this
  exact this

theorem step_registration_pc81 (env : ModuleEnv) (cs : List Frame) (stack : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 81) :
    step env frame cs stack ms =
      .ok { frame with pc := 82 } cs (.u64 1 :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ldU64 1 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_ldU64 (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 1 hpc_lt hc
  rw [show frame.pc + 1 = 82 from by omega] at this
  exact this

/-! ## PC 74 / 79 — `moveLoc 3` (push ek ref) on scalar-parse-fail / point-parse-fail paths -/

theorem step_registration_pc74 (env : ModuleEnv) (cs : List Frame) (stack : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 74)
    (hlocals : 3 < frame.locals.size)
    (hv : frame.locals[3]'hlocals = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨
        ∃ (h : 3 < frame.localRefs.size), frame.localRefs[3]'h = none) :
    step env frame cs stack ms =
      .ok { frame with
              pc := 75,
              locals := frame.locals.set 3 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    3 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 75 from by omega] at this
  exact this

theorem step_registration_pc79 (env : ModuleEnv) (cs : List Frame) (stack : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 79)
    (hlocals : 3 < frame.locals.size)
    (hv : frame.locals[3]'hlocals = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨
        ∃ (h : 3 < frame.localRefs.size), frame.localRefs[3]'h = none) :
    step env frame cs stack ms =
      .ok { frame with
              pc := 80,
              locals := frame.locals.set 3 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    3 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 80 from by omega] at this
  exact this

/-! ## PC 75 / 80 — `pop` (drop ek ref on error paths) -/

theorem step_registration_pc75 (env : ModuleEnv) (cs : List Frame) (v : MoveValue)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 75) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 76 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .pop := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_pop (frame := frame) (env := env) (cs := cs) (ms := ms)
    v rest hpc_lt hc
  rw [show frame.pc + 1 = 76 from by omega] at this
  exact this

theorem step_registration_pc80 (env : ModuleEnv) (cs : List Frame) (v : MoveValue)
    (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 80) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 81 } cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .pop := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_pop (frame := frame) (env := env) (cs := cs) (ms := ms)
    v rest hpc_lt hc
  rw [show frame.pc + 1 = 81 from by omega] at this
  exact this

/-! ## PC 73 / 78 / 83 — `abort_` (the three abort sinks on error paths) -/

theorem step_registration_pc73 (env : ModuleEnv) (cs : List Frame)
    (code : UInt64) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 73) :
    step env frame cs (.u64 code :: rest) ms = .aborted code := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .abort_ := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_abort (frame := frame) (env := env) (cs := cs) (ms := ms)
    code rest hpc_lt hc

theorem step_registration_pc78 (env : ModuleEnv) (cs : List Frame)
    (code : UInt64) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 78) :
    step env frame cs (.u64 code :: rest) ms = .aborted code := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .abort_ := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_abort (frame := frame) (env := env) (cs := cs) (ms := ms)
    code rest hpc_lt hc

theorem step_registration_pc83 (env : ModuleEnv) (cs : List Frame)
    (code : UInt64) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 83) :
    step env frame cs (.u64 code :: rest) ms = .aborted code := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .abort_ := by
    simp only [hcode, hpc]; rfl
  exact StepLemmas.step_abort (frame := frame) (env := env) (cs := cs) (ms := ms)
    code rest hpc_lt hc

/-! ## Bulk Fiat-Shamir / point-arithmetic per-PC step theorems

The block below covers every non-native PC from 12 through 68, plus the lone `copyLoc 3/8`
instructions that feed the native calls. Every theorem follows the same three-line template
established above: (1) `hpc_lt` by `decide` after rewriting to the concrete bytecode, (2) `hc`
via `simp only [hcode, hpc]; rfl`, (3) apply the relevant step-lemma and arithmetically reduce
`pc + 1`. -/

/-! ### PC 12 — `immBorrowLoc 9` (&s_opt) -/

theorem step_registration_pc12 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 12)
    (hlocals : 9 < frame.locals.size)
    (hv : frame.locals[9]'hlocals = some v)
    (hltRef : 9 < frame.localRefs.size)
    (hRef : frame.localRefs[9]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 13 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 9 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    9 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 13 from by omega] at this; exact this

/-! ### PC 15 — `mutBorrowLoc 9` (&mut s_opt) -/

theorem step_registration_pc15 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 15)
    (hlocals : 9 < frame.locals.size)
    (hv : frame.locals[9]'hlocals = some v)
    (hltRef : 9 < frame.localRefs.size)
    (hRef : frame.localRefs[9]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 16 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 9 := by
    simp only [hcode, hpc]; rfl
  have := StepLemmas.step_mutBorrowLoc_existing
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    9 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 16 from by omega] at this; exact this

/-! ### PC 17 — `stLoc 10` (store s) -/

theorem step_registration_pc17 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 17)
    (hlocals : 10 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 18, locals := frame.locals.set 10 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 10 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    10 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 18 from by omega] at this; exact this

/-! ### PC 18 — `ldConst 5` (push DST bytes) -/

theorem step_registration_pc18 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 18)
    (hconstants : 5 < env.constants.size) :
    step env frame cs stack ms =
      .ok { frame with pc := 19 } cs (env.constants[5].value :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .ldConst 5 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_ldConst (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 5 hpc_lt hc hconstants
  rw [show frame.pc + 1 = 19 from by omega] at this; exact this

/-! ### PC 19 — `stLoc 11` (store msg) -/

theorem step_registration_pc19 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 19)
    (hlocals : 11 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 20, locals := frame.locals.set 11 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 11 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    11 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 20 from by omega] at this; exact this

/-! ### PC 20, 23, 27, 31, 35, 39 — all `mutBorrowLoc 11` (repeatedly &mut msg) -/

private theorem step_registration_mutBorrowLoc11_helper
    (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hpc_lt : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := frame.pc + 1 } cs (.mutRef rid :: stack) ms :=
  StepLemmas.step_mutBorrowLoc_existing
    (frame := frame) (env := env) (cs := cs) (stack := stack) (ms := ms)
    11 v rid hpc_lt hc hlocals hv hltRef hRef

theorem step_registration_pc20 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 20)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 21 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 21 from by omega] at this; exact this

theorem step_registration_pc23 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 23)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 24 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 24 from by omega] at this; exact this

theorem step_registration_pc27 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 27)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 28 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 28 from by omega] at this; exact this

theorem step_registration_pc31 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 31)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 32 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 32 from by omega] at this; exact this

theorem step_registration_pc35 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 35)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 36 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 36 from by omega] at this; exact this

theorem step_registration_pc39 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 39)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hltRef : 11 < frame.localRefs.size)
    (hRef : frame.localRefs[11]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 40 } cs (.mutRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .mutBorrowLoc 11 := by simp only [hcode, hpc]; rfl
  have := step_registration_mutBorrowLoc11_helper env cs stack ms frame v rid
    hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 40 from by omega] at this; exact this

/-! ### PC 21 — `moveLoc 0` (push chainId) -/

theorem step_registration_pc21 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 21)
    (hlocals : 0 < frame.locals.size)
    (hv : frame.locals[0]'hlocals = some v)
    (hRefNone : ¬ 0 < frame.localRefs.size ∨
        ∃ (h : 0 < frame.localRefs.size), frame.localRefs[0]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := 22, locals := frame.locals.set 0 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 0 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 0 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 22 from by omega] at this; exact this

/-! ### PC 24 — `immBorrowLoc 1` (&sender) -/

theorem step_registration_pc24 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 24)
    (hlocals : 1 < frame.locals.size)
    (hv : frame.locals[1]'hlocals = some v)
    (hltRef : 1 < frame.localRefs.size)
    (hRef : frame.localRefs[1]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 25 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 1 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 1 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 25 from by omega] at this; exact this

/-! ### PC 28 — `immBorrowLoc 2` (&contract_address) -/

theorem step_registration_pc28 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 28)
    (hlocals : 2 < frame.locals.size)
    (hv : frame.locals[2]'hlocals = some v)
    (hltRef : 2 < frame.localRefs.size)
    (hRef : frame.localRefs[2]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 29 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 2 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 2 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 29 from by omega] at this; exact this

/-! ### PC 32 — `immBorrowLoc 4` (&token_address) -/

theorem step_registration_pc32 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 32)
    (hlocals : 4 < frame.locals.size)
    (hv : frame.locals[4]'hlocals = some v)
    (hltRef : 4 < frame.localRefs.size)
    (hRef : frame.localRefs[4]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 33 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 4 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 4 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 33 from by omega] at this; exact this

/-! ### PC 43 — `moveLoc 11` (push msg, consumes it) -/

theorem step_registration_pc43 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 43)
    (hlocals : 11 < frame.locals.size)
    (hv : frame.locals[11]'hlocals = some v)
    (hRefNone : ¬ 11 < frame.localRefs.size ∨
        ∃ (h : 11 < frame.localRefs.size), frame.localRefs[11]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := 44, locals := frame.locals.set 11 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 11 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 11 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 44 from by omega] at this; exact this

/-! ### PC 45 — `stLoc 12` (store e) -/

theorem step_registration_pc45 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 45)
    (hlocals : 12 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 46, locals := frame.locals.set 12 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 12 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    12 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 46 from by omega] at this; exact this

/-! ### PC 47 — `stLoc 13` (store h) -/

theorem step_registration_pc47 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 47)
    (hlocals : 13 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 48, locals := frame.locals.set 13 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 13 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    13 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 48 from by omega] at this; exact this

/-! ### PC 48 — `moveLoc 3` (push ek ref, consumes it) -/

theorem step_registration_pc48 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 48)
    (hlocals : 3 < frame.locals.size)
    (hv : frame.locals[3]'hlocals = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨
        ∃ (h : 3 < frame.localRefs.size), frame.localRefs[3]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := 49, locals := frame.locals.set 3 none (by omega) }
           cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .moveLoc 3 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_moveLoc_noRef (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 3 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 49 from by omega] at this; exact this

/-! ### PC 50 — `stLoc 14` (store ek_point) -/

theorem step_registration_pc50 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 50)
    (hlocals : 14 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 51, locals := frame.locals.set 14 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 14 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    14 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 51 from by omega] at this; exact this

/-! ### PCs 51, 52, 55, 56, 57, 60, 63, 66, 67 — immBorrowLoc of various locals -/

theorem step_registration_pc51 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 51)
    (hlocals : 13 < frame.locals.size) (hv : frame.locals[13]'hlocals = some v)
    (hltRef : 13 < frame.localRefs.size) (hRef : frame.localRefs[13]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 52 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 13 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 13 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 52 from by omega] at this; exact this

theorem step_registration_pc52 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 52)
    (hlocals : 10 < frame.locals.size) (hv : frame.locals[10]'hlocals = some v)
    (hltRef : 10 < frame.localRefs.size) (hRef : frame.localRefs[10]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 53 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 10 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 10 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 53 from by omega] at this; exact this

theorem step_registration_pc54 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 54)
    (hlocals : 15 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 55, locals := frame.locals.set 15 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 15 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    15 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 55 from by omega] at this; exact this

theorem step_registration_pc55 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 55)
    (hlocals : 15 < frame.locals.size) (hv : frame.locals[15]'hlocals = some v)
    (hltRef : 15 < frame.localRefs.size) (hRef : frame.localRefs[15]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 56 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 15 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 15 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 56 from by omega] at this; exact this

theorem step_registration_pc56 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 56)
    (hlocals : 14 < frame.locals.size) (hv : frame.locals[14]'hlocals = some v)
    (hltRef : 14 < frame.localRefs.size) (hRef : frame.localRefs[14]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 57 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 14 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 14 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 57 from by omega] at this; exact this

theorem step_registration_pc57 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 57)
    (hlocals : 12 < frame.locals.size) (hv : frame.locals[12]'hlocals = some v)
    (hltRef : 12 < frame.localRefs.size) (hRef : frame.localRefs[12]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 58 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 12 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 12 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 58 from by omega] at this; exact this

theorem step_registration_pc59 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 59)
    (hlocals : 16 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 60, locals := frame.locals.set 16 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 16 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    16 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 60 from by omega] at this; exact this

theorem step_registration_pc60 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 60)
    (hlocals : 16 < frame.locals.size) (hv : frame.locals[16]'hlocals = some v)
    (hltRef : 16 < frame.localRefs.size) (hRef : frame.localRefs[16]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 61 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 16 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 16 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 61 from by omega] at this; exact this

theorem step_registration_pc62 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 62)
    (hlocals : 17 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 63, locals := frame.locals.set 17 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 17 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    17 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 63 from by omega] at this; exact this

theorem step_registration_pc63 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 63)
    (hlocals : 8 < frame.locals.size) (hv : frame.locals[8]'hlocals = some v)
    (hltRef : 8 < frame.localRefs.size) (hRef : frame.localRefs[8]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 64 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 8 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 8 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 64 from by omega] at this; exact this

theorem step_registration_pc65 (env : ModuleEnv) (cs : List Frame)
    (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 65)
    (hlocals : 18 < frame.locals.size) :
    step env frame cs (v :: rest) ms =
      .ok { frame with pc := 66, locals := frame.locals.set 18 (some v) (by omega) }
           cs rest ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .stLoc 18 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_stLoc (frame := frame) (env := env) (cs := cs) (ms := ms)
    18 v rest hpc_lt hc hlocals
  rw [show frame.pc + 1 = 66 from by omega] at this; exact this

theorem step_registration_pc66 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 66)
    (hlocals : 17 < frame.locals.size) (hv : frame.locals[17]'hlocals = some v)
    (hltRef : 17 < frame.localRefs.size) (hRef : frame.localRefs[17]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 67 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 17 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 17 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 67 from by omega] at this; exact this

theorem step_registration_pc67 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue) (rid : RefId)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 67)
    (hlocals : 18 < frame.locals.size) (hv : frame.locals[18]'hlocals = some v)
    (hltRef : 18 < frame.localRefs.size) (hRef : frame.localRefs[18]'hltRef = some rid) :
    step env frame cs stack ms =
      .ok { frame with pc := 68 } cs (.immRef rid :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .immBorrowLoc 18 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_immBorrowLoc_existing (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 18 v rid hpc_lt hc hlocals hv hltRef hRef
  rw [show frame.pc + 1 = 68 from by omega] at this; exact this

/-! ### PC 36 — `copyLoc 3` (copy ek ref without consuming) -/

theorem step_registration_pc36 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 36)
    (hlocals : 3 < frame.locals.size)
    (hv : frame.locals[3]'hlocals = some v)
    (hRefNone : ¬ 3 < frame.localRefs.size ∨
        ∃ (h : 3 < frame.localRefs.size), frame.localRefs[3]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := 37 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 3 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_copyLoc_noRef (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 3 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 37 from by omega] at this; exact this

/-! ### PC 40 — `copyLoc 8` (copy r_compressed value without consuming) -/

theorem step_registration_pc40 (env : ModuleEnv) (cs : List Frame)
    (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (v : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 40)
    (hlocals : 8 < frame.locals.size)
    (hv : frame.locals[8]'hlocals = some v)
    (hRefNone : ¬ 8 < frame.localRefs.size ∨
        ∃ (h : 8 < frame.localRefs.size), frame.localRefs[8]'h = none) :
    step env frame cs stack ms =
      .ok { frame with pc := 41 } cs (v :: stack) ms := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .copyLoc 8 := by simp only [hcode, hpc]; rfl
  have := StepLemmas.step_copyLoc_noRef (frame := frame) (env := env) (cs := cs)
    (stack := stack) (ms := ms) 8 v hpc_lt hc hlocals hv hRefNone
  rw [show frame.pc + 1 = 41 from by omega] at this; exact this

/-! ## Native-call PCs — oracle-result case splits

Each `.call <natIdx>` dispatches to a native body. The step lemma below instantiates
`StepLemmas.Calls.step_call_native_ret1` (or `_nativeRef_ret1`) with the registration module's
concrete function descriptors. Each lemma takes the oracle result as an explicit hypothesis —
the caller case-splits on the oracle response (`some [mv]` vs `none`) and threads each branch
through the rest of the proof. -/

/-- PC 1: `.call 0` dispatching to `newCompressedPointFromBytes`. Happy path: oracle returns
`some [mv]` for a singleton compressed-point result. -/
theorem step_registration_pc1_some (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (mv : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 1)
    (horacle : env_orig.newCompressedPointFromBytes [v] = some [mv]) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 2 } cs (mv :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; rfl
  have hlt : (0 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[0]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[0]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[0]'hlt).body =
      .native env_orig.newCompressedPointFromBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by
    unfold takeN; simp
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    0 [v] rest (v :: rest) env_orig.newCompressedPointFromBytes 1 mv
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 2 from by omega] at this
  exact this

/-- PC 1: `.call 0` dispatching to `newCompressedPointFromBytes`. Error path: oracle returns `none`. -/
theorem step_registration_pc1_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 1)
    (horacle : env_orig.newCompressedPointFromBytes [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 0 := by simp only [hcode, hpc]; rfl
  have hlt : (0 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[0]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[0]'hlt).body =
      .native env_orig.newCompressedPointFromBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by
    unfold takeN; simp
  exact StepLemmas.step_call_native_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    0 [v] rest (v :: rest) env_orig.newCompressedPointFromBytes 1
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 10: `.call 3` dispatching to `newScalarFromBytes`. Happy path. -/
theorem step_registration_pc10_some (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (sv : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 10)
    (horacle : env_orig.newScalarFromBytes [v] = some [sv]) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 11 } cs (sv :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 3 := by simp only [hcode, hpc]; rfl
  have hlt : (3 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[3]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[3]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[3]'hlt).body =
      .native env_orig.newScalarFromBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by
    unfold takeN; simp
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    3 [v] rest (v :: rest) env_orig.newScalarFromBytes 1 sv
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 11 from by omega] at this
  exact this

/-! ## Per-function-descriptor facts for `registrationModuleEnv`

Batched `rfl` lemmas exposing `numParams`, `numReturns`, and `body` for every function index the
bytecode dispatches to. These let per-PC proofs be shortened, and give future rebuild work a
fixed reference point. -/

theorem registrationModuleEnv_fn0_numParams (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[0]'(by
      rw [registrationModuleEnv_functions_size]; decide)).numParams = 1 := by
  unfold registrationModuleEnv; rfl

theorem registrationModuleEnv_fn0_numReturns (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[0]'(by
      rw [registrationModuleEnv_functions_size]; decide)).numReturns = 1 := by
  unfold registrationModuleEnv; rfl

theorem registrationModuleEnv_fn0_body (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[0]'(by
      rw [registrationModuleEnv_functions_size]; decide)).body =
      .native o.newCompressedPointFromBytes := by
  unfold registrationModuleEnv; rfl

theorem registrationModuleEnv_fn1_numParams (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[1]'(by
      rw [registrationModuleEnv_functions_size]; decide)).numParams = 1 := by
  unfold registrationModuleEnv; rfl

theorem registrationModuleEnv_fn1_body (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[1]'(by
      rw [registrationModuleEnv_functions_size]; decide)).body =
      .nativeRef optionIsSomeRef := by
  unfold registrationModuleEnv; rfl

theorem registrationModuleEnv_fn16_body (o : RegistrationNativeOracle) :
    ((registrationModuleEnv o).functions[16]'(by
      rw [registrationModuleEnv_functions_size]; decide)).body =
      .native errorInvalidArgument := by
  unfold registrationModuleEnv; rfl

/-! ### PC 4 / 13 — `.call 1` (option::is_some<T>, nativeRef, 1→1) -/

theorem step_registration_pc4 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 4)
    (horacle : optionIsSomeRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 5 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; rfl
  have hlt : (1 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[1]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[1]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[1]'hlt).body = .nativeRef optionIsSomeRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    1 [v] rest (v :: rest) optionIsSomeRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 5 from by omega] at this
  exact this

theorem step_registration_pc13 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 13)
    (horacle : optionIsSomeRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 14 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 1 := by simp only [hcode, hpc]; rfl
  have hlt : (1 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[1]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[1]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[1]'hlt).body = .nativeRef optionIsSomeRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    1 [v] rest (v :: rest) optionIsSomeRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 14 from by omega] at this
  exact this

/-! ### PC 7 / 16 — `.call 2` (option::extract<T>, nativeRef, 1→1) -/

theorem step_registration_pc7 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 7)
    (horacle : optionExtractRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 8 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 2 := by simp only [hcode, hpc]; rfl
  have hlt : (2 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[2]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[2]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[2]'hlt).body = .nativeRef optionExtractRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    2 [v] rest (v :: rest) optionExtractRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 8 from by omega] at this
  exact this

theorem step_registration_pc16 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 16)
    (horacle : optionExtractRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 17 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 2 := by simp only [hcode, hpc]; rfl
  have hlt : (2 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[2]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[2]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[2]'hlt).body = .nativeRef optionExtractRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    2 [v] rest (v :: rest) optionExtractRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 17 from by omega] at this
  exact this

/-! ### PC 72 / 77 / 82 — `.call 16` (error::invalid_argument, native, 1→1) -/

theorem step_registration_pc72 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (reason : UInt64) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 72) :
    step (registrationModuleEnv env_orig) frame cs (.u64 reason :: rest) ms =
      .ok { frame with pc := 73 } cs (.u64 (65536 + reason) :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 16 := by simp only [hcode, hpc]; rfl
  have hlt : (16 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[16]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[16]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[16]'hlt).body = .native errorInvalidArgument := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (.u64 reason :: rest) 1 = some ([.u64 reason], rest) := by unfold takeN; simp
  have himpl : errorInvalidArgument [.u64 reason] = some [.u64 (65536 + reason)] := rfl
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    16 [.u64 reason] rest (.u64 reason :: rest) errorInvalidArgument 1 (.u64 (65536 + reason))
    hpc_lt hc hlt hparams hreturns hbody htake himpl
  rw [show frame.pc + 1 = 73 from by omega] at this
  exact this

theorem step_registration_pc77 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (reason : UInt64) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 77) :
    step (registrationModuleEnv env_orig) frame cs (.u64 reason :: rest) ms =
      .ok { frame with pc := 78 } cs (.u64 (65536 + reason) :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 16 := by simp only [hcode, hpc]; rfl
  have hlt : (16 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[16]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[16]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[16]'hlt).body = .native errorInvalidArgument := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (.u64 reason :: rest) 1 = some ([.u64 reason], rest) := by unfold takeN; simp
  have himpl : errorInvalidArgument [.u64 reason] = some [.u64 (65536 + reason)] := rfl
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    16 [.u64 reason] rest (.u64 reason :: rest) errorInvalidArgument 1 (.u64 (65536 + reason))
    hpc_lt hc hlt hparams hreturns hbody htake himpl
  rw [show frame.pc + 1 = 78 from by omega] at this
  exact this

theorem step_registration_pc82 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (reason : UInt64) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 82) :
    step (registrationModuleEnv env_orig) frame cs (.u64 reason :: rest) ms =
      .ok { frame with pc := 83 } cs (.u64 (65536 + reason) :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 16 := by simp only [hcode, hpc]; rfl
  have hlt : (16 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[16]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[16]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[16]'hlt).body = .native errorInvalidArgument := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (.u64 reason :: rest) 1 = some ([.u64 reason], rest) := by unfold takeN; simp
  have himpl : errorInvalidArgument [.u64 reason] = some [.u64 (65536 + reason)] := rfl
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    16 [.u64 reason] rest (.u64 reason :: rest) errorInvalidArgument 1 (.u64 (65536 + reason))
    hpc_lt hc hlt hparams hreturns hbody htake himpl
  rw [show frame.pc + 1 = 83 from by omega] at this
  exact this

/-! ### PC 46 — `.call 10` (hashToPointBase, native, 0→1)

Zero-argument native: `impl []` produces the base point. -/

theorem step_registration_pc46 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (stack : List MoveValue) (ms : MachineState) (frame : Frame) (hPoint : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 46)
    (horacle : env_orig.hashToPointBase [] = some [hPoint]) :
    step (registrationModuleEnv env_orig) frame cs stack ms =
      .ok { frame with pc := 47 } cs (hPoint :: stack)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 10 := by simp only [hcode, hpc]; rfl
  have hlt : (10 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[10]'hlt).numParams = 0 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[10]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[10]'hlt).body = .native env_orig.hashToPointBase := by
    unfold registrationModuleEnv; rfl
  have htake : takeN stack 0 = some ([], stack) := by unfold takeN; simp
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    10 [] stack stack env_orig.hashToPointBase 0 hPoint
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 47 from by omega] at this
  exact this

/-! ### PC 41 — `.call 8` (compressedPointToBytes, native, 1→1) -/

theorem step_registration_pc41 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (bytesV : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 41)
    (horacle : env_orig.compressedPointToBytes [v] = some [bytesV]) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 42 } cs (bytesV :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 8 := by simp only [hcode, hpc]; rfl
  have hlt : (8 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[8]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[8]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[8]'hlt).body = .native env_orig.compressedPointToBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    8 [v] rest (v :: rest) env_orig.compressedPointToBytes 1 bytesV
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 42 from by omega] at this
  exact this

/-! ### PC 44 — `.call 9` (newScalarFromSha2_512, native, 1→1) -/

theorem step_registration_pc44 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (eScalar : MoveValue)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 44)
    (horacle : newScalarFromSha2_512 [v] = some [eScalar]) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 45 } cs (eScalar :: rest)
           { ms with containers := ms.containers, globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 9 := by simp only [hcode, hpc]; rfl
  have hlt : (9 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[9]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[9]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[9]'hlt).body = .native newScalarFromSha2_512 := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_native_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    9 [v] rest (v :: rest) newScalarFromSha2_512 1 eScalar
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 45 from by omega] at this
  exact this

/-! ### PC 22 — `.call 4` (vectorPushBackU8Ref, nativeRef, 2→0)

Consumes `&mut msg` and `u8` (chainId) from the stack, pushes nothing. -/

theorem step_registration_pc22 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 22)
    (horacle : vectorPushBackU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 23 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 4 := by simp only [hcode, hpc]; rfl
  have hlt : (4 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[4]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[4]'hlt).numReturns = 0 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[4]'hlt).body = .nativeRef vectorPushBackU8Ref := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret0
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    4 [a, b] rest (b :: a :: rest) vectorPushBackU8Ref 2 containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 23 from by omega] at this
  exact this

/-! ### PC 25 / 29 / 33 — `.call 5` (bcsToBytesAddressRef, nativeRef, 1→1) -/

theorem step_registration_pc25 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 25)
    (horacle : bcsToBytesAddressRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 26 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 5 := by simp only [hcode, hpc]; rfl
  have hlt : (5 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[5]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[5]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[5]'hlt).body = .nativeRef bcsToBytesAddressRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    5 [v] rest (v :: rest) bcsToBytesAddressRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 26 from by omega] at this
  exact this

theorem step_registration_pc29 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 29)
    (horacle : bcsToBytesAddressRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 30 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 5 := by simp only [hcode, hpc]; rfl
  have hlt : (5 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[5]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[5]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[5]'hlt).body = .nativeRef bcsToBytesAddressRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    5 [v] rest (v :: rest) bcsToBytesAddressRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 30 from by omega] at this
  exact this

theorem step_registration_pc33 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 33)
    (horacle : bcsToBytesAddressRef ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 34 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 5 := by simp only [hcode, hpc]; rfl
  have hlt : (5 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[5]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[5]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[5]'hlt).body = .nativeRef bcsToBytesAddressRef := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    5 [v] rest (v :: rest) bcsToBytesAddressRef 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 34 from by omega] at this
  exact this

/-! ### PC 26 / 30 / 34 / 38 / 42 — `.call 6` (vectorAppendU8Ref, nativeRef, 2→0) -/

private theorem step_registration_call6_apply (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hpc_lt : frame.pc < frame.code.size)
    (hc : frame.code[frame.pc]'hpc_lt = .call 6)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := frame.pc + 1 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hlt : (6 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[6]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[6]'hlt).numReturns = 0 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[6]'hlt).body = .nativeRef vectorAppendU8Ref := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_ret0
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    6 [a, b] rest (b :: a :: rest) vectorAppendU8Ref 2 containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle

theorem step_registration_pc26 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 26)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 27 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 6 := by simp only [hcode, hpc]; rfl
  have := step_registration_call6_apply env_orig cs a b rest ms frame containers'
    hpc_lt hc horacle
  rw [show frame.pc + 1 = 27 from by omega] at this
  exact this

theorem step_registration_pc30 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 30)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 31 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 6 := by simp only [hcode, hpc]; rfl
  have := step_registration_call6_apply env_orig cs a b rest ms frame containers'
    hpc_lt hc horacle
  rw [show frame.pc + 1 = 31 from by omega] at this
  exact this

theorem step_registration_pc34 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 34)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 35 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 6 := by simp only [hcode, hpc]; rfl
  have := step_registration_call6_apply env_orig cs a b rest ms frame containers'
    hpc_lt hc horacle
  rw [show frame.pc + 1 = 35 from by omega] at this
  exact this

theorem step_registration_pc38 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 38)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 39 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 6 := by simp only [hcode, hpc]; rfl
  have := step_registration_call6_apply env_orig cs a b rest ms frame containers'
    hpc_lt hc horacle
  rw [show frame.pc + 1 = 39 from by omega] at this
  exact this

theorem step_registration_pc42 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 42)
    (horacle : vectorAppendU8Ref ms.containers [a, b] = some ([], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 43 } cs rest
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 6 := by simp only [hcode, hpc]; rfl
  have := step_registration_call6_apply env_orig cs a b rest ms frame containers'
    hpc_lt hc horacle
  rw [show frame.pc + 1 = 43 from by omega] at this
  exact this

/-! ### PC 37 — `.call 7` (pubkeyToBytes, nativeRef via wrapOracleImmRef1, 1→1) -/

theorem step_registration_pc37 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 37)
    (horacle : wrapOracleImmRef1 env_orig.pubkeyToBytes ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 38 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 7 := by simp only [hcode, hpc]; rfl
  have hlt : (7 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[7]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[7]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[7]'hlt).body =
      .nativeRef (wrapOracleImmRef1 env_orig.pubkeyToBytes) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    7 [v] rest (v :: rest) (wrapOracleImmRef1 env_orig.pubkeyToBytes) 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 38 from by omega] at this
  exact this

/-! ### PC 49 — `.call 11` (pubkeyToPoint, nativeRef via wrapOracleImmRef1, 1→1) -/

theorem step_registration_pc49 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 49)
    (horacle : wrapOracleImmRef1 env_orig.pubkeyToPoint ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 50 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 11 := by simp only [hcode, hpc]; rfl
  have hlt : (11 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[11]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[11]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[11]'hlt).body =
      .nativeRef (wrapOracleImmRef1 env_orig.pubkeyToPoint) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    11 [v] rest (v :: rest) (wrapOracleImmRef1 env_orig.pubkeyToPoint) 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 50 from by omega] at this
  exact this

/-! ### PC 64 — `.call 14` (pointDecompress, nativeRef via wrapOracleImmRef1, 1→1) -/

theorem step_registration_pc64 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 64)
    (horacle : wrapOracleImmRef1 env_orig.pointDecompress ms.containers [v] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms =
      .ok { frame with pc := 65 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 14 := by simp only [hcode, hpc]; rfl
  have hlt : (14 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[14]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[14]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[14]'hlt).body =
      .nativeRef (wrapOracleImmRef1 env_orig.pointDecompress) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    14 [v] rest (v :: rest) (wrapOracleImmRef1 env_orig.pointDecompress) 1 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 65 from by omega] at this
  exact this

/-! ### PC 53 / 58 — `.call 12` (pointMul, nativeRef via wrapOracleImmRef2, 2→1) -/

theorem step_registration_pc53 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 53)
    (horacle : wrapOracleImmRef2 env_orig.pointMul ms.containers [a, b] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 54 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 12 := by simp only [hcode, hpc]; rfl
  have hlt : (12 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[12]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[12]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[12]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointMul) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    12 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointMul) 2 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 54 from by omega] at this
  exact this

theorem step_registration_pc58 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 58)
    (horacle : wrapOracleImmRef2 env_orig.pointMul ms.containers [a, b] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 59 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 12 := by simp only [hcode, hpc]; rfl
  have hlt : (12 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[12]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[12]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[12]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointMul) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    12 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointMul) 2 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 59 from by omega] at this
  exact this

/-! ### PC 61 — `.call 13` (pointAdd, nativeRef via wrapOracleImmRef2, 2→1) -/

theorem step_registration_pc61 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 61)
    (horacle : wrapOracleImmRef2 env_orig.pointAdd ms.containers [a, b] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 62 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 13 := by simp only [hcode, hpc]; rfl
  have hlt : (13 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[13]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[13]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[13]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointAdd) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    13 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointAdd) 2 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 62 from by omega] at this
  exact this

/-! ## Error-path (`_none`) variants

Each native-call PC also has a `_none` variant: when the oracle returns `none`, the step
produces `.error`. These are needed for the final composition theorem's case-split on oracle
results.

Only the natives whose `none` result is semantically meaningful are covered — stdlib natives like
`optionIsSomeRef` / `vectorAppendU8Ref` don't meaningfully fail on well-typed input, so their
`_none` variants are omitted. -/

theorem step_registration_pc10_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 10)
    (horacle : env_orig.newScalarFromBytes [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 3 := by simp only [hcode, hpc]; rfl
  have hlt : (3 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[3]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[3]'hlt).body = .native env_orig.newScalarFromBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_native_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    3 [v] rest (v :: rest) env_orig.newScalarFromBytes 1
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 46 (`hashToPointBase`) error variant: oracle returns `none`. -/
theorem step_registration_pc46_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (stack : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 46)
    (horacle : env_orig.hashToPointBase [] = none) :
    step (registrationModuleEnv env_orig) frame cs stack ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 10 := by simp only [hcode, hpc]; rfl
  have hlt : (10 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[10]'hlt).numParams = 0 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[10]'hlt).body = .native env_orig.hashToPointBase := by
    unfold registrationModuleEnv; rfl
  have htake : takeN stack 0 = some ([], stack) := by unfold takeN; simp
  exact StepLemmas.step_call_native_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    10 [] stack stack env_orig.hashToPointBase 0
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 41 (`compressedPointToBytes`) error variant. -/
theorem step_registration_pc41_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 41)
    (horacle : env_orig.compressedPointToBytes [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 8 := by simp only [hcode, hpc]; rfl
  have hlt : (8 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[8]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[8]'hlt).body = .native env_orig.compressedPointToBytes := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_native_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    8 [v] rest (v :: rest) env_orig.compressedPointToBytes 1
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 44 (`newScalarFromSha2_512`) error variant. -/
theorem step_registration_pc44_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 44)
    (horacle : newScalarFromSha2_512 [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 9 := by simp only [hcode, hpc]; rfl
  have hlt : (9 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[9]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[9]'hlt).body = .native newScalarFromSha2_512 := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_native_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    9 [v] rest (v :: rest) newScalarFromSha2_512 1
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 49 (`pubkey_to_point`) error variant. -/
theorem step_registration_pc49_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 49)
    (horacle : wrapOracleImmRef1 env_orig.pubkeyToPoint ms.containers [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 11 := by simp only [hcode, hpc]; rfl
  have hlt : (11 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[11]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[11]'hlt).body =
      .nativeRef (wrapOracleImmRef1 env_orig.pubkeyToPoint) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    11 [v] rest (v :: rest) (wrapOracleImmRef1 env_orig.pubkeyToPoint) 1
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 53 (`point_mul`) error variant. -/
theorem step_registration_pc53_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 53)
    (horacle : wrapOracleImmRef2 env_orig.pointMul ms.containers [a, b] = none) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 12 := by simp only [hcode, hpc]; rfl
  have hlt : (12 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[12]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[12]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointMul) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    12 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointMul) 2
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 61 (`point_add`) error variant. -/
theorem step_registration_pc61_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 61)
    (horacle : wrapOracleImmRef2 env_orig.pointAdd ms.containers [a, b] = none) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 13 := by simp only [hcode, hpc]; rfl
  have hlt : (13 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[13]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[13]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointAdd) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    13 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointAdd) 2
    hpc_lt hc hlt hparams hbody htake horacle

/-- PC 64 (`point_decompress`) error variant. -/
theorem step_registration_pc64_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (v : MoveValue) (rest : List MoveValue) (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 64)
    (horacle : wrapOracleImmRef1 env_orig.pointDecompress ms.containers [v] = none) :
    step (registrationModuleEnv env_orig) frame cs (v :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 14 := by simp only [hcode, hpc]; rfl
  have hlt : (14 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[14]'hlt).numParams = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[14]'hlt).body =
      .nativeRef (wrapOracleImmRef1 env_orig.pointDecompress) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (v :: rest) 1 = some ([v], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    14 [v] rest (v :: rest) (wrapOracleImmRef1 env_orig.pointDecompress) 1
    hpc_lt hc hlt hparams hbody htake horacle

theorem step_registration_pc68_none (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 68)
    (horacle : wrapOracleImmRef2 env_orig.pointEquals ms.containers [a, b] = none) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms = .error := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 15 := by simp only [hcode, hpc]; rfl
  have hlt : (15 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[15]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[15]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointEquals) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  exact StepLemmas.step_call_nativeRef_none
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    15 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointEquals) 2
    hpc_lt hc hlt hparams hbody htake horacle

/-! ### PC 68 — `.call 15` (pointEquals, nativeRef via wrapOracleImmRef2, 2→1) -/

theorem step_registration_pc68 (env_orig : RegistrationNativeOracle)
    (cs : List Frame) (a b : MoveValue) (rest : List MoveValue)
    (ms : MachineState) (frame : Frame) (resultV : MoveValue) (containers' : ContainerStore)
    (hcode : frame.code = verifyRegistrationProofCode) (hpc : frame.pc = 68)
    (horacle : wrapOracleImmRef2 env_orig.pointEquals ms.containers [a, b] = some ([resultV], containers')) :
    step (registrationModuleEnv env_orig) frame cs (b :: a :: rest) ms =
      .ok { frame with pc := 69 } cs (resultV :: rest)
           { ms with containers := containers', globals := ms.globals } := by
  have hpc_lt : frame.pc < frame.code.size := by
    rw [hpc, hcode]; unfold verifyRegistrationProofCode; decide
  have hc : frame.code[frame.pc]'hpc_lt = .call 15 := by simp only [hcode, hpc]; rfl
  have hlt : (15 : Nat) < (registrationModuleEnv env_orig).functions.size := by
    rw [registrationModuleEnv_functions_size]; decide
  have hparams : ((registrationModuleEnv env_orig).functions[15]'hlt).numParams = 2 := by
    unfold registrationModuleEnv; rfl
  have hreturns : ((registrationModuleEnv env_orig).functions[15]'hlt).numReturns = 1 := by
    unfold registrationModuleEnv; rfl
  have hbody : ((registrationModuleEnv env_orig).functions[15]'hlt).body =
      .nativeRef (wrapOracleImmRef2 env_orig.pointEquals) := by
    unfold registrationModuleEnv; rfl
  have htake : takeN (b :: a :: rest) 2 = some ([a, b], rest) := by unfold takeN; simp
  have := StepLemmas.step_call_nativeRef_ret1
    (env := registrationModuleEnv env_orig) (frame := frame) (cs := cs) (ms := ms)
    15 [a, b] rest (b :: a :: rest) (wrapOracleImmRef2 env_orig.pointEquals) 2 resultV containers'
    hpc_lt hc hlt hparams hreturns hbody htake horacle
  rw [show frame.pc + 1 = 69 from by omega] at this
  exact this

/-! ## Early-error composition — `newCompressedPointFromBytes` returns `none`

First real composition win: when the commitment-bytes oracle returns `none`, `eval` on the
registration entry produces `.error`. Threads PC 0 (`moveLoc 5`) + PC 1 `_none` through
`run`'s recursion — the pattern the full `registration_eval_equiv_functional_sim` scales to
84 PCs via the same `unfold run; rw [PC lemma]` idiom.

The statement is about `run` rather than `eval` because `eval_registration_eq_run` bridges them
— combining this with `eval_registration_eq_run` gives the `eval = .error` form directly. -/

theorem registration_early_error_compressedPoint_none
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : 2 ≤ fuel)
    (hnone : o.newCompressedPointFromBytes
        [.vector .u8 (commitBa.toList.map .u8)] = none) :
    (run (registrationModuleEnv o)
        (registrationInitFrame
          (registrationArgs chainId sender contract token ekBa commitBa respBa))
        [] [] MachineState.empty fuel) = .error := by
  -- Peel off first two units of fuel: fuel = f2 + 2.
  have hf : ∃ f2, fuel = f2 + 2 := by
    rcases fuel with _ | _ | f2
    · omega
    · omega
    · exact ⟨f2, by omega⟩
  obtain ⟨f2, rfl⟩ := hf
  -- Apply PC 0 step: moveLoc 5 produces the args[5] = commitBa vector on stack.
  have step0 := step_registration_pc0_7args (registrationModuleEnv o) [] [] MachineState.empty
    chainId sender contract token ekBa commitBa respBa
  -- Apply PC 1 step with oracle returning none: step returns .error.
  have step1_none := step_registration_pc1_none o []
    (.vector .u8 (commitBa.toList.map .u8)) [] MachineState.empty
    { code := verifyRegistrationProofCode, pc := 1,
      locals := (((registrationArgs chainId sender contract token ekBa commitBa respBa).map some ++
                  List.replicate 12 none).toArray).set 5 none (by
        show 5 < ((registrationArgs chainId sender contract token ekBa commitBa respBa).map some ++
                  List.replicate 12 none).length
        simp [registrationArgs]),
      localRefs := (List.replicate 19 none).toArray }
    (by rfl) (by rfl) hnone
  -- Thread step0 and step1_none through two `run` unfoldings.
  show run _ _ _ _ _ (f2 + 2) = _
  unfold run
  rw [step0]
  simp only
  unfold run
  rw [step1_none]

/-- `eval` form of the early-error composition — combines `eval_registration_eq_run` with
`registration_early_error_compressedPoint_none` so callers can see the top-level statement. -/
theorem eval_registration_early_error_compressedPoint_none
    (o : RegistrationNativeOracle)
    (chainId : UInt8) (sender contract token ekBa commitBa respBa : ByteArray)
    (fuel : Nat) (hfuel : 2 ≤ fuel)
    (hnone : o.newCompressedPointFromBytes
        [.vector .u8 (commitBa.toList.map .u8)] = none) :
    eval (registrationModuleEnv o) verifyRegistrationProofIdx
        (registrationArgs chainId sender contract token ekBa commitBa respBa)
        fuel MachineState.empty = .error := by
  rw [eval_registration_eq_run]
  exact registration_early_error_compressedPoint_none o chainId sender contract token
    ekBa commitBa respBa fuel hfuel hnone

/-! The `Run` helpers (`run_succ_ok_of_step`, `run_succ_error_of_step`, etc.) in
`StepLemmas/Run.lean` provide a cleaner pattern for future compositions. Each PC becomes a
one-line `rw` rather than manual `unfold run`. See the PC-0/1 inline proof above for the manual
form; future composition theorems should prefer the `Run` helpers. -/

end MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
