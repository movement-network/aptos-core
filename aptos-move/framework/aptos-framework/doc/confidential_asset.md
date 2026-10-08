
<a id="0x1_confidential_asset"></a>

# Module `0x1::confidential_asset`

This module implements the Confidential Asset (CA) Standard, a privacy-focused protocol for managing fungible assets (FA).
It enables private transfers by obfuscating token amounts while keeping sender and recipient addresses visible.


-  [Resource `ConfidentialAssetStore`](#0x1_confidential_asset_ConfidentialAssetStore)
-  [Resource `GlobalConfig`](#0x1_confidential_asset_GlobalConfig)
-  [Resource `FAConfig`](#0x1_confidential_asset_FAConfig)
-  [Struct `Registered`](#0x1_confidential_asset_Registered)
-  [Struct `Deposited`](#0x1_confidential_asset_Deposited)
-  [Struct `Withdrawn`](#0x1_confidential_asset_Withdrawn)
-  [Struct `Transferred`](#0x1_confidential_asset_Transferred)
-  [Struct `Normalized`](#0x1_confidential_asset_Normalized)
-  [Struct `RolledOver`](#0x1_confidential_asset_RolledOver)
-  [Struct `KeyRotated`](#0x1_confidential_asset_KeyRotated)
-  [Struct `FreezeChanged`](#0x1_confidential_asset_FreezeChanged)
-  [Struct `AllowListChanged`](#0x1_confidential_asset_AllowListChanged)
-  [Struct `TokenAllowChanged`](#0x1_confidential_asset_TokenAllowChanged)
-  [Struct `AssetAuditorChanged`](#0x1_confidential_asset_AssetAuditorChanged)
-  [Struct `ChainAuditorChanged`](#0x1_confidential_asset_ChainAuditorChanged)
-  [Struct `ChainAuditorAdminChanged`](#0x1_confidential_asset_ChainAuditorAdminChanged)
-  [Constants](#@Constants_0)
-  [Function `init_module`](#0x1_confidential_asset_init_module)
-  [Function `initialize`](#0x1_confidential_asset_initialize)
-  [Function `register`](#0x1_confidential_asset_register)
-  [Function `register_and_deposit_and_rollover_pending_balance`](#0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance)
-  [Function `deposit_and_rollover_pending_balance`](#0x1_confidential_asset_deposit_and_rollover_pending_balance)
-  [Function `deposit_and_normalize_and_rollover_pending_balance`](#0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance)
-  [Function `deposit_to`](#0x1_confidential_asset_deposit_to)
-  [Function `deposit`](#0x1_confidential_asset_deposit)
-  [Function `deposit_coins_to`](#0x1_confidential_asset_deposit_coins_to)
-  [Function `deposit_coins`](#0x1_confidential_asset_deposit_coins)
-  [Function `withdraw_to`](#0x1_confidential_asset_withdraw_to)
-  [Function `withdraw`](#0x1_confidential_asset_withdraw)
-  [Function `confidential_transfer`](#0x1_confidential_asset_confidential_transfer)
-  [Function `max_sender_auditor_hint_bytes`](#0x1_confidential_asset_max_sender_auditor_hint_bytes)
-  [Function `rotate_encryption_key`](#0x1_confidential_asset_rotate_encryption_key)
-  [Function `normalize`](#0x1_confidential_asset_normalize)
-  [Function `freeze_token`](#0x1_confidential_asset_freeze_token)
-  [Function `unfreeze_token`](#0x1_confidential_asset_unfreeze_token)
-  [Function `rollover_pending_balance`](#0x1_confidential_asset_rollover_pending_balance)
-  [Function `normalize_and_rollover_pending_balance`](#0x1_confidential_asset_normalize_and_rollover_pending_balance)
-  [Function `rollover_pending_balance_and_freeze`](#0x1_confidential_asset_rollover_pending_balance_and_freeze)
-  [Function `rotate_encryption_key_and_unfreeze`](#0x1_confidential_asset_rotate_encryption_key_and_unfreeze)
-  [Function `enable_allow_list`](#0x1_confidential_asset_enable_allow_list)
-  [Function `disable_allow_list`](#0x1_confidential_asset_disable_allow_list)
-  [Function `enable_token`](#0x1_confidential_asset_enable_token)
-  [Function `disable_token`](#0x1_confidential_asset_disable_token)
-  [Function `set_asset_auditor`](#0x1_confidential_asset_set_asset_auditor)
-  [Function `set_chain_auditor_admin`](#0x1_confidential_asset_set_chain_auditor_admin)
-  [Function `set_chain_auditor`](#0x1_confidential_asset_set_chain_auditor)
-  [Function `has_confidential_asset_store`](#0x1_confidential_asset_has_confidential_asset_store)
-  [Function `is_token_allowed`](#0x1_confidential_asset_is_token_allowed)
-  [Function `is_allow_list_enabled`](#0x1_confidential_asset_is_allow_list_enabled)
-  [Function `pending_balance`](#0x1_confidential_asset_pending_balance)
-  [Function `actual_balance`](#0x1_confidential_asset_actual_balance)
-  [Function `encryption_key`](#0x1_confidential_asset_encryption_key)
-  [Function `is_normalized`](#0x1_confidential_asset_is_normalized)
-  [Function `is_frozen`](#0x1_confidential_asset_is_frozen)
-  [Function `get_asset_auditor`](#0x1_confidential_asset_get_asset_auditor)
-  [Function `get_asset_auditor_epoch`](#0x1_confidential_asset_get_asset_auditor_epoch)
-  [Function `get_chain_auditor`](#0x1_confidential_asset_get_chain_auditor)
-  [Function `get_chain_auditor_epoch`](#0x1_confidential_asset_get_chain_auditor_epoch)
-  [Function `get_chain_auditor_admin`](#0x1_confidential_asset_get_chain_auditor_admin)
-  [Function `confidential_asset_balance`](#0x1_confidential_asset_confidential_asset_balance)
-  [Function `register_internal`](#0x1_confidential_asset_register_internal)
-  [Function `deposit_to_internal`](#0x1_confidential_asset_deposit_to_internal)
-  [Function `withdraw_to_internal`](#0x1_confidential_asset_withdraw_to_internal)
-  [Function `confidential_transfer_internal`](#0x1_confidential_asset_confidential_transfer_internal)
-  [Function `rotate_encryption_key_internal`](#0x1_confidential_asset_rotate_encryption_key_internal)
-  [Function `normalize_internal`](#0x1_confidential_asset_normalize_internal)
-  [Function `rollover_pending_balance_internal`](#0x1_confidential_asset_rollover_pending_balance_internal)
-  [Function `freeze_token_internal`](#0x1_confidential_asset_freeze_token_internal)
-  [Function `unfreeze_token_internal`](#0x1_confidential_asset_unfreeze_token_internal)
-  [Function `is_safe_for_confidentiality`](#0x1_confidential_asset_is_safe_for_confidentiality)
-  [Function `ensure_fa_config_exists`](#0x1_confidential_asset_ensure_fa_config_exists)
-  [Function `get_fa_store_signer`](#0x1_confidential_asset_get_fa_store_signer)
-  [Function `get_fa_store_address`](#0x1_confidential_asset_get_fa_store_address)
-  [Function `get_pool_fa_store`](#0x1_confidential_asset_get_pool_fa_store)
-  [Function `ensure_pool_fa_store`](#0x1_confidential_asset_ensure_pool_fa_store)
-  [Function `get_user_signer`](#0x1_confidential_asset_get_user_signer)
-  [Function `get_user_address`](#0x1_confidential_asset_get_user_address)
-  [Function `get_fa_config_signer`](#0x1_confidential_asset_get_fa_config_signer)
-  [Function `get_fa_config_address`](#0x1_confidential_asset_get_fa_config_address)
-  [Function `construct_user_seed`](#0x1_confidential_asset_construct_user_seed)
-  [Function `construct_fa_seed`](#0x1_confidential_asset_construct_fa_seed)
-  [Function `validate_auditors`](#0x1_confidential_asset_validate_auditors)
-  [Function `deserialize_auditor_eks`](#0x1_confidential_asset_deserialize_auditor_eks)
-  [Function `deserialize_auditor_amounts`](#0x1_confidential_asset_deserialize_auditor_amounts)
-  [Function `ensure_sufficient_fa`](#0x1_confidential_asset_ensure_sufficient_fa)
-  [Function `serialize_auditor_eks`](#0x1_confidential_asset_serialize_auditor_eks)
-  [Function `serialize_auditor_amounts`](#0x1_confidential_asset_serialize_auditor_amounts)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="chain_id.md#0x1_chain_id">0x1::chain_id</a>;
<b>use</b> <a href="coin.md#0x1_coin">0x1::coin</a>;
<b>use</b> <a href="confidential_balance.md#0x1_confidential_balance">0x1::confidential_balance</a>;
<b>use</b> <a href="confidential_proof.md#0x1_confidential_proof">0x1::confidential_proof</a>;
<b>use</b> <a href="dispatchable_fungible_asset.md#0x1_dispatchable_fungible_asset">0x1::dispatchable_fungible_asset</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="fungible_asset.md#0x1_fungible_asset">0x1::fungible_asset</a>;
<b>use</b> <a href="object.md#0x1_object">0x1::object</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="primary_fungible_store.md#0x1_primary_fungible_store">0x1::primary_fungible_store</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255">0x1::ristretto255</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ristretto255_bulletproofs.md#0x1_ristretto255_bulletproofs">0x1::ristretto255_bulletproofs</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal">0x1::ristretto255_twisted_elgamal</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/string_utils.md#0x1_string_utils">0x1::string_utils</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_confidential_asset_ConfidentialAssetStore"></a>

## Resource `ConfidentialAssetStore`

The <code><a href="confidential_asset.md#0x1_confidential_asset">confidential_asset</a></code> module stores a <code><a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code> object for each user-token pair.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>frozen: bool</code>
</dt>
<dd>
 Indicates if the account is frozen. If <code><b>true</b></code>, transactions are temporarily disabled
 for this account. This is particularly useful during key rotations, which require
 two transactions: rolling over the pending balance to the actual balance and rotating
 the encryption key. Freezing prevents the user from accepting additional payments
 between these two transactions.
</dd>
<dt>
<code>normalized: bool</code>
</dt>
<dd>
 A flag indicating whether the actual balance is normalized. A normalized balance
 ensures that all chunks fit within the defined 16-bit bounds, preventing overflows.
</dd>
<dt>
<code>pending_counter: u64</code>
</dt>
<dd>
 Tracks the maximum number of transactions the user can accept before normalization
 is required. For example, if the user can accept up to 2^16 transactions and each
 chunk has a 16-bit limit, the maximum chunk value before normalization would be
 2^16 * 2^16 = 2^32. Maintaining this counter is crucial because users must solve
 a discrete logarithm problem of this size to decrypt their balances.
</dd>
<dt>
<code>pending_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Stores the user's pending balance, which is used for accepting incoming payments.
 Represented as four 16-bit chunks (p0 + 2^16 * p1 + 2^32 * p2 + 2^48 * p3), that can grow up to 32 bits.
 All payments are accepted into this pending balance, which users must roll over into the actual balance
 to perform transactions like withdrawals or transfers.
 This separation helps protect against front-running attacks, where small incoming transfers could force
 frequent regenerating of zk-proofs.
</dd>
<dt>
<code>actual_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Represents the actual user balance, which is available for sending payments.
 It consists of eight 16-bit chunks (p0 + 2^16 * p1 + ... + 2^112 * p8), supporting a 128-bit balance.
 Users can decrypt this balance with their decryption keys and by solving a discrete logarithm problem.
</dd>
<dt>
<code>ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a></code>
</dt>
<dd>
 The encryption key associated with the user's confidential asset account, different for each token.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_GlobalConfig"></a>

## Resource `GlobalConfig`

Global configuration for confidential assets: primary FA stores, <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code> derivation, and chain-level auditor state.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>allow_list_enabled: bool</code>
</dt>
<dd>
 Indicates whether the allow list is enabled. If <code><b>true</b></code>, only tokens from the allow list can be transferred.
 This flag is managed by the governance module.
</dd>
<dt>
<code>extend_ref: <a href="object.md#0x1_object_ExtendRef">object::ExtendRef</a></code>
</dt>
<dd>
 Used to derive a signer that owns all the FAs' primary stores and <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code> objects.
</dd>
<dt>
<code>chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;</code>
</dt>
<dd>
 Chain-level auditor encryption key. Required at <code>auditor_eks[0]</code> on every
 confidential transfer. <code>None</code> until set via [<code>set_chain_auditor</code>]; transfers
 abort with [<code><a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET">ECHAIN_AUDITOR_NOT_SET</a></code>] in that state.
</dd>
<dt>
<code>chain_auditor_admin: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>
 Account authorized to call [<code>set_chain_auditor</code>]. Set by governance via
 [<code>set_chain_auditor_admin</code>]. <code>None</code> until governance assigns one, during which
 window <code>set_chain_auditor</code> aborts with [<code><a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_ADMIN_NOT_SET">ECHAIN_AUDITOR_ADMIN_NOT_SET</a></code>].
</dd>
<dt>
<code>chain_auditor_epoch: u64</code>
</dt>
<dd>
 Bumped on every [<code>set_chain_auditor</code>] call (including clears). Stamped on each
 [<code><a href="confidential_asset.md#0x1_confidential_asset_Transferred">Transferred</a></code>] event so off-chain auditors / gateways can identify which
 historical chain-auditor key was in force at that transfer.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_FAConfig"></a>

## Resource `FAConfig`

Represents the configuration of a token.


<pre><code><b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>allowed: bool</code>
</dt>
<dd>
 Indicates whether the token is allowed for confidential transfers.
 If allow list is disabled, all tokens are allowed.
 Can be toggled by the governance module. The withdrawals are always allowed.
</dd>
<dt>
<code>asset_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;</code>
</dt>
<dd>
 Per-asset auditor encryption key. When set, required at <code>auditor_eks[1]</code> on
 every transfer of this asset (additive to the chain auditor at <code>[0]</code>). Set via
 [<code>set_asset_auditor</code>] by the FA metadata object's root owner.
</dd>
<dt>
<code>asset_auditor_epoch: u64</code>
</dt>
<dd>
 Bumped on every [<code>set_asset_auditor</code>] call (including clears). Stamped on each
 [<code><a href="confidential_asset.md#0x1_confidential_asset_Transferred">Transferred</a></code>] event for this asset so off-chain auditors / gateways can
 identify which historical asset-auditor key was in force at that transfer.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_Registered"></a>

## Struct `Registered`

Emitted when a new confidential asset store is registered.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_Registered">Registered</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>
 Fungible asset metadata object address.
</dd>
<dt>
<code>ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_Deposited"></a>

## Struct `Deposited`

Emitted when tokens are brought into the protocol.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_Deposited">Deposited</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>from: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code><b>to</b>: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>
 Fungible asset metadata object address.
</dd>
<dt>
<code>amount: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>new_pending_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Recipient's new pending balance after the deposit.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_Withdrawn"></a>

## Struct `Withdrawn`

Emitted when tokens are brought out of the protocol.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_Withdrawn">Withdrawn</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>from: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code><b>to</b>: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>
 Fungible asset metadata object address.
</dd>
<dt>
<code>amount: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>new_available_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Sender's new available (actual) balance after the withdrawal.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_Transferred"></a>

## Struct `Transferred`

Emitted after a successful <code>confidential_transfer</code> between two registered confidential accounts.

This is the primary on-chain signal for indexers and tooling: **plaintext amounts are not** included;
fields carry **compressed Twisted-ElGamal ciphertexts** and a **subset of sigma commitment bytes** copied
from the verified proof. See the technical whitepaper (<code>whitepaper.md</code>, §5) for a field-by-field guide.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_Transferred">Transferred</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>from: <b>address</b></code>
</dt>
<dd>
 Address of the sender's confidential account (the <code><a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a></code> of the transfer entry).
</dd>
<dt>
<code><b>to</b>: <b>address</b></code>
</dt>
<dd>
 Recipient confidential account address.
</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>
 Fungible-asset metadata object address (<code><a href="object.md#0x1_object_object_address">object::object_address</a>(&token)</code>); identifies which token moved.
</dd>
<dt>
<code>amount: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Encrypted transfer amount under the recipient key (pending-balance / four-chunk layout).
</dd>
<dt>
<code>ek_volun_auds: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 Flattened **transfer sigma <code>x7s</code>** commitments taken from the verified <code>TransferProof</code>: for each
 auditor encryption key row in the proof, exactly **four** compressed Ristretto points (32 bytes each),
 concatenated in **row-major** order (auditor index, then inner index 0..3). Empty when the proof carries
 **no** auditor rows. Total byte length is always **<code>128 × n</code>** with <code>n</code> = number of auditor rows
 (<code><a href="confidential_proof.md#0x1_confidential_proof_auditors_count_in_transfer_proof">confidential_proof::auditors_count_in_transfer_proof</a></code> / <code>proof.sigma_proof.xs.x7s.length()</code>).
</dd>
<dt>
<code>sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 Opaque sender-supplied bytes (bounded by [<code><a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a></code>]); same bytes bound into
 the transfer sigma Fiat–Shamir challenge and passed as the <code>sender_auditor_hint</code> entry argument.
</dd>
<dt>
<code>new_sender_available_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Sender's new **actual** (spendable) balance ciphertext after the debit, compressed for storage/events.
</dd>
<dt>
<code>new_recip_pending_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>
 Recipient's new **pending** balance ciphertext after the credit, compressed for storage/events.
</dd>
<dt>
<code>memo: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 Reserved memo payload for future or off-chain conventions; currently emitted as an empty <code><a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a></code>.
</dd>
<dt>
<code>chain_auditor_epoch: u64</code>
</dt>
<dd>
 Value of [<code><a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>.chain_auditor_epoch</code>] at the time of the transfer.
 Required for compliance: lets future audits identify which historical
 chain-level auditor key was in force, so that the transcript can still be
 decrypted years after a key rotation.
</dd>
<dt>
<code>asset_auditor_epoch: u64</code>
</dt>
<dd>
 Value of [<code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>.asset_auditor_epoch</code>] for this asset at the time of the
 transfer. <code>0</code> only when [<code>set_asset_auditor</code>] has never been called for this
 asset; once called (including a clear with empty bytes) the epoch is bumped
 and stamped here even if the current <code>asset_auditor_ek</code> is <code>None</code>. Off-chain
 auditors / gateways resolve <code>(asset_type, asset_auditor_epoch)</code> to the active
 key by indexing [<code><a href="confidential_asset.md#0x1_confidential_asset_AssetAuditorChanged">AssetAuditorChanged</a></code>] events.
</dd>
</dl>


</details>

<a id="0x1_confidential_asset_Normalized"></a>

## Struct `Normalized`

Emitted when the available balance is re-encrypted to normalize chunk bounds.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_Normalized">Normalized</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_available_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_RolledOver"></a>

## Struct `RolledOver`

Emitted when the pending balance is rolled over into the available balance.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_RolledOver">RolledOver</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_available_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_KeyRotated"></a>

## Struct `KeyRotated`

Emitted when the encryption key is rotated and the balance is re-encrypted.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_KeyRotated">KeyRotated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a></code>
</dt>
<dd>

</dd>
<dt>
<code>new_available_balance: <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_FreezeChanged"></a>

## Struct `FreezeChanged`

Emitted when a confidential account's incoming-transfer pause state changes (freeze/unfreeze).


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_FreezeChanged">FreezeChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>frozen: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_AllowListChanged"></a>

## Struct `AllowListChanged`

Emitted when the global allow list is enabled or disabled.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_AllowListChanged">AllowListChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>enabled: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_TokenAllowChanged"></a>

## Struct `TokenAllowChanged`

Emitted when a token's confidential-transfer permission is toggled.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_TokenAllowChanged">TokenAllowChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>allowed: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_AssetAuditorChanged"></a>

## Struct `AssetAuditorChanged`

Asset auditor set, rotated, or cleared.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_AssetAuditorChanged">AssetAuditorChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>asset_type: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>new_asset_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>new_epoch: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_ChainAuditorChanged"></a>

## Struct `ChainAuditorChanged`

Chain auditor set, rotated, or cleared.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_ChainAuditorChanged">ChainAuditorChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>new_chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>new_epoch: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_confidential_asset_ChainAuditorAdminChanged"></a>

## Struct `ChainAuditorAdminChanged`

Chain-auditor admin assigned or rotated by governance.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="confidential_asset.md#0x1_confidential_asset_ChainAuditorAdminChanged">ChainAuditorAdminChanged</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>new_admin: <b>address</b></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_confidential_asset_EZERO_AMOUNT"></a>

Deposit or withdrawal amount must be greater than zero.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EZERO_AMOUNT">EZERO_AMOUNT</a>: u64 = 25;
</code></pre>



<a id="0x1_confidential_asset_EINTERNAL_ERROR"></a>

An internal error occurred, indicating unexpected behavior.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EINTERNAL_ERROR">EINTERNAL_ERROR</a>: u64 = 16;
</code></pre>



<a id="0x1_confidential_asset_EALLOW_LIST_DISABLED"></a>

The allow list is already disabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EALLOW_LIST_DISABLED">EALLOW_LIST_DISABLED</a>: u64 = 15;
</code></pre>



<a id="0x1_confidential_asset_EALLOW_LIST_ENABLED"></a>

The allow list is already enabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EALLOW_LIST_ENABLED">EALLOW_LIST_ENABLED</a>: u64 = 14;
</code></pre>



<a id="0x1_confidential_asset_EALREADY_FROZEN"></a>

The confidential asset account is already frozen.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EALREADY_FROZEN">EALREADY_FROZEN</a>: u64 = 7;
</code></pre>



<a id="0x1_confidential_asset_EALREADY_INITIALIZED"></a>

The module's <code><a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a></code> has already been initialized.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EALREADY_INITIALIZED">EALREADY_INITIALIZED</a>: u64 = 27;
</code></pre>



<a id="0x1_confidential_asset_EALREADY_NORMALIZED"></a>

The balance is already normalized and cannot be normalized again.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EALREADY_NORMALIZED">EALREADY_NORMALIZED</a>: u64 = 11;
</code></pre>



<a id="0x1_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED"></a>

The deserialization of the auditor EK failed.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED">EAUDITOR_EK_DESERIALIZATION_FAILED</a>: u64 = 4;
</code></pre>



<a id="0x1_confidential_asset_EAUDITOR_HINT_TOO_LONG"></a>

<code>sender_auditor_hint</code> exceeds [<code><a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a></code>].


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EAUDITOR_HINT_TOO_LONG">EAUDITOR_HINT_TOO_LONG</a>: u64 = 18;
</code></pre>



<a id="0x1_confidential_asset_ECA_STORE_ALREADY_PUBLISHED"></a>

The confidential asset store has already been published for the given user-token pair.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_ALREADY_PUBLISHED">ECA_STORE_ALREADY_PUBLISHED</a>: u64 = 2;
</code></pre>



<a id="0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED"></a>

The confidential asset store has not been published for the given user-token pair.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>: u64 = 3;
</code></pre>



<a id="0x1_confidential_asset_ECHAIN_AUDITOR_ADMIN_NOT_SET"></a>

Chain-auditor admin not assigned by governance.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_ADMIN_NOT_SET">ECHAIN_AUDITOR_ADMIN_NOT_SET</a>: u64 = 23;
</code></pre>



<a id="0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET"></a>

Chain auditor not configured; confidential transfers cannot proceed.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET">ECHAIN_AUDITOR_NOT_SET</a>: u64 = 21;
</code></pre>



<a id="0x1_confidential_asset_EINVALID_AUDITORS"></a>

The provided auditors or auditor proofs are invalid.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EINVALID_AUDITORS">EINVALID_AUDITORS</a>: u64 = 6;
</code></pre>



<a id="0x1_confidential_asset_EINVALID_SENDER_AMOUNT"></a>

Sender and recipient amounts encrypt different transfer amounts


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EINVALID_SENDER_AMOUNT">EINVALID_SENDER_AMOUNT</a>: u64 = 17;
</code></pre>



<a id="0x1_confidential_asset_ENORMALIZATION_REQUIRED"></a>

The operation requires the actual balance to be normalized.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENORMALIZATION_REQUIRED">ENORMALIZATION_REQUIRED</a>: u64 = 10;
</code></pre>



<a id="0x1_confidential_asset_ENOT_ASSET_ISSUER"></a>

Signer is not the FA metadata object's root owner.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENOT_ASSET_ISSUER">ENOT_ASSET_ISSUER</a>: u64 = 22;
</code></pre>



<a id="0x1_confidential_asset_ENOT_AUDITOR"></a>

The sender is not the registered auditor.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENOT_AUDITOR">ENOT_AUDITOR</a>: u64 = 5;
</code></pre>



<a id="0x1_confidential_asset_ENOT_CHAIN_AUDITOR_ADMIN"></a>

Signer is not the configured chain-auditor admin.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENOT_CHAIN_AUDITOR_ADMIN">ENOT_CHAIN_AUDITOR_ADMIN</a>: u64 = 24;
</code></pre>



<a id="0x1_confidential_asset_ENOT_FROZEN"></a>

The confidential asset account is not frozen.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENOT_FROZEN">ENOT_FROZEN</a>: u64 = 8;
</code></pre>



<a id="0x1_confidential_asset_ENOT_ZERO_BALANCE"></a>

The pending balance must be zero for this operation.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENOT_ZERO_BALANCE">ENOT_ZERO_BALANCE</a>: u64 = 9;
</code></pre>



<a id="0x1_confidential_asset_ENO_CONFIDENTIAL_ASSET_POOL"></a>

No confidential asset pool exists for the given asset type.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ENO_CONFIDENTIAL_ASSET_POOL">ENO_CONFIDENTIAL_ASSET_POOL</a>: u64 = 20;
</code></pre>



<a id="0x1_confidential_asset_ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE"></a>

The range proof system does not support sufficient range.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE">ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE</a>: u64 = 1;
</code></pre>



<a id="0x1_confidential_asset_ESELF_TRANSFER"></a>

The sender and recipient of a confidential transfer must be different accounts.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ESELF_TRANSFER">ESELF_TRANSFER</a>: u64 = 26;
</code></pre>



<a id="0x1_confidential_asset_ETOKEN_DISABLED"></a>

The token is not allowed for confidential transfers.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>: u64 = 13;
</code></pre>



<a id="0x1_confidential_asset_ETOKEN_ENABLED"></a>

The token is already allowed for confidential transfers.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_ENABLED">ETOKEN_ENABLED</a>: u64 = 12;
</code></pre>



<a id="0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA"></a>

Dispatchable fungible asset types (those with custom withdraw, deposit, balance, or
supply hooks) are not yet supported in confidential transfers.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>: u64 = 19;
</code></pre>



<a id="0x1_confidential_asset_MAINNET_CHAIN_ID"></a>

The Movement mainnet chain ID. If the chain ID is 126, the allow list is enabled.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_MAINNET_CHAIN_ID">MAINNET_CHAIN_ID</a>: u8 = 126;
</code></pre>



<a id="0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES"></a>

Maximum length (bytes) of the opaque <code>sender_auditor_hint</code> passed to [<code>confidential_transfer</code>].


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a>: u64 = 256;
</code></pre>



<a id="0x1_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER"></a>

The maximum number of transactions can be aggregated on the pending balance before rollover is required.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER">MAX_TRANSFERS_BEFORE_ROLLOVER</a>: u64 = 65534;
</code></pre>



<a id="0x1_confidential_asset_init_module"></a>

## Function `init_module`

Runs when CA is first published onto an already-live network (governance framework upgrade).
Does not run at genesis — genesis calls <code>initialize</code> directly (see <code><a href="genesis.md#0x1_genesis_initialize">genesis::initialize</a></code>).


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_init_module">init_module</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_init_module">init_module</a>(deployer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="confidential_asset.md#0x1_confidential_asset_initialize">initialize</a>(deployer)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_initialize"></a>

## Function `initialize`

Publishes the chain-level <code><a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a></code>. Invoked at genesis via <code><a href="genesis.md#0x1_genesis_initialize">genesis::initialize</a></code>, and on
a first-time governance publish via <code>init_module</code>. Idempotent: aborts if already initialized.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_initialize">initialize</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);
    <b>assert</b>!(
        !<b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_INITIALIZED">EALREADY_INITIALIZED</a>)
    );
    <b>assert</b>!(
        bulletproofs::get_max_range_bits() &gt;= <a href="confidential_proof.md#0x1_confidential_proof_get_bulletproofs_num_bits">confidential_proof::get_bulletproofs_num_bits</a>(),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_internal">error::internal</a>(<a href="confidential_asset.md#0x1_confidential_asset_ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE">ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE</a>)
    );

    <b>let</b> deployer_address = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(aptos_framework);

    <b>let</b> global_config_ctor_ref = &<a href="object.md#0x1_object_create_object">object::create_object</a>(deployer_address);

    <b>move_to</b>(aptos_framework, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
        allow_list_enabled: <a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() == <a href="confidential_asset.md#0x1_confidential_asset_MAINNET_CHAIN_ID">MAINNET_CHAIN_ID</a>,
        extend_ref: <a href="object.md#0x1_object_generate_extend_ref">object::generate_extend_ref</a>(global_config_ctor_ref),
        chain_auditor_ek: std::option::none(),
        chain_auditor_epoch: 0,
        chain_auditor_admin: std::option::none(),
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_register"></a>

## Function `register`

Registers an account for a specified token. Users must register an account for each token they
intend to transact with.

Users are also responsible for generating a Twisted ElGamal key pair on their side.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register">register</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register">register</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>let</b> ek = twisted_elgamal::new_pubkey_from_bytes(ek).extract();

    // Verify registration proof (ZKPoK of decryption key)
    <b>let</b> cid = (<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() <b>as</b> u8);
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <a href="confidential_proof.md#0x1_confidential_proof_verify_registration_proof">confidential_proof::verify_registration_proof</a>(
        cid,
        user,
        @aptos_framework,
        &ek,
        <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        registration_proof_commitment,
        registration_proof_response
    );

    <a href="confidential_asset.md#0x1_confidential_asset_register_internal">register_internal</a>(sender, token, ek);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance"></a>

## Function `register_and_deposit_and_rollover_pending_balance`

Atomically [<code>register</code>], [<code>deposit</code>], and [<code>rollover_pending_balance</code>] for first-time users — public
FA lands as spendable confidential (actual) balance in one tx. Aborts with
[<code><a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_ALREADY_PUBLISHED">ECA_STORE_ALREADY_PUBLISHED</a></code>] if the sender is already registered.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance">register_and_deposit_and_rollover_pending_balance</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64, ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance">register_and_deposit_and_rollover_pending_balance</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    amount: u64,
    ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    // The fresh store created by `register` is `normalized = <b>true</b>` <b>with</b> empty actual_balance,
    // so `deposit_and_rollover_pending_balance`'s normalized-state assertion passes — no need
    // for a separate normalize step here.
    <a href="confidential_asset.md#0x1_confidential_asset_register">register</a>(sender, token, ek, registration_proof_commitment, registration_proof_response);
    <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_rollover_pending_balance">deposit_and_rollover_pending_balance</a>(sender, token, amount);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_and_rollover_pending_balance"></a>

## Function `deposit_and_rollover_pending_balance`

Atomically [<code>deposit</code>] and [<code>rollover_pending_balance</code>] when the sender's actual balance is already
normalized — no proofs needed. Aborts with [<code><a href="confidential_asset.md#0x1_confidential_asset_ENORMALIZATION_REQUIRED">ENORMALIZATION_REQUIRED</a></code>] otherwise; use
[<code>deposit_and_normalize_and_rollover_pending_balance</code>] in that case.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_rollover_pending_balance">deposit_and_rollover_pending_balance</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_rollover_pending_balance">deposit_and_rollover_pending_balance</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, user, amount);
    <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance"></a>

## Function `deposit_and_normalize_and_rollover_pending_balance`

Atomically [<code>deposit</code>], [<code>normalize</code>] the actual balance, and [<code>rollover_pending_balance</code>] when the
sender's actual balance is NOT normalized. Same proof arguments as [<code>normalize</code>]. Aborts with
[<code><a href="confidential_asset.md#0x1_confidential_asset_EALREADY_NORMALIZED">EALREADY_NORMALIZED</a></code>] if already normalized; use [<code>deposit_and_rollover_pending_balance</code>] then.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance">deposit_and_normalize_and_rollover_pending_balance</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance">deposit_and_normalize_and_rollover_pending_balance</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    amount: u64,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_normalization_proof">confidential_proof::deserialize_normalization_proof</a>(sigma_proof, zkrp_new_balance).extract();

    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, user, amount);
    <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(sender, token, new_balance, proof);
    <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_to"></a>

## Function `deposit_to`

Brings tokens into the protocol, transferring the passed amount from the sender's primary FA store
to the pending balance of the recipient.
The initial confidential balance is publicly visible, as entering the protocol requires a normal transfer.
However, tokens within the protocol become obfuscated through confidential transfers, ensuring privacy in
subsequent transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to">deposit_to</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to">deposit_to</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, <b>to</b>, amount)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit"></a>

## Function `deposit`

The same as <code>deposit_to</code>, but the recipient is the sender.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit">deposit</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit">deposit</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender), amount)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_coins_to"></a>

## Function `deposit_coins_to`

The same as <code>deposit_to</code>, but converts coins to missing FA first.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins_to">deposit_coins_to</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins_to">deposit_coins_to</a>&lt;CoinType&gt;(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <b>to</b>: <b>address</b>,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>let</b> token = <a href="confidential_asset.md#0x1_confidential_asset_ensure_sufficient_fa">ensure_sufficient_fa</a>&lt;CoinType&gt;(sender, amount).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, <b>to</b>, amount)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_coins"></a>

## Function `deposit_coins`

The same as <code>deposit</code>, but converts coins to missing FA first.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins">deposit_coins</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins">deposit_coins</a>&lt;CoinType&gt;(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>let</b> token = <a href="confidential_asset.md#0x1_confidential_asset_ensure_sufficient_fa">ensure_sufficient_fa</a>&lt;CoinType&gt;(sender, amount).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender, token, <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender), amount)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw_to"></a>

## Function `withdraw_to`

Brings tokens out of the protocol by transferring the specified amount from the sender's actual balance to
the recipient's primary FA store.
The withdrawn amount is publicly visible, as this process requires a normal transfer.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to">withdraw_to</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to">withdraw_to</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    amount: u64,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_withdrawal_proof">confidential_proof::deserialize_withdrawal_proof</a>(sigma_proof, zkrp_new_balance).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(sender, token, <b>to</b>, amount, new_balance, proof);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw"></a>

## Function `withdraw`

The same as <code>withdraw_to</code>, but the recipient is the sender.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw">withdraw</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, amount: u64, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw">withdraw</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    amount: u64,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to">withdraw_to</a>(
        sender,
        token,
        <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender),
        amount,
        new_balance,
        zkrp_new_balance,
        sigma_proof
    )
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_transfer"></a>

## Function `confidential_transfer`

Transfers tokens from the sender's actual balance to the recipient's pending balance.
The function hides the transferred amount while keeping the sender and recipient addresses visible.
The sender encrypts the transferred amount with the recipient's encryption key and the function updates the
recipient's confidential balance homomorphically.
Additionally, the sender encrypts the transferred amount with each auditor's EK, allowing auditors to decrypt
it on their side. The combined auditor list (<code>auditor_eks</code> / <code>auditor_amounts</code>) has a fixed prefix layout:

```text
[0]   chain-level compliance auditor (always required; configured via <code>set_chain_auditor</code>)
[1]   asset-specific auditor         (required iff <code><a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(token).is_some()</code>)
[2..] voluntary auditors             (sender's choice; ordered)
```

Aborts with [<code><a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET">ECHAIN_AUDITOR_NOT_SET</a></code>] when the chain-level auditor has not yet been configured.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.

<code>sender_auditor_hint</code> is emitted on [<code><a href="confidential_asset.md#0x1_confidential_asset_Transferred">Transferred</a></code>] and is **bound into the transfer sigma Fiat–Shamir
transcript** (must match the hint used when generating the proof). Length must not exceed
[<code><a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a></code>].


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer">confidential_transfer</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sender_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, recipient_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_transfer_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer">confidential_transfer</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sender_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    recipient_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_transfer_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> sender_amount = <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_from_bytes">confidential_balance::new_pending_balance_from_bytes</a>(sender_amount).extract();
    <b>let</b> recipient_amount = <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_from_bytes">confidential_balance::new_pending_balance_from_bytes</a>(recipient_amount).extract();
    <b>let</b> auditor_eks = <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_eks">deserialize_auditor_eks</a>(auditor_eks).extract();
    <b>let</b> auditor_amounts = <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_amounts">deserialize_auditor_amounts</a>(auditor_amounts).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_transfer_proof">confidential_proof::deserialize_transfer_proof</a>(
        sigma_proof,
        zkrp_new_balance,
        zkrp_transfer_amount
    ).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(
        sender,
        token,
        <b>to</b>,
        new_balance,
        sender_amount,
        recipient_amount,
        auditor_eks,
        auditor_amounts,
        proof,
        sender_auditor_hint
    )
}
</code></pre>



</details>

<a id="0x1_confidential_asset_max_sender_auditor_hint_bytes"></a>

## Function `max_sender_auditor_hint_bytes`

Returns the maximum allowed <code>sender_auditor_hint</code> length for [<code>confidential_transfer</code>].


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_max_sender_auditor_hint_bytes">max_sender_auditor_hint_bytes</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_max_sender_auditor_hint_bytes">max_sender_auditor_hint_bytes</a>(): u64 {
    <a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a>
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key"></a>

## Function `rotate_encryption_key`

Rotates the encryption key for the user's confidential balance, updating it to a new encryption key.
The function ensures that the pending balance is zero before the key rotation, requiring the sender to
call <code>rollover_pending_balance_and_freeze</code> beforehand if necessary.
The sender provides their new normalized confidential balance, encrypted with the new encryption key and fresh randomness
to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> new_ek = twisted_elgamal::new_pubkey_from_bytes(new_ek).extract();
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_rotation_proof">confidential_proof::deserialize_rotation_proof</a>(sigma_proof, zkrp_new_balance).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(sender, token, new_ek, new_balance, proof);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize"></a>

## Function `normalize`

Adjusts each chunk to fit into defined 16-bit bounds to prevent overflows.
Most functions perform implicit normalization by accepting a new normalized confidential balance as a parameter.
However, explicit normalization is required before rolling over the pending balance, as multiple rolls may cause
chunk overflows.
The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize">normalize</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize">normalize</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_normalization_proof">confidential_proof::deserialize_normalization_proof</a>(sigma_proof, zkrp_new_balance).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(sender, token, new_balance, proof);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_freeze_token"></a>

## Function `freeze_token`

Freezes the confidential account for the specified token, disabling all incoming transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token">freeze_token</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token">freeze_token</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> {
    <a href="confidential_asset.md#0x1_confidential_asset_freeze_token_internal">freeze_token_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_unfreeze_token"></a>

## Function `unfreeze_token`

Unfreezes the confidential account for the specified token, re-enabling incoming transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token">unfreeze_token</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token">unfreeze_token</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> {
    <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance"></a>

## Function `rollover_pending_balance`

Adds the pending balance to the actual balance for the specified token, resetting the pending balance to zero.
This operation is necessary to use tokens from the pending balance for outgoing transactions.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize_and_rollover_pending_balance"></a>

## Function `normalize_and_rollover_pending_balance`

Atomically [<code>normalize</code>] the actual balance and [<code>rollover_pending_balance</code>] in one transaction. Takes the
same proof arguments as [<code>normalize</code>].


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_and_rollover_pending_balance">normalize_and_rollover_pending_balance</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_and_rollover_pending_balance">normalize_and_rollover_pending_balance</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> new_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_actual_balance_from_bytes">confidential_balance::new_actual_balance_from_bytes</a>(new_balance).extract();
    <b>let</b> proof = <a href="confidential_proof.md#0x1_confidential_proof_deserialize_normalization_proof">confidential_proof::deserialize_normalization_proof</a>(sigma_proof, zkrp_new_balance).extract();

    <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(sender, token, new_balance, proof);
    <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance_and_freeze"></a>

## Function `rollover_pending_balance_and_freeze`

Before calling <code>rotate_encryption_key</code>, we need to rollover the pending balance and freeze the token to prevent
any new payments being come.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_and_freeze">rollover_pending_balance_and_freeze</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_and_freeze">rollover_pending_balance_and_freeze</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(sender, token);
    <a href="confidential_asset.md#0x1_confidential_asset_freeze_token">freeze_token</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key_and_unfreeze"></a>

## Function `rotate_encryption_key_and_unfreeze`

After rotating the encryption key, we may want to unfreeze the token to allow payments.
This function facilitates making both calls in a single transaction.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_and_unfreeze">rotate_encryption_key_and_unfreeze</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, new_confidential_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, rotate_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_and_unfreeze">rotate_encryption_key_and_unfreeze</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    new_confidential_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    rotate_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(sender, token, new_ek, new_confidential_balance, zkrp_new_balance, rotate_proof);
    <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token">unfreeze_token</a>(sender, token);
}
</code></pre>



</details>

<a id="0x1_confidential_asset_enable_allow_list"></a>

## Function `enable_allow_list`

Enables the allow list, restricting confidential transfers to tokens on the allow list.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_allow_list">enable_allow_list</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_allow_list">enable_allow_list</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    <b>let</b> global_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework);

    <b>assert</b>!(!global_config.allow_list_enabled, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALLOW_LIST_ENABLED">EALLOW_LIST_ENABLED</a>));

    global_config.allow_list_enabled = <b>true</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_AllowListChanged">AllowListChanged</a> { enabled: <b>true</b> });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_disable_allow_list"></a>

## Function `disable_allow_list`

Disables the allow list, allowing confidential transfers for all tokens.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_allow_list">disable_allow_list</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_allow_list">disable_allow_list</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    <b>let</b> global_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework);

    <b>assert</b>!(global_config.allow_list_enabled, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALLOW_LIST_DISABLED">EALLOW_LIST_DISABLED</a>));

    global_config.allow_list_enabled = <b>false</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_AllowListChanged">AllowListChanged</a> { enabled: <b>false</b> });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_enable_token"></a>

## Function `enable_token`

Enables confidential transfers for the specified token.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_token">enable_token</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_token">enable_token</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    <b>let</b> fa_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_ensure_fa_config_exists">ensure_fa_config_exists</a>(token));

    <b>assert</b>!(!fa_config.allowed, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_ENABLED">ETOKEN_ENABLED</a>));

    fa_config.allowed = <b>true</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_TokenAllowChanged">TokenAllowChanged</a> {
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        allowed: <b>true</b>,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_disable_token"></a>

## Function `disable_token`

Disables confidential transfers for the specified token.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_token">disable_token</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_token">disable_token</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    <b>let</b> fa_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_ensure_fa_config_exists">ensure_fa_config_exists</a>(token));

    <b>assert</b>!(fa_config.allowed, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>));

    fa_config.allowed = <b>false</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_TokenAllowChanged">TokenAllowChanged</a> {
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        allowed: <b>false</b>,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_asset_auditor"></a>

## Function `set_asset_auditor`

Sets, rotates, or clears the asset-specific auditor key for <code>token</code>. Pass an empty
<code>new_auditor_ek</code> to clear. Bumps <code>asset_auditor_epoch</code> and emits [<code><a href="confidential_asset.md#0x1_confidential_asset_AssetAuditorChanged">AssetAuditorChanged</a></code>].

Callable by <code><a href="object.md#0x1_object_root_owner">object::root_owner</a>(token)</code>; aborts with [<code><a href="confidential_asset.md#0x1_confidential_asset_ENOT_ASSET_ISSUER">ENOT_ASSET_ISSUER</a></code>] otherwise.
Rotation invalidates pending transfer proofs (auditor key is bound into the
Fiat–Shamir transcript) — senders must regenerate against the new key.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_asset_auditor">set_asset_auditor</a>(issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_asset_auditor">set_asset_auditor</a>(
    issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>assert</b>!(
        <a href="object.md#0x1_object_root_owner">object::root_owner</a>(token) == <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(issuer),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENOT_ASSET_ISSUER">ENOT_ASSET_ISSUER</a>)
    );

    <b>let</b> fa_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_ensure_fa_config_exists">ensure_fa_config_exists</a>(token));

    <b>let</b> new_ek_opt = <b>if</b> (new_auditor_ek.length() == 0) {
        std::option::none()
    } <b>else</b> {
        <b>let</b> parsed = twisted_elgamal::new_pubkey_from_bytes(new_auditor_ek);
        <b>assert</b>!(parsed.is_some(), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED">EAUDITOR_EK_DESERIALIZATION_FAILED</a>));
        parsed
    };

    <b>let</b> new_epoch = fa_config.asset_auditor_epoch + 1;

    fa_config.asset_auditor_ek = new_ek_opt;
    fa_config.asset_auditor_epoch = new_epoch;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_AssetAuditorChanged">AssetAuditorChanged</a> {
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        new_asset_auditor_ek: fa_config.asset_auditor_ek,
        new_epoch,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_chain_auditor_admin"></a>

## Function `set_chain_auditor_admin`

Designates (or rotates) the account authorized to call [<code>set_chain_auditor</code>].
Governance-only. No clear form — rotate to a successor instead.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor_admin">set_chain_auditor_admin</a>(aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_admin: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor_admin">set_chain_auditor_admin</a>(
    aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    new_admin: <b>address</b>) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <a href="system_addresses.md#0x1_system_addresses_assert_aptos_framework">system_addresses::assert_aptos_framework</a>(aptos_framework);

    <b>let</b> global_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework);
    global_config.chain_auditor_admin = std::option::some(new_admin);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_ChainAuditorAdminChanged">ChainAuditorAdminChanged</a> { new_admin });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_chain_auditor"></a>

## Function `set_chain_auditor`

Sets, rotates, or clears the chain-level auditor key. Pass an empty
<code>new_chain_auditor_ek</code> to clear (which disables all confidential transfers until a
successor is set). Bumps <code>chain_auditor_epoch</code> and emits [<code><a href="confidential_asset.md#0x1_confidential_asset_ChainAuditorChanged">ChainAuditorChanged</a></code>].

Callable only by [<code><a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>.chain_auditor_admin</code>]. Aborts with
[<code><a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_ADMIN_NOT_SET">ECHAIN_AUDITOR_ADMIN_NOT_SET</a></code>] before an admin is assigned, or
[<code><a href="confidential_asset.md#0x1_confidential_asset_ENOT_CHAIN_AUDITOR_ADMIN">ENOT_CHAIN_AUDITOR_ADMIN</a></code>] for any other signer. Rotation invalidates pending
transfer proofs — see [<code>set_asset_auditor</code>].


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor">set_chain_auditor</a>(admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor">set_chain_auditor</a>(
    admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    new_chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>let</b> global_config = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework);

    <b>assert</b>!(
        global_config.chain_auditor_admin.is_some(),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_ADMIN_NOT_SET">ECHAIN_AUDITOR_ADMIN_NOT_SET</a>)
    );
    <b>assert</b>!(
        *global_config.chain_auditor_admin.borrow() == <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(admin),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_permission_denied">error::permission_denied</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENOT_CHAIN_AUDITOR_ADMIN">ENOT_CHAIN_AUDITOR_ADMIN</a>)
    );

    <b>let</b> new_ek_opt = <b>if</b> (new_chain_auditor_ek.length() == 0) {
        std::option::none()
    } <b>else</b> {
        <b>let</b> parsed = twisted_elgamal::new_pubkey_from_bytes(new_chain_auditor_ek);
        <b>assert</b>!(parsed.is_some(), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EAUDITOR_EK_DESERIALIZATION_FAILED">EAUDITOR_EK_DESERIALIZATION_FAILED</a>));
        parsed
    };

    <b>let</b> new_epoch = global_config.chain_auditor_epoch + 1;

    global_config.chain_auditor_ek = new_ek_opt;
    global_config.chain_auditor_epoch = new_epoch;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_ChainAuditorChanged">ChainAuditorChanged</a> {
        new_chain_auditor_ek: global_config.chain_auditor_ek,
        new_epoch,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_has_confidential_asset_store"></a>

## Function `has_confidential_asset_store`

Checks if the user has a confidential asset store for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user: <b>address</b>, token: Object&lt;Metadata&gt;): bool {
    <b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_token_allowed"></a>

## Function `is_token_allowed`

Checks if the token is allowed for confidential transfers.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(token: Object&lt;Metadata&gt;): bool <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a> {
    <b>if</b> (!<a href="confidential_asset.md#0x1_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>()) {
        <b>return</b> <b>true</b>
    };

    <b>let</b> fa_config_address = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token);

    <b>if</b> (!<b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address)) {
        <b>return</b> <b>false</b>
    };

    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address).allowed
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_allow_list_enabled"></a>

## Function `is_allow_list_enabled`

Checks if the allow list is enabled.
If the allow list is enabled, only tokens from the allow list can be transferred.
Otherwise, all tokens are allowed.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>(): bool <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).allow_list_enabled
}
</code></pre>



</details>

<a id="0x1_confidential_asset_pending_balance"></a>

## Function `pending_balance`

Returns the pending balance of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_pending_balance">pending_balance</a>(owner: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_pending_balance">pending_balance</a>(
    owner: <b>address</b>,
    token: Object&lt;Metadata&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(owner, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>let</b> ca_store = <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(owner, token));

    ca_store.pending_balance
}
</code></pre>



</details>

<a id="0x1_confidential_asset_actual_balance"></a>

## Function `actual_balance`

Returns the actual balance of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_actual_balance">actual_balance</a>(owner: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_actual_balance">actual_balance</a>(
    owner: <b>address</b>,
    token: Object&lt;Metadata&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(owner, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>let</b> ca_store = <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(owner, token));

    ca_store.actual_balance
}
</code></pre>



</details>

<a id="0x1_confidential_asset_encryption_key"></a>

## Function `encryption_key`

Returns the encryption key (EK) of the user for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(user: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(
    user: <b>address</b>,
    token: Object&lt;Metadata&gt;): twisted_elgamal::CompressedPubkey <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token)).ek
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_normalized"></a>

## Function `is_normalized`

Checks if the user's actual balance is normalized for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_normalized">is_normalized</a>(user: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_normalized">is_normalized</a>(user: <b>address</b>, token: Object&lt;Metadata&gt;): bool <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> {
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token)).normalized
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_frozen"></a>

## Function `is_frozen`

Checks if the user's confidential asset store is frozen for the specified token.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(user: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(user: <b>address</b>, token: Object&lt;Metadata&gt;): bool <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> {
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token)).frozen
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_asset_auditor"></a>

## Function `get_asset_auditor`

Asset auditor encryption key for <code>token</code>, or <code>None</code> if unset.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(
    token: Object&lt;Metadata&gt;): Option&lt;twisted_elgamal::CompressedPubkey&gt; <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>let</b> fa_config_address = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token);

    <b>if</b> (!<b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address)) {
        <b>return</b> std::option::none();
    };

    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address).asset_auditor_ek
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_asset_auditor_epoch"></a>

## Function `get_asset_auditor_epoch`

Asset auditor epoch for <code>token</code>. <code>0</code> if no asset auditor has been set.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor_epoch">get_asset_auditor_epoch</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor_epoch">get_asset_auditor_epoch</a>(token: Object&lt;Metadata&gt;): u64 <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>let</b> fa_config_address = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token);
    <b>if</b> (!<b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address)) {
        <b>return</b> 0;
    };
    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address).asset_auditor_epoch
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor"></a>

## Function `get_chain_auditor`

Chain auditor encryption key, or <code>None</code> if unset.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor">get_chain_auditor</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor">get_chain_auditor</a>(): Option&lt;twisted_elgamal::CompressedPubkey&gt; <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).chain_auditor_ek
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor_epoch"></a>

## Function `get_chain_auditor_epoch`

Chain auditor epoch. <code>0</code> before any chain auditor has been configured.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_epoch">get_chain_auditor_epoch</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_epoch">get_chain_auditor_epoch</a>(): u64 <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).chain_auditor_epoch
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor_admin"></a>

## Function `get_chain_auditor_admin`

Chain-auditor admin address, or <code>None</code> if governance hasn't assigned one yet.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_admin">get_chain_auditor_admin</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_admin">get_chain_auditor_admin</a>(): Option&lt;<b>address</b>&gt; <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).chain_auditor_admin
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_asset_balance"></a>

## Function `confidential_asset_balance`

Returns the circulating supply of the confidential asset.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_asset_balance">confidential_asset_balance</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_asset_balance">confidential_asset_balance</a>(token: Object&lt;Metadata&gt;): u64 <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="fungible_asset.md#0x1_fungible_asset_balance">fungible_asset::balance</a>(<a href="confidential_asset.md#0x1_confidential_asset_get_pool_fa_store">get_pool_fa_store</a>(token))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_register_internal"></a>

## Function `register_internal`

Implementation of the <code>register</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_internal">register_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_internal">register_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    ek: twisted_elgamal::CompressedPubkey) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(&token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>));
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>));

    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>assert</b>!(!<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_ALREADY_PUBLISHED">ECA_STORE_ALREADY_PUBLISHED</a>));

    <b>let</b> ca_store = <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> {
        frozen: <b>false</b>,
        normalized: <b>true</b>,
        pending_counter: 0,
        pending_balance: <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_pending_balance_no_randomness">confidential_balance::new_compressed_pending_balance_no_randomness</a>(),
        actual_balance: <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_actual_balance_no_randomness">confidential_balance::new_compressed_actual_balance_no_randomness</a>(),
        ek,
    };

    <b>move_to</b>(&<a href="confidential_asset.md#0x1_confidential_asset_get_user_signer">get_user_signer</a>(sender, token), ca_store);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_Registered">Registered</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        ek,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_to_internal"></a>

## Function `deposit_to_internal`

Implementation of the <code>deposit_to</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    amount: u64) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(&token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>));
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>));
    <b>assert</b>!(!<a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(<b>to</b>, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_FROZEN">EALREADY_FROZEN</a>));
    // A zero deposit moves no funds but still consumes one of the recipient's
    // `<a href="confidential_asset.md#0x1_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER">MAX_TRANSFERS_BEFORE_ROLLOVER</a>` pending slots, letting anyone force rollovers on them.
    <b>assert</b>!(amount &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EZERO_AMOUNT">EZERO_AMOUNT</a>));

    <b>let</b> from = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>let</b> pool_fa_store = <a href="confidential_asset.md#0x1_confidential_asset_ensure_pool_fa_store">ensure_pool_fa_store</a>(token);

    <b>let</b> pool_before = <a href="fungible_asset.md#0x1_fungible_asset_balance">fungible_asset::balance</a>(pool_fa_store);
    <b>let</b> sender_fa_store = <a href="primary_fungible_store.md#0x1_primary_fungible_store_primary_store">primary_fungible_store::primary_store</a>(from, token);
    <a href="dispatchable_fungible_asset.md#0x1_dispatchable_fungible_asset_transfer">dispatchable_fungible_asset::transfer</a>(sender, sender_fa_store, pool_fa_store, amount);

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(<b>to</b>, token));
    <b>let</b> pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.pending_balance);

    <a href="confidential_balance.md#0x1_confidential_balance_add_balances_mut">confidential_balance::add_balances_mut</a>(
        &<b>mut</b> pending_balance,
        &<a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_u64_no_randonmess">confidential_balance::new_pending_balance_u64_no_randonmess</a>(amount)
    );

    ca_store.pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&pending_balance);

    <b>assert</b>!(
        ca_store.pending_counter &lt; <a href="confidential_asset.md#0x1_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER">MAX_TRANSFERS_BEFORE_ROLLOVER</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EINTERNAL_ERROR">EINTERNAL_ERROR</a>)
    );

    ca_store.pending_counter += 1;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_Deposited">Deposited</a> {
        from,
        <b>to</b>,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        amount,
        new_pending_balance: ca_store.pending_balance,
    });

    <b>assert</b>!(
        amount == <a href="fungible_asset.md#0x1_fungible_asset_balance">fungible_asset::balance</a>(pool_fa_store) - pool_before,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>)
    );
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw_to_internal"></a>

## Function `withdraw_to_internal`

Implementation of the <code>withdraw_to</code> entry function.
Withdrawals are always allowed, regardless of the token allow status.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, amount: u64, new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    amount: u64,
    new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    proof: WithdrawalProof) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(&token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>));
    // A zero withdrawal would re-randomize the actual balance and mark it normalized,
    // acting <b>as</b> a `normalize` that skips the `<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_NORMALIZED">EALREADY_NORMALIZED</a>` guard.
    <b>assert</b>!(amount &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EZERO_AMOUNT">EZERO_AMOUNT</a>));

    <b>let</b> from = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>let</b> sender_ek = <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(from, token);

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(from, token));
    <b>let</b> current_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.actual_balance);

    <b>let</b> cid = (<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() <b>as</b> u8);
    <a href="confidential_proof.md#0x1_confidential_proof_verify_withdrawal_proof">confidential_proof::verify_withdrawal_proof</a>(
        cid,
        from,
        @aptos_framework,
        <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        &sender_ek,
        amount,
        &current_balance,
        &new_balance,
        &proof
    );

    ca_store.normalized = <b>true</b>;
    ca_store.actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&new_balance);

    <b>let</b> pool_fa_store = <a href="confidential_asset.md#0x1_confidential_asset_get_pool_fa_store">get_pool_fa_store</a>(token);
    <b>let</b> pool_before = <a href="fungible_asset.md#0x1_fungible_asset_balance">fungible_asset::balance</a>(pool_fa_store);
    <b>let</b> recipient_fa_store = <a href="primary_fungible_store.md#0x1_primary_fungible_store_ensure_primary_store_exists">primary_fungible_store::ensure_primary_store_exists</a>(<b>to</b>, token);
    <a href="dispatchable_fungible_asset.md#0x1_dispatchable_fungible_asset_transfer">dispatchable_fungible_asset::transfer</a>(&<a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_signer">get_fa_store_signer</a>(), pool_fa_store, recipient_fa_store, amount);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_Withdrawn">Withdrawn</a> {
        from,
        <b>to</b>,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        amount,
        new_available_balance: ca_store.actual_balance,
    });

    <b>assert</b>!(
        amount == pool_before - <a href="fungible_asset.md#0x1_fungible_asset_balance">fungible_asset::balance</a>(pool_fa_store),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>)
    );
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_transfer_internal"></a>

## Function `confidential_transfer_internal`

Implementation of the <code>confidential_transfer</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, <b>to</b>: <b>address</b>, new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, sender_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, recipient_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, proof: <a href="confidential_proof.md#0x1_confidential_proof_TransferProof">confidential_proof::TransferProof</a>, sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    <b>to</b>: <b>address</b>,
    new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    sender_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    recipient_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;,
    auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;,
    proof: TransferProof,
    sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender) != <b>to</b>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_ESELF_TRANSFER">ESELF_TRANSFER</a>));
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(&token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EUNSAFE_DISPATCHABLE_FA">EUNSAFE_DISPATCHABLE_FA</a>));
    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_ETOKEN_DISABLED">ETOKEN_DISABLED</a>));
    <b>assert</b>!(!<a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(<b>to</b>, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_FROZEN">EALREADY_FROZEN</a>));
    <b>assert</b>!(
        <a href="confidential_asset.md#0x1_confidential_asset_validate_auditors">validate_auditors</a>(token, &recipient_amount, &auditor_eks, &auditor_amounts, &proof),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EINVALID_AUDITORS">EINVALID_AUDITORS</a>)
    );
    <b>assert</b>!(
        <a href="confidential_balance.md#0x1_confidential_balance_balance_c_equals">confidential_balance::balance_c_equals</a>(&sender_amount, &recipient_amount),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EINVALID_SENDER_AMOUNT">EINVALID_SENDER_AMOUNT</a>)
    );
    <b>assert</b>!(
        sender_auditor_hint.length() &lt;= <a href="confidential_asset.md#0x1_confidential_asset_MAX_SENDER_AUDITOR_HINT_BYTES">MAX_SENDER_AUDITOR_HINT_BYTES</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EAUDITOR_HINT_TOO_LONG">EAUDITOR_HINT_TOO_LONG</a>)
    );

    <b>let</b> from = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>let</b> sender_ek = <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(from, token);
    <b>let</b> recipient_ek = <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(<b>to</b>, token);

    <b>let</b> sender_ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(from, token));

    <b>let</b> sender_current_actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(
        &sender_ca_store.actual_balance
    );

    <b>let</b> cid = (<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() <b>as</b> u8);
    <a href="confidential_proof.md#0x1_confidential_proof_verify_transfer_proof">confidential_proof::verify_transfer_proof</a>(
        cid,
        from,
        @aptos_framework,
        <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        &sender_ek,
        &recipient_ek,
        &sender_current_actual_balance,
        &new_balance,
        &sender_amount,
        &recipient_amount,
        &auditor_eks,
        &auditor_amounts,
        &sender_auditor_hint,
        &proof);

    sender_ca_store.normalized = <b>true</b>;
    <b>let</b> new_sender_available_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&new_balance);
    sender_ca_store.actual_balance = new_sender_available_balance;

    <b>let</b> amount = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&recipient_amount);
    <b>let</b> ek_volun_auds = <a href="confidential_proof.md#0x1_confidential_proof_transfer_proof_ek_volun_auds_flat_bytes">confidential_proof::transfer_proof_ek_volun_auds_flat_bytes</a>(&proof);

    // Cannot create multiple mutable references <b>to</b> the same type, so we need <b>to</b> drop it
    <b>let</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a> { .. } = sender_ca_store;

    <b>let</b> recipient_ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(<b>to</b>, token));

    <b>assert</b>!(
        recipient_ca_store.pending_counter &lt; <a href="confidential_asset.md#0x1_confidential_asset_MAX_TRANSFERS_BEFORE_ROLLOVER">MAX_TRANSFERS_BEFORE_ROLLOVER</a>,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="confidential_asset.md#0x1_confidential_asset_EINTERNAL_ERROR">EINTERNAL_ERROR</a>)
    );

    <b>let</b> recipient_pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(
        &recipient_ca_store.pending_balance
    );
    <a href="confidential_balance.md#0x1_confidential_balance_add_balances_mut">confidential_balance::add_balances_mut</a>(&<b>mut</b> recipient_pending_balance, &recipient_amount);

    recipient_ca_store.pending_counter += 1;
    <b>let</b> new_recip_pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&recipient_pending_balance);
    recipient_ca_store.pending_balance = new_recip_pending_balance;

    <b>let</b> chain_auditor_epoch = <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).chain_auditor_epoch;
    <b>let</b> asset_auditor_epoch = <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor_epoch">get_asset_auditor_epoch</a>(token);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_Transferred">Transferred</a> {
        from,
        <b>to</b>,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        amount,
        ek_volun_auds,
        sender_auditor_hint,
        new_sender_available_balance,
        new_recip_pending_balance,
        memo: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
        chain_auditor_epoch,
        asset_auditor_epoch,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key_internal"></a>

## Function `rotate_encryption_key_internal`

Implementation of the <code>rotate_encryption_key</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x1_confidential_proof_RotationProof">confidential_proof::RotationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_ek: twisted_elgamal::CompressedPubkey,
    new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    proof: RotationProof) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>let</b> current_ek = <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(user, token);

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token));

    <b>let</b> pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.pending_balance);

    // We need <b>to</b> ensure that the pending balance is zero before rotating the key.
    // To guarantee this, the user must call `rollover_pending_balance_and_freeze` beforehand.
    <b>assert</b>!(<a href="confidential_balance.md#0x1_confidential_balance_is_zero_balance">confidential_balance::is_zero_balance</a>(&pending_balance), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENOT_ZERO_BALANCE">ENOT_ZERO_BALANCE</a>));

    <b>let</b> current_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.actual_balance);

    <b>let</b> cid = (<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() <b>as</b> u8);
    <a href="confidential_proof.md#0x1_confidential_proof_verify_rotation_proof">confidential_proof::verify_rotation_proof</a>(
        cid,
        user,
        @aptos_framework,
        <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        &current_ek,
        &new_ek,
        &current_balance,
        &new_balance,
        &proof
    );

    ca_store.ek = new_ek;
    // We don't need <b>to</b> <b>update</b> the pending balance here, <b>as</b> it <b>has</b> been asserted <b>to</b> be zero.
    ca_store.actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&new_balance);
    ca_store.normalized = <b>true</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_KeyRotated">KeyRotated</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        new_ek,
        new_available_balance: ca_store.actual_balance,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize_internal"></a>

## Function `normalize_internal`

Implementation of the <code>normalize</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, proof: <a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;,
    new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    proof: NormalizationProof) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>let</b> sender_ek = <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(user, token);

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token));

    <b>assert</b>!(!ca_store.normalized, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_NORMALIZED">EALREADY_NORMALIZED</a>));

    <b>let</b> current_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.actual_balance);

    <b>let</b> cid = (<a href="chain_id.md#0x1_chain_id_get">chain_id::get</a>() <b>as</b> u8);
    <a href="confidential_proof.md#0x1_confidential_proof_verify_normalization_proof">confidential_proof::verify_normalization_proof</a>(
        cid,
        user,
        @aptos_framework,
        <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        &sender_ek,
        &current_balance,
        &new_balance,
        &proof
    );

    ca_store.actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&new_balance);
    ca_store.normalized = <b>true</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_Normalized">Normalized</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        new_available_balance: ca_store.actual_balance,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance_internal"></a>

## Function `rollover_pending_balance_internal`

Implementation of the <code>rollover_pending_balance</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token));

    <b>assert</b>!(ca_store.normalized, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENORMALIZATION_REQUIRED">ENORMALIZATION_REQUIRED</a>));

    <b>let</b> actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.actual_balance);
    <b>let</b> pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_decompress_balance">confidential_balance::decompress_balance</a>(&ca_store.pending_balance);

    <a href="confidential_balance.md#0x1_confidential_balance_add_balances_mut">confidential_balance::add_balances_mut</a>(&<b>mut</b> actual_balance, &pending_balance);

    ca_store.normalized = <b>false</b>;
    ca_store.pending_counter = 0;
    ca_store.actual_balance = <a href="confidential_balance.md#0x1_confidential_balance_compress_balance">confidential_balance::compress_balance</a>(&actual_balance);
    ca_store.pending_balance = <a href="confidential_balance.md#0x1_confidential_balance_new_compressed_pending_balance_no_randomness">confidential_balance::new_compressed_pending_balance_no_randomness</a>();

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_RolledOver">RolledOver</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        new_available_balance: ca_store.actual_balance,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_freeze_token_internal"></a>

## Function `freeze_token_internal`

Implementation of the <code>freeze_token</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token_internal">freeze_token_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token_internal">freeze_token_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token));

    <b>assert</b>!(!ca_store.frozen, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_EALREADY_FROZEN">EALREADY_FROZEN</a>));

    ca_store.frozen = <b>true</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_FreezeChanged">FreezeChanged</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        frozen: <b>true</b>,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_unfreeze_token_internal"></a>

## Function `unfreeze_token_internal`

Implementation of the <code>unfreeze_token</code> entry function.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(
    sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    token: Object&lt;Metadata&gt;) <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>
{
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);

    <b>assert</b>!(<a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(user, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECA_STORE_NOT_PUBLISHED">ECA_STORE_NOT_PUBLISHED</a>));

    <b>let</b> ca_store = <b>borrow_global_mut</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a>&gt;(<a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user, token));

    <b>assert</b>!(ca_store.frozen, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENOT_FROZEN">ENOT_FROZEN</a>));

    ca_store.frozen = <b>false</b>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="confidential_asset.md#0x1_confidential_asset_FreezeChanged">FreezeChanged</a> {
        addr: user,
        asset_type: <a href="object.md#0x1_object_object_address">object::object_address</a>(&token),
        frozen: <b>false</b>,
    });
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_safe_for_confidentiality"></a>

## Function `is_safe_for_confidentiality`

Returns whether the given asset type is safe for use in confidential transfers.

Dispatchable fungible assets can override withdraw, deposit, balance, or supply
behaviour in ways that are incompatible with encrypted on-chain balances (e.g.,
fee-on-transfer tokens, rebasing balances, custom supply hooks). Until a safe
integration path exists, only standard (non-dispatchable) FA types are accepted.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(token: &<a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_safe_for_confidentiality">is_safe_for_confidentiality</a>(token: &Object&lt;Metadata&gt;): bool {
    !<a href="fungible_asset.md#0x1_fungible_asset_is_asset_type_dispatchable">fungible_asset::is_asset_type_dispatchable</a>(*token)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_ensure_fa_config_exists"></a>

## Function `ensure_fa_config_exists`

Ensures that the <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code> object exists for the specified token.
If the object does not exist, creates it.
Used only for internal purposes.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_fa_config_exists">ensure_fa_config_exists</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_fa_config_exists">ensure_fa_config_exists</a>(token: Object&lt;Metadata&gt;): <b>address</b> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>let</b> fa_config_address = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token);

    <b>if</b> (!<b>exists</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>&gt;(fa_config_address)) {
        <b>let</b> fa_config_singer = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_signer">get_fa_config_signer</a>(token);

        <b>move_to</b>(&fa_config_singer, <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a> {
            allowed: <b>false</b>,
            asset_auditor_ek: std::option::none(),
            asset_auditor_epoch: 0,
        });
    };

    fa_config_address
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_fa_store_signer"></a>

## Function `get_fa_store_signer`

Returns an object for handling all the FA primary stores, and returns a signer for it.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_signer">get_fa_store_signer</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_signer">get_fa_store_signer</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="object.md#0x1_object_generate_signer_for_extending">object::generate_signer_for_extending</a>(&<b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).extend_ref)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_fa_store_address"></a>

## Function `get_fa_store_address`

Returns the address that handles all the FA primary stores.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_address">get_fa_store_address</a>(): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_address">get_fa_store_address</a>(): <b>address</b> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="object.md#0x1_object_address_from_extend_ref">object::address_from_extend_ref</a>(&<b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).extend_ref)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_pool_fa_store"></a>

## Function `get_pool_fa_store`

Returns the pool's primary fungible store for the given token, aborting if it does not exist.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_pool_fa_store">get_pool_fa_store</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_FungibleStore">fungible_asset::FungibleStore</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_pool_fa_store">get_pool_fa_store</a>(token: Object&lt;Metadata&gt;): Object&lt;FungibleStore&gt; <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>let</b> pool_addr = <a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_address">get_fa_store_address</a>();
    <b>assert</b>!(<a href="primary_fungible_store.md#0x1_primary_fungible_store_primary_store_exists">primary_fungible_store::primary_store_exists</a>(pool_addr, token), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="confidential_asset.md#0x1_confidential_asset_ENO_CONFIDENTIAL_ASSET_POOL">ENO_CONFIDENTIAL_ASSET_POOL</a>));
    <a href="primary_fungible_store.md#0x1_primary_fungible_store_primary_store">primary_fungible_store::primary_store</a>(pool_addr, token)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_ensure_pool_fa_store"></a>

## Function `ensure_pool_fa_store`

Returns the pool's primary fungible store for the given token, creating it if necessary.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_pool_fa_store">ensure_pool_fa_store</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_FungibleStore">fungible_asset::FungibleStore</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_pool_fa_store">ensure_pool_fa_store</a>(token: Object&lt;Metadata&gt;): Object&lt;FungibleStore&gt; <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <a href="primary_fungible_store.md#0x1_primary_fungible_store_ensure_primary_store_exists">primary_fungible_store::ensure_primary_store_exists</a>(<a href="confidential_asset.md#0x1_confidential_asset_get_fa_store_address">get_fa_store_address</a>(), token)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_user_signer"></a>

## Function `get_user_signer`

Returns an object for handling the <code><a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code> and returns a signer for it.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_user_signer">get_user_signer</a>(user: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_user_signer">get_user_signer</a>(user: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, token: Object&lt;Metadata&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> {
    <b>let</b> user_ctor = &<a href="object.md#0x1_object_create_named_object">object::create_named_object</a>(user, <a href="confidential_asset.md#0x1_confidential_asset_construct_user_seed">construct_user_seed</a>(token));

    <a href="object.md#0x1_object_generate_signer">object::generate_signer</a>(user_ctor)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_user_address"></a>

## Function `get_user_address`

Returns the address that handles the user's <code><a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code> object for the specified user and token.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user: <b>address</b>, token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_user_address">get_user_address</a>(user: <b>address</b>, token: Object&lt;Metadata&gt;): <b>address</b> {
    <a href="object.md#0x1_object_create_object_address">object::create_object_address</a>(&user, <a href="confidential_asset.md#0x1_confidential_asset_construct_user_seed">construct_user_seed</a>(token))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_fa_config_signer"></a>

## Function `get_fa_config_signer`

Returns an object for handling the <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code>, and returns a signer for it.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_signer">get_fa_config_signer</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_signer">get_fa_config_signer</a>(token: Object&lt;Metadata&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>let</b> fa_ext = &<b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).extend_ref;
    <b>let</b> fa_ext_signer = <a href="object.md#0x1_object_generate_signer_for_extending">object::generate_signer_for_extending</a>(fa_ext);

    <b>let</b> fa_ctor = &<a href="object.md#0x1_object_create_named_object">object::create_named_object</a>(&fa_ext_signer, <a href="confidential_asset.md#0x1_confidential_asset_construct_fa_seed">construct_fa_seed</a>(token));

    <a href="object.md#0x1_object_generate_signer">object::generate_signer</a>(fa_ctor)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_fa_config_address"></a>

## Function `get_fa_config_address`

Returns the address that handles primary FA store and <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code> objects for the specified token.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_fa_config_address">get_fa_config_address</a>(token: Object&lt;Metadata&gt;): <b>address</b> <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a> {
    <b>let</b> fa_ext = &<b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).extend_ref;
    <b>let</b> fa_ext_address = <a href="object.md#0x1_object_address_from_extend_ref">object::address_from_extend_ref</a>(fa_ext);

    <a href="object.md#0x1_object_create_object_address">object::create_object_address</a>(&fa_ext_address, <a href="confidential_asset.md#0x1_confidential_asset_construct_fa_seed">construct_fa_seed</a>(token))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_construct_user_seed"></a>

## Function `construct_user_seed`

Constructs a unique seed for the user's <code><a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code> object.
As all the <code><a href="confidential_asset.md#0x1_confidential_asset_ConfidentialAssetStore">ConfidentialAssetStore</a></code>'s have the same type, we need to differentiate them by the seed.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_construct_user_seed">construct_user_seed</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_construct_user_seed">construct_user_seed</a>(token: Object&lt;Metadata&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(
        &<a href="../../aptos-stdlib/doc/string_utils.md#0x1_string_utils_format2">string_utils::format2</a>(
            &b"<a href="confidential_asset.md#0x1_confidential_asset">confidential_asset</a>::{}::token::{}::user",
            @aptos_framework,
            <a href="object.md#0x1_object_object_address">object::object_address</a>(&token)
        )
    )
}
</code></pre>



</details>

<a id="0x1_confidential_asset_construct_fa_seed"></a>

## Function `construct_fa_seed`

Constructs a unique seed for the FA's <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code> object.
As all the <code><a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a></code>'s have the same type, we need to differentiate them by the seed.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_construct_fa_seed">construct_fa_seed</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_construct_fa_seed">construct_fa_seed</a>(token: Object&lt;Metadata&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(
        &<a href="../../aptos-stdlib/doc/string_utils.md#0x1_string_utils_format2">string_utils::format2</a>(
            &b"<a href="confidential_asset.md#0x1_confidential_asset">confidential_asset</a>::{}::token::{}::fa",
            @aptos_framework,
            <a href="object.md#0x1_object_object_address">object::object_address</a>(&token)
        )
    )
}
</code></pre>



</details>

<a id="0x1_confidential_asset_validate_auditors"></a>

## Function `validate_auditors`

Validates the auditor-related fields of a confidential transfer.

Aborts with [<code><a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET">ECHAIN_AUDITOR_NOT_SET</a></code>] if no chain-level auditor has been
configured (transfers cannot proceed in that state).

Returns <code><b>false</b></code> (rejecting the transfer) if any of:
- any <code>auditor_amount</code> does not encrypt the same plaintext as <code>transfer_amount</code>;
- the lengths of <code>auditor_eks</code>, <code>auditor_amounts</code>, and the transfer-proof auditor
row count disagree;
- <code>auditor_eks</code> is missing the required prefix (see slot layout below);
- the prefix slot keys do not equal the active chain / asset auditor keys.

**Slot layout of <code>auditor_eks</code>** (and <code>auditor_amounts</code>):
```text
[0]   chain-level auditor       (always required)
[1]   asset-specific auditor    (required iff <code><a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(token).is_some()</code>)
[2..] voluntary auditors        (sender's choice, ordered)
```
Auditor identity at slots 0 and 1 is bound into the transfer's Fiat–Shamir
transcript (via the order in which <code>auditor_eks</code> is hashed in
<code><a href="confidential_proof.md#0x1_confidential_proof_fiat_shamir_transfer_sigma_proof_challenge">confidential_proof::fiat_shamir_transfer_sigma_proof_challenge</a></code>), so a sender
cannot substitute one auditor's slot for another's.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_validate_auditors">validate_auditors</a>(token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, transfer_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, proof: &<a href="confidential_proof.md#0x1_confidential_proof_TransferProof">confidential_proof::TransferProof</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_validate_auditors">validate_auditors</a>(
    token: Object&lt;Metadata&gt;,
    transfer_amount: &<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;,
    auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;,
    proof: &TransferProof): bool <b>acquires</b> <a href="confidential_asset.md#0x1_confidential_asset_FAConfig">FAConfig</a>, <a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>
{
    <b>if</b> (
        !auditor_amounts.all(|auditor_amount| {
            <a href="confidential_balance.md#0x1_confidential_balance_balance_c_equals">confidential_balance::balance_c_equals</a>(transfer_amount, auditor_amount)
        })
    ) {
        <b>return</b> <b>false</b>
    };

    <b>if</b> (
        auditor_eks.length() != auditor_amounts.length() ||
            auditor_eks.length() != <a href="confidential_proof.md#0x1_confidential_proof_auditors_count_in_transfer_proof">confidential_proof::auditors_count_in_transfer_proof</a>(proof)
    ) {
        <b>return</b> <b>false</b>
    };

    <b>let</b> chain_auditor_ek_opt = <b>borrow_global</b>&lt;<a href="confidential_asset.md#0x1_confidential_asset_GlobalConfig">GlobalConfig</a>&gt;(@aptos_framework).chain_auditor_ek;
    <b>assert</b>!(chain_auditor_ek_opt.is_some(), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="confidential_asset.md#0x1_confidential_asset_ECHAIN_AUDITOR_NOT_SET">ECHAIN_AUDITOR_NOT_SET</a>));

    <b>let</b> asset_auditor_ek_opt = <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(token);
    <b>let</b> required_prefix = <b>if</b> (asset_auditor_ek_opt.is_some()) 2 <b>else</b> 1;

    <b>if</b> (auditor_eks.length() &lt; required_prefix) {
        <b>return</b> <b>false</b>
    };

    <b>let</b> chain_auditor_point = twisted_elgamal::pubkey_to_point(&chain_auditor_ek_opt.extract());
    <b>let</b> slot0_point = twisted_elgamal::pubkey_to_point(&auditor_eks[0]);
    <b>if</b> (!<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_point_equals">ristretto255::point_equals</a>(&chain_auditor_point, &slot0_point)) {
        <b>return</b> <b>false</b>
    };

    <b>if</b> (asset_auditor_ek_opt.is_some()) {
        <b>let</b> asset_auditor_point = twisted_elgamal::pubkey_to_point(&asset_auditor_ek_opt.extract());
        <b>let</b> slot1_point = twisted_elgamal::pubkey_to_point(&auditor_eks[1]);
        <b>if</b> (!<a href="../../aptos-stdlib/doc/ristretto255.md#0x1_ristretto255_point_equals">ristretto255::point_equals</a>(&asset_auditor_point, &slot1_point)) {
            <b>return</b> <b>false</b>
        };
    };

    <b>true</b>
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deserialize_auditor_eks"></a>

## Function `deserialize_auditor_eks`

Deserializes the auditor EKs from a byte array.
Returns <code>Some(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;)</code> if the deserialization is successful, otherwise <code>None</code>.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_eks">deserialize_auditor_eks</a>(auditor_eks_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_eks">deserialize_auditor_eks</a>(
    auditor_eks_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;&gt;
{
    <b>if</b> (auditor_eks_bytes.length() % 32 != 0) {
        <b>return</b> std::option::none()
    };

    <b>let</b> auditors_count = auditor_eks_bytes.length() / 32;

    <b>let</b> auditor_eks = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_range">vector::range</a>(0, auditors_count).map(|i| {
        twisted_elgamal::new_pubkey_from_bytes(auditor_eks_bytes.slice(i * 32, (i + 1) * 32))
    });

    <b>if</b> (auditor_eks.<a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a>(|ek| ek.is_none())) {
        <b>return</b> std::option::none()
    };

    std::option::some(auditor_eks.map(|ek| ek.extract()))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deserialize_auditor_amounts"></a>

## Function `deserialize_auditor_amounts`

Deserializes the auditor amounts from a byte array.
Returns <code>Some(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;)</code> if the deserialization is successful, otherwise <code>None</code>.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_amounts">deserialize_auditor_amounts</a>(auditor_amounts_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deserialize_auditor_amounts">deserialize_auditor_amounts</a>(
    auditor_amounts_bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;&gt;
{
    <b>if</b> (auditor_amounts_bytes.length() % 256 != 0) {
        <b>return</b> std::option::none()
    };

    <b>let</b> auditors_count = auditor_amounts_bytes.length() / 256;

    <b>let</b> auditor_amounts = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_range">vector::range</a>(0, auditors_count).map(|i| {
        <a href="confidential_balance.md#0x1_confidential_balance_new_pending_balance_from_bytes">confidential_balance::new_pending_balance_from_bytes</a>(auditor_amounts_bytes.slice(i * 256, (i + 1) * 256))
    });

    <b>if</b> (auditor_amounts.<a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a>(|ek| ek.is_none())) {
        <b>return</b> std::option::none()
    };

    std::option::some(auditor_amounts.map(|balance| balance.extract()))
}
</code></pre>



</details>

<a id="0x1_confidential_asset_ensure_sufficient_fa"></a>

## Function `ensure_sufficient_fa`

Converts coins to missing FA.
Returns <code>Some(Object&lt;Metadata&gt;)</code> if user has a sufficient amount of FA to proceed, otherwise <code>None</code>.


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_sufficient_fa">ensure_sufficient_fa</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_ensure_sufficient_fa">ensure_sufficient_fa</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, amount: u64): Option&lt;Object&lt;Metadata&gt;&gt; {
    <b>let</b> user = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>let</b> fa = <a href="coin.md#0x1_coin_paired_metadata">coin::paired_metadata</a>&lt;CoinType&gt;();

    <b>if</b> (fa.is_none()) {
        <b>return</b> fa;
    };

    <b>let</b> fa_balance = <a href="primary_fungible_store.md#0x1_primary_fungible_store_balance">primary_fungible_store::balance</a>(user, *fa.borrow());

    <b>if</b> (fa_balance &gt;= amount) {
        <b>return</b> fa;
    };

    <b>if</b> (<a href="coin.md#0x1_coin_balance">coin::balance</a>&lt;CoinType&gt;(user) &lt; amount) {
        <b>return</b> std::option::none();
    };

    <b>let</b> coin_amount = <a href="coin.md#0x1_coin_withdraw">coin::withdraw</a>&lt;CoinType&gt;(sender, amount - fa_balance);
    <b>let</b> fa_amount = <a href="coin.md#0x1_coin_coin_to_fungible_asset">coin::coin_to_fungible_asset</a>(coin_amount);

    <a href="primary_fungible_store.md#0x1_primary_fungible_store_deposit">primary_fungible_store::deposit</a>(user, fa_amount);

    fa
}
</code></pre>



</details>

<a id="0x1_confidential_asset_serialize_auditor_eks"></a>

## Function `serialize_auditor_eks`

Pure serialization helpers (no <code><b>borrow_global</b></code>). Public so off-chain tooling and
tooling can exercise the same entrypoints as tests without <code>#[test_only]</code> harness modules.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_eks">serialize_auditor_eks</a>(auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_eks">serialize_auditor_eks</a>(auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> auditor_eks_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];

    auditor_eks.for_each_ref(|auditor| {
        auditor_eks_bytes.append(twisted_elgamal::pubkey_to_bytes(auditor));
    });

    auditor_eks_bytes
}
</code></pre>



</details>

<a id="0x1_confidential_asset_serialize_auditor_amounts"></a>

## Function `serialize_auditor_amounts`



<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_amounts">serialize_auditor_amounts</a>(auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_amounts">serialize_auditor_amounts</a>(
    auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>let</b> auditor_amounts_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];

    auditor_amounts.for_each_ref(|balance| {
        auditor_amounts_bytes.append(<a href="confidential_balance.md#0x1_confidential_balance_balance_to_bytes">confidential_balance::balance_to_bytes</a>(balance));
    });

    auditor_amounts_bytes
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
