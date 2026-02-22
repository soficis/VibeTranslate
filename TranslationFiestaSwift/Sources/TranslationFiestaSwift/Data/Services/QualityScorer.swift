import Foundation

/// Service for assessing translation quality using BLEU and other metrics
public enum QualityScorer {
    /// Calculates a simplified BLEU score between a reference and candidate string
    public static func calculateSimpleBLEUScore(reference: String, candidate: String) -> Double {
        let referenceWords = reference.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        let candidateWords = candidate.lowercased().components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !referenceWords.isEmpty && !candidateWords.isEmpty else {
            return 0.0
        }
        
        let referenceSet = Set(referenceWords)
        let candidateSet = Set(candidateWords)
        let intersection = referenceSet.intersection(candidateSet)
        
        let precision = Double(intersection.count) / Double(candidateSet.count)
        let recall = Double(intersection.count) / Double(referenceSet.count)
        
        guard precision + recall > 0 else { return 0.0 }
        
        let f1Score = 2 * (precision * recall) / (precision + recall)
        
        // Apply length penalty
        let lengthRatio = Double(candidateWords.count) / Double(referenceWords.count)
        let lengthPenalty = lengthRatio > 1.0 ? (1.0 / lengthRatio) : lengthRatio
        
        return f1Score * lengthPenalty
    }
    
    /// Generates quality recommendations based on scores and lengths
    public static func generateQualityRecommendations(
        bleuScore: Double,
        originalLength: Int,
        backTranslatedLength: Int
    ) -> [String] {
        var recommendations: [String] = []
        
        if bleuScore < 0.3 {
            recommendations.append("Consider reviewing the translation for accuracy")
            recommendations.append("The back-translation shows significant differences from the original")
        }
        
        let lengthDifference = abs(originalLength - backTranslatedLength)
        let lengthRatio = originalLength > 0 ? Double(lengthDifference) / Double(originalLength) : 1.0
        
        if lengthRatio > 0.5 {
            recommendations.append("Large difference in text length detected")
            recommendations.append("This may indicate translation quality issues")
        }
        
        if bleuScore > 0.7 {
            recommendations.append("High quality translation detected")
            recommendations.append("The meaning appears to be well preserved")
        }
        
        return recommendations
    }
}
