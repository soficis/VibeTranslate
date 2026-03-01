use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicBool;

use anyhow::{Result, bail};
use clap::{Parser, Subcommand};

use crate::app_paths::AppPaths;
use crate::batch::{BatchOptions, BatchProcessor};
use crate::export::{BatchExportContext, ExportService};
use crate::file_service::load_text;
use crate::memory::TranslationMemory;
use crate::models::{ExportFormat, ProviderId};
use crate::translation::TranslationService;

#[derive(Debug, Parser)]
#[command(name = "translation-fiesta-rust")]
#[command(about = "TranslationFiesta Rust desktop + CLI port", long_about = None)]
pub struct CliArgs {
    #[command(subcommand)]
    pub command: Option<CliCommand>,
}

#[derive(Debug, Subcommand)]
pub enum CliCommand {
    Gui,
    Translate {
        text: String,
        #[arg(long, default_value = "en")]
        source: String,
        #[arg(long, default_value = "ja")]
        intermediate: String,
        #[arg(long, default_value = "google_unofficial")]
        provider: String,
        #[arg(long)]
        output: Option<PathBuf>,
        #[arg(long, default_value = "txt")]
        format: String,
    },
    File {
        path: PathBuf,
        #[arg(long, default_value = "en")]
        source: String,
        #[arg(long, default_value = "ja")]
        intermediate: String,
        #[arg(long, default_value = "google_unofficial")]
        provider: String,
        #[arg(long)]
        output: Option<PathBuf>,
        #[arg(long, default_value = "txt")]
        format: String,
    },
    Batch {
        directory: PathBuf,
        #[arg(long, default_value = "en")]
        source: String,
        #[arg(long, default_value = "ja")]
        intermediate: String,
        #[arg(long, default_value = "google_unofficial")]
        provider: String,
        #[arg(long)]
        output: Option<PathBuf>,
        #[arg(long, default_value = "txt")]
        format: String,
    },
    Memory {
        #[command(subcommand)]
        command: MemoryCommand,
    },
}

#[derive(Debug, Subcommand)]
pub enum MemoryCommand {
    Stats,
    Clear,
    Search {
        query: String,
        #[arg(long, default_value_t = 20)]
        limit: usize,
    },
}

#[derive(Clone)]
pub struct CliRuntime {
    pub paths: AppPaths,
    pub translator: TranslationService,
    pub batch: BatchProcessor,
    pub export: ExportService,
    pub memory: std::sync::Arc<TranslationMemory>,
}

pub fn execute(args: &CliArgs, runtime: &CliRuntime) -> Result<bool> {
    let Some(command) = &args.command else {
        return Ok(false);
    };

    match command {
        CliCommand::Gui => Ok(false),
        CliCommand::Translate {
            text,
            source,
            intermediate,
            provider,
            output,
            format,
        } => {
            let provider = ProviderId::normalize(provider);
            let cancel = AtomicBool::new(false);
            let result = runtime.translator.back_translate(
                text,
                Some(source.as_str()),
                intermediate,
                provider,
                Some(&cancel),
            )?;

            print_single_result(&result);

            if let Some(path) = output {
                let format = parse_format(format, path)?;
                runtime.export.export_single(&result, path, format, true)?;
                println!("\nSaved to {}", path.display());
            }

            Ok(true)
        }
        CliCommand::File {
            path,
            source,
            intermediate,
            provider,
            output,
            format,
        } => {
            let content = load_text(path)?;
            let provider = ProviderId::normalize(provider);
            let cancel = AtomicBool::new(false);
            let result = runtime.translator.back_translate(
                &content,
                Some(source.as_str()),
                intermediate,
                provider,
                Some(&cancel),
            )?;

            println!("File: {}", path.display());
            print_single_result(&result);

            if let Some(path) = output {
                let format = parse_format(format, path)?;
                runtime.export.export_single(&result, path, format, true)?;
                println!("\nSaved to {}", path.display());
            }

            Ok(true)
        }
        CliCommand::Batch {
            directory,
            source,
            intermediate,
            provider,
            output,
            format,
        } => {
            let files = runtime.batch.collect_files(directory)?;
            if files.is_empty() {
                println!("No supported files found in {}", directory.display());
                return Ok(true);
            }

            println!("Processing {} files...", files.len());

            let cancel = AtomicBool::new(false);
            let options = BatchOptions {
                source_language: Some(source.clone()),
                intermediate_language: intermediate.clone(),
                provider_id: ProviderId::normalize(provider),
            };

            let results = runtime
                .batch
                .process_files(&files, &options, &cancel, |progress| {
                    println!(
                        "{}/{} - {}",
                        progress.done, progress.total, progress.current_file
                    );
                });

            let successful = results.iter().filter(|item| item.success).count();
            let failed = results.len().saturating_sub(successful);

            println!("\nBatch complete");
            println!("Total: {}", results.len());
            println!("Successful: {}", successful);
            println!("Failed: {}", failed);

            if let Some(path) = output {
                let format = parse_format(format, path)?;
                runtime.export.export_batch(
                    &results,
                    path,
                    format,
                    BatchExportContext {
                        include_metadata: true,
                        source_language: source,
                        target_language: intermediate,
                        provider: ProviderId::normalize(provider).as_str(),
                    },
                )?;
                println!("Saved batch report to {}", path.display());
            }

            Ok(true)
        }
        CliCommand::Memory { command } => {
            match command {
                MemoryCommand::Stats => {
                    let stats = runtime.memory.stats()?;
                    println!("Entries: {} / {}", stats.total_entries, stats.max_entries);
                    println!("Hits: {}", stats.total_hits);
                    println!("Misses: {}", stats.total_misses);
                    println!("Lookups: {}", stats.total_lookups);
                    println!("Hit Rate: {:.2}%", stats.hit_rate * 100.0);
                    println!("Avg Lookup: {:.2} ms", stats.avg_lookup_ms);
                }
                MemoryCommand::Clear => {
                    runtime.memory.clear()?;
                    println!("Translation memory cleared");
                }
                MemoryCommand::Search { query, limit } => {
                    let items = runtime.memory.search(query, *limit)?;
                    if items.is_empty() {
                        println!("No memory entries matched '{query}'");
                    } else {
                        for (index, item) in items.iter().enumerate() {
                            println!(
                                "{}. {} -> {} ({} | {} uses)",
                                index + 1,
                                truncate(&item.source_text, 48),
                                truncate(&item.translated_text, 48),
                                item.provider_id,
                                item.access_count,
                            );
                        }
                    }
                }
            }
            Ok(true)
        }
    }
}

fn parse_format(format: &str, output_path: &Path) -> Result<ExportFormat> {
    if let Ok(parsed) = format.parse::<ExportFormat>() {
        return Ok(parsed);
    }

    if let Some(parsed_from_path) = ExportFormat::from_path(output_path) {
        return Ok(parsed_from_path);
    }

    bail!("unsupported export format: {format}")
}

fn print_single_result(result: &crate::models::BackTranslationResult) {
    println!();
    println!("ORIGINAL");
    println!("{}", result.original_text);
    println!(
        "\nINTERMEDIATE ({})",
        result.intermediate_language.to_uppercase()
    );
    println!("{}", result.intermediate_text);
    println!(
        "\nBACK TRANSLATED ({})",
        result.source_language.to_uppercase()
    );
    println!("{}", result.back_translated_text);
    println!(
        "\nProvider: {} | Duration: {:.2}s",
        result.provider_id,
        result.duration_ms as f64 / 1000.0
    );
}

fn truncate(value: &str, max_len: usize) -> String {
    if value.chars().count() <= max_len {
        value.to_owned()
    } else {
        let mut truncated = value.chars().take(max_len).collect::<String>();
        truncated.push('…');
        truncated
    }
}
