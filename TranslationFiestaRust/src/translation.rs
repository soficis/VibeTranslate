use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;
use std::time::{Duration, Instant};

use anyhow::Result;
use rand::Rng;
use reqwest::StatusCode;
use reqwest::blocking::{Client, Response};
use serde_json::Value;
use thiserror::Error;
use tracing::{debug, error, info, warn};

use crate::memory::TranslationMemory;
use crate::models::{BackTranslationResult, ProviderId};

#[derive(Debug, Error, Clone)]
pub enum TranslationError {
    #[error("cancelled")]
    Cancelled,
    #[error("provider rate limited")]
    RateLimited,
    #[error("provider blocked or captcha detected")]
    Blocked,
    #[error("{0}")]
    InvalidResponse(String),
    #[error("{0}")]
    Network(String),
    #[error("{0}")]
    InvalidInput(String),
}

#[derive(Debug, Clone)]
pub struct TranslationService {
    client: Client,
    memory: Arc<TranslationMemory>,
    max_retries: usize,
    base_retry_delay_ms: u64,
}

impl TranslationService {
    pub fn new(memory: Arc<TranslationMemory>) -> Result<Self> {
        let timeout = std::env::var("TF_UNOFFICIAL_TIMEOUT_SECONDS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(20);

        let client = Client::builder()
            .timeout(Duration::from_secs(timeout))
            .build()?;

        Ok(Self {
            client,
            memory,
            max_retries: 4,
            base_retry_delay_ms: 300,
        })
    }

    pub fn with_retry_policy(mut self, max_retries: usize, base_retry_delay_ms: u64) -> Self {
        self.max_retries = max_retries.max(1);
        self.base_retry_delay_ms = base_retry_delay_ms.max(50);
        self
    }

    pub fn detect_language(&self, text: &str) -> String {
        let sample = text.trim();
        if sample.is_empty() {
            return "en".to_owned();
        }

        match whatlang::detect(sample) {
            Some(info) => {
                let code = info.lang().code();
                if code.len() == 2 {
                    code.to_owned()
                } else {
                    "en".to_owned()
                }
            }
            None => "en".to_owned(),
        }
    }

    pub fn translate_text(
        &self,
        text: &str,
        source_language: &str,
        target_language: &str,
        provider_id: ProviderId,
        cancel_flag: Option<&AtomicBool>,
    ) -> std::result::Result<String, TranslationError> {
        if is_cancelled(cancel_flag) {
            return Err(TranslationError::Cancelled);
        }

        if text.trim().is_empty() {
            return Ok(String::new());
        }

        validate_language_code(source_language)?;
        validate_language_code(target_language)?;

        let normalized_provider = provider_id.as_str();

        if let Ok(Some(cached)) =
            self.memory
                .lookup(text, source_language, target_language, normalized_provider)
        {
            info!(
                "translation memory hit ({} -> {})",
                source_language, target_language
            );
            return Ok(cached);
        }

        let encoded = urlencoding::encode(text);
        let url = format!(
            "https://translate.googleapis.com/translate_a/single?client=gtx&sl={source_language}&tl={target_language}&dt=t&q={encoded}"
        );

        let user_agent = std::env::var("TF_UNOFFICIAL_USER_AGENT").ok();

        let mut attempt = 0;
        loop {
            attempt += 1;
            if is_cancelled(cancel_flag) {
                return Err(TranslationError::Cancelled);
            }

            debug!(
                "translation attempt {attempt} ({} -> {})",
                source_language, target_language
            );

            let result = self.send_request(&url, user_agent.as_deref());
            match result {
                Ok(response) => match self.handle_response(response) {
                    Ok(translated) => {
                        if let Err(store_error) = self.memory.store(
                            text,
                            &translated,
                            source_language,
                            target_language,
                            normalized_provider,
                        ) {
                            warn!("failed to persist translation memory entry: {store_error}");
                        }
                        return Ok(translated);
                    }
                    Err(error @ TranslationError::RateLimited) => {
                        if attempt < self.max_retries {
                            let delay = self.retry_delay(attempt);
                            warn!("rate limited on attempt {attempt}, retrying in {delay:?}");
                            sleep_with_cancel(delay, cancel_flag)?;
                            continue;
                        }
                        return Err(error);
                    }
                    Err(error @ TranslationError::Network(_)) => {
                        if attempt < self.max_retries {
                            let delay = self.retry_delay(attempt);
                            warn!("network error on attempt {attempt}, retrying in {delay:?}");
                            sleep_with_cancel(delay, cancel_flag)?;
                            continue;
                        }
                        return Err(error);
                    }
                    Err(error) => return Err(error),
                },
                Err(error) => {
                    if attempt < self.max_retries {
                        let delay = self.retry_delay(attempt);
                        warn!(
                            "request failed on attempt {attempt}, retrying in {delay:?}: {error}"
                        );
                        sleep_with_cancel(delay, cancel_flag)?;
                        continue;
                    }
                    return Err(TranslationError::Network(error.to_string()));
                }
            }
        }
    }

    pub fn back_translate(
        &self,
        text: &str,
        source_language: Option<&str>,
        intermediate_language: &str,
        provider_id: ProviderId,
        cancel_flag: Option<&AtomicBool>,
    ) -> std::result::Result<BackTranslationResult, TranslationError> {
        let input = text.trim();
        if input.is_empty() {
            return Err(TranslationError::InvalidInput(
                "text cannot be empty".to_owned(),
            ));
        }

        validate_language_code(intermediate_language)?;

        let source = source_language
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToOwned::to_owned)
            .unwrap_or_else(|| self.detect_language(input));

        let started_at = Instant::now();

        info!(
            "starting backtranslation {} -> {} -> {}",
            source, intermediate_language, source
        );

        let intermediate = self.translate_text(
            input,
            &source,
            intermediate_language,
            provider_id,
            cancel_flag,
        )?;

        if is_cancelled(cancel_flag) {
            return Err(TranslationError::Cancelled);
        }

        let back_translated = self.translate_text(
            &intermediate,
            intermediate_language,
            &source,
            provider_id,
            cancel_flag,
        )?;

        Ok(BackTranslationResult::new(
            input.to_owned(),
            intermediate,
            back_translated,
            source,
            intermediate_language.to_owned(),
            provider_id,
            started_at.elapsed(),
        ))
    }

    fn send_request(&self, url: &str, user_agent: Option<&str>) -> reqwest::Result<Response> {
        let mut request = self
            .client
            .get(url)
            .header("Accept", "application/json,text/plain,*/*");

        if let Some(agent) = user_agent
            && !agent.trim().is_empty()
        {
            request = request.header("User-Agent", agent.trim());
        }

        request.send()
    }

    fn handle_response(&self, response: Response) -> std::result::Result<String, TranslationError> {
        let status = response.status();
        let body = response
            .text()
            .map_err(|err| TranslationError::Network(err.to_string()))?;

        if status == StatusCode::TOO_MANY_REQUESTS {
            return Err(TranslationError::RateLimited);
        }

        if status == StatusCode::FORBIDDEN {
            return Err(TranslationError::Blocked);
        }

        if !status.is_success() {
            return Err(TranslationError::InvalidResponse(format!(
                "HTTP {}",
                status.as_u16()
            )));
        }

        if body.trim().is_empty() {
            return Err(TranslationError::InvalidResponse(
                "empty response body".to_owned(),
            ));
        }

        let lower = body.to_ascii_lowercase();
        if lower.contains("<html") || lower.contains("captcha") {
            return Err(TranslationError::Blocked);
        }

        parse_unofficial_google_response(&body)
    }

    fn retry_delay(&self, attempt: usize) -> Duration {
        let jitter_ms: u64 = rand::thread_rng().gen_range(50..=220);
        let exp = (2_u64).saturating_pow(attempt.saturating_sub(1) as u32);
        let delay_ms = self
            .base_retry_delay_ms
            .saturating_mul(exp)
            .saturating_add(jitter_ms)
            .min(30_000);
        Duration::from_millis(delay_ms)
    }
}

fn validate_language_code(code: &str) -> std::result::Result<(), TranslationError> {
    let trimmed = code.trim();
    if trimmed.len() == 2 && trimmed.chars().all(|ch| ch.is_ascii_alphabetic()) {
        return Ok(());
    }

    Err(TranslationError::InvalidInput(format!(
        "invalid language code: {code}"
    )))
}

fn sleep_with_cancel(
    delay: Duration,
    cancel_flag: Option<&AtomicBool>,
) -> std::result::Result<(), TranslationError> {
    let started = Instant::now();
    while started.elapsed() < delay {
        if is_cancelled(cancel_flag) {
            return Err(TranslationError::Cancelled);
        }
        thread::sleep(Duration::from_millis(40));
    }
    Ok(())
}

fn is_cancelled(cancel_flag: Option<&AtomicBool>) -> bool {
    cancel_flag
        .map(|flag| flag.load(Ordering::Relaxed))
        .unwrap_or(false)
}

pub fn parse_unofficial_google_response(
    body: &str,
) -> std::result::Result<String, TranslationError> {
    let parsed: Value = serde_json::from_str(body)
        .map_err(|err| TranslationError::InvalidResponse(err.to_string()))?;

    let root = parsed
        .as_array()
        .ok_or_else(|| TranslationError::InvalidResponse("root is not an array".to_owned()))?;

    let segments = root.first().and_then(Value::as_array).ok_or_else(|| {
        TranslationError::InvalidResponse("missing translation segments".to_owned())
    })?;

    let mut result = String::new();
    for sentence in segments {
        if let Some(parts) = sentence.as_array()
            && let Some(part) = parts.first().and_then(Value::as_str)
        {
            result.push_str(part);
        }
    }

    if result.trim().is_empty() {
        return Err(TranslationError::InvalidResponse(
            "no translation segments returned".to_owned(),
        ));
    }

    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_unofficial_response_segments() {
        let body = r#"[[["こんにちは", "hello", null, null, 1],["！","!",null,null,1]] ]"#;
        let parsed = parse_unofficial_google_response(body).unwrap();
        assert_eq!(parsed, "こんにちは！");
    }

    #[test]
    fn rejects_invalid_response_shape() {
        let error = parse_unofficial_google_response("{}").unwrap_err();
        assert!(matches!(error, TranslationError::InvalidResponse(_)));
    }
}
