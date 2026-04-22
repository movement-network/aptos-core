/-!
# Bytecode eval ≡ sigma-verifier predicate for `verify_withdrawal_proof` — Phase 4 scaffold

**Scope:** Phase 4 target per [`CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md`](../../../../../CONFIDENTIAL_ASSETS_UNIFIED_VERIFICATION_PLAN.md) §6.

This file will eventually prove that the `verify_withdrawal_proof` bytecode, when evaluated on the
honest oracle, accepts iff the mathematical sigma predicate in `SigmaVerifiers.lean` holds. The
rebuild follows the architecture described in plan §4 and the PC-by-PC scaffolding pattern
validated by `Registration/EvalEquivRebuild.lean`:

- `@[irreducible]` symbolic state for `withdrawal_verify`'s initial frame.
- Per-PC step-lemma dispatch from `MovementFormal.MoveModel.StepLemmas.*`.
- `Array.get?` in statements to sidestep dependent bound-proof motive issues.

**Prerequisites (not yet landed):**
- `MovementFormal.MoveModel.Programs.Withdrawal` — the withdrawal bytecode transcription.
- A `WithdrawalNativeOracle` structure analogous to `RegistrationNativeOracle`.
- A functional sim `verifyWithdrawalBytecodeResult : WithdrawalNativeOracle → List MoveValue → ExecResult`.

Until those land, this file is a placeholder — no declarations, no axioms. Once the
prerequisites land, copy the proof scaffolding from `Registration/EvalEquivRebuild.lean`
(`initFrame`, `_def`/`_code`/`_pc`/`_locals_size`/`_localRefs_*` projection lemmas,
`eval_…_eq_run` boundary, per-PC step lemmas) and substitute the withdrawal-specific names.
-/

-- Intentionally empty body — see module docstring above.
