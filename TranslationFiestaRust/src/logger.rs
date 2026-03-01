use std::fs;
use std::path::Path;

use anyhow::{Context, Result};
use tracing_subscriber::EnvFilter;

pub fn init_logger(log_file: &Path) -> Result<()> {
    if let Some(parent) = log_file.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create log directory {}", parent.display()))?;
    }

    let file_appender = tracing_appender::rolling::never(
        log_file
            .parent()
            .ok_or_else(|| anyhow::anyhow!("log file parent not found"))?,
        log_file
            .file_name()
            .ok_or_else(|| anyhow::anyhow!("log file name missing"))?,
    );

    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    tracing_subscriber::fmt()
        .with_env_filter(env_filter)
        .with_writer(file_appender)
        .with_ansi(false)
        .with_target(false)
        .try_init()
        .map_err(|err| anyhow::anyhow!(err.to_string()))?;

    Ok(())
}
