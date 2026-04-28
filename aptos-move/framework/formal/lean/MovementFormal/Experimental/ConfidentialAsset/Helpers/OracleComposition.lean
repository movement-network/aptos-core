import MovementFormal.MoveModel.StepLemmas.Run
import MovementFormal.MoveModel.StepLemmas.NativeCallPatterns

/-!
# Oracle Composition Helpers (deprecated stub)

This file previously held nine `axiom` declarations modelling sigma + range / triple-oracle
composition for the four crypto verifiers (Normalization / Rotation / Withdrawal / Transfer).
None of those axioms were ever referenced — the per-verifier `ConcreteHelpers.lean` files
provide their own analogues that are used in the actual proofs.

The file is kept as an empty stub (with the same imports it always exported) to preserve the
import edges from the five files that import it; the body is intentionally vacuous so the
9-axiom liability is removed from `audit/AXIOM_INVENTORY.md`.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition

end MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleComposition
