package main

import (
	"embed"
	"log"
	"path/filepath"
	"runtime"
	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	dataRoot, err := utils.DataRoot()
	if err != nil {
		log.Fatalf("Failed to resolve data root: %v", err)
	}

	// Initialize logger
	logPath := filepath.Join(dataRoot, "logs", "translationfiestago.log")
	if err := utils.InitLogger(utils.INFO, logPath); err != nil {
		log.Fatalf("Failed to initialize logger: %v", err)
	}

	logger := utils.GetLogger()
	logger.Info("TranslationFiestaGo starting with data root: %s", dataRoot)

	// Initialize repositories
	settingsRepo := repositories.NewSettingsRepository(filepath.Join(dataRoot, "settings.json"))
	translationRepo := repositories.NewTranslationRepository(filepath.Join(dataRoot, "tm_cache.json"))
	fileRepo := repositories.NewFileRepository()

	// Initialize use cases
	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)
	fileUseCases := usecases.NewFileUseCases(fileRepo)

	// Create an instance of the app structure
	app := NewApp(logger, translationUseCases, fileUseCases, settingsRepo)

	var windowsOptions *windows.Options
	if runtime.GOOS == "windows" {
		windowsOptions = &windows.Options{
			WebviewUserDataPath: filepath.Join(dataRoot, "webview2"),
		}

		if bundledRuntimePath, ok := utils.BundledWebView2RuntimePath(); ok {
			windowsOptions.WebviewBrowserPath = bundledRuntimePath
			logger.Info("Using bundled WebView2 runtime: %s", bundledRuntimePath)
		}
	}

	// Create application with options
	err = wails.Run(&options.App{
		Title:  "TranslationFiesta Go",
		Width:  1024,
		Height: 768,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 15, G: 20, B: 25, A: 1},
		OnStartup:        app.startup,
		Bind: []interface{}{
			app,
		},
		Windows: windowsOptions,
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
