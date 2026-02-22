package test

import (
	"testing"

	"translationfiestago/internal/data/repositories"
)

func TestSecureStorageInfoDoesNotExposeFallback(t *testing.T) {
	storage := repositories.NewSecureStorage("TranslationFiestaGoTest")
	info := storage.GetStorageInfo()

	if _, exists := info["fallback_available"]; exists {
		t.Fatalf("fallback_available should not be present in storage info")
	}
	if _, exists := info["fallback_file"]; exists {
		t.Fatalf("fallback_file should not be present in storage info")
	}

	if _, ok := info["keyring_available"].(bool); !ok {
		t.Fatalf("keyring_available must be a bool")
	}
}

func TestSecureStorageRoundTrip(t *testing.T) {
	storage := repositories.NewSecureStorage("TranslationFiestaGoTest")
	if !storage.IsAvailable() {
		t.Skip("keyring backend unavailable in this environment")
	}

	testKey := "test_api_key"
	testValue := "sk-test12345678901234567890"

	if err := storage.StoreAPIKey(testKey, testValue); err != nil {
		t.Fatalf("store failed: %v", err)
	}

	retrieved, err := storage.GetAPIKey(testKey)
	if err != nil {
		t.Fatalf("retrieve failed: %v", err)
	}
	if retrieved != testValue {
		t.Fatalf("retrieved value mismatch: expected %q got %q", testValue, retrieved)
	}

	if err := storage.DeleteAPIKey(testKey); err != nil {
		t.Fatalf("delete failed: %v", err)
	}

	if _, err := storage.GetAPIKey(testKey); err == nil {
		t.Fatalf("expected get to fail after delete")
	}
}

func TestSecureStorageRejectsEmptyValue(t *testing.T) {
	storage := repositories.NewSecureStorage("TranslationFiestaGoTest")
	if err := storage.StoreAPIKey("test_api_key", "   "); err == nil {
		t.Fatalf("expected empty API key to be rejected")
	}
}

func TestSecureStorageUnavailableReturnsExplicitError(t *testing.T) {
	storage := repositories.NewSecureStorage("TranslationFiestaGoTest")
	if storage.IsAvailable() {
		t.Skip("keyring available in this environment; unavailable-path test not applicable")
	}

	err := storage.StoreAPIKey("test_api_key", "sk-test")
	if err == nil {
		t.Fatalf("expected error when keyring is unavailable")
	}
	if got := err.Error(); got == "" {
		t.Fatalf("expected non-empty error message")
	}
}
