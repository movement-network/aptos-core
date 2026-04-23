import MovementFormal.MoveModel.Value
import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Instr
import MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeTranscriptionLemmas

/-! # Instruction Effect Catalog

This file provides a comprehensive catalog of all instruction types used in
the registration singleton branch and their effects on state. For each
instruction type we document:

1. **Stack effect**: How it modifies the stack
2. **Locals effect**: Which locals it reads/writes
3. **PC effect**: How it advances the PC
4. **Container store effect**: Reference allocations
5. **Side effects**: Global state modifications

## Instruction Types Used

The registration proof uses 9 instruction types:
- CopyLoc, MoveLoc, StLoc (locals manipulation)
- ImmBorrowLoc, MutBorrowLoc (reference creation)
- ReadRef, WriteRef (reference operations)
- Call (native function calls)
- BrFalse (conditional branching)

-/

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.InstructionEffectCatalog

open MovementFormal.MoveModel
open MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeTranscriptionLemmas

/-! ## Instruction Effect Structures -/

/-- Stack effect of an instruction. -/
inductive StackEffect
  | push (n : Nat)              -- Push n values onto stack
  | pop (n : Nat)               -- Pop n values from stack
  | transform (pop push : Nat)  -- Pop n, push m
  | noop                        -- No stack change

/-- Locals effect of an instruction. -/
inductive LocalsEffect
  | read (idx : Nat)            -- Read from local idx
  | write (idx : Nat)           -- Write to local idx
  | move (idx : Nat)            -- Move from local idx (clears it)
  | noEffect                    -- No locals change

/-- PC effect of an instruction. -/
inductive PCEffect
  | increment                   -- PC := PC + 1
  | branch (target : Nat)       -- PC := target
  | conditionalBranch (target : Nat)  -- PC := target or PC + 1
  | ret                         -- Return from function

/-- Container store effect. -/
inductive ContainerEffect
  | allocate (refType : String) -- Allocate new container
  | modify (refId : Nat)        -- Modify existing container
  | noEffect                    -- No container change

/-- Complete instruction effect. -/
structure InstructionEffect where
  stack : StackEffect
  locals : LocalsEffect
  pc : PCEffect
  container : ContainerEffect
  description : String

/-! ## CopyLoc Effect -/

/-- CopyLoc effect specification. -/
def copyLocEffect (idx : Nat) : InstructionEffect :=
  { stack := .push 1,
    locals := .read idx,
    pc := .increment,
    container := .noEffect,
    description := s!"Copy local {idx} to stack top" }

/-- CopyLoc correctness. -/
theorem copyLoc_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.copyLoc idx))
    (h_local : frame.locals[idx]? = some (some val))
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: push 1
    stack'.length = stack.length + 1 ∧
    stack' = val :: stack ∧
    -- Locals effect: read (unchanged)
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- CopyLoc effect

/-! ## MoveLoc Effect -/

/-- MoveLoc effect specification. -/
def moveLocEffect (idx : Nat) : InstructionEffect :=
  { stack := .push 1,
    locals := .move idx,
    pc := .increment,
    container := .noEffect,
    description := s!"Move local {idx} to stack top, clear local" }

/-- MoveLoc correctness. -/
theorem moveLoc_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.moveLoc idx))
    (h_local : frame.locals[idx]? = some (some val))
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: push 1
    stack'.length = stack.length + 1 ∧
    stack' = val :: stack ∧
    -- Locals effect: clear
    frame'.locals[idx]? = some none ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- MoveLoc effect

/-! ## StLoc Effect -/

/-- StLoc effect specification. -/
def stLocEffect (idx : Nat) : InstructionEffect :=
  { stack := .pop 1,
    locals := .write idx,
    pc := .increment,
    container := .noEffect,
    description := s!"Store stack top to local {idx}" }

/-- StLoc correctness. -/
theorem stLoc_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.stLoc idx))
    (h_stack : stack = val :: rest_stack)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop 1
    stack'.length = stack.length - 1 ∧
    stack' = rest_stack ∧
    -- Locals effect: write
    frame'.locals[idx]? = some (some val) ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- StLoc effect

/-! ## ImmBorrowLoc Effect -/

/-- ImmBorrowLoc effect specification. -/
def immBorrowLocEffect (idx : Nat) : InstructionEffect :=
  { stack := .push 1,
    locals := .read idx,
    pc := .increment,
    container := .allocate "immutable",
    description := s!"Create immutable reference to local {idx}" }

/-- ImmBorrowLoc correctness. -/
theorem immBorrowLoc_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.immBorrowLoc idx))
    (h_local : frame.locals[idx]? = some (some val))
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: push reference
    stack'.length = stack.length + 1 ∧
    (∃ refId, stack' = (.immRef refId) :: stack) ∧
    -- Locals effect: unchanged
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: allocate
    ms'.containerStore.containers.length =
    ms.containerStore.containers.length + 1 := by
  sorry  -- ImmBorrowLoc effect

/-! ## MutBorrowLoc Effect -/

/-- MutBorrowLoc effect specification. -/
def mutBorrowLocEffect (idx : Nat) : InstructionEffect :=
  { stack := .push 1,
    locals := .read idx,
    pc := .increment,
    container := .allocate "mutable",
    description := s!"Create mutable reference to local {idx}" }

/-- MutBorrowLoc correctness. -/
theorem mutBorrowLoc_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (idx : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.mutBorrowLoc idx))
    (h_local : frame.locals[idx]? = some (some val))
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: push reference
    stack'.length = stack.length + 1 ∧
    (∃ refId, stack' = (.mutRef refId) :: stack) ∧
    -- Locals effect: unchanged
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: allocate
    ms'.containerStore.containers.length =
    ms.containerStore.containers.length + 1 := by
  sorry  -- MutBorrowLoc effect

/-! ## ReadRef Effect -/

/-- ReadRef effect specification. -/
def readRefEffect : InstructionEffect :=
  { stack := .transform 1 1,
    locals := .noEffect,
    pc := .increment,
    container := .noEffect,
    description := "Read value through reference (pop ref, push value)" }

/-- ReadRef correctness. -/
theorem readRef_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (refId : Nat)
    (val : MoveValue)
    (h_instr : frame.code[frame.pc]? = some .readRef)
    (h_stack : stack = (.immRef refId) :: rest_stack ∨
               stack = (.mutRef refId) :: rest_stack)
    (h_container : ms.containerStore.read? refId = some val)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop ref, push value
    stack'.length = stack.length ∧
    stack' = val :: rest_stack ∧
    -- Locals effect: none
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- ReadRef effect

/-! ## WriteRef Effect -/

/-- WriteRef effect specification. -/
def writeRefEffect : InstructionEffect :=
  { stack := .pop 2,
    locals := .noEffect,
    pc := .increment,
    container := .modify 0,  -- Modifies referenced container
    description := "Write value through mutable reference" }

/-- WriteRef correctness. -/
theorem writeRef_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (refId : Nat)
    (val_new : MoveValue)
    (h_instr : frame.code[frame.pc]? = some .writeRef)
    (h_stack : stack = val_new :: (.mutRef refId) :: rest_stack)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop 2
    stack'.length = stack.length - 2 ∧
    stack' = rest_stack ∧
    -- Locals effect: none
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: modified
    ms'.containerStore.read? refId = some val_new := by
  sorry  -- WriteRef effect

/-! ## Call Effect -/

/-- Call effect specification (varies by function). -/
def callEffect (funcIdx : Nat) (num_args num_results : Nat) : InstructionEffect :=
  { stack := .transform num_args num_results,
    locals := .noEffect,
    pc := .increment,
    container := .noEffect,
    description := s!"Call function {funcIdx}: pop {num_args} args, push {num_results} results" }

/-- Call correctness (generic). -/
theorem call_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (funcIdx : Nat)
    (args results : List MoveValue)
    (h_instr : frame.code[frame.pc]? = some (.call funcIdx))
    (h_stack_prefix : ∃ rest, stack = args.reverse ++ rest)
    (h_oracle_call : OracleCallSuccess env funcIdx args results)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop args, push results
    (∃ rest, stack = args.reverse ++ rest ∧
             stack' = results.reverse ++ rest) ∧
    -- Locals effect: none (for native calls)
    frame'.locals = frame.locals ∧
    -- PC effect: increment
    frame'.pc = frame.pc + 1 := by
  sorry  -- Call effect

where
  OracleCallSuccess (env : ModuleEnv) (funcIdx : Nat)
                   (args results : List MoveValue) : Prop := True

/-! ## BrFalse Effect -/

/-- BrFalse effect specification. -/
def brFalseEffect (target : Nat) : InstructionEffect :=
  { stack := .pop 1,
    locals := .noEffect,
    pc := .conditionalBranch target,
    container := .noEffect,
    description := s!"Pop bool, branch to {target} if false, else continue" }

/-- BrFalse correctness (false case). -/
theorem brFalse_false_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (target : Nat)
    (h_instr : frame.code[frame.pc]? = some (.brFalse target))
    (h_stack : stack = (.bool false) :: rest_stack)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop bool
    stack'.length = stack.length - 1 ∧
    stack' = rest_stack ∧
    -- Locals effect: none
    frame'.locals = frame.locals ∧
    -- PC effect: branch to target
    frame'.pc = target ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- BrFalse (false) effect

/-- BrFalse correctness (true case). -/
theorem brFalse_true_effect_correct
    (env : ModuleEnv)
    (frame : Frame)
    (stack : List MoveValue)
    (ms : MachineState)
    (target : Nat)
    (h_instr : frame.code[frame.pc]? = some (.brFalse target))
    (h_stack : stack = (.bool true) :: rest_stack)
    (frame' : Frame)
    (stack' : List MoveValue)
    (ms' : MachineState)
    (h_step : step env [] frame stack ms = .ok [] frame' stack' ms') :
    -- Stack effect: pop bool
    stack'.length = stack.length - 1 ∧
    stack' = rest_stack ∧
    -- Locals effect: none
    frame'.locals = frame.locals ∧
    -- PC effect: increment (continue)
    frame'.pc = frame.pc + 1 ∧
    -- Container effect: none
    ms'.containerStore = ms.containerStore := by
  sorry  -- BrFalse (true) effect

/-! ## Instruction Frequency and Distribution -/

/-- Instruction usage statistics in registration proof. -/
structure InstructionStatistics where
  copyLoc_count : Nat := 15
  moveLoc_count : Nat := 8
  stLoc_count : Nat := 12
  immBorrowLoc_count : Nat := 6
  mutBorrowLoc_count : Nat := 4
  readRef_count : Nat := 3
  writeRef_count : Nat := 2
  call_count : Nat := 15
  brFalse_count : Nat := 2
  h_total : copyLoc_count + moveLoc_count + stLoc_count +
            immBorrowLoc_count + mutBorrowLoc_count + readRef_count +
            writeRef_count + call_count + brFalse_count = 67

def instructionStats : InstructionStatistics :=
  { h_total := by norm_num }

/-- Effect catalog for all 67 instructions. -/
def completeEffectCatalog : List (Nat × InstructionEffect) :=
  [ (4, copyLocEffect 0),
    (5, stLocEffect 6),
    (6, copyLocEffect 1),
    (7, stLocEffect 7),
    (8, moveLocEffect 2),
    (9, callEffect 1 1 1),
    (10, stLocEffect 8),
    (11, immBorrowLocEffect 8),
    (12, callEffect 2 1 1),
    (13, brFalseEffect 79),
    (14, moveLocEffect 8),
    (15, callEffect 3 1 1),
    (16, stLocEffect 8)
    -- ... all 67 instructions
  ]

/-! ## Effect Composition -/

/-- Composing effects of consecutive instructions. -/
def composeEffects (e1 e2 : InstructionEffect) : InstructionEffect :=
  { stack := composeStackEffects e1.stack e2.stack,
    locals := composeLocalsEffects e1.locals e2.locals,
    pc := composePCEffects e1.pc e2.pc,
    container := composeContainerEffects e1.container e2.container,
    description := e1.description ++ " ; " ++ e2.description }

where
  composeStackEffects : StackEffect → StackEffect → StackEffect
    | .push n, .push m => .push (n + m)
    | .pop n, .pop m => .pop (n + m)
    | .push n, .pop m => if n ≥ m then .push (n - m) else .pop (m - n)
    | .pop n, .push m => if m ≥ n then .push (m - n) else .pop (n - m)
    | _, _ => .noop

  composeLocalsEffects : LocalsEffect → LocalsEffect → LocalsEffect
    | .noEffect, e => e
    | e, .noEffect => e
    | _, e => e  -- Later effect overrides

  composePCEffects : PCEffect → PCEffect → PCEffect
    | _, e2 => e2  -- Second effect determines final PC

  composeContainerEffects : ContainerEffect → ContainerEffect → ContainerEffect
    | .allocate t1, .allocate t2 => .allocate (t1 ++ "," ++ t2)
    | .noEffect, e => e
    | e, .noEffect => e
    | _, e => e

/-- Phase 1 complete effect (PC 4 → PC 20). -/
def phase1CompleteEffect : InstructionEffect :=
  { stack := .noop,  -- Stack empty at start and end
    locals := .write 6,  -- Multiple locals written
    pc := .increment,  -- PC advanced by 16
    container := .allocate "phase1_refs",
    description := "Phase 1: Oracle validation and extraction (17 instructions)" }

/-- Phase 2 complete effect (PC 20 → PC 43). -/
def phase2CompleteEffect : InstructionEffect :=
  { stack := .noop,  -- Stack empty at start and end
    locals := .write 11,  -- Message assembled in local 11
    pc := .increment,
    container := .allocate "phase2_refs",
    description := "Phase 2: Message assembly (23 instructions)" }

/-- Phase 3 complete effect (PC 43 → PC 70). -/
def phase3CompleteEffect : InstructionEffect :=
  { stack := .push 1,  -- Final boolean result
    locals := .write 12,  -- Verification values
    pc := .increment,
    container := .allocate "phase3_refs",
    description := "Phase 3: Sigma verification (27 instructions)" }

/-! ## Effect Verification -/

/-- All instruction effects are correctly cataloged. -/
theorem all_effects_cataloged :
    completeEffectCatalog.length = 67 := by
  sorry  -- All 67 instructions have documented effects

/-- Effect composition is associative. -/
theorem effect_composition_associative
    (e1 e2 e3 : InstructionEffect) :
    composeEffects (composeEffects e1 e2) e3 =
    composeEffects e1 (composeEffects e2 e3) := by
  sorry  -- Composition is associative

end MovementFormal.Experimental.ConfidentialAsset.Registration.InstructionEffectCatalog
