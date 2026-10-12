module aptos_framework::rate_limiter {
    use aptos_framework::timestamp;

    enum RateLimiter has key, store, copy, drop {
        // Struct to represent a Token Bucket that refills every minute
        TokenBucket {
            // Maximum number of tokens allowed at any time.
            capacity: u64,
            // Current number of tokens remaining in this interval.
            current_amount: u64,
            // refill `capacity` number of tokens every `refill_interval` in seconds.
            refill_interval: u64,
            // Last time the bucket was refilled (in seconds)
            last_refill_timestamp: u64,
            // accumulated amount that hasn't yet added up to a full token
            fractional_accumulated: u64,
        }
    }

    // Public entry function to initialize a Token Bucket based rate limiter.
    public fun initialize(capacity: u64, refill_interval: u64): RateLimiter {
        RateLimiter::TokenBucket {
            capacity,
            current_amount: capacity, // Start with a full bucket (full capacity of transactions allowed)
            refill_interval,
            last_refill_timestamp: timestamp::now_seconds(),
            fractional_accumulated: 0, // Start with no fractional accumulated
        }
    }

    // Public function to request a transaction from the bucket
    public fun request(limiter: &mut RateLimiter, num_token_requested: u64): bool {
        refill(limiter);
        if (limiter.current_amount >= num_token_requested) {
            limiter.current_amount = limiter.current_amount - num_token_requested;
            true
        } else {
            false
        }
    }

    // Function to refill the transactions in the bucket based on time passed
    fun refill(limiter: &mut RateLimiter) {
        let current_time = timestamp::now_seconds();
        let time_passed = current_time - limiter.last_refill_timestamp;
        // Calculate the full tokens that can be added
        let accumulated_amount = time_passed * limiter.capacity + limiter.fractional_accumulated;
        let new_tokens = accumulated_amount / limiter.refill_interval;
        if (limiter.current_amount + new_tokens >= limiter.capacity) {
            limiter.current_amount = limiter.capacity;
            limiter.fractional_accumulated = 0;
        } else {
            limiter.current_amount = limiter.current_amount + new_tokens;
            // Update the fractional amount accumulated for the next refill cycle
            limiter.fractional_accumulated = accumulated_amount % limiter.refill_interval;
        };
        limiter.last_refill_timestamp = current_time;
    }

    #[test(aptos_framework = @0x1)]
    fun test_initialize_bucket(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 60);
        assert!(bucket.capacity == 10, 100);
        assert!(bucket.current_amount == 10, 101);
        assert!(bucket.refill_interval == 60, 102);
    }

    #[test(aptos_framework = @0x1)]
    fun test_request_success(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 30);
        let success = request(&mut bucket, 5);
        assert!(success, 200); // Should succeed since 5 <= 10
        assert!(bucket.current_amount == 5, 201); // Remaining tokens should be 5
    }

    #[test(aptos_framework = @0x1)]
    fun test_request_failure(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 30);
        let success = request(&mut bucket, 15);
        assert!(!success, 300); // Should fail since 15 > 10
        assert!(bucket.current_amount == 10, 301); // Tokens should remain unchanged
    }

    #[test(aptos_framework = @0x1)]
    fun test_refill(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 60);

        // Simulate a passage of 31 seconds
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 31);

        // Refill the bucket
        refill(&mut bucket);

        // Should have refilled 5 tokens (half of the capacity),
        // but bucket was already full, so should remain full
        assert!(bucket.current_amount == 10, 400);
        assert!(bucket.fractional_accumulated == 0, 401);

        // Request 5 tokens
        let success = request(&mut bucket, 5);
        assert!(success, 401); // Request should succeed
        assert!(bucket.current_amount == 5, 402); // Remaining tokens should be 5
        assert!(bucket.fractional_accumulated == 0, 403);

        // Simulate another passage of 23 seconds
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 23);

        // Refill again
        refill(&mut bucket);

        // Should refill 3 tokens
        assert!(bucket.current_amount == 8, 403);
        // and have 230-180 leftover
        assert!(bucket.fractional_accumulated == 50, 404);
    }

    #[test(aptos_framework= @0x1)]
    fun test_fractional_accumulation(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 60);
        assert!(request(&mut bucket, 10), 1); // Request should succeed

        assert!(bucket.current_amount == 0, 500); // No token will be added since it rounds down

        // Simulate 10 seconds passing
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 10);

        // Refill the bucket
        refill(&mut bucket);
        // Should add 1/6th of the tokens (because 10 seconds is 1/6th of a minute)
        assert!(bucket.current_amount == 1, 500); // 1 token will be added since it rounds down
        assert!(bucket.fractional_accumulated == 40, 501); // Accumulate the 4 seconds of fractional amount

        // Simulate another 50 seconds passing (total 60 seconds)
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 50);

        // Refill the bucket again
        refill(&mut bucket);

        assert!(bucket.current_amount == 10, 502); // Should be full now
        assert!(bucket.fractional_accumulated == 0, 503); // Fractional time should reset
    }

    #[test(aptos_framework= @0x1)]
    fun test_multiple_refills(aptos_framework: &signer) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let bucket = initialize(10, 60);

        // Request 8 tokens
        let success = request(&mut bucket, 8);
        assert!(success, 600); // Should succeed
        assert!(bucket.current_amount == 2, 601); // Remaining tokens should be 2

        // Simulate a passage of 30 seconds
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 30);

        // Refill the bucket
        refill(&mut bucket);
        assert!(bucket.current_amount == 7, 602); // Should add 5 tokens (half of the refill rate)

        // Simulate another 30 seconds
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + 30);

        // Refill the bucket again
        refill(&mut bucket);
        assert!(bucket.current_amount == 10, 603); // Should be full again
    }

    //
    // Fuzz tests
    //

    // A token bucket must never hold more than its capacity, no matter how
    // requests and time-based refills interleave. `refill`'s arithmetic is where
    // a fuzzer earns its keep: a zero `refill_interval` divides by zero, and an
    // unbounded `capacity`/elapsed pair overflows `time_passed * capacity` or the
    // running `current_amount + new_tokens`. We bound the drawn values into
    // realistic ranges so the test exercises the logic rather than tripping the
    // u64 guardrails, and assert the capacity invariant plus exact accounting on
    // the no-elapsed-time path.
    #[test(aptos_framework = @0x1)]
    fun fuzz_request_respects_capacity(
        aptos_framework: &signer,
        cap_raw: u64,
        interval_raw: u64,
        req_raw: u64,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let capacity = 1 + cap_raw % 1000000; // [1, 1_000_000]
        let interval = 1 + interval_raw % 86400; // [1, 86400]; never 0
        let bucket = initialize(capacity, interval);

        // No time has elapsed since initialize(), so the refill inside request()
        // adds nothing: a full bucket grants exactly `req` when req <= capacity.
        let req = req_raw % (capacity + 1); // [0, capacity]
        let granted = request(&mut bucket, req);
        assert!(granted, 0);
        assert!(bucket.current_amount == capacity - req, 1);
        assert!(bucket.current_amount <= bucket.capacity, 2);
    }

    #[test(aptos_framework = @0x1)]
    fun fuzz_refill_never_exceeds_capacity(
        aptos_framework: &signer,
        cap_raw: u64,
        interval_raw: u64,
        elapsed_raw: u64,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        let capacity = 1 + cap_raw % 1000000; // [1, 1_000_000]
        let interval = 1 + interval_raw % 86400; // [1, 86400]
        let bucket = initialize(capacity, interval);

        // Drain fully, advance the clock by a bounded, strictly positive amount
        // (update_global_time_for_test requires time to move forward), then
        // refill. With capacity <= 1e6 and elapsed <= 1e5, `time_passed *
        // capacity` <= 1e11 — well inside u64 — so we test the refill logic, not
        // overflow.
        assert!(request(&mut bucket, capacity), 0);
        assert!(bucket.current_amount == 0, 1);

        let elapsed = 1 + elapsed_raw % 100000; // [1, 100_000] seconds
        timestamp::update_global_time_for_test_secs(timestamp::now_seconds() + elapsed);
        refill(&mut bucket);

        // A refill tops up to, but never beyond, capacity...
        assert!(bucket.current_amount <= bucket.capacity, 2);
        // ...and any carried-over fractional accumulation is a proper remainder.
        assert!(bucket.fractional_accumulated < interval, 3);
    }
}
