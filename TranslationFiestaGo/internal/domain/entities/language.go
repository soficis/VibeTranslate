package entities

// Language represents a supported language
type Language struct {
	Code string
	Name string
}

// SupportedLanguages contains all available languages
var SupportedLanguages = []Language{
	{Code: "auto", Name: "Auto-detect"},
	{Code: "en", Name: "English"},
	{Code: "ja", Name: "Japanese"},
	{Code: "es", Name: "Spanish"},
	{Code: "fr", Name: "French"},
	{Code: "de", Name: "German"},
	{Code: "it", Name: "Italian"},
	{Code: "pt", Name: "Portuguese"},
	{Code: "ru", Name: "Russian"},
	{Code: "ko", Name: "Korean"},
	{Code: "zh", Name: "Chinese"},
}

// GetLanguageByCode finds a language by its code
func GetLanguageByCode(code string) *Language {
	for _, lang := range SupportedLanguages {
		if lang.Code == code {
			return &lang
		}
	}
	return nil
}

// GetLanguageName returns the display name for a language code
func GetLanguageName(code string) string {
	if lang := GetLanguageByCode(code); lang != nil {
		return lang.Name
	}
	return code
}
