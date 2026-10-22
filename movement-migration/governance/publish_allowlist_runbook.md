# Code publishing allowlist

The code publishing allowlist is disabled by default. Once enabled, every publish request requires
its primary transaction sender to be listed, including scripts, resource accounts, objects, and
multisig. For multisig, list the outer transaction sender, not the multisig account or publish
destination. Deployments, upgrades, and added modules use the same permission. Existing package
ownership and compatibility checks still apply.

## Rollout

Publishing enforcement uses existing node functionality and can be installed with a framework
upgrade. It does not require initializing or populating the script execution allowlist. If script
enforcement is enabled separately, the transaction sender submitting these helpers must be in that
list; the named upgrade and recovery addresses need script membership only when they submit scripts.

1. Upgrade the framework with `code::PublishAllowlist`; the new resource is absent and therefore
   enforcement remains disabled.
2. Submit `initialize_publish_allowlist.move` with the core-resources signer. Initialization is
   idempotent and never resets a saved list or enabled state.
3. Submit `add_publish_allowlist_sender.move` for each approved primary transaction sender,
   including the planned upgrade and recovery senders.
4. Inspect `0x1::code::get_publish_allowed_senders` and
   `0x1::code::is_publish_allowlist_enabled`. Confirm that the upgrade and recovery senders
   are distinct, and use `0x1::code::is_publish_allowlisted` to verify each membership.
5. Complete the recovery rehearsal below. Then submit `enable_publish_allowlist.move` with
   `--args address:<UPGRADE_SENDER> address:<RECOVERY_SENDER>`. It checks both publishing memberships and
   calls `code::enable_publish_allowlist`; activation is immediate on commit, with no epoch or DKG
   wait.
6. Verify the enabled view immediately. A listed sender must publish successfully and an unlisted
   sender must be rejected without package metadata or module effects.

From the repository root, initialize with:

```bash
movement move run-script \
  --script-path movement-migration/governance/initialize_publish_allowlist.move \
  --framework-local-dir aptos-move/framework/aptos-framework \
  --sender-account <CORE_RESOURCES_ADDRESS> \
  --private-key-file <KEY_FILE> --url <NODE_URL>
```

Use the same options for the other helpers. Add with
`--args address:<SENDER>` to `add_publish_allowlist_sender.move`; revoke with the matching
`remove_publish_allowlist_sender.move`. The enable helper takes the two named sender addresses.
Use the actual primary senders for the planned transactions, including when governance or multisig
supplies authority.

## Administration and enforcement

Only framework-signer authority can initialize, enable, disable, add, or remove. The core-resources
helpers obtain that signer through existing governance support. Where core-resources is unavailable,
a governance proposal must resolve the framework signer and invoke the same module action.

Membership edits and enabled-state changes apply immediately. Actual membership edits emit
`PublishAllowedSenderChanged`; actual enabled-state changes emit `PublishAllowlistEnabledChanged`;
repeated actions are
no-ops. The list is capped at 256 addresses. `is_publish_allowlisted` reports membership independently of
enabled state, and a missing resource is disabled. An enabled empty list denies every publisher.

There are no special-address or governance-script exemptions. A denied payload is a kept Move abort
that charges gas and rolls back package metadata and module writes. The check also covers account
authenticators and zero-module publish requests.

`disable_publish_allowlist.move` calls `code::disable_publish_allowlist` immediately and preserves the
list. The fixed-action `disable_publish_allowlist_by_proposal.move` takes only
`u64:<PROPOSAL_ID>` after governance has approved that exact action. These administration scripts
do not publish code.

## Publishing activation and recovery rehearsal

Before target-network activation, rehearse with the target framework, governance configuration,
stake, and lockup conditions. Record separately controlled upgrade and recovery credentials, the
available proposer and voter authority, approval threshold, voting duration, and recovery stake
lockup. Publishing membership does not prove possession of credentials, package ownership, or
governance vote authority.

The rehearsal must demonstrate:

1. Publishing activates through its `code` module entry function. Listed senders publish; unlisted
   senders cannot.
2. The actual upgrade and recovery senders can sign and obtain the framework signer through the
   supported core-resources or governance path. Perform a representative framework upgrade while
   publishing enforcement is enabled.
3. With the normal operator revoked or unavailable, the separately controlled recovery sender
   performs a governance upgrade at `0x1`, then executes the approved
   `disable_publish_allowlist_by_proposal.move` action. Its sole argument is the proposal ID.
   Verify publishing is restored immediately.

Run the repository publishing checks with:

```bash
cargo test -p e2e-move-tests --lib allowlist -- --test-threads=1
```

The local result is not proof of target-network credential custody, stake, quorum, or lockup
readiness. Retain target-specific rehearsal results and re-check publishing membership and
authority immediately before activation. If other restrictions are active, verify their separate
requirements as well. Do not activate if the recovery path cannot be executed. No bypass is
available if usable senders or the required governance authority are lost.
