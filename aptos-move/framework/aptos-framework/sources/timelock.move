/// Timelock account module for Aptos. Unlike multisig accounts which require n-of-m signatures,
/// a timelock account enforces a time delay before transactions can be executed.
///
/// The timelock account is a resource account underneath. It has:
/// - A list of creators who can propose transactions (must have at least 1)
/// - A list of executors who can execute transactions after the timelock period
///   (if executors is empty, creators can also execute)
/// - A configurable time delay (num_seconds_execute) that must elapse after a transaction
///   is proposed before it can be executed
///
/// Key properties:
/// - Transactions are indexed by a user-provided salt (not a sequence number), allowing
///   non-sequential execution. To submit the same payload more than once, change the salt.
/// - Changing num_seconds_execute or membership can only happen through the timelock proposal
///   mechanism itself (the timelock account must be the signer).
/// - Both creators and executors can cancel any pending transaction at any time.
/// - Once executed or canceled, the transaction's executed field is set to true.
///   Entries are kept permanently for historical record.
/// - The actual transaction execution uses the validate_timelock_transaction / cleanup pattern
///   (analogous to validate_multisig_transaction in multisig_account) and requires VM support
///   for a TimelockTransaction transaction type.
module aptos_framework::timelock {
    use aptos_framework::account::{Self, SignerCapability, create_resource_address};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event::emit;
    use aptos_framework::timestamp::now_seconds;
    use aptos_std::table::{Self, Table};
    use std::bcs::to_bytes;
    use std::error;
    use std::option::{Self, Option};
    use std::signer::address_of;
    use std::string::String;

    /// Domain separator used when deriving the resource account seed, to avoid collisions
    /// with other modules that create resource accounts.
    const DOMAIN_SEPARATOR: vector<u8> = b"aptos_framework::timelock";

    // Error codes > 2000 may be thrown from the transaction prologue.
    /// Creator list cannot contain duplicate addresses.
    const EDUPLICATE_CREATOR: u64 = 1;
    /// Executor list cannot contain duplicate addresses.
    const EDUPLICATE_EXECUTOR: u64 = 2;
    /// Specified account is not a timelock account.
    const EACCOUNT_NOT_TIMELOCK: u64 = 2011;
    /// The caller is not a creator of the timelock account.
    const ENOT_CREATOR: u64 = 2003;
    /// The caller is not an executor of the timelock account (or a creator when executors is empty).
    const ENOT_EXECUTOR: u64 = 2004;
    /// Transaction payload cannot be empty.
    const EPAYLOAD_CANNOT_BE_EMPTY: u64 = 4;
    /// Timelock account must have at least one creator.
    const ENOT_ENOUGH_CREATORS: u64 = 5;
    /// Transaction with the specified salt was not found.
    const ETRANSACTION_NOT_FOUND: u64 = 2012;
    /// Provided payload does not match the payload stored on chain for this transaction.
    const EPAYLOAD_DOES_NOT_MATCH: u64 = 2007;
    /// The timelock period has not elapsed yet.
    const ETIMELOCK_NOT_EXPIRED: u64 = 2013;
    /// Transaction has already been executed or canceled.
    const ETRANSACTION_ALREADY_EXECUTED: u64 = 9;
    /// The timelock account itself cannot be a creator or executor.
    const ESELF_CANNOT_BE_MEMBER: u64 = 10;
    /// A transaction with this salt already exists.
    const EDUPLICATE_SALT: u64 = 11;
    /// Removing these creators would leave the timelock account with zero creators.
    const EWOULD_REMOVE_ALL_CREATORS: u64 = 12;
    /// The caller is neither a creator nor an executor.
    const ENOT_CREATOR_OR_EXECUTOR: u64 = 13;
    /// The specified number of seconds for execution is too small (must be > 360).
    const ENUMBER_SECONDS_TOO_SMALL: u64 = 14;

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
        // Map from salt to transaction. Entries are never deleted; executed/canceled
        // transactions are kept with executed = true for historical record.
        transactions: Table<vector<u8>, TimelockTransaction>,
        // Signer capability for the resource account.
        signer_cap: Option<SignerCapability>,
    }

    /// A transaction proposed for timelock execution.
    struct TimelockTransaction has copy, drop, store {
        // BCS-encoded `TimelockTransactionPayload`.
        // - `Some(bytes)`: the full payload is stored on-chain. During execution the VM verifies
        //   that the bytes in the submitted transaction match exactly what is stored here.
        // - `None`: no payload is stored on-chain (e.g. the proposer chose off-chain storage).
        //   In this case the VM uses whatever payload is supplied in the transaction without
        //   performing a byte-equality check.
        payload: Option<vector<u8>>,
        // The creator who proposed this transaction.
        creator: address,
        // Unix timestamp (seconds) when this transaction was proposed.
        creation_time_secs: u64,
        // Amount of seconds that must elapse after creation_time_secs before this transaction can be executed.
        num_seconds_execute: u64,
        // User-provided salt. Acts as the table key and differentiates transactions.
        // To submit the same payload again, use a different salt.
        salt: vector<u8>,
        // True once the transaction is executed (successfully or not) or canceled.
        executed: bool,
    }

    /// Information about a transaction execution failure.
    struct ExecutionError has copy, drop, store {
        abort_location: String,
        // One of: "VMError", "MoveAbort", "MoveExecutionFailure"
        error_type: String,
        error_code: u64,
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
        salt: vector<u8>,
        transaction: TimelockTransaction,
    }

    #[event]
    struct CancelTransaction has drop, store {
        timelock_account: address,
        actor: address,
        salt: vector<u8>,
    }

    #[event]
    struct TransactionExecutionSucceeded has drop, store {
        timelock_account: address,
        executor: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
    }

    #[event]
    struct TransactionExecutionFailed has drop, store {
        timelock_account: address,
        executor: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
        execution_error: ExecutionError,
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
    /// Return the transaction stored under the given salt.
    public fun get_transaction(
        timelock_account: address,
        salt: vector<u8>,
    ): TimelockTransaction acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        assert!(
            timelock.transactions.contains(salt),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        *timelock.transactions.borrow(salt)
    }

    #[view]
    /// Return true if the transaction with the given salt exists, is not yet executed/canceled,
    /// and has passed the timelock period.
    public fun can_be_executed(timelock_account: address, salt: vector<u8>): bool acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        if (!timelock.transactions.contains(salt)) {
            return false
        };
        let tx = timelock.transactions.borrow(salt);
        !tx.executed && now_seconds() >= tx.creation_time_secs + tx.num_seconds_execute
    }

    #[view]
    /// Return the predicted address for the next timelock account created by the given creator.
    public fun get_next_timelock_account_address(creator: address): address {
        let owner_nonce = account::get_sequence_number(creator);
        create_resource_address(&creator, create_timelock_account_seed(to_bytes(&owner_nonce)))
    }

    #[view]
    /// Return the authoritative payload bytes for the transaction identified by `salt`.
    /// If a payload is stored on-chain for this transaction, that stored value is returned.
    /// Otherwise `provided_payload` is returned as-is (off-chain storage path).
    ///
    /// This is called by the VM when executing a timelock transaction whose payload was not
    /// included in the transaction envelope (analogous to `get_next_transaction_payload` in
    /// multisig_account).
    public fun get_transaction_payload(
        timelock_account: address,
        salt: vector<u8>,
        provided_payload: vector<u8>,
    ): vector<u8> acquires TimelockAccount {
        let timelock = borrow_global<TimelockAccount>(timelock_account);
        assert!(
            timelock.transactions.contains(salt),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        let transaction = timelock.transactions.borrow(salt);
        if (transaction.payload.is_some()) {
            *transaction.payload.borrow()
        } else {
            provided_payload
        }
    }

    // =============================== Account creation ===============================

    /// Create a new timelock account with the calling signer as the initial creator.
    ///
    /// @param additional_creators Additional creator addresses. The calling signer is always
    ///        included. No duplicates allowed.
    /// @param executors Addresses authorized to execute transactions after the timelock period.
    ///        If empty, creators can also execute.
    /// @param num_seconds_execute Delay in seconds before a proposed transaction can be executed.
    public entry fun create(
        creator: &signer,
        additional_creators: vector<address>,
        executors: vector<address>,
        num_seconds_execute: u64,
    ) {
        let (timelock_signer, timelock_signer_cap) = create_timelock_account(creator);
        additional_creators.push_back(address_of(creator));
        create_timelock_account_internal(
            &timelock_signer,
            additional_creators,
            executors,
            num_seconds_execute,
            option::some(timelock_signer_cap),
        );
    }

    fun create_timelock_account_internal(
        timelock_account: &signer,
        creators: vector<address>,
        executors: vector<address>,
        min_num_seconds_execute: u64,
        signer_cap: Option<SignerCapability>,
    ) {
        let timelock_address = address_of(timelock_account);
        assert!(
            creators.length() >= 1,
            error::invalid_argument(ENOT_ENOUGH_CREATORS),
        );
        validate_members(&creators, timelock_address, EDUPLICATE_CREATOR);
        validate_members(&executors, timelock_address, EDUPLICATE_EXECUTOR);
        assert!(min_num_seconds_execute > 360, error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL));

        move_to(timelock_account, TimelockAccount {
            creators,
            executors,
            min_num_seconds_execute,
            transactions: table::new<vector<u8>, TimelockTransaction>(),
            signer_cap,
        });
    }

    // =============================== Self-governance ===============================
    // These functions can only be called by the timelock account itself. The intended
    // flow is: a creator proposes a transaction calling one of these entry functions,
    // the timelock period elapses, and an executor submits the TimelockTransaction.
    // The VM then uses the timelock account's signer (from signer_cap) to invoke these.

    /// Add new creators to the timelock account.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    entry fun add_creators(
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
    entry fun remove_creators(
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
        if (creators_removed.length() > 0) {
            emit(RemoveCreators { timelock_account: timelock_address, creators_removed });
        };
    }

    /// Add new executors to the timelock account.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    entry fun add_executors(
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
    entry fun remove_executors(
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
        if (executors_removed.length() > 0) {
            emit(RemoveExecutors { timelock_account: timelock_address, executors_removed });
        };
    }

    /// Update the timelock delay. The new value takes effect immediately for future proposals.
    /// Existing pending transactions are not affected.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    entry fun update_min_num_seconds_execute(
        timelock_account: &signer,
        new_min_num_seconds_execute: u64,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        assert!(new_min_num_seconds_execute > 360, error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL));
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
    /// @param payload BCS-encoded transaction payload. Must not be empty.
    /// @param salt    Unique identifier for this proposal. Use a different salt to submit
    ///                the same payload again.
    public entry fun create_transaction(
        creator: &signer,
        timelock_account: address,
        payload: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
    ) acquires TimelockAccount {
        assert!(!payload.is_empty(), error::invalid_argument(EPAYLOAD_CANNOT_BE_EMPTY));
        assert_timelock_account_exists(timelock_account);
        assert_is_creator(creator, timelock_account);

        let creator_addr = address_of(creator);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
        assert!(
            !timelock.transactions.contains(salt),
            error::already_exists(EDUPLICATE_SALT),
        );
        assert!(num_seconds_execute >= timelock.min_num_seconds_execute, error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL));

        let transaction = TimelockTransaction {
            payload: option::some(payload),
            creator: creator_addr,
            creation_time_secs: now_seconds(),
            num_seconds_execute,
            salt,
            executed: false,
        };
        timelock.transactions.add(salt, transaction);

        emit(CreateTransaction { timelock_account, creator: creator_addr, salt, transaction });
    }

    /// Cancel a pending transaction. The transaction's executed field is set to true.
    /// Any creator or executor (or creator when executors is empty) can cancel at any time.
    public entry fun cancel_transaction(
        actor: &signer,
        timelock_account: address,
        salt: vector<u8>,
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
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
            timelock.transactions.contains(salt),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        let transaction = timelock.transactions.borrow_mut(salt);
        assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
        transaction.executed = true;

        emit(CancelTransaction { timelock_account, actor: actor_addr, salt });
    }

    // =============================== VM-called functions ===============================

    /// Called by the VM as part of the transaction prologue for timelock transactions.
    ///
    /// Validates that:
    /// - The account exists and is a timelock account
    /// - The executor is authorized
    /// - The transaction exists and has not been executed or canceled
    /// - The timelock period (creation_time_secs + num_seconds_execute) has elapsed
    /// - If a payload is stored on chain and a non-empty payload is provided, they match
    fun validate_timelock_transaction(
        executor: &signer,
        timelock_account: address,
        payload: vector<u8>,
        salt: vector<u8>,
    ) acquires TimelockAccount {
        assert_timelock_account_exists(timelock_account);
        assert_is_executor(executor, timelock_account);

        let timelock = borrow_global<TimelockAccount>(timelock_account);
        assert!(
            timelock.transactions.contains(salt),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        let transaction = timelock.transactions.borrow(salt);
        assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
        assert!(
            now_seconds() >= transaction.creation_time_secs + transaction.num_seconds_execute,
            error::invalid_state(ETIMELOCK_NOT_EXPIRED),
        );
        // If a payload is stored on chain and a non-empty payload is provided, verify they match.
        if (transaction.payload.is_some() && !payload.is_empty()) {
            let stored = transaction.payload.borrow();
            assert!(payload == *stored, error::invalid_argument(EPAYLOAD_DOES_NOT_MATCH));
        };
    }

    /// Called by the VM after a successful timelock transaction execution.
    /// Marks the transaction as executed and emits a success event.
    fun successful_transaction_execution_cleanup(
        executor: address,
        timelock_account: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
    ) acquires TimelockAccount {
        let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
        timelock.transactions.borrow_mut(salt).executed = true;
        emit(TransactionExecutionSucceeded { timelock_account, executor, salt, transaction_payload });
    }

    /// Called by the VM after a failed timelock transaction execution.
    /// Marks the transaction as executed and emits a failure event.
    fun failed_transaction_execution_cleanup(
        executor: address,
        timelock_account: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
        execution_error: ExecutionError,
    ) acquires TimelockAccount {
        let timelock = borrow_global_mut<TimelockAccount>(timelock_account);
        timelock.transactions.borrow_mut(salt).executed = true;
        emit(TransactionExecutionFailed {
            timelock_account, executor, salt, transaction_payload, execution_error,
        });
    }

    // =============================== Private helpers ===============================

    fun create_timelock_account(creator: &signer): (signer, SignerCapability) {
        let creator_nonce = account::get_sequence_number(address_of(creator));
        let (timelock_signer, timelock_signer_cap) =
            account::create_resource_account(creator, create_timelock_account_seed(to_bytes(&creator_nonce)));
        // Register for APT so the timelock account can pay gas and receive transfers.
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
        members.for_each_ref(|member| {
            let member = *member;
            assert!(
                member != timelock_address,
                error::invalid_argument(ESELF_CANNOT_BE_MEMBER),
            );
            let (found, _) = distinct.index_of(&member);
            assert!(!found, error::invalid_argument(duplicate_error));
            distinct.push_back(member);
        });
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

    // =============================== Tests ===============================

    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use std::string::utf8;
    #[test_only]
    use aptos_framework::aptos_coin;
    #[test_only]
    use aptos_framework::coin::{destroy_mint_cap, destroy_burn_cap};

    #[test_only]
    const PAYLOAD: vector<u8> = vector[1, 2, 3];
    #[test_only]
    const SALT: vector<u8> = b"salt_1";
    #[test_only]
    const SALT_2: vector<u8> = b"salt_2";
    #[test_only]
    const ERROR_TYPE: vector<u8> = b"MoveAbort";
    #[test_only]
    const ABORT_LOCATION: vector<u8> = b"abort_location";
    #[test_only]
    const ERROR_CODE: u64 = 10;
    #[test_only]
    const TIMELOCK_SECS: u64 = 3600;
    

    #[test_only]
    fun execution_error(): ExecutionError {
        ExecutionError {
            abort_location: utf8(ABORT_LOCATION),
            error_type: utf8(ERROR_TYPE),
            error_code: ERROR_CODE,
        }
    }

    #[test_only]
    fun setup(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        let (burn, mint) = aptos_coin::initialize_for_test(framework);
        destroy_mint_cap(mint);
        destroy_burn_cap(burn);
    }

    /// Get a signer for the timelock account using its stored SignerCapability.
    /// Used in tests to simulate the VM invoking self-governance entry functions.
    #[test_only]
    fun get_timelock_signer(timelock_account: address): signer acquires TimelockAccount {
        account::create_signer_with_capability(
            borrow_global<TimelockAccount>(timelock_account).signer_cap.borrow()
        )
    }

    // --- Creation tests ---

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create(framework: &signer, creator: &signer) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
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
        create(creator_1, vector[address_of(creator_2)], vector[address_of(executor_1)], TIMELOCK_SECS);
        assert!(is_creator(address_of(creator_1), timelock_addr), 0);
        assert!(is_creator(address_of(creator_2), timelock_addr), 1);
        assert!(is_executor(address_of(executor_1), timelock_addr), 2);
        // creator_1 is not in executors (executor list is non-empty), so is_executor returns false.
        assert!(!is_executor(address_of(creator_1), timelock_addr), 3);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x10005, location = Self)]
    public entry fun test_create_with_no_creators_fails(framework: &signer, creator: &signer) {
        setup(framework);
        create_account(address_of(creator));
        let (timelock_signer, signer_cap) = create_timelock_account(creator);
        create_timelock_account_internal(
            &timelock_signer,
            vector[],
            vector[],
            TIMELOCK_SECS,
            option::some(signer_cap),
        );
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
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        let tx = get_transaction(timelock_addr, SALT);
        assert!(tx.creator == address_of(creator), 0);
        assert!(!tx.executed, 1);
        assert!(tx.salt == SALT, 2);
    }

    #[test(framework = @0x1, creator = @0x123)]
    #[expected_failure(abort_code = 0x8000B, location = Self)]
    public entry fun test_create_duplicate_salt_fails(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        // Same salt — must fail.
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_create_same_payload_different_salt(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        // Different salt — must succeed.
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT_2);
    }

    #[test(framework = @0x1, creator = @0x123, non_creator = @0x999)]
    #[expected_failure(abort_code = 0x507D3, location = Self)]
    public entry fun test_non_creator_cannot_propose(
        framework: &signer,
        creator: &signer,
        non_creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
        // non_creator tries to propose — must fail with ENOT_CREATOR (error::permission_denied(2003) = 0x507D3).
        create_transaction(non_creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
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
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        cancel_transaction(creator, timelock_addr, SALT);
        let tx = get_transaction(timelock_addr, SALT);
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
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD,TIMELOCK_SECS, SALT);
        cancel_transaction(executor, timelock_addr, SALT);
        let tx = get_transaction(timelock_addr, SALT);
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
        create(creator, vector[], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        cancel_transaction(creator, timelock_addr, SALT);
        let tx = get_transaction(timelock_addr, SALT);
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
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD,TIMELOCK_SECS, SALT);
        cancel_transaction(creator, timelock_addr, SALT);
        // Cancel again — must fail.
        cancel_transaction(creator, timelock_addr, SALT);
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
        create(creator, vector[], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        cancel_transaction(non_member, timelock_addr, SALT);
    }

    // --- Validation and execution tests ---

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_validate_and_execute_success(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS,SALT);

        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);

        assert!(can_be_executed(timelock_addr, SALT), 0);
        validate_timelock_transaction(executor, timelock_addr, PAYLOAD, SALT);
        successful_transaction_execution_cleanup(address_of(executor), timelock_addr, SALT, PAYLOAD);
        let tx = get_transaction(timelock_addr, SALT);
        assert!(tx.executed, 1);
        // Entry is kept for historical record.
        assert!(borrow_global<TimelockAccount>(timelock_addr).transactions.contains(SALT), 2);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    #[expected_failure(abort_code = 0x307DD, location = Self)]
    public entry fun test_validate_before_timelock_expires_fails(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        // No time advance — must fail with ETIMELOCK_NOT_EXPIRED (error::invalid_state(2013) = 0x307DD).
        validate_timelock_transaction(executor, timelock_addr, PAYLOAD, SALT);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_creator_can_execute_when_executors_empty(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        // No executors provided.
        create(creator, vector[], vector[], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        validate_timelock_transaction(creator, timelock_addr, PAYLOAD, SALT);
        successful_transaction_execution_cleanup(address_of(creator), timelock_addr, SALT, PAYLOAD);
        let tx = get_transaction(timelock_addr, SALT);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_failed_execution_marks_executed(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        failed_transaction_execution_cleanup(
            address_of(executor), timelock_addr, SALT, PAYLOAD, execution_error(),
        );
        let tx = get_transaction(timelock_addr, SALT);
        assert!(tx.executed, 0);
    }

    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_multiple_transactions_independent_order(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT);
        create_transaction(creator, timelock_addr, PAYLOAD, TIMELOCK_SECS, SALT_2);

        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);

        // Execute SALT_2 before SALT — non-sequential execution is allowed.
        assert!(can_be_executed(timelock_addr, SALT_2), 0);
        validate_timelock_transaction(executor, timelock_addr, PAYLOAD, SALT_2);
        successful_transaction_execution_cleanup(address_of(executor), timelock_addr, SALT_2, PAYLOAD);
        assert!(get_transaction(timelock_addr, SALT_2).executed, 1);

        // SALT is still executable.
        assert!(can_be_executed(timelock_addr, SALT), 2);
    }

    // --- Self-governance tests ---

    /// Full end-to-end test for a self-governance proposal.
    ///
    /// Flow:
    ///   1. Creator proposes a transaction whose payload encodes the call to
    ///      update_num_seconds_execute with a new delay value.
    ///   2. Timelock period elapses.
    ///   3. Executor validates the transaction (VM prologue simulation).
    ///   4. VM executes the encoded entry function using the timelock account's signer.
    ///   5. VM calls the successful cleanup.
    ///   6. Verify the delay changed and the transaction is permanently recorded as executed.
    #[test(framework = @0x1, creator = @0x123, executor = @0x124)]
    public entry fun test_update_num_seconds_execute(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);

        // Build the transaction payload. In production this is a BCS-encoded EntryFunction
        // (module address + name + function name + type args + serialized args). Here we
        // encode the single u64 argument so the payload is realistic and self-describing.
        let new_delay: u64 = 7200;
        let payload = to_bytes(&new_delay);
        let salt = b"update_delay_1";

        // --- Step 1: Creator proposes the governance transaction ---
        create_transaction(creator, timelock_addr, payload, TIMELOCK_SECS, salt);
        // The delay must not have changed yet.
        assert!(min_num_seconds_execute(timelock_addr) == TIMELOCK_SECS, 0);
        assert!(!get_transaction(timelock_addr, salt).executed, 1);

        // --- Step 2: Timelock period elapses ---
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        assert!(can_be_executed(timelock_addr, salt), 2);

        // --- Step 3: Executor submits the transaction (VM prologue) ---
        validate_timelock_transaction(executor, timelock_addr, payload, salt);

        // --- Step 4: VM executes the encoded function using the timelock account's signer ---
        // The VM would decode the EntryFunction payload and call update_num_seconds_execute
        // with the timelock account as signer. We simulate that directly here.
        let timelock_signer = get_timelock_signer(timelock_addr);
        update_min_num_seconds_execute(&timelock_signer, new_delay);

        // --- Step 5: VM calls post-execution cleanup ---
        successful_transaction_execution_cleanup(address_of(executor), timelock_addr, salt, payload);

        // --- Step 6: Verify outcome ---
        assert!(min_num_seconds_execute(timelock_addr) == new_delay, 3);
        // Transaction is permanently recorded as executed in the table.
        assert!(get_transaction(timelock_addr, salt).executed, 4);
        assert!(borrow_global<TimelockAccount>(timelock_addr).transactions.contains(salt), 5);
    }

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_update_num_seconds_execute_custom_payload(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
        
        // BCS-encoded EntryFunction payload for:
        //   0x1::timelock::update_min_num_seconds_execute(<timelock_signer>, 7200)
        // Layout: module_addr (32B) | module_name | func_name | ty_args_count | args_count | arg
        let new_min_num_seconds: u64 = 7200;
        let update_time_payload = to_bytes(&@aptos_framework);
        update_time_payload.append(to_bytes(&b"timelock"));
        update_time_payload.append(to_bytes(&b"update_min_num_seconds_execute"));
        update_time_payload.push_back(0u8); // 0 type arguments
        update_time_payload.push_back(1u8); // 1 argument
        update_time_payload.append(to_bytes(&to_bytes(&new_min_num_seconds))); // BCS(7200u64) wrapped as vector<u8>
        create_transaction(creator, timelock_addr, update_time_payload, TIMELOCK_SECS, SALT);
        timestamp::fast_forward_seconds(TIMELOCK_SECS + 1);
        validate_timelock_transaction(creator, timelock_addr, update_time_payload, SALT);
        successful_transaction_execution_cleanup(address_of(creator), timelock_addr, SALT, update_time_payload);

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
        create(creator_1, vector[], vector[], TIMELOCK_SECS);
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
        create(creator, vector[], vector[], TIMELOCK_SECS);
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
        create(creator, vector[], vector[address_of(executor_1)], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        add_executors(&timelock_signer, vector[address_of(executor_2)]);
        assert!(is_executor(address_of(executor_2), timelock_addr), 0);
        remove_executors(&timelock_signer, vector[address_of(executor_1)]);
        assert!(!is_executor(address_of(executor_1), timelock_addr), 1);
        // After removing executor_1, executor_2 is still an executor.
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
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        let timelock_signer = get_timelock_signer(timelock_addr);
        // Remove the only executor — now creator should be able to execute.
        remove_executors(&timelock_signer, vector[address_of(executor)]);
        assert!(is_executor(address_of(creator), timelock_addr), 0);
        assert!(!is_executor(address_of(executor), timelock_addr), 1);
    }
}
