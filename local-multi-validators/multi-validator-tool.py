#!/usr/bin/env python3
"""
Multi-Validator Tool
"""

import argparse
import os
import subprocess
import sys
import shutil
import yaml

def _check_current_folder():
    """Check if we're in aptos-core or its subfolder and navigate to aptos-core"""
    current_dir = os.getcwd()
    
    # Check if we're already in aptos-core
    if os.path.basename(current_dir) == "aptos-core":
        return current_dir
    
    # Check if we're in a subfolder of aptos-core
    while current_dir != "/":
        if os.path.basename(current_dir) == "aptos-core":
            os.chdir(current_dir)
            return current_dir
        current_dir = os.path.dirname(current_dir)
    
    # Look for aptos-core in current directory or parent directories
    current_dir = os.getcwd()
    while current_dir != "/":
        aptos_core_path = os.path.join(current_dir, "aptos-core")
        if os.path.isdir(aptos_core_path):
            os.chdir(aptos_core_path)
            return aptos_core_path
        current_dir = os.path.dirname(current_dir)
    
    raise Exception("Cannot find aptos-core directory")

def _load_aptos_cli():
    """Load or build aptos CLI binary"""
    aptos_core_dir = _check_current_folder()
    aptos_path = os.path.join(aptos_core_dir, "target", "release", "aptos")
    
    if os.path.exists(aptos_path):
        print(f"Found aptos CLI at: {aptos_path}")
        return aptos_path
    
    print("Building aptos CLI...")
    try:
        subprocess.run(["cargo", "build", "--release", "--bin", "aptos"], 
                      cwd=aptos_core_dir, check=True)
        print(f"Built aptos CLI at: {aptos_path}")
        return aptos_path
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to build aptos CLI: {e}")

def _load_aptos_node():
    """Load or build aptos-node binary"""
    aptos_core_dir = _check_current_folder()
    aptos_node_path = os.path.join(aptos_core_dir, "target", "release", "aptos-node")
    
    if os.path.exists(aptos_node_path):
        print(f"Found aptos-node at: {aptos_node_path}")
        return aptos_node_path
    
    print("Building aptos-node...")
    try:
        subprocess.run(["cargo", "build", "--release", "--bin", "aptos-node"], 
                      cwd=aptos_core_dir, check=True)
        print(f"Built aptos-node at: {aptos_node_path}")
        return aptos_node_path
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to build aptos-node: {e}")

def _load_framework_mrb():
    """Load or build framework.mrb"""
    aptos_core_dir = _check_current_folder()
    framework_path = os.path.join(aptos_core_dir, "aptos-move", "framework", "cached-packages", "framework.mrb")
    
    if os.path.exists(framework_path):
        print(f"Found framework.mrb at: {framework_path}")
        return framework_path
    
    print("Building framework.mrb...")
    try:
        # Build aptos-framework binary
        subprocess.run(["cargo", "build", "--release", "--package", "aptos-framework"], 
                      cwd=aptos_core_dir, check=True)
        
        # Run aptos-framework release to generate head.mrb
        aptos_framework_path = os.path.join(aptos_core_dir, "target", "release", "aptos-framework")
        subprocess.run([aptos_framework_path, "release"], 
                      cwd=aptos_core_dir, check=True)
        
        # Find head.mrb in aptos-core root directory
        head_mrb_path = os.path.join(aptos_core_dir, "head.mrb")
        if os.path.exists(head_mrb_path):
            # Create cached-packages directory if it doesn't exist
            cached_packages_dir = os.path.dirname(framework_path)
            os.makedirs(cached_packages_dir, exist_ok=True)
            
            # Copy head.mrb to framework.mrb
            shutil.copy2(head_mrb_path, framework_path)
            print(f"Built framework.mrb at: {framework_path}")
            return framework_path
        else:
            raise Exception("head.mrb was not created after running aptos-framework release")
    except subprocess.CalledProcessError as e:
        raise Exception(f"Failed to build framework.mrb: {e}")

def load():
    """Load aptos CLI, aptos-node binaries, and framework.mrb"""
    try:
        aptos_cli = _load_aptos_cli()
        aptos_node = _load_aptos_node()
        framework_mrb = _load_framework_mrb()
        print("\nSuccessfully loaded:")
        print(f"  aptos CLI: {aptos_cli}")
        print(f"  aptos-node: {aptos_node}")
        print(f"  framework.mrb: {framework_mrb}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def bootstrap_network(chain_id, prepare_only=False):
    """Bootstrap a new multi-validator network"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_cli = _load_aptos_cli()
        aptos_node = _load_aptos_node()
        framework_mrb = _load_framework_mrb()
        
        # Create local-multi-validators directory
        network_dir = os.path.join(aptos_core_dir, "local-multi-validators")
        data_dir = os.path.join(network_dir, "data")
        
        print(f"Creating multi-validator network with chain ID {chain_id}...")
        
        # Clean up existing data
        print("Cleaning up existing data...")
        if os.path.exists(data_dir):
            shutil.rmtree(data_dir)
        os.makedirs(data_dir, exist_ok=True)
        
        # 1. Generate node identities
        print("1. Generating node identities...")
        validator_dir = os.path.join(data_dir, "0")
        os.makedirs(validator_dir, exist_ok=True)
        
        # Generate validator keys (with assume-yes)
        subprocess.run([
            aptos_cli, "genesis", "generate-keys", 
            "--output-dir", validator_dir,
            "--assume-yes"
        ], check=True)
        
        # Configure validator information
        subprocess.run([
            aptos_cli, "genesis", "set-validator-configuration",
            "--local-repository-dir", data_dir,
            "--username", "validator-0",
            "--owner-public-identity-file", os.path.join(validator_dir, "public-keys.yaml"),
            "--validator-host", "127.0.0.1:6180",
            "--stake-amount", "50000000000000000"
        ], check=True)
        
        # Copy framework.mrb to data directory
        framework_dest = os.path.join(data_dir, "framework.mrb")
        shutil.copy2(framework_mrb, framework_dest)
        
        # 2. Generate genesis and waypoint
        print("2. Generating genesis and waypoint...")
        
        # Generate root key
        root_key_path = os.path.join(data_dir, "root.key")
        subprocess.run([
            aptos_cli, "key", "generate",
            "--output-file", root_key_path
        ], check=True)
        
        # Generate layout template
        layout_path = os.path.join(data_dir, "layout.yaml")
        subprocess.run([
            aptos_cli, "genesis", "generate-layout-template",
            "--output-file", layout_path
        ], check=True)
        
        # Read the generated root public key
        root_pub_key_path = root_key_path + ".pub"
        with open(root_pub_key_path, "r") as f:
            root_public_key = f.read().strip()
        
        # Update layout with our specific chain_id, users, and root_key
        import re
        with open(layout_path, "r") as f:
            layout_content = f.read()
        
        # Replace values with our settings
        layout_content = re.sub(r'chain_id: \d+', f'chain_id: {chain_id}', layout_content)
        layout_content = layout_content.replace('users: []', 'users: ["validator-0"]')
        layout_content = layout_content.replace('root_key: ~', f'root_key: "{root_public_key}"')
        layout_content = re.sub(r'epoch_duration_secs: \d+', 'epoch_duration_secs: 120', layout_content)
        layout_content = layout_content.replace('total_supply: ~', 'total_supply: 18000000000000000000')  # 18 quintillion APT (safe u64)
        
        with open(layout_path, "w") as f:
            f.write(layout_content)
        
        # Generate genesis
        subprocess.run([
            aptos_cli, "genesis", "generate-genesis",
            "--local-repository-dir", data_dir,
            "--output-dir", data_dir
        ], check=True)
        
        # Fix permissions for genesis files and identity files
        genesis_blob_path = os.path.join(data_dir, "genesis.blob")
        waypoint_path = os.path.join(data_dir, "waypoint.txt")
        validator_identity_path = os.path.join(validator_dir, "validator-identity.yaml")
        validator_full_node_identity_path = os.path.join(validator_dir, "validator-full-node-identity.yaml")
        
        os.chmod(genesis_blob_path, 0o644)
        os.chmod(waypoint_path, 0o644)
        os.chmod(validator_identity_path, 0o644)
        os.chmod(validator_full_node_identity_path, 0o644)
        
        # 3. Create validator node configuration for raw binary execution
        print("3. Creating validator configuration...")
        
        # Create absolute paths for the binary configuration
        node_data_dir = os.path.join(validator_dir, "node-data")
        os.makedirs(node_data_dir, exist_ok=True)
        
        # Set ports for validator-0 (avoid 9101 which is used by dart)
        admin_port = 9103
        
        # Create validator config for raw binary execution
        validator_config = f"""base:
  role: "validator"
  data_dir: "{node_data_dir}"
  waypoint:
    from_file: "{waypoint_path}"

consensus:
  sync_only: false
  vote_back_pressure_limit: 999999
  safety_rules:
    service:
      type: "local"
    backend:
      type: "on_disk_storage"
      path: secure-data.json
      namespace: ~
    initial_safety_rules_config:
      from_file:
        waypoint:
          from_file: {waypoint_path}
        identity_blob_path: {validator_identity_path}

execution:
  genesis_file_location: "{genesis_blob_path}"

storage:
  rocksdb_configs:
    enable_storage_sharding: false

validator_network:
  discovery_method: "none"
  mutual_authentication: true
  identity:
    type: "from_file"
    path: {validator_identity_path}

full_node_networks:
- network_id:
    private: "vfn"
  listen_address: "/ip4/0.0.0.0/tcp/6181"
  identity:
    type: "from_file"
    path: {validator_full_node_identity_path}

api:
  enabled: true
  address: "0.0.0.0:8080"

admin_service:
  enabled: true
  address: "127.0.0.1"
  port: {admin_port}

inspection_service:
  address: "127.0.0.1"
  port: {admin_port + 1}

state_sync:
  state_sync_driver:
    bootstrapping_mode: ExecuteOrApplyFromGenesis
    continuous_syncing_mode: ExecuteTransactionsOrApplyOutputs
    enable_auto_bootstrapping: true
    max_connection_deadline_secs: 1
"""
        
        # Put validator.yaml directly in the validator directory (0/)
        validator_config_path = os.path.join(validator_dir, "validator.yaml")
        with open(validator_config_path, "w") as f:
            f.write(validator_config)
        
        # Create startup script in the validator directory too
        startup_script_path = os.path.join(validator_dir, "start-validator.sh")
        startup_script = f"""#!/bin/bash
# Startup script for validator-0

APTOS_NODE_PATH="{aptos_node}"
CONFIG_PATH="{validator_config_path}"

echo "Starting validator-0..."
echo "Config: $CONFIG_PATH"
echo "Binary: $APTOS_NODE_PATH"

exec "$APTOS_NODE_PATH" -f "$CONFIG_PATH"
"""
        
        with open(startup_script_path, "w") as f:
            f.write(startup_script)
        os.chmod(startup_script_path, 0o755)
        
        if not prepare_only:
            print("4. Network is ready. Use 'start-node' command to run validators.")
        else:
            print("4. Configuration complete - ready for manual startup.")
        
        print(f"\\nBootstrap complete!")
        print(f"Chain ID: {chain_id}")
        print(f"Configuration directory: {data_dir}")
        print(f"Validator config: {validator_config_path}")
        print(f"Start script: {startup_script_path}")
        print(f"\\nTo start validator manually:")
        print(f"  {aptos_node} -f {validator_config_path}")
        print(f"\\nOr use the startup script:")
        print(f"  {startup_script_path}")
        print(f"\\nOnce running:")
        print(f"API: http://127.0.0.1:8080/v1")
        print(f"Admin: http://127.0.0.1:9102/metrics")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def stop():
    """Stop all validators and clean up generated files"""
    try:
        aptos_core_dir = _check_current_folder()
        network_dir = os.path.join(aptos_core_dir, "local-multi-validators")
        
        print("Stopping validators and cleaning up...")
        
        # Kill any running aptos-node processes
        try:
            print("Looking for running aptos-node processes...")
            result = subprocess.run(["pgrep", "-f", "aptos-node"], capture_output=True, text=True)
            if result.stdout.strip():
                pids = result.stdout.strip().split('\n')
                print(f"Found {len(pids)} aptos-node processes, stopping them...")
                for pid in pids:
                    subprocess.run(["kill", pid], check=False)
                print("Stopped aptos-node processes")
            else:
                print("No running aptos-node processes found")
        except Exception as e:
            print(f"Warning: Could not check/stop aptos-node processes: {e}")
        
        # Stop docker containers if they exist (for backward compatibility)
        if os.path.exists(os.path.join(network_dir, "docker-compose.yml")):
            print("Stopping Docker containers...")
            try:
                subprocess.run([
                    "docker", "compose", "down"
                ], cwd=network_dir, check=True)
                print("Docker containers stopped.")
            except subprocess.CalledProcessError:
                print("Warning: Could not stop Docker containers (may not be running)")
        
        # Remove generated files but keep the tool and binaries
        files_to_remove = [
            "docker-compose.yml",
            "docker-data",
            "data",
            "aptos.yaml"  # in case it exists
        ]
        
        for item in files_to_remove:
            item_path = os.path.join(network_dir, item)
            if os.path.exists(item_path):
                if os.path.isdir(item_path):
                    print(f"Removing directory: {item}")
                    shutil.rmtree(item_path)
                else:
                    print(f"Removing file: {item}")
                    os.remove(item_path)
        
        print("Cleanup complete! Kept:")
        print("  - multi-validator-tool.py")
        print("  - Dockerfile")
        print("  - docker-compose.yml.template")
        
    except Exception as e:
        print(f"Error during cleanup: {e}")
        sys.exit(1)

def _get_next_validator_index():
    """Get the next available validator index by checking existing validator folders"""
    try:
        aptos_core_dir = _check_current_folder()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        
        if not os.path.exists(data_dir):
            return 0  # No network exists yet
        
        max_index = -1
        for item in os.listdir(data_dir):
            if os.path.isdir(os.path.join(data_dir, item)) and item.isdigit():
                try:
                    index = int(item)
                    max_index = max(max_index, index)
                except ValueError:
                    continue
        
        return max_index + 1
    except Exception:
        return 0

def _generate_validator_identities(validator_index):
    """Generate keys and identities for a new validator"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_cli = _load_aptos_cli()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        
        if not os.path.exists(data_dir):
            raise Exception("No existing network found. Please run bootstrap-network first.")
        
        print(f"Generating identities for validator-{validator_index}...")
        
        # Create validator directory using numeric naming
        validator_dir = os.path.join(data_dir, str(validator_index))
        os.makedirs(validator_dir, exist_ok=True)
        
        # Generate validator keys
        subprocess.run([
            aptos_cli, "genesis", "generate-keys", 
            "--output-dir", validator_dir,
            "--assume-yes"
        ], check=True)
        
        # Generate operator.yaml and owner.yaml
        consensus_port = 6180 + validator_index * 4
        subprocess.run([
            aptos_cli, "genesis", "set-validator-configuration",
            "--local-repository-dir", data_dir,
            "--username", f"validator-{validator_index}",
            "--owner-public-identity-file", os.path.join(validator_dir, "public-keys.yaml"),
            "--validator-host", f"127.0.0.1:{consensus_port}",
            "--stake-amount", "50000000000000000"
        ], check=True)
        
        # Fix permissions for all generated files
        validator_identity_path = os.path.join(validator_dir, "validator-identity.yaml")
        validator_full_node_identity_path = os.path.join(validator_dir, "validator-full-node-identity.yaml")
        public_keys_path = os.path.join(validator_dir, "public-keys.yaml")
        private_keys_path = os.path.join(validator_dir, "private-keys.yaml")
        operator_yaml_path = os.path.join(validator_dir, "operator.yaml")
        owner_yaml_path = os.path.join(validator_dir, "owner.yaml")
        
        os.chmod(validator_identity_path, 0o644)
        os.chmod(validator_full_node_identity_path, 0o644)
        os.chmod(public_keys_path, 0o644)
        os.chmod(private_keys_path, 0o644)
        os.chmod(operator_yaml_path, 0o644)
        os.chmod(owner_yaml_path, 0o644)
        
        # Create validator config for this validator
        aptos_node = _load_aptos_node()
        genesis_blob_path = os.path.join(data_dir, "genesis.blob")
        waypoint_path = os.path.join(data_dir, "waypoint.txt")
        
        # Create node data directory
        node_data_dir = os.path.join(validator_dir, "node-data")
        os.makedirs(node_data_dir, exist_ok=True)
        
        # Calculate ports for this validator (admin_port base is 9103 to avoid dart on 9101)
        api_port = 8080 + validator_index * 10
        admin_port = 9103 + validator_index * 10
        vfn_port = 6181 + validator_index * 10
        
        validator_config = f"""base:
  role: "validator"
  data_dir: "{node_data_dir}"
  waypoint:
    from_file: "{waypoint_path}"

consensus:
  sync_only: false
  vote_back_pressure_limit: 999999
  safety_rules:
    service:
      type: "local"
    backend:
      type: "on_disk_storage"
      path: secure-data.json
      namespace: ~
    initial_safety_rules_config:
      from_file:
        waypoint:
          from_file: {waypoint_path}
        identity_blob_path: {validator_identity_path}

execution:
  genesis_file_location: "{genesis_blob_path}"

storage:
  rocksdb_configs:
    enable_storage_sharding: false

validator_network:
  discovery_method: "none"
  mutual_authentication: true
  identity:
    type: "from_file"
    path: {validator_identity_path}

full_node_networks:
- network_id:
    private: "vfn"
  listen_address: "/ip4/0.0.0.0/tcp/{vfn_port}"
  identity:
    type: "from_file"
    path: {validator_full_node_identity_path}

api:
  enabled: true
  address: "0.0.0.0:{api_port}"

admin_service:
  enabled: true
  address: "127.0.0.1"
  port: {admin_port}

inspection_service:
  address: "127.0.0.1"
  port: {admin_port + 1}

state_sync:
  state_sync_driver:
    bootstrapping_mode: ExecuteOrApplyFromGenesis
    continuous_syncing_mode: ExecuteTransactionsOrApplyOutputs
    enable_auto_bootstrapping: true
    max_connection_deadline_secs: 1
"""
        
        # Write validator config to the validator directory
        validator_config_path = os.path.join(validator_dir, "validator.yaml")
        with open(validator_config_path, "w") as f:
            f.write(validator_config)
        
        # Create startup script
        startup_script_path = os.path.join(validator_dir, "start-validator.sh")
        startup_script = f"""#!/bin/bash
# Startup script for validator-{validator_index}

APTOS_NODE_PATH="{aptos_node}"
CONFIG_PATH="{validator_config_path}"

echo "Starting validator-{validator_index}..."
echo "Config: $CONFIG_PATH"
echo "Binary: $APTOS_NODE_PATH"

exec "$APTOS_NODE_PATH" -f "$CONFIG_PATH"
"""
        
        with open(startup_script_path, "w") as f:
            f.write(startup_script)
        os.chmod(startup_script_path, 0o755)
        
        print(f"Created validator config: {validator_config_path}")
        print(f"API will be available on: http://127.0.0.1:{api_port}")
        print(f"Admin will be available on: http://127.0.0.1:{admin_port}")
        
        # Read and return the account address
        with open(public_keys_path, "r") as f:
            keys_data = yaml.safe_load(f)
            account_address = keys_data['account_address']
            
        print(f"Generated validator-{validator_index} with account address: {account_address}")
        return account_address
        
    except Exception as e:
        raise Exception(f"Failed to generate validator identities: {e}")

def _fund_validator(account_address, amount="1100000000000000"):
    """Fund validator account using root key"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_cli = _load_aptos_cli()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        root_key_path = os.path.join(data_dir, "root.key")
        
        if not os.path.exists(root_key_path):
            raise Exception("Root key not found. Please run bootstrap-network first.")
        
        print(f"Funding account {account_address} with {amount} APT...")
        
        # Mint APT coins directly using root authority
        subprocess.run([
            aptos_cli, "move", "run",
            "--private-key-file", root_key_path,
            "--function-id", "0x1::aptos_coin::mint",
            "--args", f"address:{account_address}", f"u64:{amount}",
            "--url", "http://127.0.0.1:8080",
            "--gas-unit-price", "100",
            "--max-gas", "2000000",
            "--assume-yes"
        ], check=True)
        
        print(f"Successfully funded account {account_address}")
        
    except Exception as e:
        raise Exception(f"Failed to fund validator account: {e}")

def _join_validator(validator_index, account_address):
    """Join validator to the active validator set"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_cli = _load_aptos_cli()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        validator_dir = os.path.join(data_dir, str(validator_index))
        
        private_keys_path = os.path.join(validator_dir, "private-keys.yaml")
        operator_config_path = os.path.join(validator_dir, "operator.yaml")
        
        if not os.path.exists(private_keys_path) or not os.path.exists(operator_config_path):
            raise Exception(f"Validator {validator_index} keys or config not found")
        
        print(f"Joining validator-{validator_index} to the validator set...")
        
        # Extract private key from private-keys.yaml
        with open(private_keys_path, "r") as f:
            private_keys_data = yaml.safe_load(f)
            account_private_key = private_keys_data['account_private_key']
        
        # 1. Initialize validator
        print("1. Initializing validator...")
        subprocess.run([
            aptos_cli, "stake", "initialize-validator",
            "--private-key", account_private_key,
            "--operator-config-file", operator_config_path,
            "--url", "http://127.0.0.1:8080",
            "--assume-yes"
        ], check=True)
        
        # 2. Add stake
        print("2. Adding stake...")
        subprocess.run([
            aptos_cli, "stake", "add-stake",
            "--private-key", account_private_key,
            "--amount", "100000000000000",  # 1M APT
            "--url", "http://127.0.0.1:8080",
            "--assume-yes"
        ], check=True)
        
        # 3. Join validator set
        print("3. Joining validator set...")
        subprocess.run([
            aptos_cli, "stake", "join-validator-set",
            "--private-key", account_private_key,
            "--url", "http://127.0.0.1:8080",
            "--assume-yes"
        ], check=True)
        
        print(f"Validator-{validator_index} successfully joined! Will be active in next epoch.")
        
    except Exception as e:
        raise Exception(f"Failed to join validator set: {e}")

def add_validator():
    """Add a new validator to the existing network"""
    try:
        validator_index = _get_next_validator_index()
        print(f"Validator to add is {validator_index}")
        
        # 1. Generate identities and keys
        account_address = _generate_validator_identities(validator_index)
        print(f"Validator account address: {account_address}")
        
        # 2. Fund the validator account
        _fund_validator(account_address)
        
        # 3. Join the validator set
        _join_validator(validator_index, account_address)
        
        print(f"\nValidator-{validator_index} setup complete!")
        print(f"Account: {account_address}")
        print(f"Status: Will join active validator set in next epoch")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def prepare_network(chain_id):
    """Prepare network configuration without starting nodes"""
    bootstrap_network(chain_id, prepare_only=True)

def start_node(validator_index=None):
    """Start a specific validator node or all nodes"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_node = _load_aptos_node()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        
        if not os.path.exists(data_dir):
            raise Exception("No network configuration found. Please run prepare-network or bootstrap-network first.")
        
        if validator_index is not None:
            # Start specific validator
            validator_dir = os.path.join(data_dir, str(validator_index))
            config_path = os.path.join(validator_dir, "validator.yaml")
            
            if not os.path.exists(config_path):
                raise Exception(f"Validator {validator_index} configuration not found at {config_path}")
            
            print(f"Starting validator-{validator_index}...")
            print(f"Config: {config_path}")
            print(f"Command: {aptos_node} -f {config_path}")
            print("\nPress Ctrl+C to stop the validator\n")
            
            subprocess.run([aptos_node, "-f", config_path])
        else:
            # List all available validators
            validators = []
            for item in os.listdir(data_dir):
                if os.path.isdir(os.path.join(data_dir, item)) and item.isdigit():
                    validators.append(item)
            
            if not validators:
                raise Exception("No validator configurations found")
            
            print("Available validators:")
            for validator in sorted(validators, key=int):
                config_path = os.path.join(data_dir, validator, "validator.yaml")
                startup_script = os.path.join(data_dir, validator, "start-validator.sh")
                print(f"  validator-{validator}:")
                print(f"    Config: {config_path}")
                print(f"    Startup script: {startup_script}")
                print(f"    Manual command: {aptos_node} -f {config_path}")
            
            print(f"\nTo start a specific validator, use: python3 {sys.argv[0]} start-node <validator_index>")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

def list_configs():
    """List all validator configurations and startup commands"""
    try:
        aptos_core_dir = _check_current_folder()
        aptos_node = _load_aptos_node()
        data_dir = os.path.join(aptos_core_dir, "local-multi-validators", "data")
        
        if not os.path.exists(data_dir):
            print("No network configuration found. Please run prepare-network or bootstrap-network first.")
            return
        
        validators = []
        for item in os.listdir(data_dir):
            if os.path.isdir(os.path.join(data_dir, item)) and item.isdigit():
                validators.append(item)
        
        if not validators:
            print("No validator configurations found")
            return
        
        print("Validator configurations:")
        print(f"Binary: {aptos_node}")
        print()
        
        for validator in sorted(validators, key=int):
            validator_dir = os.path.join(data_dir, validator)
            config_path = os.path.join(validator_dir, "validator.yaml")
            startup_script = os.path.join(validator_dir, "start-validator.sh")
            
            if os.path.exists(config_path):
                print(f"validator-{validator}:")
                print(f"  Config: {config_path}")
                if os.path.exists(startup_script):
                    print(f"  Startup script: {startup_script}")
                print(f"  Manual command: {aptos_node} -f {config_path}")
                print()
            
    except Exception as e:
        print(f"Error: {e}")

def main():
    parser = argparse.ArgumentParser(description="Multi-Validator Tool")
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Load command
    subparsers.add_parser("load", help="Load aptos CLI and aptos-node binaries")
    
    # Bootstrap network command (creates and optionally starts)
    bootstrap_parser = subparsers.add_parser("bootstrap-network", help="Bootstrap a new multi-validator network")
    bootstrap_parser.add_argument("chain_id", type=int, help="Chain ID for the network")
    
    # Prepare network command (creates but doesn't start)
    prepare_parser = subparsers.add_parser("prepare-network", help="Prepare network configuration without starting nodes")
    prepare_parser.add_argument("chain_id", type=int, help="Chain ID for the network")
    
    # Start node command
    start_parser = subparsers.add_parser("start-node", help="Start validator node(s)")
    start_parser.add_argument("validator_index", type=int, nargs='?', help="Validator index to start (optional)")
    
    # List configs command
    subparsers.add_parser("list-configs", help="List all validator configurations and startup commands")
    
    # Stop command
    subparsers.add_parser("stop", help="Stop validators and clean up generated files")
    
    # Add validator command
    subparsers.add_parser("add-validator", help="Add a new validator to the network")
    
    args = parser.parse_args()
    
    if args.command == "load":
        load()
    elif args.command == "bootstrap-network":
        bootstrap_network(args.chain_id)
    elif args.command == "prepare-network":
        prepare_network(args.chain_id)
    elif args.command == "start-node":
        start_node(args.validator_index)
    elif args.command == "list-configs":
        list_configs()
    elif args.command == "stop":
        stop()
    elif args.command == "add-validator":
        add_validator()
    else:
        parser.print_help()

if __name__ == "__main__":
    main()