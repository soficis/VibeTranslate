package entities

import "strings"

const (
	ProviderGoogleUnofficial = "google_unofficial"
)

func NormalizeProviderID(raw string) string {
	value := strings.TrimSpace(strings.ToLower(raw))
	switch value {
	case "unofficial", "google_unofficial_free", "google_free", "googletranslate":
		return ProviderGoogleUnofficial
	case "":
		return ProviderGoogleUnofficial
	default:
		return ProviderGoogleUnofficial
	}
}

