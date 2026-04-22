# Singleton branch roadmap — closing `registration_eval_equiv_functional_sim`

The top-level `registration_eval_equiv_functional_sim` theorem has three oracle cases:

1. `newCompressedPointFromBytes [...] = none` — ✅ closed (`…_compressedPoint_none`).
2. `newCompressedPointFromBytes [...] = some []` or `some (_ :: _ :: _)` — ✅ closed (`…_compressedPoint_empty`, `…_compressedPoint_multi`, `…_compressedPoint_nonSingleton`).
3. `newCompressedPointFromBytes [...] = some [mv]` — 🟡 **remaining work.**

This doc enumerates the sub-cases of case 3 and the PC threading each one requires.

## Structure of the singleton branch

After the first oracle call (PC 1) succeeds with `some [mv]`, the bytecode continues:

```
PC 2:  stLoc 7              (store rOpt)
PC 3:  immBorrowLoc 7        (&rOpt)            ← container alloc (blocker)
PC 4:  call 1 (option::is_some)                 ← oracle case split
PC 5:  brFalse 79            (if !is_some, goto abort)
─── Case 3a: rOpt is Some
PC 6:  mutBorrowLoc 7        (&mut rOpt)
PC 7:  call 2 (option::extract)                 ← extracts rCompressed
PC 8:  stLoc 8               (store rCompressed)
PC 9:  moveLoc 6             (push respBytes)
PC 10: call 3 (newScalarFromBytes)              ← oracle case split
PC 11: stLoc 9               (store sOpt)
PC 12: immBorrowLoc 9
PC 13: call 1 (option::is_some)                 ← oracle case split
PC 14: brFalse 74            (if !is_some, goto abort)
─── Case 3a-i: sOpt is Some
PC 15: mutBorrowLoc 9
PC 16: call 2 (option::extract)                 ← extracts s
PC 17-43: Fiat-Shamir message assembly (load DST, append chainId, sender, contract, token, ek, r)
PC 44: call 9 (newScalarFromSha2_512)           ← computes challenge e
PC 45: stLoc 12
PC 46: call 10 (hashToPointBase)                ← oracle
PC 47: stLoc 13
PC 48: moveLoc 3             (push ek ref)
PC 49: call 11 (pubkey_to_point)                ← oracle
PC 50: stLoc 14
PC 51-53: point_mul(h, s) → $t41
PC 54:  stLoc 15
PC 55-58: point_mul(ek, e) → $t45
PC 59:  stLoc 16
PC 60-61: point_add($t41, $t45) → lhs
PC 62:  stLoc 17
PC 63-64: point_decompress(r_compressed) → rhs
PC 65:  stLoc 18
PC 66-68: point_equals(lhs, rhs)                ← oracle case split
PC 69:  brFalse 71           (if !equal, goto B4)
─── Case 3a-i-α: equal
PC 70:  ret                  ← SUCCESS
─── Case 3a-i-β: !equal
PC 71-73: abort with ESIGMA_PROTOCOL_VERIFY_FAILED
─── Case 3a-ii: sOpt is None
PC 74-78: abort with ESIGMA_PROTOCOL_VERIFY_FAILED
─── Case 3b: rOpt is None
PC 79-83: abort with ESIGMA_PROTOCOL_VERIFY_FAILED
```

## Oracle-case decomposition for the singleton branch

| Sub-case | Oracle outputs | Expected `eval` result | PC path |
|---|---|---|---|
| 3.0 | `newCompressedPointFromBytes = some [mv]` continues | — | PC 0→1 |
| 3.1 | `optionIsSome mv = some [.bool false]` (mv was wrapped None) | `.aborted ESIGMA_PROTOCOL_VERIFY_FAILED` (65537) | PC 0→5 then branch to PC 79→83 |
| 3.2 | `optionIsSome mv = some [.bool true]`, `optionExtract mv = some [rCompressed]`, `newScalarFromBytes = none` | `.error` (native returning none) | PC 0→10, then step errors |
| 3.3 | `newScalarFromBytes = some []` or `some (_ :: _ :: _)` | `.error` (arity mismatch) | PC 0→10 then error |
| 3.4 | `newScalarFromBytes = some [sOpt]`, `optionIsSome sOpt = some [.bool false]` | `.aborted 65537` via PC 74→78 abort | PC 0→14 then branch |
| 3.5 | all opts unwrap successfully, `point_equals = some [.bool false]` | `.aborted 65537` via PC 71→73 abort | PC 0→69 then branch |
| 3.6 | all opts unwrap, `point_equals = some [.bool true]` | `.returned [] ms` (success) | PC 0→70 (ret) |
| 3.* | any intermediate oracle returns `none` / wrong arity | `.error` | varies |

## Proof-engineering challenges

### A. Container-store mutation

PC 3 (`immBorrowLoc 7`) allocates a fresh container. Every subsequent `immBorrowLoc` /
`mutBorrowLoc` either reuses the existing `localRefs[idx]` or allocates a new one. The
composition must thread `containers'` through all the PCs from 3 onwards.

**Solutions:**
- Parameterize each subsequent composition lemma over the allocation result (messy — 20+ params).
- Use a single `@[irreducible]` "state after allocation" `let`-bound definition and only expose
  the observable stack + pc through projection lemmas.
- Bundle the container-state into an abstract `ContainerSnapshot` hypothesis that each PC
  lemma threads.

Recommend the third approach once the non-singleton branch closes.

### B. Native-call case splits for oracles

Each oracle with two or more outcomes (`point_equals`: true/false/none, `newScalarFromBytes`:
some/none) requires a case-split. The composition pattern:

```
case horacle : oracle_call_result with
| none => use the _none PC lemma + reach the error
| some [v] => continue composition with v threaded
| _ => use the _empty / _multi PC lemma + reach the error
```

### C. Fiat-Shamir message assembly (PCs 18-42)

25 PCs of pure bytecode with no oracle case-splits. Once the container-store threading is
solved, these 25 PCs are mechanically chainable via the existing step-lemmas. They define
the byte-level `buildFSMessageMv` result that the sigma check verifies.

The existing `FiatShamirSymbolic.lean` proves the Move VM FS-message matches the Fiat-Shamir
bytes used by `SigmaVerifiers.lean` — so this stretch of PCs can likely close via that
existing theorem once the PC-by-PC composition reaches PC 43 (`moveLoc 11`).

### D. Terminal PC 70 success path

The `ret` instruction on empty callStack returns `.returned [] ms`. After `.dropMs`, this
becomes `.returned [] MachineState.empty` — the expected final form.

The functional sim's `blockB` / `blockCDE` build to the same shape via the existing
`SchnorrCompleteness.lean` proofs once the sigma predicate's accept conditions are threaded.

## Recommended attack plan

1. **Fix the container-store threading once**: pick the bundled-snapshot approach, rewrite
   the PC-3 step with it, verify PC-2 → PC-3 composition.
2. Extend PC-3 composition through PC 4 (call 1 `optionIsSome`) with oracle case-split.
3. Extend through PC 5 (branch on bool) — both branches need compositions:
   - `_true` branch continues to PC 6.
   - `_false` branch jumps to PC 79, which is the `compressedPoint_false` sub-case 3.1.
4. Continue through PCs 6-16 using the same pattern. PC 10 and PC 13 are oracle case-splits
   similar to PC 4.
5. The Fiat-Shamir stretch (PCs 17-43) should close mechanically once container-store
   threading is solved.
6. PCs 44-68 are dense with oracle case-splits — each native-call PC requires a 3-branch
   case analysis (some/none/multi).
7. Final PC 69 case-split + PC 70 (ret) or PC 71-73 (abort) closes the branch.

Estimated LoC for the full singleton branch: 2000-3000 lines. ~130 PC-step applications
(but each is a one-line `rw` once framing is right).

## Alternative: structural reasoning

Instead of PC-by-PC threading, one could invoke the existing `SchnorrCompleteness.lean` +
`FiatShamirSymbolic.lean` results abstractly. This would require:

- A "bytecode oracle monad" abstraction that bundles the oracle calls in order.
- A theorem showing the `eval.dropMs` produces the same sigma-verification call sequence.
- Then substitute the Lean-side sigma predicate from `SigmaVerifiers.lean`.

This is the path the original `EvalEquiv/Part*.lean` took (before deletion). It drove the
O(N²) whnf cost that motivated the rebuild. The rebuild is following the explicit PC-by-PC
path precisely because it's tractable — but the abstract approach may close this remaining
branch in fewer lines.

**Open question for the rebuild:** which approach wins on this specific remaining branch?
The PC-by-PC path is the architectural commitment per the plan; the abstract path may be a
one-off fallback for the success case specifically. Decide before committing to multi-week
singleton-branch work.
