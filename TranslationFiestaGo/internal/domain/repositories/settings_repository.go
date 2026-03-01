package repositories

// SettingsRepository defines the interface for application settings
type SettingsRepository interface {
	// Theme settings
	GetTheme() string
	SetTheme(theme string) error

	// API settings
	GetProviderID() string
	SetProviderID(providerID string) error

	// Language settings
	GetSourceLanguage() string
	SetSourceLanguage(lang string) error

	GetTargetLanguage() string
	SetTargetLanguage(lang string) error

	GetIntermediateLanguage() string
	SetIntermediateLanguage(lang string) error

	// UI settings
	GetWindowSize() (width, height int)
	SetWindowSize(width, height int) error

	GetWindowPosition() (x, y int)
	SetWindowPosition(x, y int) error
}
