// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Per-peer token-bucket rate limiter for inbound transaction broadcasts.
//!
//! Each peer gets an independent bucket that refills at `rate` tokens per
//! second up to a maximum of `capacity` tokens.  When a broadcast arrives the
//! coordinator calls [`PeerRateLimiter::try_acquire`] which returns the number
//! of transactions the peer is allowed to submit right now — the rest should be
//! dropped before validation.

use aptos_config::network_id::PeerNetworkId;
use std::{
    collections::HashMap,
    time::Instant,
};

/// A single token bucket.
#[derive(Debug, Clone)]
struct TokenBucket {
    tokens: f64,
    capacity: f64,
    rate: f64, // tokens per second
    last_refill: Instant,
}

impl TokenBucket {
    fn new(capacity: f64, rate: f64) -> Self {
        Self {
            tokens: capacity, // start full
            capacity,
            rate,
            last_refill: Instant::now(),
        }
    }

    /// Refill tokens based on elapsed time, then try to consume `requested`.
    /// Returns the number of tokens actually granted (may be less than requested).
    fn try_acquire(&mut self, requested: usize) -> usize {
        let now = Instant::now();
        let elapsed = now.duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + self.rate * elapsed).min(self.capacity);
        self.last_refill = now;

        let granted = (requested as f64).min(self.tokens).max(0.0) as usize;
        self.tokens -= granted as f64;
        granted
    }
}

/// Manages per-peer token buckets.
#[derive(Debug, Clone)]
pub(crate) struct PeerRateLimiter {
    buckets: HashMap<PeerNetworkId, TokenBucket>,
    capacity: f64,
    rate: f64,
}

impl PeerRateLimiter {
    /// Create a new rate limiter.
    ///
    /// * `rate` — sustained transactions per second allowed per peer.
    /// * `burst` — maximum burst size (token-bucket capacity).
    pub(crate) fn new(rate: u64, burst: u64) -> Self {
        Self {
            buckets: HashMap::new(),
            capacity: burst as f64,
            rate: rate as f64,
        }
    }

    /// Try to acquire `requested` tokens for `peer`.
    /// Returns the number of transactions the peer is allowed to send.
    /// A new bucket (starting full) is created on first contact with a peer.
    pub(crate) fn try_acquire(&mut self, peer: &PeerNetworkId, requested: usize) -> usize {
        let bucket = self
            .buckets
            .entry(*peer)
            .or_insert_with(|| TokenBucket::new(self.capacity, self.rate));
        bucket.try_acquire(requested)
    }

    /// Remove the bucket for a disconnected peer so we don't leak memory.
    pub(crate) fn remove_peer(&mut self, peer: &PeerNetworkId) {
        self.buckets.remove(peer);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aptos_config::network_id::NetworkId;
    use aptos_types::PeerId;
    use std::thread;
    use std::time::Duration;

    fn test_peer() -> PeerNetworkId {
        PeerNetworkId::new(NetworkId::Validator, PeerId::ZERO)
    }

    #[test]
    fn test_initial_burst_allowed() {
        let mut limiter = PeerRateLimiter::new(100, 200);
        let peer = test_peer();
        // First request up to burst size should be fully granted
        assert_eq!(limiter.try_acquire(&peer, 200), 200);
    }

    #[test]
    fn test_over_burst_truncated() {
        let mut limiter = PeerRateLimiter::new(100, 200);
        let peer = test_peer();
        // Requesting more than burst should be capped
        assert_eq!(limiter.try_acquire(&peer, 300), 200);
    }

    #[test]
    fn test_budget_exhausted_then_refills() {
        let mut limiter = PeerRateLimiter::new(1000, 100);
        let peer = test_peer();
        // Exhaust the bucket
        assert_eq!(limiter.try_acquire(&peer, 100), 100);
        assert_eq!(limiter.try_acquire(&peer, 50), 0);

        // Wait for some refill (100ms at 1000 TPS = ~100 tokens)
        thread::sleep(Duration::from_millis(110));
        let granted = limiter.try_acquire(&peer, 200);
        assert!(granted >= 90 && granted <= 110, "granted={}", granted);
    }

    #[test]
    fn test_independent_peers() {
        let mut limiter = PeerRateLimiter::new(100, 50);
        let peer_a = PeerNetworkId::new(NetworkId::Validator, PeerId::ZERO);
        let peer_b = PeerNetworkId::new(NetworkId::Validator, PeerId::ONE);

        // Exhaust peer A
        assert_eq!(limiter.try_acquire(&peer_a, 50), 50);
        assert_eq!(limiter.try_acquire(&peer_a, 10), 0);

        // Peer B is independent and should still have full budget
        assert_eq!(limiter.try_acquire(&peer_b, 50), 50);
    }

    #[test]
    fn test_remove_peer_resets_on_reconnect() {
        let mut limiter = PeerRateLimiter::new(100, 50);
        let peer = test_peer();

        // Exhaust
        assert_eq!(limiter.try_acquire(&peer, 50), 50);
        assert_eq!(limiter.try_acquire(&peer, 10), 0);

        // Simulate disconnect + reconnect
        limiter.remove_peer(&peer);
        assert_eq!(limiter.try_acquire(&peer, 50), 50);
    }
}
