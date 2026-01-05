module test_module::test_module {
    use std::string::{Self, String};

    #[view]
    public fun greet(): String {
        string::utf8(b"Different source code that doesn't match")
    }
}

