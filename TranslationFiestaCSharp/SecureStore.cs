using System;
using System.IO;
using System.Security.Cryptography;
using static System.Security.Cryptography.ProtectedData;
using System.Text;

namespace TranslationFiestaCSharp
{
    // Simple DPAPI-based secure storage for small secrets (per-user)
    public static class SecureStore
    {
        private static string StorePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CsharpTranslationFiesta", "secret.bin");

        public static void SaveApiKey(string apiKey)
        {
            try
            {
                var directoryPath = Path.GetDirectoryName(StorePath);
                if (!string.IsNullOrEmpty(directoryPath))
                {
                    Directory.CreateDirectory(directoryPath);
                }
                var bytes = Encoding.UTF8.GetBytes(apiKey);
                var enc = ProtectedData.Protect(bytes, null, DataProtectionScope.CurrentUser);
                File.WriteAllBytes(StorePath, enc);
                Logger.Info("API key saved securely");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save API key: {ex.Message}");
            }
        }

        public static string? GetApiKey()
        {
            try
            {
                if (!File.Exists(StorePath)) return null;
                var enc = File.ReadAllBytes(StorePath);
                var bytes = ProtectedData.Unprotect(enc, null, DataProtectionScope.CurrentUser);
                Logger.Info("API key loaded securely");
                return Encoding.UTF8.GetString(bytes);
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load API key: {ex.Message}");
                return null;
            }
        }

        public static void ClearApiKey()
        {
            try
            {
                if (File.Exists(StorePath))
                {
                    File.Delete(StorePath);
                    Logger.Info("API key cleared");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to clear API key: {ex.Message}");
            }
        }
    }
}