package main

import (
	"context"
	"fmt"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"
)

// App struct
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

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// Greet returns a greeting for the given name
func (a *App) Greet(name string) string {
	return fmt.Sprintf("Hello %s, welcome to TranslationFiestaGo!", name)
}

// BackTranslate performs a back-translation of the given text.
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
