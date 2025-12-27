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

// SecureSettings represents the application settings with secure API key storage
type SecureSettings struct {
	Theme                string `json:"theme"`
	ProviderID           string `json:"provider_id"`
	UseOfficialAPI       bool   `json:"use_official_api"`
	CostTrackingEnabled  bool   `json:"cost_tracking_enabled"`
	SourceLanguage       string `json:"source_language"`
	TargetLanguage       string `json:"target_language"`
	IntermediateLanguage string `json:"intermediate_language"`
	LocalServiceURL      string `json:"local_service_url"`
	LocalModelDir        string `json:"local_model_dir"`
	LocalAutoStart       bool   `json:"local_auto_start"`
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
			ProviderID:           entities.ProviderGoogleUnofficial,
			UseOfficialAPI:       false,
			CostTrackingEnabled:  false,
			SourceLanguage:       "en",
			TargetLanguage:       "ja",
			IntermediateLanguage: "ja",
			LocalServiceURL:      "",
			LocalModelDir:        "",
			LocalAutoStart:       true,
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
	repo.applyLocalEnvironment()

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
	r.applyLocalEnvironment()
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

func (r *SecureSettingsRepositoryImpl) applyLocalEnvironment() {
	if r.settings.CostTrackingEnabled {
		_ = os.Setenv("TF_COST_TRACKING_ENABLED", "1")
	} else {
		_ = os.Setenv("TF_COST_TRACKING_ENABLED", "0")
	}

	if strings.TrimSpace(r.settings.LocalServiceURL) == "" {
		_ = os.Unsetenv("TF_LOCAL_URL")
	} else {
		_ = os.Setenv("TF_LOCAL_URL", strings.TrimSpace(r.settings.LocalServiceURL))
	}

	if strings.TrimSpace(r.settings.LocalModelDir) == "" {
		_ = os.Unsetenv("TF_LOCAL_MODEL_DIR")
	} else {
		_ = os.Setenv("TF_LOCAL_MODEL_DIR", strings.TrimSpace(r.settings.LocalModelDir))
	}

	if r.settings.LocalAutoStart {
		_ = os.Setenv("TF_LOCAL_AUTOSTART", "1")
	} else {
		_ = os.Setenv("TF_LOCAL_AUTOSTART", "0")
	}
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
func (r *SecureSettingsRepositoryImpl) GetProviderID() string {
	raw := strings.TrimSpace(r.settings.ProviderID)
	if raw == "" {
		if r.settings.UseOfficialAPI {
			return entities.ProviderGoogleOfficial
		}
		return entities.ProviderGoogleUnofficial
	}
	return entities.NormalizeProviderID(raw)
}

func (r *SecureSettingsRepositoryImpl) SetProviderID(providerID string) error {
	normalized := entities.NormalizeProviderID(providerID)
	r.settings.ProviderID = normalized
	r.settings.UseOfficialAPI = normalized == entities.ProviderGoogleOfficial
	r.saveSettings()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetUseOfficialAPI() bool {
	return r.settings.UseOfficialAPI
}

func (r *SecureSettingsRepositoryImpl) SetUseOfficialAPI(useOfficial bool) error {
	r.settings.UseOfficialAPI = useOfficial
	if useOfficial {
		r.settings.ProviderID = entities.ProviderGoogleOfficial
	} else if strings.TrimSpace(r.settings.ProviderID) == "" || r.settings.ProviderID == entities.ProviderGoogleOfficial {
		r.settings.ProviderID = entities.ProviderGoogleUnofficial
	}
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

func (r *SecureSettingsRepositoryImpl) GetCostTrackingEnabled() bool {
	return r.settings.CostTrackingEnabled
}

func (r *SecureSettingsRepositoryImpl) SetCostTrackingEnabled(enabled bool) error {
	r.settings.CostTrackingEnabled = enabled
	r.saveSettings()
	r.applyLocalEnvironment()
	return nil
}

// Local model settings
func (r *SecureSettingsRepositoryImpl) GetLocalServiceURL() string {
	return r.settings.LocalServiceURL
}

func (r *SecureSettingsRepositoryImpl) SetLocalServiceURL(url string) error {
	r.settings.LocalServiceURL = strings.TrimSpace(url)
	r.saveSettings()
	r.applyLocalEnvironment()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetLocalModelDir() string {
	return r.settings.LocalModelDir
}

func (r *SecureSettingsRepositoryImpl) SetLocalModelDir(path string) error {
	r.settings.LocalModelDir = strings.TrimSpace(path)
	r.saveSettings()
	r.applyLocalEnvironment()
	return nil
}

func (r *SecureSettingsRepositoryImpl) GetLocalAutoStart() bool {
	return r.settings.LocalAutoStart
}

func (r *SecureSettingsRepositoryImpl) SetLocalAutoStart(enabled bool) error {
	r.settings.LocalAutoStart = enabled
	r.saveSettings()
	r.applyLocalEnvironment()
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
