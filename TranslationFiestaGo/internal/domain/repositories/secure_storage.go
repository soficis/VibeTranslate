package repositories

// SecureStorage defines the interface for secure storage of sensitive data like API keys
type SecureStorage interface {
	// StoreAPIKey stores an API key securely using platform-specific secure storage
	StoreAPIKey(keyName string, apiKey string) error

	// GetAPIKey retrieves an API key from secure storage
	GetAPIKey(keyName string) (string, error)

	// DeleteAPIKey removes an API key from secure storage
	DeleteAPIKey(keyName string) error

	// IsAvailable returns true if secure storage is available on this platform
	IsAvailable() bool

	// GetStorageInfo returns information about the current storage backend
	GetStorageInfo() map[string]interface{}
}
