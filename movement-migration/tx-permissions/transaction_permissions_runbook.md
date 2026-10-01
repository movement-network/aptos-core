# Transaction Permission Table Runbook

This runbook covers rolling out and operating the on-chain transaction permission table (`0x1::transaction_permissions`): an ordered allow/deny rule list the VM consults during transaction validation when feature 226 (`TRANSACTION_PERMISSIONS`) is enabled.

## How rules work

Each rule has three fields:

- **sender** — a specific account, or all accounts (wildcard);
- **kind** — `0` deploy, `1` upgrade, `2` script, `3` other (entry functions, multisig);
- **allow** — the verdict.

Rules are evaluated top to bottom and the first rule whose sender and kind both match decides. When no rule matches, the transaction is **allowed**, so an empty table with the feature on changes nothing. Rules match the primary transaction sender (also for fee-payer, multi-agent, and multisig transactions). A deploy is a publish whose target modules do not exist yet; publishing over any existing module is an upgrade. A script that publishes code must pass both the script rules and the deploy/upgrade rules.

Enforcement effects:

- Denied **script** and **other** transactions are discarded at validation (mempool, execution, and simulation) with status `TRANSACTION_NOT_PERMITTED`; no gas is charged.
- Denied **deploy** and **upgrade** transactions fail during execution with status `MODULE_PUBLISHING_NOT_PERMITTED`; gas **is** charged, so denied publishes are not free compute.

Administration cannot be locked out: the VM never denies approved governance scripts, framework-reserved senders (0x1–0xa), the core-resources account, or `0x1::aptos_governance` entry functions, regardless of table contents.

## Rollout order

1. **Framework upgrade.** Ship a framework release that contains `0x1::transaction_permissions` and feature flag 226 (use the standard `movement-migration/framework_upgrade.sh` flow). Enforcement code in the node binaries must also be deployed; nodes without it ignore the flag.
2. **Initialize the table** (one-time, idempotent):

   ```bash
   movement move run-script \
     --script-path movement-migration/tx-permissions/initialize_transaction_permissions.move \
     --sender-account <CORE_RESOURCE_ADDRESS> \
     --private-key-file <CORE_RESOURCE_KEY_FILE> \
     --url <NODE_URL> \
     --assume-yes
   ```

3. **Populate initial rules** (optional; see "Edit rules" below). Populating before enabling means enforcement starts with the intended policy in one step.
4. **Enable enforcement** (also forces an epoch change so it takes effect immediately):

   ```bash
   movement move run-script \
     --script-path movement-migration/tx-permissions/enable_transaction_permissions.move \
     --sender-account <CORE_RESOURCE_ADDRESS> \
     --private-key-file <CORE_RESOURCE_KEY_FILE> \
     --url <NODE_URL> \
     --assume-yes
   ```

## List the table

The table is readable from any fullnode through the view API:

```bash
curl -s -X POST "<NODE_URL>/v1/view" \
  -H "Content-Type: application/json" \
  -d '{"function":"0x1::transaction_permissions::get_rules","type_arguments":[],"arguments":[]}'
```

Rules are returned in evaluation order; the position in the array is the `index` used by the edit scripts. `0x1::transaction_permissions::check` (arguments: sender address, kind as a string-encoded u8) returns the verdict the VM would apply, as an `Option<bool>`.

## Edit rules

Edits take effect immediately; no epoch change is needed. `index` is the evaluation position: 0 is checked first, and an index equal to the current table length appends. The table holds at most 256 rules.

Insert a rule for one sender (example: deny deploys by `0xBAD...`):

```bash
movement move run-script \
  --script-path movement-migration/tx-permissions/insert_rule_for_sender.move \
  --sender-account <CORE_RESOURCE_ADDRESS> \
  --private-key-file <CORE_RESOURCE_KEY_FILE> \
  --args u64:0 \
  --args address:<SENDER_ADDRESS> \
  --args u8:0 \
  --args bool:false \
  --url <NODE_URL> \
  --assume-yes
```

Insert a wildcard rule (example: freeze all module upgrades):

```bash
movement move run-script \
  --script-path movement-migration/tx-permissions/insert_rule_for_all.move \
  --sender-account <CORE_RESOURCE_ADDRESS> \
  --private-key-file <CORE_RESOURCE_KEY_FILE> \
  --args u64:0 \
  --args u8:1 \
  --args bool:false \
  --url <NODE_URL> \
  --assume-yes
```

Remove a rule (list the table first to confirm the index; later rules shift down by one):

```bash
movement move run-script \
  --script-path movement-migration/tx-permissions/remove_rule.move \
  --sender-account <CORE_RESOURCE_ADDRESS> \
  --private-key-file <CORE_RESOURCE_KEY_FILE> \
  --args u64:0 \
  --url <NODE_URL> \
  --assume-yes
```

Because evaluation is first-match-wins, put specific exceptions at a lower index than the broad rule they override. Example — nobody deploys except `0xA11CE`:

```text
index 0: sender 0xA11CE, kind deploy, allow
index 1: all senders,    kind deploy, deny
```

Every insert and remove emits an on-chain event (`RuleInserted` / `RuleRemoved`) for audit.

## Emergency disable

Turns enforcement off chain-wide at the next block; the table is left intact for a later re-enable:

```bash
movement move run-script \
  --script-path movement-migration/tx-permissions/disable_transaction_permissions.move \
  --sender-account <CORE_RESOURCE_ADDRESS> \
  --private-key-file <CORE_RESOURCE_KEY_FILE> \
  --url <NODE_URL> \
  --assume-yes
```

## Verify feature state

```bash
curl -s -X POST "<NODE_URL>/v1/view" \
  -H "Content-Type: application/json" \
  -d '{"function":"0x1::features::transaction_permissions_enabled","type_arguments":[],"arguments":[]}'
```

## After core-resources decommissioning

These scripts use the core-resources signer (`aptos_governance::get_signer_testnet_only`), which stops working once feature 222 (`DECOMMISSION_CORE_RESOURCES`) is enabled. All entry points are gated on the framework signer, so the same operations then run as governance proposals: wrap the same calls in a proposal script that obtains the framework signer via `aptos_governance::resolve_multi_step_proposal`, following the proposal flow in `movement-migration/governance/delegation_pool_governance_runbook.md`.
