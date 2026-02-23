package entities

import "strings"

const (
	ProviderLocal            = "local"
	ProviderGoogleUnofficial = "google_unofficial"
	ProviderGoogleOfficial   = "google_official"
)

func NormalizeProviderID(raw string) string {
	value := strings.TrimSpace(strings.ToLower(raw))
	switch value {
	case ProviderLocal:
		return ProviderLocal
	case ProviderGoogleOfficial:
		return ProviderGoogleOfficial
	case "official", "google", "google_cloud", "googlecloud":
		return ProviderGoogleOfficial
	case "unofficial", "google_unofficial_free", "google_free", "googletranslate":
		return ProviderGoogleUnofficial
	case "":
		return ProviderGoogleUnofficial
	default:
		return ProviderGoogleUnofficial
	}
}

func IsOfficialProvider(providerID string) bool {
	return NormalizeProviderID(providerID) == ProviderGoogleOfficial
}

