package test

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"testing"
	"translationfiestago/internal/data/repositories"
)

func TestMain(m *testing.M) {
	fmt.Println("Testing Secure Storage Implementation")
	fmt.Println("==================================================")

	// Run tests
	code := m.Run()

	fmt.Println("\n==================================================")
	fmt.Println("Secure Storage Test Completed!")
	os.Exit(code)
}

func TestSecureStorage(t *testing.T) {

	// Test secure storage directly
	fmt.Println("\n1. Testing Secure Storage Interface:")

	secureStorage := repositories.NewSecureStorage("TranslationFiestaGoTest")

	// Get storage info
	info := secureStorage.GetStorageInfo()
	fmt.Printf("Platform: %s\n", info["platform"])
	fmt.Printf("Keyring Available: %v\n", info["keyring_available"])
	fmt.Printf("Fallback Available: %v\n", info["fallback_available"])
	fmt.Printf("Service Name: %s\n", info["service_name"])

	// Test API key storage
	testKey := "test_api_key_12345"
	testValue := "sk-test12345678901234567890"

	fmt.Println("\n2. Testing API Key Storage:")

	// Store API key
	fmt.Printf("Storing API key: %s\n", testValue[:20]+"...")
	err := secureStorage.StoreAPIKey(testKey, testValue)
	if err != nil {
		log.Printf("Failed to store API key: %v", err)
	} else {
		fmt.Println("✓ API key stored successfully")
	}

	// Retrieve API key
	retrievedKey, err := secureStorage.GetAPIKey(testKey)
	if err != nil {
		log.Printf("Failed to retrieve API key: %v", err)
	} else if retrievedKey == testValue {
		fmt.Println("✓ API key retrieved successfully and matches")
	} else {
		fmt.Printf("✗ API key mismatch: expected %s, got %s\n", testValue, retrievedKey)
	}

	// Test settings repository
	fmt.Println("\n3. Testing Settings Repository with Secure Storage:")

	// Create temporary settings file
	tempDir := os.TempDir()
	settingsFile := filepath.Join(tempDir, "test_settings.json")

	settingsRepo := repositories.NewSettingsRepository(settingsFile)

	// Test regular settings
	fmt.Println("Testing regular settings...")
	err = settingsRepo.SetTheme("dark")
	if err != nil {
		log.Printf("Failed to set theme: %v", err)
	} else {
		theme := settingsRepo.GetTheme()
		if theme == "dark" {
			fmt.Println("✓ Theme setting works correctly")
		} else {
			fmt.Printf("✗ Theme setting failed: expected 'dark', got '%s'\n", theme)
		}
	}

	// Test secure API key storage through settings
	fmt.Println("Testing secure API key through settings...")
	testAPIKey := "sk-secure12345678901234567890"

	err = settingsRepo.SetAPIKey(testAPIKey)
	if err != nil {
		log.Printf("Failed to set API key through settings: %v", err)
	} else {
		retrievedAPIKey := settingsRepo.GetAPIKey()
		if retrievedAPIKey == testAPIKey {
			fmt.Println("✓ API key storage through settings works correctly")
		} else {
			fmt.Printf("✗ API key through settings failed: expected %s, got %s\n", testAPIKey, retrievedAPIKey)
		}
	}

	// Clean up
	fmt.Println("\n4. Cleaning up...")

	// Delete API key
	err = secureStorage.DeleteAPIKey(testKey)
	if err != nil {
		log.Printf("Failed to delete test API key: %v", err)
	} else {
		fmt.Println("✓ Test API key deleted")
	}

	// Delete API key through settings
	err = settingsRepo.SetAPIKey("")
	if err != nil {
		log.Printf("Failed to delete API key through settings: %v", err)
	} else {
		fmt.Println("✓ API key deleted through settings")
	}

	// Remove temporary settings file
	os.Remove(settingsFile)
	fmt.Println("✓ Temporary files cleaned up")
}
