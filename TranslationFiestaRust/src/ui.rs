use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use arboard::Clipboard;
use crossbeam_channel::{Receiver, Sender};
use eframe::egui;
use eframe::egui::{Color32, RichText, Stroke, Vec2};
use tracing::{error, info, warn};

use crate::app_paths::AppPaths;
use crate::batch::{BatchOptions, BatchProcessor, BatchProgress};
use crate::export::{BatchExportContext, ExportService};
use crate::file_service::{SupportedFileType, load_text};
use crate::memory::TranslationMemory;
use crate::models::{
    BackTranslationResult, BatchItemResult, ExportFormat, MemoryEntry, MemoryStats, ProviderId,
};
use crate::settings::{AppSettings, save_settings};
use crate::translation::{TranslationError, TranslationService};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AppTab {
    Translate,
    Batch,
    Memory,
    Export,
    Settings,
}

#[derive(Debug)]
enum UiEvent {
    TranslationCompleted(BackTranslationResult),
    TranslationFailed(String),
    BatchProgress(BatchProgress),
    BatchCompleted(Vec<BatchItemResult>),
}

pub struct TranslationFiestaApp {
    paths: AppPaths,
    settings: AppSettings,
    translator: TranslationService,
    batch_processor: BatchProcessor,
    exporter: ExportService,
    memory: Arc<TranslationMemory>,

    active_tab: AppTab,
    status_message: String,

    input_text: String,
    intermediate_text: String,
    back_text: String,
    last_result: Option<BackTranslationResult>,

    is_translating: bool,
    translate_cancel: Arc<AtomicBool>,

    batch_files: Vec<PathBuf>,
    batch_results: Vec<BatchItemResult>,
    batch_progress: Option<BatchProgress>,
    is_batch_running: bool,
    batch_cancel: Arc<AtomicBool>,

    memory_stats: MemoryStats,
    memory_query: String,
    memory_results: Vec<MemoryEntry>,

    export_format: ExportFormat,
    include_metadata: bool,
    export_preview: String,

    clipboard: Option<Clipboard>,

    tx: Sender<UiEvent>,
    rx: Receiver<UiEvent>,

    last_save_attempt: Instant,
}

impl TranslationFiestaApp {
    pub fn new(
        paths: AppPaths,
        settings: AppSettings,
        translator: TranslationService,
        batch_processor: BatchProcessor,
        exporter: ExportService,
        memory: Arc<TranslationMemory>,
    ) -> Self {
        let (tx, rx) = crossbeam_channel::unbounded();
        let clipboard = Clipboard::new().ok();
        let initial_stats = memory.stats().unwrap_or_default();

        Self {
            paths,
            export_format: settings.export_format(),
            include_metadata: true,
            settings,
            translator,
            batch_processor,
            exporter,
            memory,
            active_tab: AppTab::Translate,
            status_message: "Ready".to_owned(),
            input_text: String::new(),
            intermediate_text: String::new(),
            back_text: String::new(),
            last_result: None,
            is_translating: false,
            translate_cancel: Arc::new(AtomicBool::new(false)),
            batch_files: Vec::new(),
            batch_results: Vec::new(),
            batch_progress: None,
            is_batch_running: false,
            batch_cancel: Arc::new(AtomicBool::new(false)),
            memory_stats: initial_stats,
            memory_query: String::new(),
            memory_results: Vec::new(),
            export_preview: String::new(),
            clipboard,
            tx,
            rx,
            last_save_attempt: Instant::now(),
        }
    }

    fn start_translation(&mut self) {
        if self.is_translating {
            return;
        }

        let text = self.input_text.trim().to_owned();
        if text.is_empty() {
            self.status_message = "Please enter text to translate.".to_owned();
            return;
        }

        self.is_translating = true;
        self.status_message = "Translating to intermediate language...".to_owned();
        self.translate_cancel.store(false, Ordering::Relaxed);

        let source_language = self.settings.source_language.clone();
        let intermediate_language = self.settings.intermediate_language.clone();
        let provider = self.settings.provider();
        let translator = self.translator.clone();
        let cancel = Arc::clone(&self.translate_cancel);
        let tx = self.tx.clone();

        std::thread::spawn(move || {
            let outcome = translator.back_translate(
                &text,
                Some(source_language.as_str()),
                &intermediate_language,
                provider,
                Some(cancel.as_ref()),
            );

            match outcome {
                Ok(result) => {
                    let _ = tx.send(UiEvent::TranslationCompleted(result));
                }
                Err(error) => {
                    let message = match error {
                        TranslationError::Cancelled => "Translation cancelled".to_owned(),
                        other => other.to_string(),
                    };
                    let _ = tx.send(UiEvent::TranslationFailed(message));
                }
            }
        });
    }

    fn cancel_translation(&mut self) {
        if !self.is_translating {
            return;
        }
        self.translate_cancel.store(true, Ordering::Relaxed);
        self.status_message = "Cancelling translation...".to_owned();
    }

    fn start_batch_processing(&mut self) {
        if self.is_batch_running {
            return;
        }
        if self.batch_files.is_empty() {
            self.status_message = "Select files for batch processing first.".to_owned();
            return;
        }

        self.is_batch_running = true;
        self.batch_results.clear();
        self.batch_progress = Some(BatchProgress {
            done: 0,
            total: self.batch_files.len(),
            current_file: String::new(),
        });
        self.status_message = "Batch processing started...".to_owned();

        let files = self.batch_files.clone();
        let options = BatchOptions {
            source_language: Some(self.settings.source_language.clone()),
            intermediate_language: self.settings.intermediate_language.clone(),
            provider_id: self.settings.provider(),
        };

        self.batch_cancel.store(false, Ordering::Relaxed);

        let processor = self.batch_processor.clone();
        let cancel = Arc::clone(&self.batch_cancel);
        let tx = self.tx.clone();

        std::thread::spawn(move || {
            let results = processor.process_files(&files, &options, cancel.as_ref(), |progress| {
                let _ = tx.send(UiEvent::BatchProgress(progress));
            });
            let _ = tx.send(UiEvent::BatchCompleted(results));
        });
    }

    fn cancel_batch_processing(&mut self) {
        if !self.is_batch_running {
            return;
        }

        self.batch_cancel.store(true, Ordering::Relaxed);
        self.status_message = "Cancelling batch...".to_owned();
    }

    fn poll_events(&mut self) {
        while let Ok(event) = self.rx.try_recv() {
            match event {
                UiEvent::TranslationCompleted(result) => {
                    self.intermediate_text = result.intermediate_text.clone();
                    self.back_text = result.back_translated_text.clone();
                    self.last_result = Some(result.clone());
                    self.status_message =
                        format!("Done ({:.2}s)", result.duration_ms as f64 / 1000.0);
                    self.is_translating = false;
                    self.refresh_memory_stats();
                }
                UiEvent::TranslationFailed(message) => {
                    self.status_message = message;
                    self.is_translating = false;
                }
                UiEvent::BatchProgress(progress) => {
                    self.batch_progress = Some(progress.clone());
                    if !progress.current_file.is_empty() {
                        self.status_message = format!(
                            "Batch {}/{}: {}",
                            progress.done, progress.total, progress.current_file
                        );
                    }
                }
                UiEvent::BatchCompleted(results) => {
                    let total = results.len();
                    let successful = results.iter().filter(|item| item.success).count();
                    let failed = total.saturating_sub(successful);
                    self.batch_results = results;
                    self.is_batch_running = false;
                    self.batch_progress = self.batch_progress.take().map(|mut p| {
                        p.done = p.total;
                        p
                    });
                    self.status_message =
                        format!("Batch complete: {successful} succeeded, {failed} failed");
                    self.refresh_memory_stats();
                }
            }
        }
    }

    fn refresh_memory_stats(&mut self) {
        match self.memory.stats() {
            Ok(stats) => {
                self.memory_stats = stats;
            }
            Err(error) => {
                warn!("failed to refresh memory stats: {error}");
            }
        }
    }

    fn run_memory_search(&mut self) {
        let query = self.memory_query.trim();
        if query.is_empty() {
            self.memory_results.clear();
            return;
        }

        match self.memory.search(query, 50) {
            Ok(items) => {
                self.memory_results = items;
                self.status_message = format!("Found {} memory entries", self.memory_results.len());
            }
            Err(error) => {
                self.status_message = format!("Memory search failed: {error}");
            }
        }
    }

    fn clear_memory(&mut self) {
        match self.memory.clear() {
            Ok(_) => {
                self.memory_results.clear();
                self.refresh_memory_stats();
                self.status_message = "Translation memory cleared".to_owned();
            }
            Err(error) => {
                self.status_message = format!("Failed to clear memory: {error}");
            }
        }
    }

    fn import_file_into_input(&mut self) {
        let mut dialog = rfd::FileDialog::new();
        dialog = dialog.add_filter("Supported", SupportedFileType::supported_extensions());

        if let Some(path) = dialog.pick_file() {
            match load_text(&path) {
                Ok(content) => {
                    self.input_text = content;
                    self.settings.last_file_path = path.display().to_string();
                    self.status_message = format!("Loaded {}", path.display());
                }
                Err(error) => {
                    self.status_message = format!("Import failed: {error}");
                }
            }
        }
    }

    fn save_current_result(&mut self) {
        let Some(result) = &self.last_result else {
            self.status_message = "Translate text first.".to_owned();
            return;
        };

        let file_name = format!("backtranslation.{}", self.export_format.extension());
        let mut dialog = rfd::FileDialog::new();
        dialog = dialog.set_file_name(&file_name);

        if let Some(path) = dialog.save_file() {
            let format = ExportFormat::from_path(&path).unwrap_or(self.export_format);
            match self
                .exporter
                .export_single(result, &path, format, self.include_metadata)
            {
                Ok(_) => {
                    self.settings.last_save_path = path.display().to_string();
                    self.status_message = format!("Saved to {}", path.display());
                }
                Err(error) => {
                    error!("failed to export single result: {error}");
                    self.status_message = format!("Export failed: {error}");
                }
            }
        }
    }

    fn save_batch_results(&mut self) {
        if self.batch_results.is_empty() {
            self.status_message = "No batch results to export.".to_owned();
            return;
        }

        let file_name = format!("batch_results.{}", self.export_format.extension());
        let mut dialog = rfd::FileDialog::new();
        dialog = dialog.set_file_name(&file_name);

        if let Some(path) = dialog.save_file() {
            let format = ExportFormat::from_path(&path).unwrap_or(self.export_format);
            let provider = self.settings.provider();
            match self.exporter.export_batch(
                &self.batch_results,
                &path,
                format,
                BatchExportContext {
                    include_metadata: self.include_metadata,
                    source_language: &self.settings.source_language,
                    target_language: &self.settings.intermediate_language,
                    provider: provider.as_str(),
                },
            ) {
                Ok(_) => {
                    self.status_message = format!("Batch report saved to {}", path.display());
                }
                Err(error) => {
                    self.status_message = format!("Batch export failed: {error}");
                }
            }
        }
    }

    fn copy_back_translation(&mut self) {
        if self.back_text.trim().is_empty() {
            self.status_message = "No back-translated text to copy.".to_owned();
            return;
        }

        match self.clipboard.as_mut() {
            Some(clipboard) => match clipboard.set_text(self.back_text.clone()) {
                Ok(_) => {
                    self.status_message = "Back translation copied to clipboard".to_owned();
                }
                Err(error) => {
                    self.status_message = format!("Clipboard copy failed: {error}");
                }
            },
            None => {
                self.status_message = "Clipboard is unavailable in this environment.".to_owned();
            }
        }
    }

    fn select_batch_files(&mut self) {
        if let Some(files) = rfd::FileDialog::new()
            .add_filter("Supported", SupportedFileType::supported_extensions())
            .pick_files()
        {
            self.batch_files = files;
            self.status_message = format!("Selected {} files", self.batch_files.len());
        }
    }

    fn select_batch_directory(&mut self) {
        if let Some(directory) = rfd::FileDialog::new().pick_folder() {
            match self.batch_processor.collect_files(&directory) {
                Ok(files) => {
                    self.batch_files = files;
                    self.status_message = format!(
                        "Loaded {} files from {}",
                        self.batch_files.len(),
                        directory.display()
                    );
                }
                Err(error) => {
                    self.status_message = format!("Failed to scan directory: {error}");
                }
            }
        }
    }

    fn rebuild_export_preview(&mut self) {
        if let Some(result) = &self.last_result {
            match self
                .exporter
                .preview_single(result, self.export_format, self.include_metadata)
            {
                Ok(preview) => {
                    self.export_preview = preview;
                    self.status_message = "Export preview generated".to_owned();
                }
                Err(error) => {
                    self.status_message = format!("Failed to generate preview: {error}");
                }
            }
        } else {
            self.export_preview =
                "Translate at least one text sample to generate preview.".to_owned();
        }
    }

    fn apply_theme(&self, ctx: &egui::Context) {
        if ctx.style().visuals.panel_fill == Color32::from_rgb(14, 14, 16) {
            return;
        }

        apply_cjk_font_fallback(ctx);

        let mut style = (*ctx.style()).clone();
        style.visuals = egui::Visuals::dark();
        style.visuals.override_text_color = Some(Color32::from_rgb(228, 228, 231));
        style.visuals.window_fill = Color32::from_rgb(20, 20, 23);
        style.visuals.panel_fill = Color32::from_rgb(14, 14, 16);
        style.visuals.extreme_bg_color = Color32::from_rgb(10, 10, 12);
        style.visuals.widgets.noninteractive.bg_fill = Color32::from_rgb(28, 28, 32);
        style.visuals.widgets.inactive.bg_fill = Color32::from_rgb(32, 32, 36);
        style.visuals.widgets.hovered.bg_fill = Color32::from_rgb(40, 40, 46);
        style.visuals.widgets.active.bg_fill = Color32::from_rgb(50, 55, 65);
        style.visuals.widgets.inactive.fg_stroke =
            Stroke::new(1.0, Color32::from_rgb(200, 200, 210));
        style.visuals.widgets.hovered.fg_stroke =
            Stroke::new(1.0, Color32::from_rgb(235, 235, 240));
        style.visuals.selection.bg_fill = Color32::from_rgb(59, 130, 246);
        style.visuals.hyperlink_color = Color32::from_rgb(96, 165, 250);
        style.visuals.window_stroke = Stroke::new(1.0, Color32::from_rgb(42, 42, 46));

        style.spacing.item_spacing = Vec2::new(8.0, 8.0);
        style.spacing.button_padding = Vec2::new(16.0, 10.0);
        style.spacing.indent = 16.0;
        style.visuals.window_corner_radius = egui::CornerRadius::same(8);
        style.visuals.widgets.active.corner_radius = egui::CornerRadius::same(8);
        style.visuals.widgets.hovered.corner_radius = egui::CornerRadius::same(8);
        style.visuals.widgets.inactive.corner_radius = egui::CornerRadius::same(8);
        style.visuals.widgets.noninteractive.corner_radius = egui::CornerRadius::same(8);

        ctx.set_style(style);
    }

    fn draw_top_bar(&mut self, ctx: &egui::Context) {
        egui::TopBottomPanel::top("top_bar")
            .resizable(false)
            .exact_height(52.0)
            .show(ctx, |ui| {
                ui.horizontal_wrapped(|ui| {
                    ui.heading(RichText::new("TranslationFiesta Rust").size(18.0).strong());
                    ui.add_space(8.0);
                    ui.label(
                        RichText::new("EN \u{2194} JA backtranslation, batch, memory, export")
                            .size(13.0)
                            .color(Color32::from_rgb(113, 113, 122)),
                    );
                });
            });
    }

    fn draw_background(&self, _ui: &egui::Ui) {
        // Intentionally empty — background provided by panel_fill.
        // Decorative gradients are intentionally omitted for visual clarity.
    }

    fn draw_tab_selector(&mut self, ui: &mut egui::Ui) {
        ui.horizontal_wrapped(|ui| {
            tab_button(ui, &mut self.active_tab, AppTab::Translate, "Translate");
            tab_button(ui, &mut self.active_tab, AppTab::Batch, "Batch");
            tab_button(ui, &mut self.active_tab, AppTab::Memory, "Memory");
            tab_button(ui, &mut self.active_tab, AppTab::Export, "Export");
            tab_button(ui, &mut self.active_tab, AppTab::Settings, "Settings");
            ui.separator();
            let status_color = status_color_for_message(&self.status_message);
            ui.label(
                RichText::new(&self.status_message)
                    .italics()
                    .color(status_color),
            );
        });
        ui.add_space(4.0);
    }

    fn ui_translate_tab(&mut self, ui: &mut egui::Ui) {
        ui.columns(2, |columns| {
            let left = &mut columns[0];
            left.group(|ui| {
                ui.heading("Input");
                ui.add(
                    egui::TextEdit::multiline(&mut self.input_text)
                        .desired_rows(22)
                        .lock_focus(true)
                        .hint_text("Type or paste source text..."),
                );
                ui.horizontal(|ui| {
                    if ui.button("Import").clicked() {
                        self.import_file_into_input();
                    }
                    if ui
                        .add_enabled(!self.is_translating, egui::Button::new("Backtranslate"))
                        .clicked()
                    {
                        self.start_translation();
                    }
                    if ui
                        .add_enabled(self.is_translating, egui::Button::new("Cancel"))
                        .clicked()
                    {
                        self.cancel_translation();
                    }
                });
            });

            let right = &mut columns[1];
            right.group(|ui| {
                ui.heading(format!(
                    "Intermediate ({})",
                    self.settings.intermediate_language.to_ascii_uppercase()
                ));
                if self.intermediate_text.is_empty() && !self.is_translating {
                    ui.label(
                        RichText::new("Translate text to see intermediate output here")
                            .color(Color32::from_rgb(113, 113, 122))
                            .italics(),
                    );
                } else {
                    ui.add(
                        egui::TextEdit::multiline(&mut self.intermediate_text)
                            .desired_rows(10)
                            .interactive(false),
                    );
                }
                ui.add_space(8.0);
                ui.heading(format!(
                    "Back Translation ({})",
                    self.settings.source_language.to_ascii_uppercase()
                ));
                if self.back_text.is_empty() && !self.is_translating {
                    ui.label(
                        RichText::new("Back-translation will appear here")
                            .color(Color32::from_rgb(113, 113, 122))
                            .italics(),
                    );
                } else {
                    ui.add(
                        egui::TextEdit::multiline(&mut self.back_text)
                            .desired_rows(10)
                            .interactive(false),
                    );
                }

                ui.horizontal(|ui| {
                    if ui.button("Copy").clicked() {
                        self.copy_back_translation();
                    }
                    if ui.button("Save").clicked() {
                        self.save_current_result();
                    }
                    if ui.button("Clear").clicked() {
                        self.intermediate_text.clear();
                        self.back_text.clear();
                        self.last_result = None;
                        self.status_message = "Cleared results".to_owned();
                    }
                });

                if self.is_translating {
                    ui.add_space(8.0);
                    ui.horizontal(|ui| {
                        ui.add(egui::Spinner::new());
                        ui.label(
                            RichText::new("Translating…").color(Color32::from_rgb(113, 113, 122)),
                        );
                    });
                }
            });
        });
    }

    fn ui_batch_tab(&mut self, ui: &mut egui::Ui) {
        ui.horizontal_wrapped(|ui| {
            if ui.button("Select Files").clicked() {
                self.select_batch_files();
            }
            if ui.button("Select Folder").clicked() {
                self.select_batch_directory();
            }
            if ui
                .add_enabled(!self.is_batch_running, egui::Button::new("Run Batch"))
                .clicked()
            {
                self.start_batch_processing();
            }
            if ui
                .add_enabled(self.is_batch_running, egui::Button::new("Cancel Batch"))
                .clicked()
            {
                self.cancel_batch_processing();
            }
            if ui
                .add_enabled(
                    !self.batch_results.is_empty(),
                    egui::Button::new("Export Batch"),
                )
                .clicked()
            {
                self.save_batch_results();
            }
        });

        if let Some(progress) = &self.batch_progress {
            let fraction = if progress.total > 0 {
                progress.done as f32 / progress.total as f32
            } else {
                0.0
            };
            ui.add(
                egui::ProgressBar::new(fraction)
                    .text(format!("{}/{}", progress.done, progress.total))
                    .show_percentage(),
            );
        }

        ui.separator();
        ui.label(RichText::new(format!("Selected files: {}", self.batch_files.len())).strong());

        egui::ScrollArea::vertical()
            .max_height(120.0)
            .show(ui, |ui| {
                if self.batch_files.is_empty() {
                    ui.label(
                        RichText::new("Select files or a folder to begin batch processing")
                            .color(Color32::from_rgb(113, 113, 122))
                            .italics(),
                    );
                }
                for file in &self.batch_files {
                    ui.label(file.display().to_string());
                }
            });

        ui.separator();
        ui.label(RichText::new(format!("Batch results: {}", self.batch_results.len())).strong());

        egui::ScrollArea::vertical().show(ui, |ui| {
            if self.batch_results.is_empty() && !self.is_batch_running {
                ui.label(
                    RichText::new("Run a batch to see results here")
                        .color(Color32::from_rgb(113, 113, 122))
                        .italics(),
                );
            }
            for item in &self.batch_results {
                ui.group(|ui| {
                    ui.horizontal(|ui| {
                        let status_label = if item.success {
                            RichText::new("OK").color(Color32::from_rgb(34, 197, 94))
                        } else {
                            RichText::new("ERR").color(Color32::from_rgb(239, 68, 68))
                        };
                        ui.label(status_label);
                        ui.label(RichText::new(&item.file_path).monospace());
                        ui.label(format!("{:.2}s", item.duration_ms as f64 / 1000.0));
                    });
                    if let Some(error) = &item.error {
                        ui.label(RichText::new(error).color(Color32::from_rgb(239, 68, 68)));
                    }
                    if !item.back_translated_text.is_empty() {
                        ui.label("Back translation preview:");
                        let mut preview = truncate_for_preview(&item.back_translated_text, 240);
                        ui.add(
                            egui::TextEdit::multiline(&mut preview)
                                .desired_rows(3)
                                .interactive(false),
                        );
                    }
                });
                ui.add_space(8.0);
            }
        });
    }

    fn ui_memory_tab(&mut self, ui: &mut egui::Ui) {
        ui.horizontal_wrapped(|ui| {
            if ui.button("Refresh Stats").clicked() {
                self.refresh_memory_stats();
            }
            if ui.button("Clear Memory").clicked() {
                self.clear_memory();
            }
            ui.separator();
            ui.label(format!(
                "Entries: {} / {}",
                self.memory_stats.total_entries, self.memory_stats.max_entries
            ));
            ui.label(format!("Hits: {}", self.memory_stats.total_hits));
            ui.label(format!("Misses: {}", self.memory_stats.total_misses));
            ui.label(format!(
                "Hit Rate: {:.1}%",
                self.memory_stats.hit_rate * 100.0
            ));
            ui.label(format!(
                "Avg lookup: {:.2} ms",
                self.memory_stats.avg_lookup_ms
            ));
        });

        ui.separator();
        ui.horizontal(|ui| {
            ui.label("Search:");
            let response = ui.add(
                egui::TextEdit::singleline(&mut self.memory_query)
                    .desired_width(320.0)
                    .hint_text("Find source or translated text..."),
            );
            let enter_pressed =
                response.lost_focus() && ui.input(|input| input.key_pressed(egui::Key::Enter));
            if ui.button("Run").clicked() || enter_pressed {
                self.run_memory_search();
            }
        });

        ui.add_space(8.0);
        egui::ScrollArea::vertical().show(ui, |ui| {
            for entry in &self.memory_results {
                ui.group(|ui| {
                    ui.horizontal(|ui| {
                        ui.label(
                            RichText::new(format!(
                                "{} -> {} ({})",
                                entry.source_language, entry.target_language, entry.provider_id
                            ))
                            .strong(),
                        );
                        ui.label(format!("uses: {}", entry.access_count));
                        ui.label(entry.last_accessed.to_rfc3339());
                    });
                    ui.label(RichText::new(&entry.source_text).monospace());
                    ui.label(
                        RichText::new(&entry.translated_text)
                            .color(Color32::from_rgb(145, 208, 255)),
                    );
                });
                ui.add_space(6.0);
            }

            if self.memory_results.is_empty() {
                ui.label(
                    RichText::new("Search for translations in memory")
                        .color(Color32::from_rgb(113, 113, 122))
                        .italics(),
                );
            }
        });
    }

    fn ui_export_tab(&mut self, ui: &mut egui::Ui) {
        ui.horizontal_wrapped(|ui| {
            ui.label("Format");
            egui::ComboBox::from_id_salt("export_format")
                .selected_text(self.export_format.display_name())
                .show_ui(ui, |ui| {
                    for format in ExportFormat::all() {
                        ui.selectable_value(&mut self.export_format, format, format.display_name());
                    }
                });

            ui.checkbox(&mut self.include_metadata, "Include metadata");

            if ui.button("Generate Preview").clicked() {
                self.rebuild_export_preview();
            }

            if ui
                .add_enabled(
                    self.last_result.is_some(),
                    egui::Button::new("Export Current Result"),
                )
                .clicked()
            {
                self.save_current_result();
            }

            if ui
                .add_enabled(
                    !self.batch_results.is_empty(),
                    egui::Button::new("Export Batch Result"),
                )
                .clicked()
            {
                self.save_batch_results();
            }
        });

        ui.separator();
        ui.label("Preview");
        if self.export_preview.is_empty() {
            self.export_preview = "Generate a preview to inspect export output.".to_owned();
        }
        ui.add(
            egui::TextEdit::multiline(&mut self.export_preview)
                .desired_rows(26)
                .font(egui::TextStyle::Monospace),
        );
    }

    fn ui_settings_tab(&mut self, ui: &mut egui::Ui) {
        ui.group(|ui| {
            ui.heading("Language & Provider");
            ui.horizontal(|ui| {
                ui.label("Source Language");
                ui.text_edit_singleline(&mut self.settings.source_language);
                ui.label("Intermediate Language");
                ui.text_edit_singleline(&mut self.settings.intermediate_language);
            });

            ui.horizontal(|ui| {
                ui.label("Provider");
                egui::ComboBox::from_id_salt("provider_picker")
                    .selected_text(self.settings.provider().display_name())
                    .show_ui(ui, |ui| {
                        ui.selectable_value(
                            &mut self.settings.provider_id,
                            ProviderId::GoogleUnofficial.as_str().to_owned(),
                            ProviderId::GoogleUnofficial.display_name(),
                        );
                    });
            });
        });

        ui.add_space(10.0);

        ui.group(|ui| {
            ui.heading("Runtime Data");
            ui.label(format!("App root: {}", self.paths.app_root.display()));
            ui.label(format!("Data root: {}", self.paths.data_root.display()));
            ui.label(format!("Logs: {}", self.paths.logs_dir.display()));
            ui.label(format!("Exports: {}", self.paths.exports_dir.display()));
            ui.label(format!(
                "Settings file: {}",
                self.paths.settings_file.display()
            ));
            ui.label(format!(
                "Memory DB: {}",
                self.paths.memory_db_file.display()
            ));
        });

        ui.add_space(10.0);

        ui.group(|ui| {
            ui.heading("Behavior");
            ui.horizontal(|ui| {
                ui.label("Translation memory max entries");
                ui.add(
                    egui::DragValue::new(&mut self.settings.translation_memory_max_entries)
                        .speed(10.0)
                        .range(100..=50_000),
                );
            });
            ui.label("Changes are saved automatically every few seconds and on app close.");
        });
    }

    fn maybe_autosave_settings(&mut self) {
        if self.last_save_attempt.elapsed() < Duration::from_secs(4) {
            return;
        }

        self.last_save_attempt = Instant::now();
        if let Err(error) = save_settings(&self.paths.settings_file, &self.settings) {
            warn!("failed to autosave settings: {error}");
        }
    }
}

impl eframe::App for TranslationFiestaApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        self.apply_theme(ctx);
        self.poll_events();

        self.draw_top_bar(ctx);

        egui::CentralPanel::default().show(ctx, |ui| {
            self.draw_background(ui);
            ui.add_space(8.0);
            self.draw_tab_selector(ui);

            match self.active_tab {
                AppTab::Translate => self.ui_translate_tab(ui),
                AppTab::Batch => self.ui_batch_tab(ui),
                AppTab::Memory => self.ui_memory_tab(ui),
                AppTab::Export => self.ui_export_tab(ui),
                AppTab::Settings => self.ui_settings_tab(ui),
            }
        });

        if self.is_translating || self.is_batch_running {
            ctx.request_repaint_after(Duration::from_millis(33));
        }

        self.maybe_autosave_settings();
    }
}

impl Drop for TranslationFiestaApp {
    fn drop(&mut self) {
        if let Err(error) = save_settings(&self.paths.settings_file, &self.settings) {
            error!("failed to save settings on shutdown: {error}");
        } else {
            info!("settings saved to {}", self.paths.settings_file.display());
        }
    }
}

fn tab_button(ui: &mut egui::Ui, active_tab: &mut AppTab, value: AppTab, label: &str) {
    let selected = *active_tab == value;
    let text = if selected {
        RichText::new(label).strong()
    } else {
        RichText::new(label)
    };

    if ui.add(egui::Button::new(text).selected(selected)).clicked() {
        *active_tab = value;
    }
}

fn truncate_for_preview(value: &str, limit: usize) -> String {
    let count = value.chars().count();
    if count <= limit {
        return value.to_owned();
    }

    let mut out = value.chars().take(limit).collect::<String>();
    out.push_str("...");
    out
}

fn status_color_for_message(message: &str) -> Color32 {
    let lower = message.to_ascii_lowercase();

    if lower.starts_with("done")
        || lower.contains("complete")
        || lower.contains("saved")
        || lower.contains("copied")
        || lower.contains("cleared")
        || lower.contains("loaded")
    {
        return Color32::from_rgb(34, 197, 94); // success green
    }

    if lower.contains("failed") || lower.contains("error") {
        return Color32::from_rgb(239, 68, 68); // error red
    }

    if lower.contains("translating")
        || lower.contains("processing")
        || lower.contains("cancelling")
        || lower.starts_with("batch ")
    {
        return Color32::from_rgb(59, 130, 246); // accent blue
    }

    // Idle / ready / informational
    Color32::from_rgb(113, 113, 122) // muted gray
}

fn apply_cjk_font_fallback(ctx: &egui::Context) {
    let Some((font_name, font_data, font_path)) = load_cjk_font_data() else {
        warn!("no Japanese-capable system font found; install a CJK font to avoid missing glyphs");
        return;
    };

    let mut fonts = egui::FontDefinitions::default();
    fonts.font_data.insert(
        font_name.clone(),
        Arc::new(egui::FontData::from_owned(font_data)),
    );

    if let Some(family) = fonts.families.get_mut(&egui::FontFamily::Proportional) {
        family.push(font_name.clone());
    }
    if let Some(family) = fonts.families.get_mut(&egui::FontFamily::Monospace) {
        family.push(font_name.clone());
    }

    ctx.set_fonts(fonts);
    info!("loaded Japanese fallback font from {}", font_path.display());
}

fn load_cjk_font_data() -> Option<(String, Vec<u8>, PathBuf)> {
    for candidate in cjk_font_candidates() {
        let path = PathBuf::from(candidate);
        let bytes = match fs::read(&path) {
            Ok(bytes) => bytes,
            Err(_) => continue,
        };

        let stem = path
            .file_stem()
            .and_then(|name| name.to_str())
            .unwrap_or("cjk-fallback");
        let font_name = format!("cjk-{stem}");
        return Some((font_name, bytes, path));
    }
    None
}

fn cjk_font_candidates() -> &'static [&'static str] {
    &[
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
        r"C:\Windows\Fonts\YuGothM.ttc",
        r"C:\Windows\Fonts\YuGothR.ttc",
        r"C:\Windows\Fonts\Meiryo.ttc",
        r"C:\Windows\Fonts\msgothic.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
        "/usr/share/fonts/truetype/noto/NotoSansJP-Regular.otf",
        "/usr/share/fonts/truetype/noto/NotoSansJP-Regular.ttf",
        "/usr/local/share/fonts/NotoSansCJK-Regular.ttc",
    ]
}
