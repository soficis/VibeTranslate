package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"time"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/utils"
)

// TranslationService implements the translation operations
type TranslationService struct {
	httpClient *utils.HTTPClient
	logger     *utils.Logger
}

// NewTranslationService creates a new translation service
func NewTranslationService() *TranslationService {
	return &TranslationService{
		httpClient: utils.NewHTTPClient(),
		logger:     utils.GetLogger(),
	}
}

// TranslateUnofficial performs translation using the unofficial Google Translate API
func (ts *TranslationService) TranslateUnofficial(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Unofficial translation: %s -> %s -> %s", sourceLang, targetLang, text)

	// Prepare the request
	encodedText := url.QueryEscape(text)
	requestURL := fmt.Sprintf("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
		sourceLang, targetLang, encodedText)

	// Make the request
	resp, err := ts.httpClient.Get(ctx, requestURL)
	if err != nil {
		ts.logger.Error("Unofficial translation HTTP error: %v", err)
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}

	if resp.StatusCode() != 200 {
		ts.logger.Error("Unofficial translation API error: HTTP %d - %s", resp.StatusCode(), resp.String())
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode(), resp.String())
	}

	// Parse the response
	result, err := ts.parseUnofficialResponse(resp.String())
	if err != nil {
		ts.logger.Error("Failed to parse unofficial translation response: %v", err)
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	ts.logger.Info("Unofficial translation successful: %d chars", len(result.TranslatedText))

	return result, nil
}

// TranslateOfficial performs translation using the official Google Cloud Translation API
func (ts *TranslationService) TranslateOfficial(ctx context.Context, text, sourceLang, targetLang, apiKey string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Official translation: %s -> %s -> %s", sourceLang, targetLang, text)

	if apiKey == "" {
		return nil, fmt.Errorf("API key is required for official translation")
	}

	requestURL := fmt.Sprintf("https://translation.googleapis.com/language/translate/v2?key=%s", url.QueryEscape(apiKey))

	// Prepare the request body
	requestBody := map[string]interface{}{
		"q":      []string{text},
		"target": targetLang,
		"format": "text",
	}

	if sourceLang != "auto" {
		requestBody["source"] = sourceLang
	}

	// Make the request
	resp, err := ts.httpClient.Post(ctx, requestURL, requestBody)
	if err != nil {
		ts.logger.Error("Official translation HTTP error: %v", err)
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}

	if resp.StatusCode() != 200 {
		ts.logger.Error("Official translation API error: HTTP %d - %s", resp.StatusCode(), resp.String())
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode(), resp.String())
	}

	// Parse the response
	result, err := ts.parseOfficialResponse(resp.String())
	if err != nil {
		ts.logger.Error("Failed to parse official translation response: %v", err)
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	ts.logger.Info("Official translation successful: %d chars", len(result.TranslatedText))

	return result, nil
}

// parseUnofficialResponse parses the unofficial Google Translate API response
func (ts *TranslationService) parseUnofficialResponse(responseBody string) (*entities.TranslationResult, error) {
	var data interface{}
	if err := json.Unmarshal([]byte(responseBody), &data); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	// The response is an array of arrays
	dataArray, ok := data.([]interface{})
	if !ok || len(dataArray) == 0 {
		return nil, fmt.Errorf("invalid response format")
	}

	// Get the translation array (first element)
	translationArray, ok := dataArray[0].([]interface{})
	if !ok || len(translationArray) == 0 {
		return nil, fmt.Errorf("no translation data found")
	}

	var result strings.Builder
	for _, sentence := range translationArray {
		sentenceArray, ok := sentence.([]interface{})
		if !ok || len(sentenceArray) == 0 {
			continue
		}

		if part, ok := sentenceArray[0].(string); ok && part != "" {
			result.WriteString(part)
		}
	}

	translatedText := strings.TrimSpace(result.String())
	if translatedText == "" {
		return nil, fmt.Errorf("no translation found in response")
	}

	return &entities.TranslationResult{
		OriginalText:   "", // Will be set by caller
		TranslatedText: translatedText,
		SourceLang:     "", // Will be set by caller
		TargetLang:     "", // Will be set by caller
		Error:          nil,
		Timestamp:      time.Now(),
	}, nil
}

// parseOfficialResponse parses the official Google Cloud Translation API response
func (ts *TranslationService) parseOfficialResponse(responseBody string) (*entities.TranslationResult, error) {
	var response struct {
		Data struct {
			Translations []struct {
				TranslatedText         string `json:"translatedText"`
				DetectedSourceLanguage string `json:"detectedSourceLanguage,omitempty"`
			} `json:"translations"`
		} `json:"data"`
	}

	if err := json.Unmarshal([]byte(responseBody), &response); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if len(response.Data.Translations) == 0 {
		return nil, fmt.Errorf("no translation found in response")
	}

	translation := response.Data.Translations[0]
	if translation.TranslatedText == "" {
		return nil, fmt.Errorf("empty translation in response")
	}

	return &entities.TranslationResult{
		OriginalText:   "", // Will be set by caller
		TranslatedText: translation.TranslatedText,
		SourceLang:     "", // Will be set by caller
		TargetLang:     "", // Will be set by caller
		Error:          nil,
		Timestamp:      time.Now(),
	}, nil
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
