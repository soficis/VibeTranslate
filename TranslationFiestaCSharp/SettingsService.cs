using System;
using System.IO;
using System.Text.Json;

namespace TranslationFiestaCSharp
{
    public class AppSettings
    {
        public bool DarkMode { get; set; } = false;
        public bool UseOfficialApi { get; set; } = false;
        public int WindowWidth { get; set; } = 900;
        public int WindowHeight { get; set; } = 850;
        public int WindowX { get; set; } = -1; // -1 means center
        public int WindowY { get; set; } = -1; // -1 means center
        public string LastFilePath { get; set; } = "";
        public string LastSavePath { get; set; } = "";
    }

    public static class SettingsService
    {
        private static readonly string SettingsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CsharpTranslationFiesta", "settings.json");
        private static AppSettings? _cached;

        public static AppSettings Load()
        {
            try
            {
                Logger.Debug("Attempting to load settings.");
                if (_cached != null)
                {
                    Logger.Debug("Returning cached settings.");
                    return _cached;
                }
                if (!File.Exists(SettingsPath))
                {
                    Logger.Info("Settings file not found. Returning default settings.");
                    return _cached = new AppSettings();
                }
                var json = File.ReadAllText(SettingsPath);
                _cached = JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
                Logger.Info("Settings loaded successfully.");
                Logger.Debug($"Loaded settings: DarkMode={_cached.DarkMode}, UseOfficialApi={_cached.UseOfficialApi}, WindowSize={_cached.WindowWidth}x{_cached.WindowHeight}");
                return _cached;
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load settings.", ex);
                return new AppSettings();
            }
        }

        public static void Save(AppSettings settings)
        {
            try
            {
                Logger.Debug("Attempting to save settings.");
                var directory = Path.GetDirectoryName(SettingsPath);
                if (!string.IsNullOrEmpty(directory))
                {
                    Directory.CreateDirectory(directory);
                    Logger.Debug($"Ensured settings directory exists: {directory}");
                }
                var json = JsonSerializer.Serialize(settings, new JsonSerializerOptions { WriteIndented = true });
                File.WriteAllText(SettingsPath, json);
                _cached = settings;
                Logger.Info("Settings saved successfully.");
                Logger.Debug($"Saved settings: DarkMode={settings.DarkMode}, UseOfficialApi={settings.UseOfficialApi}, WindowSize={settings.WindowWidth}x{settings.WindowHeight}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save settings.", ex);
            }
        }

        public static void SaveCurrentSettings(bool darkMode, bool useOfficialApi, int width, int height, int x, int y, string lastFilePath = "", string lastSavePath = "")
        {
            var settings = new AppSettings
            {
                DarkMode = darkMode,
                UseOfficialApi = useOfficialApi,
                WindowWidth = width,
                WindowHeight = height,
                WindowX = x,
                WindowY = y,
                LastFilePath = lastFilePath,
                LastSavePath = lastSavePath
            };
            Save(settings);
        }
    }
}