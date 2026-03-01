package usecases

import (
	"context"
	"fmt"
	"strings"
	"time"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/repositories"
	"unicode"
)

// TranslationUseCases contains the business logic for translation operations
type TranslationUseCases struct {
	translationRepo repositories.TranslationRepository
	settingsRepo    repositories.SettingsRepository
}

// NewTranslationUseCases creates a new instance of TranslationUseCases
func NewTranslationUseCases(translationRepo repositories.TranslationRepository, settingsRepo repositories.SettingsRepository) *TranslationUseCases {
	return &TranslationUseCases{
		translationRepo: translationRepo,
		settingsRepo:    settingsRepo,
	}
}

// Translate performs a single translation
func (uc *TranslationUseCases) Translate(ctx context.Context, text, sourceLang, targetLang, providerID string) (*entities.TranslationResult, error) {
	if text == "" {
		return nil, fmt.Errorf("text cannot be empty")
	}

	if !uc.validateLanguage(sourceLang) {
		return nil, fmt.Errorf("invalid source language: %s", sourceLang)
	}

	if !uc.validateLanguage(targetLang) {
		return nil, fmt.Errorf("invalid target language: %s", targetLang)
	}

	normalizedProvider := entities.NormalizeProviderID(providerID)

	if sourceLang == "" {
		var err error
		sourceLang, err = uc.DetectLanguage(ctx, text)
		if err != nil {
			return nil, fmt.Errorf("failed to detect language: %w", err)
		}
	}

	request := entities.TranslationRequest{
		Text:       text,
		SourceLang: sourceLang,
		TargetLang: targetLang,
		ProviderID: normalizedProvider,
	}

	return uc.translationRepo.Translate(ctx, request)
}

// validateLanguage checks if the language code is a valid 2-letter code
func (uc *TranslationUseCases) validateLanguage(lang string) bool {
	if len(lang) != 2 {
		return false
	}
	lower := strings.ToLower(lang)
	if lower != lang {
		return false
	}
	for _, r := range lang {
		if !unicode.IsLetter(r) {
			return false
		}
	}
	return true
}

// DetectLanguage returns the default source language.
func (uc *TranslationUseCases) DetectLanguage(_ context.Context, _ string) (string, error) {
	return "en", nil
}

// BackTranslate performs a full back-translation
func (uc *TranslationUseCases) BackTranslate(ctx context.Context, text string) (*entities.BackTranslation, error) {
	if text == "" {
		return nil, fmt.Errorf("text cannot be empty")
	}

	sourceLang := uc.settingsRepo.GetSourceLanguage()
	if sourceLang == "" {
		sourceLang = "en"
	}

	intermediateLang := uc.settingsRepo.GetIntermediateLanguage()
	if intermediateLang == "" {
		intermediateLang = "ja"
	}

	providerID := uc.settingsRepo.GetProviderID()

	startTime := time.Now()

	result, err := uc.translationRepo.BackTranslate(ctx, text, sourceLang, intermediateLang, providerID)

	if result != nil {
		result.Duration = time.Since(startTime)
	}

	return result, err
}

// GetDefaultLanguages returns the default source and intermediate languages
func (uc *TranslationUseCases) GetDefaultLanguages() (source, intermediate string) {
	source = uc.settingsRepo.GetSourceLanguage()
	if source == "" {
		source = "en"
	}

	intermediate = uc.settingsRepo.GetIntermediateLanguage()
	if intermediate == "" {
		intermediate = "ja"
	}

	return source, intermediate
}
