use std::fmt::{Display, Formatter};
use std::path::Path;
use std::str::FromStr;
use std::time::Duration;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub const GOOGLE_UNOFFICIAL_PROVIDER: &str = "google_unofficial";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProviderId {
    GoogleUnofficial,
}

impl ProviderId {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::GoogleUnofficial => GOOGLE_UNOFFICIAL_PROVIDER,
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            Self::GoogleUnofficial => "Google Translate (Unofficial / Free)",
        }
    }

    pub fn normalize(value: &str) -> Self {
        match value.trim().to_ascii_lowercase().as_str() {
            "google_unofficial" | "unofficial" | "google_free" | "googletranslate" => {
                Self::GoogleUnofficial
            }
            _ => Self::GoogleUnofficial,
        }
    }
}

impl Display for ProviderId {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ExportFormat {
    Txt,
    Markdown,
    Html,
    Json,
    Csv,
    Xml,
    Pdf,
    Docx,
}

impl ExportFormat {
    pub fn extension(self) -> &'static str {
        match self {
            Self::Txt => "txt",
            Self::Markdown => "md",
            Self::Html => "html",
            Self::Json => "json",
            Self::Csv => "csv",
            Self::Xml => "xml",
            Self::Pdf => "pdf",
            Self::Docx => "docx",
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            Self::Txt => "Plain Text (.txt)",
            Self::Markdown => "Markdown (.md)",
            Self::Html => "HTML (.html)",
            Self::Json => "JSON (.json)",
            Self::Csv => "CSV (.csv)",
            Self::Xml => "XML (.xml)",
            Self::Pdf => "PDF (.pdf)",
            Self::Docx => "DOCX (.docx)",
        }
    }

    pub fn from_path(path: &Path) -> Option<Self> {
        let ext = path.extension()?.to_string_lossy().to_ascii_lowercase();
        Self::from_str(ext.as_str()).ok()
    }

    pub fn all() -> [Self; 8] {
        [
            Self::Txt,
            Self::Markdown,
            Self::Html,
            Self::Json,
            Self::Csv,
            Self::Xml,
            Self::Pdf,
            Self::Docx,
        ]
    }
}

impl Display for ExportFormat {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.extension())
    }
}

impl FromStr for ExportFormat {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "txt" | "text" => Ok(Self::Txt),
            "md" | "markdown" => Ok(Self::Markdown),
            "html" | "htm" => Ok(Self::Html),
            "json" => Ok(Self::Json),
            "csv" => Ok(Self::Csv),
            "xml" => Ok(Self::Xml),
            "pdf" => Ok(Self::Pdf),
            "docx" | "doc" => Ok(Self::Docx),
            _ => Err(format!("unsupported format: {s}")),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackTranslationResult {
    pub id: Uuid,
    pub original_text: String,
    pub intermediate_text: String,
    pub back_translated_text: String,
    pub source_language: String,
    pub intermediate_language: String,
    pub provider_id: String,
    pub created_at: DateTime<Utc>,
    pub duration_ms: u128,
}

impl BackTranslationResult {
    pub fn new(
        original_text: String,
        intermediate_text: String,
        back_translated_text: String,
        source_language: String,
        intermediate_language: String,
        provider_id: ProviderId,
        duration: Duration,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            original_text,
            intermediate_text,
            back_translated_text,
            source_language,
            intermediate_language,
            provider_id: provider_id.as_str().to_owned(),
            created_at: Utc::now(),
            duration_ms: duration.as_millis(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchItemResult {
    pub file_path: String,
    pub success: bool,
    pub intermediate_text: String,
    pub back_translated_text: String,
    pub error: Option<String>,
    pub duration_ms: u128,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportMetadata {
    pub title: String,
    pub author: String,
    pub subject: String,
    pub keywords: Vec<String>,
    pub created_date: DateTime<Utc>,
    pub source_language: String,
    pub target_language: String,
    pub processing_time_seconds: f64,
    pub api_used: String,
}

impl ExportMetadata {
    pub fn from_result(result: &BackTranslationResult) -> Self {
        Self {
            title: "Translation Results".to_string(),
            author: "TranslationFiesta Rust".to_string(),
            subject: "Backtranslation Results".to_string(),
            keywords: vec!["translation".to_string(), "backtranslation".to_string()],
            created_date: result.created_at,
            source_language: result.source_language.clone(),
            target_language: result.intermediate_language.clone(),
            processing_time_seconds: result.duration_ms as f64 / 1000.0,
            api_used: result.provider_id.clone(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct MemoryEntry {
    pub source_text: String,
    pub translated_text: String,
    pub source_language: String,
    pub target_language: String,
    pub provider_id: String,
    pub access_count: i64,
    pub last_accessed: DateTime<Utc>,
}

#[derive(Debug, Clone, Default)]
pub struct MemoryStats {
    pub total_entries: usize,
    pub max_entries: usize,
    pub total_hits: usize,
    pub total_misses: usize,
    pub total_lookups: usize,
    pub hit_rate: f64,
    pub avg_lookup_ms: f64,
}

#[derive(Debug, Clone)]
pub struct EpubChapter {
    pub title: String,
    pub path: String,
    pub content: String,
    pub order: usize,
}

#[derive(Debug, Clone)]
pub struct EpubBook {
    pub title: String,
    pub author: Option<String>,
    pub chapters: Vec<EpubChapter>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn provider_normalization_handles_aliases() {
        assert_eq!(
            ProviderId::normalize("google_unofficial"),
            ProviderId::GoogleUnofficial
        );
        assert_eq!(
            ProviderId::normalize("unofficial"),
            ProviderId::GoogleUnofficial
        );
        assert_eq!(
            ProviderId::normalize("unknown"),
            ProviderId::GoogleUnofficial
        );
    }

    #[test]
    fn export_format_from_str_supports_expected_values() {
        assert_eq!(ExportFormat::from_str("txt").unwrap(), ExportFormat::Txt);
        assert_eq!(
            ExportFormat::from_str("md").unwrap(),
            ExportFormat::Markdown
        );
        assert_eq!(ExportFormat::from_str("docx").unwrap(), ExportFormat::Docx);
        assert!(ExportFormat::from_str("yaml").is_err());
    }
}
