// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::quorum_store::{
    batch_proof_queue::BatchProofQueue, tests::batch_store_test::batch_store_for_test,
};
use aptos_consensus_types::{
    common::TxnSummaryWithExpiration,
    proof_of_store::{BatchId, BatchInfo, ProofOfStore},
    utils::PayloadTxnsSize,
};
use aptos_crypto::HashValue;
use aptos_types::{aggregate_signature::AggregateSignature, transaction::ReplayProtector, PeerId};
use maplit::hashset;
use std::{collections::HashSet, time::Duration};

/// Return a ProofOfStore with minimal fields used by ProofQueue tests.
fn proof_of_store(
    author: PeerId,
    batch_id: BatchId,
    gas_bucket_start: u64,
    expiration: u64,
) -> ProofOfStore {
    ProofOfStore::new(
        BatchInfo::new(
            author,
            batch_id,
            0,
            expiration,
            HashValue::random(),
            1,
            1,
            gas_bucket_start,
        ),
        AggregateSignature::empty(),
    )
}

fn proof_of_store_with_size(
    author: PeerId,
    batch_id: BatchId,
    gas_bucket_start: u64,
    expiration: u64,
    num_txns: u64,
) -> ProofOfStore {
    ProofOfStore::new(
        BatchInfo::new(
            author,
            batch_id,
            0,
            expiration,
            HashValue::random(),
            num_txns,
            num_txns,
            gas_bucket_start,
        ),
        AggregateSignature::empty(),
    )
}

#[tokio::test]
async fn test_proof_queue_sorting() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author_0 = PeerId::random();
    let author_1 = PeerId::random();

    let author_0_batches = vec![
        proof_of_store(author_0, BatchId::new_for_test(0), 100, 1),
        proof_of_store(author_0, BatchId::new_for_test(1), 200, 1),
        proof_of_store(author_0, BatchId::new_for_test(2), 50, 1),
        proof_of_store(author_0, BatchId::new_for_test(3), 300, 1),
    ];
    for batch in author_0_batches {
        proof_queue.insert_proof(batch);
    }
    let author_1_batches = vec![
        proof_of_store(author_1, BatchId::new_for_test(4), 500, 1),
        proof_of_store(author_1, BatchId::new_for_test(5), 400, 1),
        proof_of_store(author_1, BatchId::new_for_test(6), 600, 1),
        proof_of_store(author_1, BatchId::new_for_test(7), 50, 1),
    ];
    for batch in author_1_batches {
        proof_queue.insert_proof(batch);
    }

    // Expect: [600, 300]
    let (pulled, _, num_unique_txns, _) = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(4, 10),
        2,
        2,
        true,
        aptos_infallible::duration_since_epoch(),
    );
    let mut count_author_0 = 0;
    let mut count_author_1 = 0;
    let mut prev: Option<&ProofOfStore> = None;
    for batch in &pulled {
        if let Some(prev) = prev {
            assert!(prev.gas_bucket_start() >= batch.gas_bucket_start());
        } else {
            assert_eq!(batch.gas_bucket_start(), 600);
        }
        if batch.author() == author_0 {
            count_author_0 += 1;
        } else {
            count_author_1 += 1;
        }
        prev = Some(batch);
    }
    assert_eq!(count_author_0, 1);
    assert_eq!(count_author_1, 1);
    assert_eq!(num_unique_txns, 2);

    // Expect: [600, 500, 300, 100]
    let (pulled, _, num_unique_txns, _) = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(6, 10),
        4,
        4,
        true,
        aptos_infallible::duration_since_epoch(),
    );
    let mut count_author_0 = 0;
    let mut count_author_1 = 0;
    let mut prev: Option<&ProofOfStore> = None;
    for batch in &pulled {
        if let Some(prev) = prev {
            assert!(prev.gas_bucket_start() >= batch.gas_bucket_start());
        } else {
            assert_eq!(batch.gas_bucket_start(), 600);
        }
        if batch.author() == author_0 {
            count_author_0 += 1;
        } else {
            count_author_1 += 1;
        }
        prev = Some(batch);
    }
    assert_eq!(num_unique_txns, 4);
    assert_eq!(count_author_0, 2);
    assert_eq!(count_author_1, 2);
}

#[tokio::test]
async fn test_proof_calculate_remaining_txns_and_proofs() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);
    let now_in_secs = aptos_infallible::duration_since_epoch().as_secs() as u64;
    let now_in_usecs = aptos_infallible::duration_since_epoch().as_micros() as u64;
    let author_0 = PeerId::random();
    let author_1 = PeerId::random();
    let txns = vec![
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(0),
            now_in_secs + 1,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(1),
            now_in_secs + 1,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(2),
            now_in_secs + 1,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(3),
            now_in_secs + 1,
            HashValue::zero(),
        ),
    ];

    let author_0_batches = vec![
        proof_of_store(
            author_0,
            BatchId::new_for_test(0),
            100,
            now_in_usecs + 50000,
        ),
        proof_of_store(
            author_0,
            BatchId::new_for_test(1),
            200,
            now_in_usecs + 70000,
        ),
        proof_of_store(author_0, BatchId::new_for_test(2), 50, now_in_usecs + 20000),
        proof_of_store(
            author_0,
            BatchId::new_for_test(3),
            300,
            now_in_usecs + 10000,
        ),
    ];

    let author_1_batches = vec![
        proof_of_store(
            author_1,
            BatchId::new_for_test(4),
            500,
            now_in_usecs + 20000,
        ),
        proof_of_store(
            author_1,
            BatchId::new_for_test(5),
            400,
            now_in_usecs + 30000,
        ),
        proof_of_store(
            author_1,
            BatchId::new_for_test(6),
            600,
            now_in_usecs + 50000,
        ),
        proof_of_store(author_1, BatchId::new_for_test(7), 50, now_in_usecs + 60000),
    ];

    let info_1 = author_0_batches[0].info().clone();
    let info_2 = author_0_batches[1].info().clone();
    let info_3 = author_0_batches[2].info().clone();
    let info_4 = author_0_batches[3].info().clone();
    let info_5 = author_1_batches[0].info().clone();
    let info_6 = author_1_batches[1].info().clone();
    let info_7 = author_1_batches[2].info().clone();
    let info_8 = author_1_batches[3].info().clone();

    proof_queue.insert_batches(vec![(info_1.clone(), vec![txns[0]])]);
    // batch_summaries: [1 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (0, 0));
    assert_eq!(proof_queue.batch_summaries_len(), 1);

    proof_queue.insert_proof(author_0_batches[0].clone());
    // txns: [txn_0]
    // proofs: [1]
    // batch_summaries: [1 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (1, 1));
    assert_eq!(proof_queue.batch_summaries_len(), 1);

    proof_queue.insert_proof(author_0_batches[1].clone());
    // txns: [txn_0] + txns(proof_2)
    // proofs: [1, 2]
    // batch_summaries: [1 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 1);

    proof_queue.insert_batches(vec![(info_2, vec![txns[1]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 2);

    proof_queue.insert_batches(vec![(info_3.clone(), vec![txns[0]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    // Adding the batch again shouldn't have an effect
    proof_queue.insert_batches(vec![(info_3.clone(), vec![txns[0]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_proof(author_0_batches[2].clone());
    // txns: [txn_0, txn_1]
    // proofs: [1, 2, 3]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 3));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    // Adding the batch again shouldn't have an effect
    proof_queue.insert_batches(vec![(info_3.clone(), vec![txns[0]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2, 3]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 3));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_proof(author_1_batches[0].clone());
    // txns: [txn_0, txn_1] + txns(proof_5)
    // proofs: [1, 2, 3, 5]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (3, 4));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_batches(vec![(info_5, vec![txns[1]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2, 3, 5]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0, 5 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 4));
    assert_eq!(proof_queue.batch_summaries_len(), 4);

    proof_queue.insert_batches(vec![(info_4, vec![txns[2]])]);
    // txns: [txn_0, txn_1]
    // proofs: [1, 2, 3, 5]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0, 4 -> txn_2, 5 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 4));
    assert_eq!(proof_queue.batch_summaries_len(), 5);

    proof_queue.insert_proof(author_0_batches[3].clone());
    // txns: [txn_0, txn_1, txn_2]
    // proofs: [1, 2, 3, 4, 5]
    // batch_summaries: [1 -> txn_0, 2 -> txn_1, 3 -> txn_0, 4 -> txn_2, 5 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (3, 5));
    assert_eq!(proof_queue.batch_summaries_len(), 5);

    proof_queue.mark_committed(vec![info_1.clone()]);
    // txns: [txn_0, txn_1, txn_2]
    // proofs: [2, 3, 4, 5]
    // batch_summaries: [2 -> txn_1, 3 -> txn_0, 4 -> txn_2, 5 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (3, 4));
    assert_eq!(proof_queue.batch_summaries_len(), 4);

    proof_queue.insert_proof(author_1_batches[1].clone());
    // txns: [txn_0, txn_1, txn_2] + txns(proof_6)
    // proofs: [2, 3, 4, 5, 6]
    // batch_summaries: [2 -> txn_1, 3 -> txn_0, 4 -> txn_2, 5 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (4, 5));
    assert_eq!(proof_queue.batch_summaries_len(), 4);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 20000);
    // Expires info_3, info_4, info_5
    // txns: [txn_1] + txns(proof_6)
    // proofs: [2, 6]
    // batch_summaries: [2 -> txn_1]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 1);

    // Adding an expired batch again
    proof_queue.insert_batches(vec![(info_3, vec![txns[0]])]);
    // txns: [txn_1] + txns(proof_6)
    // proofs: [2, 6]
    // batch_summaries: [2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 2);

    // Adding an expired proof again. Should have no effect
    proof_queue.insert_proof(author_0_batches[2].clone());
    // txns: [txn_1] + txns(proof_6)
    // proofs: [2, 6]
    // batch_summaries: [2 -> txn_1, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 2);

    proof_queue.insert_batches(vec![(info_7, vec![txns[3]])]);
    // txns: [txn_1] + txns(proof_6)
    // proofs: [2, 6]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 3 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 30000);
    // Expires info_6, info_3
    // txns: [txn_1]
    // proofs: [2]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (1, 1));
    assert_eq!(proof_queue.batch_summaries_len(), 2);

    proof_queue.insert_batches(vec![(info_6, vec![txns[0]])]);
    // Expired batch not added to batch summaries
    // txns: [txn_1]
    // proofs: [2]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (1, 1));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_proof(author_1_batches[2].clone());
    // txns: [txn_1, txn_3]
    // proofs: [2, 7]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_proof(author_1_batches[3].clone());
    // txns: [txn_1, txn_3] + txns(proof_8)
    // proofs: [2, 7, 8]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (3, 3));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.mark_committed(vec![info_8.clone()]);
    // txns: [txn_1, txn_3]
    // proofs: [2, 7]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_batches(vec![(info_8, vec![txns[0]])]);
    // Committed batch not added to batch summaries
    // txns: [txn_1, txn_3]
    // proofs: [2, 7]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.insert_proof(author_1_batches[3].clone());
    // Committed proof added again. Should have no effect
    // txns: [txn_1, txn_3]
    // proofs: [2, 7, 8]
    // batch_summaries: [2 -> txn_1, 7 -> txn_3, 6 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (2, 2));
    assert_eq!(proof_queue.batch_summaries_len(), 3);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 70000);
    // Expires info_2, info_7
    // txns: []
    // proofs: []
    // batch_summaries: [3 -> txn_0, 6 -> txn_0, 8 -> txn_0]
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (0, 0));
    assert_eq!(proof_queue.batch_summaries_len(), 0);
}

#[tokio::test]
async fn test_proof_pull_proofs_with_duplicates() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);
    let now_in_secs = aptos_infallible::duration_since_epoch().as_secs() as u64;
    let now_in_usecs = now_in_secs * 1_000_000;
    let txns = vec![
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(0),
            now_in_secs + 2,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(1),
            now_in_secs + 1,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(2),
            now_in_secs + 3,
            HashValue::zero(),
        ),
        TxnSummaryWithExpiration::new(
            PeerId::ONE,
            ReplayProtector::SequenceNumber(3),
            now_in_secs + 4,
            HashValue::zero(),
        ),
    ];

    let author_0 = PeerId::random();
    let author_1 = PeerId::random();

    let author_0_batches = vec![
        proof_of_store(
            author_0,
            BatchId::new_for_test(0),
            100,
            now_in_usecs + 1_100_000,
        ),
        proof_of_store(
            author_0,
            BatchId::new_for_test(1),
            200,
            now_in_usecs + 3_000_000,
        ),
        proof_of_store(
            author_0,
            BatchId::new_for_test(2),
            50,
            now_in_usecs + 5_000_000,
        ),
        proof_of_store(
            author_0,
            BatchId::new_for_test(3),
            300,
            now_in_usecs + 4_000_000,
        ),
    ];

    let author_1_batches = vec![
        proof_of_store(
            author_1,
            BatchId::new_for_test(4),
            500,
            now_in_usecs + 4_000_000,
        ),
        proof_of_store(
            author_1,
            BatchId::new_for_test(5),
            400,
            now_in_usecs + 2_500_000,
        ),
        proof_of_store(
            author_1,
            BatchId::new_for_test(6),
            600,
            now_in_usecs + 3_500_000,
        ),
        proof_of_store(
            author_1,
            BatchId::new_for_test(7),
            50,
            now_in_usecs + 4_500_000,
        ),
    ];

    let info_0 = author_0_batches[0].info().clone();
    let info_7 = author_1_batches[2].info().clone();

    proof_queue.insert_batches(vec![(author_0_batches[0].info().clone(), vec![txns[0]])]);
    proof_queue.insert_batches(vec![(author_0_batches[1].info().clone(), vec![txns[1]])]);
    proof_queue.insert_batches(vec![(author_0_batches[2].info().clone(), vec![txns[2]])]);
    proof_queue.insert_batches(vec![(author_0_batches[3].info().clone(), vec![txns[0]])]);

    for batch in author_0_batches {
        proof_queue.insert_proof(batch);
    }

    proof_queue.insert_batches(vec![(author_1_batches[0].info().clone(), vec![txns[1]])]);
    proof_queue.insert_batches(vec![(author_1_batches[1].info().clone(), vec![txns[2]])]);
    proof_queue.insert_batches(vec![(author_1_batches[2].info().clone(), vec![txns[3]])]);
    proof_queue.insert_batches(vec![(author_1_batches[3].info().clone(), vec![txns[0]])]);

    for batch in author_1_batches {
        proof_queue.insert_proof(batch);
    }
    assert_eq!(proof_queue.remaining_txns_and_proofs(), (4, 8));

    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs),
    );
    assert_eq!(result.2, 4);

    let mut pulled_txns = HashSet::new();
    for proof in result.0 {
        match proof.batch_id() {
            BatchId { id: 0, nonce: 0 } => pulled_txns.insert(0),
            BatchId { id: 1, nonce: 0 } => pulled_txns.insert(1),
            BatchId { id: 2, nonce: 0 } => pulled_txns.insert(2),
            BatchId { id: 3, nonce: 0 } => pulled_txns.insert(0),
            BatchId { id: 4, nonce: 0 } => pulled_txns.insert(1),
            BatchId { id: 5, nonce: 0 } => pulled_txns.insert(2),
            BatchId { id: 6, nonce: 0 } => pulled_txns.insert(3),
            BatchId { id: 7, nonce: 0 } => pulled_txns.insert(0),
            _ => panic!("Unexpected batch id"),
        };
    }
    assert_eq!(pulled_txns.len(), 4);

    let result = proof_queue.pull_proofs(
        &hashset![info_0.clone()],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs),
    );
    assert_eq!(result.0.len(), 7);
    // filtered_txns: txn_0 (included in excluded batches)
    assert_eq!(result.2, 3);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 500_000);
    // Nothing changes
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        5,
        5,
        true,
        Duration::from_micros(now_in_usecs + 500_100),
    );
    assert_eq!(result.2, 4);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 1_000_000);
    // txn_1 expired
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        5,
        5,
        true,
        Duration::from_micros(now_in_usecs + 1_000_100),
    );
    assert_eq!(result.0.len(), 8);
    assert_eq!(result.2, 3);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 1_200_000);
    // author_0_batches[0] is removed. txn_1 expired.
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 1_200_100),
    );
    assert_eq!(result.0.len(), 7);
    assert_eq!(result.2, 3);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 2_000_000);
    // author_0_batches[0] is removed. txn_0, txn_1 are expired.
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 2_000_100),
    );
    assert_eq!(result.0.len(), 7);
    assert_eq!(result.2, 2);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 2_500_000);
    // author_0_batches[0], author_1_batches[1] is removed. txn_0, txn_1 is expired.
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 2_500_100),
    );
    assert_eq!(result.0.len(), 6);
    assert_eq!(result.2, 2);

    let result = proof_queue.pull_proofs(
        &hashset![info_7],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 2_500_100),
    );
    // author_0_batches[0], author_1_batches[1] is removed. author_1_batches[2] is excluded. txn_0, txn_1 are expired.
    assert_eq!(result.0.len(), 5);
    assert_eq!(result.2, 1);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 3_000_000);
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        8,
        8,
        true,
        Duration::from_micros(now_in_usecs + 3_000_100),
    );
    // author_0_batches[0], author_0_batches[1], author_1_batches[1] are removed. txn_0, txn_1, txn_2 are expired.
    assert_eq!(result.0.len(), 5);
    assert_eq!(result.2, 1);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 3_500_000);
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 3_500_100),
    );
    // author_0_batches[0], author_0_batches[1], author_1_batches[1], author_1_batches[2] are removed. txn_0, txn_1, txn_0 are expired.
    assert_eq!(result.0.len(), 4);
    assert_eq!(result.2, 0);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 4_000_000);
    let result = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(8, 400),
        4,
        4,
        true,
        Duration::from_micros(now_in_usecs + 4_000_100),
    );
    // author_0_batches[0], author_0_batches[1], author_0_batches[3], author_1_batches[0], author_1_batches[1], author_1_batches[2] are removed.
    // txn_0, txn_1, txn_2 are expired.
    assert_eq!(result.0.len(), 2);
    assert_eq!(result.2, 0);

    proof_queue.handle_updated_block_timestamp(now_in_usecs + 5_000_000);
    assert!(proof_queue.is_empty());
}

#[tokio::test]
async fn test_proof_queue_soft_limit() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();

    let author_batches = vec![
        proof_of_store_with_size(author, BatchId::new_for_test(0), 100, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(1), 200, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(2), 200, 1, 10),
    ];
    for batch in author_batches {
        proof_queue.insert_proof(batch);
    }

    let (pulled, _, num_unique_txns, _) = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(100, 100),
        12,
        12,
        true,
        aptos_infallible::duration_since_epoch(),
    );

    assert_eq!(pulled.len(), 1);
    assert_eq!(num_unique_txns, 10);

    let (pulled, _, num_unique_txns, _) = proof_queue.pull_proofs(
        &hashset![],
        PayloadTxnsSize::new(100, 100),
        30,
        12,
        true,
        aptos_infallible::duration_since_epoch(),
    );

    assert_eq!(pulled.len(), 2);
    assert_eq!(num_unique_txns, 20);
}

#[tokio::test]
async fn test_proof_queue_insert_after_commit() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let author_batches = vec![
        proof_of_store_with_size(author, BatchId::new_for_test(0), 100, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(1), 200, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(2), 200, 1, 10),
    ];
    let batch_infos = author_batches
        .iter()
        .map(|proof| proof.info().clone())
        .collect();

    proof_queue.mark_committed(batch_infos);

    for proof in author_batches {
        proof_queue.insert_proof(proof);
    }

    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_txns, 0);
    assert_eq!(remaining_proofs, 0);

    proof_queue.handle_updated_block_timestamp(10);

    assert!(proof_queue.is_empty());
}

#[tokio::test]
async fn test_proof_queue_pull_full_utilization() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let author_batches = vec![
        proof_of_store_with_size(author, BatchId::new_for_test(0), 100, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(1), 200, 1, 10),
        proof_of_store_with_size(author, BatchId::new_for_test(2), 200, 1, 10),
    ];

    for proof in author_batches {
        proof_queue.insert_proof(proof);
    }

    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_txns, 30);
    assert_eq!(remaining_proofs, 3);

    let now_in_secs = aptos_infallible::duration_since_epoch();
    let (proof_block, txns_with_proof_size, cur_unique_txns, proof_queue_fully_utilized) =
        proof_queue.pull_proofs(
            &HashSet::new(),
            PayloadTxnsSize::new(10, 10),
            10,
            10,
            true,
            now_in_secs,
        );

    assert_eq!(proof_block.len(), 1);
    assert_eq!(txns_with_proof_size.count(), 10);
    assert_eq!(cur_unique_txns, 10);
    assert!(!proof_queue_fully_utilized);

    let now_in_secs = aptos_infallible::duration_since_epoch();
    let (proof_block, txns_with_proof_size, cur_unique_txns, proof_queue_fully_utilized) =
        proof_queue.pull_proofs(
            &HashSet::new(),
            PayloadTxnsSize::new(50, 50),
            50,
            50,
            true,
            now_in_secs,
        );

    assert_eq!(proof_block.len(), 3);
    assert_eq!(txns_with_proof_size.count(), 30);
    assert_eq!(cur_unique_txns, 30);
    assert!(proof_queue_fully_utilized);

    proof_queue.handle_updated_block_timestamp(10);
    assert!(proof_queue.is_empty());
}

/// Build a BatchInfo with a deterministic (non-random) digest so two calls with the same
/// `num_txns` produce the same BatchInfo, and calls with different `num_txns` produce
/// different ones — giving us a proper collision: same (author, batch_id), different metadata.
///
/// Expiration is set to `u64::MAX` so that `gc_expired_batch_summaries_without_proofs` never
/// evicts the entry during the test.
fn batch_info_with_num_txns(
    author: PeerId,
    batch_id: BatchId,
    gas_bucket_start: u64,
    num_txns: u64,
) -> BatchInfo {
    let digest = HashValue::sha3_256_of(&num_txns.to_le_bytes());
    BatchInfo::new(
        author,
        batch_id,
        0,
        u64::MAX, // far-future expiration — never GC'd by wall-clock
        digest,
        num_txns,
        num_txns,
        gas_bucket_start,
    )
}

/// Regression test: a batch summary is inserted first, then a proof arrives for the same
/// (author, batch_id) key but with different metadata.  The proof must be rejected.
#[tokio::test]
async fn test_proof_queue_rejects_batch_key_collision() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let batch_id = BatchId::new_for_test(0);

    // Insert a batch summary with num_txns = 5.
    let summary_info = batch_info_with_num_txns(author, batch_id, 100, 5);
    proof_queue.insert_batches(vec![(summary_info, vec![])]);

    // A proof for the same (author, batch_id) but num_txns = 100 must be rejected.
    let colliding_proof = ProofOfStore::new(
        batch_info_with_num_txns(author, batch_id, 100, 100),
        AggregateSignature::empty(),
    );
    proof_queue.insert_proof(colliding_proof);

    // The collision was rejected: no proof is tracked.
    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_proofs, 0, "colliding proof must not be counted");
    assert_eq!(remaining_txns, 0);

    // The batch summary is still present.
    assert_eq!(proof_queue.batch_summaries_len(), 1);
}

/// Regression test: a proof arrives first, then a second proof for the same (author, batch_id)
/// key arrives with different metadata.  The second proof must be rejected.
#[tokio::test]
async fn test_proof_queue_rejects_batch_key_collision_proof_first() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let batch_id = BatchId::new_for_test(1);

    // Insert the legitimate proof (num_txns = 5).
    let proof_v1 = ProofOfStore::new(
        batch_info_with_num_txns(author, batch_id, 100, 5),
        AggregateSignature::empty(),
    );
    proof_queue.insert_proof(proof_v1);

    let (txns_after_first, proofs_after_first) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(proofs_after_first, 1);
    assert_eq!(txns_after_first, 5);

    // A second proof with the same (author, batch_id) but num_txns = 100 must be rejected.
    let proof_v2 = ProofOfStore::new(
        batch_info_with_num_txns(author, batch_id, 100, 100),
        AggregateSignature::empty(),
    );
    proof_queue.insert_proof(proof_v2);

    // Accounting must be unchanged — the colliding proof was dropped.
    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_proofs, 1, "only the original proof must be counted");
    assert_eq!(remaining_txns, 5, "txn count must reflect original proof only");
}

/// Regression test: a proof is inserted first, then a batch summary for the same
/// (author, batch_id) key arrives with different metadata.  The summary must be rejected.
#[tokio::test]
async fn test_proof_queue_rejects_batch_summary_collision() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let batch_id = BatchId::new_for_test(2);

    // Insert the legitimate proof (num_txns = 5).
    let proof = ProofOfStore::new(
        batch_info_with_num_txns(author, batch_id, 100, 5),
        AggregateSignature::empty(),
    );
    proof_queue.insert_proof(proof);

    // A batch summary with the same key but num_txns = 100 must be rejected.
    let colliding_summary = batch_info_with_num_txns(author, batch_id, 100, 100);
    proof_queue.insert_batches(vec![(colliding_summary, vec![])]);

    // Proof accounting must be unchanged.
    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_proofs, 1);
    assert_eq!(remaining_txns, 5, "txn count must not be corrupted by colliding summary");

    // No batch summary must have been recorded.
    assert_eq!(proof_queue.batch_summaries_len(), 0);
}

/// Regression test: mark_committed must use the stored item's num_txns for accounting,
/// not the num_txns from the caller-supplied BatchInfo.  A colliding BatchInfo with a
/// larger num_txns previously caused an integer underflow / panic.
#[tokio::test]
async fn test_mark_committed_with_colliding_info_uses_stored_num_txns() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let batch_id = BatchId::new_for_test(3);

    // Insert a proof with num_txns = 5; remaining counter becomes 5.
    let proof = ProofOfStore::new(
        batch_info_with_num_txns(author, batch_id, 100, 5),
        AggregateSignature::empty(),
    );
    proof_queue.insert_proof(proof);

    let (txns_before, proofs_before) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(proofs_before, 1);
    assert_eq!(txns_before, 5);

    // Call mark_committed with a BatchInfo for the same key but num_txns = 1_000_000.
    // Before the fix this would underflow (5 - 1_000_000) and panic in debug mode.
    let colliding_commit_info =
        batch_info_with_num_txns(author, batch_id, 100, 1_000_000);
    proof_queue.mark_committed(vec![colliding_commit_info]);

    // The counter must have been decremented by the stored 5, not the caller's 1_000_000.
    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_proofs, 0);
    assert_eq!(remaining_txns, 0, "accounting must use stored num_txns, not caller's");
}

/// Exact retransmits (same key, same metadata) must still be accepted as a no-op.
#[tokio::test]
async fn test_proof_queue_accepts_identical_resend() {
    let my_peer_id = PeerId::random();
    let batch_store = batch_store_for_test(5 * 1024 * 1024);
    let mut proof_queue = BatchProofQueue::new(my_peer_id, batch_store, 1);

    let author = PeerId::random();
    let batch_id = BatchId::new_for_test(4);
    let info = batch_info_with_num_txns(author, batch_id, 100, 7);

    let proof1 = ProofOfStore::new(info.clone(), AggregateSignature::empty());
    let proof2 = ProofOfStore::new(info, AggregateSignature::empty());

    proof_queue.insert_proof(proof1);
    proof_queue.insert_proof(proof2); // identical resend — must not panic or double-count

    let (remaining_txns, remaining_proofs) = proof_queue.remaining_txns_and_proofs();
    assert_eq!(remaining_proofs, 1, "duplicate proof must not be double-counted");
    assert_eq!(remaining_txns, 7);
}
