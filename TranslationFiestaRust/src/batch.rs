use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

use anyhow::Result;
use tracing::{error, info, warn};

use crate::file_service::{list_supported_files_in_directory, load_text};
use crate::models::{BatchItemResult, ProviderId};
use crate::translation::{TranslationError, TranslationService};

#[derive(Debug, Clone)]
pub struct BatchOptions {
    pub source_language: Option<String>,
    pub intermediate_language: String,
    pub provider_id: ProviderId,
}

impl Default for BatchOptions {
    fn default() -> Self {
        Self {
            source_language: Some("en".to_owned()),
            intermediate_language: "ja".to_owned(),
            provider_id: ProviderId::GoogleUnofficial,
        }
    }
}

#[derive(Debug, Clone)]
pub struct BatchProgress {
    pub done: usize,
    pub total: usize,
    pub current_file: String,
}

#[derive(Debug, Clone)]
pub struct BatchProcessor {
    translator: TranslationService,
}

impl BatchProcessor {
    pub fn new(translator: TranslationService) -> Self {
        Self { translator }
    }

    pub fn collect_files(&self, directory: &Path) -> Result<Vec<PathBuf>> {
        list_supported_files_in_directory(directory)
    }

    pub fn process_files<F>(
        &self,
        files: &[PathBuf],
        options: &BatchOptions,
        cancel_flag: &AtomicBool,
        mut on_progress: F,
    ) -> Vec<BatchItemResult>
    where
        F: FnMut(BatchProgress),
    {
        let total = files.len();
        if total == 0 {
            return Vec::new();
        }

        info!("starting batch processing of {total} files");

        let mut results = Vec::with_capacity(total);

        for (index, file_path) in files.iter().enumerate() {
            if cancel_flag.load(Ordering::Relaxed) {
                warn!("batch processing cancelled by user");
                break;
            }

            let started = Instant::now();
            let file_label = file_path.to_string_lossy().to_string();
            on_progress(BatchProgress {
                done: index,
                total,
                current_file: file_label.clone(),
            });

            let item_result = match load_text(file_path) {
                Ok(content) => {
                    self.translate_single_file(&content, options, cancel_flag, &file_label, started)
                }
                Err(error) => BatchItemResult {
                    file_path: file_label,
                    success: false,
                    intermediate_text: String::new(),
                    back_translated_text: String::new(),
                    error: Some(error.to_string()),
                    duration_ms: started.elapsed().as_millis(),
                },
            };

            results.push(item_result);
            on_progress(BatchProgress {
                done: index + 1,
                total,
                current_file: file_path.to_string_lossy().to_string(),
            });
        }

        info!("batch processing completed with {} results", results.len());
        results
    }

    fn translate_single_file(
        &self,
        content: &str,
        options: &BatchOptions,
        cancel_flag: &AtomicBool,
        file_label: &str,
        started: Instant,
    ) -> BatchItemResult {
        match self.translator.back_translate(
            content,
            options.source_language.as_deref(),
            &options.intermediate_language,
            options.provider_id,
            Some(cancel_flag),
        ) {
            Ok(result) => BatchItemResult {
                file_path: file_label.to_owned(),
                success: true,
                intermediate_text: result.intermediate_text,
                back_translated_text: result.back_translated_text,
                error: None,
                duration_ms: started.elapsed().as_millis(),
            },
            Err(error) => {
                if matches!(error, TranslationError::Cancelled) {
                    warn!("translation cancelled while processing file: {file_label}");
                } else {
                    error!("failed to process file {file_label}: {error}");
                }

                BatchItemResult {
                    file_path: file_label.to_owned(),
                    success: false,
                    intermediate_text: String::new(),
                    back_translated_text: String::new(),
                    error: Some(error.to_string()),
                    duration_ms: started.elapsed().as_millis(),
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_batch_options_use_google_unofficial() {
        let options = BatchOptions::default();
        assert_eq!(options.provider_id, ProviderId::GoogleUnofficial);
        assert_eq!(options.intermediate_language, "ja");
    }
}
