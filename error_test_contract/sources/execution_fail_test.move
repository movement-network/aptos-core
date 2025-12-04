module error_test::execution_fail_test {
    
    /// Function A: Should cause execution failure
    public entry fun function_a(_account: &signer) {
        let x: u64 = 0;
        let _y = 100 / x;  // Division by zero - execution failure
    }

    /// Function B: Should cause execution failure  
    public entry fun function_b(_account: &signer) {
        let x: u64 = 0;
        let _y = 200 / x;  // Division by zero - execution failure
    }

    /// Function C: Should cause execution failure
    public entry fun function_c(_account: &signer) {
        let x: u64 = 0; 
        let _y = 300 / x;  // Division by zero - execution failure
    }
}