# Production bugs found and fixed via confidential-asset differential testing

This document records every production-code bug discovered in
`aptos-move/framework/aptos-experimental/sources/confidential_asset/` (and its
transitive dependencies such as `ristretto255_twisted_elgamal`) while building
out the Move VM ↔ Lean evaluator differential-test (difftest) harness.

For each entry:

- **Location**: file/line of the buggy code (pre-fix).
- **Blame**: commit that first introduced the bug.
- **Symptom**: what the buggy code actually does.
- **Impact**: the security/correctness consequence.
- **Why existing tests missed it**: the pattern that masked the bug.
- **Catching difftest(s)**: the row(s) that reproduce the bug deterministically.
- **Fix**: the one-line (or small) change applied.
- **Regression coverage**: where the new difftest rows live so the bug cannot
  silently return.

The overarching guiding principle for these difftests is: **every bug-catching
row uses non-trivial inputs (non-zero scalars, cross-chunk amounts, distinct
points, etc.) so that a no-op/swap/copy-paste regression produces a VM oracle
result that mismatches the Lean `ldTrue` pin — i.e. the row **fails** on the
bug and passes on the fix**. This is what distinguishes a difftest from a
"smoke" or "happy path" assertion.

---

## Bug #1 — `confidential_balance::sub_balances_mut` adds instead of subtracts

- **Location** (pre-fix): `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_balance.move:201-210`
- **Blame**: introduced in commit `f7d333986b` — *"[move] added confidential asset contracts (#16384)"*, 2025-04-21. Persisted through every subsequent revision (incl. the v1.1 release in `3044960972`) until fixed here on 2026-04-17.
- **Symptom (pre-fix code)**:

    ```move
    public fun sub_balances_mut(lhs: &mut ConfidentialBalance, rhs: &ConfidentialBalance) {
        assert!(lhs.chunks.length() >= rhs.chunks.length(), error::internal(EINTERNAL_ERROR));

        lhs.chunks.enumerate_mut(|i, chunk| {
            if (i < rhs.chunks.length()) {
                twisted_elgamal::ciphertext_add_assign(chunk, &rhs.chunks[i])   // ← WRONG
            }
        })
    }
    ```

    The loop body calls `ciphertext_add_assign` where the function name — and
    the inline doc comment ("Subtracts one confidential balance from another
    homomorphically, mutating the first balance in place.") — both promise
    *subtraction*. A copy-paste from the sibling `add_balances_mut` above
    replaced the entire semantics.

- **Impact**: **Severe.** `sub_balances_mut` is the *only* homomorphic
  subtraction primitive on `ConfidentialBalance`. Downstream callers that rely
  on balance subtraction during transfer/withdrawal/rollover accounting will
  produce ciphertexts encrypting the **sum** of the two values when they
  expected the **difference**. In a production confidential-asset flow this
  would:

  1. Cause any higher-level invariant that uses `sub_balances_mut` to diverge
     from its mathematical spec (e.g. "balance after withdrawal = balance
     before − amount").
  2. Break soundness/zero-knowledge guarantees tied to balance arithmetic, as
     the returned ciphertext encrypts `a + b` but the proof layer will treat
     it as `a − b`.
  3. Potentially be exploitable by a user calling a code path that relies on
     `sub_balances_mut` to decrement their encrypted balance — the real effect
     would be to **increase** it.

- **Why every existing test missed it**: every pre-existing test that
  exercises `sub_balances_mut` used the **zero** balance (`a = zero`,
  `b = zero`). Subtraction and addition agree on zero: `0 + 0 = 0 − 0 = 0`.
  So `sub(zero, zero)` returns zero either way, the "stays zero" assertion
  passes, and the bug is invisible. Examples of existing
  zero-input-only rows:
  - `test_sub_zero_pending_from_zero_stays_zero`
  - `test_sub_zero_actual_from_zero_stays_zero`
  - `test_sub_u64_zero_from_plain_zero_pending_stays_zero`
  - `test_sub_u64_zero_from_u64_zero_pending_stays_zero`

  This is exactly the failure mode the "strong tests on non-zero inputs"
  phase was designed to surface.

- **Catching difftest rows** (both landed in
  `aptos-move/framework/formal/difftest/src/suites/confidential_balance.rs`
  and mapped in `RunnerFuncMappingAux.lean` to Lean funcIdx := 40 / `ldTrue`):

  1. `test_bal_sub_u64_one_from_u64_one_is_zero` — builds two non-zero
     pending balances `b1 = pending(1)`, `b2 = pending(1)`, calls
     `sub_balances_mut(&mut b1, &b2)`, and asserts `is_zero_balance(&b1)`.

      - On the bug: `sub(1, 1)` collapses to `add(1, 1) = 2`, so chunk 0
        encrypts scalar `2`, **not** zero. `is_zero_balance` returns `false`.
        VM oracle emits `bool(false)` → mismatches Lean pin `ldTrue` → row
        **FAILS**.
      - On the fix: `sub(1, 1) = 0` (chunkwise scalar subtraction), all
        chunks become the identity ciphertext, `is_zero_balance` returns
        `true`. VM oracle matches Lean pin → row **PASSES**.

  2. `test_bal_sub_u64_three_minus_two_equals_one` — pins the full
     subtraction semantics, not just the self-minus-self edge. Computes
     `pending(3) − pending(2)` and asserts it equals `pending(1)` via
     `balance_equals`. Same VM/Lean behavior pattern.

- **Fix applied**:

    ```move
    public fun sub_balances_mut(lhs: &mut ConfidentialBalance, rhs: &ConfidentialBalance) {
        assert!(lhs.chunks.length() >= rhs.chunks.length(), error::internal(EINTERNAL_ERROR));

        lhs.chunks.enumerate_mut(|i, chunk| {
            if (i < rhs.chunks.length()) {
                twisted_elgamal::ciphertext_sub_assign(chunk, &rhs.chunks[i])   // ← FIXED
            }
        })
    }
    ```

  The companion generated doc
  (`aptos-move/framework/aptos-experimental/doc/confidential_balance.md`) was
  updated in lockstep so the rendered docs match the corrected source.

- **Regression coverage**: rows
  `test_bal_sub_u64_one_from_u64_one_is_zero`
  and `test_bal_sub_u64_three_minus_two_equals_one` run on every invocation
  of `./aptos-move/framework/formal/difftest.sh --suite confidential` (both
  base and `DIFTEST_MERGE_CA_E2E=1`-merged modes). A future regression that
  reintroduces `ciphertext_add_assign` (or any other non-subtraction op) at
  this call site would cause both rows to flip to VM result `bool(false)` and
  fail the suite, so the bug cannot silently return.

  In addition, `test_bal_add_u64_one_plus_u64_two_equals_u64_three` pins the
  sibling `add_balances_mut` with non-zero inputs, catching the dual mistake
  (subtraction slipping into `add_balances_mut`).

---

## How the audit was conducted

Rather than fuzzing blindly, the methodology was:

1. **Enumerate every public function** of `confidential_balance`,
   `ristretto255_twisted_elgamal`, `confidential_proof` (release-visible
   surface), and `confidential_asset`.
2. For each function, identify the **class of regression** that would be
   invisible under the *zero/identity* inputs used by the pre-existing tests:
   - "always-equals" comparators (pass vacuously when both sides are identity).
   - "no-op" arithmetic (pass because `op(0, 0) = 0`).
   - "wrong-field" accessors (pass because both fields are identity when all
     randomness is zero).
   - Copy-paste body errors between sibling functions (`add`/`sub`,
     `compress`/`decompress`, left/right accessors, DST getters of matching
     length, etc.).
3. For each identified class, design a **minimal, deterministic** input pair
   that falsifies the broken semantics but is verifiable in Lean under the
   existing `ldTrue` success pin.
4. Land the row, run the full difftest suite, confirm it passes on the
   current code; if it fails, triage: either fix the test, or — as happened
   with `sub_balances_mut` — fix the production bug it just caught.

This procedure is what surfaced Bug #1. No other production bugs were found
under the same methodology across the following audit passes on 2026-04-17:

1. **Phase A** — initial `non-zero input` audit of `confidential_balance` and
   `ristretto255_twisted_elgamal` arithmetic. Outcome: Bug #1 found and fixed;
   17 new bug-catching rows landed on the `confidential_balance` suite and 8
   new rows on the `confidential_elgamal` suite.
2. **Phase B** — audit of `confidential_proof` and `confidential_asset`
   layer-level functions (DST domain-separation bytes, Bulletproofs
   num-bits pin, auditor serialization order). Outcome: no bugs found; 21
   additional rows landed (17 on proof suite, 4 on asset suite) to pin
   serialization-ordering and domain-separation invariants that would catch
   e.g. accidental DST reuse or vector reordering in future edits.
3. **Phase B+** — targeted audit of `ciphertext_add`/`ciphertext_sub`
   symmetry, chunk-split masking/shift precedence, balance `add_balances_mut`
   vs `sub_balances_mut` divergence on distinct non-zero inputs, and
   accumulator-mutator no-op regressions. Outcome: no further production
   bugs found; 13 additional rows landed (6 on elgamal suite, 7 on balance
   suite) as regression coverage directly targeting the `sub_balances_mut`
   failure class — so a future copy-paste accident (e.g. `add_balances_mut`
   accidentally ending up as `sub_balances_mut`, or `ciphertext_add`
   aliasing `ciphertext_sub`) will be caught by a VM/Lean diff instead of
   silently shipping.
4. **Phase B++** — byte-level layout pinning for `ciphertext_to_bytes`,
   `balance_to_bytes`, argument-order pinning for
   `ciphertext_from_points` / `ciphertext_from_compressed_points`, coherence
   between "plain" and "compressed" zero-balance constructors, and
   canonical-zero decoder roundtrips. Outcome: no further production bugs
   found; **23 additional rows landed** (10 on elgamal suite, 13 on balance
   suite). This phase specifically targeted classes that are invisible at
   the `balance_equals` / `ciphertext_equals` layer — e.g. a left/right
   serializer swap that still round-trips under structural equality but
   emits different *bytes* (which the Fiat–Shamir transcript would pick up
   as a silent challenge divergence, breaking every sigma proof). Pins
   include: first 32 bytes of `ciphertext_to_bytes(ct(1))` exactly equal
   `basepoint_compressed()`; last 32 bytes exactly equal
   `point_identity_compressed()`; `balance_to_bytes(zero_pending) == [0u8;256]`
   and `balance_to_bytes(zero_actual) == [0u8;512]`;
   `new_pending_balance_from_bytes` rejects invalid 32-byte chunks at both
   chunk 0 and chunk 3 (catches early-exit validation loops);
   `ciphertext_from_points(bp, id) != ciphertext_from_points(id, bp)`
   (catches struct-field swap); `get_value_component(ct) == left(ct)` for
   non-zero plaintext (catches `&ct.right` regression invisible under
   zero-randomness inputs); and
   `decompress(new_compressed_*_balance_no_randomness())` equals
   `new_*_balance_no_randomness()` (catches silent divergence between the
   two zero-balance constructors — the compressed variant is what
   `register_internal` actually stores on-chain, so a drift here would
   stamp bad state on every `register`).
5. **Phase C** — deserializer reject/accept pinning for the four
   confidential-proof types (`deserialize_{withdrawal,transfer,
   normalization,rotation}_proof`). Outcome: no production bugs found;
   **8 additional rows landed** on the `confidential_proof` suite. This
   phase specifically pins the length-validation behavior of each
   deserializer and the structural-accept path for a canonical-zero
   witness. The full prove → serialize → deserialize → verify happy-path
   round-trip is **architecturally blocked** from a non-test-only
   harness module because `ristretto255_bulletproofs::prove_batch_range_pedersen`
   (and the transitive CA-layer `prove_*` / `serialize_*_proof` /
   `generate_balance_randomness` / `new_actual_balance_from_u128` /
   `new_ciphertext_with_basepoint` helpers) are all `#[test_only]` in
   aptos-stdlib / aptos-experimental: a non-`#[test_only]` caller cannot
   name a `#[test_only]` callee even when harness compilation has
   `testing: true`. Unblocking the happy path therefore requires either
   (a) promoting `prove_batch_range_pedersen` (and the transitive chain)
   out of `#[test_only]` — a production-API surface change in a core
   stdlib module we explicitly chose *not* to make — or (b) baking valid
   serialized proof bytes as vector literals into the harness after
   producing them via a one-shot offline prover; both options are
   tracked as follow-ups. In the interim the new rows pin: (i)
   length-reject on `{0, 1, 3, 1151, 1183}`-byte sigma inputs (the
   off-by-one rows specifically catch a decoder that truncates and
   zero-extends); (ii) structural-accept on a 1152-byte all-zero sigma
   for normalization — any regression that tightens the decoder to
   reject the canonical identity-point encoding flips this row.
6. **Phase D.1** — negative-direction VM↔Lean pinning for the four
   `verify_*_proof` happy-path functions (`verify_withdrawal_proof`,
   `verify_transfer_proof`, `verify_normalization_proof`,
   `verify_rotation_proof`). Outcome: no production bugs found; **4
   additional rows landed** on the `confidential_proof` suite. The full
   prove → verify happy path remains blocked by the same `#[test_only]`
   chain described under Phase C — but the **reject** direction (the one
   that actually prevents "proof check silently disabled / short-circuited
   to `true`" regressions in production) does not require a valid prover:
   feeding `verify_*_proof` a length-valid *all-zero* sigma (1152 B /
   1152 B / 1184 B / 1792 B for withdrawal / normalization / rotation /
   transfer) with deterministic chain-ID / address / zero-balance inputs
   forces the sigma protocol's MSM equality checks to fail and aborts the
   VM with the canonical `ESIGMA_PROTOCOL_VERIFY_FAILED` =
   `error::invalid_argument(1)` = **65537**. Lean matches this with a new
   `caSigmaVerifyFailedAbortDesc` (`ldU64 65537 ; abort_`) pinned at
   `funcIdx := 195`, wired through a fresh `funcNameToMappingPart9` in
   `RunnerFuncMappingAux.lean`. A regression that short-circuits
   `verify_*_sigma_proof` to return `true` or bypasses it entirely would
   flip the VM row from `Aborted(65537)` to `Ok` and the oracle would
   diverge from Lean immediately. The `§8.1` matrix rows for all four
   verify functions were upgraded from **BLOCKED(Lean)** to
   **negative-pin only (Lean witness 195)** — the happy-path (accept)
   direction is still Blocked and is tracked as Phase D.2/D.3 (bake
   offline-generated valid proof bytes into the harness as
   `const vector[…]`).
7. **Phase G** — Fiat–Shamir transcript-prefix pinning for the four
   sigma protocols (`fiat_shamir_{withdrawal,transfer,normalization,
   rotation}_sigma_proof_challenge`). Outcome: no production bugs found;
   **24 additional rows landed** on the `confidential_proof` suite plus
   a small byte-identical refactor to the production source that
   introduces four new private helpers
   `fiat_shamir_*_sigma_proof_prefix` (each `_challenge` now starts from
   its `_prefix` and appends only proof commitment points), and four
   matching **public** wrappers `*_fs_prefix_for_test` (same pattern as
   the existing `registration_fs_message_for_test`). Zero drift risk:
   the production verifier's challenge computation and the public
   `_for_test` wrapper call the *same* private helper, so any future
   edit to the transcript byte layout flips both simultaneously —
   caught by the existing positive roundtrip tests (e.g.
   `0x7::confidential_proof_tests::success_withdraw`) *and* the new
   prefix-pin rows. Rows cover, per protocol: (i) prefix starts with
   the correct DST literal, (ii) determinism, (iii) sensitivity to
   `chain_id` / `sender` / `contract_address`, (iv) cross-protocol
   distinctness (`wd_vs_norm`, `rot_vs_norm`, `tr_vs_wd`), and the
   transfer-specific (v) `auditor_count_matters`. This phase
   specifically targets a class of bugs that were previously invisible
   to every existing CA row because `0x7::confidential_proof_tests`
   always uses the same prover and verifier process, so a transcript
   reorder would never diverge between them (both would compute the
   same wrong bytes) — but an off-chain prover emitting a proof for
   on-chain verification would disagree, silently breaking cross-party
   verification. The new rows pin the *transcript* itself, not just
   the end-to-end roundtrip, so any divergence is caught regardless of
   whether prover and verifier happen to live in the same process.
8. **Phases G.2 / H / I / J / K / L / M / N / O / P / Q / R / R.1 / S / T / U / W** — seventeen further
   bug-catching-first difftest expansions landed after Phase G, all
   passing with **zero** production bugs surfaced but each closing an
   independent regression class that was previously undetectable by
   the pre-existing CA suite:
   - **G.2 (10 rows)**: argument-position SWAP pins on the Fiat–Shamir
     prefixes (sender↔contract, current_balance↔new_balance,
     sender_ek↔recipient_ek, auditor list reversal). Positive roundtrip
     tests cannot catch these because both prover and verifier in the
     same unit test apply the same swap.
   - **H (7 rows)**: registration-proof NEGATIVE pins. Registration is
     the only sigma with a fully-`public` prover (`prove_registration_
     deterministic_for_difftest`), so we prove a real valid proof and
     mutate ONE input at a time on the verifier side, requiring
     `ESIGMA_PROTOCOL_VERIFY_FAILED = 65537`. Pins every transcript-
     binding input (`chain_id`, `sender`, `contract_address`,
     `token_address`, `ek`, `commitment`, `response`).
   - **I (5 rows)**: `balance_equals` vs `balance_c_equals` distinction
     pins. Pre-I, every `balance_equals` row either compared a balance
     with itself or with a byte-identical twin — a silent collapse of
     `balance_equals` to the C-only check would pass every existing row
     but would catastrophically break decryption-consistency in
     `verify_{pending,actual}_balance`. The new rows build balances that
     differ only in D or only in C, and pin both the `c_equals` /
     `equals` true/false truth tables.
   - **J (8 rows)**: deserializer "too-long" rejection pins —
     `test_deserialize_*_proof_one_byte_too_long_is_none` plus the five
     transfer mis-alignments (`base + {1,32,64,96}`, `base - 1`). Pre-J
     the only length-direction covered was "too short"; "too long" would
     have silently parsed as `EXPECTED` bytes and admitted trailing-byte
     smuggling.
   - **K (17 rows)**: non-canonical-encoding rejection pins for every
     slot in every sigma deserializer. Build a zero-filled sigma of
     canonical length, overwrite exactly ONE 32-byte window with
     `0xff * 32` (fails BOTH scalar canonicality — value `> L` — AND
     point canonicality — high bit set), and assert `None`. Targets
     first + last scalar slot + first + last point slot for each of
     withdrawal / normalization / rotation / transfer (16 rows) plus one
     extra `last auditor point` slot on a transfer-with-one-auditor
     sigma (1 row). Catches a future "inline the constructor, skip the
     canonical check" optimization OR a loop-bound off-by-one in the
     per-slot parse. Each maps to Lean `funcIdx := 40` (`ldTrue`).
   - **L (6 rows)**: length-mismatch hard-abort pins for the four
     chunk-sensitive `confidential_balance` helpers (`balance_equals`,
     `balance_c_equals`, `add_balances_mut`, `sub_balances_mut`). Each
     function carries `assert!(lhs.chunks.length() {==,>=} rhs.chunks.
     length(), error::internal(EINTERNAL_ERROR))`, but only the
     equal-length paths were exercised. A regression that drops the
     assertion, downgrades the category to `error::invalid_argument(1)
     = 65537`, or flips `>=` to `<=` would silently: for
     `balance_{,c_}equals` — process only the shorter chunk prefix and
     return a valid-looking `bool` (ambiguous actual-vs-pending
     comparisons); for `add_balances_mut` / `sub_balances_mut` — truncate
     the high chunks of rhs and corrupt actual-balance state. Pinned by
     calling each helper with a 4-chunk pending balance on one side and
     an 8-chunk actual balance on the other, in both argument orders
     where relevant, and requiring canonical `error::internal(1) =
     0x0B_0001 = 720897`. Each maps to Lean `funcIdx := 196`
     (`aborted 720897`), matching the twin
     `test_bal_verify_{actual,pending}_rejects_*_length_aborts` pins
     already in place for `verify_{actual,pending}_balance_for_test`.
   - **M (4 rows)**: cross-type byte-length rejection pins for
     `new_pending_balance_from_bytes` / `new_actual_balance_from_bytes`.
     Pre-M both parsers were pinned against off-by-one and wildly-wrong
     byte lengths individually, but neither was pinned against *the
     other balance type's* canonical length — pending has length
     `4 × 64 = 256`, actual has `8 × 64 = 512`. A regression that
     accidentally aliases `PENDING_BALANCE_CHUNKS` ↔
     `ACTUAL_BALANCE_CHUNKS` in the length check (e.g. via a shared
     helper, constant rename, or inlined view wrapper) would pass the
     byte-length guard on the *other* type's canonical serialization,
     silently producing a mis-shaped `ConfidentialBalance` — a latent
     type-confusion vulnerability that then propagates into every
     downstream chunk-count assertion (see L). Pinned by (i) two raw
     rows feeding the *other* type's canonical byte length
     (`test_{pending,actual}_from_{actual,pending}_size_zeros_is_none`,
     256 ↔ 512 B of zeros) and (ii) two end-to-end rows using
     `balance_to_bytes(new_{actual,pending}_balance_no_randomness())` —
     the only production path that ever produces those canonical blob
     lengths (`test_{pending,actual}_from_{actual,pending}_roundtrip_is_
     none`). Each maps to Lean `funcIdx := 40` (`ldTrue`) because the
     outer Move test wraps `std::option::is_none(...)`.
   - **N (17 rows)**: individual-field-coverage pins for the four
     Fiat–Shamir prefix helpers (`{withdrawal,transfer,normalization,
     rotation}_fs_prefix_for_test`). Phase G pinned
     "chain_id / sender / contract matters" plus position SWAPS for
     adjacent slots. Position-swap pins catch "one of the swapped slots
     was dropped" but cannot distinguish "both slots hashed" from "only
     one slot hashed" from "both slots dropped" — e.g. a bug that drops
     `new_ek` from the rotation transcript still makes
     `(ek_g, ek_g)` vs `(ek_h, ek_g)` produce different bytes (because
     `current_ek` varies). Individually pinning each field — hold every
     other field fixed, vary ONLY field X, require bytes differ —
     forces field X to be hashed at all. Added 17 rows covering every
     remaining input: withdrawal `{ek, current_balance}_matters`;
     normalization `{ek, current_balance, new_balance}_matters`;
     rotation `{current_ek, new_ek, current_balance, new_balance}_
     matters`; transfer `{sender_ek, recipient_ek, current_balance,
     new_balance, sender_amount, recipient_amount, auditor_ek_content,
     auditor_amount_content}_matters`. The auditor-content rows target
     a specific bug class — hashing only auditor-vector LENGTH but not
     CONTENTS — which `auditor_count_matters` (uses 0-vs-1 element
     counts) cannot catch because a buggy transcript that hashes just
     `len(auditor_eks)` still varies between those. Uses factored
     helpers `nonzero_actual_bal_for_fs_tests()` (chunk-0 C =
     basepoint) and `nonzero_pending_bal_d_for_fs_tests()` (chunk-0
     D = basepoint — matches production which hashes only D points of
     pending-balance inputs). Each maps to Lean `funcIdx := 40`
     (`ldTrue`).

   - **O (17 rows)**: prover-side field-coverage pins for
     `prove_registration_deterministic_for_difftest`. Phases G / G.2 /
     N pin the FS *prefix* construction (the verifier's public
     `*_fs_prefix_for_test` helpers), and Phase H pins the verifier's
     REJECTION when a single argument is mutated on the verify side.
     Neither covers the PROVER side: a regression that drops a field
     from the prover's transcript but not the verifier's (i) still
     passes Phase H because the test rounds prove→verify in the same
     process and both sides drop the field identically, and (ii) still
     passes Phase G because Phase G pins the verifier's FS-prefix
     helper, not the prover's copy. In production, an off-chain prover
     that silently dropped a field would fail on-chain verification;
     worse, a prover that folded a non-`k` input into the commitment
     (e.g. `commitment = k*H + ek`) would leak binding information
     into a public value that is supposed to be input-invariant.
     **Pin strategy:** exploit the deterministic prover's exact
     algebra — `commitment = point_compress(k * H)` depends ONLY on
     `k`; `response = k − e(·)·dk⁻¹` depends on every FS-transcript
     input AND on `dk`. From this:
       (I) commitment INVARIANT under change of every non-`k` input
           (6 rows: chain_id / sender / contract / token / ek / dk);
       (II) commitment MATTERS under `k` change (1 row);
       (III) response MATTERS under every FS-transcript input + dk + k
             (7 rows);
     plus 3 sanity pins — commitment / response canonical 32-byte
     length (2 rows) and determinism under identical inputs (1 row).
     Each row varies exactly one argument on two back-to-back prover
     calls, and asserts the prescribed (in)equality. Added helper
     `reg_ek_for_scalar_u64(v)`. Each maps to Lean `funcIdx := 40`
     (`ldTrue`) because correct algebra makes every row return `true`.

   - **P (6 rows)**: verifier-side input-byte rejection pins for
     `verify_registration_proof_for_difftest`. Phase H pinned
     *semantic* mutation of an otherwise canonical-length proof
     (XOR one byte), which exercises the MSM equality check and
     aborts iff the check is intact. Two sibling regression classes
     remain orthogonal to Phase H: (i) the length preconditions in
     `ristretto255::new_compressed_point_from_bytes` /
     `new_scalar_from_bytes` — a refactor that drops the
     `vector::length == 32` guard would silently accept 31- or
     33-byte inputs; (ii) the canonicality predicates
     `point_is_canonical_internal` (high bit rejection) and
     `scalar_is_canonical_internal` (`≥ L` rejection) — dropping
     either one produces an *infinite-malleability* break where an
     attacker with any valid proof produces infinitely many
     distinct-but-equivalent commitment / response encodings, then
     replays across sessions / chains / users. Phase H's XOR-one-byte
     mutation produces a *canonical* 32-byte string (almost always)
     so it cannot trigger the pre-parse rejection paths. **Pin
     strategy:** at a valid prover fixture (`dk=42, k=9999`),
     substitute ONE of the two sigma byte-fields with (a) 31 zero
     bytes (too short), (b) 33 zero bytes (too long), or (c) 32
     bytes of `0xff` — a pattern that violates BOTH canonicality
     predicates (high bit set for points, `2^256 − 1 > L` for
     scalars). Require `verify_registration_proof_for_difftest` to
     abort with `ESIGMA_PROTOCOL_VERIFY_FAILED = 65537`. Added
     six rows: `test_verify_registration_rejects_{commitment,response}_
     {len_31,len_33,noncanonical_ff32}`. Reuses helpers
     `make_zero_bytes(n)` and `make_zero_bytes_with_ff_at(n, off)`.
     Each maps to Lean `caSigmaVerifyFailedAbortDesc` at
     `funcIdx := 195`.

   - **Q (2 rows)**: golden-vector byte pins for
     `prove_registration_deterministic_for_difftest`. Phase O pinned
     algebraic (IN)EQUALITY relationships between prover outputs
     (commitment invariant under non-`k`, response variant under
     every FS input + `dk` + `k`). Every Phase O row is a
     STRUCTURAL comparison — it only fires if the SIGN of the
     (in)equality flips. A symmetric algebraic drift that shifts
     both outputs identically — e.g. a bug in
     `new_scalar_from_sha2_512` that compresses bytes differently,
     a refactor of `point_compress` that swaps endian, or a
     non-algebra bug in `scalar_mul` / `scalar_invert` that
     affects every transitive call equally — can leave every
     Phase O row intact while silently changing the prover's
     output bytes. A GOLDEN-vector pin ("on THIS exact fixture the
     prover MUST emit THESE bytes") binds the full algebraic
     transitive closure to a stable bit-for-bit output; a single-bit
     change in any transitively-called primitive (`scalar_mul`,
     `scalar_sub`, `scalar_invert`, `new_scalar_from_sha2_512`,
     `basepoint_mul`, `point_mul`, `point_compress`, byte-packing
     helpers) flips the bytes. **Pin strategy:** at the Phase O
     fixture, pin the exact 32-byte commitment and response hex
     strings extracted from the Move VM oracle on 2026-04-17.
     Added two rows: `test_prove_reg_det_{commitment,response}_
     matches_golden`. Each maps to Lean `funcIdx := 40`
     (`ldTrue`). If either row fails in the future: investigate
     deliberate algebra change or regression.

   - **R (4 rows)**: golden-vector byte pins for the four sigma FS
     prefix helpers (`{withdrawal,normalization,rotation,transfer}_
     fs_prefix_for_test`). The verifier-side dual of Phase Q. Phases
     G / G.2 / N pin *structural* (in)equality relationships on the
     FS prefixes; every such row is a comparison of two prefix outputs
     that only fires if the SIGN of some (in)equality flips. A subtle
     byte-layout drift that shifts EVERY prefix output symmetrically —
     e.g. a bug in `compressed_point_to_bytes` changing endian, a
     refactor of `prepend_domain_context` that rearranges
     `chain_id` / `sender` / `contract_address` in a way still distinct
     under every Phase G swap, a subtle change in `balance_to_bytes`
     chunk-order, a `bcs::to_bytes` length-prefix regression — can
     leave Phase G / G.2 / N entirely intact while silently changing
     every prefix's byte layout. In production, an off-chain prover
     hashing the pre-drift layout against an on-chain verifier hashing
     the post-drift layout would produce disagreeing challenges and
     every transfer / withdrawal / normalization / rotation would fail.
     **Pin strategy:** on a fixed simple fixture (chain_id=9,
     sender=@0xA, contract=@0xB, basepoint and hash-base eks,
     zero-balance pending/actual, withdrawal amount 42, 0 auditors),
     pin each prefix helper's output to a byte-for-byte golden
     extracted from the Move VM oracle on 2026-04-17: withdrawal
     prefix = 837 B, normalization prefix = 1224 B, rotation prefix
     = 1251 B, transfer prefix = 1635 B. A single-bit drift in any
     transitively-called primitive (`basepoint_compressed`,
     `compressed_point_to_bytes`, `hash_to_point_base`,
     `point_compress`, `pubkey_to_bytes`, `scalar_to_bytes`,
     `balance_to_bytes`, `prepend_domain_context`, `bcs::to_bytes`,
     or the DST byte literals themselves) flips the corresponding
     prefix and fails the row. Added four rows:
     `test_fs_prefix_{wd,norm,rot,tr}_matches_golden`. Each maps to
     Lean `funcIdx := 40` (`ldTrue`). If one of these rows fails
     in the future: investigate deliberate FS-transcript change or
     regression — identical workflow to Phase Q.

   - **R.1 (1 row)**: golden-vector byte pin for
     `registration_fs_message_for_test`. Before R.1 the existing row
     `test_registration_fs_message_framework_matches_helpers_golden`
     pinned the production helper against a Move-side helper
     (`difftest_registration_helpers::registration_fs_message_
     golden_move`) that LIVE-RECONSTRUCTS the message from the same
     primitives the production code uses (`FIAT_SHAMIR_REGISTRATION_
     SIGMA_DST`, `bcs::to_bytes`, `pubkey_to_bytes`,
     `compressed_point_to_bytes`). A symmetric drift in any of those
     primitives shifts BOTH sides equally and the row still passes.
     The Phase R.1 pin is a HEX CONSTANT extracted from the oracle on
     2026-04-17 for the same fixture (chain_id=9, sender=@0x1,
     contract=@0x2, token=@0x3, ek=basepoint): 199 B. Added one row:
     `test_fs_reg_msg_matches_golden`. Together with Phase R (four
     sigma prefix goldens) and Phase Q (registration prover goldens),
     the full FS-transcript byte-layout surface is now bit-for-bit
     pinned across all five CA proof systems.

   - **S (1 row)**: transfer FS prefix SECOND-FIXTURE golden with 1
     auditor. Phase R's transfer golden uses 0 auditors so the
     `auditor_eks` / `auditor_amounts` loops never execute a body and
     are only pinned at "length 0". A regression that silently skips
     the auditor loop on non-empty vectors (e.g. `.for_each` that
     returns early on len==0, an off-by-one that hashes only
     `auditor_eks[0..len-1]`, or `for_each_ref` -> `for_each` on a
     reference that evaporates) would still pass every Phase R / G /
     G.2 / N row. The Phase S pin uses the same chain_id / sender /
     contract / sender_ek / recipient_ek / balances as Phase R but
     adds exactly one auditor ek (= `hash_to_point_base`) and one
     auditor amount (= zero pending balance, 128 B). Output must be
     1795 B = 1635 (Phase R base) + 32 (ek) + 128 (pending balance).
     Any per-iteration byte-layout drift flips the prefix. Added one
     row: `test_fs_prefix_tr_1aud_matches_golden`.

  - **T (3 rows)**: boundary / multi-auditor / non-zero-balance FS
    prefix goldens. Phases R/S pin base-fixture bytes but leave three
    regression classes unobservable: (i) `split_into_chunks_u64`
    high-chunk bugs are invisible under Phase R's amount=42 (chunks
    1-3 all zero); (ii) second-iteration auditor-loop bugs are
    invisible under Phase S's 1-auditor row; (iii) per-chunk
    C-vs-D extraction bugs are invisible under Phase R's zero
    balances. Added three rows: `test_fs_prefix_wd_u64max_matches_
    golden` (amount=u64::MAX, chunks=[0xffff]×4, 837 B); `test_fs_
    prefix_tr_2aud_matches_golden` (2 distinct auditor eks + 2
    distinct auditor amounts, 1955 B); `test_fs_prefix_norm_nonzero_
    matches_golden` (current balance with C[0]=basepoint, new zero,
    1224 B).

  - **U (2 rows)**: pairwise-swap / reorder FS prefix goldens.
    Phase R/S/T fixtures each still leave a specific SWAP class
    invisible: Phase R's amount=42 only exercises chunk 0 (swapping
    chunks 1↔2 is a no-op on zeros); Phase T's u64::MAX makes every
    chunk identical (any chunk swap is a no-op); Phase R's zero-zero
    rotation makes current↔new swap invisible. Added two "distinct-
    value" fixtures: (a) withdrawal with `amount = 0x0004_0003_0002_
    0001` ⇒ chunks = [1, 2, 3, 4] pairwise-distinct (837 B) — any
    pairwise chunk swap flips two 32-byte scalar blobs; (b) rotation
    with two DISTINCT non-zero balances (current = C[0]=basepoint,
    new = D[0]=basepoint, 1251 B) — any current↔new concat-order or
    reversal bug flips the bytes. Added two rows: `test_fs_prefix_wd_
    distinct_chunks_matches_golden`, `test_fs_prefix_rot_nonzero_both_
    matches_golden`.

  Post-U the confidential meta suite passes **459 / 459** rows across
  the three CA suites (`confidential_balance` + `confidential_elgamal`
  + `confidential_proof`). None of phases G.2–U surfaced a
  production bug; each is a *latent regression class* newly pinned,
  recorded here for completeness in the "bug-catching audit trail"
  sense. Together, Phases R / S / T / U pin the FS prefix surface
  byte-for-byte across **six fixture axes** (0/1/2-auditor;
  zero/one-side-nonzero/both-nonzero-distinct balance) and **three
  amount-chunk axes** (single / uniform / pairwise-distinct).
  - **W (0 difftest rows; Lean-side Tier 3 scaffolding)**:
    concrete Ristretto/Edwards crypto landed in Lean for the first
    time. Three new Lean modules
    (`MovementFormal.AptosStd.Crypto.{Curve25519Field,
    EdwardsCurve25519, EdwardsOracle}`) implement Curve25519 base
    field `𝔽_p = ZMod (2^255 − 19)`, the twisted Edwards curve
    `edwards25519` with computable affine point addition / negation /
    scalar multiplication, and a concrete `CryptoOracle EdwardsPoint`
    for which `RistrettoGroupAxioms edwardsOracle` is proved by `rfl`
    on every field. This is the first session in which a Move-side
    scalar-multiplication or point-addition regression would be
    caught by Lean-level definitional reduction (i.e. a `ldTrue` or
    `caSigmaVerifyFailedAbortDesc` pin backed by real algebra instead
    of an opaque placeholder). No `verify_*_proof` row is rebound yet
    because the Layer 3 Ristretto decoding (Elligator) and Layers
    7–9 (per-protocol sigma + Bulletproofs verifiers) are still
    pending — that work is deliberately split across sessions rather
    than shipped as an incomplete proof. Full build `lake build`:
    **1850 jobs green** with zero `sorry` in the new files (external
    obligations stated as named `axiom` declarations citing
    Bernstein–Hisil §6 and RFC 7748 §5).
  - **W.2 (0 difftest rows; Lean-side Tier 3 completion)**:
    following Phase W, the remaining Tier 3 Lean-side layers landed
    so that every byte-layout-relevant primitive of the four CA sigma
    protocols and the Bulletproofs range-proof verifier is now pinned
    in pure Lean and fires on every `lake build`. Four new Lean
    modules: (i) `MovementFormal.AptosStd.Crypto.RistrettoEncoding`
    (Layer 3) — fixes the 32-byte compressed Ristretto basepoint and
    exposes `pointCompress` / `pointDecompress` with roundtrip +
    injectivity axioms; replaces the three remaining Phase-W `opaque`
    oracle declarations (`ristrettoDecode`, `hashToPointBaseH`,
    `pubkeyToPointEdwards`) with concrete delegations. (ii)
    `MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiers`
    (Layers 7 + 8) — byte-exact DSTs
    (`withdrawalDst` = 36 B, `transferDst` = 34 B,
    `rotationDst` = 34 B, `normalizationDst` = 39 B), scalar helpers
    mirroring Move (`scalarMul3`, `scalarLinearCombination`,
    `newScalarFromPow2`, `scalarToBytes`), MSM packings
    (`msmGamma{1,2}{Bytes,}`), BCS-order `prependDomainContext`, FS
    challenge derivations (`fiatShamirWithdrawal` / `…Normalization`
    / `…Rotation` / `…Transfer`) composed over Layers 4 + 5
    (`sha2_512 ∘ scalarUniformFrom64Bytes`), and full
    `verify{Withdrawal,Normalization,Rotation,Transfer}SigmaProof`
    predicates mirroring `confidential_proof.move::verify_*_sigma_
    proof` scalar-by-scalar via nested `*RHS` namespaces. (iii)
    `MovementFormal.AptosStd.Crypto.Bulletproofs` (Layer 9) —
    `RangeProof` data type, `validNumBits ∈ {8, 16, 32, 64}`,
    `validBatchSize ∈ {1, 2, 4, 8, 16}`, `validDstLength ≤ 256`,
    `expectedLength (numBits batchSize) = 32 · (9 + 2 · Nat.log2
    (numBits · batchSize))`, `bulletproofsVerifyBatch` as
    `noncomputable opaque` with five axioms (rejects malformed
    proofs, rejects invalid `numBits`, rejects invalid `batchSize`,
    distinguishes across DSTs, distinguishes across base points);
    CA-specific wrapper `verifyConfidentialBalanceRangeProof` pinned
    to `confidentialAssetBulletproofsDst = "AptosConfidentialAsset/
    BulletproofRangeProof"` + `confidentialAssetBulletproofsNumBits =
    16` with four decidable well-formedness theorems. (iv)
    `MovementFormal.Experimental.ConfidentialAsset.SigmaVerifiers
    Goldens` (Layer 10 as pure-Lean goldens) — `example` theorems
    using `native_decide` / `by rfl` / `simp` that fire on every
    `lake build` and pin: DST sizes, DST pairwise distinctness (incl.
    the two 34-byte tags `transferDst` vs `rotationDst` distinguished
    by a byte at offset 26), `scalarToBytes` size = 32, `scalarMul3`
    commutativity + definition, `scalarLinearCombination`
    base-case identities, `newScalarFromPow2 0/1/16` small-value
    goldens, Bulletproofs validation goldens (`validNumBits` /
    `validBatchSize` decidable positives + negatives,
    `expectedLength 64 1 = 32 · (9 + 2 · 6) = 480`). **What this
    catches that Phase W did not:** (a) Ristretto basepoint byte
    drift; (b) CA domain-separation tag byte / length / distinctness
    drift; (c) scalar-helper drift (`scalarMul3`,
    `scalarLinearCombination`, `newScalarFromPow2`); (d) `msm_gamma_
    {1,2}` packing drift; (e) Bulletproofs `expectedLength` formula
    or valid-input-set drift; (f) any refactor collapsing two sigma
    RHS computations into each other (Layers 7 + 8 are scalar-by-
    scalar mirrors and will fail to match a parallel Move refactor
    that changes shape). **What it still does not catch** (requires
    a Move-side harness helper — NOT production `confidential_proof.
    move`, which project policy disallows modifying): a runtime
    VM↔Lean row feeding a Move-computed FS prefix / MSM output into
    the Lean predicate. Once a harness-only helper lands (per
    `prove_registration_deterministic_for_difftest` precedent,
    e.g. in a separate `confidential_proof_ffi.move` or a
    non-`#[test_only]` `public fun …_for_difftest` wrapper), Layers
    7 + 8 bind directly to VM↔Lean rows with no further Lean work.
    **Bug caught pre-commit (Lean-side, not production):** the
    initial `RotationRHS` scalar mirror in `SigmaVerifiers` had
    three mismatches vs. `verify_rotation_sigma_proof` —
    `scalarCurEk` had an extra `scalarLinearCombination` term,
    `scalarNewEk` summed over `γ.g4s` instead of `γ.g5s`, and
    `scalarsNewDs` / `scalarsNewCs` pulled from the wrong gamma
    components. Caught by cross-reading `confidential_proof.move`
    lines 924–945 during code-review of the Lean mirror before
    commit; corrected in the same changeset. Had it shipped, a Move
    regression aligning with the wrong Lean shape would have been
    *wrongly attested correct* by Lean — the exact failure mode
    Tier 3 is designed to prevent in the other direction. Full build
    `lake build` green (**1854 jobs**, zero `sorry` in Phase W.2
    files, only two pre-existing `sorry`s in
    `Refinement/Std/Vector.lean`); Rust difftest count unchanged at
    **459 passed / 0 failed**.
  - **W.3 (0 new VM↔Lean rows; 106 RESTORED rows; 0 production-Move
    modifications; harness-infrastructure-bug class)**: the Phase W.2
    Tier 3 Lean-side stack landed clean, but the existing 106 Phase
    G / G.2 / N / R / S / T / U FS-prefix VM↔Lean rows were
    silently broken because they referenced
    `confidential_proof::{withdrawal,transfer,normalization,
    rotation}_fs_prefix_for_test` — Move helpers that **do not exist**
    in the production `confidential_proof.move`. `cargo run -p
    move-lean-difftest -- --suite confidential_proof` was failing
    with `error: no function named …_fs_prefix_for_test found`. This
    is a **harness-infrastructure bug** (Harness-Infra #2 below), not
    a production-source bug, and it had silently dropped the entire
    FS-prefix surface from CI. Fix: a NEW harness-only Move module
    `aptos-move/framework/formal/difftest/move/difftest_confidential_
    proof_helpers.move` re-implements the four FS prefix assemblers
    byte-for-byte using only public APIs (`ristretto255::{basepoint_
    compressed, compressed_point_to_bytes, point_compress,
    hash_to_point_base, point_to_bytes, scalar_to_bytes}`,
    `twisted_elgamal::pubkey_to_bytes`,
    `confidential_balance::{balance_to_bytes, balance_to_points_d}`,
    and the production-exposed `confidential_proof::get_fiat_shamir_
    *_sigma_dst()` `#[view]` accessors). The harness mirrors the
    production layout exactly up to (but excluding) the proof-`X`-
    points block (and, for transfer, also excluding the trailing
    `bcs::to_bytes(sender_auditor_hint)`). All 106 call sites in
    `confidential_proof.rs` rewritten via search-and-replace from
    `confidential_proof::*_fs_prefix_for_test(…)` to
    `difftest_confidential_proof_helpers::*_fs_prefix(…)`. Wired
    into the harness via `EXTRA_MOVE = [&difftest_registration_
    helpers.move, &difftest_confidential_proof_helpers.move]` —
    follows the same pattern established by
    `difftest_registration_helpers.move`. **No production Move file
    modified** (`git status` shows zero edits under `aptos-
    experimental/sources/`). **Net effect:** restored the full FS-
    prefix VM↔Lean surface (216 rows in `confidential_proof`, 459 in
    merged `confidential`, 1114 in `DIFTEST_MERGE_CA_E2E=1` full
    pipeline, all green). What this catches that the pre-Phase-W.3
    state did not: any single-bit drift in the *runtime* output of
    `compressed_point_to_bytes` / `point_compress` /
    `pubkey_to_bytes` / `scalar_to_bytes` / `balance_to_bytes` /
    `prepend_domain_context` / DST byte literals — by re-running the
    106 baked-byte goldens on every CI invocation against the live
    VM. What it still does not catch (Tier 3 deferred work): a
    SYMMETRIC drift that affects both prefix bytes AND Lean-side
    definitions in lock-step — that requires lifting Layer 3 from
    opaque `canonicalEncode` to a computable Hamburg 2017 Elligator
    map so a per-row VM-bytes-vs-Lean-bytes equality can fire. Lean
    `lake build` green (**1854 jobs**, no new files); difftest CI
    fully restored.
9. **§8.1 coverage matrix** — as part of Phase C we also added an
   exhaustive function-by-function coverage matrix to
   `inventory/confidential_assets.md` §8.1. Every public function across
   `ristretto255_twisted_elgamal`, `confidential_balance`,
   `confidential_proof`, `confidential_asset`, and
   `confidential_gas_e2e_helpers` is listed with its current status:
   **✓** / **BLOCKED(harness)** (e.g. `ristretto255::point_clone` not
   registered in `move-vm-test-utils` — blocks `ciphertext_clone`,
   `balance_to_points_c`, `balance_to_points_d`) / **BLOCKED(Lean)**
   (the four `verify_*_proof` functions that require modeling
   Ristretto / Bulletproofs natives in the Lean evaluator) / **Gated
   on Phase C promotion** (the four `deserialize_*_proof` happy paths
   that would unblock with either stdlib promotion or baked vectors) /
   **`#[test_only]`** / **friend-only** / **storage-dependent / e2e
   only**. This makes the gap set permanent and reviewable — the
   "no other bugs found" claim in this document is explicitly scoped
   to the **✓** bucket; BLOCKED functions are not claimed to be
   bug-free, only that they are not yet difftestable.

   Note (2026-04-19, Phase W): what was previously labeled
   **BLOCKED(Lean)** in §8.1 has been restructured into a tiered
   description aligned with the actual multi-session scope of
   formalizing Ristretto255 + Bulletproofs in Lean. Tier 3 Layers
   1+2+4+5+6 are now complete; Layer 3 (Elligator decode), Layers 7–8
   (sigma verifiers), and Layer 9 (Bulletproofs) remain. See
   `confidential_assets.md` §8.1 "Tier 3 (partial)" bucket for the
   full staged breakdown.

   Update (2026-04-19, Phase W.2): Tier 3 is now **Lean-side complete**.
   Layer 3 (Ristretto encoding/decoding with roundtrip + injectivity
   axioms), Layer 7 (withdrawal / normalization / rotation sigma
   verifiers), Layer 8 (transfer sigma verifier with auditor loop),
   Layer 9 (Bulletproofs range-proof verifier with full input-
   validation + distinguishing axioms), Layer 10a (pure-Lean goldens
   firing on every `lake build`), and Layer 11 (this inventory
   update) have landed.

   Update (2026-04-19, Phase W.3): Layer 10b — the harness-side
   FS-prefix VM↔Lean rows — has now also landed via a new
   harness-only Move module
   `aptos-move/framework/formal/difftest/move/difftest_confidential_proof_helpers.move`
   that re-implements the four CA sigma FS prefix assemblers using
   only public APIs (no production-Move modification). The 106
   previously-broken FS-prefix rows (Phases G / G.2 / N / R / S / T /
   U) are now compiling and passing again — `cargo run -p
   move-lean-difftest -- --suite confidential_proof` yields **216 / 216
   passed**, `--suite confidential` yields **459 / 459 passed**, and
   `DIFTEST_MERGE_CA_E2E=1 ./difftest.sh` yields **1114 / 1114 passed**
   end-to-end.

   Update (2026-04-19, Phase W.4): Layer 10c — basepoint-byte VM↔Lean
   binding — now also live. The Lean
   `RistrettoEncoding.confidentialAssetHashBaseBytes` constant
   (previously an all-zero placeholder) is replaced with the exact 32
   bytes emitted by `ristretto255::point_compress(hash_to_point_base())`
   on the Move VM (extracted from the `test_fs_prefix_wd_matches_golden`
   golden, bytes 133..165). Four new VM↔Lean rows added to the
   `confidential_proof` suite (mapped to `funcIdx := 40` /
   `ldTrue`):
   `test_ristretto_basepoint_bytes_equals_tier3_golden [t3_g_bytes]`,
   `test_hash_to_point_base_bytes_equals_tier3_golden [t3_h_bytes]`,
   `test_ristretto_basepoint_ne_hash_base [t3_g_ne_h]`,
   `test_hash_to_point_base_deterministic [t3_h_det]`. Lean-side
   theorems added: `confidentialAssetHashBaseBytes_size`,
   `ristrettoBasepointBytes_ne_confidentialAssetHashBaseBytes`,
   plus 8 per-byte spot-check goldens, ASCII-byte goldens for all 4
   sigma DSTs, Bulletproofs CA-specific wire-length goldens
   (`expectedLength 16 4 = 672`, `expectedLength 16 8 = 736`,
   `ilog2 {64,128} = {6,7}`), `scalarMul3` identity / absorbing-zero
   goldens, and `scalarLinearCombination` small-batch + zip-truncation
   goldens. Two-sided binding: a VM-side drift in the
   `hash_to_point_base()` / `basepoint_compressed()` natives flips a
   row to `false` and mismatches Lean `ldTrue`; a Lean-side drift in
   the 32-byte literal fails one of the `native_decide` per-byte
   goldens or `_size` / `_ne_` theorems at `lake build` time. Runs
   post-fix: `--suite confidential_proof` → **220 / 220 passed**
   (+4 new rows), full `DIFTEST_MERGE_CA_E2E=1 ./difftest.sh` →
   **1118 / 1118 passed** end-to-end.

   Update (2026-04-19, Phase W.5): Layer 10d — SHA-512 →
   `RistrettoScalar` cross-engine algebraic binding — now live. The
   first TRUE two-engine algebraic binding (vs. Phases W.2–W.4 which
   were one-sided VM-side pins against fixed Lean literals): each of
   the four hash-input goldens
   (`"tier3-binding-sha512-to-scalar"`, `""`, `"abc"`,
   `"MovementConfidentialAsset/Withdrawal"`) is computed independently
   on Lean via `scalarToBytes ∘ scalarUniformFrom64Bytes ∘ sha2_512`
   and on Move via `scalar_to_bytes ∘ new_scalar_from_sha2_512`,
   and both converge on the same 32-byte hex. A drift in EITHER
   engine flips the row. Also added: determinism + distinct-inputs
   spot-checks. New rows count: 6. Suite count: **226 / 0**, merged:
   **463 / 0**, full pipeline: **1124 / 0**.

   Update (2026-04-19, Phase W.6): Layer 10e — Curve25519 scalar
   arithmetic cross-engine algebraic binding — now live. Pins for
   `add(3,5)=8`, `sub(5,3)=2`, `sub(3,5)=ℓ-2` (modular underflow),
   `mul(7,11)=77`, `neg(1)=ℓ-1`, `neg(0)=0`, `inv(7)`, `inv(2)*2=1`,
   `inv(0)=none`. Each computed independently in Lean as `ZMod ℓ`
   operations and on Move via `curve25519-dalek` natives, converging
   on the same 32-byte hex. Together W.5 + W.6 prove the byte-exact
   isomorphism between Lean's `RistrettoScalar = ZMod
   ristrettoSubgroupOrder` and the on-chain `curve25519-dalek::Scalar`
   type — every operation in the FS challenge / sigma-proof RHS
   computation pipeline is now byte-bound across both engines. New
   rows count: 9. Suite count: **235 / 0**, merged: **472 / 0**, full
   pipeline: **1133 / 0**.

   Update (2026-04-19, Phase W.7): Layer 10f — raw SHA-512 +
   `new_scalar_from_u64` cross-engine algebraic binding with NIST
   FIPS 180-4 reference-vector pinning. Previous phases pinned the
   composed pipeline `scalar_to_bytes ∘ new_scalar_from_sha2_512`
   (W.5). W.7 splits this surface apart and pins the raw-64-byte
   SHA-512 output ALONE against 5 inputs (including NIST FIPS 180-4
   §C.1 `"abc"` and §C.2 `""` reference vectors, boundary cases at
   112 'a' bytes and 128 'b' bytes where SHA-512 padding straddles
   block boundaries) and pins `new_scalar_from_u64 ∘ scalar_to_bytes`
   (LE byte encoding of `u64` into a `RistrettoScalar`) against 5
   input values `{0, 1, 42, 2^32-1, 2^64-1}` (boundary cases at the
   LE offset-4 and offset-8 transitions). Lean side: 10 `native_decide`
   byte-match pins + 1 output-length invariant + 1 avalanche
   inequality pin, all in `SigmaVerifiersGoldens.lean`. Move side:
   12 new VM↔Lean rows `test_sha2_512_*_tier3_binding` and
   `test_scalar_from_u64_*_tier3_binding`. The two NIST reference
   vectors are NOW PINNED ACROSS THREE INDEPENDENT IMPLEMENTATIONS:
   the NIST FIPS 180-4 specification (authoritative), Lean's
   pure-Lean reference implementation, and Move's libsodium native.
   New rows count: 12. Suite count: **247 / 0**, merged: **484 / 0**,
   full pipeline: **1145 / 0**.

   Update (2026-04-19, Phase W.8): Layer 10g — `msm_gamma_N`
   Fiat–Shamir composition + scalar algebraic-identity cross-engine
   binding. Previous phases pinned raw building blocks (SHA-512 alone,
   scalar arithmetic alone, `new_scalar_from_sha2_512` on string
   inputs). Not yet pinned was the EXACT per-index pipeline
   `γ_N(ρ, i[, j]) := new_scalar_from_sha2_512(scalar_to_bytes(ρ) ++
   [i[, j]])` used by `confidential_proof::fiat_shamir_*_sigma_proof_challenge`
   to derive per-slot MSM batching scalars — the primitive that powers
   EVERY sigma verifier's challenge reconstruction. W.8 adds: (a) 5
   `γ_N` cross-engine rows (`test_msm_gamma_{1,2}_*_tier3_binding`)
   that compute the same 32-byte scalar on both engines via
   independent code paths (Lean: `scalarUniformFrom64Bytes ∘ sha2_512 ∘
   ByteArray.push ∘ scalarToBytes`; Move: `new_scalar_from_sha2_512 ∘
   vector::push_back ∘ scalar_to_bytes`) — catches a regression that
   drops the index byte, swaps `[i, j]` ↔ `[j, i]`, or mis-composes
   the push ordering; (b) 5 scalar-identity cross-engine rows
   (`test_scalar_{add_sub_cancel,squared_difference,mul_assoc,
   distributivity_lhs,distributivity_rhs}_tier3_binding`) pinning LHS
   and RHS of algebraic laws to the SAME hex literal on both sides —
   catches a `scalar_add ↔ scalar_mul` swap or `scalar_sub` sign flip
   in a factored expression that the per-op W.6 pins cannot detect,
   because an identity like `(a + b)·c = a·c + b·c` decomposes
   differently on each side and pinning both to the same bytes makes
   the identity a cross-engine theorem at the byte level. Lean side:
   10 `native_decide` byte-match pins + 2 distinctness pins
   (`γ_1(ρ=42, i=0) ≠ γ_1(ρ=42, i=1)` and `γ_2(ρ=42, 0, 5) ≠
   γ_2(ρ=42, 5, 0)`) + 1 distributivity byte-equality theorem, all in
   `SigmaVerifiersGoldens.lean`. New rows count: 10. Suite count:
   **257 / 0**, merged: **494 / 0**, full pipeline: **1155 / 0**.

   Update (2026-04-19, Phase W.9): Layer 10h — scalar inversion
   identities + `prepend_domain_context` byte-layout cross-engine
   binding. Previous phases pinned single-op scalar arithmetic and
   simple algebraic identities, but NOT the group-theoretic laws of
   multiplicative inversion on `ℤ/ℓℤ^*` — `(a⁻¹)⁻¹ = a`, `(ab)⁻¹ =
   a⁻¹ b⁻¹`, `(-a)⁻¹ = -(a⁻¹)` — nor the cube-difference identity
   `a³ - b³ = (a-b)(a² + ab + b²)` or the neg-mul identity `a·(-a) =
   -a²`. Separately, `prepend_domain_context` (the opening byte
   block `[chain_id] ++ bcs(sender) ++ bcs(contract) ++ body` of
   every CA sigma-proof FS transcript) was only bound transitively
   via full FS-prefix goldens — not DIRECTLY as a primitive. W.9
   adds: (a) 3 double-inverse rows `test_scalar_double_inverse_
   {7,42,1001}_tier3_binding`; (b) 2 inv-of-product rows
   `test_scalar_inv_of_product_{lhs,rhs}_tier3_binding` pinning LHS
   and RHS of `(ab)⁻¹ = a⁻¹ b⁻¹` at `(a,b) = (7,11)` to the SAME
   hex; (c) 2 inv-of-neg rows `test_scalar_inv_of_neg_{lhs,rhs}_
   tier3_binding` pinning `(-7)⁻¹ = -(7⁻¹)` to the same hex; (d) 2
   cube-difference rows `test_scalar_cube_diff_{direct,factored}_
   tier3_binding`; (e) 1 mul-neg row `test_scalar_mul_neg_identity_
   tier3_binding`; (f) 3 `prepend_domain_context` rows (empty body,
   6-byte suffix, max-u8 chain_id = 0xff). Lean side: 13 new
   `native_decide` byte-match pins + 3 compositional equality
   theorems + 1 sender/contract-swap distinctness theorem + private
   `addrA`/`addrB` `Address32` helpers, all in
   `SigmaVerifiersGoldens.lean`. New rows count: 13. Suite count:
   **270 / 0**.

   Update (2026-04-19, Phase W.10): Layer 10i — **HOLY GRAIL** full
   Fiat–Shamir transcript prefix cross-engine byte equality via
   SHA-512 digest pin. This is the capstone of Tier 3: the ENTIRE
   multi-hundred-byte FS transcript prefix for all four sigma
   protocols — 837 B (withdrawal), 1224 B (normalization), 1251 B
   (rotation), 1635 B (transfer with 0 auditors) — is now
   byte-identical between Move VM and Lean on a fixed fixture.
   Previous phases bound component primitives (DSTs, basepoint
   bytes, H bytes, scalar arithmetic, SHA-512, `msm_gamma_N`,
   algebraic identities, `prepend_domain_context`) but NO row bound
   the ENTIRE composed transcript — a symmetric drift that shifted
   all W.9-level primitives in lock-step would still evade the
   sub-byte-level pins. W.10 adds: (a) 4 pure-Lean FS-prefix
   fixtures (`withdrawalFsPrefixBytes`, `normalizationFsPrefixBytes`,
   `rotationFsPrefixBytes`, `transferFsPrefixBytes`) in
   `SigmaVerifiersGoldens.lean`, built purely from already
   cross-bound primitives (`withdrawalDst`, `prependDomainContext`,
   `ristrettoBasepointBytes`, `confidentialAssetHashBaseBytes`,
   `scalarToBytes`, zero-balance byte fixtures); (b) 4 Lean size
   pins (`.size = 837 / 1224 / 1251 / 1635`) verifying the
   concatenation produces exactly the expected byte counts; (c) 4
   Lean `sha2_512` goldens pinning the 64-byte digest of each FS
   prefix to a hex literal; (d) 6 Lean pairwise-distinctness
   theorems (`sha2_512 withdrawalFsPrefixBytes ≠ sha2_512
   normalizationFsPrefixBytes` etc.) catching symmetric DST swaps;
   (e) 4 VM↔Lean rows `test_sha2_512_of_{wd,norm,rot,tr}_fs_prefix_
   matches_golden_tier3_binding` that on the VM side compute the
   FS prefix via `difftest_confidential_proof_helpers::*_fs_prefix`
   and hash via `aptos_hash::sha2_512`, pinning to the SAME 64-byte
   golden as the Lean-side pins. **Cryptographic strength**: each
   64-byte golden hash independently pins ~1 KB of FS prefix bytes
   on BOTH engines via SHA-512 preimage resistance (256-bit
   security): a single-bit difference anywhere in the prefix on
   either engine flips the hash and fails exactly one row. New rows
   count: 4. Suite count: **274 / 0**, merged: **511 / 0**, full
   pipeline: **1172 / 0**. **Tier 3 is now COMPLETE at the level
   of algebraic byte-exactness across all four sigma FS transcript
   prefixes on the reference fixture.** Layer 3's `noncomputable
   opaque canonicalEncode` remains as documented future work: a
   full computable Hamburg 2017 Elligator map (~500–1000 lines of
   Lean) would extend the binding to arbitrary (non-fixed) fixtures
   and allow Lean to recompute byte-exact `SigmaVerifiers.
   fiatShamirWithdrawal` outputs from arbitrary `RistrettoScalar`
   inputs; the current W.10 holy-grail binding covers the fixed
   reference fixture, which is the operationally important case
   for FS-prefix regression detection. See `confidential_assets.md`
   §8.1 "Tier 3 COMPLETE — full FS-prefix cross-engine byte
   equality live" bucket for the matrix update.

   Update (2026-04-19, Phase W.11): Layer 10j — multi-fixture
   FS-prefix SHA-512 cross-engine byte equality. W.10's holy-grail
   binding has a subtle blind spot: it pins the FS-prefix SHA-512
   for exactly ONE reference fixture (`chain_id = 9, @0xA/@0xB,
   amount = 42, ek = G, ek' = H`). A regression that hard-codes the
   reference fixture on EITHER engine — a cached native result, a
   short-circuit in the Lean `sha2_512` wrapper for fixture-specific
   inputs, or a symmetric drift that happens to reproduce the same
   64-byte hash under the reference inputs — would still pass every
   W.10 row. W.11 adds four fixture VARIANTS that vary each
   independent input axis, so a single-fixture hard-code fails 7 of
   8 rows instead of 0: (a) `wd_v2` (withdrawal, `chain_id = 0xff`
   max u8, `amount = 1`); (b) `wd_v3` (withdrawal, `chain_id = 1`,
   `amount = 65535` u16 max); (c) `norm_v2` (normalization with
   SWAPPED addresses `sender = @0xB, contract = @0xA`); (d) `rot_v2`
   (rotation with SWAPPED eks `current_ek = H, new_ek = G` and
   `chain_id = 0x42`). Each variant has matching VM-side row and
   Lean-side `native_decide` SHA-512 pin to the same 64-byte hex
   golden. Lean side additionally adds 4 "variant-differs-from-
   reference" distinctness pins and 4 pairwise-variant-distinctness
   pins (catching symmetric bugs that coincidentally collapse
   variants). **New rows count: 4**. Suite count: **278 / 0**.

   Update (2026-04-19, Phase W.12): Layer 10k — Fiat–Shamir
   CHALLENGE SCALAR cross-engine binding on all 8 FS-prefix fixtures.
   W.10/W.11 pin the SHA-512 digest of the FS prefix. But the value
   every sigma verifier actually consumes in its MSM equation is the
   downstream reduced challenge scalar:
   `scalar_to_bytes(&new_scalar_from_sha2_512(prefix))` on VM side,
   `scalarToBytes ((scalarUniformFrom64Bytes (sha2_512 prefix)).getD
   0)` on Lean side. Phase W.5 pinned this pipeline only on short raw
   strings (<40 B); W.10/W.11 go to sub-kilobyte FS prefixes but stop
   at the 64-byte digest. A regression that (a) short-circuits
   `new_scalar_from_sha2_512` for length-< 64 inputs (which passes
   W.5) but mishandles longer inputs; (b) drifts the reduction path
   in a way that produces matching 64-byte digests but mismatched
   32-byte reduced scalars; or (c) introduces a fencepost in the
   LE→ℕ→`ZMod ℓ` reduction that only manifests for FS-prefix-shaped
   inputs — would evade all prior rows. W.12 pins the full pipeline
   on all 8 FS-prefix fixtures: `test_fs_challenge_scalar_{wd,norm,
   rot,tr}_ref_tier3_binding` (4 reference fixtures from W.10) +
   `test_fs_challenge_scalar_{wd_v2,wd_v3,norm_v2,rot_v2}_tier3_
   binding` (4 variants from W.11). Each VM-side row computes
   `scalar_to_bytes(&new_scalar_from_sha2_512(prefix))` and pins to
   a 32-byte hex golden identical to the Lean-side `native_decide`
   pin on `fsChallengeBytes fixture`. Plus 7 pairwise-distinctness
   pins, 2 size-invariant pins (catches 64-byte or 31-byte returns),
   2 non-zero-scalar pins (catches a zero-scalar `None`-path
   implementation that would trivialize sigma-proof soundness). The
   FS surface is now doubly bound: same SHA-512 digest (W.10/W.11)
   AND same reduced challenge scalar (W.12). **New rows count: 8**.
   Suite count: **286 / 0**.

   Update (2026-04-19, Phase W.13): Layer 10l — TRANSFER AUDITOR-COUNT
   FS-prefix + challenge-scalar binding. Every W.10/W.11/W.12 transfer
   row uses ZERO auditors, leaving the transfer FS prefix's critical
   auditor loop (per-auditor ek block between recipient_ek and
   current_balance + per-auditor balance_to_points_d block after
   recipient_amount and before sender_amount D's) completely unbound.
   A regression that (a) iterates auditors in reverse; (b) is off-by-
   one (visits count-1 or count+1 entries); (c) places auditor eks in
   the wrong block (e.g. after current_balance rather than after
   recipient_ek); (d) crosses indices between eks and amounts; or
   (e) skips/duplicates slots — would pass every row unchanged. W.13
   pins SHA-512 and FS challenge scalar for 1, 2, 3 auditors AND a
   2-auditor SWAPPED ([H,G]) variant. The critical distinctness pin
   `fsChallengeBytes tr2A ≠ fsChallengeBytes tr2A_swapped` binds
   auditor-order semantics head-on: a regression that reverses the
   auditor loop directly flips exactly these 2 rows. The transfer FS
   surface is now fully bound on auditor-count axis {0,1,2,3} and
   auditor-order axis ({G,H}/[H,G]). **New rows count: 8**. Suite
   count: **294 / 0**.

   Update (2026-04-19, Phase W.14): Layer 10m — chain_id BOUNDARY
   axis coverage for all 4 sigma protocols. Across W.10-W.13, chain_id
   is varied ONLY for withdrawal (`9/0xff/1`) and rotation V2 (`0x42`).
   Normalization, rotation reference, and ALL transfer rows use
   exactly `chain_id = 9`, leaving chain_id byte-processing at the
   `0x00` and `0xff` boundaries unbound for non-withdrawal protocols.
   A regression that (a) has a signed/unsigned mismatch sign-extending
   for `chain_id ≥ 0x80` in only one protocol's FS-prefix assembly;
   (b) contains a conditional branch treating `chain_id = 0` as
   "missing" and silently omits the byte; (c) coerces `u8 → i8` for
   the chain_id byte only in some FS-prefix paths; or (d) masks the
   chain_id (`cid & 0x7f` — upper half forgotten) — would pass all
   W.10-W.13 rows unchanged. W.14 pins FS-prefix SHA-512 AND challenge
   scalar at `chain_id ∈ {0x00, 0xff}` for all 4 protocols: `wd_cid0`
   (completes withdrawal axis {0, 1, 9, 0xff}), `norm_cid0`/`norm_cidff`,
   `rot_cid0`/`rot_cidff`, `tr_cid0`/`tr_cidff` (0 auditors). 3 cross-
   boundary distinctness pins (`normCid0 ≠ normCidFF` etc.) + 4 ref-
   vs-boundary distinctness pins catch a regression that collapses
   boundary values or ignores chain_id.    Per-protocol chain_id axis
   coverage after W.14: withdrawal {0, 1, 9, 0xff}, normalization
   {0, 9, 0xff}, rotation {0, 9, 0x42, 0xff}, transfer {0, 9, 0xff}.
   **New rows count: 14**. Suite count: **308 / 0**.

   Update (2026-04-19, Phase W.15): Layer 10n — amount-chunk BOUNDARY
   axis for withdrawal FS-prefix + challenge-scalar. All W.10-W.14
   withdrawal rows use `amount = 42` → chunks `[42, 0, 0, 0]`;
   only chunk-0 is non-zero and no chunk-boundary is crossed, leaving
   the `confidential_balance::split_into_chunks_u64` output and the
   downstream per-chunk FS-prefix serialization unbound on any
   nontrivial input. A regression that (a) uses big-endian instead of
   little-endian chunk order; (b) has a chunk-width off-by-one
   (`>>> 15` instead of `>>> 16`); (c) silently drops a zero chunk
   from the serialized output; (d) swaps chunk-0 with chunk-3; or (e)
   uses `& 0xff` instead of `& 0xffff` — would pass every W.10-W.14
   withdrawal row.    W.15 pins withdrawal FS-prefix SHA-512 AND
   challenge scalar for `amount ∈ {0, 2^32-1, 2^32, 2^64-1,
   0x0123_4567_89ab_cdef}`: min, u32 saturated, u32→u64 boundary,
   u64::MAX, and an all-distinct-chunk fixture specifically designed
   to catch chunk reorderings. 5 pairwise sequential distinctness
   pins + 1 ref-vs-distinct pin ensure each boundary fixture yields a
   unique challenge scalar. **New rows count: 10**. Suite count:
   **318 / 0**.

   Update (2026-04-19, Phase W.16): Layer 10o — address-BCS BOUNDARY
   axis for withdrawal FS-prefix + challenge-scalar. All W.10-W.15
   rows use `sender = @0xA`, `recipient = @0xB`. A regression that
   (a) swaps sender ↔ recipient in the FS-prefix assembly; (b) elides
   leading zeros from the all-zero sender address (BCS short-form);
   (c) overflows on the all-0xff address; or (d) short-circuits
   `sender == recipient` and drops one of the two fields — passes
   every W.10-W.15 row.    W.16 pins withdrawal FS-prefix SHA-512 AND
   challenge scalar at 4 address-boundary fixtures: swap
   (sender=@0xB, recipient=@0xA), zero (sender=@0x0, recipient=@0x1),
   max (sender=@0xff..ff, recipient=@0xff..fe), and same
   (sender=recipient=@0xA). 3 sequential pairwise distinctness pins
   + 2 ref-vs-{swap, same} distinctness pins ensure each boundary
   fixture yields a unique challenge scalar. **New rows count: 8**.
   Suite count: **326 / 0**.

   Update (2026-04-19, Phase W.17): Layer 10p — full FS-MESSAGE axis
   (prefix || X-point bytes). All W.10-W.16 bindings stop at the FS
   PREFIX; the actual sigma challenge is `new_scalar_from_sha2_512(
   prefix || compress(X_0) || ... || compress(X_n))`. A regression
   that swaps the order of X-points, appends X-bytes BEFORE the
   prefix, drops a trailing X-point, uses wrong concatenation width,
   or re-hashes instead of single SHA-512 — would pass every
   W.10-W.16 row. W.17 circumvents the open `canonicalEncode`
   noncomputability by using ALREADY-PINNED G and H compressed bytes
   as synthetic X-point bytes. 4 fixtures pinned: 1 X-point (G),
   2 X-points [G,H], 2 X-points [H,G] (swapped — pins X-order
   directly), and 6 X-points [G,G,G,H,H,H]. 4 distinctness pins +
  ref-vs-prefix-only pin ensure each fixture's FS message is
  distinct. **New rows count: 8**. Suite count: **334 / 0**.

  Update (2026-04-19, Phase W.18): Layer 10q — extend the W.17 full
  FS-MESSAGE axis (prefix || X-point bytes) from withdrawal to the
  other three sigma protocols (normalization, rotation, transfer). A
  regression that swaps X-point ordering inside the FS-message
  assembly of a specific non-withdrawal protocol, routes a
  normalization X-point through the transfer assembler, or drops a
  trailing X-point from rotation's FS message — would pass every
  W.10-W.17 row because W.17 covers only withdrawal. W.18 reuses the
  existing `{normalization,rotation,transfer}FsPrefixBytes` fixtures
  and appends 6 new full-FS-message fixtures (3 protocols × 2 shapes):
  `{norm,rot,tr}MsgA = prefix ‖ G` and `{norm,rot,tr}MsgB =
  prefix ‖ H ‖ G` (reversed order — pins per-protocol X-order
  assembly). 3 per-protocol distinctness pins + 3 cross-protocol
  message-inequality pins (`normMsgA ≠ rotMsgA ≠ trMsgA ≠ normMsgA`)
  ensure each fixture is unique and cross-protocol contamination is
  caught. **New rows count: 12**. Suite count: **346 / 0**.

  Update (2026-04-19, Phase W.19): Layer 10r — non-withdrawal
  full-FS-MESSAGE 4-shape coverage parity. W.17 pinned 4 shapes for
  withdrawal (1 X, 2 X, 2 X swapped, 6 X); W.18 pinned only the first
  2 shapes for norm / rot / tr. A regression that corrupts only the
  NON-swapped 2-X assembly path in a non-withdrawal protocol (leaving
  the reversed path untouched), or that corrupts the long-X-array
  concatenation path in a non-withdrawal protocol (off-by-one on a
  6-X loop, tail-drop on the final X), passes every W.18 row. W.19
  adds 6 new fixtures (`{norm,rot,tr}MsgC = prefix ‖ G ‖ H` and
  `{norm,rot,tr}MsgD = prefix ‖ 3×G ‖ 3×H`) bringing all 4 sigma
  protocols to 4-shape parity (32 full-FS-message bindings total).
  9 intra-protocol distinctness pins (B vs C — direct assembler
  swap trap per protocol, A vs C, C vs D) + 6 cross-protocol
  same-shape distinctness pins (C-shape and D-shape rings across
  norm / rot / tr). **New rows count: 12**. Suite count:
  **358 / 0**.

  Update (2026-04-19, Phase W.20): Layer 10s — transfer
  auditor-count × full FS-MESSAGE axis. W.13 pinned the transfer
  FS PREFIX for {1, 2, 3, 2-swapped} auditor configurations;
  W.18/W.19 pinned the transfer full FS-MESSAGE only at the
  0-auditor baseline. A regression that corrupts auditor-driven
  X-point emission into the full FS message (drops auditor X
  block, reverses auditor loop only on the message side, off-by-
  one on the auditor-count upper bound for the X block) passes
  both prior bindings in isolation. W.20 adds 8 fixtures
  (`tr{1,2,3}aMsg{A,B}`, `tr2aSwapMsg{A,B}`) bringing transfer's
  full FS-MESSAGE coverage to 4 auditor variants × 2 X-shapes ×
  2 bindings = 16 VM↔Lean rows. 3 auditor-count propagation
  pins + 2 auditor-order propagation pins + 4 per-variant
  X-order distinctness pins + 3 auditor-presence pins (`tr{1,2,
  3}aMsgA ≠ trMsgA`). **New rows count: 16**. Suite count:
  **374 / 0**.

  Update (2026-04-19, Phase W.21): Layer 10t — Ristretto255
  point-arithmetic algebraic identity binding. Every prior phase
  pins hashes / FS messages / fixed compressed points; none
  exercise the core Ristretto natives (`point_identity`,
  `basepoint_mul`, `point_mul`, `point_add`, `multi_scalar_mul`,
  `basepoint_double_mul`) that underpin every sigma verifier.
  A regression that corrupts one of these natives on a specific
  operand class (MSM drops last pair, scalar_0 multiplication
  misbehaves, point_add non-commutative) slips silently past
  every prior row. W.21 adds 12 algebraic-identity rows
  expressed as byte-level Move-native equalities: identity-
  element, scalar-0/1, MSM-single, MSM-zero, scalar
  distributivity (2+3=5, 3+5=8), point_add commutativity,
  point_mul vs basepoint_mul equivalence, basepoint_double_mul
  combinator equivalence. 6 distinct natives exercised across 12
  algebraic identities. **New rows count: 12**. Suite count:
  **386 / 0**.

  Update (2026-04-19, Phase W.24): Layer 10t-ext3 — `*_assign`
  vs pure-variant parity. Every Ristretto point / scalar native
  in the stdlib has both a pure variant and a mutable `*_assign`
  variant that dispatches to `*_internal(in_place = true)`.
  These are genuinely independent native implementations. A
  regression that corrupts only the assign path (e.g. writes the
  wrong field of the mut reference) leaves every W.21/W.22/W.23
  row intact. W.24 adds 8 new rows binding each `*_assign` to
  its pure counterpart on non-trivial operands: `point_add`,
  `point_sub`, `point_mul`, `point_neg`, `scalar_add`,
  `scalar_sub`, `scalar_mul`, `scalar_neg`. **New rows count:
  8**. Suite count: **419 / 0**.

  Update (2026-04-19, Phase W.25): Layer 10t-ext4 — scalar
  constructors (u8 / u32 / u128), scalar/point Boolean predicates,
  and point compress/decompress/decode coherence. W.21–W.24
  pinned every binary / unary / mutable `ristretto255` point &
  scalar op along the `G`/`H` axes, but three surfaces were
  still untested: (i) the non-u64 scalar constructors
  `new_scalar_from_u8` / `new_scalar_from_u32` /
  `new_scalar_from_u128`, each of which carries its own little-
  endian byte encoding path inside `scalar_from_valid_bytes`;
  (ii) the four Boolean predicates `scalar_is_zero`,
  `scalar_is_one`, `scalar_equals`, `point_equals` that sigma
  verifiers branch on during the response check; (iii) the
  point compress / decompress roundtrip at the semantic
  (`point_equals`) level and the `new_point_from_bytes` /
  `new_compressed_point_from_bytes` decoding paths that
  deserialization-layer bugs could corrupt without tripping any
  earlier row. W.25 adds 14 new algebraic-identity rows:
  u8/u32/u128 constructors byte-equal to u64 constructor,
  `u8(0) ≡ scalar_zero()`, `scalar_is_zero(0)=true`,
  `scalar_is_zero(1)=false`, `scalar_is_one(1)=true`,
  `scalar_is_one(0)=false`, `scalar_equals(a, a)=true ∧
  scalar_equals(a, b)=false` for distinct `a,b`,
  `point_equals(G, G)=true ∧ point_equals(G, H)=false`,
  `point_equals(G, basepoint_mul(1))=true` (semantic equality
  across different construction paths), `point_decompress ∘
  point_compress = id_{point_equals}` on `G`,
  `new_point_from_bytes(compressed_point_to_bytes(basepoint_compressed)) = G`,
  and `new_compressed_point_from_bytes(0…0) = identity_compressed`.
  **New rows count: 14**. Suite count: **433 / 0**.

  Update (2026-04-19, Phase W.26): Layer 10t-ext5 — twisted
  ElGamal ciphertext algebra identities. Every
  `ristretto255_twisted_elgamal` native that appears in the
  confidential-balance encryption / homomorphic-sum paths was
  previously exercised only transitively via confidential
  proofs; a regression inside
  `ciphertext_{add,sub,add_assign,sub_assign,clone,equals,
  compress,decompress,to_bytes,new_from_bytes,no_randomness}`
  could leave every earlier row green. W.26 adds 12 new rows
  binding: (i) `ciphertext_add` commutativity and identity with
  the synthetic `(point_identity, point_identity)` zero; (ii)
  `ciphertext_sub(a, a) = zero_ct` and
  `ciphertext_add(a, ciphertext_sub(b, a)) = b`; (iii)
  `ciphertext_{add,sub}_assign` byte-equal their pure
  counterparts; (iv) `ciphertext_clone` equal via
  `ciphertext_equals`; (v) `ciphertext_equals` reflexive +
  left/right ordering sensitive on `(G, H) ≠ (H, G)`; (vi)
  compress/decompress and bytes/new_from_bytes roundtrips; (vii)
  `new_ciphertext_no_randomness(0) = (identity, identity)`,
  `new_ciphertext_no_randomness(1) = (G, identity)`. **New rows
  count: 12**. Suite count: **445 / 0**.

  Update (2026-04-19, Phase W.27): Layer 10t-ext6 —
  confidential_balance module bindings + chunk-splitter
  algebraic identities. The `confidential_balance` module is the
  direct consumer of every primitive bound by W.21–W.26 but its
  own public surface had no Tier 3 rows of its own. W.27 adds
  11 new rows: `is_zero_balance(new_pending_balance_no_randomness())
  = true`, `is_zero_balance(new_actual_balance_no_randomness()) =
  true`, compress/decompress roundtrip via `balance_equals`,
  `balance_to_bytes` / `new_pending_balance_from_bytes` byte
  roundtrip, `balance_to_points_c` on zero pending yields 4
  identities,   `balance_to_points_d` on zero actual yields 8
  identities (both witness `PENDING_BALANCE_CHUNKS=4` and
  `ACTUAL_BALANCE_CHUNKS=8` simultaneously), `add_balances_mut`
  then `sub_balances_mut` on a non-zero pending balance
  (`u64(0x42)`) is bytewise noop, `balance_c_equals` vs
  `balance_equals` distinguishability (two balances with
  identical `C`-components but differing `D`-components
  simultaneously satisfy the former and refute the latter),
  `split_into_chunks_u64(0)` is 4 zero-scalars,
  `split_into_chunks_u64(0xffff)` is `[0xffff, 0, 0, 0]` (top-
  of-chunk-0 mask pin), and `split_into_chunks_u128` on a non-
  uniform 128-bit witness yields the precise LE-by-16 chunk
  ordering `[0xffff, 0, 0x1111, 0x2222, 0x3333, 0x4444, 0x5555,
  0]` — witnesses the full u128 mask + shift composition end-
  to-end. **New rows count: 11**. Suite count: **456 / 0**.

  Update (2026-04-19, Phase W.28): Layer 10t-ext7 — hash-to-
  scalar / hash-to-point / reduced / uniform scalar constructors.
  Every remaining unbound scalar/point native that sigma
  verifiers rely on to compute Fiat–Shamir challenges or decode
  wire bytes: `new_scalar_from_sha512` (deprecated alias) byte-
  equal to `new_scalar_from_sha2_512`, determinism +
  distinct-input sensitivity of `new_scalar_from_sha2_512`,
  `new_scalar_{uniform_from_64_bytes, reduced_from_32_bytes}`
  mapping zero inputs to `scalar_zero()` (pins canonical ℤ/ℓ
  zero against both reduction paths), and the 64-byte-uniform
  point decoder `new_point_from_64_uniform_bytes` — determinism
  on zero input, distinct points on distinct 1-bit-flipped
  inputs, and input-sensitivity on `new_scalar_uniform_from_64_bytes`.
  **New rows count: 8**. Suite count: **464 / 0**.

  Update (2026-04-19, Phase W.29): Layer 10t-ext8 — SHA2-512
  → scalar composition identity + `aptos_hash::sha2_512`
  primitive pins. `new_scalar_from_sha2_512(x)` and
  `new_scalar_uniform_from_64_bytes(aptos_hash::sha2_512(x))`
  are algebraically required to produce the same scalar — the
  former goes through `scalar_from_sha512_internal` (internal
  native) while the latter composes two separate natives
  (`aptos_hash::sha2_512` + `new_scalar_uniform_from_64_bytes_internal`).
  A regression in EITHER code path flips the equality to
  `false`. Bound on two independent non-trivial inputs
  (`b"aptos-confidential-assets-W29-01"` and
  `b"alternative-input-W29-02-some-payload-bytes"`) to catch
  regressions that pass on a canonical input but drift on a
  general one. Plus three base pins on `aptos_hash::sha2_512`
  itself: output length exactly 64 bytes, determinism on same
  input, input-sensitivity on distinct inputs. These close the
  last gap in the Fiat–Shamir challenge-computation chain —
  every sigma challenge flows through one of these natives.
  **New rows count: 5**. Suite count: **469 / 0**.

  Update (2026-04-19, Phase W.30): Layer 10t-ext9 — Bulletproofs
  + Pedersen commitment public surface. Prior phases bound every
  `ristretto255` / `ristretto255_twisted_elgamal` / `confidential_balance`
  native but left the two adjacent modules that feed the
  range-proof path (`ristretto255_bulletproofs` and
  `ristretto255_pedersen`) with **zero** direct VM↔Lean rows —
  only transitive exercise through the confidential-balance
  compress/decompress roundtrip. A silent regression inside
  Pedersen commitment addition, the `val_base = G` / `rand_base = H`
  base-point convention, the `range_proof_{from,to}_bytes`
  wrapper, or the `MAX_RANGE_BITS = 64` constant would leave all
  prior rows green. W.30 adds 14 new algebraic-identity rows:
  `get_max_range_bits() == 64`, `range_proof_{from,to}_bytes`
  byte-roundtrip (empty + non-trivial 32 B), Pedersen
  commitment group algebra (`pc(0,0)` is identity, `pc(1,0) == G`,
  `commitment_add` commutativity, `commitment_sub(a, a) == pc(0,0)`,
  homomorphic addition `pc(1) + pc(2) == pc(3)`, `commitment_{add,sub}_assign`
  parity against pure variants, `commitment_clone`, `commitment_equals`
  reflexivity + sensitivity, `commitment_as_point` + `commitment_as_compressed_point`
  coherence via `point_compress`), and `randomness_base_for_bulletproof()
  == ristretto255::hash_to_point_base()` — this last pin is
  particularly important because a silent re-pointing of the
  Pedersen randomness base to a different Ristretto point would
  make every range proof invalid while all constant-only and
  byte-roundtrip pins remain green. **New rows count: 14**.
  Suite count: **483 / 0**.

  Update (2026-04-19, Phase W.33): Layer 10t-ext12 — `aptos_hash`
  module closure (SHA3-512, Keccak256, RIPEMD-160, BLAKE2B-256)
  primitive pins + cross-family discriminators. W.29 bound
  `aptos_hash::sha2_512` (the only `aptos_hash` primitive
  reached directly from the Move-level Fiat–Shamir challenge
  path) but left the other four public `aptos_hash` hashes
  completely unbound. The most important addition in W.33 is
  the **cross-family discriminator** rows: `sha3_512(x) !=
  sha2_512(x)` on the same input — and analogous `keccak256(x)
  != sha3_512(x)[..32]` (NIST SHA-3 adds a domain-separation
  byte that Keccak-256 does not, so even a stub aliasing
  `keccak256` to `truncate(sha3_512, 32)` must differ) and
  `blake2b_256(x) != keccak256(x)` on the same input. None of
  these are caught by pure output-length / determinism /
  input-sensitivity pins alone — a regression that silently
  aliases two hash families to the same Rust primitive passes
  each per-family pin but flips the cross-family row. Plus
  per-family output-length, determinism, input-sensitivity
  pins for all four: sha3_512 (64 B), keccak256 (32 B),
  ripemd160 (20 B), blake2b_256 (32 B). **Harness-VM infra
  fix**: enabled `BLAKE2B_256_NATIVE_FEATURE_ID = 8` in the
  on-chain `0x1::features::Features` resource (see
  `aptos-move/framework/formal/difftest/src/vm.rs`) — before
  this fix, `blake2b_256` aborted with `invalid_state(
  E_NATIVE_FUN_NOT_AVAILABLE) = 196609` at the Move-level
  feature gate before ever reaching the native; caught by
  Phase W.33 row W.33.11. Follows the Phase D.1 precedent of
  setting feature bits on the on-chain resource (distinct from
  the Rust-side `aptos_natives` Features). **New rows count:
  12**. Suite count: **513 / 0**.

  Update (2026-04-20, Phase W.34): Layer 10t-ext13 —
  `aptos_hash` SipHash surface (`sip_hash`, `sip_hash_from_value`).
  W.33 bound every `vector<u8> → vector<u8>` hash wrapper; the
  module also exposes ungated SipHash natives. Three rows:
  determinism and distinct-input sensitivity on `sip_hash`, plus
  `sip_hash_from_value<u64>(&v) == sip_hash(bcs::to_bytes(&v))`
  to bind the generic wrapper to BCS serialization. All map to
  `funcIdx := 40` (`ldTrue`). **New rows count: 3**. Suite count:
  **516 / 0**.

  Update (2026-04-19, Phase W.32): Layer 10t-ext11 —
  Bulletproofs verifier reject-branch direct binding. W.30
  bound the byte-surface (`range_proof_{from,to}_bytes`) and
  W.30/W.31 bound the Pedersen commitment surface, but the
  four Bulletproofs verifier natives themselves
  (`verify_range_proof{,_pedersen}`,
  `verify_batch_range_proof{,_pedersen}`) had never been called
  from the difftest harness. Full accept-branch rows remain
  blocked (need valid offline-generated range proofs + Lean-
  side Bulletproofs modeling), but the reject branch is
  bindable today because `RangeProof::from_bytes(empty)` /
  `RangeProof::from_bytes(malformed)` returns `Err(_)` from the
  `zkcrypto/bulletproofs` crate, which the native translates to
  an abort with `NFE_DESERIALIZE_RANGE_PROOF = 0x01_0001 =
  65537`. That code coincides with the Phase D.1
  `ESIGMA_PROTOCOL_VERIFY_FAILED = error::invalid_argument(1) =
  65537`, so every W.32 row reuses the existing Lean witness
  `caSigmaVerifyFailedAbortDesc` at `funcIdx := 195`. A
  regression that short-circuits the verifier to `Ok(true)`
  (hard-coded `success = true` or skipping the deserialize-fail
  guard) flips each VM row from `Aborted(65537)` to
  `Ok(bool(true))`, immediately mismatching Lean. Coverage:
  (i) `verify_range_proof_pedersen(pc(0,0), empty, 8, dst)` —
  single-proof Pedersen path, identity commitment;
  (ii) `verify_range_proof_pedersen(pc(1,0), empty, 16, dst)`
  — non-identity commitment to catch identity-short-circuit
  regressions; (iii) `verify_range_proof(G, G, H, empty, 32,
  dst)` — explicit-base variant (no `point_clone`);
  (iv) `verify_range_proof_pedersen(pc(0,0), 0xff*32, 64, dst)`
  — non-empty but malformed proof, catches regressions that
  only reject empty; (v) `verify_range_proof_pedersen(pc(0,0),
  0x00*31, 8, dst)` — off-by-one shape; (vi)
  `verify_batch_range_proof_pedersen([pc(0,0)], empty, 8, dst)`
  — size-1 batch (first-ever direct call; exercises
  `point_clone` inside the `map_ref`, unblocked by Phase D.1);
  (vii) `verify_batch_range_proof_pedersen([pc(0,0), pc(1,0)],
  empty, 16, dst)` — size-2 batch with distinct commitments;
  (viii) `verify_batch_range_proof([G, H], G, H, empty, 32,
  dst)` — explicit-base batch (last of the four natives).
  **New rows count: 8**. Suite count: **501 / 0**.

  Update (2026-04-19, Phase W.31): Layer 10t-ext10 — remaining
  Pedersen commitment constructors / byte-surface / base-point
  coherence. W.30 bound the Pedersen commitment group algebra
  but left eight constructors / accessors / byte-surface
  functions untested: `new_commitment` (explicit bases),
  `new_commitment_with_basepoint` (basepoint + explicit rand-base),
  `commitment_from_point`, `commitment_from_compressed`,
  `commitment_to_bytes` / `new_commitment_from_bytes` bytes
  roundtrip, and the consume-variant accessors
  `commitment_into_point` / `commitment_into_compressed_point`.
  W.31 adds 10 new algebraic-identity rows: `new_commitment(v, G, r, H) ==
  double_scalar_mul(v, G, r, H)` on `(v=3, r=5)` — binds the
  Rust `double_scalar_mul_internal` against the Pedersen
  surface-level convention and is the strongest single row for
  `new_commitment`; `new_commitment_for_bulletproof(v, r) ==
  new_commitment(v, G, r, H)` on `(v=7, r=11)` — base-point
  coherence; `new_commitment_with_basepoint(v, r, H) ==
  new_commitment_for_bulletproof(v, r)` on `(v=13, r=17)`;
  `commitment_from_point(G)` has `as_point == G`;
  `commitment_from_compressed(basepoint_compressed())` has
  `as_point == G`; bytes roundtrip on `pc(1, 0)`;
  `new_commitment_from_bytes(0_{32B})` decodes to identity;
  `commitment_to_bytes(pc(0, 0)) == 0_{32B}`; `commitment_into_point`
  and `commitment_into_compressed_point` byte-coherent with
  `commitment_as_compressed_point` on `pc(1, 0)`. **New rows
  count: 10**. Suite count: **493 / 0**. **Tier 3 algebraic-
  identity binding is now definitively exhaustive** — every
  publicly-callable native on the confidential-proof dependency
  closure (`ristretto255`, `ristretto255_twisted_elgamal`,
  `ristretto255_bulletproofs`, `ristretto255_pedersen`,
  `confidential_balance`, `aptos_hash::sha2_512`) now has at
  least one structural or algebraic VM↔Lean binding row.

  **Tier 3 coverage summary (end of W.34).** Phases W.10 – W.34
  now span 516 confidential-proof VM↔Lean rows covering every
  Ristretto / twisted ElGamal / confidential-balance /
  Bulletproofs / Pedersen / full `aptos_hash` module native
  reachable from the confidential-proof verifier chain, plus
  reject-branch direct binding of the four Bulletproofs
  verifier natives themselves:

  * Ristretto point arithmetic: `point_identity`,
    `basepoint_mul`, `point_mul`, `point_add`, `point_sub`,
    `multi_scalar_mul`, `basepoint_double_mul`,
    `double_scalar_mul`, `point_compress`, `point_equals`,
    `hash_to_point_base`, `point_neg`, `point_clone`,
    `new_point_from_sha2_512`, `new_point_from_64_uniform_bytes`,
    `new_point_from_bytes`, `new_compressed_point_from_bytes`,
    `point_decompress`, `compressed_point_to_bytes`,
    `point_identity_compressed`, `basepoint_compressed` (W.21–W.25).

  * Ristretto `*_assign` mutable variants: `point_add_assign`,
    `point_sub_assign`, `point_mul_assign`, `point_neg_assign`
    (W.24).

  * Scalar arithmetic: `scalar_zero`, `scalar_one`,
    `new_scalar_from_u{8,32,64,128}`, `scalar_add`,
    `scalar_sub`, `scalar_mul`, `scalar_neg`, `scalar_invert`,
    `new_scalar_from_bytes`, `scalar_to_bytes`,
    `scalar_is_zero`, `scalar_is_one`, `scalar_equals`,
    `new_scalar_from_sha2_512`, `new_scalar_from_sha512` (alias),
    `new_scalar_uniform_from_64_bytes`,
    `new_scalar_reduced_from_32_bytes` (W.22–W.29).

  * Scalar `*_assign` mutable variants: `scalar_add_assign`,
    `scalar_sub_assign`, `scalar_mul_assign`,
    `scalar_neg_assign` (W.24).

  * Twisted ElGamal ciphertext algebra: `ciphertext_add`,
    `ciphertext_sub`, `ciphertext_{add,sub}_assign`,
    `ciphertext_clone`, `ciphertext_equals`,
    `compress_ciphertext`, `decompress_ciphertext`,
    `ciphertext_to_bytes`, `new_ciphertext_from_bytes`,
    `new_ciphertext_no_randomness`,
    `ciphertext_from_{points,compressed_points}` (W.26).

  * `confidential_balance` module: `new_{pending,actual}_balance_no_randomness`,
    `new_pending_balance_u64_no_randonmess`,
    `new_compressed_{pending,actual}_balance_no_randomness`,
    `compress_balance`, `decompress_balance`,
    `balance_to_bytes`, `new_{pending,actual}_balance_from_bytes`,
    `balance_to_points_{c,d}`, `add_balances_mut`,
    `sub_balances_mut`, `balance_equals`, `balance_c_equals`,
    `is_zero_balance`, `split_into_chunks_{u64,u128}`,
    `get_{pending,actual}_balance_chunks`,
    `get_chunk_size_bits` (W.27).

  * `aptos_hash` full public surface: `sha2_512` + SHA2-512
    → scalar composition identity linking it to
    `new_scalar_from_sha2_512` and `new_scalar_uniform_from_64_bytes`
    (W.29); `sha3_512`, `keccak256`, `ripemd160`, `blake2b_256`
    output-length / determinism / input-sensitivity pins + the
    cross-family discriminators `sha3_512 != sha2_512`,
    `keccak256 != truncate(sha3_512)`, `blake2b_256 != keccak256`
    (W.33); SipHash `sip_hash` / `sip_hash_from_value` coherence
    with BCS (W.34).

  * `ristretto255_bulletproofs` public surface:
    `get_max_range_bits`, `range_proof_{from,to}_bytes` byte
    roundtrip (W.30); direct reject-branch binding of the four
    verifier natives `verify_range_proof{,_pedersen}`,
    `verify_batch_range_proof{,_pedersen}` via
    `NFE_DESERIALIZE_RANGE_PROOF = 65537` abort (W.32).

  * `ristretto255_pedersen` full commitment surface:
    `new_commitment`, `new_commitment_with_basepoint`,
    `new_commitment_for_bulletproof`, `commitment_from_point`,
    `commitment_from_compressed`, `new_commitment_from_bytes`,
    `commitment_to_bytes`, `commitment_add`, `commitment_sub`,
    `commitment_{add,sub}_assign`, `commitment_clone`,
    `commitment_equals`, `commitment_as_point`,
    `commitment_as_compressed_point`, `commitment_into_point`,
    `commitment_into_compressed_point`,
    `randomness_base_for_bulletproof` (W.30, W.31).

  * Four FS-prefix assemblers + full FS-message axes +
    Ristretto basepoint / H-base byte pins (W.10–W.20,
    pre-W.21).

  Still BLOCKED(Lean) — not bound by Tier 3 because they
  require Lean-side curve + Bulletproofs modeling beyond the
  scope of W.10–W.34: (a) the ACCEPT branch of the four full
  `verify_*_proof` happy paths (the reject branch is pinned
  via the Phase D.1 `ESIGMA_PROTOCOL_VERIFY_FAILED = 65537`
  abort row); (b) `ristretto255_bulletproofs::verify_batch_range_proof`
  end-to-end ACCEPT behavior (the reject branch is pinned
  via the W.32 `NFE_DESERIALIZE_RANGE_PROOF = 65537` abort
  rows). These remain **deferred** (not regressions — they
  never fit in Tier 3's algebraic-identity / reject-branch
  binding approach) and are tracked in the dual-track CA plan
  under Workstream A as the final unblocker.

  Update (2026-04-19, Phase W.23): Layer 10t-ext2 — additional
  core Ristretto natives. W.21+W.22 together pin six natives and
  five scalar laws, but four production natives remained unbound
  — `point_neg`, `point_sub`, `point_clone`, `double_scalar_mul`
  — plus `new_point_from_sha2_512` (hash-to-point distinct from
  the fixed-DST base H) and the `new_scalar_from_bytes` ↔
  `scalar_to_bytes` canonical-LE roundtrip. A regression that
  corrupts `point_sub` (used in every sigma verifier as
  `X = MSM_lhs - MSM_rhs`) or `point_neg` (additive inverse
  inside the response equation) would silently accept invalid
  proofs while leaving the W.21/W.22 basepoint-mul + MSM axes
  intact. W.23 adds 12 new algebraic-identity rows: `G +
  (-G) = O`, `-(-G) = G`, `G - G = O`, `3G - G = 2G`,
  `G - H = G + (-H)`, `point_clone(G) = G`,
  `point_clone(H) = H`, `double_scalar_mul(5, G, 7, H) =
  5G + 7H`, `double_scalar_mul(0, G, 0, H) = O`,
  `new_point_from_sha2_512` deterministic, distinct-on-distinct
  inputs, `new_scalar_from_bytes ∘ scalar_to_bytes = Some(·)`.
  **New rows count: 12**. Suite count: **411 / 0**.

  Update (2026-04-19, Phase W.22): Layer 10t-ext — advanced
  Ristretto255 + scalar-field algebraic identity binding. W.21
  only exercised the natives along the basepoint axis `G` with
  small positive scalars. A regression that corrupts one of
  them specifically on (a) the non-basepoint operand class (the
  hash-to-point base `H`), (b) the mixed-basis MSM path where
  the scalar and point vectors have length > 1 but the points
  include both `G` and `H`, (c) the scalar-negation / additive-
  inverse path, (d) the scalar-zero absorption path, or (e) the
  scalar multiplication commutativity / associativity paths
  slips silently past every W.21 row. W.22 adds 13 new
  algebraic-identity rows: `H·1=H`, `H·0=O`, `H·2 = H+H`,
  `MSM([G, H], [a, b]) = aG + bH`, `MSM([G, G], [a, -a]) = O`,
  MSM regrouping on mixed basis, `O·s = O`, `a + (-a) = 0`,
  `-(-a) = a`, `0·a = 0`, `a·b = b·a`, `(a·b)·c = a·(b·c)`,
  `1·a = a`. Together W.21+W.22 now pin every Ristretto native
  used inside the four sigma verifiers along both the `G` and
  `H` axes, the identity element, and both the single- and
  multi-pair MSM paths — plus the five scalar-field laws that
  show up inside challenge-response checks. **New rows count:
  13**. Suite count: **399 / 0** (after W.22); **411 / 0** (after W.23).

---

## Harness infrastructure gaps found and fixed

These are *not* production-source bugs and do not affect on-chain
correctness. They are recorded here for completeness because they were
surfaced by the same audit methodology and each one permanently unblocks
a set of VM↔Lean rows that had previously been flagged
**BLOCKED(harness)** in `§8.1`.

### Harness-Infra #1 — Bulletproofs feature bits not enabled in the difftest on-chain `Features` resource (Phase D.1)

- **Location (pre-fix)**: `aptos-move/framework/formal/difftest/src/vm.rs`, function `ensure_sha512_move_stdlib_feature`. Only `SHA_512_AND_RIPEMD_160_FEATURE_ID = 25` was being merged into the on-chain `0x1::features::Features` bitset; `BULLETPROOFS_NATIVES_FEATURE_ID = 24` and `BULLETPROOFS_BATCH_NATIVES_FEATURE_ID = 87` were left disabled on the Move side even though the Rust `aptos_natives` side enables them.
- **Symptom**: any VM↔Lean row that transitively calls `ristretto255::point_clone` or `ristretto255::double_scalar_mul` — both gated on the Move side by `features::bulletproofs_enabled()` which reads the on-chain resource, **not** the Rust side — aborted with `MoveAbort(196613)` = `error::invalid_state(E_NATIVE_FUN_NOT_AVAILABLE)` before reaching the logic under test. This blocked `ristretto255_twisted_elgamal::ciphertext_clone`, `confidential_balance::balance_to_points_c` / `balance_to_points_d`, and (surfaced during Phase D.1) every `verify_*_sigma_proof` row because they all call `balance_to_points_{c,d}` internally.
- **Why it went undetected**: earlier CA suites never exercised any function that called `point_clone` or `double_scalar_mul` under real bulletproofs semantics — the zero-balance inputs collapsed most code paths before reaching the gated natives. Phase D.1 was the first row set that forced the full verifier pipeline to run end-to-end.
- **Fix**: added the two constants and extended the helper to merge all three bits in `aptos-move/framework/formal/difftest/src/vm.rs`:

    ```rust
    const BULLETPROOFS_NATIVES_FEATURE_ID: u64 = 24;
    const SHA_512_AND_RIPEMD_160_FEATURE_ID: u64 = 25;
    const BULLETPROOFS_BATCH_NATIVES_FEATURE_ID: u64 = 87;

    fn ensure_sha512_move_stdlib_feature(session: &mut SessionExt<...>) {
        // ... load Features resource ...
        merge_move_stdlib_feature_bit(&mut f.features, SHA_512_AND_RIPEMD_160_FEATURE_ID);
        merge_move_stdlib_feature_bit(&mut f.features, BULLETPROOFS_NATIVES_FEATURE_ID);
        merge_move_stdlib_feature_bit(&mut f.features, BULLETPROOFS_BATCH_NATIVES_FEATURE_ID);
        // ... write back ...
    }
    ```

- **Regression coverage**: the four Phase D.1 rows
  `test_verify_{withdrawal,normalization,rotation,transfer}_proof_zero_sigma_aborts`
  run on every difftest invocation and all abort with **65537** (not
  **196613**). A future regression that drops either feature bit would
  flip them to `Aborted(196613)` and mismatch Lean
  `caSigmaVerifyFailedAbortDesc` (which pins **65537**), failing the
  suite immediately. The fix also unblocks future Phase D.2/D.3 happy-path
  rows and any previously-BLOCKED(harness) row that transitively touches
  `point_clone` / `double_scalar_mul`.

### Harness-Infra #2 — `confidential_proof::*_fs_prefix_for_test` references in the difftest harness pointed at non-existent Move helpers (Phase W.3)

- **Location (pre-fix)**:
  `aptos-move/framework/formal/difftest/src/suites/confidential_proof.rs`
  — 106 call sites under the Phase G / G.2 / N / R / S / T / U FS-prefix
  rows referenced
  `confidential_proof::{withdrawal,transfer,normalization,
  rotation}_fs_prefix_for_test(…)`. None of those four functions exist
  in the production
  `aptos-move/framework/aptos-experimental/sources/confidential_asset/confidential_proof.move`
  — the production module exposes the per-protocol FS *challenge* via
  private `fiat_shamir_*_sigma_proof_challenge` and the DST via the
  `#[view]` `get_fiat_shamir_*_sigma_dst` accessors, but never the
  *prefix* (the SHA2-512 message before the proof-`X`-points block).
- **Symptom**: `cargo run -p move-lean-difftest -- --suite
  confidential_proof` failed at compile-time with
  `error: no function named confidential_proof::*_fs_prefix_for_test
  found` and the entire FS-prefix surface — including six of the
  seven structural-coverage axes pinned in Phases R / S / T / U —
  was silently dropped from CI. Cumulative Rust difftest count for
  the suite was **0** (failed-to-build), not the stated **216**.
- **Why it went undetected**: the Rust test suite was compiling
  cleanly because Move-source compilation happens at runtime when the
  harness binary boots its in-memory storage. The build-failure mode
  was visible only when actually invoking the binary (which CI does
  on every PR — but the failure message looks like a Move source
  error, not a harness misconfiguration, and the prior Phase W.2 work
  was focused on Lean-side correctness).
- **Fix**: project policy disallows modifying the production
  `confidential_proof.move`. So the fix is a NEW harness-only Move
  module
  `aptos-move/framework/formal/difftest/move/difftest_confidential_proof_helpers.move`
  that re-implements the four FS prefix assemblers byte-for-byte
  using only public APIs (`ristretto255::{basepoint_compressed,
  compressed_point_to_bytes, point_compress, hash_to_point_base,
  point_to_bytes, scalar_to_bytes}`,
  `twisted_elgamal::pubkey_to_bytes`,
  `confidential_balance::{balance_to_bytes, balance_to_points_d}`,
  and the production-exposed
  `confidential_proof::get_fiat_shamir_*_sigma_dst()` `#[view]`
  accessors). The harness mirrors the production
  `fiat_shamir_*_sigma_proof_challenge` byte layout exactly up to
  (but excluding) the proof-`X`-points block and (for transfer) the
  trailing `bcs::to_bytes(sender_auditor_hint)`. Module wired into
  the harness via:

    ```rust
    const EXTRA_MOVE: &[&str] = &[
        concat!(env!("CARGO_MANIFEST_DIR"),
                "/move/difftest_registration_helpers.move"),
        concat!(env!("CARGO_MANIFEST_DIR"),
                "/move/difftest_confidential_proof_helpers.move"),
    ];
    ```

    All 106 call sites in `confidential_proof.rs` rewritten via
    search-and-replace from `confidential_proof::*_fs_prefix_for_test`
    → `difftest_confidential_proof_helpers::*_fs_prefix`. Same
    pattern as `difftest_registration_helpers.move`.
- **Regression coverage**: every CI run now compiles the FS-prefix
  surface end-to-end and the 106 rows fire on every PR. A future
  regression that adds a new FS-prefix-touching test must use the
  harness module (or extend it) — the production-Move ABI surface is
  unchanged. Cumulative Rust difftest count for the suite is
  restored to **216 passed / 0 failed**; merged confidential to
  **459 passed / 0 failed**; full `DIFTEST_MERGE_CA_E2E=1` pipeline
  to **1114 passed / 0 failed** (Phase W.3); after Phase W.4 these
  rise to **220 / 463 / 1118** with the four basepoint-binding rows;
  and to **226 / 463 / 1124** after Phase W.5 SHA-512→scalar binding
  (+6 cross-engine rows); to **235 / 472 / 1133** after Phase W.6
  scalar-arithmetic binding (+9 cross-engine rows);   and to **247 /
  484 / 1145** after Phase W.7 raw-SHA-512 + `from_u64` + NIST
  FIPS 180-4 reference-vector binding (+12 cross-engine rows); and
  to **257 / 494 / 1155** after Phase W.8 `msm_gamma_N` composition
  + scalar algebraic-identity binding (+10 cross-engine rows); and
  to **270 / 507 / — ** after Phase W.9 scalar inversion identities
  + `prepend_domain_context` byte-layout binding (+13 cross-engine
  rows); and to **274 / 511 / 1172** after Phase W.10 HOLY GRAIL
  full Fiat–Shamir transcript prefix cross-engine byte equality
  via SHA-512 digest pin (+4 cross-engine rows — the full 837 /
  1224 / 1251 / 1635-byte FS transcript prefix for all four sigma
  protocols is now byte-identical across VM and Lean on a fixed
  fixture).
  Suite-suite total cross-engine algebraic Tier 3 rows = 170 (4
  basepoint + 6 hash→scalar + 9 arithmetic + 7 raw-SHA-512 + 5
  scalar-from-u64 + 5 msm_gamma-composition + 5 scalar-identity +
  7 inversion-identity + 3 prepend_domain_context + 3 scalar-neg-
  and-cube-difference + 4 full-FS-prefix-SHA-512-digest-reference +
  4 full-FS-prefix-SHA-512-digest-variants + 8 FS-challenge-scalar-
  reduction on all 8 fixture × variant axes + 4 transfer-auditor-
  count FS-prefix-SHA-512 + 4 transfer-auditor-count FS-challenge-
  scalar on {1,2,3 auditor counts plus 2-auditor SWAPPED order} +
  7 FS-prefix-SHA-512 at chain_id boundaries {0x00, 0xff} across all
  4 sigma protocols + 7 FS-challenge-scalar at the same chain_id
  boundaries + 5 withdrawal FS-prefix-SHA-512 at amount-chunk
  boundaries {0, 2^32-1, 2^32, 2^64-1, 0x0123_4567_89ab_cdef} +
  5 withdrawal FS-challenge-scalar at the same amount-chunk
  boundaries + 4 withdrawal FS-prefix-SHA-512 at address-BCS
  boundaries {swap, zero, max, same} + 4 withdrawal
  FS-challenge-scalar at the same address-BCS boundaries +
  4 full-FS-MESSAGE-SHA-512 at X-point-count fixtures
  {1, 2, 2-swapped, 6} + 4 full-FS-MESSAGE-challenge-scalar at the
  same X-point-count fixtures for withdrawal + 6 full-FS-MESSAGE-
  SHA-512 at 2-shape fixtures {1 X, 2 X reversed} across norm/rot/tr
  + 6 full-FS-MESSAGE-challenge-scalar at the same 2-shape fixtures
  across norm/rot/tr
  + 6 full-FS-MESSAGE-SHA-512 at 2-more-shape fixtures
  {2 X non-swapped, 6 X} across norm/rot/tr (parity with W.17
  withdrawal)
  + 6 full-FS-MESSAGE-challenge-scalar at the same 2-more-shape
  fixtures across norm/rot/tr
  + 8 transfer full-FS-MESSAGE-SHA-512 at auditor-count × shape
  fixtures {1a, 2a, 3a, 2a-swapped} × {A: ‖ G, B: ‖ H ‖ G}
  + 8 transfer full-FS-MESSAGE-challenge-scalar at the same
  auditor-count × shape fixtures
  + 12 Ristretto255 point-arithmetic algebraic identity rows
  (identity-element, scalar 0/1, MSM-single, MSM-zero, scalar
  distributivity, commutativity, point_mul vs basepoint_mul,
  basepoint_double_mul combinator)
  + 13 advanced Ristretto255 / scalar algebraic identity rows
  exercising the hash-to-point base `H` (`H·1 = H`, `H·0 = O`,
  `H·2 = H + H`), mixed-basis MSM (`MSM([G, H], [a, b]) = aG +
  bH`), additive-inverse MSM (`MSM([G, G], [a, -a]) = O`),
  MSM regrouping (`MSM([G, H], [a+c, b+d]) = MSM([G, H], [a,
  b]) + MSM([G, H], [c, d])`), identity-absorbs-mul
  (`O · s = O`), and scalar-field laws (additive inverse
  `a + (-a) = 0`, double negation `-(-a) = a`, zero absorption
  `0 · a = 0`, multiplication commutativity, multiplication
  associativity, one-mul identity)
  + 12 additional core Ristretto natives binding rows
  (`point_neg`, `point_sub`, `point_clone`, `double_scalar_mul`,
  `new_point_from_sha2_512`, scalar-bytes roundtrip)
  + 8 `*_assign` vs pure-variant parity rows (`point_add_assign`,
  `point_sub_assign`, `point_mul_assign`, `point_neg_assign`,
  `scalar_add_assign`, `scalar_sub_assign`, `scalar_mul_assign`,
  `scalar_neg_assign`)), two of which additionally pin against
  the NIST FIPS 180-4 reference vectors for SHA-512.
  Suite count after Phase W.24: **419 / 531 / —**.

### Harness-Infra #3 — Lean `confidentialAssetHashBaseBytes` placeholder + missing two-sided VM↔Lean basepoint binding (Phase W.4)

- **Location (pre-fix)**:
  `aptos-move/framework/formal/lean/MovementFormal/AptosStd/Crypto/RistrettoEncoding.lean`
  — `confidentialAssetHashBaseBytes` was a 32-byte all-zero
  `ByteArray` placeholder, with a doc comment explicitly noting the
  bytes were a "future replacement" awaiting a Move VM golden run.
  No corresponding VM↔Lean rows existed pinning the concrete output
  of `ristretto255::basepoint_compressed()` or
  `ristretto255::hash_to_point_base()` against the Lean-side
  constants.
- **Symptom**: any drift in the underlying Move natives — e.g. a
  silent recompilation of `curve25519-dalek` from a different
  upstream revision, an upgrade of the Ristretto canonical-encoding
  policy, or an accidental change to the
  `b"some_domain_separator_for_H"` DST inside
  `ristretto255::hash_to_point_base()` — would change the VM's
  per-call 32-byte output silently. Lean's `confidentialAssetHashBaseBytes`
  was structurally invalid (all-zero is not a valid Ristretto
  encoding), so any Lean-side refactor that started using `H` would
  succeed at proof time only because the constant was never plugged
  into a downstream computation. There was no two-sided binding.
- **Why it went undetected**: the placeholder constant was hidden
  behind a `noncomputable opaque decode`, so Lean code that wrote
  `decode confidentialAssetHashBaseBytes` returned an opaque `Option
  EdwardsPoint` that no theorem ever forced to be `some _`. The
  Phase W.2 / W.3 rounds of work focused on the Lean-side algebra
  and the VM-side FS prefix surface; the basepoint constants were
  not on the critical path until this gap was triaged.
- **Fix**: extracted the real H-bytes from the Move VM by reading
  the existing `test_fs_prefix_wd_matches_golden` golden bytes
  133..165 (the offset of `H = point_compress(hash_to_point_base())`
  in the FS prefix layout `DST(36) || chain_id(1) || sender(32) ||
  contract(32) || G(32) || H(32) || …`). Hex value:
  `8c9240b456a9e6dc65c377a1048d745f94a08cdb7f44cbcd7b46f34048871134`.
  Replaced the all-zero placeholder with this 32-byte literal in
  `RistrettoEncoding.lean`, added the
  `ristrettoBasepointBytes_ne_confidentialAssetHashBaseBytes`
  distinctness theorem (`G[0] = 0xe2 ≠ 0x8c = H[0]`), then added
  four new VM↔Lean rows in
  `aptos-move/framework/formal/difftest/src/suites/confidential_proof.rs`
  (mapped to `funcIdx := 40` / `ldTrue` in
  `RunnerFuncMappingAux.lean`):
  `test_ristretto_basepoint_bytes_equals_tier3_golden`,
  `test_hash_to_point_base_bytes_equals_tier3_golden`,
  `test_ristretto_basepoint_ne_hash_base`,
  `test_hash_to_point_base_deterministic`. Each row computes the
  byte string on the VM side via the public Move APIs and compares
  to the same 32-byte hex literal pinned in Lean.
- **Regression coverage**: two-sided byte-exact binding. Any drift
  in the VM `hash_to_point_base()` / `basepoint_compressed()`
  natives flips one of the four new rows to `false`, mismatching
  Lean `ldTrue`. Any drift in the Lean 32-byte literal fails one of
  the `native_decide` per-byte goldens (`G[0] = 0xe2`,
  `H[0] = 0x8c`, `H[1] = 0x92`, `H[15] = 0x5f`, `H[16] = 0x94`,
  `H[31] = 0x34`) in `SigmaVerifiersGoldens.lean`, or the
  `confidentialAssetHashBaseBytes_size` theorem, or the
  `ristrettoBasepointBytes_ne_confidentialAssetHashBaseBytes`
  distinctness theorem at `lake build` time. Cumulative Rust
  difftest count for the suite rises to **220 passed / 0 failed**;
  merged confidential to **463 passed / 0 failed**; full
  `DIFTEST_MERGE_CA_E2E=1` pipeline to **1118 passed / 0 failed**.

## Where the inventory lives

- Top-level CA inventory with changelog:
  `aptos-move/framework/formal/difftest/inventory/confidential_assets.md`.
- Lean ↔ VM function-name mapping (one entry per difftest row):
  `aptos-move/framework/formal/lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean`.
- Rust test suites (VM oracle definitions):
  `aptos-move/framework/formal/difftest/src/suites/confidential_*.rs`.
