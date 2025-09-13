package main

import (
	"embed"
	"log"
	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	// Initialize logger
	if err := utils.InitLogger(utils.INFO, "translationfiestago.log"); err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}

	logger := utils.GetLogger()
	logger.Info("TranslationFiestaGo starting...")

	// Initialize repositories
	settingsRepo := repositories.NewSettingsRepository("settings.json")
	translationRepo := repositories.NewTranslationRepository()
	fileRepo := repositories.NewFileRepository()

	// Initialize use cases
	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)
	fileUseCases := usecases.NewFileUseCases(fileRepo)

	// Create an instance of the app structure
	app := NewApp(logger, translationUseCases, fileUseCases, settingsRepo)

	// Create application with options
	err := wails.Run(&options.App{
		Title:  "TranslationFiestaGo",
		Width:  1024,
		Height: 768,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 27, G: 38, B: 54, A: 1},
		OnStartup:        app.startup,
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
