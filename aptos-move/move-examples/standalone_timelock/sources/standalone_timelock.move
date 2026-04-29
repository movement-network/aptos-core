/// A standalone timelock whose module address is the timelock account.
///
/// This package is meant to be published under a resource account. During `init_module`, it
/// retrieves that resource account's signer capability from `@deployer` and stores exactly one
/// timelock state resource at `@standalone_timelock`. There is no factory and no per-timelock
/// object/resource-account layer: deploying this package mints one timelock.
///
/// Execution follows the same authority pattern as `aptos_governance`: a creator proposes the
/// hash of a future resolution script, then, after the delay, an authorized executor submits that
/// exact script. The script calls `resolve`, receives the `@standalone_timelock` signer, and can
/// then perform arbitrary Move calls as this timelock.
///
/// This is not a VM transaction payload type. Unlike framework `timelock`, a failed target call
/// rolls back the whole transaction, including the executed flag. That is the same atomic script
/// behavior used by governance resolution.
module standalone_timelock::standalone_timelock {
    use std::error;
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::resource_account;
    use aptos_framework::timestamp;
    use aptos_framework::transaction_context;
    use aptos_std::aptos_hash::keccak256;
    use aptos_std::table::{Self, Table};

    const SCRIPT_HASH_LENGTH: u64 = 32;
    const SALT_LENGTH: u64 = 32;
    const MAX_METADATA_BYTES: u64 = 256;
    const MIN_DELAY_FLOOR_SECS: u64 = 360;
    const DEFAULT_MIN_DELAY_SECS: u64 = 3600;

    /// Creator list cannot contain duplicate addresses.
    const EDUPLICATE_CREATOR: u64 = 1;
    /// Executor list cannot contain duplicate addresses.
    const EDUPLICATE_EXECUTOR: u64 = 2;
    /// Standalone timelock state has not been initialized.
    const ETIMELOCK_NOT_INITIALIZED: u64 = 3;
    /// Caller is not a creator.
    const ENOT_CREATOR: u64 = 4;
    /// Caller is not an executor, or a creator when the executor list is empty.
    const ENOT_EXECUTOR: u64 = 5;
    /// Timelock must have at least one creator.
    const ENOT_ENOUGH_CREATORS: u64 = 6;
    /// Transaction with the specified hash was not found.
    const ETRANSACTION_NOT_FOUND: u64 = 7;
    /// The timelock delay has not elapsed.
    const ETIMELOCK_NOT_EXPIRED: u64 = 8;
    /// Transaction has already been executed or canceled.
    const ETRANSACTION_ALREADY_EXECUTED: u64 = 9;
    /// The timelock account itself cannot be a creator or executor.
    const ESELF_CANNOT_BE_MEMBER: u64 = 10;
    /// A transaction with this execution hash and salt already exists.
    const EDUPLICATE_TRANSACTION: u64 = 11;
    /// Removing these creators would leave the timelock account with zero creators.
    const EWOULD_REMOVE_ALL_CREATORS: u64 = 12;
    /// Caller is neither a creator nor an executor.
    const ENOT_CREATOR_OR_EXECUTOR: u64 = 13;
    /// Delay is too small.
    const EDELAY_TOO_SMALL: u64 = 14;
    /// Hashes and salts must be exactly 32 bytes.
    const EINVALID_BYTES_LENGTH: u64 = 15;
    /// Metadata fields are intentionally bounded.
    const EMETADATA_TOO_LONG: u64 = 16;
    /// Current transaction script hash does not match the proposed execution hash.
    const EEXECUTION_HASH_NOT_MATCHING: u64 = 17;
    /// One-time initialize has already completed.
    const EINITIALIZE_ALREADY_COMPLETE: u64 = 18;
    /// Only the configured deployer can perform initialize.
    const ENOT_DEPLOYER: u64 = 19;
    /// The package was not initialized at its own named address.
    const EWRONG_MODULE_SIGNER: u64 = 20;
    /// Timelock operations require initialize to be complete.
    const EINITIALIZE_NOT_COMPLETE: u64 = 21;

    /// Singleton state for the deployed timelock.
    struct Timelock has key {
        creators: vector<address>,
        executors: vector<address>,
        min_delay_secs: u64,
        transactions: Table<vector<u8>, TimelockTransaction>,
        signer_cap: SignerCapability,
        initialize_complete: bool,
    }

    /// A pending or historical timelock transaction.
    ///
    /// `execution_hash` is the hash of the authorized resolution script and is consumed once.
    struct TimelockTransaction has copy, drop, store {
        execution_hash: vector<u8>,
        creator: address,
        creation_time_secs: u64,
        delay_secs: u64,
        salt: vector<u8>,
        executed: bool,
        metadata_location: vector<u8>,
        metadata_hash: vector<u8>,
    }

    #[event]
    struct Initialize has drop, store {
        timelock: address,
        deployer: address,
        min_delay_secs: u64,
    }

    #[event]
    struct Bootstrap has drop, store {
        timelock: address,
        creators: vector<address>,
        executors: vector<address>,
        min_delay_secs: u64,
    }

    #[event]
    struct CreateTransaction has drop, store {
        timelock: address,
        creator: address,
        transaction_hash: vector<u8>,
        transaction: TimelockTransaction,
    }

    #[event]
    struct CancelTransaction has drop, store {
        timelock: address,
        actor: address,
        transaction_hash: vector<u8>,
    }

    #[event]
    struct ResolveTransaction has drop, store {
        timelock: address,
        executor: address,
        transaction_hash: vector<u8>,
        execution_hash: vector<u8>,
    }

    #[event]
    struct AddCreators has drop, store {
        timelock: address,
        creators_added: vector<address>,
    }

    #[event]
    struct RemoveCreators has drop, store {
        timelock: address,
        creators_removed: vector<address>,
    }

    #[event]
    struct AddExecutors has drop, store {
        timelock: address,
        executors_added: vector<address>,
    }

    #[event]
    struct RemoveExecutors has drop, store {
        timelock: address,
        executors_removed: vector<address>,
    }

    #[event]
    struct UpdateMinDelay has drop, store {
        timelock: address,
        old_min_delay_secs: u64,
        new_min_delay_secs: u64,
    }

    fun init_module(standalone_timelock: &signer) {
        assert!(
            signer::address_of(standalone_timelock) == @standalone_timelock,
            error::invalid_argument(EWRONG_MODULE_SIGNER),
        );

        let signer_cap = resource_account::retrieve_resource_account_cap(standalone_timelock, @deployer);
        if (!coin::is_account_registered<AptosCoin>(@standalone_timelock)) {
            coin::register<AptosCoin>(standalone_timelock);
        };

        let creators = vector[@deployer];
        move_to(standalone_timelock, Timelock {
            creators,
            executors: vector[],
            min_delay_secs: DEFAULT_MIN_DELAY_SECS,
            transactions: table::new<vector<u8>, TimelockTransaction>(),
            signer_cap,
            initialize_complete: false,
        });

        event::emit(Initialize {
            timelock: @standalone_timelock,
            deployer: @deployer,
            min_delay_secs: DEFAULT_MIN_DELAY_SECS,
        });
    }

    #[view]
    public fun account_address(): address {
        @standalone_timelock
    }

    #[view]
    public fun is_initialized(): bool {
        exists<Timelock>(@standalone_timelock)
    }

    #[view]
    public fun initialize_complete(): bool acquires Timelock {
        borrow_global<Timelock>(@standalone_timelock).initialize_complete
    }

    #[view]
    public fun creators(): vector<address> acquires Timelock {
        borrow_global<Timelock>(@standalone_timelock).creators
    }

    #[view]
    public fun executors(): vector<address> acquires Timelock {
        borrow_global<Timelock>(@standalone_timelock).executors
    }

    #[view]
    public fun min_delay_secs(): u64 acquires Timelock {
        borrow_global<Timelock>(@standalone_timelock).min_delay_secs
    }

    #[view]
    public fun is_creator(addr: address): bool acquires Timelock {
        borrow_global<Timelock>(@standalone_timelock).creators.contains(&addr)
    }

    #[view]
    public fun is_executor(addr: address): bool acquires Timelock {
        let timelock = borrow_global<Timelock>(@standalone_timelock);
        if (timelock.executors.is_empty()) {
            timelock.creators.contains(&addr)
        } else {
            timelock.executors.contains(&addr)
        }
    }

    #[view]
    public fun get_transaction(transaction_hash: vector<u8>): TimelockTransaction acquires Timelock {
        let timelock = borrow_global<Timelock>(@standalone_timelock);
        assert!(
            timelock.transactions.contains(copy transaction_hash),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        *timelock.transactions.borrow(transaction_hash)
    }

    #[view]
    public fun can_be_executed(transaction_hash: vector<u8>): bool acquires Timelock {
        let timelock = borrow_global<Timelock>(@standalone_timelock);
        if (!timelock.transactions.contains(copy transaction_hash)) {
            return false
        };

        let transaction = timelock.transactions.borrow(transaction_hash);
        !transaction.executed
            && timestamp::now_seconds() >= transaction.creation_time_secs + transaction.delay_secs
    }

    public fun get_transaction_hash(execution_hash: vector<u8>, salt: vector<u8>): vector<u8> {
        let bytes = execution_hash;
        bytes.append(salt);
        keccak256(bytes)
    }

    /// One-time constructor-like setup for launch configuration.
    ///
    /// `init_module` cannot receive arguments, so deployment starts with `@deployer` as the sole
    /// creator and a default delay. The deployer can call this exactly once to set the intended
    /// creators, executors, and minimum delay before normal operation begins.
    public entry fun initialize(
        deployer: &signer,
        creators: vector<address>,
        executors: vector<address>,
        min_delay_secs: u64,
    ) acquires Timelock {
        assert!(signer::address_of(deployer) == @deployer, error::permission_denied(ENOT_DEPLOYER));
        assert_delay(min_delay_secs);
        assert!(creators.length() >= 1, error::invalid_argument(ENOT_ENOUGH_CREATORS));
        validate_members(&creators, @standalone_timelock, EDUPLICATE_CREATOR);
        validate_members(&executors, @standalone_timelock, EDUPLICATE_EXECUTOR);

        let event_creators = copy creators;
        let event_executors = copy executors;
        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        assert!(!timelock.initialize_complete, error::invalid_state(EINITIALIZE_ALREADY_COMPLETE));
        timelock.creators = creators;
        timelock.executors = executors;
        timelock.min_delay_secs = min_delay_secs;
        timelock.initialize_complete = true;

        event::emit(Initialize {
            timelock: @standalone_timelock,
            creators: event_creators,
            executors: event_executors,
            min_delay_secs,
        });
    }

    /// Add new creators. This must be called by a resolution script after `resolve`.
    public entry fun add_creators(
        standalone_timelock: &signer,
        new_creators: vector<address>,
    ) acquires Timelock {
        assert_standalone_timelock_signer(standalone_timelock);
        let creators_added = copy new_creators;
        validate_members(&new_creators, @standalone_timelock, EDUPLICATE_CREATOR);

        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        timelock.creators.append(new_creators);
        validate_members(&timelock.creators, @standalone_timelock, EDUPLICATE_CREATOR);
        event::emit(AddCreators { timelock: @standalone_timelock, creators_added });
    }

    /// Remove creators. At least one creator must remain.
    public entry fun remove_creators(
        standalone_timelock: &signer,
        creators_to_remove: vector<address>,
    ) acquires Timelock {
        assert_standalone_timelock_signer(standalone_timelock);
        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
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
            event::emit(RemoveCreators { timelock: @standalone_timelock, creators_removed });
        };
    }

    /// Add new executors. This must be called by a resolution script after `resolve`.
    public entry fun add_executors(
        standalone_timelock: &signer,
        new_executors: vector<address>,
    ) acquires Timelock {
        assert_standalone_timelock_signer(standalone_timelock);
        let executors_added = copy new_executors;
        validate_members(&new_executors, @standalone_timelock, EDUPLICATE_EXECUTOR);

        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        timelock.executors.append(new_executors);
        validate_members(&timelock.executors, @standalone_timelock, EDUPLICATE_EXECUTOR);
        event::emit(AddExecutors { timelock: @standalone_timelock, executors_added });
    }

    /// Remove executors. An empty executor list means creators are executors.
    public entry fun remove_executors(
        standalone_timelock: &signer,
        executors_to_remove: vector<address>,
    ) acquires Timelock {
        assert_standalone_timelock_signer(standalone_timelock);
        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        let executors_removed = vector[];

        executors_to_remove.for_each_ref(|to_remove| {
            let (found, index) = timelock.executors.index_of(to_remove);
            if (found) {
                executors_removed.push_back(timelock.executors.swap_remove(index));
            }
        });

        if (!executors_removed.is_empty()) {
            event::emit(RemoveExecutors { timelock: @standalone_timelock, executors_removed });
        };
    }

    /// Update the minimum delay for future transactions.
    public entry fun update_min_delay(
        standalone_timelock: &signer,
        new_min_delay_secs: u64,
    ) acquires Timelock {
        assert_standalone_timelock_signer(standalone_timelock);
        assert_delay(new_min_delay_secs);

        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        let old_min_delay_secs = timelock.min_delay_secs;
        timelock.min_delay_secs = new_min_delay_secs;
        event::emit(UpdateMinDelay { timelock: @standalone_timelock, old_min_delay_secs, new_min_delay_secs });
    }

    /// Create a single-step transaction proposal.
    public entry fun create_transaction(
        creator: &signer,
        execution_hash: vector<u8>,
        delay_secs: u64,
        salt: vector<u8>,
        metadata_location: vector<u8>,
        metadata_hash: vector<u8>,
    ) acquires Timelock {
        create_transaction_internal(
            creator,
            execution_hash,
            delay_secs,
            salt,
            metadata_location,
            metadata_hash,
        );
    }

    /// Cancel a pending transaction. Creators and executors can cancel at any time.
    public entry fun cancel_transaction(
        actor: &signer,
        transaction_hash: vector<u8>,
    ) acquires Timelock {
        assert_initialize_complete();
        assert!(transaction_hash.length() == SCRIPT_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));
        let actor_addr = signer::address_of(actor);
        let actor_is_creator = is_creator(actor_addr);
        let actor_is_executor = is_executor(actor_addr);
        assert!(actor_is_creator || actor_is_executor, error::permission_denied(ENOT_CREATOR_OR_EXECUTOR));

        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        assert!(
            timelock.transactions.contains(copy transaction_hash),
            error::not_found(ETRANSACTION_NOT_FOUND),
        );
        let transaction = timelock.transactions.borrow_mut(copy transaction_hash);
        assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
        transaction.executed = true;
        event::emit(CancelTransaction { timelock: @standalone_timelock, actor: actor_addr, transaction_hash });
    }

    /// Resolve a single-step transaction and return the `@standalone_timelock` signer.
    ///
    /// The caller's transaction must be the exact script whose hash was proposed.
    public fun resolve(
        executor: &signer,
        transaction_hash: vector<u8>,
    ): signer acquires Timelock {
        resolve_internal(executor, transaction_hash)
    }

    fun create_transaction_internal(
        creator: &signer,
        execution_hash: vector<u8>,
        delay_secs: u64,
        salt: vector<u8>,
        metadata_location: vector<u8>,
        metadata_hash: vector<u8>,
    ) acquires Timelock {
        assert_initialize_complete();
        assert_is_creator(creator);
        assert_execution_hash(&execution_hash);
        assert!(salt.length() == SALT_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));
        assert!(metadata_location.length() <= MAX_METADATA_BYTES, error::invalid_argument(EMETADATA_TOO_LONG));
        assert!(metadata_hash.length() <= MAX_METADATA_BYTES, error::invalid_argument(EMETADATA_TOO_LONG));

        let transaction_hash = get_transaction_hash(copy execution_hash, copy salt);
        let creator_addr = signer::address_of(creator);
        let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
        assert!(delay_secs >= timelock.min_delay_secs, error::invalid_argument(EDELAY_TOO_SMALL));
        assert!(
            !timelock.transactions.contains(copy transaction_hash),
            error::already_exists(EDUPLICATE_TRANSACTION),
        );

        let transaction = TimelockTransaction {
            execution_hash,
            creator: creator_addr,
            creation_time_secs: timestamp::now_seconds(),
            delay_secs,
            salt,
            executed: false,
            metadata_location,
            metadata_hash,
        };
        timelock.transactions.add(copy transaction_hash, copy transaction);
        event::emit(CreateTransaction {
            timelock: @standalone_timelock,
            creator: creator_addr,
            transaction_hash,
            transaction,
        });
    }

    fun resolve_internal(
        executor: &signer,
        transaction_hash: vector<u8>,
    ): signer acquires Timelock {
        assert_initialize_complete();
        assert_is_executor(executor);
        assert!(transaction_hash.length() == SCRIPT_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));

        let executor_addr = signer::address_of(executor);
        let current_execution_hash;
        {
            let timelock = borrow_global_mut<Timelock>(@standalone_timelock);
            assert!(
                timelock.transactions.contains(copy transaction_hash),
                error::not_found(ETRANSACTION_NOT_FOUND),
            );
            let transaction = timelock.transactions.borrow_mut(copy transaction_hash);
            assert!(!transaction.executed, error::invalid_state(ETRANSACTION_ALREADY_EXECUTED));
            assert!(
                timestamp::now_seconds() >= transaction.creation_time_secs + transaction.delay_secs,
                error::invalid_state(ETIMELOCK_NOT_EXPIRED),
            );
            assert!(
                transaction_context::get_script_hash() == transaction.execution_hash,
                error::invalid_argument(EEXECUTION_HASH_NOT_MATCHING),
            );

            current_execution_hash = transaction.execution_hash;
            transaction.executed = true;
        };

        event::emit(ResolveTransaction {
            timelock: @standalone_timelock,
            executor: executor_addr,
            transaction_hash,
            execution_hash: current_execution_hash,
        });

        let timelock = borrow_global<Timelock>(@standalone_timelock);
        account::create_signer_with_capability(&timelock.signer_cap)
    }

    inline fun assert_initialized() {
        assert!(exists<Timelock>(@standalone_timelock), error::invalid_state(ETIMELOCK_NOT_INITIALIZED));
    }

    inline fun assert_initialize_complete() {
        assert_initialized();
        assert!(
            borrow_global<Timelock>(@standalone_timelock).initialize_complete,
            error::invalid_state(EINITIALIZE_NOT_COMPLETE),
        );
    }

    inline fun assert_standalone_timelock_signer(standalone_timelock: &signer) {
        assert!(
            signer::address_of(standalone_timelock) == @standalone_timelock,
            error::permission_denied(ENOT_DEPLOYER),
        );
    }

    inline fun assert_is_creator(creator: &signer) {
        assert!(
            borrow_global<Timelock>(@standalone_timelock).creators.contains(&signer::address_of(creator)),
            error::permission_denied(ENOT_CREATOR),
        );
    }

    inline fun assert_is_executor(executor: &signer) {
        let timelock = borrow_global<Timelock>(@standalone_timelock);
        let executor_addr = signer::address_of(executor);
        let authorized = if (timelock.executors.is_empty()) {
            timelock.creators.contains(&executor_addr)
        } else {
            timelock.executors.contains(&executor_addr)
        };
        assert!(authorized, error::permission_denied(ENOT_EXECUTOR));
    }

    inline fun assert_delay(delay_secs: u64) {
        assert!(delay_secs > MIN_DELAY_FLOOR_SECS, error::invalid_argument(EDELAY_TOO_SMALL));
    }

    inline fun assert_execution_hash(execution_hash: &vector<u8>) {
        assert!(execution_hash.length() == SCRIPT_HASH_LENGTH, error::invalid_argument(EINVALID_BYTES_LENGTH));
    }

    fun validate_members(members: &vector<address>, timelock_address: address, duplicate_error: u64) {
        let distinct: vector<address> = vector[];
        members.for_each_ref(|member| {
            let member = *member;
            assert!(member != timelock_address, error::invalid_argument(ESELF_CANNOT_BE_MEMBER));
            let (found, _) = distinct.index_of(&member);
            assert!(!found, error::invalid_argument(duplicate_error));
            distinct.push_back(member);
        });
    }
}
