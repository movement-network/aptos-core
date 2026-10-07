/// A minimal consumer of `aptos_framework::attestation_policy`: the whole integration surface a
/// business touches is one call at the top of each gated entry function.
module gated::vault {
    use std::signer;
    use aptos_framework::attestation_policy;

    /// Matches `attestation_policy::ACTION_TRANSFER`.
    const ACTION_TRANSFER: u8 = 1;

    /// Counts gated actions that went through, so a test can tell a success from a no-op.
    struct Transfers has key {
        count: u64,
        total: u64
    }

    public entry fun transfer(user: &signer, policy: address, amount: u64) acquires Transfers {
        attestation_policy::require(policy, signer::address_of(user), ACTION_TRANSFER, amount);
        record(user, amount);
    }

    public entry fun transfer_authorized(
        user: &signer, policy: address, amount: u64, authorization: vector<u8>
    ) acquires Transfers {
        attestation_policy::require_authorized(
            policy,
            signer::address_of(user),
            ACTION_TRANSFER,
            amount,
            authorization
        );
        record(user, amount);
    }

    #[view]
    public fun count_of(user: address): u64 acquires Transfers {
        if (exists<Transfers>(user)) { Transfers[user].count } else { 0 }
    }

    fun record(user: &signer, amount: u64) acquires Transfers {
        let addr = signer::address_of(user);
        if (!exists<Transfers>(addr)) {
            move_to(user, Transfers { count: 0, total: 0 });
        };
        let transfers = &mut Transfers[addr];
        transfers.count += 1;
        transfers.total += amount;
    }
}
