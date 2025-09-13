/// BLEU Score Calculator for Translation Quality Assessment
/// Provides BLEU score calculation for back-translation quality assessment
library;

import 'dart:math' as math;

class BLEUScorer {
  final int maxNGrams;

  BLEUScorer({this.maxNGrams = 4});

  /// Calculate BLEU score between reference and candidate text
  double calculateBleu(String reference, String candidate) {
    if (reference.trim().isEmpty || candidate.trim().isEmpty) {
      return 0;
    }

    final referenceTokens = _tokenize(reference);
    final candidateTokens = _tokenize(candidate);

    if (referenceTokens.isEmpty || candidateTokens.isEmpty) {
      return 0;
    }

    // Calculate precision for each n-gram order
    var precision = 1.0;
    for (var n = 1; n <= maxNGrams && n <= candidateTokens.length; n++) {
      final candidateNGrams = _getNGrams(candidateTokens, n);
      final referenceNGrams = _getNGrams(referenceTokens, n);

      if (candidateNGrams.isEmpty) continue;

      final referenceCounts = <String, int>{};
      for (final ngram in referenceNGrams) {
        referenceCounts[ngram] = (referenceCounts[ngram] ?? 0) + 1;
      }

      var matches = 0;
      for (final ngram in candidateNGrams) {
        if (referenceCounts.containsKey(ngram) && referenceCounts[ngram]! > 0) {
          matches++;
          referenceCounts[ngram] = referenceCounts[ngram]! - 1;
        }
      }

      final ngramPrecision = matches / candidateNGrams.length;
      precision *= ngramPrecision;
    }

    // Apply geometric mean
    precision = math.pow(precision, 1.0 / maxNGrams) as double;

    // Calculate brevity penalty
    final brevityPenalty = _calculateBrevityPenalty(
      referenceTokens.length,
      candidateTokens.length,
    );

    return precision * brevityPenalty;
  }

  /// Get confidence level and description based on BLEU score
  (String level, String description) getConfidenceLevel(double bleuScore) {
    if (bleuScore >= 0.8) {
      return (
        'High',
        'Excellent translation quality - minimal loss of meaning'
      );
    } else if (bleuScore >= 0.6) {
      return (
        'Medium-High',
        'Good translation quality - some minor differences'
      );
    } else if (bleuScore >= 0.4) {
      return (
        'Medium',
        'Moderate translation quality - noticeable differences'
      );
    } else if (bleuScore >= 0.2) {
      return (
        'Low-Medium',
        'Poor translation quality - significant differences'
      );
    } else {
      return ('Low', 'Very poor translation quality - major loss of meaning');
    }
  }

  /// Assess translation quality using BLEU score
  TranslationQualityAssessment assessTranslationQuality(
    String originalText,
    String backtranslatedText,
  ) {
    final bleuScore = calculateBleu(originalText, backtranslatedText);
    final (confidenceLevel, description) = getConfidenceLevel(bleuScore);

    return TranslationQualityAssessment(
      bleuScore: bleuScore,
      bleuPercentage: '${(bleuScore * 100).toStringAsFixed(2)}%',
      confidenceLevel: confidenceLevel,
      description: description,
      qualityRating: _getQualityRating(bleuScore),
      recommendations: _getRecommendations(bleuScore),
    );
  }

  /// Generate detailed quality report
  String getDetailedReport(
    String originalText,
    String intermediateText,
    String backtranslatedText,
  ) {
    final assessment =
        assessTranslationQuality(originalText, backtranslatedText);

    return '''
=== TRANSLATION QUALITY REPORT ===

Original Text Length: ${originalText.length} characters
Intermediate Text Length: ${intermediateText.length} characters
Back-translated Text Length: ${backtranslatedText.length} characters

BLEU Score: ${assessment.bleuPercentage}
Confidence Level: ${assessment.confidenceLevel}
Quality Rating: ${assessment.qualityRating}

Assessment: ${assessment.description}

Recommendations: ${assessment.recommendations}

=== TEXT COMPARISON ===
Original: ${_truncateText(originalText, 100)}
Back-translated: ${_truncateText(backtranslatedText, 100)}
${'=' * 50}
'''
        .trim();
  }

  List<String> _tokenize(String text) {
    // Simple tokenization: split on whitespace and punctuation
    final tokens = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();
    return tokens;
  }

  List<String> _getNGrams(List<String> tokens, int n) {
    if (tokens.length < n) return [];

    final ngrams = <String>[];
    for (var i = 0; i <= tokens.length - n; i++) {
      final ngram = tokens.sublist(i, i + n).join(' ');
      ngrams.add(ngram);
    }
    return ngrams;
  }

  double _calculateBrevityPenalty(int referenceLength, int candidateLength) {
    if (candidateLength >= referenceLength) return 1;

    return math.exp(referenceLength / candidateLength);
  }

  String _getQualityRating(double bleuScore) {
    if (bleuScore >= 0.8) return '★★★★★';
    if (bleuScore >= 0.6) return '★★★★☆';
    if (bleuScore >= 0.4) return '★★★☆☆';
    if (bleuScore >= 0.2) return '★★☆☆☆';
    return '★☆☆☆☆';
  }

  String _getRecommendations(double bleuScore) {
    if (bleuScore >= 0.8) {
      return 'Translation quality is excellent. No action needed.';
    } else if (bleuScore >= 0.6) {
      return 'Translation quality is good. Minor review recommended.';
    } else if (bleuScore >= 0.4) {
      return 'Translation quality is moderate. Consider manual review.';
    } else if (bleuScore >= 0.2) {
      return 'Translation quality is poor. Manual correction recommended.';
    } else {
      return 'Translation quality is very poor. Complete retranslation advised.';
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// Translation quality assessment result
class TranslationQualityAssessment {
  final double bleuScore;
  final String bleuPercentage;
  final String confidenceLevel;
  final String description;
  final String qualityRating;
  final String recommendations;

  TranslationQualityAssessment({
    required this.bleuScore,
    required this.bleuPercentage,
    required this.confidenceLevel,
    required this.description,
    required this.qualityRating,
    required this.recommendations,
  });

  @override
  String toString() {
    return 'BLEU: $bleuPercentage ($confidenceLevel) - $qualityRating';
  }
}

/// Global BLEU scorer instance
BLEUScorer? _globalBleuScorer;

/// Get global BLEU scorer instance
BLEUScorer getBleuScorer() {
  _globalBleuScorer ??= BLEUScorer();
  return _globalBleuScorer!;
}
