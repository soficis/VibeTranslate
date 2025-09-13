using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using PdfSharp.Drawing;
using PdfSharp.Pdf;
using PdfSharp.Fonts;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;

namespace TranslationFiesta.WinUI
{

    /// <summary>
    /// PDF Font Resolver for PDFSharp to handle standard PDF fonts
    /// </summary>
    public class PdfFontResolver : IFontResolver
    {
        private static readonly Dictionary<string, string> _fontMappings = new(StringComparer.OrdinalIgnoreCase)
        {
            // Standard PDF fonts
            { "Times-Roman", "Times-Roman" },
            { "Times-Bold", "Times-Bold" },
            { "Times-Italic", "Times-Italic" },
            { "Times-BoldItalic", "Times-BoldItalic" },
            { "Helvetica", "Helvetica" },
            { "Helvetica-Bold", "Helvetica-Bold" },
            { "Helvetica-Oblique", "Helvetica-Oblique" },
            { "Helvetica-BoldOblique", "Helvetica-BoldOblique" },
            { "Courier", "Courier" },
            { "Courier-Bold", "Courier-Bold" },
            { "Courier-Oblique", "Courier-Oblique" },
            { "Courier-BoldOblique", "Courier-BoldOblique" },
            { "Symbol", "Symbol" },
            { "ZapfDingbats", "ZapfDingbats" },

            // Alternative names
            { "Times New Roman", "Times-Roman" },
            { "Times New Roman Bold", "Times-Bold" },
            { "Times New Roman Italic", "Times-Italic" },
            { "Times New Roman Bold Italic", "Times-BoldItalic" },
            { "Arial", "Helvetica" },
            { "Arial Bold", "Helvetica-Bold" },
            { "Arial Italic", "Helvetica-Oblique" },
            { "Arial Bold Italic", "Helvetica-BoldOblique" },
            { "Courier New", "Courier" },
            { "Courier New Bold", "Courier-Bold" },
            { "Courier New Italic", "Courier-Oblique" },
            { "Courier New Bold Italic", "Courier-BoldOblique" }
        };

        public FontResolverInfo ResolveTypeface(string familyName, bool isBold, bool isItalic)
        {
            // Build the font key
            string style = "";
            if (isBold && isItalic)
                style = "BoldItalic";
            else if (isBold)
                style = "Bold";
            else if (isItalic)
                style = "Italic";

            string baseFamily = familyName;
            string fontKey = string.IsNullOrEmpty(style) ? baseFamily : $"{baseFamily} {style}";
            string altFontKey = string.IsNullOrEmpty(style) ? baseFamily : $"{baseFamily}-{style}";

            // Try exact match first
            if (_fontMappings.TryGetValue(fontKey, out string? mappedFont))
            {
                return new FontResolverInfo(mappedFont);
            }

            // Try alternative format
            if (_fontMappings.TryGetValue(altFontKey, out mappedFont))
            {
                return new FontResolverInfo(mappedFont);
            }

            // Try base family name
            if (_fontMappings.TryGetValue(baseFamily, out mappedFont))
            {
                return new FontResolverInfo(mappedFont);
            }

            // Default to Times-Roman as ultimate fallback
            return new FontResolverInfo("Times-Roman");
        }

        public byte[] GetFont(string faceName)
        {
            // PDFSharp handles the actual font data for standard PDF fonts
            // We just need to indicate that the font is available
            return Array.Empty<byte>();
        }
    }

    /// <summary>
    /// Metadata for exported documents
    /// </summary>
    public class ExportMetadata
    {
        public string Title { get; set; } = "Translation Results";
        public string Author { get; set; } = "TranslationFiesta";
        public string Subject { get; set; } = "Translation Results";
        public List<string> Keywords { get; set; } = new() { "translation", "localization" };
        public string CreatedDate { get; set; } = DateTime.Now.ToString("O");
        public string SourceLanguage { get; set; } = "";
        public string TargetLanguage { get; set; } = "";
        public double TranslationQualityScore { get; set; } = 0.0;
        public double ProcessingTimeSeconds { get; set; } = 0.0;
        public string ApiUsed { get; set; } = "";
    }

    /// <summary>
    /// Configuration for document export
    /// </summary>
    public class ExportConfig
    {
        public string Format { get; set; } = "pdf"; // pdf, docx, html
        public string? TemplatePath { get; set; }
        public bool IncludeMetadata { get; set; } = true;
        public bool IncludeQualityMetrics { get; set; } = true;
        public bool IncludeTimestamps { get; set; } = true;
        public string PageSize { get; set; } = "A4"; // A4, letter
        public string FontFamily { get; set; } = "Arial";
        public int FontSize { get; set; } = 12;
        public bool IncludeTableOfContents { get; set; } = false;
        public bool CompressOutput { get; set; } = false;
        public string? CustomCss { get; set; }
    }

    /// <summary>
    /// Represents a translation result for export
    /// </summary>
    public class TranslationResult
    {
        public string OriginalText { get; set; } = "";
        public string TranslatedText { get; set; } = "";
        public string SourceLanguage { get; set; } = "";
        public string TargetLanguage { get; set; } = "";
        public double QualityScore { get; set; } = 0.0;
        public string ConfidenceLevel { get; set; } = "";
        public double ProcessingTime { get; set; } = 0.0;
        public string ApiUsed { get; set; } = "";
        public string Timestamp { get; set; } = DateTime.Now.ToString("O");

        public TranslationResult() { }

        public TranslationResult(
            string originalText,
            string translatedText,
            string sourceLanguage,
            string targetLanguage,
            double qualityScore = 0.0,
            string confidenceLevel = "",
            double processingTime = 0.0,
            string apiUsed = "")
        {
            OriginalText = originalText;
            TranslatedText = translatedText;
            SourceLanguage = sourceLanguage;
            TargetLanguage = targetLanguage;
            QualityScore = qualityScore;
            ConfidenceLevel = confidenceLevel;
            ProcessingTime = processingTime;
            ApiUsed = apiUsed;
        }
    }

    /// <summary>
    /// Main export manager for TranslationFiesta
    /// </summary>
    public class ExportManager
    {
        private readonly ExportConfig _config;
        private static readonly string[] SupportedFormats = { "pdf", "docx", "html" };

        public ExportManager(ExportConfig? config = null)
        {
            _config = config ?? new ExportConfig();
            ValidateDependencies();
        }

        private void ValidateDependencies()
        {
            // Dependencies are validated at runtime when methods are called
        }

        /// <summary>
        /// Export translations to the specified format
        /// </summary>
        public string ExportTranslations(
            List<TranslationResult> translations,
            string outputPath,
            ExportMetadata? metadata = null,
            TranslationTemplate? template = null)
        {
            if (translations == null || translations.Count == 0)
                throw new ArgumentException("No translations provided for export");

            // Create default metadata if not provided
            metadata ??= new ExportMetadata
            {
                Title = $"Translation Results - {translations.Count} items",
                SourceLanguage = translations.FirstOrDefault()?.SourceLanguage ?? "",
                TargetLanguage = translations.FirstOrDefault()?.TargetLanguage ?? "",
            };

            // Export based on format
            return _config.Format.ToLower() switch
            {
                "pdf" => ExportToPdf(translations, outputPath, metadata, template),
                "docx" => ExportToDocx(translations, outputPath, metadata, template),
                "html" => ExportToHtml(translations, outputPath, metadata),
                _ => throw new ArgumentException($"Unsupported export format: {_config.Format}")
            };
        }

        private string ExportToPdf(List<TranslationResult> translations, string outputPath, ExportMetadata metadata, TranslationTemplate? template)
        {
            // Validate input parameters
            if (translations == null)
            {
                throw new ArgumentNullException(nameof(translations), "Translations list cannot be null");
            }

            if (string.IsNullOrWhiteSpace(outputPath))
            {
                throw new ArgumentException("Output path cannot be null or empty", nameof(outputPath));
            }

            if (metadata == null)
            {
                metadata = new ExportMetadata();
            }

            // Handle empty translations list
            if (translations.Count == 0)
            {
                // Create a minimal PDF with just metadata
                var emptyDocument = new PdfDocument();
                emptyDocument.Info.Title = metadata.Title ?? "Empty Translation Results";
                emptyDocument.Info.Author = metadata.Author ?? "TranslationFiesta";
                emptyDocument.Info.Subject = metadata.Subject ?? "No translations to export";

                var emptyPage = emptyDocument.AddPage();
                var emptyGfx = XGraphics.FromPdfPage(emptyPage);

                // Use safe font creation
                XFont emptyTitleFont;
                try
                {
                    emptyTitleFont = new XFont("Times-Bold", 18, XFontStyleEx.Bold);
                }
                catch
                {
                    emptyTitleFont = new XFont("Helvetica-Bold", 18, XFontStyleEx.Bold);
                }

                emptyGfx.DrawString("No Translation Results to Export", emptyTitleFont, XBrushes.Black, new XPoint(50, 100));
                emptyDocument.Save(outputPath);
                return outputPath;
            }

            // Initialize PDF font resolver for standard PDF fonts
            if (GlobalFontSettings.FontResolver == null)
            {
                GlobalFontSettings.FontResolver = new PdfFontResolver();
            }

            // Create PDF document
            var document = new PdfDocument();
            document.Info.Title = metadata.Title;
            document.Info.Author = metadata.Author;
            document.Info.Subject = metadata.Subject;
            document.Info.Keywords = string.Join(", ", metadata.Keywords);

            var page = document.AddPage();
            var gfx = XGraphics.FromPdfPage(page);

            // Use PDF standard fonts that are guaranteed to work
            XFont font = new XFont("Times-Roman", _config.FontSize, XFontStyleEx.Regular);
            XFont boldFont = new XFont("Times-Bold", _config.FontSize, XFontStyleEx.Bold);
            XFont titleFont = new XFont("Times-Bold", 18, XFontStyleEx.Bold);
            XFont smallFont = new XFont("Times-Italic", _config.FontSize - 2, XFontStyleEx.Regular);

            double yPosition = 50;
            double pageWidth = page.Width - 100;
            double lineHeight = _config.FontSize + 5;

            // Title
            gfx.DrawString(metadata.Title, titleFont, XBrushes.Black, new XPoint(50, yPosition));
            yPosition += 40;

            // Metadata
            if (_config.IncludeMetadata)
            {
                yPosition = DrawMetadataTable(gfx, metadata, yPosition, pageWidth, font, boldFont);
                yPosition += 30;
            }

            // Translations
            gfx.DrawString("Translation Results", boldFont, XBrushes.Black, new XPoint(50, yPosition));
            yPosition += 25;

            for (int i = 0; i < translations.Count; i++)
            {
                var translation = translations[i];

                // Check if we need a new page
                if (yPosition > page.Height - 100)
                {
                    page = document.AddPage();
                    gfx = XGraphics.FromPdfPage(page);
                    yPosition = 50;
                }

                // Translation header
                gfx.DrawString($"Translation {i + 1}", boldFont, XBrushes.Black, new XPoint(50, yPosition));
                yPosition += lineHeight + 5;

                // Original text
                gfx.DrawString("Original Text:", boldFont, XBrushes.Black, new XPoint(50, yPosition));
                yPosition += lineHeight;
                if (template != null)
                {
                    var templateManager = new TemplateManager();
                    var content = templateManager.ApplyTemplate(translation.OriginalText, translation.TranslatedText, translation.SourceLanguage, translation.TargetLanguage, translation.QualityScore, null, template);
                    yPosition = DrawMultilineText(gfx, content, font, 70, yPosition, pageWidth - 20);
                }
                else
                {
                    yPosition = DrawMultilineText(gfx, translation.OriginalText, font, 70, yPosition, pageWidth - 20);

                    // Translated text
                    yPosition += 10;
                    gfx.DrawString("Translated Text:", boldFont, XBrushes.Black, new XPoint(50, yPosition));
                    yPosition += lineHeight;
                    yPosition = DrawMultilineText(gfx, translation.TranslatedText, font, 70, yPosition, pageWidth - 20);
                }

                // Quality metrics
                if (_config.IncludeQualityMetrics)
                {
                    yPosition += 10;
                    string qualityText = $"Quality Score: {translation.QualityScore:F3} ({translation.ConfidenceLevel})";
                    if (translation.ProcessingTime > 0)
                        qualityText += $" | Processing Time: {translation.ProcessingTime:F2}s";

                    // smallFont is now created above with the same fallback logic
                    gfx.DrawString(qualityText, smallFont, XBrushes.Gray, new XPoint(50, yPosition));
                    yPosition += lineHeight;
                }

                yPosition += 20;
            }

            // Save document
            document.Save(outputPath);
            return outputPath;
        }

        private string ExportToDocx(List<TranslationResult> translations, string outputPath, ExportMetadata metadata, TranslationTemplate? template)
        {
            using var doc = WordprocessingDocument.Create(outputPath, WordprocessingDocumentType.Document);

            // Create document structure
            var mainPart = doc.AddMainDocumentPart();
            mainPart.Document = new Document();
            var body = mainPart.Document.AppendChild(new Body());

            // Document properties
            var docProps = doc.PackageProperties;
            docProps.Title = metadata.Title;
            docProps.Creator = metadata.Author;
            docProps.Subject = metadata.Subject;
            docProps.Keywords = string.Join(", ", metadata.Keywords);
            docProps.Created = DateTime.Parse(metadata.CreatedDate);

            // Title
            var titleParagraph = body.AppendChild(new Paragraph());
            var titleRun = titleParagraph.AppendChild(new Run());
            titleRun.AppendChild(new Text(metadata.Title));
            var titleProps = titleParagraph.AppendChild(new ParagraphProperties());
            titleProps.AppendChild(new Justification() { Val = JustificationValues.Center });

            // Metadata table
            if (_config.IncludeMetadata)
            {
                AddMetadataTable(body, metadata);
            }

            // Translations section
            var headingParagraph = body.AppendChild(new Paragraph());
            var headingRun = headingParagraph.AppendChild(new Run());
            headingRun.AppendChild(new Text("Translation Results"));

            foreach (var (translation, index) in translations.Select((t, i) => (t, i)))
            {
                // Translation header
                var transHeader = body.AppendChild(new Paragraph());
                var transRun = transHeader.AppendChild(new Run());
                transRun.AppendChild(new Text($"Translation {index + 1}"));

                // Original text
                var origPara = body.AppendChild(new Paragraph());
                if (template != null)
                {
                    var templateManager = new TemplateManager();
                    var content = templateManager.ApplyTemplate(translation.OriginalText, translation.TranslatedText, translation.SourceLanguage, translation.TargetLanguage, translation.QualityScore, null, template);
                    var contentPara = body.AppendChild(new Paragraph());
                    var contentRun = contentPara.AppendChild(new Run());
                    contentRun.AppendChild(new Text(content));
                }
                else
                {
                    var origRun = origPara.AppendChild(new Run());
                    origRun.AppendChild(new RunProperties(new Bold()));
                    origRun.AppendChild(new Text("Original Text:"));
                    origRun = origPara.AppendChild(new Run());
                    origRun.AppendChild(new Text(translation.OriginalText));

                    // Translated text
                    var transPara = body.AppendChild(new Paragraph());
                    transRun = transPara.AppendChild(new Run());
                    transRun.AppendChild(new RunProperties(new Bold()));
                    transRun.AppendChild(new Text("Translated Text:"));
                    transRun = transPara.AppendChild(new Run());
                    transRun.AppendChild(new Text(translation.TranslatedText));
                }

                // Quality metrics
                if (_config.IncludeQualityMetrics)
                {
                    var qualityPara = body.AppendChild(new Paragraph());
                    var qualityRun = qualityPara.AppendChild(new Run());
                    qualityRun.AppendChild(new RunProperties(new Italic(), new DocumentFormat.OpenXml.Wordprocessing.Color() { Val = "666666" }));

                    string qualityText = $"Quality Score: {translation.QualityScore:F3} ({translation.ConfidenceLevel})";
                    if (translation.ProcessingTime > 0)
                        qualityText += $" | Processing Time: {translation.ProcessingTime:F2}s";

                    qualityRun.AppendChild(new Text(qualityText));
                }

                // Add spacing
                body.AppendChild(new Paragraph());
            }

            mainPart.Document.Save();
            return outputPath;
        }

        private string ExportToHtml(List<TranslationResult> translations, string outputPath, ExportMetadata metadata)
        {
            var html = new System.Text.StringBuilder();

            html.AppendLine("<!DOCTYPE html>");
            html.AppendLine("<html lang=\"en\">");
            html.AppendLine("<head>");
            html.AppendLine("    <meta charset=\"UTF-8\">");
            html.AppendLine("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">");
            html.AppendLine($"    <title>{metadata.Title}</title>");
            html.AppendLine("    <style>");
            html.AppendLine("        body {");
            html.AppendLine($"            font-family: {_config.FontFamily}, sans-serif;");
            html.AppendLine($"            font-size: {_config.FontSize}px;");
            html.AppendLine("            line-height: 1.6;");
            html.AppendLine("            margin: 40px;");
            html.AppendLine("            background-color: #f5f5f5;");
            html.AppendLine("        }");
            html.AppendLine("        .container {");
            html.AppendLine("            max-width: 800px;");
            html.AppendLine("            margin: 0 auto;");
            html.AppendLine("            background: white;");
            html.AppendLine("            padding: 30px;");
            html.AppendLine("            border-radius: 8px;");
            html.AppendLine("            box-shadow: 0 2px 10px rgba(0,0,0,0.1);");
            html.AppendLine("        }");
            html.AppendLine("        h1 {");
            html.AppendLine("            color: #333;");
            html.AppendLine("            text-align: center;");
            html.AppendLine("            border-bottom: 2px solid #007acc;");
            html.AppendLine("            padding-bottom: 10px;");
            html.AppendLine("        }");
            html.AppendLine("        h2 {");
            html.AppendLine("            color: #555;");
            html.AppendLine("            margin-top: 30px;");
            html.AppendLine("        }");
            html.AppendLine("        .translation {");
            html.AppendLine("            margin-bottom: 30px;");
            html.AppendLine("            padding: 20px;");
            html.AppendLine("            background: #f9f9f9;");
            html.AppendLine("            border-left: 4px solid #007acc;");
            html.AppendLine("        }");
            html.AppendLine("        .original {");
            html.AppendLine("            margin-bottom: 15px;");
            html.AppendLine("        }");
            html.AppendLine("        .translated {");
            html.AppendLine("            margin-bottom: 15px;");
            html.AppendLine("        }");
            html.AppendLine("        .quality {");
            html.AppendLine("            font-style: italic;");
            html.AppendLine("            color: #666;");
            html.AppendLine("            font-size: 0.9em;");
            html.AppendLine("        }");
            html.AppendLine("        .metadata {");
            html.AppendLine("            background: #e8f4fd;");
            html.AppendLine("            padding: 15px;");
            html.AppendLine("            border-radius: 5px;");
            html.AppendLine("            margin-bottom: 20px;");
            html.AppendLine("        }");
            html.AppendLine("        table {");
            html.AppendLine("            width: 100%;");
            html.AppendLine("            border-collapse: collapse;");
            html.AppendLine("        }");
            html.AppendLine("        th, td {");
            html.AppendLine("            padding: 8px 12px;");
            html.AppendLine("            text-align: left;");
            html.AppendLine("            border-bottom: 1px solid #ddd;");
            html.AppendLine("        }");
            html.AppendLine("        th {");
            html.AppendLine("            background-color: #007acc;");
            html.AppendLine("            color: white;");
            html.AppendLine("        }");
            html.AppendLine("    </style>");

            if (!string.IsNullOrEmpty(_config.CustomCss))
            {
                html.AppendLine(_config.CustomCss);
            }

            html.AppendLine("</head>");
            html.AppendLine("<body>");
            html.AppendLine("    <div class=\"container\">");
            html.AppendLine($"        <h1>{metadata.Title}</h1>");

            // Metadata
            if (_config.IncludeMetadata)
            {
                html.AppendLine("        <div class=\"metadata\">");
                html.AppendLine("            <h2>Document Information</h2>");
                html.AppendLine("            <table>");
                html.AppendLine($"                <tr><th>Author</th><td>{metadata.Author}</td></tr>");
                html.AppendLine($"                <tr><th>Created</th><td>{metadata.CreatedDate}</td></tr>");
                html.AppendLine($"                <tr><th>Source Language</th><td>{metadata.SourceLanguage}</td></tr>");
                html.AppendLine($"                <tr><th>Target Language</th><td>{metadata.TargetLanguage}</td></tr>");
                html.AppendLine($"                <tr><th>Quality Score</th><td>{metadata.TranslationQualityScore:F3}</td></tr>");
                html.AppendLine($"                <tr><th>API Used</th><td>{metadata.ApiUsed}</td></tr>");
                html.AppendLine("            </table>");
                html.AppendLine("        </div>");
            }

            // Translations
            html.AppendLine("        <h2>Translation Results</h2>");

            foreach (var (translation, index) in translations.Select((t, i) => (t, i)))
            {
                string qualityInfo = "";
                if (_config.IncludeQualityMetrics)
                {
                    qualityInfo = $"<div class=\"quality\">Quality Score: {translation.QualityScore:F3} ({translation.ConfidenceLevel})";
                    if (translation.ProcessingTime > 0)
                        qualityInfo += $" | Processing Time: {translation.ProcessingTime:F2}s";
                    qualityInfo += "</div>";
                }

                html.AppendLine("        <div class=\"translation\">");
                html.AppendLine($"            <h3>Translation {index + 1}</h3>");
                html.AppendLine("            <div class=\"original\">");
                html.AppendLine("                <strong>Original Text:</strong><br>");
                html.AppendLine($"                {translation.OriginalText.Replace("\n", "<br>")}");
                html.AppendLine("            </div>");
                html.AppendLine("            <div class=\"translated\">");
                html.AppendLine("                <strong>Translated Text:</strong><br>");
                html.AppendLine($"                {translation.TranslatedText.Replace("\n", "<br>")}");
                html.AppendLine("            </div>");
                html.AppendLine($"            {qualityInfo}");
                html.AppendLine("        </div>");
            }

            html.AppendLine("    </div>");
            html.AppendLine("</body>");
            html.AppendLine("</html>");

            File.WriteAllText(outputPath, html.ToString());
            return outputPath;
        }

        private double DrawMultilineText(XGraphics gfx, string text, XFont font, double x, double y, double maxWidth)
        {
            var lines = SplitTextIntoLines(text, font, maxWidth, gfx);
            foreach (var line in lines)
            {
                gfx.DrawString(line, font, XBrushes.Black, new XPoint(x, y));
                y += font.Height + 2;
            }
            return y;
        }

        private List<string> SplitTextIntoLines(string text, XFont font, double maxWidth, XGraphics gfx)
        {
            var lines = new List<string>();

            // Handle null or empty text
            if (string.IsNullOrWhiteSpace(text))
            {
                lines.Add("");
                return lines;
            }

            // Split text into words, handling potential null characters
            var words = text.Split(new[] { ' ', '\t', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);

            // Handle empty word array
            if (words.Length == 0)
            {
                lines.Add("");
                return lines;
            }

            var currentLine = "";

            foreach (var word in words)
            {
                // Skip null or empty words (safety check)
                if (string.IsNullOrWhiteSpace(word))
                    continue;

                var testLine = string.IsNullOrEmpty(currentLine) ? word : currentLine + " " + word;
                var width = gfx.MeasureString(testLine, font).Width;

                if (width > maxWidth && !string.IsNullOrEmpty(currentLine))
                {
                    lines.Add(currentLine);
                    currentLine = word;
                }
                else
                {
                    currentLine = testLine;
                }
            }

            // Add remaining line if not empty
            if (!string.IsNullOrEmpty(currentLine))
                lines.Add(currentLine);

            // Ensure we have at least one line
            if (lines.Count == 0)
                lines.Add("");

            return lines;
        }

        private double DrawMetadataTable(XGraphics gfx, ExportMetadata metadata, double y, double pageWidth, XFont font, XFont boldFont)
        {
            // Safely build table data with null checks
            var tableRows = new List<string[]>
            {
                new[] { "Property", "Value" },
                new[] { "Title", metadata.Title ?? "N/A" },
                new[] { "Author", metadata.Author ?? "N/A" },
                new[] { "Created", metadata.CreatedDate ?? "N/A" },
                new[] { "Source Language", metadata.SourceLanguage ?? "N/A" },
                new[] { "Target Language", metadata.TargetLanguage ?? "N/A" },
                new[] { "Quality Score", metadata.TranslationQualityScore.ToString("F3") },
                new[] { "API Used", metadata.ApiUsed ?? "N/A" },
                new[] { "Processing Time", metadata.ProcessingTimeSeconds.ToString("F2") + "s" }
            };

            // Convert to array for processing
            var tableData = tableRows.ToArray();

            double rowHeight = font.Height + 8;
            double currentY = y;

            for (int i = 0; i < tableData.Length; i++)
            {
                var row = tableData[i];
                var isHeader = i == 0;

                // Bounds check to prevent array access errors
                if (row == null || row.Length < 2)
                    continue;

                // Draw background
                var brush = isHeader ? XBrushes.Gray : XBrushes.LightGray;
                gfx.DrawRectangle(brush, 50, currentY - font.Height + 2, pageWidth, rowHeight);

                // Draw text
                var textFont = isHeader ? boldFont : font;
                var textBrush = isHeader ? XBrushes.White : XBrushes.Black;

                // Safe array access with bounds checking
                string propertyText = row.Length > 0 ? row[0] ?? "N/A" : "N/A";
                string valueText = row.Length > 1 ? row[1] ?? "N/A" : "N/A";

                gfx.DrawString(propertyText, textFont, textBrush, new XPoint(60, currentY));
                gfx.DrawString(valueText, textFont, textBrush, new XPoint(200, currentY));

                currentY += rowHeight;
            }

            return currentY;
        }

        private void AddMetadataTable(Body body, ExportMetadata metadata)
        {
            var table = body.AppendChild(new Table());

            // Header row
            var headerRow = table.AppendChild(new TableRow());
            AddTableCell(headerRow, "Property", true);
            AddTableCell(headerRow, "Value", true);

            // Data rows
            AddTableRow(table, "Title", metadata.Title);
            AddTableRow(table, "Author", metadata.Author);
            AddTableRow(table, "Created", metadata.CreatedDate);
            AddTableRow(table, "Source Language", metadata.SourceLanguage);
            AddTableRow(table, "Target Language", metadata.TargetLanguage);
            AddTableRow(table, "Quality Score", metadata.TranslationQualityScore.ToString("F3"));
            AddTableRow(table, "API Used", metadata.ApiUsed);
            AddTableRow(table, "Processing Time", metadata.ProcessingTimeSeconds.ToString("F2") + "s");
        }

        private void AddTableRow(Table table, string property, string value)
        {
            var row = table.AppendChild(new TableRow());
            AddTableCell(row, property, false);
            AddTableCell(row, value, false);
        }

        private void AddTableCell(TableRow row, string text, bool isHeader)
        {
            var cell = row.AppendChild(new TableCell());
            var para = cell.AppendChild(new Paragraph());
            var run = para.AppendChild(new Run());

            if (isHeader)
            {
                run.AppendChild(new RunProperties(new Bold()));
            }

            run.AppendChild(new Text(text));
        }

        /// <summary>
        /// Convenience method to export to PDF
        /// </summary>
        public static string ExportToPdf(
            List<TranslationResult> translations,
            string outputPath,
            ExportMetadata? metadata = null,
            ExportConfig? config = null,
            TranslationTemplate? template = null)
        {
            config ??= new ExportConfig { Format = "pdf" };
            config.Format = "pdf";
            var manager = new ExportManager(config);
            return manager.ExportTranslations(translations, outputPath, metadata, template);
        }


        /// <summary>
        /// Test PDF generation with custom font resolver
        /// </summary>
        public static bool TestPdfGeneration(string testOutputPath = "test_pdf.pdf")
        {
            try
            {
                // Initialize PDF font resolver
                if (GlobalFontSettings.FontResolver == null)
                {
                    GlobalFontSettings.FontResolver = new PdfFontResolver();
                }

                // Create a simple PDF document
                var document = new PdfDocument();
                document.Info.Title = "PDF Test";
                document.Info.Author = "TranslationFiesta";

                var page = document.AddPage();
                var gfx = XGraphics.FromPdfPage(page);

                // Test different font styles to ensure resolver works
                var regularFont = new XFont("Arial", 12, XFontStyleEx.Regular);
                var boldFont = new XFont("Arial", 14, XFontStyleEx.Bold);
                var italicFont = new XFont("Arial", 12, XFontStyleEx.Italic);

                double yPosition = 50;

                // Draw test content with different font styles
                gfx.DrawString("PDF Generation Test - Arial Fonts", boldFont, XBrushes.Black, new XPoint(50, yPosition));
                yPosition += 30;

                gfx.DrawString("Regular Arial Font", regularFont, XBrushes.Black, new XPoint(50, yPosition));
                yPosition += 20;

                gfx.DrawString("Italic Arial Font", italicFont, XBrushes.Black, new XPoint(50, yPosition));
                yPosition += 20;

                gfx.DrawString("PDF generation with custom font resolver is working!", regularFont, XBrushes.Black, new XPoint(50, yPosition));

                // Save the document
                document.Save(testOutputPath);

                // Verify file was created and has reasonable size
                if (File.Exists(testOutputPath))
                {
                    var fileInfo = new FileInfo(testOutputPath);
                    Console.WriteLine($"✅ PDF created successfully: {testOutputPath}");
                    Console.WriteLine($"📊 File size: {fileInfo.Length} bytes");
                    return fileInfo.Length > 1000; // Should be at least 1KB for a valid PDF
                }

                Console.WriteLine("❌ PDF file was not created");
                return false;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"❌ PDF generation failed: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return false;
            }
        }

        /// <summary>
        /// Convenience method to export to DOCX
        /// </summary>
        public static string ExportToDocx(
            List<TranslationResult> translations,
            string outputPath,
            ExportMetadata? metadata = null,
            ExportConfig? config = null,
            TranslationTemplate? template = null)
        {
            config ??= new ExportConfig { Format = "docx" };
            config.Format = "docx";
            var manager = new ExportManager(config);
            return manager.ExportTranslations(translations, outputPath, metadata, template);
        }

        /// <summary>
        /// Convenience method to export to HTML
        /// </summary>
        public static string ExportToHtml(
            List<TranslationResult> translations,
            string outputPath,
            ExportMetadata? metadata = null,
            ExportConfig? config = null)
        {
            config ??= new ExportConfig { Format = "html" };
            config.Format = "html";
            var manager = new ExportManager(config);
            return manager.ExportTranslations(translations, outputPath, metadata);
        }
    }
}