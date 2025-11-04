use serde::Deserialize;

#[derive(Debug, Clone, Deserialize)]
pub struct BotConfig {
    pub indexer_graphql_url: String,
    pub rest_url: String,
    pub ggp_address_override: Option<String>,
    pub poll_secs: u64,
    pub slack_webhook_url: Option<String>,
    pub local_threshold: LocalThresholdParams,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LocalThresholdParams {
    pub base_per_validator: u64,
    pub runway_epochs: u64,
    pub safety_bps: u64,
}

impl BotConfig {
    pub fn from_env() -> anyhow::Result<Self> {
        let indexer_graphql_url = std::env::var("INDEXER_GRAPHQL_URL")?;
        let rest_url = std::env::var("REST_URL")?;
        let ggp_address_override = std::env::var("GGP_ADDRESS").ok();
        let poll_secs = std::env::var("POLL_SECS").ok().and_then(|s| s.parse().ok()).unwrap_or(60);
        let slack_webhook_url = std::env::var("SLACK_WEBHOOK_URL").ok();

        // Require threshold params (num_validators_hint is derived from chain at runtime)
        let base_per_validator: u64 = std::env::var("BASE_PER_VALIDATOR")?.parse()?;
        let runway_epochs: u64 = std::env::var("RUNWAY_EPOCHS")?.parse()?;
        let safety_bps: u64 = std::env::var("SAFETY_BPS")?.parse()?;
        let local_threshold = LocalThresholdParams { base_per_validator, runway_epochs, safety_bps };

        Ok(Self { indexer_graphql_url, rest_url, ggp_address_override, poll_secs, slack_webhook_url, local_threshold })
    }
}
