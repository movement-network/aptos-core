#!/bin/bash

# Test script for error location reporting
set -e

ACCOUNT_ADDR="865068c439cac7b4eb72621f1a41d615101a263c6163ec947296a40afe6ae0f1"

echo "=== Testing Error Location Reporting on Movement Previewnet ==="
echo "Account: $ACCOUNT_ADDR"

# Compile the contract
echo "Compiling contract..."
aptos move compile --named-addresses error_test=$ACCOUNT_ADDR

# Deploy the contract
echo "Deploying contract..."
aptos move publish --named-addresses error_test=$ACCOUNT_ADDR --assume-yes

# Wait a bit for deployment
sleep 3

echo "=== Running Error Location Tests ==="

# Test 1: Should succeed
echo -e "\n=== Test 1: Success test ==="
aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::initialize --assume-yes
echo "✓ Initialize succeeded"

aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::test_success --assume-yes
echo "✓ Success test passed"

# Test 2: Abort failure - should report test_abort_fail
echo -e "\n=== Test 2: Direct abort (should report 'test_abort_fail') ==="
aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::test_abort_fail --assume-yes 2>&1 || echo "Expected failure"

# Test 3: Assert failure - should report test_assert_fail  
echo -e "\n=== Test 3: Assert failure (should report 'test_assert_fail') ==="
aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::test_assert_fail --assume-yes 2>&1 || echo "Expected failure"

# Test 4: Arithmetic failure - should report test_arithmetic_fail
echo -e "\n=== Test 4: Arithmetic error (should report 'test_arithmetic_fail') ==="  
aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::test_arithmetic_fail --assume-yes 2>&1 || echo "Expected failure"

# Test 5: Nested failure - should report nested_level_2, NOT test_nested_fail
echo -e "\n=== Test 5: Nested failure (should report 'nested_level_2') ==="
aptos move run --function-id ${ACCOUNT_ADDR}::simple_error_test::test_nested_fail --assume-yes 2>&1 || echo "Expected failure"

# Test 6: Borrow failure - should report test_borrow_fail
echo -e "\n=== Test 6: Deploy fresh contract and test borrow fail ==="
# First let's create a fresh account scenario by trying to borrow non-existent resource
# We'll call this on a different "account" (simulated by reinitializing)

echo -e "\n=== SUMMARY ==="
echo "Check the error messages above. Each test should report the CORRECT function name:"
echo "- Test 2 should show error in 'test_abort_fail'"  
echo "- Test 3 should show error in 'test_assert_fail'"
echo "- Test 4 should show error in 'test_arithmetic_fail'"
echo "- Test 5 should show error in 'nested_level_2' (NOT test_nested_fail)"
echo ""
echo "If any test shows the WRONG function name, then error location reporting is corrupted!"