package costtracker

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"translationfiestago/internal/utils"
)

// CostDashboard provides a web-based interface for cost management
type CostDashboard struct {
	costTracker *CostTracker
	logger      *utils.Logger
	port        int
	server      *http.Server
}

// NewCostDashboard creates a new cost dashboard
func NewCostDashboard(costTracker *CostTracker, port int) *CostDashboard {
	return &CostDashboard{
		costTracker: costTracker,
		logger:      utils.GetLogger(),
		port:        port,
	}
}

// Start starts the dashboard web server
func (cd *CostDashboard) Start() error {
	mux := http.NewServeMux()

	// Static files
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.Dir("static"))))

	// Routes
	mux.HandleFunc("/", cd.handleDashboard)
	mux.HandleFunc("/api/budget", cd.handleBudgetAPI)
	mux.HandleFunc("/api/report", cd.handleReportAPI)
	mux.HandleFunc("/api/history", cd.handleHistoryAPI)
	mux.HandleFunc("/api/settings", cd.handleSettingsAPI)

	cd.server = &http.Server{
		Addr:    fmt.Sprintf(":%d", cd.port),
		Handler: mux,
	}

	cd.logger.Info("Starting cost dashboard on port %d", cd.port)
	return cd.server.ListenAndServe()
}

// Stop stops the dashboard web server
func (cd *CostDashboard) Stop() error {
	if cd.server != nil {
		cd.logger.Info("Stopping cost dashboard")
		return cd.server.Close()
	}
	return nil
}

func (cd *CostDashboard) handleDashboard(w http.ResponseWriter, r *http.Request) {
	// Simple JSON API dashboard
	w.Header().Set("Content-Type", "application/json")

	status := cd.costTracker.GetBudgetStatus()
	report := cd.costTracker.GetCostReport(30, true)

	response := map[string]interface{}{
		"budget_status": status,
		"cost_report":   report,
		"pricing_info": map[string]interface{}{
			"cost_per_million_chars": CostPerMillionChars,
			"currency":               "USD",
		},
	}

	json.NewEncoder(w).Encode(response)
}

func (cd *CostDashboard) handleBudgetAPI(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		cd.getBudgetStatus(w, r)
	case "POST":
		if r.URL.Path == "/api/budget/reset" {
			cd.resetBudget(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (cd *CostDashboard) getBudgetStatus(w http.ResponseWriter, r *http.Request) {
	status := cd.costTracker.GetBudgetStatus()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
}

func (cd *CostDashboard) resetBudget(w http.ResponseWriter, r *http.Request) {
	cd.costTracker.ResetBudget()
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

func (cd *CostDashboard) handleReportAPI(w http.ResponseWriter, r *http.Request) {
	daysStr := r.URL.Query().Get("days")
	days := 30 // default
	if daysStr != "" {
		if parsed, err := strconv.Atoi(daysStr); err == nil && parsed > 0 {
			days = parsed
		}
	}

	report := cd.costTracker.GetCostReport(days, true)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(report)
}

func (cd *CostDashboard) handleHistoryAPI(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		cd.getHistory(w, r)
	case "POST":
		if r.URL.Path == "/api/history/clear" {
			cd.clearOldEntries(w, r)
		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	default:
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}
}

func (cd *CostDashboard) getHistory(w http.ResponseWriter, r *http.Request) {
	limitStr := r.URL.Query().Get("limit")
	limit := 50 // default
	if limitStr != "" {
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	entries := cd.costTracker.GetRecentEntries(limit)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(entries)
}

func (cd *CostDashboard) clearOldEntries(w http.ResponseWriter, r *http.Request) {
	removedCount := cd.costTracker.ClearOldEntries(365)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":        "success",
		"removed_count": removedCount,
	})
}

func (cd *CostDashboard) handleSettingsAPI(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var settings struct {
		MonthlyLimitUSD       float64 `json:"monthly_limit_usd"`
		AlertThresholdPercent float64 `json:"alert_threshold_percent"`
	}

	if err := json.NewDecoder(r.Body).Decode(&settings); err != nil {
		http.Error(w, "Invalid JSON", http.StatusBadRequest)
		return
	}

	cd.costTracker.SetBudget(settings.MonthlyLimitUSD, settings.AlertThresholdPercent)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "success"})
}

// StartDashboard is a convenience function to start the cost dashboard
func StartDashboard(port int) error {
	tracker := GetGlobalCostTracker(DefaultConfig())
	dashboard := NewCostDashboard(tracker, port)
	return dashboard.Start()
}
