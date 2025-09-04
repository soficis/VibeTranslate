package main

import (
	"log"
	"os"
	"path/filepath"
	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/gui"
	"translationfiestago/internal/utils"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
)

func main() {
	// Initialize logger
	logFile := getLogFilePath()
	if err := utils.InitLogger(utils.INFO, logFile); err != nil {
		log.Printf("Failed to initialize logger: %v", err)
		// Continue without logging to file
		if err := utils.InitLogger(utils.INFO, ""); err != nil {
			log.Printf("Failed to initialize console logger: %v", err)
			os.Exit(1)
		}
	}

	logger := utils.GetLogger()
	logger.Info("TranslationFiestaGo starting...")

	// Initialize repositories
	settingsFile := getSettingsFilePath()
	settingsRepo := repositories.NewSettingsRepository(settingsFile)
	translationRepo := repositories.NewTranslationRepository()
	fileRepo := repositories.NewFileRepository()

	// Initialize use cases
	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)
	fileUseCases := usecases.NewFileUseCases(fileRepo)

	// Create Fyne app
	a := app.New()

	// Create custom theme
	customTheme := gui.NewTranslationTheme(settingsRepo)
	a.Settings().SetTheme(customTheme)

	// Create main window
	w := a.NewWindow("TranslationFiesta Go")
	w.SetMaster()

	// Create GUI
	guiApp := gui.NewGUIApp(w, translationUseCases, fileUseCases, settingsRepo, logger)

	// Set window size and position from settings
	width, height := settingsRepo.GetWindowSize()
	w.Resize(fyne.NewSize(float32(width), float32(height)))

	x, y := settingsRepo.GetWindowPosition()
	w.SetFixedSize(false)

	// Handle window close to save settings
	w.SetCloseIntercept(func() {
		// Save window size and position
		size := w.Canvas().Size()
		settingsRepo.SetWindowSize(int(size.Width), int(size.Height))

		pos := w.Position()
		settingsRepo.SetWindowPosition(int(pos.X), int(pos.Y))

		logger.Info("Application closing, settings saved")
		w.Close()
	})

	// Show the window
	w.ShowAndRun()

	logger.Info("TranslationFiestaGo shutting down")
}

// getLogFilePath returns the path for the log file
func getLogFilePath() string {
	userConfigDir, err := os.UserConfigDir()
	if err != nil {
		return "translationfiestago.log"
	}

	appDir := filepath.Join(userConfigDir, "TranslationFiestaGo")
	logFile := filepath.Join(appDir, "translationfiestago.log")

	return logFile
}

// getSettingsFilePath returns the path for the settings file
func getSettingsFilePath() string {
	userConfigDir, err := os.UserConfigDir()
	if err != nil {
		return "settings.json"
	}

	appDir := filepath.Join(userConfigDir, "TranslationFiestaGo")
	settingsFile := filepath.Join(appDir, "settings.json")

	return settingsFile
}
