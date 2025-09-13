# Advanced Exporting

## Overview

The TranslationFiesta applications provide advanced exporting capabilities, allowing you to save your translation results in various formats, including PDF, DOCX, and HTML. This feature is available in the Python, Go, and WinUI implementations.

## Core Features

- **Multiple Formats**: Export your translations to PDF, DOCX, and HTML.
- **Custom Templates**: Use custom templates to control the layout and styling of your exported documents (Python and WinUI).
- **Metadata Inclusion**: Include metadata in your exported documents, such as the source and target languages, the date of the translation, and the quality metrics (BLEU score).
- **Batch Exporting**: Export the results of batch processing operations to a single file.

## How It Works

The Export Manager component is responsible for handling all export-related functionality. It takes the translation results and metadata as input and generates the output file in the specified format.

### Templates

The Python and WinUI implementations support the use of custom templates for exporting. This allows you to create your own layouts and styles for your exported documents.

- **Python**: Uses the Jinja2 templating engine.
- **WinUI**: Provides a built-in template editor for creating and managing templates.

### Metadata

The following metadata can be included in your exported documents:
- Source Language
- Target Language
- Date of Translation
- BLEU Score
- Quality Rating

## Usage

To export your translations, simply click the "Export" button in the application's UI and select your desired format. You can also configure the export settings in the application's preferences.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`export_manager.py`**: Contains the `ExportManager` class, which handles the core logic for exporting to PDF, DOCX, and HTML. It uses the `reportlab` library for PDF generation, `python-docx` for DOCX generation, and `Jinja2` for HTML templating.

### Go (`TranslationFiestaGo`)
- **`internal/export/export_manager.go`**: Implements the export functionality in Go.

### WinUI (`TranslationFiesta.WinUI`)
- **`ExportManager.cs`**: Implements the export functionality in C#. It uses the `PdfSharp` library for PDF generation and `Open-XML-SDK` for DOCX generation.
- **`TemplateEditor.xaml`** and **`TemplateManager.cs`**: Provide the UI and logic for the template editor.