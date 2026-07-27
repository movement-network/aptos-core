/// Timelock account module for Movement. Unlike multisig accounts which require n-of-m
/// signatures, a timelock account enforces a time delay before transactions can be executed.
///
/// Each timelock account is a resource account with:
/// - A list of creators who can propose transactions (must have at least 1). Creators can both
///   propose and cancel transactions.
/// - A list of executors who can execute transactions after the timelock period
///   (if executors is empty, creators can also execute)
/// - A list of cancelers who can cancel any pending transaction at any time (an emergency-response
///   role). The canceler role by itself grants only cancellation — being listed solely as a
///   canceler does not authorize proposing or executing. The list may be empty. An address MAY,
///   however, hold the canceler role in addition to being a creator or executor; this overlap is
///   allowed on purpose, so an operator can be granted cancel authority first and have its
///   creator/executor role removed afterward for a gap-free, safe role transition.
/// - A configurable minimum delay (`min_num_seconds_execute`) that must elapse after a
///   transaction is proposed before it can be executed
///
/// Execution model (mirrors `aptos_governance`): a creator proposes the SHA3-256 hash of a future
/// resolution script's bytecode. After the delay, an authorized executor submits a `Script` whose
/// hash matches; the script calls `resolve`, which verifies the hash via
/// `transaction_context::get_script_hash()` and returns the timelock account's signer for arbitrary
/// Move calls (including this module's self-governance functions).
///
/// Delegated approval: an executor that cannot submit a `Script` (notably an Aptos multisig, which
/// dispatches entry functions) instead calls `approve_resolution`; any party may then submit the
/// committed script, which `resolve` accepts on the strength of that approval. A direct executor
/// needs no prior approval.
///
/// Committing to bytecode, not arguments (IMPORTANT): the proposal commits to the SHA3-256 hash of
/// the resolution script's *bytecode* only — exactly like `aptos_governance`. It does NOT commit to
/// the script's `Script` arguments, and it cannot: committing to a full payload would exclude Aptos
/// multisigs (which dispatch entry functions, not `Script`s) from ever owning a timelock. As a
/// consequence, whoever submits the transaction chooses the argument values, so a resolution script
/// MUST bake every privileged value (an address to grant a role to, a new delay, a transfer
/// recipient/amount, ...) into its body as a literal, where the hash covers it. A value passed as a
/// `Script` argument is attacker-controllable by the submitter even though the bytecode hash
/// matches. Runtime arguments should be limited to non-privileged routing values (the submitter
/// signer, the timelock address, the proposal hash). See the resolution-script examples under
/// `e2e-move-tests/.../timelock.data` for the self-contained, no-privileged-arg pattern.
///
/// Properties:
/// - Transactions are indexed by `keccak256(execution_hash || salt)`; change the salt to resubmit.
/// - Changing the delay or membership requires the timelock proposal mechanism (the account signs).
/// - Executed/canceled transactions keep `executed = true` permanently for historical record.
/// - If the resolution script aborts, the whole transaction (including the `executed` flip) reverts.
module aptos_framework::timelock {
    use std::account::{Self, SignerCapability, create_resource_address};
    use std::aptos_coin::AptosCoin;
    use std::coin;
    use std::event::emit;
    use std::timestamp::now_seconds;
    use std::table::{Self, Table};
    use std::bcs::to_bytes;
    use std::error;
    use std::aptos_hash::keccak256;
    use std::signer::address_of;
    use std::transaction_context;

    /// Domain separator used when deriving the resource account seed, to avoid collisions
    /// with other modules that create resource accounts.
    const DOMAIN_SEPARATOR: vector<u8> = b"aptos_framework::timelock";

    const SCRIPT_HASH_LENGTH: u64 = 32;
    const PROPOSAL_HASH_LENGTH: u64 = 32;
    const SALT_LENGTH: u64 = 32;
    const MIN_NUM_SECONDS_EXECUTE: u64 = 3600;
    /// Upper bound (90 days in seconds) on every delay in this module: the account's
    /// `min_num_seconds_execute` and each proposal's `num_seconds_execute`. Bounding the
    /// per-proposal delay keeps `creation_time_secs + num_seconds_execute` from overflowing and
    /// prevents a creator from proposing a transaction that can never be executed.
    const MAX_NUM_SECONDS_EXECUTE: u64 = 7776000;
    /// Maximum byte length of the optional off-chain `script_path` pointer.
    const MAX_SCRIPT_PATH_LENGTH: u64 = 256;

    /// Creator list cannot contain duplicate addresses.
    const EDUPLICATE_CREATOR: u64 = 1;
    /// Executor list cannot contain duplicate addresses.
    const EDUPLICATE_EXECUTOR: u64 = 2;
    /// Specified account is not a timelock account.
    const EACCOUNT_NOT_TIMELOCK: u64 = 3;
    /// The caller is not a creator.
    const ENOT_CREATOR: u64 = 4;
    /// The submitter is not authorized to resolve: it is neither an executor (nor a creator when
    /// the executor list is empty) nor resolving a transaction pre-approved via `approve_resolution`.
    const ENOT_EXECUTOR: u64 = 5;
    /// Timelock account must have at least one creator.
    const ENOT_ENOUGH_CREATORS: u64 = 6;
    /// Transaction with the specified hash was not found.
    const ETRANSACTION_NOT_FOUND: u64 = 7;
    /// The timelock period has not elapsed yet.
    const ETIMELOCK_NOT_EXPIRED: u64 = 8;
    /// Transaction has already been executed or canceled.
    const ETRANSACTION_ALREADY_EXECUTED: u64 = 9;
    /// The timelock account itself cannot be a creator or executor.
    const ESELF_CANNOT_BE_MEMBER: u64 = 10;
    /// A transaction with this execution hash and salt already exists.
    const EDUPLICATE_TRANSACTION: u64 = 11;
    /// Removing these creators would leave the timelock account with zero creators.
    const EWOULD_REMOVE_ALL_CREATORS: u64 = 12;
    /// The caller is neither a creator nor a canceler.
    const ENOT_CREATOR_OR_CANCELER: u64 = 13;
    /// The specified number of seconds is below the required minimum: the account's
    /// `min_num_seconds_execute` must be at least `MIN_NUM_SECONDS_EXECUTE` (3600),
    /// and a transaction's `num_seconds_execute` must be at least the account's
    /// `min_num_seconds_execute`.
    const ENUMBER_SECONDS_TOO_SMALL: u64 = 14;
    /// The specified number of seconds exceeds `MAX_NUM_SECONDS_EXECUTE` (90 days). This bounds
    /// both the account's `min_num_seconds_execute` and each transaction's `num_seconds_execute`.
    const ENUMBER_SECONDS_TOO_LARGE: u64 = 15;
    /// The provided hash or salt must be exactly 32 bytes.
    const EINVALID_BYTES_LENGTH: u64 = 16;
    /// Current transaction script hash does not match the proposed execution hash.
    const EEXECUTION_HASH_NOT_MATCHING: u64 = 17;
    /// The provided `script_path` exceeds `MAX_SCRIPT_PATH_LENGTH`.
    const ESCRIPT_PATH_TOO_LONG: u64 = 18;
    /// Canceler list cannot contain duplicate addresses.
    const EDUPLICATE_CANCELER: u64 = 19;

    /// Represents a timelock account's configuration and pending/historical transactions.
    /// Stored at the resource account address created during timelock account creation.
    struct TimelockAccount has key {
        // Addresses allowed to propose transactions. Must have at least 1.
        creators: vector<address>,
        // Addresses allowed to execute transactions after the timelock period.
        // If empty, creators can also execute.
        executors: vector<address>,
        // Addresses granted cancel authority (emergency response). May be empty. The canceler role
        // alone does not grant propose/execute, but an address here may also appear in `creators`
        // or `executors` — that overlap is allowed intentionally (see the module doc).
        cancelers: vector<address>,
        // Minimum seconds that must elapse after proposal before a transaction can be executed.
        min_num_seconds_execute: u64,
        // Map from `keccak256(execution_hash || salt)` to transaction. Entries are never
        // deleted; executed/canceled transactions remain with executed = true for record.
        transactions: Table<vector<u8>, TimelockTransaction>,
        // Signer capability for the resource account.
        signer_cap: SignerCapability
    }

    /// A transaction proposed for timelock execution.
    ///
    /// `execution_hash` is the SHA3-256 hash of the authorized resolution script's bytecode — the
    /// same value `transaction_context::get_script_hash()` returns for that script. At resolve time
    /// it is compared (raw, not re-hashed) against the running script's hash. Note this is distinct
    /// from the table key, which is `keccak256(execution_hash || salt)`.
    struct TimelockTransaction has copy, drop, store {
        execution_hash: vector<u8>,
        // The creator who proposed this transaction.
        creator: address,
        // Unix timestamp (seconds) when this transaction was proposed.
        creation_time_secs: u64,
        // Seconds that must elapse after creation_time_secs before this transaction can be executed.
        num_seconds_execute: u64,
        // User-provided salt used when deriving the proposal hash from execution_hash.
        salt: vector<u8>,
        // Optional off-chain pointer (e.g. an IPFS URI or URL) to the human-readable script
        // payload and metadata, capped at `MAX_SCRIPT_PATH_LENGTH` bytes. An empty vector means
        // no pointer was provided.
        script_path: vector<u8>,
        // True once the transaction is resolved (successfully) or canceled.
        executed: bool,
        // True once an executor has pre-authorized resolution via `approve_resolution`. This lets
        // a party that cannot submit a `Script` transaction itself (e.g. a multisig account, which
        // executes entry functions only) authorize execution; any party may then submit the
        // committed resolution script, which `resolve` accepts on the strength of this approval.
        // A direct executor calling `resolve` does not need this — see `resolve`.
        approved: bool
    }

    // =============================== Events ===============================

    #[event]
    struct AddCreators has drop, store {
        timelock_account: address,
        new_creators: vector<address>
    }

    #[event]
    struct RemoveCreators has drop, store {
        timelock_account: address,
        removed_creators: vector<address>
    }

    #[event]
    struct AddExecutors has drop, store {
        timelock_account: address,
        new_executors: vector<address>
    }

    #[event]
    struct RemoveExecutors has drop, store {
        timelock_account: address,
        removed_executors: vector<address>
    }

    #[event]
    struct AddCancelers has drop, store {
        timelock_account: address,
        new_cancelers: vector<address>
    }

    #[event]
    struct RemoveCancelers has drop, store {
        timelock_account: address,
        removed_cancelers: vector<address>
    }

    #[event]
    struct UpdateMinNumSecondsExecute has drop, store {
        timelock_account: address,
        old_min_num_seconds_execute: u64,
        new_min_num_seconds_execute: u64
    }

    #[event]
    struct CreateTransaction has drop, store {
        timelock_account: address,
        creator: address,
        proposal_hash: vector<u8>,
        transaction: TimelockTransaction
    }

    #[event]
    struct CancelTransaction has drop, store {
        timelock_account: address,
        actor: address,
        proposal_hash: vector<u8>
    }

    #[event]
    struct ResolveTransaction has drop, store {
        timelock_account: address,
        executor: address,
        proposal_hash: vector<u8>,
        execution_hash: vector<u8>
    }

    #[event]
    struct ApproveResolution has drop, store {
        timelock_account: address,
        executor: address,
        proposal_hash: vector<u8>
    }

    // =============================== View functions ===============================

    #[view]
    /// Return the list of creators for the given timelock account.
    public fun creators(timelock_account: address): vector<address> acquires TimelockAccount {
        TimelockAccount[timelock_account].creators
    }

    #[view]
    /// Return the list of executors. An empty list means creators can also execute.
    public fun executors(timelock_account: address): vector<address> acquires TimelockAccount {
        TimelockAccount[timelock_account].executors
    }

    #[view]
    /// Return the list of cancelers (the emergency-response role that can only cancel).
    public fun cancelers(timelock_account: address): vector<address> acquires TimelockAccount {
        TimelockAccount[timelock_account].cancelers
    }

    #[view]
    /// Return the minimum timelock delay in seconds.
    public fun min_num_seconds_execute(timelock_account: address): u64 acquires TimelockAccount {
        TimelockAccount[timelock_account].min_num_seconds_execute
    }

    #[view]
    /// Return true if the given address is a creator of the timelock account.
    public fun is_creator(addr: address, timelock_account: address): bool acquires TimelockAccount {
        TimelockAccount[timelock_account].creators.contains(&addr)
    }

    #[view]
    /// Return true if the given address is authorized to execute transactions.
    /// If the executor list is empty, creators are also authorized to execute.
    public fun is_executor(addr: address, timelock_account: address): bool acquires TimelockAccount {
        is_executor_addr(&TimelockAccount[timelock_account], addr)
    }

    #[view]
    /// Return true if the given address is a canceler of the timelock account.
    public fun is_canceler(addr: address, timelock_account: address): bool acquires TimelockAccount {
        TimelockAccount[timelock_account].cancelers.contains(&addr)
    }

    #[view]
    /// Return the transaction stored under the given proposal hash.
    public fun get_transaction(
        timelock_account: address, proposal_hash: vector<u8>
    ): TimelockTransaction acquires TimelockAccount {
        let timelock = &TimelockAccount[timelock_account];
        assert!(
            timelock.transactions.contains(proposal_hash),
            error::not_found(ETRANSACTION_NOT_FOUND)
        );
        *timelock.transactions.borrow(proposal_hash)
    }

    #[view]
    /// Return true if the transaction exists, is not yet executed/canceled,
    /// and has passed the timelock period.
    public fun can_be_executed(
        timelock_account: address, proposal_hash: vector<u8>
    ): bool acquires TimelockAccount {
        let timelock = &TimelockAccount[timelock_account];
        if (!timelock.transactions.contains(proposal_hash)) {
            return false
        };
        let tx = timelock.transactions.borrow(proposal_hash);
        !tx.executed && now_seconds() >= tx.creation_time_secs + tx.num_seconds_execute
    }

    #[view]
    /// Return the predicted address for the next timelock account deployed by the given account.
    /// The deployer authorizes resource-account creation but does not become a creator or executor;
    /// membership is determined entirely by the `creators` and `executors` arguments to `create`.
    public fun get_next_timelock_account_address(deployer: address): address {
        let owner_nonce = account::get_sequence_number(deployer);
        create_resource_address(
            &deployer, create_timelock_account_seed(to_bytes(&owner_nonce))
        )
    }

    #[view]
    /// Return the proposal hash (the table key indexing a proposed transaction) for the given
    /// execution hash and salt. Clients use this to compute the proposal hash before proposing.
    public fun get_proposal_hash(
        execution_hash: vector<u8>, salt: vector<u8>
    ): vector<u8> {
        execution_hash.append(salt);
        keccak256(execution_hash)
    }

    // =============================== Account creation ===============================

    /// Create a new timelock account. The deployer only authorizes resource-account creation and
    /// pays gas; it gains no role unless listed in the member arguments.
    ///
    /// @param deployer Signer that authorizes resource-account creation and pays gas.
    /// @param creators Addresses allowed to propose. At least one, no duplicates, not the timelock address.
    /// @param executors Addresses allowed to execute after the delay. If empty, creators may execute.
    /// @param cancelers Addresses allowed only to cancel at any time. May be empty.
    /// @param num_seconds_execute Minimum delay in seconds before a proposed transaction can execute.
    /// @abort If a list is invalid or num_seconds_execute is outside the allowed delay bounds.
    public entry fun create(
        deployer: &signer,
        creators: vector<address>,
        executors: vector<address>,
        cancelers: vector<address>,
        num_seconds_execute: u64
    ) {
        let (timelock_signer, timelock_signer_cap) = create_timelock_account(deployer);
        create_timelock_account_internal(
            &timelock_signer,
            creators,
            executors,
            cancelers,
            num_seconds_execute,
            timelock_signer_cap
        );
    }

    fun create_timelock_account_internal(
        timelock_account: &signer,
        creators: vector<address>,
        executors: vector<address>,
        cancelers: vector<address>,
        min_num_seconds_execute: u64,
        signer_cap: SignerCapability
    ) {
        assert_delay(min_num_seconds_execute);
        let timelock_address = address_of(timelock_account);
        assert!(creators.length() >= 1, error::invalid_argument(ENOT_ENOUGH_CREATORS));
        validate_members(&creators, timelock_address, EDUPLICATE_CREATOR);
        validate_members(&executors, timelock_address, EDUPLICATE_EXECUTOR);
        validate_members(&cancelers, timelock_address, EDUPLICATE_CANCELER);

        move_to(
            timelock_account,
            TimelockAccount {
                creators,
                executors,
                cancelers,
                min_num_seconds_execute,
                transactions: table::new<vector<u8>, TimelockTransaction>(),
                signer_cap
            }
        );
    }

    // =============================== Self-governance ===============================
    // These functions can only be called by the timelock account itself. The intended flow is:
    // a creator proposes a resolution script that calls one of these entry functions, the
    // timelock period elapses, an executor submits the script, the script calls `resolve` to
    // obtain the timelock signer, then invokes the entry function with that signer.

    /// Add new creators. Callable only by the timelock account itself via the proposal flow.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param new_creators Addresses to add as creators.
    public entry fun add_creators(
        timelock_account: &signer, new_creators: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        // Validate `new_creators` on its own first. This is redundant at runtime.
        validate_members(&new_creators, timelock_address, EDUPLICATE_CREATOR);
        let timelock = &mut TimelockAccount[timelock_address];
        timelock.creators.append(new_creators);
        // Re-validate the combined list to also catch cross-list duplicates against existing creators.
        validate_members(&timelock.creators, timelock_address, EDUPLICATE_CREATOR);
        emit(AddCreators { timelock_account: timelock_address, new_creators });
    }

    /// Remove creators; at least one must remain. Callable only by the timelock account itself.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param creators_to_remove Addresses to remove from the creator list.
    public entry fun remove_creators(
        timelock_account: &signer, creators_to_remove: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = &mut TimelockAccount[timelock_address];
        let removed_creators = vector[];
        creators_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.creators.index_of(to_remove);
            if (found) {
                removed_creators.push_back(timelock.creators.swap_remove(index));
            }
        });
        assert!(
            timelock.creators.length() >= 1,
            error::invalid_state(EWOULD_REMOVE_ALL_CREATORS)
        );
        if (!removed_creators.is_empty()) {
            emit(RemoveCreators { timelock_account: timelock_address, removed_creators });
        };
    }

    /// Add new executors. Callable only by the timelock account itself via the proposal flow.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param new_executors Addresses to add as executors.
    public entry fun add_executors(
        timelock_account: &signer, new_executors: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        // Pre-append validation kept for the prover's `aborts_if` (see `add_creators`); do not remove.
        validate_members(&new_executors, timelock_address, EDUPLICATE_EXECUTOR);
        let timelock = &mut TimelockAccount[timelock_address];
        timelock.executors.append(new_executors);
        // Re-validate the combined list to also catch cross-list duplicates against existing executors.
        validate_members(&timelock.executors, timelock_address, EDUPLICATE_EXECUTOR);
        emit(AddExecutors { timelock_account: timelock_address, new_executors });
    }

    /// Remove executors; the list may become empty, in which case creators can execute. Callable
    /// only by the timelock account itself via the proposal flow.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param executors_to_remove Addresses to remove from the executor list.
    public entry fun remove_executors(
        timelock_account: &signer, executors_to_remove: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = &mut TimelockAccount[timelock_address];
        let removed_executors = vector[];
        executors_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.executors.index_of(to_remove);
            if (found) {
                removed_executors.push_back(timelock.executors.swap_remove(index));
            }
        });
        if (!removed_executors.is_empty()) {
            emit(
                RemoveExecutors { timelock_account: timelock_address, removed_executors }
            );
        };
    }

    /// Add new cancelers (emergency-response role that can only cancel). Callable only by the
    /// timelock account itself via the proposal flow.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param new_cancelers Addresses to add as cancelers.
    public entry fun add_cancelers(
        timelock_account: &signer, new_cancelers: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        // Pre-append validation kept for the prover's `aborts_if` (see `add_creators`); do not remove.
        validate_members(&new_cancelers, timelock_address, EDUPLICATE_CANCELER);
        let timelock = &mut TimelockAccount[timelock_address];
        timelock.cancelers.append(new_cancelers);
        // Re-validate the combined list to also catch cross-list duplicates against existing cancelers.
        validate_members(&timelock.cancelers, timelock_address, EDUPLICATE_CANCELER);
        emit(AddCancelers { timelock_account: timelock_address, new_cancelers });
    }

    /// Remove cancelers; the list may become empty. Callable only by the timelock account itself.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param cancelers_to_remove Addresses to remove from the canceler list.
    public entry fun remove_cancelers(
        timelock_account: &signer, cancelers_to_remove: vector<address>
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = &mut TimelockAccount[timelock_address];
        let removed_cancelers = vector[];
        cancelers_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.cancelers.index_of(to_remove);
            if (found) {
                removed_cancelers.push_back(timelock.cancelers.swap_remove(index));
            }
        });
        if (!removed_cancelers.is_empty()) {
            emit(
                RemoveCancelers { timelock_account: timelock_address, removed_cancelers }
            );
        };
    }

    /// Update the timelock delay for future proposals; pending transactions are unaffected. Callable
    /// only by the timelock account itself via the proposal flow.
    ///
    /// @param timelock_account The timelock account's signer.
    /// @param new_min_num_seconds_execute The new minimum delay in seconds.
    public entry fun update_min_num_seconds_execute(
        timelock_account: &signer, new_min_num_seconds_execute: u64
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        assert_delay(new_min_num_seconds_execute);
        let timelock = &mut TimelockAccount[timelock_address];
        let old_min_num_seconds_execute = timelock.min_num_seconds_execute;
        timelock.min_num_seconds_execute = new_min_num_seconds_execute;
        emit(
            UpdateMinNumSecondsExecute {
                timelock_account: timelock_address,
                old_min_num_seconds_execute,
                new_min_num_seconds_execute
            }
        );
    }

    // =============================== Transaction flow ===============================

    /// Propose a transaction to be executed after the timelock period. Indexed by
    /// keccak256(execution_hash || salt).
    ///
    /// @param creator A creator's signer.
    /// @param timelock_account The timelock account address.
    /// @param execution_hash SHA3-256 hash (32 bytes) of the resolution script's bytecode.
    /// @param num_seconds_execute Delay in seconds before execution; must be >= the account
    ///        minimum and <= `MAX_NUM_SECONDS_EXECUTE` (90 days).
    /// @param salt 32 bytes disambiguating duplicate proposals of the same script.
    /// @param script_path Optional off-chain pointer to the script payload (e.g. an IPFS URI); empty to omit.
    public entry fun create_transaction(
        creator: &signer,
        timelock_account: address,
        execution_hash: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
        script_path: vector<u8>
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_is_creator(creator, timelock_account);
        assert!(
            execution_hash.length() == SCRIPT_HASH_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        assert!(
            salt.length() == SALT_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
        assert!(
            script_path.length() <= MAX_SCRIPT_PATH_LENGTH,
            error::invalid_argument(ESCRIPT_PATH_TOO_LONG)
        );

        let proposal_hash = get_proposal_hash(execution_hash, salt);
        let creator_addr = address_of(creator);
        let timelock = &mut TimelockAccount[timelock_account];
        assert!(
            num_seconds_execute >= timelock.min_num_seconds_execute,
            error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL)
        );
        // Bound the per-proposal delay by the same maximum as the account config. Without this a
        // creator could pass an arbitrarily large `num_seconds_execute`, overflowing
        // `creation_time_secs + num_seconds_execute` at resolve/approve time and stranding the
        // transaction permanently.
        assert!(
            num_seconds_execute <= MAX_NUM_SECONDS_EXECUTE,
            error::invalid_argument(ENUMBER_SECONDS_TOO_LARGE)
        );
        assert!(
            !timelock.transactions.contains(proposal_hash),
            error::already_exists(EDUPLICATE_TRANSACTION)
        );

        let transaction = TimelockTransaction {
            execution_hash,
            creator: creator_addr,
            creation_time_secs: now_seconds(),
            num_seconds_execute,
            salt,
            script_path,
            executed: false,
            approved: false
        };
        timelock.transactions.add(proposal_hash, transaction);

        emit(
            CreateTransaction {
                timelock_account,
                creator: creator_addr,
                proposal_hash,
                transaction
            }
        );
    }

    /// Cancel a pending transaction (marks it executed). Any creator or canceler may cancel at any
    /// time; executors cannot.
    ///
    /// @param actor A creator's or canceler's signer.
    /// @param timelock_account The timelock account address.
    /// @param proposal_hash The 32-byte hash indexing the transaction.
    public entry fun cancel_transaction(
        actor: &signer, timelock_account: address, proposal_hash: vector<u8>
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_proposal_hash_length(&proposal_hash);
        let actor_addr = address_of(actor);
        // Creators and cancelers may cancel; executors cannot.
        assert!(
            is_creator(actor_addr, timelock_account)
                || is_canceler(actor_addr, timelock_account),
            error::permission_denied(ENOT_CREATOR_OR_CANCELER)
        );

        let timelock = &mut TimelockAccount[timelock_account];
        assert!(
            timelock.transactions.contains(proposal_hash),
            error::not_found(ETRANSACTION_NOT_FOUND)
        );
        let transaction = timelock.transactions.borrow_mut(proposal_hash);
        assert!(
            !transaction.executed,
            error::invalid_state(ETRANSACTION_ALREADY_EXECUTED)
        );
        transaction.executed = true;

        emit(CancelTransaction { timelock_account, actor: actor_addr, proposal_hash });
    }

    /// Pre-authorize resolution for an executor that cannot submit a `Script` itself (notably an
    /// Aptos multisig, which dispatches entry functions, not `Script`s). After approval, any party
    /// may submit the committed resolution script and `resolve` accepts it. Authorization mirrors
    /// execution (an executor, or a creator when the executor list is empty). Both `approve_resolution`
    /// and `resolve` enforce the delay, and the approval is bound to `proposal_hash`, which commits to
    /// the exact script, so it cannot authorize anything else.
    ///
    /// @param executor An executor's signer (or a creator when the executor list is empty).
    /// @param timelock_account The timelock account address.
    /// @param proposal_hash The 32-byte hash indexing the transaction.
    public entry fun approve_resolution(
        executor: &signer, timelock_account: address, proposal_hash: vector<u8>
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_proposal_hash_length(&proposal_hash);
        assert_is_executor(executor, timelock_account);
        let executor_addr = address_of(executor);

        let timelock = &mut TimelockAccount[timelock_account];
        assert!(
            timelock.transactions.contains(proposal_hash),
            error::not_found(ETRANSACTION_NOT_FOUND)
        );
        let transaction = timelock.transactions.borrow_mut(proposal_hash);
        assert!(
            !transaction.executed,
            error::invalid_state(ETRANSACTION_ALREADY_EXECUTED)
        );
        assert!(
            now_seconds()
                >= transaction.creation_time_secs + transaction.num_seconds_execute,
            error::invalid_state(ETIMELOCK_NOT_EXPIRED)
        );
        transaction.approved = true;

        emit(ApproveResolution { timelock_account, executor: executor_addr, proposal_hash });
    }

    /// Resolve a pending transaction and return the timelock account's signer for the calling script
    /// to perform its effects. Requires authorization, an elapsed delay, and a matching script hash;
    /// marks the transaction executed (reverted atomically if the calling script later aborts).
    ///
    /// @param submitter An executor's signer, or any signer when the transaction was pre-approved.
    /// @param timelock_account The timelock account address.
    /// @param proposal_hash The 32-byte hash indexing the transaction.
    /// @return The timelock account's signer.
    public fun resolve(
        submitter: &signer, timelock_account: address, proposal_hash: vector<u8>
    ): signer acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_proposal_hash_length(&proposal_hash);

        let submitter_addr = address_of(submitter);
        let timelock = &mut TimelockAccount[timelock_account];
        // Executor authorization, computed from the same borrow used for the lookup below so the
        // resource is loaded once.
        let submitter_is_executor = is_executor_addr(timelock, submitter_addr);
        assert!(
            timelock.transactions.contains(proposal_hash),
            error::not_found(ETRANSACTION_NOT_FOUND)
        );
        let transaction = timelock.transactions.borrow_mut(proposal_hash);
        // Authorized if the submitter is an executor (direct execute = approve-and-resolve in one
        // step) or the transaction was pre-approved by an executor via `approve_resolution`.
        // Checked before the executed/delay checks so an unauthorized caller cannot probe a
        // proposal's execution state.
        assert!(
            submitter_is_executor || transaction.approved,
            error::permission_denied(ENOT_EXECUTOR)
        );
        assert!(
            !transaction.executed,
            error::invalid_state(ETRANSACTION_ALREADY_EXECUTED)
        );
        assert!(
            now_seconds()
                >= transaction.creation_time_secs + transaction.num_seconds_execute,
            error::invalid_state(ETIMELOCK_NOT_EXPIRED)
        );
        assert!(
            transaction_context::get_script_hash() == transaction.execution_hash,
            error::invalid_argument(EEXECUTION_HASH_NOT_MATCHING)
        );
        transaction.executed = true;
        emit(
            ResolveTransaction {
                timelock_account,
                executor: submitter_addr,
                proposal_hash,
                execution_hash: transaction.execution_hash
            }
        );

        let timelock = &TimelockAccount[timelock_account];
        account::create_signer_with_capability(&timelock.signer_cap)
    }

    // =============================== Private helpers ===============================

    fun create_timelock_account(deployer: &signer): (signer, SignerCapability) {
        let deployer_nonce = account::get_sequence_number(address_of(deployer));
        let (timelock_signer, timelock_signer_cap) =
            account::create_resource_account(
                deployer, create_timelock_account_seed(to_bytes(&deployer_nonce))
            );
        // Register for MOVE so the timelock account can pay gas and receive transfers.
        if (!coin::is_account_registered<AptosCoin>(address_of(&timelock_signer))) {
            coin::register<AptosCoin>(&timelock_signer);
        };
        (timelock_signer, timelock_signer_cap)
    }

    fun create_timelock_account_seed(seed: vector<u8>): vector<u8> {
        let account_seed = vector[];
        account_seed.append(DOMAIN_SEPARATOR);
        account_seed.append(seed);
        account_seed
    }

    /// Validate that a list of member addresses has no duplicates and does not include
    /// the timelock account address itself. `duplicate_error` is the error code to use
    /// when a duplicate is found (EDUPLICATE_CREATOR or EDUPLICATE_EXECUTOR).
    fun validate_members(
        members: &vector<address>, timelock_address: address, duplicate_error: u64
    ) {
        let distinct: vector<address> = vector[];
        let total = members.length();
        let i = 0;
        while ({
            spec {
                invariant i <= total;
                invariant len(distinct) == i;
                invariant forall k in 0..i: distinct[k] == members[k];
                invariant forall k in 0..i: members[k] != timelock_address;
                invariant forall k in 0..i: forall l in 0..k: members[k] != members[l];
            };
            i < total
        }) {
            let member = *members.borrow(i);
            assert!(
                member != timelock_address,
                error::invalid_argument(ESELF_CANNOT_BE_MEMBER)
            );
            let (found, _) = distinct.index_of(&member);
            assert!(!found, error::invalid_argument(duplicate_error));
            distinct.push_back(member);
            i = i + 1;
        };
    }

    inline fun assert_timelock_account_exists(timelock_account: address) {
        assert!(
            exists<TimelockAccount>(timelock_account),
            error::invalid_state(EACCOUNT_NOT_TIMELOCK)
        );
    }

    inline fun assert_is_creator(
        creator: &signer, timelock_account: address
    ) {
        assert!(
            TimelockAccount[timelock_account].creators.contains(&address_of(creator)),
            error::permission_denied(ENOT_CREATOR)
        );
    }

    /// The single source of truth for executor authorization: an executor, or a creator when the
    /// executor list is empty. Operates on an already-borrowed resource so callers holding a
    /// borrow (e.g. `resolve`) reuse it instead of loading `TimelockAccount` again.
    inline fun is_executor_addr(timelock: &TimelockAccount, addr: address): bool {
        if (timelock.executors.is_empty()) {
            timelock.creators.contains(&addr)
        } else {
            timelock.executors.contains(&addr)
        }
    }

    inline fun assert_is_executor(
        executor: &signer, timelock_account: address
    ) {
        assert!(
            is_executor_addr(&TimelockAccount[timelock_account], address_of(executor)),
            error::permission_denied(ENOT_EXECUTOR)
        );
    }

    /// Assert a proposal hash is exactly `PROPOSAL_HASH_LENGTH` bytes. Shared by the
    /// transaction-mutating entry points (cancel/approve/resolve).
    inline fun assert_proposal_hash_length(proposal_hash: &vector<u8>) {
        assert!(
            proposal_hash.length() == PROPOSAL_HASH_LENGTH,
            error::invalid_argument(EINVALID_BYTES_LENGTH)
        );
    }

    inline fun assert_delay(num_seconds_execute: u64) {
        assert!(
            num_seconds_execute >= MIN_NUM_SECONDS_EXECUTE,
            error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL)
        );
        assert!(
            num_seconds_execute <= MAX_NUM_SECONDS_EXECUTE,
            error::invalid_argument(ENUMBER_SECONDS_TOO_LARGE)
        );
    }

    // =============================== Tests ===============================

    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use aptos_framework::coin::{destroy_mint_cap, destroy_burn_cap};

    #[test_only]
    const EXECUTION_HASH: vector<u8> = x"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    #[test_only]
    const EXECUTION_HASH_2: vector<u8> = x"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    #[test_only]
    const SALT: vector<u8> = x"1111111111111111111111111111111111111111111111111111111111111111";
    #[test_only]
    const SALT_2: vector<u8> = x"2222222222222222222222222222222222222222222222222222222222222222";
    #[test_only]
    const INVALID_BYTES: vector<u8> = b"too_short";
    #[test_only]
    const TIMELOCK_SECS: u64 = 3600;

    #[test_only]
    fun setup(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let (burn, mint) = aptos_coin::initialize_for_test(framework);
        destroy_mint_cap(mint);
        destroy_burn_cap(burn);
    }

    #[test_only]
    /// Get a signer for the timelock account using its stored SignerCapability.
    /// Used in tests to simulate the signer that `resolve` would return to a resolution script.
    fun get_timelock_signer(timelock_account: address): signer acquires TimelockAccount {
        account::create_signer_with_capability(
            &TimelockAccount[timelock_account].signer_cap
        )
    }

    // --- Creation tests ---

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create(framework: &signer, creator: &signer) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        assert_timelock_account_exists(timelock_addr);
        assert!(
            creators(timelock_addr) == vector[address_of(creator)],
            0
        );
        assert!(executors(timelock_addr) == vector[], 1);
        assert!(min_num_seconds_execute(timelock_addr) == TIMELOCK_SECS, 2);
    }

    #[test(
        framework = @0x1, creator_1 = @0x123, creator_2 = @0x124, executor_1 = @0x125
    )]
    public entry fun test_create_with_multiple_members(
        framework: &signer,
        creator_1: &signer,
        creator_2: &signer,
        executor_1: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator_1));
        let timelock_addr = get_next_timelock_account_address(address_of(creator_1));
        create(
            creator_1,
            vector[address_of(creator_1), address_of(creator_2)],
            vector[address_of(executor_1)],
            vector[],
            TIMELOCK_SECS
        );
        assert!(is_creator(address_of(creator_1), timelock_addr), 0);
        assert!(is_creator(address_of(creator_2), timelock_addr), 1);
        assert!(is_executor(address_of(executor_1), timelock_addr), 2);
        // creator_1 is not in executors (executor list is non-empty), so is_executor returns false.
        assert!(!is_executor(address_of(creator_1), timelock_addr), 3);
    }

    #[test(framework = @0x1, creator_1 = @0x123, creator_2 = @0x124)]
    #[expected_failure(abort_code = 0x10001, location = Self)]
    public entry fun test_create_with_duplicate_creators_fails(
        framework: &signer, creator_1: &signer, creator_2: &signer
    ) {
        setup(framework);
        create_account(address_of(creator_1));
        let creator_2_addr = address_of(creator_2);
        create(
            creator_1,
            vector[creator_2_addr, creator_2_addr],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
    }

    #[test(
        framework = @0x1, deployer = @0x123, owner = @0x456, executor = @0x789
    )]
    public entry fun test_create_deployer_not_auto_member(
        framework: &signer,
        deployer: &signer,
        owner: &signer,
        executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(deployer));
        let timelock_addr = get_next_timelock_account_address(address_of(deployer));
        // Deployer is the signer used to derive the resource account but is NOT a creator/executor.
        create(
            deployer,
            vector[address_of(owner)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        assert!(
            creators(timelock_addr) == vector[address_of(owner)],
            0
        );
        assert!(!is_creator(address_of(deployer), timelock_addr), 1);
        assert!(!is_executor(address_of(deployer), timelock_addr), 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    public entry fun test_create_with_empty_creators_fails(
        framework: &signer, deployer: &signer
    ) {
        setup(framework);
        create_account(address_of(deployer));
        create(deployer, vector[], vector[], vector[], TIMELOCK_SECS);
    }

    // --- Transaction creation tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_create_transaction(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        let tx = get_transaction(timelock_addr, proposal_hash);
        assert!(tx.creator == address_of(creator), 0);
        assert!(!tx.executed, 1);
        assert!(tx.salt == SALT, 2);
        assert!(tx.execution_hash == EXECUTION_HASH, 3);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x8000B, location = Self)]
    public entry fun test_create_duplicate_transaction_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        // Same execution hash and salt — must fail.
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create_same_execution_hash_different_salt(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        // Different salt — must succeed.
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT_2,
            b""
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x10010, location = Self)]
    public entry fun test_create_transaction_invalid_execution_hash_length_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            INVALID_BYTES,
            TIMELOCK_SECS,
            SALT,
            b""
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x10010, location = Self)]
    public entry fun test_create_transaction_invalid_salt_length_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            INVALID_BYTES,
            b""
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x1000F, location = Self)]
    public entry fun test_create_transaction_num_seconds_too_large_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        // A per-proposal delay above the module maximum must be rejected, mirroring the
        // account-level bound and preventing an unexecutable (overflowing) proposal.
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            MAX_NUM_SECONDS_EXECUTE + 1,
            SALT,
            b""
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create_transaction_num_seconds_at_max_succeeds(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        // The maximum itself is allowed (boundary is inclusive).
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            MAX_NUM_SECONDS_EXECUTE,
            SALT,
            b""
        );
        let tx = get_transaction(timelock_addr, get_proposal_hash(EXECUTION_HASH, SALT));
        assert!(tx.num_seconds_execute == MAX_NUM_SECONDS_EXECUTE, 0);
    }

    #[test(framework = @0x1, creator = @0x123, non_creator = @0x999)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    public entry fun test_non_creator_cannot_propose(
        framework: &signer, creator: &signer, non_creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            non_creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
    }

    // --- Cancellation tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_cancel_by_creator(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, proposal_hash);
        let tx = get_transaction(timelock_addr, proposal_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, canceler = @0x124)]
    public entry fun test_cancel_by_canceler(
        framework: &signer, creator: &signer, canceler: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[address_of(canceler)],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(canceler, timelock_addr, proposal_hash);
        let tx = get_transaction(timelock_addr, proposal_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x5000D, location = Self)]
    /// Executors can execute but must not be able to cancel (only creators and cancelers can).
    public entry fun test_executor_cannot_cancel(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        cancel_transaction(
            executor,
            timelock_addr,
            get_proposal_hash(EXECUTION_HASH, SALT)
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_cancel_by_creator_when_executors_empty(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, proposal_hash);
        let tx = get_transaction(timelock_addr, proposal_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30009, location = Self)]
    public entry fun test_cancel_already_executed_fails(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, proposal_hash);
        cancel_transaction(creator, timelock_addr, proposal_hash);
    }

    #[test(framework = @0x1, creator = @0x123, non_member = @0x999)]
    #[expected_failure(abort_code = 0x5000D, location = Self)]
    public entry fun test_cancel_by_non_member_fails(
        framework: &signer, creator: &signer, non_member: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        cancel_transaction(
            non_member,
            timelock_addr,
            get_proposal_hash(EXECUTION_HASH, SALT)
        );
    }

    // --- Resolve tests ---
    //
    // Note: `resolve` reads `transaction_context::get_script_hash()`, which has no usable value
    // outside of an actual Script transaction. Move-level unit tests therefore cover only the
    // pre-checks that abort before that comparison. End-to-end tests cover the positive flow.

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30008, location = Self)]
    public entry fun test_resolve_before_timelock_expires_fails(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        // No time advance — must fail with ETIMELOCK_NOT_EXPIRED.
        let _ = resolve(
            executor,
            timelock_addr,
            get_proposal_hash(EXECUTION_HASH, SALT)
        );
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30009, location = Self)]
    public entry fun test_resolve_canceled_fails(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, proposal_hash);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        let _ = resolve(executor, timelock_addr, proposal_hash);
    }

    #[test(framework = @0x1, creator = @0x123, non_member = @0x999)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    public entry fun test_resolve_by_non_executor_fails(
        framework: &signer, creator: &signer, non_member: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[@0x124],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        let _ =
            resolve(
                non_member,
                timelock_addr,
                get_proposal_hash(EXECUTION_HASH, SALT)
            );
    }

    // --- approve_resolution tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_approve_resolution_by_executor(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT, b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        assert!(!get_transaction(timelock_addr, proposal_hash).approved, 0);
        // Approval is only permitted once the delay has elapsed.
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        approve_resolution(executor, timelock_addr, proposal_hash);
        assert!(get_transaction(timelock_addr, proposal_hash).approved, 1);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_approve_resolution_by_creator_when_executors_empty(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], vector[], TIMELOCK_SECS);
        create_transaction(
            creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT, b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        // With no executors, a creator is the executor and may approve once the delay has elapsed.
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        approve_resolution(creator, timelock_addr, proposal_hash);
        assert!(get_transaction(timelock_addr, proposal_hash).approved, 0);
    }

    #[test(framework = @0x1, creator = @0x123, intruder = @0x125)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    public entry fun test_approve_resolution_by_non_executor_fails(
        framework: &signer, creator: &signer, intruder: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[@0x124],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT, b""
        );
        // intruder is neither an executor nor (since executors is non-empty) a fallback creator.
        approve_resolution(intruder, timelock_addr, get_proposal_hash(EXECUTION_HASH, SALT));
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30009, location = Self)]
    public entry fun test_approve_resolution_already_canceled_fails(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT, b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, proposal_hash);
        // Cannot approve a transaction that has already been executed or canceled.
        approve_resolution(executor, timelock_addr, proposal_hash);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30008, location = Self)]
    public entry fun test_approve_resolution_before_delay_fails(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT, b""
        );
        // The delay has not elapsed, so approval must abort with ETIMELOCK_NOT_EXPIRED.
        approve_resolution(
            executor, timelock_addr, get_proposal_hash(EXECUTION_HASH, SALT)
        );
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_can_be_executed_view(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
        let proposal_hash = get_proposal_hash(EXECUTION_HASH, SALT);
        // Not yet executable — delay hasn't elapsed.
        assert!(!can_be_executed(timelock_addr, proposal_hash), 0);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        assert!(can_be_executed(timelock_addr, proposal_hash), 1);
        // Cancel makes it not executable.
        cancel_transaction(creator, timelock_addr, proposal_hash);
        assert!(!can_be_executed(timelock_addr, proposal_hash), 2);
    }

    // --- Self-governance tests ---
    //
    // The intended on-chain flow is: creator proposes a script hash, time elapses, executor
    // submits the script, the script calls `resolve` to obtain the timelock signer, and the
    // script then invokes the entry function below with that signer. These tests simulate the
    // post-resolve signer directly via `get_timelock_signer`.

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_update_min_num_seconds_execute(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        update_min_num_seconds_execute(&timelock_signer, 7200);
        assert!(min_num_seconds_execute(timelock_addr) == 7200, 0);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x1000F, location = Self)]
    public entry fun test_create_min_num_seconds_execute_too_large_fails(
        framework: &signer, creator: &signer
    ) {
        setup(framework);
        create_account(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            MAX_NUM_SECONDS_EXECUTE + 1
        );
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x1000F, location = Self)]
    public entry fun test_update_min_num_seconds_execute_too_large_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        update_min_num_seconds_execute(&timelock_signer, MAX_NUM_SECONDS_EXECUTE + 1);
    }

    #[test(framework = @0x1, creator_1 = @0x123, creator_2 = @0x124)]
    public entry fun test_add_and_remove_creators(
        framework: &signer, creator_1: &signer, creator_2: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator_1));
        let timelock_addr = get_next_timelock_account_address(address_of(creator_1));
        create(
            creator_1,
            vector[address_of(creator_1)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        add_creators(&timelock_signer, vector[address_of(creator_2)]);
        assert!(is_creator(address_of(creator_2), timelock_addr), 0);
        remove_creators(&timelock_signer, vector[address_of(creator_1)]);
        assert!(!is_creator(address_of(creator_1), timelock_addr), 1);
        assert!(is_creator(address_of(creator_2), timelock_addr), 2);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x3000C, location = Self)]
    public entry fun test_remove_all_creators_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        remove_creators(&timelock_signer, vector[address_of(creator)]);
    }

    #[test(
        framework = @0x1, creator = @0x123, executor_1 = @0x124, executor_2 = @0x125
    )]
    public entry fun test_add_and_remove_executors(
        framework: &signer,
        creator: &signer,
        executor_1: &signer,
        executor_2: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor_1)],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        add_executors(&timelock_signer, vector[address_of(executor_2)]);
        assert!(is_executor(address_of(executor_2), timelock_addr), 0);
        remove_executors(&timelock_signer, vector[address_of(executor_1)]);
        assert!(!is_executor(address_of(executor_1), timelock_addr), 1);
        assert!(is_executor(address_of(executor_2), timelock_addr), 2);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_remove_all_executors_allows_creator_to_execute(
        framework: &signer, creator: &signer, executor: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[address_of(executor)],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        remove_executors(&timelock_signer, vector[address_of(executor)]);
        assert!(is_executor(address_of(creator), timelock_addr), 0);
        assert!(!is_executor(address_of(executor), timelock_addr), 1);
    }

    // --- canceler tests ---

    #[test(framework = @0x1, creator = @0x123, canceler = @0x124)]
    public entry fun test_create_with_cancelers_membership(
        framework: &signer, creator: &signer, canceler: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[address_of(canceler)],
            TIMELOCK_SECS
        );
        assert!(is_canceler(address_of(canceler), timelock_addr), 0);
        assert!(cancelers(timelock_addr) == vector[address_of(canceler)], 1);
        // A canceler is neither a creator nor an executor.
        assert!(!is_creator(address_of(canceler), timelock_addr), 2);
        assert!(!is_executor(address_of(canceler), timelock_addr), 3);
    }

    #[test(framework = @0x1, creator = @0x123, canceler = @0x124)]
    #[expected_failure(abort_code = 0x10013, location = Self)]
    public entry fun test_create_with_duplicate_cancelers_fails(
        framework: &signer, creator: &signer, canceler: &signer
    ) {
        setup(framework);
        create_account(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[address_of(canceler), address_of(canceler)],
            TIMELOCK_SECS
        );
    }

    #[test(framework = @0x1, creator = @0x123, canceler = @0x124)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    /// A canceler can only cancel; it must not be able to propose transactions.
    public entry fun test_canceler_cannot_propose(
        framework: &signer, creator: &signer, canceler: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[address_of(canceler)],
            TIMELOCK_SECS
        );
        create_transaction(
            canceler,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            b""
        );
    }

    #[test(
        framework = @0x1, creator = @0x123, canceler_1 = @0x124, canceler_2 = @0x125
    )]
    public entry fun test_add_and_remove_cancelers(
        framework: &signer,
        creator: &signer,
        canceler_1: &signer,
        canceler_2: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        // Start with no cancelers; add and remove them through the self-governance flow.
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let timelock_signer = get_timelock_signer(timelock_addr);
        add_cancelers(
            &timelock_signer,
            vector[address_of(canceler_1), address_of(canceler_2)]
        );
        assert!(is_canceler(address_of(canceler_1), timelock_addr), 0);
        assert!(is_canceler(address_of(canceler_2), timelock_addr), 1);
        remove_cancelers(&timelock_signer, vector[address_of(canceler_1)]);
        assert!(!is_canceler(address_of(canceler_1), timelock_addr), 2);
        assert!(is_canceler(address_of(canceler_2), timelock_addr), 3);
        // The canceler list may be emptied entirely.
        remove_cancelers(&timelock_signer, vector[address_of(canceler_2)]);
        assert!(cancelers(timelock_addr) == vector[], 4);
    }

    // --- script_path tests ---

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create_transaction_with_script_path(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        let path = b"ipfs://bafybeigexampleexampleexamplecid";
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            path
        );
        let tx = get_transaction(timelock_addr, get_proposal_hash(EXECUTION_HASH, SALT));
        assert!(tx.script_path == path, 0);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x10012, location = Self)]
    public entry fun test_create_transaction_script_path_too_long_fails(
        framework: &signer, creator: &signer
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(
            creator,
            vector[address_of(creator)],
            vector[],
            vector[],
            TIMELOCK_SECS
        );
        // One byte over the cap.
        let path: vector<u8> = vector[];
        let i = 0;
        while (i <= MAX_SCRIPT_PATH_LENGTH) {
            path.push_back(0u8);
            i += 1;
        };
        create_transaction(
            creator,
            timelock_addr,
            EXECUTION_HASH,
            TIMELOCK_SECS,
            SALT,
            path
        );
    }

}
