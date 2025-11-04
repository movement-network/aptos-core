use crate::{
    alert::{AlertSink, LogAlert, SlackAlert},
    config::BotConfig,
    sources::{indexer::IndexerClient, rest::RestClient},
    threshold::{compute_dynamic_low_threshold, ThresholdParams},
};
use std::sync::Arc;
use tokio::time::{sleep, Duration};

pub async fn run_bot(cfg: BotConfig) -> anyhow::Result<()> {
    let indexer = IndexerClient::new(cfg.indexer_graphql_url.clone());
    let rest = RestClient::new(cfg.rest_url.clone());

    let mut sinks: Vec<Arc<dyn AlertSink>> = vec![Arc::new(LogAlert)];
    if let Some(url) = &cfg.slack_webhook_url { sinks.push(Arc::new(SlackAlert::new(url.clone()))); }

    // Determine GGP address once (allow override via env)
    let ggp_address = if let Some(addr) = cfg.ggp_address_override.clone() {
        addr
    } else {
        rest.get_ggp_address_via_view().await?
    };

    loop {
        if let Err(e) = tick(&cfg, &ggp_address, &rest, &indexer, &sinks).await {
            tracing::error!(error = %e, "tick failed");
        }
        sleep(Duration::from_secs(cfg.poll_secs)).await;
    }
}

async fn tick(
    cfg: &BotConfig,
    ggp_address: &str,
    rest: &RestClient,
    indexer: &IndexerClient,
    sinks: &[Arc<dyn AlertSink>],
) -> anyhow::Result<()> {
    let balance = indexer.get_latest_apt_balance(ggp_address).await?.unwrap_or(0);

    // Derive num_validators_hint from chain at runtime
    let num_validators_hint = rest.get_active_validator_count().await?;

    // Compute threshold locally (base params from env, num_validators_hint from chain)
    let p = ThresholdParams {
        base_per_validator: cfg.local_threshold.base_per_validator,
        runway_epochs: cfg.local_threshold.runway_epochs,
        safety_bps: cfg.local_threshold.safety_bps,
        num_validators_hint,
    };
    let threshold = compute_dynamic_low_threshold(Some(p));

    tracing::info!(%balance, %threshold, "GGP balance check");

    if threshold > 0 && balance < threshold {
        for s in sinks { s.alert_low_balance(balance, threshold).await; }
    }
    Ok(())
}
