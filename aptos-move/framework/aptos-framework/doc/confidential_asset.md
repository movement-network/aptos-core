
<a id="0x1_confidential_asset"></a>

# Module `0x1::confidential_asset`

PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only

The Confidential Asset (CA) standard for fungible assets.

Every public function and every entry function aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code> (wrapped in
<code><a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a></code>). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
remove or change a published struct. No resource is published, no event is emitted and no state is changed.


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
-  [Function `serialize_auditor_eks`](#0x1_confidential_asset_serialize_auditor_eks)
-  [Function `serialize_auditor_amounts`](#0x1_confidential_asset_serialize_auditor_amounts)


<pre><code><b>use</b> <a href="confidential_balance.md#0x1_confidential_balance">0x1::confidential_balance</a>;
<b>use</b> <a href="confidential_proof.md#0x1_confidential_proof">0x1::confidential_proof</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="fungible_asset.md#0x1_fungible_asset">0x1::fungible_asset</a>;
<b>use</b> <a href="object.md#0x1_object">0x1::object</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal">0x1::ristretto255_twisted_elgamal</a>;
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
 abort with [<code>ECHAIN_AUDITOR_NOT_SET</code>] in that state.
</dd>
<dt>
<code>chain_auditor_admin: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;</code>
</dt>
<dd>
 Account authorized to call [<code>set_chain_auditor</code>]. Set by governance via
 [<code>set_chain_auditor_admin</code>]. <code>None</code> until governance assigns one, during which
 window <code>set_chain_auditor</code> aborts with [<code>ECHAIN_AUDITOR_ADMIN_NOT_SET</code>].
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
 (<code>confidential_proof::auditors_count_in_transfer_proof</code> / <code>proof.sigma_proof.xs.x7s.length()</code>).
</dd>
<dt>
<code>sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 Opaque sender-supplied bytes (bounded by [<code>MAX_SENDER_AUDITOR_HINT_BYTES</code>]); same bytes bound into
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


<a id="0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED"></a>

Confidential assets are paused: every function in this module aborts.


<pre><code><b>const</b> <a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>: u64 = 1;
</code></pre>



<a id="0x1_confidential_asset_register"></a>

## Function `register`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register">register</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register">register</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance"></a>

## Function `register_and_deposit_and_rollover_pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance">register_and_deposit_and_rollover_pending_balance</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _amount: u64, _ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_and_deposit_and_rollover_pending_balance">register_and_deposit_and_rollover_pending_balance</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _amount: u64,
    _ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _registration_proof_commitment: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _registration_proof_response: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_and_rollover_pending_balance"></a>

## Function `deposit_and_rollover_pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_rollover_pending_balance">deposit_and_rollover_pending_balance</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_rollover_pending_balance">deposit_and_rollover_pending_balance</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance"></a>

## Function `deposit_and_normalize_and_rollover_pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance">deposit_and_normalize_and_rollover_pending_balance</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _amount: u64, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_and_normalize_and_rollover_pending_balance">deposit_and_normalize_and_rollover_pending_balance</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _amount: u64,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_to"></a>

## Function `deposit_to`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to">deposit_to</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to">deposit_to</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit"></a>

## Function `deposit`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit">deposit</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit">deposit</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_coins_to"></a>

## Function `deposit_coins_to`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins_to">deposit_coins_to</a>&lt;CoinType&gt;(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _to: <b>address</b>, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins_to">deposit_coins_to</a>&lt;CoinType&gt;(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _to: <b>address</b>,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_coins"></a>

## Function `deposit_coins`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins">deposit_coins</a>&lt;CoinType&gt;(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_coins">deposit_coins</a>&lt;CoinType&gt;(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw_to"></a>

## Function `withdraw_to`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to">withdraw_to</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _amount: u64, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to">withdraw_to</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _amount: u64,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw"></a>

## Function `withdraw`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw">withdraw</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _amount: u64, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw">withdraw</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _amount: u64,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_transfer"></a>

## Function `confidential_transfer`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer">confidential_transfer</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sender_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _recipient_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_transfer_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer">confidential_transfer</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sender_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _recipient_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_transfer_amount: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_max_sender_auditor_hint_bytes"></a>

## Function `max_sender_auditor_hint_bytes`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_max_sender_auditor_hint_bytes">max_sender_auditor_hint_bytes</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_max_sender_auditor_hint_bytes">max_sender_auditor_hint_bytes</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key"></a>

## Function `rotate_encryption_key`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key">rotate_encryption_key</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize"></a>

## Function `normalize`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize">normalize</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize">normalize</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_freeze_token"></a>

## Function `freeze_token`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token">freeze_token</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token">freeze_token</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_unfreeze_token"></a>

## Function `unfreeze_token`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token">unfreeze_token</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token">unfreeze_token</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance"></a>

## Function `rollover_pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance">rollover_pending_balance</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize_and_rollover_pending_balance"></a>

## Function `normalize_and_rollover_pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_and_rollover_pending_balance">normalize_and_rollover_pending_balance</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_and_rollover_pending_balance">normalize_and_rollover_pending_balance</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _sigma_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance_and_freeze"></a>

## Function `rollover_pending_balance_and_freeze`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_and_freeze">rollover_pending_balance_and_freeze</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_and_freeze">rollover_pending_balance_and_freeze</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key_and_unfreeze"></a>

## Function `rotate_encryption_key_and_unfreeze`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_and_unfreeze">rotate_encryption_key_and_unfreeze</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _new_confidential_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, _rotate_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_and_unfreeze">rotate_encryption_key_and_unfreeze</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _new_confidential_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _zkrp_new_balance: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    _rotate_proof: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_enable_allow_list"></a>

## Function `enable_allow_list`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_allow_list">enable_allow_list</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_allow_list">enable_allow_list</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_disable_allow_list"></a>

## Function `disable_allow_list`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_allow_list">disable_allow_list</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_allow_list">disable_allow_list</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_enable_token"></a>

## Function `enable_token`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_token">enable_token</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_enable_token">enable_token</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_disable_token"></a>

## Function `disable_token`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_token">disable_token</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_disable_token">disable_token</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_asset_auditor"></a>

## Function `set_asset_auditor`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_asset_auditor">set_asset_auditor</a>(_issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_asset_auditor">set_asset_auditor</a>(
    _issuer: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_chain_auditor_admin"></a>

## Function `set_chain_auditor_admin`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor_admin">set_chain_auditor_admin</a>(_aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _new_admin: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor_admin">set_chain_auditor_admin</a>(
    _aptos_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _new_admin: <b>address</b>) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_set_chain_auditor"></a>

## Function `set_chain_auditor`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor">set_chain_auditor</a>(_admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _new_chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_set_chain_auditor">set_chain_auditor</a>(
    _admin: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _new_chain_auditor_ek: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_has_confidential_asset_store"></a>

## Function `has_confidential_asset_store`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(_user: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_has_confidential_asset_store">has_confidential_asset_store</a>(_user: <b>address</b>, _token: Object&lt;Metadata&gt;): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_token_allowed"></a>

## Function `is_token_allowed`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(_token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_token_allowed">is_token_allowed</a>(_token: Object&lt;Metadata&gt;): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_allow_list_enabled"></a>

## Function `is_allow_list_enabled`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_allow_list_enabled">is_allow_list_enabled</a>(): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_pending_balance"></a>

## Function `pending_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_pending_balance">pending_balance</a>(_owner: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_pending_balance">pending_balance</a>(
    _owner: <b>address</b>,
    _token: Object&lt;Metadata&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_actual_balance"></a>

## Function `actual_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_actual_balance">actual_balance</a>(_owner: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_actual_balance">actual_balance</a>(
    _owner: <b>address</b>,
    _token: Object&lt;Metadata&gt;): <a href="confidential_balance.md#0x1_confidential_balance_CompressedConfidentialBalance">confidential_balance::CompressedConfidentialBalance</a> {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_encryption_key"></a>

## Function `encryption_key`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(_user: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_encryption_key">encryption_key</a>(
    _user: <b>address</b>,
    _token: Object&lt;Metadata&gt;): twisted_elgamal::CompressedPubkey {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_normalized"></a>

## Function `is_normalized`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_normalized">is_normalized</a>(_user: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_normalized">is_normalized</a>(_user: <b>address</b>, _token: Object&lt;Metadata&gt;): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_is_frozen"></a>

## Function `is_frozen`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(_user: <b>address</b>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_is_frozen">is_frozen</a>(_user: <b>address</b>, _token: Object&lt;Metadata&gt;): bool {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_asset_auditor"></a>

## Function `get_asset_auditor`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(_token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor">get_asset_auditor</a>(
    _token: Object&lt;Metadata&gt;): Option&lt;twisted_elgamal::CompressedPubkey&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_asset_auditor_epoch"></a>

## Function `get_asset_auditor_epoch`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor_epoch">get_asset_auditor_epoch</a>(_token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_asset_auditor_epoch">get_asset_auditor_epoch</a>(_token: Object&lt;Metadata&gt;): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor"></a>

## Function `get_chain_auditor`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor">get_chain_auditor</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor">get_chain_auditor</a>(): Option&lt;twisted_elgamal::CompressedPubkey&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor_epoch"></a>

## Function `get_chain_auditor_epoch`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_epoch">get_chain_auditor_epoch</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_epoch">get_chain_auditor_epoch</a>(): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_get_chain_auditor_admin"></a>

## Function `get_chain_auditor_admin`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_admin">get_chain_auditor_admin</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<b>address</b>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_get_chain_auditor_admin">get_chain_auditor_admin</a>(): Option&lt;<b>address</b>&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_asset_balance"></a>

## Function `confidential_asset_balance`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_asset_balance">confidential_asset_balance</a>(_token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_asset_balance">confidential_asset_balance</a>(_token: Object&lt;Metadata&gt;): u64 {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_register_internal"></a>

## Function `register_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_internal">register_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_register_internal">register_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _ek: twisted_elgamal::CompressedPubkey) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_deposit_to_internal"></a>

## Function `deposit_to_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_deposit_to_internal">deposit_to_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _amount: u64) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_withdraw_to_internal"></a>

## Function `withdraw_to_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _amount: u64, _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: <a href="confidential_proof.md#0x1_confidential_proof_WithdrawalProof">confidential_proof::WithdrawalProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_withdraw_to_internal">withdraw_to_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _amount: u64,
    _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: WithdrawalProof) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_confidential_transfer_internal"></a>

## Function `confidential_transfer_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _to: <b>address</b>, _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _sender_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _recipient_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;, _auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;, _proof: <a href="confidential_proof.md#0x1_confidential_proof_TransferProof">confidential_proof::TransferProof</a>, _sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_confidential_transfer_internal">confidential_transfer_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _to: <b>address</b>,
    _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _sender_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _recipient_amount: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _auditor_eks: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;,
    _auditor_amounts: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;,
    _proof: TransferProof,
    _sender_auditor_hint: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rotate_encryption_key_internal"></a>

## Function `rotate_encryption_key_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_ek: <a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>, _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: <a href="confidential_proof.md#0x1_confidential_proof_RotationProof">confidential_proof::RotationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rotate_encryption_key_internal">rotate_encryption_key_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_ek: twisted_elgamal::CompressedPubkey,
    _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: RotationProof) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_normalize_internal"></a>

## Function `normalize_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;, _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>, _proof: <a href="confidential_proof.md#0x1_confidential_proof_NormalizationProof">confidential_proof::NormalizationProof</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_normalize_internal">normalize_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;,
    _new_balance: <a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>,
    _proof: NormalizationProof) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_rollover_pending_balance_internal"></a>

## Function `rollover_pending_balance_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_rollover_pending_balance_internal">rollover_pending_balance_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_freeze_token_internal"></a>

## Function `freeze_token_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token_internal">freeze_token_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_freeze_token_internal">freeze_token_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_unfreeze_token_internal"></a>

## Function `unfreeze_token_internal`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, _token: <a href="object.md#0x1_object_Object">object::Object</a>&lt;<a href="fungible_asset.md#0x1_fungible_asset_Metadata">fungible_asset::Metadata</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_unfreeze_token_internal">unfreeze_token_internal</a>(
    _sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    _token: Object&lt;Metadata&gt;) {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_serialize_auditor_eks"></a>

## Function `serialize_auditor_eks`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_eks">serialize_auditor_eks</a>(_auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="ristretto255_twisted_elgamal.md#0x1_ristretto255_twisted_elgamal_CompressedPubkey">ristretto255_twisted_elgamal::CompressedPubkey</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_eks">serialize_auditor_eks</a>(_auditor_eks: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;twisted_elgamal::CompressedPubkey&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>

<a id="0x1_confidential_asset_serialize_auditor_amounts"></a>

## Function `serialize_auditor_amounts`

Paused: always aborts with <code><a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_amounts">serialize_auditor_amounts</a>(_auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="confidential_asset.md#0x1_confidential_asset_serialize_auditor_amounts">serialize_auditor_amounts</a>(
    _auditor_amounts: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="confidential_balance.md#0x1_confidential_balance_ConfidentialBalance">confidential_balance::ConfidentialBalance</a>&gt;
): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_unavailable">error::unavailable</a>(<a href="confidential_asset.md#0x1_confidential_asset_E_CONFIDENTIAL_ASSETS_PAUSED">E_CONFIDENTIAL_ASSETS_PAUSED</a>)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
