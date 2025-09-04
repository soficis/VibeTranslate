package repositories

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"

	"golang.org/x/net/html"
)

// FileRepositoryImpl implements the FileRepository interface
type FileRepositoryImpl struct {
	logger *utils.Logger
}

// NewFileRepository creates a new file repository
func NewFileRepository() repositories.FileRepository {
	return &FileRepositoryImpl{
		logger: utils.GetLogger(),
	}
}

// LoadFile loads and processes a file
func (r *FileRepositoryImpl) LoadFile(filePath string) (*entities.FileInfo, error) {
	r.logger.Info("Loading file: %s", filePath)

	fileInfo := &entities.FileInfo{
		Path:     filePath,
		Name:     filepath.Base(filePath),
		Type:     entities.GetFileType(filePath),
		LoadTime: time.Now(),
	}

	// Read file content
	content, err := os.ReadFile(filePath)
	if err != nil {
		fileInfo.Error = err
		r.logger.Error("Failed to read file %s: %v", filePath, err)
		return fileInfo, fmt.Errorf("failed to read file: %w", err)
	}

	fileInfo.Size = int64(len(content))
	fileInfo.Content = string(content)

	// Process content based on file type
	switch fileInfo.Type {
	case entities.FileTypeHTML:
		processedContent, err := r.ExtractTextFromHTML(fileInfo.Content)
		if err != nil {
			r.logger.Warn("Failed to extract text from HTML: %v", err)
			// Fall back to raw content
		} else {
			fileInfo.Content = processedContent
			r.logger.Info("Extracted text from HTML: %d -> %d chars", len(string(content)), len(processedContent))
		}
	case entities.FileTypeText, entities.FileTypeMarkdown:
		// For text and markdown, use content as-is but trim whitespace
		fileInfo.Content = strings.TrimSpace(fileInfo.Content)
	default:
		// For unknown types, use content as-is
		fileInfo.Content = strings.TrimSpace(fileInfo.Content)
	}

	r.logger.Info("Successfully loaded file: %s (%s, %d chars)", fileInfo.Name, entities.GetFileTypeName(fileInfo.Type), len(fileInfo.Content))
	return fileInfo, nil
}

// SaveText saves text content to a file
func (r *FileRepositoryImpl) SaveText(content, filePath string) error {
	r.logger.Info("Saving text to file: %s", filePath)

	// Create directory if it doesn't exist
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		r.logger.Error("Failed to create directory %s: %v", dir, err)
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write file
	err := os.WriteFile(filePath, []byte(content), 0644)
	if err != nil {
		r.logger.Error("Failed to write file %s: %v", filePath, err)
		return fmt.Errorf("failed to write file: %w", err)
	}

	r.logger.Info("Successfully saved file: %s (%d chars)", filePath, len(content))
	return nil
}

// ExtractTextFromHTML extracts plain text from HTML content
func (r *FileRepositoryImpl) ExtractTextFromHTML(htmlContent string) (string, error) {
	r.logger.Debug("Extracting text from HTML content (%d chars)", len(htmlContent))

	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		r.logger.Error("Failed to parse HTML: %v", err)
		return "", fmt.Errorf("failed to parse HTML: %w", err)
	}

	var text strings.Builder
	r.extractTextFromNode(doc, &text)

	result := strings.TrimSpace(text.String())

	// Normalize whitespace
	result = r.normalizeWhitespace(result)

	r.logger.Debug("Extracted text: %d -> %d chars", len(htmlContent), len(result))
	return result, nil
}

// extractTextFromNode recursively extracts text from HTML nodes
func (r *FileRepositoryImpl) extractTextFromNode(node *html.Node, text *strings.Builder) {
	// Skip script, style, code, and pre blocks
	if node.Type == html.ElementNode {
		tagName := strings.ToLower(node.Data)
		if tagName == "script" || tagName == "style" || tagName == "code" || tagName == "pre" {
			return
		}
	}

	// Extract text from text nodes
	if node.Type == html.TextNode {
		text.WriteString(node.Data)
		text.WriteString(" ")
	}

	// Recursively process child nodes
	for child := node.FirstChild; child != nil; child = child.NextSibling {
		r.extractTextFromNode(child, text)
	}
}

// normalizeWhitespace normalizes whitespace in extracted text
func (r *FileRepositoryImpl) normalizeWhitespace(text string) string {
	// Remove extra whitespace and normalize line breaks
	re := regexp.MustCompile(`\s+`)
	return re.ReplaceAllString(text, " ")
}
