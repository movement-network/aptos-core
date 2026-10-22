// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{stream_coordinator::IndexerStreamCoordinator, ServiceContext};
use aptos_logger::{error, info};
use aptos_protos::{
    indexer::v1::{raw_data_server::RawData, GetTransactionsRequest, TransactionsResponse},
    internal::fullnode::v1::transactions_from_node_response,
};
use futures::Stream;
use std::pin::Pin;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;
use tonic::{Request, Response, Status};

// Default Values
pub const DEFAULT_NUM_RETRIES: usize = 3;
pub const RETRY_TIME_MILLIS: u64 = 100;
const TRANSACTION_CHANNEL_SIZE: usize = 35;

type TransactionResponseStream =
    Pin<Box<dyn Stream<Item = Result<TransactionsResponse, Status>> + Send>>;

pub struct LocalnetDataService {
    pub service_context: ServiceContext,
}

/// External service on the fullnode is for testing/local development only.
/// Performance is not optimized, e.g., single-threaded.
/// NOTE: code is duplicated from fullnode_data_service.rs with some minor changes.
#[tonic::async_trait]
impl RawData for LocalnetDataService {
    type GetTransactionsStream = TransactionResponseStream;

    async fn get_transactions(
        &self,
        req: Request<GetTransactionsRequest>,
    ) -> Result<Response<Self::GetTransactionsStream>, Status> {
        // Some node metadata
        let context = self.service_context.context.clone();
        let r = req.into_inner();
        // A missing starting version means "latest", as in the indexer-grpc data service; it must
        // not panic the node (aptos-indexer-processor-sdk v2.4.1 get_chain_id sends None).
        let starting_version = resolve_starting_version(r.starting_version, || {
            Ok(context.get_latest_ledger_info_wrapped()?.ledger_version.0)
        })?;
        let ending_version = if let Some(count) = r.transactions_count {
            starting_version.saturating_add(count)
        } else {
            u64::MAX
        };
        let processor_batch_size = self.service_context.processor_batch_size;
        let output_batch_size = self.service_context.output_batch_size;
        let ledger_chain_id = context.chain_id().id();
        let transactions_count = r.transactions_count;
        // Creates a channel to send the stream to the client
        let (tx, mut rx) = mpsc::channel(TRANSACTION_CHANNEL_SIZE);
        let (external_service_tx, external_service_rx) = mpsc::channel(TRANSACTION_CHANNEL_SIZE);

        tokio::spawn(async move {
            // Initialize the coordinator that tracks starting version and processes transactions
            let mut coordinator = IndexerStreamCoordinator::new(
                context,
                starting_version,
                ending_version,
                // Performance is not important for raw data, and to make sure data is in order,
                // single thread is used.
                1,
                processor_batch_size,
                output_batch_size,
                tx.clone(),
            );
            while coordinator.current_version < coordinator.end_version {
                // Processes and sends batch of transactions to client
                let results = coordinator.process_next_batch().await;
                if results.is_empty() {
                    info!(
                        start_version = starting_version,
                        chain_id = ledger_chain_id,
                        "[Indexer Fullnode] Client disconnected."
                    );
                    break;
                }
                let max_version = match IndexerStreamCoordinator::get_max_batch_version(results) {
                    Ok(max_version) => max_version,
                    Err(e) => {
                        error!("[indexer-grpc] Error sending to stream: {}", e);
                        break;
                    },
                };
                coordinator.current_version = max_version + 1;
            }
        });
        tokio::spawn(async move {
            let mut response_transactions_count = transactions_count;
            while let Some(response) = rx.recv().await {
                if let Some(count) = response_transactions_count.as_ref() {
                    if *count == 0 {
                        break;
                    }
                }

                let response = response.map(|t| TransactionsResponse {
                    chain_id: Some(ledger_chain_id as u64),
                    transactions: match t.response.expect("Response must be set") {
                        transactions_from_node_response::Response::Data(transaction_output) => {
                            let mut transactions = transaction_output.transactions;
                            let current_transactions_count = transactions.len() as u64;
                            if let Some(count) = response_transactions_count.as_mut() {
                                transactions =
                                    transactions.into_iter().take(*count as usize).collect();
                                *count = count.saturating_sub(current_transactions_count);
                            }
                            transactions
                        },
                        _ => panic!("Unexpected response type."),
                    },
                    processed_range: None,
                });
                match external_service_tx.send(response).await {
                    Ok(_) => {},
                    Err(e) => {
                        aptos_logger::warn!(
                            "[indexer-grpc] Unable to send end batch status: {:?}",
                            e
                        );
                        break;
                    },
                }
            }
        });

        let output_stream = ReceiverStream::new(external_service_rx);
        Ok(Response::new(
            Box::pin(output_stream) as Self::GetTransactionsStream
        ))
    }
}

/// Resolves the requested starting version. `None` means the latest committed version, so a client
/// that asks for "the latest transaction" gets one immediately instead of waiting for a new commit.
fn resolve_starting_version(
    requested: Option<u64>,
    latest: impl FnOnce() -> anyhow::Result<u64>,
) -> Result<u64, Status> {
    match requested {
        Some(version) => Ok(version),
        None => latest().map_err(|e| {
            Status::unavailable(format!("Unable to read the latest ledger version: {e}"))
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::resolve_starting_version;
    use tonic::Code;

    #[test]
    fn explicit_starting_version_is_used() {
        let version = resolve_starting_version(Some(7), || panic!("latest must not be read"));
        assert_eq!(version.unwrap(), 7);
    }

    #[test]
    fn missing_starting_version_resolves_to_latest() {
        assert_eq!(resolve_starting_version(None, || Ok(42)).unwrap(), 42);
    }

    #[test]
    fn missing_starting_version_with_unreadable_ledger_is_an_error_not_a_panic() {
        let status =
            resolve_starting_version(None, || Err(anyhow::anyhow!("db down"))).unwrap_err();
        assert_eq!(status.code(), Code::Unavailable);
    }
}
