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
                Directory.CreateDirectory(Path.GetDirectoryName(PathFile)!);
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
