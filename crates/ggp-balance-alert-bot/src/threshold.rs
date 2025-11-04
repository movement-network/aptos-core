#[derive(Debug, Clone, Copy)]
pub struct ThresholdParams {
    pub base_per_validator: u64,
    pub runway_epochs: u64,
    pub safety_bps: u64,
    pub num_validators_hint: u64,
}

pub fn compute_dynamic_low_threshold(p: Option<ThresholdParams>) -> u64 {
    let Some(p) = p else { return 0; };
    let base = p.base_per_validator as u128;
    let n = p.num_validators_hint as u128;
    let runway = p.runway_epochs as u128;
    let bps = 10000u128 + p.safety_bps as u128;
    let product = base.saturating_mul(n).saturating_mul(runway).saturating_mul(bps);
    let low = product / 10000u128;
    (low.min(u128::from(u64::MAX))) as u64
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_threshold_basic() {
        let p = ThresholdParams { base_per_validator: 1000, runway_epochs: 2, safety_bps: 0, num_validators_hint: 5 };
        assert_eq!(compute_dynamic_low_threshold(Some(p)), 10000);
    }
}
