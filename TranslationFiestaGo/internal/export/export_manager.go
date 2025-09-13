package export

import (
	"fmt"
	"os"
	"strings"
	"time"
	"translationfiestago/internal/utils"
)

// ExportMetadata contains metadata for exported documents
type ExportMetadata struct {
	Title                   string   `json:"title"`
	Author                  string   `json:"author"`
	Subject                 string   `json:"subject"`
	Keywords                []string `json:"keywords"`
	CreatedDate             string   `json:"created_date"`
	SourceLanguage          string   `json:"source_language"`
	TargetLanguage          string   `json:"target_language"`
	TranslationQualityScore float64  `json:"translation_quality_score"`
	ProcessingTimeSeconds   float64  `json:"processing_time_seconds"`
	ApiUsed                 string   `json:"api_used"`
}

// ExportConfig contains configuration for document export
type ExportConfig struct {
	Format                 string `json:"format"`                    // pdf, docx, html
	TemplatePath           string `json:"template_path"`             // optional template path
	IncludeMetadata        bool   `json:"include_metadata"`          // include metadata in output
	IncludeQualityMetrics  bool   `json:"include_quality_metrics"`   // include quality metrics
	IncludeTimestamps      bool   `json:"include_timestamps"`        // include timestamps
	PageSize               string `json:"page_size"`                 // A4, letter
	FontFamily             string `json:"font_family"`               // font family
	FontSize               int    `json:"font_size"`                 // font size
	IncludeTableOfContents bool   `json:"include_table_of_contents"` // include TOC
	CompressOutput         bool   `json:"compress_output"`           // compress output
	CustomCss              string `json:"custom_css"`                // custom CSS for HTML
}

// TranslationResult represents a translation result for export
type TranslationResult struct {
	OriginalText    string  `json:"original_text"`
	TranslatedText  string  `json:"translated_text"`
	SourceLanguage  string  `json:"source_language"`
	TargetLanguage  string  `json:"target_language"`
	QualityScore    float64 `json:"quality_score"`
	ConfidenceLevel string  `json:"confidence_level"`
	ProcessingTime  float64 `json:"processing_time"`
	ApiUsed         string  `json:"api_used"`
	Timestamp       string  `json:"timestamp"`
}

// ExportManager handles document export operations
type ExportManager struct {
	config     *ExportConfig
	bleuScorer *utils.BLEUScorer
}

// NewExportManager creates a new export manager
func NewExportManager(config *ExportConfig) *ExportManager {
	if config == nil {
		config = &ExportConfig{
			Format:                "html",
			IncludeMetadata:       true,
			IncludeQualityMetrics: true,
			IncludeTimestamps:     true,
			PageSize:              "A4",
			FontFamily:            "Arial",
			FontSize:              12,
		}
	}

	return &ExportManager{
		config:     config,
		bleuScorer: utils.GetBLEUScorer(),
	}
}

// ExportTranslations exports translations to the specified format
func (em *ExportManager) ExportTranslations(translations []TranslationResult, outputPath string, metadata *ExportMetadata) (string, error) {
	if len(translations) == 0 {
		return "", fmt.Errorf("no translations provided for export")
	}

	// Create default metadata if not provided
	if metadata == nil {
		metadata = &ExportMetadata{
			Title:          fmt.Sprintf("Translation Results - %d items", len(translations)),
			Author:         "TranslationFiesta",
			Subject:        "Translation Results",
			Keywords:       []string{"translation", "localization"},
			CreatedDate:    time.Now().Format(time.RFC3339),
			SourceLanguage: translations[0].SourceLanguage,
			TargetLanguage: translations[0].TargetLanguage,
		}
	}

	// Calculate overall quality metrics
	finalMetadata, finalTranslations := em.calculateQualityMetrics(*metadata, translations)

	// Export based on format
	switch strings.ToLower(em.config.Format) {
	case "html":
		return em.exportToHTML(finalTranslations, outputPath, finalMetadata)
	default:
		return "", fmt.Errorf("unsupported export format: %s (supported: html)", em.config.Format)
	}
}

func (em *ExportManager) calculateQualityMetrics(metadata ExportMetadata, translations []TranslationResult) (ExportMetadata, []TranslationResult) {
	totalScore := 0.0
	totalTime := 0.0

	for i := range translations {
		translation := &translations[i]

		// Calculate BLEU score if not already calculated
		if translation.QualityScore == 0.0 && translation.OriginalText != "" && translation.TranslatedText != "" {
			bleuScore := em.bleuScorer.CalculateBLEU(translation.OriginalText, translation.TranslatedText)
			translation.QualityScore = bleuScore
			confidenceLevel, _ := em.bleuScorer.GetConfidenceLevel(bleuScore)
			translation.ConfidenceLevel = confidenceLevel
		}

		totalScore += translation.QualityScore
		totalTime += translation.ProcessingTime
	}

	// Update metadata with averages
	if len(translations) > 0 {
		metadata.TranslationQualityScore = totalScore / float64(len(translations))
		metadata.ProcessingTimeSeconds = totalTime / float64(len(translations))
	}

	return metadata, translations
}

func (em *ExportManager) exportToHTML(translations []TranslationResult, outputPath string, metadata ExportMetadata) (string, error) {
	htmlContent := em.generateHTMLContent(translations, metadata)

	err := os.WriteFile(outputPath, []byte(htmlContent), 0644)
	if err != nil {
		return "", fmt.Errorf("failed to write HTML file: %w", err)
	}

	return outputPath, nil
}

func (em *ExportManager) generateHTMLContent(translations []TranslationResult, metadata ExportMetadata) string {
	var sb strings.Builder

	sb.WriteString("<!DOCTYPE html>\n")
	sb.WriteString("<html lang=\"en\">\n")
	sb.WriteString("<head>\n")
	sb.WriteString("    <meta charset=\"UTF-8\">\n")
	sb.WriteString("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n")
	sb.WriteString(fmt.Sprintf("    <title>%s</title>\n", metadata.Title))
	sb.WriteString("    <style>\n")
	sb.WriteString("        body {\n")
	sb.WriteString(fmt.Sprintf("            font-family: %s, sans-serif;\n", em.config.FontFamily))
	sb.WriteString(fmt.Sprintf("            font-size: %dpx;\n", em.config.FontSize))
	sb.WriteString("            line-height: 1.6;\n")
	sb.WriteString("            margin: 40px;\n")
	sb.WriteString("            background-color: #f5f5f5;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .container {\n")
	sb.WriteString("            max-width: 800px;\n")
	sb.WriteString("            margin: 0 auto;\n")
	sb.WriteString("            background: white;\n")
	sb.WriteString("            padding: 30px;\n")
	sb.WriteString("            border-radius: 8px;\n")
	sb.WriteString("            box-shadow: 0 2px 10px rgba(0,0,0,0.1);\n")
	sb.WriteString("        }\n")
	sb.WriteString("        h1 {\n")
	sb.WriteString("            color: #333;\n")
	sb.WriteString("            text-align: center;\n")
	sb.WriteString("            border-bottom: 2px solid #007acc;\n")
	sb.WriteString("            padding-bottom: 10px;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        h2 {\n")
	sb.WriteString("            color: #555;\n")
	sb.WriteString("            margin-top: 30px;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .translation {\n")
	sb.WriteString("            margin-bottom: 30px;\n")
	sb.WriteString("            padding: 20px;\n")
	sb.WriteString("            background: #f9f9f9;\n")
	sb.WriteString("            border-left: 4px solid #007acc;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .original {\n")
	sb.WriteString("            margin-bottom: 15px;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .translated {\n")
	sb.WriteString("            margin-bottom: 15px;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .quality {\n")
	sb.WriteString("            font-style: italic;\n")
	sb.WriteString("            color: #666;\n")
	sb.WriteString("            font-size: 0.9em;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        .metadata {\n")
	sb.WriteString("            background: #e8f4fd;\n")
	sb.WriteString("            padding: 15px;\n")
	sb.WriteString("            border-radius: 5px;\n")
	sb.WriteString("            margin-bottom: 20px;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        table {\n")
	sb.WriteString("            width: 100%;\n")
	sb.WriteString("            border-collapse: collapse;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        th, td {\n")
	sb.WriteString("            padding: 8px 12px;\n")
	sb.WriteString("            text-align: left;\n")
	sb.WriteString("            border-bottom: 1px solid #ddd;\n")
	sb.WriteString("        }\n")
	sb.WriteString("        th {\n")
	sb.WriteString("            background-color: #007acc;\n")
	sb.WriteString("            color: white;\n")
	sb.WriteString("        }\n")
	sb.WriteString("    </style>\n")

	if em.config.CustomCss != "" {
		sb.WriteString(em.config.CustomCss)
		sb.WriteString("\n")
	}

	sb.WriteString("</head>\n")
	sb.WriteString("<body>\n")
	sb.WriteString("    <div class=\"container\">\n")
	sb.WriteString(fmt.Sprintf("        <h1>%s</h1>\n", metadata.Title))

	// Metadata
	if em.config.IncludeMetadata {
		sb.WriteString("        <div class=\"metadata\">\n")
		sb.WriteString("            <h2>Document Information</h2>\n")
		sb.WriteString("            <table>\n")
		sb.WriteString(fmt.Sprintf("                <tr><th>Author</th><td>%s</td></tr>\n", metadata.Author))
		sb.WriteString(fmt.Sprintf("                <tr><th>Created</th><td>%s</td></tr>\n", metadata.CreatedDate))
		sb.WriteString(fmt.Sprintf("                <tr><th>Source Language</th><td>%s</td></tr>\n", metadata.SourceLanguage))
		sb.WriteString(fmt.Sprintf("                <tr><th>Target Language</th><td>%s</td></tr>\n", metadata.TargetLanguage))
		sb.WriteString(fmt.Sprintf("                <tr><th>Quality Score</th><td>%.3f</td></tr>\n", metadata.TranslationQualityScore))
		sb.WriteString(fmt.Sprintf("                <tr><th>API Used</th><td>%s</td></tr>\n", metadata.ApiUsed))
		sb.WriteString("            </table>\n")
		sb.WriteString("        </div>\n")
	}

	// Translations
	sb.WriteString("        <h2>Translation Results</h2>\n")

	for i, translation := range translations {
		qualityInfo := ""
		if em.config.IncludeQualityMetrics {
			qualityInfo = fmt.Sprintf("<div class=\"quality\">Quality Score: %.3f (%s)", translation.QualityScore, translation.ConfidenceLevel)
			if translation.ProcessingTime > 0 {
				qualityInfo += fmt.Sprintf(" | Processing Time: %.2fs", translation.ProcessingTime)
			}
			qualityInfo += "</div>"
		}

		sb.WriteString("        <div class=\"translation\">\n")
		sb.WriteString(fmt.Sprintf("            <h3>Translation %d</h3>\n", i+1))
		sb.WriteString("            <div class=\"original\">\n")
		sb.WriteString("                <strong>Original Text:</strong><br>\n")
		sb.WriteString(fmt.Sprintf("                %s\n", strings.ReplaceAll(translation.OriginalText, "\n", "<br>")))
		sb.WriteString("            </div>\n")
		sb.WriteString("            <div class=\"translated\">\n")
		sb.WriteString("                <strong>Translated Text:</strong><br>\n")
		sb.WriteString(fmt.Sprintf("                %s\n", strings.ReplaceAll(translation.TranslatedText, "\n", "<br>")))
		sb.WriteString("            </div>\n")
		sb.WriteString(fmt.Sprintf("            %s\n", qualityInfo))
		sb.WriteString("        </div>\n")
	}

	sb.WriteString("    </div>\n")
	sb.WriteString("</body>\n")
	sb.WriteString("</html>")

	return sb.String()
}

// Convenience functions

func ExportToHTML(translations []TranslationResult, outputPath string, metadata *ExportMetadata, config *ExportConfig) (string, error) {
	if config == nil {
		config = &ExportConfig{Format: "html"}
	} else {
		config.Format = "html"
	}
	manager := NewExportManager(config)
	return manager.ExportTranslations(translations, outputPath, metadata)
}
