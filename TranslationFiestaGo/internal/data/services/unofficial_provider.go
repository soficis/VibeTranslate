package services

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"strings"
	"time"

	"translationfiestago/internal/domain/entities"
)

// TranslateUnofficial performs translation using the unofficial Google Translate API.
func (ts *TranslationService) TranslateUnofficial(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Unofficial translation: %s -> %s -> %s", sourceLang, targetLang, text)

	encodedText := url.QueryEscape(text)
	requestURL := fmt.Sprintf("https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s",
		sourceLang, targetLang, encodedText)

	resp, err := ts.httpClient.Get(ctx, requestURL)
	if err != nil {
		ts.logger.Error("Unofficial translation HTTP error: %v", err)
		return nil, entities.ProviderError{Code: "network_error", Message: "HTTP request failed"}
	}

	if resp.StatusCode() == 429 {
		ts.logger.Error("Unofficial translation API rate limited: HTTP 429")
		return nil, entities.ProviderError{Code: "rate_limited", Message: "Provider rate limited"}
	}
	if resp.StatusCode() == 403 {
		ts.logger.Error("Unofficial translation API blocked: HTTP 403")
		return nil, entities.ProviderError{Code: "blocked", Message: "Provider blocked or captcha detected"}
	}
	if resp.StatusCode() != 200 {
		ts.logger.Error("Unofficial translation API error: HTTP %d - %s", resp.StatusCode(), resp.String())
		code := "invalid_response"
		if resp.StatusCode() >= 500 {
			code = "network_error"
		}
		return nil, entities.ProviderError{Code: code, Message: fmt.Sprintf("HTTP %d", resp.StatusCode())}
	}

	bodyLower := strings.ToLower(resp.String())
	if strings.TrimSpace(bodyLower) == "" {
		return nil, entities.ProviderError{Code: "invalid_response", Message: "Empty response body"}
	}
	if strings.Contains(bodyLower, "<html") || strings.Contains(bodyLower, "captcha") {
		return nil, entities.ProviderError{Code: "blocked", Message: "Provider blocked or captcha detected"}
	}

	result, err := ts.parseUnofficialResponse(resp.String())
	if err != nil {
		ts.logger.Error("Failed to parse unofficial translation response: %v", err)
		return nil, entities.ProviderError{Code: "invalid_response", Message: "Failed to parse response"}
	}

	ts.logger.Info("Unofficial translation successful: %d chars", len(result.TranslatedText))
	return result, nil
}

// parseUnofficialResponse parses the unofficial Google Translate API response.
func (ts *TranslationService) parseUnofficialResponse(responseBody string) (*entities.TranslationResult, error) {
	var data interface{}
	if err := json.Unmarshal([]byte(responseBody), &data); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	dataArray, ok := data.([]interface{})
	if !ok || len(dataArray) == 0 {
		return nil, fmt.Errorf("invalid response format")
	}

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
		OriginalText:   "",
		TranslatedText: translatedText,
		SourceLang:     "",
		TargetLang:     "",
		Error:          nil,
		Timestamp:      time.Now(),
	}, nil
}
