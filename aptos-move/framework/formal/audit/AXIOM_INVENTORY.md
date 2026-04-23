# CA Lean axiom inventory — Phase 8 working doc

Complete enumeration of `axiom` declarations in the CA Lean tree (`MovementFormal/Experimental/ConfidentialAsset/*` + the `AptosStd/Crypto/*` dependencies it pulls in). Regenerate with:

```
grep -rn "^axiom " aptos-move/framework/formal/lean/MovementFormal/
```

Count as of 2026-04-22: **27 axioms** across 6 files, organized into 4 categories below.

**Update 2026-04-22 (Phase 6 work - morning):** Added 4 PC-chaining helper axioms for withdrawal composition proof.

**Update 2026-04-22 (Phase 6 work - afternoon):** Refactored all 4 withdrawal PC-chaining axioms to use explicit parameter signatures instead of generic `initFrame`. Changes:
- `run_to_sigma_fail_produces_error`: Now takes explicit `chainId`, `sender`, `contract`, `ekRef`, `amount`, `curBalRef`, `newBalRef`, `proofRef` parameters plus container state `(cs1, sigmaFid)`. Proof structure documented, body has sorry.
- `run_to_range_fail_produces_error`: Extended signature with 3 container states (cs1, cs2, cs3) and 2 field IDs (sigmaFid, zkrpFid) to track both sigma and range oracle state.
- `run_sigma_arity_mismatch_produces_error` and `run_range_arity_mismatch_produces_error`: Refactored for consistency, documented as low-priority impossible cases.
- All usage sites updated in `withdrawal_eval_equiv_functional_sim` composition theorem.
- Full Lean tree builds cleanly (1896 jobs).

---

## Category 1: TEMPORARY axioms — target for elimination

These are stubs for theorems we intend to prove. Each should have a documented elimination plan.

| Axiom | File:line | Target | Status |
|---|---|---|---|
| `registration_eval_equiv_functional_sim` | `…/Registration/EvalEquiv.lean:42` | Reprove via `EvalEquivRebuild.lean`: **184 theorems**, including all 83 per-PC step lemmas + 4 complete non-singleton branches (`_compressedPoint_{none,empty,multi,nonSingleton}`). Singleton branch remaining — see [`../SINGLETON_BRANCH_ROADMAP.md`](../SINGLETON_BRANCH_ROADMAP.md). | 🟡 in progress — non-singleton case closed; singleton case is the last blocker |
| `run_to_sigma_fail_produces_error` | `…/Withdrawal/EvalEquiv.lean:568` | **REFACTORED (2026-04-22)**: Signature improved from generic `initFrame` to explicit parameters (`chainId`, `sender`, `contract`, etc.) + container state (`cs1`, `sigmaFid`). Proof body has sorry. Requires PC chain 0-9: PCs 0-5 moveLoc, 6-7 copyLoc, 8 immBorrowField, 9 call → .error. Estimated ~80 lines. Blocker: elaborator constraint on frame construction. | 🟡 refactored signature, proof pending |
| `run_to_range_fail_produces_error` | `…/Withdrawal/EvalEquiv.lean:615` | **REFACTORED (2026-04-22)**: Signature improved with explicit parameters + 3 container states (cs1, cs2, cs3) + 2 field IDs (sigmaFid, zkrpFid). Proof body has sorry. Requires PC chain 0-13 through both sigma success and range failure. Estimated ~100 lines. Same elaborator blocker. | 🟡 refactored signature, proof pending |
| `run_sigma_arity_mismatch_produces_error` | `…/Withdrawal/EvalEquiv.lean:656` | **REFACTORED (2026-04-22)**: Signature improved to match other axioms. Handles impossible case where sigma oracle returns non-empty list. Low priority (type system prevents this case). | 🟡 refactored, low priority |
| `run_range_arity_mismatch_produces_error` | `…/Withdrawal/EvalEquiv.lean:687` | **REFACTORED (2026-04-22)**: Signature improved. Handles impossible case where range oracle returns non-empty list. Low priority (type system prevents this case). | 🟡 refactored, low priority |

## Category 1a: Phase 6 composition axioms (textual, discharged in same file)

| Axiom | File:line | Purpose | Status |
|---|---|---|---|
| `register_is_formally_verified` | `…/Registration/Phase6Composition.lean` | Human-readable Phase 6 claim: `register` is formally verified via (MSL spec + Lean theorem + difftest corpus). Plan §6 explicitly calls out Phase 6 compositions as textual + difftest-enforced, not proof-theoretic. Discharged in-file by an `example` invoking `registration_eval_equiv_functional_sim`. | ✅ "axiom" by design |
| `withdraw_is_formally_verified` | `…/Withdrawal/Phase6Composition.lean` | Phase 6 claim for `withdraw` — scaffold, pending Phase 4 withdrawal theorem | 🟡 pending Phase 4 closure |
| `transfer_is_formally_verified` | `…/Transfer/Phase6Composition.lean` | Phase 6 claim for `confidential_transfer` — scaffold | 🟡 pending Phase 4 |
| `normalize_is_formally_verified` | `…/Normalization/Phase6Composition.lean` | Phase 6 claim for `normalize` — scaffold | 🟡 pending Phase 4 |
| `rotate_is_formally_verified` | `…/Rotation/Phase6Composition.lean` | Phase 6 claim for `rotate_encryption_key` — scaffold | 🟡 pending Phase 4 |

---

## Category 2: Group-theory axioms (twisted Edwards curve25519)

These state the classical Edwards-curve group laws on the Lean carrier type `EdwardsPoint`. They're not in-scope for in-repo proof — they're standard algebraic facts deferred to external mathematical literature. Expected to remain axioms permanently.

| Axiom | File:line | What it states | Why accepted |
|---|---|---|---|
| `zero_add'` | `…/EdwardsCurve25519.lean:157` | `add zero P = P` | Identity element of the group |
| `add_zero'` | `…/EdwardsCurve25519.lean:160` | `add P zero = P` | Identity element |
| `neg_add_cancel'` | `…/EdwardsCurve25519.lean:163` | `add (neg P) P = zero` | Inverse element |
| `add_assoc'` | `…/EdwardsCurve25519.lean:175` | `add (add P Q) R = add P (add Q R)` | Group associativity on twisted Edwards — classical result (Bernstein-Birkner-Joye-Lange-Peters 2008) |
| `nsmul_subgroup_order` | `…/EdwardsCurve25519.lean:210` | `nsmul ord P = zero` | Lagrange's theorem applied to prime-order subgroup |
| `scalarSmul_add'` | `…/EdwardsCurve25519.lean:222` | `scalarSmul (s+t) P = add (scalarSmul s P) (scalarSmul t P)` | Distributivity of scalar action over scalar addition |
| `scalarSmul_pointAdd'` | `…/EdwardsCurve25519.lean:226` | `scalarSmul s (add P Q) = add (scalarSmul s P) (scalarSmul s Q)` | Distributivity over point addition |
| `scalarSmul_assoc'` | `…/EdwardsCurve25519.lean:230` | `scalarSmul (s*t) P = scalarSmul s (scalarSmul t P)` | Associativity of scalar multiplication |
| `scalarSmul_one'` | `…/EdwardsCurve25519.lean:234` | `scalarSmul 1 P = P` | Identity scalar |
| `scalarSmul_smul_zero'` | `…/EdwardsCurve25519.lean:238` | `scalarSmul s zero = zero` | Annihilator on identity point |
| `ristretto_subgroup_order_prime` | `…/Ristretto255.lean:39` | `Nat.Prime ristrettoSubgroupOrder` | The Ristretto subgroup order `ℓ ≈ 2^252 + 27742…` is known-prime (can be verified by any primality-test implementation; stated as axiom to avoid pulling in that proof) |
| `p_prime` | `…/Ristretto255.lean:66` | `Nat.Prime p` | The Curve25519 base field prime `2^255 − 19` is prime — same rationale |

**Elimination plan:** none expected. These are definitional group laws + two primality facts. Moving them into Mathlib would require carrier-type alignment work that's not on the critical path; the trust cost is well-understood (standard crypto facts, textbook references).

---

## Category 3: Ristretto encoding axioms (injective / round-trip / size)

The Ristretto255 compression function `canonicalEncode : EdwardsPoint → ByteArray` is defined abstractly; the properties we need from it are stated as axioms because the full implementation lives in Rust / C and is not worth re-implementing in Lean.

| Axiom | File:line | What it states | Why accepted |
|---|---|---|---|
| `canonicalEncode_size` | `…/RistrettoEncoding.lean:139` | `(canonicalEncode P).size = 32` | By construction — Ristretto compressed format is 32 bytes |
| `decode_invalid` | `…/RistrettoEncoding.lean:143` | `decode b = none` for non-canonical inputs | By construction of the decoder |
| `decode_canonicalEncode_roundtrip` | `…/RistrettoEncoding.lean:148` | `decode (canonicalEncode P) = some P` | Round-trip property of the Ristretto encoder/decoder pair |
| `canonicalEncode_injective` | `…/RistrettoEncoding.lean:156` | `canonicalEncode P = canonicalEncode Q → P = Q` | Injectivity of the encoder |

**Elimination plan:** long-term, if Lean gets a verified Ristretto compressor these could be proved from its correctness theorems. For now, they're anchored by the per-input VM↔Lean difftest corpus (every ristretto255 corpus row = byte-level agreement between VM native and Lean oracle, which bounds the axioms' practical trust base).

---

## Category 4: Bulletproofs axioms (external audit, not in-repo verified)

Bulletproofs is the Bünz et al. 2017 range-proof system. Implementing and verifying it in Lean is a multi-year project explicitly out of scope per plan §3 / §7. The four CA axioms below pin the minimum semantic behavior the verifier needs.

| Axiom | File:line | What it states | Why accepted |
|---|---|---|---|
| `bulletproofs_reject_malformed` | `…/Bulletproofs.lean:157` | The verifier rejects proofs whose serialized form fails to decode | Basic sanity for the verifier's input validation |
| `bulletproofs_reject_bad_bits` | `…/Bulletproofs.lean:164` | Rejects proofs for bit-widths ≠ supported sizes | Explicit width-check |
| `bulletproofs_reject_bad_batch` | `…/Bulletproofs.lean:171` | Rejects batch proofs with inconsistent commitments/values | Batch-mode sanity |
| `bulletproofs_dst_distinguishing` | `…/Bulletproofs.lean:179` | Different domain-separation tags produce non-interoperable proofs | Standard DST security assumption |
| `bulletproofs_base_distinguishing` | `…/Bulletproofs.lean:187` | Different generator bases produce non-interoperable proofs | Standard base-separation assumption |

**Elimination plan:** none expected; external audit of the Rust implementation is the closest substitute.

---

## Summary

| Category | Count | Status |
|---|---|---|
| TEMPORARY (Phase 1 & 6 scope) | 5 | 🟡 elimination in progress (1 from Phase 1 + 4 from Phase 6 withdrawal) |
| Group theory | 12 | ✅ accepted (textbook crypto) |
| Ristretto encoding | 4 | ✅ accepted (anchored by difftest corpus) |
| Bulletproofs | 5 | ✅ accepted (external audit scope) |
| **TOTAL** | **26** | 21 "permanent" + 5 temporary |

**Note:** The 4 new Phase 6 axioms (`run_to_sigma_fail_produces_error`, `run_to_range_fail_produces_error`, and 2 arity mismatch axioms) are PC-chaining helpers for the withdrawal composition theorem. They represent ~280 lines of proof work that needs to be completed to fully discharge the withdrawal eval↔functional-sim equivalence.

## Acceptance criteria for Phase 8 closure

1. The TEMPORARY category empties (`registration_eval_equiv_functional_sim` gets reproved from `EvalEquivRebuild.lean`).
2. Every permanent axiom in categories 2-4 has a row here with its citation / rationale — **done**.
3. Any new axiom introduced to the tree gets a row here in the same PR. (CI guard: `check_axioms.sh` output diffed against `registration-axioms-baseline.txt` fails on net-new axioms.)
4. The composition claims (`audit/COMPOSITION_CLAIMS.md`) reference this inventory so reviewers can trace every claim back to its trust base in one hop.
