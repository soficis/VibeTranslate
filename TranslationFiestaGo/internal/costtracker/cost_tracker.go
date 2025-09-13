package costtracker

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"translationfiestago/internal/utils"
)

// CostEntry represents a single cost transaction
type CostEntry struct {
	Timestamp      float64 `json:"timestamp"`
	Characters     int     `json:"characters"`
	CostUSD        float64 `json:"cost_usd"`
	SourceLang     string  `json:"source_lang"`
	TargetLang     string  `json:"target_lang"`
	Implementation string  `json:"implementation"`
	APIVersion     string  `json:"api_version"`
}

// Budget represents budget configuration and tracking
type Budget struct {
	MonthlyLimitUSD       float64 `json:"monthly_limit_usd"`
	CurrentMonthUsageUSD  float64 `json:"current_month_usage_usd"`
	AlertThresholdPercent float64 `json:"alert_threshold_percent"`
	LastResetTimestamp    float64 `json:"last_reset_timestamp"`
}

// IsNearLimit checks if current usage is near the budget limit
func (b *Budget) IsNearLimit() bool {
	if b.MonthlyLimitUSD <= 0 {
		return false
	}
	usagePercent := (b.CurrentMonthUsageUSD / b.MonthlyLimitUSD) * 100
	return usagePercent >= b.AlertThresholdPercent
}

// IsOverLimit checks if current usage exceeds the budget limit
func (b *Budget) IsOverLimit() bool {
	return b.CurrentMonthUsageUSD >= b.MonthlyLimitUSD
}

// CostTracker handles cost tracking for Google Cloud Translation API
type CostTracker struct {
	storagePath    string
	costEntries    []CostEntry
	budget         Budget
	alertCallbacks []func(alertType string, currentUsage float64)
	mutex          sync.RWMutex
	logger         *utils.Logger
}

// CostTrackerConfig holds configuration for cost tracker
type CostTrackerConfig struct {
	StoragePath           string
	DefaultMonthlyBudget  float64
	DefaultAlertThreshold float64
}

// DefaultConfig returns default configuration
func DefaultConfig() CostTrackerConfig {
	return CostTrackerConfig{
		StoragePath:           "translation_costs.json",
		DefaultMonthlyBudget:  50.0, // $50/month default
		DefaultAlertThreshold: 80.0, // 80% alert threshold
	}
}

// Google Cloud Translation pricing constants
const (
	CostPerMillionChars = 20.0 // $20 per 1 million characters
)

// CalculateCost calculates cost for given number of characters
func CalculateCost(characters int) float64 {
	if characters <= 0 {
		return 0.0
	}
	return (float64(characters) / 1_000_000) * CostPerMillionChars
}

// NewCostTracker creates a new cost tracker instance
func NewCostTracker(config CostTrackerConfig) *CostTracker {
	ct := &CostTracker{
		storagePath:    config.StoragePath,
		costEntries:    make([]CostEntry, 0),
		alertCallbacks: make([]func(alertType string, currentUsage float64), 0),
		logger:         utils.GetLogger(),
	}

	// Initialize budget
	ct.budget = Budget{
		MonthlyLimitUSD:       config.DefaultMonthlyBudget,
		CurrentMonthUsageUSD:  0.0,
		AlertThresholdPercent: config.DefaultAlertThreshold,
		LastResetTimestamp:    0.0,
	}

	// Load existing data
	ct.loadData()

	return ct
}

// TrackTranslation tracks a translation operation and updates costs
func (ct *CostTracker) TrackTranslation(characters int, sourceLang, targetLang, implementation, apiVersion string) CostEntry {
	ct.mutex.Lock()
	defer ct.mutex.Unlock()

	costUSD := CalculateCost(characters)

	entry := CostEntry{
		Timestamp:      float64(time.Now().Unix()),
		Characters:     characters,
		CostUSD:        costUSD,
		SourceLang:     sourceLang,
		TargetLang:     targetLang,
		Implementation: implementation,
		APIVersion:     apiVersion,
	}

	ct.costEntries = append(ct.costEntries, entry)
	ct.budget.CurrentMonthUsageUSD += costUSD

	// Check for budget alerts
	ct.checkBudgetAlerts()

	// Save to persistent storage
	ct.saveData()

	ct.logger.Info(
		"Tracked translation: %d chars, $%.6f, %s->%s, total this month: $%.2f",
		characters, costUSD, sourceLang, targetLang, ct.budget.CurrentMonthUsageUSD,
	)

	return entry
}

// SetBudget sets monthly budget and alert threshold
func (ct *CostTracker) SetBudget(monthlyLimitUSD, alertThresholdPercent float64) {
	ct.mutex.Lock()
	defer ct.mutex.Unlock()

	ct.budget.MonthlyLimitUSD = monthlyLimitUSD
	ct.budget.AlertThresholdPercent = alertThresholdPercent
	ct.saveData()

	ct.logger.Info("Budget set to $%.2f/month with %.1f%% alert threshold",
		monthlyLimitUSD, alertThresholdPercent)
}

// GetBudgetStatus returns current budget status
func (ct *CostTracker) GetBudgetStatus() map[string]interface{} {
	ct.mutex.RLock()
	defer ct.mutex.RUnlock()

	usagePercent := 0.0
	if ct.budget.MonthlyLimitUSD > 0 {
		usagePercent = (ct.budget.CurrentMonthUsageUSD / ct.budget.MonthlyLimitUSD) * 100
	}

	return map[string]interface{}{
		"monthly_limit_usd":       ct.budget.MonthlyLimitUSD,
		"current_month_usage_usd": ct.budget.CurrentMonthUsageUSD,
		"usage_percent":           usagePercent,
		"alert_threshold_percent": ct.budget.AlertThresholdPercent,
		"is_near_limit":           ct.budget.IsNearLimit(),
		"is_over_limit":           ct.budget.IsOverLimit(),
		"remaining_budget_usd":    max(0, ct.budget.MonthlyLimitUSD-ct.budget.CurrentMonthUsageUSD),
	}
}

// GetCostReport generates cost report for the specified number of days
func (ct *CostTracker) GetCostReport(days int, groupByImplementation bool) map[string]interface{} {
	ct.mutex.RLock()
	defer ct.mutex.RUnlock()

	cutoffTime := float64(time.Now().AddDate(0, 0, -days).Unix())

	// Filter entries within the time range
	var recentEntries []CostEntry
	for _, entry := range ct.costEntries {
		if entry.Timestamp >= cutoffTime {
			recentEntries = append(recentEntries, entry)
		}
	}

	totalCost := 0.0
	totalChars := 0
	for _, entry := range recentEntries {
		totalCost += entry.CostUSD
		totalChars += entry.Characters
	}

	report := map[string]interface{}{
		"period_days":            days,
		"total_cost_usd":         totalCost,
		"total_characters":       totalChars,
		"average_cost_per_char":  totalCost / max(1, float64(totalChars)),
		"entry_count":            len(recentEntries),
		"cost_per_million_chars": CostPerMillionChars,
	}

	if groupByImplementation {
		implStats := make(map[string]map[string]interface{})
		for _, entry := range recentEntries {
			impl := entry.Implementation
			if implStats[impl] == nil {
				implStats[impl] = map[string]interface{}{
					"total_cost_usd":   0.0,
					"total_characters": 0,
					"entry_count":      0,
				}
			}
			implStats[impl]["total_cost_usd"] = implStats[impl]["total_cost_usd"].(float64) + entry.CostUSD
			implStats[impl]["total_characters"] = implStats[impl]["total_characters"].(int) + entry.Characters
			implStats[impl]["entry_count"] = implStats[impl]["entry_count"].(int) + 1
		}
		report["by_implementation"] = implStats
	}

	return report
}

// GetRecentEntries returns recent cost entries (most recent first)
func (ct *CostTracker) GetRecentEntries(limit int) []CostEntry {
	ct.mutex.RLock()
	defer ct.mutex.RUnlock()

	// Create a copy of entries sorted by timestamp (most recent first)
	entries := make([]CostEntry, len(ct.costEntries))
	copy(entries, ct.costEntries)

	// Simple bubble sort by timestamp (descending)
	for i := 0; i < len(entries); i++ {
		for j := i + 1; j < len(entries); j++ {
			if entries[i].Timestamp < entries[j].Timestamp {
				entries[i], entries[j] = entries[j], entries[i]
			}
		}
	}

	if limit > 0 && limit < len(entries) {
		return entries[:limit]
	}
	return entries
}

// ClearOldEntries clears cost entries older than specified days
func (ct *CostTracker) ClearOldEntries(daysToKeep int) int {
	ct.mutex.Lock()
	defer ct.mutex.Unlock()

	cutoffTime := float64(time.Now().AddDate(0, 0, -daysToKeep).Unix())
	originalCount := len(ct.costEntries)

	var newEntries []CostEntry
	for _, entry := range ct.costEntries {
		if entry.Timestamp >= cutoffTime {
			newEntries = append(newEntries, entry)
		}
	}

	removedCount := originalCount - len(newEntries)
	ct.costEntries = newEntries

	if removedCount > 0 {
		ct.saveData()
		ct.logger.Info("Cleared %d old cost entries (kept last %d days)", removedCount, daysToKeep)
	}

	return removedCount
}

// ResetBudget resets the current month's budget usage
func (ct *CostTracker) ResetBudget() {
	ct.mutex.Lock()
	defer ct.mutex.Unlock()

	ct.budget.CurrentMonthUsageUSD = 0.0
	ct.budget.LastResetTimestamp = float64(time.Now().Unix())
	ct.saveData()

	ct.logger.Info("Monthly budget usage reset to $0.00")
}

// AddAlertCallback adds a callback function for budget alerts
func (ct *CostTracker) AddAlertCallback(callback func(alertType string, currentUsage float64)) {
	ct.mutex.Lock()
	defer ct.mutex.Unlock()

	ct.alertCallbacks = append(ct.alertCallbacks, callback)
}

func (ct *CostTracker) checkBudgetAlerts() {
	if ct.budget.IsOverLimit() {
		ct.triggerAlert("BUDGET_EXCEEDED",
			fmt.Sprintf("Monthly budget exceeded! Current usage: $%.2f, Limit: $%.2f",
				ct.budget.CurrentMonthUsageUSD, ct.budget.MonthlyLimitUSD))
	} else if ct.budget.IsNearLimit() {
		usagePercent := (ct.budget.CurrentMonthUsageUSD / ct.budget.MonthlyLimitUSD) * 100
		ct.triggerAlert("BUDGET_WARNING",
			fmt.Sprintf("Approaching budget limit: %.1f%% used ($%.2f of $%.2f)",
				usagePercent, ct.budget.CurrentMonthUsageUSD, ct.budget.MonthlyLimitUSD))
	}
}

func (ct *CostTracker) triggerAlert(alertType, message string) {
	ct.logger.Warn("Cost Alert [%s]: %s", alertType, message)

	// Call all registered alert callbacks
	for _, callback := range ct.alertCallbacks {
		func(cb func(string, float64)) {
			defer func() {
				if r := recover(); r != nil {
					ct.logger.Error("Alert callback panic: %v", r)
				}
			}()
			cb(alertType, ct.budget.CurrentMonthUsageUSD)
		}(callback)
	}
}

func (ct *CostTracker) loadData() {
	// Ensure directory exists
	dir := filepath.Dir(ct.storagePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		ct.logger.Error("Failed to create cost tracker directory: %v", err)
		return
	}

	bytes, err := os.ReadFile(ct.storagePath)
	if err != nil {
		if !os.IsNotExist(err) {
			ct.logger.Error("Failed to read cost data: %v", err)
		}
		return
	}

	var data struct {
		CostEntries []CostEntry `json:"cost_entries"`
		Budget      Budget      `json:"budget"`
	}

	if err := json.Unmarshal(bytes, &data); err != nil {
		ct.logger.Error("Failed to unmarshal cost data: %v", err)
		return
	}

	ct.costEntries = data.CostEntries
	ct.budget = data.Budget

	// Recalculate current month usage
	ct.recalculateCurrentMonthUsage()

	ct.logger.Info("Loaded %d cost entries from %s", len(ct.costEntries), ct.storagePath)
}

func (ct *CostTracker) saveData() {
	data := map[string]interface{}{
		"cost_entries": ct.costEntries,
		"budget":       ct.budget,
		"last_updated": float64(time.Now().Unix()),
	}

	bytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		ct.logger.Error("Failed to marshal cost data: %v", err)
		return
	}

	if err := os.WriteFile(ct.storagePath, bytes, 0644); err != nil {
		ct.logger.Error("Failed to write cost data: %v", err)
	}
}

func (ct *CostTracker) recalculateCurrentMonthUsage() {
	now := time.Now()
	currentMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	totalCost := 0.0
	for _, entry := range ct.costEntries {
		entryTime := time.Unix(int64(entry.Timestamp), 0)
		entryMonth := time.Date(entryTime.Year(), entryTime.Month(), 1, 0, 0, 0, 0, entryTime.Location())

		if entryMonth.Equal(currentMonth) || entryMonth.After(currentMonth) {
			totalCost += entry.CostUSD
		}
	}

	ct.budget.CurrentMonthUsageUSD = totalCost

	// Reset budget if it's a new month
	if ct.budget.LastResetTimestamp == 0 ||
		time.Unix(int64(ct.budget.LastResetTimestamp), 0).Month() != now.Month() {
		ct.budget.LastResetTimestamp = float64(currentMonth.Unix())
		ct.saveData()
	}
}

// Global cost tracker instance
var (
	globalCostTracker *CostTracker
	globalMutex       sync.Mutex
)

// GetGlobalCostTracker returns the global cost tracker instance
func GetGlobalCostTracker(config CostTrackerConfig) *CostTracker {
	globalMutex.Lock()
	defer globalMutex.Unlock()

	if globalCostTracker == nil {
		globalCostTracker = NewCostTracker(config)
	}

	return globalCostTracker
}

// TrackTranslationCost is a convenience function to track translation cost
func TrackTranslationCost(characters int, sourceLang, targetLang, implementation, apiVersion string) CostEntry {
	tracker := GetGlobalCostTracker(DefaultConfig())
	return tracker.TrackTranslation(characters, sourceLang, targetLang, implementation, apiVersion)
}

func max(a, b float64) float64 {
	if a > b {
		return a
	}
	return b
}
