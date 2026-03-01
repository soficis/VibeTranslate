use std::env;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result};

#[derive(Debug, Clone)]
pub struct AppPaths {
    pub app_root: PathBuf,
    pub data_root: PathBuf,
    pub logs_dir: PathBuf,
    pub exports_dir: PathBuf,
    pub settings_file: PathBuf,
    pub memory_db_file: PathBuf,
}

impl AppPaths {
    pub fn discover() -> Result<Self> {
        let app_root = resolve_app_root()?;
        let data_root = resolve_data_root(&app_root)?;
        let logs_dir = ensure_dir(data_root.join("logs"))?;
        let exports_dir = ensure_dir(data_root.join("exports"))?;
        let settings_file = data_root.join("settings.json");
        let memory_db_file = data_root.join("translation_memory.db");

        Ok(Self {
            app_root,
            data_root,
            logs_dir,
            exports_dir,
            settings_file,
            memory_db_file,
        })
    }
}

fn resolve_app_root() -> Result<PathBuf> {
    if let Ok(exe) = env::current_exe()
        && let Some(parent) = exe.parent()
    {
        return Ok(parent.to_path_buf());
    }

    env::current_dir().context("failed to resolve current directory")
}

fn resolve_data_root(app_root: &Path) -> Result<PathBuf> {
    if let Ok(override_path) = env::var("TF_APP_HOME") {
        let trimmed = override_path.trim();
        if !trimmed.is_empty() {
            return ensure_dir(PathBuf::from(trimmed));
        }
    }

    ensure_dir(app_root.join("data"))
}

fn ensure_dir(path: PathBuf) -> Result<PathBuf> {
    std::fs::create_dir_all(&path)
        .with_context(|| format!("failed to create directory {}", path.display()))?;
    Ok(path)
}
