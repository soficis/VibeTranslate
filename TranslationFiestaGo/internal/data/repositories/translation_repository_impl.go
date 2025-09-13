package repositories

import (
	"context"
	"time"
	"translationfiestago/internal/data/services"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/repositories"
	"translationfiestago/internal/utils"
)

// TranslationRepositoryImpl implements the TranslationRepository interface
type TranslationRepositoryImpl struct {
	translationService *services.TranslationService
	logger             *utils.Logger
}

// NewTranslationRepository creates a new translation repository
func NewTranslationRepository() repositories.TranslationRepository {
	return &TranslationRepositoryImpl{
		translationService: services.NewTranslationService(),
		logger:             utils.GetLogger(),
	}
}

// Translate performs a single translation
func (r *TranslationRepositoryImpl) Translate(ctx context.Context, request entities.TranslationRequest) (*entities.TranslationResult, error) {
	r.logger.Debug("Translating text: %s -> %s", request.SourceLang, request.TargetLang)

	var result *entities.TranslationResult
	var err error

	if request.UseOfficial {
		result, err = r.translationService.TranslateOfficial(ctx, request.Text, request.SourceLang, request.TargetLang, request.APIKey)
	} else {
		result, err = r.translationService.TranslateUnofficial(ctx, request.Text, request.SourceLang, request.TargetLang)
	}

	if err != nil {
		r.logger.Error("Translation failed: %v", err)
		return nil, err
	}

	// Fill in the missing fields
	result.OriginalText = request.Text
	result.SourceLang = request.SourceLang
	result.TargetLang = request.TargetLang

	return result, nil
}

// TranslateUnofficial performs translation using the unofficial Google Translate API
func (r *TranslationRepositoryImpl) TranslateUnofficial(ctx context.Context, text, sourceLang, targetLang string) (*entities.TranslationResult, error) {
	result, err := r.translationService.TranslateUnofficial(ctx, text, sourceLang, targetLang)
	if err != nil {
		return nil, err
	}

	result.OriginalText = text
	result.SourceLang = sourceLang
	result.TargetLang = targetLang

	return result, nil
}

// TranslateOfficial performs translation using the official Google Cloud Translation API
func (r *TranslationRepositoryImpl) TranslateOfficial(ctx context.Context, text, sourceLang, targetLang, apiKey string) (*entities.TranslationResult, error) {
	result, err := r.translationService.TranslateOfficial(ctx, text, sourceLang, targetLang, apiKey)
	if err != nil {
		return nil, err
	}

	result.OriginalText = text
	result.SourceLang = sourceLang
	result.TargetLang = targetLang

	return result, nil
}

// BackTranslate performs a full back-translation (source -> intermediate -> source)
func (r *TranslationRepositoryImpl) BackTranslate(ctx context.Context, text, sourceLang, intermediateLang string, useOfficial bool, apiKey string) (*entities.BackTranslation, error) {
	r.logger.Info("Starting back-translation: %s -> %s -> %s", sourceLang, intermediateLang, sourceLang)

	startTime := time.Now()

	backTranslation := &entities.BackTranslation{
		Input:            text,
		SourceLang:       sourceLang,
		IntermediateLang: intermediateLang,
		FinalLang:        sourceLang,
		Timestamp:        startTime,
	}

	// Step 1: Translate source -> intermediate
	r.logger.Debug("Step 1: %s -> %s", sourceLang, intermediateLang)

	step1Result, err := r.Translate(ctx, entities.TranslationRequest{
		Text:        text,
		SourceLang:  sourceLang,
		TargetLang:  intermediateLang,
		UseOfficial: useOfficial,
		APIKey:      apiKey,
	})

	if err != nil {
		backTranslation.Error = err
		r.logger.Error("Back-translation step 1 failed: %v", err)
		return backTranslation, err
	}

	backTranslation.Intermediate = step1Result.TranslatedText
	r.logger.Info("Step 1 completed: %d chars", len(backTranslation.Intermediate))

	// Step 2: Translate intermediate -> source (back to original language)
	r.logger.Debug("Step 2: %s -> %s", intermediateLang, sourceLang)

	step2Result, err := r.Translate(ctx, entities.TranslationRequest{
		Text:        backTranslation.Intermediate,
		SourceLang:  intermediateLang,
		TargetLang:  sourceLang,
		UseOfficial: useOfficial,
		APIKey:      apiKey,
	})

	if err != nil {
		backTranslation.Error = err
		r.logger.Error("Back-translation step 2 failed: %v", err)
		return backTranslation, err
	}

	backTranslation.Result = step2Result.TranslatedText
	backTranslation.Duration = time.Since(startTime)

	// Calculate BLEU score for quality assessment
	bleuScorer := utils.GetBLEUScorer()
	qualityAssessment := bleuScorer.AssessTranslationQuality(text, backTranslation.Result)
	backTranslation.QualityAssessment = qualityAssessment

	r.logger.Info("Back-translation quality assessment: BLEU=%s, Confidence=%s",
		qualityAssessment.BLEUPercentage, qualityAssessment.ConfidenceLevel)
	r.logger.Info("Quality rating: %s", qualityAssessment.QualityRating)
	r.logger.Info("Recommendations: %s", qualityAssessment.Recommendations)

	r.logger.Info("Back-translation completed successfully: %d -> %d -> %d chars (took %v)",
		len(text), len(backTranslation.Intermediate), len(backTranslation.Result), backTranslation.Duration)

	return backTranslation, nil
}

// DetectLanguage implements the DetectLanguage method
func (r *TranslationRepositoryImpl) DetectLanguage(ctx context.Context, text string, apiKey string) (string, error) {
	return r.translationService.DetectLanguage(ctx, text, apiKey)
}
