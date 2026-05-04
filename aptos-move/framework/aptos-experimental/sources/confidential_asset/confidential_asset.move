/// This module implements the Confidential Asset (CA) Standard, a privacy-focused protocol for managing fungible assets (FA).
/// It enables private transfers by obfuscating token amounts while keeping sender and recipient addresses visible.
module aptos_experimental::confidential_asset {
    use std::bcs;
    use std::error;
    use std::option::Option;
    use std::signer;
    use std::vector;
    use aptos_std::ristretto255::Self;
    use aptos_std::ristretto255_bulletproofs::Self as bulletproofs;
    use aptos_std::string_utils;
    use aptos_framework::chain_id;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::dispatchable_fungible_asset;
    use aptos_framework::fungible_asset::{Self, FungibleStore, Metadata};
    use aptos_framework::object::{Self, ExtendRef, Object};
    use aptos_framework::primary_fungible_store;
    use aptos_framework::system_addresses;

    use aptos_experimental::confidential_balance;
    use aptos_experimental::confidential_proof::{
        Self, NormalizationProof, RotationProof, TransferProof, WithdrawalProof
    };
    use aptos_experimental::ristretto255_twisted_elgamal as twisted_elgamal;

    #[test_only]
    use aptos_std::ristretto255::Scalar;

    //
    // Errors
    //

    /// The range proof system does not support sufficient range.
    const ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE: u64 = 1;

    /// The confidential asset store has already been published for the given user-token pair.
    const ECA_STORE_ALREADY_PUBLISHED: u64 = 2;

    /// The confidential asset store has not been published for the given user-token pair.
    const ECA_STORE_NOT_PUBLISHED: u64 = 3;

    /// The deserialization of the auditor EK failed.
    const EAUDITOR_EK_DESERIALIZATION_FAILED: u64 = 4;

    /// The sender is not the registered auditor.
    const ENOT_AUDITOR: u64 = 5;

    /// The provided auditors or auditor proofs are invalid.
    const EINVALID_AUDITORS: u64 = 6;

    /// The confidential asset account is already frozen.
    const EALREADY_FROZEN: u64 = 7;

    /// The confidential asset account is not frozen.
    const ENOT_FROZEN: u64 = 8;

    /// The pending balance must be zero for this operation.
    const ENOT_ZERO_BALANCE: u64 = 9;

    /// The operation requires the actual balance to be normalized.
    const ENORMALIZATION_REQUIRED: u64 = 10;

    /// The balance is already normalized and cannot be normalized again.
    const EALREADY_NORMALIZED: u64 = 11;

    /// The token is already allowed for confidential transfers.
    const ETOKEN_ENABLED: u64 = 12;

    /// The token is not allowed for confidential transfers.
    const ETOKEN_DISABLED: u64 = 13;

    /// The allow list is already enabled.
    const EALLOW_LIST_ENABLED: u64 = 14;

    /// The allow list is already disabled.
    const EALLOW_LIST_DISABLED: u64 = 15;

    /// An internal error occurred, indicating unexpected behavior.
    const EINTERNAL_ERROR: u64 = 16;

    /// Sender and recipient amounts encrypt different transfer amounts
    const EINVALID_SENDER_AMOUNT: u64 = 17;

    /// `sender_auditor_hint` exceeds [`MAX_SENDER_AUDITOR_HINT_BYTES`].
    const EAUDITOR_HINT_TOO_LONG: u64 = 18;

    /// Dispatchable fungible asset types (those with custom withdraw, deposit, balance, or
    /// supply hooks) are not yet supported in confidential transfers.
    const EUNSAFE_DISPATCHABLE_FA: u64 = 19;

    /// No confidential asset pool exists for the given asset type.
    const ENO_CONFIDENTIAL_ASSET_POOL: u64 = 20;

    /// Chain auditor not configured; confidential transfers cannot proceed.
    const ECHAIN_AUDITOR_NOT_SET: u64 = 21;

    /// Signer is not the FA metadata object's root owner.
    const ENOT_ASSET_ISSUER: u64 = 22;

    /// Chain-auditor admin not assigned by governance.
    const ECHAIN_AUDITOR_ADMIN_NOT_SET: u64 = 23;

    /// Signer is not the configured chain-auditor admin.
    const ENOT_CHAIN_AUDITOR_ADMIN: u64 = 24;

    //
    // Constants
    //

    /// Maximum length (bytes) of the opaque `sender_auditor_hint` passed to [`confidential_transfer`].
    const MAX_SENDER_AUDITOR_HINT_BYTES: u64 = 256;

    /// The maximum number of transactions can be aggregated on the pending balance before rollover is required.
    const MAX_TRANSFERS_BEFORE_ROLLOVER: u64 = 65534;

    /// The mainnet chain ID. If the chain ID is 1, the allow list is enabled.
    const MAINNET_CHAIN_ID: u8 = 1;

    //
    // Structs
    //

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

    /// One entry in an auditor key history vector — used for both the chain-level auditor
    /// (on [`GlobalConfig`]) and the per-asset auditor (on [`FAConfig`]). Rotated keys are
    /// retained so transfers stamped with a prior epoch can still be decrypted.
    struct AuditorEntry has store, drop, copy {
        ek: twisted_elgamal::CompressedPubkey,
        /// First epoch in which `ek` was the active auditor key. Monotonically increasing
        /// per layer (chain or asset).
        activated_at_epoch: u64,
        /// Epoch at which this entry was deactivated (i.e. the `activated_at_epoch` of its
        /// successor). `0` means the entry is still the active key.
        deactivated_at_epoch: u64,
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
        /// [`Transferred`] event.
        chain_auditor_epoch: u64,

        /// Append-only history of chain auditor keys. Each entry's
        /// `[activated_at_epoch, deactivated_at_epoch)` half-open interval is the range
        /// of `chain_auditor_epoch` values during which it was active.
        chain_auditor_history: vector<AuditorEntry>,
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

        /// Bumped on every [`set_asset_auditor`] call. Stamped on each [`Transferred`]
        /// event for this asset.
        asset_auditor_epoch: u64,

        /// Append-only history of asset auditor keys. See [`AuditorEntry`].
        asset_auditor_history: vector<AuditorEntry>,
    }

    //
    // Events
    //

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
        /// and stamped here even if the current `asset_auditor_ek` is `None`. Consult
        /// [`FAConfig.asset_auditor_history`] to recover the key (if any) active at this
        /// epoch.
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

    //
    // Module initialization, done only once when this module is first published on the blockchain
    //

    fun init_module(deployer: &signer) {
        assert!(
            bulletproofs::get_max_range_bits() >= confidential_proof::get_bulletproofs_num_bits(),
            error::internal(ERANGE_PROOF_SYSTEM_HAS_INSUFFICIENT_RANGE)
        );

        let deployer_address = signer::address_of(deployer);

        let global_config_ctor_ref = &object::create_object(deployer_address);

        move_to(deployer, GlobalConfig {
            allow_list_enabled: chain_id::get() == MAINNET_CHAIN_ID,
            extend_ref: object::generate_extend_ref(global_config_ctor_ref),
            chain_auditor_ek: std::option::none(),
            chain_auditor_epoch: 0,
            chain_auditor_history: vector[],
            chain_auditor_admin: std::option::none(),
        });
    }

    //
    // Entry functions
    //

    /// Registers an account for a specified token. Users must register an account for each token they
    /// intend to transact with.
    ///
    /// Users are also responsible for generating a Twisted ElGamal key pair on their side.
    public entry fun register(
        sender: &signer,
        token: Object<Metadata>,
        ek: vector<u8>,
        registration_proof_commitment: vector<u8>,
        registration_proof_response: vector<u8>) acquires GlobalConfig, FAConfig
    {
        let ek = twisted_elgamal::new_pubkey_from_bytes(ek).extract();

        // Verify registration proof (ZKPoK of decryption key)
        let cid = (chain_id::get() as u8);
        let user = signer::address_of(sender);
        confidential_proof::verify_registration_proof(
            cid,
            user,
            @aptos_experimental,
            &ek,
            object::object_address(&token),
            registration_proof_commitment,
            registration_proof_response
        );

        register_internal(sender, token, ek);
    }

    /// Brings tokens into the protocol, transferring the passed amount from the sender's primary FA store
    /// to the pending balance of the recipient.
    /// The initial confidential balance is publicly visible, as entering the protocol requires a normal transfer.
    /// However, tokens within the protocol become obfuscated through confidential transfers, ensuring privacy in
    /// subsequent transactions.
    public entry fun deposit_to(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        amount: u64) acquires ConfidentialAssetStore, GlobalConfig, FAConfig
    {
        deposit_to_internal(sender, token, to, amount)
    }

    /// The same as `deposit_to`, but the recipient is the sender.
    public entry fun deposit(
        sender: &signer,
        token: Object<Metadata>,
        amount: u64) acquires ConfidentialAssetStore, GlobalConfig, FAConfig
    {
        deposit_to_internal(sender, token, signer::address_of(sender), amount)
    }

    /// The same as `deposit_to`, but converts coins to missing FA first.
    public entry fun deposit_coins_to<CoinType>(
        sender: &signer,
        to: address,
        amount: u64) acquires ConfidentialAssetStore, GlobalConfig, FAConfig
    {
        let token = ensure_sufficient_fa<CoinType>(sender, amount).extract();

        deposit_to_internal(sender, token, to, amount)
    }

    /// The same as `deposit`, but converts coins to missing FA first.
    public entry fun deposit_coins<CoinType>(
        sender: &signer,
        amount: u64) acquires ConfidentialAssetStore, GlobalConfig, FAConfig
    {
        let token = ensure_sufficient_fa<CoinType>(sender, amount).extract();

        deposit_to_internal(sender, token, signer::address_of(sender), amount)
    }

    /// Brings tokens out of the protocol by transferring the specified amount from the sender's actual balance to
    /// the recipient's primary FA store.
    /// The withdrawn amount is publicly visible, as this process requires a normal transfer.
    /// The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.
    public entry fun withdraw_to(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_balance: vector<u8>,
        zkrp_new_balance: vector<u8>,
        sigma_proof: vector<u8>) acquires ConfidentialAssetStore, GlobalConfig
    {
        let new_balance = confidential_balance::new_actual_balance_from_bytes(new_balance).extract();
        let proof = confidential_proof::deserialize_withdrawal_proof(sigma_proof, zkrp_new_balance).extract();

        withdraw_to_internal(sender, token, to, amount, new_balance, proof);
    }

    /// The same as `withdraw_to`, but the recipient is the sender.
    public entry fun withdraw(
        sender: &signer,
        token: Object<Metadata>,
        amount: u64,
        new_balance: vector<u8>,
        zkrp_new_balance: vector<u8>,
        sigma_proof: vector<u8>) acquires ConfidentialAssetStore, GlobalConfig
    {
        withdraw_to(
            sender,
            token,
            signer::address_of(sender),
            amount,
            new_balance,
            zkrp_new_balance,
            sigma_proof
        )
    }

    /// Transfers tokens from the sender's actual balance to the recipient's pending balance.
    /// The function hides the transferred amount while keeping the sender and recipient addresses visible.
    /// The sender encrypts the transferred amount with the recipient's encryption key and the function updates the
    /// recipient's confidential balance homomorphically.
    /// Additionally, the sender encrypts the transferred amount with each auditor's EK, allowing auditors to decrypt
    /// it on their side. The combined auditor list (`auditor_eks` / `auditor_amounts`) has a fixed prefix layout:
    ///
    /// ```text
    ///   [0]   chain-level compliance auditor (always required; configured via `set_chain_auditor`)
    ///   [1]   asset-specific auditor         (required iff `get_asset_auditor(token).is_some()`)
    ///   [2..] voluntary auditors             (sender's choice; ordered)
    /// ```
    ///
    /// Aborts with [`ECHAIN_AUDITOR_NOT_SET`] when the chain-level auditor has not yet been configured.
    /// The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.
    ///
    /// `sender_auditor_hint` is emitted on [`Transferred`] and is **bound into the transfer sigma Fiat–Shamir
    /// transcript** (must match the hint used when generating the proof). Length must not exceed
    /// [`MAX_SENDER_AUDITOR_HINT_BYTES`].
    public entry fun confidential_transfer(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        new_balance: vector<u8>,
        sender_amount: vector<u8>,
        recipient_amount: vector<u8>,
        auditor_eks: vector<u8>,
        auditor_amounts: vector<u8>,
        zkrp_new_balance: vector<u8>,
        zkrp_transfer_amount: vector<u8>,
        sigma_proof: vector<u8>,
        sender_auditor_hint: vector<u8>) acquires ConfidentialAssetStore, FAConfig, GlobalConfig
    {
        let new_balance = confidential_balance::new_actual_balance_from_bytes(new_balance).extract();
        let sender_amount = confidential_balance::new_pending_balance_from_bytes(sender_amount).extract();
        let recipient_amount = confidential_balance::new_pending_balance_from_bytes(recipient_amount).extract();
        let auditor_eks = deserialize_auditor_eks(auditor_eks).extract();
        let auditor_amounts = deserialize_auditor_amounts(auditor_amounts).extract();
        let proof = confidential_proof::deserialize_transfer_proof(
            sigma_proof,
            zkrp_new_balance,
            zkrp_transfer_amount
        ).extract();

        confidential_transfer_internal(
            sender,
            token,
            to,
            new_balance,
            sender_amount,
            recipient_amount,
            auditor_eks,
            auditor_amounts,
            proof,
            sender_auditor_hint
        )
    }

    #[view]
    /// Returns the maximum allowed `sender_auditor_hint` length for [`confidential_transfer`].
    public fun max_sender_auditor_hint_bytes(): u64 {
        MAX_SENDER_AUDITOR_HINT_BYTES
    }

    /// Rotates the encryption key for the user's confidential balance, updating it to a new encryption key.
    /// The function ensures that the pending balance is zero before the key rotation, requiring the sender to
    /// call `rollover_pending_balance_and_freeze` beforehand if necessary.
    /// The sender provides their new normalized confidential balance, encrypted with the new encryption key and fresh randomness
    /// to preserve privacy.
    public entry fun rotate_encryption_key(
        sender: &signer,
        token: Object<Metadata>,
        new_ek: vector<u8>,
        new_balance: vector<u8>,
        zkrp_new_balance: vector<u8>,
        sigma_proof: vector<u8>) acquires ConfidentialAssetStore
    {
        let new_ek = twisted_elgamal::new_pubkey_from_bytes(new_ek).extract();
        let new_balance = confidential_balance::new_actual_balance_from_bytes(new_balance).extract();
        let proof = confidential_proof::deserialize_rotation_proof(sigma_proof, zkrp_new_balance).extract();

        rotate_encryption_key_internal(sender, token, new_ek, new_balance, proof);
    }

    /// Adjusts each chunk to fit into defined 16-bit bounds to prevent overflows.
    /// Most functions perform implicit normalization by accepting a new normalized confidential balance as a parameter.
    /// However, explicit normalization is required before rolling over the pending balance, as multiple rolls may cause
    /// chunk overflows.
    /// The sender provides their new normalized confidential balance, encrypted with fresh randomness to preserve privacy.
    public entry fun normalize(
        sender: &signer,
        token: Object<Metadata>,
        new_balance: vector<u8>,
        zkrp_new_balance: vector<u8>,
        sigma_proof: vector<u8>) acquires ConfidentialAssetStore
    {
        let new_balance = confidential_balance::new_actual_balance_from_bytes(new_balance).extract();
        let proof = confidential_proof::deserialize_normalization_proof(sigma_proof, zkrp_new_balance).extract();

        normalize_internal(sender, token, new_balance, proof);
    }

    /// Freezes the confidential account for the specified token, disabling all incoming transactions.
    public entry fun freeze_token(sender: &signer, token: Object<Metadata>) acquires ConfidentialAssetStore {
        freeze_token_internal(sender, token);
    }

    /// Unfreezes the confidential account for the specified token, re-enabling incoming transactions.
    public entry fun unfreeze_token(sender: &signer, token: Object<Metadata>) acquires ConfidentialAssetStore {
        unfreeze_token_internal(sender, token);
    }

    /// Adds the pending balance to the actual balance for the specified token, resetting the pending balance to zero.
    /// This operation is necessary to use tokens from the pending balance for outgoing transactions.
    public entry fun rollover_pending_balance(
        sender: &signer,
        token: Object<Metadata>) acquires ConfidentialAssetStore
    {
        rollover_pending_balance_internal(sender, token);
    }

    /// Before calling `rotate_encryption_key`, we need to rollover the pending balance and freeze the token to prevent
    /// any new payments being come.
    public entry fun rollover_pending_balance_and_freeze(
        sender: &signer,
        token: Object<Metadata>) acquires ConfidentialAssetStore
    {
        rollover_pending_balance(sender, token);
        freeze_token(sender, token);
    }

    /// After rotating the encryption key, we may want to unfreeze the token to allow payments.
    /// This function facilitates making both calls in a single transaction.
    public entry fun rotate_encryption_key_and_unfreeze(
        sender: &signer,
        token: Object<Metadata>,
        new_ek: vector<u8>,
        new_confidential_balance: vector<u8>,
        zkrp_new_balance: vector<u8>,
        rotate_proof: vector<u8>) acquires ConfidentialAssetStore
    {
        rotate_encryption_key(sender, token, new_ek, new_confidential_balance, zkrp_new_balance, rotate_proof);
        unfreeze_token(sender, token);
    }

    //
    // Public governance functions
    //

    /// Enables the allow list, restricting confidential transfers to tokens on the allow list.
    public fun enable_allow_list(aptos_framework: &signer) acquires GlobalConfig {
        system_addresses::assert_aptos_framework(aptos_framework);

        let global_config = borrow_global_mut<GlobalConfig>(@aptos_experimental);

        assert!(!global_config.allow_list_enabled, error::invalid_state(EALLOW_LIST_ENABLED));

        global_config.allow_list_enabled = true;

        event::emit(AllowListChanged { enabled: true });
    }

    /// Disables the allow list, allowing confidential transfers for all tokens.
    public fun disable_allow_list(aptos_framework: &signer) acquires GlobalConfig {
        system_addresses::assert_aptos_framework(aptos_framework);

        let global_config = borrow_global_mut<GlobalConfig>(@aptos_experimental);

        assert!(global_config.allow_list_enabled, error::invalid_state(EALLOW_LIST_DISABLED));

        global_config.allow_list_enabled = false;

        event::emit(AllowListChanged { enabled: false });
    }

    /// Enables confidential transfers for the specified token.
    public fun enable_token(aptos_framework: &signer, token: Object<Metadata>) acquires FAConfig, GlobalConfig {
        system_addresses::assert_aptos_framework(aptos_framework);

        let fa_config = borrow_global_mut<FAConfig>(ensure_fa_config_exists(token));

        assert!(!fa_config.allowed, error::invalid_state(ETOKEN_ENABLED));

        fa_config.allowed = true;

        event::emit(TokenAllowChanged {
            asset_type: object::object_address(&token),
            allowed: true,
        });
    }

    /// Disables confidential transfers for the specified token.
    public fun disable_token(aptos_framework: &signer, token: Object<Metadata>) acquires FAConfig, GlobalConfig {
        system_addresses::assert_aptos_framework(aptos_framework);

        let fa_config = borrow_global_mut<FAConfig>(ensure_fa_config_exists(token));

        assert!(fa_config.allowed, error::invalid_state(ETOKEN_DISABLED));

        fa_config.allowed = false;

        event::emit(TokenAllowChanged {
            asset_type: object::object_address(&token),
            allowed: false,
        });
    }

    /// Sets, rotates, or clears the asset-specific auditor key for `token`. Pass an empty
    /// `new_auditor_ek` to clear. Bumps `asset_auditor_epoch` and appends to history.
    ///
    /// Callable by `object::root_owner(token)`; aborts with [`ENOT_ASSET_ISSUER`] otherwise.
    /// Rotation invalidates pending transfer proofs (auditor key is bound into the
    /// Fiat–Shamir transcript) — senders must regenerate against the new key.
    public entry fun set_asset_auditor(
        issuer: &signer,
        token: Object<Metadata>,
        new_auditor_ek: vector<u8>) acquires FAConfig, GlobalConfig
    {
        assert!(
            object::root_owner(token) == signer::address_of(issuer),
            error::permission_denied(ENOT_ASSET_ISSUER)
        );

        let fa_config = borrow_global_mut<FAConfig>(ensure_fa_config_exists(token));

        let new_ek_opt = if (new_auditor_ek.length() == 0) {
            std::option::none()
        } else {
            let parsed = twisted_elgamal::new_pubkey_from_bytes(new_auditor_ek);
            assert!(parsed.is_some(), error::invalid_argument(EAUDITOR_EK_DESERIALIZATION_FAILED));
            parsed
        };

        let new_epoch = fa_config.asset_auditor_epoch + 1;
        let prior_ek = fa_config.asset_auditor_ek;

        if (prior_ek.is_some()) {
            let history_len = fa_config.asset_auditor_history.length();
            assert!(history_len > 0, error::internal(EINTERNAL_ERROR));
            let prior_entry = fa_config.asset_auditor_history.borrow_mut(history_len - 1);
            prior_entry.deactivated_at_epoch = new_epoch;
        };

        if (new_ek_opt.is_some()) {
            fa_config.asset_auditor_history.push_back(AuditorEntry {
                ek: *new_ek_opt.borrow(),
                activated_at_epoch: new_epoch,
                deactivated_at_epoch: 0,
            });
        };

        fa_config.asset_auditor_ek = new_ek_opt;
        fa_config.asset_auditor_epoch = new_epoch;

        event::emit(AssetAuditorChanged {
            asset_type: object::object_address(&token),
            new_asset_auditor_ek: fa_config.asset_auditor_ek,
            new_epoch,
        });
    }

    /// Designates (or rotates) the account authorized to call [`set_chain_auditor`].
    /// Governance-only. No clear form — rotate to a successor instead.
    public entry fun set_chain_auditor_admin(
        aptos_framework: &signer,
        new_admin: address) acquires GlobalConfig
    {
        system_addresses::assert_aptos_framework(aptos_framework);

        let global_config = borrow_global_mut<GlobalConfig>(@aptos_experimental);
        global_config.chain_auditor_admin = std::option::some(new_admin);

        event::emit(ChainAuditorAdminChanged { new_admin });
    }

    /// Sets, rotates, or clears the chain-level auditor key. Pass an empty
    /// `new_chain_auditor_ek` to clear (which disables all confidential transfers until a
    /// successor is set). Bumps `chain_auditor_epoch` and appends to history.
    ///
    /// Callable only by [`GlobalConfig.chain_auditor_admin`]. Aborts with
    /// [`ECHAIN_AUDITOR_ADMIN_NOT_SET`] before an admin is assigned, or
    /// [`ENOT_CHAIN_AUDITOR_ADMIN`] for any other signer. Rotation invalidates pending
    /// transfer proofs — see [`set_asset_auditor`].
    public entry fun set_chain_auditor(
        admin: &signer,
        new_chain_auditor_ek: vector<u8>) acquires GlobalConfig
    {
        let global_config = borrow_global_mut<GlobalConfig>(@aptos_experimental);

        assert!(
            global_config.chain_auditor_admin.is_some(),
            error::invalid_state(ECHAIN_AUDITOR_ADMIN_NOT_SET)
        );
        assert!(
            *global_config.chain_auditor_admin.borrow() == signer::address_of(admin),
            error::permission_denied(ENOT_CHAIN_AUDITOR_ADMIN)
        );

        let new_ek_opt = if (new_chain_auditor_ek.length() == 0) {
            std::option::none()
        } else {
            let parsed = twisted_elgamal::new_pubkey_from_bytes(new_chain_auditor_ek);
            assert!(parsed.is_some(), error::invalid_argument(EAUDITOR_EK_DESERIALIZATION_FAILED));
            parsed
        };

        let new_epoch = global_config.chain_auditor_epoch + 1;
        let prior_ek = global_config.chain_auditor_ek;

        if (prior_ek.is_some()) {
            let history_len = global_config.chain_auditor_history.length();
            assert!(history_len > 0, error::internal(EINTERNAL_ERROR));
            let prior_entry = global_config.chain_auditor_history.borrow_mut(history_len - 1);
            prior_entry.deactivated_at_epoch = new_epoch;
        };

        if (new_ek_opt.is_some()) {
            global_config.chain_auditor_history.push_back(AuditorEntry {
                ek: *new_ek_opt.borrow(),
                activated_at_epoch: new_epoch,
                deactivated_at_epoch: 0,
            });
        };

        global_config.chain_auditor_ek = new_ek_opt;
        global_config.chain_auditor_epoch = new_epoch;

        event::emit(ChainAuditorChanged {
            new_chain_auditor_ek: global_config.chain_auditor_ek,
            new_epoch,
        });
    }

    //
    // Public view functions
    //

    #[view]
    /// Checks if the user has a confidential asset store for the specified token.
    public fun has_confidential_asset_store(user: address, token: Object<Metadata>): bool {
        exists<ConfidentialAssetStore>(get_user_address(user, token))
    }

    #[view]
    /// Checks if the token is allowed for confidential transfers.
    public fun is_token_allowed(token: Object<Metadata>): bool acquires GlobalConfig, FAConfig {
        if (!is_allow_list_enabled()) {
            return true
        };

        let fa_config_address = get_fa_config_address(token);

        if (!exists<FAConfig>(fa_config_address)) {
            return false
        };

        borrow_global<FAConfig>(fa_config_address).allowed
    }

    #[view]
    /// Checks if the allow list is enabled.
    /// If the allow list is enabled, only tokens from the allow list can be transferred.
    /// Otherwise, all tokens are allowed.
    public fun is_allow_list_enabled(): bool acquires GlobalConfig {
        borrow_global<GlobalConfig>(@aptos_experimental).allow_list_enabled
    }

    #[view]
    /// Returns the pending balance of the user for the specified token.
    public fun pending_balance(
        owner: address,
        token: Object<Metadata>): confidential_balance::CompressedConfidentialBalance acquires ConfidentialAssetStore
    {
        assert!(has_confidential_asset_store(owner, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        let ca_store = borrow_global<ConfidentialAssetStore>(get_user_address(owner, token));

        ca_store.pending_balance
    }

    #[view]
    /// Returns the actual balance of the user for the specified token.
    public fun actual_balance(
        owner: address,
        token: Object<Metadata>): confidential_balance::CompressedConfidentialBalance acquires ConfidentialAssetStore
    {
        assert!(has_confidential_asset_store(owner, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        let ca_store = borrow_global<ConfidentialAssetStore>(get_user_address(owner, token));

        ca_store.actual_balance
    }

    #[view]
    /// Returns the encryption key (EK) of the user for the specified token.
    public fun encryption_key(
        user: address,
        token: Object<Metadata>): twisted_elgamal::CompressedPubkey acquires ConfidentialAssetStore
    {
        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token)).ek
    }

    #[view]
    /// Checks if the user's actual balance is normalized for the specified token.
    public fun is_normalized(user: address, token: Object<Metadata>): bool acquires ConfidentialAssetStore {
        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        borrow_global<ConfidentialAssetStore>(get_user_address(user, token)).normalized
    }

    #[view]
    /// Checks if the user's confidential asset store is frozen for the specified token.
    public fun is_frozen(user: address, token: Object<Metadata>): bool acquires ConfidentialAssetStore {
        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        borrow_global<ConfidentialAssetStore>(get_user_address(user, token)).frozen
    }

    #[view]
    /// Asset auditor encryption key for `token`, or `None` if unset.
    public fun get_asset_auditor(
        token: Object<Metadata>): Option<twisted_elgamal::CompressedPubkey> acquires FAConfig, GlobalConfig
    {
        let fa_config_address = get_fa_config_address(token);

        if (!is_allow_list_enabled() && !exists<FAConfig>(fa_config_address)) {
            return std::option::none();
        };

        borrow_global<FAConfig>(fa_config_address).asset_auditor_ek
    }

    #[view]
    /// Asset auditor epoch for `token`. `0` if no asset auditor has been set.
    public fun get_asset_auditor_epoch(token: Object<Metadata>): u64 acquires FAConfig, GlobalConfig {
        let fa_config_address = get_fa_config_address(token);
        if (!exists<FAConfig>(fa_config_address)) {
            return 0;
        };
        borrow_global<FAConfig>(fa_config_address).asset_auditor_epoch
    }

    #[view]
    /// Append-only history of asset auditor keys for `token`.
    public fun get_asset_auditor_history(
        token: Object<Metadata>): vector<AuditorEntry> acquires FAConfig, GlobalConfig
    {
        let fa_config_address = get_fa_config_address(token);
        if (!exists<FAConfig>(fa_config_address)) {
            return vector[];
        };
        borrow_global<FAConfig>(fa_config_address).asset_auditor_history
    }

    #[view]
    /// Chain auditor encryption key, or `None` if unset.
    public fun get_chain_auditor(): Option<twisted_elgamal::CompressedPubkey> acquires GlobalConfig {
        borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_ek
    }

    #[view]
    /// Chain auditor epoch. `0` before any chain auditor has been configured.
    public fun get_chain_auditor_epoch(): u64 acquires GlobalConfig {
        borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_epoch
    }

    #[view]
    /// Append-only history of chain auditor keys.
    public fun get_chain_auditor_history(): vector<AuditorEntry> acquires GlobalConfig {
        borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_history
    }

    #[view]
    /// Chain-auditor admin address, or `None` if governance hasn't assigned one yet.
    public fun get_chain_auditor_admin(): Option<address> acquires GlobalConfig {
        borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_admin
    }

    #[view]
    /// Returns the circulating supply of the confidential asset.
    public fun confidential_asset_balance(token: Object<Metadata>): u64 acquires GlobalConfig {
        fungible_asset::balance(get_pool_fa_store(token))
    }

    //
    // Public functions that correspond to the entry functions and don't require serializtion of the input data.
    // These function can be useful for external contracts that want to integrate with the Confidential Asset protocol.
    //

    /// Implementation of the `register` entry function.
    public fun register_internal(
        sender: &signer,
        token: Object<Metadata>,
        ek: twisted_elgamal::CompressedPubkey) acquires GlobalConfig, FAConfig
    {
        assert!(is_safe_for_confidentiality(&token), error::invalid_argument(EUNSAFE_DISPATCHABLE_FA));
        assert!(is_token_allowed(token), error::invalid_argument(ETOKEN_DISABLED));

        let user = signer::address_of(sender);

        assert!(!has_confidential_asset_store(user, token), error::already_exists(ECA_STORE_ALREADY_PUBLISHED));

        let ca_store = ConfidentialAssetStore {
            frozen: false,
            normalized: true,
            pending_counter: 0,
            pending_balance: confidential_balance::new_compressed_pending_balance_no_randomness(),
            actual_balance: confidential_balance::new_compressed_actual_balance_no_randomness(),
            ek,
        };

        move_to(&get_user_signer(sender, token), ca_store);

        event::emit(Registered {
            addr: user,
            asset_type: object::object_address(&token),
            ek,
        });
    }

    /// Implementation of the `deposit_to` entry function.
    public fun deposit_to_internal(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        amount: u64) acquires ConfidentialAssetStore, GlobalConfig, FAConfig
    {
        assert!(is_safe_for_confidentiality(&token), error::invalid_argument(EUNSAFE_DISPATCHABLE_FA));
        assert!(is_token_allowed(token), error::invalid_argument(ETOKEN_DISABLED));
        assert!(!is_frozen(to, token), error::invalid_state(EALREADY_FROZEN));

        let from = signer::address_of(sender);

        let pool_fa_store = ensure_pool_fa_store(token);

        let pool_before = fungible_asset::balance(pool_fa_store);
        let sender_fa_store = primary_fungible_store::primary_store(from, token);
        dispatchable_fungible_asset::transfer(sender, sender_fa_store, pool_fa_store, amount);

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(to, token));
        let pending_balance = confidential_balance::decompress_balance(&ca_store.pending_balance);

        confidential_balance::add_balances_mut(
            &mut pending_balance,
            &confidential_balance::new_pending_balance_u64_no_randonmess(amount)
        );

        ca_store.pending_balance = confidential_balance::compress_balance(&pending_balance);

        assert!(
            ca_store.pending_counter < MAX_TRANSFERS_BEFORE_ROLLOVER,
            error::invalid_argument(EINTERNAL_ERROR)
        );

        ca_store.pending_counter += 1;

        event::emit(Deposited {
            from,
            to,
            asset_type: object::object_address(&token),
            amount,
            new_pending_balance: ca_store.pending_balance,
        });

        assert!(
            amount == fungible_asset::balance(pool_fa_store) - pool_before,
            error::invalid_argument(EUNSAFE_DISPATCHABLE_FA)
        );
    }

    /// Implementation of the `withdraw_to` entry function.
    /// Withdrawals are always allowed, regardless of the token allow status.
    public fun withdraw_to_internal(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        amount: u64,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: WithdrawalProof) acquires ConfidentialAssetStore, GlobalConfig
    {
        assert!(is_safe_for_confidentiality(&token), error::invalid_argument(EUNSAFE_DISPATCHABLE_FA));

        let from = signer::address_of(sender);

        let sender_ek = encryption_key(from, token);

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(from, token));
        let current_balance = confidential_balance::decompress_balance(&ca_store.actual_balance);

        let cid = (chain_id::get() as u8);
        confidential_proof::verify_withdrawal_proof(
            cid,
            from,
            @aptos_experimental,
            object::object_address(&token),
            &sender_ek,
            amount,
            &current_balance,
            &new_balance,
            &proof
        );

        ca_store.normalized = true;
        ca_store.actual_balance = confidential_balance::compress_balance(&new_balance);

        let pool_fa_store = get_pool_fa_store(token);
        let pool_before = fungible_asset::balance(pool_fa_store);
        let recipient_fa_store = primary_fungible_store::ensure_primary_store_exists(to, token);
        dispatchable_fungible_asset::transfer(&get_fa_store_signer(), pool_fa_store, recipient_fa_store, amount);

        event::emit(Withdrawn {
            from,
            to,
            asset_type: object::object_address(&token),
            amount,
            new_available_balance: ca_store.actual_balance,
        });

        assert!(
            amount == pool_before - fungible_asset::balance(pool_fa_store),
            error::invalid_argument(EUNSAFE_DISPATCHABLE_FA)
        );
    }

    /// Implementation of the `confidential_transfer` entry function.
    public fun confidential_transfer_internal(
        sender: &signer,
        token: Object<Metadata>,
        to: address,
        new_balance: confidential_balance::ConfidentialBalance,
        sender_amount: confidential_balance::ConfidentialBalance,
        recipient_amount: confidential_balance::ConfidentialBalance,
        auditor_eks: vector<twisted_elgamal::CompressedPubkey>,
        auditor_amounts: vector<confidential_balance::ConfidentialBalance>,
        proof: TransferProof,
        sender_auditor_hint: vector<u8>) acquires ConfidentialAssetStore, FAConfig, GlobalConfig
    {
        assert!(is_safe_for_confidentiality(&token), error::invalid_argument(EUNSAFE_DISPATCHABLE_FA));
        assert!(is_token_allowed(token), error::invalid_argument(ETOKEN_DISABLED));
        assert!(!is_frozen(to, token), error::invalid_state(EALREADY_FROZEN));
        assert!(
            validate_auditors(token, &recipient_amount, &auditor_eks, &auditor_amounts, &proof),
            error::invalid_argument(EINVALID_AUDITORS)
        );
        assert!(
            confidential_balance::balance_c_equals(&sender_amount, &recipient_amount),
            error::invalid_argument(EINVALID_SENDER_AMOUNT)
        );
        assert!(
            sender_auditor_hint.length() <= MAX_SENDER_AUDITOR_HINT_BYTES,
            error::invalid_argument(EAUDITOR_HINT_TOO_LONG)
        );

        let from = signer::address_of(sender);

        let sender_ek = encryption_key(from, token);
        let recipient_ek = encryption_key(to, token);

        let sender_ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(from, token));

        let sender_current_actual_balance = confidential_balance::decompress_balance(
            &sender_ca_store.actual_balance
        );

        let cid = (chain_id::get() as u8);
        confidential_proof::verify_transfer_proof(
            cid,
            from,
            @aptos_experimental,
            object::object_address(&token),
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

        sender_ca_store.normalized = true;
        let new_sender_available_balance = confidential_balance::compress_balance(&new_balance);
        sender_ca_store.actual_balance = new_sender_available_balance;

        let amount = confidential_balance::compress_balance(&recipient_amount);
        let ek_volun_auds = confidential_proof::transfer_proof_ek_volun_auds_flat_bytes(&proof);

        // Cannot create multiple mutable references to the same type, so we need to drop it
        let ConfidentialAssetStore { .. } = sender_ca_store;

        let recipient_ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(to, token));

        assert!(
            recipient_ca_store.pending_counter < MAX_TRANSFERS_BEFORE_ROLLOVER,
            error::invalid_argument(EINTERNAL_ERROR)
        );

        let recipient_pending_balance = confidential_balance::decompress_balance(
            &recipient_ca_store.pending_balance
        );
        confidential_balance::add_balances_mut(&mut recipient_pending_balance, &recipient_amount);

        recipient_ca_store.pending_counter += 1;
        let new_recip_pending_balance = confidential_balance::compress_balance(&recipient_pending_balance);
        recipient_ca_store.pending_balance = new_recip_pending_balance;

        let chain_auditor_epoch = borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_epoch;
        let asset_auditor_epoch = get_asset_auditor_epoch(token);

        event::emit(Transferred {
            from,
            to,
            asset_type: object::object_address(&token),
            amount,
            ek_volun_auds,
            sender_auditor_hint,
            new_sender_available_balance,
            new_recip_pending_balance,
            memo: vector[],
            chain_auditor_epoch,
            asset_auditor_epoch,
        });
    }

    /// Implementation of the `rotate_encryption_key` entry function.
    public fun rotate_encryption_key_internal(
        sender: &signer,
        token: Object<Metadata>,
        new_ek: twisted_elgamal::CompressedPubkey,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: RotationProof) acquires ConfidentialAssetStore
    {
        let user = signer::address_of(sender);
        let current_ek = encryption_key(user, token);

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token));

        let pending_balance = confidential_balance::decompress_balance(&ca_store.pending_balance);

        // We need to ensure that the pending balance is zero before rotating the key.
        // To guarantee this, the user must call `rollover_pending_balance_and_freeze` beforehand.
        assert!(confidential_balance::is_zero_balance(&pending_balance), error::invalid_state(ENOT_ZERO_BALANCE));

        let current_balance = confidential_balance::decompress_balance(&ca_store.actual_balance);

        let cid = (chain_id::get() as u8);
        confidential_proof::verify_rotation_proof(
            cid,
            user,
            @aptos_experimental,
            object::object_address(&token),
            &current_ek,
            &new_ek,
            &current_balance,
            &new_balance,
            &proof
        );

        ca_store.ek = new_ek;
        // We don't need to update the pending balance here, as it has been asserted to be zero.
        ca_store.actual_balance = confidential_balance::compress_balance(&new_balance);
        ca_store.normalized = true;

        event::emit(KeyRotated {
            addr: user,
            asset_type: object::object_address(&token),
            new_ek,
            new_available_balance: ca_store.actual_balance,
        });
    }

    /// Implementation of the `normalize` entry function.
    public fun normalize_internal(
        sender: &signer,
        token: Object<Metadata>,
        new_balance: confidential_balance::ConfidentialBalance,
        proof: NormalizationProof) acquires ConfidentialAssetStore
    {
        let user = signer::address_of(sender);
        let sender_ek = encryption_key(user, token);

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token));

        assert!(!ca_store.normalized, error::invalid_state(EALREADY_NORMALIZED));

        let current_balance = confidential_balance::decompress_balance(&ca_store.actual_balance);

        let cid = (chain_id::get() as u8);
        confidential_proof::verify_normalization_proof(
            cid,
            user,
            @aptos_experimental,
            object::object_address(&token),
            &sender_ek,
            &current_balance,
            &new_balance,
            &proof
        );

        ca_store.actual_balance = confidential_balance::compress_balance(&new_balance);
        ca_store.normalized = true;

        event::emit(Normalized {
            addr: user,
            asset_type: object::object_address(&token),
            new_available_balance: ca_store.actual_balance,
        });
    }

    /// Implementation of the `rollover_pending_balance` entry function.
    public fun rollover_pending_balance_internal(
        sender: &signer,
        token: Object<Metadata>) acquires ConfidentialAssetStore
    {
        let user = signer::address_of(sender);

        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token));

        assert!(ca_store.normalized, error::invalid_state(ENORMALIZATION_REQUIRED));

        let actual_balance = confidential_balance::decompress_balance(&ca_store.actual_balance);
        let pending_balance = confidential_balance::decompress_balance(&ca_store.pending_balance);

        confidential_balance::add_balances_mut(&mut actual_balance, &pending_balance);

        ca_store.normalized = false;
        ca_store.pending_counter = 0;
        ca_store.actual_balance = confidential_balance::compress_balance(&actual_balance);
        ca_store.pending_balance = confidential_balance::new_compressed_pending_balance_no_randomness();

        event::emit(RolledOver {
            addr: user,
            asset_type: object::object_address(&token),
            new_available_balance: ca_store.actual_balance,
        });
    }

    /// Implementation of the `freeze_token` entry function.
    public fun freeze_token_internal(
        sender: &signer,
        token: Object<Metadata>) acquires ConfidentialAssetStore
    {
        let user = signer::address_of(sender);

        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token));

        assert!(!ca_store.frozen, error::invalid_state(EALREADY_FROZEN));

        ca_store.frozen = true;

        event::emit(FreezeChanged {
            addr: user,
            asset_type: object::object_address(&token),
            frozen: true,
        });
    }

    /// Implementation of the `unfreeze_token` entry function.
    public fun unfreeze_token_internal(
        sender: &signer,
        token: Object<Metadata>) acquires ConfidentialAssetStore
    {
        let user = signer::address_of(sender);

        assert!(has_confidential_asset_store(user, token), error::not_found(ECA_STORE_NOT_PUBLISHED));

        let ca_store = borrow_global_mut<ConfidentialAssetStore>(get_user_address(user, token));

        assert!(ca_store.frozen, error::invalid_state(ENOT_FROZEN));

        ca_store.frozen = false;

        event::emit(FreezeChanged {
            addr: user,
            asset_type: object::object_address(&token),
            frozen: false,
        });
    }

    //
    // Private functions.
    //

    /// Returns whether the given asset type is safe for use in confidential transfers.
    ///
    /// Dispatchable fungible assets can override withdraw, deposit, balance, or supply
    /// behaviour in ways that are incompatible with encrypted on-chain balances (e.g.,
    /// fee-on-transfer tokens, rebasing balances, custom supply hooks). Until a safe
    /// integration path exists, only standard (non-dispatchable) FA types are accepted.
    fun is_safe_for_confidentiality(token: &Object<Metadata>): bool {
        !fungible_asset::is_asset_type_dispatchable(*token)
    }

    /// Ensures that the `FAConfig` object exists for the specified token.
    /// If the object does not exist, creates it.
    /// Used only for internal purposes.
    fun ensure_fa_config_exists(token: Object<Metadata>): address acquires GlobalConfig {
        let fa_config_address = get_fa_config_address(token);

        if (!exists<FAConfig>(fa_config_address)) {
            let fa_config_singer = get_fa_config_signer(token);

            move_to(&fa_config_singer, FAConfig {
                allowed: false,
                asset_auditor_ek: std::option::none(),
                asset_auditor_epoch: 0,
                asset_auditor_history: vector[],
            });
        };

        fa_config_address
    }

    /// Returns an object for handling all the FA primary stores, and returns a signer for it.
    fun get_fa_store_signer(): signer acquires GlobalConfig {
        object::generate_signer_for_extending(&borrow_global<GlobalConfig>(@aptos_experimental).extend_ref)
    }

    /// Returns the address that handles all the FA primary stores.
    fun get_fa_store_address(): address acquires GlobalConfig {
        object::address_from_extend_ref(&borrow_global<GlobalConfig>(@aptos_experimental).extend_ref)
    }

    /// Returns the pool's primary fungible store for the given token, aborting if it does not exist.
    fun get_pool_fa_store(token: Object<Metadata>): Object<FungibleStore> acquires GlobalConfig {
        let pool_addr = get_fa_store_address();
        assert!(primary_fungible_store::primary_store_exists(pool_addr, token), error::not_found(ENO_CONFIDENTIAL_ASSET_POOL));
        primary_fungible_store::primary_store(pool_addr, token)
    }

    /// Returns the pool's primary fungible store for the given token, creating it if necessary.
    fun ensure_pool_fa_store(token: Object<Metadata>): Object<FungibleStore> acquires GlobalConfig {
        primary_fungible_store::ensure_primary_store_exists(get_fa_store_address(), token)
    }

    /// Returns an object for handling the `ConfidentialAssetStore` and returns a signer for it.
    fun get_user_signer(user: &signer, token: Object<Metadata>): signer {
        let user_ctor = &object::create_named_object(user, construct_user_seed(token));

        object::generate_signer(user_ctor)
    }

    /// Returns the address that handles the user's `ConfidentialAssetStore` object for the specified user and token.
    fun get_user_address(user: address, token: Object<Metadata>): address {
        object::create_object_address(&user, construct_user_seed(token))
    }

    /// Returns an object for handling the `FAConfig`, and returns a signer for it.
    fun get_fa_config_signer(token: Object<Metadata>): signer acquires GlobalConfig {
        let fa_ext = &borrow_global<GlobalConfig>(@aptos_experimental).extend_ref;
        let fa_ext_signer = object::generate_signer_for_extending(fa_ext);

        let fa_ctor = &object::create_named_object(&fa_ext_signer, construct_fa_seed(token));

        object::generate_signer(fa_ctor)
    }

    /// Returns the address that handles primary FA store and `FAConfig` objects for the specified token.
    fun get_fa_config_address(token: Object<Metadata>): address acquires GlobalConfig {
        let fa_ext = &borrow_global<GlobalConfig>(@aptos_experimental).extend_ref;
        let fa_ext_address = object::address_from_extend_ref(fa_ext);

        object::create_object_address(&fa_ext_address, construct_fa_seed(token))
    }

    /// Constructs a unique seed for the user's `ConfidentialAssetStore` object.
    /// As all the `ConfidentialAssetStore`'s have the same type, we need to differentiate them by the seed.
    fun construct_user_seed(token: Object<Metadata>): vector<u8> {
        bcs::to_bytes(
            &string_utils::format2(
                &b"confidential_asset::{}::token::{}::user",
                @aptos_experimental,
                object::object_address(&token)
            )
        )
    }

    /// Constructs a unique seed for the FA's `FAConfig` object.
    /// As all the `FAConfig`'s have the same type, we need to differentiate them by the seed.
    fun construct_fa_seed(token: Object<Metadata>): vector<u8> {
        bcs::to_bytes(
            &string_utils::format2(
                &b"confidential_asset::{}::token::{}::fa",
                @aptos_experimental,
                object::object_address(&token)
            )
        )
    }

    /// Validates the auditor-related fields of a confidential transfer.
    ///
    /// Aborts with [`ECHAIN_AUDITOR_NOT_SET`] if no chain-level auditor has been
    /// configured (transfers cannot proceed in that state).
    ///
    /// Returns `false` (rejecting the transfer) if any of:
    /// - any `auditor_amount` does not encrypt the same plaintext as `transfer_amount`;
    /// - the lengths of `auditor_eks`, `auditor_amounts`, and the transfer-proof auditor
    ///   row count disagree;
    /// - `auditor_eks` is missing the required prefix (see slot layout below);
    /// - the prefix slot keys do not equal the active chain / asset auditor keys.
    ///
    /// **Slot layout of `auditor_eks`** (and `auditor_amounts`):
    /// ```text
    ///   [0]   chain-level auditor       (always required)
    ///   [1]   asset-specific auditor    (required iff `get_asset_auditor(token).is_some()`)
    ///   [2..] voluntary auditors        (sender's choice, ordered)
    /// ```
    /// Auditor identity at slots 0 and 1 is bound into the transfer's Fiat–Shamir
    /// transcript (via the order in which `auditor_eks` is hashed in
    /// `confidential_proof::fiat_shamir_transfer_sigma_proof_challenge`), so a sender
    /// cannot substitute one auditor's slot for another's.
    fun validate_auditors(
        token: Object<Metadata>,
        transfer_amount: &confidential_balance::ConfidentialBalance,
        auditor_eks: &vector<twisted_elgamal::CompressedPubkey>,
        auditor_amounts: &vector<confidential_balance::ConfidentialBalance>,
        proof: &TransferProof): bool acquires FAConfig, GlobalConfig
    {
        if (
            !auditor_amounts.all(|auditor_amount| {
                confidential_balance::balance_c_equals(transfer_amount, auditor_amount)
            })
        ) {
            return false
        };

        if (
            auditor_eks.length() != auditor_amounts.length() ||
                auditor_eks.length() != confidential_proof::auditors_count_in_transfer_proof(proof)
        ) {
            return false
        };

        let chain_auditor_ek_opt = borrow_global<GlobalConfig>(@aptos_experimental).chain_auditor_ek;
        assert!(chain_auditor_ek_opt.is_some(), error::invalid_state(ECHAIN_AUDITOR_NOT_SET));

        let asset_auditor_ek_opt = get_asset_auditor(token);
        let required_prefix = if (asset_auditor_ek_opt.is_some()) 2 else 1;

        if (auditor_eks.length() < required_prefix) {
            return false
        };

        let chain_auditor_point = twisted_elgamal::pubkey_to_point(&chain_auditor_ek_opt.extract());
        let slot0_point = twisted_elgamal::pubkey_to_point(&auditor_eks[0]);
        if (!ristretto255::point_equals(&chain_auditor_point, &slot0_point)) {
            return false
        };

        if (asset_auditor_ek_opt.is_some()) {
            let asset_auditor_point = twisted_elgamal::pubkey_to_point(&asset_auditor_ek_opt.extract());
            let slot1_point = twisted_elgamal::pubkey_to_point(&auditor_eks[1]);
            if (!ristretto255::point_equals(&asset_auditor_point, &slot1_point)) {
                return false
            };
        };

        true
    }

    /// Deserializes the auditor EKs from a byte array.
    /// Returns `Some(vector<twisted_elgamal::CompressedPubkey>)` if the deserialization is successful, otherwise `None`.
    fun deserialize_auditor_eks(
        auditor_eks_bytes: vector<u8>): Option<vector<twisted_elgamal::CompressedPubkey>>
    {
        if (auditor_eks_bytes.length() % 32 != 0) {
            return std::option::none()
        };

        let auditors_count = auditor_eks_bytes.length() / 32;

        let auditor_eks = vector::range(0, auditors_count).map(|i| {
            twisted_elgamal::new_pubkey_from_bytes(auditor_eks_bytes.slice(i * 32, (i + 1) * 32))
        });

        if (auditor_eks.any(|ek| ek.is_none())) {
            return std::option::none()
        };

        std::option::some(auditor_eks.map(|ek| ek.extract()))
    }

    /// Deserializes the auditor amounts from a byte array.
    /// Returns `Some(vector<confidential_balance::ConfidentialBalance>)` if the deserialization is successful, otherwise `None`.
    fun deserialize_auditor_amounts(
        auditor_amounts_bytes: vector<u8>): Option<vector<confidential_balance::ConfidentialBalance>>
    {
        if (auditor_amounts_bytes.length() % 256 != 0) {
            return std::option::none()
        };

        let auditors_count = auditor_amounts_bytes.length() / 256;

        let auditor_amounts = vector::range(0, auditors_count).map(|i| {
            confidential_balance::new_pending_balance_from_bytes(auditor_amounts_bytes.slice(i * 256, (i + 1) * 256))
        });

        if (auditor_amounts.any(|ek| ek.is_none())) {
            return std::option::none()
        };

        std::option::some(auditor_amounts.map(|balance| balance.extract()))
    }

    /// Converts coins to missing FA.
    /// Returns `Some(Object<Metadata>)` if user has a sufficient amount of FA to proceed, otherwise `None`.
    fun ensure_sufficient_fa<CoinType>(sender: &signer, amount: u64): Option<Object<Metadata>> {
        let user = signer::address_of(sender);
        let fa = coin::paired_metadata<CoinType>();

        if (fa.is_none()) {
            return fa;
        };

        let fa_balance = primary_fungible_store::balance(user, *fa.borrow());

        if (fa_balance >= amount) {
            return fa;
        };

        if (coin::balance<CoinType>(user) < amount) {
            return std::option::none();
        };

        let coin_amount = coin::withdraw<CoinType>(sender, amount - fa_balance);
        let fa_amount = coin::coin_to_fungible_asset(coin_amount);

        primary_fungible_store::deposit(user, fa_amount);

        fa
    }

    //
    // Test-only functions
    //

    #[test_only]
    public fun init_module_for_testing(deployer: &signer) {
        init_module(deployer)
    }

    #[test_only]
    /// Register without requiring a registration proof (for test convenience).
    public fun register_for_testing(
        sender: &signer,
        token: Object<Metadata>,
        ek: vector<u8>) acquires GlobalConfig, FAConfig
    {
        let ek = twisted_elgamal::new_pubkey_from_bytes(ek).extract();
        register_internal(sender, token, ek);
    }

    #[test_only]
    public fun verify_pending_balance(
        user: address,
        token: Object<Metadata>,
        user_dk: &Scalar,
        amount: u64): bool acquires ConfidentialAssetStore
    {
        let ca_store = borrow_global<ConfidentialAssetStore>(get_user_address(user, token));
        let pending_balance = confidential_balance::decompress_balance(&ca_store.pending_balance);

        confidential_balance::verify_pending_balance(&pending_balance, user_dk, amount)
    }

    #[test_only]
    public fun verify_actual_balance(
        user: address,
        token: Object<Metadata>,
        user_dk: &Scalar,
        amount: u128): bool acquires ConfidentialAssetStore
    {
        let ca_store = borrow_global<ConfidentialAssetStore>(get_user_address(user, token));
        let actual_balance = confidential_balance::decompress_balance(&ca_store.actual_balance);

        confidential_balance::verify_actual_balance(&actual_balance, user_dk, amount)
    }

    /// Pure serialization helpers (no `borrow_global`). Public so off-chain tooling and
    /// tooling can exercise the same entrypoints as tests without `#[test_only]` harness modules.
    public fun serialize_auditor_eks(auditor_eks: &vector<twisted_elgamal::CompressedPubkey>): vector<u8> {
        let auditor_eks_bytes = vector[];

        auditor_eks.for_each_ref(|auditor| {
            auditor_eks_bytes.append(twisted_elgamal::pubkey_to_bytes(auditor));
        });

        auditor_eks_bytes
    }

    public fun serialize_auditor_amounts(
        auditor_amounts: &vector<confidential_balance::ConfidentialBalance>
    ): vector<u8> {
        let auditor_amounts_bytes = vector[];

        auditor_amounts.for_each_ref(|balance| {
            auditor_amounts_bytes.append(confidential_balance::balance_to_bytes(balance));
        });

        auditor_amounts_bytes
    }

    #[test_only]
    /// Asserts the last emitted `Transferred` matches `from` / `to` / `asset_type`, the expected
    /// `sender_auditor_hint`, `ek_volun_auds` length (`128 * expected_auditor_entry_count` bytes,
    /// i.e. four 32-byte compressed points per auditor row), and on-chain `new_sender_available_balance` /
    /// `new_recip_pending_balance` against `actual_balance` / `pending_balance`. Does not assert `amount`
    /// or `memo` (memo is always empty in production transfers today).
    public fun assert_last_transferred_event_matches_state(
        token: Object<Metadata>,
        expected_from: address,
        expected_to: address,
        expected_auditor_entry_count: u64,
        expected_sender_auditor_hint: vector<u8>,
        expected_chain_auditor_epoch: u64,
        expected_asset_auditor_epoch: u64,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<Transferred>();
        let len = vector::length(&evts);
        assert!(len > 0, 1);
        let e = vector::borrow(&evts, len - 1);
        assert!(e.from == expected_from, 2);
        assert!(e.to == expected_to, 3);
        assert!(e.asset_type == object::object_address(&token), 4);
        assert!(e.sender_auditor_hint == expected_sender_auditor_hint, 9);
        assert!(
            e.ek_volun_auds.length() == 32 * 4 * expected_auditor_entry_count,
            8
        );
        let on_chain_sender = actual_balance(expected_from, token);
        let on_chain_recip_pending = pending_balance(expected_to, token);
        assert!(e.new_sender_available_balance == on_chain_sender, 6);
        assert!(e.new_recip_pending_balance == on_chain_recip_pending, 7);
        assert!(e.chain_auditor_epoch == expected_chain_auditor_epoch, 10);
        assert!(e.asset_auditor_epoch == expected_asset_auditor_epoch, 11);
    }

    #[test_only]
    public fun assert_last_registered_event(
        token: Object<Metadata>,
        expected_addr: address,
    ) {
        let evts = event::emitted_events<Registered>();
        assert!(evts.length() > 0, 100);
        let e = &evts[evts.length() - 1];
        assert!(e.addr == expected_addr, 101);
        assert!(e.asset_type == object::object_address(&token), 102);
    }

    #[test_only]
    public fun assert_last_deposited_event_matches_state(
        token: Object<Metadata>,
        expected_to: address,
        expected_amount: u64,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<Deposited>();
        assert!(evts.length() > 0, 110);
        let e = &evts[evts.length() - 1];
        assert!(e.to == expected_to, 111);
        assert!(e.asset_type == object::object_address(&token), 112);
        assert!(e.amount == expected_amount, 113);
        assert!(e.new_pending_balance == pending_balance(expected_to, token), 114);
    }

    #[test_only]
    public fun assert_last_withdrawn_event_matches_state(
        token: Object<Metadata>,
        expected_from: address,
        expected_amount: u64,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<Withdrawn>();
        assert!(evts.length() > 0, 120);
        let e = &evts[evts.length() - 1];
        assert!(e.from == expected_from, 121);
        assert!(e.asset_type == object::object_address(&token), 122);
        assert!(e.amount == expected_amount, 123);
        assert!(e.new_available_balance == actual_balance(expected_from, token), 124);
    }

    #[test_only]
    public fun assert_last_normalized_event_matches_state(
        token: Object<Metadata>,
        expected_addr: address,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<Normalized>();
        assert!(evts.length() > 0, 130);
        let e = &evts[evts.length() - 1];
        assert!(e.addr == expected_addr, 131);
        assert!(e.asset_type == object::object_address(&token), 132);
        assert!(e.new_available_balance == actual_balance(expected_addr, token), 133);
    }

    #[test_only]
    public fun assert_last_rolled_over_event_matches_state(
        token: Object<Metadata>,
        expected_addr: address,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<RolledOver>();
        assert!(evts.length() > 0, 140);
        let e = &evts[evts.length() - 1];
        assert!(e.addr == expected_addr, 141);
        assert!(e.asset_type == object::object_address(&token), 142);
        assert!(e.new_available_balance == actual_balance(expected_addr, token), 143);
    }

    #[test_only]
    public fun assert_last_key_rotated_event_matches_state(
        token: Object<Metadata>,
        expected_addr: address,
    ) acquires ConfidentialAssetStore {
        let evts = event::emitted_events<KeyRotated>();
        assert!(evts.length() > 0, 150);
        let e = &evts[evts.length() - 1];
        assert!(e.addr == expected_addr, 151);
        assert!(e.asset_type == object::object_address(&token), 152);
        assert!(e.new_available_balance == actual_balance(expected_addr, token), 153);
        assert!(e.new_ek == encryption_key(expected_addr, token), 154);
    }

    #[test_only]
    public fun assert_last_freeze_changed_event(
        token: Object<Metadata>,
        expected_addr: address,
        expected_frozen: bool,
    ) {
        let evts = event::emitted_events<FreezeChanged>();
        assert!(evts.length() > 0, 160);
        let e = &evts[evts.length() - 1];
        assert!(e.addr == expected_addr, 161);
        assert!(e.asset_type == object::object_address(&token), 162);
        assert!(e.frozen == expected_frozen, 163);
    }

    #[test_only]
    public fun assert_last_allow_list_changed_event(expected_enabled: bool) {
        let evts = event::emitted_events<AllowListChanged>();
        assert!(evts.length() > 0, 170);
        let e = &evts[evts.length() - 1];
        assert!(e.enabled == expected_enabled, 171);
    }

    #[test_only]
    public fun assert_last_token_allow_changed_event(
        token: Object<Metadata>,
        expected_allowed: bool,
    ) {
        let evts = event::emitted_events<TokenAllowChanged>();
        assert!(evts.length() > 0, 180);
        let e = &evts[evts.length() - 1];
        assert!(e.asset_type == object::object_address(&token), 181);
        assert!(e.allowed == expected_allowed, 182);
    }

    #[test_only]
    public fun assert_last_asset_auditor_changed_event(token: Object<Metadata>, expected_epoch: u64) {
        let evts = event::emitted_events<AssetAuditorChanged>();
        assert!(evts.length() > 0, 190);
        let e = &evts[evts.length() - 1];
        assert!(e.asset_type == object::object_address(&token), 191);
        assert!(e.new_epoch == expected_epoch, 192);
    }

    #[test_only]
    public fun assert_last_chain_auditor_changed_event(expected_epoch: u64) {
        let evts = event::emitted_events<ChainAuditorChanged>();
        assert!(evts.length() > 0, 195);
        let e = &evts[evts.length() - 1];
        assert!(e.new_epoch == expected_epoch, 196);
    }

    #[test_only]
    public fun assert_last_chain_auditor_admin_changed_event(expected_admin: address) {
        let evts = event::emitted_events<ChainAuditorAdminChanged>();
        assert!(evts.length() > 0, 197);
        let e = &evts[evts.length() - 1];
        assert!(e.new_admin == expected_admin, 198);
    }
}
