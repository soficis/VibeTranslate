using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace TranslationFiestaCSharp
{
    public class CostEntry
    {
        public double Timestamp { get; set; }
        public int Characters { get; set; }
        public double CostUSD { get; set; }
        public string SourceLang { get; set; } = string.Empty;
        public string TargetLang { get; set; } = string.Empty;
        public string Implementation { get; set; } = string.Empty;
        public string APIVersion { get; set; } = "v2";
    }

    public class Budget
    {
        public double MonthlyLimitUSD { get; set; }
        public double CurrentMonthUsageUSD { get; set; }
        public double AlertThresholdPercent { get; set; } = 80.0;
        public double LastResetTimestamp { get; set; }

        public bool IsNearLimit()
        {
            if (MonthlyLimitUSD <= 0) return false;
            double usagePercent = (CurrentMonthUsageUSD / MonthlyLimitUSD) * 100;
            return usagePercent >= AlertThresholdPercent;
        }

        public bool IsOverLimit()
        {
            return CurrentMonthUsageUSD >= MonthlyLimitUSD;
        }
    }

    public class CostTracker
    {
        private const double CostPerMillionChars = 20.0;
        private readonly string _storagePath;
        private readonly List<CostEntry> _costEntries;
        private readonly Budget _budget;
        private readonly List<Action<string, double>> _alertCallbacks;
        private readonly ReaderWriterLockSlim _lock;
        private readonly object _fileLock = new object();

        public CostTracker(string storagePath = "translation_costs.json")
        {
            _storagePath = storagePath;
            _costEntries = new List<CostEntry>();
            _budget = new Budget
            {
                MonthlyLimitUSD = 50.0, // Default $50/month
                CurrentMonthUsageUSD = 0.0,
                AlertThresholdPercent = 80.0,
                LastResetTimestamp = 0.0
            };
            _alertCallbacks = new List<Action<string, double>>();
            _lock = new ReaderWriterLockSlim();

            LoadData();
        }

        public static double CalculateCost(int characters)
        {
            if (characters <= 0) return 0.0;
            return (characters / 1_000_000.0) * CostPerMillionChars;
        }

        public CostEntry TrackTranslation(int characters, string sourceLang, string targetLang,
                                        string implementation = "csharp", string apiVersion = "v2")
        {
            _lock.EnterWriteLock();
            try
            {
                double costUSD = CalculateCost(characters);

                var entry = new CostEntry
                {
                    Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
                    Characters = characters,
                    CostUSD = costUSD,
                    SourceLang = sourceLang,
                    TargetLang = targetLang,
                    Implementation = implementation,
                    APIVersion = apiVersion
                };

                _costEntries.Add(entry);
                _budget.CurrentMonthUsageUSD += costUSD;

                // Check for budget alerts
                CheckBudgetAlerts();

                // Save to persistent storage
                SaveData();

                Logger.Info($"Tracked translation: {characters} chars, ${costUSD:F6}, {sourceLang}->{targetLang}, total this month: ${_budget.CurrentMonthUsageUSD:F2}");

                return entry;
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        public void SetBudget(double monthlyLimitUSD, double alertThresholdPercent = 80.0)
        {
            _lock.EnterWriteLock();
            try
            {
                _budget.MonthlyLimitUSD = monthlyLimitUSD;
                _budget.AlertThresholdPercent = alertThresholdPercent;
                SaveData();

                Logger.Info($"Budget set to ${monthlyLimitUSD:F2}/month with {alertThresholdPercent:F1}% alert threshold");
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        public Dictionary<string, object> GetBudgetStatus()
        {
            _lock.EnterReadLock();
            try
            {
                double usagePercent = 0.0;
                if (_budget.MonthlyLimitUSD > 0)
                {
                    usagePercent = (_budget.CurrentMonthUsageUSD / _budget.MonthlyLimitUSD) * 100;
                }

                return new Dictionary<string, object>
                {
                    ["monthly_limit_usd"] = _budget.MonthlyLimitUSD,
                    ["current_month_usage_usd"] = _budget.CurrentMonthUsageUSD,
                    ["usage_percent"] = usagePercent,
                    ["alert_threshold_percent"] = _budget.AlertThresholdPercent,
                    ["is_near_limit"] = _budget.IsNearLimit(),
                    ["is_over_limit"] = _budget.IsOverLimit(),
                    ["remaining_budget_usd"] = Math.Max(0, _budget.MonthlyLimitUSD - _budget.CurrentMonthUsageUSD)
                };
            }
            finally
            {
                _lock.ExitReadLock();
            }
        }

        public Dictionary<string, object> GetCostReport(int days = 30, bool groupByImplementation = true)
        {
            _lock.EnterReadLock();
            try
            {
                double cutoffTime = DateTimeOffset.UtcNow.AddDays(-days).ToUnixTimeSeconds();

                var recentEntries = _costEntries.Where(e => e.Timestamp >= cutoffTime).ToList();

                double totalCost = recentEntries.Sum(e => e.CostUSD);
                int totalChars = recentEntries.Sum(e => e.Characters);

                var report = new Dictionary<string, object>
                {
                    ["period_days"] = days,
                    ["total_cost_usd"] = totalCost,
                    ["total_characters"] = totalChars,
                    ["average_cost_per_char"] = totalChars > 0 ? totalCost / totalChars : 0,
                    ["entry_count"] = recentEntries.Count,
                    ["cost_per_million_chars"] = CostPerMillionChars
                };

                if (groupByImplementation)
                {
                    var implStats = new Dictionary<string, Dictionary<string, object>>();
                    var grouped = recentEntries.GroupBy(e => e.Implementation);

                    foreach (var group in grouped)
                    {
                        implStats[group.Key] = new Dictionary<string, object>
                        {
                            ["total_cost_usd"] = group.Sum(e => e.CostUSD),
                            ["total_characters"] = group.Sum(e => e.Characters),
                            ["entry_count"] = group.Count()
                        };
                    }

                    report["by_implementation"] = implStats;
                }

                return report;
            }
            finally
            {
                _lock.ExitReadLock();
            }
        }

        public List<CostEntry> GetRecentEntries(int limit = 100)
        {
            _lock.EnterReadLock();
            try
            {
                return _costEntries
                    .OrderByDescending(e => e.Timestamp)
                    .Take(limit)
                    .ToList();
            }
            finally
            {
                _lock.ExitReadLock();
            }
        }

        public int ClearOldEntries(int daysToKeep = 365)
        {
            _lock.EnterWriteLock();
            try
            {
                double cutoffTime = DateTimeOffset.UtcNow.AddDays(-daysToKeep).ToUnixTimeSeconds();
                int originalCount = _costEntries.Count;

                _costEntries.RemoveAll(e => e.Timestamp < cutoffTime);

                int removedCount = originalCount - _costEntries.Count;
                if (removedCount > 0)
                {
                    SaveData();
                    Logger.Info($"Cleared {removedCount} old cost entries (kept last {daysToKeep} days)");
                }

                return removedCount;
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        public void ResetBudget()
        {
            _lock.EnterWriteLock();
            try
            {
                _budget.CurrentMonthUsageUSD = 0.0;
                _budget.LastResetTimestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
                SaveData();

                Logger.Info("Monthly budget usage reset to $0.00");
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        public void AddAlertCallback(Action<string, double> callback)
        {
            _lock.EnterWriteLock();
            try
            {
                _alertCallbacks.Add(callback);
            }
            finally
            {
                _lock.ExitWriteLock();
            }
        }

        private void CheckBudgetAlerts()
        {
            if (_budget.IsOverLimit())
            {
                TriggerAlert("BUDGET_EXCEEDED",
                    $"Monthly budget exceeded! Current usage: ${_budget.CurrentMonthUsageUSD:F2}, Limit: ${_budget.MonthlyLimitUSD:F2}");
            }
            else if (_budget.IsNearLimit())
            {
                double usagePercent = (_budget.CurrentMonthUsageUSD / _budget.MonthlyLimitUSD) * 100;
                TriggerAlert("BUDGET_WARNING",
                    $"Approaching budget limit: {usagePercent:F1}% used (${_budget.CurrentMonthUsageUSD:F2} of ${_budget.MonthlyLimitUSD:F2})");
            }
        }

        private void TriggerAlert(string alertType, string message)
        {
            Logger.Warn($"Cost Alert [{alertType}]: {message}");

            // Call all registered alert callbacks
            foreach (var callback in _alertCallbacks.ToList())
            {
                try
                {
                    Task.Run(() => callback(alertType, _budget.CurrentMonthUsageUSD));
                }
                catch (Exception ex)
                {
                    Logger.Error($"Alert callback failed: {ex.Message}");
                }
            }
        }

        private void LoadData()
        {
            try
            {
                if (!File.Exists(_storagePath))
                {
                    // Initialize with defaults if file doesn't exist
                    RecalculateCurrentMonthUsage();
                    return;
                }

                lock (_fileLock)
                {
                    string json = File.ReadAllText(_storagePath);
                    var data = JsonSerializer.Deserialize<JsonElement>(json);

                    // Load cost entries
                    if (data.TryGetProperty("cost_entries", out var entriesElement))
                    {
                        var entries = JsonSerializer.Deserialize<List<CostEntry>>(entriesElement.GetRawText());
                        if (entries != null)
                        {
                            _costEntries.AddRange(entries);
                        }
                    }

                    // Load budget
                    if (data.TryGetProperty("budget", out var budgetElement))
                    {
                        var budget = JsonSerializer.Deserialize<Budget>(budgetElement.GetRawText());
                        if (budget != null)
                        {
                            _budget.MonthlyLimitUSD = budget.MonthlyLimitUSD;
                            _budget.CurrentMonthUsageUSD = budget.CurrentMonthUsageUSD;
                            _budget.AlertThresholdPercent = budget.AlertThresholdPercent;
                            _budget.LastResetTimestamp = budget.LastResetTimestamp;
                        }
                    }
                }

                // Recalculate current month usage
                RecalculateCurrentMonthUsage();

                Logger.Info($"Loaded {_costEntries.Count} cost entries from {_storagePath}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load cost data: {ex.Message}");
                // Initialize with defaults if loading fails
            }
        }

        private void SaveData()
        {
            try
            {
                var data = new
                {
                    cost_entries = _costEntries,
                    budget = _budget,
                    last_updated = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
                };

                lock (_fileLock)
                {
                    string json = JsonSerializer.Serialize(data, new JsonSerializerOptions
                    {
                        WriteIndented = true
                    });
                    File.WriteAllText(_storagePath, json);
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save cost data: {ex.Message}");
            }
        }

        private void RecalculateCurrentMonthUsage()
        {
            var now = DateTimeOffset.UtcNow;
            var currentMonth = new DateTimeOffset(now.Year, now.Month, 1, 0, 0, 0, TimeSpan.Zero);

            double totalCost = 0.0;
            foreach (var entry in _costEntries)
            {
                var entryTime = DateTimeOffset.FromUnixTimeSeconds((long)entry.Timestamp);
                var entryMonth = new DateTimeOffset(entryTime.Year, entryTime.Month, 1, 0, 0, 0, TimeSpan.Zero);

                if (entryMonth >= currentMonth)
                {
                    totalCost += entry.CostUSD;
                }
            }

            _budget.CurrentMonthUsageUSD = totalCost;

            // Reset budget if it's a new month
            if (_budget.LastResetTimestamp == 0 ||
                DateTimeOffset.FromUnixTimeSeconds((long)_budget.LastResetTimestamp).Month != now.Month)
            {
                _budget.LastResetTimestamp = currentMonth.ToUnixTimeSeconds();
                SaveData();
            }
        }

        // Singleton pattern for global access
        private static CostTracker? _instance;
        private static readonly object _instanceLock = new object();

        public static CostTracker Instance
        {
            get
            {
                if (_instance == null)
                {
                    lock (_instanceLock)
                    {
                        if (_instance == null)
                        {
                            _instance = new CostTracker();
                        }
                    }
                }
                return _instance;
            }
        }

        // Convenience method for tracking costs
        public static CostEntry TrackTranslationCost(int characters, string sourceLang, string targetLang,
                                                    string implementation = "csharp", string apiVersion = "v2")
        {
            return Instance.TrackTranslation(characters, sourceLang, targetLang, implementation, apiVersion);
        }
    }
}