package repositories

import (
	"translationfiestago/internal/domain/entities"
)

// FileRepository defines the interface for file operations
type FileRepository interface {
	// LoadFile loads and processes a file
	LoadFile(filePath string) (*entities.FileInfo, error)

	// SaveText saves text content to a file
	SaveText(content, filePath string) error

	// ExtractTextFromHTML extracts plain text from HTML content
	ExtractTextFromHTML(htmlContent string) (string, error)
}
