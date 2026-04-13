//! Static **hex corpora** checks for `corpora/confidential_assets/` (registration FS, tagged SHA3-512,
//! Bulletproofs DST, sigma layout blobs, auditor serializer VM pins).
//!
//! Authoritative **byte-level** checks for those goldens (VM + Lean remain the semantic ground truth
//! for `lake exe difftest`).

use anyhow::{Context, Result};
use sha3::{Digest, Sha3_512};
use std::path::{Path, PathBuf};

const FIAT_SHAMIR_REGISTRATION_DST: &[u8] = b"MovementConfidentialAsset/Registration";
const BULLETPROOFS_DST: &[u8] = b"AptosConfidentialAsset/BulletproofRangeProof";
const RISTRETTO_A_POINT: [u8; 32] = [
    0xe8, 0x7f, 0xed, 0xa1, 0x99, 0xd7, 0x2b, 0x83, 0xde, 0x4f, 0x5b, 0x2d, 0x45, 0xd3, 0x48, 0x05,
    0xc5, 0x70, 0x19, 0xc6, 0xc5, 0x9c, 0x42, 0xcb, 0x70, 0xee, 0x3d, 0x19, 0xaa, 0x99, 0x6f, 0x75,
];

fn sha3_512(data: &[u8]) -> [u8; 64] {
    let mut h = Sha3_512::new();
    h.update(data);
    h.finalize().into()
}

/// Matches Move `tagged_hash` / Lean `taggedHash`: `sha3_512( sha3_512(dst)||sha3_512(dst)||msg )`.
fn tagged_hash_sha3_512(dst: &[u8], msg: &[u8]) -> [u8; 64] {
    let th = sha3_512(dst);
    let mut input = Vec::with_capacity(64 + 64 + msg.len());
    input.extend_from_slice(&th);
    input.extend_from_slice(&th);
    input.extend_from_slice(msg);
    sha3_512(&input)
}

fn deserialize_sigma_wire(ns: usize, np: usize) -> Vec<u8> {
    let mut v = vec![0u8; 32 * (ns + np)];
    for j in 0..np {
        let off = ns * 32 + j * 32;
        v[off..off + 32].copy_from_slice(&RISTRETTO_A_POINT);
    }
    v
}

fn read_hex_file(dir: &Path, name: &str) -> Result<Vec<u8>> {
    let p: PathBuf = dir.join(name);
    let text = std::fs::read_to_string(&p)
        .with_context(|| format!("read {}", p.display()))?
        .trim()
        .to_owned();
    hex::decode(&text).with_context(|| format!("hex-decode {}", p.display()))
}

/// Run all corpus checks. `corpora_dir` should be `…/difftest/corpora/confidential_assets`.
pub fn verify_corpora_in_dir(corpora_dir: &Path) -> Result<()> {
    let dst_file = read_hex_file(corpora_dir, "fiat_shamir_registration_dst.hex")?;
    anyhow::ensure!(
        dst_file == FIAT_SHAMIR_REGISTRATION_DST,
        "fiat_shamir_registration_dst.hex drift vs MovementConfidentialAsset/Registration"
    );
    eprintln!(
        "OK fiat_shamir_registration_dst.hex: {} bytes",
        dst_file.len()
    );

    for (hex_name, expected_len) in [
        ("registration_fs_msg_move_golden_1.hex", 161usize),
        ("registration_fs_msg_move_golden_2.hex", 161),
        ("registration_tagged_hash_golden_1.hex", 64),
        ("registration_tagged_hash_golden_2.hex", 64),
    ] {
        let data = read_hex_file(corpora_dir, hex_name)?;
        anyhow::ensure!(
            data.len() == expected_len,
            "{hex_name}: len {} expected {}",
            data.len(),
            expected_len
        );
        eprintln!("OK {hex_name}: {} bytes", data.len());
    }

    let msg = read_hex_file(corpora_dir, "registration_fs_msg_move_golden_1.hex")?;
    let tagged_file = read_hex_file(corpora_dir, "registration_tagged_hash_golden_1.hex")?;
    let tagged_calc = tagged_hash_sha3_512(FIAT_SHAMIR_REGISTRATION_DST, &msg);
    anyhow::ensure!(
        tagged_file.as_slice() == tagged_calc.as_slice(),
        "tagged hash mismatch vs registration_tagged_hash_golden_1.hex"
    );
    eprintln!("OK tagged SHA3-512(dst, msg) matches registration_tagged_hash_golden_1.hex");

    let msg2 = read_hex_file(corpora_dir, "registration_fs_msg_move_golden_2.hex")?;
    let tagged2_file = read_hex_file(corpora_dir, "registration_tagged_hash_golden_2.hex")?;
    let tagged2_calc = tagged_hash_sha3_512(FIAT_SHAMIR_REGISTRATION_DST, &msg2);
    anyhow::ensure!(
        tagged2_file.as_slice() == tagged2_calc.as_slice(),
        "tagged hash mismatch vs registration_tagged_hash_golden_2.hex"
    );
    eprintln!("OK tagged SHA3-512(dst, msg2) matches registration_tagged_hash_golden_2.hex");

    let bp_dst = read_hex_file(corpora_dir, "bulletproofs_dst.hex")?;
    anyhow::ensure!(
        bp_dst == BULLETPROOFS_DST,
        "bulletproofs_dst.hex drift vs Move BULLETPROOFS_DST"
    );
    eprintln!("OK bulletproofs_dst.hex: {} bytes", bp_dst.len());

    let bp_sha3_file = read_hex_file(corpora_dir, "bulletproofs_dst_sha3_512.hex")?;
    let bp_sha3_calc = sha3_512(&bp_dst);
    anyhow::ensure!(
        bp_sha3_file.as_slice() == bp_sha3_calc.as_slice(),
        "bulletproofs_dst_sha3_512.hex drift vs sha3_512(DST)"
    );
    anyhow::ensure!(bp_sha3_file.len() == 64);
    eprintln!("OK bulletproofs_dst_sha3_512.hex: 64 bytes");

    for (hex_name, ns, np, expected_len) in [
        (
            "deserialize_sigma_18_scalars_18_points.hex",
            18usize,
            18usize,
            1152usize,
        ),
        ("deserialize_sigma_19_scalars_19_points.hex", 19, 19, 1216),
        (
            "deserialize_sigma_transfer_26_scalars_30_points.hex",
            26,
            30,
            1792,
        ),
    ] {
        let data = read_hex_file(corpora_dir, hex_name)?;
        let expected = deserialize_sigma_wire(ns, np);
        anyhow::ensure!(data.len() == expected_len);
        anyhow::ensure!(
            data == expected,
            "{hex_name} drift vs canonical zero scalar + A_POINT layout"
        );
        eprintln!("OK {hex_name}: {expected_len} bytes");
    }

    let transfer_ext_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_one_auditor_quad.hex";
    let mut transfer_one_auditor = deserialize_sigma_wire(26, 30);
    for _ in 0..4 {
        transfer_one_auditor.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_one_auditor.len() == 1920,
        "{transfer_ext_name}: built len {}",
        transfer_one_auditor.len()
    );
    anyhow::ensure!(
        (transfer_one_auditor.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_ext_name}: auditor extension not multiple of 128 B"
    );
    let transfer_ext_file = read_hex_file(corpora_dir, transfer_ext_name)?;
    anyhow::ensure!(
        transfer_ext_file == transfer_one_auditor,
        "{transfer_ext_name} drift vs base transfer sigma + 4×A_POINT"
    );
    eprintln!("OK {transfer_ext_name}: 1920 bytes");

    let transfer_two_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_two_auditor_quads.hex";
    let mut transfer_two_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..8 {
        transfer_two_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_two_auditors.len() == 2048,
        "{transfer_two_name}: built len {}",
        transfer_two_auditors.len()
    );
    anyhow::ensure!(
        (transfer_two_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_two_name}: auditor extension not multiple of 128 B"
    );
    let transfer_two_file = read_hex_file(corpora_dir, transfer_two_name)?;
    anyhow::ensure!(
        transfer_two_file == transfer_two_auditors,
        "{transfer_two_name} drift vs base transfer sigma + 8×A_POINT"
    );
    eprintln!("OK {transfer_two_name}: 2048 bytes");

    let transfer_three_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_three_auditor_quads.hex";
    let mut transfer_three_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..12 {
        transfer_three_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_three_auditors.len() == 2176,
        "{transfer_three_name}: built len {}",
        transfer_three_auditors.len()
    );
    anyhow::ensure!(
        (transfer_three_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_three_name}: auditor extension not multiple of 128 B"
    );
    let transfer_three_file = read_hex_file(corpora_dir, transfer_three_name)?;
    anyhow::ensure!(
        transfer_three_file == transfer_three_auditors,
        "{transfer_three_name} drift vs base transfer sigma + 12×A_POINT"
    );
    eprintln!("OK {transfer_three_name}: 2176 bytes");

    let transfer_four_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_four_auditor_quads.hex";
    let mut transfer_four_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..16 {
        transfer_four_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_four_auditors.len() == 2304,
        "{transfer_four_name}: built len {}",
        transfer_four_auditors.len()
    );
    anyhow::ensure!(
        (transfer_four_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_four_name}: auditor extension not multiple of 128 B"
    );
    let transfer_four_file = read_hex_file(corpora_dir, transfer_four_name)?;
    anyhow::ensure!(
        transfer_four_file == transfer_four_auditors,
        "{transfer_four_name} drift vs base transfer sigma + 16×A_POINT"
    );
    eprintln!("OK {transfer_four_name}: 2304 bytes");

    let transfer_five_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_five_auditor_quads.hex";
    let mut transfer_five_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..20 {
        transfer_five_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_five_auditors.len() == 2432,
        "{transfer_five_name}: built len {}",
        transfer_five_auditors.len()
    );
    anyhow::ensure!(
        (transfer_five_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_five_name}: auditor extension not multiple of 128 B"
    );
    let transfer_five_file = read_hex_file(corpora_dir, transfer_five_name)?;
    anyhow::ensure!(
        transfer_five_file == transfer_five_auditors,
        "{transfer_five_name} drift vs base transfer sigma + 20×A_POINT"
    );
    eprintln!("OK {transfer_five_name}: 2432 bytes");

    let transfer_six_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_six_auditor_quads.hex";
    let mut transfer_six_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..24 {
        transfer_six_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_six_auditors.len() == 2560,
        "{transfer_six_name}: built len {}",
        transfer_six_auditors.len()
    );
    anyhow::ensure!(
        (transfer_six_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_six_name}: auditor extension not multiple of 128 B"
    );
    let transfer_six_file = read_hex_file(corpora_dir, transfer_six_name)?;
    anyhow::ensure!(
        transfer_six_file == transfer_six_auditors,
        "{transfer_six_name} drift vs base transfer sigma + 24×A_POINT"
    );
    eprintln!("OK {transfer_six_name}: 2560 bytes");

    let transfer_seven_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_seven_auditor_quads.hex";
    let mut transfer_seven_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..28 {
        transfer_seven_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_seven_auditors.len() == 2688,
        "{transfer_seven_name}: built len {}",
        transfer_seven_auditors.len()
    );
    anyhow::ensure!(
        (transfer_seven_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_seven_name}: auditor extension not multiple of 128 B"
    );
    let transfer_seven_file = read_hex_file(corpora_dir, transfer_seven_name)?;
    anyhow::ensure!(
        transfer_seven_file == transfer_seven_auditors,
        "{transfer_seven_name} drift vs base transfer sigma + 28×A_POINT"
    );
    eprintln!("OK {transfer_seven_name}: 2688 bytes");

    let transfer_eight_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_eight_auditor_quads.hex";
    let mut transfer_eight_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..32 {
        transfer_eight_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_eight_auditors.len() == 2816,
        "{transfer_eight_name}: built len {}",
        transfer_eight_auditors.len()
    );
    anyhow::ensure!(
        (transfer_eight_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_eight_name}: auditor extension not multiple of 128 B"
    );
    let transfer_eight_file = read_hex_file(corpora_dir, transfer_eight_name)?;
    anyhow::ensure!(
        transfer_eight_file == transfer_eight_auditors,
        "{transfer_eight_name} drift vs base transfer sigma + 32×A_POINT"
    );
    eprintln!("OK {transfer_eight_name}: 2816 bytes");

    let transfer_nine_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_nine_auditor_quads.hex";
    let mut transfer_nine_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..36 {
        transfer_nine_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_nine_auditors.len() == 2944,
        "{transfer_nine_name}: built len {}",
        transfer_nine_auditors.len()
    );
    anyhow::ensure!(
        (transfer_nine_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_nine_name}: auditor extension not multiple of 128 B"
    );
    let transfer_nine_file = read_hex_file(corpora_dir, transfer_nine_name)?;
    anyhow::ensure!(
        transfer_nine_file == transfer_nine_auditors,
        "{transfer_nine_name} drift vs base transfer sigma + 36×A_POINT"
    );
    eprintln!("OK {transfer_nine_name}: 2944 bytes");

    let transfer_ten_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_ten_auditor_quads.hex";
    let mut transfer_ten_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..40 {
        transfer_ten_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_ten_auditors.len() == 3072,
        "{transfer_ten_name}: built len {}",
        transfer_ten_auditors.len()
    );
    anyhow::ensure!(
        (transfer_ten_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_ten_name}: auditor extension not multiple of 128 B"
    );
    let transfer_ten_file = read_hex_file(corpora_dir, transfer_ten_name)?;
    anyhow::ensure!(
        transfer_ten_file == transfer_ten_auditors,
        "{transfer_ten_name} drift vs base transfer sigma + 40×A_POINT"
    );
    eprintln!("OK {transfer_ten_name}: 3072 bytes");

    let transfer_eleven_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_eleven_auditor_quads.hex";
    let mut transfer_eleven_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..44 {
        transfer_eleven_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_eleven_auditors.len() == 3200,
        "{transfer_eleven_name}: built len {}",
        transfer_eleven_auditors.len()
    );
    anyhow::ensure!(
        (transfer_eleven_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_eleven_name}: auditor extension not multiple of 128 B"
    );
    let transfer_eleven_file = read_hex_file(corpora_dir, transfer_eleven_name)?;
    anyhow::ensure!(
        transfer_eleven_file == transfer_eleven_auditors,
        "{transfer_eleven_name} drift vs base transfer sigma + 44×A_POINT"
    );
    eprintln!("OK {transfer_eleven_name}: 3200 bytes");

    let transfer_twelve_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_twelve_auditor_quads.hex";
    let mut transfer_twelve_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..48 {
        transfer_twelve_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_twelve_auditors.len() == 3328,
        "{transfer_twelve_name}: built len {}",
        transfer_twelve_auditors.len()
    );
    anyhow::ensure!(
        (transfer_twelve_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_twelve_name}: auditor extension not multiple of 128 B"
    );
    let transfer_twelve_file = read_hex_file(corpora_dir, transfer_twelve_name)?;
    anyhow::ensure!(
        transfer_twelve_file == transfer_twelve_auditors,
        "{transfer_twelve_name} drift vs base transfer sigma + 48×A_POINT"
    );
    eprintln!("OK {transfer_twelve_name}: 3328 bytes");

    let transfer_thirteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_thirteen_auditor_quads.hex";
    let mut transfer_thirteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..52 {
        transfer_thirteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_thirteen_auditors.len() == 3456,
        "{transfer_thirteen_name}: built len {}",
        transfer_thirteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_thirteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_thirteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_thirteen_file = read_hex_file(corpora_dir, transfer_thirteen_name)?;
    anyhow::ensure!(
        transfer_thirteen_file == transfer_thirteen_auditors,
        "{transfer_thirteen_name} drift vs base transfer sigma + 52×A_POINT"
    );
    eprintln!("OK {transfer_thirteen_name}: 3456 bytes");

    let transfer_fourteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_fourteen_auditor_quads.hex";
    let mut transfer_fourteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..56 {
        transfer_fourteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_fourteen_auditors.len() == 3584,
        "{transfer_fourteen_name}: built len {}",
        transfer_fourteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_fourteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_fourteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_fourteen_file = read_hex_file(corpora_dir, transfer_fourteen_name)?;
    anyhow::ensure!(
        transfer_fourteen_file == transfer_fourteen_auditors,
        "{transfer_fourteen_name} drift vs base transfer sigma + 56×A_POINT"
    );
    eprintln!("OK {transfer_fourteen_name}: 3584 bytes");

    let transfer_fifteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_fifteen_auditor_quads.hex";
    let mut transfer_fifteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..60 {
        transfer_fifteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_fifteen_auditors.len() == 3712,
        "{transfer_fifteen_name}: built len {}",
        transfer_fifteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_fifteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_fifteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_fifteen_file = read_hex_file(corpora_dir, transfer_fifteen_name)?;
    anyhow::ensure!(
        transfer_fifteen_file == transfer_fifteen_auditors,
        "{transfer_fifteen_name} drift vs base transfer sigma + 60×A_POINT"
    );
    eprintln!("OK {transfer_fifteen_name}: 3712 bytes");

    let transfer_sixteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_sixteen_auditor_quads.hex";
    let mut transfer_sixteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..64 {
        transfer_sixteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_sixteen_auditors.len() == 3840,
        "{transfer_sixteen_name}: built len {}",
        transfer_sixteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_sixteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_sixteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_sixteen_file = read_hex_file(corpora_dir, transfer_sixteen_name)?;
    anyhow::ensure!(
        transfer_sixteen_file == transfer_sixteen_auditors,
        "{transfer_sixteen_name} drift vs base transfer sigma + 64×A_POINT"
    );
    eprintln!("OK {transfer_sixteen_name}: 3840 bytes");

    let transfer_seventeen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_seventeen_auditor_quads.hex";
    let mut transfer_seventeen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..68 {
        transfer_seventeen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_seventeen_auditors.len() == 3968,
        "{transfer_seventeen_name}: built len {}",
        transfer_seventeen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_seventeen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_seventeen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_seventeen_file = read_hex_file(corpora_dir, transfer_seventeen_name)?;
    anyhow::ensure!(
        transfer_seventeen_file == transfer_seventeen_auditors,
        "{transfer_seventeen_name} drift vs base transfer sigma + 68×A_POINT"
    );
    eprintln!("OK {transfer_seventeen_name}: 3968 bytes");

    let transfer_eighteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_eighteen_auditor_quads.hex";
    let mut transfer_eighteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..72 {
        transfer_eighteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_eighteen_auditors.len() == 4096,
        "{transfer_eighteen_name}: built len {}",
        transfer_eighteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_eighteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_eighteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_eighteen_file = read_hex_file(corpora_dir, transfer_eighteen_name)?;
    anyhow::ensure!(
        transfer_eighteen_file == transfer_eighteen_auditors,
        "{transfer_eighteen_name} drift vs base transfer sigma + 72×A_POINT"
    );
    eprintln!("OK {transfer_eighteen_name}: 4096 bytes");

    let transfer_nineteen_name =
        "deserialize_sigma_transfer_26_scalars_30_points_plus_nineteen_auditor_quads.hex";
    let mut transfer_nineteen_auditors = deserialize_sigma_wire(26, 30);
    for _ in 0..76 {
        transfer_nineteen_auditors.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        transfer_nineteen_auditors.len() == 4224,
        "{transfer_nineteen_name}: built len {}",
        transfer_nineteen_auditors.len()
    );
    anyhow::ensure!(
        (transfer_nineteen_auditors.len() - (32 * 30 + 32 * 26)) % 128 == 0,
        "{transfer_nineteen_name}: auditor extension not multiple of 128 B"
    );
    let transfer_nineteen_file = read_hex_file(corpora_dir, transfer_nineteen_name)?;
    anyhow::ensure!(
        transfer_nineteen_file == transfer_nineteen_auditors,
        "{transfer_nineteen_name} drift vs base transfer sigma + 76×A_POINT"
    );
    eprintln!("OK {transfer_nineteen_name}: 4224 bytes");

    let eks_one = read_hex_file(corpora_dir, "serialize_auditor_eks_single_a_point.hex")?;
    anyhow::ensure!(eks_one.len() == 32);
    anyhow::ensure!(
        eks_one.as_slice() == RISTRETTO_A_POINT.as_slice(),
        "serialize_auditor_eks_single_a_point.hex drift"
    );

    let amounts_one = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_one_zero_pending.hex",
    )?;
    anyhow::ensure!(amounts_one.len() == 256);
    anyhow::ensure!(
        amounts_one == vec![0u8; 256],
        "serialize_auditor_amounts_one_zero_pending.hex expected 256 zero bytes"
    );
    eprintln!("OK serialize_auditor_eks_single_a_point.hex: 32 bytes");
    eprintln!("OK serialize_auditor_amounts_one_zero_pending.hex: 256 bytes");

    let eks_two = read_hex_file(corpora_dir, "serialize_auditor_eks_two_a_points.hex")?;
    anyhow::ensure!(eks_two.len() == 64);
    let mut two = Vec::with_capacity(64);
    two.extend_from_slice(&RISTRETTO_A_POINT);
    two.extend_from_slice(&RISTRETTO_A_POINT);
    anyhow::ensure!(
        eks_two == two,
        "serialize_auditor_eks_two_a_points.hex drift"
    );
    let eks_three = read_hex_file(corpora_dir, "serialize_auditor_eks_three_a_points.hex")?;
    anyhow::ensure!(eks_three.len() == 96);
    let mut three = Vec::with_capacity(96);
    three.extend_from_slice(&RISTRETTO_A_POINT);
    three.extend_from_slice(&RISTRETTO_A_POINT);
    three.extend_from_slice(&RISTRETTO_A_POINT);
    anyhow::ensure!(
        eks_three == three,
        "serialize_auditor_eks_three_a_points.hex drift vs 3×A_POINT"
    );
    let eks_four = read_hex_file(corpora_dir, "serialize_auditor_eks_four_a_points.hex")?;
    anyhow::ensure!(eks_four.len() == 128);
    let mut four = Vec::with_capacity(128);
    four.extend_from_slice(&RISTRETTO_A_POINT);
    four.extend_from_slice(&RISTRETTO_A_POINT);
    four.extend_from_slice(&RISTRETTO_A_POINT);
    four.extend_from_slice(&RISTRETTO_A_POINT);
    anyhow::ensure!(
        eks_four == four,
        "serialize_auditor_eks_four_a_points.hex drift vs 4×A_POINT"
    );
    let eks_five = read_hex_file(corpora_dir, "serialize_auditor_eks_five_a_points.hex")?;
    anyhow::ensure!(eks_five.len() == 160);
    let mut five = Vec::with_capacity(160);
    for _ in 0..5 {
        five.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        eks_five == five,
        "serialize_auditor_eks_five_a_points.hex drift vs 5×A_POINT"
    );
    let eks_six = read_hex_file(corpora_dir, "serialize_auditor_eks_six_a_points.hex")?;
    anyhow::ensure!(eks_six.len() == 192);
    let mut six = Vec::with_capacity(192);
    for _ in 0..6 {
        six.extend_from_slice(&RISTRETTO_A_POINT);
    }
    anyhow::ensure!(
        eks_six == six,
        "serialize_auditor_eks_six_a_points.hex drift vs 6×A_POINT"
    );
    let amounts_two = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_two_zero_pending.hex",
    )?;
    anyhow::ensure!(amounts_two == vec![0u8; 512]);
    eprintln!("OK serialize_auditor_eks_two_a_points.hex: 64 bytes");
    eprintln!("OK serialize_auditor_eks_three_a_points.hex: 96 bytes");
    eprintln!("OK serialize_auditor_eks_four_a_points.hex: 128 bytes");
    eprintln!("OK serialize_auditor_eks_five_a_points.hex: 160 bytes");
    eprintln!("OK serialize_auditor_eks_six_a_points.hex: 192 bytes");
    eprintln!("OK serialize_auditor_amounts_two_zero_pending.hex: 512 bytes");

    let u64_one = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_one_u64_one_pending.hex",
    )?;
    anyhow::ensure!(u64_one.len() == 256);
    anyhow::ensure!(
        u64_one[..32] != [0u8; 32],
        "u64(1) wire should not start with 32 zero bytes"
    );
    anyhow::ensure!(
        u64_one[32..] == vec![0u8; 224],
        "u64(1) wire tail should be zero-filled ciphertext slots"
    );

    let act_zero = read_hex_file(corpora_dir, "serialize_auditor_amounts_one_actual_zero.hex")?;
    anyhow::ensure!(act_zero == vec![0u8; 512]);
    eprintln!("OK serialize_auditor_amounts_one_u64_one_pending.hex: 256 bytes");
    eprintln!("OK serialize_auditor_amounts_one_actual_zero.hex: 512 bytes");

    let zero_then_u64 = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_zero_then_u64_one_pending.hex",
    )?;
    anyhow::ensure!(zero_then_u64.len() == 512);
    let mut zero_then_expected = Vec::with_capacity(512);
    zero_then_expected.extend_from_slice(&amounts_one);
    zero_then_expected.extend_from_slice(&u64_one);
    anyhow::ensure!(
        zero_then_u64 == zero_then_expected,
        "serialize_auditor_amounts_zero_then_u64_one_pending.hex drift vs one_zero ++ u64_one"
    );
    anyhow::ensure!(
        zero_then_u64[..256] == vec![0u8; 256],
        "mixed wire first half should be 256 zero bytes (zero pending)"
    );
    anyhow::ensure!(
        zero_then_u64[256..] == u64_one[..],
        "mixed wire second half should match u64(1) single-balance wire"
    );
    eprintln!("OK serialize_auditor_amounts_zero_then_u64_one_pending.hex: 512 bytes");

    let u64_then_zero = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_u64_one_then_zero_pending.hex",
    )?;
    anyhow::ensure!(u64_then_zero.len() == 512);
    let mut u64_then_zero_expected = Vec::with_capacity(512);
    u64_then_zero_expected.extend_from_slice(&u64_one);
    u64_then_zero_expected.extend_from_slice(&amounts_one);
    anyhow::ensure!(
        u64_then_zero == u64_then_zero_expected,
        "serialize_auditor_amounts_u64_one_then_zero_pending.hex drift vs u64_one ++ one_zero"
    );
    anyhow::ensure!(
        u64_then_zero[..256] == u64_one[..],
        "u64-then-zero wire first half should match u64(1) single-balance wire"
    );
    anyhow::ensure!(
        u64_then_zero[256..] == vec![0u8; 256],
        "u64-then-zero wire second half should be 256 zero bytes"
    );
    anyhow::ensure!(
        u64_then_zero != zero_then_u64,
        "u64-then-zero and zero-then-u64 mixed wires must differ (vector order)"
    );
    eprintln!("OK serialize_auditor_amounts_u64_one_then_zero_pending.hex: 512 bytes");

    let actual_then_u64p = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_actual_zero_then_u64_one_pending.hex",
    )?;
    let u64p_then_actual = read_hex_file(
        corpora_dir,
        "serialize_auditor_amounts_u64_one_pending_then_actual_zero.hex",
    )?;
    anyhow::ensure!(actual_then_u64p.len() == 768);
    anyhow::ensure!(u64p_then_actual.len() == 768);
    let mut exp_a_u = Vec::with_capacity(768);
    exp_a_u.extend_from_slice(&act_zero);
    exp_a_u.extend_from_slice(&u64_one);
    anyhow::ensure!(
        actual_then_u64p == exp_a_u,
        "serialize_auditor_amounts_actual_zero_then_u64_one_pending.hex drift vs actual_zero ++ u64_one"
    );
    let mut exp_u_a = Vec::with_capacity(768);
    exp_u_a.extend_from_slice(&u64_one);
    exp_u_a.extend_from_slice(&act_zero);
    anyhow::ensure!(
        u64p_then_actual == exp_u_a,
        "serialize_auditor_amounts_u64_one_pending_then_actual_zero.hex drift vs u64_one ++ actual_zero"
    );
    anyhow::ensure!(
        actual_then_u64p != u64p_then_actual,
        "768B actual/u64-pending permutations must differ"
    );
    anyhow::ensure!(
        actual_then_u64p[..512] == act_zero,
        "actual-then-u64: first 512 B should match all-zero actual wire"
    );
    anyhow::ensure!(
        actual_then_u64p[512..] == u64_one[..],
        "actual-then-u64: last 256 B should match u64(1) pending wire"
    );
    anyhow::ensure!(
        u64p_then_actual[..256] == u64_one[..],
        "u64-then-actual: first 256 B should match u64(1) pending wire"
    );
    anyhow::ensure!(
        u64p_then_actual[256..] == act_zero,
        "u64-then-actual: last 512 B should match all-zero actual wire"
    );
    eprintln!("OK serialize_auditor_amounts_actual_zero_then_u64_one_pending.hex: 768 bytes");
    eprintln!("OK serialize_auditor_amounts_u64_one_pending_then_actual_zero.hex: 768 bytes");

    Ok(())
}

/// CLI entry: `cargo run -p move-lean-difftest -- verify-corpora`
pub fn run() -> Result<()> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let corpora_dir = manifest_dir.join("corpora/confidential_assets");
    verify_corpora_in_dir(&corpora_dir)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn confidential_assets_corpora_match_rust_verifier() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("corpora/confidential_assets");
        verify_corpora_in_dir(&dir).expect("corpus verify");
    }
}
