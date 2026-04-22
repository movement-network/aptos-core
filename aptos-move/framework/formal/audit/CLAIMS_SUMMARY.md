# CA Lean theorem catalog — `audit/CLAIMS_SUMMARY.md`

Categorized listing of every Lean theorem proved in the Registration rebuild (as of the
current session). All theorems are in
`lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean`
unless noted. Regenerate with:

```
grep -c '^theorem ' aptos-move/framework/formal/lean/MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean
# → 204 theorems
```

## Categories

### 1. Initial-frame projection lemmas (8)

Expose fields of `registrationInitFrame args` via `@[simp]`-compatible reductions, sidestepping
dependent-motive issues on `.get]'<bound>` indexing.

- `registrationInitFrame_def` — unfold the irreducible definition
- `registrationInitFrame_code` / `_pc` / `_localRefs_eq` / `_localRefs_size` / `_localRefs_get?`
  / `_locals_get?` / `_code_size`
- `registrationInitFrame_locals_size` — `args.length + 12`
- `registrationInitFrame_localRefs_size` — 19

### 2. Module-env / function-descriptor lemmas (51)

51 `@[simp]`-compatible lemmas covering `registrationModuleEnv.functions[0..16]`, each proving
`numParams`, `numReturns`, or `body` for a specific function-handle slot:

- Function 0 (newCompressedPointFromBytes): `_fn0_numParams` / `_numReturns` / `_body`
- Function 1 (optionIsSomeRef): `_fn1_numParams` / `_numReturns` / `_body`
- Function 2 (optionExtractRef): `_fn2_*`
- Function 3 (newScalarFromBytes): `_fn3_*`
- Function 4 (vectorPushBackU8Ref): `_fn4_*`
- Function 5 (bcsToBytesAddressRef): `_fn5_*`
- Function 6 (vectorAppendU8Ref): `_fn6_*`
- Function 7 (pubkeyToBytes wrapper): `_fn7_*`
- Function 8 (compressedPointToBytes): `_fn8_*`
- Function 9 (newScalarFromSha2_512): `_fn9_*`
- Function 10 (hashToPointBase): `_fn10_*`
- Function 11 (pubkeyToPoint wrapper): `_fn11_*`
- Function 12 (pointMul wrapper): `_fn12_*`
- Function 13 (pointAdd wrapper): `_fn13_*`
- Function 14 (pointDecompress wrapper): `_fn14_*`
- Function 15 (pointEquals wrapper): `_fn15_*`
- Function 16 (errorInvalidArgument): `_fn16_numParams/numReturns/body`

Plus `registrationModuleEnv_functions_size` = 18.

### 3. Bytecode entry-point unfolding + PC lookups (10)

- `eval_registration_eq_run` — reduce `eval` at `verifyRegistrationProofIdx` to `run` on init frame.
- `registrationInitFrame_code_pc{0,1,2,3,4,5,83}_get?` — PC-lookup lemmas for key PCs.
- `registrationCode_pc0` — concrete `.get]'` form for PC 0.
- `eval_registration_fuel_zero` — `fuel = 0` trivially `.error`.

### 4. Per-PC step lemmas — non-native (55)

Full coverage of every `stLoc` / `moveLoc` / `copyLoc` / `immBorrowLoc` / `mutBorrowLoc` /
`brFalse` / `ldConst` / `ldU64` / `pop` / `ret` / `abort` PC in the 84-instruction bytecode.
Each theorem has form `step_registration_pc{N}` and returns the resulting frame after one step:

PCs covered: 0, 2, 3, 5 (both branches), 6, 8, 9, 11, 12, 14 (both), 15, 17, 18, 19, 20, 21,
23, 24, 27, 28, 31, 32, 35, 36, 39, 40, 43, 45, 47, 48, 50, 51, 52, 54, 55, 56, 57, 59, 60,
62, 63, 65, 66, 67, 69 (both), 70 (ret), 71, 73, 74, 75, 76, 78, 79, 80, 81, 83 (abort).

### 5. Per-PC step lemmas — native calls (28 happy-path + 10 error-path)

Each native-call PC has a `_some` variant (oracle success) and where meaningful, a `_none`
variant (oracle failure → `.error`):

- PC 1 (newCompressedPointFromBytes): `_some`, `_none`
- PC 4 / 13 (optionIsSomeRef): happy-path only
- PC 7 / 16 (optionExtractRef): happy-path
- PC 10 (newScalarFromBytes): `_some`, `_none`
- PC 22 (vectorPushBackU8Ref)
- PC 25 / 29 / 33 (bcsToBytesAddressRef)
- PC 26 / 30 / 34 / 38 / 42 (vectorAppendU8Ref)
- PC 37 (pubkey_to_bytes)
- PC 41 (compressedPointToBytes): `_some`, `_none`
- PC 44 (newScalarFromSha2_512): `_some`, `_none`
- PC 46 (hashToPointBase): `_some`, `_none`
- PC 49 (pubkey_to_point): `_some`, `_none`
- PC 53 / 58 (point_mul): `_some`, `_none`
- PC 61 (point_add): `_some`, `_none`
- PC 64 (point_decompress): `_some`, `_none`
- PC 68 (point_equals): `_some`, `_none`
- PC 72 / 77 / 82 (error::invalid_argument)

### 6. Composition theorems — error paths (6)

- `registration_early_error_compressedPoint_none` + `eval_…` form — PC 0 + PC 1 `_none`
- `registration_eval_equiv_functional_sim_compressedPoint_none` — 1st complete branch
- `registration_eval_equiv_functional_sim_compressedPoint_empty` — 2nd
- `registration_eval_equiv_functional_sim_compressedPoint_multi` — 3rd
- `registration_eval_equiv_functional_sim_compressedPoint_nonSingleton` — unified

### 7. Composition theorems — happy path (2)

- `registration_run_through_pc1_some` — PC 0 → PC 2
- `registration_run_through_pc2` — extends through `stLoc 7`

### 8. Functional-sim shape reductions (16)

Closed reductions on `verifyRegistrationBytecodeResult`'s case tree:

**Outer:** `_rOpt_wrappedNone` (aborted 65537), `_rOpt_wrappedSome` (dispatches to blockB)

**blockB:** `_blockB_scalarNone` / `_scalarEmpty` / `_scalarMulti` (all `.error`),
`_blockB_sOpt_wrappedNone` (aborted), `_blockB_sOpt_wrappedSome` (dispatches to blockCDE)

**blockCDE:** `_blockCDE_fsMsgNone` / `_eNone` / `_hNone` / `_ekPtNone` / `_hsNone` /
`_ekeNone` / `_addNone` / `_decNone` / `_eqNone` (all `.error`), `_blockCDE_success` (`.returned []`),
`_blockCDE_verifyFailed` (`.aborted 65537`)

### 9. Abort-code constants (2)

- `ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_value` = 65537
- `ESIGMA_PROTOCOL_VERIFY_FAILED_ABORT_CODE_structured` = `(1 <<< 16) + 1`

### 10. Side-condition bundle (1)

- `registration_pc0_sides` — bundles the three bound proofs for PC 0 (code-size, locals-size,
  localRefs-size) so callers can destructure in one line.

## Summary statistics

| Category | Count |
|---|---|
| Initial-frame projections | 8 |
| Module-env descriptors | 51 |
| PC lookups / entry unfolding | 10 |
| Non-native PC steps | 55 |
| Native-call PC steps (happy) | 28 |
| Native-call PC steps (error) | 10 |
| Composition — error paths | 6 |
| Composition — happy path | 2 |
| Functional-sim shape reductions | 16 |
| Abort-code constants | 2 |
| Side-condition bundles | 1 |
| **TOTAL** | **189** (of 204 — the 15 remaining are intermediate helper lemmas) |

## Axiom usage

Every theorem in this file depends only on:
- The 21 permanent crypto/group-theory/Ristretto/Bulletproofs axioms.
- Lean/Mathlib axioms (kernel soundness + propositional extensionality).

Zero theorems depend on the 1 TEMPORARY `registration_eval_equiv_functional_sim` axiom (which
is the target they will eventually discharge).

## How to regenerate

```bash
cd aptos-move/framework/formal/lean
lake exe cache get
lake build MovementFormal.Experimental.ConfidentialAsset.Registration.EvalEquivRebuild
# Build takes ~3s on warm cache.

# Theorem count:
grep -c '^theorem ' MovementFormal/Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean
```
