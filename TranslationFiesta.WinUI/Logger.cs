using System;
using System.IO;

namespace TranslationFiesta.WinUI
{
    public static class Logger
    {
        private static readonly object _lock = new object();
        private static readonly string LogFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TranslationFiesta", "translationfiesta.log");

        public static void Info(string msg) => Write("INFO", msg);
        public static void Error(string msg) => Write("ERROR", msg);

        private static void Write(string level, string msg)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogFile)!);
                lock (_lock)
                {
                    File.AppendAllText(LogFile, $"[{DateTime.UtcNow:O}] {level}: {msg}{Environment.NewLine}");
                }
            }
            catch
            {
            }
        }
    }
}
