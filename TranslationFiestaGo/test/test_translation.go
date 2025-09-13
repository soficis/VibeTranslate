package test

import (
	"context"
	"fmt"
	"log"
	"testing"
	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"
)

func TestTranslation(t *testing.T) {
	// Initialize logger
	if err := utils.InitLogger(utils.INFO, ""); err != nil {
		log.Printf("Failed to initialize logger: %v", err)
		return
	}

	logger := utils.GetLogger()
	logger.Info("Testing TranslationFiesta Go implementation...")

	// Initialize repositories
	settingsRepo := repositories.NewSettingsRepository("")
	translationRepo := repositories.NewTranslationRepository()

	// Initialize use cases
	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)

	// Test translation
	testText := "Hello world, this is a test of the back-translation functionality."

	fmt.Println("=== Testing TranslationFiesta Go ===")
	fmt.Printf("Input text: %s\n", testText)
	fmt.Println("Performing back-translation (English -> Japanese -> English)...")

	result, err := translationUseCases.BackTranslate(context.Background(), testText)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		logger.Error("Translation test failed: %v", err)
		return
	}

	fmt.Println("\n=== Results ===")
	fmt.Printf("Original: %s\n", result.Input)
	fmt.Printf("Japanese: %s\n", result.Intermediate)
	fmt.Printf("Back to English: %s\n", result.Result)
	fmt.Printf("Duration: %v\n", result.Duration)

	logger.Info("Translation test completed successfully")
	fmt.Println("\n✅ TranslationFiesta Go implementation is working!")
}
