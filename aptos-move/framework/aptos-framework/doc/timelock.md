
<a id="0x1_timelock"></a>

# Module `0x1::timelock`

Timelock account module for Movement. Unlike multisig accounts which require n-of-m
signatures, a timelock account enforces a time delay before transactions can be executed.

Each timelock account is a resource account with:
- A list of creators who can propose transactions (must have at least 1)
- A list of executors who can execute transactions after the timelock period
(if executors is empty, creators can also execute)
- A configurable minimum delay (<code>min_num_seconds_execute</code>) that must elapse after a
transaction is proposed before it can be executed

Execution model (mirrors <code><a href="aptos_governance.md#0x1_aptos_governance">aptos_governance</a></code> resolution): a creator proposes the SHA3-256
hash of a future resolution script's bytecode. After the delay, an authorized executor submits a
<code>Script</code> transaction whose script hash equals the proposed <code>execution_hash</code>. The script
calls <code>resolve</code>, which verifies the running script's hash via
<code><a href="transaction_context.md#0x1_transaction_context_get_script_hash">transaction_context::get_script_hash</a>()</code> and returns the timelock account's signer. The
script then performs arbitrary Move calls under that signer, including the self-governance
entry functions in this module.

Properties:
- Transactions are indexed by <code>keccak256(execution_hash || salt)</code>. To submit the same
script more than once, change the salt.
- Changing <code>min_num_seconds_execute</code> or membership can only happen through the timelock
proposal mechanism itself (the timelock account must be the signer).
- Both creators and executors can cancel any pending transaction at any time.
- Once executed or canceled, the transaction's <code>executed</code> field is set to true and the
entry is kept permanently for historical record.
- If the resolution script aborts, the entire transaction (including the <code>executed</code> flag
flip) reverts atomically, so the proposal remains executable.


-  [Resource `TimelockAccount`](#0x1_timelock_TimelockAccount)
-  [Struct `TimelockTransaction`](#0x1_timelock_TimelockTransaction)
-  [Struct `AddCreators`](#0x1_timelock_AddCreators)
-  [Struct `RemoveCreators`](#0x1_timelock_RemoveCreators)
-  [Struct `AddExecutors`](#0x1_timelock_AddExecutors)
-  [Struct `RemoveExecutors`](#0x1_timelock_RemoveExecutors)
-  [Struct `UpdateMinNumSecondsExecute`](#0x1_timelock_UpdateMinNumSecondsExecute)
-  [Struct `CreateTransaction`](#0x1_timelock_CreateTransaction)
-  [Struct `CancelTransaction`](#0x1_timelock_CancelTransaction)
-  [Struct `ResolveTransaction`](#0x1_timelock_ResolveTransaction)
-  [Constants](#@Constants_0)
-  [Function `creators`](#0x1_timelock_creators)
-  [Function `executors`](#0x1_timelock_executors)
-  [Function `min_num_seconds_execute`](#0x1_timelock_min_num_seconds_execute)
-  [Function `is_creator`](#0x1_timelock_is_creator)
-  [Function `is_executor`](#0x1_timelock_is_executor)
-  [Function `get_transaction`](#0x1_timelock_get_transaction)
-  [Function `can_be_executed`](#0x1_timelock_can_be_executed)
-  [Function `get_next_timelock_account_address`](#0x1_timelock_get_next_timelock_account_address)
-  [Function `get_transaction_hash`](#0x1_timelock_get_transaction_hash)
-  [Function `create`](#0x1_timelock_create)
    -  [Arguments](#@Arguments_1)
    -  [Aborts](#@Aborts_2)
-  [Function `create_timelock_account_internal`](#0x1_timelock_create_timelock_account_internal)
-  [Function `add_creators`](#0x1_timelock_add_creators)
-  [Function `remove_creators`](#0x1_timelock_remove_creators)
-  [Function `add_executors`](#0x1_timelock_add_executors)
-  [Function `remove_executors`](#0x1_timelock_remove_executors)
-  [Function `update_min_num_seconds_execute`](#0x1_timelock_update_min_num_seconds_execute)
-  [Function `create_transaction`](#0x1_timelock_create_transaction)
-  [Function `cancel_transaction`](#0x1_timelock_cancel_transaction)
-  [Function `resolve`](#0x1_timelock_resolve)
-  [Function `create_timelock_account`](#0x1_timelock_create_timelock_account)
-  [Function `create_timelock_account_seed`](#0x1_timelock_create_timelock_account_seed)
-  [Function `validate_members`](#0x1_timelock_validate_members)
-  [Function `assert_timelock_account_exists`](#0x1_timelock_assert_timelock_account_exists)
-  [Function `assert_is_creator`](#0x1_timelock_assert_is_creator)
-  [Function `assert_is_executor`](#0x1_timelock_assert_is_executor)
-  [Function `assert_delay`](#0x1_timelock_assert_delay)
-  [Specification](#@Specification_3)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `creators`](#@Specification_3_creators)
    -  [Function `executors`](#@Specification_3_executors)
    -  [Function `min_num_seconds_execute`](#@Specification_3_min_num_seconds_execute)
    -  [Function `is_creator`](#@Specification_3_is_creator)
    -  [Function `is_executor`](#@Specification_3_is_executor)
    -  [Function `get_transaction`](#@Specification_3_get_transaction)
    -  [Function `can_be_executed`](#@Specification_3_can_be_executed)
    -  [Function `get_next_timelock_account_address`](#@Specification_3_get_next_timelock_account_address)
    -  [Function `get_transaction_hash`](#@Specification_3_get_transaction_hash)
    -  [Function `create`](#@Specification_3_create)
    -  [Function `create_timelock_account_internal`](#@Specification_3_create_timelock_account_internal)
    -  [Function `add_creators`](#@Specification_3_add_creators)
    -  [Function `remove_creators`](#@Specification_3_remove_creators)
    -  [Function `add_executors`](#@Specification_3_add_executors)
    -  [Function `remove_executors`](#@Specification_3_remove_executors)
    -  [Function `update_min_num_seconds_execute`](#@Specification_3_update_min_num_seconds_execute)
    -  [Function `create_transaction`](#@Specification_3_create_transaction)
    -  [Function `cancel_transaction`](#@Specification_3_cancel_transaction)
    -  [Function `resolve`](#@Specification_3_resolve)
    -  [Function `create_timelock_account`](#@Specification_3_create_timelock_account)
    -  [Function `create_timelock_account_seed`](#@Specification_3_create_timelock_account_seed)
    -  [Function `validate_members`](#@Specification_3_validate_members)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="aptos_coin.md#0x1_aptos_coin">0x1::aptos_coin</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/hash.md#0x1_aptos_hash">0x1::aptos_hash</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="coin.md#0x1_coin">0x1::coin</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table">0x1::table</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="transaction_context.md#0x1_transaction_context">0x1::transaction_context</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_timelock_TimelockAccount"></a>

## Resource `TimelockAccount`

Represents a timelock account's configuration and pending/historical transactions.
Stored at the resource account address created during timelock account creation.


<pre><code><b>struct</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>min_num_seconds_execute: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>transactions: <a href="../../aptos-stdlib/doc/table.md#0x1_table_Table">table::Table</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="timelock.md#0x1_timelock_TimelockTransaction">timelock::TimelockTransaction</a>&gt;</code>
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

<a id="0x1_timelock_TimelockTransaction"></a>

## Struct `TimelockTransaction`

A transaction proposed for timelock execution.

<code>execution_hash</code> is the keccak256 hash of the authorized resolution script. At resolve
time it is checked against the running script's hash via <code><a href="transaction_context.md#0x1_transaction_context_get_script_hash">transaction_context::get_script_hash</a>()</code>.


<pre><code><b>struct</b> <a href="timelock.md#0x1_timelock_TimelockTransaction">TimelockTransaction</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>creator: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>creation_time_secs: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>num_seconds_execute: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>executed: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_AddCreators"></a>

## Struct `AddCreators`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_AddCreators">AddCreators</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_RemoveCreators"></a>

## Struct `RemoveCreators`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_RemoveCreators">RemoveCreators</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>removed_creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_AddExecutors"></a>

## Struct `AddExecutors`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_AddExecutors">AddExecutors</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_RemoveExecutors"></a>

## Struct `RemoveExecutors`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_RemoveExecutors">RemoveExecutors</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>removed_executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_UpdateMinNumSecondsExecute"></a>

## Struct `UpdateMinNumSecondsExecute`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_UpdateMinNumSecondsExecute">UpdateMinNumSecondsExecute</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>old_min_num_seconds_execute: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>new_min_num_seconds_execute: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_CreateTransaction"></a>

## Struct `CreateTransaction`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_CreateTransaction">CreateTransaction</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>creator: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>transaction: <a href="timelock.md#0x1_timelock_TimelockTransaction">timelock::TimelockTransaction</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_CancelTransaction"></a>

## Struct `CancelTransaction`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_CancelTransaction">CancelTransaction</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>actor: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_timelock_ResolveTransaction"></a>

## Struct `ResolveTransaction`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="timelock.md#0x1_timelock_ResolveTransaction">ResolveTransaction</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>timelock_account: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>executor: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_timelock_DOMAIN_SEPARATOR"></a>

Domain separator used when deriving the resource account seed, to avoid collisions
with other modules that create resource accounts.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 116, 105, 109, 101, 108, 111, 99, 107];
</code></pre>



<a id="0x1_timelock_ETRANSACTION_NOT_FOUND"></a>

Transaction with the specified hash was not found.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ETRANSACTION_NOT_FOUND">ETRANSACTION_NOT_FOUND</a>: u64 = 7;
</code></pre>



<a id="0x1_timelock_EACCOUNT_NOT_TIMELOCK"></a>

Specified account is not a timelock account.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EACCOUNT_NOT_TIMELOCK">EACCOUNT_NOT_TIMELOCK</a>: u64 = 3;
</code></pre>



<a id="0x1_timelock_EDUPLICATE_CREATOR"></a>

Creator list cannot contain duplicate addresses.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EDUPLICATE_CREATOR">EDUPLICATE_CREATOR</a>: u64 = 1;
</code></pre>



<a id="0x1_timelock_EDUPLICATE_EXECUTOR"></a>

Executor list cannot contain duplicate addresses.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EDUPLICATE_EXECUTOR">EDUPLICATE_EXECUTOR</a>: u64 = 2;
</code></pre>



<a id="0x1_timelock_EDUPLICATE_TRANSACTION"></a>

A transaction with this execution hash and salt already exists.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EDUPLICATE_TRANSACTION">EDUPLICATE_TRANSACTION</a>: u64 = 11;
</code></pre>



<a id="0x1_timelock_EEXECUTION_HASH_NOT_MATCHING"></a>

Current transaction script hash does not match the proposed execution hash.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EEXECUTION_HASH_NOT_MATCHING">EEXECUTION_HASH_NOT_MATCHING</a>: u64 = 17;
</code></pre>



<a id="0x1_timelock_EINVALID_BYTES_LENGTH"></a>

The provided hash or salt must be exactly 32 bytes.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>: u64 = 16;
</code></pre>



<a id="0x1_timelock_ENOT_CREATOR"></a>

The caller is not a creator.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENOT_CREATOR">ENOT_CREATOR</a>: u64 = 4;
</code></pre>



<a id="0x1_timelock_ENOT_CREATOR_OR_EXECUTOR"></a>

The caller is neither a creator nor an executor.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENOT_CREATOR_OR_EXECUTOR">ENOT_CREATOR_OR_EXECUTOR</a>: u64 = 13;
</code></pre>



<a id="0x1_timelock_ENOT_ENOUGH_CREATORS"></a>

Timelock account must have at least one creator.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENOT_ENOUGH_CREATORS">ENOT_ENOUGH_CREATORS</a>: u64 = 6;
</code></pre>



<a id="0x1_timelock_ENOT_EXECUTOR"></a>

The caller is not an executor (or a creator when the executor list is empty).


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENOT_EXECUTOR">ENOT_EXECUTOR</a>: u64 = 5;
</code></pre>



<a id="0x1_timelock_ENUMBER_SECONDS_TOO_LARGE"></a>

The account's <code>min_num_seconds_execute</code> must not exceed <code><a href="timelock.md#0x1_timelock_MAX_NUM_SECONDS_EXECUTE">MAX_NUM_SECONDS_EXECUTE</a></code> (604800).


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENUMBER_SECONDS_TOO_LARGE">ENUMBER_SECONDS_TOO_LARGE</a>: u64 = 15;
</code></pre>



<a id="0x1_timelock_ENUMBER_SECONDS_TOO_SMALL"></a>

The specified number of seconds is below the required minimum: the account's
<code>min_num_seconds_execute</code> must be greater than <code><a href="timelock.md#0x1_timelock_MIN_NUM_SECONDS_EXECUTE">MIN_NUM_SECONDS_EXECUTE</a></code> (360),
and a transaction's <code>num_seconds_execute</code> must be at least the account's
<code>min_num_seconds_execute</code>.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ENUMBER_SECONDS_TOO_SMALL">ENUMBER_SECONDS_TOO_SMALL</a>: u64 = 14;
</code></pre>



<a id="0x1_timelock_ESELF_CANNOT_BE_MEMBER"></a>

The timelock account itself cannot be a creator or executor.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>: u64 = 10;
</code></pre>



<a id="0x1_timelock_ETIMELOCK_NOT_EXPIRED"></a>

The timelock period has not elapsed yet.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ETIMELOCK_NOT_EXPIRED">ETIMELOCK_NOT_EXPIRED</a>: u64 = 8;
</code></pre>



<a id="0x1_timelock_ETRANSACTION_ALREADY_EXECUTED"></a>

Transaction has already been executed or canceled.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_ETRANSACTION_ALREADY_EXECUTED">ETRANSACTION_ALREADY_EXECUTED</a>: u64 = 9;
</code></pre>



<a id="0x1_timelock_EWOULD_REMOVE_ALL_CREATORS"></a>

Removing these creators would leave the timelock account with zero creators.


<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_EWOULD_REMOVE_ALL_CREATORS">EWOULD_REMOVE_ALL_CREATORS</a>: u64 = 12;
</code></pre>



<a id="0x1_timelock_MAX_NUM_SECONDS_EXECUTE"></a>



<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_MAX_NUM_SECONDS_EXECUTE">MAX_NUM_SECONDS_EXECUTE</a>: u64 = 604800;
</code></pre>



<a id="0x1_timelock_MIN_NUM_SECONDS_EXECUTE"></a>



<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_MIN_NUM_SECONDS_EXECUTE">MIN_NUM_SECONDS_EXECUTE</a>: u64 = 360;
</code></pre>



<a id="0x1_timelock_SALT_LENGTH"></a>



<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_SALT_LENGTH">SALT_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_timelock_SCRIPT_HASH_LENGTH"></a>



<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_SCRIPT_HASH_LENGTH">SCRIPT_HASH_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_timelock_TRANSACTION_HASH_LENGTH"></a>



<pre><code><b>const</b> <a href="timelock.md#0x1_timelock_TRANSACTION_HASH_LENGTH">TRANSACTION_HASH_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_timelock_creators"></a>

## Function `creators`

Return the list of creators for the given timelock account.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_creators">creators</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_creators">creators</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].creators
}
</code></pre>



</details>

<a id="0x1_timelock_executors"></a>

## Function `executors`

Return the list of executors. An empty list means creators can also execute.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_executors">executors</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_executors">executors</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].executors
}
</code></pre>



</details>

<a id="0x1_timelock_min_num_seconds_execute"></a>

## Function `min_num_seconds_execute`

Return the minimum timelock delay in seconds.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_min_num_seconds_execute">min_num_seconds_execute</a>(timelock_account: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_min_num_seconds_execute">min_num_seconds_execute</a>(timelock_account: <b>address</b>): u64 <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].min_num_seconds_execute
}
</code></pre>



</details>

<a id="0x1_timelock_is_creator"></a>

## Function `is_creator`

Return true if the given address is a creator of the timelock account.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_creator">is_creator</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_creator">is_creator</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].creators.contains(&addr)
}
</code></pre>



</details>

<a id="0x1_timelock_is_executor"></a>

## Function `is_executor`

Return true if the given address is authorized to execute transactions.
If the executor list is empty, creators are also authorized to execute.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_executor">is_executor</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_executor">is_executor</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>if</b> (<a href="timelock.md#0x1_timelock">timelock</a>.executors.is_empty()) {
        <a href="timelock.md#0x1_timelock">timelock</a>.creators.contains(&addr)
    } <b>else</b> {
        <a href="timelock.md#0x1_timelock">timelock</a>.executors.contains(&addr)
    }
}
</code></pre>



</details>

<a id="0x1_timelock_get_transaction"></a>

## Function `get_transaction`

Return the transaction stored under the given transaction hash.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction">get_transaction</a>(timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="timelock.md#0x1_timelock_TimelockTransaction">timelock::TimelockTransaction</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction">get_transaction</a>(
    timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): <a href="timelock.md#0x1_timelock_TimelockTransaction">TimelockTransaction</a> <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>assert</b>!(
        <a href="timelock.md#0x1_timelock">timelock</a>.transactions.contains(transaction_hash),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="timelock.md#0x1_timelock_ETRANSACTION_NOT_FOUND">ETRANSACTION_NOT_FOUND</a>)
    );
    *<a href="timelock.md#0x1_timelock">timelock</a>.transactions.borrow(transaction_hash)
}
</code></pre>



</details>

<a id="0x1_timelock_can_be_executed"></a>

## Function `can_be_executed`

Return true if the transaction exists, is not yet executed/canceled,
and has passed the timelock period.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_can_be_executed">can_be_executed</a>(timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_can_be_executed">can_be_executed</a>(
    timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): bool <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>if</b> (!<a href="timelock.md#0x1_timelock">timelock</a>.transactions.contains(transaction_hash)) {
        <b>return</b> <b>false</b>
    };
    <b>let</b> tx = <a href="timelock.md#0x1_timelock">timelock</a>.transactions.borrow(transaction_hash);
    !tx.executed && now_seconds() &gt;= tx.creation_time_secs + tx.num_seconds_execute
}
</code></pre>



</details>

<a id="0x1_timelock_get_next_timelock_account_address"></a>

## Function `get_next_timelock_account_address`

Return the predicted address for the next timelock account deployed by the given account.
The deployer authorizes resource-account creation but does not become a creator or executor;
membership is determined entirely by the <code>creators</code> and <code>executors</code> arguments to <code>create</code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_next_timelock_account_address">get_next_timelock_account_address</a>(deployer: <b>address</b>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_next_timelock_account_address">get_next_timelock_account_address</a>(deployer: <b>address</b>): <b>address</b> {
    <b>let</b> owner_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(deployer);
    create_resource_address(
        &deployer, <a href="timelock.md#0x1_timelock_create_timelock_account_seed">create_timelock_account_seed</a>(to_bytes(&owner_nonce))
    )
}
</code></pre>



</details>

<a id="0x1_timelock_get_transaction_hash"></a>

## Function `get_transaction_hash`

Return the table key used to index a transaction with the given execution hash and salt.
Clients use this to compute the hash before proposing a transaction.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction_hash">get_transaction_hash</a>(execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction_hash">get_transaction_hash</a>(
    execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    execution_hash.append(salt);
    keccak256(execution_hash)
}
</code></pre>



</details>

<a id="0x1_timelock_create"></a>

## Function `create`

Create a new timelock account.

The <code>deployer</code> signer authorizes resource-account creation (and pays storage gas) but
gains no ongoing authority over the timelock — they are not added to creators or
executors. This lets a deployer (e.g. a multisig) instantiate a timelock that is owned
by an entirely different set of addresses without first having to transfer ownership.


<a id="@Arguments_1"></a>

### Arguments

* <code>deployer</code> - Signer used to derive the resource-account address. Must not appear in
<code>creators</code> or <code>executors</code> unless that role is intended.
* <code>creators</code> - Addresses authorized to propose transactions. Must contain at least one
address and have no duplicates. The timelock account address itself is not allowed.
* <code>executors</code> - Addresses authorized to execute transactions after the timelock period.
If empty, creators can also execute.
* <code>num_seconds_execute</code> - Minimum delay in seconds before a proposed transaction can be executed.


<a id="@Aborts_2"></a>

### Aborts

* If <code>creators</code> is empty
* If <code>creators</code> or <code>executors</code> contains duplicate addresses or the timelock account address
* If <code>num_seconds_execute</code> is outside the allowed delay bounds


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, num_seconds_execute: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create">create</a>(
    deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    num_seconds_execute: u64
) {
    <b>let</b> (timelock_signer, timelock_signer_cap) = <a href="timelock.md#0x1_timelock_create_timelock_account">create_timelock_account</a>(deployer);
    <a href="timelock.md#0x1_timelock_create_timelock_account_internal">create_timelock_account_internal</a>(
        &timelock_signer,
        creators,
        executors,
        num_seconds_execute,
        timelock_signer_cap
    );
}
</code></pre>



</details>

<a id="0x1_timelock_create_timelock_account_internal"></a>

## Function `create_timelock_account_internal`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_internal">create_timelock_account_internal</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, min_num_seconds_execute: u64, signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_internal">create_timelock_account_internal</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    min_num_seconds_execute: u64,
    signer_cap: SignerCapability
) {
    <a href="timelock.md#0x1_timelock_assert_delay">assert_delay</a>(min_num_seconds_execute);
    <b>let</b> timelock_address = address_of(timelock_account);
    <b>assert</b>!(creators.length() &gt;= 1, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_ENOT_ENOUGH_CREATORS">ENOT_ENOUGH_CREATORS</a>));
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&creators, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_CREATOR">EDUPLICATE_CREATOR</a>);
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&executors, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_EXECUTOR">EDUPLICATE_EXECUTOR</a>);

    <b>move_to</b>(
        timelock_account,
        <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
            creators,
            executors,
            min_num_seconds_execute,
            transactions: <a href="../../aptos-stdlib/doc/table.md#0x1_table_new">table::new</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="timelock.md#0x1_timelock_TimelockTransaction">TimelockTransaction</a>&gt;(),
            signer_cap
        }
    );
}
</code></pre>



</details>

<a id="0x1_timelock_add_creators"></a>

## Function `add_creators`

Add new creators to the timelock account.
Can only be invoked by the timelock account itself via the proposal flow.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_creators">add_creators</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_creators">add_creators</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> timelock_address = address_of(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_address);
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&new_creators, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_CREATOR">EDUPLICATE_CREATOR</a>);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_address];
    <a href="timelock.md#0x1_timelock">timelock</a>.creators.append(new_creators);
    // Re-validate the combined list <b>to</b> catch cross-list duplicates.
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&<a href="timelock.md#0x1_timelock">timelock</a>.creators, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_CREATOR">EDUPLICATE_CREATOR</a>);
    emit(<a href="timelock.md#0x1_timelock_AddCreators">AddCreators</a> { timelock_account: timelock_address, new_creators });
}
</code></pre>



</details>

<a id="0x1_timelock_remove_creators"></a>

## Function `remove_creators`

Remove creators from the timelock account. At least one creator must remain.
Can only be invoked by the timelock account itself via the proposal flow.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_creators">remove_creators</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_creators">remove_creators</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> timelock_address = address_of(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_address);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_address];
    <b>let</b> removed_creators = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    creators_to_remove.for_each_ref(|to_remove| {
        <b>let</b> (found, index) = <a href="timelock.md#0x1_timelock">timelock</a>.creators.index_of(to_remove);
        <b>if</b> (found) {
            removed_creators.push_back(<a href="timelock.md#0x1_timelock">timelock</a>.creators.swap_remove(index));
        }
    });
    <b>assert</b>!(
        <a href="timelock.md#0x1_timelock">timelock</a>.creators.length() &gt;= 1,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="timelock.md#0x1_timelock_EWOULD_REMOVE_ALL_CREATORS">EWOULD_REMOVE_ALL_CREATORS</a>)
    );
    <b>if</b> (!removed_creators.is_empty()) {
        emit(<a href="timelock.md#0x1_timelock_RemoveCreators">RemoveCreators</a> { timelock_account: timelock_address, removed_creators });
    };
}
</code></pre>



</details>

<a id="0x1_timelock_add_executors"></a>

## Function `add_executors`

Add new executors to the timelock account.
Can only be invoked by the timelock account itself via the proposal flow.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_executors">add_executors</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_executors">add_executors</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> timelock_address = address_of(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_address);
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&new_executors, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_EXECUTOR">EDUPLICATE_EXECUTOR</a>);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_address];
    <a href="timelock.md#0x1_timelock">timelock</a>.executors.append(new_executors);
    <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(&<a href="timelock.md#0x1_timelock">timelock</a>.executors, timelock_address, <a href="timelock.md#0x1_timelock_EDUPLICATE_EXECUTOR">EDUPLICATE_EXECUTOR</a>);
    emit(<a href="timelock.md#0x1_timelock_AddExecutors">AddExecutors</a> { timelock_account: timelock_address, new_executors });
}
</code></pre>



</details>

<a id="0x1_timelock_remove_executors"></a>

## Function `remove_executors`

Remove executors from the timelock account.
After removal the executor list may be empty, which means creators can execute.
Can only be invoked by the timelock account itself via the proposal flow.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_executors">remove_executors</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, executors_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_executors">remove_executors</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, executors_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> timelock_address = address_of(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_address);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_address];
    <b>let</b> removed_executors = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    executors_to_remove.for_each_ref(|to_remove| {
        <b>let</b> (found, index) = <a href="timelock.md#0x1_timelock">timelock</a>.executors.index_of(to_remove);
        <b>if</b> (found) {
            removed_executors.push_back(<a href="timelock.md#0x1_timelock">timelock</a>.executors.swap_remove(index));
        }
    });
    <b>if</b> (!removed_executors.is_empty()) {
        emit(
            <a href="timelock.md#0x1_timelock_RemoveExecutors">RemoveExecutors</a> { timelock_account: timelock_address, removed_executors }
        );
    };
}
</code></pre>



</details>

<a id="0x1_timelock_update_min_num_seconds_execute"></a>

## Function `update_min_num_seconds_execute`

Update the timelock delay. The new value takes effect immediately for future proposals.
Existing pending transactions are not affected.
Can only be invoked by the timelock account itself via the proposal flow.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_update_min_num_seconds_execute">update_min_num_seconds_execute</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_min_num_seconds_execute: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_update_min_num_seconds_execute">update_min_num_seconds_execute</a>(
    timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_min_num_seconds_execute: u64
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <b>let</b> timelock_address = address_of(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_address);
    <a href="timelock.md#0x1_timelock_assert_delay">assert_delay</a>(new_min_num_seconds_execute);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_address];
    <b>let</b> old_min_num_seconds_execute = <a href="timelock.md#0x1_timelock">timelock</a>.min_num_seconds_execute;
    <a href="timelock.md#0x1_timelock">timelock</a>.min_num_seconds_execute = new_min_num_seconds_execute;
    emit(
        <a href="timelock.md#0x1_timelock_UpdateMinNumSecondsExecute">UpdateMinNumSecondsExecute</a> {
            timelock_account: timelock_address,
            old_min_num_seconds_execute,
            new_min_num_seconds_execute
        }
    );
}
</code></pre>



</details>

<a id="0x1_timelock_create_transaction"></a>

## Function `create_transaction`

Propose a new transaction to be executed after the timelock period.

<code>execution_hash</code> is the SHA3-256 hash of the resolution script's bytecode that will
perform the transaction's effects when submitted. <code>salt</code> (32 bytes) disambiguates duplicate
proposals of the same script. The table key is <code>keccak256(execution_hash || salt)</code>.
<code>num_seconds_execute</code> must be >= <code>min_num_seconds_execute</code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create_transaction">create_transaction</a>(creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, num_seconds_execute: u64, salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create_transaction">create_transaction</a>(
    creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    timelock_account: <b>address</b>,
    execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    num_seconds_execute: u64,
    salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_is_creator">assert_is_creator</a>(creator, timelock_account);
    <b>assert</b>!(
        execution_hash.length() == <a href="timelock.md#0x1_timelock_SCRIPT_HASH_LENGTH">SCRIPT_HASH_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>assert</b>!(
        salt.length() == <a href="timelock.md#0x1_timelock_SALT_LENGTH">SALT_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );

    <b>let</b> transaction_hash = <a href="timelock.md#0x1_timelock_get_transaction_hash">get_transaction_hash</a>(execution_hash, salt);
    <b>let</b> creator_addr = address_of(creator);
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>assert</b>!(
        num_seconds_execute &gt;= <a href="timelock.md#0x1_timelock">timelock</a>.min_num_seconds_execute,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_ENUMBER_SECONDS_TOO_SMALL">ENUMBER_SECONDS_TOO_SMALL</a>)
    );
    <b>assert</b>!(
        !<a href="timelock.md#0x1_timelock">timelock</a>.transactions.contains(transaction_hash),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="timelock.md#0x1_timelock_EDUPLICATE_TRANSACTION">EDUPLICATE_TRANSACTION</a>)
    );

    <b>let</b> transaction = <a href="timelock.md#0x1_timelock_TimelockTransaction">TimelockTransaction</a> {
        execution_hash,
        creator: creator_addr,
        creation_time_secs: now_seconds(),
        num_seconds_execute,
        salt,
        executed: <b>false</b>
    };
    <a href="timelock.md#0x1_timelock">timelock</a>.transactions.add(transaction_hash, transaction);

    emit(
        <a href="timelock.md#0x1_timelock_CreateTransaction">CreateTransaction</a> {
            timelock_account,
            creator: creator_addr,
            transaction_hash,
            transaction
        }
    );
}
</code></pre>



</details>

<a id="0x1_timelock_cancel_transaction"></a>

## Function `cancel_transaction`

Cancel a pending transaction. The transaction's executed field is set to true.
Any creator or executor can cancel at any time.
<code>transaction_hash</code> must be exactly 32 bytes.


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_cancel_transaction">cancel_transaction</a>(actor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_cancel_transaction">cancel_transaction</a>(
    actor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_account);
    <b>assert</b>!(
        transaction_hash.length() == <a href="timelock.md#0x1_timelock_TRANSACTION_HASH_LENGTH">TRANSACTION_HASH_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );
    <b>let</b> actor_addr = address_of(actor);

    // Evaluate authorization before acquiring the mutable borrow.
    <b>let</b> actor_is_creator = <a href="timelock.md#0x1_timelock_is_creator">is_creator</a>(actor_addr, timelock_account);
    <b>let</b> actor_is_executor = <a href="timelock.md#0x1_timelock_is_executor">is_executor</a>(actor_addr, timelock_account);
    <b>assert</b>!(
        actor_is_creator || actor_is_executor,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="timelock.md#0x1_timelock_ENOT_CREATOR_OR_EXECUTOR">ENOT_CREATOR_OR_EXECUTOR</a>)
    );

    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>assert</b>!(
        <a href="timelock.md#0x1_timelock">timelock</a>.transactions.contains(transaction_hash),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="timelock.md#0x1_timelock_ETRANSACTION_NOT_FOUND">ETRANSACTION_NOT_FOUND</a>)
    );
    <b>let</b> transaction = <a href="timelock.md#0x1_timelock">timelock</a>.transactions.borrow_mut(transaction_hash);
    <b>assert</b>!(
        !transaction.executed,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="timelock.md#0x1_timelock_ETRANSACTION_ALREADY_EXECUTED">ETRANSACTION_ALREADY_EXECUTED</a>)
    );
    transaction.executed = <b>true</b>;

    emit(<a href="timelock.md#0x1_timelock_CancelTransaction">CancelTransaction</a> { timelock_account, actor: actor_addr, transaction_hash });
}
</code></pre>



</details>

<a id="0x1_timelock_resolve"></a>

## Function `resolve`

Resolve a pending transaction and return the timelock account's signer.

Asserts that:
- The account exists and is a timelock account
- The executor is authorized
- The transaction exists and has not been executed or canceled
- The timelock period (creation_time_secs + num_seconds_execute) has elapsed
- The running script's hash equals the transaction's execution_hash

Marks the transaction executed, emits ResolveTransaction, and returns the signer for
the timelock account. The calling script uses this signer to perform the transaction's
effects (including, optionally, the self-governance entry functions in this module).
If the script later aborts, the entire transaction—including the executed flag flip—
reverts atomically, leaving the proposal in its previous state.


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_resolve">resolve</a>(executor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_resolve">resolve</a>(
    executor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>acquires</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a> {
    <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_account);
    <a href="timelock.md#0x1_timelock_assert_is_executor">assert_is_executor</a>(executor, timelock_account);
    <b>assert</b>!(
        transaction_hash.length() == <a href="timelock.md#0x1_timelock_TRANSACTION_HASH_LENGTH">TRANSACTION_HASH_LENGTH</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_EINVALID_BYTES_LENGTH">EINVALID_BYTES_LENGTH</a>)
    );

    <b>let</b> executor_addr = address_of(executor);

    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<b>mut</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>assert</b>!(
        <a href="timelock.md#0x1_timelock">timelock</a>.transactions.contains(transaction_hash),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="timelock.md#0x1_timelock_ETRANSACTION_NOT_FOUND">ETRANSACTION_NOT_FOUND</a>)
    );
    <b>let</b> transaction = <a href="timelock.md#0x1_timelock">timelock</a>.transactions.borrow_mut(transaction_hash);
    <b>assert</b>!(
        !transaction.executed,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="timelock.md#0x1_timelock_ETRANSACTION_ALREADY_EXECUTED">ETRANSACTION_ALREADY_EXECUTED</a>)
    );
    <b>assert</b>!(
        now_seconds()
            &gt;= transaction.creation_time_secs + transaction.num_seconds_execute,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="timelock.md#0x1_timelock_ETIMELOCK_NOT_EXPIRED">ETIMELOCK_NOT_EXPIRED</a>)
    );
    <b>assert</b>!(
        <a href="transaction_context.md#0x1_transaction_context_get_script_hash">transaction_context::get_script_hash</a>() == transaction.execution_hash,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_EEXECUTION_HASH_NOT_MATCHING">EEXECUTION_HASH_NOT_MATCHING</a>)
    );
    transaction.executed = <b>true</b>;
    emit(
        <a href="timelock.md#0x1_timelock_ResolveTransaction">ResolveTransaction</a> {
            timelock_account,
            executor: executor_addr,
            transaction_hash,
            execution_hash: transaction.execution_hash
        }
    );

    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <a href="account.md#0x1_account_create_signer_with_capability">account::create_signer_with_capability</a>(&<a href="timelock.md#0x1_timelock">timelock</a>.signer_cap)
}
</code></pre>



</details>

<a id="0x1_timelock_create_timelock_account"></a>

## Function `create_timelock_account`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account">create_timelock_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account">create_timelock_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, SignerCapability) {
    <b>let</b> deployer_nonce = <a href="account.md#0x1_account_get_sequence_number">account::get_sequence_number</a>(address_of(deployer));
    <b>let</b> (timelock_signer, timelock_signer_cap) =
        <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
            deployer, <a href="timelock.md#0x1_timelock_create_timelock_account_seed">create_timelock_account_seed</a>(to_bytes(&deployer_nonce))
        );
    // Register for MOVE so the <a href="timelock.md#0x1_timelock">timelock</a> <a href="account.md#0x1_account">account</a> can pay gas and receive transfers.
    <b>if</b> (!<a href="coin.md#0x1_coin_is_account_registered">coin::is_account_registered</a>&lt;AptosCoin&gt;(address_of(&timelock_signer))) {
        <a href="coin.md#0x1_coin_register">coin::register</a>&lt;AptosCoin&gt;(&timelock_signer);
    };
    (timelock_signer, timelock_signer_cap)
}
</code></pre>



</details>

<a id="0x1_timelock_create_timelock_account_seed"></a>

## Function `create_timelock_account_seed`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_seed">create_timelock_account_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_seed">create_timelock_account_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> account_seed = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    account_seed.append(<a href="timelock.md#0x1_timelock_DOMAIN_SEPARATOR">DOMAIN_SEPARATOR</a>);
    account_seed.append(seed);
    account_seed
}
</code></pre>



</details>

<a id="0x1_timelock_validate_members"></a>

## Function `validate_members`

Validate that a list of member addresses has no duplicates and does not include
the timelock account address itself. <code>duplicate_error</code> is the error code to use
when a duplicate is found (EDUPLICATE_CREATOR or EDUPLICATE_EXECUTOR).


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, timelock_address: <b>address</b>, duplicate_error: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(
    members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, timelock_address: <b>address</b>, duplicate_error: u64
) {
    <b>let</b> distinct: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> total = members.length();
    <b>let</b> i = 0;
    <b>while</b> ({
        <b>spec</b> {
            <b>invariant</b> i &lt;= total;
            <b>invariant</b> len(distinct) == i;
            <b>invariant</b> <b>forall</b> k in 0..i: distinct[k] == members[k];
            <b>invariant</b> <b>forall</b> k in 0..i: members[k] != timelock_address;
            <b>invariant</b> <b>forall</b> k in 0..i: <b>forall</b> l in 0..k: members[k] != members[l];
        };
        i &lt; total
    }) {
        <b>let</b> member = *members.borrow(i);
        <b>assert</b>!(
            member != timelock_address,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_ESELF_CANNOT_BE_MEMBER">ESELF_CANNOT_BE_MEMBER</a>)
        );
        <b>let</b> (found, _) = distinct.index_of(&member);
        <b>assert</b>!(!found, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(duplicate_error));
        distinct.push_back(member);
        i = i + 1;
    };
}
</code></pre>



</details>

<a id="0x1_timelock_assert_timelock_account_exists"></a>

## Function `assert_timelock_account_exists`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_account: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="timelock.md#0x1_timelock_assert_timelock_account_exists">assert_timelock_account_exists</a>(timelock_account: <b>address</b>) {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="timelock.md#0x1_timelock_EACCOUNT_NOT_TIMELOCK">EACCOUNT_NOT_TIMELOCK</a>)
    );
}
</code></pre>



</details>

<a id="0x1_timelock_assert_is_creator"></a>

## Function `assert_is_creator`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_assert_is_creator">assert_is_creator</a>(creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="timelock.md#0x1_timelock_assert_is_creator">assert_is_creator</a>(
    creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>
) {
    <b>assert</b>!(
        <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].creators.contains(&address_of(creator)),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="timelock.md#0x1_timelock_ENOT_CREATOR">ENOT_CREATOR</a>)
    );
}
</code></pre>



</details>

<a id="0x1_timelock_assert_is_executor"></a>

## Function `assert_is_executor`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_assert_is_executor">assert_is_executor</a>(executor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="timelock.md#0x1_timelock_assert_is_executor">assert_is_executor</a>(
    executor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>
) {
    <b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = &<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
    <b>let</b> executor_addr = address_of(executor);
    <b>let</b> authorized =
        <b>if</b> (<a href="timelock.md#0x1_timelock">timelock</a>.executors.is_empty()) {
            <a href="timelock.md#0x1_timelock">timelock</a>.creators.contains(&executor_addr)
        } <b>else</b> {
            <a href="timelock.md#0x1_timelock">timelock</a>.executors.contains(&executor_addr)
        };
    <b>assert</b>!(authorized, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="timelock.md#0x1_timelock_ENOT_EXECUTOR">ENOT_EXECUTOR</a>));
}
</code></pre>



</details>

<a id="0x1_timelock_assert_delay"></a>

## Function `assert_delay`



<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_assert_delay">assert_delay</a>(num_seconds_execute: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="timelock.md#0x1_timelock_assert_delay">assert_delay</a>(num_seconds_execute: u64) {
    <b>assert</b>!(
        num_seconds_execute &gt; <a href="timelock.md#0x1_timelock_MIN_NUM_SECONDS_EXECUTE">MIN_NUM_SECONDS_EXECUTE</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_ENUMBER_SECONDS_TOO_SMALL">ENUMBER_SECONDS_TOO_SMALL</a>)
    );
    <b>assert</b>!(
        num_seconds_execute &lt;= <a href="timelock.md#0x1_timelock_MAX_NUM_SECONDS_EXECUTE">MAX_NUM_SECONDS_EXECUTE</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="timelock.md#0x1_timelock_ENUMBER_SECONDS_TOO_LARGE">ENUMBER_SECONDS_TOO_LARGE</a>)
    );
}
</code></pre>



</details>

<a id="@Specification_3"></a>

## Specification




<a id="high-level-req"></a>

### High-level Requirements

<table>
<tr>
<th>No.</th><th>Requirement</th><th>Criticality</th><th>Implementation</th><th>Enforcement</th>
</tr>

<tr>
<td>1</td>
<td>A timelock account must always have at least one creator.</td>
<td>Critical</td>
<td>The create_timelock_account_internal function asserts that the creators vector has length >= 1 before publishing the TimelockAccount resource. The remove_creators function asserts that at least one creator remains after removal.</td>
<td>Audited that it aborts if creators is empty (create_timelock_account_internal). Audited that it aborts if the last creator would be removed (remove_creators).</td>
</tr>

<tr>
<td>2</td>
<td>Creator and executor lists must not contain duplicate addresses, and the timelock account address itself cannot appear in either list.</td>
<td>Critical</td>
<td>The validate_members function iterates through the member list and aborts on any duplicate or self-reference. It is called for both creators and executors during account creation and member updates.</td>
<td>Audited that duplicate detection aborts correctly (validate_members, add_creators, add_executors). Audited that self-reference is rejected (validate_members).</td>
</tr>

<tr>
<td>3</td>
<td>A transaction can only be resolved after the timelock period has fully elapsed. Specifically, block time must satisfy: now_seconds >= creation_time_secs + num_seconds_execute.</td>
<td>Critical</td>
<td>The resolve function asserts this time condition before authorizing execution.</td>
<td>Audited that it aborts if the timelock period has not elapsed (resolve).</td>
</tr>

<tr>
<td>4</td>
<td>Each transaction proposal is uniquely identified by keccak256(execution_hash || salt). Submitting a proposal whose computed key already exists is rejected. To submit the same script again, a new salt must be used.</td>
<td>High</td>
<td>The create_transaction function computes the table key and asserts that the key does not already exist as a key in the transactions table before adding the new entry.</td>
<td>Audited that it aborts if the computed transaction hash already exists (create_transaction).</td>
</tr>

<tr>
<td>5</td>
<td>When the executor list is empty, creators are authorized to execute transactions.</td>
<td>High</td>
<td>The assert_is_executor inline function checks the executors vector and falls back to checking the creators vector when executors is empty. The is_executor view function applies the same logic.</td>
<td>Audited that creators can execute when executors is empty (assert_is_executor, is_executor).</td>
</tr>

<tr>
<td>6</td>
<td>Any creator or any executor can cancel any pending transaction at any time, before the transaction has been executed or canceled.</td>
<td>High</td>
<td>The cancel_transaction function checks that the caller is either a creator or an executor (applying the empty-executors fallback), then asserts that the transaction has not yet been executed, and sets executed = true.</td>
<td>Audited that it aborts if the caller has no cancellation rights (cancel_transaction). Audited that it aborts if the transaction is already executed or canceled (cancel_transaction).</td>
</tr>

<tr>
<td>7</td>
<td>Once a transaction's executed field is set to true (either by execution or cancellation), neither further execution nor further cancellation is permitted. The transaction entry is kept in the table permanently.</td>
<td>High</td>
<td>Both resolve and cancel_transaction assert !transaction.executed before proceeding. resolve sets executed = true; if the surrounding script aborts, this state change reverts atomically.</td>
<td>Audited that it aborts if executed is already true (resolve, cancel_transaction). Audited that entries remain in the table after execution (resolve).</td>
</tr>

<tr>
<td>8</td>
<td>Changes to num_seconds_execute, the creator list, and the executor list can only be made by the timelock account itself, enforced by requiring the timelock account signer on the self-governance entry functions.</td>
<td>Critical</td>
<td>The self-governance functions (update_min_num_seconds_execute, add_creators, remove_creators, add_executors, remove_executors) all take timelock_account: &signer as first argument. The signer is produced only by <code>resolve</code>, which derives it from the stored signer_cap after verifying the running script.</td>
<td>Audited that the signer must be the timelock account address for self-governance functions.</td>
</tr>

<tr>
<td>9</td>
<td>Creating a timelock account properly initializes all resources and publishes the TimelockAccount resource under the resource account address derived from the deployer's address and sequence number. The deployer authorizes resource-account creation but does not gain creator or executor status; membership is determined entirely by the <code>creators</code> and <code>executors</code> arguments passed to <code>create</code>.</td>
<td>Medium</td>
<td>The create function derives the resource account address, creates the account via account::create_resource_account, and calls create_timelock_account_internal which publishes the TimelockAccount resource with all fields initialized from the supplied creators and executors lists.</td>
<td>Audited that TimelockAccount is initialized and published (create, create_timelock_account_internal).</td>
</tr>

<tr>
<td>10</td>
<td>Only valid creators are allowed to propose transactions. Proposing a transaction stores the execution_hash, salt, the proposer, and the proposal timestamp, with executed = false.</td>
<td>Critical</td>
<td>The create_transaction function validates that the caller is in the creators list before adding the new TimelockTransaction to the table.</td>
<td>Audited that it aborts if the caller is not a creator (create_transaction, assert_is_creator). Audited that the transaction is stored correctly with executed = false (create_transaction).</td>
</tr>

<tr>
<td>11</td>
<td>Only authorized executors (or creators when executors is empty) are allowed to resolve transactions. The running script's hash must equal the proposed execution_hash.</td>
<td>Critical</td>
<td>The resolve function checks executor authorization, transaction existence, executed status, timelock expiry, and equality between transaction_context::get_script_hash() and the stored execution_hash.</td>
<td>Audited that it aborts if the caller is not an executor (resolve, assert_is_executor). Audited that it aborts if the script hash mismatches (resolve).</td>
</tr>

</table>



<a id="module-level-spec"></a>

### Module-level Specification


<a id="@Specification_3_creators"></a>

### Function `creators`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_creators">creators</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>ensures</b> result == <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].creators;
</code></pre>



<a id="@Specification_3_executors"></a>

### Function `executors`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_executors">executors</a>(timelock_account: <b>address</b>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>ensures</b> result == <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].executors;
</code></pre>



<a id="@Specification_3_min_num_seconds_execute"></a>

### Function `min_num_seconds_execute`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_min_num_seconds_execute">min_num_seconds_execute</a>(timelock_account: <b>address</b>): u64
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>ensures</b> result == <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].min_num_seconds_execute;
</code></pre>



<a id="@Specification_3_is_creator"></a>

### Function `is_creator`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_creator">is_creator</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>ensures</b> result == contains(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].creators, addr);
</code></pre>



<a id="@Specification_3_is_executor"></a>

### Function `is_executor`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_is_executor">is_executor</a>(addr: <b>address</b>, timelock_account: <b>address</b>): bool
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>ensures</b> len(<a href="timelock.md#0x1_timelock">timelock</a>.executors) == 0 ==&gt; result == contains(<a href="timelock.md#0x1_timelock">timelock</a>.creators, addr);
<b>ensures</b> len(<a href="timelock.md#0x1_timelock">timelock</a>.executors) &gt; 0 ==&gt; result == contains(<a href="timelock.md#0x1_timelock">timelock</a>.executors, addr);
</code></pre>



<a id="@Specification_3_get_transaction"></a>

### Function `get_transaction`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction">get_transaction</a>(timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="timelock.md#0x1_timelock_TimelockTransaction">timelock::TimelockTransaction</a>
</code></pre>




<pre><code><b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash);
<b>ensures</b> result == <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash);
</code></pre>



<a id="@Specification_3_can_be_executed"></a>

### Function `can_be_executed`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_can_be_executed">can_be_executed</a>(timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>ensures</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash) ==&gt; !result;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash) ==&gt; result ==
    (!<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).executed
        && aptos_framework::timestamp::now_seconds()
            &gt;= <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).creation_time_secs
                + <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).num_seconds_execute);
</code></pre>



<a id="@Specification_3_get_next_timelock_account_address"></a>

### Function `get_next_timelock_account_address`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_next_timelock_account_address">get_next_timelock_account_address</a>(deployer: <b>address</b>): <b>address</b>
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
</code></pre>



<a id="@Specification_3_get_transaction_hash"></a>

### Function `get_transaction_hash`


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_get_transaction_hash">get_transaction_hash</a>(execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code><b>ensures</b> result == aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt));
</code></pre>



<a id="@Specification_3_create"></a>

### Function `create`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create">create</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, num_seconds_execute: u64)
</code></pre>




<pre><code><b>pragma</b> verify = <b>false</b>;
<b>aborts_if</b> num_seconds_execute &lt;= 360;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="account.md#0x1_account_Account">account::Account</a>&gt;(address_of(deployer));
</code></pre>



<a id="@Specification_3_create_timelock_account_internal"></a>

### Function `create_timelock_account_internal`


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_internal">create_timelock_account_internal</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, min_num_seconds_execute: u64, signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>




<pre><code><b>aborts_if</b> len(creators) &lt; 1;
<b>aborts_if</b> <a href="timelock.md#0x1_timelock_min_num_seconds_execute">min_num_seconds_execute</a> &lt;= 360;
<b>aborts_if</b> min_num_seconds_execute &gt; 604800;
<b>aborts_if</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(address_of(timelock_account));
<b>aborts_if</b> <b>exists</b> i in 0..len(creators): creators[i] == address_of(timelock_account);
<b>aborts_if</b> <b>exists</b> i in 0..len(creators): <b>exists</b> j in 0..i: creators[i] == creators[j];
<b>aborts_if</b> <b>exists</b> i in 0..len(executors): executors[i] == address_of(timelock_account);
<b>aborts_if</b> <b>exists</b> i in 0..len(executors): <b>exists</b> j in 0..i: executors[i] == executors[j];
<b>ensures</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(address_of(timelock_account));
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[address_of(timelock_account)].min_num_seconds_execute == min_num_seconds_execute;
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[address_of(timelock_account)].creators == creators;
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[address_of(timelock_account)].executors == executors;
</code></pre>



<a id="@Specification_3_add_creators"></a>

### Function `add_creators`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_creators">add_creators</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_creators: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> addr = address_of(timelock_account);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>aborts_if</b> <b>exists</b> i in 0..len(new_creators): new_creators[i] == addr;
<b>aborts_if</b> <b>exists</b> i in 0..len(new_creators): <b>exists</b> j in 0..i: new_creators[i] == new_creators[j];
<b>ensures</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators
    == concat(<b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators), new_creators);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].min_num_seconds_execute
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].min_num_seconds_execute);
</code></pre>



<a id="@Specification_3_remove_creators"></a>

### Function `remove_creators`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_creators">remove_creators</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, creators_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> addr = address_of(timelock_account);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>ensures</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>ensures</b> len(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators) &gt;= 1;
</code></pre>



<a id="@Specification_3_add_executors"></a>

### Function `add_executors`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_add_executors">add_executors</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_executors: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> addr = address_of(timelock_account);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>aborts_if</b> <b>exists</b> i in 0..len(new_executors): new_executors[i] == addr;
<b>aborts_if</b> <b>exists</b> i in 0..len(new_executors): <b>exists</b> j in 0..i: new_executors[i] == new_executors[j];
<b>ensures</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors
    == concat(<b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors), new_executors);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].min_num_seconds_execute
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].min_num_seconds_execute);
<b>ensures</b> <b>forall</b> i in 0..len(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors):
    <b>forall</b> j in i+1..len(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors): <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors[i] != <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors[j];
</code></pre>



<a id="@Specification_3_remove_executors"></a>

### Function `remove_executors`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_remove_executors">remove_executors</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, executors_to_remove: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>




<pre><code><b>let</b> addr = address_of(timelock_account);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>ensures</b> <b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
</code></pre>



<a id="@Specification_3_update_min_num_seconds_execute"></a>

### Function `update_min_num_seconds_execute`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_update_min_num_seconds_execute">update_min_num_seconds_execute</a>(timelock_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_min_num_seconds_execute: u64)
</code></pre>




<pre><code><b>let</b> addr = address_of(timelock_account);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(addr);
<b>aborts_if</b> new_min_num_seconds_execute &lt;= 360;
<b>aborts_if</b> new_min_num_seconds_execute &gt; 604800;
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].min_num_seconds_execute == new_min_num_seconds_execute;
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].creators);
<b>ensures</b> <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors
    == <b>old</b>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[addr].executors);
</code></pre>



<a id="@Specification_3_create_transaction"></a>

### Function `create_transaction`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_create_transaction">create_transaction</a>(creator: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, execution_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, num_seconds_execute: u64, salt: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial;
<b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>aborts_if</b> !contains(<a href="timelock.md#0x1_timelock">timelock</a>.creators, address_of(creator));
<b>aborts_if</b> len(execution_hash) != 32;
<b>aborts_if</b> len(salt) != 32;
<b>aborts_if</b> num_seconds_execute &lt; <a href="timelock.md#0x1_timelock">timelock</a>.min_num_seconds_execute;
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
).creator == address_of(creator);
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
).execution_hash == execution_hash;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
).salt == salt;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
).num_seconds_execute == num_seconds_execute;
<b>ensures</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(
    <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions,
    aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
).executed;
</code></pre>



<a id="@Specification_3_cancel_transaction"></a>

### Function `cancel_transaction`


<pre><code><b>public</b> entry <b>fun</b> <a href="timelock.md#0x1_timelock_cancel_transaction">cancel_transaction</a>(actor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>aborts_if</b> len(transaction_hash) != 32;
<b>aborts_if</b> !contains(<a href="timelock.md#0x1_timelock">timelock</a>.creators, address_of(actor))
    && (len(<a href="timelock.md#0x1_timelock">timelock</a>.executors) == 0 || !contains(<a href="timelock.md#0x1_timelock">timelock</a>.executors, address_of(actor)));
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash);
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).executed;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions, transaction_hash).executed;
</code></pre>



<a id="@Specification_3_resolve"></a>

### Function `resolve`


<pre><code><b>public</b> <b>fun</b> <a href="timelock.md#0x1_timelock_resolve">resolve</a>(executor: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, timelock_account: <b>address</b>, transaction_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>




<pre><code><b>pragma</b> verify = <b>false</b>;
<b>let</b> <a href="timelock.md#0x1_timelock">timelock</a> = <a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account];
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>&gt;(timelock_account);
<b>aborts_if</b> len(transaction_hash) != 32;
<b>aborts_if</b> {
    <b>let</b> execs = <a href="timelock.md#0x1_timelock">timelock</a>.executors;
    <b>let</b> creators = <a href="timelock.md#0x1_timelock">timelock</a>.creators;
    <b>if</b> (len(execs) == 0) {
        !contains(creators, address_of(executor))
    } <b>else</b> {
        !contains(execs, address_of(executor))
    }
};
<b>aborts_if</b> !<a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash);
<b>aborts_if</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).executed;
<b>aborts_if</b> aptos_framework::timestamp::now_seconds() &lt; <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).creation_time_secs
    + <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock">timelock</a>.transactions, transaction_hash).num_seconds_execute;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_get">table::spec_get</a>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions, transaction_hash).executed;
<b>ensures</b> <a href="../../aptos-stdlib/doc/table.md#0x1_table_spec_contains">table::spec_contains</a>(<a href="timelock.md#0x1_timelock_TimelockAccount">TimelockAccount</a>[timelock_account].transactions, transaction_hash);
</code></pre>



<a id="@Specification_3_create_timelock_account"></a>

### Function `create_timelock_account`


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account">create_timelock_account</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a>)
</code></pre>




<pre><code><b>pragma</b> verify = <b>false</b>;
<b>aborts_if</b> !<b>exists</b>&lt;<a href="account.md#0x1_account_Account">account::Account</a>&gt;(address_of(deployer));
</code></pre>



<a id="@Specification_3_create_timelock_account_seed"></a>

### Function `create_timelock_account_seed`


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_create_timelock_account_seed">create_timelock_account_seed</a>(seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
</code></pre>



<a id="@Specification_3_validate_members"></a>

### Function `validate_members`


<pre><code><b>fun</b> <a href="timelock.md#0x1_timelock_validate_members">validate_members</a>(members: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, timelock_address: <b>address</b>, duplicate_error: u64)
</code></pre>




<pre><code><b>aborts_if</b> <b>exists</b> i in 0..len(members): members[i] == timelock_address;
<b>aborts_if</b> <b>exists</b> i in 0..len(members):
    <b>exists</b> j in 0..i: members[i] == members[j];
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
