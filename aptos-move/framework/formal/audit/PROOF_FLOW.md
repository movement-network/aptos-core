# CA Lean proof flow — `audit/PROOF_FLOW.md`

High-level diagram of the Registration verification proof, showing the L2 → L1.5 → L1 → L0
refinement layers and which Lean files own each step. Use this as a mental model when reading
the proof source.

## Layer stack

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  L0 — Mathematical sigma predicate                                           │
│  (point-arithmetic claim: s·H + e·ek = R)                                    │
│  File: SigmaVerifiers.lean                                                   │
│  Status: ✅ proved (standard Schnorr correctness)                            │
└──────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │  refinement via
                                       │  OracleCoherence + SchnorrCompleteness
                                       │
┌──────────────────────────────────────────────────────────────────────────────┐
│  L1 — Functional spec (execVerifyRegistrationProof)                          │
│  (readable Lean function on structured inputs)                               │
│  File: Formal.lean, Operational.lean                                          │
│  Status: ✅ proved                                                           │
└──────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │  refinement via
                                       │  func_success_implies_exec_some
                                       │  + transcript-alignment proofs
                                       │
┌──────────────────────────────────────────────────────────────────────────────┐
│  L1.5 — Bytecode functional simulation (verifyRegistrationBytecodeResult)    │
│  (matches L2 output shape but expressed as readable Lean func)               │
│  File: FunctionalSim.lean                                                    │
│  Status: ✅ defined + reduction lemmas for non-singleton cases               │
└──────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │  refinement via
                                       │  registration_eval_equiv_functional_sim
                                       │  (the top-level Phase 1 target)
                                       │
┌──────────────────────────────────────────────────────────────────────────────┐
│  L2 — Bytecode evaluator (eval on the transcribed 84-instruction program)   │
│  (Move VM semantics, tested byte-for-byte against the VM via difftest)       │
│  Files: EvalEquivRebuild.lean + Programs/Registration.lean + MoveModel/…     │
│  Status: 🟡 184 theorems proved; singleton branch pending                    │
└──────────────────────────────────────────────────────────────────────────────┘
                                       ▲
                                       │  byte-level equality via
                                       │  87-row CA difftest corpus
                                       │
┌──────────────────────────────────────────────────────────────────────────────┐
│  Move VM — Ground truth                                                      │
│  (Rust `aptos-vm` executing the compiled `.mv` bytecode)                     │
│  File: aptos-move/aptos-vm/ (production Rust implementation)                  │
│  Status: ✅ difftest corpus rows green                                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Per-phase proof entry points

### Phase 1 (Registration) — 🟡 in progress

```
 registration_eval_equiv_functional_sim   ← TOP-LEVEL TARGET (temporary axiom)
   │
   ├── compressedPoint_none case          ← ✅ proved
   ├── compressedPoint_empty case         ← ✅ proved
   ├── compressedPoint_multi case         ← ✅ proved
   ├── compressedPoint_nonSingleton case  ← ✅ unified, proved
   │
   └── singleton_some case                ← 🟡 remaining (SINGLETON_BRANCH_ROADMAP.md)
         │
         ├── rOpt = wrapped-None          ← threads PCs 0→5→79-83, returns .aborted 65537
         ├── rOpt = wrapped-Some(rComp)   ← threads PCs 0→14 via scalar-parse
         │     │
         │     ├── scalar-parse None      ← threads → PC 74-78 abort
         │     ├── scalar-parse Some(s)   ← threads PCs 15→68 (FS msg + MSM)
         │     │     │
         │     │     ├── point-equals None  ← returns .error
         │     │     ├── point-equals true  ← threads → PC 70 ret (SUCCESS)
         │     │     └── point-equals false ← threads → PC 71-73 abort
         │     └── (oracle-arity mismatch cases)
         └── (oracle-arity mismatch cases for optionIsSome / optionExtract)
```

### Phase 4 (other verifiers) — 🟡 scaffolded, proofs pending

Each of `Withdrawal` / `Transfer` / `Normalization` / `Rotation` mirrors the Registration
structure. Scaffolds landed:

- `Experimental/ConfidentialAsset/{Op}/FunctionalSim.lean` — `{Op}NativeOracle` + stub
  `verify{Op}BytecodeResult`.
- `Experimental/ConfidentialAsset/{Op}/EvalEquiv.lean` — placeholder pointing at the
  Registration template.
- `MoveModel/Programs/{Op}.lean` — empty bytecode array + module-env stub.

Follow [`BYTECODE_TRANSCRIPTION_GUIDE.md`](../BYTECODE_TRANSCRIPTION_GUIDE.md) to fill in
the `verify{Op}ProofCode` arrays; the rebuild pattern in `EvalEquivRebuild.lean` applies
mechanically after that.

## Composition into Phase 6 end-to-end claims

For each CA operation, the end-to-end claim (Phase 6) combines:

- **Move Prover** at L1.5 via MSL spec (store pre/post, abort conditions).
- **Lean** at L2 via the `verify_*_proof` theorem (bytecode ≡ sigma predicate).
- **Difftest** as the binding layer (L2 ≡ VM byte-for-byte).

See [`COMPOSITION_CLAIMS.md`](COMPOSITION_CLAIMS.md) for the per-operation status table.

## Key files in the Lean tree

| File | Role | Status |
|---|---|---|
| `MoveModel/Step.lean` | Small-step semantics + helpers | ✅ |
| `MoveModel/StepLemmas/{Basic,Locals,Refs,Arithmetic,Casts,Structs,Calls,Vectors,Globals,Run,Example}.lean` | Per-instruction-class step lemmas (Phase 0 lib) | ✅ |
| `MoveModel/Programs/Registration.lean` | Transcribed 84-instruction bytecode | ✅ |
| `MoveModel/Programs/{Withdrawal,Transfer,Normalization,Rotation}.lean` | Placeholder bytecodes | 🟡 stub |
| `Experimental/ConfidentialAsset/SigmaVerifiers.lean` | L0 sigma predicates | ✅ |
| `Experimental/ConfidentialAsset/Registration/FunctionalSim.lean` | L1.5 functional sim | ✅ |
| `Experimental/ConfidentialAsset/Registration/Formal.lean` / `Operational.lean` | L1 layer | ✅ |
| `Experimental/ConfidentialAsset/Registration/EvalEquivRebuild.lean` | L2 ≡ L1.5 equivalence (the current work) | 🟡 non-singleton closed |
| `Experimental/ConfidentialAsset/Registration/EvalEquiv.lean` | Axiom-stub re-exporting the top-level theorem | 🟡 |
| `Experimental/ConfidentialAsset/Registration/Refinement.lean` | L1.5 → L1 refinement | ✅ |
| `Experimental/ConfidentialAsset/Registration/EndToEnd.lean` | L0-to-L2 glue | ✅ |
| `Experimental/ConfidentialAsset/Registration/BytecodeDifftestBridge.lean` | L2 ≡ VM bridge | ✅ |
| `AptosStd/Crypto/{EdwardsCurve25519,Ristretto255,Bulletproofs,RistrettoEncoding}.lean` | Crypto axioms / lemmas | ✅ axioms (22 cataloged) |

All files build green with `lake build` (after `lake exe cache get`).
