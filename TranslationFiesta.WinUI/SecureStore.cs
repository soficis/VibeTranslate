using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace TranslationFiesta.WinUI
{
    // Simple DPAPI-based secure storage for small secrets (per-user)
    public static class SecureStore
    {
        private static string StorePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TranslationFiesta", "secret.bin");

        public static void SaveApiKey(string apiKey)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(StorePath));
                var bytes = Encoding.UTF8.GetBytes(apiKey);
                var enc = ProtectedData.Protect(bytes, null, DataProtectionScope.CurrentUser);
                File.WriteAllBytes(StorePath, enc);
            }
            catch
            {
            }
        }

        public static string? GetApiKey()
        {
            try
            {
                if (!File.Exists(StorePath)) return null;
                var enc = File.ReadAllBytes(StorePath);
                var bytes = ProtectedData.Unprotect(enc, null, DataProtectionScope.CurrentUser);
                return Encoding.UTF8.GetString(bytes);
            }
            catch
            {
                return null;
            }
        }
    }
}
