// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! Pricing for walking an already-materialized Move value.
//!
//! BCS blobs and storage items can expand into a much larger in-memory node
//! graph than their byte length suggests. Charging only for those bytes leaves
//! a free-amplification hole: a cheap load or `from_bytes` can produce a huge
//! graph. The walk billed here is the same class of work as `cmp::compare`
//! (visit every node). We price it at three times that native so a traversal
//! cannot undercut a comparison of the same value.
//!
//! The multipliers are derived from the current `move_stdlib.cmp.compare`
//! schedule (`base = 367`, `per_abs_val_unit = 14`). They are not on-chain
//! parameters yet; a later gas-schedule version can promote them.

use aptos_gas_algebra::{AbstractValueSize, InternalGas, InternalGasPerAbstractValueUnit};

/// Three times `move_stdlib.cmp.compare.base`.
const WALK_BASE: InternalGas = InternalGas::new(1_101);

/// Three times `move_stdlib.cmp.compare.per_abs_val_unit`.
const WALK_PER_ABS_UNIT: InternalGasPerAbstractValueUnit = InternalGasPerAbstractValueUnit::new(42);

/// Execution gas for visiting `abstract_units` of a value graph.
///
/// Addition and multiplication saturate, so a huge graph over-charges rather
/// than wrapping to a cheap cost.
pub fn value_graph_walk_cost(abstract_units: AbstractValueSize) -> InternalGas {
    WALK_BASE + WALK_PER_ABS_UNIT * abstract_units
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_graph_still_pays_the_base() {
        let cost = value_graph_walk_cost(AbstractValueSize::new(0));
        assert_eq!(u64::from(cost), 1_101);
    }

    #[test]
    fn cost_grows_linearly_with_abstract_size() {
        let small = value_graph_walk_cost(AbstractValueSize::new(10));
        let large = value_graph_walk_cost(AbstractValueSize::new(1_000));
        assert!(u64::from(large) > u64::from(small) * 20);
        assert_eq!(u64::from(small), 1_101 + 42 * 10);
        assert_eq!(u64::from(large), 1_101 + 42 * 1_000);
    }

    #[test]
    fn saturated_product_does_not_wrap_to_a_cheap_cost() {
        // u64::MAX abstract units * 42 saturates; the billed amount must stay
        // enormous rather than wrapping toward zero.
        let cost = value_graph_walk_cost(AbstractValueSize::new(u64::MAX));
        assert_eq!(u64::from(cost), u64::MAX);
    }
}
