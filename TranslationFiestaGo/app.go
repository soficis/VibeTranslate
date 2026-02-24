package main

import (
	"context"
	"fmt"
	"translationfiestago/internal/data/services"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"
)

type App struct {
	ctx                 context.Context
	logger              *utils.Logger
	translationUseCases *usecases.TranslationUseCases
	fileUseCases        *usecases.FileUseCases
	settingsRepo        repositories.SettingsRepository
	localClient         *services.LocalServiceClient
}

// NewApp creates a new App application struct
func NewApp(logger *utils.Logger, translationUseCases *usecases.TranslationUseCases, fileUseCases *usecases.FileUseCases, settingsRepo repositories.SettingsRepository) *App {
	httpClient := utils.NewHTTPClient()
	return &App{
		logger:              logger,
		translationUseCases: translationUseCases,
		fileUseCases:        fileUseCases,
		settingsRepo:        settingsRepo,
		localClient:         services.NewLocalServiceClient(httpClient),
	}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func (a *App) Greet(name string) string {
	return fmt.Sprintf("Hello %s, welcome to TranslationFiestaGo!", name)
}

func (a *App) BackTranslate(text string) (map[string]interface{}, error) {
	result, err := a.translationUseCases.BackTranslate(a.ctx, text)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"input":        result.Input,
		"intermediate": result.Intermediate,
		"result":       result.Result,
		"duration":     result.Duration.Seconds(),
	}, nil
}

func (a *App) GetProviderID() string {
	return a.settingsRepo.GetProviderID()
}

func (a *App) SetProviderID(providerID string) error {
	return a.settingsRepo.SetProviderID(providerID)
}

func (a *App) GetLocalServiceURL() string {
	return a.settingsRepo.GetLocalServiceURL()
}

func (a *App) SetLocalServiceURL(url string) error {
	return a.settingsRepo.SetLocalServiceURL(url)
}

func (a *App) GetLocalModelDir() string {
	return a.settingsRepo.GetLocalModelDir()
}

func (a *App) SetLocalModelDir(path string) error {
	return a.settingsRepo.SetLocalModelDir(path)
}

func (a *App) GetLocalAutoStart() bool {
	return a.settingsRepo.GetLocalAutoStart()
}

func (a *App) SetLocalAutoStart(enabled bool) error {
	return a.settingsRepo.SetLocalAutoStart(enabled)
}

func (a *App) GetLocalModelsStatus() (string, error) {
	return a.localClient.ModelsStatus(a.ctx)
}

func (a *App) VerifyLocalModels() (string, error) {
	return a.localClient.ModelsVerify(a.ctx)
}

func (a *App) RemoveLocalModels() (string, error) {
	return a.localClient.ModelsRemove(a.ctx)
}

func (a *App) InstallDefaultLocalModels() (string, error) {
	return a.localClient.ModelsInstallDefault(a.ctx)
}
