/// PAUSED: confidential assets are disabled on Movement; interface retained for upgrade compatibility only
///
/// Confidential balance abstraction over Twisted ElGamal ciphertexts.
///
/// Every public function and every entry function aborts with `E_CONFIDENTIAL_ASSETS_PAUSED` (wrapped in
/// `error::unavailable`). All structs are retained with identical names, abilities and field layout because the compatible upgrade policy refuses to
/// remove or change a published struct. No resource is published, no event is emitted and no state is changed.
module aptos_framework::confidential_balance {
    use std::error;
    use std::option::Option;
    use aptos_std::ristretto255::{RistrettoPoint, Scalar};
    use aptos_framework::ristretto255_twisted_elgamal as twisted_elgamal;

    /// Confidential assets are paused: every function in this module aborts.
    const E_CONFIDENTIAL_ASSETS_PAUSED: u64 = 1;

    /// Represents a compressed confidential balance, where each chunk is a compressed Twisted ElGamal ciphertext.
    struct CompressedConfidentialBalance has store, drop, copy {
        chunks: vector<twisted_elgamal::CompressedCiphertext>,
    }

    /// Represents a confidential balance, where each chunk is a Twisted ElGamal ciphertext.
    struct ConfidentialBalance has drop {
        chunks: vector<twisted_elgamal::Ciphertext>,
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_pending_balance_no_randomness(): ConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_actual_balance_no_randomness(): ConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_compressed_pending_balance_no_randomness(): CompressedConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_compressed_actual_balance_no_randomness(): CompressedConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_pending_balance_u64_no_randonmess(_amount: u64): ConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_pending_balance_from_bytes(_bytes: vector<u8>): Option<ConfidentialBalance> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun new_actual_balance_from_bytes(_bytes: vector<u8>): Option<ConfidentialBalance> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun compress_balance(_balance: &ConfidentialBalance): CompressedConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun decompress_balance(_balance: &CompressedConfidentialBalance): ConfidentialBalance {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun balance_to_bytes(_balance: &ConfidentialBalance): vector<u8> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun balance_to_points_c(_balance: &ConfidentialBalance): vector<RistrettoPoint> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun balance_to_points_d(_balance: &ConfidentialBalance): vector<RistrettoPoint> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun add_balances_mut(_lhs: &mut ConfidentialBalance, _rhs: &ConfidentialBalance) {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun balance_equals(_lhs: &ConfidentialBalance, _rhs: &ConfidentialBalance): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun balance_c_equals(_lhs: &ConfidentialBalance, _rhs: &ConfidentialBalance): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun is_zero_balance(_balance: &ConfidentialBalance): bool {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun split_into_chunks_u64(_amount: u64): vector<Scalar> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun split_into_chunks_u128(_amount: u128): vector<Scalar> {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_pending_balance_chunks(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_actual_balance_chunks(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }

    #[view]
    /// Paused: always aborts with `E_CONFIDENTIAL_ASSETS_PAUSED`.
    public fun get_chunk_size_bits(): u64 {
        abort error::unavailable(E_CONFIDENTIAL_ASSETS_PAUSED)
    }
}
