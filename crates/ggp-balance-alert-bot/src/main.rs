use ggp_balance_alert_bot::{config::BotConfig, runner::run_bot};
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    let cfg = BotConfig::from_env()?;
    run_bot(cfg).await
}
