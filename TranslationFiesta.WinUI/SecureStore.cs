using System;
using System.IO;
using System.Security.Cryptography;
using static System.Security.Cryptography.ProtectedData;
using System.Text;

namespace TranslationFiesta.WinUI
{
    // Simple DPAPI-based secure storage for small secrets (per-user)
    public static class SecureStore
    {
        private static string StorePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TranslationFiesta", "secret.bin");

        public static bool SaveApiKey(string apiKey)
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
                return true;
            }
            catch (CryptographicException ex)
            {
                Logger.Error("SecureStore.SaveApiKey cryptography failure.", ex);
                return false;
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Error("SecureStore.SaveApiKey access denied.", ex);
                return false;
            }
            catch (IOException ex)
            {
                Logger.Error("SecureStore.SaveApiKey I/O failure.", ex);
                return false;
            }
            catch (Exception ex)
            {
                Logger.Error("SecureStore.SaveApiKey unexpected failure.", ex);
                return false;
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
            catch (CryptographicException ex)
            {
                Logger.Error("SecureStore.GetApiKey cryptography failure.", ex);
                return null;
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Error("SecureStore.GetApiKey access denied.", ex);
                return null;
            }
            catch (IOException ex)
            {
                Logger.Error("SecureStore.GetApiKey I/O failure.", ex);
                return null;
            }
            catch (Exception ex)
            {
                Logger.Error("SecureStore.GetApiKey unexpected failure.", ex);
                return null;
            }
        }

        public static bool ClearApiKey()
        {
            try
            {
                if (File.Exists(StorePath))
                {
                    File.Delete(StorePath);
                }
                return true;
            }
            catch (UnauthorizedAccessException ex)
            {
                Logger.Error("SecureStore.ClearApiKey access denied.", ex);
                return false;
            }
            catch (IOException ex)
            {
                Logger.Error("SecureStore.ClearApiKey I/O failure.", ex);
                return false;
            }
            catch (Exception ex)
            {
                Logger.Error("SecureStore.ClearApiKey unexpected failure.", ex);
                return false;
            }
        }
    }
}
