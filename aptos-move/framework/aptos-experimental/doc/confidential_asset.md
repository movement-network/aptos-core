
<a id="0x7_confidential_asset"></a>

# Module `0x7::confidential_asset`

This module implements the Confidential Asset (CA) Standard, a privacy-focused protocol for managing fungible assets (FA).
It enables private transfers by obfuscating token amounts while keeping sender and recipient addresses visible.


-  [Resource `ConfidentialAssetStore`](#0x7_confidential_asset_ConfidentialAssetStore)
-  [Resource `FAController`](#0x7_confidential_asset_FAController)
-  [Resource `FAConfig`](#0x7_confidential_asset_FAConfig)
-  [Struct `Registered`](#0x7_confidential_asset_Registered)
-  [Struct `Deposited`](#0x7_confidential_asset_Deposited)
-  [Struct `Withdrawn`](#0x7_confidential_asset_Withdrawn)
-  [Struct `Transferred`](#0x7_confidential_asset_Transferred)
-  [Struct `Normalized`](#0x7_confidential_asset_Normalized)
-  [Struct `RolledOver`](#0x7_confidential_asset_RolledOver)
-  [Struct `KeyRotated`](#0x7_confidential_asset_KeyRotated)
-  [Struct `FreezeChanged`](#0x7_confidential_asset_FreezeChanged)
-  [Struct `AllowListChanged`](#0x7_confidential_asset_AllowListChanged)
-  [Struct `TokenAllowChanged`](#0x7_confidential_asset_TokenAllowChanged)
-  [Struct `AuditorChanged`](#0x7_confidential_asset_AuditorChanged)
-  [Constants](#@Constants_0)
-  [Function `register`](#0x7_confidential_asset_register)
-  [Function `deposit_to`](#0x7_confidential_asset_deposit_to)
-  [Function `deposit`](#0x7_confidential_asset_deposit)
-  [Function `deposit_coins_to`](#0x7_confidential_asset_deposit_coins_to)
-  [Function `deposit_coins`](#0x7_confidential_asset_deposit_coins)
-  [Function `withdraw_to`](#0x7_confidential_asset_withdraw_to)
-  [Function `withdraw`](#0x7_confidential_asset_withdraw)
-  [Function `confidential_transfer`](#0x7_confidential_asset_confidential_transfer)
-  [Function `max_sender_auditor_hint_bytes`](#0x7_confidential_asset_max_sender_auditor_hint_bytes)
-  [Function `rotate_encryption_key`](#0x7_confidential_asset_rotate_encryption_key)
-  [Function `normalize`](#0x7_confidential_asset_normalize)
-  [Function `freeze_token`](#0x7_confidential_asset_freeze_token)
-  [Function `unfreeze_token`](#0x7_confidential_asset_unfreeze_token)
-  [Function `rollover_pending_balance`](#0x7_confidential_asset_rollover_pending_balance)
-  [Function `rollover_pending_balance_and_freeze`](#0x7_confidential_asset_rollover_pending_balance_and_freeze)
-  [Function `rotate_encryption_key_and_unfreeze`](#0x7_confidential_asset_rotate_encryption_key_and_unfreeze)
-  [Function `enable_allow_list`](#0x7_confidential_asset_enable_allow_list)
-  [Function `disable_allow_list`](#0x7_confidential_asset_disable_allow_list)
-  [Function `enable_token`](#0x7_confidential_asset_enable_token)
-  [Function `disable_token`](#0x7_confidential_asset_disable_token)
-  [Function `set_auditor`](#0x7_confidential_asset_set_auditor)
-  [Function `has_confidential_asset_store`](#0x7_confidential_asset_has_confidential_asset_store)
-  [Function `is_token_allowed`](#0x7_confidential_asset_is_token_allowed)
-  [Function `is_allow_list_enabled`](#0x7_confidential_asset_is_allow_list_enabled)
-  [Function `pending_balance`](#0x7_confidential_asset_pending_balance)
-  [Function `actual_balance`](#0x7_confidential_asset_actual_balance)
-  [Function `encryption_key`](#0x7_confidential_asset_encryption_key)
-  [Function `is_normalized`](#0x7_confidential_asset_is_normalized)
-  [Function `is_frozen`](#0x7_confidential_asset_is_frozen)
-  [Function `get_auditor`](#0x7_confidential_asset_get_auditor)
-  [Function `confidential_asset_balance`](#0x7_confidential_asset_confidential_asset_balance)
-  [Function `register_internal`](#0x7_confidential_asset_register_internal)
-  [Function `deposit_to_internal`](#0x7_confidential_asset_deposit_to_internal)
-  [Function `withdraw_to_internal`](#0x7_confidential_asset_withdraw_to_internal)
-  [Function `confidential_transfer_internal`](#0x7_confidential_asset_confidential_transfer_internal)
-  [Function `rotate_encryption_key_internal`](#0x7_confidential_asset_rotate_encryption_key_internal)
-  [Function `normalize_internal`](#0x7_confidential_asset_normalize_internal)
-  [Function `rollover_pending_balance_internal`](#0x7_confidential_asset_rollover_pending_balance_internal)
-  [Function `freeze_token_internal`](#0x7_confidential_asset_freeze_token_internal)
-  [Function `unfreeze_token_internal`](#0x7_confidential_asset_unfreeze_token_internal)
-  [Function `serialize_auditor_eks`](#0x7_confidential_asset_serialize_auditor_eks)
-  [Function `serialize_auditor_amounts`](#0x7_confidential_asset_serialize_auditor_amounts)


<pre><code><b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-framework/doc/chain_id.md#0x1_chain_id">0x1::chain_id</a>;
<b>use</b> <a href="../../aptos-framework/doc/coin.md#0x1_coin">0x1::coin</a>;
<b>use</b> <a href="../../aptos-framework/doc/dispatchable_fungible_asset.md#0x1_dispatchable_fungible_asset">0x1::dispatchable_fungible_asset</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-framework/doc/event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset">0x1::fungible_asset</a>;
<b>use</b> <a href="../../aptos-framework/doc/object.md#0x1_object">0x1::object</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-framework/doc/primary_fungible_store.md#0x1_primary_fungible_store">0x1::primary_fungible_store</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs">0x1::ristretto255_bulletproofs</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/doc/string_utils.md#0x1_string_utils">0x1::string_utils</a>;
<b>use</b> <a href="../../aptos-framework/doc/system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
<b>use</b> <a href="confidential_balance.md#0x7_confidential_balance">0x7::confidential_balance</a>;
<b>use</b> <a href="confidential_proof.md#0x7_confidential_proof">0x7::confidential_proof</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal">0x7::ristretto255_twisted_elgamal</a>;
</code></pre>



<a id="0x7_confidential_asset_ConfidentialAssetStore"></a>

## Resource `ConfidentialAssetStore`

The <code><a href="confidential_asset.md#0x7_confidential_asset">confidential_asset</a></code> module stores a <code><a href="confidential_asset.md#0x7_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code> object for each user-token pair.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> <b>has</b> key
</code></pre>



<a id="0x7_confidential_asset_FAController"></a>

## Resource `FAController`

Represents the controller for the primary FA stores and <code><a href="confidential_asset.md#0x7_confidential_asset_FAConfig">FAConfig</a></code> objects.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_FAController">FAController</a> <b>has</b> key
</code></pre>



<a id="0x7_confidential_asset_FAConfig"></a>

## Resource `FAConfig`

Represents the configuration of a token.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_FAConfig">FAConfig</a> <b>has</b> key
</code></pre>



<a id="0x7_confidential_asset_Registered"></a>

## Struct `Registered`

Emitted when a new confidential asset store is registered.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_Registered">Registered</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_Deposited"></a>

## Struct `Deposited`

Emitted when tokens are brought into the protocol.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_Deposited">Deposited</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_Withdrawn"></a>

## Struct `Withdrawn`

Emitted when tokens are brought out of the protocol.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_Withdrawn">Withdrawn</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_Transferred"></a>

## Struct `Transferred`

Emitted after a successful <code>confidential_transfer</code> between two registered confidential accounts.

This is the primary on-chain signal for indexers and tooling: **plaintext amounts are not** included;
fields carry **compressed Twisted-ElGamal ciphertexts** and a **subset of sigma commitment bytes** copied
from the verified proof. See the technical whitepaper (<code>whitepaper.md</code>, §5) for a field-by-field guide.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_Transferred">Transferred</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_Normalized"></a>

## Struct `Normalized`

Emitted when the available balance is re-encrypted to normalize chunk bounds.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_Normalized">Normalized</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_RolledOver"></a>

## Struct `RolledOver`

Emitted when the pending balance is rolled over into the available balance.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_RolledOver">RolledOver</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_KeyRotated"></a>

## Struct `KeyRotated`

Emitted when the encryption key is rotated and the balance is re-encrypted.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_KeyRotated">KeyRotated</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_FreezeChanged"></a>

## Struct `FreezeChanged`

Emitted when a confidential account's incoming-transfer pause state changes (freeze/unfreeze).


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_FreezeChanged">FreezeChanged</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_AllowListChanged"></a>

## Struct `AllowListChanged`

Emitted when the global allow list is enabled or disabled.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_AllowListChanged">AllowListChanged</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_TokenAllowChanged"></a>

## Struct `TokenAllowChanged`

Emitted when a token's confidential-transfer permission is toggled.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_TokenAllowChanged">TokenAllowChanged</a> <b>has</b> drop, store
</code></pre>



<a id="0x7_confidential_asset_AuditorChanged"></a>

## Struct `AuditorChanged`

Emitted when the asset-specific auditor is set or removed.


<pre><code>#[<a href="../../aptos-framework/doc/event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x7_confidential_asset_AuditorChanged">AuditorChanged</a> <b>has</b> drop, store
</code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x7_confidential_asset_EINTERNAL_ERROR"></a>

An internal error occurred, indicating unexpected behavior.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EINTERNAL_ERROR">EINTERNAL_ERROR</a>: u64 = 16;
</code></pre>



<a id="0x7_confidential_asset_EALLOW_LIST_DISABLED"></a>

The allow list is already disabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EALLOW_LIST_DISABLED">EALLOW_LIST_DISABLED</a>: u64 = 15;
</code></pre>



<a id="0x7_confidential_asset_EALLOW_LIST_ENABLED"></a>

The allow list is already enabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EALLOW_LIST_ENABLED">EALLOW_LIST_ENABLED</a>: u64 = 14;
</code></pre>



<a id="0x7_confidential_asset_EALREADY_FROZEN"></a>

The confidential asset account is already frozen.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EALREADY_FROZEN">EALREADY_FROZEN</a>: u64 = 7;
</code></pre>



<a id="0x7_confidential_asset_EALREADY_NORMALIZED"></a>

The balance is already normalized and cannot be normalized again.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EALREADY_NORMALIZED">EALREADY_NORMALIZED</a>: u64 = 11;
</code></pre>



<a id="0x7_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED"></a>

The deserialization of the auditor EK failed.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED">EAUDITOR_EK_DESERIALIZATION_FAILED</a>: u64 = 4;
</code></pre>



<a id="0x7_confidential_asset_EAUDITOR_HINT_TOO_LONG"></a>

<code>sender_auditor_hint</code> exceeds [<code><a href="confidential_asset.md#0x7_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a></code>].


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EAUDITOR_HINT_TOO_LONG">EAUDITOR_HINT_TOO_LONG</a>: u64 = 18;
</code></pre>



<a id="0x7_confidential_asset_ECA_STORE_ALREADY_PUBLISHED"></a>

The confidential asset store has already been published for the given user-token pair.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ECA_STORE_ALREADY_PUBLISHED">ECA_STORE_ALREADY_PUBLISHED</a>: u64 = 2;
</code></pre>



<a id="0x7_confidential_asset_ECA_STORE_NOT_PUBLISHED"></a>

The confidential asset store has not been published for the given user-token pair.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>: u64 = 3;
</code></pre>



<a id="0x7_confidential_asset_EINVALID_AUDITORS"></a>

The provided auditors or auditor proofs are invalid.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EINVALID_AUDITORS">EINVALID_AUDITORS</a>: u64 = 6;
</code></pre>



<a id="0x7_confidential_asset_EINVALID_SENDER_AMOUNT"></a>

Sender and recipient amounts encrypt different transfer amounts


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_EINVALID_SENDER_AMOUNT">EINVALID_SENDER_AMOUNT</a>: u64 = 17;
</code></pre>



<a id="0x7_confidential_asset_ENORMALIZATION_REQUIRED"></a>

The operation requires the actual balance to be normalized.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ENORMALIZATION_REQUIRED">ENORMALIZATION_REQUIRED</a>: u64 = 10;
</code></pre>



<a id="0x7_confidential_asset_ENOT_AUDITOR"></a>

The sender is not the registered auditor.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ENOT_AUDITOR">ENOT_AUDITOR</a>: u64 = 5;
</code></pre>



<a id="0x7_confidential_asset_ENOT_FROZEN"></a>

The confidential asset account is not frozen.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ENOT_FROZEN">ENOT_FROZEN</a>: u64 = 8;
</code></pre>



<a id="0x7_confidential_asset_ENOT_ZERO_BALANCE"></a>

The pending balance must be zero for this operation.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ENOT_ZERO_BALANCE">ENOT_ZERO_BALANCE</a>: u64 = 9;
</code></pre>



<a id="0x7_confidential_asset_ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE"></a>

The range proof system does not support sufficient range.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE">ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE</a>: u64 = 1;
</code></pre>



<a id="0x7_confidential_asset_ETOKEN_DISABLED"></a>

The token is not allowed for confidential transfers.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>: u64 = 13;
</code></pre>



<a id="0x7_confidential_asset_ETOKEN_ENABLED"></a>

The token is already allowed for confidential transfers.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_ETOKEN_ENABLED">ETOKEN_ENABLED</a>: u64 = 12;
</code></pre>



<a id="0x7_confidential_asset_MAINNET_CHAIN_ID"></a>

The mainnet chain ID. If the chain ID is 1, the allow list is enabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_MAINNET_CHAIN_ID">MAINNET_CHAIN_ID</a>: u8 = 1;
</code></pre>



<a id="0x7_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES"></a>

Maximum length (bytes) of the opaque <code>sender_auditor_hint</code> passed to [<code>confidential_transfer</code>].


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a>: u64 = 256;
</code></pre>



<a id="0x7_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER"></a>

The maximum number of transactions can be aggregated on the pending balance before rollover is required.


<pre><code><b>const</b> <a href="confidential_asset.md#0x7_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER">MAX_TRANSFERS_BEFORE_ROLLOVER</a>: u64 = 65534;
</code></pre>



<a id="0x7_confidential_asset_register"></a>

## Function `register`

Registers an account for a specified token. Users must register an account for each token they
intend to transact with.

Users are also responsible for generating a Twisted ElGamal key pair on their side.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_register">register</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, ek: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_commitment: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_response: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_deposit_to"></a>

## Function `deposit_to`

Brings tokens into the protocol, transferring the passed amount from the sender's primary FA store
to the pending balance of the recipient.
The initial confidential balance is publicly visible, as entering the protocol requires a normal transfer.
However, tokens within the protocol become obfuscated through confidential transfers, ensuring privacy in
subsequent transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_deposit_to">deposit_to</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<a id="0x7_confidential_asset_deposit"></a>

## Function `deposit`

The same as <code>deposit_to</code>, but the recipient is the sender.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_deposit">deposit</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64)
</code></pre>



<a id="0x7_confidential_asset_deposit_coins_to"></a>

## Function `deposit_coins_to`

The same as <code>deposit_to</code>, but converts coins to missing FA first.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_deposit_coins_to">deposit_coins_to</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<a id="0x7_confidential_asset_deposit_coins"></a>

## Function `deposit_coins`

The same as <code>deposit</code>, but converts coins to missing FA first.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_deposit_coins">deposit_coins</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64)
</code></pre>



<a id="0x7_confidential_asset_withdraw_to"></a>

## Function `withdraw_to`

Brings tokens out of the protocol by transferring the specified amount from the sender's actual balance to
the recipient's primary FA store.
The withdrawn amount is publicly visible, as this process requires a normal transfer.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_withdraw_to">withdraw_to</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64, new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_withdraw"></a>

## Function `withdraw`

The same as <code>withdraw_to</code>, but the recipient is the sender.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_withdraw">withdraw</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64, new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_confidential_transfer"></a>

## Function `confidential_transfer`

Transfers tokens from the sender's actual balance to the recipient's pending balance.
The function hides the transferred amount while keeping the sender and recipient addresses visible.
The sender encrypts the transferred amount with the recipient's encryption key and the function updates the
recipient's confidential balance homomorphically.
Additionally, the sender encrypts the transferred amount with the auditors' EKs, allowing auditors to decrypt
it on their side.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.
Warning: If the auditor feature is enabled, the sender must include the auditor as the first element in the
<code>auditor_eks</code> vector.

<code>sender_auditor_hint</code> is emitted on [<code><a href="confidential_asset.md#0x7_confidential_asset_Transferred">Transferred</a></code>] and is **bound into the transfer sigma Fiat–Shamir
transcript** (must match the hint used when generating the proof). Length must not exceed
[<code><a href="confidential_asset.md#0x7_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a></code>].


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_confidential_transfer">confidential_transfer</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sender_amount: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, recipient_amount: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, auditor_eks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, auditor_amounts: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_transfer_amount: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sender_auditor_hint: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_max_sender_auditor_hint_bytes"></a>

## Function `max_sender_auditor_hint_bytes`

Returns the maximum allowed <code>sender_auditor_hint</code> length for [<code>confidential_transfer</code>].


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_max_sender_auditor_hint_bytes">max_sender_auditor_hint_bytes</a>(): u64
</code></pre>



<a id="0x7_confidential_asset_rotate_encryption_key"></a>

## Function `rotate_encryption_key`

Rotates the encryption key for the user's confidential balance, updating it to a new encryption key.
The function ensures that the pending balance is zero before the key rotation, requiring the sender to
call <code>rollover_pending_balance_and_freeze</code> beforehand if necessary.
The sender provides their new normalized confidential balance, encrypted with the new encryption key and fresh randomness
to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_normalize"></a>

## Function `normalize`

Adjusts each chunk to fit into defined 16-bit bounds to prevent overflows.
Most functions perform implicit normalization by accepting a new normalized confidential balance as a parameter.
However, explicit normalization is required before rolling over the pending balance, as multiple rolls may cause
chunk overflows.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_normalize">normalize</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_freeze_token"></a>

## Function `freeze_token`

Freezes the confidential account for the specified token, disabling all incoming transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_freeze_token">freeze_token</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_unfreeze_token"></a>

## Function `unfreeze_token`

Unfreezes the confidential account for the specified token, re-enabling incoming transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_unfreeze_token">unfreeze_token</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_rollover_pending_balance"></a>

## Function `rollover_pending_balance`

Adds the pending balance to the actual balance for the specified token, resetting the pending balance to zero.
This operation is necessary to use tokens from the pending balance for outgoing transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_rollover_pending_balance_and_freeze"></a>

## Function `rollover_pending_balance_and_freeze`

Before calling <code>rotate_encryption_key</code>, we need to rollover the pending balance and freeze the token to prevent
any new payments being come.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rollover_pending_balance_and_freeze">rollover_pending_balance_and_freeze</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_rotate_encryption_key_and_unfreeze"></a>

## Function `rotate_encryption_key_and_unfreeze`

After rotating the encryption key, we may want to unfreeze the token to allow payments.
This function facilitates making both calls in a single transaction.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rotate_encryption_key_and_unfreeze">rotate_encryption_key_and_unfreeze</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, new_confidential_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, rotate_proof: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_enable_allow_list"></a>

## Function `enable_allow_list`

Enables the allow list, restricting confidential transfers to tokens on the allow list.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_enable_allow_list">enable_allow_list</a>(aptos_framework: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<a id="0x7_confidential_asset_disable_allow_list"></a>

## Function `disable_allow_list`

Disables the allow list, allowing confidential transfers for all tokens.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_disable_allow_list">disable_allow_list</a>(aptos_framework: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<a id="0x7_confidential_asset_enable_token"></a>

## Function `enable_token`

Enables confidential transfers for the specified token.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_enable_token">enable_token</a>(aptos_framework: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_disable_token"></a>

## Function `disable_token`

Disables confidential transfers for the specified token.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_disable_token">disable_token</a>(aptos_framework: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_set_auditor"></a>

## Function `set_auditor`

Sets the auditor's public key for the specified token.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_set_auditor">set_auditor</a>(aptos_framework: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_auditor_ek: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_has_confidential_asset_store"></a>

## Function `has_confidential_asset_store`

Checks if the user has a confidential asset store for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<a id="0x7_confidential_asset_is_token_allowed"></a>

## Function `is_token_allowed`

Checks if the token is allowed for confidential transfers.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_is_token_allowed">is_token_allowed</a>(token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<a id="0x7_confidential_asset_is_allow_list_enabled"></a>

## Function `is_allow_list_enabled`

Checks if the allow list is enabled.
If the allow list is enabled, only tokens from the allow list can be transferred.
Otherwise, all tokens are allowed.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>(): bool
</code></pre>



<a id="0x7_confidential_asset_pending_balance"></a>

## Function `pending_balance`

Returns the pending balance of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_pending_balance">pending_balance</a>(owner: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x7_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<a id="0x7_confidential_asset_actual_balance"></a>

## Function `actual_balance`

Returns the actual balance of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_actual_balance">actual_balance</a>(owner: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x7_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<a id="0x7_confidential_asset_encryption_key"></a>

## Function `encryption_key`

Returns the encryption key (EK) of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_encryption_key">encryption_key</a>(user: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>
</code></pre>



<a id="0x7_confidential_asset_is_normalized"></a>

## Function `is_normalized`

Checks if the user's actual balance is normalized for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_is_normalized">is_normalized</a>(user: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<a id="0x7_confidential_asset_is_frozen"></a>

## Function `is_frozen`

Checks if the user's confidential asset store is frozen for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_is_frozen">is_frozen</a>(user: <b>address</b>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<a id="0x7_confidential_asset_get_auditor"></a>

## Function `get_auditor`

Returns the asset-specific auditor's encryption key.
If the auditing feature is disabled for the token, the encryption key is set to <code>None</code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_get_auditor">get_auditor</a>(token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<a id="0x7_confidential_asset_confidential_asset_balance"></a>

## Function `confidential_asset_balance`

Returns the circulating supply of the confidential asset.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_confidential_asset_balance">confidential_asset_balance</a>(token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): u64
</code></pre>



<a id="0x7_confidential_asset_register_internal"></a>

## Function `register_internal`

Implementation of the <code>register</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_register_internal">register_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, ek: <a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>)
</code></pre>



<a id="0x7_confidential_asset_deposit_to_internal"></a>

## Function `deposit_to_internal`

Implementation of the <code>deposit_to</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<a id="0x7_confidential_asset_withdraw_to_internal"></a>

## Function `withdraw_to_internal`

Implementation of the <code>withdraw_to</code> entry function.
Withdrawals are always allowed, regardless of the token allow status.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64, new_balance: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x7_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>)
</code></pre>



<a id="0x7_confidential_asset_confidential_transfer_internal"></a>

## Function `confidential_transfer_internal`

Implementation of the <code>confidential_transfer</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, new_balance: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, sender_amount: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, recipient_amount: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, auditor_eks: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, auditor_amounts: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, proof: <a href="confidential_proof.md#0x7_confidential_proof_TransferProof">confidential_proof::TransferProof</a>, sender_auditor_hint: <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<a id="0x7_confidential_asset_rotate_encryption_key_internal"></a>

## Function `rotate_encryption_key_internal`

Implementation of the <code>rotate_encryption_key</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, new_balance: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x7_confidential_proof_RotationProof">confidential_proof::RotationProof</a>)
</code></pre>



<a id="0x7_confidential_asset_normalize_internal"></a>

## Function `normalize_internal`

Implementation of the <code>normalize</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_normalize_internal">normalize_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_balance: <a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x7_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>)
</code></pre>



<a id="0x7_confidential_asset_rollover_pending_balance_internal"></a>

## Function `rollover_pending_balance_internal`

Implementation of the <code>rollover_pending_balance</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_freeze_token_internal"></a>

## Function `freeze_token_internal`

Implementation of the <code>freeze_token</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_freeze_token_internal">freeze_token_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_unfreeze_token_internal"></a>

## Function `unfreeze_token_internal`

Implementation of the <code>unfreeze_token</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(sender: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="../../aptos-framework/doc/object.md#0x1_object_Object">object::Object</a>&lt;<a href="../../aptos-framework/doc/fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<a id="0x7_confidential_asset_serialize_auditor_eks"></a>

## Function `serialize_auditor_eks`

Pure serialization helpers (no <code><b>borrow_global</b></code>). Public so off-chain tooling and
tooling can exercise the same entrypoints as tests without <code>#[test_only]</code> harness modules.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_serialize_auditor_eks">serialize_auditor_eks</a>(auditor_eks: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x7_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<a id="0x7_confidential_asset_serialize_auditor_amounts"></a>

## Function `serialize_auditor_amounts`



<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x7_confidential_asset_serialize_auditor_amounts">serialize_auditor_amounts</a>(auditor_amounts: &<a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x7_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;): <a href="../../aptos-framework/../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>
