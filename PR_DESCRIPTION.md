# Add `normalize_and_rollover_pending_balance`

Single entry function in `aptos_experimental::confidential_asset` that runs `normalize` then `rollover_pending_balance` so wallets can offer a one-tap "accept pending" flow without two signature prompts.

## Behavior

| Incoming state | Result |
|---|---|
| `normalized == false` | Normalize, then rollover. |
| `normalized == true` | Aborts with `EALREADY_NORMALIZED`. |

Strict by design: callers that may already be normalized should check `is_normalized` first and route to plain `rollover_pending_balance` (no proofs needed). Making the on-chain function tolerant wouldn't save the client work — proof generation is the expensive step and happens before tx build.

## Client integration (already wired)

- `ts-sdk/confidential-assets` — `rolloverPendingBalance` reads `isBalanceNormalized` and dispatches to `rollover_pending_balance` or `normalize_and_rollover_pending_balance` accordingly. One signature either way.
- `motion-wallet` — `rolloverConfidentialPending` forwards to the SDK with the decryption key; user sees one wallet prompt regardless of state.

No client changes required by this PR.

## Tests

- Move unit tests for happy path and `EALREADY_NORMALIZED` abort.
- E2E test in `confidential_asset_e2e.rs` exercising the combined flow.
