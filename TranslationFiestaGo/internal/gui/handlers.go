package gui

import (
	"context"
	"fmt"
	"path/filepath"
	"time"
	"translationfiestago/internal/domain/entities"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/storage"
)

// setupMenu sets up the application menu
func (app *GUIApp) setupMenu() {
	menu := fyne.NewMainMenu(
		fyne.NewMenu("File",
			fyne.NewMenuItem("Load File", app.loadFile),
			fyne.NewMenuItem("Save Result", app.saveResult),
			fyne.NewMenuItemSeparator(),
			fyne.NewMenuItem("Exit", func() { app.window.Close() }),
		),
		fyne.NewMenu("Edit",
			fyne.NewMenuItem("Copy Result", app.copyResult),
		),
	)

	app.window.SetMainMenu(menu)

	// Set up keyboard shortcuts
	app.window.Canvas().SetOnTypedKey(func(key *fyne.KeyEvent) {
		if key.Name == fyne.KeyS && fyne.CurrentDevice().IsKeyboardShortcut(fyne.KeyModifierControl) {
			app.saveResult()
		}
		if key.Name == fyne.KeyC && fyne.CurrentDevice().IsKeyboardShortcut(fyne.KeyModifierControl) {
			app.copyResult()
		}
		if key.Name == fyne.KeyO && fyne.CurrentDevice().IsKeyboardShortcut(fyne.KeyModifierControl) {
			app.loadFile()
		}
	})
}

// toggleTheme toggles between light and dark themes
func (app *GUIApp) toggleTheme() {
	currentTheme := app.settingsRepo.GetTheme()

	if currentTheme == "dark" {
		app.setLightTheme()
	} else {
		app.setDarkTheme()
	}
}

// setLightTheme sets the light theme
func (app *GUIApp) setLightTheme() {
	app.settingsRepo.SetTheme("light")
	app.themeToggle.SetText("🌙 Dark")
	app.updateTheme()
	app.logger.Info("Switched to light theme")
}

// setDarkTheme sets the dark theme
func (app *GUIApp) setDarkTheme() {
	app.settingsRepo.SetTheme("dark")
	app.themeToggle.SetText("☀️ Light")
	app.updateTheme()
	app.logger.Info("Switched to dark theme")
}

// updateTheme updates the UI theme
func (app *GUIApp) updateTheme() {
	// This would trigger a theme refresh in a real implementation
	// For now, we'll just update the button text
	currentTheme := app.settingsRepo.GetTheme()
	if currentTheme == "dark" {
		app.themeToggle.SetText("☀️ Light")
	} else {
		app.themeToggle.SetText("🌙 Dark")
	}
}

// toggleAPI toggles between official and unofficial API
func (app *GUIApp) toggleAPI() {
	useOfficial := app.settingsRepo.GetUseOfficialAPI()
	useOfficial = !useOfficial

	app.settingsRepo.SetUseOfficialAPI(useOfficial)

	if useOfficial {
		app.apiToggle.SetText("Using Official API")
		app.apiKeyEntry.Enable()
		app.setStatus("Official API enabled. Provide API key.", "orange")
	} else {
		app.apiToggle.SetText("Use Official API")
		app.apiKeyEntry.Disable()
		app.setStatus("Using unofficial API.", "blue")
	}

	app.logger.Info("API mode changed: official=%v", useOfficial)
}

// loadFile loads a file for translation
func (app *GUIApp) loadFile() {
	fd := dialog.NewFileOpen(func(reader fyne.URIReadCloser, err error) {
		if err != nil {
			app.logger.Error("File dialog error: %v", err)
			return
		}
		if reader == nil {
			return
		}
		defer reader.Close()

		// Read file content
		data := make([]byte, 1024*1024) // 1MB limit
		n, err := reader.Read(data)
		if err != nil && n == 0 {
			app.showError("Failed to read file", err)
			return
		}

		content := string(data[:n])

		// Process file based on type
		fileName := reader.URI().Name()
		ext := filepath.Ext(fileName)

		switch ext {
		case ".html", ".htm":
			// Extract text from HTML
			extracted, err := app.fileUseCase.ExtractTextFromHTML(content)
			if err != nil {
				app.showError("Failed to extract text from HTML", err)
				return
			}
			content = extracted
			app.setStatus(fmt.Sprintf("Loaded HTML: %s (%d chars extracted)", fileName, len(content)), "green")
		case ".txt", ".md", ".markdown":
			app.setStatus(fmt.Sprintf("Loaded %s: %s", entities.GetFileTypeName(entities.GetFileType(fileName)), fileName), "green")
		default:
			app.setStatus(fmt.Sprintf("Loaded: %s", fileName), "green")
		}

		// Set content in input field
		app.inputText.SetText(content)
		app.logger.Info("Loaded file: %s (%d chars)", fileName, len(content))

	}, app.window)

	fd.SetFilter(storage.NewExtensionFileFilter([]string{".txt", ".md", ".html"}))
	fd.Show()
}

// startTranslation starts the back-translation process
func (app *GUIApp) startTranslation() {
	if app.isTranslating {
		return
	}

	inputText := app.inputText.Text
	if inputText == "" {
		app.showError("No input", fmt.Errorf("please enter text to translate"))
		return
	}

	app.isTranslating = true
	app.setStatus("Starting back-translation...", "blue")
	app.showProgress(true)

	// Create cancellable context
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	app.cancelCtx = cancel

	// Run translation in background
	go func() {
		defer func() {
			app.isTranslating = false
			app.showProgress(false)
			cancel()
		}()

		result, err := app.translationUseCase.BackTranslate(ctx, inputText)
		if err != nil {
			if ctx.Err() == context.Canceled {
				app.setStatus("Translation cancelled", "orange")
				return
			}
			app.showError("Translation failed", err)
			return
		}

		// Update UI with results
		app.intermediateText.SetText(result.Intermediate)
		app.resultText.SetText(result.Result)

		duration := result.Duration
		app.setStatus(fmt.Sprintf("Completed in %.2fs", duration.Seconds()), "green")
		app.logger.Info("Back-translation completed: %d -> %d -> %d chars",
			len(result.Input), len(result.Intermediate), len(result.Result))
	}()
}

// copyResult copies the result to clipboard
func (app *GUIApp) copyResult() {
	result := app.resultText.Text
	if result == "" {
		app.setStatus("Nothing to copy", "orange")
		return
	}

	app.window.Clipboard().SetContent(result)
	app.setStatus("Result copied to clipboard", "green")
	app.logger.Info("Result copied to clipboard (%d chars)", len(result))
}

// saveResult saves the result to a file
func (app *GUIApp) saveResult() {
	result := app.resultText.Text
	if result == "" {
		app.setStatus("Nothing to save", "orange")
		return
	}

	fd := dialog.NewFileSave(func(writer fyne.URIWriteCloser, err error) {
		if err != nil {
			app.logger.Error("Save dialog error: %v", err)
			return
		}
		if writer == nil {
			return
		}
		defer writer.Close()

		// Create content with all sections
		content := fmt.Sprintf("Input (English):\n%s\n\n", app.inputText.Text)
		content += fmt.Sprintf("Japanese (intermediate):\n%s\n\n", app.intermediateText.Text)
		content += fmt.Sprintf("Back to English:\n%s\n", result)

		_, err = writer.Write([]byte(content))
		if err != nil {
			app.showError("Failed to save file", err)
			return
		}

		fileName := writer.URI().Name()
		app.setStatus(fmt.Sprintf("Saved to %s", fileName), "green")
		app.logger.Info("Result saved to file: %s", fileName)

	}, app.window)

	fd.SetFileName("backtranslation.txt")
	fd.Show()
}

// loadSettings loads saved settings into the UI
func (app *GUIApp) loadSettings() {
	// Load theme
	theme := app.settingsRepo.GetTheme()
	if theme == "dark" {
		app.setDarkTheme()
	} else {
		app.setLightTheme()
	}

	// Load API settings
	useOfficial := app.settingsRepo.GetUseOfficialAPI()
	if useOfficial {
		app.settingsRepo.SetUseOfficialAPI(true)
		app.apiToggle.SetText("Using Official API")
		app.apiKeyEntry.Enable()
		app.apiKeyEntry.SetText(app.settingsRepo.GetAPIKey())
	}
}

// setStatus sets the status message
func (app *GUIApp) setStatus(message, color string) {
	app.statusLabel.SetText(message)
	// Color would be set via theme in a real implementation
}

// showProgress shows or hides the progress bar
func (app *GUIApp) showProgress(show bool) {
	if show {
		app.progressBar.Show()
		app.progressBar.SetValue(0)
		// In a real implementation, you'd animate this
	} else {
		app.progressBar.Hide()
	}
}

// showError shows an error dialog
func (app *GUIApp) showError(title string, err error) {
	dialog.ShowError(err, app.window)
	app.setStatus(fmt.Sprintf("Error: %s", err.Error()), "red")
	app.logger.Error("%s: %v", title, err)
}
