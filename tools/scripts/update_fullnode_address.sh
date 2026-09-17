#!/bin/bash

# Simple script to update validator network addresses (both validator and fullnode)
# Usage: ./update_fullnode_address.sh <validator-identity-file> <owner-identity-file> <validator-host> <fullnode-host> [network-url]
#
# Example:
#   ./update_fullnode_address.sh data/1/operator/validator-identity.yaml data/1/operator/owner-identity.yaml localhost:6181 localhost:6191 http://localhost:8080

set -e

# Arguments
VALIDATOR_IDENTITY_FILE="$1"
VALIDATOR_FULL_NODE_IDENTITY="$2"
OWNER_IDENTITY_FILE="$3"
VALIDATOR_HOST="$4"
FULLNODE_HOST="$5"
NETWORK_URL="$6"

# Default to localhost:8080 if not specified
NETWORK_URL="${NETWORK_URL:-http://localhost:8080}"

# Delegation pool configuration (same as update_validator_set_staking.sh)
SEED=2563
DELEGATION_SEED="aptos_framework::delegation_pool${SEED}"

# Help message
if [ -z "$VALIDATOR_IDENTITY_FILE" ] || [ -z "$OWNER_IDENTITY_FILE" ] || [ -z "$VALIDATOR_HOST" ] || [ -z "$FULLNODE_HOST" ]; then
    echo "Usage: $0 <validator-identity-file> <validator-full-node-identity-file> <owner-identity-file> <validator-host> <fullnode-host> [network-url]"
    echo ""
    echo "Arguments:"
    echo "  validator-identity-file  - Path to validator/operator identity YAML file"
    echo "  validator-full-node-identity-file        - Path to VFN identity YAML file"
    echo "  owner-identity-file      - Path to owner identity YAML file"
    echo "  validator-host          - Validator address (e.g., localhost:6181)"
    echo "  fullnode-host           - Fullnode address (e.g., localhost:6191)"
    echo "  network-url             - API endpoint (default: http://localhost:8080)"
    echo ""
    echo "Example:"
    echo "  $0 operator/validator-identity.yaml owner-identity.yaml localhost:6181 localhost:6191"
    echo "  $0 validator-identity.yaml owner.yaml 127.0.0.1:6181 127.0.0.1:6191 http://localhost:8090"
    exit 1
fi

# Check if identity files exist
if [ ! -f "$VALIDATOR_IDENTITY_FILE" ]; then
    echo "Error: Validator identity file not found: $VALIDATOR_IDENTITY_FILE"
    exit 1
fi

if [ ! -f "$OWNER_IDENTITY_FILE" ]; then
    echo "Error: Owner identity file not found: $OWNER_IDENTITY_FILE"
    exit 1
fi

if [ ! -f "$VALIDATOR_FULL_NODE_IDENTITY" ]; then
    echo "Error: VFN identity file not found: $VALIDATOR_FULL_NODE_IDENTITY"
    exit 1
fi

# Extract keys from validator identity (operator)
VN_ACCOUNT=$(grep "account_address:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')
VN_ACCOUNT_PRIVATE_KEY=$(grep "account_private_key:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')
VN_NETWORK_PRIVATE_KEY=$(grep "network_private_key:" "$VALIDATOR_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')

VFN_ACCOUNT=$(grep "account_address:" "$VALIDATOR_FULL_NODE_IDENTITY" | awk '{print $2}' | tr -d '"')
VFN_NETWORK_PRIVATE_KEY=$(grep "network_private_key:" "$VALIDATOR_FULL_NODE_IDENTITY" | awk '{print $2}' | tr -d '"')

if [ -z "$VN_ACCOUNT" ] || [ -z "$VN_ACCOUNT_PRIVATE_KEY" ] || [ -z "$VN_NETWORK_PRIVATE_KEY" ] || [ -z "$VFN_ACCOUNT" ] || [ -z "$VFN_NETWORK_PRIVATE_KEY" ]; then
    echo "Error: Missing required fields in validator identity file"
    echo "Required: account_address, account_private_key, network_private_key"
    exit 1
fi

# Extract owner account from owner identity file
OWNER_ACCOUNT=$(grep "account_address:" "$OWNER_IDENTITY_FILE" | awk '{print $2}' | tr -d '"')

if [ -z "$OWNER_ACCOUNT" ]; then
    echo "Error: Missing account_address in owner identity file"
    exit 1
fi

# Function to derive delegated resource account (same as update_validator_set_staking.sh)
derive_delegated_resource_account() {
    # Find the aptos binary
    local APTOS_CMD="aptos"
    if [ -f "./aptos" ]; then
        APTOS_CMD="./aptos"
    elif [ -f "../../aptos" ]; then
        APTOS_CMD="../../aptos"
    elif [ -f "../aptos" ]; then
        APTOS_CMD="../aptos"
    fi
    
    echo "Deriving delegated pool resource-account address..."
    local output
    output=$($APTOS_CMD account derive-resource-account-address \
        --address "$OWNER_ACCOUNT" \
        --seed "$DELEGATION_SEED" \
        --seed-encoding utf8 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to derive resource account address for delegated pool"
        echo "$output"
        exit 1
    fi
    
    DELEGATED_RESOURCE_ACCOUNT=$(echo "$output" | jq -r '.Result')
    
    if [ -z "$DELEGATED_RESOURCE_ACCOUNT" ]; then
        echo "Error: Failed to parse delegated resource account from CLI output"
        echo "$output"
        exit 1
    fi
    
    echo "Derived delegated resource account: $DELEGATED_RESOURCE_ACCOUNT"
}

# Derive the pool address
derive_delegated_resource_account

echo ""
echo "=========================================="
echo "Updating Validator Network Addresses"
echo "=========================================="
echo "Operator Account:  $VN_ACCOUNT"
echo "Owner Account:     $OWNER_ACCOUNT"
echo "Pool Address:      $DELEGATED_RESOURCE_ACCOUNT"
echo "Validator Host:    $VALIDATOR_HOST"
echo "Fullnode Host:     $FULLNODE_HOST"
echo "Network URL:       $NETWORK_URL"
echo ""

# Function to extract network public key (same as update_validator_set_staking.sh)
get_network_pub_key() {
    local private_key="$1"
    local temp_file
    temp_file=$(mktemp)
    
    # Find the aptos binary - could be in current dir or parent dirs
    APTOS_CLI="aptos"
    if [ -f "./aptos" ]; then
        APTOS_CLI="./aptos"
    elif [ -f "../../aptos" ]; then
        APTOS_CLI="../../aptos"
    elif [ -f "../aptos" ]; then
        APTOS_CLI="../aptos"
    fi
    
    $APTOS_CLI key extract-public-key \
        --private-key "$private_key" \
        --key-type "x25519" \
        --encoding hex \
        --output-file "$temp_file" \
        --assume-yes >/dev/null 2>&1
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        rm -f "$temp_file" "${temp_file}.pub"
        echo ""
        return 1
    fi
    
    local public_key
    public_key=$(cat "${temp_file}.pub")
    rm -f "$temp_file" "${temp_file}.pub"
    
    echo "$public_key"
}

# Extract network public key
echo "Extracting network public key..."
NETWORK_PUBLIC_KEY=$(get_network_pub_key "$VN_NETWORK_PRIVATE_KEY")
VFN_NETWORK_PUBLIC_KEY=$(get_network_pub_key "$VFN_NETWORK_PRIVATE_KEY")

if [ -z "$NETWORK_PUBLIC_KEY" ]; then
    echo "Error: Failed to extract network public key"
    echo "This may be due to:"
    echo "  1. Invalid private key format"
    echo "  2. Missing aptos CLI or wrong version"
    echo "  3. Incorrect key type"
    exit 1
fi

echo "Network Public Key: ${NETWORK_PUBLIC_KEY:0:32}..."
echo ""

# Determine aptos CLI path for the update command
APTOS_CLI="aptos"
if [ -f "./aptos" ]; then
    APTOS_CLI="./aptos"
elif [ -f "../../aptos" ]; then
    APTOS_CLI="../../aptos"
elif [ -f "../aptos" ]; then
    APTOS_CLI="../aptos"
fi

# Update validator and fullnode addresses
echo "Updating network addresses..."
echo "Validator host: $VALIDATOR_HOST"
echo "Full node host: $FULLNODE_HOST"
echo "Network public key: ${NETWORK_PUBLIC_KEY:0:32}..."
echo ""

$APTOS_CLI node update-validator-network-addresses \
    --pool-address "$DELEGATED_RESOURCE_ACCOUNT" \
    --validator-host "$VALIDATOR_HOST" \
    --validator-network-public-key "$NETWORK_PUBLIC_KEY" \
    --full-node-host "$FULLNODE_HOST" \
    --full-node-network-public-key "$VFN_NETWORK_PUBLIC_KEY" \
    --private-key "$VN_ACCOUNT_PRIVATE_KEY" \
    --url "$NETWORK_URL" \
    --assume-yes

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "SUCCESS: Network addresses updated"
    echo "=========================================="
    echo "Validator: $VALIDATOR_HOST"
    echo "Fullnode:  $FULLNODE_HOST"
    echo "The changes will take effect in the next epoch"
else
    echo ""
    echo "ERROR: Failed to update fullnode address"
    exit 1
fi
