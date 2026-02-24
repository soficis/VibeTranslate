package services

import (
	"context"
	"fmt"
	"time"

	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/utils"
)

func previewText(text string) string {
	const maxLen = 50
	if len(text) <= maxLen {
		return text
	}
	return text[:maxLen]
}

type TranslationService struct {
	httpClient *utils.HTTPClient
	logger     *utils.Logger
	tm         *TranslationMemory
	local      *LocalServiceClient
}

// NewTranslationService creates a new translation service
func NewTranslationService() *TranslationService {
	httpClient := utils.NewHTTPClient()
	return &TranslationService{
		httpClient: httpClient,
		logger:     utils.GetLogger(),
		tm:         NewTranslationMemory(1000, "tm_cache.json", 0.8),
		local:      NewLocalServiceClient(httpClient),
	}
}

// retryTranslate performs translation with retry logic
func (ts *TranslationService) retryTranslate(ctx context.Context, translateFunc func() (*entities.TranslationResult, error), maxRetries int) (*entities.TranslationResult, error) {
	var lastErr error

	for attempt := 1; attempt <= maxRetries; attempt++ {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		default:
		}

		result, err := translateFunc()
		if err == nil {
			return result, nil
		}

		lastErr = err
		ts.logger.Warn("Translation attempt %d/%d failed: %v", attempt, maxRetries, err)

		// Don't retry on the last attempt
		if attempt < maxRetries {
			// Exponential backoff
			waitTime := time.Duration(attempt) * time.Second
			ts.logger.Info("Retrying in %v...", waitTime)

			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(waitTime):
				// Continue to next attempt
			}
		}
	}

	return nil, fmt.Errorf("all %d attempts failed, last error: %w", maxRetries, lastErr)
}

// Translate implements the TranslationRepository interface
func (ts *TranslationService) Translate(ctx context.Context, request entities.TranslationRequest) (*entities.TranslationResult, error) {
	providerID := entities.NormalizeProviderID(request.ProviderID)

	// Check cache
	translation, found := ts.tm.Lookup(request.Text, request.TargetLang, providerID)
	if found {
		ts.logger.Info("Cache hit for %s", previewText(request.Text))
		return &entities.TranslationResult{
			OriginalText:   request.Text,
			TranslatedText: translation,
			SourceLang:     request.SourceLang,
			TargetLang:     request.TargetLang,
			Error:          nil,
			Timestamp:      time.Now(),
		}, nil
	}

	// Check fuzzy cache
	fuzzyTrans, score, fuzzyFound := ts.tm.FuzzyLookup(request.Text, request.TargetLang, providerID)
	if fuzzyFound {
		ts.logger.Info("Fuzzy cache hit (score: %.2f) for %s", score, previewText(request.Text))
		return &entities.TranslationResult{
			OriginalText:   request.Text,
			TranslatedText: fuzzyTrans,
			SourceLang:     request.SourceLang,
			TargetLang:     request.TargetLang,
			Error:          nil,
			Timestamp:      time.Now(),
		}, nil
	}

	// API call with retry
	translateFunc := func() (*entities.TranslationResult, error) {
		var result *entities.TranslationResult
		var err error
		switch providerID {
		case entities.ProviderLocal:
			result, err = ts.TranslateLocal(ctx, request.Text, request.SourceLang, request.TargetLang)
		default:
			result, err = ts.TranslateUnofficial(ctx, request.Text, request.SourceLang, request.TargetLang)
		}
		if err != nil {
			return nil, err
		}
		return result, nil
	}

	result, err := ts.retryTranslate(ctx, translateFunc, 4)
	if err != nil {
		return nil, err
	}

	result.OriginalText = request.Text
	result.SourceLang = request.SourceLang
	result.TargetLang = request.TargetLang

	// Store in cache
	ts.tm.Store(request.Text, request.TargetLang, providerID, result.TranslatedText)

	return result, nil
}

// BackTranslate implements the BackTranslate method
func (ts *TranslationService) BackTranslate(ctx context.Context, text, sourceLang, intermediateLang, providerID string) (*entities.BackTranslation, error) {
	// First translation: source -> intermediate
	firstResult, err := ts.Translate(ctx, entities.TranslationRequest{
		Text:       text,
		SourceLang: sourceLang,
		TargetLang: intermediateLang,
		ProviderID: providerID,
	})
	if err != nil {
		return nil, err
	}

	// Second translation: intermediate -> source
	secondResult, err := ts.Translate(ctx, entities.TranslationRequest{
		Text:       firstResult.TranslatedText,
		SourceLang: intermediateLang,
		TargetLang: sourceLang,
		ProviderID: providerID,
	})
	if err != nil {
		return nil, err
	}

	return &entities.BackTranslation{
		Intermediate: firstResult.TranslatedText,
		Result:       secondResult.TranslatedText,
	}, nil
}

func (ts *TranslationService) GetTMStats() map[string]interface{} {
	return ts.tm.GetStats()
}

func (ts *TranslationService) ClearTMCache() {
	ts.tm.ClearCache()
}
