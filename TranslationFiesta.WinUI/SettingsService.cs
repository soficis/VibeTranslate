using System;
using System.IO;
using System.Text.Json;

namespace TranslationFiesta.WinUI
{
    public class AppSettings
    {
        public string? LastSource { get; set; }
        public string? LastTarget { get; set; }
        public bool DarkMode { get; set; }
        public bool UseOfficialApi { get; set; }
        public string? LastFilePath { get; set; }
        public string? LastSavePath { get; set; }
        public int WindowWidth { get; set; } = 1200;
        public int WindowHeight { get; set; } = 800;
        public int WindowX { get; set; } = -1;
        public int WindowY { get; set; } = -1;

        // Cost tracking settings
        public decimal MonthlyBudget { get; set; } = 50.0M;
        public bool EnableCostAlerts { get; set; } = true;
        public bool ShowCostInUI { get; set; } = true;
    }

    public static class SettingsService
    {
        private static readonly string PathFile = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TranslationFiesta", "settings.json");
        private static AppSettings? _cached;

        public static AppSettings Load()
        {
            try
            {
                if (_cached != null) return _cached;
                if (!File.Exists(PathFile)) return _cached = new AppSettings();
                var txt = File.ReadAllText(PathFile);
                _cached = JsonSerializer.Deserialize<AppSettings>(txt) ?? new AppSettings();
                return _cached;
            }
            catch
            {
                return new AppSettings();
            }
        }

        public static void Save(AppSettings s)
        {
            try
            {
                var directory = Path.GetDirectoryName(PathFile);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                }
                var txt = JsonSerializer.Serialize(s, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(PathFile, txt);
                _cached = s;
            }
            catch
            {
            }
        }
    }
}
