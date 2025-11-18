#!/bin/bash

# Bare bones script to update the validator set using movement CLI
# Usage: ./update_validator_set.sh <validator-identity-file> <network-api-address> <stake-amount>

set -e

# Configuration
MOVEMENT_CLI="movement"
PROFILE="PROFILE_SHOULD_NOT_BE_USED"
VALIDATOR_IDENTITY_FILE="$1"
NETWORK_API_ADDRESS="${2%/}"  # Remove trailing slash if present
STAKE_AMOUNT="$3"
DRY_RUN="${4:-true}"

help_message_and_exit() {
    echo "Usage: $0 <validator-identity-file> <network-api-address> <stake-amount> [dry-run]"
    exit 1
}

# Check parameters.
check_params() {
    if [ -z "$VALIDATOR_IDENTITY_FILE" ] || [ -z "$NETWORK_API_ADDRESS" ] || [ -z "$STAKE_AMOUNT" ]; then
        help_message_and_exit
    fi
}

# Functions
get_network_pub_key() {
    local private_key="$1"
    local temp_file=$(mktemp)

    $MOVEMENT_CLI key extract-public-key \
        --private-key "$private_key" \
        --key-type "x25519" \
        --encoding hex \
        --output-file "$temp_file" \
        --assume-yes >/dev/null 2>&1
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        rm -f "$temp_file" "${temp_file}.pub"
        echo "Error: Failed to extract public key (exit code: $exit_code)" >&2
        exit 1
    fi

    # The public key is written to <output-file>.pub
    local public_key=$(cat "${temp_file}.pub")
    rm -f "$temp_file" "${temp_file}.pub"

    echo "$public_key"
}

get_consensus_keys() {
    local private_key="$1"
    local temp_file=$(mktemp)

    $MOVEMENT_CLI key extract-public-key \
        --private-key "$private_key" \
        --key-type "bls12381" \
        --encoding hex \
        --output-file "$temp_file" \
        --assume-yes >/dev/null 2>&1
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        rm -f "$temp_file" "${temp_file}.pub" "${temp_file}.pop"
        echo "Error: Failed to extract consensus keys (exit code: $exit_code)" >&2
        exit 1
    fi

    # Check if .pub and .pop files were created
    if [ ! -f "${temp_file}.pub" ]; then
        rm -f "$temp_file" "${temp_file}.pub" "${temp_file}.pop"
        echo "Error: Consensus public key file was not created" >&2
        exit 1
    fi

    if [ ! -f "${temp_file}.pop" ]; then
        rm -f "$temp_file" "${temp_file}.pub" "${temp_file}.pop"
        echo "Error: Consensus proof of possession file was not created" >&2
        exit 1
    fi

    # Read both the public key and proof of possession
    local public_key=$(cat "${temp_file}.pub")
    local pop_key=$(cat "${temp_file}.pop")

    # Clean up all temp files
    rm -f "$temp_file" "${temp_file}.pub" "${temp_file}.pop"

    # Return both values separated by space
    echo "$public_key $pop_key"
}

dependency_check() {
    if ! command -v $MOVEMENT_CLI &> /dev/null; then
        echo "Error: movement CLI is not installed or not in PATH"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        echo "Error: curl is not installed or not in PATH"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed or not in PATH"
        exit 1
    fi
}

validate_input() {
    if [ -z "$VALIDATOR_IDENTITY_FILE" ]; then
        echo "Error: Validator identity file not provided"
        help_message_and_exit
    fi

    if [ ! -f "$VALIDATOR_IDENTITY_FILE" ]; then
        echo "Error: Validator identity file not found: $VALIDATOR_IDENTITY_FILE"
        help_message_and_exit
    fi

    if [ -z "$NETWORK_API_ADDRESS" ]; then
        echo "Error: Network API address not provided"
        help_message_and_exit
    fi

    if [ -z "$STAKE_AMOUNT" ]; then
        echo "Error: Stake amount not provided"
        help_message_and_exit
    fi
}

get_identities() {
    # Read values from YAML file and strip quotes
    ACCOUNT_ADDRESS=$(grep "account_address:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')
    ACCOUNT_PRIVATE_KEY=$(grep "account_private_key:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')
    CONSENSUS_PRIVATE_KEY=$(grep "consensus_private_key:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')
    NETWORK_PRIVATE_KEY=$(grep "network_private_key:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')

    # Validate all fields are present
    if [ -z "$ACCOUNT_ADDRESS" ] || [ -z "$ACCOUNT_PRIVATE_KEY" ] || [ -z "$CONSENSUS_PRIVATE_KEY" ] || [ -z "$NETWORK_PRIVATE_KEY" ]; then
        echo "Error: Missing required fields in validator identity file"
        echo "Required fields: account_address, account_private_key, consensus_private_key, network_private_key"
        exit 1
    fi

    # Extract public keys from private keys
    read CONSENSUS_PUBLIC_KEY CONSENSUS_POP <<< $(get_consensus_keys "$CONSENSUS_PRIVATE_KEY")

    NETWORK_PUBLIC_KEY=$(get_network_pub_key "$NETWORK_PRIVATE_KEY")
}

check_account_exists() {
    local api_url="${NETWORK_API_ADDRESS}/v1/accounts/${ACCOUNT_ADDRESS}"
    local response=$(curl -s -w "\n%{http_code}" "$api_url")
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "404" ]; then
        echo "Error: Account $ACCOUNT_ADDRESS does not exist on the network"
        exit 1
    fi

    if [ "$http_code" != "200" ]; then
        echo "Error: Failed to retrieve account info (HTTP $http_code)"
        echo "$body"
        exit 1
    fi

    echo "Account exists on network"
}

check_account_balance() {
    BALANCE_OUTPUT=$($MOVEMENT_CLI account balance --account $ACCOUNT_ADDRESS --url $NETWORK_API_ADDRESS 2>&1)

    if [ $? -ne 0 ]; then
        echo "Error: Failed to retrieve account balance"
        echo "$BALANCE_OUTPUT"
        exit 1
    fi

    BALANCE=$(echo "$BALANCE_OUTPUT" | jq -r '.Result[0].balance')

    if [ -z "$BALANCE" ] || [ "$BALANCE" = "null" ]; then
        echo "Error: Unable to parse balance from response"
        exit 1
    fi
}

validate_config() {
    if [ "$STAKE_AMOUNT" -gt "$BALANCE" ]; then
        echo "Error: Stake amount ($STAKE_AMOUNT) exceeds account balance ($BALANCE)"
        exit 1
    fi
}

# Execution.
init_stake_owner() {
    $MOVEMENT_CLI stake initialize-stake-owner \
        --initial-stake-amount $STAKE_AMOUNT \
        --operator-address $ACCOUNT_ADDRESS \
        --voter-address $ACCOUNT_ADDRESS \
        --sender-account $ACCOUNT_ADDRESS \
        --private-key $ACCOUNT_PRIVATE_KEY \
        --url $NETWORK_API_ADDRESS \
        --gas-unit-price 100 \
        --max-gas 2000 \
        --assume-yes
}

update_consensus_keys() {
    $MOVEMENT_CLI node update-consensus-key \
        --pool-address $ACCOUNT_ADDRESS \
        --consensus-public-key $CONSENSUS_PUBLIC_KEY \
        --proof-of-possession $CONSENSUS_POP \
        --private-key $ACCOUNT_PRIVATE_KEY \
        --sender-account $ACCOUNT_ADDRESS \
        --url $NETWORK_API_ADDRESS \
        --gas-unit-price 100 \
        --max-gas 2000 \
        --assume-yes
}

update_network_address() {
    $MOVEMENT_CLI node update-validator-network-addresses \
        --pool-address $ACCOUNT_ADDRESS \
        --validator-host 127.0.0.1:40564 \
        --validator-network-public-key $NETWORK_PUBLIC_KEY \
        --private-key $ACCOUNT_PRIVATE_KEY \
        --sender-account $ACCOUNT_ADDRESS \
        --url $NETWORK_API_ADDRESS \
        --gas-unit-price 100 \
        --max-gas 2000 \
        --assume-yes
}

join_the_network() {
    $MOVEMENT_CLI node join-validator-set \
        --pool-address $ACCOUNT_ADDRESS \
        --private-key $ACCOUNT_PRIVATE_KEY \
        --sender-account $ACCOUNT_ADDRESS \
        --url $NETWORK_API_ADDRESS \
        --gas-unit-price 100 \
        --max-gas 2000 \
        --assume-yes
}

execute() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "Dry run enabled. No changes will be made."
    else
        echo "Executing validator set update..."

        # Validate the configuration
        validate_config

        # Initialize stake owner
        echo "Initializing stake owner..."
        init_stake_owner

        # Update consensus keys
        echo "Updating consensus keys..."
        update_consensus_keys

        echo "Validator set update completed successfully!"
    fi
}


execution_summary() {
    echo "Execution Summary:"
    echo "-------------------"
    echo "Account Address:           $ACCOUNT_ADDRESS"
    echo "Consensus Public Key:      ${CONSENSUS_PUBLIC_KEY:0:64}"
    echo "                           ${CONSENSUS_PUBLIC_KEY:64}"
    echo "Consensus Proof of Poss:   ${CONSENSUS_POP:0:64}"
    echo "                           ${CONSENSUS_POP:64:64}"
    echo "                           ${CONSENSUS_POP:128}"
    echo "Network Public Key:        $NETWORK_PUBLIC_KEY"
    echo "Network API Address:       $NETWORK_API_ADDRESS"
    echo "Account Balance:           $BALANCE"
    echo "Stake Amount:              $STAKE_AMOUNT"
    echo "-------------------"
}

# Main execution
check_params
dependency_check
validate_input
get_identities
# check_account_exists
check_account_balance
execution_summary
execute