package repositories

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"

	"github.com/zalando/go-keyring"
)

// SecureStorageImpl implements the SecureStorage interface using go-keyring
type SecureStorageImpl struct {
	serviceName      string
	logger           *utils.Logger
	keyringAvailable bool
	fallbackFile     string
}

// NewSecureStorage creates a new secure storage instance
func NewSecureStorage(serviceName string) repositories.SecureStorage {
	if serviceName == "" {
		serviceName = "TranslationFiestaGo"
	}

	impl := &SecureStorageImpl{
		serviceName: serviceName,
		logger:      utils.GetLogger(),
	}

	// Test keyring availability
	impl.keyringAvailable = impl.testKeyringAvailability()

	// Set up fallback file path
	impl.fallbackFile = impl.getFallbackFilePath()

	impl.logger.Info("Secure storage initialized - Keyring available: %v", impl.keyringAvailable)

	return impl
}

// testKeyringAvailability tests if the keyring backend is available and working
func (s *SecureStorageImpl) testKeyringAvailability() bool {
	testKey := "__test_key__"
	testValue := "__test_value__"

	defer func() {
		// Clean up test data
		keyring.Delete(s.serviceName, testKey)
	}()

	// Try to store and retrieve a test value
	err := keyring.Set(s.serviceName, testKey, testValue)
	if err != nil {
		s.logger.Debug("Keyring test store failed: %v", err)
		return false
	}

	retrieved, err := keyring.Get(s.serviceName, testKey)
	if err != nil {
		s.logger.Debug("Keyring test retrieve failed: %v", err)
		return false
	}

	return retrieved == testValue
}

// getFallbackFilePath returns the path for fallback encrypted storage
func (s *SecureStorageImpl) getFallbackFilePath() string {
	var baseDir string

	switch runtime.GOOS {
	case "windows":
		if appData := os.Getenv("APPDATA"); appData != "" {
			baseDir = filepath.Join(appData, "TranslationFiestaGo")
		} else {
			baseDir = filepath.Join(os.Getenv("USERPROFILE"), ".translationfiestago")
		}
	case "darwin": // macOS
		if home := os.Getenv("HOME"); home != "" {
			baseDir = filepath.Join(home, "Library", "Application Support", "TranslationFiestaGo")
		} else {
			baseDir = filepath.Join(os.Getenv("HOME"), ".translationfiestago")
		}
	default: // Linux and others
		if home := os.Getenv("HOME"); home != "" {
			baseDir = filepath.Join(home, ".config", "translationfiestago")
		} else {
			baseDir = filepath.Join(os.Getenv("HOME"), ".translationfiestago")
		}
	}

	// Create directory if it doesn't exist
	os.MkdirAll(baseDir, 0700)

	return filepath.Join(baseDir, "secure_storage.enc")
}

// StoreAPIKey stores an API key securely
func (s *SecureStorageImpl) StoreAPIKey(keyName string, apiKey string) error {
	if strings.TrimSpace(apiKey) == "" {
		return fmt.Errorf("API key cannot be empty")
	}

	if s.keyringAvailable {
		err := keyring.Set(s.serviceName, keyName, strings.TrimSpace(apiKey))
		if err != nil {
			s.logger.Error("Failed to store API key in keyring: %v", err)
			// Fall back to encrypted file storage
			return s.storeFallback(keyName, strings.TrimSpace(apiKey))
		}
		s.logger.Debug("API key stored securely in keyring")
		return nil
	}

	// Use fallback storage
	return s.storeFallback(keyName, strings.TrimSpace(apiKey))
}

// GetAPIKey retrieves an API key from secure storage
func (s *SecureStorageImpl) GetAPIKey(keyName string) (string, error) {
	if s.keyringAvailable {
		apiKey, err := keyring.Get(s.serviceName, keyName)
		if err == nil {
			return apiKey, nil
		}
		s.logger.Debug("Failed to get API key from keyring: %v", err)
		// Try fallback storage
	}

	// Try fallback storage
	return s.getFallback(keyName)
}

// DeleteAPIKey removes an API key from secure storage
func (s *SecureStorageImpl) DeleteAPIKey(keyName string) error {
	if s.keyringAvailable {
		err := keyring.Delete(s.serviceName, keyName)
		if err == nil {
			s.logger.Debug("API key deleted from keyring")
			return nil
		}
		s.logger.Debug("Failed to delete API key from keyring: %v", err)
		// Try fallback storage
	}

	// Try fallback storage
	return s.deleteFallback(keyName)
}

// IsAvailable returns true if secure storage is available
func (s *SecureStorageImpl) IsAvailable() bool {
	return s.keyringAvailable || s.fallbackAvailable()
}

// GetStorageInfo returns information about the current storage backend
func (s *SecureStorageImpl) GetStorageInfo() map[string]interface{} {
	return map[string]interface{}{
		"platform":           runtime.GOOS,
		"keyring_available":  s.keyringAvailable,
		"fallback_available": s.fallbackAvailable(),
		"service_name":       s.serviceName,
		"fallback_file":      s.fallbackFile,
	}
}

// Fallback encrypted file storage methods

// storeFallback stores data in encrypted fallback file
func (s *SecureStorageImpl) storeFallback(keyName string, value string) error {
	data := s.loadFallbackData()

	// Encrypt the value
	encrypted, err := s.encrypt(value)
	if err != nil {
		return fmt.Errorf("failed to encrypt value: %v", err)
	}

	data[keyName] = encrypted
	return s.saveFallbackData(data)
}

// getFallback retrieves data from encrypted fallback file
func (s *SecureStorageImpl) getFallback(keyName string) (string, error) {
	data := s.loadFallbackData()

	encrypted, exists := data[keyName]
	if !exists {
		return "", fmt.Errorf("API key not found")
	}

	// Decrypt the value
	decrypted, err := s.decrypt(encrypted)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt value: %v", err)
	}

	return decrypted, nil
}

// deleteFallback removes data from encrypted fallback file
func (s *SecureStorageImpl) deleteFallback(keyName string) error {
	data := s.loadFallbackData()

	if _, exists := data[keyName]; !exists {
		return fmt.Errorf("API key not found")
	}

	delete(data, keyName)
	return s.saveFallbackData(data)
}

// loadFallbackData loads encrypted data from fallback file
func (s *SecureStorageImpl) loadFallbackData() map[string]string {
	if !s.fallbackAvailable() {
		return make(map[string]string)
	}

	fileData, err := os.ReadFile(s.fallbackFile)
	if err != nil {
		if os.IsNotExist(err) {
			return make(map[string]string)
		}
		s.logger.Error("Failed to read fallback file: %v", err)
		return make(map[string]string)
	}

	var data map[string]string
	if err := json.Unmarshal(fileData, &data); err != nil {
		s.logger.Error("Failed to parse fallback file: %v", err)
		return make(map[string]string)
	}

	return data
}

// saveFallbackData saves encrypted data to fallback file
func (s *SecureStorageImpl) saveFallbackData(data map[string]string) error {
	// Ensure directory exists
	dir := filepath.Dir(s.fallbackFile)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed to create fallback directory: %v", err)
	}

	fileData, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal fallback data: %v", err)
	}

	if err := os.WriteFile(s.fallbackFile, fileData, 0600); err != nil {
		return fmt.Errorf("failed to write fallback file: %v", err)
	}

	return nil
}

// fallbackAvailable checks if fallback storage is available
func (s *SecureStorageImpl) fallbackAvailable() bool {
	dir := filepath.Dir(s.fallbackFile)
	return s.canWriteToDirectory(dir)
}

// canWriteToDirectory checks if we can write to a directory
func (s *SecureStorageImpl) canWriteToDirectory(dir string) bool {
	testFile := filepath.Join(dir, ".write_test")
	err := os.WriteFile(testFile, []byte("test"), 0600)
	if err != nil {
		return false
	}
	os.Remove(testFile)
	return true
}

// Simple encryption/decryption using AES (for fallback storage)
// Note: This is not as secure as platform-specific keyring, but better than plain text

// encrypt encrypts a string using AES
func (s *SecureStorageImpl) encrypt(plaintext string) (string, error) {
	// Use a simple key derived from the service name for fallback
	// In production, you might want to use a more sophisticated key derivation
	key := s.deriveKey(s.serviceName)

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	// Create a new GCM cipher
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	// Generate a nonce
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	// Encrypt the data
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)

	// Encode as base64
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// decrypt decrypts a string using AES
func (s *SecureStorageImpl) decrypt(encrypted string) (string, error) {
	key := s.deriveKey(s.serviceName)

	ciphertext, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", err
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]

	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

// deriveKey derives a 32-byte key from a string (simple implementation)
func (s *SecureStorageImpl) deriveKey(input string) []byte {
	// Simple key derivation - in production, use proper KDF like PBKDF2
	key := make([]byte, 32)
	copy(key, []byte(input))

	// Pad or truncate to 32 bytes
	if len(input) < 32 {
		for i := len(input); i < 32; i++ {
			key[i] = byte(i)
		}
	}

	return key
}
