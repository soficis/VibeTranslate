using System;
using System.IO;
using System.Text.Json;

namespace TranslationFiestaCSharp
{
    public class AppSettings
    {
        public bool DarkMode { get; set; } = false;
        public string ProviderId { get; set; } = ProviderIds.GoogleUnofficial;
        public int WindowWidth { get; set; } = 900;
        public int WindowHeight { get; set; } = 850;
        public int WindowX { get; set; } = -1; // -1 means center
        public int WindowY { get; set; } = -1; // -1 means center
        public string LastFilePath { get; set; } = "";
        public string LastSavePath { get; set; } = "";
    }

    public static class SettingsService
    {
        private static readonly string SettingsPath = PortablePaths.SettingsFile;
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
                if (string.IsNullOrWhiteSpace(_cached.ProviderId))
                {
                    _cached.ProviderId = ProviderIds.GoogleUnofficial;
                }
                _cached.ProviderId = ProviderIds.Normalize(_cached.ProviderId);
                Logger.Info("Settings loaded successfully.");
                Logger.Debug($"Loaded settings: DarkMode={_cached.DarkMode}, ProviderId={_cached.ProviderId}, WindowSize={_cached.WindowWidth}x{_cached.WindowHeight}");
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
                Logger.Debug($"Saved settings: DarkMode={settings.DarkMode}, ProviderId={settings.ProviderId}, WindowSize={settings.WindowWidth}x{settings.WindowHeight}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save settings.", ex);
            }
        }

        public static void SaveCurrentSettings(bool darkMode, string providerId, int width, int height, int x, int y, string lastFilePath = "", string lastSavePath = "")
        {
            var current = Load();
            var normalizedProvider = ProviderIds.Normalize(providerId);
            current.DarkMode = darkMode;
            current.ProviderId = normalizedProvider;
            current.WindowWidth = width;
            current.WindowHeight = height;
            current.WindowX = x;
            current.WindowY = y;
            current.LastFilePath = lastFilePath;
            current.LastSavePath = lastSavePath;
            Save(current);
        }
    }
}
