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
8. **Phases G.2 / H / I / J / K / L / M / N / O / P / Q / R / R.1 / S / T / U** — sixteen further
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
  + `confidential_proof`). None of these sixteen phases surfaced a
  production bug; each is a *latent regression class* newly pinned,
  recorded here for completeness in the "bug-catching audit trail"
  sense. Together, Phases R / S / T / U pin the FS prefix surface
  byte-for-byte across **six fixture axes** (0/1/2-auditor;
  zero/one-side-nonzero/both-nonzero-distinct balance) and **three
  amount-chunk axes** (single / uniform / pairwise-distinct).
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

## Where the inventory lives

- Top-level CA inventory with changelog:
  `aptos-move/framework/formal/difftest/inventory/confidential_assets.md`.
- Lean ↔ VM function-name mapping (one entry per difftest row):
  `aptos-move/framework/formal/lean/MovementFormal/DiffTest/RunnerFuncMappingAux.lean`.
- Rust test suites (VM oracle definitions):
  `aptos-move/framework/formal/difftest/src/suites/confidential_*.rs`.
