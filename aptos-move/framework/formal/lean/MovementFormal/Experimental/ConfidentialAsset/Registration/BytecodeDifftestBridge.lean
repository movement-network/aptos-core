import MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval
import MovementFormal.MoveModel.Programs.RegistrationDifftestOracle
import MovementFormal.Experimental.ConfidentialAsset.Registration.Operational

/-!
# L2 → L1 → L0 concrete refinement chain for the difftest roundtrip trace

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; difftest `aptos-move/framework/formal/difftest/`.

Imports the `native_decide` eval proof from `BytecodeDifftestEval` (light imports:
`Step`, `Programs.Registration`, `FunctionalSim`, `ExecResultDropMs` — not the full
`EvalEquiv` module) and connects it to the
L1 (`execVerifyRegistrationProof`) and L0 (`verifyRegistrationProofProp`) layers.

For this specific trace (dk=42, k=9999), all three layers agree:
- **L2** (bytecode eval): `returned [] MachineState.empty`
- **L1** (Option Unit runner): `some ()`
- **L0** (mathematical prop): `True`
-/

set_option maxRecDepth 8192

namespace MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestBridge

open MovementFormal.MoveModel
open MovementFormal.MoveModel.Native.Registration
open MovementFormal.MoveModel.Programs.Registration
open MovementFormal.MoveModel.Programs.RegistrationDifftestOracle
open MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestEval
open MovementFormal.Experimental.ConfidentialAsset.Registration.Operational

/-! ## Re-export L2 eval result (reference-aware) -/

theorem eval_bytecode_success :
    isReturnedEmpty (eval difftestEnv verifyRegistrationProofIdx difftestArgs 200 difftestInitMs) = true :=
  eval_difftest_registration_roundtrip

/-! ## L1: Operational runner succeeds -/

theorem exec_operational_success :
    execVerifyRegistrationProof difftestRegistrationOracle
      difftestRegistrationRoundtripInputs difftestRegResponseBytes =
      some () :=
  difftest_registration_exec_ok

/-! ## L2 ∧ L1 concrete agreement -/

theorem difftest_L2_L1_agree :
    (isReturnedEmpty (eval difftestEnv verifyRegistrationProofIdx difftestArgs 200 difftestInitMs) = true) ∧
    (execVerifyRegistrationProof difftestRegistrationOracle
      difftestRegistrationRoundtripInputs difftestRegResponseBytes = some ()) :=
  ⟨eval_bytecode_success, exec_operational_success⟩

/-! ## Full L2 → L0 chain

The bytecode-level L2 proof now uses `isReturnedEmpty` with an `initMs` that has
the encryption key pre-allocated in the ContainerStore (matching how Move passes
`&TwistedElGamalPubkey` by immutable reference).

The L2→L0 connection requires the L2≡L1.5 bridge (eval_eq_func) which is pending
the FunctionalSim.lean rewrite. The L1→L0 direction is proven independently. -/

theorem difftest_L1_implies_L0 :
    RegistrationVerify.verifyRegistrationProofProp
      difftestRegistrationOracle.toCryptoOracle
      difftestRegistrationRoundtripInputs
      difftestRegResponseBytes :=
  (execVerifyRegistrationProof_iff
    difftestRegistrationOracle
    difftestRegistrationRoundtripInputs
    difftestRegResponseBytes).mp exec_operational_success

end MovementFormal.Experimental.ConfidentialAsset.Registration.BytecodeDifftestBridge
