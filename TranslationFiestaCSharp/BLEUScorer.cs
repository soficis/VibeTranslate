using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace TranslationFiestaCSharp
{
    /// <summary>
    /// BLEU Score Calculator for Translation Quality Assessment
    /// </summary>
    public class BLEUScorer
    {
        private readonly int _maxNGrams;

        public BLEUScorer(int maxNGrams = 4)
        {
            _maxNGrams = maxNGrams;
        }

        /// <summary>
        /// Calculate BLEU score between reference and candidate text
        /// </summary>
        public double CalculateBleu(string reference, string candidate)
        {
            if (string.IsNullOrWhiteSpace(reference) || string.IsNullOrWhiteSpace(candidate))
                return 0.0;

            var referenceTokens = Tokenize(reference);
            var candidateTokens = Tokenize(candidate);

            if (referenceTokens.Count == 0 || candidateTokens.Count == 0)
                return 0.0;

            // Calculate precision for each n-gram order
            double precision = 1.0;
            for (int n = 1; n <= Math.Min(_maxNGrams, candidateTokens.Count); n++)
            {
                var candidateNGrams = GetNGrams(candidateTokens, n);
                var referenceNGrams = GetNGrams(referenceTokens, n);

                if (candidateNGrams.Count == 0)
                    continue;

                int matches = 0;
                var referenceCounts = new Dictionary<string, int>();

                // Count reference n-grams
                foreach (var ngram in referenceNGrams)
                {
                    if (!referenceCounts.ContainsKey(ngram))
                        referenceCounts[ngram] = 0;
                    referenceCounts[ngram]++;
                }

                // Count matches in candidate
                foreach (var ngram in candidateNGrams)
                {
                    if (referenceCounts.ContainsKey(ngram) && referenceCounts[ngram] > 0)
                    {
                        matches++;
                        referenceCounts[ngram]--;
                    }
                }

                double ngramPrecision = (double)matches / candidateNGrams.Count;
                precision *= ngramPrecision;
            }

            // Apply geometric mean
            precision = Math.Pow(precision, 1.0 / _maxNGrams);

            // Calculate brevity penalty
            double brevityPenalty = CalculateBrevityPenalty(referenceTokens.Count, candidateTokens.Count);

            return precision * brevityPenalty;
        }

        /// <summary>
        /// Get confidence level and description based on BLEU score
        /// </summary>
        public (string Level, string Description) GetConfidenceLevel(double bleuScore)
        {
            if (bleuScore >= 0.8)
                return ("High", "Excellent translation quality - minimal loss of meaning");
            else if (bleuScore >= 0.6)
                return ("Medium-High", "Good translation quality - some minor differences");
            else if (bleuScore >= 0.4)
                return ("Medium", "Moderate translation quality - noticeable differences");
            else if (bleuScore >= 0.2)
                return ("Low-Medium", "Poor translation quality - significant differences");
            else
                return ("Low", "Very poor translation quality - major loss of meaning");
        }

        /// <summary>
        /// Assess translation quality using BLEU score
        /// </summary>
        public TranslationQualityAssessment AssessTranslationQuality(string originalText, string backtranslatedText)
        {
            double bleuScore = CalculateBleu(originalText, backtranslatedText);
            var (confidenceLevel, description) = GetConfidenceLevel(bleuScore);

            var assessment = new TranslationQualityAssessment
            {
                BleuScore = bleuScore,
                BleuPercentage = $"{bleuScore * 100:F2}%",
                ConfidenceLevel = confidenceLevel,
                Description = description,
                QualityRating = GetQualityRating(bleuScore),
                Recommendations = GetRecommendations(bleuScore)
            };

            Logger.Info($"Translation quality assessment: BLEU={assessment.BleuPercentage}, Confidence={confidenceLevel}");

            return assessment;
        }

        /// <summary>
        /// Generate detailed quality report
        /// </summary>
        public string GetDetailedReport(string originalText, string intermediateText, string backtranslatedText)
        {
            var assessment = AssessTranslationQuality(originalText, backtranslatedText);

            var report = $@"
=== TRANSLATION QUALITY REPORT ===

Original Text Length: {originalText.Length} characters
Intermediate Text Length: {intermediateText.Length} characters
Back-translated Text Length: {backtranslatedText.Length} characters

BLEU Score: {assessment.BleuPercentage}
Confidence Level: {assessment.ConfidenceLevel}
Quality Rating: {assessment.QualityRating}

Assessment: {assessment.Description}

Recommendations: {assessment.Recommendations}

=== TEXT COMPARISON ===
Original: {originalText.Substring(0, Math.Min(100, originalText.Length))}{(originalText.Length > 100 ? "..." : "")}
Back-translated: {backtranslatedText.Substring(0, Math.Min(100, backtranslatedText.Length))}{(backtranslatedText.Length > 100 ? "..." : "")}
{"=".PadRight(50, '=')}
";
            return report.Trim();
        }

        private List<string> Tokenize(string text)
        {
            // Simple tokenization: split on whitespace and punctuation
            var tokens = Regex.Split(text.ToLower(), @"[^\w]+")
                .Where(t => !string.IsNullOrWhiteSpace(t))
                .ToList();
            return tokens;
        }

        private List<string> GetNGrams(List<string> tokens, int n)
        {
            var ngrams = new List<string>();
            for (int i = 0; i <= tokens.Count - n; i++)
            {
                var ngram = string.Join(" ", tokens.Skip(i).Take(n));
                ngrams.Add(ngram);
            }
            return ngrams;
        }

        private double CalculateBrevityPenalty(int referenceLength, int candidateLength)
        {
            if (candidateLength >= referenceLength)
                return 1.0;

            return Math.Exp(1.0 - (double)referenceLength / candidateLength);
        }

        private string GetQualityRating(double bleuScore)
        {
            if (bleuScore >= 0.8) return "★★★★★";
            else if (bleuScore >= 0.6) return "★★★★☆";
            else if (bleuScore >= 0.4) return "★★★☆☆";
            else if (bleuScore >= 0.2) return "★★☆☆☆";
            else return "★☆☆☆☆";
        }

        private string GetRecommendations(double bleuScore)
        {
            if (bleuScore >= 0.8)
                return "Translation quality is excellent. No action needed.";
            else if (bleuScore >= 0.6)
                return "Translation quality is good. Minor review recommended.";
            else if (bleuScore >= 0.4)
                return "Translation quality is moderate. Consider manual review.";
            else if (bleuScore >= 0.2)
                return "Translation quality is poor. Manual correction recommended.";
            else
                return "Translation quality is very poor. Complete retranslation advised.";
        }
    }

    /// <summary>
    /// Translation quality assessment result
    /// </summary>
    public class TranslationQualityAssessment
    {
        public double BleuScore { get; set; }
        public string BleuPercentage { get; set; } = string.Empty;
        public string ConfidenceLevel { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string QualityRating { get; set; } = string.Empty;
        public string Recommendations { get; set; } = string.Empty;
    }
}