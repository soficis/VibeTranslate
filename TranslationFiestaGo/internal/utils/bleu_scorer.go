package utils

import (
	"fmt"
	"math"
	"regexp"
	"strings"
)

// BLEUScorer provides BLEU score calculation for translation quality assessment
type BLEUScorer struct {
	maxNGrams int
}

// NewBLEUScorer creates a new BLEU scorer
func NewBLEUScorer(maxNGrams int) *BLEUScorer {
	if maxNGrams <= 0 {
		maxNGrams = 4
	}
	return &BLEUScorer{maxNGrams: maxNGrams}
}

// CalculateBLEU calculates BLEU score between reference and candidate text
func (bs *BLEUScorer) CalculateBLEU(reference, candidate string) float64 {
	if strings.TrimSpace(reference) == "" || strings.TrimSpace(candidate) == "" {
		return 0.0
	}

	referenceTokens := bs.tokenize(reference)
	candidateTokens := bs.tokenize(candidate)

	if len(referenceTokens) == 0 || len(candidateTokens) == 0 {
		return 0.0
	}

	// Calculate precision for each n-gram order
	precision := 1.0
	for n := 1; n <= bs.maxNGrams && n <= len(candidateTokens); n++ {
		candidateNGrams := bs.getNGrams(candidateTokens, n)
		referenceNGrams := bs.getNGrams(referenceTokens, n)

		if len(candidateNGrams) == 0 {
			continue
		}

		referenceCounts := make(map[string]int)
		for _, ngram := range referenceNGrams {
			referenceCounts[ngram]++
		}

		matches := 0
		for _, ngram := range candidateNGrams {
			if referenceCounts[ngram] > 0 {
				matches++
				referenceCounts[ngram]--
			}
		}

		ngramPrecision := float64(matches) / float64(len(candidateNGrams))
		precision *= ngramPrecision
	}

	// Apply geometric mean
	precision = math.Pow(precision, 1.0/float64(bs.maxNGrams))

	// Calculate brevity penalty
	brevityPenalty := bs.calculateBrevityPenalty(len(referenceTokens), len(candidateTokens))

	return precision * brevityPenalty
}

// GetConfidenceLevel returns confidence level and description based on BLEU score
func (bs *BLEUScorer) GetConfidenceLevel(bleuScore float64) (string, string) {
	switch {
	case bleuScore >= 0.8:
		return "High", "Excellent translation quality - minimal loss of meaning"
	case bleuScore >= 0.6:
		return "Medium-High", "Good translation quality - some minor differences"
	case bleuScore >= 0.4:
		return "Medium", "Moderate translation quality - noticeable differences"
	case bleuScore >= 0.2:
		return "Low-Medium", "Poor translation quality - significant differences"
	default:
		return "Low", "Very poor translation quality - major loss of meaning"
	}
}

// TranslationQualityAssessment represents the quality assessment result
type TranslationQualityAssessment struct {
	BLEUScore       float64
	BLEUPercentage  string
	ConfidenceLevel string
	Description     string
	QualityRating   string
	Recommendations string
}

// AssessTranslationQuality assesses translation quality using BLEU score
func (bs *BLEUScorer) AssessTranslationQuality(originalText, backtranslatedText string) *TranslationQualityAssessment {
	bleuScore := bs.CalculateBLEU(originalText, backtranslatedText)
	confidenceLevel, description := bs.GetConfidenceLevel(bleuScore)

	return &TranslationQualityAssessment{
		BLEUScore:       bleuScore,
		BLEUPercentage:  fmt.Sprintf("%.2f%%", bleuScore*100.0),
		ConfidenceLevel: confidenceLevel,
		Description:     description,
		QualityRating:   bs.getQualityRating(bleuScore),
		Recommendations: bs.getRecommendations(bleuScore),
	}
}

// GetDetailedReport generates a detailed quality report
func (bs *BLEUScorer) GetDetailedReport(originalText, intermediateText, backtranslatedText string) string {
	assessment := bs.AssessTranslationQuality(originalText, backtranslatedText)

	report := fmt.Sprintf(`
=== TRANSLATION QUALITY REPORT ===

Original Text Length: %d characters
Intermediate Text Length: %d characters
Back-translated Text Length: %d characters

BLEU Score: %s
Confidence Level: %s
Quality Rating: %s

Assessment: %s

Recommendations: %s

=== TEXT COMPARISON ===
Original: %s
Back-translated: %s
%s
`,
		len(originalText),
		len(intermediateText),
		len(backtranslatedText),
		assessment.BLEUPercentage,
		assessment.ConfidenceLevel,
		assessment.QualityRating,
		assessment.Description,
		assessment.Recommendations,
		truncateText(originalText, 100),
		truncateText(backtranslatedText, 100),
		strings.Repeat("=", 50))

	return strings.TrimSpace(report)
}

func (bs *BLEUScorer) tokenize(text string) []string {
	// Simple tokenization: split on whitespace and punctuation
	re := regexp.MustCompile(`[^\w]+`)
	tokens := re.Split(strings.ToLower(text), -1)

	// Filter out empty strings
	var filtered []string
	for _, token := range tokens {
		if strings.TrimSpace(token) != "" {
			filtered = append(filtered, token)
		}
	}

	return filtered
}

func (bs *BLEUScorer) getNGrams(tokens []string, n int) []string {
	if len(tokens) < n {
		return []string{}
	}

	var ngrams []string
	for i := 0; i <= len(tokens)-n; i++ {
		ngram := strings.Join(tokens[i:i+n], " ")
		ngrams = append(ngrams, ngram)
	}

	return ngrams
}

func (bs *BLEUScorer) calculateBrevityPenalty(referenceLength, candidateLength int) float64 {
	if candidateLength >= referenceLength {
		return 1.0
	}

	return math.Exp(1.0 - float64(referenceLength)/float64(candidateLength))
}

func (bs *BLEUScorer) getQualityRating(bleuScore float64) string {
	switch {
	case bleuScore >= 0.8:
		return "★★★★★"
	case bleuScore >= 0.6:
		return "★★★★☆"
	case bleuScore >= 0.4:
		return "★★★☆☆"
	case bleuScore >= 0.2:
		return "★★☆☆☆"
	default:
		return "★☆☆☆☆"
	}
}

func (bs *BLEUScorer) getRecommendations(bleuScore float64) string {
	switch {
	case bleuScore >= 0.8:
		return "Translation quality is excellent. No action needed."
	case bleuScore >= 0.6:
		return "Translation quality is good. Minor review recommended."
	case bleuScore >= 0.4:
		return "Translation quality is moderate. Consider manual review."
	case bleuScore >= 0.2:
		return "Translation quality is poor. Manual correction recommended."
	default:
		return "Translation quality is very poor. Complete retranslation advised."
	}
}

func truncateText(text string, maxLength int) string {
	if len(text) <= maxLength {
		return text
	}
	return text[:maxLength] + "..."
}

// Global BLEU scorer instance
var globalBLEUScorer *BLEUScorer

// GetBLEUScorer returns the global BLEU scorer instance
func GetBLEUScorer() *BLEUScorer {
	if globalBLEUScorer == nil {
		globalBLEUScorer = NewBLEUScorer(4)
	}
	return globalBLEUScorer
}
