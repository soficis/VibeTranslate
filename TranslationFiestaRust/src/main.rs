use std::error::Error;

use clap::Parser;
use eframe::egui;

use translation_fiesta_rust::app_paths::AppPaths;
use translation_fiesta_rust::cli::{CliArgs, CliRuntime, execute};
use translation_fiesta_rust::initialize_runtime;
use translation_fiesta_rust::logger::init_logger;
use translation_fiesta_rust::ui::TranslationFiestaApp;

fn main() -> Result<(), Box<dyn Error>> {
    let args = CliArgs::parse();

    let paths = AppPaths::discover()?;
    let log_path = paths.logs_dir.join("translationfiestarust.log");
    init_logger(&log_path)?;

    let runtime = initialize_runtime(paths.clone())?;

    let cli_runtime = CliRuntime {
        paths: runtime.paths.clone(),
        translator: runtime.translator.clone(),
        batch: runtime.batch.clone(),
        export: runtime.export.clone(),
        memory: runtime.memory.clone(),
    };

    if execute(&args, &cli_runtime)? {
        return Ok(());
    }

    let window_size = egui::vec2(
        runtime.settings.window_width,
        runtime.settings.window_height,
    );

    let native_options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size(window_size)
            .with_min_inner_size(egui::vec2(900.0, 620.0)),
        ..Default::default()
    };

    let app = TranslationFiestaApp::new(
        runtime.paths,
        runtime.settings,
        runtime.translator,
        runtime.batch,
        runtime.export,
        runtime.memory,
    );

    eframe::run_native(
        "TranslationFiesta Rust",
        native_options,
        Box::new(|_cc| Ok(Box::new(app))),
    )?;

    Ok(())
}
