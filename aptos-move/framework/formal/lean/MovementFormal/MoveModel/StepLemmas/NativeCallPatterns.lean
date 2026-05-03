import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.Basic
import MovementFormal.MoveModel.StepLemmas.Calls

/-!
# Native Call Patterns

Helper theorems for common native function call patterns in crypto verifiers.

Native calls in verification functions follow a standard pattern:
1. Marshal arguments onto stack (moveLoc/copyLoc sequence)
2. Execute call instruction (pops args, pushes results via oracle)
3. Handle return values or errors

This file provides composition helpers for these patterns.
-/

namespace MovementFormal.MoveModel.StepLemmas.NativeCallPatterns

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas

variable {env : ModuleEnv}

/-! ## Basic native call structure -/

/-- Single native call with N args, empty return.

Common pattern in verification: call returns `some ([], cs')` on success.
-/
axiom native_call_empty_return
    (frame : Frame) (cs_frames : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n fnIdx : Nat)
    (args : List MoveValue)
    (numParams : Nat)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_result : ContainerStore)
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .call fnIdx)
    (hpc : frame.pc = n)
    (hstack : stack = args.reverse ++ stack.drop numParams)
    (hargs_len : args.length = numParams)
    (hfn_idx : fnIdx < env.functions.size)
    (hfn_body : env.functions[fnIdx].body = .nativeRef oracle)
    (hfn_params : env.functions[fnIdx].numParams = numParams)
    (hfn_returns : env.functions[fnIdx].numReturns = 0)
    (horacle_ok : oracle ms.containers args = some ([], cs_result)) :
    run env frame cs_frames stack ms (fuel + 1) =
    run env
      { frame with pc := n + 1 }
      cs_frames
      (stack.drop numParams)
      { ms with containers := cs_result }
      fuel

/-- Native call that returns error (oracle returns none).

On oracle failure, step produces .error which propagates through run.
-/
axiom native_call_oracle_fail
    (frame : Frame) (cs_frames : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n fnIdx : Nat)
    (args : List MoveValue)
    (numParams : Nat)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (fuel : Nat)
    (hn_lt : n < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .call fnIdx)
    (hpc : frame.pc = n)
    (hstack : stack = args.reverse ++ stack.drop numParams)
    (hargs_len : args.length = numParams)
    (hfn_idx : fnIdx < env.functions.size)
    (hfn_body : env.functions[fnIdx].body = .nativeRef oracle)
    (hfn_params : env.functions[fnIdx].numParams = numParams)
    (horacle_fail : oracle ms.containers args = none) :
    run env frame cs_frames stack ms (fuel + 1) = .error

/-! ## Dual-oracle verifier pattern -/

/-- Common verifier pattern: sigma oracle followed by range oracle.

Example from Normalization/Rotation/Withdrawal:
- First oracle (sigma verifier): takes 7 args, returns empty on success
- Second oracle (range verifier): takes 2 args, returns empty on success

Both must succeed for overall verification to pass.
-/
axiom dual_oracle_pattern
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (pc_sigma pc_range : Nat)
    (sigma_args range_args : List MoveValue)
    (sigma_oracle range_oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_range : ContainerStore)
    (fuel : Nat)
    -- Sigma oracle at pc_sigma
    (hsigma_bound : pc_sigma < frame.code.size)
    (hsigma_call : frame.code[pc_sigma]'hsigma_bound = .call 0)
    (hsigma_pc : frame.pc = pc_sigma)
    (hsigma_ok : sigma_oracle ms.containers sigma_args = some ([], cs_after_sigma))
    -- Range oracle at pc_range (after sigma succeeds)
    (hrange_bound : pc_range < frame.code.size)
    (hrange_call : frame.code[pc_range]'hrange_bound = .call 1)
    (hrange_ok : range_oracle cs_after_sigma range_args = some ([], cs_after_range))
    -- Spacing between calls
    (hpc_order : pc_sigma < pc_range)
    (hfuel : fuel ≥ pc_range - pc_sigma + 2) :
    ∃ (_intermediate_states : List (Frame × List Frame × List MoveValue × MachineState)),
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_range + 1 }
      cs_frames
      []
      { ms with containers := cs_after_range }
      (fuel - (pc_range - pc_sigma + 2))

/-! ## Triple-oracle verifier pattern (Transfer) -/

/-- Transfer uses three oracles in sequence.

Pattern:
- Sigma verifier (7 args)
- New balance range verifier (2 args)
- Transfer range verifier (2 args)

All three must succeed for transfer to pass.
-/
axiom triple_oracle_pattern
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (pc_sigma pc_new_balance pc_transfer : Nat)
    (sigma_args new_balance_args transfer_args : List MoveValue)
    (sigma_oracle new_balance_oracle transfer_oracle :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_new_balance cs_after_transfer : ContainerStore)
    (fuel : Nat)
    -- All three oracles succeed
    (hsigma_ok : sigma_oracle ms.containers sigma_args = some ([], cs_after_sigma))
    (hnew_balance_ok : new_balance_oracle cs_after_sigma new_balance_args = some ([], cs_after_new_balance))
    (htransfer_ok : transfer_oracle cs_after_new_balance transfer_args = some ([], cs_after_transfer))
    -- PC ordering
    (horder1 : pc_sigma < pc_new_balance)
    (horder2 : pc_new_balance < pc_transfer)
    (hfuel : fuel ≥ pc_transfer - pc_sigma + 3) :
    ∃ (_states : List (Frame × List Frame × List MoveValue × MachineState)),
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_transfer + 1 }
      cs_frames
      []
      { ms with containers := cs_after_transfer }
      (fuel - (pc_transfer - pc_sigma + 3))

/-! ## Oracle error cascading -/

/-- If first oracle in a dual-oracle pattern fails, entire verification fails.

No need to check second oracle - error propagates immediately.
-/
axiom dual_oracle_first_fails
    (frame : Frame) (cs_frames : List Frame) (stack : List MoveValue) (ms : MachineState)
    (pc_sigma : Nat)
    (sigma_args : List MoveValue)
    (sigma_oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (fuel : Nat)
    (hsigma_bound : pc_sigma < frame.code.size)
    (hsigma_call : frame.code[pc_sigma]'hsigma_bound = .call 0)
    (hsigma_pc : frame.pc = pc_sigma)
    (hsigma_fail : sigma_oracle ms.containers sigma_args = none) :
    run env frame cs_frames stack ms fuel = .error

/-- If second oracle in a dual-oracle pattern fails (first succeeded), verification fails. -/
axiom dual_oracle_second_fails
    (frame : Frame) (cs_frames : List Frame) (stack : List MoveValue) (ms : MachineState)
    (pc_sigma pc_range : Nat)
    (sigma_args range_args : List MoveValue)
    (sigma_oracle range_oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma : ContainerStore)
    (fuel : Nat)
    -- First oracle succeeds
    (hsigma_ok : sigma_oracle ms.containers sigma_args = some ([], cs_after_sigma))
    -- Second oracle fails
    (hrange_fail : range_oracle cs_after_sigma range_args = none)
    (hpc_order : pc_sigma < pc_range)
    (hfuel : fuel ≥ pc_range - pc_sigma + 2) :
    run env frame cs_frames stack ms fuel = .error

/-! ## Return value handling -/

/-- After successful empty-return oracle, PC advances and stack is cleared of args. -/
axiom native_call_advances_pc
    (frame : Frame) (cs_frames : List Frame) (stack : List MoveValue) (ms : MachineState)
    (n fnIdx : Nat)
    (args rest : List MoveValue)
    (numParams : Nat)
    (oracle : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_result : ContainerStore)
    (hn_lt : n < frame.code.size)
    (hcode : frame.code[n]'hn_lt = .call fnIdx)
    (hpc : frame.pc = n)
    (hstack : stack = args.reverse ++ rest)
    (hargs_len : args.length = numParams)
    (hfn_idx : fnIdx < env.functions.size)
    (hfn_body : env.functions[fnIdx].body = .nativeRef oracle)
    (hfn_params : env.functions[fnIdx].numParams = numParams)
    (hfn_returns : env.functions[fnIdx].numReturns = 0)
    (horacle_ok : oracle ms.containers args = some ([], cs_result)) :
    step env frame cs_frames stack ms = .ok
      { frame with pc := n + 1 }
      cs_frames
      rest
      { ms with containers := cs_result }

end MovementFormal.MoveModel.StepLemmas.NativeCallPatterns
