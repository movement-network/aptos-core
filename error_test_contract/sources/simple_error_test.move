module error_test::simple_error_test {
    use std::signer;
    
    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1001;
    const E_INVALID_AMOUNT: u64 = 1002;
    const E_RESOURCE_NOT_FOUND: u64 = 1003;
    const E_INSUFFICIENT_BALANCE: u64 = 1004;

    struct SimpleStorage has key {
        value: u64,
        owner: address,
    }

    /// Initialize storage
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        if (!exists<SimpleStorage>(addr)) {
            move_to(account, SimpleStorage {
                value: 0,
                owner: addr,
            });
        };
    }

    /// Function 1: Should succeed
    public entry fun test_success(account: &signer) acquires SimpleStorage {
        let addr = signer::address_of(account);
        assert!(exists<SimpleStorage>(addr), E_RESOURCE_NOT_FOUND);
        
        let storage = borrow_global_mut<SimpleStorage>(addr);
        storage.value = storage.value + 1;
    }

    /// Function 2: Should fail with abort in THIS function (test_abort_fail)
    public entry fun test_abort_fail(_account: &signer) {
        // Direct abort - should report test_abort_fail as location
        abort E_NOT_AUTHORIZED
    }

    /// Function 3: Should fail with assert in THIS function (test_assert_fail)  
    public entry fun test_assert_fail(account: &signer) acquires SimpleStorage {
        let addr = signer::address_of(account);
        assert!(exists<SimpleStorage>(addr), E_RESOURCE_NOT_FOUND);
        
        let storage = borrow_global<SimpleStorage>(addr);
        // This should fail and report test_assert_fail as location
        assert!(storage.value > 1000, E_INSUFFICIENT_BALANCE);
    }

    /// Function 4: Should fail with arithmetic error in THIS function
    public entry fun test_arithmetic_fail(_account: &signer) {
        let x: u64 = 0;
        // This should cause an arithmetic error and report test_arithmetic_fail
        let _y = 10 / x;  // Division by zero
    }

    /// Function 5: Test nested call stack - should report the deepest function
    public entry fun test_nested_fail(account: &signer) acquires SimpleStorage {
        nested_level_1(account);
    }

    fun nested_level_1(account: &signer) acquires SimpleStorage {
        nested_level_2(account);
    }

    fun nested_level_2(account: &signer) acquires SimpleStorage {
        let addr = signer::address_of(account);
        assert!(exists<SimpleStorage>(addr), E_RESOURCE_NOT_FOUND);
        
        let storage = borrow_global<SimpleStorage>(addr);
        // This should fail and report nested_level_2 as the location, NOT test_nested_fail
        assert!(storage.value > 9999, E_INSUFFICIENT_BALANCE);
    }

    /// Function 6: Test borrow failure
    public entry fun test_borrow_fail(account: &signer) acquires SimpleStorage {
        let addr = signer::address_of(account);
        // This should fail and report test_borrow_fail, NOT some other function
        let _storage = borrow_global<SimpleStorage>(addr);  // Will fail if resource doesn't exist
    }
}
