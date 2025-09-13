# Translation Quality Metrics (BLEU Scoring)

## Overview

To help users assess the quality of translations, the TranslationFiesta applications include a built-in BLEU (Bilingual Evaluation Understudy) scoring system. This feature provides an objective measure of how closely the back-translated text matches the original source text.

## Core Features

- **BLEU Score Calculation**: The system calculates a BLEU score for each back-translation, providing a numerical representation of its quality.
- **Confidence Levels**: Based on the BLEU score, the system assigns a confidence level (e.g., High, Medium, Low) to each translation.
- **Quality Ratings**: A simple star rating (e.g., ★★★★★) is provided for a quick visual assessment of the translation's quality.
- **Detailed Reports**: The system can generate detailed reports that include the BLEU score, confidence level, and recommendations for improving the translation.

## How It Works

The BLEU score is calculated by comparing the n-grams (contiguous sequences of n items) of the back-translated text with the n-grams of the original text. A higher BLEU score indicates a better match and, therefore, a higher quality translation.

### Confidence Levels

The BLEU score is mapped to a set of confidence levels to make it easier to interpret:

| BLEU Score | Confidence Level |
|------------|------------------|
| > 0.6      | High             |
| 0.4 - 0.6  | Medium-High      |
| 0.2 - 0.4  | Medium           |
| 0.1 - 0.2  | Low-Medium       |
| < 0.1      | Low              |

### Recommendations

Based on the BLEU score, the system provides recommendations for how to improve the translation. For example, if the score is low, it might suggest rephrasing the original text or trying a different translation service.

## Usage

The BLEU score and quality assessment are automatically calculated for each back-translation. The results are displayed in the application's UI, typically alongside the back-translated text.

## Implementation Details

### Python (`TranslationFiestaPy`)
- **`bleu_scorer.py`**: Contains the `BLEUScorer` class, which implements the BLEU score calculation and quality assessment logic. It uses the `sacrebleu` library for the core calculation.

### Go (`TranslationFiestaGo`)
- **`internal/utils/bleu_scorer.go`**: Implements the BLEU scoring logic in Go.

### WinUI (`TranslationFiesta.WinUI`)
- **`BLEUScorer.cs`**: Implements the BLEU scoring logic in C#.

### F# (`TranslationFiestaFSharp`)
- **`BLEUScorer.fs`**: Implements the BLEU scoring logic in F#.

### Flutter (`TranslationFiestaFlutter`)
- **`lib/core/utils/bleu_scorer.dart`**: Implements the BLEU scoring logic in Dart.