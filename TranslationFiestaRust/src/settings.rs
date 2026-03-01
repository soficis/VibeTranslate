use std::fs;
use std::path::Path;

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

use crate::models::{ExportFormat, ProviderId};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSettings {
    pub provider_id: String,
    pub source_language: String,
    pub intermediate_language: String,
    pub output_format: String,
    pub window_width: f32,
    pub window_height: f32,
    pub last_file_path: String,
    pub last_save_path: String,
    pub translation_memory_max_entries: usize,
}

impl Default for AppSettings {
    fn default() -> Self {
        Self {
            provider_id: ProviderId::GoogleUnofficial.as_str().to_owned(),
            source_language: "en".to_owned(),
            intermediate_language: "ja".to_owned(),
            output_format: ExportFormat::Html.extension().to_owned(),
            window_width: 1260.0,
            window_height: 860.0,
            last_file_path: String::new(),
            last_save_path: String::new(),
            translation_memory_max_entries: 1000,
        }
    }
}

impl AppSettings {
    pub fn provider(&self) -> ProviderId {
        ProviderId::normalize(&self.provider_id)
    }

    pub fn export_format(&self) -> ExportFormat {
        self.output_format.parse().unwrap_or(ExportFormat::Html)
    }

    pub fn normalize(&mut self) {
        self.provider_id = self.provider().as_str().to_owned();

        if self.source_language.trim().len() != 2 {
            self.source_language = "en".to_owned();
        }
        if self.intermediate_language.trim().len() != 2 {
            self.intermediate_language = "ja".to_owned();
        }

        self.output_format = self.export_format().extension().to_owned();

        if self.window_width < 900.0 {
            self.window_width = 900.0;
        }
        if self.window_height < 620.0 {
            self.window_height = 620.0;
        }

        if self.translation_memory_max_entries == 0 {
            self.translation_memory_max_entries = 1000;
        }
    }
}

pub fn load_settings(path: &Path) -> AppSettings {
    if !path.exists() {
        return AppSettings::default();
    }

    match fs::read_to_string(path)
        .with_context(|| format!("failed to read settings from {}", path.display()))
        .and_then(|content| {
            serde_json::from_str::<AppSettings>(&content)
                .with_context(|| format!("failed to parse settings from {}", path.display()))
        }) {
        Ok(mut settings) => {
            settings.normalize();
            settings
        }
        Err(error) => {
            warn!(
                "failed to load settings from {}: {error}",
                path.display()
            );
            AppSettings::default()
        }
    }
}

pub fn save_settings(path: &Path, settings: &AppSettings) -> Result<()> {
    let mut normalized = settings.clone();
    normalized.normalize();

    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create settings directory {}", parent.display()))?;
    }

    let json = serde_json::to_string_pretty(&normalized).context("failed to serialize settings")?;
    fs::write(path, json)
        .with_context(|| format!("failed to write settings to {}", path.display()))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_to_unofficial_provider() {
        let settings = AppSettings::default();
        assert_eq!(settings.provider(), ProviderId::GoogleUnofficial);
    }
}
