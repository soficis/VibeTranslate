# VibeTranslate 🎉

[![GitHub Repository](https://img.shields.io/badge/GitHub-soficis/VibeTranslate-blue?logo=github)](https://github.com/soficis/VibeTranslate)

A collection of translation applications built in different languages and frameworks, all implementing the same core functionality: **English ↔ Japanese back-translation** for content quality evaluation and linguistic analysis.

## 🌟 Overview

VibeTranslate is a polyglot project showcasing how the same application can be implemented across multiple programming languages and UI frameworks. Each implementation maintains the same core features while leveraging language-specific strengths and platform capabilities.

### 🎯 Core Functionality
- **Back-translation**: English → Japanese → English using Google Translate APIs
- **File Import**: Load text from .txt, .md, and .html files
- **Dual API Support**: Unofficial (free) and Official Google Cloud Translation API
- **Modern UI**: Dark/Light themes, responsive design, progress indicators
- **Export Features**: Save results, copy to clipboard, file operations

### ✨ Advanced Features
- **Batch Processing**: Process entire directories of text files (implemented in Python, Go, WinUI; available in others).
- **Quality Metrics (BLEU)**: Assess translation quality with BLEU scores (implemented in Python, Go, F#, WinUI, C#; integrated with export and batch processing).
- **Cost Tracking**: Track API usage costs and set monthly budgets (implemented in Python, Go, WinUI; with persistent storage).
- **Advanced Exporting**: Export to PDF, DOCX, and HTML with custom templates (implemented in Python, Go, WinUI; F# supports as undocumented feature).
- **Secure Storage**: Securely store API keys using platform-specific features (Go uses keyring with AES fallback; WinUI uses DPAPI).
- **EPUB Processing**: Extract and translate text from .epub files (implemented in Flutter, Go; disabled in C#, not in others).
- **Translation Memory**: Cache translations to improve performance and reduce costs (implemented in Python, Go, WinUI, C#; missing in F#, Flutter).

## 📱 Applications

### 🐍 TranslationFiestaPy (Python)
**Original Implementation** - The foundation for all other ports

**Functionality**:
- Core: English ↔ Japanese back-translation, file import (.txt, .md, .html), dual API support (unofficial/official Google Cloud Translation).
- Advanced: Batch processing, BLEU scoring, cost tracking, advanced exporting, secure storage, translation memory.

**Architecture**: Modular design with dedicated modules for each feature (batch_processor.py, bleu_scorer.py, cost_tracker.py, etc.).

**Dependencies**: Google Translate API (unofficial/ official), Python 3.6+, Tkinter GUI, additional libraries for export and scoring.

**Integration Points**: Google Translate APIs, secure storage via environment variables, file system for batch operations.

**Framework**: Tkinter GUI

**Language**: Python 3.6+

**Best For**: Cross-platform compatibility, easy customization, educational reference.

### 🦀 TranslationFiestaGo (Go)
**Modern Systems Edition** - Clean Architecture implementation

**Functionality**:
- Core: English ↔ Japanese back-translation, file import, dual API support.
- Advanced: Batch processing, BLEU scoring, cost tracking, advanced exporting, secure storage, EPUB processing, translation memory.

**Architecture**: Clean Architecture with domain/usecases/repositories layers (internal/domain/usecases/, internal/data/repositories/), cross-cutting concerns (logging, utils), modular design.

**Dependencies**: Go 1.21+, Fyne (GUI), Google Translate APIs, go-keyring for secure storage.

**Integration Points**: Google Translate APIs, secure storage (keyring with AES encrypted file fallback), EPUS processing, cost tracking dashboard.

**Framework**: Fyne (GUI) + CLI

**Language**: Go 1.21+

**Best For**: Learning Clean Architecture, production CLI tools, cross-platform applications.

**Known Issues**: GUI version has OpenGL build issues on Windows; Security note: Go secure storage uses simple key derivation for AES fallback, recommended to use stronger derivation in production.

### 🎭 TranslationFiesta.WinUI (C#)
**Modern Windows Edition** - Windows 11 native app

**Functionality**:
- Core: Back-translation, file import, dual API support.
- Advanced: Batch processing, BLEU scoring, cost tracking, advanced exporting, secure storage, translation memory.

**Architecture**: MVVM pattern, modular design with dedicated classes (BatchProcessor.cs, CostTracker.cs, etc.).

**Dependencies**: Windows App SDK, .NET 9, Google Translate APIs, Windows DPAPI for secure storage.

**Integration Points**: Google Translate APIs, secure storage via DPAPI, batch operations via file system.

**Framework**: WinUI 3 (Windows App SDK)

**Language**: C# 12

**Best For**: Modern Windows experiences, app store distribution via MSIX.

### 🦋 TranslationFiestaFlutter (Dart)
**Cross-Platform Edition** - Modern mobile/desktop app

**Functionality**:
- Core: Back-translation, file import, dual API support.
- Advanced: EPUB processing (chapter selection, preview), secure storage, cost tracking.

**Architecture**: Clean Code architecture with domain/repositories/data layers (lib/domain/, lib/data/), provider pattern for state management.

**Dependencies**: Flutter 3.0+, Dart 3, Google Translate APIs, epub package for EPUB processing.

**Integration Points**: Google Translate APIs, secure storage via flutter_secure_storage, file picker, EPUB repository/usecases.

**Framework**: Flutter (Material Design)

**Language**: Dart 3

**Best For**: Cross-platform deployment, modern UI, interactive features like EPUB preview and surrealist themes.

**Feature Gap**: Missing translation memory implementation.

### ⚡ TranslationFiestaFSharp (F#)
**Functional Edition** - Feature-complete implementation

**Functionality**:
- Core: Back-translation, file import, dual API support.
- Advanced: Batch processing, BLEU scoring, cost tracking, advanced exporting with BLEU integration, secure storage, high error handling.

**Architecture**: Clean Code principles with immutability, modular design, dependency injection (e.g., BLEUScorer passed to ExportManager).

**Dependencies**: .NET 9, F# 8, Windows Forms, Google Translate APIs.

**Integration Points**: Google Translate APIs, secure storage via secure store pattern.

**Framework**: Windows Forms (.NET 9)

**Language**: F# 8

**Best For**: Production use, functional programming examples, comprehensive error handling.

**Feature Gap**: Missing translation memory implementation. **Undocumented Feature**: Advanced exporting with BLEU scoring.

### 🔷 TranslationFiestaCSharp (C#)
**WinForms Edition** - .NET 9 console application

**Functionality**:
- Core: Back-translation, file import, dual API support.
- Advanced: BLEU scoring, secure storage, translation memory.

**Architecture**: Object-oriented design, modular with dedicated classes.

**Dependencies**: .NET 9, C# 12, Windows Forms, Google Translate APIs.

**Integration Points**: Google Translate APIs, secure storage via SecureStore.

**Framework**: Windows Forms (.NET 9)

**Language**: C# 12

**Best For**: Windows-native performance, enterprise deployment.

**Feature Gap**: EPUB processing disabled (EpubProcessor.cs.disabled file present, indicating planned but not active feature).

## 🚀 Quick Start

For detailed setup and build instructions, please see the [`docs/SetupAndBuild.md`](docs/SetupAndBuild.md) file.

## 📊 Feature Comparison

For a detailed feature comparison across all implementations, please see the [`docs/FeatureComparison.md`](docs/FeatureComparison.md) file.

## 🤝 Contributing

We welcome contributions! Please see the [`docs/Contributing.md`](docs/Contributing.md) file for guidelines on how to get started.

## 📄 License

This project is provided for educational and development purposes. Usage of translation APIs should comply with respective terms of service.

## 🔒 Security Notes

- **Go Secure Storage**: Uses keyring for secure API key storage with AES encrypted file fallback. Key derivation for fallback is simple; recommend stronger derivation (e.g., PBKDF2) for production to address potential security gaps.
- All implementations use Google Translate APIs; ensure compliance with terms of service and handle API keys securely.

## ⚠️ Known Issues

- **Go GUI**: OpenGL build issues on Windows; CLI version works perfectly.
- **Feature Disparities**: Translation memory missing in F# and Flutter; EPUB processing disabled in C#; advanced exporting undocumented in F#.
- Full feature parity matrix available in [docs/FeatureComparison.md](docs/FeatureComparison.md).
