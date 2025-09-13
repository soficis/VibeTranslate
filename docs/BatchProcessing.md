# Batch Processing

## Overview

The TranslationFiesta applications support batch processing, allowing you to translate multiple files or even entire directories of text documents at once. This feature significantly enhances productivity for users dealing with large volumes of content. This feature is available in the Python, Go, and WinUI implementations.

## Core Features

- **Directory-based Processing**: Select a directory, and the application will automatically find and process all supported text files within it.
- **Supported File Types**: Processes `.txt`, `.md` (Markdown), and `.html` files.
- **Real-time Progress Tracking**: Monitor the progress of batch operations with visual indicators and status updates.
- **Error Resilience**: The batch processor is designed to continue processing even if individual file translations encounter errors, logging the issues for review.
- **Quality Assessment Integration**: Automatically applies BLEU scoring and quality metrics to each processed file.
- **Batch Export**: Export all translated files into a structured output, optionally including quality reports.

## How It Works

The Batch Processor component iterates through the selected files or directories, reading each supported file, sending its content for translation, and then saving the translated output.

### File Handling

- **HTML Processing**: For `.html` files, the system intelligently extracts only the visible text content, ignoring scripts, styles, and other non-textual elements.
- **Markdown Processing**: `.md` files are treated as plain text, with Markdown syntax preserved in the output unless specifically configured otherwise.

### Output Structure

Translated files are typically saved to a designated output directory, often mirroring the original directory structure, with clear naming conventions to distinguish translated versions.

## Usage

### Starting a Batch Process

1. **Select Batch Mode**: In the application's UI, look for a "Batch Process" or "Process Directory" option.
2. **Choose Directory**: Select the input directory containing the files you wish to translate.
3. **Configure Options**: Specify output directory, desired export format, and any other relevant settings (e.g., API key if using official API).
4. **Start Processing**: Initiate the batch operation.

### Monitoring Progress

During batch processing, the application will provide feedback on:
- The current file being processed.
- The number of files completed versus total files.
- Any errors encountered during individual file processing.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`batch_processor.py`**: Contains the `BatchProcessor` class, which orchestrates the file reading, translation, and saving for batch operations.

### Go (`TranslationFiestaGo`)
- **`internal/domain/usecases/batch_processor.go`**: Implements the batch processing logic within the Clean Architecture.

### WinUI (`TranslationFiesta.WinUI`)
- **`BatchProcessor.cs`**: Implements the batch processing logic in C#.