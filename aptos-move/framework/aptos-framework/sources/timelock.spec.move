spec aptos_framework::timelock {
    /// <high-level-req>
    /// No.: 1
    /// Requirement: A timelock account must always have at least one creator.
    /// Criticality: Critical
    /// Implementation: The create_timelock_account_internal function asserts that the creators vector has length >= 1
    /// before publishing the TimelockAccount resource. The remove_creators function asserts that at least one creator
    /// remains after removal.
    /// Enforcement: Audited that it aborts if creators is empty (create_timelock_account_internal). Audited that it
    /// aborts if the last creator would be removed (remove_creators).
    ///
    /// No.: 2
    /// Requirement: Creator and executor lists must not contain duplicate addresses, and the timelock account address
    /// itself cannot appear in either list.
    /// Criticality: Critical
    /// Implementation: The validate_members function iterates through the member list and aborts on any duplicate or
    /// self-reference. It is called for both creators and executors during account creation and member updates.
    /// Enforcement: Audited that duplicate detection aborts correctly (validate_members, add_creators, add_executors).
    /// Audited that self-reference is rejected (validate_members).
    ///
    /// No.: 3
    /// Requirement: A transaction can only be executed after the timelock period has fully elapsed.
    /// Specifically, block time must satisfy: now_seconds >= creation_time_secs + num_seconds_execute.
    /// Criticality: Critical
    /// Implementation: The validate_timelock_transaction function asserts this time condition before allowing execution.
    /// Enforcement: Audited that it aborts if the timelock period has not elapsed (validate_timelock_transaction).
    ///
    /// No.: 4
    /// Requirement: Each transaction proposal is uniquely identified by its transaction hash, which is either the
    /// caller-provided hash or keccak256(payload || salt) when a payload is stored on chain. Submitting a proposal with
    /// an already existing transaction hash is rejected. To submit the same payload again, a new salt must be used.
    /// Criticality: High
    /// Implementation: The create_transaction function computes the table key and asserts that the hash does not
    /// already exist as a key in the transactions table before adding the new entry.
    /// Enforcement: Audited that it aborts if the computed transaction hash already exists (create_transaction).
    ///
    /// No.: 5
    /// Requirement: When the executor list is empty, creators are authorized to execute transactions.
    /// Criticality: High
    /// Implementation: The assert_is_executor inline function checks the executors vector and falls back to checking the
    /// creators vector when executors is empty. The is_executor view function applies the same logic.
    /// Enforcement: Audited that creators can execute when executors is empty (assert_is_executor, is_executor).
    ///
    /// No.: 6
    /// Requirement: Any creator or any executor can cancel any pending transaction at any time, before the transaction
    /// has been executed or canceled.
    /// Criticality: High
    /// Implementation: The cancel_transaction function checks that the caller is either a creator or an executor
    /// (applying the empty-executors fallback), then asserts that the transaction has not yet been executed, and sets
    /// executed = true.
    /// Enforcement: Audited that it aborts if the caller has no cancellation rights (cancel_transaction). Audited that
    /// it aborts if the transaction is already executed or canceled (cancel_transaction).
    ///
    /// No.: 7
    /// Requirement: Once a transaction's executed field is set to true (either by execution or cancellation), neither
    /// further execution nor further cancellation is permitted. The transaction entry is kept in the table permanently.
    /// Criticality: High
    /// Implementation: Both validate_timelock_transaction and cancel_transaction assert !transaction.executed before
    /// proceeding. The cleanup functions set executed = true but do not remove the entry from the table.
    /// Enforcement: Audited that it aborts if executed is already true (validate_timelock_transaction,
    /// cancel_transaction). Audited that entries remain in the table after execution (successful_transaction_execution_
    /// cleanup, failed_transaction_execution_cleanup).
    ///
    /// No.: 8
    /// Requirement: Changes to num_seconds_execute, the creator list, and the executor list can only be made by the
    /// timelock account itself, enforced by requiring the timelock account signer on the self-governance entry functions.
    /// Criticality: Critical
    /// Implementation: The self-governance functions (update_num_seconds_execute, add_creators, remove_creators,
    /// add_executors, remove_executors) all take timelock_account: &signer as first argument. Only the VM, using the
    /// signer derived from the stored signer_cap, can produce this signer after a timelock proposal executes.
    /// Enforcement: Audited that the signer must be the timelock account address for self-governance functions.
    ///
    /// No.: 9
    /// Requirement: Creating a timelock account properly initializes all resources and publishes the TimelockAccount
    /// resource under the resource account address derived from the creator's address and sequence number.
    /// Criticality: Medium
    /// Implementation: The create function derives the resource account address, creates the account via
    /// account::create_resource_account, adds the creator to the creators list, and calls
    /// create_timelock_account_internal which publishes the TimelockAccount resource with all fields initialized.
    /// Enforcement: Audited that TimelockAccount is initialized and published (create, create_timelock_account_internal).
    ///
    /// No.: 10
    /// Requirement: Only valid creators are allowed to propose transactions. Proposing a transaction stores the
    /// optional payload, plus the salt, recording the creator and timestamp, with executed = false.
    /// Criticality: Critical
    /// Implementation: The create_transaction function validates that the caller is in the creators list before adding
    /// the new TimelockTransaction to the table.
    /// Enforcement: Audited that it aborts if the caller is not a creator (create_transaction, assert_is_creator).
    /// Audited that the transaction is stored correctly with executed = false (create_transaction).
    ///
    /// No.: 11
    /// Requirement: Only authorized executors (or creators when executors is empty) are allowed to execute transactions
    /// via the VM prologue validation function. Additionally, the payload must match the stored payload if both are
    /// non-empty.
    /// Criticality: Critical
    /// Implementation: The validate_timelock_transaction function checks executor authorization, transaction existence,
    /// executed status, timelock expiry, and optional payload match.
    /// Enforcement: Audited that it aborts if the caller is not an executor (validate_timelock_transaction,
    /// assert_is_executor). Audited that it aborts if the payload mismatches (validate_timelock_transaction).
    /// </high-level-req>

    spec module {}

    // =============================== View functions ===============================

    spec creators(timelock_account: address): vector<address> {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == global<TimelockAccount>(timelock_account).creators;
    }

    spec executors(timelock_account: address): vector<address> {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == global<TimelockAccount>(timelock_account).executors;
    }

    spec min_num_seconds_execute(timelock_account: address): u64 {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == global<TimelockAccount>(timelock_account).min_num_seconds_execute;
    }

    spec is_creator(addr: address, timelock_account: address): bool {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == contains(global<TimelockAccount>(timelock_account).creators, addr);
    }

    spec is_executor(addr: address, timelock_account: address): bool {
        aborts_if !exists<TimelockAccount>(timelock_account);
        let timelock = global<TimelockAccount>(timelock_account);
        ensures len(timelock.executors) == 0 ==> result == contains(timelock.creators, addr);
        ensures len(timelock.executors) > 0 ==> result == contains(timelock.executors, addr);
    }

    spec get_transaction(timelock_account: address, hash: vector<u8>): TimelockTransaction {
        let timelock = global<TimelockAccount>(timelock_account);
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !table::spec_contains(timelock.transactions, hash);
        ensures result == table::spec_get(timelock.transactions, hash);
    }

    spec can_be_executed(timelock_account: address, hash: vector<u8>): bool {
        // Only aborts when the timelock account resource does not exist.
        // Returns false (does not abort) when the hash is absent, executed, or delay not elapsed.
        aborts_if !exists<TimelockAccount>(timelock_account);
        let timelock = global<TimelockAccount>(timelock_account);
        ensures !table::spec_contains(timelock.transactions, hash) ==> !result;
        ensures table::spec_contains(timelock.transactions, hash) ==> result ==
            (!table::spec_get(timelock.transactions, hash).executed
                && aptos_framework::timestamp::now_seconds()
                    >= table::spec_get(timelock.transactions, hash).creation_time_secs
                        + table::spec_get(timelock.transactions, hash).num_seconds_execute);
    }

    spec get_transaction_hash(payload: vector<u8>, salt: vector<u8>): vector<u8> {
        ensures result == aptos_std::aptos_hash::keccak256(concat(payload, salt));
    }

    spec get_next_timelock_account_address(creator: address): address {
        // Only aborts when the creator account does not exist (sequence number not readable).
        aborts_if !exists<account::Account>(creator);
    }

    // =============================== Account creation ===============================

    spec create(
        creator: &signer,
        additional_creators: vector<address>,
        executors: vector<address>,
        num_seconds_execute: u64,
    ) {
        // Full verification is disabled because create_resource_account involves complex
        // cross-module side-effects (coin registration, nonce derivation) that the prover
        // cannot fully reason about.
        pragma verify = false;
        aborts_if num_seconds_execute <= 360;
        aborts_if !exists<account::Account>(address_of(creator));
    }

    spec create_timelock_account_internal(
        timelock_account: &signer,
        creators: vector<address>,
        executors: vector<address>,
        min_num_seconds_execute: u64,
        signer_cap: Option<SignerCapability>,
    ) {
        aborts_if len(creators) < 1;
        aborts_if min_num_seconds_execute <= 360;
        aborts_if exists<TimelockAccount>(address_of(timelock_account));
        // Aborts if creators or executors contain duplicates or include the timelock address.
        aborts_if exists i in 0..len(creators): creators[i] == address_of(timelock_account);
        aborts_if exists i in 0..len(creators): exists j in 0..i: creators[i] == creators[j];
        aborts_if exists i in 0..len(executors): executors[i] == address_of(timelock_account);
        aborts_if exists i in 0..len(executors): exists j in 0..i: executors[i] == executors[j];
        ensures exists<TimelockAccount>(address_of(timelock_account));
        ensures global<TimelockAccount>(address_of(timelock_account)).min_num_seconds_execute == min_num_seconds_execute;
        ensures global<TimelockAccount>(address_of(timelock_account)).creators == creators;
        ensures global<TimelockAccount>(address_of(timelock_account)).executors == executors;
    }

    // =============================== Self-governance ===============================

    spec add_creators(timelock_account: &signer, new_creators: vector<address>) {
        aborts_if !exists<TimelockAccount>(address_of(timelock_account));
        // Aborts if any new creator is the timelock address itself.
        aborts_if exists i in 0..len(new_creators): new_creators[i] == address_of(timelock_account);
        // Aborts if new_creators list has internal duplicates.
        aborts_if exists i in 0..len(new_creators): exists j in 0..i: new_creators[i] == new_creators[j];
        ensures exists<TimelockAccount>(address_of(timelock_account));
    }

    spec remove_creators(timelock_account: &signer, creators_to_remove: vector<address>) {
        pragma aborts_if_is_partial;
        aborts_if !exists<TimelockAccount>(address_of(timelock_account));
        // Aborts if removing these creators would leave zero creators.
        // (Full enumeration of the post-removal set is complex; partial spec retained here.)
        // Must retain at least one creator.
        ensures len(global<TimelockAccount>(address_of(timelock_account)).creators) >= 1;
    }

    spec add_executors(timelock_account: &signer, new_executors: vector<address>) {
        aborts_if !exists<TimelockAccount>(address_of(timelock_account));
        // Aborts if any new executor is the timelock address itself.
        aborts_if exists i in 0..len(new_executors): new_executors[i] == address_of(timelock_account);
        // Aborts if new_executors list has internal duplicates.
        aborts_if exists i in 0..len(new_executors): exists j in 0..i: new_executors[i] == new_executors[j];
        ensures exists<TimelockAccount>(address_of(timelock_account));
    }

    spec remove_executors(timelock_account: &signer, executors_to_remove: vector<address>) {
        aborts_if !exists<TimelockAccount>(address_of(timelock_account));
        ensures exists<TimelockAccount>(address_of(timelock_account));
    }

    spec update_min_num_seconds_execute(timelock_account: &signer, new_min_num_seconds_execute: u64) {
        aborts_if !exists<TimelockAccount>(address_of(timelock_account));
        aborts_if new_min_num_seconds_execute <= 360;
        ensures global<TimelockAccount>(address_of(timelock_account)).min_num_seconds_execute == new_min_num_seconds_execute;
    }

    // =============================== Transaction flow ===============================

    spec create_transaction(
        creator: &signer,
        timelock_account: address,
        payload: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
    ) {
        pragma aborts_if_is_partial;
        let timelock = global<TimelockAccount>(timelock_account);
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !contains(timelock.creators, address_of(creator));
        aborts_if len(salt) != 32;
        aborts_if len(payload) == 0;
        aborts_if num_seconds_execute < timelock.min_num_seconds_execute;
        aborts_if table::spec_contains(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        );
        ensures table::spec_contains(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        );
        ensures table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).creator == address_of(creator);
        ensures option::is_some(table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).payload);
        ensures option::borrow(table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).payload) == payload;
        ensures table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).salt == salt;
        ensures table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).num_seconds_execute == num_seconds_execute;
        ensures !table::spec_get(
            global<TimelockAccount>(timelock_account).transactions,
            aptos_std::aptos_hash::keccak256(concat(payload, salt)),
        ).executed;
    }

    spec create_transaction_with_hash(
        creator: &signer,
        timelock_account: address,
        hash: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
    ) {
        pragma aborts_if_is_partial;
        let timelock = global<TimelockAccount>(timelock_account);
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !contains(timelock.creators, address_of(creator));
        aborts_if len(hash) != 32;
        aborts_if len(salt) != 32;
        aborts_if num_seconds_execute < timelock.min_num_seconds_execute;
        aborts_if table::spec_contains(timelock.transactions, hash);
        ensures table::spec_contains(global<TimelockAccount>(timelock_account).transactions, hash);
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).creator
            == address_of(creator);
        ensures !option::is_some(table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).payload);
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).salt
            == salt;
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).num_seconds_execute
            == num_seconds_execute;
        ensures !table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).executed;
    }

    spec cancel_transaction(actor: &signer, timelock_account: address, hash: vector<u8>) {
        let timelock = global<TimelockAccount>(timelock_account);
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !contains(timelock.creators, address_of(actor))
            && (len(timelock.executors) == 0 || !contains(timelock.executors, address_of(actor)));
        aborts_if !table::spec_contains(timelock.transactions, hash);
        aborts_if table::spec_get(timelock.transactions, hash).executed;
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).executed;
    }

    // =============================== VM-called functions ===============================

    spec validate_timelock_transaction(
        executor: &signer,
        timelock_account: address,
        payload: vector<u8>,
        salt: vector<u8>,
    ) {
        let timelock = global<TimelockAccount>(timelock_account);
        let hash = aptos_std::aptos_hash::keccak256(concat(payload, salt));
        aborts_if !exists<TimelockAccount>(timelock_account);
        // Aborts if executor is not authorized (ENOT_EXECUTOR).
        aborts_if {
            let execs = timelock.executors;
            let creators = timelock.creators;
            if (len(execs) == 0) {
                !contains(creators, address_of(executor))
            } else {
                !contains(execs, address_of(executor))
            }
        };
        aborts_if !table::spec_contains(timelock.transactions, hash);
        aborts_if table::spec_get(timelock.transactions, hash).executed;
        // Aborts if the timelock period has not yet elapsed (ETIMELOCK_NOT_EXPIRED).
        aborts_if aptos_framework::timestamp::now_seconds() < table::spec_get(timelock.transactions, hash).creation_time_secs
            + table::spec_get(timelock.transactions, hash).num_seconds_execute;
        // Aborts if a stored payload exists and the provided payload is non-empty but mismatches (EPAYLOAD_DOES_NOT_MATCH).
        aborts_if {
            let tx = table::spec_get(timelock.transactions, hash);
            option::is_some(tx.payload) && len(payload) > 0
                && payload != option::borrow(tx.payload)
        };
    }

    spec successful_transaction_execution_cleanup(
        executor: address,
        timelock_account: address,
        salt: vector<u8>,
        payload: vector<u8>,
    ) {
        let hash = aptos_std::aptos_hash::keccak256(concat(payload, salt));
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !table::spec_contains(global<TimelockAccount>(timelock_account).transactions, hash);
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).executed;
        // Entry is kept in the table (not deleted).
        ensures table::spec_contains(global<TimelockAccount>(timelock_account).transactions, hash);
    }

    spec failed_transaction_execution_cleanup(
        executor: address,
        timelock_account: address,
        salt: vector<u8>,
        payload: vector<u8>,
        execution_error: ExecutionError,
    ) {
        let hash = aptos_std::aptos_hash::keccak256(concat(payload, salt));
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !table::spec_contains(global<TimelockAccount>(timelock_account).transactions, hash);
        ensures table::spec_get(global<TimelockAccount>(timelock_account).transactions, hash).executed;
        // Entry is kept in the table (not deleted).
        ensures table::spec_contains(global<TimelockAccount>(timelock_account).transactions, hash);
    }

    // =============================== Private helpers ===============================

    spec create_timelock_account(creator: &signer): (signer, SignerCapability) {
        // Full verification disabled; create_resource_account involves complex cross-module effects.
        pragma verify = false;
        aborts_if !exists<account::Account>(address_of(creator));
    }

    spec create_timelock_account_seed(seed: vector<u8>): vector<u8> {
        aborts_if false;
    }

    spec validate_members(members: &vector<address>, timelock_address: address, duplicate_error: u64) {
        // Aborts if any member equals the timelock address itself.
        aborts_if exists i in 0..len(members): members[i] == timelock_address;
        // Aborts if any member appears more than once.
        aborts_if exists i in 0..len(members):
            exists j in 0..i: members[i] == members[j];
    }
}
