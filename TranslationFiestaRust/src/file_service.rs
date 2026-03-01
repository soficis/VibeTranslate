use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use walkdir::WalkDir;

use crate::epub;
use crate::html::extract_text_from_html;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SupportedFileType {
    Txt,
    Markdown,
    Html,
    Epub,
}

impl SupportedFileType {
    pub fn detect(path: &Path) -> Option<Self> {
        let extension = path.extension()?.to_string_lossy().to_ascii_lowercase();
        match extension.as_str() {
            "txt" => Some(Self::Txt),
            "md" | "markdown" => Some(Self::Markdown),
            "html" | "htm" => Some(Self::Html),
            "epub" => Some(Self::Epub),
            _ => None,
        }
    }

    pub fn supported_extensions() -> &'static [&'static str] {
        &["txt", "md", "html", "htm", "epub"]
    }
}

pub fn load_text(path: &Path) -> Result<String> {
    if !path.exists() {
        bail!("file does not exist: {}", path.display());
    }

    let file_type = SupportedFileType::detect(path)
        .ok_or_else(|| anyhow::anyhow!("unsupported file type for {}", path.display()))?;

    match file_type {
        SupportedFileType::Txt | SupportedFileType::Markdown => read_text(path),
        SupportedFileType::Html => {
            let raw = read_text(path)?;
            Ok(extract_text_from_html(&raw))
        }
        SupportedFileType::Epub => epub::extract_text(path),
    }
}

pub fn save_text(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .with_context(|| format!("failed to create output directory {}", parent.display()))?;
    }

    fs::write(path, content.as_bytes())
        .with_context(|| format!("failed to write file {}", path.display()))
}

pub fn list_supported_files_in_directory(directory: &Path) -> Result<Vec<PathBuf>> {
    if !directory.exists() {
        bail!("directory does not exist: {}", directory.display());
    }
    if !directory.is_dir() {
        bail!("path is not a directory: {}", directory.display());
    }

    let mut files = Vec::new();
    for entry in WalkDir::new(directory)
        .follow_links(false)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file())
    {
        let path = entry.path();
        if SupportedFileType::detect(path).is_some() {
            files.push(path.to_path_buf());
        }
    }

    files.sort();
    Ok(files)
}

fn read_text(path: &Path) -> Result<String> {
    const MAX_FILE_BYTES: u64 = 50 * 1024 * 1024;

    let metadata = fs::metadata(path)
        .with_context(|| format!("failed to read metadata for {}", path.display()))?;

    if metadata.len() > MAX_FILE_BYTES {
        bail!(
            "file too large: {} ({} bytes exceeds {} bytes)",
            path.display(),
            metadata.len(),
            MAX_FILE_BYTES
        );
    }

    let raw = fs::read(path).with_context(|| format!("failed to read {}", path.display()))?;
    Ok(String::from_utf8_lossy(&raw).trim().to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn detects_supported_extensions() {
        assert_eq!(
            SupportedFileType::detect(Path::new("note.md")),
            Some(SupportedFileType::Markdown)
        );
        assert!(SupportedFileType::detect(Path::new("image.png")).is_none());
    }
}
