"""
BLEU Score Calculator for Translation Quality Assessment

This module provides BLEU score calculation for back-translation quality assessment,
including confidence indicators and user-friendly quality feedback.
"""

import logging
from typing import Any, Dict, Tuple

import sacrebleu

logger = logging.getLogger(__name__)

class BLEUScorer:
    """BLEU scorer for translation quality assessment."""

    def __init__(self):
        """Initialize BLEU scorer with default settings."""
        self.logger = logging.getLogger(__name__)

    def calculate_bleu(self, reference: str, candidate: str) -> float:
        """
        Calculate BLEU score between reference and candidate text.

        Args:
            reference: Original reference text
            candidate: Translated/back-translated text

        Returns:
            BLEU score (0.0 to 1.0, higher is better)
        """
        try:
            if not reference.strip() or not candidate.strip():
                return 0.0

            # Use sacrebleu for accurate BLEU calculation
            bleu = sacrebleu.corpus_bleu([candidate], [[reference]])
            return bleu.score / 100.0  # Convert to 0-1 scale

        except Exception as e:
            self.logger.error(f"BLEU calculation failed: {e}")
            return 0.0

    def get_confidence_level(self, bleu_score: float) -> Tuple[str, str]:
        """
        Get confidence level and description based on BLEU score.

        Args:
            bleu_score: BLEU score (0.0 to 1.0)

        Returns:
            Tuple of (confidence_level, description)
        """
        if bleu_score >= 0.8:
            return "High", "Excellent translation quality - minimal loss of meaning"
        elif bleu_score >= 0.6:
            return "Medium-High", "Good translation quality - some minor differences"
        elif bleu_score >= 0.4:
            return "Medium", "Moderate translation quality - noticeable differences"
        elif bleu_score >= 0.2:
            return "Low-Medium", "Poor translation quality - significant differences"
        else:
            return "Low", "Very poor translation quality - major loss of meaning"

    def assess_translation_quality(self, original_text: str, backtranslated_text: str) -> Dict[str, Any]:
        """
        Assess translation quality using BLEU score.

        Args:
            original_text: Original source text
            backtranslated_text: Back-translated text

        Returns:
            Dictionary with BLEU score, confidence level, and quality assessment
        """
        bleu_score = self.calculate_bleu(original_text, backtranslated_text)
        confidence_level, description = self.get_confidence_level(bleu_score)

        assessment = {
            "bleu_score": bleu_score,
            "bleu_percentage": f"{bleu_score * 100:.2f}%",
            "confidence_level": confidence_level,
            "description": description,
            "quality_rating": self._get_quality_rating(bleu_score),
            "recommendations": self._get_recommendations(bleu_score)
        }

        self.logger.info(
            f"Translation quality assessment: BLEU={assessment['bleu_percentage']}, "
            f"Confidence={confidence_level}"
        )

        return assessment

    def _get_quality_rating(self, bleu_score: float) -> str:
        """Get star rating based on BLEU score."""
        if bleu_score >= 0.8:
            return "★★★★★"
        elif bleu_score >= 0.6:
            return "★★★★☆"
        elif bleu_score >= 0.4:
            return "★★★☆☆"
        elif bleu_score >= 0.2:
            return "★★☆☆☆"
        else:
            return "★☆☆☆☆"

    def _get_recommendations(self, bleu_score: float) -> str:
        """Get recommendations based on BLEU score."""
        if bleu_score >= 0.8:
            return "Translation quality is excellent. No action needed."
        elif bleu_score >= 0.6:
            return "Translation quality is good. Minor review recommended."
        elif bleu_score >= 0.4:
            return "Translation quality is moderate. Consider manual review."
        elif bleu_score >= 0.2:
            return "Translation quality is poor. Manual correction recommended."
        else:
            return "Translation quality is very poor. Complete retranslation advised."

    def get_detailed_report(self, original_text: str, intermediate_text: str,
                          backtranslated_text: str) -> str:
        """
        Generate detailed quality report for back-translation.

        Args:
            original_text: Original English text
            intermediate_text: Japanese intermediate text
            backtranslated_text: Back-translated English text

        Returns:
            Formatted quality report string
        """
        assessment = self.assess_translation_quality(original_text, backtranslated_text)

        report = f"""
=== TRANSLATION QUALITY REPORT ===

Original Text Length: {len(original_text)} characters
Intermediate Text Length: {len(intermediate_text)} characters
Back-translated Text Length: {len(backtranslated_text)} characters

BLEU Score: {assessment['bleu_percentage']}
Confidence Level: {assessment['confidence_level']}
Quality Rating: {assessment['quality_rating']}

Assessment: {assessment['description']}

Recommendations: {assessment['recommendations']}

=== TEXT COMPARISON ===
Original: {original_text[:100]}{'...' if len(original_text) > 100 else ''}
Back-translated: {backtranslated_text[:100]}{'...' if len(backtranslated_text) > 100 else ''}
{'='*50}
"""
        return report.strip()

# Global instance for easy access
_bleu_scorer = None

def get_bleu_scorer() -> BLEUScorer:
    """Get global BLEU scorer instance."""
    global _bleu_scorer
    if _bleu_scorer is None:
        _bleu_scorer = BLEUScorer()
    return _bleu_scorer
