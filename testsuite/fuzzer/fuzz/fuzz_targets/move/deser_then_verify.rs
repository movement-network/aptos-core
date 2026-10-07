// Fuzz the exact on-chain validation path: raw bytes → deserialize → verify.
//
// This matches what a validator does when it receives a module publish transaction:
// 1. CompiledModule::deserialize_with_config (binary format parsing)
// 2. verify_module_with_config (bytecode verification)
//
// Any crash here = on-chain exploitable DoS.
// An invariant violation in step 2 = validator halt.

#![no_main]
use aptos_types::on_chain_config::Features;
use aptos_vm_environment::prod_configs;
use libfuzzer_sys::{fuzz_target, Corpus};
use move_binary_format::{
    deserializer::DeserializerConfig,
    errors::VMError,
    CompiledModule,
};
use move_core_types::vm_status::StatusType;

mod utils;

// Invariant violations in the verifier are bugs — they halt validators.
fn check_invariant_violation(e: &VMError) {
    if e.status_type() == StatusType::InvariantViolation {
        let empty = String::new();
        let msg = e.message().unwrap_or(&empty);
        // Filter known false positives
        if msg.starts_with("too many type parameters/arguments in the program") {
            return;
        }
        panic!(
            "VERIFIER INVARIANT VIOLATION from deserialized module: {:?}",
            e
        );
    }
}

fuzz_target!(|data: &[u8]| -> Corpus {
    // Step 1: Deserialize raw bytes as a CompiledModule.
    // This is the binary format parser — the first gate on the network.
    let deserializer_config = DeserializerConfig::new(8, 255);
    let module = match CompiledModule::deserialize_with_config(data, &deserializer_config) {
        Ok(m) => m,
        Err(_) => return Corpus::Reject, // Deserialization failed = network rejects it too
    };

    // Step 2: Run the bytecode verifier with production config.
    // Anything that passes step 1 and crashes step 2 = on-chain exploitable.
    let verifier_config = prod_configs::aptos_prod_verifier_config(&Features::default());
    if let Err(e) = move_bytecode_verifier::verify_module_with_config(&verifier_config, &module) {
        check_invariant_violation(&e);
        // Normal verification errors are fine — the network rejects these gracefully.
        return Corpus::Keep;
    }

    // Module passed both deserializer AND verifier from raw bytes.
    // This is a valid on-chain module. Keep it for mutation.
    Corpus::Keep
});
