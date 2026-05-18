/// Timelock account module for Movement. Unlike multisig accounts which require n-of-m
/// signatures, a timelock account enforces a time delay before transactions can be executed.
///
/// Each timelock account is a resource account with:
/// - A list of creators who can propose transactions (must have at least 1)
/// - A list of executors who can execute transactions after the timelock period
///   (if executors is empty, creators can also execute)
/// - A configurable minimum delay (`min_num_seconds_execute`) that must elapse after a
///   transaction is proposed before it can be executed
///
/// Execution model (mirrors `aptos_governance` resolution): a creator proposes the SHA3-256
/// hash of a future resolution script's bytecode. After the delay, an authorized executor submits a
/// `Script` transaction whose script hash equals the proposed `execution_hash`. The script
/// calls `resolve`, which verifies the running script's hash via
/// `transaction_context::get_script_hash()` and returns the timelock account's signer. The
/// script then performs arbitrary Move calls under that signer, including the self-governance
/// entry functions in this module.
///
/// Properties:
/// - Transactions are indexed by `keccak256(execution_hash || salt)`. To submit the same
///   script more than once, change the salt.
/// - Changing `min_num_seconds_execute` or membership can only happen through the timelock
///   proposal mechanism itself (the timelock account must be the signer).
/// - Both creators and executors can cancel any pending transaction at any time.
/// - Once executed or canceled, the transaction's `executed` field is set to true and the
///   entry is kept permanently for historical record.
/// - If the resolution script aborts, the entire transaction (including the `executed` flag
///   flip) reverts atomically, so the proposal remains executable.
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
    const TRANSACTION_HASH_LENGTH: u64 = 32;
    const SALT_LENGTH: u64 = 32;
    const MIN_NUM_SECONDS_EXECUTE_FLOOR: u64 = 360;

    /// Creator list cannot contain duplicate addresses.
    const EDUPLICATE_CREATOR: u64 = 1;
    /// Executor list cannot contain duplicate addresses.
    const EDUPLICATE_EXECUTOR: u64 = 2;
    /// Specified account is not a timelock account.
    const EACCOUNT_NOT_TIMELOCK: u64 = 3;
    /// The caller is not a creator.
    const ENOT_CREATOR: u64 = 4;
    /// The caller is not an executor (or a creator when the executor list is empty).
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
    /// The caller is neither a creator nor an executor.
    const ENOT_CREATOR_OR_EXECUTOR: u64 = 13;
    /// The specified number of seconds is below the required minimum: the account's
    /// `min_num_seconds_execute` must be greater than `MIN_NUM_SECONDS_EXECUTE_FLOOR` (360),
    /// and a transaction's `num_seconds_execute` must be at least the account's
    /// `min_num_seconds_execute`.
    const ENUMBER_SECONDS_TOO_SMALL: u64 = 14;
    /// The provided hash or salt must be exactly 32 bytes.
    const EINVALID_BYTES_LENGTH: u64 = 15;
    /// Current transaction script hash does not match the proposed execution hash.
    const EEXECUTION_HASH_NOT_MATCHING: u64 = 16;

    /// Represents a timelock account's configuration and pending/historical transactions.
    /// Stored at the resource account address created during timelock account creation.
    struct TimelockAccount has key {
        // Addresses allowed to propose transactions. Must have at least 1.
        creators: vector<address>,
        // Addresses allowed to execute transactions after the timelock period.
        // If empty, creators can also execute.
        executors: vector<address>,
        // Minimum seconds that must elapse after proposal before a transaction can be executed.
        min_num_seconds_execute: u64,
        // Map from `keccak256(execution_hash || salt)` to transaction. Entries are never
        // deleted; executed/canceled transactions remain with executed = true for record.
        transactions: Table<vector<u8>, TimelockTransaction>,
        // Signer capability for the resource account.
        signer_cap: SignerCapability,
    }

    /// A transaction proposed for timelock execution.
    ///
    /// `execution_hash` is the keccak256 hash of the authorized resolution script. At resolve
    /// time it is checked against the running script's hash via `transaction_context::get_script_hash()`.
    struct TimelockTransaction has copy, drop, store {
        execution_hash: vector<u8>,
        // The creator who proposed this transaction.
        creator: address,
        // Unix timestamp (seconds) when this transaction was proposed.
        creation_time_secs: u64,
        // Seconds that must elapse after creation_time_secs before this transaction can be executed.
        num_seconds_execute: u64,
        // User-provided salt used when deriving the transaction hash from execution_hash.
        salt: vector<u8>,
        // True once the transaction is resolved (successfully) or canceled.
        executed: bool,
    }

    // =============================== Events ===============================

    #[event]
    struct AddCreators has drop, store {
        timelock_account: address,
        creators_added: vector<address>,
    }

    #[event]
    struct RemoveCreators has drop, store {
        timelock_account: address,
        creators_removed: vector<address>,
    }

    #[event]
    struct AddExecutors has drop, store {
        timelock_account: address,
        executors_added: vector<address>,
    }

    #[event]
    struct RemoveExecutors has drop, store {
        timelock_account: address,
        executors_removed: vector<address>,
    }

    #[event]
    struct UpdateMinNumSecondsExecute has drop, store {
        timelock_account: address,
        old_min_num_seconds_execute: u64,
        new_min_num_seconds_execute: u64,
    }

    #[event]
    struct CreateTransaction has drop, store {
        timelock_account: address,
        creator: address,
        transaction_hash: vector<u8>,
        transaction: TimelockTransaction,
    }

    #[event]
    struct CancelTransaction has drop, store {
        timelock_account: address,
        actor: address,
        transaction_hash: vector<u8>,
    }

    #[event]
    struct ResolveTransaction has drop, store {
        timelock_account: address,
        executor: address,
        transaction_hash: vector<u8>,
        execution_hash: vector<u8>,
    }

    // =============================== View functions ===============================

    #[view]
    /// Return the list of creators for the given timelock account.
    public fun creators(timelock_account: address): vector<address> acquires TimelockAccount {
        borrow_global<TimelockAccount>(timelock_account).creators
    }

    #[view]
    /// Return the list of executors. An empty list means creators can also execute.
    public fun executors(timelock_account: address): vector<address> acquires TimelockAccount {
        borrow_global<TimelockAccount>(timelock_account).executors
    }

    #[view]
    /// Return the minimum timelock delay in seconds.
    public fun min_num_seconds_execute(timelock_account: address): u64 acquires TimelockAccount {
        borrow_global<TimelockAccount>(timelock_account).min_num_seconds_execute
    }

    #[view]
    /// Return true if the given address is a creator of the timelock account.
    public fun is_creator(addr: address, timelock_account: address): bool acquires TimelockAccount {
        borrow_global<TimelockAccount>(timelock_account).creators.contains(&addr)
    }

    #[view]
    /// Return true if the given address is authorized to execute transactions.
    /// If the executor list is empty, creators are also authorized to execute.
    public fun is_executor(addr: address, timelock_account: address): bool acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        if (timelock.executors.is_empty()) {
            timelock.creators.contains(&addr)
        } else {
            timelock.executors.contains(&addr)
        }
    }

    #[view]
    /// Return the transaction stored under the given transaction hash.
    public fun get_transaction(
        timelock_account: address,
        transaction_hash: vector<u8>,
    ): TimelockTransaction acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        assert!(
            timelock.transactions.contains(transaction_hash),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        *timelock.transactions.borrow(transaction_hash)
    }

    #[view]
    /// Return true if the transaction exists, is not yet executed/canceled,
    /// and has passed the timelock period.
    public fun can_be_executed(
        timelock_account: address,
        transaction_hash: vector<u8>,
    ): bool acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        if (!timelock.transactions.contains(transaction_hash)) {
            return false
        };
        let tx = timelock.transactions.borrow(transaction_hash);
        !tx.executed && now_seconds() >= tx.creation_time_secs + tx.num_seconds_execute
    }

    #[view]
    /// Return the predicted address for the next timelock account deployed by the given account.
    /// The deployer authorizes resource-account creation but does not become a creator or executor;
    /// membership is determined entirely by the `creators` and `executors` arguments to `create`.
    public fun get_next_timelock_account_address(deployer: address): address {
        let owner_nonce = account::get_sequence_number(deployer);
        create_resource_address(&deployer, create_timelock_account_seed(to_bytes(&owner_nonce)))
    }

    #[view]
    /// Return the table key used to index a transaction with the given execution hash and salt.
    /// Clients use this to compute the hash before proposing a transaction.
    public fun get_transaction_hash(execution_hash: vector<u8>, salt: vector<u8>): vector<u8> {
        let bytes = copy execution_hash;
        bytes.append(copy salt);
        keccak256(bytes)
    }

    // =============================== Account creation ===============================

    /// Create a new timelock account.
    ///
    /// The `deployer` signer authorizes resource-account creation (and pays storage gas) but
    /// gains no ongoing authority over the timelock — they are not added to creators or
    /// executors. This lets a deployer (e.g. a multisig) instantiate a timelock that is owned
    /// by an entirely different set of addresses without first having to transfer ownership.
    ///
    /// @param deployer Signer used to derive the resource-account address. Must not appear in
    ///        `creators` or `executors` unless that role is intended.
    /// @param creators Addresses authorized to propose transactions. Must contain at least one
    ///        address and have no duplicates. The timelock account address itself is not allowed.
    /// @param executors Addresses authorized to execute transactions after the timelock period.
    ///        If empty, creators can also execute.
    /// @param num_seconds_execute Minimum delay in seconds before a proposed transaction can be executed.
    public entry fun create(
        deployer: &signer,
        creators: vector<address>,
        executors: vector<address>,
        num_seconds_execute: u64,
    ) {
        let (timelock_signer, timelock_signer_cap) = create_timelock_account(deployer);
        create_timelock_account_internal(
            &timelock_signer,
            creators,
            executors,
            num_seconds_execute,
            timelock_signer_cap,
        );
    }

    fun create_timelock_account_internal(
        timelock_account: &signer,
        creators: vector<address>,
        executors: vector<address>,
        min_num_seconds_execute: u64,
        signer_cap: SignerCapability,
    ) {
        let timelock_address = address_of(timelock_account);
        assert!(creators.length() >= 1, error::invalid_argument(ENOT_ENOUGH_CREATORS));
        validate_members(&creators, timelock_address, EDUPLICATE_CREATOR);
        validate_members(&executors, timelock_address, EDUPLICATE_EXECUTOR);
        assert_delay(min_num_seconds_execute);

        move_to(timelock_account, TimelockAccount {
            creators,
            executors,
            min_num_seconds_execute,
            transactions: table::new<vector<u8>, TimelockTransaction>(),
            signer_cap,
        });
    }

    // =============================== Self-governance ===============================
    // These functions can only be called by the timelock account itself. The intended flow is:
    // a creator proposes a resolution script that calls one of these entry functions, the
    // timelock period elapses, an executor submits the script, the script calls `resolve` to
    // obtain the timelock signer, then invokes the entry function with that signer.

    /// Add new creators to the timelock account.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    public entry fun add_creators(
        timelock_account: &signer,
        new_creators: vector<address>,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let creators_added = copy new_creators;
        validate_members(&new_creators, timelock_address, EDUPLICATE_CREATOR);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        timelock.creators.append(new_creators);
        // Re-validate the combined list to catch cross-list duplicates.
        validate_members(&timelock.creators, timelock_address, EDUPLICATE_CREATOR);
        emit(AddCreators { timelock_account: timelock_address, creators_added });
    }

    /// Remove creators from the timelock account. At least one creator must remain.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    public entry fun remove_creators(
        timelock_account: &signer,
        creators_to_remove: vector<address>,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        let creators_removed = vector[];
        creators_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.creators.index_of(to_remove);
            if (found) {
                creators_removed.push_back(timelock.creators.swap_remove(index));
            }
        });
        assert!(
            timelock.creators.length() >= 1,
            error::invalid_state(EWOULD_REMOVE_ALL_CREATORS),
        );
        if (!creators_removed.is_empty()) {
            emit(RemoveCreators { timelock_account: timelock_address, creators_removed });
        };
    }

    /// Add new executors to the timelock account.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    public entry fun add_executors(
        timelock_account: &signer,
        new_executors: vector<address>,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let executors_added = copy new_executors;
        validate_members(&new_executors, timelock_address, EDUPLICATE_EXECUTOR);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        timelock.executors.append(new_executors);
        validate_members(&timelock.executors, timelock_address, EDUPLICATE_EXECUTOR);
        emit(AddExecutors { timelock_account: timelock_address, executors_added });
    }

    /// Remove executors from the timelock account.
    /// After removal the executor list may be empty, which means creators can execute.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    public entry fun remove_executors(
        timelock_account: &signer,
        executors_to_remove: vector<address>,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        let executors_removed = vector[];
        executors_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.executors.index_of(to_remove);
            if (found) {
                executors_removed.push_back(timelock.executors.swap_remove(index));
            }
        });
        if (!executors_removed.is_empty()) {
            emit(RemoveExecutors { timelock_account: timelock_address, executors_removed });
        };
    }

    /// Update the timelock delay. The new value takes effect immediately for future proposals.
    /// Existing pending transactions are not affected.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    public entry fun update_min_num_seconds_execute(
        timelock_account: &signer,
        new_min_num_seconds_execute: u64,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        assert_delay(new_min_num_seconds_execute);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        let old_min_num_seconds_execute = timelock.min_num_seconds_execute;
        timelock.min_num_seconds_execute = new_min_num_seconds_execute;
        emit(UpdateMinNumSecondsExecute {
            timelock_account: timelock_address,
            old_min_num_seconds_execute,
            new_min_num_seconds_execute,
        });
    }

    // =============================== Transaction flow ===============================

    /// Propose a new transaction to be executed after the timelock period.
    ///
    /// `execution_hash` is the SHA3-256 hash of the resolution script's bytecode that will
    /// perform the transaction's effects when submitted. `salt` (32 bytes) disambiguates duplicate
    /// proposals of the same script. The table key is `keccak256(execution_hash || salt)`.
    /// `num_seconds_execute` must be >= `min_num_seconds_execute`.
    public entry fun create_transaction(
        creator: &signer,
        timelock_account: address,
        execution_hash: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_is_creator(creator, timelock_account);
        assert!(execution_hash.length() == SCRIPT_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));
        assert!(salt.length() == SALT_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));

        let transaction_hash = get_transaction_hash(copy execution_hash, copy salt);
        let creator_addr = address_of(creator);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
        assert!(num_seconds_execute >= timelock.min_num_seconds_execute, error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL));
        assert!(
            !timelock.transactions.contains(transaction_hash),
            error::already_exists(EDUPLICATE_TRANSACTION),
        );

        let transaction = TimelockTransaction {
            execution_hash,
            creator: creator_addr,
            creation_time_secs: now_seconds(),
            num_seconds_execute,
            salt,
            executed: false,
        };
        timelock.transactions.add(copy transaction_hash, copy transaction);

        emit(CreateTransaction {
            timelock_account,
            creator: creator_addr,
            transaction_hash,
            transaction,
        });
    }

    /// Cancel a pending transaction. The transaction's executed field is set to true.
    /// Any creator or executor can cancel at any time.
    /// `transaction_hash` must be exactly 32 bytes.
    public entry fun cancel_transaction(
        actor: &signer,
        timelock_account: address,
        transaction_hash: vector<u8>,
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert!(transaction_hash.length() == TRANSACTION_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));
        let actor_addr = address_of(actor);

        // Evaluate authorization before acquiring the mutable borrow.
        let actor_is_creator = is_creator(actor_addr, timelock_account);
        let actor_is_executor = is_executor(actor_addr, timelock_account);
        assert!(
            actor_is_creator || actor_is_executor,
            error::permission_denied(ENOT_CREATOR_OR_EXECUTOR),
        );

        let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
        assert!(
            timelock.transactions.contains(transaction_hash),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        let transaction = timelock.transactions.borrow_mut(transaction_hash);
        assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
        transaction.executed = true;

        emit(CancelTransaction { timelock_account, actor: actor_addr, transaction_hash });
    }

    /// Resolve a pending transaction and return the timelock account's signer.
    ///
    /// Asserts that:
    /// - The account exists and is a timelock account
    /// - The executor is authorized
    /// - The transaction exists and has not been executed or canceled
    /// - The timelock period (creation_time_secs + num_seconds_execute) has elapsed
    /// - The running script's hash equals the transaction's execution_hash
    ///
    /// Marks the transaction executed, emits ResolveTransaction, and returns the signer for
    /// the timelock account. The calling script uses this signer to perform the transaction's
    /// effects (including, optionally, the self-governance entry functions in this module).
    /// If the script later aborts, the entire transaction—including the executed flag flip—
    /// reverts atomically, leaving the proposal in its previous state.
    public fun resolve(
        executor: &signer,
        timelock_account: address,
        transaction_hash: vector<u8>,
    ): signer acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_is_executor(executor, timelock_account);
        assert!(transaction_hash.length() == TRANSACTION_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));

        let executor_addr = address_of(executor);
        {
            let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
            assert!(
                timelock.transactions.contains(transaction_hash),
                error::not_found(ETRANSACTION_NOT_FOUND),
            );
            let transaction = timelock.transactions.borrow_mut(transaction_hash);
            assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
            assert!(
                now_seconds() >= transaction.creation_time_secs + transaction.num_seconds_execute,
                error::invalid_state(ETIMELOCK_NOT_EXPIRED),
            );
            assert!(
                transaction_context::get_script_hash() == transaction.execution_hash,
                error::invalid_argument(EEXECUTION_HASH_NOT_MATCHING),
            );
            transaction.executed = true;
            emit(ResolveTransaction {
                timelock_account,
                executor: executor_addr,
                transaction_hash,
                execution_hash: transaction.execution_hash,
            });
        };

        let timelock = borrow_global<TimelockAccount>(timelock_account);
        account::create_signer_with_capability(&timelock.signer_cap)
    }

    // =============================== Private helpers ===============================

    fun create_timelock_account(deployer: &signer): (signer, SignerCapability) {
        let deployer_nonce = account::get_sequence_number(address_of(deployer));
        let (timelock_signer, timelock_signer_cap) =
            account::create_resource_account(deployer, create_timelock_account_seed(to_bytes(&deployer_nonce)));
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
    fun validate_members(members: &vector<address>, timelock_address: address, duplicate_error: u64) {
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
                error::invalid_argument(ESELF_CANNOT_BE_MEMBER),
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
            error::invalid_state(EACCOUNT_NOT_TIMELOCK),
        );
    }

    inline fun assert_is_creator(creator: &signer, timelock_account: address) {
        assert!(
            borrow_global<TimelockAccount>(timelock_account).creators.contains(&address_of(creator)),
            error::permission_denied(ENOT_CREATOR),
        );
    }

    inline fun assert_is_executor(executor: &signer, timelock_account: address) {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        let executor_addr = address_of(executor);
        let authorized = if (timelock.executors.is_empty()) {
            timelock.creators.contains(&executor_addr)
        } else {
            timelock.executors.contains(&executor_addr)
        };
        assert!(authorized, error::permission_denied(ENOT_EXECUTOR));
    }

    inline fun assert_delay(num_seconds_execute: u64) {
        assert!(
            num_seconds_execute > MIN_NUM_SECONDS_EXECUTE_FLOOR,
            error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL),
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
            &borrow_global<TimelockAccount>(timelock_account).signer_cap
        )
    }

    // --- Creation tests ---

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create(framework: &signer, creator: &signer) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        assert_timelock_account_exists(timelock_addr);
        assert!(creators(timelock_addr) == vector[address_of(creator)], 0);
        assert!(executors(timelock_addr) == vector[], 1);
        assert!(min_num_seconds_execute(timelock_addr) == TIMELOCK_SECS, 2);
    }

    #[test(framework = @0x1, creator_1 = @0x123, creator_2 = @0x124, executor_1 = @0x125)]
    public entry fun test_create_with_multiple_members(
        framework: &signer,
        creator_1: &signer,
        creator_2: &signer,
        executor_1: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator_1));
        let timelock_addr = get_next_timelock_account_address(address_of(creator_1));
        create(
            creator_1,
            vector[address_of(creator_1), address_of(creator_2)],
            vector[address_of(executor_1)],
            TIMELOCK_SECS,
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
        framework: &signer,
        creator_1: &signer,
        creator_2: &signer,
    ) {
        setup(framework);
        create_account(address_of(creator_1));
        let creator_2_addr = address_of(creator_2);
        create(creator_1, vector[creator_2_addr, creator_2_addr], vector[], TIMELOCK_SECS);
    }

    #[test(framework = @0x1, deployer = @0x123, owner = @0x456, executor = @0x789)]
    public entry fun test_create_deployer_not_auto_member(
        framework: &signer,
        deployer: &signer,
        owner: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(deployer));
        let timelock_addr = get_next_timelock_account_address(address_of(deployer));
        // Deployer is the signer used to derive the resource account but is NOT a creator/executor.
        create(
            deployer,
            vector[address_of(owner)],
            vector[address_of(executor)],
            TIMELOCK_SECS,
        );
        assert!(creators(timelock_addr) == vector[address_of(owner)], 0);
        assert!(!is_creator(address_of(deployer), timelock_addr), 1);
        assert!(!is_executor(address_of(deployer), timelock_addr), 2);
    }

    #[test(framework = @0x1, deployer = @0x123)]
    #[expected_failure(abort_code = 0x10006, location = Self)]
    public entry fun test_create_with_empty_creators_fails(
        framework: &signer,
        deployer: &signer,
    ) {
        setup(framework);
        create_account(address_of(deployer));
        create(deployer, vector[], vector[], TIMELOCK_SECS);
    }

    // --- Transaction creation tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_create_transaction(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        let tx = get_transaction(timelock_addr, tx_hash);
        assert!(tx.creator == address_of(creator), 0);
        assert!(!tx.executed, 1);
        assert!(tx.salt == SALT, 2);
        assert!(tx.execution_hash == EXECUTION_HASH, 3);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x8000B, location = Self)]
    public entry fun test_create_duplicate_transaction_fails(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        // Same execution hash and salt — must fail.
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create_same_execution_hash_different_salt(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        // Different salt — must succeed.
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT_2);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x1000F, location = Self)]
    public entry fun test_create_transaction_invalid_execution_hash_length_fails(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, INVALID_BYTES, TIMELOCK_SECS, SALT);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x1000F, location = Self)]
    public entry fun test_create_transaction_invalid_salt_length_fails(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, INVALID_BYTES);
    }

    #[test(framework = @0x1, creator = @0x123, non_creator = @0x999)]
    #[expected_failure(abort_code = 0x50004, location = Self)]
    public entry fun test_non_creator_cannot_propose(
        framework: &signer,
        creator: &signer,
        non_creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(non_creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
    }

    // --- Cancellation tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_cancel_by_creator(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, tx_hash);
        let tx = get_transaction(timelock_addr, tx_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_cancel_by_executor(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        cancel_transaction(executor, timelock_addr, tx_hash);
        let tx = get_transaction(timelock_addr, tx_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_cancel_by_creator_when_executors_empty(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, tx_hash);
        let tx = get_transaction(timelock_addr, tx_hash);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30009, location = Self)]
    public entry fun test_cancel_already_executed_fails(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, tx_hash);
        cancel_transaction(creator, timelock_addr, tx_hash);
    }

    #[test(framework = @0x1, creator = @0x123, non_member = @0x999)]
    #[expected_failure(abort_code = 0x5000D, location = Self)]
    public entry fun test_cancel_by_non_member_fails(
        framework: &signer,
        creator: &signer,
        non_member: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        cancel_transaction(non_member, timelock_addr, get_transaction_hash(EXECUTION_HASH, SALT));
    }

    // --- Resolve tests ---
    //
    // Note: `resolve` reads `transaction_context::get_script_hash()`, which has no usable value
    // outside of an actual Script transaction. Move-level unit tests therefore cover only the
    // pre-checks that abort before that comparison. End-to-end tests cover the positive flow.

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30008, location = Self)]
    public entry fun test_resolve_before_timelock_expires_fails(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        // No time advance — must fail with ETIMELOCK_NOT_EXPIRED.
        let _ = resolve(executor, timelock_addr, get_transaction_hash(EXECUTION_HASH, SALT));
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x30009, location = Self)]
    public entry fun test_resolve_canceled_fails(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        cancel_transaction(creator, timelock_addr, tx_hash);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        let _ = resolve(executor, timelock_addr, tx_hash);
    }

    #[test(framework = @0x1, creator = @0x123, non_member = @0x999)]
    #[expected_failure(abort_code = 0x50005, location = Self)]
    public entry fun test_resolve_by_non_executor_fails(
        framework: &signer,
        creator: &signer,
        non_member: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[@0x124], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        let _ = resolve(non_member, timelock_addr, get_transaction_hash(EXECUTION_HASH, SALT));
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_can_be_executed_view(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, EXECUTION_HASH, TIMELOCK_SECS, SALT);
        let tx_hash = get_transaction_hash(EXECUTION_HASH, SALT);
        // Not yet executable — delay hasn't elapsed.
        assert!(!can_be_executed(timelock_addr, tx_hash), 0);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        assert!(can_be_executed(timelock_addr, tx_hash), 1);
        // Cancel makes it not executable.
        cancel_transaction(creator, timelock_addr, tx_hash);
        assert!(!can_be_executed(timelock_addr, tx_hash), 2);
    }

    // --- Self-governance tests ---
    //
    // The intended on-chain flow is: creator proposes a script hash, time elapses, executor
    // submits the script, the script calls `resolve` to obtain the timelock signer, and the
    // script then invokes the entry function below with that signer. These tests simulate the
    // post-resolve signer directly via `get_timelock_signer`.

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_update_min_num_seconds_execute(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        update_min_num_seconds_execute(&timelock_signer, 7200);
        assert!(min_num_seconds_execute(timelock_addr) == 7200, 0);
    }

    #[test(framework = @0x1, creator_1 = @0x123, creator_2 = @0x124)]
    public entry fun test_add_and_remove_creators(
        framework: &signer,
        creator_1: &signer,
        creator_2: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator_1));
        let timelock_addr = get_next_timelock_account_address(address_of(creator_1));
        create(creator_1, vector[address_of(creator_1)], vector[], TIMELOCK_SECS);
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
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        remove_creators(&timelock_signer, vector[address_of(creator)]);
    }

    #[test(framework = @0x1, creator = @0x123, executor_1 = @0x124, executor_2 = @0x125)]
    public entry fun test_add_and_remove_executors(
        framework: &signer,
        creator: &signer,
        executor_1: &signer,
        executor_2: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor_1)], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        add_executors(&timelock_signer, vector[address_of(executor_2)]);
        assert!(is_executor(address_of(executor_2), timelock_addr), 0);
        remove_executors(&timelock_signer, vector[address_of(executor_1)]);
        assert!(!is_executor(address_of(executor_1), timelock_addr), 1);
        assert!(is_executor(address_of(executor_2), timelock_addr), 2);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_remove_all_executors_allows_creator_to_execute(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[address_of(creator)], vector[address_of(executor)], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        remove_executors(&timelock_signer, vector[address_of(executor)]);
        assert!(is_executor(address_of(creator), timelock_addr), 0);
        assert!(!is_executor(address_of(executor), timelock_addr), 1);
    }
}
