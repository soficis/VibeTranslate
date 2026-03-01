package test

import (
	"testing"

	"translationfiestago/internal/domain/entities"
)

func TestNormalizeProviderID(t *testing.T) {
	aliases := []string{
		"google_unofficial",
		"unofficial",
		"google_unofficial_free",
		"google_free",
		"googletranslate",
		"",
		" GOOGLE_UNOFFICIAL ",
		"unknown_provider",
	}

	for _, alias := range aliases {
		if entities.NormalizeProviderID(alias) != entities.ProviderGoogleUnofficial {
			t.Fatalf("expected %q to normalize to google_unofficial", alias)
		}
	}
}
