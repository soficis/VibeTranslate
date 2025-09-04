package gui

import (
	"context"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

// GUIApp represents the main GUI application
type GUIApp struct {
	window             fyne.Window
	translationUseCase *usecases.TranslationUseCases
	fileUseCase        *usecases.FileUseCases
	settingsRepo       repositories.SettingsRepository
	logger             *utils.Logger

	// UI components
	inputText        *widget.Entry
	intermediateText *widget.Entry
	resultText       *widget.Entry
	statusLabel      *widget.Label
	progressBar      *widget.ProgressBar
	themeToggle      *widget.Button
	apiToggle        *widget.Button
	apiKeyEntry      *widget.Entry

	// State
	isTranslating bool
	cancelCtx     context.CancelFunc
}

// NewGUIApp creates a new GUI application
func NewGUIApp(window fyne.Window, translationUseCase *usecases.TranslationUseCases, fileUseCase *usecases.FileUseCases, settingsRepo repositories.SettingsRepository, logger *utils.Logger) *GUIApp {
	app := &GUIApp{
		window:             window,
		translationUseCase: translationUseCase,
		fileUseCase:        fileUseCase,
		settingsRepo:       settingsRepo,
		logger:             logger,
		isTranslating:      false,
	}

	app.createUI()
	app.setupMenu()
	app.loadSettings()

	return app
}

// createUI creates the main user interface
func (app *GUIApp) createUI() {
	// Create main components
	app.createTextAreas()
	app.createControlPanel()
	app.createStatusBar()

	// Layout
	leftPanel := container.NewVBox(
		app.createToolbar(),
		app.createInputSection(),
		app.createIntermediateSection(),
		app.createResultSection(),
	)

	rightPanel := container.NewVBox(
		app.createControlPanel(),
		app.createStatusBar(),
	)

	// Main layout
	mainContent := container.NewBorder(
		nil,                   // top
		app.createStatusBar(), // bottom
		nil,                   // left
		rightPanel,            // right
		container.NewBorder(
			app.createToolbar(), // top
			nil,                 // bottom
			nil,                 // left
			nil,                 // right
			container.NewVBox(
				app.createInputSection(),
				app.createIntermediateSection(),
				app.createResultSection(),
			),
		),
	)

	app.window.SetContent(mainContent)
}

// createTextAreas creates the text input/output areas
func (app *GUIApp) createTextAreas() {
	// Input text area
	app.inputText = widget.NewMultiLineEntry()
	app.inputText.SetPlaceHolder("Enter English text to translate...")
	app.inputText.Wrapping = fyne.TextWrapWord

	// Intermediate text area (read-only)
	app.intermediateText = widget.NewMultiLineEntry()
	app.intermediateText.SetPlaceHolder("Japanese intermediate result...")
	app.intermediateText.Disable()
	app.intermediateText.Wrapping = fyne.TextWrapWord

	// Result text area (read-only)
	app.resultText = widget.NewMultiLineEntry()
	app.resultText.SetPlaceHolder("Back-translated English result...")
	app.resultText.Disable()
	app.resultText.Wrapping = fyne.TextWrapWord
}

// createToolbar creates the top toolbar
func (app *GUIApp) createToolbar() *fyne.Container {
	// Theme toggle button
	app.themeToggle = widget.NewButton("🌙 Dark", app.toggleTheme)
	app.themeToggle.Resize(fyne.NewSize(80, 32))

	// Load file button
	loadBtn := widget.NewButton("📁 Load File", app.loadFile)
	loadBtn.Resize(fyne.NewSize(100, 32))

	// File info label
	fileInfoLabel := widget.NewLabel("")
	fileInfoLabel.Resize(fyne.NewSize(300, 32))

	return container.NewBorder(
		nil, nil, nil, nil,
		container.NewHBox(
			app.themeToggle,
			loadBtn,
			fileInfoLabel,
		),
	)
}

// createControlPanel creates the right-side control panel
func (app *GUIApp) createControlPanel() *fyne.Container {
	// API toggle
	app.apiToggle = widget.NewButton("Use Official API", app.toggleAPI)
	app.apiToggle.Resize(fyne.NewSize(140, 32))

	// API key entry
	apiKeyLabel := widget.NewLabel("API Key:")
	app.apiKeyEntry = widget.NewPasswordEntry()
	app.apiKeyEntry.SetPlaceHolder("Enter API key...")
	app.apiKeyEntry.Disable()

	// Translate button
	translateBtn := widget.NewButton("🔄 Backtranslate", app.startTranslation)
	translateBtn.Importance = widget.HighImportance
	translateBtn.Resize(fyne.NewSize(140, 40))

	// Copy result button
	copyBtn := widget.NewButton("📋 Copy Result", app.copyResult)
	copyBtn.Resize(fyne.NewSize(140, 32))

	// Save result button
	saveBtn := widget.NewButton("💾 Save Result", app.saveResult)
	saveBtn.Resize(fyne.NewSize(140, 32))

	return container.NewVBox(
		app.apiToggle,
		apiKeyLabel,
		app.apiKeyEntry,
		widget.NewSeparator(),
		translateBtn,
		copyBtn,
		saveBtn,
	)
}

// createStatusBar creates the status bar with progress indicator
func (app *GUIApp) createStatusBar() *fyne.Container {
	app.statusLabel = widget.NewLabel("Ready")
	app.progressBar = widget.NewProgressBar()
	app.progressBar.Hide()

	return container.NewBorder(
		nil, nil, nil, nil,
		container.NewHBox(
			app.statusLabel,
			app.progressBar,
		),
	)
}

// createInputSection creates the input text section
func (app *GUIApp) createInputSection() *fyne.Container {
	label := widget.NewLabelWithStyle("Input (English):", fyne.TextAlignLeading, fyne.TextStyle{Bold: true})

	scroll := container.NewScroll(app.inputText)
	scroll.SetMinSize(fyne.NewSize(600, 120))

	return container.NewBorder(
		label, nil, nil, nil,
		scroll,
	)
}

// createIntermediateSection creates the intermediate result section
func (app *GUIApp) createIntermediateSection() *fyne.Container {
	label := widget.NewLabelWithStyle("Japanese (intermediate):", fyne.TextAlignLeading, fyne.TextStyle{Bold: true})

	scroll := container.NewScroll(app.intermediateText)
	scroll.SetMinSize(fyne.NewSize(600, 120))

	return container.NewBorder(
		label, nil, nil, nil,
		scroll,
	)
}

// createResultSection creates the final result section
func (app *GUIApp) createResultSection() *fyne.Container {
	label := widget.NewLabelWithStyle("Back to English:", fyne.TextAlignLeading, fyne.TextStyle{Bold: true})

	scroll := container.NewScroll(app.resultText)
	scroll.SetMinSize(fyne.NewSize(600, 120))

	return container.NewBorder(
		label, nil, nil, nil,
		scroll,
	)
}
