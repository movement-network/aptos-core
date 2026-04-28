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

theorem dual_oracle_cases
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
    (∃ cs1 cs2, sigma_result = some ([], cs1) ∧ range_result = some ([], cs2)) := by
  cases sigma_result with
  | none => left; rfl
  | some sigma_pair =>
    cases sigma_pair with | mk sigma_list sigma_cs =>
    cases sigma_list with
    | nil =>
      -- sigma_result = some ([], sigma_cs)
      cases range_result with
      | none =>
        -- Case 3
        right; right; left
        exact ⟨sigma_cs, rfl, rfl⟩
      | some range_pair =>
        cases range_pair with | mk range_list range_cs =>
        cases range_list with
        | nil =>
          -- Case 5
          right; right; right; right
          exact ⟨sigma_cs, range_cs, rfl, rfl⟩
        | cons hd tl =>
          -- Case 4
          right; right; right; left
          exact ⟨sigma_cs, hd, tl, range_cs, rfl, rfl⟩
    | cons hd tl =>
      -- Case 2
      right; left
      exact ⟨hd, tl, sigma_cs, rfl⟩

theorem triple_oracle_cases
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
      transfer_result = some ([], cs3)) := by
  cases sigma_result with
  | none => left; rfl
  | some sigma_pair =>
    cases sigma_pair with | mk sigma_list sigma_cs =>
    cases sigma_list with
    | nil =>
      -- sigma succeeded with []
      cases new_balance_result with
      | none =>
        -- Case: sigma [], new_balance none
        right; right; left
        exact ⟨sigma_cs, rfl, rfl⟩
      | some nb_pair =>
        cases nb_pair with | mk nb_list nb_cs =>
        cases nb_list with
        | nil =>
          -- sigma [], new_balance []
          cases transfer_result with
          | none =>
            -- Case: all [], [], none
            right; right; right; right; left
            exact ⟨sigma_cs, nb_cs, rfl, rfl, rfl⟩
          | some tr_pair =>
            cases tr_pair with | mk tr_list tr_cs =>
            cases tr_list with
            | nil =>
              -- Case: all [], [], []
              right; right; right; right; right; right
              exact ⟨sigma_cs, nb_cs, tr_cs, rfl, rfl, rfl⟩
            | cons hd tl =>
              -- Case: sigma [], nb [], transfer non-empty
              right; right; right; right; right; left
              refine ⟨sigma_cs, nb_cs, (hd :: tl), tr_cs, rfl, rfl, rfl, ?_⟩
              intro h; cases h
        | cons hd tl =>
          -- Case: sigma [], new_balance non-empty
          right; right; right; left
          refine ⟨sigma_cs, (hd :: tl), nb_cs, rfl, rfl, ?_⟩
          intro h; cases h
    | cons hd tl =>
      -- Case: sigma non-empty
      right; left
      refine ⟨(hd :: tl), sigma_cs, rfl, ?_⟩
      intro h; cases h

end MovementFormal.Experimental.ConfidentialAsset.Helpers.OracleCaseSplitting
