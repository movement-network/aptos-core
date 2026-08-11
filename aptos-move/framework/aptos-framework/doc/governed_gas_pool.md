
<a id="0x1_governed_gas_pool"></a>

# Module `0x1::governed_gas_pool`



-  [Struct `WithdrawStakingRewardEvent`](#0x1_governed_gas_pool_WithdrawStakingRewardEvent)
-  [Resource `GovernedGasPool`](#0x1_governed_gas_pool_GovernedGasPool)
-  [Resource `GovernedGasPoolExtension`](#0x1_governed_gas_pool_GovernedGasPoolExtension)
-  [Struct `AcceptedGasFa`](#0x1_governed_gas_pool_AcceptedGasFa)
-  [Resource `AcceptedGasFungibleAssets`](#0x1_governed_gas_pool_AcceptedGasFungibleAssets)
-  [Struct `AcceptedGasFungibleAssetUpdate`](#0x1_governed_gas_pool_AcceptedGasFungibleAssetUpdate)
-  [Struct `GasFungibleAssetPriceUpdate`](#0x1_governed_gas_pool_GasFungibleAssetPriceUpdate)
-  [Struct `FungibleAssetGasFeeDeposit`](#0x1_governed_gas_pool_FungibleAssetGasFeeDeposit)
-  [Constants](#@Constants_0)
-  [Function `primary_fungible_store_address_for`](#0x1_governed_gas_pool_primary_fungible_store_address_for)
-  [Function `create_resource_account_seed`](#0x1_governed_gas_pool_create_resource_account_seed)
-  [Function `initialize`](#0x1_governed_gas_pool_initialize)
-  [Function `initialize_governed_gas_pool_extension`](#0x1_governed_gas_pool_initialize_governed_gas_pool_extension)
-  [Function `init_module`](#0x1_governed_gas_pool_init_module)
-  [Function `governed_gas_signer`](#0x1_governed_gas_pool_governed_gas_signer)
-  [Function `governed_gas_pool_address`](#0x1_governed_gas_pool_governed_gas_pool_address)
-  [Function `get_treasury_deposited`](#0x1_governed_gas_pool_get_treasury_deposited)
-  [Function `fund`](#0x1_governed_gas_pool_fund)
-  [Function `deposit`](#0x1_governed_gas_pool_deposit)
-  [Function `deposit_from`](#0x1_governed_gas_pool_deposit_from)
-  [Function `deposit_from_fungible_store`](#0x1_governed_gas_pool_deposit_from_fungible_store)
-  [Function `deposit_from_fungible_store_for`](#0x1_governed_gas_pool_deposit_from_fungible_store_for)
-  [Function `deposit_gas_fee`](#0x1_governed_gas_pool_deposit_gas_fee)
-  [Function `deposit_gas_fee_v2`](#0x1_governed_gas_pool_deposit_gas_fee_v2)
-  [Function `ensure_accepted_registry`](#0x1_governed_gas_pool_ensure_accepted_registry)
-  [Function `find_accepted_index`](#0x1_governed_gas_pool_find_accepted_index)
-  [Function `add_accepted_gas_fungible_asset`](#0x1_governed_gas_pool_add_accepted_gas_fungible_asset)
-  [Function `set_gas_fungible_asset_price`](#0x1_governed_gas_pool_set_gas_fungible_asset_price)
-  [Function `remove_accepted_gas_fungible_asset`](#0x1_governed_gas_pool_remove_accepted_gas_fungible_asset)
-  [Function `is_accepted_gas_fungible_asset`](#0x1_governed_gas_pool_is_accepted_gas_fungible_asset)
-  [Function `accepted_gas_fungible_assets`](#0x1_governed_gas_pool_accepted_gas_fungible_assets)
-  [Function `get_gas_fungible_asset_price`](#0x1_governed_gas_pool_get_gas_fungible_asset_price)
-  [Function `gas_fee_in_fa`](#0x1_governed_gas_pool_gas_fee_in_fa)
-  [Function `get_fa_balance`](#0x1_governed_gas_pool_get_fa_balance)
-  [Function `deposit_gas_fee_fa`](#0x1_governed_gas_pool_deposit_gas_fee_fa)
-  [Function `fund_fa`](#0x1_governed_gas_pool_fund_fa)
-  [Function `deposit_treasury`](#0x1_governed_gas_pool_deposit_treasury)
-  [Function `get_balance`](#0x1_governed_gas_pool_get_balance)
-  [Function `withdraw_staking_reward`](#0x1_governed_gas_pool_withdraw_staking_reward)
-  [Function `register_coin`](#0x1_governed_gas_pool_register_coin)
-  [Specification](#@Specification_1)
    -  [Function `initialize`](#@Specification_1_initialize)
    -  [Function `fund`](#@Specification_1_fund)
    -  [Function `deposit`](#@Specification_1_deposit)
    -  [Function `deposit_gas_fee`](#@Specification_1_deposit_gas_fee)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="aptos_account.md#0x1_aptos_account">0x1::aptos_account</a>;
<b>use</b> <a href="aptos_coin.md#0x1_aptos_coin">0x1::aptos_coin</a>;
<b>use</b> <a href="coin.md#0x1_coin">0x1::coin</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features">0x1::features</a>;
<b>use</b> <a href="fungible_asset.md#0x1_fungible_asset">0x1::fungible_asset</a>;
<b>use</b> <a href="object.md#0x1_object">0x1::object</a>;
<b>use</b> <a href="primary_fungible_store.md#0x1_primary_fungible_store">0x1::primary_fungible_store</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_governed_gas_pool_WithdrawStakingRewardEvent"></a>

## Struct `WithdrawStakingRewardEvent`

Event emitted when token are withdraw from the pool


<pre><code><b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">WithdrawStakingRewardEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>amount: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_GovernedGasPool"></a>

## Resource `GovernedGasPool`

The Governed Gas Pool
Internally, this is a simply wrapper around a resource account.


<pre><code><b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>signer_capability: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a></code>
</dt>
<dd>
 The signer capability of the resource account.
</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_GovernedGasPoolExtension"></a>

## Resource `GovernedGasPoolExtension`

Contains added variable needed for the GovernedGasPool staking reward update.


<pre><code><b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>deposited_treasury_counter: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>withdraw_staking_reward_events: <a href="event.md#0x1_event_EventHandle">event::EventHandle</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">governed_gas_pool::WithdrawStakingRewardEvent</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_AcceptedGasFa"></a>

## Struct `AcceptedGasFa`

A fungible asset accepted for gas payment, together with its gas price: the number of FA base
units charged per unit of gas consumed. The FA gas fee for a transaction is
<code>gas_units_used * gas_price</code>.


<pre><code><b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">AcceptedGasFa</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>metadata: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>gas_price: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_AcceptedGasFungibleAssets"></a>

## Resource `AcceptedGasFungibleAssets`

Registry of fungible assets accepted for gas payment. Each accepted FA is held in the
governed gas pool account's own primary store for that metadata object (a separate per-FA
pool that shares the single pool resource account), and stores its gas price alongside.


<pre><code><b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>entries: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">governed_gas_pool::AcceptedGasFa</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_AcceptedGasFungibleAssetUpdate"></a>

## Struct `AcceptedGasFungibleAssetUpdate`

Emitted when a fungible asset is added to (<code>accepted = <b>true</b></code>) or removed from
(<code>accepted = <b>false</b></code>) the set accepted for gas payment.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssetUpdate">AcceptedGasFungibleAssetUpdate</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>metadata: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>accepted: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_GasFungibleAssetPriceUpdate"></a>

## Struct `GasFungibleAssetPriceUpdate`

Emitted when a fungible asset's gas price is set or updated.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GasFungibleAssetPriceUpdate">GasFungibleAssetPriceUpdate</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>metadata: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>gas_price: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_governed_gas_pool_FungibleAssetGasFeeDeposit"></a>

## Struct `FungibleAssetGasFeeDeposit`

Emitted when gas fees are deposited into a per-FA governed gas pool.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_FungibleAssetGasFeeDeposit">FungibleAssetGasFeeDeposit</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>gas_payer: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>metadata: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>amount: u64</code>
</dt>
<dd>
 Fungible asset base units deposited.
</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_governed_gas_pool_MAX_U64"></a>

Maximum u64 value, used to guard fungible asset gas fee computation against overflow.


<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_MAX_U64">MAX_U64</a>: u128 = 18446744073709551615;
</code></pre>



<a id="0x1_governed_gas_pool_EFA_NOT_ACCEPTED"></a>

The fungible asset is not accepted for gas payment.


<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>: u64 = 5;
</code></pre>



<a id="0x1_governed_gas_pool_EGAS_FA_FEE_OVERFLOW"></a>

The computed fungible asset gas fee does not fit in a u64.


<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_EGAS_FA_FEE_OVERFLOW">EGAS_FA_FEE_OVERFLOW</a>: u64 = 7;
</code></pre>



<a id="0x1_governed_gas_pool_EINVALID_GAS_FA_PRICE"></a>

A gas fungible asset's gas price must be non-zero.


<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_EINVALID_GAS_FA_PRICE">EINVALID_GAS_FA_PRICE</a>: u64 = 6;
</code></pre>



<a id="0x1_governed_gas_pool_ENO_LONGER_SUPPORTED"></a>

No longer supported.


<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_ENO_LONGER_SUPPORTED">ENO_LONGER_SUPPORTED</a>: u64 = 4;
</code></pre>



<a id="0x1_governed_gas_pool_MODULE_SALT"></a>



<pre><code><b>const</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_MODULE_SALT">MODULE_SALT</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [97, 112, 116, 111, 115, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 103, 111, 118, 101, 114, 110, 101, 100, 95, 103, 97, 115, 95, 112, 111, 111, 108];
</code></pre>



<a id="0x1_governed_gas_pool_primary_fungible_store_address_for"></a>

## Function `primary_fungible_store_address_for`

Address of <code><a href="account.md#0x1_account">account</a></code>'s primary fungible store for the FA identified by <code>metadata</code>.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_primary_fungible_store_address_for">primary_fungible_store_address_for</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, metadata: <b>address</b>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_primary_fungible_store_address_for">primary_fungible_store_address_for</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, metadata: <b>address</b>): <b>address</b> {
    <a href="object.md#0x1_object_create_user_derived_object_address">object::create_user_derived_object_address</a>(<a href="account.md#0x1_account">account</a>, metadata)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_create_resource_account_seed"></a>

## Function `create_resource_account_seed`

Create the seed to derive the resource account address.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_create_resource_account_seed">create_resource_account_seed</a>(delegation_pool_creation_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_create_resource_account_seed">create_resource_account_seed</a>(
    delegation_pool_creation_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> seed = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;u8&gt;();
    // <b>include</b> <b>module</b> salt (before <a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a> subseeds) <b>to</b> avoid conflicts <b>with</b> other modules creating resource accounts
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> seed, <a href="governed_gas_pool.md#0x1_governed_gas_pool_MODULE_SALT">MODULE_SALT</a>);
    // <b>include</b> an additional salt in case the same resource <a href="account.md#0x1_account">account</a> <b>has</b> already been created
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> seed, delegation_pool_creation_seed);
    seed
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_initialize"></a>

## Function `initialize`

Initializes the governed gas pool around a resource account creation seed.
@param aptos_framework The signer of the aptos_framework module.
@param delegation_pool_creation_seed The seed to be used to create the resource account hosting the delegation pool.


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, delegation_pool_creation_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize">initialize</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    delegation_pool_creation_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    // <b>return</b> <b>if</b> the governed gas pool <b>has</b> already been initialized
    <b>if</b> (<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework))) {
        <b>if</b> (!<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework))) {
            <b>move_to</b>(aptos_framework, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>{
                deposited_treasury_counter: 0,
                withdraw_staking_reward_events: <a href="account.md#0x1_account_new_event_handle">account::new_event_handle</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">WithdrawStakingRewardEvent</a>&gt;(aptos_framework),
            });
        }
    } <b>else</b> {

        // generate a seed <b>to</b> be used <b>to</b> create the resource <a href="account.md#0x1_account">account</a> hosting the delegation pool
        <b>let</b> seed = <a href="governed_gas_pool.md#0x1_governed_gas_pool_create_resource_account_seed">create_resource_account_seed</a>(delegation_pool_creation_seed);

        <b>let</b> (governed_gas_pool_signer, governed_gas_pool_signer_cap) = <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(aptos_framework, seed);

        // register apt
        <a href="aptos_account.md#0x1_aptos_account_register_fa_and_apt">aptos_account::register_fa_and_apt</a>(&governed_gas_pool_signer);
        <b>move_to</b>(aptos_framework, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>{
            signer_capability: governed_gas_pool_signer_cap,
        });

        <b>move_to</b>(aptos_framework, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>{
            deposited_treasury_counter: 0,
            withdraw_staking_reward_events: <a href="account.md#0x1_account_new_event_handle">account::new_event_handle</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">WithdrawStakingRewardEvent</a>&gt;(aptos_framework),
        });
    }
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_initialize_governed_gas_pool_extension"></a>

## Function `initialize_governed_gas_pool_extension`

Initializes the governed gas pool extension alone.
@param aptos_framework The signer of the aptos_framework module.


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize_governed_gas_pool_extension">initialize_governed_gas_pool_extension</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize_governed_gas_pool_extension">initialize_governed_gas_pool_extension</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    // <b>return</b> <b>if</b> the governed gas extension <b>has</b> already been initialized
    <b>if</b> (<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework))) {
    } <b>else</b> {

    <b>move_to</b>(aptos_framework, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>{
        deposited_treasury_counter: 0,
        withdraw_staking_reward_events: <a href="account.md#0x1_account_new_event_handle">account::new_event_handle</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">WithdrawStakingRewardEvent</a>&gt;(aptos_framework),
    });
    }
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_init_module"></a>

## Function `init_module`

Initialize the governed gas pool as a module
@param aptos_framework The signer of the aptos_framework module.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_init_module">init_module</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_init_module">init_module</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    // Initialize the governed gas pool
    <b>let</b> seed : <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = b"aptos_framework::governed_gas_pool";
    <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize">initialize</a>(aptos_framework, seed);
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_governed_gas_signer"></a>

## Function `governed_gas_signer`

Borrows the signer of the governed gas pool.
@return The signer of the governed gas pool.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>let</b> signer_cap = &<b>borrow_global</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>&gt;(@aptos_framework).signer_capability;
    create_signer_with_capability(signer_cap)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_governed_gas_pool_address"></a>

## Function `governed_gas_pool_address`

Gets the address of the governed gas pool.
@return The address of the governed gas pool.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>(): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>(): <b>address</b> <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(&<a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>())
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_get_treasury_deposited"></a>

## Function `get_treasury_deposited`

Return the amount of treasury deposited.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_treasury_deposited">get_treasury_deposited</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_treasury_deposited">get_treasury_deposited</a>(): u64 <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a> {
    <b>borrow_global</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>&gt;(@aptos_framework).deposited_treasury_counter
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_fund"></a>

## Function `fund`

Funds the destination account with a given amount of coin.
@param account The account to be funded.
@param amount The amount of coin to be funded.


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_fund">fund</a>&lt;CoinType&gt;(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_fund">fund</a>&lt;CoinType&gt;(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    // Check that the Aptos framework is the caller
    // This is what <b>ensures</b> that funding can only be done by the Aptos framework,
    // i.e., via a governance proposal.
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>let</b> governed_gas_signer = &<a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>();
    <a href="coin.md#0x1_coin_deposit">coin::deposit</a>(<a href="account.md#0x1_account">account</a>, <a href="coin.md#0x1_coin_withdraw">coin::withdraw</a>&lt;CoinType&gt;(governed_gas_signer, amount));
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit"></a>

## Function `deposit`

Deposits some coin into the governed gas pool.
@param coin The coin to be deposited.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit">deposit</a>&lt;CoinType&gt;(<a href="coin.md#0x1_coin">coin</a>: <a href="coin.md#0x1_coin_Coin">coin::Coin</a>&lt;CoinType&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit">deposit</a>&lt;CoinType&gt;(<a href="coin.md#0x1_coin">coin</a>: Coin&lt;CoinType&gt;) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>let</b> governed_gas_pool_address = <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>();
    <a href="coin.md#0x1_coin_deposit">coin::deposit</a>(governed_gas_pool_address, <a href="coin.md#0x1_coin">coin</a>);
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_from"></a>

## Function `deposit_from`

Deposits some coin from an account to the governed gas pool.
@param account The account from which the coin is to be deposited.
@param amount The amount of coin to be deposited.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from">deposit_from</a>&lt;CoinType&gt;(<a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from">deposit_from</a>&lt;CoinType&gt;(<a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
   <b>let</b> asset = <a href="coin.md#0x1_coin_withdraw_from">coin::withdraw_from</a>&lt;CoinType&gt;(<a href="account.md#0x1_account">account</a>, amount);
   <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit">deposit</a>(asset);
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_from_fungible_store"></a>

## Function `deposit_from_fungible_store`

Deposits APT from the fungible store into the governed gas pool.
@param account The account from which the APT FA is to be deposited.
@param amount The amount of APT FA to be deposited.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store">deposit_from_fungible_store</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store">deposit_from_fungible_store</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store_for">deposit_from_fungible_store_for</a>(<a href="account.md#0x1_account">account</a>, @aptos_fungible_asset, amount);
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_from_fungible_store_for"></a>

## Function `deposit_from_fungible_store_for`

Deposits <code>amount</code> of the fungible asset identified by <code>metadata</code> from <code><a href="account.md#0x1_account">account</a></code>'s primary
store into the governed gas pool account's own primary store for that FA (its per-FA pool).
Uses the unchecked (VM-privileged) withdraw/deposit path, as gas collection is not authorized
by the payer's signer.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store_for">deposit_from_fungible_store_for</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, metadata: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store_for">deposit_from_fungible_store_for</a>(<a href="account.md#0x1_account">account</a>: <b>address</b>, metadata: <b>address</b>, amount: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>if</b> (amount &gt; 0) {
        <b>let</b> pool_store_address =
            <a href="governed_gas_pool.md#0x1_governed_gas_pool_primary_fungible_store_address_for">primary_fungible_store_address_for</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>(), metadata);
        <b>let</b> account_store_address = <a href="governed_gas_pool.md#0x1_governed_gas_pool_primary_fungible_store_address_for">primary_fungible_store_address_for</a>(<a href="account.md#0x1_account">account</a>, metadata);
        <a href="fungible_asset.md#0x1_fungible_asset_unchecked_deposit">fungible_asset::unchecked_deposit</a>(
            pool_store_address,
            <a href="fungible_asset.md#0x1_fungible_asset_unchecked_withdraw">fungible_asset::unchecked_withdraw</a>(account_store_address, amount)
        );
    }
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_gas_fee"></a>

## Function `deposit_gas_fee`

Deposits gas fees into the governed gas pool.
@param gas_payer The address of the account that paid the gas fees.
@param gas_fee The amount of gas fees to be deposited.


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee">deposit_gas_fee</a>(_gas_payer: <b>address</b>, _gas_fee: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee">deposit_gas_fee</a>(_gas_payer: <b>address</b>, _gas_fee: u64) {
     <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_implemented">error::not_implemented</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_ENO_LONGER_SUPPORTED">ENO_LONGER_SUPPORTED</a>)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_gas_fee_v2"></a>

## Function `deposit_gas_fee_v2`

Deposits gas fees into the governed gas pool.
@param gas_payer The address of the account that paid the gas fees.
@param gas_fee The amount of gas fees to be deposited.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee_v2">deposit_gas_fee_v2</a>(gas_payer: <b>address</b>, gas_fee: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee_v2">deposit_gas_fee_v2</a>(gas_payer: <b>address</b>, gas_fee: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_operations_default_to_fa_apt_store_enabled">features::operations_default_to_fa_apt_store_enabled</a>()) {
        <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store">deposit_from_fungible_store</a>(gas_payer, gas_fee);
    } <b>else</b> {
        <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from">deposit_from</a>&lt;AptosCoin&gt;(gas_payer, gas_fee);
    };
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_ensure_accepted_registry"></a>

## Function `ensure_accepted_registry`

Creates the accepted-FA registry under @aptos_framework if it does not yet exist. This lets
the feature roll out onto an already-initialized governed gas pool without re-running
<code>initialize</code>.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_ensure_accepted_registry">ensure_accepted_registry</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_ensure_accepted_registry">ensure_accepted_registry</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>if</b> (!<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework))) {
        <b>move_to</b>(aptos_framework, <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> { entries: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">AcceptedGasFa</a>&gt;() });
    };
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_find_accepted_index"></a>

## Function `find_accepted_index`

Index of the accepted-FA entry for <code>metadata</code>, if present.


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(entries: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">governed_gas_pool::AcceptedGasFa</a>&gt;, metadata: <b>address</b>): (bool, u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(entries: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">AcceptedGasFa</a>&gt;, metadata: <b>address</b>): (bool, u64) {
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(entries);
    <b>let</b> i = 0;
    <b>while</b> (i &lt; len) {
        <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(entries, i).metadata == metadata) {
            <b>return</b> (<b>true</b>, i)
        };
        i = i + 1;
    };
    (<b>false</b>, 0)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_add_accepted_gas_fungible_asset"></a>

## Function `add_accepted_gas_fungible_asset`

Adds a fungible asset to the set accepted for gas payment with its gas price (FA base units
charged per unit of gas consumed), and ensures the pool has a primary store to hold it.
Governance-gated (requires the @aptos_framework signer). Re-adding an existing FA updates its
gas price.
@param aptos_framework The signer of the aptos_framework module.
@param metadata The metadata object of the fungible asset to accept.
@param gas_price FA base units charged per unit of gas consumed; must be non-zero.


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_add_accepted_gas_fungible_asset">add_accepted_gas_fungible_asset</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, gas_price: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_add_accepted_gas_fungible_asset">add_accepted_gas_fungible_asset</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    metadata: Object&lt;Metadata&gt;,
    gas_price: u64,
) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>, <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>assert</b>!(gas_price &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EINVALID_GAS_FA_PRICE">EINVALID_GAS_FA_PRICE</a>));
    <a href="governed_gas_pool.md#0x1_governed_gas_pool_ensure_accepted_registry">ensure_accepted_registry</a>(aptos_framework);
    <b>let</b> metadata_address = <a href="object.md#0x1_object_object_address">object::object_address</a>(&metadata);
    <b>let</b> accepted = <b>borrow_global_mut</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework);
    <b>let</b> (found, i) = <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(&accepted.entries, metadata_address);
    <b>if</b> (found) {
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow_mut">vector::borrow_mut</a>(&<b>mut</b> accepted.entries, i).gas_price = gas_price;
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> accepted.entries, <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFa">AcceptedGasFa</a> { metadata: metadata_address, gas_price });
        // Ensure the pool <b>has</b> a primary store for this FA so unchecked deposits succeed.
        <a href="primary_fungible_store.md#0x1_primary_fungible_store_ensure_primary_store_exists">primary_fungible_store::ensure_primary_store_exists</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>(), metadata);
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssetUpdate">AcceptedGasFungibleAssetUpdate</a> { metadata: metadata_address, accepted: <b>true</b> });
    };
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_GasFungibleAssetPriceUpdate">GasFungibleAssetPriceUpdate</a> { metadata: metadata_address, gas_price });
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_set_gas_fungible_asset_price"></a>

## Function `set_gas_fungible_asset_price`

Sets (updates) the gas price of an already-accepted fungible asset. Governance-gated.
@param aptos_framework The signer of the aptos_framework module.
@param metadata The metadata object of the fungible asset.
@param gas_price FA base units charged per unit of gas consumed; must be non-zero.


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_set_gas_fungible_asset_price">set_gas_fungible_asset_price</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, gas_price: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_set_gas_fungible_asset_price">set_gas_fungible_asset_price</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    metadata: Object&lt;Metadata&gt;,
    gas_price: u64,
) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>assert</b>!(gas_price &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EINVALID_GAS_FA_PRICE">EINVALID_GAS_FA_PRICE</a>));
    <b>assert</b>!(<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>));
    <b>let</b> metadata_address = <a href="object.md#0x1_object_object_address">object::object_address</a>(&metadata);
    <b>let</b> accepted = <b>borrow_global_mut</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework);
    <b>let</b> (found, i) = <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(&accepted.entries, metadata_address);
    <b>assert</b>!(found, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>));
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow_mut">vector::borrow_mut</a>(&<b>mut</b> accepted.entries, i).gas_price = gas_price;
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_GasFungibleAssetPriceUpdate">GasFungibleAssetPriceUpdate</a> { metadata: metadata_address, gas_price });
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_remove_accepted_gas_fungible_asset"></a>

## Function `remove_accepted_gas_fungible_asset`

Removes a fungible asset from the set accepted for gas payment. Any balance already held in
its pool remains and can still be withdrawn via <code>fund_fa</code>. Governance-gated.
@param aptos_framework The signer of the aptos_framework module.
@param metadata The metadata object of the fungible asset to stop accepting.


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_remove_accepted_gas_fungible_asset">remove_accepted_gas_fungible_asset</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, metadata: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_remove_accepted_gas_fungible_asset">remove_accepted_gas_fungible_asset</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    metadata: Object&lt;Metadata&gt;,
) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework)) {
        <b>return</b>
    };
    <b>let</b> metadata_address = <a href="object.md#0x1_object_object_address">object::object_address</a>(&metadata);
    <b>let</b> accepted = <b>borrow_global_mut</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework);
    <b>let</b> (found, i) = <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(&accepted.entries, metadata_address);
    <b>if</b> (found) {
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_remove">vector::remove</a>(&<b>mut</b> accepted.entries, i);
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssetUpdate">AcceptedGasFungibleAssetUpdate</a> { metadata: metadata_address, accepted: <b>false</b> });
    };
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_is_accepted_gas_fungible_asset"></a>

## Function `is_accepted_gas_fungible_asset`

Whether the fungible asset identified by <code>metadata</code> is accepted for gas payment.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_is_accepted_gas_fungible_asset">is_accepted_gas_fungible_asset</a>(metadata: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_is_accepted_gas_fungible_asset">is_accepted_gas_fungible_asset</a>(metadata: <b>address</b>): bool <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework)) {
        <b>return</b> <b>false</b>
    };
    <b>let</b> (found, _) = <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(&<b>borrow_global</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework).entries, metadata);
    found
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_accepted_gas_fungible_assets"></a>

## Function `accepted_gas_fungible_assets`

The full set of fungible asset metadata addresses accepted for gas payment.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_accepted_gas_fungible_assets">accepted_gas_fungible_assets</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_accepted_gas_fungible_assets">accepted_gas_fungible_assets</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt; <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <b>let</b> result = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;<b>address</b>&gt;();
    <b>if</b> (<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework)) {
        <b>let</b> entries = &<b>borrow_global</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework).entries;
        <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(entries);
        <b>let</b> i = 0;
        <b>while</b> (i &lt; len) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> result, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(entries, i).metadata);
            i = i + 1;
        };
    };
    result
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_get_gas_fungible_asset_price"></a>

## Function `get_gas_fungible_asset_price`

The gas price (FA base units per unit of gas) of an accepted fungible asset. Aborts if the
fungible asset is not accepted for gas payment.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_gas_fungible_asset_price">get_gas_fungible_asset_price</a>(metadata: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_gas_fungible_asset_price">get_gas_fungible_asset_price</a>(metadata: <b>address</b>): u64 <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>));
    <b>let</b> accepted = <b>borrow_global</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a>&gt;(@aptos_framework);
    <b>let</b> (found, i) = <a href="governed_gas_pool.md#0x1_governed_gas_pool_find_accepted_index">find_accepted_index</a>(&accepted.entries, metadata);
    <b>assert</b>!(found, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>));
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&accepted.entries, i).gas_price
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_gas_fee_in_fa"></a>

## Function `gas_fee_in_fa`

The fungible asset gas fee for <code>gas_units</code> of gas consumed under <code>metadata</code>'s gas price, i.e.
<code>gas_units * gas_price</code>. Aborts if the FA is not accepted or the fee overflows u64.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_gas_fee_in_fa">gas_fee_in_fa</a>(metadata: <b>address</b>, gas_units: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_gas_fee_in_fa">gas_fee_in_fa</a>(metadata: <b>address</b>, gas_units: u64): u64 <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <b>let</b> price = <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_gas_fungible_asset_price">get_gas_fungible_asset_price</a>(metadata);
    <b>let</b> fee = (gas_units <b>as</b> u128) * (price <b>as</b> u128);
    <b>assert</b>!(fee &lt;= <a href="governed_gas_pool.md#0x1_governed_gas_pool_MAX_U64">MAX_U64</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_out_of_range">error::out_of_range</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EGAS_FA_FEE_OVERFLOW">EGAS_FA_FEE_OVERFLOW</a>));
    (fee <b>as</b> u64)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_get_fa_balance"></a>

## Function `get_fa_balance`

The governed gas pool's balance of the fungible asset identified by <code>metadata</code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_fa_balance">get_fa_balance</a>(metadata: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_fa_balance">get_fa_balance</a>(metadata: <b>address</b>): u64 <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <a href="primary_fungible_store.md#0x1_primary_fungible_store_balance">primary_fungible_store::balance</a>(
        <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>(),
        <a href="object.md#0x1_object_address_to_object">object::address_to_object</a>&lt;Metadata&gt;(metadata)
    )
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_gas_fee_fa"></a>

## Function `deposit_gas_fee_fa`

Deposits <code>fa_amount</code> base units of a selected gas fungible asset (already converted from gas
via that FA's gas price) into its governed gas pool. Aborts if the FA is not accepted.
@param gas_payer The address that paid the gas fees.
@param metadata The metadata object address of the fungible asset.
@param fa_amount The fungible asset base units to deposit.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee_fa">deposit_gas_fee_fa</a>(gas_payer: <b>address</b>, metadata: <b>address</b>, fa_amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee_fa">deposit_gas_fee_fa</a>(
    gas_payer: <b>address</b>,
    metadata: <b>address</b>,
    fa_amount: u64,
) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>, <a href="governed_gas_pool.md#0x1_governed_gas_pool_AcceptedGasFungibleAssets">AcceptedGasFungibleAssets</a> {
    <b>assert</b>!(<a href="governed_gas_pool.md#0x1_governed_gas_pool_is_accepted_gas_fungible_asset">is_accepted_gas_fungible_asset</a>(metadata), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_EFA_NOT_ACCEPTED">EFA_NOT_ACCEPTED</a>));
    <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from_fungible_store_for">deposit_from_fungible_store_for</a>(gas_payer, metadata, fa_amount);
    <b>if</b> (fa_amount &gt; 0) {
        <a href="event.md#0x1_event_emit">event::emit</a>(<a href="governed_gas_pool.md#0x1_governed_gas_pool_FungibleAssetGasFeeDeposit">FungibleAssetGasFeeDeposit</a> { gas_payer, metadata, amount: fa_amount });
    };
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_fund_fa"></a>

## Function `fund_fa`

Withdraws <code>amount</code> of the fungible asset identified by <code>metadata</code> from its governed gas pool
and deposits it to <code><a href="account.md#0x1_account">account</a></code>. Governance-gated; the mirror of <code>fund</code> for fungible assets.
@param aptos_framework The signer of the aptos_framework module.
@param account The recipient account.
@param metadata The metadata object address of the fungible asset.
@param amount The amount to withdraw from the pool.


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_fund_fa">fund_fa</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account">account</a>: <b>address</b>, metadata: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_fund_fa">fund_fa</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="account.md#0x1_account">account</a>: <b>address</b>,
    metadata: <b>address</b>,
    amount: u64,
) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>let</b> pool_signer = <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>();
    <b>let</b> fa = <a href="primary_fungible_store.md#0x1_primary_fungible_store_withdraw">primary_fungible_store::withdraw</a>(
        &pool_signer,
        <a href="object.md#0x1_object_address_to_object">object::address_to_object</a>&lt;Metadata&gt;(metadata),
        amount
    );
    <a href="primary_fungible_store.md#0x1_primary_fungible_store_deposit">primary_fungible_store::deposit</a>(<a href="account.md#0x1_account">account</a>, fa);
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_deposit_treasury"></a>

## Function `deposit_treasury`

Deposits from the treasury account. Treasury deposit are recorded.
@param treasury_account The address of the account that paid the treasury.
@param amount The amount of treasury to be deposited.


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_treasury">deposit_treasury</a>(treasury_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_treasury">deposit_treasury</a>(treasury_account: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64) <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a> {
    <b>let</b> treasury_account_address = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(treasury_account);
    <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_from">deposit_from</a>&lt;AptosCoin&gt;(treasury_account_address, amount);

    <b>let</b> ggp = <b>borrow_global_mut</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>&gt;(@aptos_framework);
    ggp.deposited_treasury_counter = ggp.deposited_treasury_counter + amount;
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_get_balance"></a>

## Function `get_balance`

Gets the balance of a specified coin type in the governed gas pool.
@return The balance of the coin in the pool.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_balance">get_balance</a>&lt;CoinType&gt;(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_balance">get_balance</a>&lt;CoinType&gt;(): u64 <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>let</b> pool_address = <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_pool_address">governed_gas_pool_address</a>();
    <a href="coin.md#0x1_coin_balance">coin::balance</a>&lt;CoinType&gt;(pool_address)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_withdraw_staking_reward"></a>

## Function `withdraw_staking_reward`

Withdraws coins from the governed gas pool.

This function allows friend modules to withdraw a specified amount of a given
<code>CoinType</code> from the governed gas pool. It uses the internal signer of the
governed gas pool to authorize the withdrawal.

@param amount The amount of coins to withdraw from the pool.
@return A <code>Coin&lt;CoinType&gt;</code> resource containing the withdrawn amount.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_withdraw_staking_reward">withdraw_staking_reward</a>&lt;CoinType&gt;(amount: u64): <a href="coin.md#0x1_coin_Coin">coin::Coin</a>&lt;CoinType&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_withdraw_staking_reward">withdraw_staking_reward</a>&lt;CoinType&gt;(
    amount: u64
): Coin&lt;CoinType&gt; <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>, <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a> {
    <b>let</b> balance = <a href="governed_gas_pool.md#0x1_governed_gas_pool_get_balance">get_balance</a>&lt;CoinType&gt;();
    <b>assert</b>!(balance &gt;= amount, 0); // insufficient balance
    <b>let</b> ggpv2 = <b>borrow_global_mut</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPoolExtension">GovernedGasPoolExtension</a>&gt;(@aptos_framework);

    <a href="event.md#0x1_event_emit_event">event::emit_event</a>(
        &<b>mut</b> ggpv2.withdraw_staking_reward_events,
        <a href="governed_gas_pool.md#0x1_governed_gas_pool_WithdrawStakingRewardEvent">WithdrawStakingRewardEvent</a> {
            amount,
        },
    );

    // Withdraw reward <a href="coin.md#0x1_coin">coin</a>.
    <a href="coin.md#0x1_coin_withdraw">coin::withdraw</a>&lt;CoinType&gt;(&<a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>(), amount)
}
</code></pre>



</details>

<a id="0x1_governed_gas_pool_register_coin"></a>

## Function `register_coin`

Register Aptos coin with Governed gas signer.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_register_coin">register_coin</a>&lt;CoinType&gt;()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_register_coin">register_coin</a>&lt;CoinType&gt;() <b>acquires</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a> {
    <b>let</b> s = <a href="governed_gas_pool.md#0x1_governed_gas_pool_governed_gas_signer">governed_gas_signer</a>();
    <a href="coin.md#0x1_coin_register">coin::register</a>&lt;CoinType&gt;(&s);
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification



<pre><code>// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>invariant</b> <b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>&gt;(@aptos_framework);
</code></pre>



<a id="@Specification_1_initialize"></a>

### Function `initialize`


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, delegation_pool_creation_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>requires</b> <a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">system_addresses::is_aptos_framework_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework));
// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>ensures</b> <b>exists</b>&lt;<a href="governed_gas_pool.md#0x1_governed_gas_pool_GovernedGasPool">GovernedGasPool</a>&gt;(@aptos_framework);
</code></pre>



<a id="@Specification_1_fund"></a>

### Function `fund`


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_fund">fund</a>&lt;CoinType&gt;(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="account.md#0x1_account">account</a>: <b>address</b>, amount: u64)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial = <b>true</b>;
// This enforces <a id="high-level-req-4" href="#high-level-req">high-level requirement 4</a>:
<b>aborts_if</b> !<a href="system_addresses.md#0x1_system_addresses_is_aptos_framework_address">system_addresses::is_aptos_framework_address</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework));
</code></pre>


Abort if the governed gas pool has insufficient funds


<pre><code><b>aborts_with</b> <a href="coin.md#0x1_coin_EINSUFFICIENT_BALANCE">coin::EINSUFFICIENT_BALANCE</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(EINSUFFICIENT_BALANCE), 0x1, 0x5, 0x7;
</code></pre>



<a id="@Specification_1_deposit"></a>

### Function `deposit`


<pre><code><b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit">deposit</a>&lt;CoinType&gt;(<a href="coin.md#0x1_coin">coin</a>: <a href="coin.md#0x1_coin_Coin">coin::Coin</a>&lt;CoinType&gt;)
</code></pre>




<pre><code><b>pragma</b> aborts_if_is_partial = <b>true</b>;
</code></pre>



<a id="@Specification_1_deposit_gas_fee"></a>

### Function `deposit_gas_fee`


<pre><code><b>public</b> <b>fun</b> <a href="governed_gas_pool.md#0x1_governed_gas_pool_deposit_gas_fee">deposit_gas_fee</a>(_gas_payer: <b>address</b>, _gas_fee: u64)
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
