package entities

import (
	"time"
	"translationfiestago/internal/utils"
)

// Translation represents a translation operation
type Translation struct {
	ID             string
	SourceText     string
	SourceLang     string
	TargetLang     string
	TranslatedText string
	Timestamp      time.Time
	Error          error
}

// TranslationRequest represents a request for translation
type TranslationRequest struct {
	Text       string
	SourceLang string
	TargetLang string
	ProviderID string
	APIKey     string
}

// TranslationResult represents the result of a translation operation
type TranslationResult struct {
	OriginalText   string
	TranslatedText string
	SourceLang     string
	TargetLang     string
	Error          error
	Timestamp      time.Time
}

// BackTranslation represents a full back-translation operation
type BackTranslation struct {
	Input             string
	Intermediate      string
	Result            string
	SourceLang        string
	IntermediateLang  string
	FinalLang         string
	Error             error
	Timestamp         time.Time
	Duration          time.Duration
	QualityAssessment *utils.TranslationQualityAssessment
}
