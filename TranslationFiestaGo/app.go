package main

import (
	"context"
	"fmt"
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
}

// NewApp creates a new App application struct
func NewApp(logger *utils.Logger, translationUseCases *usecases.TranslationUseCases, fileUseCases *usecases.FileUseCases, settingsRepo repositories.SettingsRepository) *App {
	return &App{
		logger:              logger,
		translationUseCases: translationUseCases,
		fileUseCases:        fileUseCases,
		settingsRepo:        settingsRepo,
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
