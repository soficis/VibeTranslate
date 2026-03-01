use std::fs::File;
use std::io::Read;
use std::path::Path;

use anyhow::{Context, Result};
use quick_xml::Reader;
use quick_xml::events::Event;
use zip::ZipArchive;

use crate::html::extract_text_from_html;
use crate::models::{EpubBook, EpubChapter};

pub fn load_epub(path: &Path) -> Result<EpubBook> {
    let file =
        File::open(path).with_context(|| format!("failed to open EPUB file {}", path.display()))?;
    let mut archive = ZipArchive::new(file).context("failed to read EPUB zip archive")?;

    let mut title: Option<String> = None;
    let mut author: Option<String> = None;

    let mut chapters = Vec::new();

    for index in 0..archive.len() {
        let mut entry = archive
            .by_index(index)
            .with_context(|| format!("failed to open EPUB entry index {index}"))?;

        let name = entry.name().to_string();
        let lower = name.to_ascii_lowercase();

        if lower.ends_with(".opf") {
            let mut xml = String::new();
            entry
                .read_to_string(&mut xml)
                .with_context(|| format!("failed to read OPF entry {name}"))?;
            let (parsed_title, parsed_author) = parse_opf_metadata(&xml);
            if title.is_none() {
                title = parsed_title;
            }
            if author.is_none() {
                author = parsed_author;
            }
            continue;
        }

        if !(lower.ends_with(".xhtml") || lower.ends_with(".html") || lower.ends_with(".htm")) {
            continue;
        }

        let mut bytes = Vec::new();
        entry
            .read_to_end(&mut bytes)
            .with_context(|| format!("failed to read chapter entry {name}"))?;

        let raw = String::from_utf8_lossy(&bytes).to_string();
        let text = extract_text_from_html(&raw);

        if text.trim().is_empty() {
            continue;
        }

        let chapter_title = parse_html_title(&raw)
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| infer_title_from_path(&name));

        chapters.push(EpubChapter {
            title: chapter_title,
            path: name,
            content: text,
            order: chapters.len(),
        });
    }

    chapters.sort_by_key(|chapter| chapter.order);

    let fallback_title = path
        .file_stem()
        .map(|stem| stem.to_string_lossy().to_string())
        .unwrap_or_else(|| "Untitled EPUB".to_string());

    Ok(EpubBook {
        title: title.unwrap_or(fallback_title),
        author,
        chapters,
    })
}

pub fn extract_text(path: &Path) -> Result<String> {
    let book = load_epub(path)?;
    let content = book
        .chapters
        .iter()
        .map(|chapter| chapter.content.as_str())
        .collect::<Vec<_>>()
        .join("\n\n");
    Ok(content)
}

fn parse_html_title(html: &str) -> Option<String> {
    let lower = html.to_ascii_lowercase();
    let start = lower.find("<title>")? + "<title>".len();
    let end = lower[start..].find("</title>")? + start;
    let raw = &html[start..end];
    let value = raw.replace(['\n', '\r', '\t'], " ").trim().to_string();
    if value.is_empty() { None } else { Some(value) }
}

fn infer_title_from_path(path: &str) -> String {
    Path::new(path)
        .file_stem()
        .map(|name| name.to_string_lossy().replace(['_', '-'], " "))
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| "Untitled Chapter".to_string())
}

fn parse_opf_metadata(opf_xml: &str) -> (Option<String>, Option<String>) {
    let mut reader = Reader::from_str(opf_xml);
    reader.config_mut().trim_text(true);

    let mut current_tag = String::new();
    let mut title: Option<String> = None;
    let mut author: Option<String> = None;

    loop {
        match reader.read_event() {
            Ok(Event::Start(tag)) => {
                current_tag = String::from_utf8_lossy(tag.name().as_ref())
                    .to_ascii_lowercase()
                    .to_string();
            }
            Ok(Event::Text(text)) => {
                if let Ok(value) = text.decode() {
                    let value = value.trim().to_string();
                    if value.is_empty() {
                        continue;
                    }

                    if title.is_none()
                        && (current_tag == "dc:title" || current_tag.ends_with(":title"))
                    {
                        title = Some(value.clone());
                    }

                    if author.is_none()
                        && (current_tag == "dc:creator" || current_tag.ends_with(":creator"))
                    {
                        author = Some(value);
                    }
                }
            }
            Ok(Event::Eof) => break,
            Ok(_) => {}
            Err(_) => break,
        }
    }

    (title, author)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_basic_opf_metadata() {
        let xml = r#"
            <package>
              <metadata>
                <dc:title>Book Title</dc:title>
                <dc:creator>Author Name</dc:creator>
              </metadata>
            </package>
        "#;

        let (title, author) = parse_opf_metadata(xml);
        assert_eq!(title.as_deref(), Some("Book Title"));
        assert_eq!(author.as_deref(), Some("Author Name"));
    }
}
