package usecases

import (
	"fmt"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/repositories"
)

// FileUseCases contains the business logic for file operations
type FileUseCases struct {
	fileRepo repositories.FileRepository
}

// NewFileUseCases creates a new instance of FileUseCases
func NewFileUseCases(fileRepo repositories.FileRepository) *FileUseCases {
	return &FileUseCases{
		fileRepo: fileRepo,
	}
}

// LoadFile loads and processes a file
func (uc *FileUseCases) LoadFile(filePath string) (*entities.FileInfo, error) {
	if filePath == "" {
		return nil, fmt.Errorf("file path cannot be empty")
	}

	fileInfo, err := uc.fileRepo.LoadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to load file: %w", err)
	}

	return fileInfo, nil
}

// SaveText saves text content to a file
func (uc *FileUseCases) SaveText(content, filePath string) error {
	if filePath == "" {
		return fmt.Errorf("file path cannot be empty")
	}

	if content == "" {
		return fmt.Errorf("content cannot be empty")
	}

	err := uc.fileRepo.SaveText(content, filePath)
	if err != nil {
		return fmt.Errorf("failed to save file: %w", err)
	}

	return nil
}

// ExtractTextFromHTML extracts plain text from HTML
func (uc *FileUseCases) ExtractTextFromHTML(htmlContent string) (string, error) {
	if htmlContent == "" {
		return "", fmt.Errorf("HTML content cannot be empty")
	}

	text, err := uc.fileRepo.ExtractTextFromHTML(htmlContent)
	if err != nil {
		return "", fmt.Errorf("failed to extract text from HTML: %w", err)
	}

	return text, nil
}
