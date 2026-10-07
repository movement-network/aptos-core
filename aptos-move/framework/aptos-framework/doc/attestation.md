
<a id="0x1_attestation"></a>

# Module `0x1::attestation`

Attestation source module for Movement. A source is an independent namespace that asserts
facts about addresses: who is verified, at what level, with what attributes, and who is
excluded. Anyone may create one, and nothing here is globally trusted, so a consumer names the
sources it trusts or gets no answer. Two sources may disagree about the same subject and
nothing is broken, because a fact is never true globally, only true according to somebody.

Each source is a resource account, following <code>aptos_framework::timelock</code>: the deployer
authorizes creation and pays gas but gains no role unless it is listed in the role arguments.
The account has no owner, so unlike an object it cannot be transferred or burned out from under
the integrators that hardcoded its address.

Roles, and why each is separate:
- Admins configure the source, register and rotate issuers, and grant roles.
- Issuers write facts. This is the hot key, and it deliberately cannot touch denials or roles.
- Sentinels may ADD denials only, which is the fast path for sanctions screening.
- Removers may REMOVE denials only. Mistaken denial is the dominant operational failure mode in
production systems of this kind, so reversal is a designed path with a different key rather
than an afterthought.
- Guardians may pause writes without needing the admin path.
An address may hold several roles; the overlap is allowed on purpose so authority can be handed
over without a gap, exactly as <code>timelock</code> allows for its canceler role.

Delayed governance comes for free by composition: an admin address may be a
<code>aptos_framework::timelock</code> account, in which case every configuration change inherits that
module's delay, multi-role and cancel semantics. This module deliberately does not reimplement
any of it.

Properties:
- Denial is evaluated before anything else and no positive write can create, modify or clear it.
- A fact is never active past its expiry, below its issuer's epoch, or below the source floor.
- Bumping an issuer's epoch invalidates every fact that issuer wrote, in one write, which is
the remedy for a compromised issuer key and is O(1) in the size of the cohort.
- Pausing blocks writes and never changes the answer <code>is_verified</code> gives. A pause must not
silently flip a boolean that other protocols depend on.
- Configuration and facts live in two separate resources so the read path touches only
immutable state and per-subject table keys, and gated transactions therefore never conflict
with one another under Block-STM.


-  [Struct `Change`](#0x1_attestation_Change)
-  [Struct `Record`](#0x1_attestation_Record)
-  [Struct `DenyEntry`](#0x1_attestation_DenyEntry)
-  [Struct `Root`](#0x1_attestation_Root)
-  [Struct `Issuer`](#0x1_attestation_Issuer)
-  [Resource `Source`](#0x1_attestation_Source)
-  [Resource `Facts`](#0x1_attestation_Facts)
-  [Struct `CreateSource`](#0x1_attestation_CreateSource)
-  [Struct `AddMembers`](#0x1_attestation_AddMembers)
-  [Struct `RemoveMembers`](#0x1_attestation_RemoveMembers)
-  [Struct `RegisterIssuer`](#0x1_attestation_RegisterIssuer)
-  [Struct `RotateIssuerKey`](#0x1_attestation_RotateIssuerKey)
-  [Struct `BumpIssuerEpoch`](#0x1_attestation_BumpIssuerEpoch)
-  [Struct `SetFloorEpoch`](#0x1_attestation_SetFloorEpoch)
-  [Struct `RecordFact`](#0x1_attestation_RecordFact)
-  [Struct `SetAttribute`](#0x1_attestation_SetAttribute)
-  [Struct `PublishRoot`](#0x1_attestation_PublishRoot)
-  [Struct `Deny`](#0x1_attestation_Deny)
-  [Struct `Undeny`](#0x1_attestation_Undeny)
-  [Struct `SetPaused`](#0x1_attestation_SetPaused)
-  [Constants](#@Constants_0)
-  [Function `get_next_source_address`](#0x1_attestation_get_next_source_address)
-  [Function `is_verified`](#0x1_attestation_is_verified)
-  [Function `state_of`](#0x1_attestation_state_of)
-  [Function `level_of`](#0x1_attestation_level_of)
-  [Function `active_with_level`](#0x1_attestation_active_with_level)
-  [Function `record_of`](#0x1_attestation_record_of)
-  [Function `attribute_of`](#0x1_attestation_attribute_of)
-  [Function `is_denied`](#0x1_attestation_is_denied)
-  [Function `deny_reason`](#0x1_attestation_deny_reason)
-  [Function `expires_at`](#0x1_attestation_expires_at)
-  [Function `current_root`](#0x1_attestation_current_root)
-  [Function `verify_membership`](#0x1_attestation_verify_membership)
-  [Function `admins`](#0x1_attestation_admins)
-  [Function `issuers`](#0x1_attestation_issuers)
-  [Function `sentinels`](#0x1_attestation_sentinels)
-  [Function `removers`](#0x1_attestation_removers)
-  [Function `guardians`](#0x1_attestation_guardians)
-  [Function `is_admin`](#0x1_attestation_is_admin)
-  [Function `is_issuer`](#0x1_attestation_is_issuer)
-  [Function `issuer_id_of`](#0x1_attestation_issuer_id_of)
-  [Function `issuer_epoch_of`](#0x1_attestation_issuer_epoch_of)
-  [Function `floor_epoch`](#0x1_attestation_floor_epoch)
-  [Function `is_paused`](#0x1_attestation_is_paused)
-  [Function `is_source`](#0x1_attestation_is_source)
-  [Function `standard_version`](#0x1_attestation_standard_version)
-  [Function `attestation_message`](#0x1_attestation_attestation_message)
-  [Function `create`](#0x1_attestation_create)
-  [Function `create_source_internal`](#0x1_attestation_create_source_internal)
-  [Function `add_admins`](#0x1_attestation_add_admins)
-  [Function `remove_admins`](#0x1_attestation_remove_admins)
-  [Function `add_issuers`](#0x1_attestation_add_issuers)
-  [Function `remove_issuers`](#0x1_attestation_remove_issuers)
-  [Function `add_sentinels`](#0x1_attestation_add_sentinels)
-  [Function `remove_sentinels`](#0x1_attestation_remove_sentinels)
-  [Function `add_removers`](#0x1_attestation_add_removers)
-  [Function `remove_removers`](#0x1_attestation_remove_removers)
-  [Function `add_guardians`](#0x1_attestation_add_guardians)
-  [Function `remove_guardians`](#0x1_attestation_remove_guardians)
-  [Function `pause`](#0x1_attestation_pause)
-  [Function `unpause`](#0x1_attestation_unpause)
-  [Function `set_paused`](#0x1_attestation_set_paused)
-  [Function `register_issuer`](#0x1_attestation_register_issuer)
-  [Function `rotate_issuer_key`](#0x1_attestation_rotate_issuer_key)
-  [Function `bump_issuer_epoch`](#0x1_attestation_bump_issuer_epoch)
-  [Function `set_floor_epoch`](#0x1_attestation_set_floor_epoch)
-  [Function `issue_batch`](#0x1_attestation_issue_batch)
-  [Function `revoke_batch`](#0x1_attestation_revoke_batch)
-  [Function `suspend`](#0x1_attestation_suspend)
-  [Function `unsuspend`](#0x1_attestation_unsuspend)
-  [Function `set_attribute`](#0x1_attestation_set_attribute)
-  [Function `remove_attribute`](#0x1_attestation_remove_attribute)
-  [Function `redeem_attestation`](#0x1_attestation_redeem_attestation)
-  [Function `source_signer`](#0x1_attestation_source_signer)
-  [Function `record_verified_claim`](#0x1_attestation_record_verified_claim)
-  [Function `deny`](#0x1_attestation_deny)
-  [Function `deny_batch`](#0x1_attestation_deny_batch)
-  [Function `undeny`](#0x1_attestation_undeny)
-  [Function `deny_internal`](#0x1_attestation_deny_internal)
-  [Function `publish_root`](#0x1_attestation_publish_root)
-  [Function `record_fact`](#0x1_attestation_record_fact)
-  [Function `transition`](#0x1_attestation_transition)
-  [Function `create_source_account`](#0x1_attestation_create_source_account)
-  [Function `create_source_seed`](#0x1_attestation_create_source_seed)
-  [Function `validate_members`](#0x1_attestation_validate_members)
-  [Function `add_members`](#0x1_attestation_add_members)
-  [Function `remove_members`](#0x1_attestation_remove_members)
-  [Function `push_history`](#0x1_attestation_push_history)
-  [Function `bind_nullifier`](#0x1_attestation_bind_nullifier)
-  [Function `assert_newer`](#0x1_attestation_assert_newer)
-  [Function `is_denied_internal`](#0x1_attestation_is_denied_internal)
-  [Function `assert_source_exists`](#0x1_attestation_assert_source_exists)
-  [Function `assert_admin`](#0x1_attestation_assert_admin)
-  [Function `assert_not_paused`](#0x1_attestation_assert_not_paused)
-  [Function `assert_issuer`](#0x1_attestation_assert_issuer)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `active_with_level`](#@Specification_1_active_with_level)
    -  [Function `is_denied`](#@Specification_1_is_denied)
    -  [Function `admins`](#@Specification_1_admins)
    -  [Function `is_admin`](#@Specification_1_is_admin)
    -  [Function `is_issuer`](#@Specification_1_is_issuer)
    -  [Function `issuer_epoch_of`](#@Specification_1_issuer_epoch_of)
    -  [Function `floor_epoch`](#@Specification_1_floor_epoch)
    -  [Function `is_paused`](#@Specification_1_is_paused)
    -  [Function `is_source`](#@Specification_1_is_source)
    -  [Function `standard_version`](#@Specification_1_standard_version)
    -  [Function `create`](#@Specification_1_create)
    -  [Function `create_source_internal`](#@Specification_1_create_source_internal)
    -  [Function `add_admins`](#@Specification_1_add_admins)
    -  [Function `remove_admins`](#@Specification_1_remove_admins)
    -  [Function `pause`](#@Specification_1_pause)
    -  [Function `unpause`](#@Specification_1_unpause)
    -  [Function `set_paused`](#@Specification_1_set_paused)
    -  [Function `bump_issuer_epoch`](#@Specification_1_bump_issuer_epoch)
    -  [Function `set_floor_epoch`](#@Specification_1_set_floor_epoch)
    -  [Function `suspend`](#@Specification_1_suspend)
    -  [Function `unsuspend`](#@Specification_1_unsuspend)
    -  [Function `redeem_attestation`](#@Specification_1_redeem_attestation)
    -  [Function `record_verified_claim`](#@Specification_1_record_verified_claim)
    -  [Function `deny`](#@Specification_1_deny)
    -  [Function `deny_batch`](#@Specification_1_deny_batch)
    -  [Function `undeny`](#@Specification_1_undeny)
    -  [Function `publish_root`](#@Specification_1_publish_root)
    -  [Function `record_fact`](#@Specification_1_record_fact)
    -  [Function `transition`](#@Specification_1_transition)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash">0x1::aptos_hash</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="chain_id.md#0x1_chain_id">0x1::chain_id</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519">0x1::ed25519</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="merkle_proof.md#0x1_merkle_proof">0x1::merkle_proof</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map">0x1::simple_map</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_attestation_Change"></a>

## Struct `Change`

One entry in a subject's change history.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Change">Change</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>prev_state: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>new_state: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>reason: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_id: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_Record"></a>

## Struct `Record`

What one source asserts about one subject.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Record">Record</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>state: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>level: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_id: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>issued_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>expires_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>revoked_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>reason: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>attrs: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_SimpleMap">simple_map::SimpleMap</a>&lt;u16, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>history: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation.md#0x1_attestation_Change">attestation::Change</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_DenyEntry"></a>

## Struct `DenyEntry`

An exclusion. Written only by a sentinel, removed only by a remover, and unreachable from
every positive write path.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_DenyEntry">DenyEntry</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>reason: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>effective_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>added_at_secs: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_Root"></a>

## Struct `Root`

A published set commitment. Present for interoperability, since an EVM contract can verify
the same root, and for audit, since a third party can check the published set matches the
claim. It is not a storage compression device.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Root">Root</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>leaf_count: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>published_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_id: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_Issuer"></a>

## Struct `Issuer`

A registered issuer. <code>pubkey</code> is used only by the permissionless relay path.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Issuer">Issuer</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>id: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>active: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_Source"></a>

## Resource `Source`

Configuration and governance. Mutable, and deliberately never read by the check path.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Source">Source</a> <b>has</b> key
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
<code>issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_info: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_Issuer">attestation::Issuer</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_by_id: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u16, <b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>next_issuer_id: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>paused: bool</code>
</dt>
<dd>

</dd>
<dt>
<code>root_epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>roots: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u64, <a href="attestation.md#0x1_attestation_Root">attestation::Root</a>&gt;</code>
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

<a id="0x1_attestation_Facts"></a>

## Resource `Facts`

Facts. This resource is written once at creation and never again: only its table ENTRIES
change, and each entry is its own state key. That is what keeps gated transactions from
conflicting with one another under Block-STM.


<pre><code><b>struct</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>subjects: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_Record">attestation::Record</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>denied: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_DenyEntry">attestation::DenyEntry</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>nullifiers: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_epochs: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u16, u64&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>floor_epoch: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;u8, u64&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_CreateSource"></a>

## Struct `CreateSource`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_CreateSource">CreateSource</a> <b>has</b> drop, store
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
<code>deployer: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_AddMembers"></a>

## Struct `AddMembers`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> <b>has</b> drop, store
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

<a id="0x1_attestation_RemoveMembers"></a>

## Struct `RemoveMembers`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> <b>has</b> drop, store
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

<a id="0x1_attestation_RegisterIssuer"></a>

## Struct `RegisterIssuer`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_RegisterIssuer">RegisterIssuer</a> <b>has</b> drop, store
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
<code>issuer: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>id: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_RotateIssuerKey"></a>

## Struct `RotateIssuerKey`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_RotateIssuerKey">RotateIssuerKey</a> <b>has</b> drop, store
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
<code>id: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_BumpIssuerEpoch"></a>

## Struct `BumpIssuerEpoch`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_BumpIssuerEpoch">BumpIssuerEpoch</a> <b>has</b> drop, store
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
<code>id: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_SetFloorEpoch"></a>

## Struct `SetFloorEpoch`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_SetFloorEpoch">SetFloorEpoch</a> <b>has</b> drop, store
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
<code>epoch: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_RecordFact"></a>

## Struct `RecordFact`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_RecordFact">RecordFact</a> <b>has</b> drop, store
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
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>state: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>level: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>issuer_id: u16</code>
</dt>
<dd>

</dd>
<dt>
<code>expires_at_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>reason: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_SetAttribute"></a>

## Struct `SetAttribute`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_SetAttribute">SetAttribute</a> <b>has</b> drop, store
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
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>key: u16</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_PublishRoot"></a>

## Struct `PublishRoot`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_PublishRoot">PublishRoot</a> <b>has</b> drop, store
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
<code>epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>leaf_count: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_Deny"></a>

## Struct `Deny`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_Deny">Deny</a> <b>has</b> drop, store
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
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>reason: u16</code>
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

<a id="0x1_attestation_Undeny"></a>

## Struct `Undeny`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_Undeny">Undeny</a> <b>has</b> drop, store
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
<code>subject: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_attestation_SetPaused"></a>

## Struct `SetPaused`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="attestation.md#0x1_attestation_SetPaused">SetPaused</a> <b>has</b> drop, store
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
<code>paused: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_attestation_DIGEST_LENGTH"></a>

Required length of a 32-byte digest, nullifier or root.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_DOMAIN_ATTESTATION"></a>

Domain separator for the message an issuer signs for the permissionless relay path. Keeps a
relay attestation from being reinterpreted as any other signed payload.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_DOMAIN_ATTESTATION">DOMAIN_ATTESTATION</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 116, 116, 101, 115, 116, 97, 116, 105, 111, 110, 58, 58, 65, 84, 84, 69, 83, 84];
</code></pre>



<a id="0x1_attestation_DOMAIN_SEPARATOR"></a>

Domain separator used when deriving the resource account seed, to avoid collisions with
other modules that create resource accounts.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 116, 116, 101, 115, 116, 97, 116, 105, 111, 110];
</code></pre>



<a id="0x1_attestation_EACCOUNT_NOT_SOURCE"></a>

Specified account is not an attestation source.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EACCOUNT_NOT_SOURCE">EACCOUNT_NOT_SOURCE</a>: u64 = 1;
</code></pre>



<a id="0x1_attestation_EBAD_ATTRIBUTE"></a>

The attribute key is in the reserved range but is not a known vocabulary key.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EBAD_ATTRIBUTE">EBAD_ATTRIBUTE</a>: u64 = 22;
</code></pre>



<a id="0x1_attestation_EBAD_SIGNATURE"></a>

The issuer signature over the relayed attestation did not verify.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EBAD_SIGNATURE">EBAD_SIGNATURE</a>: u64 = 16;
</code></pre>



<a id="0x1_attestation_EBATCH_TOO_LARGE"></a>

The batch exceeds MAX_BATCH.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>: u64 = 13;
</code></pre>



<a id="0x1_attestation_EDUPLICATE_ISSUER"></a>

An issuer is already registered under this address.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EDUPLICATE_ISSUER">EDUPLICATE_ISSUER</a>: u64 = 15;
</code></pre>



<a id="0x1_attestation_EDUPLICATE_MEMBER"></a>

A role list cannot contain duplicate addresses.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>: u64 = 8;
</code></pre>



<a id="0x1_attestation_EINVALID_BYTES_LENGTH"></a>

The provided digest, nullifier or root must be exactly 32 bytes.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>: u64 = 23;
</code></pre>



<a id="0x1_attestation_EINVALID_TRANSITION"></a>

The record's current state does not allow this lifecycle change.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EINVALID_TRANSITION">EINVALID_TRANSITION</a>: u64 = 25;
</code></pre>



<a id="0x1_attestation_ELENGTH_MISMATCH"></a>

Batch argument vectors have differing lengths.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ELENGTH_MISMATCH">ELENGTH_MISMATCH</a>: u64 = 12;
</code></pre>



<a id="0x1_attestation_ENOT_ADMIN"></a>

The caller is not an admin.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_ADMIN">ENOT_ADMIN</a>: u64 = 2;
</code></pre>



<a id="0x1_attestation_ENOT_ENOUGH_ADMINS"></a>

A source must have at least one admin.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_ENOUGH_ADMINS">ENOT_ENOUGH_ADMINS</a>: u64 = 10;
</code></pre>



<a id="0x1_attestation_ENOT_GUARDIAN"></a>

The caller is not a guardian.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_GUARDIAN">ENOT_GUARDIAN</a>: u64 = 6;
</code></pre>



<a id="0x1_attestation_ENOT_ISSUER"></a>

The caller is not a registered, active issuer.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_ISSUER">ENOT_ISSUER</a>: u64 = 3;
</code></pre>



<a id="0x1_attestation_ENOT_MONOTONIC"></a>

A newer attestation has already been recorded for this subject.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_MONOTONIC">ENOT_MONOTONIC</a>: u64 = 18;
</code></pre>



<a id="0x1_attestation_ENOT_REMOVER"></a>

The caller is not a remover.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_REMOVER">ENOT_REMOVER</a>: u64 = 5;
</code></pre>



<a id="0x1_attestation_ENOT_SENTINEL"></a>

The caller is not a sentinel.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENOT_SENTINEL">ENOT_SENTINEL</a>: u64 = 4;
</code></pre>



<a id="0x1_attestation_ENULLIFIER_BOUND"></a>

This nullifier is already bound to a different subject.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ENULLIFIER_BOUND">ENULLIFIER_BOUND</a>: u64 = 20;
</code></pre>



<a id="0x1_attestation_EPAUSED"></a>

Writes are paused on this source.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EPAUSED">EPAUSED</a>: u64 = 7;
</code></pre>



<a id="0x1_attestation_ERECORD_NOT_FOUND"></a>

No record exists for this subject.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ERECORD_NOT_FOUND">ERECORD_NOT_FOUND</a>: u64 = 21;
</code></pre>



<a id="0x1_attestation_EROOT_NOT_FOUND"></a>

No root has been published for the requested epoch.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EROOT_NOT_FOUND">EROOT_NOT_FOUND</a>: u64 = 24;
</code></pre>



<a id="0x1_attestation_ESELF_CANNOT_BE_MEMBER"></a>

The source account itself cannot hold a role.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>: u64 = 9;
</code></pre>



<a id="0x1_attestation_ESTALE_EPOCH"></a>

The attestation names an issuer epoch other than the issuer's current one.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ESTALE_EPOCH">ESTALE_EPOCH</a>: u64 = 17;
</code></pre>



<a id="0x1_attestation_ESUBJECT_DENIED"></a>

The subject is denied, so no positive fact may be written for it.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ESUBJECT_DENIED">ESUBJECT_DENIED</a>: u64 = 19;
</code></pre>



<a id="0x1_attestation_EUNKNOWN_ISSUER"></a>

No issuer is registered under the given address or id.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>: u64 = 14;
</code></pre>



<a id="0x1_attestation_EWOULD_REMOVE_ALL_ADMINS"></a>

Removing these admins would leave the source with zero admins.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_EWOULD_REMOVE_ALL_ADMINS">EWOULD_REMOVE_ALL_ADMINS</a>: u64 = 11;
</code></pre>



<a id="0x1_attestation_MAX_ATTRS"></a>

Largest number of attributes retained per subject.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_MAX_ATTRS">MAX_ATTRS</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_MAX_BATCH"></a>

Largest number of subjects one batch call may touch.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_MAX_BATCH">MAX_BATCH</a>: u64 = 1000;
</code></pre>



<a id="0x1_attestation_MAX_HISTORY"></a>

Largest number of change entries retained per subject. Older entries are dropped.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_MAX_HISTORY">MAX_HISTORY</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_NEVER_EXPIRES"></a>

Expiry value meaning the fact never expires on its own.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_NEVER_EXPIRES">NEVER_EXPIRES</a>: u64 = 18446744073709551615;
</code></pre>



<a id="0x1_attestation_PUBKEY_LENGTH"></a>

Required length of an ed25519 public key.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_PUBKEY_LENGTH">PUBKEY_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_attestation_RESERVED_ATTR_KEYS"></a>

Attribute keys below this value are reserved for the published vocabulary.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_RESERVED_ATTR_KEYS">RESERVED_ATTR_KEYS</a>: u16 = 1024;
</code></pre>



<a id="0x1_attestation_ROLE_ADMIN"></a>



<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ROLE_ADMIN">ROLE_ADMIN</a>: u8 = 0;
</code></pre>



<a id="0x1_attestation_ROLE_GUARDIAN"></a>



<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ROLE_GUARDIAN">ROLE_GUARDIAN</a>: u8 = 4;
</code></pre>



<a id="0x1_attestation_ROLE_ISSUER"></a>



<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ROLE_ISSUER">ROLE_ISSUER</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_ROLE_REMOVER"></a>



<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ROLE_REMOVER">ROLE_REMOVER</a>: u8 = 3;
</code></pre>



<a id="0x1_attestation_ROLE_SENTINEL"></a>



<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_ROLE_SENTINEL">ROLE_SENTINEL</a>: u8 = 2;
</code></pre>



<a id="0x1_attestation_SIGNATURE_LENGTH"></a>

Required length of an ed25519 signature.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_SIGNATURE_LENGTH">SIGNATURE_LENGTH</a>: u64 = 64;
</code></pre>



<a id="0x1_attestation_STATE_ACTIVE"></a>

The source asserts this subject currently qualifies.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>: u8 = 1;
</code></pre>



<a id="0x1_attestation_STATE_NONE"></a>

No record exists. The default for every address.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_STATE_NONE">STATE_NONE</a>: u8 = 0;
</code></pre>



<a id="0x1_attestation_STATE_REVOKED"></a>

Terminal for this record; requires re-issuance rather than un-revocation.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>: u8 = 3;
</code></pre>



<a id="0x1_attestation_STATE_SUSPENDED"></a>

Temporarily withheld, reversible by the issuer.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>: u8 = 2;
</code></pre>



<a id="0x1_attestation_VERSION"></a>

Published version of this module's interface.


<pre><code><b>const</b> <a href="attestation.md#0x1_attestation_VERSION">VERSION</a>: u64 = 1;
</code></pre>



<a id="0x1_attestation_get_next_source_address"></a>

## Function `get_next_source_address`

Return the predicted address for the next source deployed by the given account. The
deployer authorizes resource-account creation but gains no role unless it is listed in the
role arguments to <code>create</code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_get_next_source_address">get_next_source_address</a>(deployer: <b>address</b>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_get_next_source_address">get_next_source_address</a>(deployer: <b>address</b>): <b>address</b> {
    <b>let</b> owner_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(deployer);
    create_resource_address(&deployer, <a href="attestation.md#0x1_attestation_create_source_seed">create_source_seed</a>(to_bytes(&owner_nonce)))
}
</code></pre>



</details>

<a id="0x1_attestation_is_verified"></a>

## Function `is_verified`

The single mandatory conformance function: does this source currently vouch for this
subject at all. Denial, expiry and epoch staleness are all accounted for.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_verified">is_verified</a>(source: <b>address</b>, subject: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_verified">is_verified</a>(source: <b>address</b>, subject: <b>address</b>): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> (active, _) = <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source, subject);
    active
}
</code></pre>



</details>

<a id="0x1_attestation_state_of"></a>

## Function `state_of`

Lifecycle state as the check path sees it, so an expired or stale record reads as
STATE_NONE and a denied subject reads as STATE_REVOKED.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_state_of">state_of</a>(source: <b>address</b>, subject: <b>address</b>): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_state_of">state_of</a>(source: <b>address</b>, subject: <b>address</b>): u8 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> (active, _) = <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source, subject);
    <b>if</b> (active) {
        <b>return</b> <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>
    };
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>if</b> (<a href="attestation.md#0x1_attestation_is_denied_internal">is_denied_internal</a>(facts, subject)) {
        <b>return</b> <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>
    };
    <b>if</b> (!<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject)) {
        <b>return</b> <a href="attestation.md#0x1_attestation_STATE_NONE">STATE_NONE</a>
    };
    <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.subjects, subject);
    <b>if</b> (record.state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>) {
        // Active but not usable, so expired or stale.
        <b>return</b> <a href="attestation.md#0x1_attestation_STATE_NONE">STATE_NONE</a>
    };
    record.state
}
</code></pre>



</details>

<a id="0x1_attestation_level_of"></a>

## Function `level_of`

Tier of a currently usable fact, or 0 when there is none.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_level_of">level_of</a>(source: <b>address</b>, subject: <b>address</b>): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_level_of">level_of</a>(source: <b>address</b>, subject: <b>address</b>): u8 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> (_, level) = <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source, subject);
    level
}
</code></pre>



</details>

<a id="0x1_attestation_active_with_level"></a>

## Function `active_with_level`

Whether this source currently vouches for the subject, and at what level, in one pass.
This is what <code>aptos_framework::attestation_policy</code> calls. Not a <code>#[view]</code> returning two
values by design: callers that want one value use <code>is_verified</code> or <code>level_of</code>.

Order is load-bearing. Denial is checked before anything else and cannot be overridden.


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source: <b>address</b>, subject: <b>address</b>): (bool, u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source: <b>address</b>, subject: <b>address</b>): (bool, u8) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];

    <b>if</b> (<a href="attestation.md#0x1_attestation_is_denied_internal">is_denied_internal</a>(facts, subject)) {
        <b>return</b> (<b>false</b>, 0)
    };
    <b>if</b> (!<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject)) {
        <b>return</b> (<b>false</b>, 0)
    };

    <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.subjects, subject);
    <b>if</b> (record.state != <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>) {
        <b>return</b> (<b>false</b>, 0)
    };
    <b>if</b> (record.expires_at_secs &lt;= now_seconds()) {
        <b>return</b> (<b>false</b>, 0)
    };
    // A bump of this issuer's epoch, or a raise of the source floor, invalidates the fact.
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.issuer_epochs, record.issuer_id)
        && record.issuer_epoch &lt; *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.issuer_epochs, record.issuer_id)) {
        <b>return</b> (<b>false</b>, 0)
    };
    <b>if</b> (record.issuer_epoch &lt; *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.floor_epoch, 0)) {
        <b>return</b> (<b>false</b>, 0)
    };

    (<b>true</b>, record.level)
}
</code></pre>



</details>

<a id="0x1_attestation_record_of"></a>

## Function `record_of`

The full record, including history and attributes. Aborts when there is none.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_record_of">record_of</a>(source: <b>address</b>, subject: <b>address</b>): <a href="attestation.md#0x1_attestation_Record">attestation::Record</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_record_of">record_of</a>(source: <b>address</b>, subject: <b>address</b>): <a href="attestation.md#0x1_attestation_Record">Record</a> <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_ERECORD_NOT_FOUND">ERECORD_NOT_FOUND</a>)
    );
    *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.subjects, subject)
}
</code></pre>



</details>

<a id="0x1_attestation_attribute_of"></a>

## Function `attribute_of`

An attribute value, or an empty vector when unset.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_attribute_of">attribute_of</a>(source: <b>address</b>, subject: <b>address</b>, key: u16): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_attribute_of">attribute_of</a>(source: <b>address</b>, subject: <b>address</b>, key: u16): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>if</b> (!<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject)) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
    };
    <b>let</b> attrs = &<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.subjects, subject).attrs;
    <b>if</b> (<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(attrs, &key)) {
        *<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(attrs, &key)
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
    }
}
</code></pre>



</details>

<a id="0x1_attestation_is_denied"></a>

## Function `is_denied`

Whether the subject is excluded and the exclusion is in effect now.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_denied">is_denied</a>(source: <b>address</b>, subject: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_denied">is_denied</a>(source: <b>address</b>, subject: <b>address</b>): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_is_denied_internal">is_denied_internal</a>(&<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source], subject)
}
</code></pre>



</details>

<a id="0x1_attestation_deny_reason"></a>

## Function `deny_reason`

Reason code attached to an exclusion, or 0 when there is none.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_deny_reason">deny_reason</a>(source: <b>address</b>, subject: <b>address</b>): u16
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_deny_reason">deny_reason</a>(source: <b>address</b>, subject: <b>address</b>): u16 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.denied, subject)) {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.denied, subject).reason
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_attestation_expires_at"></a>

## Function `expires_at`

Expiry of the stored record, or 0 when there is none.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_expires_at">expires_at</a>(source: <b>address</b>, subject: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_expires_at">expires_at</a>(source: <b>address</b>, subject: <b>address</b>): u64 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject)) {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.subjects, subject).expires_at_secs
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_attestation_current_root"></a>

## Function `current_root`

Most recently published root.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_current_root">current_root</a>(source: <b>address</b>): <a href="attestation.md#0x1_attestation_Root">attestation::Root</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_current_root">current_root</a>(source: <b>address</b>): <a href="attestation.md#0x1_attestation_Root">Root</a> <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> config = &<a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.roots, config.root_epoch),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EROOT_NOT_FOUND">EROOT_NOT_FOUND</a>)
    );
    *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.roots, config.root_epoch)
}
</code></pre>



</details>

<a id="0x1_attestation_verify_membership"></a>

## Function `verify_membership`

Membership of the subject in the most recently published root. OpenZeppelin shape: the
subject address and the proof, with no leaf index and no commitment argument.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_verify_membership">verify_membership</a>(source: <b>address</b>, subject: <b>address</b>, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_verify_membership">verify_membership</a>(
    source: <b>address</b>, subject: <b>address</b>, proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <b>let</b> root = <a href="attestation.md#0x1_attestation_current_root">current_root</a>(source);
    aptos_framework::merkle_proof::verify(
        root.digest,
        aptos_framework::merkle_proof::subject_leaf(source, subject),
        proof
    )
}
</code></pre>



</details>

<a id="0x1_attestation_admins"></a>

## Function `admins`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_admins">admins</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_admins">admins</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].admins
}
</code></pre>



</details>

<a id="0x1_attestation_issuers"></a>

## Function `issuers`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuers">issuers</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuers">issuers</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].issuers
}
</code></pre>



</details>

<a id="0x1_attestation_sentinels"></a>

## Function `sentinels`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_sentinels">sentinels</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_sentinels">sentinels</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].sentinels
}
</code></pre>



</details>

<a id="0x1_attestation_removers"></a>

## Function `removers`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_removers">removers</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_removers">removers</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].removers
}
</code></pre>



</details>

<a id="0x1_attestation_guardians"></a>

## Function `guardians`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_guardians">guardians</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_guardians">guardians</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].guardians
}
</code></pre>



</details>

<a id="0x1_attestation_is_admin"></a>

## Function `is_admin`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_admin">is_admin</a>(addr: <b>address</b>, source: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_admin">is_admin</a>(addr: <b>address</b>, source: <b>address</b>): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].admins.contains(&addr)
}
</code></pre>



</details>

<a id="0x1_attestation_is_issuer"></a>

## Function `is_issuer`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_issuer">is_issuer</a>(addr: <b>address</b>, source: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_issuer">is_issuer</a>(addr: <b>address</b>, source: <b>address</b>): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].issuers.contains(&addr)
}
</code></pre>



</details>

<a id="0x1_attestation_issuer_id_of"></a>

## Function `issuer_id_of`

Stable id assigned to an issuer at registration. Aborts when unregistered.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuer_id_of">issuer_id_of</a>(source: <b>address</b>, issuer: <b>address</b>): u16
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuer_id_of">issuer_id_of</a>(source: <b>address</b>, issuer: <b>address</b>): u16 <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> config = &<a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.issuer_info, issuer),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>)
    );
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.issuer_info, issuer).id
}
</code></pre>



</details>

<a id="0x1_attestation_issuer_epoch_of"></a>

## Function `issuer_epoch_of`

Effective epoch of an issuer: the larger of its own counter and the source floor. Facts
written below it are no longer usable, and new writes by that issuer are stamped with it.
Issuer id 0 is the zkTLS enrollment cohort, which has no registered issuer.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source: <b>address</b>, issuer_id: u16): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source: <b>address</b>, issuer_id: u16): u64 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>let</b> facts = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>let</b> own =
        <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.issuer_epochs, issuer_id)) {
            *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.issuer_epochs, issuer_id)
        } <b>else</b> { 0 };
    <b>let</b> floor = *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.floor_epoch, 0);
    <b>if</b> (own &gt; floor) { own } <b>else</b> { floor }
}
</code></pre>



</details>

<a id="0x1_attestation_floor_epoch"></a>

## Function `floor_epoch`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_floor_epoch">floor_epoch</a>(source: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_floor_epoch">floor_epoch</a>(source: <b>address</b>): u64 <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].floor_epoch, 0)
}
</code></pre>



</details>

<a id="0x1_attestation_is_paused"></a>

## Function `is_paused`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_paused">is_paused</a>(source: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_paused">is_paused</a>(source: <b>address</b>): bool <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].paused
}
</code></pre>



</details>

<a id="0x1_attestation_is_source"></a>

## Function `is_source`

Whether an address is an attestation source. Consulted by <code><a href="attestation_policy.md#0x1_attestation_policy">attestation_policy</a></code> at staging
time, so a policy cannot be configured to name a source that does not exist and then abort
for every subject at evaluation time.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_source">is_source</a>(source: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_source">is_source</a>(source: <b>address</b>): bool {
    <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source) && <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source)
}
</code></pre>



</details>

<a id="0x1_attestation_standard_version"></a>

## Function `standard_version`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_standard_version">standard_version</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_standard_version">standard_version</a>(): u64 {
    <a href="attestation.md#0x1_attestation_VERSION">VERSION</a>
}
</code></pre>



</details>

<a id="0x1_attestation_attestation_message"></a>

## Function `attestation_message`

The message an issuer signs for the permissionless relay path. Published so an issuing
service can be implemented in any language without reading this module.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_attestation_message">attestation_message</a>(source: <b>address</b>, subject: <b>address</b>, issuer_id: u16, issuer_epoch: u64, level: u8, expires_at_secs: u64, issued_at_secs: u64, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_attestation_message">attestation_message</a>(
    source: <b>address</b>,
    subject: <b>address</b>,
    issuer_id: u16,
    issuer_epoch: u64,
    level: u8,
    expires_at_secs: u64,
    issued_at_secs: u64,
    nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> message = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    message.append(<a href="attestation.md#0x1_attestation_DOMAIN_ATTESTATION">DOMAIN_ATTESTATION</a>);
    message.append(to_bytes(&<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>()));
    message.append(to_bytes(&source));
    message.append(to_bytes(&subject));
    message.append(to_bytes(&issuer_id));
    message.append(to_bytes(&issuer_epoch));
    message.append(to_bytes(&level));
    message.append(to_bytes(&expires_at_secs));
    message.append(to_bytes(&issued_at_secs));
    message.append(to_bytes(&nullifier));
    message
}
</code></pre>



</details>

<a id="0x1_attestation_create"></a>

## Function `create`

Create a new attestation source. The deployer only authorizes resource-account creation and
pays gas; it gains no role unless listed in the role arguments.

@param deployer Signer that authorizes resource-account creation and pays gas.
@param admins Addresses allowed to configure. At least one, no duplicates, not the source.
@param issuers Addresses allowed to write facts. May be empty and filled in later.
@param sentinels Addresses allowed to add denials only. May be empty.
@param removers Addresses allowed to remove denials only. May be empty.
@param guardians Addresses allowed to pause writes. May be empty.
@abort If a list has duplicates, names the source itself, or there is no admin.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_create">create</a>(
    deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) {
    <b>let</b> (source_signer, source_signer_cap) = <a href="attestation.md#0x1_attestation_create_source_account">create_source_account</a>(deployer);
    <a href="attestation.md#0x1_attestation_create_source_internal">create_source_internal</a>(
        &source_signer,
        address_of(deployer),
        admins,
        issuers,
        sentinels,
        removers,
        guardians,
        source_signer_cap
    );
}
</code></pre>



</details>

<a id="0x1_attestation_create_source_internal"></a>

## Function `create_source_internal`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_internal">create_source_internal</a>(source_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, deployer: <b>address</b>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_internal">create_source_internal</a>(
    source_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    deployer: <b>address</b>,
    admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    signer_cap: SignerCapability
) {
    <b>let</b> source_address = address_of(source_account);
    <b>assert</b>!(admins.length() &gt;= 1, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_ENOT_ENOUGH_ADMINS">ENOT_ENOUGH_ADMINS</a>));
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(&admins, source_address);
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(&issuers, source_address);
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(&sentinels, source_address);
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(&removers, source_address);
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(&guardians, source_address);

    <b>let</b> floor_epoch = <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u8, u64&gt;();
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> floor_epoch, 0, 0);

    <b>move_to</b>(
        source_account,
        <a href="attestation.md#0x1_attestation_Source">Source</a> {
            admins,
            issuers,
            sentinels,
            removers,
            guardians,
            issuer_info: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_Issuer">Issuer</a>&gt;(),
            issuer_by_id: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u16, <b>address</b>&gt;(),
            next_issuer_id: 1,
            paused: <b>false</b>,
            root_epoch: 0,
            roots: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u64, <a href="attestation.md#0x1_attestation_Root">Root</a>&gt;(),
            signer_cap
        }
    );
    <b>move_to</b>(
        source_account,
        <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
            subjects: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_Record">Record</a>&gt;(),
            denied: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<b>address</b>, <a href="attestation.md#0x1_attestation_DenyEntry">DenyEntry</a>&gt;(),
            nullifiers: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <b>address</b>&gt;(),
            issuer_epochs: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;u16, u64&gt;(),
            floor_epoch
        }
    );

    emit(<a href="attestation.md#0x1_attestation_CreateSource">CreateSource</a> { source: source_address, deployer, admins, issuers });
}
</code></pre>



</details>

<a id="0x1_attestation_add_admins"></a>

## Function `add_admins`

Add admins.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_admins">add_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_admins">add_admins</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_add_members">add_members</a>(&<b>mut</b> config.admins, &new_admins, source);
    emit(<a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_ADMIN">ROLE_ADMIN</a>, members: new_admins });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_admins"></a>

## Function `remove_admins`

Remove admins. A source may never be left with zero admins.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_admins">remove_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_admins">remove_admins</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(&<b>mut</b> config.admins, &old_admins);
    <b>assert</b>!(
        config.admins.length() &gt;= 1,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EWOULD_REMOVE_ALL_ADMINS">EWOULD_REMOVE_ALL_ADMINS</a>)
    );
    emit(<a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_ADMIN">ROLE_ADMIN</a>, members: old_admins });
}
</code></pre>



</details>

<a id="0x1_attestation_add_issuers"></a>

## Function `add_issuers`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_issuers">add_issuers</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_issuers">add_issuers</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_add_members">add_members</a>(&<b>mut</b> config.issuers, &new_issuers, source);
    emit(<a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_ISSUER">ROLE_ISSUER</a>, members: new_issuers });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_issuers"></a>

## Function `remove_issuers`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_issuers">remove_issuers</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_issuers">remove_issuers</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(&<b>mut</b> config.issuers, &old_issuers);
    emit(<a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_ISSUER">ROLE_ISSUER</a>, members: old_issuers });
}
</code></pre>



</details>

<a id="0x1_attestation_add_sentinels"></a>

## Function `add_sentinels`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_sentinels">add_sentinels</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_sentinels">add_sentinels</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_add_members">add_members</a>(&<b>mut</b> config.sentinels, &new_sentinels, source);
    emit(<a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_SENTINEL">ROLE_SENTINEL</a>, members: new_sentinels });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_sentinels"></a>

## Function `remove_sentinels`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_sentinels">remove_sentinels</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_sentinels">remove_sentinels</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(&<b>mut</b> config.sentinels, &old_sentinels);
    emit(<a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_SENTINEL">ROLE_SENTINEL</a>, members: old_sentinels });
}
</code></pre>



</details>

<a id="0x1_attestation_add_removers"></a>

## Function `add_removers`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_removers">add_removers</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_removers">add_removers</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_add_members">add_members</a>(&<b>mut</b> config.removers, &new_removers, source);
    emit(<a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_REMOVER">ROLE_REMOVER</a>, members: new_removers });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_removers"></a>

## Function `remove_removers`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_removers">remove_removers</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_removers">remove_removers</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(&<b>mut</b> config.removers, &old_removers);
    emit(<a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_REMOVER">ROLE_REMOVER</a>, members: old_removers });
}
</code></pre>



</details>

<a id="0x1_attestation_add_guardians"></a>

## Function `add_guardians`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_guardians">add_guardians</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_guardians">add_guardians</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_add_members">add_members</a>(&<b>mut</b> config.guardians, &new_guardians, source);
    emit(<a href="attestation.md#0x1_attestation_AddMembers">AddMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_GUARDIAN">ROLE_GUARDIAN</a>, members: new_guardians });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_guardians"></a>

## Function `remove_guardians`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_guardians">remove_guardians</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_guardians">remove_guardians</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(&<b>mut</b> config.guardians, &old_guardians);
    emit(<a href="attestation.md#0x1_attestation_RemoveMembers">RemoveMembers</a> { source, role: <a href="attestation.md#0x1_attestation_ROLE_GUARDIAN">ROLE_GUARDIAN</a>, members: old_guardians });
}
</code></pre>



</details>

<a id="0x1_attestation_pause"></a>

## Function `pause`

Pause writes. Never changes the answer <code>is_verified</code> gives.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_pause">pause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_pause">pause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_set_paused">set_paused</a>(guardian, source, <b>true</b>);
}
</code></pre>



</details>

<a id="0x1_attestation_unpause"></a>

## Function `unpause`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unpause">unpause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unpause">unpause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_set_paused">set_paused</a>(guardian, source, <b>false</b>);
}
</code></pre>



</details>

<a id="0x1_attestation_set_paused"></a>

## Function `set_paused`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, paused: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, paused: bool) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_Source">Source</a>[source].guardians.contains(&address_of(guardian)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_GUARDIAN">ENOT_GUARDIAN</a>)
    );
    <a href="attestation.md#0x1_attestation_Source">Source</a>[source].paused = paused;
    emit(<a href="attestation.md#0x1_attestation_SetPaused">SetPaused</a> { source, paused });
}
</code></pre>



</details>

<a id="0x1_attestation_register_issuer"></a>

## Function `register_issuer`

Register an issuer and assign it a stable id. The public key is used only by the
permissionless relay path, and may be empty for an issuer that only writes directly.

@param admin An admin of the source.
@param source The source address.
@param issuer Address to register.
@param pubkey 32-byte ed25519 public key, or empty.
@abort If the issuer is already registered or the key length is wrong.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_register_issuer">register_issuer</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer: <b>address</b>, pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_register_issuer">register_issuer</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer: <b>address</b>, pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>assert</b>!(
        pubkey.is_empty() || pubkey.length() == <a href="attestation.md#0x1_attestation_PUBKEY_LENGTH">PUBKEY_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        !<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.issuer_info, issuer),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="attestation.md#0x1_attestation_EDUPLICATE_ISSUER">EDUPLICATE_ISSUER</a>)
    );
    <b>let</b> id = config.next_issuer_id;
    config.next_issuer_id = id + 1;
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> config.issuer_info, issuer, <a href="attestation.md#0x1_attestation_Issuer">Issuer</a> { id, pubkey, active: <b>true</b> });
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> config.issuer_by_id, id, issuer);
    <b>if</b> (!config.issuers.contains(&issuer)) {
        config.issuers.push_back(issuer);
    };
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(&<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].issuer_epochs, id, 0);
    emit(<a href="attestation.md#0x1_attestation_RegisterIssuer">RegisterIssuer</a> { source, issuer, id });
}
</code></pre>



</details>

<a id="0x1_attestation_rotate_issuer_key"></a>

## Function `rotate_issuer_key`

Replace an issuer's signing key. Facts already written stay valid; use
<code>bump_issuer_epoch</code> to invalidate them.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_rotate_issuer_key">rotate_issuer_key</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer: <b>address</b>, new_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_rotate_issuer_key">rotate_issuer_key</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer: <b>address</b>, new_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>assert</b>!(
        new_pubkey.is_empty() || new_pubkey.length() == <a href="attestation.md#0x1_attestation_PUBKEY_LENGTH">PUBKEY_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.issuer_info, issuer),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>)
    );
    <b>let</b> info = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(&<b>mut</b> config.issuer_info, issuer);
    info.pubkey = new_pubkey;
    emit(<a href="attestation.md#0x1_attestation_RotateIssuerKey">RotateIssuerKey</a> { source, id: info.id });
}
</code></pre>



</details>

<a id="0x1_attestation_bump_issuer_epoch"></a>

## Function `bump_issuer_epoch`

Invalidate every fact an issuer has written, in one write. This is the remedy for a
compromised issuer key and it is O(1) in the size of the cohort. Issuer id 0 bumps the
zkTLS enrollment cohort, which has no registered issuer. The new epoch is one above the
issuer's effective epoch, so a bump always takes effect even below a raised floor.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_bump_issuer_epoch">bump_issuer_epoch</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer_id: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_bump_issuer_epoch">bump_issuer_epoch</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer_id: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>assert</b>!(
        issuer_id == 0 || <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&<a href="attestation.md#0x1_attestation_Source">Source</a>[source].issuer_by_id, issuer_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>)
    );
    <b>let</b> epoch = <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source, issuer_id) + 1;
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_upsert">table::upsert</a>(&<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].issuer_epochs, issuer_id, epoch);
    emit(<a href="attestation.md#0x1_attestation_BumpIssuerEpoch">BumpIssuerEpoch</a> { source, id: issuer_id, epoch });
}
</code></pre>



</details>

<a id="0x1_attestation_set_floor_epoch"></a>

## Function `set_floor_epoch`

Invalidate every fact written below the given epoch, across all issuers including the zkTLS
cohort. Strictly increasing, so lowering the floor can never resurrect a fact.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_set_floor_epoch">set_floor_epoch</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, epoch: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_set_floor_epoch">set_floor_epoch</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, epoch: u64
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source, address_of(admin));
    <b>let</b> floor = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(&<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].floor_epoch, 0);
    <b>assert</b>!(epoch &gt; *floor, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_ENOT_MONOTONIC">ENOT_MONOTONIC</a>));
    *floor = epoch;
    emit(<a href="attestation.md#0x1_attestation_SetFloorEpoch">SetFloorEpoch</a> { source, epoch });
}
</code></pre>



</details>

<a id="0x1_attestation_issue_batch"></a>

## Function `issue_batch`

Record or refresh facts for many subjects at once.

@param issuer A registered, active issuer of the source.
@param source The source address.
@param subjects Subjects to write.
@param levels Tier per subject, same length as <code>subjects</code>.
@param expires_at_secs Expiry per subject, same length as <code>subjects</code>.
@param reason Reason code recorded in each subject's history.
@abort If paused, the caller is not an issuer, the lengths differ, the batch is too large,
or any subject is denied.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_issue_batch">issue_batch</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, expires_at_secs: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_issue_batch">issue_batch</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    levels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    expires_at_secs: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;,
    reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> count = subjects.length();
    <b>assert</b>!(count &lt;= <a href="attestation.md#0x1_attestation_MAX_BATCH">MAX_BATCH</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>));
    <b>assert</b>!(
        count == levels.length() && count == expires_at_secs.length(),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_ELENGTH_MISMATCH">ELENGTH_MISMATCH</a>)
    );
    <b>let</b> (issuer_id, issuer_epoch) = <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <b>let</b> index = 0;
    <b>while</b> (index &lt; count) {
        <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(
            source,
            subjects[index],
            <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>,
            levels[index],
            issuer_id,
            issuer_epoch,
            expires_at_secs[index],
            now_seconds(),
            reason,
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
        );
        index += 1;
    };
}
</code></pre>



</details>

<a id="0x1_attestation_revoke_batch"></a>

## Function `revoke_batch`

Move many subjects to STATE_REVOKED. A subject that is already revoked is skipped, so one
stale entry cannot brick a batch.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_revoke_batch">revoke_batch</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_revoke_batch">revoke_batch</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> count = subjects.length();
    <b>assert</b>!(count &lt;= <a href="attestation.md#0x1_attestation_MAX_BATCH">MAX_BATCH</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>));
    <b>let</b> (issuer_id, _) = <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <b>let</b> index = 0;
    <b>while</b> (index &lt; count) {
        <a href="attestation.md#0x1_attestation_transition">transition</a>(source, subjects[index], <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>, issuer_id, reason);
        index += 1;
    };
}
</code></pre>



</details>

<a id="0x1_attestation_suspend"></a>

## Function `suspend`

Temporarily withhold an active subject's fact, reversibly.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_suspend">suspend</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_suspend">suspend</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> (issuer_id, _) = <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <a href="attestation.md#0x1_attestation_transition">transition</a>(source, subject, <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>, issuer_id, reason);
}
</code></pre>



</details>

<a id="0x1_attestation_unsuspend"></a>

## Function `unsuspend`

Reverse a suspension. Only a suspended record can be reactivated: a revoked one needs
re-issuance, and a denied subject cannot be reactivated at all. The record keeps the issuer
and epoch it was issued under, so a fact killed by an epoch bump stays dead.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unsuspend">unsuspend</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unsuspend">unsuspend</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> (issuer_id, _) = <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <a href="attestation.md#0x1_attestation_transition">transition</a>(source, subject, <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>, issuer_id, reason);
}
</code></pre>



</details>

<a id="0x1_attestation_set_attribute"></a>

## Function `set_attribute`

Set an attribute on a subject. Every attribute written is public forever, so a source that
writes jurisdiction data has made a disclosure decision on behalf of its subjects.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_set_attribute">set_attribute</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, key: u16, value: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_set_attribute">set_attribute</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, key: u16, value: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source);
    <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <b>let</b> facts = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_ERECORD_NOT_FOUND">ERECORD_NOT_FOUND</a>)
    );
    <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(&<b>mut</b> facts.subjects, subject);
    <b>if</b> (<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&record.attrs, &key)) {
        *<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow_mut">simple_map::borrow_mut</a>(&<b>mut</b> record.attrs, &key) = value;
    } <b>else</b> {
        <b>assert</b>!(
            <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_length">simple_map::length</a>(&record.attrs) &lt; <a href="attestation.md#0x1_attestation_MAX_ATTRS">MAX_ATTRS</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EBAD_ATTRIBUTE">EBAD_ATTRIBUTE</a>)
        );
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_add">simple_map::add</a>(&<b>mut</b> record.attrs, key, value);
    };
    emit(<a href="attestation.md#0x1_attestation_SetAttribute">SetAttribute</a> { source, subject, key });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_attribute"></a>

## Function `remove_attribute`



<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_attribute">remove_attribute</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, key: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_attribute">remove_attribute</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, key: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source);
    <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <b>let</b> facts = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_ERECORD_NOT_FOUND">ERECORD_NOT_FOUND</a>)
    );
    <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(&<b>mut</b> facts.subjects, subject);
    <b>if</b> (<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&record.attrs, &key)) {
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_remove">simple_map::remove</a>(&<b>mut</b> record.attrs, &key);
    };
}
</code></pre>



</details>

<a id="0x1_attestation_redeem_attestation"></a>

## Function `redeem_attestation`

Record a fact from an attestation the issuer signed off chain. The caller need not be the
subject or the issuer.

@param source The source address.
@param subject Subject the attestation is about.
@param issuer_id Issuer that signed.
@param issuer_epoch Must equal the issuer's current epoch, so an attestation signed before
a compromise bump is refused and one signed for a future epoch is too.
@param nullifier 32 bytes binding one real-world identity to one subject, or empty to skip.
@param signature 64-byte ed25519 signature over <code>attestation_message</code>.
@abort If paused, the epoch is stale, the signature fails, a newer attestation is already
recorded, the nullifier is bound elsewhere, or the subject is denied.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_redeem_attestation">redeem_attestation</a>(_relayer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, issuer_id: u16, issuer_epoch: u64, level: u8, expires_at_secs: u64, issued_at_secs: u64, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_redeem_attestation">redeem_attestation</a>(
    _relayer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    subject: <b>address</b>,
    issuer_id: u16,
    issuer_epoch: u64,
    level: u8,
    expires_at_secs: u64,
    issued_at_secs: u64,
    nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source);
    <b>let</b> config = &<a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.issuer_by_id, issuer_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>)
    );
    <b>let</b> issuer_address = *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.issuer_by_id, issuer_id);
    // Same rule <b>as</b> assert_issuer: removing an issuer's role also stops its relayed
    // attestations.
    <b>assert</b>!(
        config.issuers.contains(&issuer_address),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_ISSUER">ENOT_ISSUER</a>)
    );
    <b>let</b> info = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.issuer_info, issuer_address);
    <b>assert</b>!(info.active, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>));
    <b>assert</b>!(
        info.pubkey.length() == <a href="attestation.md#0x1_attestation_PUBKEY_LENGTH">PUBKEY_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EUNKNOWN_ISSUER">EUNKNOWN_ISSUER</a>)
    );

    // Equality, not "at least": refuse an epoch the issuer <b>has</b> not entered, and refuse one
    // signed before a bump.
    <b>assert</b>!(
        issuer_epoch == <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source, issuer_id),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_ESTALE_EPOCH">ESTALE_EPOCH</a>)
    );

    <b>let</b> message =
        <a href="attestation.md#0x1_attestation_attestation_message">attestation_message</a>(
            source,
            subject,
            issuer_id,
            issuer_epoch,
            level,
            expires_at_secs,
            issued_at_secs,
            nullifier
        );
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_signature_verify_strict">ed25519::signature_verify_strict</a>(
            &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_signature_from_bytes">ed25519::new_signature_from_bytes</a>(signature),
            &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_unvalidated_public_key_from_bytes">ed25519::new_unvalidated_public_key_from_bytes</a>(info.pubkey),
            message
        ),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EBAD_SIGNATURE">EBAD_SIGNATURE</a>)
    );

    // Monotonicity: a kept <a href="attestation.md#0x1_attestation">attestation</a> must not be replayable <b>to</b> push an expiry back out.
    <a href="attestation.md#0x1_attestation_assert_newer">assert_newer</a>(source, subject, issued_at_secs);
    <a href="attestation.md#0x1_attestation_bind_nullifier">bind_nullifier</a>(source, subject, nullifier);

    <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(
        source,
        subject,
        <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>,
        level,
        issuer_id,
        issuer_epoch,
        expires_at_secs,
        issued_at_secs,
        0,
        std::aptos_hash::keccak256(message)
    );
}
</code></pre>



</details>

<a id="0x1_attestation_source_signer"></a>

## Function `source_signer`

Return a signer for the source's resource account. Restricted to the <code><b>friend</b></code> list, which
is the security boundary: <code><a href="zktls.md#0x1_zktls">zktls</a></code> needs it to store its attestor set and template
allowlist under the source address. Nothing outside the friend list can obtain it.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation.md#0x1_attestation_source_signer">source_signer</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation.md#0x1_attestation_source_signer">source_signer</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <a href="account.md#0x1_account_create_signer_with_capability">account::create_signer_with_capability</a>(&<a href="attestation.md#0x1_attestation_Source">Source</a>[source].signer_cap)
}
</code></pre>



</details>

<a id="0x1_attestation_record_verified_claim"></a>

## Function `record_verified_claim`

Record a fact from a claim <code>aptos_framework::zktls</code> has already verified against its
attestor set. No issuer key is involved on this path at all.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation.md#0x1_attestation_record_verified_claim">record_verified_claim</a>(source: <b>address</b>, subject: <b>address</b>, level: u8, expires_at_secs: u64, attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation.md#0x1_attestation_record_verified_claim">record_verified_claim</a>(
    source: <b>address</b>,
    subject: <b>address</b>,
    level: u8,
    expires_at_secs: u64,
    attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source);
    <b>assert</b>!(
        attestation_digest.length() == <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <a href="attestation.md#0x1_attestation_bind_nullifier">bind_nullifier</a>(source, subject, nullifier);
    // <a href="attestation.md#0x1_attestation_Issuer">Issuer</a> id 0 is the zkTLS cohort, stamped <b>with</b> its effective epoch so a raised floor does
    // not silently kill new enrollments and a bump of id 0 kills the whole cohort.
    <b>let</b> cohort_epoch = <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source, 0);
    <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(
        source,
        subject,
        <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>,
        level,
        0,
        cohort_epoch,
        expires_at_secs,
        now_seconds(),
        0,
        attestation_digest
    );
}
</code></pre>



</details>

<a id="0x1_attestation_deny"></a>

## Function `deny`

Exclude a subject. Takes effect at <code>effective_at_secs</code>, which may be in the future so a
denial can be announced before it bites.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny">deny</a>(sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16, effective_at_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny">deny</a>(
    sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    source: <b>address</b>,
    subject: <b>address</b>,
    reason: u16,
    effective_at_secs: u64
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_Source">Source</a>[source].sentinels.contains(&address_of(sentinel)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_SENTINEL">ENOT_SENTINEL</a>)
    );
    <a href="attestation.md#0x1_attestation_deny_internal">deny_internal</a>(source, subject, reason, effective_at_secs);
}
</code></pre>



</details>

<a id="0x1_attestation_deny_batch"></a>

## Function `deny_batch`

Exclude many subjects at once, with a shared reason and immediate effect.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny_batch">deny_batch</a>(sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny_batch">deny_batch</a>(
    sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_Source">Source</a>[source].sentinels.contains(&address_of(sentinel)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_SENTINEL">ENOT_SENTINEL</a>)
    );
    <b>let</b> count = subjects.length();
    <b>assert</b>!(count &lt;= <a href="attestation.md#0x1_attestation_MAX_BATCH">MAX_BATCH</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EBATCH_TOO_LARGE">EBATCH_TOO_LARGE</a>));
    <b>let</b> index = 0;
    <b>let</b> now = now_seconds();
    <b>while</b> (index &lt; count) {
        <a href="attestation.md#0x1_attestation_deny_internal">deny_internal</a>(source, subjects[index], reason, now);
        index += 1;
    };
}
</code></pre>



</details>

<a id="0x1_attestation_undeny"></a>

## Function `undeny`

Remove an exclusion. Deliberately a different role from <code>deny</code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_undeny">undeny</a>(remover: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_undeny">undeny</a>(
    remover: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_Source">Source</a>[source].removers.contains(&address_of(remover)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_REMOVER">ENOT_REMOVER</a>)
    );
    <b>let</b> denied = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].denied;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(denied, subject)) {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_remove">table::remove</a>(denied, subject);
        emit(<a href="attestation.md#0x1_attestation_Undeny">Undeny</a> { source, subject });
    };
}
</code></pre>



</details>

<a id="0x1_attestation_deny_internal"></a>

## Function `deny_internal`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_deny_internal">deny_internal</a>(source: <b>address</b>, subject: <b>address</b>, reason: u16, effective_at_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_deny_internal">deny_internal</a>(
    source: <b>address</b>, subject: <b>address</b>, reason: u16, effective_at_secs: u64
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    // upsert, never add: a repeated denial must be idempotent rather than <b>abort</b> a batch.
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_upsert">table::upsert</a>(
        &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].denied,
        subject,
        <a href="attestation.md#0x1_attestation_DenyEntry">DenyEntry</a> { reason, effective_at_secs, added_at_secs: now_seconds() }
    );
    emit(<a href="attestation.md#0x1_attestation_Deny">Deny</a> { source, subject, reason, effective_at_secs });
}
</code></pre>



</details>

<a id="0x1_attestation_publish_root"></a>

## Function `publish_root`

Publish a set commitment for the next epoch. Rotation invalidates outstanding proofs, so
publish on a fixed low-frequency cadence: it is a privacy measure, because cohort timing
leaks, and a throughput one, because every gated transaction reads this slot.


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_publish_root">publish_root</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf_count: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_publish_root">publish_root</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf_count: u64
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>assert</b>!(
        digest.length() == <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>let</b> (issuer_id, _) = <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source, address_of(issuer));
    <b>let</b> config = &<b>mut</b> <a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>let</b> epoch = config.root_epoch + 1;
    config.root_epoch = epoch;
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(
        &<b>mut</b> config.roots,
        epoch,
        <a href="attestation.md#0x1_attestation_Root">Root</a> { digest, leaf_count, published_at_secs: now_seconds(), issuer_id }
    );
    emit(<a href="attestation.md#0x1_attestation_PublishRoot">PublishRoot</a> { source, epoch, digest, leaf_count });
}
</code></pre>



</details>

<a id="0x1_attestation_record_fact"></a>

## Function `record_fact`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(source: <b>address</b>, subject: <b>address</b>, state: u8, level: u8, issuer_id: u16, issuer_epoch: u64, expires_at_secs: u64, issued_at_secs: u64, reason: u16, attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(
    source: <b>address</b>,
    subject: <b>address</b>,
    state: u8,
    level: u8,
    issuer_id: u16,
    issuer_epoch: u64,
    expires_at_secs: u64,
    issued_at_secs: u64,
    reason: u16,
    attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> now = now_seconds();
    <b>let</b> facts = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];

    // A positive write can never overwrite, clear or ignore an exclusion.
    <b>assert</b>!(
        !<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.denied, subject),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_ESUBJECT_DENIED">ESUBJECT_DENIED</a>)
    );

    <b>let</b> subjects = &<b>mut</b> facts.subjects;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(subjects, subject)) {
        <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(subjects, subject);
        <b>let</b> change = <a href="attestation.md#0x1_attestation_Change">Change</a> {
            at_secs: now,
            prev_state: record.state,
            new_state: state,
            reason,
            issuer_id
        };
        record.state = state;
        record.level = level;
        record.issuer_id = issuer_id;
        record.issuer_epoch = issuer_epoch;
        record.expires_at_secs = expires_at_secs;
        record.issued_at_secs = issued_at_secs;
        record.reason = reason;
        record.attestation_digest = attestation_digest;
        <b>if</b> (state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>) {
            record.revoked_at_secs = now;
        };
        <a href="attestation.md#0x1_attestation_push_history">push_history</a>(&<b>mut</b> record.history, change);
    } <b>else</b> {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(
            subjects,
            subject,
            <a href="attestation.md#0x1_attestation_Record">Record</a> {
                state,
                level,
                issuer_id,
                issuer_epoch,
                issued_at_secs,
                expires_at_secs,
                revoked_at_secs: <b>if</b> (state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>) { now } <b>else</b> { 0 },
                reason,
                attestation_digest,
                attrs: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_create">simple_map::create</a>&lt;u16, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;(),
                history: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[
                    <a href="attestation.md#0x1_attestation_Change">Change</a> {
                        at_secs: now,
                        prev_state: <a href="attestation.md#0x1_attestation_STATE_NONE">STATE_NONE</a>,
                        new_state: state,
                        reason,
                        issuer_id
                    }
                ]
            }
        );
    };

    emit(<a href="attestation.md#0x1_attestation_RecordFact">RecordFact</a> { source, subject, state, level, issuer_id, expires_at_secs, reason });
}
</code></pre>



</details>

<a id="0x1_attestation_transition"></a>

## Function `transition`

Change the state of an existing record. Used by revoke, suspend and unsuspend, all of which
must not silently create a record. The record keeps the issuer id and epoch it was issued
under, because validity comes from the original issuance; the acting issuer is recorded in
the history entry only.

Allowed: ACTIVE to SUSPENDED, SUSPENDED to ACTIVE, and ACTIVE or SUSPENDED to REVOKED.
Revoking an already revoked record is a silent no-op so a batch is not bricked by one entry.


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_transition">transition</a>(source: <b>address</b>, subject: <b>address</b>, state: u8, acting_issuer_id: u16, reason: u16)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_transition">transition</a>(
    source: <b>address</b>,
    subject: <b>address</b>,
    state: u8,
    acting_issuer_id: u16,
    reason: u16
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> now = now_seconds();
    <b>let</b> facts = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source];
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.subjects, subject),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_ERECORD_NOT_FOUND">ERECORD_NOT_FOUND</a>)
    );
    <b>let</b> denied = <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.denied, subject);
    <b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow_mut">table::borrow_mut</a>(&<b>mut</b> facts.subjects, subject);
    <b>let</b> prev_state = record.state;
    <b>if</b> (state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>) {
        <b>if</b> (prev_state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>) {
            <b>return</b>
        };
        <b>assert</b>!(
            prev_state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a> || prev_state == <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EINVALID_TRANSITION">EINVALID_TRANSITION</a>)
        );
    } <b>else</b> <b>if</b> (state == <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>) {
        <b>assert</b>!(
            prev_state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EINVALID_TRANSITION">EINVALID_TRANSITION</a>)
        );
    } <b>else</b> {
        <b>assert</b>!(
            state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a> && prev_state == <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EINVALID_TRANSITION">EINVALID_TRANSITION</a>)
        );
        // Reactivation is a positive write, so it obeys the same exclusion rule <b>as</b> record_fact.
        <b>assert</b>!(!denied, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_ESUBJECT_DENIED">ESUBJECT_DENIED</a>));
    };
    <b>let</b> change = <a href="attestation.md#0x1_attestation_Change">Change</a> {
        at_secs: now,
        prev_state,
        new_state: state,
        reason,
        issuer_id: acting_issuer_id
    };
    record.state = state;
    record.reason = reason;
    <b>if</b> (state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>) {
        record.revoked_at_secs = now;
    };
    <a href="attestation.md#0x1_attestation_push_history">push_history</a>(&<b>mut</b> record.history, change);
    emit(
        <a href="attestation.md#0x1_attestation_RecordFact">RecordFact</a> {
            source,
            subject,
            state,
            level: record.level,
            issuer_id: acting_issuer_id,
            expires_at_secs: record.expires_at_secs,
            reason
        }
    );
}
</code></pre>



</details>

<a id="0x1_attestation_create_source_account"></a>

## Function `create_source_account`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_account">create_source_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_account">create_source_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, SignerCapability) {
    <b>let</b> deployer_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(address_of(deployer));
    <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
        deployer, <a href="attestation.md#0x1_attestation_create_source_seed">create_source_seed</a>(to_bytes(&deployer_nonce))
    )
}
</code></pre>



</details>

<a id="0x1_attestation_create_source_seed"></a>

## Function `create_source_seed`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_seed">create_source_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_seed">create_source_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> account_seed = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    account_seed.append(<a href="attestation.md#0x1_attestation_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>);
    account_seed.append(seed);
    account_seed
}
</code></pre>



</details>

<a id="0x1_attestation_validate_members"></a>

## Function `validate_members`

Validate that a role list has no duplicates and does not name the source itself.


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, source_address: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, source_address: <b>address</b>) {
    <b>let</b> distinct: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    members.for_each_ref(|member| {
        <b>assert</b>!(
            *member != source_address,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>)
        );
        <b>assert</b>!(
            !distinct.contains(member),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>)
        );
        distinct.push_back(*member);
    });
}
</code></pre>



</details>

<a id="0x1_attestation_add_members"></a>

## Function `add_members`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_add_members">add_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, new_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, source_address: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_add_members">add_members</a>(
    list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, new_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, source_address: <b>address</b>
) {
    <a href="attestation.md#0x1_attestation_validate_members">validate_members</a>(new_members, source_address);
    new_members.for_each_ref(|member| {
        <b>assert</b>!(
            !list.contains(member),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EDUPLICATE_MEMBER">EDUPLICATE_MEMBER</a>)
        );
        list.push_back(*member);
    });
}
</code></pre>



</details>

<a id="0x1_attestation_remove_members"></a>

## Function `remove_members`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, old_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_remove_members">remove_members</a>(list: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, old_members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;) {
    old_members.for_each_ref(|member| {
        <b>let</b> (found, index) = list.index_of(member);
        <b>if</b> (found) {
            list.remove(index);
        };
    });
}
</code></pre>



</details>

<a id="0x1_attestation_push_history"></a>

## Function `push_history`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_push_history">push_history</a>(history: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation.md#0x1_attestation_Change">attestation::Change</a>&gt;, change: <a href="attestation.md#0x1_attestation_Change">attestation::Change</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_push_history">push_history</a>(history: &<b>mut</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="attestation.md#0x1_attestation_Change">Change</a>&gt;, change: <a href="attestation.md#0x1_attestation_Change">Change</a>) {
    <b>if</b> (history.length() &gt;= <a href="attestation.md#0x1_attestation_MAX_HISTORY">MAX_HISTORY</a>) {
        history.remove(0);
    };
    history.push_back(change);
}
</code></pre>



</details>

<a id="0x1_attestation_bind_nullifier"></a>

## Function `bind_nullifier`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_bind_nullifier">bind_nullifier</a>(source: <b>address</b>, subject: <b>address</b>, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_bind_nullifier">bind_nullifier</a>(
    source: <b>address</b>, subject: <b>address</b>, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>if</b> (nullifier.is_empty()) {
        <b>return</b>
    };
    <b>assert</b>!(
        nullifier.length() == <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>let</b> nullifiers = &<b>mut</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].nullifiers;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(nullifiers, nullifier)) {
        <b>assert</b>!(
            *<a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(nullifiers, nullifier) == subject,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_ENULLIFIER_BOUND">ENULLIFIER_BOUND</a>)
        );
    } <b>else</b> {
        <a href="../../aptos-stdlib/doc/table.md#0x1_table_add">table::add</a>(nullifiers, nullifier, subject);
    };
}
</code></pre>



</details>

<a id="0x1_attestation_assert_newer"></a>

## Function `assert_newer`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_newer">assert_newer</a>(source: <b>address</b>, subject: <b>address</b>, issued_at_secs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_newer">assert_newer</a>(
    source: <b>address</b>, subject: <b>address</b>, issued_at_secs: u64
) <b>acquires</b> <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <b>let</b> subjects = &<a href="attestation.md#0x1_attestation_Facts">Facts</a>[source].subjects;
    <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(subjects, subject)) {
        <b>assert</b>!(
            issued_at_secs &gt; <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(subjects, subject).issued_at_secs,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="attestation.md#0x1_attestation_ENOT_MONOTONIC">ENOT_MONOTONIC</a>)
        );
    };
}
</code></pre>



</details>

<a id="0x1_attestation_is_denied_internal"></a>

## Function `is_denied_internal`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_is_denied_internal">is_denied_internal</a>(facts: &<a href="attestation.md#0x1_attestation_Facts">attestation::Facts</a>, subject: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_is_denied_internal">is_denied_internal</a>(facts: &<a href="attestation.md#0x1_attestation_Facts">Facts</a>, subject: <b>address</b>): bool {
    <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&facts.denied, subject)
        && now_seconds() &gt;= <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&facts.denied, subject).effective_at_secs
}
</code></pre>



</details>

<a id="0x1_attestation_assert_source_exists"></a>

## Function `assert_source_exists`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source: <b>address</b>) {
    <b>assert</b>!(<b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EACCOUNT_NOT_SOURCE">EACCOUNT_NOT_SOURCE</a>));
    <b>assert</b>!(<b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="attestation.md#0x1_attestation_EACCOUNT_NOT_SOURCE">EACCOUNT_NOT_SOURCE</a>));
}
</code></pre>



</details>

<a id="0x1_attestation_assert_admin"></a>

## Function `assert_admin`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source: <b>address</b>, addr: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_admin">assert_admin</a>(source: <b>address</b>, addr: <b>address</b>) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(
        <a href="attestation.md#0x1_attestation_Source">Source</a>[source].admins.contains(&addr),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_ADMIN">ENOT_ADMIN</a>)
    );
}
</code></pre>



</details>

<a id="0x1_attestation_assert_not_paused"></a>

## Function `assert_not_paused`



<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source: <b>address</b>) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a> {
    <a href="attestation.md#0x1_attestation_assert_source_exists">assert_source_exists</a>(source);
    <b>assert</b>!(!<a href="attestation.md#0x1_attestation_Source">Source</a>[source].paused, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="attestation.md#0x1_attestation_EPAUSED">EPAUSED</a>));
}
</code></pre>



</details>

<a id="0x1_attestation_assert_issuer"></a>

## Function `assert_issuer`

Assert the caller is a registered, active issuer and return its id and current epoch.


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source: <b>address</b>, addr: <b>address</b>): (u16, u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_assert_issuer">assert_issuer</a>(source: <b>address</b>, addr: <b>address</b>): (u16, u64) <b>acquires</b> <a href="attestation.md#0x1_attestation_Source">Source</a>, <a href="attestation.md#0x1_attestation_Facts">Facts</a> {
    <a href="attestation.md#0x1_attestation_assert_not_paused">assert_not_paused</a>(source);
    <b>let</b> config = &<a href="attestation.md#0x1_attestation_Source">Source</a>[source];
    <b>assert</b>!(
        config.issuers.contains(&addr) && <a href="../../aptos-stdlib/doc/table.md#0x1_table_contains">table::contains</a>(&config.issuer_info, addr),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_ISSUER">ENOT_ISSUER</a>)
    );
    <b>let</b> info = <a href="../../aptos-stdlib/doc/table.md#0x1_table_borrow">table::borrow</a>(&config.issuer_info, addr);
    <b>assert</b>!(info.active, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="attestation.md#0x1_attestation_ENOT_ISSUER">ENOT_ISSUER</a>));
    (info.id, <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source, info.id))
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
<td>A denial always wins. While a denial is in effect for a subject, the source never reports that subject as verified, regardless of any fact recorded for it (INV-1).</td>
<td>Critical</td>
<td>active_with_level checks is_denied_internal before reading the subject's record and returns (false, 0) when the denial is in effect. is_verified, level_of and state_of all route through it, and attestation_policy consults is_denied before any positive rule.</td>
<td>Formally verified via <a href="#high-level-req-1">active_with_level</a>.</td>
</tr>

<tr>
<td>2</td>
<td>No positive write path can create, modify or clear a denial (INV-2), and no positive write can be recorded for a subject that has a denial entry.</td>
<td>Critical</td>
<td>Every positive write ends in record_fact, which aborts when the subject has a denial entry and never touches the denied table. transition refuses to reactivate a denied subject.</td>
<td>Formally verified via <a href="#high-level-req-2.1">record_fact</a> and <a href="#high-level-req-2.2">transition</a>.</td>
</tr>

<tr>
<td>3</td>
<td>A fact whose expiry has passed, whose epoch is below its issuer's current epoch, or whose epoch is below the source floor is never treated as active (INV-3). A floor raise or an epoch bump always takes effect, and new writes are stamped with the issuer's effective epoch so they are not born stale.</td>
<td>Critical</td>
<td>active_with_level compares the record against now_seconds(), the per-issuer epoch and the floor. issuer_epoch_of returns max(own counter, floor), which is what assert_issuer and record_verified_claim stamp and what bump_issuer_epoch increments. set_floor_epoch is strictly increasing.</td>
<td>Formally verified via <a href="#high-level-req-3.1">active_with_level</a>, <a href="#high-level-req-3.2">issuer_epoch_of</a>, <a href="#high-level-req-3.3">bump_issuer_epoch</a>, <a href="#high-level-req-3.4">set_floor_epoch</a> and <a href="#high-level-req-3.5">record_verified_claim</a>.</td>
</tr>

<tr>
<td>4</td>
<td>Pausing a source blocks writes and never changes any fact or denial, so it never changes what is_verified reports (INV-4).</td>
<td>High</td>
<td>set_paused writes only Source.paused. Facts is a separate resource that the read path uses exclusively; every write path calls assert_not_paused.</td>
<td>Formally verified via <a href="#high-level-req-4">set_paused</a>.</td>
</tr>

<tr>
<td>5</td>
<td>Only a sentinel can add a denial and only a remover can remove one (INV-5). Neither operation touches any fact.</td>
<td>Critical</td>
<td>deny and deny_batch check the sentinel list, undeny checks the remover list, and both write only the denied table.</td>
<td>Formally verified via <a href="#high-level-req-5.1">deny</a>, <a href="#high-level-req-5.2">deny_batch</a> and <a href="#high-level-req-5.3">undeny</a>.</td>
</tr>

<tr>
<td>6</td>
<td>Lifecycle changes follow ACTIVE <-> SUSPENDED and ACTIVE or SUSPENDED -> REVOKED only. A revoked record is terminal until re-issued, and a lifecycle change never alters the issuer or epoch a fact was issued under, so it cannot resurrect a fact an epoch bump killed.</td>
<td>Critical</td>
<td>transition asserts the allowed transitions, treats a repeated revocation as a no-op, and leaves issuer_id and issuer_epoch unchanged; the acting issuer is recorded in the history entry only.</td>
<td>Formally verified via <a href="#high-level-req-6">transition</a>.</td>
</tr>

<tr>
<td>7</td>
<td>Configuration and facts live in separate resources, and the read path touches only Facts and per-subject table entries, so gated transactions never conflict with one another under Block-STM (INV-7).</td>
<td>Medium</td>
<td>Facts is published once at creation and only its table entries change afterwards. The read functions (is_verified, active_with_level, is_denied) acquire Facts only.</td>
<td>Enforced by the <code><b>acquires</b></code> annotations of the read functions, which the compiler checks. Audited that no write path replaces the Facts resource itself.</td>
</tr>

<tr>
<td>8</td>
<td>Every role list is duplicate free, never contains the source itself, and a source always has at least one admin.</td>
<td>High</td>
<td>validate_members runs on creation and on every add, and remove_admins asserts that at least one admin remains.</td>
<td>Formally verified via <a href="#high-level-req-8.1">create_source_internal</a> and <a href="#high-level-req-8.2">remove_admins</a>.</td>
</tr>

<tr>
<td>9</td>
<td>Only a current issuer can write facts, directly or through the permissionless relay path. Removing an issuer's role also stops its relayed attestations.</td>
<td>Critical</td>
<td>assert_issuer and redeem_attestation both require the issuer to be in Source.issuers.</td>
<td>Formally verified via <a href="#high-level-req-9.1">suspend</a> and <a href="#high-level-req-9.2">redeem_attestation</a>.</td>
</tr>

</table>



INV-6 of the functional specification (every keyed resource an enum with a V1 variant) was not adopted: the
module follows the plain-struct style of the rest of the framework, so it is not specified here. INV-8 and INV-9
belong to attestation_authorization and attestation_policy respectively.


<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict = <b>false</b>;
</code></pre>




<a id="0x1_attestation_spec_now"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_now">spec_now</a>(): u64 {
   aptos_framework::timestamp::spec_now_seconds()
}
</code></pre>




<a id="0x1_attestation_spec_has_time"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_has_time">spec_has_time</a>(): bool {
   <b>exists</b>&lt;aptos_framework::timestamp::CurrentTimeMicroseconds&gt;(@aptos_framework)
}
</code></pre>




<a id="0x1_attestation_spec_is_source"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_is_source">spec_is_source</a>(source: <b>address</b>): bool {
   <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source) && <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source)
}
</code></pre>


A denial is in effect for the subject.


<a id="0x1_attestation_spec_is_denied"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_is_denied">spec_is_denied</a>(source: <b>address</b>, subject: <b>address</b>): bool {
   <b>let</b> denied = <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied;
   <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(denied, subject)
       && <a href="attestation.md#0x1_attestation_spec_now">spec_now</a>() &gt;= <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(denied, subject).effective_at_secs
}
</code></pre>




<a id="0x1_attestation_spec_floor"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source: <b>address</b>): u64 {
   <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch, 0)
}
</code></pre>




<a id="0x1_attestation_spec_own_epoch"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_own_epoch">spec_own_epoch</a>(source: <b>address</b>, issuer_id: u16): u64 {
   <b>let</b> epochs = <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).issuer_epochs;
   <b>if</b> (<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(epochs, issuer_id)) {
       <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(epochs, issuer_id)
   } <b>else</b> { 0 }
}
</code></pre>


Effective epoch of an issuer: the larger of its own counter and the source floor.


<a id="0x1_attestation_spec_effective_epoch"></a>


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source: <b>address</b>, issuer_id: u16): u64 {
   <b>let</b> own = <a href="attestation.md#0x1_attestation_spec_own_epoch">spec_own_epoch</a>(source, issuer_id);
   <b>let</b> floor = <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source);
   <b>if</b> (own &gt; floor) { own } <b>else</b> { floor }
}
</code></pre>




<a id="0x1_attestation_SourceExistsAbortsIf"></a>


<pre><code><b>schema</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a> {
    source: <b>address</b>;
    <b>aborts_if</b> !<a href="attestation.md#0x1_attestation_spec_is_source">spec_is_source</a>(source);
}
</code></pre>



<a id="@Specification_1_active_with_level"></a>

### Function `active_with_level`


<pre><code><b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_active_with_level">active_with_level</a>(source: <b>address</b>, subject: <b>address</b>): (bool, u8)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>let</b> facts = <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source);
<b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(facts.subjects, subject);
// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_is_denied">spec_is_denied</a>(source, subject) ==&gt; !result_1 && result_2 == 0;
// This enforces <a id="high-level-req-3.1" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> result_1 ==&gt; <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(facts.subjects, subject)
    && record.state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>
    && record.expires_at_secs &gt; <a href="attestation.md#0x1_attestation_spec_now">spec_now</a>()
    && record.issuer_epoch &gt;= <a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, record.issuer_id);
<b>ensures</b> result_1 ==&gt; result_2 == record.level;
<b>ensures</b> !result_1 ==&gt; result_2 == 0;
</code></pre>



<a id="@Specification_1_is_denied"></a>

### Function `is_denied`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_denied">is_denied</a>(source: <b>address</b>, subject: <b>address</b>): bool
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject) && !<a href="attestation.md#0x1_attestation_spec_has_time">spec_has_time</a>();
<b>ensures</b> result == <a href="attestation.md#0x1_attestation_spec_is_denied">spec_is_denied</a>(source, subject);
</code></pre>



<a id="@Specification_1_admins"></a>

### Function `admins`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_admins">admins</a>(source: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>ensures</b> result == <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).admins;
</code></pre>



<a id="@Specification_1_is_admin"></a>

### Function `is_admin`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_admin">is_admin</a>(addr: <b>address</b>, source: <b>address</b>): bool
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>ensures</b> result == contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).admins, addr);
</code></pre>



<a id="@Specification_1_is_issuer"></a>

### Function `is_issuer`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_issuer">is_issuer</a>(addr: <b>address</b>, source: <b>address</b>): bool
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>ensures</b> result == contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).issuers, addr);
</code></pre>



<a id="@Specification_1_issuer_epoch_of"></a>

### Function `issuer_epoch_of`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_issuer_epoch_of">issuer_epoch_of</a>(source: <b>address</b>, issuer_id: u16): u64
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch, 0);
// This enforces <a id="high-level-req-3.2" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> result == <a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, issuer_id);
<b>ensures</b> result &gt;= <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source);
<b>ensures</b> result &gt;= <a href="attestation.md#0x1_attestation_spec_own_epoch">spec_own_epoch</a>(source, issuer_id);
</code></pre>



<a id="@Specification_1_floor_epoch"></a>

### Function `floor_epoch`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_floor_epoch">floor_epoch</a>(source: <b>address</b>): u64
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch, 0);
<b>ensures</b> result == <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source);
</code></pre>



<a id="@Specification_1_is_paused"></a>

### Function `is_paused`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_paused">is_paused</a>(source: <b>address</b>): bool
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>ensures</b> result == <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
</code></pre>



<a id="@Specification_1_is_source"></a>

### Function `is_source`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_is_source">is_source</a>(source: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == <a href="attestation.md#0x1_attestation_spec_is_source">spec_is_source</a>(source);
</code></pre>



<a id="@Specification_1_standard_version"></a>

### Function `standard_version`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="attestation.md#0x1_attestation_standard_version">standard_version</a>(): u64
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
<b>ensures</b> result == <a href="attestation.md#0x1_attestation_VERSION">VERSION</a>;
</code></pre>



<a id="@Specification_1_create"></a>

### Function `create`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> verify = <b>false</b>;
</code></pre>



<a id="@Specification_1_create_source_internal"></a>

### Function `create_source_internal`


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_create_source_internal">create_source_internal</a>(source_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, deployer: <b>address</b>, admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, issuers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, sentinels: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, removers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, guardians: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>




<pre><code><b>let</b> addr = address_of(source_account);
<b>pragma</b> aborts_if_is_partial;
// This enforces <a id="high-level-req-8.1" href="#high-level-req">high-level requirement 8</a>:
<b>aborts_if</b> len(admins) &lt; 1;
<b>aborts_if</b> <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr);
<b>aborts_if</b> <b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(addr);
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_is_source">spec_is_source</a>(addr);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).admins == admins;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).issuers == issuers;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).sentinels == sentinels;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).removers == removers;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).guardians == guardians;
<b>ensures</b> !<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).paused;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(addr).next_issuer_id == 1;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(addr).floor_epoch, 0);
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(addr) == 0;
</code></pre>



<a id="@Specification_1_add_admins"></a>

### Function `add_admins`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_add_admins">add_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, new_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_AdminAbortsIf">AdminAbortsIf</a>;
</code></pre>



<a id="@Specification_1_remove_admins"></a>

### Function `remove_admins`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_remove_admins">remove_admins</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, old_admins: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_AdminAbortsIf">AdminAbortsIf</a>;
// This enforces <a id="high-level-req-8.2" href="#high-level-req">high-level requirement 8</a>:
<b>ensures</b> len(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).admins) &gt;= 1;
</code></pre>



<a id="@Specification_1_pause"></a>

### Function `pause`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_pause">pause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).guardians, address_of(guardian));
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source) == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source));
</code></pre>



<a id="@Specification_1_unpause"></a>

### Function `unpause`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unpause">unpause</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).guardians, address_of(guardian));
<b>ensures</b> !<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source) == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source));
</code></pre>



<a id="@Specification_1_set_paused"></a>

### Function `set_paused`


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_set_paused">set_paused</a>(guardian: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, paused: bool)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).guardians, address_of(guardian));
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused == paused;
// This enforces <a id="high-level-req-4" href="#high-level-req">high-level requirement 4</a>:
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source) == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source));
</code></pre>



<a id="@Specification_1_bump_issuer_epoch"></a>

### Function `bump_issuer_epoch`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_bump_issuer_epoch">bump_issuer_epoch</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, issuer_id: u16)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_AdminAbortsIf">AdminAbortsIf</a>;
<b>aborts_if</b> issuer_id != 0 && !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).issuer_by_id, issuer_id);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch, 0);
<b>aborts_if</b> <a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, issuer_id) + 1 &gt; MAX_U64;
// This enforces <a id="high-level-req-3.3" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_own_epoch">spec_own_epoch</a>(source, issuer_id) == <b>old</b>(<a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, issuer_id)) + 1;
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, issuer_id) &gt; <b>old</b>(<a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, issuer_id));
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch);
</code></pre>



<a id="@Specification_1_set_floor_epoch"></a>

### Function `set_floor_epoch`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_set_floor_epoch">set_floor_epoch</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, epoch: u64)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_AdminAbortsIf">AdminAbortsIf</a>;
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch, 0);
// This enforces <a id="high-level-req-3.4" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> epoch &lt;= <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source);
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source) == epoch;
<b>ensures</b> <a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source) &gt; <b>old</b>(<a href="attestation.md#0x1_attestation_spec_floor">spec_floor</a>(source));
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
</code></pre>



<a id="@Specification_1_suspend"></a>

### Function `suspend`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_suspend">suspend</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
// This enforces <a id="high-level-req-9.1" href="#high-level-req">high-level requirement 9</a>:
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).issuers, address_of(issuer));
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).issuer_info, address_of(issuer));
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject).state == <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
</code></pre>



<a id="@Specification_1_unsuspend"></a>

### Function `unsuspend`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_unsuspend">unsuspend</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).issuers, address_of(issuer));
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject)
    && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject).state != <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject).issuer_epoch
    == <b>old</b>(<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject).issuer_epoch);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
</code></pre>



<a id="@Specification_1_redeem_attestation"></a>

### Function `redeem_attestation`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_redeem_attestation">redeem_attestation</a>(_relayer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, issuer_id: u16, issuer_epoch: u64, level: u8, expires_at_secs: u64, issued_at_secs: u64, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> config = <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source);
<b>let</b> issuer_address = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(config.issuer_by_id, issuer_id);
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> config.paused;
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(config.issuer_by_id, issuer_id);
// This enforces <a id="high-level-req-9.2" href="#high-level-req">high-level requirement 9</a>:
<b>aborts_if</b> !contains(config.issuers, issuer_address);
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject).issuer_epoch == issuer_epoch;
</code></pre>



<a id="@Specification_1_record_verified_claim"></a>

### Function `record_verified_claim`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="attestation.md#0x1_attestation_record_verified_claim">record_verified_claim</a>(source: <b>address</b>, subject: <b>address</b>, level: u8, expires_at_secs: u64, attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, nullifier: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
<b>aborts_if</b> len(attestation_digest) != <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>;
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>let</b> <b>post</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject);
<b>ensures</b> record.issuer_id == 0;
// This enforces <a id="high-level-req-3.5" href="#high-level-req">high-level requirement 3</a>:
<b>ensures</b> record.issuer_epoch == <b>old</b>(<a href="attestation.md#0x1_attestation_spec_effective_epoch">spec_effective_epoch</a>(source, 0));
<b>ensures</b> record.level == level;
<b>ensures</b> record.state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
</code></pre>



<a id="@Specification_1_deny"></a>

### Function `deny`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny">deny</a>(sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>, reason: u16, effective_at_secs: u64)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
// This enforces <a id="high-level-req-5.1" href="#high-level-req">high-level requirement 5</a>:
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).sentinels, address_of(sentinel));
<b>aborts_if</b> !<a href="attestation.md#0x1_attestation_spec_has_time">spec_has_time</a>();
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject).effective_at_secs == effective_at_secs;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects);
</code></pre>



<a id="@Specification_1_deny_batch"></a>

### Function `deny_batch`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_deny_batch">deny_batch</a>(sentinel: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subjects: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, reason: u16)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
// This enforces <a id="high-level-req-5.2" href="#high-level-req">high-level requirement 5</a>:
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).sentinels, address_of(sentinel));
<b>aborts_if</b> len(subjects) &gt; <a href="attestation.md#0x1_attestation_MAX_BATCH">MAX_BATCH</a>;
</code></pre>



<a id="@Specification_1_undeny"></a>

### Function `undeny`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_undeny">undeny</a>(remover: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, subject: <b>address</b>)
</code></pre>




<pre><code><b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
// This enforces <a id="high-level-req-5.3" href="#high-level-req">high-level requirement 5</a>:
<b>aborts_if</b> !contains(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).removers, address_of(remover));
<b>ensures</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects);
</code></pre>



<a id="@Specification_1_publish_root"></a>

### Function `publish_root`


<pre><code><b>public</b> entry <b>fun</b> <a href="attestation.md#0x1_attestation_publish_root">publish_root</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, source: <b>address</b>, digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, leaf_count: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> len(digest) != <a href="attestation.md#0x1_attestation_DIGEST_LENGTH">DIGEST_LENGTH</a>;
<b>include</b> <a href="attestation.md#0x1_attestation_SourceExistsAbortsIf">SourceExistsAbortsIf</a>;
<b>aborts_if</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).paused;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).root_epoch == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Source">Source</a>&gt;(source).root_epoch) + 1;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source) == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source));
</code></pre>



<a id="@Specification_1_record_fact"></a>

### Function `record_fact`


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_record_fact">record_fact</a>(source: <b>address</b>, subject: <b>address</b>, state: u8, level: u8, issuer_id: u16, issuer_epoch: u64, expires_at_secs: u64, issued_at_secs: u64, reason: u16, attestation_digest: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source);
<b>aborts_if</b> !<a href="attestation.md#0x1_attestation_spec_has_time">spec_has_time</a>();
// This enforces <a id="high-level-req-2.1" href="#high-level-req">high-level requirement 2</a>:
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied, subject);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).issuer_epochs == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).issuer_epochs);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).nullifiers == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).nullifiers);
<b>let</b> <b>post</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject);
<b>ensures</b> record.state == state;
<b>ensures</b> record.level == level;
<b>ensures</b> record.issuer_id == issuer_id;
<b>ensures</b> record.issuer_epoch == issuer_epoch;
<b>ensures</b> record.expires_at_secs == expires_at_secs;
</code></pre>



<a id="@Specification_1_transition"></a>

### Function `transition`


<pre><code><b>fun</b> <a href="attestation.md#0x1_attestation_transition">transition</a>(source: <b>address</b>, subject: <b>address</b>, state: u8, acting_issuer_id: u16, reason: u16)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> facts = <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source);
<b>let</b> record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(facts.subjects, subject);
<b>let</b> <b>post</b> post_record = <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).subjects, subject);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(facts.subjects, subject);
// This enforces <a id="high-level-req-6" href="#high-level-req">high-level requirement 6</a>:
<b>aborts_if</b> state == <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a> && record.state != <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>;
<b>aborts_if</b> state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a> && record.state != <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a>;
<b>aborts_if</b> state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a> && record.state != <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a>
    && record.state != <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a> && record.state != <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>;
<b>aborts_if</b> state != <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a> && state != <a href="attestation.md#0x1_attestation_STATE_SUSPENDED">STATE_SUSPENDED</a> && state != <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a>;
// This enforces <a id="high-level-req-2.2" href="#high-level-req">high-level requirement 2</a>:
<b>aborts_if</b> state == <a href="attestation.md#0x1_attestation_STATE_ACTIVE">STATE_ACTIVE</a> && <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(facts.denied, subject);
<b>ensures</b> post_record.issuer_id == record.issuer_id;
<b>ensures</b> post_record.issuer_epoch == record.issuer_epoch;
<b>ensures</b> post_record.level == record.level;
<b>ensures</b> post_record.expires_at_secs == record.expires_at_secs;
<b>ensures</b> post_record.state == state;
<b>ensures</b> record.state == <a href="attestation.md#0x1_attestation_STATE_REVOKED">STATE_REVOKED</a> ==&gt; post_record == record;
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).denied);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).issuer_epochs == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).issuer_epochs);
<b>ensures</b> <b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch == <b>old</b>(<b>global</b>&lt;<a href="attestation.md#0x1_attestation_Facts">Facts</a>&gt;(source).floor_epoch);
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
