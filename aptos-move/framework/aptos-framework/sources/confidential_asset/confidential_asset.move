/// PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only
///
/// The Confidential Asset (CA) standard for fungible assets.
///
/// Every public function and every entry function aborts with `E_CONFIDENTIAL_ASSETS_PAUSED` (wrapped in
/// `error::unavailable`). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
/// remove or change a published struct. No resource is published, no event is emitted and no state is changed.
module aptos_framework::confidential_asset {
    use std::error;
    use std::option::Option;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{ExtendRef, Object};
    use aptos_framework::confidential_balance;
    use aptos_framework::ristretto255_twisted_elgamal as twisted_elgamal;
    use aptos_framework::confidential_proof::{WithdrawalProof, TransferProof, NormalizationProof, RotationProof};

    /// Confidential assets are paused: every function in this module aborts.
    const E_CONFIDENTIAL_ASSETS_PAUSED: u64 = 1;

    /// The `confidential_asset` module stores a `ConfidentialAssetStore` object for each user-token pair.
    struct ConfidentialAssetStore has key {
        /// Indicates if the account is frozen. If `true`, transactions are temporarily disabled
        /// for this account. This is particularly useful during key rotations, which require
        /// two transactions: rolling over the pending balance to the actual balance and rotating
        /// the encryption key. Freezing prevents the user from accepting additional payments
        /// between these two transactions.
        frozen: bool,

        /// A flag indicating whether the actual balance is normalized. A normalized balance
        /// ensures that all chunks fit within the defined 16-bit bounds, preventing overflows.
        normalized: bool,

        /// Tracks the maximum number of transactions the user can accept before normalization
        /// is required. For example, if the user can accept up to 2^16 transactions and each
        /// chunk has a 16-bit limit, the maximum chunk value before normalization would be
        /// 2^16 * 2^16 = 2^32. Maintaining this counter is crucial because users must solve
        /// a discrete logarithm problem of this size to decrypt their balances.
        pending_counter: u64,

        /// Stores the user's pending balance, which is used for accepting incoming payments.
        /// Represented as four 16-bit chunks (p0 + 2^16 * p1 + 2^32 * p2 + 2^48 * p3), that can grow up to 32 bits.
        /// All payments are accepted into this pending balance, which users must roll over into the actual balance
        /// to perform transactions like withdrawals or transfers.
        /// This separation helps protect against front-running attacks, where small incoming transfers could force
        /// frequent regenerating of zk-proofs.
        pending_balance: confidential_balance::CompressedConfidentialBalance,

        /// Represents the actual user balance, which is available for sending payments.
        /// It consists of eight 16-bit chunks (p0 + 2^16 * p1 + ... + 2^112 * p8), supporting a 128-bit balance.
        /// Users can decrypt this balance with their decryption keys and by solving a discrete logarithm problem.
        actual_balance: confidential_balance::CompressedConfidentialBalance,

        /// The encryption key associated with the user's confidential asset account, different for each token.
        ek: twisted_elgamal::CompressedPubkey,
    }

    /// Global configuration for confidential assets: primary FA stores, `FAConfig` derivation, and chain-level auditor state.
    struct GlobalConfig has key {
        /// Indicates whether the allow list is enabled. If `true`, only tokens from the allow list can be transferred.
        /// This flag is managed by the governance module.
        allow_list_enabled: bool,

        /// Used to derive a signer that owns all the FAs' primary stores and `FAConfig` objects.
        extend_ref: ExtendRef,

        /// Chain-level auditor encryption key. Required at `auditor_eks[0]` on every
        /// confidential transfer. `None` until set via [`set_chain_auditor`]; transfers
        /// abort with [`ECHAIN_AUDITOR_NOT_SET`] in that state.
        chain_auditor_ek: Option<twisted_elgamal::CompressedPubkey>,

        /// Account authorized to call [`set_chain_auditor`]. Set by governance via
        /// [`set_chain_auditor_admin`]. `None` until governance assigns one, during which
        /// window `set_chain_auditor` aborts with [`ECHAIN_AUDITOR_ADMIN_NOT_SET`].
        chain_auditor_admin: Option<address>,

        /// Bumped on every [`set_chain_auditor`] call (including clears). Stamped on each
        /// [`Transferred`] event so off-chain auditors / gateways can identify which
        /// historical chain-auditor key was in force at that transfer.
        chain_auditor_epoch: u64,
    }

    /// Represents the configuration of a token.
    struct FAConfig has key {
        /// Indicates whether the token is allowed for confidential transfers.
        /// If allow list is disabled, all tokens are allowed.
        /// Can be toggled by the governance module. The withdrawals are always allowed.
        allowed: bool,

        /// Per-asset auditor encryption key. When set, required at `auditor_eks[1]` on
        /// every transfer of this asset (additive to the chain auditor at `[0]`). Set via
        /// [`set_asset_auditor`] by the FA metadata object's root owner.
        asset_auditor_ek: Option<twisted_elgamal::CompressedPubkey>,

        /// Bumped on every [`set_asset_auditor`] call (including clears). Stamped on each
        /// [`Transferred`] event for this asset so off-chain auditors / gateways can
        /// identify which historical asset-auditor key was in force at that transfer.
        asset_auditor_epoch: u64,
    }

    #[event]
    /// Emitted when a new confidential asset store is registered.
    struct Registered has drop, store {
        addr: address,
        /// Fungible asset metadata object address.
        asset_type: address,
        ek: twisted_elgamal::CompressedPubkey,
    }

    #[event]
    /// Emitted when tokens are brought into the protocol.
    struct Deposited has drop, store {
        from: address,
        to: address,
        /// Fungible asset metadata object address.
        asset_type: address,
        amount: u64,
        /// Recipient's new pending balance after the deposit.
        new_pending_balance: confidential_balance::CompressedConfidentialBalance,
    }

    #[event]
    /// Emitted when tokens are brought out of the protocol.
    struct Withdrawn has drop, store {
        from: address,
        to: address,
        /// Fungible asset metadata object address.
        asset_type: address,
        amount: u64,
        /// Sender's new available (actual) balance after the withdrawal.
        new_available_balance: confidential_balance::CompressedConfidentialBalance,
    }

    #[event]
    /// Emitted after a successful `confidential_transfer` between two registered confidential accounts.
    ///
    /// This is the primary on-chain signal for indexers and tooling: **plaintext amounts are not** included;
    /// fields carry **compressed Twisted-ElGamal ciphertexts** and a **subset of sigma commitment bytes** copied
    /// from the verified proof. See the technical whitepaper (`whitepaper.md`, §5) for a field-by-field guide.
    struct Transferred has drop, store {
        /// Address of the sender's confidential account (the `signer` of the transfer entry).
        from: address,
        /// Recipient confidential account address.
        to: address,
        /// Fungible-asset metadata object address (`object::object_address(&token)`); identifies which token moved.
        asset_type: address,
        /// Encrypted transfer amount under the recipient key (pending-balance / four-chunk layout).
        amount: confidential_balance::CompressedConfidentialBalance,
        /// Flattened **transfer sigma `x7s`** commitments taken from the verified `TransferProof`: for each
        /// auditor encryption key row in the proof, exactly **four** compressed Ristretto points (32 bytes each),
        /// concatenated in **row-major** order (auditor index, then inner index 0..3). Empty when the proof carries
        /// **no** auditor rows. Total byte length is always **`128 × n`** with `n` = number of auditor rows
        /// (`confidential_proof::auditors_count_in_transfer_proof` / `proof.sigma_proof.xs.x7s.length()`).
        ek_volun_auds: vector<u8>,
        /// Opaque sender-supplied bytes (bounded by [`MAX_SENDER_AUDITOR_HINT_BYTES`]); same bytes bound into
        /// the transfer sigma Fiat–Shamir challenge and passed as the `sender_auditor_hint` entry argument.
        sender_auditor_hint: vector<u8>,
        /// Sender's new **actual** (spendable) balance ciphertext after the debit, compressed for storage/events.
        new_sender_available_balance: confidential_balance::CompressedConfidentialBalance,
        /// Recipient's new **pending** balance ciphertext after the credit, compressed for storage/events.
        new_recip_pending_balance: confidential_balance::CompressedConfidentialBalance,
        /// Reserved memo payload for future or off-chain conventions; currently emitted as an empty `vector`.
        memo: vector<u8>,
        /// Value of [`GlobalConfig.chain_auditor_epoch`] at the time of the transfer.
        /// Required for compliance: lets future audits identify which historical
        /// chain-level auditor key was in force, so that the transcript can still be
        /// decrypted years after a key rotation.
        chain_auditor_epoch: u64,
        /// Value of [`FAConfig.asset_auditor_epoch`] for this asset at the time of the
        /// transfer. `0` only when [`set_asset_auditor`] has never been called for this
        /// asset; once called (including a clear with empty bytes) the epoch is bumped
        /// and stamped here even if the current `asset_auditor_ek` is `None`. Off-chain
        /// auditors / gateways resolve `(asset_type, asset_auditor_epoch)` to the active
        /// key by indexing [`AssetAuditorChanged`] events.
        asset_auditor_epoch: u64,
    }

    #[event]
    /// Emitted when the available balance is re-encrypted to normalize chunk bounds.
    struct Normalized has drop, store {
        addr: address,
        asset_type: address,
        new_available_balance: confidential_balance::CompressedConfidentialBalance,
    }

    #[event]
    /// Emitted when the pending balance is rolled over into the available balance.
    struct RolledOver has drop, store {
        addr: address,
        asset_type: address,
        new_available_balance: confidential_balance::CompressedConfidentialBalance,
    }

    #[event]
    /// Emitted when the encryption key is rotated and the balance is re-encrypted.
    struct KeyRotated has drop, store {
        addr: address,
        asset_type: address,
        new_ek: twisted_elgamal::CompressedPubkey,
        new_available_balance: confidential_balance::CompressedConfidentialBalance,
    }

    #[event]
    /// Emitted when a confidential account's incoming-transfer pause state changes (freeze/unfreeze).
    struct FreezeChanged has drop, store {
        addr: address,
        asset_type: address,
        frozen: bool,
    }

    #[event]
    /// Emitted when the global allow list is enabled or disabled.
    struct AllowListChanged has drop, store {
        enabled: bool,
    }

    #[event]
    /// Emitted when a token's confidential-transfer permission is toggled.
    struct TokenAllowChanged has drop, store {
        asset_type: address,
        allowed: bool,
    }

    #[event]
    /// Asset auditor set, rotated, or cleared.
    struct AssetAuditorChanged has drop, store {
        asset_type: address,
        new_asset_auditor_ek: Option<twisted_elgamal::CompressedPubkey>,
        new_epoch: u64,
    }

    #[event]
    /// Chain auditor set, rotated, or cleared.
    struct ChainAuditorChanged has drop, store {
        new_chain_auditor_ek: Option<twisted_elgamal::CompressedPubkey>,
        new_epoch: u64,
    }

    #[event]
    /// Chain-auditor admin assigned or rotated by governance.
    struct ChainAuditorAdminChanged has drop, store {
        new_admin: address,
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun register(
        _sender: &signer,
        _token: Object<Metadata>,
        _ek: vector<u8>,
        _registration_proof_commitment: vector<u8>,
        _registration_proof_response: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun register_and_deposit_and_rollover_pending_balance(
        _sender: &signer,
        _token: Object<Metadata>,
        _amount: u64,
        _ek: vector<u8>,
        _registration_proof_commitment: vector<u8>,
        _registration_proof_response: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit_and_rollover_pending_balance(
        _sender: &signer,
        _token: Object<Metadata>,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit_and_normalize_and_rollover_pending_balance(
        _sender: &signer,
        _token: Object<Metadata>,
        _amount: u64,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit_to(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit(
        _sender: &signer,
        _token: Object<Metadata>,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit_coins_to<CoinType>(
        _sender: &signer,
        _to: address,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun deposit_coins<CoinType>(
        _sender: &signer,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun withdraw_to(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _amount: u64,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun withdraw(
        _sender: &signer,
        _token: Object<Metadata>,
        _amount: u64,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun confidential_transfer(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _new_balance: vector<u8>,
        _sender_amount: vector<u8>,
        _recipient_amount: vector<u8>,
        _auditor_eks: vector<u8>,
        _auditor_amounts: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _zkrp_transfer_amount: vector<u8>,
        _sigma_proof: vector<u8>,
        _sender_auditor_hint: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun max_sender_auditor_hint_bytes(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun rotate_encryption_key(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_ek: vector<u8>,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun normalize(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun freeze_token(_sender: &signer, _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun unfreeze_token(_sender: &signer, _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun rollover_pending_balance(
        _sender: &signer,
        _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun normalize_and_rollover_pending_balance(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _sigma_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun rollover_pending_balance_and_freeze(
        _sender: &signer,
        _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun rotate_encryption_key_and_unfreeze(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_ek: vector<u8>,
        _new_confidential_balance: vector<u8>,
        _zkrp_new_balance: vector<u8>,
        _rotate_proof: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun enable_allow_list(_aptos_framework: &signer) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun disable_allow_list(_aptos_framework: &signer) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun enable_token(_aptos_framework: &signer, _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun disable_token(_aptos_framework: &signer, _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun set_asset_auditor(
        _issuer: &signer,
        _token: Object<Metadata>,
        _new_auditor_ek: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun set_chain_auditor_admin(
        _aptos_framework: &signer,
        _new_admin: address) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public entry fun set_chain_auditor(
        _admin: &signer,
        _new_chain_auditor_ek: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun has_confidential_asset_store(_user: address, _token: Object<Metadata>): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_token_allowed(_token: Object<Metadata>): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_allow_list_enabled(): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun pending_balance(
        _owner: address,
        _token: Object<Metadata>): confidential_balance::CompressedConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun actual_balance(
        _owner: address,
        _token: Object<Metadata>): confidential_balance::CompressedConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun encryption_key(
        _user: address,
        _token: Object<Metadata>): twisted_elgamal::CompressedPubkey {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_normalized(_user: address, _token: Object<Metadata>): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_frozen(_user: address, _token: Object<Metadata>): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_asset_auditor(
        _token: Object<Metadata>): Option<twisted_elgamal::CompressedPubkey> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_asset_auditor_epoch(_token: Object<Metadata>): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_chain_auditor(): Option<twisted_elgamal::CompressedPubkey> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_chain_auditor_epoch(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_chain_auditor_admin(): Option<address> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun confidential_asset_balance(_token: Object<Metadata>): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun register_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _ek: twisted_elgamal::CompressedPubkey) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun deposit_to_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _amount: u64) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun withdraw_to_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _amount: u64,
        _new_balance: confidential_balance::ConfidentialBalance,
        _proof: WithdrawalProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun confidential_transfer_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _to: address,
        _new_balance: confidential_balance::ConfidentialBalance,
        _sender_amount: confidential_balance::ConfidentialBalance,
        _recipient_amount: confidential_balance::ConfidentialBalance,
        _auditor_eks: vector<twisted_elgamal::CompressedPubkey>,
        _auditor_amounts: vector<confidential_balance::ConfidentialBalance>,
        _proof: TransferProof,
        _sender_auditor_hint: vector<u8>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun rotate_encryption_key_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_ek: twisted_elgamal::CompressedPubkey,
        _new_balance: confidential_balance::ConfidentialBalance,
        _proof: RotationProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun normalize_internal(
        _sender: &signer,
        _token: Object<Metadata>,
        _new_balance: confidential_balance::ConfidentialBalance,
        _proof: NormalizationProof) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun rollover_pending_balance_internal(
        _sender: &signer,
        _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun freeze_token_internal(
        _sender: &signer,
        _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun unfreeze_token_internal(
        _sender: &signer,
        _token: Object<Metadata>) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun serialize_auditor_eks(_auditor_eks: &vector<twisted_elgamal::CompressedPubkey>): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun serialize_auditor_amounts(
        _auditor_amounts: &vector<confidential_balance::ConfidentialBalance>
    ): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }
}
