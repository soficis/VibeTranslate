package repositories

import (
	"context"
	"translationfiestago/internal/domain/entities"
)

// TranslationRepository defines the interface for translation operations
type TranslationRepository interface {
	// Translate performs a single translation
	Translate(ctx context.Context, request entities.TranslationRequest) (*entities.TranslationResult, error)

	// TranslateUnofficial performs translation using the unofficial Google Translate API
	TranslateUnofficial(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error)

	// BackTranslate performs a full back-translation (source -> intermediate -> source)
	BackTranslate(ctx context.Context, text, sourceLang, intermediateLang, providerID string) (*entities.BackTranslation, error)
}
