
<a id="0x1_attestation_policy"></a>

# Module `0x1::attestation_policy`

A business's rules over attestation sources, without deploying anything.

A policy is a resource account, created the same way <code>aptos_framework::attestation</code> creates a
source and <code>aptos_framework::timelock</code> creates a timelock account: the deployer authorizes
creation and pays gas but gains no role unless listed. A policy names the sources it trusts,
how to combine them, predicates over their attributes, and a per-action amount above which a
fresh authorization is demanded.

The consequence is the reason this module exists rather than a single registry. A new business
does not onboard subjects: it creates a policy pointing at sources that already have them, so
its marginal onboarding cost is zero, and the network effect sits on the source side.

Evaluation returns three values, not two. Two-valued authorization forces one global threshold
on every consumer. The third value lets a policy be permissive for ordinary activity and strict
where the business actually cares, and it is what joins persistent facts and per-action
authorization into one product instead of two.

Properties:
- An empty body denies everything. A policy that allows nothing is obvious in testing; one that
allows everything is not.
- Denial is evaluated before anything positive, and no source can override another's denial.
- Rule changes are staged with an activation time, so a change never breaks a transaction that
is already in flight, and anyone may push a staged body live once its time arrives.
- A paused policy denies with its own reason rather than silently allowing.
- Source lists are bounded, because unbounded iteration over rules is a denial-of-service
vector. <code>ERC-3643</code> caps its module list at 25 for the same reason.

Delayed governance comes by composition: an admin may be a <code>aptos_framework::timelock</code> account,
in which case every rule change inherits that module's delay and cancel semantics.


-  [Struct `SourceRef`](#0x1_attestation_policy_SourceRef)
-  [Struct `AttrRule`](#0x1_attestation_policy_AttrRule)
-  [Struct `Body`](#0x1_attestation_policy_Body)
-  [Struct `Staged`](#0x1_attestation_policy_Staged)
-  [Resource `Policy`](#0x1_attestation_policy_Policy)
-  [Struct `CreatePolicy`](#0x1_attestation_policy_CreatePolicy)
-  [Struct `AddMembers`](#0x1_attestation_policy_AddMembers)
-  [Struct `RemoveMembers`](#0x1_attestation_policy_RemoveMembers)
-  [Struct `StageBody`](#0x1_attestation_policy_StageBody)
-  [Struct `ActivateBody`](#0x1_attestation_policy_ActivateBody)
-  [Struct `CancelPending`](#0x1_attestation_policy_CancelPending)
-  [Struct `SetStepUp`](#0x1_attestation_policy_SetStepUp)
-  [Struct `SetAuthorizer`](#0x1_attestation_policy_SetAuthorizer)
-  [Struct `SetPaused`](#0x1_attestation_policy_SetPaused)
-  [Constants](#@Constants_0)
-  [Function `get_next_policy_address`](#0x1_attestation_policy_get_next_policy_address)
-  [Function `evaluate`](#0x1_attestation_policy_evaluate)
-  [Function `is_allowed`](#0x1_attestation_policy_is_allowed)
-  [Function `decision_of`](#0x1_attestation_policy_decision_of)
-  [Function `reason_of`](#0x1_attestation_policy_reason_of)
-  [Function `simulate`](#0x1_attestation_policy_simulate)
-  [Function `simulate_counts`](#0x1_attestation_policy_simulate_counts)
-  [Function `admins`](#0x1_attestation_policy_admins)
-  [Function `guardians`](#0x1_attestation_policy_guardians)
-  [Function `is_admin`](#0x1_attestation_policy_is_admin)
-  [Function `is_paused`](#0x1_attestation_policy_is_paused)
-  [Function `require_any_sources`](#0x1_attestation_policy_require_any_sources)
-  [Function `require_all_sources`](#0x1_attestation_policy_require_all_sources)
-  [Function `deny_any_sources`](#0x1_attestation_policy_deny_any_sources)
-  [Function `step_up_for`](#0x1_attestation_policy_step_up_for)
-  [Function `has_pending`](#0x1_attestation_policy_has_pending)
-  [Function `pending_effective_at`](#0x1_attestation_policy_pending_effective_at)
-  [Function `authorizer_pubkey`](#0x1_attestation_policy_authorizer_pubkey)
-  [Function `authorizer_max_ttl_secs`](#0x1_attestation_policy_authorizer_max_ttl_secs)
-  [Function `standard_version`](#0x1_attestation_policy_standard_version)
-  [Function `create`](#0x1_attestation_policy_create)
-  [Function `stage_body`](#0x1_attestation_policy_stage_body)
-  [Function `stage_attr_rules`](#0x1_attestation_policy_stage_attr_rules)
-  [Function `activate_pending`](#0x1_attestation_policy_activate_pending)
-  [Function `cancel_pending`](#0x1_attestation_policy_cancel_pending)
-  [Function `set_step_up`](#0x1_attestation_policy_set_step_up)
-  [Function `set_authorizer`](#0x1_attestation_policy_set_authorizer)
-  [Function `clear_step_up`](#0x1_attestation_policy_clear_step_up)
-  [Function `add_admins`](#0x1_attestation_policy_add_admins)
-  [Function `remove_admins`](#0x1_attestation_policy_remove_admins)
-  [Function `add_guardians`](#0x1_attestation_policy_add_guardians)
-  [Function `remove_guardians`](#0x1_attestation_policy_remove_guardians)
-  [Function `pause`](#0x1_attestation_policy_pause)
-  [Function `unpause`](#0x1_attestation_policy_unpause)
-  [Function `set_paused`](#0x1_attestation_policy_set_paused)
-  [Function `require`](#0x1_attestation_policy_require)
-  [Function `require_authorized`](#0x1_attestation_policy_require_authorized)
-  [Function `check`](#0x1_attestation_policy_check)
-  [Function `create_policy_account`](#0x1_attestation_policy_create_policy_account)
-  [Function `create_policy_seed`](#0x1_attestation_policy_create_policy_seed)
-  [Function `empty_body`](#0x1_attestation_policy_empty_body)
-  [Function `build_body`](#0x1_attestation_policy_build_body)
-  [Function `build_source_refs`](#0x1_attestation_policy_build_source_refs)
-  [Function `eval_attr_rule`](#0x1_attestation_policy_eval_attr_rule)
-  [Function `gte_bytes`](#0x1_attestation_policy_gte_bytes)
-  [Function `validate_members`](#0x1_attestation_policy_validate_members)
-  [Function `add_members`](#0x1_attestation_policy_add_members)
-  [Function `remove_members`](#0x1_attestation_policy_remove_members)
-  [Function `assert_policy_exists`](#0x1_attestation_policy_assert_policy_exists)
-  [Function `assert_admin`](#0x1_attestation_policy_assert_admin)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `evaluate`](#@Specification_1_evaluate)
    -  [Function `is_paused`](#@Specification_1_is_paused)
    -  [Function `step_up_for`](#@Specification_1_step_up_for)
    -  [Function `has_pending`](#@Specification_1_has_pending)
    -  [Function `standard_version`](#@Specification_1_standard_version)
    -  [Function `create`](#@Specification_1_create)
    -  [Function `stage_body`](#@Specification_1_stage_body)
    -  [Function `stage_attr_rules`](#@Specification_1_stage_attr_rules)
    -  [Function `activate_pending`](#@Specification_1_activate_pending)
    -  [Function `cancel_pending`](#@Specification_1_cancel_pending)
    -  [Function `set_step_up`](#@Specification_1_set_step_up)
    -  [Function `set_authorizer`](#@Specification_1_set_authorizer)
    -  [Function `remove_admins`](#@Specification_1_remove_admins)
    -  [Function `set_paused`](#@Specification_1_set_paused)
    -  [Function `require`](#@Specification_1_require)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="attestation.md#0x1_attestation">0x1::attestation</a>;
<b>use</b> <a href="attestation_authorization.md#0x1_attestation_authorization">0x1::attestation_authorization</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_attestation_policy_SourceRef"></a>

## Struct `SourceRef`

One source the policy consults, and the minimum level it must vouch at.


<pre><code><b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_SourceRef">SourceRef</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>min_level: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_AttrRule"></a>

## Struct `AttrRule`

A predicate over one attribute of one source.


<pre><code><b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_AttrRule">AttrRule</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>source: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>key: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>op: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_Body"></a>

## Struct `Body`

The rules themselves, swapped atomically when a staged body activates.


<pre><code><b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_Body">Body</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>require_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_SourceRef">attestation_policy::SourceRef</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>require_all: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_SourceRef">attestation_policy::SourceRef</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>attr_rules: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_AttrRule">attestation_policy::AttrRule</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_Staged"></a>

## Struct `Staged`

A body waiting for its activation time.


<pre><code><b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_Staged">Staged</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>body: <a href="attestation_policy.md#0x1_attestation_policy_Body">attestation_policy::Body</a></code>
</dt>
<dd>

</dd>
<dt>
<code>effective_at_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_Policy"></a>

## Resource `Policy`

Stored at the policy's resource account address.


<pre><code><b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>paused: bool</code>
</dt>
<dd>

</dd>
<dt>
<code>body: <a href="attestation_policy.md#0x1_attestation_policy_Body">attestation_policy::Body</a></code>
</dt>
<dd>

</dd>
<dt>
<code>pending: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Staged">attestation_policy::Staged</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>step_up_above: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u8, u64&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>authorizer_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>authorizer_max_ttl_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_CreatePolicy"></a>

## Struct `CreatePolicy`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_CreatePolicy">CreatePolicy</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>deployer: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_AddMembers"></a>

## Struct `AddMembers`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_AddMembers">AddMembers</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>role: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>members: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_RemoveMembers"></a>

## Struct `RemoveMembers`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_RemoveMembers">RemoveMembers</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>role: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>members: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_StageBody"></a>

## Struct `StageBody`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_StageBody">StageBody</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>effective_at_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_ActivateBody"></a>

## Struct `ActivateBody`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_ActivateBody">ActivateBody</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>at_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_CancelPending"></a>

## Struct `CancelPending`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_CancelPending">CancelPending</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_SetStepUp"></a>

## Struct `SetStepUp`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_SetStepUp">SetStepUp</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>action: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>threshold: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_SetAuthorizer"></a>

## Struct `SetAuthorizer`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_SetAuthorizer">SetAuthorizer</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>max_ttl_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_policy_SetPaused"></a>

## Struct `SetPaused`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation_policy.md#0x1_attestation_policy_SetPaused">SetPaused</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>policy: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>paused: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_attestation_policy_DOMAIN_SEPARATOR"></a>

Domain separator used when deriving the resource account seed, to avoid collisions with
other modules that create resource accounts.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 116, 116, 101, 115, 116, 97, 116, 105, 111, 110, 95, 112, 111, 108, 105, 99, 121];
</code></pre>



<a id="0x1_attestation_policy_EDUPLICATE_MEMBER"></a>

A role list cannot contain duplicate addresses.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>: u64 = 4;
</code></pre>



<a id="0x1_attestation_policy_ELENGTH_MISMATCH"></a>

Argument vectors have differing lengths.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ELENGTH_MISMATCH">ELENGTH_MISMATCH</a>: u64 = 10;
</code></pre>



<a id="0x1_attestation_policy_ENOT_ADMIN"></a>

The caller is not an admin.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ENOT_ADMIN">ENOT_ADMIN</a>: u64 = 2;
</code></pre>



<a id="0x1_attestation_policy_ENOT_ENOUGH_ADMINS"></a>

A policy must have at least one admin.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ENOT_ENOUGH_ADMINS">ENOT_ENOUGH_ADMINS</a>: u64 = 6;
</code></pre>



<a id="0x1_attestation_policy_ENOT_GUARDIAN"></a>

The caller is not a guardian.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ENOT_GUARDIAN">ENOT_GUARDIAN</a>: u64 = 3;
</code></pre>



<a id="0x1_attestation_policy_ESELF_CANNOT_BE_MEMBER"></a>

The policy account itself cannot hold a role.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>: u64 = 5;
</code></pre>



<a id="0x1_attestation_policy_EWOULD_REMOVE_ALL_ADMINS"></a>

Removing these admins would leave the policy with zero admins.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EWOULD_REMOVE_ALL_ADMINS">EWOULD_REMOVE_ALL_ADMINS</a>: u64 = 7;
</code></pre>



<a id="0x1_attestation_policy_ROLE_ADMIN"></a>



<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ROLE_ADMIN">ROLE_ADMIN</a>: u8 = 0;
</code></pre>



<a id="0x1_attestation_policy_ROLE_GUARDIAN"></a>



<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ROLE_GUARDIAN">ROLE_GUARDIAN</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_policy_VERSION"></a>

Published version of this module's interface.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_VERSION">VERSION</a>: u64 = 1;
</code></pre>



<a id="0x1_attestation_policy_ACTION_BORROW"></a>

Borrow.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_BORROW">ACTION_BORROW</a>: u8 = 5;
</code></pre>



<a id="0x1_attestation_policy_ACTION_MINT"></a>

Mint.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_MINT">ACTION_MINT</a>: u8 = 3;
</code></pre>



<a id="0x1_attestation_policy_ACTION_RECEIVE"></a>

Receive value.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_RECEIVE">ACTION_RECEIVE</a>: u8 = 2;
</code></pre>



<a id="0x1_attestation_policy_ACTION_REDEEM"></a>

Redeem or burn.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_REDEEM">ACTION_REDEEM</a>: u8 = 4;
</code></pre>



<a id="0x1_attestation_policy_ACTION_TRANSFER"></a>

Transfer value out of the subject's control.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_TRANSFER">ACTION_TRANSFER</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_policy_ACTION_VOTE"></a>

Vote.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ACTION_VOTE">ACTION_VOTE</a>: u8 = 6;
</code></pre>



<a id="0x1_attestation_policy_DECISION_ALLOW"></a>

The subject may take the action.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a>: u8 = 0;
</code></pre>



<a id="0x1_attestation_policy_DECISION_DENY"></a>

The subject may not take the action.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_policy_DECISION_STEP_UP"></a>

The subject may take the action only with a fresh authorization attached.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_DECISION_STEP_UP">DECISION_STEP_UP</a>: u8 = 2;
</code></pre>



<a id="0x1_attestation_policy_EACCOUNT_NOT_POLICY"></a>

Specified account is not a policy.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EACCOUNT_NOT_POLICY">EACCOUNT_NOT_POLICY</a>: u64 = 1;
</code></pre>



<a id="0x1_attestation_policy_EBAD_AUTHORIZER"></a>

The authorizer key must be 32 bytes or empty.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EBAD_AUTHORIZER">EBAD_AUTHORIZER</a>: u64 = 17;
</code></pre>



<a id="0x1_attestation_policy_EBAD_RULE"></a>

An attribute predicate is malformed.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EBAD_RULE">EBAD_RULE</a>: u64 = 16;
</code></pre>



<a id="0x1_attestation_policy_EDENIED"></a>

The subject may not take this action.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EDENIED">EDENIED</a>: u64 = 13;
</code></pre>



<a id="0x1_attestation_policy_ENOT_EFFECTIVE"></a>

The staged body's activation time has not arrived.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ENOT_EFFECTIVE">ENOT_EFFECTIVE</a>: u64 = 12;
</code></pre>



<a id="0x1_attestation_policy_ENO_PENDING"></a>

No staged body is waiting.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ENO_PENDING">ENO_PENDING</a>: u64 = 11;
</code></pre>



<a id="0x1_attestation_policy_ESTEP_UP_REQUIRED"></a>

The action needs a fresh authorization, which was not supplied.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ESTEP_UP_REQUIRED">ESTEP_UP_REQUIRED</a>: u64 = 14;
</code></pre>



<a id="0x1_attestation_policy_ETOO_MANY_CHAIN_DENY"></a>

At most one chain-wide denial source may be named.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_CHAIN_DENY">ETOO_MANY_CHAIN_DENY</a>: u64 = 18;
</code></pre>



<a id="0x1_attestation_policy_ETOO_MANY_RULES"></a>

A body carries more predicates than MAX_RULES.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_RULES">ETOO_MANY_RULES</a>: u64 = 9;
</code></pre>



<a id="0x1_attestation_policy_ETOO_MANY_SOURCES"></a>

A list names more sources than MAX_SOURCES.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_SOURCES">ETOO_MANY_SOURCES</a>: u64 = 8;
</code></pre>



<a id="0x1_attestation_policy_EUNKNOWN_SOURCE"></a>

A named source does not exist.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_EUNKNOWN_SOURCE">EUNKNOWN_SOURCE</a>: u64 = 15;
</code></pre>



<a id="0x1_attestation_policy_MAX_RULES"></a>

Largest number of attribute predicates a body may carry.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_MAX_RULES">MAX_RULES</a>: u64 = 16;
</code></pre>



<a id="0x1_attestation_policy_MAX_SOURCES"></a>

Largest number of sources any one list in a body may name.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>: u64 = 16;
</code></pre>



<a id="0x1_attestation_policy_OP_EQ"></a>

The attribute value must equal the single listed value.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_OP_EQ">OP_EQ</a>: u8 = 2;
</code></pre>



<a id="0x1_attestation_policy_OP_GTE"></a>

The attribute value must be greater than or equal to the single listed value, compared as a
big-endian unsigned integer of the same length.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_OP_GTE">OP_GTE</a>: u8 = 3;
</code></pre>



<a id="0x1_attestation_policy_OP_IN"></a>

The attribute value must be one of the listed values.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_OP_IN">OP_IN</a>: u8 = 0;
</code></pre>



<a id="0x1_attestation_policy_OP_NOT_IN"></a>

The attribute value must not be any of the listed values.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_OP_NOT_IN">OP_NOT_IN</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_policy_REASON_AMOUNT_THRESHOLD"></a>

The amount is above the policy's step-up threshold for this action.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_AMOUNT_THRESHOLD">REASON_AMOUNT_THRESHOLD</a>: u16 = 7;
</code></pre>



<a id="0x1_attestation_policy_REASON_ATTR_FAILED"></a>

An attribute predicate failed.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_ATTR_FAILED">REASON_ATTR_FAILED</a>: u16 = 6;
</code></pre>



<a id="0x1_attestation_policy_REASON_CHAIN_DENIED"></a>

Excluded by the chain-wide denial source.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_CHAIN_DENIED">REASON_CHAIN_DENIED</a>: u16 = 1;
</code></pre>



<a id="0x1_attestation_policy_REASON_EMPTY_BODY"></a>

The policy has no rules, so it allows nothing.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_EMPTY_BODY">REASON_EMPTY_BODY</a>: u16 = 9;
</code></pre>



<a id="0x1_attestation_policy_REASON_LEVEL_TOO_LOW"></a>

A source vouches for the subject but below the level the policy requires.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_LEVEL_TOO_LOW">REASON_LEVEL_TOO_LOW</a>: u16 = 5;
</code></pre>



<a id="0x1_attestation_policy_REASON_MISSING_REQUIRED"></a>

A source the policy requires does not vouch for the subject.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_MISSING_REQUIRED">REASON_MISSING_REQUIRED</a>: u16 = 3;
</code></pre>



<a id="0x1_attestation_policy_REASON_NO_QUALIFYING"></a>

No source among the alternatives vouches for the subject.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_NO_QUALIFYING">REASON_NO_QUALIFYING</a>: u16 = 4;
</code></pre>



<a id="0x1_attestation_policy_REASON_OK"></a>

Allowed.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_OK">REASON_OK</a>: u16 = 0;
</code></pre>



<a id="0x1_attestation_policy_REASON_POLICY_PAUSED"></a>

The policy is paused.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_POLICY_PAUSED">REASON_POLICY_PAUSED</a>: u16 = 8;
</code></pre>



<a id="0x1_attestation_policy_REASON_SOURCE_DENIED"></a>

Excluded by one of the policy's denial sources.


<pre><code><b>const</b> <a href="attestation_policy.md#0x1_attestation_policy_REASON_SOURCE_DENIED">REASON_SOURCE_DENIED</a>: u16 = 2;
</code></pre>



<a id="0x1_attestation_policy_get_next_policy_address"></a>

## Function `get_next_policy_address`

Return the predicted address for the next policy deployed by the given account.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_get_next_policy_address">get_next_policy_address</a>(deployer: <b>address</b>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_get_next_policy_address">get_next_policy_address</a>(deployer: <b>address</b>): <b>address</b> {
    <b>let</b> owner_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(deployer);
    create_resource_address(&deployer, <a href="attestation_policy.md#0x1_attestation_policy_create_policy_seed">create_policy_seed</a>(to_bytes(&owner_nonce)))
}
</code></pre>



</details>

<a id="0x1_attestation_policy_evaluate"></a>

## Function `evaluate`

Evaluate the policy for a subject, action and amount, returning a decision and a reason.

The order below is the load-bearing part of this module. Denial comes before anything
positive and cannot be outvoted by a source that vouches.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): (u8, u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
): (u8, u16) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> config = &<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];

    <b>if</b> (config.paused) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_POLICY_PAUSED">REASON_POLICY_PAUSED</a>)
    };

    <b>let</b> body = &config.body;

    // A policy <b>with</b> no positive rule allows nothing. Stated explicitly so an unconfigured
    // policy is a loud failure rather than an open door.
    <b>if</b> (body.require_any.is_empty() && body.require_all.is_empty()) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_EMPTY_BODY">REASON_EMPTY_BODY</a>)
    };

    // 1. chain-wide denial
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&body.chain_deny)) {
        <b>let</b> chain_source = *<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&body.chain_deny);
        <b>if</b> (<a href="attestation.md#0x1_attestation_is_denied">attestation::is_denied</a>(chain_source, subject)) {
            <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_CHAIN_DENIED">REASON_CHAIN_DENIED</a>)
        };
    };

    // 2. per-source denials
    <b>let</b> denied = <b>false</b>;
    body.deny_any.for_each_ref(|source| {
        <b>if</b> (!denied && <a href="attestation.md#0x1_attestation_is_denied">attestation::is_denied</a>(*source, subject)) {
            denied = <b>true</b>;
        };
    });
    <b>if</b> (denied) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_SOURCE_DENIED">REASON_SOURCE_DENIED</a>)
    };

    // 3. every required source must vouch, at or above its level
    <b>let</b> missing = <b>false</b>;
    <b>let</b> too_low = <b>false</b>;
    body.require_all.for_each_ref(|entry| {
        <b>if</b> (!missing && !too_low) {
            <b>let</b> (active, level) = <a href="attestation.md#0x1_attestation_active_with_level">attestation::active_with_level</a>(entry.source, subject);
            <b>if</b> (!active) {
                missing = <b>true</b>;
            } <b>else</b> <b>if</b> (level &lt; entry.min_level) {
                too_low = <b>true</b>;
            };
        };
    });
    <b>if</b> (missing) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_MISSING_REQUIRED">REASON_MISSING_REQUIRED</a>)
    };
    <b>if</b> (too_low) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_LEVEL_TOO_LOW">REASON_LEVEL_TOO_LOW</a>)
    };

    // 4. at least one alternative must vouch, when <a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a> are configured
    <b>if</b> (!body.require_any.is_empty()) {
        <b>let</b> qualified = <b>false</b>;
        body.require_any.for_each_ref(|entry| {
            <b>if</b> (!qualified) {
                <b>let</b> (active, level) = <a href="attestation.md#0x1_attestation_active_with_level">attestation::active_with_level</a>(entry.source, subject);
                <b>if</b> (active && level &gt;= entry.min_level) {
                    qualified = <b>true</b>;
                };
            };
        });
        <b>if</b> (!qualified) {
            <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_NO_QUALIFYING">REASON_NO_QUALIFYING</a>)
        };
    };

    // 5. attribute predicates
    <b>let</b> failed = <b>false</b>;
    body.attr_rules.for_each_ref(|rule| {
        <b>if</b> (!failed && !<a href="attestation_policy.md#0x1_attestation_policy_eval_attr_rule">eval_attr_rule</a>(rule, subject)) {
            failed = <b>true</b>;
        };
    });
    <b>if</b> (failed) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_ATTR_FAILED">REASON_ATTR_FAILED</a>)
    };

    // 6. step-up threshold for this action
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.step_up_above, action)
        && amount &gt; *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.step_up_above, action)) {
        <b>return</b> (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_STEP_UP">DECISION_STEP_UP</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_AMOUNT_THRESHOLD">REASON_AMOUNT_THRESHOLD</a>)
    };

    (<a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a>, <a href="attestation_policy.md#0x1_attestation_policy_REASON_OK">REASON_OK</a>)
}
</code></pre>



</details>

<a id="0x1_attestation_policy_is_allowed"></a>

## Function `is_allowed`

Whether the subject may take the action outright, with no authorization needed.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_allowed">is_allowed</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_allowed">is_allowed</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
): bool <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> (decision, _) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
    decision == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a>
}
</code></pre>



</details>

<a id="0x1_attestation_policy_decision_of"></a>

## Function `decision_of`

Decision only, for a caller that does not need the reason.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_decision_of">decision_of</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_decision_of">decision_of</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
): u8 <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> (decision, _) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
    decision
}
</code></pre>



</details>

<a id="0x1_attestation_policy_reason_of"></a>

## Function `reason_of`

Reason only, for a wallet that wants to explain a refusal rather than show a revert.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_reason_of">reason_of</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): u16
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_reason_of">reason_of</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
): u16 <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> (_, reason) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
    reason
}
</code></pre>



</details>

<a id="0x1_attestation_policy_simulate"></a>

## Function `simulate`

Dry-run the policy against a population, returning one decision per subject in order.
A business uses this to see what a staged rule change will do before its time arrives.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_simulate">simulate</a>(policy: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, action: u8, amount: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_simulate">simulate</a>(
    policy: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, action: u8, amount: u64
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> decisions = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    subjects.for_each(|subject| {
        <b>let</b> (decision, _) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
        decisions.push_back(decision);
    });
    decisions
}
</code></pre>



</details>

<a id="0x1_attestation_policy_simulate_counts"></a>

## Function `simulate_counts`

Counts of allow, deny and step-up over a population, in that order.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_simulate_counts">simulate_counts</a>(policy: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, action: u8, amount: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_simulate_counts">simulate_counts</a>(
    policy: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, action: u8, amount: u64
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> counts = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[0, 0, 0];
    <a href="attestation_policy.md#0x1_attestation_policy_simulate">simulate</a>(policy, subjects, action, amount).for_each(|decision| {
        <b>let</b> slot = counts.borrow_mut((decision <b>as</b> u64));
        *slot += 1;
    });
    counts
}
</code></pre>



</details>

<a id="0x1_attestation_policy_admins"></a>

## Function `admins`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_admins">admins</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_admins">admins</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].admins
}
</code></pre>



</details>

<a id="0x1_attestation_policy_guardians"></a>

## Function `guardians`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_guardians">guardians</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_guardians">guardians</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].guardians
}
</code></pre>



</details>

<a id="0x1_attestation_policy_is_admin"></a>

## Function `is_admin`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_admin">is_admin</a>(addr: <b>address</b>, policy: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_admin">is_admin</a>(addr: <b>address</b>, policy: <b>address</b>): bool <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].admins.contains(&addr)
}
</code></pre>



</details>

<a id="0x1_attestation_policy_is_paused"></a>

## Function `is_paused`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_paused">is_paused</a>(policy: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_paused">is_paused</a>(policy: <b>address</b>): bool <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].paused
}
</code></pre>



</details>

<a id="0x1_attestation_policy_require_any_sources"></a>

## Function `require_any_sources`

Sources named in <code>require_any</code>, with their minimum levels alongside in <code>require_any_levels</code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_any_sources">require_any_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_any_sources">require_any_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> sources = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].body.require_any.for_each_ref(|entry| {
        sources.push_back(entry.source);
    });
    sources
}
</code></pre>



</details>

<a id="0x1_attestation_policy_require_all_sources"></a>

## Function `require_all_sources`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_all_sources">require_all_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_all_sources">require_all_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> sources = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].body.require_all.for_each_ref(|entry| {
        sources.push_back(entry.source);
    });
    sources
}
</code></pre>



</details>

<a id="0x1_attestation_policy_deny_any_sources"></a>

## Function `deny_any_sources`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_deny_any_sources">deny_any_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_deny_any_sources">deny_any_sources</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].body.deny_any
}
</code></pre>



</details>

<a id="0x1_attestation_policy_step_up_for"></a>

## Function `step_up_for`

Amount above which this action needs an authorization, or 0 when it never does.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_step_up_for">step_up_for</a>(policy: <b>address</b>, action: u8): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_step_up_for">step_up_for</a>(policy: <b>address</b>, action: u8): u64 <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> thresholds = &<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].step_up_above;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(thresholds, action)) {
        *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(thresholds, action)
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_attestation_policy_has_pending"></a>

## Function `has_pending`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_has_pending">has_pending</a>(policy: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_has_pending">has_pending</a>(policy: <b>address</b>): bool <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].pending)
}
</code></pre>



</details>

<a id="0x1_attestation_policy_pending_effective_at"></a>

## Function `pending_effective_at`

When the staged body becomes active, or 0 when nothing is staged.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_pending_effective_at">pending_effective_at</a>(policy: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_pending_effective_at">pending_effective_at</a>(policy: <b>address</b>): u64 <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> pending = &<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].pending;
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(pending)) {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(pending).effective_at_secs
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_attestation_policy_authorizer_pubkey"></a>

## Function `authorizer_pubkey`

The key that signs authorizations for this policy, or empty when step-up is disabled.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_authorizer_pubkey">authorizer_pubkey</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_authorizer_pubkey">authorizer_pubkey</a>(policy: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].authorizer_pubkey
}
</code></pre>



</details>

<a id="0x1_attestation_policy_authorizer_max_ttl_secs"></a>

## Function `authorizer_max_ttl_secs`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_authorizer_max_ttl_secs">authorizer_max_ttl_secs</a>(policy: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_authorizer_max_ttl_secs">authorizer_max_ttl_secs</a>(policy: <b>address</b>): u64 <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].authorizer_max_ttl_secs
}
</code></pre>



</details>

<a id="0x1_attestation_policy_standard_version"></a>

## Function `standard_version`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_standard_version">standard_version</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_standard_version">standard_version</a>(): u64 {
    <a href="attestation_policy.md#0x1_attestation_policy_VERSION">VERSION</a>
}
</code></pre>



</details>

<a id="0x1_attestation_policy_create"></a>

## Function `create`

Create a new policy. The deployer only authorizes resource-account creation and pays gas;
it gains no role unless listed. The body starts empty, which denies everything until rules
are staged and activated.

@param deployer Signer that authorizes resource-account creation and pays gas.
@param admins Addresses allowed to stage rules. At least one, no duplicates.
@param guardians Addresses allowed to pause evaluation. May be empty.
@abort If a list has duplicates, names the policy itself, or there is no admin.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create">create</a>(
    deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) {
    <b>let</b> (policy_signer, policy_signer_cap) = <a href="attestation_policy.md#0x1_attestation_policy_create_policy_account">create_policy_account</a>(deployer);
    <b>let</b> policy_address = address_of(&policy_signer);
    <b>assert</b>!(admins.length() &gt;= 1, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENOT_ENOUGH_ADMINS">ENOT_ENOUGH_ADMINS</a>));
    <a href="attestation_policy.md#0x1_attestation_policy_validate_members">validate_members</a>(&admins, policy_address);
    <a href="attestation_policy.md#0x1_attestation_policy_validate_members">validate_members</a>(&guardians, policy_address);

    <b>move_to</b>(
        &policy_signer,
        <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
            admins,
            guardians,
            paused: <b>false</b>,
            body: <a href="attestation_policy.md#0x1_attestation_policy_empty_body">empty_body</a>(),
            pending: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>(),
            step_up_above: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u8, u64&gt;(),
            authorizer_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
            authorizer_max_ttl_secs: 0,
            signer_cap: policy_signer_cap
        }
    );
    <a href="attestation_authorization.md#0x1_attestation_authorization_initialize">attestation_authorization::initialize</a>(&policy_signer);
    emit(
        <a href="attestation_policy.md#0x1_attestation_policy_CreatePolicy">CreatePolicy</a> {
            policy: policy_address,
            deployer: address_of(deployer),
            admins
        }
    );
}
</code></pre>



</details>

<a id="0x1_attestation_policy_stage_body"></a>

## Function `stage_body`

Stage a new body, to take effect at <code>effective_at_secs</code>. Staging rather than applying
immediately is what keeps a rule change from breaking a transaction already in flight.

@param admin An admin of the policy.
@param policy The policy address.
@param require_any_sources Sources of which at least one must vouch. May be empty.
@param require_any_levels Minimum level per entry, same length as require_any_sources.
@param require_all_sources Sources that must all vouch. May be empty.
@param require_all_levels Minimum level per entry, same length as require_all_sources.
@param deny_any Sources whose denial denies. May be empty.
@param chain_deny Optional chain-wide denial source: empty for none, or exactly one address.
A vector rather than an <code>Option</code> because entry functions cannot take <code>Option</code> arguments.
@param effective_at_secs When the body becomes active.
@abort If the lengths differ, a list is over MAX_SOURCES, chain_deny names more than one
source, or a named source does not exist.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_body">stage_body</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, require_any_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_any_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, require_all_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_all_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, effective_at_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_body">stage_body</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    policy: <b>address</b>,
    require_any_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    require_any_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    require_all_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    require_all_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    effective_at_secs: u64
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>assert</b>!(chain_deny.length() &lt;= 1, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_CHAIN_DENY">ETOO_MANY_CHAIN_DENY</a>));
    <b>let</b> chain_deny =
        <b>if</b> (chain_deny.is_empty()) <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
        <b>else</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(chain_deny[0]);
    <b>let</b> body =
        <a href="attestation_policy.md#0x1_attestation_policy_build_body">build_body</a>(
            require_any_sources,
            require_any_levels,
            require_all_sources,
            require_all_levels,
            deny_any,
            chain_deny
        );
    // Keep <a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a> predicates already staged, so the two staging calls compose in either order.
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&config.pending)) {
        body.attr_rules = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&config.pending).body.attr_rules;
    };
    config.pending = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(<a href="attestation_policy.md#0x1_attestation_policy_Staged">Staged</a> { body, effective_at_secs });
    emit(<a href="attestation_policy.md#0x1_attestation_policy_StageBody">StageBody</a> { policy, effective_at_secs });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_stage_attr_rules"></a>

## Function `stage_attr_rules`

Stage attribute predicates onto the pending body. Call <code>stage_body</code> first.

@param sources Source whose attribute each predicate reads.
@param keys Attribute key per predicate.
@param ops One of OP_IN, OP_NOT_IN, OP_EQ, OP_GTE.
@param values Candidate values per predicate. OP_EQ and OP_GTE take exactly one.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_attr_rules">stage_attr_rules</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, ops: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_attr_rules">stage_attr_rules</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    policy: <b>address</b>,
    sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;,
    ops: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> count = sources.length();
    <b>assert</b>!(count &lt;= <a href="attestation_policy.md#0x1_attestation_policy_MAX_RULES">MAX_RULES</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_RULES">ETOO_MANY_RULES</a>));
    <b>assert</b>!(
        count == keys.length() && count == ops.length() && count == values.length(),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ELENGTH_MISMATCH">ELENGTH_MISMATCH</a>)
    );

    <b>let</b> rules = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> index = 0;
    <b>while</b> (index &lt; count) {
        <b>let</b> op = ops[index];
        <b>assert</b>!(op &lt;= <a href="attestation_policy.md#0x1_attestation_policy_OP_GTE">OP_GTE</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EBAD_RULE">EBAD_RULE</a>));
        <b>let</b> candidates = values[index];
        // A comparison against a set is meaningless <b>with</b> no members, and <a href="attestation_policy.md#0x1_attestation_policy_OP_EQ">OP_EQ</a> and <a href="attestation_policy.md#0x1_attestation_policy_OP_GTE">OP_GTE</a>
        // compare against exactly one.
        <b>assert</b>!(!candidates.is_empty(), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EBAD_RULE">EBAD_RULE</a>));
        <b>if</b> (op == <a href="attestation_policy.md#0x1_attestation_policy_OP_EQ">OP_EQ</a> || op == <a href="attestation_policy.md#0x1_attestation_policy_OP_GTE">OP_GTE</a>) {
            <b>assert</b>!(candidates.length() == 1, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EBAD_RULE">EBAD_RULE</a>));
        };
        <b>assert</b>!(
            <a href="attestation.md#0x1_attestation_is_source">attestation::is_source</a>(sources[index]),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_policy.md#0x1_attestation_policy_EUNKNOWN_SOURCE">EUNKNOWN_SOURCE</a>)
        );
        rules.push_back(
            <a href="attestation_policy.md#0x1_attestation_policy_AttrRule">AttrRule</a> { source: sources[index], key: keys[index], op, values: candidates }
        );
        index += 1;
    };

    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <b>let</b> staged =
        <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&config.pending)) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> config.pending)
        } <b>else</b> {
            <a href="attestation_policy.md#0x1_attestation_policy_Staged">Staged</a> { body: config.body, effective_at_secs: now_seconds() }
        };
    staged.body.attr_rules = rules;
    <b>let</b> effective_at_secs = staged.effective_at_secs;
    config.pending = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(staged);
    emit(<a href="attestation_policy.md#0x1_attestation_policy_StageBody">StageBody</a> { policy, effective_at_secs });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_activate_pending"></a>

## Function `activate_pending`

Push the staged body live. Permissionless once its time has arrived, so the business does
not have to be online at the moment its own rule change takes effect.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_activate_pending">activate_pending</a>(_anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_activate_pending">activate_pending</a>(_anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&config.pending), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENO_PENDING">ENO_PENDING</a>));
    <b>let</b> staged = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> config.pending);
    <b>assert</b>!(
        now_seconds() &gt;= staged.effective_at_secs,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENOT_EFFECTIVE">ENOT_EFFECTIVE</a>)
    );
    config.body = staged.body;
    emit(<a href="attestation_policy.md#0x1_attestation_policy_ActivateBody">ActivateBody</a> { policy, at_secs: now_seconds() });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_cancel_pending"></a>

## Function `cancel_pending`

Discard a staged body that has not activated yet.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_cancel_pending">cancel_pending</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_cancel_pending">cancel_pending</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&config.pending), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENO_PENDING">ENO_PENDING</a>));
    config.pending = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>();
    emit(<a href="attestation_policy.md#0x1_attestation_policy_CancelPending">CancelPending</a> { policy });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_set_step_up"></a>

## Function `set_step_up`

Set the amount above which an action needs a fresh authorization. Absent by default, so a
liveness dependency is never enabled by accident.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_step_up">set_step_up</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, action: u8, threshold: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_step_up">set_step_up</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, action: u8, threshold: u64
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_upsert">table::upsert</a>(&<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].step_up_above, action, threshold);
    emit(<a href="attestation_policy.md#0x1_attestation_policy_SetStepUp">SetStepUp</a> { policy, action, threshold });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_set_authorizer"></a>

## Function `set_authorizer`

Set the key that signs authorizations for this policy, and the longest window it may
issue. A window of 0 with an empty key disables the step-up path entirely.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_authorizer">set_authorizer</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, max_ttl_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_authorizer">set_authorizer</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, max_ttl_secs: u64
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>assert</b>!(
        pubkey.is_empty() || pubkey.length() == 32,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EBAD_AUTHORIZER">EBAD_AUTHORIZER</a>)
    );
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    config.authorizer_pubkey = pubkey;
    config.authorizer_max_ttl_secs = max_ttl_secs;
    emit(<a href="attestation_policy.md#0x1_attestation_policy_SetAuthorizer">SetAuthorizer</a> { policy, max_ttl_secs });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_clear_step_up"></a>

## Function `clear_step_up`

Stop demanding authorization for an action.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_clear_step_up">clear_step_up</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, action: u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_clear_step_up">clear_step_up</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, action: u8) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> thresholds = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].step_up_above;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(thresholds, action)) {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_remove">table::remove</a>(thresholds, action);
    };
    emit(<a href="attestation_policy.md#0x1_attestation_policy_SetStepUp">SetStepUp</a> { policy, action, threshold: 0 });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_add_admins"></a>

## Function `add_admins`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_admins">add_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, new_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_admins">add_admins</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, new_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <a href="attestation_policy.md#0x1_attestation_policy_add_members">add_members</a>(&<b>mut</b> config.admins, &new_admins, policy);
    emit(<a href="attestation_policy.md#0x1_attestation_policy_AddMembers">AddMembers</a> { policy, role: <a href="attestation_policy.md#0x1_attestation_policy_ROLE_ADMIN">ROLE_ADMIN</a>, members: new_admins });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_remove_admins"></a>

## Function `remove_admins`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_admins">remove_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_admins">remove_admins</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <a href="attestation_policy.md#0x1_attestation_policy_remove_members">remove_members</a>(&<b>mut</b> config.admins, &old_admins);
    <b>assert</b>!(
        config.admins.length() &gt;= 1,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation_policy.md#0x1_attestation_policy_EWOULD_REMOVE_ALL_ADMINS">EWOULD_REMOVE_ALL_ADMINS</a>)
    );
    emit(<a href="attestation_policy.md#0x1_attestation_policy_RemoveMembers">RemoveMembers</a> { policy, role: <a href="attestation_policy.md#0x1_attestation_policy_ROLE_ADMIN">ROLE_ADMIN</a>, members: old_admins });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_add_guardians"></a>

## Function `add_guardians`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_guardians">add_guardians</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, new_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_guardians">add_guardians</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, new_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <a href="attestation_policy.md#0x1_attestation_policy_add_members">add_members</a>(&<b>mut</b> config.guardians, &new_guardians, policy);
    emit(<a href="attestation_policy.md#0x1_attestation_policy_AddMembers">AddMembers</a> { policy, role: <a href="attestation_policy.md#0x1_attestation_policy_ROLE_GUARDIAN">ROLE_GUARDIAN</a>, members: new_guardians });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_remove_guardians"></a>

## Function `remove_guardians`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_guardians">remove_guardians</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, old_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_guardians">remove_guardians</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, old_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <a href="attestation_policy.md#0x1_attestation_policy_remove_members">remove_members</a>(&<b>mut</b> config.guardians, &old_guardians);
    emit(<a href="attestation_policy.md#0x1_attestation_policy_RemoveMembers">RemoveMembers</a> { policy, role: <a href="attestation_policy.md#0x1_attestation_policy_ROLE_GUARDIAN">ROLE_GUARDIAN</a>, members: old_guardians });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_pause"></a>

## Function `pause`

Deny everything until unpaused. Denies loudly with REASON_POLICY_PAUSED rather than
silently allowing.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_pause">pause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_pause">pause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_set_paused">set_paused</a>(guardian, policy, <b>true</b>);
}
</code></pre>



</details>

<a id="0x1_attestation_policy_unpause"></a>

## Function `unpause`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_unpause">unpause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_unpause">unpause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_set_paused">set_paused</a>(guardian, policy, <b>false</b>);
}
</code></pre>



</details>

<a id="0x1_attestation_policy_set_paused"></a>

## Function `set_paused`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, paused: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, paused: bool) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>assert</b>!(
        <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].guardians.contains(&address_of(guardian)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENOT_GUARDIAN">ENOT_GUARDIAN</a>)
    );
    <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].paused = paused;
    emit(<a href="attestation_policy.md#0x1_attestation_policy_SetPaused">SetPaused</a> { policy, paused });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_require"></a>

## Function `require`

The common case, one line inside an entry function. Aborts unless the subject may act
outright.

@abort EDENIED when the policy refuses, ESTEP_UP_REQUIRED when it wants an authorization.


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require">require</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require">require</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> (decision, _) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
    <b>assert</b>!(decision != <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation_policy.md#0x1_attestation_policy_EDENIED">EDENIED</a>));
    <b>assert</b>!(
        decision != <a href="attestation_policy.md#0x1_attestation_policy_DECISION_STEP_UP">DECISION_STEP_UP</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation_policy.md#0x1_attestation_policy_ESTEP_UP_REQUIRED">ESTEP_UP_REQUIRED</a>)
    );
}
</code></pre>



</details>

<a id="0x1_attestation_policy_require_authorized"></a>

## Function `require_authorized`

The step-up variant. The authorization is a transaction argument, which is the point:
unlike a view call, which leaves no trace, it lands in the ledger permanently and gives the
business an independently verifiable record of why it allowed this specific action.

An allow decision consumes nothing, so a caller may always route through this function.


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_authorized">require_authorized</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64, authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require_authorized">require_authorized</a>(
    policy: <b>address</b>,
    subject: <b>address</b>,
    action: u8,
    amount: u64,
    authorization: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <b>let</b> (decision, _) = <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount);
    <b>assert</b>!(decision != <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation_policy.md#0x1_attestation_policy_EDENIED">EDENIED</a>));
    <b>if</b> (decision == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a>) {
        <b>return</b>
    };
    <b>let</b> config = &<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy];
    <a href="attestation_authorization.md#0x1_attestation_authorization_verify_and_consume">attestation_authorization::verify_and_consume</a>(
        policy,
        config.authorizer_pubkey,
        config.authorizer_max_ttl_secs,
        subject,
        action,
        amount,
        authorization
    );
}
</code></pre>



</details>

<a id="0x1_attestation_policy_check"></a>

## Function `check`

Non-aborting form, for a caller that wants to branch rather than fail.


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_check">check</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): (u8, u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_check">check</a>(
    policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64
): (u8, u16) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy, subject, action, amount)
}
</code></pre>



</details>

<a id="0x1_attestation_policy_create_policy_account"></a>

## Function `create_policy_account`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create_policy_account">create_policy_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create_policy_account">create_policy_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, SignerCapability) {
    <b>let</b> deployer_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(address_of(deployer));
    <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
        deployer, <a href="attestation_policy.md#0x1_attestation_policy_create_policy_seed">create_policy_seed</a>(to_bytes(&deployer_nonce))
    )
}
</code></pre>



</details>

<a id="0x1_attestation_policy_create_policy_seed"></a>

## Function `create_policy_seed`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create_policy_seed">create_policy_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create_policy_seed">create_policy_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> account_seed = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    account_seed.append(<a href="attestation_policy.md#0x1_attestation_policy_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>);
    account_seed.append(seed);
    account_seed
}
</code></pre>



</details>

<a id="0x1_attestation_policy_empty_body"></a>

## Function `empty_body`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_empty_body">empty_body</a>(): <a href="attestation_policy.md#0x1_attestation_policy_Body">attestation_policy::Body</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_empty_body">empty_body</a>(): <a href="attestation_policy.md#0x1_attestation_policy_Body">Body</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_Body">Body</a> {
        require_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        require_all: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        attr_rules: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    }
}
</code></pre>



</details>

<a id="0x1_attestation_policy_build_body"></a>

## Function `build_body`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_build_body">build_body</a>(require_any_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_any_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, require_all_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_all_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;): <a href="attestation_policy.md#0x1_attestation_policy_Body">attestation_policy::Body</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_build_body">build_body</a>(
    require_any_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    require_any_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    require_all_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    require_all_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    chain_deny: Option&lt;<b>address</b>&gt;
): <a href="attestation_policy.md#0x1_attestation_policy_Body">Body</a> {
    <b>assert</b>!(
        require_any_sources.length() &lt;= <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>
            && require_all_sources.length() &lt;= <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>
            && deny_any.length() &lt;= <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ETOO_MANY_SOURCES">ETOO_MANY_SOURCES</a>)
    );
    <b>assert</b>!(
        require_any_sources.length() == require_any_levels.length()
            && require_all_sources.length() == require_all_levels.length(),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ELENGTH_MISMATCH">ELENGTH_MISMATCH</a>)
    );

    // A named source that does not exist would <b>abort</b> at evaluation time, which would brick the
    // policy for every subject. Reject it at staging time instead, <b>where</b> it is one caller's
    // problem rather than everyone's.
    deny_any.for_each_ref(|source| {
        <b>assert</b>!(<a href="attestation.md#0x1_attestation_is_source">attestation::is_source</a>(*source), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_policy.md#0x1_attestation_policy_EUNKNOWN_SOURCE">EUNKNOWN_SOURCE</a>));
    });
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&chain_deny)) {
        <b>assert</b>!(
            <a href="attestation.md#0x1_attestation_is_source">attestation::is_source</a>(*<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(&chain_deny)),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_policy.md#0x1_attestation_policy_EUNKNOWN_SOURCE">EUNKNOWN_SOURCE</a>)
        );
    };

    <a href="attestation_policy.md#0x1_attestation_policy_Body">Body</a> {
        require_any: <a href="attestation_policy.md#0x1_attestation_policy_build_source_refs">build_source_refs</a>(require_any_sources, require_any_levels),
        require_all: <a href="attestation_policy.md#0x1_attestation_policy_build_source_refs">build_source_refs</a>(require_all_sources, require_all_levels),
        deny_any,
        attr_rules: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        chain_deny
    }
}
</code></pre>



</details>

<a id="0x1_attestation_policy_build_source_refs"></a>

## Function `build_source_refs`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_build_source_refs">build_source_refs</a>(sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_SourceRef">attestation_policy::SourceRef</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_build_source_refs">build_source_refs</a>(
    sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation_policy.md#0x1_attestation_policy_SourceRef">SourceRef</a>&gt; {
    <b>let</b> refs = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> index = 0;
    <b>while</b> (index &lt; sources.length()) {
        <b>assert</b>!(
            <a href="attestation.md#0x1_attestation_is_source">attestation::is_source</a>(sources[index]),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_policy.md#0x1_attestation_policy_EUNKNOWN_SOURCE">EUNKNOWN_SOURCE</a>)
        );
        refs.push_back(<a href="attestation_policy.md#0x1_attestation_policy_SourceRef">SourceRef</a> { source: sources[index], min_level: levels[index] });
        index += 1;
    };
    refs
}
</code></pre>



</details>

<a id="0x1_attestation_policy_eval_attr_rule"></a>

## Function `eval_attr_rule`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_eval_attr_rule">eval_attr_rule</a>(rule: &<a href="attestation_policy.md#0x1_attestation_policy_AttrRule">attestation_policy::AttrRule</a>, subject: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_eval_attr_rule">eval_attr_rule</a>(rule: &<a href="attestation_policy.md#0x1_attestation_policy_AttrRule">AttrRule</a>, subject: <b>address</b>): bool {
    <b>let</b> value = <a href="attestation.md#0x1_attestation_attribute_of">attestation::attribute_of</a>(rule.source, subject, rule.key);
    // An unset attribute satisfies only <a href="attestation_policy.md#0x1_attestation_policy_OP_NOT_IN">OP_NOT_IN</a>: a subject the source says nothing about is
    // not in <a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a> list, but neither does it meet a positive requirement.
    <b>if</b> (value.is_empty()) {
        <b>return</b> rule.op == <a href="attestation_policy.md#0x1_attestation_policy_OP_NOT_IN">OP_NOT_IN</a>
    };
    <b>if</b> (rule.op == <a href="attestation_policy.md#0x1_attestation_policy_OP_IN">OP_IN</a>) {
        rule.values.contains(&value)
    } <b>else</b> <b>if</b> (rule.op == <a href="attestation_policy.md#0x1_attestation_policy_OP_NOT_IN">OP_NOT_IN</a>) {
        !rule.values.contains(&value)
    } <b>else</b> <b>if</b> (rule.op == <a href="attestation_policy.md#0x1_attestation_policy_OP_EQ">OP_EQ</a>) {
        value == rule.values[0]
    } <b>else</b> {
        <a href="attestation_policy.md#0x1_attestation_policy_gte_bytes">gte_bytes</a>(&value, &rule.values[0])
    }
}
</code></pre>



</details>

<a id="0x1_attestation_policy_gte_bytes"></a>

## Function `gte_bytes`

Big-endian unsigned comparison. Values of differing length are not comparable, so the
predicate fails rather than guessing an alignment.


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_gte_bytes">gte_bytes</a>(left: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, right: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_gte_bytes">gte_bytes</a>(left: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, right: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool {
    <b>if</b> (left.length() != right.length()) {
        <b>return</b> <b>false</b>
    };
    <b>let</b> index = 0;
    <b>while</b> (index &lt; left.length()) {
        <b>if</b> (left[index] &gt; right[index]) {
            <b>return</b> <b>true</b>
        };
        <b>if</b> (left[index] &lt; right[index]) {
            <b>return</b> <b>false</b>
        };
        index += 1;
    };
    <b>true</b>
}
</code></pre>



</details>

<a id="0x1_attestation_policy_validate_members"></a>

## Function `validate_members`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, policy_address: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, policy_address: <b>address</b>) {
    <b>let</b> distinct: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    members.for_each_ref(|member| {
        <b>assert</b>!(
            *member != policy_address,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>)
        );
        <b>assert</b>!(
            !distinct.contains(member),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>)
        );
        distinct.push_back(*member);
    });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_add_members"></a>

## Function `add_members`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_members">add_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, new_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, policy_address: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_add_members">add_members</a>(
    list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, new_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, policy_address: <b>address</b>
) {
    <a href="attestation_policy.md#0x1_attestation_policy_validate_members">validate_members</a>(new_members, policy_address);
    new_members.for_each_ref(|member| {
        <b>assert</b>!(
            !list.contains(member),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation_policy.md#0x1_attestation_policy_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>)
        );
        list.push_back(*member);
    });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_remove_members"></a>

## Function `remove_members`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_members">remove_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, old_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_members">remove_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, old_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;) {
    old_members.for_each_ref(|member| {
        <b>let</b> (found, index) = list.index_of(member);
        <b>if</b> (found) {
            list.remove(index);
        };
    });
}
</code></pre>



</details>

<a id="0x1_attestation_policy_assert_policy_exists"></a>

## Function `assert_policy_exists`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy: <b>address</b>) {
    <b>assert</b>!(<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation_policy.md#0x1_attestation_policy_EACCOUNT_NOT_POLICY">EACCOUNT_NOT_POLICY</a>));
}
</code></pre>



</details>

<a id="0x1_attestation_policy_assert_admin"></a>

## Function `assert_admin`



<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy: <b>address</b>, addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_assert_admin">assert_admin</a>(policy: <b>address</b>, addr: <b>address</b>) <b>acquires</b> <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a> {
    <a href="attestation_policy.md#0x1_attestation_policy_assert_policy_exists">assert_policy_exists</a>(policy);
    <b>assert</b>!(
        <a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>[policy].admins.contains(&addr),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation_policy.md#0x1_attestation_policy_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification




<a id="high-level-req"></a>

### High-level Requirements

<table>
<tr>
<th>No.</th><th>Requirement</th><th>Criticality</th><th>Implementation</th><th>Enforcement</th>
</tr>

<tr>
<td>1</td>
<td>A staged body has no effect before its activation time (INV-9). Staging, re-staging and cancelling never change the live body, and only activate_pending swaps it in, once its time has arrived.</td>
<td>Critical</td>
<td>stage_body and stage_attr_rules write only Policy.pending. activate_pending asserts that a body is pending and that now_seconds() >= effective_at_secs before replacing Policy.body.</td>
<td>Formally verified via <a href="#high-level-req-1.1">stage_body</a>, <a href="#high-level-req-1.2">stage_attr_rules</a>, <a href="#high-level-req-1.3">cancel_pending</a> and <a href="#high-level-req-1.4">activate_pending</a>.</td>
</tr>

<tr>
<td>2</td>
<td>A denial always produces DECISION_DENY (INV-1). A chain-wide denial is consulted before any positive rule and wins over every vouching source.</td>
<td>Critical</td>
<td>evaluate checks the chain denial source first, then every deny_any source, before any require_all or require_any rule.</td>
<td>Formally verified for the chain denial via <a href="#high-level-req-2">evaluate</a>. The deny_any sources are consulted inside a for_each_ref loop, which the prover havocs, and are covered by unit tests (test_deny_source_beats_a_vouching_source).</td>
</tr>

<tr>
<td>3</td>
<td>A paused policy denies with its own reason rather than silently allowing, and a policy with no positive rule allows nothing.</td>
<td>High</td>
<td>evaluate returns (DECISION_DENY, REASON_POLICY_PAUSED) when paused, and (DECISION_DENY, REASON_EMPTY_BODY) when both require lists are empty.</td>
<td>Formally verified via <a href="#high-level-req-3.1">evaluate</a> and <a href="#high-level-req-3.2">require</a>.</td>
</tr>

<tr>
<td>4</td>
<td>Only an admin can stage, cancel, set step-up thresholds, set the authorizer or manage roles, only a guardian can pause, and a policy always has at least one admin.</td>
<td>Critical</td>
<td>assert_admin and the guardian check run first in every entry function, and remove_admins asserts that at least one admin remains.</td>
<td>Formally verified via <a href="#high-level-req-4.1">stage_body</a>, <a href="#high-level-req-4.2">set_paused</a> and <a href="#high-level-req-4.3">remove_admins</a>.</td>
</tr>

<tr>
<td>5</td>
<td>A body can name at most one chain-wide denial source.</td>
<td>Medium</td>
<td>stage_body asserts chain_deny has length 0 or 1.</td>
<td>Formally verified via <a href="#high-level-req-5">stage_body</a>.</td>
</tr>

</table>



<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict = <b>false</b>;
</code></pre>




<a id="0x1_attestation_policy_spec_now"></a>


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_spec_now">spec_now</a>(): u64 {
   aptos_framework::timestamp::spec_now_seconds()
}
</code></pre>




<a id="0x1_attestation_policy_PolicyAdminAbortsIf"></a>


<pre><code><b>schema</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a> {
    policy: <b>address</b>;
    admin: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>;
    <b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
    <b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).admins, address_of(admin));
}
</code></pre>



<a id="@Specification_1_evaluate"></a>

### Function `evaluate`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_evaluate">evaluate</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64): (u8, u16)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>let</b> config = <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>let</b> body = config.body;
<b>let</b> empty = len(body.require_any) == 0 && len(body.require_all) == 0;
// This enforces <a id="high-level-req-3.1" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> config.paused ==&gt; result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a> && result_2 == <a href="attestation_policy.md#0x1_attestation_policy_REASON_POLICY_PAUSED">REASON_POLICY_PAUSED</a>;
<b>ensures</b> !config.paused && empty ==&gt; result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a> && result_2 == <a href="attestation_policy.md#0x1_attestation_policy_REASON_EMPTY_BODY">REASON_EMPTY_BODY</a>;
// This enforces <a id="high-level-req-2" href="#high-level-req">high-level requirement 2</a>:
<b>ensures</b> !config.paused && !empty && <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(body.chain_deny)
    && aptos_framework::attestation::spec_is_denied(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(body.chain_deny), subject)
    ==&gt; result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a> && result_2 == <a href="attestation_policy.md#0x1_attestation_policy_REASON_CHAIN_DENIED">REASON_CHAIN_DENIED</a>;
<b>ensures</b> result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a> ==&gt; result_2 == <a href="attestation_policy.md#0x1_attestation_policy_REASON_OK">REASON_OK</a>;
<b>ensures</b> result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_ALLOW">DECISION_ALLOW</a> || result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_DENY">DECISION_DENY</a> || result_1 == <a href="attestation_policy.md#0x1_attestation_policy_DECISION_STEP_UP">DECISION_STEP_UP</a>;
</code></pre>



<a id="@Specification_1_is_paused"></a>

### Function `is_paused`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_is_paused">is_paused</a>(policy: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>ensures</b> result == <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).paused;
</code></pre>



<a id="@Specification_1_step_up_for"></a>

### Function `step_up_for`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_step_up_for">step_up_for</a>(policy: <b>address</b>, action: u8): u64
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>let</b> thresholds = <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).step_up_above;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(thresholds, action) ==&gt; result == <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(thresholds, action);
<b>ensures</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(thresholds, action) ==&gt; result == 0;
</code></pre>



<a id="@Specification_1_has_pending"></a>

### Function `has_pending`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_has_pending">has_pending</a>(policy: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>ensures</b> result == <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
</code></pre>



<a id="@Specification_1_standard_version"></a>

### Function `standard_version`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_standard_version">standard_version</a>(): u64
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == <a href="attestation_policy.md#0x1_attestation_policy_VERSION">VERSION</a>;
</code></pre>



<a id="@Specification_1_create"></a>

### Function `create`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> verify = <b>false</b>;
</code></pre>



<a id="@Specification_1_stage_body"></a>

### Function `stage_body`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_body">stage_body</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, require_any_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_any_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, require_all_sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, require_all_levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, deny_any: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, chain_deny: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, effective_at_secs: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
// This enforces <a id="high-level-req-4.1" href="#high-level-req">high-level requirement 4</a>:
<b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
// This enforces <a id="high-level-req-5" href="#high-level-req">high-level requirement 5</a>:
<b>aborts_if</b> len(chain_deny) &gt; 1;
<b>aborts_if</b> len(require_any_sources) &gt; <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>;
<b>aborts_if</b> len(require_all_sources) &gt; <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>;
<b>aborts_if</b> len(deny_any) &gt; <a href="attestation_policy.md#0x1_attestation_policy_MAX_SOURCES">MAX_SOURCES</a>;
<b>aborts_if</b> len(require_any_sources) != len(require_any_levels);
<b>aborts_if</b> len(require_all_sources) != len(require_all_levels);
<b>let</b> <b>post</b> config = <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
// This enforces <a id="high-level-req-1.1" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> config.body == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body);
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(config.pending);
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).effective_at_secs == effective_at_secs;
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).body.deny_any == deny_any;
<b>ensures</b> len(chain_deny) == 0 ==&gt; <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).body.chain_deny);
<b>ensures</b> len(chain_deny) == 1 ==&gt; <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).body.chain_deny == <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_spec_some">option::spec_some</a>(chain_deny[0]);
</code></pre>



<a id="@Specification_1_stage_attr_rules"></a>

### Function `stage_attr_rules`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_stage_attr_rules">stage_attr_rules</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, sources: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u16&gt;, ops: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
<b>aborts_if</b> len(sources) &gt; <a href="attestation_policy.md#0x1_attestation_policy_MAX_RULES">MAX_RULES</a>;
<b>aborts_if</b> len(sources) != len(keys) || len(sources) != len(ops) || len(sources) != len(values);
// This enforces <a id="high-level-req-1.2" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body);
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
</code></pre>



<a id="@Specification_1_activate_pending"></a>

### Function `activate_pending`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_activate_pending">activate_pending</a>(_anyone: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>




<pre><code><b>let</b> config = <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
<b>aborts_if</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(config.pending);
<b>aborts_if</b> !<b>exists</b>&lt;aptos_framework::timestamp::CurrentTimeMicroseconds&gt;(@aptos_framework);
// This enforces <a id="high-level-req-1.4" href="#high-level-req">high-level requirement 1</a>:
<b>aborts_if</b> <a href="attestation_policy.md#0x1_attestation_policy_spec_now">spec_now</a>() &lt; <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).effective_at_secs;
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body == <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_borrow">option::borrow</a>(config.pending).body;
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
</code></pre>



<a id="@Specification_1_cancel_pending"></a>

### Function `cancel_pending`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_cancel_pending">cancel_pending</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>)
</code></pre>




<pre><code><b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
<b>aborts_if</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
// This enforces <a id="high-level-req-1.3" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body);
<b>ensures</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
</code></pre>



<a id="@Specification_1_set_step_up"></a>

### Function `set_step_up`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_step_up">set_step_up</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, action: u8, threshold: u64)
</code></pre>




<pre><code><b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).step_up_above, action) == threshold;
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body);
</code></pre>



<a id="@Specification_1_set_authorizer"></a>

### Function `set_authorizer`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_authorizer">set_authorizer</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, max_ttl_secs: u64)
</code></pre>




<pre><code><b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
<b>aborts_if</b> len(pubkey) != 0 && len(pubkey) != 32;
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).authorizer_pubkey == pubkey;
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).authorizer_max_ttl_secs == max_ttl_secs;
</code></pre>



<a id="@Specification_1_remove_admins"></a>

### Function `remove_admins`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_remove_admins">remove_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation_policy.md#0x1_attestation_policy_PolicyAdminAbortsIf">PolicyAdminAbortsIf</a>;
// This enforces <a id="high-level-req-4.3" href="#high-level-req">high-level requirement 4</a>:
<b>ensures</b> len(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).admins) &gt;= 1;
</code></pre>



<a id="@Specification_1_set_paused"></a>

### Function `set_paused`


<pre><code><b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, policy: <b>address</b>, paused: bool)
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
// This enforces <a id="high-level-req-4.2" href="#high-level-req">high-level requirement 4</a>:
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).guardians, address_of(guardian));
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).paused == paused;
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body);
<b>ensures</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending == <b>old</b>(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).pending);
</code></pre>



<a id="@Specification_1_require"></a>

### Function `require`


<pre><code><b>public</b> <b>fun</b> <a href="attestation_policy.md#0x1_attestation_policy_require">require</a>(policy: <b>address</b>, subject: <b>address</b>, action: u8, amount: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy);
// This enforces <a id="high-level-req-3.2" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> <b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).paused;
<b>aborts_if</b> len(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body.require_any) == 0
    && len(<b>global</b>&lt;<a href="attestation_policy.md#0x1_attestation_policy_Policy">Policy</a>&gt;(policy).body.require_all) == 0;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
