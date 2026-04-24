spec aptos_framework::dispatchable_fungible_asset {
    spec module {
        pragma verify = false;
    }

    spec dispatchable_withdraw {
        pragma opaque;
    }

    spec dispatchable_deposit {
        pragma opaque;
    }

    spec dispatchable_derived_balance{
        pragma opaque;
    }

    spec dispatchable_derived_supply{
        pragma opaque;
    }

    spec transfer {
        pragma opaque;
        modifies global<fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
    }

    spec transfer_assert_minimum_deposit {
        pragma opaque;
        modifies global<fungible_asset::FungibleStore>(@aptos_framework);
        modifies global<fungible_asset::ConcurrentFungibleBalance>(@aptos_framework);
        modifies global<aptos_framework::permissioned_signer::PermissionStorage>(@aptos_framework);
    }
}
