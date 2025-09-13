# EPUB Processing

## Overview

The TranslationFiesta applications can extract text from `.epub` files, allowing you to translate the content of e-books. This feature is available in the Python, Go, and Flutter implementations.

## Core Features

- **Chapter Extraction**: The system can extract the content of each chapter in an `.epub` file.
- **Text-Only Extraction**: The system extracts only the text content of the e-book, ignoring images and other non-textual elements.
- **Table of Contents**: The system can display the table of contents of the e-book, allowing you to select which chapters to translate.

## How It Works

The EPUB Processor component is responsible for handling all `.epub` file-related functionality. It uses a third-party library to parse the `.epub` file and extract its content.

### Chapter Selection

When you open an `.epub` file, the application will display a list of the chapters in the e-book. You can then select which chapters you want to translate.

## Usage

To translate an `.epub` file, simply open it in the application. The application will then display the table of contents, allowing you to select which chapters to translate.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`epub_processor.py`**: Contains the `EpubProcessor` class, which uses the `ebooklib` library to parse `.epub` files.

### Go (`TranslationFiestaGo`)
- **`internal/epub/epub_processor.go`**: Implements the EPUB processing logic in Go.

### Flutter (`TranslationFiestaFlutter`)
- **`lib/data/repositories/epub_repository_impl.dart`** and **`lib/domain/usecases/epub_usecases.dart`**: Implement the EPUB processing logic in Dart.