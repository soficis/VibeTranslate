using System;
using System.IO;

namespace TranslationFiestaCSharp
{
    internal static class PortablePaths
    {
        private static readonly string _dataRoot = ResolveDataRoot();

        public static string DataRoot => _dataRoot;
        public static string SettingsFile => Path.Combine(DataRoot, "settings.json");
        public static string TranslationMemoryFile => Path.Combine(DataRoot, "tm_cache.json");
        public static string LogsDirectory => EnsureDirectory(Path.Combine(DataRoot, "logs"));
        public static string LogFile => Path.Combine(LogsDirectory, "translationfiestacsharp.log");
        public static string ExportsDirectory => EnsureDirectory(Path.Combine(DataRoot, "exports"));

        private static string ResolveDataRoot()
        {
            var overridePath = Environment.GetEnvironmentVariable("TF_APP_HOME");
            if (!string.IsNullOrWhiteSpace(overridePath))
            {
                return EnsureDirectory(Path.GetFullPath(overridePath));
            }

            var baseDirectory = AppContext.BaseDirectory;
            return EnsureDirectory(Path.Combine(baseDirectory, "data"));
        }

        private static string EnsureDirectory(string path)
        {
            Directory.CreateDirectory(path);
            return path;
        }
    }
}
