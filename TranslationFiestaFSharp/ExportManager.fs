#nullable enable
#nowarn "3261" // Suppress nullness warnings
/// <summary>
/// This module provides functionality for exporting translation results to various formats,
/// including PDF, DOCX, and HTML. It has been refactored according to Clean Code principles
/// to improve readability, maintainability, and efficiency.
///
/// Key Refactorings:
/// - **Robust Error Handling**: Replaced `failwith` with a `Result<'T, exn>` type for all
///   export operations, allowing for graceful error handling and propagation.
/// - **Clear Structure and Separation of Concerns**:
///     - The `ExportManager` class is now more focused on orchestrating the export process.
///     - Specific export logic for PDF, DOCX, and HTML is encapsulated in private methods.
/// - **Immutability and Functional Idioms**:
///     - The `ExportConfig` is now a record with a builder-style `Create` function and
///       `With...` methods for more readable and composable configuration.
///     - The `CalculateQualityMetrics` function now uses a more functional approach with `List.fold`.
/// - **Dependency Management**: The convenience functions (`exportToPdf`, `exportToDocx`, `exportToHtml`)
///   now accept a `BLEUScorer` instance, promoting dependency injection and avoiding the creation of new instances on each call.
/// - **Meaningful Naming**: Ensured all types, functions, and parameters have clear, descriptive names.
/// - **XML Documentation**: Added comprehensive XML documentation to all public types and members
///   to enhance clarity, discoverability, and ease of use.
/// </summary>
namespace TranslationFiestaFSharp

open System
open System.Collections.Generic
open System.IO
open PdfSharp.Drawing
open PdfSharp.Pdf
open DocumentFormat.OpenXml
open DocumentFormat.OpenXml.Packaging
open DocumentFormat.OpenXml.Wordprocessing
open TranslationFiestaFSharp.BLEUScorer

/// <summary>
/// Represents metadata for an exported document, including title, author, and translation-specific details.
/// </summary>
type ExportMetadata = {
    Title: string
    Author: string
    Subject: string
    Keywords: string list
    CreatedDate: string
    SourceLanguage: string
    TargetLanguage: string
    TranslationQualityScore: float
    ProcessingTimeSeconds: float
    ApiUsed: string
} with
    /// <summary>
    /// Provides default metadata values for an export.
    /// </summary>
    static member Default = {
        Title = "Translation Results"
        Author = "TranslationFiesta"
        Subject = "Translation Results"
        Keywords = ["translation"; "localization"]
        CreatedDate = DateTime.Now.ToString("O")
        SourceLanguage = ""
        TargetLanguage = ""
        TranslationQualityScore = 0.0
        ProcessingTimeSeconds = 0.0
        ApiUsed = ""
    }

/// <summary>
/// Represents the configuration for a document export operation.
/// </summary>
type ExportConfig = {
    Format: string
    TemplatePath: string option
    IncludeMetadata: bool
    IncludeQualityMetrics: bool
    IncludeTimestamps: bool
    PageSize: string
    FontFamily: string
    FontSize: int
    IncludeTableOfContents: bool
    CompressOutput: bool
    CustomCss: string option
} with
    /// <summary>
    /// Creates a default export configuration.
    /// </summary>
    static member Create() = {
        Format = "pdf"
        TemplatePath = None
        IncludeMetadata = true
        IncludeQualityMetrics = true
        IncludeTimestamps = true
        PageSize = "A4"
        FontFamily = "Arial"
        FontSize = 12
        IncludeTableOfContents = false
        CompressOutput = false
        CustomCss = None
    }
    /// <summary>
    /// Sets the output format for the export.
    /// </summary>
    member this.WithFormat(format: string) = { this with Format = format }
    /// <summary>
    /// Sets the path to a template file for the export.
    /// </summary>
    member this.WithTemplate(path: string) = { this with TemplatePath = Some path }
    /// <summary>
    /// Specifies whether to include metadata in the exported document.
    /// </summary>
    member this.WithMetadata(shouldInclude: bool) = { this with IncludeMetadata = shouldInclude }
    /// <summary>
    /// Specifies whether to include quality metrics in the exported document.
    /// </summary>
    member this.WithQualityMetrics(shouldInclude: bool) = { this with IncludeQualityMetrics = shouldInclude }
    /// <summary>
    /// Specifies whether to include timestamps in the exported document.
    /// </summary>
    member this.WithTimestamps(shouldInclude: bool) = { this with IncludeTimestamps = shouldInclude }

/// <summary>
/// Represents a single translation result to be included in an export.
/// </summary>
type TranslationResult = {
    OriginalText: string
    TranslatedText: string
    SourceLanguage: string
    TargetLanguage: string
    QualityScore: float
    ConfidenceLevel: string
    ProcessingTime: float
    ApiUsed: string
    Timestamp: string
} with
    /// <summary>
    /// Creates a new <see cref="TranslationResult"/> with optional parameters for quality metrics.
    /// </summary>
    static member Create(originalText, translatedText, sourceLanguage, targetLanguage,
                        ?qualityScore, ?confidenceLevel, ?processingTime, ?apiUsed) = {
        OriginalText = originalText
        TranslatedText = translatedText
        SourceLanguage = sourceLanguage
        TargetLanguage = targetLanguage
        QualityScore = defaultArg qualityScore 0.0
        ConfidenceLevel = defaultArg confidenceLevel ""
        ProcessingTime = defaultArg processingTime 0.0
        ApiUsed = defaultArg apiUsed ""
        Timestamp = DateTime.Now.ToString("O")
    }

/// <summary>
/// Manages the export of translation results to various document formats.
/// </summary>
/// <param name="config">The <see cref="ExportConfig"/> to use for export operations.</param>
/// <param name="bleuScorer">An instance of <see cref="BLEUScorer"/> for calculating quality metrics.</param>
type ExportManager(config: ExportConfig, bleuScorer: BLEUScorer) =

    let supportedFormats = ["pdf"; "docx"; "html"]

    /// <summary>
    /// Exports a list of translations to a file in the specified format.
    /// </summary>
    /// <param name="translations">A list of <see cref="TranslationResult"/> records to export.</param>
    /// <param name="outputPath">The path where the exported file will be saved.</param>
    /// <param name="metadata">Optional <see cref="ExportMetadata"/> for the document.</param>
    /// <returns>A <see cref="Result{string, exn}"/> containing the output path on success, or an exception on failure.</returns>
    member this.ExportTranslations(translations: TranslationResult list, outputPath: string,
                                  ?metadata: ExportMetadata) : Result<string, exn> =
        try
            let metadata = defaultArg metadata ExportMetadata.Default

            if translations.IsEmpty then
                Error(InvalidOperationException("No translations provided for export"))
            else
                // Create default metadata if needed
                let defaultMetadata = {
                    metadata with
                        Title = if String.IsNullOrEmpty metadata.Title then
                                   sprintf "Translation Results - %d items" translations.Length
                                else metadata.Title
                        SourceLanguage = if String.IsNullOrEmpty metadata.SourceLanguage && not translations.IsEmpty then
                                            translations.Head.SourceLanguage
                                         else metadata.SourceLanguage
                        TargetLanguage = if String.IsNullOrEmpty metadata.TargetLanguage && not translations.IsEmpty then
                                            translations.Head.TargetLanguage
                                         else metadata.TargetLanguage
                }

                // Calculate overall quality metrics
                let finalMetadata, finalTranslations =
                    if config.IncludeQualityMetrics then
                        this.CalculateQualityMetrics(defaultMetadata, translations)
                    else
                        defaultMetadata, translations

                // Export based on format
                match config.Format.ToLower() with
                | "pdf" -> this.ExportToPdf(finalTranslations, outputPath, finalMetadata)
                | "docx" -> this.ExportToDocx(finalTranslations, outputPath, finalMetadata)
                | "html" -> this.ExportToHtml(finalTranslations, outputPath, finalMetadata)
                | format -> Error(NotSupportedException(sprintf "Unsupported export format: %s" format))
        with ex ->
            Error ex

    member private this.CalculateQualityMetrics(metadata: ExportMetadata, translations: TranslationResult list) =
        let processedTranslations, totalScore, totalTime =
            translations
            |> List.fold (fun (accTranslations, accScore, accTime) translation ->
                let finalTranslation, score =
                    if translation.QualityScore = 0.0 && not (String.IsNullOrEmpty translation.OriginalText) &&
                       not (String.IsNullOrEmpty translation.TranslatedText) then
                        // Calculate BLEU score if not already calculated
                        let bleuScore = bleuScorer.CalculateBleu(translation.OriginalText, translation.TranslatedText)
                        let confidence, _ = bleuScorer.GetConfidenceLevel(bleuScore)
                        { translation with
                            QualityScore = bleuScore
                            ConfidenceLevel = confidence }, bleuScore
                    else
                        translation, translation.QualityScore

                finalTranslation :: accTranslations, accScore + score, accTime + translation.ProcessingTime
            ) ([], 0.0, 0.0)

        let avgScore = if translations.Length > 0 then totalScore / float translations.Length else 0.0
        let avgTime = if translations.Length > 0 then totalTime / float translations.Length else 0.0

        let updatedMetadata = {
            metadata with
                TranslationQualityScore = avgScore
                ProcessingTimeSeconds = avgTime
        }

        updatedMetadata, List.rev processedTranslations

    member private this.ExportToPdf(translations: TranslationResult list, outputPath: string,
                                   metadata: ExportMetadata) : Result<string, exn> =
        try
            // Create PDF document
            let document = new PdfDocument()
            document.Info.Title <- metadata.Title
            document.Info.Author <- metadata.Author
            document.Info.Subject <- metadata.Subject
            document.Info.Keywords <- String.Join(", ", metadata.Keywords)

            let page = document.AddPage()
            let gfx = XGraphics.FromPdfPage(page)
            let font = new XFont(config.FontFamily, float config.FontSize, XFontStyleEx.Regular)
            let boldFont = new XFont(config.FontFamily, float config.FontSize, XFontStyleEx.Bold)
            let titleFont = new XFont(config.FontFamily, 18.0, XFontStyleEx.Bold)

            let mutable yPosition = 50.0
            let pageWidth = page.Width.Point - 100.0
            let lineHeight = float font.Height

            // Title
            gfx.DrawString(metadata.Title, titleFont, XBrushes.Black, XRect(50.0, yPosition, pageWidth, 40.0), XStringFormats.TopCenter)
            yPosition <- yPosition + 40.0

            // Metadata
            if config.IncludeMetadata then
                yPosition <- this.DrawMetadataTable(gfx, metadata, yPosition, pageWidth, font, boldFont)
                yPosition <- yPosition + 30.0

            // Translations
            gfx.DrawString("Translation Results", boldFont, XBrushes.Black, 50.0, yPosition)
            yPosition <- yPosition + 25.0

            let mutable currentPage = page
            let mutable currentGfx = gfx

            for i, translation in List.indexed translations do
                // Check if we need a new page
                if yPosition > currentPage.Height.Point - 100.0 then
                    currentPage <- document.AddPage()
                    currentGfx <- XGraphics.FromPdfPage(currentPage)
                    yPosition <- 50.0

                // Translation header
                currentGfx.DrawString(sprintf "Translation %d" (i + 1), boldFont, XBrushes.Black, 50.0, yPosition)
                yPosition <- yPosition + lineHeight + 5.0

                // Original text
                currentGfx.DrawString("Original Text:", boldFont, XBrushes.Black, 50.0, yPosition)
                yPosition <- yPosition + lineHeight
                yPosition <- this.DrawMultilineText(currentGfx, translation.OriginalText, font, 70.0, yPosition, pageWidth - 20.0)

                // Translated text
                yPosition <- yPosition + 10.0
                currentGfx.DrawString("Translated Text:", boldFont, XBrushes.Black, 50.0, yPosition)
                yPosition <- yPosition + lineHeight
                yPosition <- this.DrawMultilineText(currentGfx, translation.TranslatedText, font, 70.0, yPosition, pageWidth - 20.0)

                // Quality metrics
                if config.IncludeQualityMetrics then
                    yPosition <- yPosition + 10.0
                    let qualityText =
                        sprintf "Quality Score: %.3f (%s)" translation.QualityScore translation.ConfidenceLevel
                        + if translation.ProcessingTime > 0.0 then sprintf " | Processing Time: %.2fs" translation.ProcessingTime else ""
                    let smallFont = new XFont(config.FontFamily, float (config.FontSize - 2), XFontStyleEx.Italic)
                    currentGfx.DrawString(qualityText, smallFont, XBrushes.Gray, 50.0, yPosition)
                    yPosition <- yPosition + lineHeight

                yPosition <- yPosition + 20.0

            // Save document
            document.Save(outputPath)
            Ok outputPath
        with ex ->
            Error ex

    member private this.ExportToDocx(translations: TranslationResult list, outputPath: string,
                                     metadata: ExportMetadata) : Result<string, exn> =
        try
            use doc = WordprocessingDocument.Create(outputPath, WordprocessingDocumentType.Document)

            // Create document structure
            let mainPart = doc.AddMainDocumentPart()
            let body = new Body()
            let document = new Document(body)
            mainPart.Document <- document

            // Document properties
            let parsedDate = DateTime.Parse(metadata.CreatedDate)
            // doc.PackageProperties is deprecated. Skipping setting these properties for now.

            // Title
            let j = new Justification()
            j.Val <- JustificationValues.Center
            let titlePara = new Paragraph(new Run(new Text(metadata.Title)), new ParagraphProperties(j))
            body.AppendChild(titlePara) |> ignore

            // Metadata table
            if config.IncludeMetadata then
                this.AddMetadataTable(body, metadata)

            // Translations section
            let resultsPara = new Paragraph(new Run(new Text("Translation Results")))
            body.AppendChild(resultsPara) |> ignore

            for i, translation in List.indexed translations do
                // Translation header
                let headerPara = new Paragraph(new Run(new Text(sprintf "Translation %d" (i + 1))))
                body.AppendChild(headerPara) |> ignore

                // Original text
                let originalPara = new Paragraph(
                    new Run(new RunProperties(new Bold()), new Text("Original Text:")),
                    new Run(new Text(translation.OriginalText))
                )
                body.AppendChild(originalPara) |> ignore

                // Translated text
                let translatedPara = new Paragraph(
                    new Run(new RunProperties(new Bold()), new Text("Translated Text:")),
                    new Run(new Text(translation.TranslatedText))
                )
                body.AppendChild(translatedPara) |> ignore

                // Quality metrics
                if config.IncludeQualityMetrics then
                    let qualityText =
                        sprintf "Quality Score: %.3f (%s)" translation.QualityScore translation.ConfidenceLevel
                        + if translation.ProcessingTime > 0.0 then sprintf " | Processing Time: %.2fs" translation.ProcessingTime else ""
                    let c = new Color()
                    c.Val <- "666666"
                    let qualityPara = new Paragraph(new Run(
                        new RunProperties(new Italic(), c),
                        new Text(qualityText)
                    ))
                    body.AppendChild(qualityPara) |> ignore
                else
                    ()

                // Add spacing
                let spacingPara = new Paragraph()
                body.AppendChild(spacingPara) |> ignore

            mainPart.Document.Save()
            Ok outputPath
        with ex ->
            Error ex

    member private this.ExportToHtml(translations: TranslationResult list, outputPath: string,
                                    metadata: ExportMetadata) : Result<string, exn> =
        try
            let html = System.Text.StringBuilder()

            html.AppendLine("<!DOCTYPE html>") |> ignore
            html.AppendLine("<html lang=\"en\">") |> ignore
            html.AppendLine("<head>") |> ignore
            html.AppendLine("    <meta charset=\"UTF-8\">") |> ignore
            html.AppendLine("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">") |> ignore
            html.AppendLine(sprintf "    <title>%s</title>" metadata.Title) |> ignore
            html.AppendLine("    <style>") |> ignore
            html.AppendLine("        body {") |> ignore
            html.AppendLine(sprintf "            font-family: %s, sans-serif;" config.FontFamily) |> ignore
            html.AppendLine(sprintf "            font-size: %dpx;" config.FontSize) |> ignore
            html.AppendLine("            line-height: 1.6;") |> ignore
            html.AppendLine("            margin: 40px;") |> ignore
            html.AppendLine("            background-color: #f5f5f5;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .container {") |> ignore
            html.AppendLine("            max-width: 800px;") |> ignore
            html.AppendLine("            margin: 0 auto;") |> ignore
            html.AppendLine("            background: white;") |> ignore
            html.AppendLine("            padding: 30px;") |> ignore
            html.AppendLine("            border-radius: 8px;") |> ignore
            html.AppendLine("            box-shadow: 0 2px 10px rgba(0,0,0,0.1);") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        h1 {") |> ignore
            html.AppendLine("            color: #333;") |> ignore
            html.AppendLine("            text-align: center;") |> ignore
            html.AppendLine("            border-bottom: 2px solid #007acc;") |> ignore
            html.AppendLine("            padding-bottom: 10px;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        h2 {") |> ignore
            html.AppendLine("            color: #555;") |> ignore
            html.AppendLine("            margin-top: 30px;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .translation {") |> ignore
            html.AppendLine("            margin-bottom: 30px;") |> ignore
            html.AppendLine("            padding: 20px;") |> ignore
            html.AppendLine("            background: #f9f9f9;") |> ignore
            html.AppendLine("            border-left: 4px solid #007acc;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .original {") |> ignore
            html.AppendLine("            margin-bottom: 15px;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .translated {") |> ignore
            html.AppendLine("            margin-bottom: 15px;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .quality {") |> ignore
            html.AppendLine("            font-style: italic;") |> ignore
            html.AppendLine("            color: #666;") |> ignore
            html.AppendLine("            font-size: 0.9em;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        .metadata {") |> ignore
            html.AppendLine("            background: #e8f4fd;") |> ignore
            html.AppendLine("            padding: 15px;") |> ignore
            html.AppendLine("            border-radius: 5px;") |> ignore
            html.AppendLine("            margin-bottom: 20px;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        table {") |> ignore
            html.AppendLine("            width: 100%;") |> ignore
            html.AppendLine("            border-collapse: collapse;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        th, td {") |> ignore
            html.AppendLine("            padding: 8px 12px;") |> ignore
            html.AppendLine("            text-align: left;") |> ignore
            html.AppendLine("            border-bottom: 1px solid #ddd;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("        th {") |> ignore
            html.AppendLine("            background-color: #007acc;") |> ignore
            html.AppendLine("            color: white;") |> ignore
            html.AppendLine("        }") |> ignore
            html.AppendLine("    </style>") |> ignore

            match config.CustomCss with
            | Some css -> html.AppendLine(css) |> ignore
            | None -> ()

            html.AppendLine("</head>") |> ignore
            html.AppendLine("<body>") |> ignore
            html.AppendLine("    <div class=\"container\">") |> ignore
            html.AppendLine(sprintf "        <h1>%s</h1>" metadata.Title) |> ignore

            // Metadata
            if config.IncludeMetadata then
                html.AppendLine("        <div class=\"metadata\">") |> ignore
                html.AppendLine("            <h2>Document Information</h2>") |> ignore
                html.AppendLine("            <table>") |> ignore
                html.AppendLine(sprintf "                <tr><th>Author</th><td>%s</td></tr>" metadata.Author) |> ignore
                html.AppendLine(sprintf "                <tr><th>Created</th><td>%s</td></tr>" metadata.CreatedDate) |> ignore
                html.AppendLine(sprintf "                <tr><th>Source Language</th><td>%s</td></tr>" metadata.SourceLanguage) |> ignore
                html.AppendLine(sprintf "                <tr><th>Target Language</th><td>%s</td></tr>" metadata.TargetLanguage) |> ignore
                html.AppendLine(sprintf "                <tr><th>Quality Score</th><td>%.3f</td></tr>" metadata.TranslationQualityScore) |> ignore
                html.AppendLine(sprintf "                <tr><th>API Used</th><td>%s</td></tr>" metadata.ApiUsed) |> ignore
                html.AppendLine("            </table>") |> ignore
                html.AppendLine("        </div>") |> ignore

            // Translations
            html.AppendLine("        <h2>Translation Results</h2>") |> ignore

            for i, translation in List.indexed translations do
                let qualityInfo =
                    if config.IncludeQualityMetrics then
                        sprintf "<div class=\"quality\">Quality Score: %.3f (%s)" translation.QualityScore translation.ConfidenceLevel
                        + if translation.ProcessingTime > 0.0 then sprintf " | Processing Time: %.2fs" translation.ProcessingTime else ""
                        + "</div>"
                    else ""

                html.AppendLine("        <div class=\"translation\">") |> ignore
                html.AppendLine(sprintf "            <h3>Translation %d</h3>" (i + 1)) |> ignore
                html.AppendLine("            <div class=\"original\">") |> ignore
                html.AppendLine("                <strong>Original Text:</strong><br>") |> ignore
                html.AppendLine(sprintf "                %s" (translation.OriginalText.Replace("\n", "<br>"))) |> ignore
                html.AppendLine("            </div>") |> ignore
                html.AppendLine("            <div class=\"translated\">") |> ignore
                html.AppendLine("                <strong>Translated Text:</strong><br>") |> ignore
                html.AppendLine(sprintf "                %s" (translation.TranslatedText.Replace("\n", "<br>"))) |> ignore
                html.AppendLine("            </div>") |> ignore
                html.AppendLine(sprintf "            %s" qualityInfo) |> ignore
                html.AppendLine("        </div>") |> ignore

            html.AppendLine("    </div>") |> ignore
            html.AppendLine("</body>") |> ignore
            html.AppendLine("</html>") |> ignore

            File.WriteAllText(outputPath, html.ToString())
            Ok outputPath
        with ex ->
            Error ex

    member private this.DrawMultilineText(gfx: XGraphics, text: string, font: XFont, x: float, y: float, maxWidth: float) : float =
        let lines = this.SplitTextIntoLines(text, font, maxWidth, gfx)
        let mutable currentY = y
        for line in lines do
            gfx.DrawString(line, font, XBrushes.Black, x, currentY)
            currentY <- currentY + float font.Height + 2.0
        currentY

    member private this.SplitTextIntoLines(text: string, font: XFont, maxWidth: float, gfx: XGraphics) : string list =
        let words = text.Split([|' '; '\t'; '\n'|], StringSplitOptions.RemoveEmptyEntries) |> Array.toList
        let rec splitLines (remainingWords: string list) (currentLine: string) (lines: string list) =
            match remainingWords with
            | [] ->
                if not (String.IsNullOrEmpty currentLine) then
                    List.rev (currentLine :: lines)
                else
                    List.rev lines
            | word :: rest ->
                let testLine = if String.IsNullOrEmpty currentLine then word else currentLine + " " + word
                let width = gfx.MeasureString(testLine, font).Width
                if width > maxWidth && not (String.IsNullOrEmpty currentLine) then
                    splitLines (word :: rest) "" (currentLine :: lines)
                else
                    splitLines rest testLine lines

        splitLines words "" []

    member private this.DrawMetadataTable(gfx: XGraphics, metadata: ExportMetadata, y: float, width: float, font: XFont, boldFont: XFont) : float =
        let mutable currentY = y
        let rowHeight = float font.Height + 5.0
        let col1X = 50.0
        let col2X = 200.0

        let drawRow (prop: string) (value: string) =
            gfx.DrawString(prop, boldFont, XBrushes.Black, col1X, currentY)
            gfx.DrawString(value, font, XBrushes.Black, col2X, currentY)
            currentY <- currentY + rowHeight

        drawRow "Author:" metadata.Author
        drawRow "Created:" metadata.CreatedDate
        drawRow "Source Language:" metadata.SourceLanguage
        drawRow "Target Language:" metadata.TargetLanguage
        drawRow "Quality Score:" (sprintf "%.3f" metadata.TranslationQualityScore)
        drawRow "API Used:" metadata.ApiUsed
        currentY

    member private this.AddMetadataTable(body: Body, metadata: ExportMetadata) =
        let table = new Table(
            // Header row
            new TableRow(
                this.CreateTableCell("Property", true),
                this.CreateTableCell("Value", true)
            ),
            // Data rows
            new TableRow(
                this.CreateTableCell("Title", false),
                this.CreateTableCell(metadata.Title, false)
            ),
            new TableRow(
                this.CreateTableCell("Author", false),
                this.CreateTableCell(metadata.Author, false)
            ),
            new TableRow(
                this.CreateTableCell("Created", false),
                this.CreateTableCell(metadata.CreatedDate, false)
            ),
            new TableRow(
                this.CreateTableCell("Source Language", false),
                this.CreateTableCell(metadata.SourceLanguage, false)
            ),
            new TableRow(
                this.CreateTableCell("Target Language", false),
                this.CreateTableCell(metadata.TargetLanguage, false)
            ),
            new TableRow(
                this.CreateTableCell("Quality Score", false),
                this.CreateTableCell(sprintf "%.3f" metadata.TranslationQualityScore, false)
            ),
            new TableRow(
                this.CreateTableCell("API Used", false),
                this.CreateTableCell(metadata.ApiUsed, false)
            ),
            new TableRow(
                this.CreateTableCell("Processing Time", false),
                this.CreateTableCell(sprintf "%.2f" metadata.ProcessingTimeSeconds + "s", false)
            )
        )
        body.AppendChild(table) |> ignore

    member private this.CreateTableCell(text: string, isHeader: bool) =
        let run =
            if isHeader then
                new Run(new RunProperties(new Bold()), new Text(text))
            else
                new Run(new Text(text))
        let paragraph = new Paragraph(run)
        let tableCell = new TableCell(paragraph)
        tableCell

/// <summary>
/// Provides convenience functions for exporting translation results to various formats.
/// </summary>

module ExportManager =

    /// <summary>
    /// Exports a list of translations to a PDF file.
    /// </summary>
    /// <param name="translations">The list of <see cref="TranslationResult"/> records to export.</param>
    /// <param name="outputPath">The path where the PDF file will be saved.</param>
    /// <param name="metadata">Optional <see cref="ExportMetadata"/> for the document.</param>
    /// <param name="config">Optional <see cref="ExportConfig"/> for the export operation.</param>
    /// <param name="bleuScorer">An instance of <see cref="BLEUScorer"/> for quality metrics.</param>
    /// <returns>A <see cref="Result{string, exn}"/> containing the output path on success, or an exception on failure.</returns>
    let exportToPdf (translations: TranslationResult list) (outputPath: string)
                   (metadata: ExportMetadata option) (config: ExportConfig option) (bleuScorer: BLEUScorer) : Result<string, exn> =
        let config = defaultArg config (ExportConfig.Create())
        let config = { config with Format = "pdf" }
        let manager = ExportManager(config, bleuScorer)
        manager.ExportTranslations(translations, outputPath, ?metadata = metadata)

    /// <summary>
    /// Exports a list of translations to a DOCX file.
    /// </summary>
    /// <param name="translations">The list of <see cref="TranslationResult"/> records to export.</param>
    /// <param name="outputPath">The path where the DOCX file will be saved.</param>
    /// <param name="metadata">Optional <see cref="ExportMetadata"/> for the document.</param>
    /// <param name="config">Optional <see cref="ExportConfig"/> for the export operation.</param>
    /// <param name="bleuScorer">An instance of <see cref="BLEUScorer"/> for quality metrics.</param>
    /// <returns>A <see cref="Result{string, exn}"/> containing the output path on success, or an exception on failure.</returns>
    let exportToDocx (translations: TranslationResult list) (outputPath: string)
                    (metadata: ExportMetadata option) (config: ExportConfig option) (bleuScorer: BLEUScorer) : Result<string, exn> =
        let config = defaultArg config (ExportConfig.Create())
        let config = { config with Format = "docx" }
        let manager = ExportManager(config, bleuScorer)
        manager.ExportTranslations(translations, outputPath, ?metadata = metadata)

    /// <summary>
    /// Exports a list of translations to an HTML file.
    /// </summary>
    /// <param name="translations">The list of <see cref="TranslationResult"/> records to export.</param>
    /// <param name="outputPath">The path where the HTML file will be saved.</param>
    /// <param name="metadata">Optional <see cref="ExportMetadata"/> for the document.</param>
    /// <param name="config">Optional <see cref="ExportConfig"/> for the export operation.</param>
    /// <param name="bleuScorer">An instance of <see cref="BLEUScorer"/> for quality metrics.</param>
    /// <returns>A <see cref="Result{string, exn}"/> containing the output path on success, or an exception on failure.</returns>
    let exportToHtml (translations: TranslationResult list) (outputPath: string)
                    (metadata: ExportMetadata option) (config: ExportConfig option) (bleuScorer: BLEUScorer) : Result<string, exn> =
        let config = defaultArg config (ExportConfig.Create())
        let config = { config with Format = "html" }
        let manager = ExportManager(config, bleuScorer)
        manager.ExportTranslations(translations, outputPath, ?metadata = metadata)