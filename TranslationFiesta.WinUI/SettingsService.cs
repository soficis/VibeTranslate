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
        public string ProviderId { get; set; } = ProviderIds.GoogleUnofficial;
        public bool UseOfficialApi { get; set; }
        public string? LastFilePath { get; set; }
        public string? LastSavePath { get; set; }
        public string LocalServiceUrl { get; set; } = string.Empty;
        public string LocalModelDir { get; set; } = string.Empty;
        public bool LocalAutoStart { get; set; } = true;
        public int WindowWidth { get; set; } = 1200;
        public int WindowHeight { get; set; } = 800;
        public int WindowX { get; set; } = -1;
        public int WindowY { get; set; } = -1;

        // Cost tracking settings
        public decimal MonthlyBudget { get; set; } = 50.0M;
        public bool CostTrackingEnabled { get; set; } = false;
        public bool EnableCostAlerts { get; set; } = true;
        public bool ShowCostInUI { get; set; } = false;
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
                if (string.IsNullOrWhiteSpace(_cached.ProviderId))
                {
                    _cached.ProviderId = _cached.UseOfficialApi ? ProviderIds.GoogleOfficial : ProviderIds.GoogleUnofficial;
                }
                _cached.ProviderId = ProviderIds.Normalize(_cached.ProviderId);
                _cached.UseOfficialApi = ProviderIds.IsOfficial(_cached.ProviderId);
                return _cached;
            }
            catch (JsonException ex)
            {
                Logger.Warning($"SettingsService.Load parse error: {ex.Message}");
                return new AppSettings();
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Warning($"SettingsService.Load access denied: {ex.Message}");
                return new AppSettings();
            }
            catch (IOException ex)
            {
                Logger.Warning($"SettingsService.Load I/O error: {ex.Message}");
                return new AppSettings();
            }
            catch (Exception ex)
            {
                Logger.Error("SettingsService.Load unexpected error.", ex);
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
            catch (UnauthorizedAccessException ex)
            {
                Logger.Error("SettingsService.Save access denied.", ex);
            }
            catch (IOException ex)
            {
                Logger.Error("SettingsService.Save I/O error.", ex);
            }
            catch (Exception ex)
            {
                Logger.Error("SettingsService.Save unexpected error.", ex);
            }
        }
    }
}
