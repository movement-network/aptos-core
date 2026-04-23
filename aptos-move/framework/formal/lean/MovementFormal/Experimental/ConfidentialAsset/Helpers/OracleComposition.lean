import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.NativeCallPatterns

/-!
# Oracle Composition Helpers

Concrete helpers for composing oracle calls in crypto verifiers.

Each verifier calls one or more crypto oracles (sigma protocol verifier,
Bulletproofs range proof verifier) and must handle success/failure cases.

This file provides composition patterns for:
- Dual-oracle pattern (Normalization, Rotation, Withdrawal)
- Triple-oracle pattern (Transfer)
- Error cascading when oracles fail
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

open MovementFormal.MoveModel
open MovementFormal.MoveModel.StepLemmas.NativeCallPatterns

variable {env : ModuleEnv}

/-! ## Normalization oracle composition -/

/-- Normalization calls two oracles in sequence:
1. verifySigmaProof at PC 8 (7 args)
2. verifyRangeProof at PC 12 (2 args)

Both must return `some ([], cs')` for verification to succeed.
-/
axiom normalization_dual_oracle_success
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args : List MoveValue)
    (range_args : List MoveValue)
    (verifySigmaProof verifyRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_range : ContainerStore)
    (fuel : Nat)
    (hsigma_args : sigma_args.length = 7)
    (hrange_args : range_args.length = 2)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hrange_ok : verifyRangeProof cs_after_sigma range_args = some ([], cs_after_range))
    (hfuel : fuel ≥ 14) :
    ∃ (pc_final : Nat) (stack_final : List MoveValue),
    pc_final = 14 ∧
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_final }
      cs_frames
      stack_final
      { ms with containers := cs_after_range }
      (fuel - 14)

/-- Normalization sigma oracle fails → entire verification fails. -/
axiom normalization_sigma_fails
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args : List MoveValue)
    (verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (fuel : Nat)
    (hsigma_args : sigma_args.length = 7)
    (hsigma_fail : verifySigmaProof ms.containers sigma_args = none)
    (hfuel : fuel ≥ 9) :
    run env frame cs_frames [] ms fuel = .error

/-- Normalization range oracle fails (sigma succeeded) → verification fails. -/
axiom normalization_range_fails
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args range_args : List MoveValue)
    (verifySigmaProof verifyRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma : ContainerStore)
    (fuel : Nat)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hrange_fail : verifyRangeProof cs_after_sigma range_args = none)
    (hfuel : fuel ≥ 13) :
    run env frame cs_frames [] ms fuel = .error

/-! ## Rotation oracle composition -/

/-- Rotation also uses dual-oracle pattern (sigma + range).

Structure is similar to Normalization but with different PC offsets
and argument counts.
-/
axiom rotation_dual_oracle_success
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args : List MoveValue)
    (range_args : List MoveValue)
    (verifySigmaProof verifyRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_range : ContainerStore)
    (fuel : Nat)
    (hsigma_args : sigma_args.length = 7)
    (hrange_args : range_args.length = 2)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hrange_ok : verifyRangeProof cs_after_sigma range_args = some ([], cs_after_range))
    (hfuel : fuel ≥ 15) :
    ∃ (pc_final : Nat) (stack_final : List MoveValue),
    pc_final = 15 ∧
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_final }
      cs_frames
      stack_final
      { ms with containers := cs_after_range }
      (fuel - 15)

/-! ## Transfer triple-oracle composition -/

/-- Transfer calls three oracles in sequence:
1. verifySigmaProof at PC 14 (7 args)
2. verifyNewBalanceRangeProof at PC 18 (2 args)
3. verifyTransferRangeProof at PC 22 (2 args)

All three must succeed for transfer to pass.
-/
axiom transfer_triple_oracle_success
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args new_balance_args transfer_args : List MoveValue)
    (verifySigmaProof verifyNewBalanceRangeProof verifyTransferRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_new_balance cs_after_transfer : ContainerStore)
    (fuel : Nat)
    (hsigma_args : sigma_args.length = 7)
    (hnew_balance_args : new_balance_args.length = 2)
    (htransfer_args : transfer_args.length = 2)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hnew_balance_ok : verifyNewBalanceRangeProof cs_after_sigma new_balance_args = some ([], cs_after_new_balance))
    (htransfer_ok : verifyTransferRangeProof cs_after_new_balance transfer_args = some ([], cs_after_transfer))
    (hfuel : fuel ≥ 24) :
    ∃ (pc_final : Nat) (stack_final : List MoveValue),
    pc_final = 24 ∧
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_final }
      cs_frames
      stack_final
      { ms with containers := cs_after_transfer }
      (fuel - 24)

/-- Transfer first oracle (sigma) fails. -/
axiom transfer_sigma_fails
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args : List MoveValue)
    (verifySigmaProof : ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (fuel : Nat)
    (hsigma_fail : verifySigmaProof ms.containers sigma_args = none)
    (hfuel : fuel ≥ 15) :
    run env frame cs_frames [] ms fuel = .error

/-- Transfer second oracle (new balance range) fails. -/
axiom transfer_new_balance_fails
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args new_balance_args : List MoveValue)
    (verifySigmaProof verifyNewBalanceRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma : ContainerStore)
    (fuel : Nat)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hnew_balance_fail : verifyNewBalanceRangeProof cs_after_sigma new_balance_args = none)
    (hfuel : fuel ≥ 19) :
    run env frame cs_frames [] ms fuel = .error

/-- Transfer third oracle (transfer range) fails. -/
axiom transfer_transfer_range_fails
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args new_balance_args transfer_args : List MoveValue)
    (verifySigmaProof verifyNewBalanceRangeProof verifyTransferRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_new_balance : ContainerStore)
    (fuel : Nat)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hnew_balance_ok : verifyNewBalanceRangeProof cs_after_sigma new_balance_args = some ([], cs_after_new_balance))
    (htransfer_fail : verifyTransferRangeProof cs_after_new_balance transfer_args = none)
    (hfuel : fuel ≥ 23) :
    run env frame cs_frames [] ms fuel = .error

/-! ## Withdrawal dual-oracle composition -/

/-- Withdrawal follows the same dual-oracle pattern as Normalization/Rotation.

Oracles:
1. verifySigmaProof at PC 9 (7 args)
2. verifyRangeProof at PC 13 (2 args)
-/
axiom withdrawal_dual_oracle_success
    (frame : Frame) (cs_frames : List Frame) (ms : MachineState)
    (sigma_args range_args : List MoveValue)
    (verifySigmaProof verifyRangeProof :
      ContainerStore → List MoveValue → Option (List MoveValue × ContainerStore))
    (cs_after_sigma cs_after_range : ContainerStore)
    (fuel : Nat)
    (hsigma_args : sigma_args.length = 7)
    (hrange_args : range_args.length = 2)
    (hsigma_ok : verifySigmaProof ms.containers sigma_args = some ([], cs_after_sigma))
    (hrange_ok : verifyRangeProof cs_after_sigma range_args = some ([], cs_after_range))
    (hfuel : fuel ≥ 15) :
    ∃ (pc_final : Nat) (stack_final : List MoveValue),
    pc_final = 15 ∧
    run env frame cs_frames [] ms fuel =
    run env
      { frame with pc := pc_final }
      cs_frames
      stack_final
      { ms with containers := cs_after_range }
      (fuel - 15)

end MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition
