#!/bin/bash

# Test script for error location reporting
set -e

NETWORK_URL="https://previewnet.devnet.movementnetwork.xyz"
PROFILE="local"  # Use existing default profile

echo "=== Testing Error Location Reporting on Movement Previewnet ==="

# Check if we have aptos CLI
if ! command -v aptos &> /dev/null; then
    echo "Error: aptos CLI not found. Please install it first."
    exit 1
fi

# Get the account address from existing profile
ACCOUNT_ADDR=$(aptos config show-profiles --profile $PROFILE | grep "account" | awk '{print $2}')
echo "Using existing profile with account address: $ACCOUNT_ADDR"

# Request testnet tokens (optional, in case balance is low)
echo "Requesting testnet tokens..."
curl -X POST "$NETWORK_URL/mint?amount=100000000&address=$ACCOUNT_ADDR" || true
sleep 2

# Compile the contract
echo "Compiling contract..."
aptos move compile --named-addresses error_test=$ACCOUNT_ADDR

# Deploy the contract
echo "Deploying contract..."
aptos move publish --named-addresses error_test=$ACCOUNT_ADDR

# Wait a bit for deployment
sleep 5

# Initialize the contract
echo "Initializing contract..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::initialize

sleep 3

echo "=== Running Error Location Tests ==="

# Test 1: Should succeed
echo "Test 1: Table operations that should succeed..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_table_success
echo "✓ Success test passed"

# Test 2: table::remove failure (should report correct location)
echo "Test 2: Testing table::remove failure (should report correct function)..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_table_remove_fail || echo "Expected failure in test_table_remove_fail"

# Test 3: abort failure (should NOT report table::remove)
echo "Test 3: Testing abort failure (should NOT report table::remove)..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_abort_fail || echo "Expected failure in test_abort_fail"

# Test 4: assertion failure (should NOT report table::remove)
echo "Test 4: Testing assertion failure (should NOT report table::remove)..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_assertion_fail || echo "Expected failure in test_assertion_fail"

# Test 5: table::borrow failure (should NOT report table::remove)
echo "Test 5: Testing table::borrow failure (should NOT report table::remove)..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_table_borrow_fail || echo "Expected failure in test_table_borrow_fail"

# Test 6: nested failure (should report correct nested function)
echo "Test 6: Testing nested failure (should report nested_helper_2, not table::remove)..."
aptos move run --function-id ${ACCOUNT_ADDR}::error_location_test::test_nested_fail || echo "Expected failure in nested function"

echo "=== Test Summary ==="
echo "Check the error messages above:"
echo "- Test 2 should report error in 'test_table_remove_fail'"
echo "- Test 3 should report error in 'test_abort_fail' (Move abort)"
echo "- Test 4 should report error in 'test_assertion_fail'"  
echo "- Test 5 should report error in 'test_table_borrow_fail'"
echo "- Test 6 should report error in 'nested_helper_2'"
echo ""
echo "If any test incorrectly reports 'table::remove' when it shouldn't,"
echo "then error location reporting is corrupted!"