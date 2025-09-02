using System;
using System.IO;

namespace TranslationFiesta
{
    public static class Logger
    {
        private static readonly object _lock = new object();
        private static readonly string LogFile = Path.Combine(AppContext.BaseDirectory, "translationfiesta.log");

        public static void Info(string msg) => Write("INFO", msg);
        public static void Error(string msg) => Write("ERROR", msg);
        public static void Debug(string msg) => Write("DEBUG", msg);

        private static void Write(string level, string msg)
        {
            try
            {
                lock (_lock)
                {
                    File.AppendAllText(LogFile, $"[{DateTime.UtcNow:O}] {level}: {msg}{Environment.NewLine}");
                }
            }
            catch
            {
                // Best effort logging; don't crash app
            }
        }
    }
}
