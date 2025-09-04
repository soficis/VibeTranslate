package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"
	"time"
	"translationfiestago/internal/data/repositories"
	"translationfiestago/internal/domain/entities"
	"translationfiestago/internal/domain/usecases"
	"translationfiestago/internal/utils"
)

func main() {
	// Initialize logger
	if err := utils.InitLogger(utils.INFO, "translationfiestago-cli.log"); err != nil {
		log.Printf("Failed to initialize logger: %v", err)
		os.Exit(1)
	}

	logger := utils.GetLogger()
	logger.Info("TranslationFiesta Go CLI starting...")

	// Initialize repositories
	settingsRepo := repositories.NewSettingsRepository("")
	translationRepo := repositories.NewTranslationRepository()
	fileRepo := repositories.NewFileRepository()

	// Initialize use cases
	translationUseCases := usecases.NewTranslationUseCases(translationRepo, settingsRepo)
	fileUseCases := usecases.NewFileUseCases(fileRepo)

	// CLI interface
	scanner := bufio.NewScanner(os.Stdin)

	fmt.Println("=== TranslationFiesta Go CLI ===")
	fmt.Println("Commands:")
	fmt.Println("  translate <text>    - Translate text")
	fmt.Println("  file <path>        - Load and translate file")
	fmt.Println("  set-api <key>      - Set official API key")
	fmt.Println("  toggle-api         - Toggle between official/unofficial API")
	fmt.Println("  quit               - Exit")
	fmt.Println()

	for {
		fmt.Print("> ")
		if !scanner.Scan() {
			break
		}

		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}

		parts := strings.SplitN(line, " ", 2)
		command := parts[0]
		args := ""
		if len(parts) > 1 {
			args = strings.TrimSpace(parts[1])
		}

		switch command {
		case "quit", "exit", "q":
			logger.Info("CLI shutting down")
			return

		case "translate", "t":
			if args == "" {
				fmt.Println("Error: Please provide text to translate")
				continue
			}
			performTranslation(translationUseCases, args, logger)

		case "file", "f":
			if args == "" {
				fmt.Println("Error: Please provide file path")
				continue
			}
			loadAndTranslateFile(fileUseCases, translationUseCases, args, logger)

		case "set-api":
			if args == "" {
				fmt.Println("Error: Please provide API key")
				continue
			}
			err := settingsRepo.SetAPIKey(args)
			if err != nil {
				fmt.Printf("Error setting API key: %v\n", err)
			} else {
				fmt.Println("API key set successfully")
				logger.Info("Official API key configured")
			}

		case "toggle-api":
			useOfficial := settingsRepo.GetUseOfficialAPI()
			useOfficial = !useOfficial
			err := settingsRepo.SetUseOfficialAPI(useOfficial)
			if err != nil {
				fmt.Printf("Error toggling API: %v\n", err)
			} else {
				if useOfficial {
					fmt.Println("Switched to official Google Cloud Translation API")
				} else {
					fmt.Println("Switched to unofficial translate.googleapis.com API")
				}
				logger.Info(fmt.Sprintf("API mode changed: official=%v", useOfficial))
			}

		case "status":
			useOfficial := settingsRepo.GetUseOfficialAPI()
			apiKey := settingsRepo.GetAPIKey()
			sourceLang := settingsRepo.GetSourceLanguage()
			intermediateLang := settingsRepo.GetIntermediateLanguage()

			fmt.Printf("API Mode: %s\n", map[bool]string{true: "Official", false: "Unofficial"}[useOfficial])
			if useOfficial {
				if apiKey != "" {
					fmt.Printf("API Key: Configured\n")
				} else {
					fmt.Printf("API Key: Not configured\n")
				}
			}
			fmt.Printf("Source Language: %s\n", sourceLang)
			fmt.Printf("Intermediate Language: %s\n", intermediateLang)

		default:
			fmt.Printf("Unknown command: %s\n", command)
			fmt.Println("Available commands: translate, file, set-api, toggle-api, status, quit")
		}
	}
}

func performTranslation(translationUseCases *usecases.TranslationUseCases, text string, logger *utils.Logger) {
	fmt.Println("Translating...")
	logger.Info(fmt.Sprintf("Starting back-translation of %d characters", len(text)))

	start := time.Now()
	result, err := translationUseCases.BackTranslate(context.Background(), text)
	duration := time.Since(start)

	if err != nil {
		fmt.Printf("Translation failed: %v\n", err)
		logger.Error(fmt.Sprintf("Translation failed: %v", err))
		return
	}

	fmt.Println("\n=== Translation Result ===")
	fmt.Printf("Input (%d chars): %s\n", len(result.Input), result.Input)
	fmt.Printf("Japanese (%d chars): %s\n", len(result.Intermediate), result.Intermediate)
	fmt.Printf("Back to English (%d chars): %s\n", len(result.Result), result.Result)
	fmt.Printf("Duration: %v\n", duration)

	logger.Info(fmt.Sprintf("Back-translation completed in %v: %d -> %d -> %d chars",
		duration, len(result.Input), len(result.Intermediate), len(result.Result)))
}

func loadAndTranslateFile(fileUseCases *usecases.FileUseCases, translationUseCases *usecases.TranslationUseCases, filePath string, logger *utils.Logger) {
	fmt.Printf("Loading file: %s\n", filePath)

	fileInfo, err := fileUseCases.LoadFile(filePath)
	if err != nil {
		fmt.Printf("Failed to load file: %v\n", err)
		logger.Error(fmt.Sprintf("Failed to load file %s: %v", filePath, err))
		return
	}

	fmt.Printf("Loaded %s file (%d chars)\n", entities.GetFileTypeName(fileInfo.Type), len(fileInfo.Content))

	// Translate the content
	performTranslation(translationUseCases, fileInfo.Content, logger)
}
