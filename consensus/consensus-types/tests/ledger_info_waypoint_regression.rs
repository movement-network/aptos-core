// Regression tests for the waypoint verification bypass (audit finding C1).
//
// Previously, `LedgerInfoWithSignatures::verify_signatures` returned `Ok(())`
// for any ledger info with `version <= waypoint_version` (a process-global set
// at node startup). Because decoupled execution gives every ordered QC and
// CommitDecision `version == 0`, the bypass covered ALL live consensus
// messages: forged messages with empty aggregate signatures were accepted.
//
// These tests pin the fixed behavior: signature verification always runs.

use aptos_consensus_types::{
    pipeline::commit_decision::CommitDecision, quorum_cert::QuorumCert, vote_data::VoteData,
};
use aptos_crypto::{
    hash::{CryptoHash, ACCUMULATOR_PLACEHOLDER_HASH},
    HashValue,
};
use aptos_types::{
    aggregate_signature::AggregateSignature,
    block_info::BlockInfo,
    ledger_info::{LedgerInfo, LedgerInfoWithSignatures},
    validator_signer::ValidatorSigner,
    validator_verifier::{ValidatorConsensusInfo, ValidatorVerifier},
};

fn seven_validator_setup() -> (Vec<ValidatorSigner>, ValidatorVerifier) {
    let signers: Vec<ValidatorSigner> = (0..7).map(|i| ValidatorSigner::random([i; 32])).collect();
    let infos: Vec<_> = signers
        .iter()
        .map(|s| ValidatorConsensusInfo::new(s.author(), s.public_key(), 1))
        .collect();
    (
        signers,
        ValidatorVerifier::new_with_quorum_voting_power(infos, 5).unwrap(),
    )
}

fn block_info(round: u64, version: u64) -> BlockInfo {
    BlockInfo::new(
        1,                   // epoch
        round,
        HashValue::random(), // id
        HashValue::random(), // executed_state_id
        version,
        12345,
        None,
    )
}

#[test]
fn forged_commit_decision_with_empty_signature_is_rejected() {
    let (_, verifier) = seven_validator_setup();

    // The exact forgery from the C1 PoC: a CommitDecision carrying an EMPTY
    // aggregate signature over a version-0 ledger info (the shape of every
    // commit decision under decoupled execution).
    let forged = CommitDecision::new(LedgerInfoWithSignatures::new(
        LedgerInfo::new(block_info(10, 0), HashValue::zero()),
        AggregateSignature::empty(),
    ));
    assert!(
        forged.verify(&verifier).is_err(),
        "a CommitDecision with no valid signatures must never verify"
    );
}

#[test]
fn forged_version_zero_quorum_cert_with_empty_signature_is_rejected() {
    let (_, verifier) = seven_validator_setup();

    // A version-0 ordered QC — the exact shape produced by decoupled
    // execution — with an empty aggregate signature. VoteData must be
    // well-formed (QuorumCert::verify checks consensus_data_hash ==
    // vote_data.hash() and vote_data.verify()).
    let parent = BlockInfo::new(
        1,
        10,
        HashValue::random(),
        *ACCUMULATOR_PLACEHOLDER_HASH,
        0,
        12345,
        None,
    );
    let proposed = BlockInfo::new(
        1,
        11,
        HashValue::random(),
        *ACCUMULATOR_PLACEHOLDER_HASH,
        0,
        12346,
        None,
    );
    let vote_data = VoteData::new(proposed, parent.clone());
    let qc_ledger_info = LedgerInfoWithSignatures::new(
        LedgerInfo::new(parent, vote_data.hash()),
        AggregateSignature::empty(),
    );
    let qc = QuorumCert::new(vote_data, qc_ledger_info);
    assert!(
        qc.verify(&verifier).is_err(),
        "an ordered QC with no valid signatures must never verify"
    );
}

#[test]
fn honestly_signed_commit_decision_still_verifies() {
    // Control: legitimate quorum-signed messages must keep passing.
    let (signers, verifier) = seven_validator_setup();

    let ledger_info = LedgerInfo::new(block_info(10, 0), HashValue::zero());
    // 5 of 7 voting power = quorum
    let signatures: Vec<_> = signers
        .iter()
        .take(5)
        .map(|s| (s.author(), s.sign(&ledger_info).unwrap()))
        .collect();
    let aggregate = verifier
        .aggregate_signatures(signatures.iter().map(|(a, s)| (a, s)))
        .unwrap();
    let decision = CommitDecision::new(LedgerInfoWithSignatures::new(ledger_info, aggregate));
    assert!(
        decision.verify(&verifier).is_ok(),
        "a quorum-signed CommitDecision must verify"
    );
}
