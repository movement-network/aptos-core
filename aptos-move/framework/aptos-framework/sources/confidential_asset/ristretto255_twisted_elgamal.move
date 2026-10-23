/// PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only
///
/// Twisted ElGamal encryption API over the Ristretto255 curve.
///
/// Every public function and every entry function aborts with `E_CONFIDENTIAL_ASSETS_PAUSED` (wrapped in
/// `error::unavailable`). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
/// remove or change a published struct. No resource is published, no event is emitted and no state is changed.
module aptos_framework::ristretto255_twisted_elgamal {
    use std::error;
    use std::option::Option;
    use aptos_std::ristretto255::{CompressedRistretto, RistrettoPoint, Scalar};

    /// Confidential assets are paused: every function in this module aborts.
    const E_CONFIDENTIAL_ASSETS_PAUSED: u64 = 1;

    /// A Twisted ElGamal ciphertext, consisting of two Ristretto255 points.
    struct Ciphertext has drop {
        left: RistrettoPoint,   // v * G + r * H
        right: RistrettoPoint,  // r * Y
    }

    /// A compressed Twisted ElGamal ciphertext, consisting of two compressed Ristretto255 points.
    struct CompressedCiphertext has store, copy, drop {
        left: CompressedRistretto,
        right: CompressedRistretto,
    }

    /// A Twisted ElGamal public key, represented as a compressed Ristretto255 point.
    struct CompressedPubkey has store, copy, drop {
        point: CompressedRistretto,
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_pubkey_from_bytes(_bytes: vector<u8>): Option<CompressedPubkey> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_identity_pubkey(_pubkey: &CompressedPubkey): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun pubkey_to_bytes(_pubkey: &CompressedPubkey): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun pubkey_to_point(_pubkey: &CompressedPubkey): RistrettoPoint {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun pubkey_to_compressed_point(_pubkey: &CompressedPubkey): CompressedRistretto {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_ciphertext_from_bytes(_bytes: vector<u8>): Option<Ciphertext> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_ciphertext_no_randomness(_val: &Scalar): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_from_points(_left: RistrettoPoint, _right: RistrettoPoint): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_from_compressed_points(
        _left: CompressedRistretto,
        _right: CompressedRistretto
    ): CompressedCiphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_to_bytes(_ct: &Ciphertext): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_into_points(_c: Ciphertext): (RistrettoPoint, RistrettoPoint) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_as_points(_c: &Ciphertext): (&RistrettoPoint, &RistrettoPoint) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun compress_ciphertext(_ct: &Ciphertext): CompressedCiphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun decompress_ciphertext(_ct: &CompressedCiphertext): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_add(_lhs: &Ciphertext, _rhs: &Ciphertext): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_add_assign(_lhs: &mut Ciphertext, _rhs: &Ciphertext) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_sub(_lhs: &Ciphertext, _rhs: &Ciphertext): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_sub_assign(_lhs: &mut Ciphertext, _rhs: &Ciphertext) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_clone(_c: &Ciphertext): Ciphertext {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun ciphertext_equals(_lhs: &Ciphertext, _rhs: &Ciphertext): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_value_component(_ct: &Ciphertext): &RistrettoPoint {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }
}
