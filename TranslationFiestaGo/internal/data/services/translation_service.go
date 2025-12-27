package services

import (
	"container/list"
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"time"

	"translationfiestago/internal/costtracker"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/utils"
)

// TranslationService implements the translation operations
type TranslationMemory struct {
	cache           map[string]*list.Element
	lruList         *list.List
	cacheSize       int
	threshold       float64
	persistencePath string
	metrics         TMetrics
}

type TMEntry struct {
	Source      string    `json:"source"`
	Translation string    `json:"translation"`
	TargetLang  string    `json:"target_lang"`
	ProviderID  string    `json:"provider_id"`
	AccessTime  time.Time `json:"access_time"`
}

type TMetrics struct {
	Hits         int     `json:"hits"`
	Misses       int     `json:"misses"`
	FuzzyHits    int     `json:"fuzzy_hits"`
	TotalLookups int     `json:"total_lookups"`
	TotalTime    float64 `json:"total_time"`
}

func NewTranslationMemory(cacheSize int, persistencePath string, threshold float64) *TranslationMemory {
	tm := &TranslationMemory{
		cache:           make(map[string]*list.Element),
		lruList:         list.New(),
		cacheSize:       cacheSize,
		threshold:       threshold,
		persistencePath: persistencePath,
		metrics:         TMetrics{},
	}
	tm.loadCache()
	return tm
}

func (tm *TranslationMemory) getKey(source, targetLang, providerID string) string {
	return source + ":" + targetLang + ":" + providerID
}

func (tm *TranslationMemory) Lookup(source, targetLang, providerID string) (string, bool) {
	key := tm.getKey(source, targetLang, providerID)
	if elem, exists := tm.cache[key]; exists {
		tm.lruList.MoveToFront(elem)
		tm.metrics.Hits++
		tm.metrics.TotalLookups++
		return elem.Value.(*TMEntry).Translation, true
	}
	tm.metrics.Misses++
	tm.metrics.TotalLookups++
	return "", false
}

func levenshtein(s1, s2 string) int {
	m, n := len(s1), len(s2)
	if m == 0 {
		return n
	}
	if n == 0 {
		return m
	}
	d := make([][]int, m+1)
	for i := range d {
		d[i] = make([]int, n+1)
	}
	for i := range d {
		d[i][0] = i
	}
	for j := range d[0] {
		d[0][j] = j
	}
	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			cost := 0
			if s1[i-1] != s2[j-1] {
				cost = 1
			}
			d[i][j] = min(d[i-1][j]+1, d[i][j-1]+1, d[i-1][j-1]+cost)
		}
	}
	return d[m][n]
}

func (tm *TranslationMemory) FuzzyLookup(source, targetLang, providerID string) (string, float64, bool) {
	var bestScore float64
	var bestTranslation string
	matched := false

	for elem := tm.lruList.Front(); elem != nil; elem = elem.Next() {
		entry := elem.Value.(*TMEntry)
		if entry.TargetLang == targetLang && entry.ProviderID == providerID {
			distance := levenshtein(source, entry.Source)
			maxLen := max(len(source), len(entry.Source))
			score := 1.0 - float64(distance)/float64(maxLen)
			if score > bestScore && score >= tm.threshold {
				bestScore = score
				bestTranslation = entry.Translation
				matched = true
			}
		}
	}

	if matched {
		tm.metrics.FuzzyHits++
		tm.metrics.TotalLookups++
		return bestTranslation, bestScore, true
	}
	tm.metrics.Misses++
	tm.metrics.TotalLookups++
	return "", 0, false
}

func (tm *TranslationMemory) Store(source, targetLang, providerID, translation string) {
	key := tm.getKey(source, targetLang, providerID)
	entry := &TMEntry{
		Source:      source,
		Translation: translation,
		TargetLang:  targetLang,
		ProviderID:  providerID,
		AccessTime:  time.Now(),
	}

	if elem, exists := tm.cache[key]; exists {
		tm.lruList.MoveToFront(elem)
		elem.Value = entry
	} else {
		newElem := tm.lruList.PushFront(entry)
		tm.cache[key] = newElem
		if tm.lruList.Len() > tm.cacheSize {
			last := tm.lruList.Back()
			if last != nil {
				delete(tm.cache, tm.getKey(last.Value.(*TMEntry).Source, last.Value.(*TMEntry).TargetLang, last.Value.(*TMEntry).ProviderID))
				tm.lruList.Remove(last)
			}
		}
	}
	tm.persist()
}

func (tm *TranslationMemory) GetStats() map[string]interface{} {
	stats := make(map[string]interface{})
	stats["hits"] = tm.metrics.Hits
	stats["misses"] = tm.metrics.Misses
	stats["fuzzy_hits"] = tm.metrics.FuzzyHits
	stats["total_lookups"] = tm.metrics.TotalLookups
	stats["hit_rate"] = float64(tm.metrics.Hits+tm.metrics.FuzzyHits) / float64(max(1, tm.metrics.TotalLookups))
	stats["avg_lookup_time"] = tm.metrics.TotalTime / float64(max(1, tm.metrics.TotalLookups))
	stats["cache_size"] = tm.lruList.Len()
	stats["max_size"] = tm.cacheSize
	return stats
}

func (tm *TranslationMemory) ClearCache() {
	tm.cache = make(map[string]*list.Element)
	tm.lruList.Init()
	tm.metrics = TMetrics{}
	tm.persist()
}

func (tm *TranslationMemory) persist() {
	data := map[string]interface{}{
		"config": map[string]interface{}{
			"max_size":  tm.cacheSize,
			"threshold": tm.threshold,
		},
		"cache":   []TMEntry{},
		"metrics": tm.metrics,
	}

	for elem := tm.lruList.Front(); elem != nil; elem = elem.Next() {
		data["cache"] = append(data["cache"].([]TMEntry), *elem.Value.(*TMEntry))
	}

	bytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Printf("Failed to marshal cache: %v\n", err)
		return
	}

	if err := os.WriteFile(tm.persistencePath, bytes, 0644); err != nil {
		fmt.Printf("Failed to write cache file: %v\n", err)
	}
}

func (tm *TranslationMemory) loadCache() {
	bytes, err := os.ReadFile(tm.persistencePath)
	if err != nil {
		if !os.IsNotExist(err) {
			fmt.Printf("Failed to read cache file: %v\n", err)
		}
		return
	}

	var data map[string]interface{}
	if err := json.Unmarshal(bytes, &data); err != nil {
		fmt.Printf("Failed to unmarshal cache: %v\n", err)
		return
	}

	if config, ok := data["config"].(map[string]interface{}); ok {
		if size, ok := config["max_size"].(float64); ok {
			tm.cacheSize = int(size)
		}
		if thresh, ok := config["threshold"].(float64); ok {
			tm.threshold = thresh
		}
	}

	if metricsData, ok := data["metrics"].(map[string]interface{}); ok {
		if h, ok := metricsData["hits"].(float64); ok {
			tm.metrics.Hits = int(h)
		}
		if m, ok := metricsData["misses"].(float64); ok {
			tm.metrics.Misses = int(m)
		}
		if fh, ok := metricsData["fuzzy_hits"].(float64); ok {
			tm.metrics.FuzzyHits = int(fh)
		}
		if tl, ok := metricsData["total_lookups"].(float64); ok {
			tm.metrics.TotalLookups = int(tl)
		}
		if tt, ok := metricsData["total_time"].(float64); ok {
			tm.metrics.TotalTime = tt
		}
	}

	tm.cache = make(map[string]*list.Element)
	tm.lruList = list.New()
	for _, entryData := range data["cache"].([]interface{}) {
		entryMap := entryData.(map[string]interface{})
		t, err := time.Parse(time.RFC3339, entryMap["access_time"].(string))
		if err != nil {
			continue
		}
		entry := &TMEntry{
			Source:      entryMap["source"].(string),
			Translation: entryMap["translation"].(string),
			TargetLang:  entryMap["target_lang"].(string),
			AccessTime:  t,
		}
		entry.ProviderID, _ = entryMap["provider_id"].(string)
		entry.ProviderID = entities.NormalizeProviderID(entry.ProviderID)
		key := tm.getKey(entry.Source, entry.TargetLang, entry.ProviderID)
		elem := tm.lruList.PushFront(entry)
		tm.cache[key] = elem
	}
}

func min(a, b, c int) int {
	if a < b {
		if a < c {
			return a
		}
		return c
	}
	if b < c {
		return b
	}
	return c
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

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

// TranslateLocal performs translation using the local offline service
func (ts *TranslationService) TranslateLocal(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Local translation: %s -> %s -> %s", sourceLang, targetLang, text)
	return ts.local.Translate(ctx, text, sourceLang, targetLang)
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

	// Parse the response
	result, err := ts.parseUnofficialResponse(resp.String())
	if err != nil {
		ts.logger.Error("Failed to parse unofficial translation response: %v", err)
		return nil, entities.ProviderError{Code: "invalid_response", Message: "Failed to parse response"}
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

	// Track cost for successful official API translation
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

// Translate implements the TranslationRepository interface
func (ts *TranslationService) Translate(ctx context.Context, request entities.TranslationRequest) (*entities.TranslationResult, error) {
	providerID := entities.NormalizeProviderID(request.ProviderID)
	if entities.IsOfficialProvider(providerID) && request.APIKey == "" {
		return nil, fmt.Errorf("API key required for official translation")
	}

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
		case entities.ProviderGoogleOfficial:
			result, err = ts.TranslateOfficial(ctx, request.Text, request.SourceLang, request.TargetLang, request.APIKey)
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
func (ts *TranslationService) BackTranslate(ctx context.Context, text, sourceLang, intermediateLang, providerID, apiKey string) (*entities.BackTranslation, error) {
	// First translation: source -> intermediate
	firstResult, err := ts.Translate(ctx, entities.TranslationRequest{
		Text:       text,
		SourceLang: sourceLang,
		TargetLang: intermediateLang,
		ProviderID: providerID,
		APIKey:     apiKey,
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
		APIKey:     apiKey,
	})
	if err != nil {
		return nil, err
	}

	// Track costs for backtranslation (two API calls)
	if entities.IsOfficialProvider(providerID) && os.Getenv("TF_COST_TRACKING_ENABLED") == "1" {
		go func() {
			defer func() {
				if r := recover(); r != nil {
					ts.logger.Error("Failed to track backtranslation costs: %v", r)
				}
			}()
			// Track cost for first translation (source -> intermediate)
			costtracker.TrackTranslationCost(
				len(firstResult.TranslatedText),
				sourceLang,
				intermediateLang,
				"go",
				"v2",
			)
			// Track cost for second translation (intermediate -> source)
			costtracker.TrackTranslationCost(
				len(secondResult.TranslatedText),
				intermediateLang,
				sourceLang,
				"go",
				"v2",
			)
		}()
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

// DetectLanguage detects the source language using official API if key provided, fallback to "en"
func (ts *TranslationService) DetectLanguage(ctx context.Context, text, apiKey string) (string, error) {
	if apiKey == "" {
		ts.logger.Warn("No API key for language detection, falling back to 'en'")
		return "en", nil
	}

	requestURL := fmt.Sprintf("https://translation.googleapis.com/language/translate/v2/detect?key=%s", url.QueryEscape(apiKey))

	requestBody := map[string]interface{}{
		"q": text,
	}

	resp, err := ts.httpClient.Post(ctx, requestURL, requestBody)
	if err != nil {
		ts.logger.Error("Language detection HTTP error: %v", err)
		return "en", fmt.Errorf("HTTP request failed: %w", err)
	}

	if resp.StatusCode() != 200 {
		ts.logger.Error("Language detection API error: HTTP %d - %s", resp.StatusCode(), resp.String())
		return "en", fmt.Errorf("API returned status %d: %s", resp.StatusCode(), resp.String())
	}

	// Parse response
	var response struct {
		Data struct {
			Translations []struct {
				Language   string  `json:"language"`
				Confidence float64 `json:"confidence"`
			} `json:"translations"`
		} `json:"data"`
	}

	if err := json.Unmarshal([]byte(resp.String()), &response); err != nil {
		ts.logger.Error("Failed to parse language detection response: %v", err)
		return "en", fmt.Errorf("failed to parse response: %w", err)
	}

	if len(response.Data.Translations) == 0 {
		return "en", fmt.Errorf("no detection result")
	}

	detected := response.Data.Translations[0].Language
	if detected == "" {
		return "en", fmt.Errorf("empty detected language")
	}

	ts.logger.Info("Detected language: %s (confidence: %f)", detected, response.Data.Translations[0].Confidence)

	return detected, nil
}
