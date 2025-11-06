use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct BotConfig {
    pub rest_url: String,
    pub poll_secs: u64,
    pub slack_webhook_url: Option<String>,
    pub local_threshold: LocalThresholdParams,
    pub health_check_port: Option<u16>,
    pub force_alert_test: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LocalThresholdParams {
    pub base_per_validator: u64,
    pub runway_epochs: u64,
    pub safety_bps: u64,
}

impl BotConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        let rest_url = std::env::var("REST_URL")?;
        let poll_secs = std::env::var("POLL_SECS").ok().and_then(|s| s.parse().ok()).unwrap_or(60);
        let slack_webhook_url = std::env::var("SLACK_WEBHOOK_URL").ok();
        let health_check_port = std::env::var("HEALTH_CHECK_PORT").ok().and_then(|s| s.parse().ok());
        let force_alert_test = std::env::var("FORCE_ALERT_TEST").is_ok();

        // Require threshold params (num_validators_hint is derived from chain at runtime)
        let base_per_validator: u64 = std::env::var("BASE_PER_VALIDATOR")?.parse()?;
        let runway_epochs: u64 = std::env::var("RUNWAY_EPOCHS")?.parse()?;
        let safety_bps: u64 = std::env::var("SAFETY_BPS")?.parse()?;
        let local_threshold = LocalThresholdParams { base_per_validator, runway_epochs, safety_bps };

        Ok(Self { rest_url, poll_secs, slack_webhook_url, local_threshold, health_check_port, force_alert_test })
    }
}
