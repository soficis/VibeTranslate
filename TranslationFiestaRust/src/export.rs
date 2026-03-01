use std::fs::File;
use std::io::Write;
use std::path::Path;

use anyhow::{Context, Result};
use chrono::Utc;
use csv::Writer;
use printpdf::{BuiltinFont, Mm, Op, PdfDocument, PdfPage, PdfSaveOptions, Point, Pt, TextItem};
use serde_json::json;
use zip::CompressionMethod;
use zip::write::SimpleFileOptions;

use crate::html::escape_html;
use crate::models::{BackTranslationResult, BatchItemResult, ExportFormat, ExportMetadata};

#[derive(Debug, Default, Clone)]
pub struct ExportService;

#[derive(Debug, Clone, Copy)]
pub struct BatchExportContext<'a> {
    pub include_metadata: bool,
    pub source_language: &'a str,
    pub target_language: &'a str,
    pub provider: &'a str,
}

impl ExportService {
    pub fn export_single(
        &self,
        result: &BackTranslationResult,
        output_path: &Path,
        format: ExportFormat,
        include_metadata: bool,
    ) -> Result<()> {
        let metadata = ExportMetadata::from_result(result);
        self.export_single_with_metadata(result, output_path, format, include_metadata, &metadata)
    }

    pub fn export_single_with_metadata(
        &self,
        result: &BackTranslationResult,
        output_path: &Path,
        format: ExportFormat,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        match format {
            ExportFormat::Txt => {
                std::fs::write(
                    output_path,
                    self.single_txt_content(result, include_metadata, metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Markdown => {
                std::fs::write(
                    output_path,
                    self.single_markdown_content(result, include_metadata, metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Html => {
                std::fs::write(
                    output_path,
                    self.single_html_content(result, include_metadata, metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Json => {
                let payload = json!({
                    "metadata": if include_metadata { serde_json::to_value(metadata)? } else { json!(null) },
                    "result": result,
                });
                std::fs::write(output_path, serde_json::to_string_pretty(&payload)?)
                    .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Csv => {
                self.write_single_csv(result, output_path, include_metadata, metadata)?;
            }
            ExportFormat::Xml => {
                std::fs::write(
                    output_path,
                    self.single_xml_content(result, include_metadata, metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Pdf => {
                self.write_single_pdf(result, output_path, include_metadata, metadata)?;
            }
            ExportFormat::Docx => {
                self.write_single_docx(result, output_path, include_metadata, metadata)?;
            }
        }

        Ok(())
    }

    pub fn export_batch(
        &self,
        results: &[BatchItemResult],
        output_path: &Path,
        format: ExportFormat,
        context: BatchExportContext<'_>,
    ) -> Result<()> {
        let average_secs = if results.is_empty() {
            0.0
        } else {
            let sum: u128 = results.iter().map(|item| item.duration_ms).sum();
            (sum as f64 / results.len() as f64) / 1000.0
        };

        let metadata = ExportMetadata {
            title: "Batch Translation Results".to_owned(),
            author: "TranslationFiesta Rust".to_owned(),
            subject: "Batch Backtranslation Results".to_owned(),
            keywords: vec!["batch".to_owned(), "translation".to_owned()],
            created_date: Utc::now(),
            source_language: context.source_language.to_owned(),
            target_language: context.target_language.to_owned(),
            processing_time_seconds: average_secs,
            api_used: context.provider.to_owned(),
        };

        match format {
            ExportFormat::Txt | ExportFormat::Markdown => {
                std::fs::write(
                    output_path,
                    self.batch_text_content(
                        results,
                        context.include_metadata,
                        &metadata,
                        matches!(format, ExportFormat::Markdown),
                    ),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Html => {
                std::fs::write(
                    output_path,
                    self.batch_html_content(results, context.include_metadata, &metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Json => {
                let payload = json!({
                    "metadata": if context.include_metadata { serde_json::to_value(&metadata)? } else { json!(null) },
                    "results": results,
                });
                std::fs::write(output_path, serde_json::to_string_pretty(&payload)?)
                    .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Csv => {
                self.write_batch_csv(results, output_path, context.include_metadata, &metadata)?
            }
            ExportFormat::Xml => {
                std::fs::write(
                    output_path,
                    self.batch_xml_content(results, context.include_metadata, &metadata),
                )
                .with_context(|| format!("failed to write {}", output_path.display()))?;
            }
            ExportFormat::Pdf => {
                self.write_batch_pdf(results, output_path, context.include_metadata, &metadata)?
            }
            ExportFormat::Docx => {
                self.write_batch_docx(results, output_path, context.include_metadata, &metadata)?
            }
        }

        Ok(())
    }

    pub fn preview_single(
        &self,
        result: &BackTranslationResult,
        format: ExportFormat,
        include_metadata: bool,
    ) -> Result<String> {
        let metadata = ExportMetadata::from_result(result);
        let preview = match format {
            ExportFormat::Txt => self.single_txt_content(result, include_metadata, &metadata),
            ExportFormat::Markdown => {
                self.single_markdown_content(result, include_metadata, &metadata)
            }
            ExportFormat::Html => self.single_html_content(result, include_metadata, &metadata),
            ExportFormat::Json => serde_json::to_string_pretty(&json!({
                "metadata": if include_metadata { serde_json::to_value(&metadata)? } else { json!(null) },
                "result": result,
            }))?,
            ExportFormat::Csv => {
                let mut buffer: Vec<u8> = Vec::new();
                {
                    let mut writer = Writer::from_writer(&mut buffer);
                    self.write_single_csv(&mut writer, result)?;
                    writer.flush()?;
                }
                String::from_utf8(buffer)
                    .context("Failed to convert CSV preview to UTF-8 string")?
            }
            ExportFormat::Xml => self.single_xml_content(result, include_metadata, &metadata),
            ExportFormat::Pdf | ExportFormat::Docx => {
                self.single_markdown_content(result, include_metadata, &metadata)
            }
        };

        Ok(preview)
    }

    fn single_txt_content(
        &self,
        result: &BackTranslationResult,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let mut output = String::new();

        output.push_str("TranslationFiesta Rust - Translation Result\n\n");
        output.push_str("Original Text:\n");
        output.push_str(&result.original_text);
        output.push_str("\n\nIntermediate Translation:\n");
        output.push_str(&result.intermediate_text);
        output.push_str("\n\nBack Translation:\n");
        output.push_str(&result.back_translated_text);
        output.push('\n');

        if include_metadata {
            output.push_str("\nMetadata:\n");
            output.push_str(&format!("- API Used: {}\n", metadata.api_used));
            output.push_str(&format!(
                "- Source Language: {}\n",
                metadata.source_language
            ));
            output.push_str(&format!(
                "- Target Language: {}\n",
                metadata.target_language
            ));
            output.push_str(&format!(
                "- Processing Time: {:.2}s\n",
                metadata.processing_time_seconds
            ));
            output.push_str(&format!("- Timestamp: {}\n", metadata.created_date));
        }

        output
    }

    fn single_markdown_content(
        &self,
        result: &BackTranslationResult,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let mut output = String::new();
        output.push_str("# Translation Result\n\n");
        output.push_str("## Original Text\n\n");
        output.push_str(&result.original_text);
        output.push_str("\n\n## Intermediate Translation\n\n");
        output.push_str(&result.intermediate_text);
        output.push_str("\n\n## Back Translation\n\n");
        output.push_str(&result.back_translated_text);
        output.push('\n');

        if include_metadata {
            output.push_str("\n## Metadata\n\n");
            output.push_str(&format!("- API Used: {}\n", metadata.api_used));
            output.push_str(&format!(
                "- Source Language: {}\n",
                metadata.source_language
            ));
            output.push_str(&format!(
                "- Target Language: {}\n",
                metadata.target_language
            ));
            output.push_str(&format!(
                "- Processing Time: {:.2}s\n",
                metadata.processing_time_seconds
            ));
            output.push_str(&format!("- Timestamp: {}\n", metadata.created_date));
        }

        output
    }

    fn single_html_content(
        &self,
        result: &BackTranslationResult,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let metadata_block = if include_metadata {
            format!(
                "<section class=\"metadata\"><h2>Metadata</h2><table><tr><th>API Used</th><td>{}</td></tr><tr><th>Source</th><td>{}</td></tr><tr><th>Target</th><td>{}</td></tr><tr><th>Processing Time</th><td>{:.2}s</td></tr><tr><th>Timestamp</th><td>{}</td></tr></table></section>",
                escape_html(&metadata.api_used),
                escape_html(&metadata.source_language),
                escape_html(&metadata.target_language),
                metadata.processing_time_seconds,
                escape_html(&metadata.created_date.to_rfc3339()),
            )
        } else {
            String::new()
        };

        format!(
            "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{}</title><style>{}</style></head><body><main class=\"container\"><h1>Translation Result</h1><section><h2>Original Text</h2><div class=\"block\">{}</div></section><section><h2>Intermediate Translation</h2><div class=\"block\">{}</div></section><section><h2>Back Translation</h2><div class=\"block\">{}</div></section>{}</main></body></html>",
            escape_html(&metadata.title),
            base_html_style(),
            escape_html(&result.original_text).replace('\n', "<br>"),
            escape_html(&result.intermediate_text).replace('\n', "<br>"),
            escape_html(&result.back_translated_text).replace('\n', "<br>"),
            metadata_block,
        )
    }

    fn single_xml_content(
        &self,
        result: &BackTranslationResult,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let metadata_xml = if include_metadata {
            format!(
                "<metadata><title>{}</title><apiUsed>{}</apiUsed><sourceLanguage>{}</sourceLanguage><targetLanguage>{}</targetLanguage><processingTimeSeconds>{:.2}</processingTimeSeconds><timestamp>{}</timestamp></metadata>",
                xml_escape(&metadata.title),
                xml_escape(&metadata.api_used),
                xml_escape(&metadata.source_language),
                xml_escape(&metadata.target_language),
                metadata.processing_time_seconds,
                xml_escape(&metadata.created_date.to_rfc3339()),
            )
        } else {
            String::new()
        };

        format!(
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?><translationResult>{}<originalText>{}</originalText><intermediateText>{}</intermediateText><backTranslatedText>{}</backTranslatedText></translationResult>",
            metadata_xml,
            xml_escape(&result.original_text),
            xml_escape(&result.intermediate_text),
            xml_escape(&result.back_translated_text),
        )
    }

    fn batch_text_content(
        &self,
        results: &[BatchItemResult],
        include_metadata: bool,
        metadata: &ExportMetadata,
        markdown: bool,
    ) -> String {
        let mut output = String::new();

        if markdown {
            output.push_str("# Batch Translation Results\n\n");
        } else {
            output.push_str("Batch Translation Results\n\n");
        }

        if include_metadata {
            if markdown {
                output.push_str("## Metadata\n\n");
            } else {
                output.push_str("Metadata:\n");
            }
            output.push_str(&format!("API Used: {}\n", metadata.api_used));
            output.push_str(&format!("Source Language: {}\n", metadata.source_language));
            output.push_str(&format!("Target Language: {}\n", metadata.target_language));
            output.push_str(&format!(
                "Average Processing Time: {:.2}s\n\n",
                metadata.processing_time_seconds
            ));
        }

        for (index, result) in results.iter().enumerate() {
            if markdown {
                output.push_str(&format!("## File {}\n\n", index + 1));
                output.push_str(&format!("- Path: `{}`\n", result.file_path));
                output.push_str(&format!("- Success: {}\n", result.success));
                output.push_str(&format!(
                    "- Duration: {:.2}s\n",
                    result.duration_ms as f64 / 1000.0
                ));
                if let Some(error) = &result.error {
                    output.push_str(&format!("- Error: {}\n", error));
                }
                output.push_str("\n### Intermediate\n\n");
                output.push_str(&result.intermediate_text);
                output.push_str("\n\n### Back Translation\n\n");
                output.push_str(&result.back_translated_text);
                output.push_str("\n\n---\n\n");
            } else {
                output.push_str(&format!("File {}\n", index + 1));
                output.push_str(&format!("Path: {}\n", result.file_path));
                output.push_str(&format!("Success: {}\n", result.success));
                output.push_str(&format!(
                    "Duration: {:.2}s\n",
                    result.duration_ms as f64 / 1000.0
                ));
                if let Some(error) = &result.error {
                    output.push_str(&format!("Error: {}\n", error));
                }
                output.push_str("Intermediate:\n");
                output.push_str(&result.intermediate_text);
                output.push_str("\nBack Translation:\n");
                output.push_str(&result.back_translated_text);
                output.push_str("\n\n----------------------------------------\n\n");
            }
        }

        output
    }

    fn batch_html_content(
        &self,
        results: &[BatchItemResult],
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let mut body = String::new();

        if include_metadata {
            body.push_str(&format!(
                "<section class=\"metadata\"><h2>Metadata</h2><table><tr><th>API Used</th><td>{}</td></tr><tr><th>Source</th><td>{}</td></tr><tr><th>Target</th><td>{}</td></tr><tr><th>Average Processing Time</th><td>{:.2}s</td></tr></table></section>",
                escape_html(&metadata.api_used),
                escape_html(&metadata.source_language),
                escape_html(&metadata.target_language),
                metadata.processing_time_seconds
            ));
        }

        body.push_str("<section><h2>Results</h2>");
        for (index, result) in results.iter().enumerate() {
            body.push_str(&format!(
                "<article class=\"item\"><h3>File {}</h3><p><strong>Path:</strong> {}</p><p><strong>Success:</strong> {}</p><p><strong>Duration:</strong> {:.2}s</p>{}<h4>Intermediate</h4><div class=\"block\">{}</div><h4>Back Translation</h4><div class=\"block\">{}</div></article>",
                index + 1,
                escape_html(&result.file_path),
                result.success,
                result.duration_ms as f64 / 1000.0,
                result
                    .error
                    .as_ref()
                    .map(|error| format!("<p><strong>Error:</strong> {}</p>", escape_html(error)))
                    .unwrap_or_default(),
                escape_html(&result.intermediate_text).replace('\n', "<br>"),
                escape_html(&result.back_translated_text).replace('\n', "<br>")
            ));
        }
        body.push_str("</section>");

        format!(
            "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>{}</title><style>{}</style></head><body><main class=\"container\"><h1>Batch Translation Results</h1>{}</main></body></html>",
            escape_html(&metadata.title),
            base_html_style(),
            body,
        )
    }

    fn batch_xml_content(
        &self,
        results: &[BatchItemResult],
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> String {
        let mut xml = String::new();
        xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?><batchTranslationResults>");

        if include_metadata {
            xml.push_str(&format!(
                "<metadata><title>{}</title><apiUsed>{}</apiUsed><sourceLanguage>{}</sourceLanguage><targetLanguage>{}</targetLanguage><averageProcessingTime>{:.2}</averageProcessingTime></metadata>",
                xml_escape(&metadata.title),
                xml_escape(&metadata.api_used),
                xml_escape(&metadata.source_language),
                xml_escape(&metadata.target_language),
                metadata.processing_time_seconds,
            ));
        }

        xml.push_str("<items>");
        for item in results {
            xml.push_str(&format!(
                "<item><filePath>{}</filePath><success>{}</success><durationMs>{}</durationMs><intermediateText>{}</intermediateText><backTranslatedText>{}</backTranslatedText>{}</item>",
                xml_escape(&item.file_path),
                item.success,
                item.duration_ms,
                xml_escape(&item.intermediate_text),
                xml_escape(&item.back_translated_text),
                item.error
                    .as_ref()
                    .map(|error| format!("<error>{}</error>", xml_escape(error)))
                    .unwrap_or_default()
            ));
        }
        xml.push_str("</items></batchTranslationResults>");
        xml
    }

    fn write_single_csv(
        &self,
        result: &BackTranslationResult,
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let mut writer = Writer::from_path(output_path)
            .with_context(|| format!("failed to create CSV {}", output_path.display()))?;

        if include_metadata {
            writer.write_record(["metadata_key", "metadata_value"])?;
            writer.write_record(["title", metadata.title.as_str()])?;
            writer.write_record(["api_used", metadata.api_used.as_str()])?;
            writer.write_record(["source_language", metadata.source_language.as_str()])?;
            writer.write_record(["target_language", metadata.target_language.as_str()])?;
            writer.write_record([
                "processing_time_seconds",
                &format!("{:.2}", metadata.processing_time_seconds),
            ])?;
            writer.write_record(["", ""])?;
        }

        writer.write_record([
            "original_text",
            "intermediate_text",
            "back_translated_text",
            "source_language",
            "target_language",
            "provider_id",
            "duration_ms",
        ])?;

        writer.write_record([
            result.original_text.as_str(),
            result.intermediate_text.as_str(),
            result.back_translated_text.as_str(),
            result.source_language.as_str(),
            result.intermediate_language.as_str(),
            result.provider_id.as_str(),
            &result.duration_ms.to_string(),
        ])?;

        writer.flush()?;
        Ok(())
    }

    fn write_batch_csv(
        &self,
        results: &[BatchItemResult],
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let mut writer = Writer::from_path(output_path)
            .with_context(|| format!("failed to create CSV {}", output_path.display()))?;

        if include_metadata {
            writer.write_record(["metadata_key", "metadata_value"])?;
            writer.write_record(["title", metadata.title.as_str()])?;
            writer.write_record(["api_used", metadata.api_used.as_str()])?;
            writer.write_record(["source_language", metadata.source_language.as_str()])?;
            writer.write_record(["target_language", metadata.target_language.as_str()])?;
            writer.write_record([
                "processing_time_seconds",
                &format!("{:.2}", metadata.processing_time_seconds),
            ])?;
            writer.write_record(["", ""])?;
        }

        writer.write_record([
            "file_path",
            "success",
            "duration_ms",
            "intermediate_text",
            "back_translated_text",
            "error",
        ])?;

        for item in results {
            writer.write_record([
                item.file_path.as_str(),
                &item.success.to_string(),
                &item.duration_ms.to_string(),
                item.intermediate_text.as_str(),
                item.back_translated_text.as_str(),
                item.error.as_deref().unwrap_or(""),
            ])?;
        }

        writer.flush()?;
        Ok(())
    }

    fn write_single_pdf(
        &self,
        result: &BackTranslationResult,
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let content = self.single_markdown_content(result, include_metadata, metadata);
        write_pdf(output_path, &metadata.title, &content)
    }

    fn write_batch_pdf(
        &self,
        results: &[BatchItemResult],
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let content = self.batch_text_content(results, include_metadata, metadata, false);
        write_pdf(output_path, &metadata.title, &content)
    }

    fn write_single_docx(
        &self,
        result: &BackTranslationResult,
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let content = self.single_txt_content(result, include_metadata, metadata);
        write_docx(output_path, &content)
    }

    fn write_batch_docx(
        &self,
        results: &[BatchItemResult],
        output_path: &Path,
        include_metadata: bool,
        metadata: &ExportMetadata,
    ) -> Result<()> {
        let content = self.batch_text_content(results, include_metadata, metadata, false);
        write_docx(output_path, &content)
    }
}

fn write_pdf(path: &Path, title: &str, text: &str) -> Result<()> {
    let mut doc = PdfDocument::new(title);

    let mut ops = vec![
        Op::StartTextSection,
        Op::SetTextCursor {
            pos: Point::new(Mm(12.0), Mm(285.0)),
        },
        Op::SetFontSizeBuiltinFont {
            size: Pt(11.0),
            font: BuiltinFont::Helvetica,
        },
        Op::SetLineHeight { lh: Pt(14.0) },
    ];

    for line in text.lines().take(90) {
        let safe_line = if line.is_empty() { " " } else { line };
        ops.push(Op::WriteTextBuiltinFont {
            items: vec![TextItem::Text(safe_line.to_owned())],
            font: BuiltinFont::Helvetica,
        });
        ops.push(Op::AddLineBreak);
    }

    ops.push(Op::EndTextSection);

    let page = PdfPage::new(Mm(210.0), Mm(297.0), ops);
    let bytes = doc
        .with_pages(vec![page])
        .save(&PdfSaveOptions::default(), &mut Vec::new());

    std::fs::write(path, bytes)
        .with_context(|| format!("failed to save PDF {}", path.display()))?;

    Ok(())
}

fn write_docx(path: &Path, text: &str) -> Result<()> {
    let file =
        File::create(path).with_context(|| format!("failed to create {}", path.display()))?;
    let mut zip = zip::ZipWriter::new(file);
    let options = SimpleFileOptions::default().compression_method(CompressionMethod::Deflated);

    zip.start_file("[Content_Types].xml", options)?;
    zip.write_all(content_types_xml().as_bytes())?;

    zip.start_file("_rels/.rels", options)?;
    zip.write_all(root_relationships_xml().as_bytes())?;

    zip.start_file("word/document.xml", options)?;
    zip.write_all(document_xml(text).as_bytes())?;

    zip.start_file("word/_rels/document.xml.rels", options)?;
    zip.write_all(document_relationships_xml().as_bytes())?;

    zip.finish()?;
    Ok(())
}

fn content_types_xml() -> &'static str {
    r#"<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>"#
}

fn root_relationships_xml() -> &'static str {
    r#"<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>"#
}

fn document_relationships_xml() -> &'static str {
    r#"<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>"#
}

fn document_xml(text: &str) -> String {
    let mut body = String::new();
    for line in text.lines() {
        body.push_str("<w:p><w:r><w:t xml:space=\"preserve\">");
        body.push_str(&xml_escape(line));
        body.push_str("</w:t></w:r></w:p>");
    }

    format!(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body>{}<w:sectPr/></w:body></w:document>",
        body
    )
}

fn base_html_style() -> &'static str {
    r#"
      :root {
        color-scheme: light dark;
      }
      body {
        font-family: "SF Pro Display", "Avenir Next", "Segoe UI", sans-serif;
        margin: 0;
        padding: 24px;
        background: linear-gradient(180deg, #0f141c 0%, #101823 40%, #0a1119 100%);
        color: #e8edf4;
      }
      .container {
        max-width: 980px;
        margin: 0 auto;
        background: rgba(22, 31, 45, 0.85);
        border: 1px solid rgba(110, 151, 193, 0.24);
        border-radius: 18px;
        padding: 24px;
        box-shadow: 0 24px 60px rgba(0, 0, 0, 0.32);
      }
      h1, h2, h3, h4 {
        margin-top: 0;
      }
      .block {
        background: rgba(6, 10, 16, 0.6);
        border: 1px solid rgba(153, 187, 222, 0.17);
        border-radius: 12px;
        padding: 14px;
        white-space: pre-wrap;
        line-height: 1.5;
      }
      .metadata table {
        width: 100%;
        border-collapse: collapse;
      }
      .metadata th,
      .metadata td {
        text-align: left;
        padding: 8px;
        border-bottom: 1px solid rgba(144, 177, 205, 0.22);
      }
      .item {
        border-top: 1px solid rgba(132, 168, 198, 0.22);
        padding-top: 16px;
        margin-top: 16px;
      }
    "#
}

fn xml_escape(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{BackTranslationResult, ProviderId};
    use std::time::Duration;
    use tempfile::TempDir;

    fn sample_result() -> BackTranslationResult {
        BackTranslationResult::new(
            "Hello world".to_string(),
            "こんにちは世界".to_string(),
            "Hello world".to_string(),
            "en".to_string(),
            "ja".to_string(),
            ProviderId::GoogleUnofficial,
            Duration::from_millis(420),
        )
    }

    #[test]
    fn exports_single_json() {
        let service = ExportService;
        let result = sample_result();
        let temp = TempDir::new().unwrap();
        let output = temp.path().join("result.json");

        service
            .export_single(&result, &output, ExportFormat::Json, true)
            .unwrap();

        let content = std::fs::read_to_string(output).unwrap();
        assert!(content.contains("Hello world"));
        assert!(content.contains("metadata"));
    }

    #[test]
    fn exports_single_docx() {
        let service = ExportService;
        let result = sample_result();
        let temp = TempDir::new().unwrap();
        let output = temp.path().join("result.docx");

        service
            .export_single(&result, &output, ExportFormat::Docx, true)
            .unwrap();

        assert!(output.exists());
        assert!(std::fs::metadata(output).unwrap().len() > 64);
    }
}
