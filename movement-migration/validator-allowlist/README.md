# Activate the four-validator allowlist

Run on testnet first, then mainnet. This package uses the framework source in this
checkout. It does not publish the framework or select the approved validators.

## Preconditions

- Publish and verify the framework upgrade containing **both** the join-time ACL
  check and the pending-queue check in `stake::configure_allowed_validators`.
  This script must not run against the old framework: the old function does not
  reject queued outsiders. A node binary update alone does not upgrade Move code.
- Independently approve the target chain ID and the four **stake-pool addresses**
  for that network. Use resource-account addresses for delegation pools, not
  operator/owner addresses. Do not automatically copy whatever set is active at
  execution time. Record these inputs and the deployed framework revision.
- Use the existing Movement core-resources migration authority (`0xa550c18`).
  Like the other migration scripts, this uses
  `aptos_governance::get_signer_testnet_only`; despite its name, its implementation
  checks the core-resources signer. Confirm that this authority is available on
  the target deployment before scheduling activation.

## Compile and activate

From the repository root, with a CLI built from this revision:

```sh
movement move compile-script \
  --package-dir movement-migration/validator-allowlist \
  --output-file /tmp/configure-validator-allowlist.mv
```

Supply the approved values explicitly (the variables below must be set for the
target network). `POOL_1` through `POOL_4` are the four approved pool addresses.

```sh
movement move run-script \
  --compiled-script-path /tmp/configure-validator-allowlist.mv \
  --sender-account 0xa550c18 \
  --private-key-file "$ADMIN_KEY_FILE" \
  --url "$NETWORK_URL" \
  --args "u8:$EXPECTED_CHAIN_ID" \
    "address:$POOL_1" "address:$POOL_2" "address:$POOL_3" "address:$POOL_4"
```

In one transaction, the script checks the chain ID, verifies that the current
set is exactly the four approved active pools (none leaving), and publishes the
ACL. The framework rejects any pending joiner outside the ACL. Duplicate or
incorrect input addresses fail the exact-set check.

If an outsider joins between the upgrade and activation, activation aborts;
the network is **not restricted** until activation succeeds. Resolve the
unexpected membership and retry with the same approved list. Do not add the
outsider to make the check pass. `stake::remove_validators` only handles active
validators; it cannot cancel an outsider's pending join.

After success, verify `0x1::stake::AllowedValidators` contains exactly the
approved addresses. At the next epoch, verify `0x1::stake::ValidatorSet` still
contains only approved pools and no pending outsiders. Confirm an existing
unapproved pool cannot join on testnet before proceeding to mainnet. Retain the
transaction hash and the observed resource values for each network. The four
approved pools can still leave and rejoin; this restricts pool identity, not
operator-key rotation or validator uptime.
