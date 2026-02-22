package services

import (
	"context"

	"translationfiestago/internal/domain/entities"
)

// TranslateLocal performs translation using the local offline service.
func (ts *TranslationService) TranslateLocal(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	ts.logger.Debug("Local translation: %s -> %s -> %s", sourceLang, targetLang, text)
	return ts.local.Translate(ctx, text, sourceLang, targetLang)
}
