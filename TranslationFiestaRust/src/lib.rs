pub mod app_paths;
pub mod batch;
pub mod cli;
pub mod epub;
pub mod export;
pub mod file_service;
pub mod html;
pub mod language;
pub mod logger;
pub mod memory;
pub mod models;
pub mod settings;
pub mod translation;
pub mod ui;

use std::sync::Arc;

use anyhow::Result;

use app_paths::AppPaths;
use batch::BatchProcessor;
use export::ExportService;
use memory::TranslationMemory;
use settings::{AppSettings, load_settings};
use translation::TranslationService;

#[derive(Clone)]
pub struct RuntimeServices {
    pub paths: AppPaths,
    pub settings: AppSettings,
    pub memory: Arc<TranslationMemory>,
    pub translator: TranslationService,
    pub batch: BatchProcessor,
    pub export: ExportService,
}

pub fn initialize_runtime(paths: AppPaths) -> Result<RuntimeServices> {
    let settings = load_settings(&paths.settings_file);

    let memory = Arc::new(TranslationMemory::new(
        &paths.memory_db_file,
        settings.translation_memory_max_entries,
    )?);

    let translator = TranslationService::new(Arc::clone(&memory))?;
    let batch = BatchProcessor::new(translator.clone());
    let export = ExportService;

    Ok(RuntimeServices {
        paths,
        settings,
        memory,
        translator,
        batch,
        export,
    })
}
