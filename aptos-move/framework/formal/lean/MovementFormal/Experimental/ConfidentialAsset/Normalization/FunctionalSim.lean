import MovementFormal.MoveModel.Step

/-!
# Functional simulation of `verify_normalization_proof` bytecode — Phase 4 scaffold

Normalization proves that a new balance's chunks all fit in 16 bits (a range proof) and that
the new balance decrypts to the same plaintext as the old balance (sigma equality). Phase 4
scaffold mirroring `Withdrawal/FunctionalSim.lean`. -/

namespace MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim

open MovementFormal.MoveModel

structure NormalizationNativeOracle where
  newScalarFromBytes : List MoveValue → Option (List MoveValue)
  newCompressedPointFromBytes : List MoveValue → Option (List MoveValue)
  newScalarFromSha2_512 : List MoveValue → Option (List MoveValue)
  compressedPointToBytes : List MoveValue → Option (List MoveValue)
  hashToPointBase : List MoveValue → Option (List MoveValue)
  pointDecompress : List MoveValue → Option (List MoveValue)
  pointMul : List MoveValue → Option (List MoveValue)
  pointAdd : List MoveValue → Option (List MoveValue)
  pointSub : List MoveValue → Option (List MoveValue)
  pointEquals : List MoveValue → Option (List MoveValue)
  multiScalarMul : List MoveValue → Option (List MoveValue)
  pubkeyToBytes : List MoveValue → Option (List MoveValue)
  pubkeyToPoint : List MoveValue → Option (List MoveValue)
  verifyBatchRangeProof : List MoveValue → Option (List MoveValue)

def verifyNormalizationBytecodeResult (_o : NormalizationNativeOracle) (_args : List MoveValue)
    : ExecResult :=
  .error

@[simp] theorem verifyNormalizationBytecodeResult_stub_is_error
    (o : NormalizationNativeOracle) (args : List MoveValue) :
    verifyNormalizationBytecodeResult o args = .error := rfl

end MovementFormal.Experimental.ConfidentialAsset.Normalization.FunctionalSim
