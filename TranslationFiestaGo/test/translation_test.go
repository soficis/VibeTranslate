package test

import (
	"testing"

	"translationfiestago/internal/domain/entities"
)

func TestNormalizeProviderID(t *testing.T) {
	if entities.NormalizeProviderID("google_unofficial") != entities.ProviderGoogleUnofficial {
		t.Fatal("expected google_unofficial to normalize to google_unofficial")
	}

	if entities.NormalizeProviderID("anything_else") != entities.ProviderGoogleUnofficial {
		t.Fatal("expected unknown provider to normalize to google_unofficial")
	}
}
