# Script execution allowlist

The module is disabled by default. When enabled,
standalone Move bytecode scripts require explicit membership of the primary
transaction sender. Entry-function calls are unchanged. Fee payers, secondary
signers, special addresses, and governance-approved script hashes do not confer
membership. Before initialization, enforcement is disabled. An enabled empty list
denies scripts. The resource at `0x1::script_execution_allowlist::AllowedSenders`
contains the shared `allowlist::Allowlist` value. Its state is independent of
`0x1::code::PublishAllowlist`.

## Rollout

1. Deploy node binaries containing the new prologue error mapping to all validators
   and serving nodes.
2. Upgrade the framework with the new module and prologue while the module remains disabled.
3. Run `scripts/initialize.move` once (idempotent).
4. Run `scripts/add.move` for each approved primary sender, including the
   core-resources account used to submit these administration scripts. Its argument
   is `address:<sender>`; use `scripts/remove.move` to revoke membership.
5. Inspect `0x1::script_execution_allowlist::get_allowed_senders` through the view API.
6. Run `scripts/enable.move` without arguments. It verifies that the actual
   core-resources transaction sender is listed and enables enforcement immediately.
7. Verify `0x1::script_execution_allowlist::is_enabled` and test listed/unlisted senders.

From the repository root, a core-resources initialization command is:

```bash
movement move run-script \
  --script-path movement-migration/script-execution-allowlist/scripts/initialize.move \
  --framework-local-dir aptos-move/framework/aptos-framework \
  --sender-account <CORE_RESOURCES_ADDRESS> \
  --private-key-file <KEY_FILE> --url <NODE_URL>
```

Use the same options with the other script paths. Add
`--args address:<SENDER>` for `add.move` or `remove.move`. No addresses are
automatically added or exempted. The framework signer obtained inside a script
authorizes management; it is not the transaction sender and does not need membership
when core resources submits the transaction.

## Administration

Membership changes take effect for subsequent transactions without an epoch change.
The views report configured membership independently of the enabled state. Actual
membership changes emit `AllowedSenderChanged`; repeating an edit is a no-op.
The list is limited to 256 senders to bound unmetered prologue work.

`disable.move` disables enforcement immediately; it
preserves the list. While enforcement is enabled, this script's sender must be
listed like any other script sender. Removing the last usable administrative
script sender can prevent subsequent script-based administration.

These helpers use `aptos_governance::get_signer_testnet_only` and require an active
core-resources account. For governance proposals, obtain the framework signer
with the existing proposal-resolution flow and call the same `initialize`, `add`,
`remove`, `enable`, and `disable` functions. The account submitting a proposal execution script
must also be listed while enforcement is on; approval of its script hash is not
an exemption. Neither management authority nor membership bypasses other
transaction authentication rules.

`scripts/disable_by_proposal.move` can disable enforcement through an approved
governance proposal. Its only argument is `u64:<PROPOSAL_ID>`; the transaction
sender must be allowlisted while script enforcement is enabled. This does not
require a designated recovery sender or provide an admission exemption.

The combined local rehearsal exercises independent policy state, immediate activation,
a governance-approved upgrade at `0x1` after revoking the normal operator, and disabling
publishing and script restrictions through a separately controlled recovery sender:

```bash
cargo test -p e2e-move-tests --lib allowlist_recovery -- --test-threads=1
```

Publishing activation does not require script-list setup. When script enforcement is enabled,
the transaction sender submitting a publishing helper needs script admission like any other
script sender. Configure each policy independently for the operations its members will perform.
