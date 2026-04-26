import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.MoveLocChains
import MovementFormal.MoveModel.StepLemmas.CopyLocChains

/-!
# Argument Marshaling Helpers for Crypto Verifiers (deprecated stub)

This file previously held six per-verifier `axiom` declarations modelling the moveLoc/copyLoc
argument-marshaling sequences at the start of each crypto verifier (Normalization,
Rotation, Withdrawal, Transfer). None of those axioms were ever referenced in proofs
(only mentioned in comments inside `ConcreteHelpers.lean` files).

The file is kept as an empty stub (with the same imports it always exported) to preserve
the import edges from the eight files that import it; the body is intentionally vacuous so
the 6-axiom liability is removed from `audit/AXIOM_INVENTORY.md`.

Verifier patterns (still documented for context):
- **Registration** (11 args): PCs 0-10 are moveLoc
- **Normalization** (7 args): PCs 0-4 moveLoc, PCs 5-6 copyLoc
- **Rotation** (6 args): PCs 0-5 moveLoc, PCs 6-7 copyLoc
- **Withdrawal** (6 args): PCs 0-5 moveLoc, PCs 6-7 copyLoc, PC 8 immBorrowField
- **Transfer** (13 args): PCs 0-13 moveLoc
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling

end MovementFormal.Experimental.ConfidentialAsset.Helpers.ArgumentMarshaling
