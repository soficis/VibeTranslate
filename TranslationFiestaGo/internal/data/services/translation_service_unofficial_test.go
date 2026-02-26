package services

import (
	"encoding/json"
	"path/filepath"
	"testing"
)

func TestParseUnofficialResponse(t *testing.T) {
	service := NewTranslationService(filepath.Join(t.TempDir(), "tm_cache.json"))
	payload := []interface{}{
		[]interface{}{
			[]interface{}{"Hello", "こんにちは"},
		},
	}
	data, _ := json.Marshal(payload)

	result, err := service.parseUnofficialResponse(string(data))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.TranslatedText != "Hello" {
		t.Fatalf("expected translation 'Hello', got '%s'", result.TranslatedText)
	}
}

func TestParseUnofficialResponseInvalid(t *testing.T) {
	service := NewTranslationService(filepath.Join(t.TempDir(), "tm_cache.json"))
	_, err := service.parseUnofficialResponse("not json")
	if err == nil {
		t.Fatal("expected parse error")
	}
}
