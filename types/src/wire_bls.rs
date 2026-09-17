// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Compressed BLS12-381 G2 payload used by consensus vote types.
//!
//! `bls12381::Signature` recovers a curve point inside `TryFrom` / serde. That
//! recovery is a field square-root and is far more expensive than reading a
//! `LedgerInfo`. Commit-vote matching only compares the ledger fields of a
//! vote against a later full `LedgerInfoWithSignatures`; it must not depend on
//! the attached signature being a valid group element.
//!
//! This type is the 96-byte encoding only. Serde matches the historical
//! `Signature` newtype so BCS and JSON stay bitwise compatible. Recovering a
//! `bls12381::Signature` is a separate, explicit step used by verification
//! and aggregation.

use aptos_crypto::{bls12381, CryptoMaterialError};
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use std::{convert::TryFrom, fmt, hash::Hash};

/// AIP-80 prefix accepted on the human-readable path, matching `bls12381::Signature`.
const BLS_SIG_AIP80_PREFIX: &str = "bls12381-sig-";

/// 96-byte compressed BLS signature that has not been turned into a group element.
#[derive(Clone, Copy)]
pub struct WireBlsSignature {
    compact: [u8; bls12381::Signature::LENGTH],
}

impl WireBlsSignature {
    /// Compressed encoding length, identical to `bls12381::Signature::LENGTH`.
    pub const COMPACT_LEN: usize = bls12381::Signature::LENGTH;

    /// Wrap an already-recovered signature by re-encoding it to compressed bytes.
    pub fn capture_point(signature: &bls12381::Signature) -> Self {
        Self {
            compact: signature.to_bytes(),
        }
    }

    /// Accept a fixed-size compressed payload. No curve checks run here.
    pub fn from_compact_array(compact: [u8; Self::COMPACT_LEN]) -> Self {
        Self { compact }
    }

    /// Accept a slice if and only if it is the compressed encoding length.
    pub fn from_compact_slice(bytes: &[u8]) -> Result<Self, CryptoMaterialError> {
        let compact: [u8; Self::COMPACT_LEN] = bytes
            .try_into()
            .map_err(|_| CryptoMaterialError::WrongLengthError)?;
        Ok(Self { compact })
    }

    /// Borrow the compressed encoding.
    pub fn compact_bytes(&self) -> &[u8; Self::COMPACT_LEN] {
        &self.compact
    }

    /// Recover the G2 element. This is the first decompression for values
    /// that arrived on the wire.
    pub fn recover_group_element(&self) -> Result<bls12381::Signature, CryptoMaterialError> {
        bls12381::Signature::try_from(self.compact.as_slice())
    }
}

impl From<bls12381::Signature> for WireBlsSignature {
    fn from(signature: bls12381::Signature) -> Self {
        Self::capture_point(&signature)
    }
}

impl From<&bls12381::Signature> for WireBlsSignature {
    fn from(signature: &bls12381::Signature) -> Self {
        Self::capture_point(signature)
    }
}

impl PartialEq for WireBlsSignature {
    fn eq(&self, other: &Self) -> bool {
        self.compact == other.compact
    }
}

impl Eq for WireBlsSignature {}

impl Hash for WireBlsSignature {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        state.write(&self.compact);
    }
}

impl fmt::Debug for WireBlsSignature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(self.compact))
    }
}

impl fmt::Display for WireBlsSignature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(self.compact))
    }
}

impl Serialize for WireBlsSignature {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        // Field name and encoding must stay identical to `bls12381::Signature`.
        if serializer.is_human_readable() {
            serializer.serialize_str(&format!("0x{}", hex::encode(self.compact)))
        } else {
            serializer.serialize_newtype_struct("Signature", serde_bytes::Bytes::new(&self.compact))
        }
    }
}

impl<'de> Deserialize<'de> for WireBlsSignature {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        use serde::de::Error;

        if deserializer.is_human_readable() {
            let encoded = String::deserialize(deserializer)?;
            decode_human_readable_compact(&encoded).map_err(D::Error::custom)
        } else {
            #[derive(Deserialize)]
            #[serde(rename = "Signature")]
            struct SignatureBytes<'a>(&'a [u8]);

            let SignatureBytes(bytes) = SignatureBytes::deserialize(deserializer)?;
            Self::from_compact_slice(bytes).map_err(D::Error::custom)
        }
    }
}

fn decode_human_readable_compact(encoded: &str) -> Result<WireBlsSignature, CryptoMaterialError> {
    let mut body = encoded
        .strip_prefix(BLS_SIG_AIP80_PREFIX)
        .unwrap_or(encoded);
    body = body.strip_prefix("0x").unwrap_or(body);
    let raw = hex::decode(body).map_err(|_| CryptoMaterialError::DeserializationError)?;
    WireBlsSignature::from_compact_slice(&raw)
}

#[cfg(test)]
mod tests {
    use super::*;
    use aptos_crypto::{bls12381::Signature, ValidCryptoMaterial, ValidCryptoMaterialStringExt};

    fn valid_point() -> Signature {
        Signature::dummy_signature()
    }

    #[test]
    fn compact_round_trip_matches_signature_bytes() {
        let point = valid_point();
        let wire = WireBlsSignature::capture_point(&point);
        assert_eq!(wire.compact_bytes().as_slice(), point.to_bytes().as_slice());
        assert_eq!(wire.recover_group_element().unwrap(), point);
        assert_eq!(
            ValidCryptoMaterial::to_bytes(&point).len(),
            WireBlsSignature::COMPACT_LEN
        );
    }

    #[test]
    fn bcs_matches_bls_signature_newtype() {
        let point = valid_point();
        let wire = WireBlsSignature::from(&point);
        assert_eq!(
            bcs::to_bytes(&wire).unwrap(),
            bcs::to_bytes(&point).unwrap()
        );
    }

    #[test]
    fn json_matches_bls_signature_string() {
        let point = valid_point();
        let wire = WireBlsSignature::from(&point);
        assert_eq!(
            serde_json::to_string(&wire).unwrap(),
            serde_json::to_string(&point).unwrap()
        );
        assert_eq!(
            serde_json::to_string(&wire).unwrap(),
            serde_json::to_string(&point.to_encoded_string().unwrap()).unwrap()
        );
    }

    #[test]
    fn option_wrapper_stays_bitwise_compatible() {
        let point = valid_point();
        let old: Option<Signature> = Some(point.clone());
        let new: Option<WireBlsSignature> = Some(WireBlsSignature::from(&point));
        assert_eq!(bcs::to_bytes(&old).unwrap(), bcs::to_bytes(&new).unwrap());
        assert_eq!(
            serde_json::to_string(&old).unwrap(),
            serde_json::to_string(&new).unwrap()
        );
    }

    #[test]
    fn well_formed_length_junk_decodes_and_fails_only_on_recover() {
        let junk = [0xFFu8; WireBlsSignature::COMPACT_LEN];
        let wire = WireBlsSignature::from_compact_array(junk);
        let encoded = bcs::to_bytes(&wire).unwrap();
        let decoded: WireBlsSignature = bcs::from_bytes(&encoded).unwrap();
        assert_eq!(decoded, wire);
        assert!(decoded.recover_group_element().is_err());

        let json = serde_json::to_string(&wire).unwrap();
        let from_json: WireBlsSignature = serde_json::from_str(&json).unwrap();
        assert_eq!(from_json, wire);
        assert!(from_json.recover_group_element().is_err());
    }

    #[test]
    fn wrong_length_is_rejected_before_recover() {
        assert!(WireBlsSignature::from_compact_slice(&[0u8; 32]).is_err());
        let short = serde_bytes::Bytes::new(&[0u8; 8]);
        // Direct slice helper is the length gate used by serde.
        assert_eq!(
            WireBlsSignature::from_compact_slice(short.as_ref()).unwrap_err(),
            CryptoMaterialError::WrongLengthError
        );
    }

    #[test]
    fn human_readable_accepts_aip80_prefix_without_recovering() {
        let junk = [0xAAu8; WireBlsSignature::COMPACT_LEN];
        let encoded = format!("{}0x{}", BLS_SIG_AIP80_PREFIX, hex::encode(junk));
        let wire = decode_human_readable_compact(&encoded).unwrap();
        assert_eq!(wire.compact_bytes(), &junk);
        assert!(wire.recover_group_element().is_err());
    }
}
