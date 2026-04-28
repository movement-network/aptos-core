//! One-shot helper: print wire bytes for `difftest_registration_helpers::registration_roundtrip_vm`
//! (chain_id=9, @0x1/@0x2/@0x3, dk=42, k=9999). Run from repo root:
//! `cargo run -p move-lean-difftest --bin print-difftest-registration-wire`
//!
//! Output: Rust `hex::encode` lines consumed when updating Lean `TranscriptAlignment.lean`.

use curve25519_dalek_ng::ristretto::{CompressedRistretto, RistrettoPoint};
use curve25519_dalek_ng::scalar::Scalar;
use sha2::{Digest, Sha512};

/// `ristretto255::HASH_BASE_POINT` in `aptos-move/framework/aptos-stdlib/sources/cryptography/ristretto255.move`.
const HASH_BASE_POINT: [u8; 32] = [
    0x8c, 0x92, 0x40, 0xb4, 0x56, 0xa9, 0xe6, 0xdc, 0x65, 0xc3, 0x77, 0xa1, 0x04, 0x8d, 0x74, 0x5f,
    0x94, 0xa0, 0x8c, 0xdb, 0x7f, 0x44, 0xcb, 0xcd, 0x7b, 0x46, 0xf3, 0x40, 0x48, 0x87, 0x11, 0x34,
];

fn h_point() -> RistrettoPoint {
    CompressedRistretto(HASH_BASE_POINT)
        .decompress()
        .expect("HASH_BASE_POINT decompress")
}

fn sha2_512(data: &[u8]) -> [u8; 64] {
    let mut h = Sha512::new();
    h.update(data);
    h.finalize().into()
}

fn new_scalar_from_sha2_512(input: &[u8]) -> Scalar {
    let h = sha2_512(input);
    Scalar::from_bytes_mod_order_wide(&h)
}

/// `FIAT_SHAMIR_REGISTRATION_SIGMA_DST` in `difftest_registration_helpers.move`.
const FS_DST: &[u8] = b"MovementConfidentialAsset/Registration";

fn main() {
    let h = h_point();

    let dk = Scalar::from(42u64);
    let dk_inv = dk.invert();
    assert_ne!(dk_inv, Scalar::from(0u64), "dk invert");
    let ek_pt = dk_inv * h;
    let ek_compressed = ek_pt.compress();
    let ek_bytes = ek_compressed.to_bytes();

    let k = Scalar::from(9999u64);
    let r_pt = k * h;
    let r_compressed = r_pt.compress();
    let commitment_bytes = r_compressed.to_bytes();

    // FS message: DST || chain_id || sender || contract || token || ek || R
    let mut msg = Vec::new();
    msg.extend_from_slice(FS_DST);
    msg.push(9u8);
    msg.extend_from_slice(&addr_bcs(1));
    msg.extend_from_slice(&addr_bcs(2));
    msg.extend_from_slice(&addr_bcs(3));
    msg.extend_from_slice(&ek_bytes);
    msg.extend_from_slice(&commitment_bytes);

    let e = new_scalar_from_sha2_512(&msg);
    let s = k - e * dk_inv;

    let response_bytes = s.to_bytes();
    let e_bytes = e.to_bytes();

    println!("ek_bytes_hex = \"{}\"", hex::encode(ek_bytes));
    println!(
        "commitment_bytes_hex = \"{}\"",
        hex::encode(commitment_bytes)
    );
    println!(
        "response_scalar_bytes_hex = \"{}\"",
        hex::encode(response_bytes)
    );
    println!(
        "challenge_e_scalar_bytes_hex = \"{}\"",
        hex::encode(e_bytes)
    );

    // Sanity: re-verify Schnorr on curve (same as Move assert)
    let rhs = r_pt;
    let lhs = s * h + e * ek_pt;
    assert_eq!(lhs, rhs, "Schnorr equation should hold");
}

fn addr_bcs(last: u8) -> [u8; 32] {
    let mut a = [0u8; 32];
    a[31] = last;
    a
}
