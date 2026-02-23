package repositories

import (
	"fmt"
	"runtime"
	"strings"

	domainrepo "translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"

	"github.com/zalando/go-keyring"
)

// SecureStorageImpl implements secure storage using the OS keyring only.
type SecureStorageImpl struct {
	serviceName      string
	logger           *utils.Logger
	keyringAvailable bool
}

// NewSecureStorage creates a secure storage instance.
func NewSecureStorage(serviceName string) domainrepo.SecureStorage {
	if serviceName == "" {
		serviceName = "TranslationFiestaGo"
	}

	impl := &SecureStorageImpl{
		serviceName: serviceName,
		logger:      utils.GetLogger(),
	}

	impl.keyringAvailable = impl.testKeyringAvailability()
	impl.logger.Info("Secure storage initialized - keyring available: %v", impl.keyringAvailable)

	return impl
}

// testKeyringAvailability verifies keyring read/write/delete behavior.
func (s *SecureStorageImpl) testKeyringAvailability() bool {
	testKey := "__test_key__"
	testValue := "__test_value__"

	if err := keyring.Set(s.serviceName, testKey, testValue); err != nil {
		s.logger.Debug("Keyring test store failed: %v", err)
		return false
	}

	retrieved, err := keyring.Get(s.serviceName, testKey)
	if err != nil {
		s.logger.Debug("Keyring test retrieve failed: %v", err)
		return false
	}

	if err := keyring.Delete(s.serviceName, testKey); err != nil {
		s.logger.Debug("Keyring test cleanup failed: %v", err)
	}

	return retrieved == testValue
}

func (s *SecureStorageImpl) keyringUnavailableError(operation string) error {
	return fmt.Errorf(
		"secure storage keyring unavailable; cannot %s API key. Configure an OS keyring backend",
		operation,
	)
}

// StoreAPIKey stores an API key securely.
func (s *SecureStorageImpl) StoreAPIKey(keyName string, apiKey string) error {
	trimmed := strings.TrimSpace(apiKey)
	if trimmed == "" {
		return fmt.Errorf("API key cannot be empty")
	}
	if !s.keyringAvailable {
		return s.keyringUnavailableError("store")
	}

	if err := keyring.Set(s.serviceName, keyName, trimmed); err != nil {
		s.logger.Error("Failed to store API key in keyring: %v", err)
		return fmt.Errorf("failed to store API key in keyring: %w", err)
	}

	s.logger.Debug("API key stored securely in keyring")
	return nil
}

// GetAPIKey retrieves an API key from secure storage.
func (s *SecureStorageImpl) GetAPIKey(keyName string) (string, error) {
	if !s.keyringAvailable {
		return "", s.keyringUnavailableError("read")
	}

	apiKey, err := keyring.Get(s.serviceName, keyName)
	if err != nil {
		return "", fmt.Errorf("failed to retrieve API key from keyring: %w", err)
	}
	return apiKey, nil
}

// DeleteAPIKey removes an API key from secure storage.
func (s *SecureStorageImpl) DeleteAPIKey(keyName string) error {
	if !s.keyringAvailable {
		return s.keyringUnavailableError("delete")
	}

	if err := keyring.Delete(s.serviceName, keyName); err != nil {
		return fmt.Errorf("failed to delete API key from keyring: %w", err)
	}

	s.logger.Debug("API key deleted from keyring")
	return nil
}

// IsAvailable returns true if keyring-backed secure storage is available.
func (s *SecureStorageImpl) IsAvailable() bool {
	return s.keyringAvailable
}

// GetStorageInfo returns information about the current storage backend.
func (s *SecureStorageImpl) GetStorageInfo() map[string]interface{} {
	return map[string]interface{}{
		"platform":          runtime.GOOS,
		"keyring_available": s.keyringAvailable,
		"service_name":      s.serviceName,
	}
}
