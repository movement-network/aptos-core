// Simple test module that uses aptos_token to verify transitive framework dependencies work.
// aptos_token depends on aptos-framework, which depends on aptos-stdlib.
// The verification compiler must include these transitive dependencies.
module token_test::token_module {
    use std::string::String;
    use aptos_token::token;

    // Get the token collection name - simple function using aptos_token
    public fun get_collection_supply(creator: address, collection_name: String): u64 {
        let supply = token::get_collection_supply(creator, collection_name);
        if (std::option::is_some(&supply)) {
            std::option::extract(&mut supply)
        } else {
            0
        }
    }
}
