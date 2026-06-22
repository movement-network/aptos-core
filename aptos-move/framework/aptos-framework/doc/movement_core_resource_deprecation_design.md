# Movement Core Resource Signer Deprecation

## Status

Draft.

## Summary

Movement mainnet should stop relying on the core resource signer as a privileged path for framework
governance execution. Mainnet framework changes should be authorized by validator governance, using
the existing multi-step proposal flow. Testnet should keep the core resource signer path because it
is useful for operational testing and fast iteration.

The migration has three phases:

1. Prove delegation-pool governance can create proposals and vote.
2. Execute a mainnet framework upgrade that decommissions core resource authority on mainnet.
3. Rotate the core resource account authentication key to an unrecoverable key as defense in depth.

## Goals

- Mainnet framework upgrades are executable only after a governance proposal receives sufficient
  validator voting power.
- A core resource account signature can no longer obtain a framework signer on Movement mainnet.
- Delegation-pool owners and voters can participate in proposal creation and voting through the
  delegation-pool governance path.
- Testnet root-signer workflows remain available.
- Historical proposal artifacts under `movement-migration/` remain unchanged.

## Non-Goals

- Remove the core resource account from genesis.
- Remove testnet root-signer workflows.
- Introduce a new release-builder execution mode if the existing `MultiStep` governance mode is
  sufficient.
- Rewrite historical proposals that have already been generated or executed.

## Current State

Mainnet currently has two relevant authority paths:

- Governance path: proposals are created, voted on, and resolved by `aptos_governance`.
- Core resource shortcut: scripts signed by `@core_resources` can call
  `aptos_governance::get_signer_testnet_only(core_resources, signer_address)` and receive a signer
  for a framework-controlled address.

The shortcut is intended for tests and testnets, but it is still callable wherever
`system_addresses::assert_core_resource` accepts `@core_resources`.

The framework already contains a transient feature flag:

```move
std::features::get_decommission_core_resources_enabled()
```

`system_addresses::is_core_resource_address` returns false when this feature flag is enabled. Since
`get_signer_testnet_only` calls `system_addresses::assert_core_resource`, enabling this feature
prevents the core resource signer from using that function.

Movement chain IDs in Rust are:

- Movement mainnet: `126`
- Movement testnet: `250`

## Proposed Design

### 1. Validate Delegation-Pool Governance

Add and run a focused test that verifies a delegation-pool owner can:

- create a governance proposal through `delegation_pool::create_proposal`;
- vote on the proposal through `delegation_pool::vote`;
- consume the expected voting power.

This validates the operator-facing path that Movement expects to use for mainnet proposal
participation.

Validation command:

```bash
RUST_MIN_STACK=16777216 TEST_FILTER=test_delegation_pool_owner_can_create_and_vote \
  cargo test -p aptos-framework --test move_unit_test move_framework_unit_tests -- --nocapture
```

### 2. Use Existing Multi-Step Governance for Mainnet Releases

Movement mainnet should use the existing `MultiStep` proposal mode, even for a one-script proposal.
For a single executable step, the proposal is still created with governance-v2 semantics and the
last step uses an empty next execution hash.

The generated script should resolve governance before obtaining the framework signer:

```move
let framework_signer = aptos_governance::resolve_multi_step_proposal(
    proposal_id,
    @aptos_framework,
    x"",
);
```

This means no new release-builder execution mode is required for the initial migration. Existing
testnet `RootSigner` behavior should remain unchanged.

### 3. Mainnet Framework Upgrade: Decommission Core Resources

The first mainnet governance upgrade should enable the existing
`DECOMMISSION_CORE_RESOURCES` feature flag.

After this feature flag is enabled:

- `system_addresses::is_core_resource_address(@core_resources)` returns false;
- `system_addresses::assert_core_resource(core_resources)` aborts;
- `aptos_governance::get_signer_testnet_only(core_resources, signer_address)` aborts before
  returning any signer;
- scripts signed only by `@core_resources` can no longer mint a framework signer on mainnet.

This is the actual security cutover. Key rotation alone is not sufficient before this step, because
the framework would still contain the privileged conversion path.

The implementation should use governance to enable the feature flag. If desired, a follow-up code
change can make `get_signer_testnet_only` explicitly reject Movement mainnet by checking
`chain_id::get() == 126`, but the feature flag is already wired into the core resource assertion and
keeps testnet behavior intact.

### 4. Rotate Core Resource Authentication Key

After the decommissioning feature is active on mainnet, submit a separate governance proposal that
rotates the `@core_resources` authentication key to an unrecoverable value.

This step is defense in depth:

- the framework already rejects core resource signer authority after phase 3;
- the key rotation prevents the old key from submitting ordinary transactions as `@core_resources`;
- operators can verify that transactions signed by the old key are rejected.

The key rotation proposal must resolve governance for the core resource address. It should not use
the old core resource private key to perform the rotation.

## Operator Flow

### Proposal Creation

For stake-pool governance:

```bash
movement governance propose \
  --pool-address <stake-pool-address> \
  --metadata-url <metadata-url> \
  --script-path <script-path> \
  --is-multi-step \
  --sender-account <delegated-voter-address>
```

For delegation-pool governance:

```bash
movement governance delegation-pool propose \
  --delegation-pool-address <delegation-pool-address> \
  --metadata-url <metadata-url> \
  --script-path <script-path> \
  --is-multi-step \
  --sender-account <voter-address>
```

### Voting

For stake-pool governance:

```bash
movement governance vote \
  --pool-addresses <stake-pool-address> \
  --proposal-id <proposal-id> \
  --yes \
  --sender-account <delegated-voter-address>
```

For delegation-pool governance:

```bash
movement governance delegation-pool vote \
  --delegation-pool-address <delegation-pool-address> \
  --proposal-id <proposal-id> \
  --yes \
  --sender-account <voter-address>
```

### Execution

After the proposal succeeds:

```bash
movement governance execute-proposal \
  --proposal-id <proposal-id> \
  --script-path <script-path> \
  --sender-account <executor-address>
```

The executor does not need core resource authority. The script itself must resolve the successful
governance proposal before obtaining the framework signer.

## Verification Checklist

Before mainnet execution:

- Delegation-pool owner create/vote test passes.
- Generated proposal scripts use `resolve_multi_step_proposal`.
- Proposal metadata and script hashes are published and independently verified by validators.
- The decommission proposal enables `DECOMMISSION_CORE_RESOURCES`.
- Testnet `RootSigner` generation is unchanged.

After mainnet execution:

- `std::features::get_decommission_core_resources_enabled()` returns true.
- `system_addresses::is_core_resource_address(@core_resources)` returns false.
- A script calling `get_signer_testnet_only` with `@core_resources` aborts on mainnet.
- The old core resource key cannot execute privileged framework operations.
- Testnet root-signer workflows continue to work on Movement testnet.

## Risks and Mitigations

### Incorrectly Breaking Testnet

Risk: disabling the core resource signer globally would break testnet operations.

Mitigation: use the feature flag only on Movement mainnet, and do not remove the testnet script
generation path.

### Governance Participation Misconfiguration

Risk: delegation-pool operators may assume operator status is enough to vote.

Mitigation: document that delegation-pool voting depends on delegated voting power. The operator can
vote only if they have their own voting power or delegators delegate voting power to them.

### Irreversible Key Rotation Before Framework Cutover

Risk: rotating the core resource key before decommissioning the framework path leaves the privileged
path in code and may complicate rollback.

Mitigation: upgrade the framework first, verify the feature is active, then rotate the auth key in a
separate proposal.

### Proposal Execution Failure

Risk: the decommission proposal succeeds but execution fails due to script or hash mismatch.

Mitigation: use the existing proposal verification tooling and require validators to independently
verify script hash, metadata hash, and expected feature flag changes before voting.

## Rollback

Before execution, rollback is simple: do not execute the proposal.

After the decommissioning proposal executes, rollback would require another successful governance
proposal to disable `DECOMMISSION_CORE_RESOURCES`. After the core resource key is rotated to an
unknown key, rollback must not depend on the core resource account.

## Open Questions

- Should `aptos_governance::get_signer_testnet_only` also include an explicit Movement mainnet
  chain-id guard, or is the existing feature flag gate sufficient?
- What exact unrecoverable authentication key should be used for `@core_resources` rotation?
- Should operator runbooks require delegation-pool vote delegation to be configured before the
  decommission proposal is submitted?
