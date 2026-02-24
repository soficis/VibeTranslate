using System;

namespace TranslationFiestaCSharp
{
    public static class ProviderIds
    {
        public const string Local = "local";
        public const string GoogleUnofficial = "google_unofficial";

        public static string Normalize(string? value)
        {
            var normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
            return normalized switch
            {
                Local => Local,
                "unofficial" => GoogleUnofficial,
                "google_unofficial_free" => GoogleUnofficial,
                "google_free" => GoogleUnofficial,
                "googletranslate" => GoogleUnofficial,
                "" => GoogleUnofficial,
                _ => GoogleUnofficial
            };
        }
    }
}

