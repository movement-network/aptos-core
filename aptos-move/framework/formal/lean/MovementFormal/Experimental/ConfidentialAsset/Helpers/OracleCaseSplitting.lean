import MovementFormal.MoveModel.State
import MovementFormal.MoveModel.Value

/-!
# Oracle Case-Splitting Helpers

Systematic case-splitting for oracle return values.

Crypto verifier oracles return `Option (List MoveValue × ContainerStore)`.
The main theorems need to split on all possible outcomes.

This file provides inductive types and axioms for exhaustive case splits.
-/

namespace MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleCaseSplitting

open MovementFormal.MoveModel

/-! ## Single oracle outcomes -/

/-- Exhaustive cases for a single oracle result. -/
inductive OracleOutcome where
  | failure : OracleOutcome
  | success (cs : ContainerStore) : OracleOutcome
  | wrongArity (results : List MoveValue) (cs : ContainerStore) : OracleOutcome

/-! ## Dual oracle outcomes (Normalization, Rotation, Withdrawal) -/

/-- All possible outcomes for dual-oracle verifiers (sigma + range). -/
inductive DualOracleOutcome where
  | sigmaFailure : DualOracleOutcome
  | sigmaWrongArity (sigma_results : List MoveValue) (cs : ContainerStore) : DualOracleOutcome
  | rangeFailure (cs_after_sigma : ContainerStore) : DualOracleOutcome
  | rangeWrongArity (cs_after_sigma : ContainerStore) (range_results : List MoveValue) (cs : ContainerStore) : DualOracleOutcome
  | success (cs_after_sigma cs_final : ContainerStore) : DualOracleOutcome

/-! ## Triple oracle outcomes (Transfer) -/

/-- All possible outcomes for triple-oracle verifier (sigma + new_balance + transfer). -/
inductive TripleOracleOutcome where
  | sigmaFailure : TripleOracleOutcome
  | sigmaWrongArity (sigma_results : List MoveValue) (cs : ContainerStore) : TripleOracleOutcome
  | newBalanceFailure (cs_after_sigma : ContainerStore) : TripleOracleOutcome
  | newBalanceWrongArity (cs_after_sigma : ContainerStore) (results : List MoveValue) (cs : ContainerStore) : TripleOracleOutcome
  | transferFailure (cs_after_sigma cs_after_new_balance : ContainerStore) : TripleOracleOutcome
  | transferWrongArity (cs_after_sigma cs_after_new_balance : ContainerStore) (results : List MoveValue) (cs : ContainerStore) : TripleOracleOutcome
  | success (cs_after_sigma cs_after_new_balance cs_final : ContainerStore) : TripleOracleOutcome

/-! ## Classification exhaustiveness axioms -/

axiom dual_oracle_cases
    (sigma_result : Option (List MoveValue × ContainerStore))
    (range_result : Option (List MoveValue × ContainerStore)) :
    -- Case 1: Sigma fails
    sigma_result = none ∨
    -- Case 2: Sigma wrong arity
    (∃ hd tl cs, sigma_result = some (hd :: tl, cs)) ∨
    -- Case 3: Sigma succeeds, range fails
    (∃ cs1, sigma_result = some ([], cs1) ∧ range_result = none) ∨
    -- Case 4: Sigma succeeds, range wrong arity
    (∃ cs1 hd tl cs2, sigma_result = some ([], cs1) ∧ range_result = some (hd :: tl, cs2)) ∨
    -- Case 5: Both succeed (happy path)
    (∃ cs1 cs2, sigma_result = some ([], cs1) ∧ range_result = some ([], cs2))

axiom triple_oracle_cases
    (sigma_result : Option (List MoveValue × ContainerStore))
    (new_balance_result : Option (List MoveValue × ContainerStore))
    (transfer_result : Option (List MoveValue × ContainerStore)) :
    -- All 15 possible combinations for triple oracle
    sigma_result = none ∨
    (∃ results cs, sigma_result = some (results, cs) ∧ results ≠ []) ∨
    (∃ cs1, sigma_result = some ([], cs1) ∧ new_balance_result = none) ∨
    (∃ cs1 results cs2, sigma_result = some ([], cs1) ∧ new_balance_result = some (results, cs2) ∧ results ≠ []) ∨
    (∃ cs1 cs2, sigma_result = some ([], cs1) ∧ new_balance_result = some ([], cs2) ∧ transfer_result = none) ∨
    (∃ cs1 cs2 results cs3, sigma_result = some ([], cs1) ∧ new_balance_result = some ([], cs2) ∧
      transfer_result = some (results, cs3) ∧ results ≠ []) ∨
    (∃ cs1 cs2 cs3, sigma_result = some ([], cs1) ∧ new_balance_result = some ([], cs2) ∧
      transfer_result = some ([], cs3))

end MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleCaseSplitting
