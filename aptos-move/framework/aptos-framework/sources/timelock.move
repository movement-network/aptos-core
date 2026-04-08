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
    use aptos_framework::account::{Self, SignerCapability, new_event_handle, create_resource_address};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event::{EventHandle, emit_event, emit};
    use aptos_framework::timestamp::now_seconds;
    use aptos_std::table::{Self, Table};
    use std::bcs::to_bytes;
    use std::error;
    use std::features;
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
    const EACCOUNT_NOT_TIMELOCK: u64 = 2002;
    /// The caller is not a creator of the timelock account.
    const ENOT_CREATOR: u64 = 2003;
    /// The caller is not an executor of the timelock account (or a creator when executors is empty).
    const ENOT_EXECUTOR: u64 = 2004;
    /// Transaction payload cannot be empty.
    const EPAYLOAD_CANNOT_BE_EMPTY: u64 = 4;
    /// Timelock account must have at least one creator.
    const ENOT_ENOUGH_CREATORS: u64 = 5;
    /// Transaction with the specified salt was not found.
    const ETRANSACTION_NOT_FOUND: u64 = 2006;
    /// Provided payload does not match the payload stored on chain for this transaction.
    const EPAYLOAD_DOES_NOT_MATCH: u64 = 2007;
    /// The timelock period has not elapsed yet.
    const ETIMELOCK_NOT_EXPIRED: u64 = 2008;
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
        // Seconds that must elapse after proposal before a transaction can be executed.
        num_seconds_execute: u64,
        // Map from salt to transaction. Entries are never deleted; executed/canceled
        // transactions are kept with executed = true for historical record.
        transactions: Table<vector<u8>, TimelockTransaction>,
        // Signer capability for the resource account.
        signer_cap: Option<SignerCapability>,

        // Event handles (legacy pattern kept for migration compatibility).
        add_creators_events: EventHandle<AddCreatorsEvent>,
        remove_creators_events: EventHandle<RemoveCreatorsEvent>,
        add_executors_events: EventHandle<AddExecutorsEvent>,
        remove_executors_events: EventHandle<RemoveExecutorsEvent>,
        update_num_seconds_execute_events: EventHandle<UpdateNumSecondsExecuteEvent>,
        create_transaction_events: EventHandle<CreateTransactionEvent>,
        cancel_transaction_events: EventHandle<CancelTransactionEvent>,
        execute_transaction_events: EventHandle<TransactionExecutionSucceededEvent>,
        transaction_execution_failed_events: EventHandle<TransactionExecutionFailedEvent>,
    }

    /// A transaction proposed for timelock execution.
    struct TimelockTransaction has copy, drop, store {
        // Full transaction payload. Can be None if only a hash is stored off chain.
        payload: Option<vector<u8>>,
        // The creator who proposed this transaction.
        creator: address,
        // Unix timestamp (seconds) when this transaction was proposed.
        creation_time_secs: u64,
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

    struct AddCreatorsEvent has drop, store {
        creators_added: vector<address>,
    }

    #[event]
    struct AddCreators has drop, store {
        timelock_account: address,
        creators_added: vector<address>,
    }

    struct RemoveCreatorsEvent has drop, store {
        creators_removed: vector<address>,
    }

    #[event]
    struct RemoveCreators has drop, store {
        timelock_account: address,
        creators_removed: vector<address>,
    }

    struct AddExecutorsEvent has drop, store {
        executors_added: vector<address>,
    }

    #[event]
    struct AddExecutors has drop, store {
        timelock_account: address,
        executors_added: vector<address>,
    }

    struct RemoveExecutorsEvent has drop, store {
        executors_removed: vector<address>,
    }

    #[event]
    struct RemoveExecutors has drop, store {
        timelock_account: address,
        executors_removed: vector<address>,
    }

    struct UpdateNumSecondsExecuteEvent has drop, store {
        old_num_seconds_execute: u64,
        new_num_seconds_execute: u64,
    }

    #[event]
    struct UpdateNumSecondsExecute has drop, store {
        timelock_account: address,
        old_num_seconds_execute: u64,
        new_num_seconds_execute: u64,
    }

    struct CreateTransactionEvent has drop, store {
        creator: address,
        salt: vector<u8>,
        transaction: TimelockTransaction,
    }

    #[event]
    struct CreateTransaction has drop, store {
        timelock_account: address,
        creator: address,
        salt: vector<u8>,
        transaction: TimelockTransaction,
    }

    struct CancelTransactionEvent has drop, store {
        actor: address,
        salt: vector<u8>,
    }

    #[event]
    struct CancelTransaction has drop, store {
        timelock_account: address,
        actor: address,
        salt: vector<u8>,
    }

    struct TransactionExecutionSucceededEvent has drop, store {
        executor: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
    }

    #[event]
    struct TransactionExecutionSucceeded has drop, store {
        timelock_account: address,
        executor: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
    }

    struct TransactionExecutionFailedEvent has drop, store {
        executor: address,
        salt: vector<u8>,
        transaction_payload: vector<u8>,
        execution_error: ExecutionError,
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
    /// Return the timelock delay in seconds.
    public fun num_seconds_execute(timelock_account: address): u64 acquires TimelockAccount {
        borrow_global<TimelockAccount>(timelock_account).num_seconds_execute
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
        !tx.executed && now_seconds() >= tx.creation_time_secs + timelock.num_seconds_execute
    }

    #[view]
    /// Return the predicted address for the next timelock account created by the given creator.
    public fun get_next_timelock_account_address(creator: address): address {
        let owner_nonce = account::get_sequence_number(creator);
        create_resource_address(&creator, create_timelock_account_seed(to_bytes(&owner_nonce)))
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
        num_seconds_execute: u64,
        signer_cap: Option<SignerCapability>,
    ) {
        let timelock_address = address_of(timelock_account);
        assert!(
            creators.length() >= 1,
            error::invalid_argument(ENOT_ENOUGH_CREATORS),
        );
        validate_members(&creators, timelock_address, EDUPLICATE_CREATOR);
        validate_members(&executors, timelock_address, EDUPLICATE_EXECUTOR);
        assert!(num_seconds_execute > 360, error::invalid_argument(ENUMBER_SECONDS_TOO_SMALL));

        move_to(timelock_account, TimelockAccount {
            creators,
            executors,
            num_seconds_execute,
            transactions: table::new<vector<u8>, TimelockTransaction>(),
            signer_cap,
            add_creators_events: new_event_handle<AddCreatorsEvent>(timelock_account),
            remove_creators_events: new_event_handle<RemoveCreatorsEvent>(timelock_account),
            add_executors_events: new_event_handle<AddExecutorsEvent>(timelock_account),
            remove_executors_events: new_event_handle<RemoveExecutorsEvent>(timelock_account),
            update_num_seconds_execute_events: new_event_handle<UpdateNumSecondsExecuteEvent>(timelock_account),
            create_transaction_events: new_event_handle<CreateTransactionEvent>(timelock_account),
            cancel_transaction_events: new_event_handle<CancelTransactionEvent>(timelock_account),
            execute_transaction_events: new_event_handle<TransactionExecutionSucceededEvent>(timelock_account),
            transaction_execution_failed_events: new_event_handle<TransactionExecutionFailedEvent>(timelock_account),
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
        if (features::module_event_migration_enabled()) {
            emit(AddCreators { timelock_account: timelock_address, creators_added });
        } else {
            emit_event(&mut timelock.add_creators_events, AddCreatorsEvent { creators_added });
        };
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
            if (features::module_event_migration_enabled()) {
                emit(RemoveCreators { timelock_account: timelock_address, creators_removed });
            } else {
                emit_event(&mut timelock.remove_creators_events, RemoveCreatorsEvent { creators_removed });
            };
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
        if (features::module_event_migration_enabled()) {
            emit(AddExecutors { timelock_account: timelock_address, executors_added });
        } else {
            emit_event(&mut timelock.add_executors_events, AddExecutorsEvent { executors_added });
        };
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
            if (features::module_event_migration_enabled()) {
                emit(RemoveExecutors { timelock_account: timelock_address, executors_removed });
            } else {
                emit_event(&mut timelock.remove_executors_events, RemoveExecutorsEvent { executors_removed });
            };
        };
    }

    /// Update the timelock delay. The new value takes effect immediately for future proposals.
    /// Existing pending transactions are not affected.
    /// Can only be invoked by the timelock account itself via the proposal flow.
    entry fun update_num_seconds_execute(
        timelock_account: &signer,
        new_num_seconds_execute: u64,
    ) acquires TimelockAccount {
        let timelock_address = address_of(timelock_account);
        assert_timelock_account_exists(timelock_address);
        let timelock = borrow_global_mut<TimelockAccount>(timelock_address);
        let old_num_seconds_execute = timelock.num_seconds_execute;
        timelock.num_seconds_execute = new_num_seconds_execute;
        if (features::module_event_migration_enabled()) {
            emit(UpdateNumSecondsExecute {
                timelock_account: timelock_address,
                old_num_seconds_execute,
                new_num_seconds_execute,
            });
        } else {
            emit_event(
                &mut timelock.update_num_seconds_execute_events,
                UpdateNumSecondsExecuteEvent { old_num_seconds_execute, new_num_seconds_execute },
            );
        };
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

        let transaction = TimelockTransaction {
            payload: option::some(payload),
            creator: creator_addr,
            creation_time_secs: now_seconds(),
            salt,
            executed: false,
        };
        timelock.transactions.add(salt, transaction);

        if (features::module_event_migration_enabled()) {
            emit(CreateTransaction { timelock_account, creator: creator_addr, salt, transaction });
        } else {
            emit_event(
                &mut timelock.create_transaction_events,
                CreateTransactionEvent { creator: creator_addr, salt, transaction },
            );
        };
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

        if (features::module_event_migration_enabled()) {
            emit(CancelTransaction { timelock_account, actor: actor_addr, salt });
        } else {
            emit_event(
                &mut timelock.cancel_transaction_events,
                CancelTransactionEvent { actor: actor_addr, salt },
            );
        };
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
            now_seconds() >= transaction.creation_time_secs + timelock.num_seconds_execute,
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
        if (features::module_event_migration_enabled()) {
            emit(TransactionExecutionSucceeded { timelock_account, executor, salt, transaction_payload });
        } else {
            emit_event(
                &mut timelock.execute_transaction_events,
                TransactionExecutionSucceededEvent { executor, salt, transaction_payload },
            );
        };
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
        if (features::module_event_migration_enabled()) {
            emit(TransactionExecutionFailed {
                timelock_account, executor, salt, transaction_payload, execution_error,
            });
        } else {
            emit_event(
                &mut timelock.transaction_execution_failed_events,
                TransactionExecutionFailedEvent { executor, salt, transaction_payload, execution_error },
            );
        };
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
        assert!(num_seconds_execute(timelock_addr) == TIMELOCK_SECS, 2);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
        // Same salt — must fail.
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
        // Different salt — must succeed.
        create_transaction(creator, timelock_addr, PAYLOAD, SALT_2);
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
        create_transaction(non_creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);

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
    #[expected_failure(abort_code = 0x307D8, location = Self)]
    public entry fun test_validate_before_timelock_expires_fails(
        framework: &signer,
        creator: &signer,
        executor: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[address_of(executor)], TIMELOCK_SECS);
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
        // No time advance — must fail with ETIMELOCK_NOT_EXPIRED (error::invalid_state(2008) = 0x307D8).
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
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
        create_transaction(creator, timelock_addr, PAYLOAD, SALT);
        create_transaction(creator, timelock_addr, PAYLOAD, SALT_2);

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

    #[test(framework = @0x1, creator = @0x123)]
    public entry fun test_update_num_seconds_execute(
        framework: &signer,
        creator: &signer,
    ) acquires TimelockAccount {
        setup(framework);
        create_account(address_of(creator));
        let timelock_addr = get_next_timelock_account_address(address_of(creator));
        create(creator, vector[], vector[], TIMELOCK_SECS);
        // Simulate the timelock account calling itself (normally via VM after proposal executes).
        let timelock_signer = get_timelock_signer(timelock_addr);
        update_num_seconds_execute(&timelock_signer, 7200);
        assert!(num_seconds_execute(timelock_addr) == 7200, 0);
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
