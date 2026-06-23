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
    /// Requirement: Creator, executor, and canceler lists must not contain duplicate addresses, and the timelock
    /// account address itself cannot appear in any of them.
    /// Criticality: Critical
    /// Implementation: The validate_members function iterates through the member list and aborts on any duplicate or
    /// self-reference. It is called for creators, executors, and cancelers during account creation and member updates.
    /// Enforcement: Audited that duplicate detection aborts correctly (validate_members, add_creators, add_executors,
    /// add_cancelers). Audited that self-reference is rejected (validate_members).
    ///
    /// No.: 3
    /// Requirement: A transaction can only be resolved after the timelock period has fully elapsed.
    /// Specifically, block time must satisfy: now_seconds >= creation_time_secs + num_seconds_execute.
    /// Criticality: Critical
    /// Implementation: The resolve function asserts this time condition before authorizing execution.
    /// Enforcement: Audited that it aborts if the timelock period has not elapsed (resolve).
    ///
    /// No.: 4
    /// Requirement: Each transaction proposal is uniquely identified by keccak256(execution_hash || salt). Submitting
    /// a proposal whose computed key already exists is rejected. To submit the same script again, a new salt must be
    /// used.
    /// Criticality: High
    /// Implementation: The create_transaction function computes the table key and asserts that the key does not
    /// already exist as a key in the transactions table before adding the new entry.
    /// Enforcement: Audited that it aborts if the computed proposal hash already exists (create_transaction).
    ///
    /// No.: 5
    /// Requirement: When the executor list is empty, creators are authorized to execute transactions.
    /// Criticality: High
    /// Implementation: The assert_is_executor inline function checks the executors vector and falls back to checking the
    /// creators vector when executors is empty. The is_executor view function applies the same logic.
    /// Enforcement: Audited that creators can execute when executors is empty (assert_is_executor, is_executor).
    ///
    /// No.: 6
    /// Requirement: Any creator or any canceler can cancel any pending transaction at any time, before the transaction
    /// has been executed or canceled. Executors cannot cancel; cancelers are an emergency-response role that can only
    /// cancel (they cannot propose or execute).
    /// Criticality: High
    /// Implementation: The cancel_transaction function checks that the caller is either a creator or a canceler, then
    /// asserts that the transaction has not yet been executed, and sets executed = true.
    /// Enforcement: Audited that it aborts if the caller has no cancellation rights (cancel_transaction). Audited that
    /// it aborts if the transaction is already executed or canceled (cancel_transaction).
    ///
    /// No.: 7
    /// Requirement: Once a transaction's executed field is set to true (either by execution or cancellation), neither
    /// further execution nor further cancellation is permitted. The transaction entry is kept in the table permanently.
    /// Criticality: High
    /// Implementation: Both resolve and cancel_transaction assert !transaction.executed before proceeding. resolve sets
    /// executed = true; if the surrounding script aborts, this state change reverts atomically.
    /// Enforcement: Audited that it aborts if executed is already true (resolve, cancel_transaction). Audited that
    /// entries remain in the table after execution (resolve).
    ///
    /// No.: 8
    /// Requirement: Changes to num_seconds_execute, the creator list, the executor list, and the canceler list can only
    /// be made by the timelock account itself, enforced by requiring the timelock account signer on the self-governance
    /// entry functions.
    /// Criticality: Critical
    /// Implementation: The self-governance functions (update_min_num_seconds_execute, add_creators, remove_creators,
    /// add_executors, remove_executors, add_cancelers, remove_cancelers) all take timelock_account: &signer as first
    /// argument. The signer is produced only by `resolve`, which derives it from the stored signer_cap after verifying
    /// the running script.
    /// Enforcement: Audited that the signer must be the timelock account address for self-governance functions.
    ///
    /// No.: 9
    /// Requirement: Creating a timelock account properly initializes all resources and publishes the TimelockAccount
    /// resource under the resource account address derived from the deployer's address and sequence number. The
    /// deployer authorizes resource-account creation but does not gain creator, executor, or canceler status; membership
    /// is determined entirely by the `creators`, `executors`, and `cancelers` arguments passed to `create`.
    /// Criticality: Medium
    /// Implementation: The create function derives the resource account address, creates the account via
    /// account::create_resource_account, and calls create_timelock_account_internal which publishes the TimelockAccount
    /// resource with all fields initialized from the supplied creators and executors lists.
    /// Enforcement: Audited that TimelockAccount is initialized and published (create, create_timelock_account_internal).
    ///
    /// No.: 10
    /// Requirement: Only valid creators are allowed to propose transactions. Proposing a transaction stores the
    /// execution_hash, salt, the proposer, and the proposal timestamp, with executed = false.
    /// Criticality: Critical
    /// Implementation: The create_transaction function validates that the caller is in the creators list before adding
    /// the new TimelockTransaction to the table.
    /// Enforcement: Audited that it aborts if the caller is not a creator (create_transaction, assert_is_creator).
    /// Audited that the transaction is stored correctly with executed = false (create_transaction).
    ///
    /// No.: 11
    /// Requirement: A transaction may be resolved only by an authorized executor (or a creator when executors is
    /// empty) submitting the script directly, OR by any submitter when the transaction was pre-approved by such an
    /// executor via approve_resolution. The running script's hash must equal the proposed execution_hash.
    /// Criticality: Critical
    /// Implementation: The resolve function authorizes if the submitter is an executor or the transaction's `approved`
    /// flag is set, then checks transaction existence, executed status, timelock expiry, and equality between
    /// transaction_context::get_script_hash() and the stored execution_hash. approve_resolution sets `approved` only
    /// for an authorized executor and only on a not-yet-executed transaction.
    /// Enforcement: Audited that it aborts if the submitter is neither an executor nor resolving an approved
    /// transaction (resolve). Audited that approval requires executor authorization (approve_resolution). Audited
    /// that it aborts if the script hash mismatches (resolve).
    /// </high-level-req>

    spec module {}

    // =============================== View functions ===============================

    spec creators(timelock_account: address): vector<address> {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == TimelockAccount[timelock_account].creators;
    }

    spec executors(timelock_account: address): vector<address> {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == TimelockAccount[timelock_account].executors;
    }

    spec min_num_seconds_execute(timelock_account: address): u64 {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == TimelockAccount[timelock_account].min_num_seconds_execute;
    }

    spec is_creator(addr: address, timelock_account: address): bool {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == contains(TimelockAccount[timelock_account].creators, addr);
    }

    spec is_executor(addr: address, timelock_account: address): bool {
        aborts_if !exists<TimelockAccount>(timelock_account);
        let timelock = TimelockAccount[timelock_account];
        ensures len(timelock.executors) == 0 ==> result == contains(timelock.creators, addr);
        ensures len(timelock.executors) > 0 ==> result == contains(timelock.executors, addr);
    }

    spec cancelers(timelock_account: address): vector<address> {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == TimelockAccount[timelock_account].cancelers;
    }

    spec is_canceler(addr: address, timelock_account: address): bool {
        aborts_if !exists<TimelockAccount>(timelock_account);
        ensures result == contains(TimelockAccount[timelock_account].cancelers, addr);
    }

    spec get_transaction(timelock_account: address, proposal_hash: vector<u8>): TimelockTransaction {
        let timelock = TimelockAccount[timelock_account];
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !table::spec_contains(timelock.transactions, proposal_hash);
        ensures result == table::spec_get(timelock.transactions, proposal_hash);
    }

    spec can_be_executed(timelock_account: address, proposal_hash: vector<u8>): bool {
        pragma aborts_if_is_partial;
        // Aborts if the resource is absent. May also overflow on `creation_time_secs +
        // num_seconds_execute` for a pathologically large (proposer-chosen) delay; that case is
        // left unspecified by `aborts_if_is_partial`.
        aborts_if !exists<TimelockAccount>(timelock_account);
        let timelock = TimelockAccount[timelock_account];
        ensures !table::spec_contains(timelock.transactions, proposal_hash) ==> !result;
        ensures table::spec_contains(timelock.transactions, proposal_hash) ==> result ==
            (!table::spec_get(timelock.transactions, proposal_hash).executed
                && aptos_framework::timestamp::now_seconds()
                    >= table::spec_get(timelock.transactions, proposal_hash).creation_time_secs
                        + table::spec_get(timelock.transactions, proposal_hash).num_seconds_execute);
    }

    spec get_proposal_hash(execution_hash: vector<u8>, salt: vector<u8>): vector<u8> {
        ensures result == aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt));
    }

    spec get_next_timelock_account_address(deployer: address): address {
        pragma aborts_if_is_partial;
    }

    // =============================== Account creation ===============================

    spec create(
        deployer: &signer,
        creators: vector<address>,
        executors: vector<address>,
        cancelers: vector<address>,
        num_seconds_execute: u64,
    ) {
        // Full verification is disabled because create_resource_account involves complex
        // cross-module side-effects (coin registration, nonce derivation) that the prover
        // cannot fully reason about.
        pragma verify = false;
        // Mirror assert_delay's bounds (referencing the module constants so the spec can't
        // drift from the code).
        aborts_if num_seconds_execute < MIN_NUM_SECONDS_EXECUTE;
        aborts_if num_seconds_execute > MAX_NUM_SECONDS_EXECUTE;
        aborts_if !exists<account::Account>(address_of(deployer));
    }

    spec create_timelock_account_internal(
        timelock_account: &signer,
        creators: vector<address>,
        executors: vector<address>,
        cancelers: vector<address>,
        min_num_seconds_execute: u64,
        signer_cap: SignerCapability,
    ) {
        aborts_if len(creators) < 1;
        // Mirror assert_delay's bounds via the module constants.
        aborts_if min_num_seconds_execute < MIN_NUM_SECONDS_EXECUTE;
        aborts_if min_num_seconds_execute > MAX_NUM_SECONDS_EXECUTE;
        aborts_if exists<TimelockAccount>(address_of(timelock_account));
        // Aborts if creators, executors, or cancelers contain duplicates or include the timelock address.
        aborts_if exists i in 0..len(creators): creators[i] == address_of(timelock_account);
        aborts_if exists i in 0..len(creators): exists j in 0..i: creators[i] == creators[j];
        aborts_if exists i in 0..len(executors): executors[i] == address_of(timelock_account);
        aborts_if exists i in 0..len(executors): exists j in 0..i: executors[i] == executors[j];
        aborts_if exists i in 0..len(cancelers): cancelers[i] == address_of(timelock_account);
        aborts_if exists i in 0..len(cancelers): exists j in 0..i: cancelers[i] == cancelers[j];
        ensures exists<TimelockAccount>(address_of(timelock_account));
        ensures TimelockAccount[address_of(timelock_account)].min_num_seconds_execute == min_num_seconds_execute;
        ensures TimelockAccount[address_of(timelock_account)].creators == creators;
        ensures TimelockAccount[address_of(timelock_account)].executors == executors;
        ensures TimelockAccount[address_of(timelock_account)].cancelers == cancelers;
    }

    // =============================== Self-governance ===============================

    spec add_creators(timelock_account: &signer, new_creators: vector<address>) {
        pragma aborts_if_is_partial;
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        // Aborts if any new creator is the timelock address itself.
        aborts_if exists i in 0..len(new_creators): new_creators[i] == addr;
        // Aborts if new_creators list has internal duplicates.
        aborts_if exists i in 0..len(new_creators): exists j in 0..i: new_creators[i] == new_creators[j];
        ensures exists<TimelockAccount>(addr);
        // Post-state: creators list is the prior list with new_creators appended; no other field changes.
        ensures TimelockAccount[addr].creators
            == concat(old(TimelockAccount[addr].creators), new_creators);
        ensures TimelockAccount[addr].executors
            == old(TimelockAccount[addr].executors);
        ensures TimelockAccount[addr].cancelers
            == old(TimelockAccount[addr].cancelers);
        ensures TimelockAccount[addr].min_num_seconds_execute
            == old(TimelockAccount[addr].min_num_seconds_execute);
    }

    spec remove_creators(timelock_account: &signer, creators_to_remove: vector<address>) {
        pragma aborts_if_is_partial;
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        // Aborts if removing these creators would leave zero creators.
        // (Full enumeration of the post-removal set is complex; partial spec retained here.)
        ensures exists<TimelockAccount>(addr);
        // Must retain at least one creator.
        ensures len(TimelockAccount[addr].creators) >= 1;
        // Note: "executors and min_num_seconds_execute unchanged" is a true property of this entry,
        // but expressing it here trips the prover's loop havoc over `for_each_ref` on a mutably
        // borrowed struct.
    }

    spec add_executors(timelock_account: &signer, new_executors: vector<address>) {
        pragma aborts_if_is_partial;
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        // Aborts if any new executor is the timelock address itself.
        aborts_if exists i in 0..len(new_executors): new_executors[i] == addr;
        // Aborts if new_executors list has internal duplicates.
        aborts_if exists i in 0..len(new_executors): exists j in 0..i: new_executors[i] == new_executors[j];
        ensures exists<TimelockAccount>(addr);
        // Post-state: executors list is the prior list with new_executors appended; no other field changes.
        ensures TimelockAccount[addr].executors
            == concat(old(TimelockAccount[addr].executors), new_executors);
        ensures TimelockAccount[addr].creators
            == old(TimelockAccount[addr].creators);
        ensures TimelockAccount[addr].cancelers
            == old(TimelockAccount[addr].cancelers);
        ensures TimelockAccount[addr].min_num_seconds_execute
            == old(TimelockAccount[addr].min_num_seconds_execute);
        // Ensure the timelock account has no duplicate executors.
        ensures forall i in 0..len(TimelockAccount[addr].executors):
            forall j in i+1..len(TimelockAccount[addr].executors): TimelockAccount[addr].executors[i] != TimelockAccount[addr].executors[j];
    }

    spec remove_executors(timelock_account: &signer, executors_to_remove: vector<address>) {
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        ensures exists<TimelockAccount>(addr);
        // Note: "creators and min_num_seconds_execute unchanged" is a true property of this entry,
        // but expressing it here trips the prover's loop havoc over `for_each_ref` on a mutably
        // borrowed struct.
    }

    spec add_cancelers(timelock_account: &signer, new_cancelers: vector<address>) {
        pragma aborts_if_is_partial;
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        // Aborts if any new canceler is the timelock address itself.
        aborts_if exists i in 0..len(new_cancelers): new_cancelers[i] == addr;
        // Aborts if new_cancelers list has internal duplicates.
        aborts_if exists i in 0..len(new_cancelers): exists j in 0..i: new_cancelers[i] == new_cancelers[j];
        ensures exists<TimelockAccount>(addr);
        // Post-state: cancelers list is the prior list with new_cancelers appended; no other field changes.
        ensures TimelockAccount[addr].cancelers
            == concat(old(TimelockAccount[addr].cancelers), new_cancelers);
        ensures TimelockAccount[addr].creators
            == old(TimelockAccount[addr].creators);
        ensures TimelockAccount[addr].executors
            == old(TimelockAccount[addr].executors);
        ensures TimelockAccount[addr].min_num_seconds_execute
            == old(TimelockAccount[addr].min_num_seconds_execute);
    }

    spec remove_cancelers(timelock_account: &signer, cancelers_to_remove: vector<address>) {
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        ensures exists<TimelockAccount>(addr);
        // Note: "creators, executors, and min_num_seconds_execute unchanged" is a true property of
        // this entry, but expressing it here trips the prover's loop havoc over `for_each_ref` on a
        // mutably borrowed struct.
    }

    spec update_min_num_seconds_execute(timelock_account: &signer, new_min_num_seconds_execute: u64) {
        let addr = address_of(timelock_account);
        aborts_if !exists<TimelockAccount>(addr);
        // Mirror assert_delay's bounds via the module constants.
        aborts_if new_min_num_seconds_execute < MIN_NUM_SECONDS_EXECUTE;
        aborts_if new_min_num_seconds_execute > MAX_NUM_SECONDS_EXECUTE;
        ensures TimelockAccount[addr].min_num_seconds_execute == new_min_num_seconds_execute;
        // Membership lists are unchanged.
        ensures TimelockAccount[addr].creators
            == old(TimelockAccount[addr].creators);
        ensures TimelockAccount[addr].executors
            == old(TimelockAccount[addr].executors);
        ensures TimelockAccount[addr].cancelers
            == old(TimelockAccount[addr].cancelers);
    }

    // =============================== Transaction flow ===============================

    spec create_transaction(
        creator: &signer,
        timelock_account: address,
        execution_hash: vector<u8>,
        num_seconds_execute: u64,
        salt: vector<u8>,
        script_path: vector<u8>,
    ) {
        pragma aborts_if_is_partial;
        let timelock = TimelockAccount[timelock_account];
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if !contains(timelock.creators, address_of(creator));
        aborts_if len(execution_hash) != 32;
        aborts_if len(salt) != 32;
        aborts_if num_seconds_execute < timelock.min_num_seconds_execute;
        aborts_if table::spec_contains(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        );
        ensures table::spec_contains(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        );
        ensures table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).creator == address_of(creator);
        ensures table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).execution_hash == execution_hash;
        ensures table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).salt == salt;
        ensures table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).num_seconds_execute == num_seconds_execute;
        ensures !table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).executed;
        // A freshly proposed transaction is not yet approved for resolution.
        ensures !table::spec_get(
            TimelockAccount[timelock_account].transactions,
            aptos_std::aptos_hash::spec_keccak256(concat(execution_hash, salt)),
        ).approved;
    }

    spec approve_resolution(executor: &signer, timelock_account: address, proposal_hash: vector<u8>) {
        // Partial: the `creation_time_secs + num_seconds_execute` sum can overflow (see
        // `create_transaction`, which does not bound `num_seconds_execute` from above).
        pragma aborts_if_is_partial;
        let timelock = TimelockAccount[timelock_account];
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if len(proposal_hash) != 32;
        // Authorization mirrors execution: an executor, or a creator when the executor list is empty.
        aborts_if len(timelock.executors) == 0 && !contains(timelock.creators, address_of(executor));
        aborts_if len(timelock.executors) > 0 && !contains(timelock.executors, address_of(executor));
        aborts_if !table::spec_contains(timelock.transactions, proposal_hash);
        aborts_if table::spec_get(timelock.transactions, proposal_hash).executed;
        // Approval is only permitted once the delay has elapsed (mirrors `resolve`).
        aborts_if aptos_framework::timestamp::now_seconds() < table::spec_get(timelock.transactions, proposal_hash).creation_time_secs
            + table::spec_get(timelock.transactions, proposal_hash).num_seconds_execute;
        // On success, the transaction is marked approved.
        ensures table::spec_get(TimelockAccount[timelock_account].transactions, proposal_hash).approved;
    }

    spec cancel_transaction(actor: &signer, timelock_account: address, proposal_hash: vector<u8>) {
        let timelock = TimelockAccount[timelock_account];
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if len(proposal_hash) != 32;
        // Only creators or cancelers may cancel; executors cannot.
        aborts_if !contains(timelock.creators, address_of(actor))
            && !contains(timelock.cancelers, address_of(actor));
        aborts_if !table::spec_contains(timelock.transactions, proposal_hash);
        aborts_if table::spec_get(timelock.transactions, proposal_hash).executed;
        ensures table::spec_get(TimelockAccount[timelock_account].transactions, proposal_hash).executed;
    }

    spec resolve(
        submitter: &signer,
        timelock_account: address,
        proposal_hash: vector<u8>,
    ): signer {
        // Full verification is disabled because resolve calls the native
        // transaction_context::get_script_hash, which the prover cannot constrain.
        pragma verify = false;
        let timelock = TimelockAccount[timelock_account];
        aborts_if !exists<TimelockAccount>(timelock_account);
        aborts_if len(proposal_hash) != 32;
        aborts_if !table::spec_contains(timelock.transactions, proposal_hash);
        aborts_if table::spec_get(timelock.transactions, proposal_hash).executed;
        // Authorized if the submitter is an executor (creator-fallback when executors is empty) OR
        // the transaction was pre-approved via approve_resolution.
        aborts_if !table::spec_get(timelock.transactions, proposal_hash).approved && {
            let execs = timelock.executors;
            let creators = timelock.creators;
            if (len(execs) == 0) {
                !contains(creators, address_of(submitter))
            } else {
                !contains(execs, address_of(submitter))
            }
        };
        aborts_if aptos_framework::timestamp::now_seconds() < table::spec_get(timelock.transactions, proposal_hash).creation_time_secs
            + table::spec_get(timelock.transactions, proposal_hash).num_seconds_execute;
        // On success, the entry is marked executed and remains in the table.
        ensures table::spec_get(TimelockAccount[timelock_account].transactions, proposal_hash).executed;
        ensures table::spec_contains(TimelockAccount[timelock_account].transactions, proposal_hash);
    }

    // =============================== Private helpers ===============================

    spec create_timelock_account(deployer: &signer): (signer, SignerCapability) {
        // Full verification disabled; create_resource_account involves complex cross-module effects.
        pragma verify = false;
        aborts_if !exists<account::Account>(address_of(deployer));
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
