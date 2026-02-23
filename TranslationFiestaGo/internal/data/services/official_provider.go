package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"time"

	"translationfiestago/internal/costtracker"
	"translationfiestago/internal/domain/entities"
)

// TranslateOfficial performs translation using the official Google Cloud Translation API.
func (ts *TranslationService) TranslateOfficial(ctx context.Context, text, sourceLang, targetLang, apiKey string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Official translation: %s -> %s -> %s", sourceLang, targetLang, text)

	if apiKey == "" {
		return nil, fmt.Errorf("API key is required for official translation")
	}

	requestURL := fmt.Sprintf("https://translation.googleapis.com/language/translate/v2?key=%s", url.QueryEscape(apiKey))

	requestBody := map[string]interface{}{
		"q":      []string{text},
		"target": targetLang,
		"format": "text",
	}
	if sourceLang != "auto" {
		requestBody["source"] = sourceLang
	}

	resp, err := ts.httpClient.Post(ctx, requestURL, requestBody)
	if err != nil {
		ts.logger.Error("Official translation HTTP error: %v", err)
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}

	if resp.StatusCode() != 200 {
		ts.logger.Error("Official translation API error: HTTP %d - %s", resp.StatusCode(), resp.String())
		return nil, fmt.Errorf("API returned status %d: %s", resp.StatusCode(), resp.String())
	}

	result, err := ts.parseOfficialResponse(resp.String())
	if err != nil {
		ts.logger.Error("Failed to parse official translation response: %v", err)
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	ts.logger.Info("Official translation successful: %d chars", len(result.TranslatedText))

	if os.Getenv("TF_COST_TRACKING_ENABLED") == "1" {
		go func() {
			defer func() {
				if r := recover(); r != nil {
					ts.logger.Error("Failed to track translation cost: %v", r)
				}
			}()
			costtracker.TrackTranslationCost(
				len(result.TranslatedText),
				sourceLang,
				targetLang,
				"go",
				"v2",
			)
		}()
	}

	return result, nil
}

// parseOfficialResponse parses the official Google Cloud Translation API response.
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
		OriginalText:   "",
		TranslatedText: translation.TranslatedText,
		SourceLang:     "",
		TargetLang:     "",
		Error:          nil,
		Timestamp:      time.Now(),
	}, nil
}
