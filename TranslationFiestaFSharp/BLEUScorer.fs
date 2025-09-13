namespace TranslationFiestaFSharp

open System
open System.Text.RegularExpressions
open System.Collections.Generic


/// Translation quality assessment result
type TranslationQualityAssessment = {
    BleuScore: float
    BleuPercentage: string
    ConfidenceLevel: string
    Description: string
    QualityRating: string
    Recommendations: string
}

module BLEUScorer =

    /// BLEU Score Calculator for Translation Quality Assessment
    type BLEUScorer(maxNGrams: int) =
        let mutable _maxNGrams = maxNGrams

        new() = BLEUScorer(4)

        /// Calculate BLEU score between reference and candidate text
        member this.CalculateBleu(reference: string, candidate: string) =
            if String.IsNullOrWhiteSpace(reference) || String.IsNullOrWhiteSpace(candidate) then
                0.0
            else
                let referenceTokens: string[] = this.Tokenize(reference)
                let candidateTokens: string[] = this.Tokenize(candidate)

                if referenceTokens.Length = 0 || candidateTokens.Length = 0 then
                    0.0
                else
                    // Calculate precision for each n-gram order
                    let mutable precision = 1.0
                    for n = 1 to Math.Min(_maxNGrams, candidateTokens.Length) do
                        let candidateNGrams: string[] = this.GetNGrams(candidateTokens, n)
                        let referenceNGrams: string[] = this.GetNGrams(referenceTokens, n)

                        if candidateNGrams.Length > 0 then
                            let referenceCounts = dict [
                                for ngram in referenceNGrams do
                                    let count = referenceNGrams |> Seq.filter ((=) ngram) |> Seq.length
                                    yield ngram, count
                            ]

                            let mutable matches = 0
                            let candidateCounts = dict [
                                for ngram in candidateNGrams do
                                    let count = candidateNGrams |> Seq.filter ((=) ngram) |> Seq.length
                                    yield ngram, count
                            ]

                            let mutable referenceCountsMutable = Dictionary<string, int>(referenceCounts)
                            for ngram in candidateNGrams do
                                if referenceCountsMutable.ContainsKey(ngram) && referenceCountsMutable.[ngram] > 0 then
                                    matches <- matches + 1
                                    referenceCountsMutable.[ngram] <- referenceCountsMutable.[ngram] - 1

                            let ngramPrecision = float matches / float candidateNGrams.Length
                            precision <- precision * ngramPrecision

                    // Apply geometric mean
                    precision <- precision ** (1.0 / float _maxNGrams)

                    // Calculate brevity penalty
                    let brevityPenalty = this.CalculateBrevityPenalty(referenceTokens.Length, candidateTokens.Length)

                    precision * brevityPenalty

        /// Get confidence level and description based on BLEU score
        member this.GetConfidenceLevel(bleuScore: float) =
            if bleuScore >= 0.8 then
                ("High", "Excellent translation quality - minimal loss of meaning")
            elif bleuScore >= 0.6 then
                ("Medium-High", "Good translation quality - some minor differences")
            elif bleuScore >= 0.4 then
                ("Medium", "Moderate translation quality - noticeable differences")
            elif bleuScore >= 0.2 then
                ("Low-Medium", "Poor translation quality - significant differences")
            else
                ("Low", "Very poor translation quality - major loss of meaning")

        /// Assess translation quality using BLEU score
        member this.AssessTranslationQuality(originalText: string, backtranslatedText: string) =
            let bleuScore = this.CalculateBleu(originalText, backtranslatedText)
            let (confidenceLevel, description) = this.GetConfidenceLevel(bleuScore)

            {
                BleuScore = bleuScore
                BleuPercentage = sprintf "%.2f%%" (bleuScore * 100.0)
                ConfidenceLevel = confidenceLevel
                Description = description
                QualityRating = this.GetQualityRating(bleuScore)
                Recommendations = this.GetRecommendations(bleuScore)
            }

        /// Generate detailed quality report
        member this.GetDetailedReport(originalText: string, intermediateText: string, backtranslatedText: string) =
            let assessment = this.AssessTranslationQuality(originalText, backtranslatedText)

            sprintf "
    === TRANSLATION QUALITY REPORT ===\n\n    Original Text Length: %d characters\n    Intermediate Text Length: %d characters\n    Back-translated Text Length: %d characters\n\n    BLEU Score: %s\n    Confidence Level: %s\n    Quality Rating: %s\n\n    Assessment: %s\n\n    Recommendations: %s\n\n    === TEXT COMPARISON ===\n    Original: %s\n    Back-translated: %s\n    %s\n    "
                originalText.Length
                intermediateText.Length
                backtranslatedText.Length
                assessment.BleuPercentage
                assessment.ConfidenceLevel
                assessment.QualityRating
                assessment.Description
                assessment.Recommendations
                (originalText.Substring(0, Math.Min(100, originalText.Length)) + (if originalText.Length > 100 then "..." else ""))
                (backtranslatedText.Substring(0, Math.Min(100, backtranslatedText.Length)) + (if backtranslatedText.Length > 100 then "..." else ""))
                (String.replicate 50 "=")

        member private this.Tokenize(text: string) =
            // Simple tokenization: split on whitespace and punctuation
            Regex.Split(text.ToLower(), @"[^\w]+")
            |> Array.filter (fun t -> not (String.IsNullOrWhiteSpace(t)))

        member private this.GetNGrams(tokens: string[], n: int) =
            [|
                for i = 0 to tokens.Length - n do
                    yield String.Join(" ", tokens.[i..i+n-1])
            |]

        member private this.CalculateBrevityPenalty(referenceLength: int, candidateLength: int) =
            if candidateLength >= referenceLength then
                1.0
            else
                Math.Exp(1.0 - float referenceLength / float candidateLength)

        member private this.GetQualityRating(bleuScore: float) =
            if bleuScore >= 0.8 then "★★★★★"
            elif bleuScore >= 0.6 then "★★★★☆"
            elif bleuScore >= 0.4 then "★★★☆☆"
            elif bleuScore >= 0.2 then "★★☆☆☆"
            else "★☆☆☆☆"

        member private this.GetRecommendations(bleuScore: float) =
            if bleuScore >= 0.8 then
                "Translation quality is excellent. No action needed."
            elif bleuScore >= 0.6 then
                "Translation quality is good. Minor review recommended."
            elif bleuScore >= 0.4 then
                "Translation quality is moderate. Consider manual review."
            elif bleuScore >= 0.2 then
                "Translation quality is poor. Manual correction recommended."
            else
                "Translation quality is very poor. Complete retranslation advised."

    /// Global BLEU scorer instance
    let private bleuScorer = BLEUScorer()

    /// Get global BLEU scorer instance
    let getBleuScorer() = bleuScorer