package test

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"
)

func TestTranslationBackTranslate(t *testing.T) {
	if err := utils.InitLogger(utils.INFO, ""); err != nil {
		t.Fatalf("failed to initialize logger: %v", err)
	}

	settingsRepo := repositories.NewSettingsRepository("")
	translationRepo := repositories.NewTranslationRepository()

	if err := settingsRepo.SetProviderID(entities.ProviderLocal); err != nil {
		t.Fatalf("failed to set provider: %v", err)
	}

	if err := os.Setenv("TF_LOCAL_FIXTURE", "1"); err != nil {
		t.Fatalf("failed to set TF_LOCAL_FIXTURE: %v", err)
	}
	if err := os.Setenv("TF_LOCAL_AUTOSTART", "1"); err != nil {
		t.Fatalf("failed to set TF_LOCAL_AUTOSTART: %v", err)
	}
	if cwd, err := os.Getwd(); err == nil {
		scriptPath := filepath.Clean(filepath.Join(cwd, "..", "..", "TranslationFiestaLocal", "local_service.py"))
		if err := os.Setenv("TF_LOCAL_SCRIPT", scriptPath); err != nil {
			t.Fatalf("failed to set TF_LOCAL_SCRIPT: %v", err)
		}
	}

	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)

	input := "Hello world, this is a test of the back-translation functionality."
	result, err := translationUseCases.BackTranslate(context.Background(), input)
	if err != nil {
		t.Fatalf("BackTranslate failed: %v", err)
	}

	if result.Input == "" {
		t.Fatalf("expected input to be populated")
	}
	if result.Intermediate == "" {
		t.Fatalf("expected intermediate translation to be populated")
	}
	if result.Result == "" {
		t.Fatalf("expected final translation to be populated")
	}
}
