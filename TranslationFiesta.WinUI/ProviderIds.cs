using System;

namespace TranslationFiesta.WinUI
{
    public static class ProviderIds
    {
        public const string Local = "local";
        public const string GoogleUnofficial = "google_unofficial";
        public const string GoogleOfficial = "google_official";

        public static string Normalize(string? value)
        {
            var normalized = (value ?? string.Empty).Trim().ToLowerInvariant();
            return normalized switch
            {
                Local => Local,
                GoogleOfficial => GoogleOfficial,
                "official" => GoogleOfficial,
                "google" => GoogleOfficial,
                "google_cloud" => GoogleOfficial,
                "googlecloud" => GoogleOfficial,
                "unofficial" => GoogleUnofficial,
                "google_unofficial_free" => GoogleUnofficial,
                "google_free" => GoogleUnofficial,
                "googletranslate" => GoogleUnofficial,
                "" => GoogleUnofficial,
                _ => GoogleUnofficial
            };
        }

        public static bool IsOfficial(string? value)
        {
            return Normalize(value) == GoogleOfficial;
        }
    }
}

