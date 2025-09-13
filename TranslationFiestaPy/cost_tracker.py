#!/usr/bin/env python3
"""
cost_tracker.py

Cost tracking service for Google Cloud Translation API usage.
Tracks characters translated, calculates costs, manages budgets, and provides reporting.
"""

from __future__ import annotations

import json
import time
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Callable
from pathlib import Path
import threading

from enhanced_logger import get_logger


@dataclass
class CostEntry:
    """Represents a single cost transaction"""
    timestamp: float
    characters: int
    cost_usd: float
    source_lang: str
    target_lang: str
    implementation: str
    api_version: str = "v2"  # Google Cloud Translation API version

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Budget:
    """Budget configuration and tracking"""
    monthly_limit_usd: float
    current_month_usage_usd: float
    alert_threshold_percent: float = 80.0
    last_reset_timestamp: float = 0.0

    def to_dict(self) -> dict:
        return asdict(self)

    def is_near_limit(self) -> bool:
        """Check if current usage is near the budget limit"""
        if self.monthly_limit_usd <= 0:
            return False
        usage_percent = (self.current_month_usage_usd / self.monthly_limit_usd) * 100
        return usage_percent >= self.alert_threshold_percent

    def is_over_limit(self) -> bool:
        """Check if current usage exceeds the budget limit"""
        return self.current_month_usage_usd >= self.monthly_limit_usd


class CostTracker:
    """
    Cost tracking service for Google Cloud Translation API.

    Features:
    - Tracks character usage and costs
    - Calculates costs based on Google Cloud pricing ($20 per 1M characters)
    - Manages monthly budgets with alerts
    - Persistent storage of cost data
    - Thread-safe operations
    """

    # Google Cloud Translation pricing (as of 2024)
    COST_PER_MILLION_CHARS = 20.0  # $20 per 1 million characters

    def __init__(self, storage_path: str = "translation_costs.json"):
        self.storage_path = Path(storage_path)
        self.logger = get_logger()
        self._lock = threading.Lock()

        # In-memory data
        self.cost_entries: List[CostEntry] = []
        self.budget = Budget(
            monthly_limit_usd=50.0,  # Default $50/month budget
            current_month_usage_usd=0.0,
            alert_threshold_percent=80.0
        )

        # Alert callbacks
        self.alert_callbacks: List[Callable[[str, float], None]] = []

        # Load existing data
        self._load_data()

    def _load_data(self) -> None:
        """Load cost data from persistent storage"""
        try:
            if self.storage_path.exists():
                with open(self.storage_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)

                # Load cost entries
                self.cost_entries = [
                    CostEntry(**entry) for entry in data.get('cost_entries', [])
                ]

                # Load budget
                if 'budget' in data:
                    self.budget = Budget(**data['budget'])

                # Recalculate current month usage
                self._recalculate_current_month_usage()

                self.logger.info(f"Loaded {len(self.cost_entries)} cost entries from {self.storage_path}")

        except Exception as e:
            self.logger.error(f"Failed to load cost data: {e}")
            # Initialize with defaults if loading fails

    def _save_data(self) -> None:
        """Save cost data to persistent storage"""
        try:
            data = {
                'cost_entries': [entry.to_dict() for entry in self.cost_entries],
                'budget': self.budget.to_dict(),
                'last_updated': time.time()
            }

            with open(self.storage_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

        except Exception as e:
            self.logger.error(f"Failed to save cost data: {e}")

    def _recalculate_current_month_usage(self) -> None:
        """Recalculate current month usage from stored entries"""
        now = datetime.now()
        current_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        total_cost = 0.0
        for entry in self.cost_entries:
            entry_date = datetime.fromtimestamp(entry.timestamp)
            entry_month = entry_date.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

            if entry_month >= current_month:
                total_cost += entry.cost_usd

        self.budget.current_month_usage_usd = total_cost

        # Reset budget if it's a new month
        if self.budget.last_reset_timestamp == 0 or \
           datetime.fromtimestamp(self.budget.last_reset_timestamp).month != now.month:
            self.budget.last_reset_timestamp = current_month.timestamp()
            self._save_data()

    @staticmethod
    def calculate_cost(characters: int) -> float:
        """Calculate cost for given number of characters using Google Cloud pricing"""
        if characters <= 0:
            return 0.0
        return (characters / 1_000_000) * CostTracker.COST_PER_MILLION_CHARS

    def track_translation(
        self,
        characters: int,
        source_lang: str,
        target_lang: str,
        implementation: str,
        api_version: str = "v2"
    ) -> CostEntry:
        """
        Track a translation operation and update costs

        Args:
            characters: Number of characters translated
            source_lang: Source language code
            target_lang: Target language code
            implementation: Which implementation performed the translation
            api_version: API version used

        Returns:
            CostEntry: The created cost entry
        """
        with self._lock:
            cost_usd = self.calculate_cost(characters)

            entry = CostEntry(
                timestamp=time.time(),
                characters=characters,
                cost_usd=cost_usd,
                source_lang=source_lang,
                target_lang=target_lang,
                implementation=implementation,
                api_version=api_version
            )

            self.cost_entries.append(entry)
            self.budget.current_month_usage_usd += cost_usd

            # Check for budget alerts
            self._check_budget_alerts()

            # Save to persistent storage
            self._save_data()

            self.logger.info(
                f"Tracked translation: {characters} chars, "
                f"${cost_usd:.6f}, {source_lang}->{target_lang}, "
                f"total this month: ${self.budget.current_month_usage_usd:.2f}"
            )

            return entry

    def _check_budget_alerts(self) -> None:
        """Check budget limits and trigger alerts if necessary"""
        if self.budget.is_over_limit():
            self._trigger_alert(
                "BUDGET_EXCEEDED",
                f"Monthly budget exceeded! Current usage: ${self.budget.current_month_usage_usd:.2f}, "
                f"Limit: ${self.budget.monthly_limit_usd:.2f}"
            )
        elif self.budget.is_near_limit():
            usage_percent = (self.budget.current_month_usage_usd / self.budget.monthly_limit_usd) * 100
            self._trigger_alert(
                "BUDGET_WARNING",
                f"Approaching budget limit: {usage_percent:.1f}% used "
                f"(${self.budget.current_month_usage_usd:.2f} of ${self.budget.monthly_limit_usd:.2f})"
            )

    def _trigger_alert(self, alert_type: str, message: str) -> None:
        """Trigger budget alerts"""
        self.logger.warning(f"Cost Alert [{alert_type}]: {message}")

        # Call all registered alert callbacks
        for callback in self.alert_callbacks:
            try:
                callback(alert_type, self.budget.current_month_usage_usd)
            except Exception as e:
                self.logger.error(f"Alert callback failed: {e}")

    def add_alert_callback(self, callback: Callable[[str, float], None]) -> None:
        """Add a callback function to be called when budget alerts are triggered"""
        self.alert_callbacks.append(callback)

    def set_budget(self, monthly_limit_usd: float, alert_threshold_percent: float = 80.0) -> None:
        """Set monthly budget and alert threshold"""
        with self._lock:
            self.budget.monthly_limit_usd = monthly_limit_usd
            self.budget.alert_threshold_percent = alert_threshold_percent
            self._save_data()
            self.logger.info(f"Budget set to ${monthly_limit_usd:.2f}/month with {alert_threshold_percent}% alert threshold")

    def get_budget_status(self) -> Dict[str, any]:
        """Get current budget status"""
        with self._lock:
            usage_percent = 0.0
            if self.budget.monthly_limit_usd > 0:
                usage_percent = (self.budget.current_month_usage_usd / self.budget.monthly_limit_usd) * 100

            return {
                'monthly_limit_usd': self.budget.monthly_limit_usd,
                'current_month_usage_usd': self.budget.current_month_usage_usd,
                'usage_percent': usage_percent,
                'alert_threshold_percent': self.budget.alert_threshold_percent,
                'is_near_limit': self.budget.is_near_limit(),
                'is_over_limit': self.budget.is_over_limit(),
                'remaining_budget_usd': max(0, self.budget.monthly_limit_usd - self.budget.current_month_usage_usd)
            }

    def get_cost_report(
        self,
        days: int = 30,
        group_by_implementation: bool = True
    ) -> Dict[str, any]:
        """Generate cost report for the specified number of days"""
        with self._lock:
            cutoff_time = time.time() - (days * 24 * 60 * 60)

            # Filter entries within the time range
            recent_entries = [
                entry for entry in self.cost_entries
                if entry.timestamp >= cutoff_time
            ]

            total_cost = sum(entry.cost_usd for entry in recent_entries)
            total_chars = sum(entry.characters for entry in recent_entries)

            report = {
                'period_days': days,
                'total_cost_usd': total_cost,
                'total_characters': total_chars,
                'average_cost_per_char': total_cost / max(1, total_chars),
                'entry_count': len(recent_entries),
                'cost_per_million_chars': self.COST_PER_MILLION_CHARS
            }

            if group_by_implementation:
                impl_stats = {}
                for entry in recent_entries:
                    impl = entry.implementation
                    if impl not in impl_stats:
                        impl_stats[impl] = {
                            'total_cost_usd': 0.0,
                            'total_characters': 0,
                            'entry_count': 0
                        }
                    impl_stats[impl]['total_cost_usd'] += entry.cost_usd
                    impl_stats[impl]['total_characters'] += entry.characters
                    impl_stats[impl]['entry_count'] += 1

                report['by_implementation'] = impl_stats

            return report

    def get_recent_entries(self, limit: int = 100) -> List[CostEntry]:
        """Get recent cost entries (most recent first)"""
        with self._lock:
            return sorted(
                self.cost_entries,
                key=lambda x: x.timestamp,
                reverse=True
            )[:limit]

    def clear_old_entries(self, days_to_keep: int = 365) -> int:
        """Clear cost entries older than specified days. Returns number of entries removed."""
        with self._lock:
            cutoff_time = time.time() - (days_to_keep * 24 * 60 * 60)
            original_count = len(self.cost_entries)

            self.cost_entries = [
                entry for entry in self.cost_entries
                if entry.timestamp >= cutoff_time
            ]

            removed_count = original_count - len(self.cost_entries)
            if removed_count > 0:
                self._save_data()
                self.logger.info(f"Cleared {removed_count} old cost entries (kept last {days_to_keep} days)")

            return removed_count

    def reset_budget(self) -> None:
        """Manually reset the current month's budget usage"""
        with self._lock:
            self.budget.current_month_usage_usd = 0.0
            self.budget.last_reset_timestamp = time.time()
            self._save_data()
            self.logger.info("Monthly budget usage reset to $0.00")


# Global cost tracker instance
_cost_tracker_instance: Optional[CostTracker] = None
_cost_tracker_lock = threading.Lock()


def get_cost_tracker(storage_path: str = "translation_costs.json") -> CostTracker:
    """Get or create the global cost tracker instance"""
    global _cost_tracker_instance

    if _cost_tracker_instance is None:
        with _cost_tracker_lock:
            if _cost_tracker_instance is None:
                _cost_tracker_instance = CostTracker(storage_path)

    return _cost_tracker_instance


def track_translation_cost(
    characters: int,
    source_lang: str,
    target_lang: str,
    implementation: str = "python",
    api_version: str = "v2"
) -> CostEntry:
    """
    Convenience function to track translation cost using the global cost tracker

    Args:
        characters: Number of characters translated
        source_lang: Source language code
        target_lang: Target language code
        implementation: Implementation name (python, go, csharp, fsharp)
        api_version: API version used

    Returns:
        CostEntry: The created cost entry
    """
    tracker = get_cost_tracker()
    return tracker.track_translation(characters, source_lang, target_lang, implementation, api_version)


# Example usage and testing
if __name__ == "__main__":
    # Initialize cost tracker
    tracker = get_cost_tracker()

    # Set a budget
    tracker.set_budget(100.0, 90.0)  # $100/month, alert at 90%

    # Add an alert callback
    def budget_alert(alert_type, current_usage):
        print(f"ALERT: {alert_type} - Current usage: ${current_usage:.2f}")

    tracker.add_alert_callback(budget_alert)

    # Track some translations
    tracker.track_translation(50000, "en", "es", "python")
    tracker.track_translation(75000, "en", "fr", "python")
    tracker.track_translation(25000, "es", "en", "python")

    # Get budget status
    status = tracker.get_budget_status()
    print(f"Budget Status: ${status['current_month_usage_usd']:.2f} used of ${status['monthly_limit_usd']:.2f}")

    # Get cost report
    report = tracker.get_cost_report(days=30)
    print(f"30-day Report: ${report['total_cost_usd']:.2f} total cost, {report['total_characters']} characters")