# Reduce recurring staking lockups to 24 hours

`scripts/set_lockup_to_24_hours.move` changes
`0x1::staking_config::StakingConfig.recurring_lockup_duration_secs` from
1,209,600 seconds (14 days) to 86,400 seconds (24 hours), using the existing
core-resources administrative signer path. Merging this change does not execute
the migration; an authorized operator must submit the script separately.

The existing parameterized `update_recurring_lockup_duration.move` script remains
available for other administrative updates.

## Effects

- Existing pools retain their `StakePool.locked_until_secs` timestamps. New locks
  and successful subsequent renewals use 24 hours. Updating the configuration
  before a pool's renewal avoids assigning another 14-day cycle.
- An unlock request waits for the remainder of the pool's cycle and the eligible
  epoch transition. A 24-hour cycle is neither a minimum holding period nor a
  strict 24-hour withdrawal deadline. Delayed epoch transitions delay settlement.
- Pending withdrawals settle before automatic renewal; inactive funds remain
  withdrawable. The script does not force an epoch or alter pool balances,
  rewards, validator membership, or governance settings.
- Delegation-pool commission changes immediately require only six hours of
  remaining lockup, because the notice threshold is one quarter of the configured
  duration. After pools transition, the existing maximum increase of 10 percentage
  points per cycle can take effect daily. This is an intentional consequence of
  the shorter cycle.

## Mandatory governance preflight

Governance proposal creation requires its backing pool's
`StakePool.locked_until_secs` to be at least the current on-chain time plus the
live `0x1::aptos_governance::GovernanceConfig.voting_duration_secs`. Reducing the
recurring lockup does not rewrite an existing pool expiry, but it limits a pool's
next successful renewal to 24 hours from that renewal. Check the live governance
duration and each governance backing pool before executing this migration.

Use the repository CLI's resource query against the same target URL:

```bash
movement account list --account 0x1 --query resources --url <NODE_REST_URL>
movement account list --account <GOVERNANCE_BACKING_POOL_ADDRESS> --query resources --url <NODE_REST_URL>
```

From the first response, record
`0x1::aptos_governance::GovernanceConfig.voting_duration_secs`; from the second,
record `0x1::stake::StakePool.locked_until_secs`. Use the on-chain
`0x1::timestamp::CurrentTimeMicroseconds.microseconds` divided by 1,000,000 for
seconds, rather than the operator's local clock. Do not execute until every
backing pool that must be able to create a proposal has expiry later than the
observed on-chain time plus the live voting duration **and operational headroom**
for the proposal transaction. Repeat this immediately before submission. A
24-hour voting duration leaves no such headroom after a separate 24-hour renewal.
For proposal availability after existing long locks expire, require the live voting
duration plus operational headroom to be less than 86,400 seconds. A longer voting
period may work with existing long locks but will not fit an ordinary renewed
24-hour lock. Resolve that configuration mismatch through the separately authorized
governance process before executing this migration; this script does not change it.

`stake::increase_lockup_with_cap` sets a renewal expiry to the current on-chain
time plus the configured recurring duration and aborts unless that value is later
than the pool's existing expiry. Consequently, a pool still locked for at least
24 hours cannot be renewed immediately after this change; it must wait until its
existing expiry is less than a new 24-hour expiry. Existing longer locks are not
shortened by the migration.

## Guards

The script requires the core-resources signer (`0xa550c18`) through
`aptos_governance::get_signer_testnet_only`, which obtains the framework signer.
Despite its name, this is the existing administrative path used by Movement's
migration scripts; it requires that authority to remain available on the target
network.

| Script abort code | Condition |
| --- | --- |
| 1 | Current recurring lockup is not exactly 1,209,600 seconds, including a second execution after success. |
| 2 | Configured epoch duration, rounded down to whole seconds by the framework getter, exceeds 86,400 seconds. |

An unauthorized signer is rejected by the framework's existing authorization
check. An abort leaves the staking configuration unchanged.

## Build and execute

Run from the repository root. Compile the script against this checkout's framework:

```bash
movement move compile \
  --package-dir movement-migration/update_recurring_lockup_duration
```

Before execution, inspect the target network's staking configuration, epoch
interval, and relevant pool expiration timestamps. Record the old values for
post-execution comparison. The recurring lockup must be `1209600`; the epoch
interval is expressed in microseconds in `0x1::block::BlockResource`.

Submit the compiled script with the authorized core-resources profile and an
explicit target URL:

```bash
movement move run-script \
  --compiled-script-path movement-migration/update_recurring_lockup_duration/build/update_recurring_lockup_duration/bytecode_scripts/set_lockup_to_24_hours.mv \
  --profile <CORE_RESOURCES_PROFILE> \
  --url <NODE_REST_URL>
```

Verify that the transaction succeeded and that
`0x1::staking_config::StakingConfig.recurring_lockup_duration_secs` is `86400`.
The migration transaction must not write any `StakePool` resource. At subsequent
eligible epoch transitions, verify that renewing active pools receive expirations
24 hours after renewal and eligible pending withdrawals become inactive.

Changing the configuration back to 14 days with the parameterized script would
affect future locks only; it would not extend existing 24-hour expirations.
