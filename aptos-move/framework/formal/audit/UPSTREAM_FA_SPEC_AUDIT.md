# Upstream `aptos_framework` FA spec audit — `audit/UPSTREAM_FA_SPEC_AUDIT.md`

**Scope:** Plan §8 Open Q 3 asks whether `aptos_framework::fungible_asset` specs are sufficient
for CA Phase 5 composition. This doc reviews what's upstream, what CA consumes, and what gaps
exist.

## Upstream specs exist

| File | Size | Contents |
|---|---|---|
| `aptos-move/framework/aptos-framework/sources/fungible_asset.spec.move` | 140 lines | 11 high-level requirements documented; one `pragma verify = false` at module level due to `object_metadata` (unsupported quantifier) |
| `aptos-move/framework/aptos-framework/sources/primary_fungible_store.spec.move` | 140 lines | Helper spec funs `spec_primary_store_exists` / `spec_primary_store_address` + spec bodies |

## High-level requirements documented in `fungible_asset.spec.move`

The 11 `<high-level-req>` entries cover (excerpted):

| # | Requirement | Criticality | Enforcement |
|---|---|---|---|
| 1 | Metadata size constraints | Medium | Audited |
| 2 | `add_fungibility` initializes Metadata + Supply | Low | Audited |
| 3 | Mint/burn/transfer refs only at creation | Low | Audited |
| 4 | **Only store owner may withdraw** | **High** | Audited |
| 5 | **Transfer/withdraw/deposit preserves total supply** | **High** | Audited |
| 6 | (...) | | |
| 7 | (...) | | |
| 8 | (...) | | |
| 9 | (...) | | |
| 10 | (...) | | |
| 11 | (...) | | |

## CA consumption surface

CA entry-point specs in `confidential_asset.spec.move` reference FA-side effects through
these module-boundary calls (ordered by criticality):

| CA entry point | FA call | What CA needs from the FA spec |
|---|---|---|
| `deposit_to` | `primary_fungible_store::ensure_primary_store_exists` + `dispatchable_fungible_asset::transfer` | (a) post-call: recipient store exists; (b) total supply unchanged; (c) sender balance decreased by `amount`, recipient balance increased by `amount` |
| `withdraw_to` | `primary_fungible_store::transfer` (from protocol store to recipient) | Same (c) inverted direction; protocol store balance decreased, recipient increased. |
| `confidential_transfer` | (no FA side-effect; all motion is in the protocol's encrypted ciphertexts) | — |
| `register` | No direct FA side-effect; creates a `ConfidentialAssetStore` only | Verifies upstream `object::*` specs around store creation (separate review) |

Requirements 4 and 5 (critical) are precisely what CA composes against for `deposit_to` /
`withdraw_to`.

## Audit verdict

**Sufficient for Phase 5 structural composition** — the upstream specs are:
- **Strong on what CA critically needs**: requirement 4 (owner-only withdraw) + requirement 5
  (supply preservation) are exactly the FA-side invariants CA's `deposit_to_internal` /
  `withdraw_to_internal` depend on.
- **Documented as audited**: each requirement ends with "Enforcement: Audited" — meaning the
  MSL prover has discharged them (upstream `aptos-framework` CI).
- **Pragma-opaque-clean for CA's purposes**: CA's entry-point specs currently declare
  `pragma opaque` on the wrapper calls, but can be tightened once Phase 0 ristretto255 patches
  unblock the Move Prover lane and the upstream specs are transitively available.

**Not sufficient for Phase 5 balance-conservation claims** — the upstream specs pin *total
supply* but not *per-store balance arithmetic in encrypted form*. The CA-side confidential
balance arithmetic (`ConfidentialAssetStore.pending_balance + delta`) is a protocol-internal
invariant that the CA specs pin directly (see `confidential_balance.spec.move` length + abort
conditions for `add_balances_mut` / `sub_balances_mut`); this is independent of the FA layer.

## Gaps that require upstream work

| Gap | Impact | Severity |
|---|---|---|
| `fungible_asset.spec.move` module has `pragma verify = false` for `object_metadata` | Some CA spec checks may fail at that boundary during Move Prover runs | Low — doesn't affect CA's critical specs |
| `dispatchable_fungible_asset` may not have full spec coverage | `deposit_to` uses `dispatchable_fungible_asset::transfer`, not the standard FA `transfer`. Dispatchable path may be less-specified upstream | Medium — audit `dispatchable_fungible_asset.spec.move` (if it exists) as a follow-up |
| No explicit composition theorem "CA.deposit_to + FA.transfer = total-supply-preserving" | Reviewers must piece this together by reading both spec files | Low — documented here |

## Follow-ups

1. ~~Audit `dispatchable_fungible_asset.spec.move`~~ — ✅ **audited below.**
2. **Once Phase 0 ristretto255 patches land and Phase 5 specs verify**: tighten `pragma opaque`
   on CA entry-point spec's FA-side abort conditions; delegate to upstream requirement 4 / 5.
3. **Plan §8 Q3 resolution**: mark this question resolved pending #2 above.

## Audit addendum: `dispatchable_fungible_asset.spec.move`

**Scope:** CA's `deposit_to_internal` calls `dispatchable_fungible_asset::transfer` (not
`fungible_asset::transfer`). The dispatchable variant dispatches through user-registered hooks,
allowing customized deposit/withdraw logic per token.

**Upstream spec:** 21 lines total. Module-level `pragma verify = false`. All four public
entry points (`dispatchable_withdraw`, `dispatchable_deposit`, `dispatchable_derived_balance`,
`dispatchable_derived_supply`) are declared `pragma opaque`.

**Verdict:** **weaker than `fungible_asset.spec.move`**. Upstream opacity means:
- No formal guarantee that `dispatchable_deposit` preserves total supply across hooks.
- No owner-only assertion on `dispatchable_withdraw`.
- All behavior deferred to per-token user-dispatch hooks, which are unknown at spec time.

**Impact on CA:**

- **`deposit_to_internal`'s FA side effect is therefore not MSL-verifiable** as "preserves
  total supply" or "only sender's balance changes." Instead, CA specs `pragma opaque` this
  call site, inheriting the opacity boundary.
- **Difftest covers the gap**: VM↔Lean corpus rows exercise the actual dispatch behavior on
  the specific FAs CA uses (aptos-coin as the test anchor), so production regressions in the
  dispatch hooks surface at the corpus level even though MSL can't catch them.
- **Phase 6 composition claim for `deposit_to`** therefore reads: "MSL pins sender's store
  pre/post + CA-side balance arithmetic; difftest pins VM behavior; dispatchable FA layer is
  an explicit trust boundary and lives in `TRUST_BOUNDARIES.md`."

**Action item:** add a trust-boundary row for `dispatchable_fungible_asset::*` in
[`TRUST_BOUNDARIES.md`](TRUST_BOUNDARIES.md). Upstream work would be to expand the spec
to at least pin the "dispatch through registered hook" shape — but that's out of CA's
scope and not blocking.
