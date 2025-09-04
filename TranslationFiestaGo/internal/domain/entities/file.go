package entities

import (
	"path/filepath"
	"strings"
	"time"
)

// FileType represents supported file types
type FileType int

const (
	FileTypeText FileType = iota
	FileTypeMarkdown
	FileTypeHTML
	FileTypeUnknown
)

// FileInfo represents information about a loaded file
type FileInfo struct {
	Path     string
	Name     string
	Type     FileType
	Size     int64
	Content  string
	LoadTime time.Time
	Error    error
}

// GetFileType determines the file type based on extension
func GetFileType(filename string) FileType {
	ext := strings.ToLower(filepath.Ext(filename))

	switch ext {
	case ".txt":
		return FileTypeText
	case ".md", ".markdown":
		return FileTypeMarkdown
	case ".html", ".htm":
		return FileTypeHTML
	default:
		return FileTypeUnknown
	}
}

// GetFileTypeName returns a display name for the file type
func GetFileTypeName(fileType FileType) string {
	switch fileType {
	case FileTypeText:
		return "Text"
	case FileTypeMarkdown:
		return "Markdown"
	case FileTypeHTML:
		return "HTML"
	default:
		return "Unknown"
	}
}
