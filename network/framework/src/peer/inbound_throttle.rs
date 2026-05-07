// Copyright (c) Movement Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    counters,
    peer_manager::PeerManagerError,
    protocols::{
        stream::StreamMessage,
        wire::messaging::v1::{MultiplexMessage, ReadError},
    },
};
use aptos_logger::debug;
use aptos_time_service::{TimeService, TimeServiceTrait};
use std::time::{Duration, Instant};

const MSG_RATE_LABEL: &str = "msg_rate";
const BYTE_RATE_LABEL: &str = "byte_rate";

/// A leaky-bucket style rate controller that tracks available capacity and
/// replenishes it over time.
struct LeakyBucket {
    available: f64,
    max_capacity: u64,
    per_second: u64,
    last_update: Instant,
}

impl LeakyBucket {
    fn new(max_capacity: u64, per_second: u64) -> Self {
        Self {
            available: max_capacity as f64,
            max_capacity,
            per_second,
            last_update: Instant::now(),
        }
    }

    /// Replenish tokens based on wall-clock time since last call.
    fn replenish(&mut self) {
        let now = Instant::now();
        let delta = now.duration_since(self.last_update);
        let added = delta.as_secs_f64() * self.per_second as f64;
        self.available = (self.available + added).min(self.max_capacity as f64);
        self.last_update = now;
    }

    /// Attempt to spend `cost` units from the bucket.
    ///
    /// - `Ok(())` — cost was deducted successfully.
    /// - `Err(Some(d))` — not enough capacity right now; caller should wait `d`.
    /// - `Err(None)` — cost exceeds the bucket's max capacity and can never be satisfied.
    fn try_spend(&mut self, cost: u64) -> Result<(), Option<Duration>> {
        if cost > self.max_capacity {
            return Err(None);
        }

        self.replenish();

        if self.available >= cost as f64 {
            self.available -= cost as f64;
            Ok(())
        } else {
            let shortfall = cost as f64 - self.available;
            let wait = shortfall / self.per_second as f64;
            Err(Some(Duration::from_secs_f64(wait)))
        }
    }
}

/// Per-peer inbound throttle that limits message rate and byte rate using
/// leaky buckets. Constructed once per accepted connection and owned by the
/// [`Peer`](super::Peer) actor.
pub struct PeerInboundThrottle {
    byte_bucket: Option<LeakyBucket>,
    msg_bucket: Option<LeakyBucket>,
    time_service: TimeService,
}

impl PeerInboundThrottle {
    /// Build a throttle from the given per-second limits.
    /// Returns `None` when both limits are `None` (throttling disabled).
    pub fn new(
        msg_per_sec: Option<u64>,
        bytes_per_sec: Option<u64>,
        time_service: TimeService,
    ) -> Option<Self> {
        if msg_per_sec.is_none() && bytes_per_sec.is_none() {
            return None;
        }

        let msg_bucket = msg_per_sec.map(|r| LeakyBucket::new(r, r));
        let byte_bucket = bytes_per_sec.map(|r| LeakyBucket::new(r, r));

        Some(Self {
            byte_bucket,
            msg_bucket,
            time_service,
        })
    }

    /// Block until both buckets can accommodate the given message, or return
    /// an error if the message exceeds a bucket's maximum capacity.
    pub async fn check_and_wait(
        &mut self,
        message: &Result<MultiplexMessage, ReadError>,
    ) -> Result<(), PeerManagerError> {
        let (msg_cost, byte_cost) = compute_message_cost(message);

        if let Some(bucket) = &mut self.msg_bucket {
            if msg_cost > 0 {
                acquire_or_wait(bucket, msg_cost, &self.time_service, MSG_RATE_LABEL).await?;
            }
        }
        if let Some(bucket) = &mut self.byte_bucket {
            if byte_cost > 0 {
                acquire_or_wait(bucket, byte_cost, &self.time_service, BYTE_RATE_LABEL).await?;
            }
        }

        Ok(())
    }
}

/// Determine how many message-units and bytes a [`MultiplexMessage`] costs.
///
/// Stream fragments do not count as a new message (only headers do) but their
/// bytes are still accounted for.
fn compute_message_cost(message: &Result<MultiplexMessage, ReadError>) -> (u64, u64) {
    match message {
        Ok(MultiplexMessage::Message(msg)) => (1, msg.data_len() as u64),
        Ok(MultiplexMessage::Stream(StreamMessage::Header(h))) => {
            (1, h.message.data_len() as u64)
        },
        Ok(MultiplexMessage::Stream(StreamMessage::Fragment(f))) => {
            (0, f.raw_data.len() as u64)
        },
        Err(_) => (0, 0),
    }
}

/// Spin on the bucket until `cost` tokens are available, sleeping in between.
async fn acquire_or_wait(
    bucket: &mut LeakyBucket,
    cost: u64,
    time_service: &TimeService,
    label: &'static str,
) -> Result<(), PeerManagerError> {
    loop {
        match bucket.try_spend(cost) {
            Ok(()) => return Ok(()),
            Err(Some(delay)) => {
                debug!(
                    "Peer throttle: {} bucket short {} tokens, backing off {:?}",
                    label, cost, delay
                );
                counters::inc_peer_throttle_delayed(label);
                time_service.sleep(delay).await;
            },
            Err(None) => {
                counters::inc_peer_throttle_rejected(label);
                return Err(PeerManagerError::InboundThrottleCapacityExceeded);
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        protocols::{
            stream::{StreamFragment, StreamHeader},
            wire::messaging::v1::{DirectSendMsg, NetworkMessage},
        },
        ProtocolId,
    };
    use aptos_time_service::MockTimeService;
    use std::io;

    #[test]
    fn cost_of_direct_send() {
        let msg = make_direct_send(42);
        let (msgs, bytes) = compute_message_cost(&msg);
        assert_eq!(msgs, 1);
        assert_eq!(bytes, 42);
    }

    #[test]
    fn cost_of_stream_header() {
        let msg = make_stream_header(20);
        let (msgs, bytes) = compute_message_cost(&msg);
        assert_eq!(msgs, 1);
        assert_eq!(bytes, 20);
    }

    #[test]
    fn cost_of_stream_fragment() {
        let msg = make_stream_fragment(15);
        let (msgs, bytes) = compute_message_cost(&msg);
        assert_eq!(msgs, 0);
        assert_eq!(bytes, 15);
    }

    #[test]
    fn cost_of_error_is_zero() {
        let io_err = io::Error::other("test error");
        let (msgs, bytes) = compute_message_cost(&Err(ReadError::IoError(io_err)));
        assert_eq!(msgs, 0);
        assert_eq!(bytes, 0);
    }

    #[test]
    fn disabled_when_no_limits() {
        let ts = TimeService::mock();
        assert!(PeerInboundThrottle::new(None, None, ts).is_none());
    }

    #[test]
    fn enabled_with_byte_limit_only() {
        let ts = TimeService::mock();
        assert!(PeerInboundThrottle::new(None, Some(100), ts).is_some());
    }

    #[test]
    fn enabled_with_msg_limit_only() {
        let ts = TimeService::mock();
        assert!(PeerInboundThrottle::new(Some(10), None, ts).is_some());
    }

    #[tokio::test]
    async fn within_budget_passes_immediately() {
        let (mut t, _) = build_throttle(10, 1000);
        let msg = make_direct_send(100);
        t.check_and_wait(&msg).await.unwrap();
    }

    #[tokio::test]
    async fn rejects_when_bytes_exceed_capacity() {
        let (mut t, _) = build_throttle(50, 1);
        let msg = make_direct_send(100);
        let res = t.check_and_wait(&msg).await;
        assert!(matches!(res, Err(PeerManagerError::InboundThrottleCapacityExceeded)));
    }

    #[tokio::test]
    async fn rejects_when_msg_limit_is_zero() {
        let (mut t, _) = build_throttle(0, 1000);
        let msg = make_direct_send(100);
        let res = t.check_and_wait(&msg).await;
        assert!(matches!(res, Err(PeerManagerError::InboundThrottleCapacityExceeded)));
    }

    #[tokio::test]
    async fn blocks_then_resumes_after_refill() {
        let (mut t, mock_time) = build_throttle(100, 100);

        let task = tokio::spawn(async move {
            t.check_and_wait(&make_direct_send(100)).await.unwrap();
            t.check_and_wait(&make_direct_send(100)).await
        });

        tokio::task::yield_now().await;
        mock_time.advance_secs_async(1).await;

        task.await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn msg_token_refill_unblocks() {
        let (mut t, mock_time) = build_throttle(1, 1000);

        let task = tokio::spawn(async move {
            t.check_and_wait(&make_direct_send(1)).await.unwrap();
            t.check_and_wait(&make_direct_send(1)).await
        });

        tokio::task::yield_now().await;
        mock_time.advance_secs_async(1).await;

        task.await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn fragments_skip_msg_accounting() {
        let (mut t, _) = build_throttle(0, 1000);
        for _ in 0..10 {
            t.check_and_wait(&make_stream_fragment(0)).await.unwrap();
        }
    }

    #[tokio::test]
    async fn fragment_bytes_still_counted() {
        let (mut t, mock_time) = build_throttle(1000, 50);

        let task = tokio::spawn(async move {
            t.check_and_wait(&make_stream_fragment(50)).await.unwrap();
            t.check_and_wait(&make_stream_fragment(50)).await
        });

        tokio::task::yield_now().await;
        mock_time.advance_secs_async(1).await;

        task.await.unwrap().unwrap();
    }

    // -- helpers --

    fn make_direct_send(n: usize) -> Result<MultiplexMessage, ReadError> {
        Ok(MultiplexMessage::Message(NetworkMessage::DirectSendMsg(
            DirectSendMsg {
                protocol_id: ProtocolId::ConsensusDirectSendJson,
                priority: 0,
                raw_msg: vec![0u8; n],
            },
        )))
    }

    fn make_stream_header(n: usize) -> Result<MultiplexMessage, ReadError> {
        let message = NetworkMessage::DirectSendMsg(DirectSendMsg {
            protocol_id: ProtocolId::ConsensusDirectSendJson,
            priority: 0,
            raw_msg: vec![0u8; n],
        });
        Ok(MultiplexMessage::Stream(StreamMessage::Header(
            StreamHeader {
                request_id: 0,
                num_fragments: 1,
                message,
            },
        )))
    }

    fn make_stream_fragment(n: usize) -> Result<MultiplexMessage, ReadError> {
        Ok(MultiplexMessage::Stream(StreamMessage::Fragment(
            StreamFragment {
                request_id: 0,
                fragment_id: 0,
                raw_data: vec![0u8; n],
            },
        )))
    }

    fn build_throttle(
        msg_per_sec: u64,
        bytes_per_sec: u64,
    ) -> (PeerInboundThrottle, MockTimeService) {
        let mock = MockTimeService::new();
        let ts = TimeService::from_mock(mock.clone());
        let throttle = PeerInboundThrottle::new(
            Some(msg_per_sec),
            Some(bytes_per_sec),
            ts,
        )
        .unwrap();
        (throttle, mock)
    }
}
