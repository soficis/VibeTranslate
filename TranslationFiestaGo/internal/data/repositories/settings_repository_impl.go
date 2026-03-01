package repositories

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"
)

// Settings represents the application settings.
type Settings struct {
	Theme                string `json:"theme"`
	ProviderID           string `json:"provider_id"`
	SourceLanguage       string `json:"source_language"`
	TargetLanguage       string `json:"target_language"`
	IntermediateLanguage string `json:"intermediate_language"`
	WindowWidth          int    `json:"window_width"`
	WindowHeight         int    `json:"window_height"`
	WindowX              int    `json:"window_x"`
	WindowY              int    `json:"window_y"`
}

// SettingsRepositoryImpl implements the SettingsRepository interface
type SettingsRepositoryImpl struct {
	settingsFile string
	settings     *Settings
	logger       *utils.Logger
}

// NewSettingsRepository creates a new settings repository
func NewSettingsRepository(settingsFile string) repositories.SettingsRepository {
	repo := &SettingsRepositoryImpl{
		settingsFile: settingsFile,
		settings: &Settings{
			Theme:                "light",
			ProviderID:           entities.ProviderGoogleUnofficial,
			SourceLanguage:       "en",
			TargetLanguage:       "ja",
			IntermediateLanguage: "ja",
			WindowWidth:          960,
			WindowHeight:         720,
			WindowX:              100,
			WindowY:              100,
		},
		logger: utils.GetLogger(),
	}

	// Load existing settings
	repo.loadSettings()

	return repo
}

// loadSettings loads settings from the settings file
func (r *SettingsRepositoryImpl) loadSettings() {
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

	var loadedSettings Settings
	if err := json.Unmarshal(data, &loadedSettings); err != nil {
		r.logger.Error("Failed to parse settings file: %v", err)
		return
	}

	r.settings = &loadedSettings

	r.logger.Info("Settings loaded from %s", r.settingsFile)
}

// saveSettings saves current settings to the settings file
func (r *SettingsRepositoryImpl) saveSettings() {
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
func (r *SettingsRepositoryImpl) GetTheme() string {
	return r.settings.Theme
}

func (r *SettingsRepositoryImpl) SetTheme(theme string) error {
	r.settings.Theme = theme
	r.saveSettings()
	return nil
}

// API settings
func (r *SettingsRepositoryImpl) GetProviderID() string {
	raw := strings.TrimSpace(r.settings.ProviderID)
	if raw == "" {
		return entities.ProviderGoogleUnofficial
	}
	return entities.NormalizeProviderID(raw)
}

func (r *SettingsRepositoryImpl) SetProviderID(providerID string) error {
	normalized := entities.NormalizeProviderID(providerID)
	r.settings.ProviderID = normalized
	r.saveSettings()
	return nil
}

// Language settings
func (r *SettingsRepositoryImpl) GetSourceLanguage() string {
	return r.settings.SourceLanguage
}

func (r *SettingsRepositoryImpl) SetSourceLanguage(lang string) error {
	r.settings.SourceLanguage = lang
	r.saveSettings()
	return nil
}

func (r *SettingsRepositoryImpl) GetTargetLanguage() string {
	return r.settings.TargetLanguage
}

func (r *SettingsRepositoryImpl) SetTargetLanguage(lang string) error {
	r.settings.TargetLanguage = lang
	r.saveSettings()
	return nil
}

func (r *SettingsRepositoryImpl) GetIntermediateLanguage() string {
	return r.settings.IntermediateLanguage
}

func (r *SettingsRepositoryImpl) SetIntermediateLanguage(lang string) error {
	r.settings.IntermediateLanguage = lang
	r.saveSettings()
	return nil
}

// UI settings
func (r *SettingsRepositoryImpl) GetWindowSize() (width, height int) {
	return r.settings.WindowWidth, r.settings.WindowHeight
}

func (r *SettingsRepositoryImpl) SetWindowSize(width, height int) error {
	r.settings.WindowWidth = width
	r.settings.WindowHeight = height
	r.saveSettings()
	return nil
}

func (r *SettingsRepositoryImpl) GetWindowPosition() (x, y int) {
	return r.settings.WindowX, r.settings.WindowY
}

func (r *SettingsRepositoryImpl) SetWindowPosition(x, y int) error {
	r.settings.WindowX = x
	r.settings.WindowY = y
	r.saveSettings()
	return nil
}
