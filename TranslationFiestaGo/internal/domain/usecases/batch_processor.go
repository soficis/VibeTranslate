package usecases

import (
	"context"
	"fmt"
	"io/fs"
	"io/ioutil"
	"path/filepath"
	"translationfiestago/internal/domain/repositories"
)

type BatchProcessor struct {
	translationUseCases *TranslationUseCases
	fileUseCases        *FileUseCases
	settingsRepo        repositories.SettingsRepository
	updateCallback      func(int, int)
}

func NewBatchProcessor(translationUseCases *TranslationUseCases, fileUseCases *FileUseCases, settingsRepo repositories.SettingsRepository, updateCallback func(int, int)) *BatchProcessor {
	return &BatchProcessor{
		translationUseCases: translationUseCases,
		fileUseCases:        fileUseCases,
		settingsRepo:        settingsRepo,
		updateCallback:      updateCallback,
	}
}

func (p *BatchProcessor) ProcessDirectory(ctx context.Context, path string, sourceLang string, targetLang string) {
	files, err := ioutil.ReadDir(path)
	if err != nil {
		return
	}

	var textFiles []fs.FileInfo
	for _, file := range files {
		if !file.IsDir() {
			switch filepath.Ext(file.Name()) {
			case ".txt", ".md", ".html":
				textFiles = append(textFiles, file)
			}
		}
	}

	totalFiles := len(textFiles)
	for i, file := range textFiles {
		fileInfo, err := p.fileUseCases.LoadFile(filepath.Join(path, file.Name()))
		if err != nil {
			continue
		}

		if sourceLang == "" {
			detected, err := p.translationUseCases.DetectLanguage(ctx, fileInfo.Content, p.settingsRepo.GetAPIKey())
			if err != nil {
				sourceLang = "en"
			} else {
				sourceLang = detected
			}
		}
		if targetLang == "" {
			targetLang = "ja"
		}
		intermediateLang := targetLang
		useOfficial := p.settingsRepo.GetUseOfficialAPI()
		apiKey := p.settingsRepo.GetAPIKey()

		translationResult, err := p.translationUseCases.Translate(ctx, fileInfo.Content, sourceLang, intermediateLang, useOfficial, apiKey)
		if err != nil {
			continue
		}

		backTranslationResult, err := p.translationUseCases.Translate(ctx, translationResult.TranslatedText, intermediateLang, sourceLang, useOfficial, apiKey)
		if err != nil {
			continue
		}

		newFileName := filepath.Join(path, fmt.Sprintf("%s_translated%s", file.Name(), filepath.Ext(file.Name())))
		p.fileUseCases.SaveText(backTranslationResult.TranslatedText, newFileName)

		if p.updateCallback != nil {
			p.updateCallback(i+1, totalFiles)
		}
	}
}
