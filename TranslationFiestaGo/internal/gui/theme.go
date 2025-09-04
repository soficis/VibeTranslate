package gui

import (
	"image/color"
	"translationfiestago/internal/domain/repositories"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/theme"
)

// TranslationTheme implements a custom theme for the application
type TranslationTheme struct {
	settingsRepo repositories.SettingsRepository
	currentTheme string
}

// Ensure TranslationTheme implements fyne.Theme
var _ fyne.Theme = (*TranslationTheme)(nil)

// NewTranslationTheme creates a new translation theme
func NewTranslationTheme(settingsRepo repositories.SettingsRepository) *TranslationTheme {
	currentTheme := "light"
	if settingsRepo != nil {
		currentTheme = settingsRepo.GetTheme()
	}

	return &TranslationTheme{
		settingsRepo: settingsRepo,
		currentTheme: currentTheme,
	}
}

// PrimaryColor returns the primary color
func (t *TranslationTheme) PrimaryColor() color.Color {
	return theme.DefaultTheme().PrimaryColor()
}

// HyperlinkColor returns the hyperlink color
func (t *TranslationTheme) HyperlinkColor() color.Color {
	return theme.DefaultTheme().HyperlinkColor()
}

// TextColor returns the text color
func (t *TranslationTheme) TextColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0xFF, G: 0xFF, B: 0xFF, A: 0xFF} // White
	}
	return color.NRGBA{R: 0x21, G: 0x21, B: 0x21, A: 0xFF} // Dark gray
}

// BackgroundColor returns the background color
func (t *TranslationTheme) BackgroundColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0x30, G: 0x30, B: 0x30, A: 0xFF} // Dark gray
	}
	return color.NRGBA{R: 0xF5, G: 0xF5, B: 0xF5, A: 0xFF} // Light gray
}

// ButtonColor returns the button color
func (t *TranslationTheme) ButtonColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0x50, G: 0x50, B: 0x50, A: 0xFF} // Medium gray
	}
	return color.NRGBA{R: 0xE0, G: 0xE0, B: 0xE0, A: 0xFF} // Light gray
}

// DisabledButtonColor returns the disabled button color
func (t *TranslationTheme) DisabledButtonColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0x40, G: 0x40, B: 0x40, A: 0xFF} // Darker gray
	}
	return color.NRGBA{R: 0xC0, G: 0xC0, B: 0xC0, A: 0xFF} // Gray
}

// DisabledTextColor returns the disabled text color
func (t *TranslationTheme) DisabledTextColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0x80, G: 0x80, B: 0x80, A: 0xFF} // Light gray
	}
	return color.NRGBA{R: 0x80, G: 0x80, B: 0x80, A: 0xFF} // Gray
}

// FocusColor returns the focus color
func (t *TranslationTheme) FocusColor() color.Color {
	return theme.DefaultTheme().FocusColor()
}

// PlaceHolderColor returns the placeholder color
func (t *TranslationTheme) PlaceHolderColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0xA0, G: 0xA0, B: 0xA0, A: 0xFF} // Light gray
	}
	return color.NRGBA{R: 0x88, G: 0x88, B: 0x88, A: 0xFF} // Medium gray
}

// ScrollBarColor returns the scrollbar color
func (t *TranslationTheme) ScrollBarColor() color.Color {
	if t.currentTheme == "dark" {
		return color.NRGBA{R: 0x60, G: 0x60, B: 0x60, A: 0xFF} // Medium gray
	}
	return color.NRGBA{R: 0xB0, G: 0xB0, B: 0xB0, A: 0xFF} // Light gray
}

// ShadowColor returns the shadow color
func (t *TranslationTheme) ShadowColor() color.Color {
	return theme.DefaultTheme().ShadowColor()
}

// TextSize returns the text size
func (t *TranslationTheme) TextSize() float32 {
	return theme.DefaultTheme().TextSize()
}

// TextFont returns the text font
func (t *TranslationTheme) TextFont() fyne.Resource {
	return theme.DefaultTheme().TextFont()
}

// TextBoldFont returns the bold text font
func (t *TranslationTheme) TextBoldFont() fyne.Resource {
	return theme.DefaultTheme().TextBoldFont()
}

// TextItalicFont returns the italic text font
func (t *TranslationTheme) TextItalicFont() fyne.Resource {
	return theme.DefaultTheme().TextItalicFont()
}

// TextBoldItalicFont returns the bold italic text font
func (t *TranslationTheme) TextBoldItalicFont() fyne.Resource {
	return theme.DefaultTheme().TextBoldItalicFont()
}

// TextMonospaceFont returns the monospace text font
func (t *TranslationTheme) TextMonospaceFont() fyne.Resource {
	return theme.DefaultTheme().TextMonospaceFont()
}

// HeadingTextSize returns the heading text size
func (t *TranslationTheme) HeadingTextSize() float32 {
	return theme.DefaultTheme().HeadingTextSize()
}

// Icon returns the icon for the given name
func (t *TranslationTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

// SetTheme updates the current theme
func (t *TranslationTheme) SetTheme(themeName string) {
	t.currentTheme = themeName
	if t.settingsRepo != nil {
		t.settingsRepo.SetTheme(themeName)
	}
}
