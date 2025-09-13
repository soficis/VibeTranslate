using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;

namespace TranslationFiesta.WinUI
{
    /// <summary>
    /// Tracks translation costs and usage statistics for Google Translate API
    /// </summary>
    public class CostTracker
    {
        private const decimal CostPerMillionChars = 20.0M;
        private static readonly string CostDataPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "TranslationFiesta",
            "cost_data.json");

        private readonly object _lock = new object();
        private CostData _costData;

        public CostTracker()
        {
            _costData = LoadCostData();
        }

        /// <summary>
        /// Calculates cost for a given character count
        /// </summary>
        public decimal CalculateCost(int characterCount)
        {
            if (characterCount <= 0)
                return 0;

            return Math.Round((characterCount / 1_000_000.0M) * CostPerMillionChars, 6);
        }

        /// <summary>
        /// Records a translation cost and updates statistics
        /// </summary>
        public void RecordTranslation(int characterCount, string fromLang, string toLang)
        {
            if (characterCount <= 0)
                return;

            lock (_lock)
            {
                var cost = CalculateCost(characterCount);
                var now = DateTime.Now;
                var currentMonth = new DateTime(now.Year, now.Month, 1);

                // Update monthly statistics
                if (!_costData.MonthlyStats.ContainsKey(currentMonth))
                {
                    _costData.MonthlyStats[currentMonth] = new MonthlyStats();
                }

                var monthlyStats = _costData.MonthlyStats[currentMonth];
                monthlyStats.TotalCharacters += characterCount;
                monthlyStats.TotalCost += cost;
                monthlyStats.TranslationCount++;
                monthlyStats.LastUpdated = now;

                // Update overall statistics
                _costData.TotalCharacters += characterCount;
                _costData.TotalCost += cost;
                _costData.TotalTranslations++;
                _costData.LastUpdated = now;

                // Add to history
                _costData.TranslationHistory.Add(new TranslationRecord
                {
                    Timestamp = now,
                    CharacterCount = characterCount,
                    Cost = cost,
                    FromLanguage = fromLang,
                    ToLanguage = toLang
                });

                // Keep only last 1000 records
                if (_costData.TranslationHistory.Count > 1000)
                {
                    _costData.TranslationHistory.RemoveAt(0);
                }

                SaveCostData();

                Logger.Info($"Cost recorded: {characterCount} chars, ${cost:F6}, Total: ${_costData.TotalCost:F2}");

                // Check budget alerts
                CheckBudgetAlerts();
            }
        }

        /// <summary>
        /// Gets current monthly statistics
        /// </summary>
        public MonthlyStats GetCurrentMonthStats()
        {
            lock (_lock)
            {
                var currentMonth = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1);
                return _costData.MonthlyStats.GetValueOrDefault(currentMonth, new MonthlyStats());
            }
        }

        /// <summary>
        /// Gets monthly statistics for a specific month
        /// </summary>
        public MonthlyStats GetMonthlyStats(DateTime month)
        {
            var monthStart = new DateTime(month.Year, month.Month, 1);
            lock (_lock)
            {
                return _costData.MonthlyStats.GetValueOrDefault(monthStart, new MonthlyStats());
            }
        }

        /// <summary>
        /// Gets overall statistics
        /// </summary>
        public (long TotalCharacters, decimal TotalCost, int TotalTranslations) GetOverallStats()
        {
            lock (_lock)
            {
                return (_costData.TotalCharacters, _costData.TotalCost, _costData.TotalTranslations);
            }
        }

        /// <summary>
        /// Sets monthly budget limit
        /// </summary>
        public void SetMonthlyBudget(decimal budget)
        {
            lock (_lock)
            {
                _costData.MonthlyBudget = Math.Max(0, budget);
                SaveCostData();
                Logger.Info($"Monthly budget set to: ${budget:F2}");
            }
        }

        /// <summary>
        /// Gets current monthly budget
        /// </summary>
        public decimal GetMonthlyBudget()
        {
            lock (_lock)
            {
                return _costData.MonthlyBudget;
            }
        }

        /// <summary>
        /// Gets recent translation history
        /// </summary>
        public List<TranslationRecord> GetRecentHistory(int count = 50)
        {
            lock (_lock)
            {
                return _costData.TranslationHistory
                    .OrderByDescending(r => r.Timestamp)
                    .Take(count)
                    .ToList();
            }
        }

        /// <summary>
        /// Clears all cost data
        /// </summary>
        public void ClearData()
        {
            lock (_lock)
            {
                _costData = new CostData();
                SaveCostData();
                Logger.Info("Cost data cleared");
            }
        }

        /// <summary>
        /// Checks if current spending exceeds budget and logs warnings
        /// </summary>
        private void CheckBudgetAlerts()
        {
            var currentStats = GetCurrentMonthStats();
            var budget = _costData.MonthlyBudget;

            if (budget > 0)
            {
                var percentage = (currentStats.TotalCost / budget) * 100;

                if (percentage >= 100)
                {
                    Logger.Warning($"Monthly budget exceeded! Spent: ${currentStats.TotalCost:F2}, Budget: ${budget:F2}");
                }
                else if (percentage >= 80)
                {
                    Logger.Warning($"Budget alert: {percentage:F1}% of monthly budget used (${currentStats.TotalCost:F2}/${budget:F2})");
                }
                else if (percentage >= 50)
                {
                    Logger.Info($"Budget status: {percentage:F1}% of monthly budget used (${currentStats.TotalCost:F2}/${budget:F2})");
                }
            }
        }

        /// <summary>
        /// Loads cost data from JSON file
        /// </summary>
        private CostData LoadCostData()
        {
            try
            {
                if (!File.Exists(CostDataPath))
                    return new CostData();

                var json = File.ReadAllText(CostDataPath);
                var data = JsonSerializer.Deserialize<CostData>(json);

                if (data == null)
                    return new CostData();

                // Ensure all required properties are initialized
                data.MonthlyStats ??= new Dictionary<DateTime, MonthlyStats>();
                data.TranslationHistory ??= new List<TranslationRecord>();

                return data;
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load cost data: {ex.Message}", ex);
                return new CostData();
            }
        }

        /// <summary>
        /// Saves cost data to JSON file
        /// </summary>
        private void SaveCostData()
        {
            try
            {
                var directory = Path.GetDirectoryName(CostDataPath);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }

                var options = new JsonSerializerOptions
                {
                    WriteIndented = true,
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };

                var json = JsonSerializer.Serialize(_costData, options);
                File.WriteAllText(CostDataPath, json);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save cost data: {ex.Message}", ex);
            }
        }
    }

    /// <summary>
    /// Monthly usage statistics
    /// </summary>
    public class MonthlyStats
    {
        public long TotalCharacters { get; set; }
        public decimal TotalCost { get; set; }
        public int TranslationCount { get; set; }
        public DateTime LastUpdated { get; set; }

        public decimal AverageCostPerTranslation => TranslationCount > 0 ? TotalCost / TranslationCount : 0;
        public decimal CostPerThousandChars => TotalCharacters > 0 ? (TotalCost / TotalCharacters) * 1000 : 0;
    }

    /// <summary>
    /// Individual translation record
    /// </summary>
    public class TranslationRecord
    {
        public DateTime Timestamp { get; set; }
        public int CharacterCount { get; set; }
        public decimal Cost { get; set; }
        public string? FromLanguage { get; set; }
        public string? ToLanguage { get; set; }
    }

    /// <summary>
    /// Cost tracking data structure
    /// </summary>
    public class CostData
    {
        public long TotalCharacters { get; set; }
        public decimal TotalCost { get; set; }
        public int TotalTranslations { get; set; }
        public decimal MonthlyBudget { get; set; } = 50.0M; // Default $50 monthly budget
        public DateTime LastUpdated { get; set; }
        public Dictionary<DateTime, MonthlyStats> MonthlyStats { get; set; } = new();
        public List<TranslationRecord> TranslationHistory { get; set; } = new();
    }
}