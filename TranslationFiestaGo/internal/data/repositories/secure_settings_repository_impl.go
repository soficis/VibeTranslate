package repositories

import (
	"encoding/json"
	"os"
	"path/filepath"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"
)

// SecureSettings represents the application settings with secure API key storage
type SecureSettings struct {
	Theme                string `json:"theme"`
	UseOfficialAPI       bool   `json:"use_official_api"`
	SourceLanguage       string `json:"source_language"`
	TargetLanguage       string `json:"target_language"`
	IntermediateLanguage string `json:"intermediate_language"`
	WindowWidth          int    `json:"window_width"`
	WindowHeight         int    `json:"window_height"`
	WindowX              int    `json:"window_x"`
	WindowY              int    `json:"window_y"`
}

// SecureSettingsRepositoryImpl implements the SettingsRepository interface with secure API key storage
type SecureSettingsRepositoryImpl struct {
	settingsFile  string
	settings      *SecureSettings
	secureStorage repositories.SecureStorage
	logger        *utils.Logger
}

// NewSecureSettingsRepository creates a new secure settings repository
func NewSecureSettingsRepository(settingsFile string, secureStorage repositories.SecureStorage) repositories.SettingsRepository {
	if secureStorage == nil {
		// Create default secure storage if none provided
		secureStorage = NewSecureStorage("TranslationFiestaGo")
	}

	repo := &SecureSettingsRepositoryImpl{
		settingsFile: settingsFile,
		settings: &SecureSettings{
			Theme:                "light",
			UseOfficialAPI:       false,
			SourceLanguage:       "en",
			TargetLanguage:       "ja",
			IntermediateLanguage: "ja",
			WindowWidth:          960,
			WindowHeight:         720,
			WindowX:              100,
			WindowY:              100,
		},
		secureStorage: secureStorage,
		logger:        utils.GetLogger(),
	}

	// Load existing settings
	repo.loadSettings()

	return repo
}

// loadSettings loads settings from the settings file
func (r *SecureSettingsRepositoryImpl) loadSettings() {
	if r.settingsFile == "" {
		r.logger.Debug("No settings file specified, using defaults")
		return
	}

	// Create directory if it doesn't exist
	dir := filepath.Dir(r.settingsFile)
	if err := os.MkdirAll(dir, 0755); err != nil {
		r.logger.Error("Failed to create settings directory: %v", err)
		return
	}

	data, err := os.ReadFile(r.settingsFile)
	if err != nil {
		if os.IsNotExist(err) {
			r.logger.Info("Settings file doesn't exist, using defaults")
			return
		}
		r.logger.Error("Failed to read settings file: %v", err)
		return
	}

	var loadedSettings SecureSettings
	if err := json.Unmarshal(data, &loadedSettings); err != nil {
		r.logger.Error("Failed to parse settings file: %v", err)
		return
	}

	r.settings = &loadedSettings
	r.logger.Info("Settings loaded from %s", r.settingsFile)
}

// saveSettings saves current settings to the settings file
func (r *SecureSettingsRepositoryImpl) saveSettings() {
	if r.settingsFile == "" {
		r.logger.Debug("No settings file specified, skipping save")
		return
	}

	data, err := json.MarshalIndent(r.settings, "", "  ")
	if err != nil {
		r.logger.Error("Failed to marshal settings: %v", err)
		return
	}

	if err := os.WriteFile(r.settingsFile, data, 0644); err != nil {
		r.logger.Error("Failed to write settings file: %v", err)
		return
	}

	r.logger.Debug("Settings saved to %s", r.settingsFile)
}

// Theme settings
func (r *SecureSettingsRepositoryImpl) GetTheme() string {
	return r.settings.Theme
}

func (r *SecureSettingsRepositoryImpl) SetTheme(theme string) error {
	r.settings.Theme = theme
	r.saveSettings()
	return nil
}

// API settings
func (r *SecureSettingsRepositoryImpl) GetUseOfficialAPI() bool {
	return r.settings.UseOfficialAPI
}

func (r *SecureSettingsRepositoryImpl) SetUseOfficialAPI(useOfficial bool) error {
	r.settings.UseOfficialAPI = useOfficial
	r.saveSettings()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetAPIKey() string {
	apiKey, err := r.secureStorage.GetAPIKey("main_api_key")
	if err != nil {
		r.logger.Debug("Failed to get API key from secure storage: %v", err)
		return ""
	}
	return apiKey
}

func (r *SecureSettingsRepositoryImpl) SetAPIKey(apiKey string) error {
	if apiKey == "" {
		// Delete the API key if empty
		err := r.secureStorage.DeleteAPIKey("main_api_key")
		if err != nil {
			r.logger.Error("Failed to delete API key from secure storage: %v", err)
			return err
		}
		return nil
	}

	err := r.secureStorage.StoreAPIKey("main_api_key", apiKey)
	if err != nil {
		r.logger.Error("Failed to store API key in secure storage: %v", err)
		return err
	}

	r.logger.Info("API key stored securely")
	return nil
}

// Language settings
func (r *SecureSettingsRepositoryImpl) GetSourceLanguage() string {
	return r.settings.SourceLanguage
}

func (r *SecureSettingsRepositoryImpl) SetSourceLanguage(lang string) error {
	r.settings.SourceLanguage = lang
	r.saveSettings()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetTargetLanguage() string {
	return r.settings.TargetLanguage
}

func (r *SecureSettingsRepositoryImpl) SetTargetLanguage(lang string) error {
	r.settings.TargetLanguage = lang
	r.saveSettings()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetIntermediateLanguage() string {
	return r.settings.IntermediateLanguage
}

func (r *SecureSettingsRepositoryImpl) SetIntermediateLanguage(lang string) error {
	r.settings.IntermediateLanguage = lang
	r.saveSettings()
	return nil
}

// UI settings
func (r *SecureSettingsRepositoryImpl) GetWindowSize() (width, height int) {
	return r.settings.WindowWidth, r.settings.WindowHeight
}

func (r *SecureSettingsRepositoryImpl) SetWindowSize(width, height int) error {
	r.settings.WindowWidth = width
	r.settings.WindowHeight = height
	r.saveSettings()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetWindowPosition() (x, y int) {
	return r.settings.WindowX, r.settings.WindowY
}

func (r *SecureSettingsRepositoryImpl) SetWindowPosition(x, y int) error {
	r.settings.WindowX = x
	r.settings.WindowY = y
	r.saveSettings()
	return nil
}
