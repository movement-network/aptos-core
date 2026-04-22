import MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv.Part4

/-!
# Bytecode eval ≡ functional simulation (L2 ≡ L1.5)

**Source:** `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`; bytecode `MovementFormal.MoveModel.Programs.Registration`.

Proof that the bytecode evaluator `eval` on the transcribed 83-instruction
`verify_registration_proof` (reference-semantic, from `movement` v7.4
compiler output) agrees with the functional simulation
`verifyRegistrationBytecodeResult` for any oracle — up to MachineState
(the container store is non-empty after execution but irrelevant to the
return values / abort code).

## MachineState note

The real bytecode uses `immBorrowLoc` / `mutBorrowLoc` / `nativeRef`
calls, so `eval` returns `.returned [] ms` where `ms` has a populated
`ContainerStore`. The functional sim returns `.returned [] MachineState.empty`.
We compare via `ExecResult.dropMs` which projects away the `MachineState`
(defined in `MovementFormal.MoveModel.ExecResultDropMs`).

**Fuel monotonicity** (`run_fuel_ge`, `eval_fuel_ge`, `eval_fuel_ge_dropMs`) lives in
`MovementFormal.Experimental.ConfidentialAsset.Registration.EvalFuelMonotonicity` for lightweight imports.

## Proof architecture

The proof uses `@[simp]` lemmas to normalize both sides to the same
match tree:

**Eval side:**
1. `run_succ_runStep` rewrites `run env frame cs stack ms (n+1)` →
   `runStep env (step env frame cs stack ms) n`
2. `step` unfolds to `handleNativeResult (impl args) numReturns ...`
   (or `nativeRef` dispatch for ref-aware functions)
3. `runStep_handleNativeResult_ret1` collapses to
   `match oracleResult with | some [v] => run env ... | _ => .error`

**Func side:**
4. `match_single?` rewrites `match (single? x) with | some v => f v | _ => g`
   to `match x with | some [v] => f v | _ => g`
5. `bind_single?` rewrites `single? x >>= f` to
   `match x with | some [v] => f v | _ => none`

**Bridging:**
6. `match_match_some_single_none` fuses
   `match (match x with | some [v] => f v | _ => none) with | some w => g w | none => h`
   into `match x with | some [v] => match f v with | some w => g w | none => h | _ => h`
   (needed for `buildFSMessageMv`'s `Option MoveValue` boundary in `blockCDE`)

After normalization, `simp`'s congruence closes matching branches.
Remaining abstract branch splits are handled by `split <;> simp`.

## Module split

The proof body is split across `Registration/EvalEquiv/Part1.lean` … `Part4.lean` (same
`MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquiv` namespace) so
`lake build` can compile them incrementally. Import this file for the full module.
-/
