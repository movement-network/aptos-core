// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Extracts the epoch-ending ledger info chain from a node's backup service, verifies it from a
//! trusted waypoint with all cores, and produces verified waypoints.

pub mod client;
pub mod framing;
pub mod pipeline;
pub mod verify;

#[cfg(test)]
mod tests;
