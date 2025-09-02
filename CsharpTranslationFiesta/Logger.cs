using System;
using System.IO;

namespace CsharpTranslationFiesta
{
    public static class Logger
    {
        private static readonly object _sync = new object();
        private static readonly string LogFilePath = Path.Combine(AppContext.BaseDirectory, "csharptranslationfiesta.log");

        public static void Info(string message) => Write("INFO", message);
        public static void Error(string message) => Write("ERROR", message);
        public static void Debug(string message) => Write("DEBUG", message);
        public static void Warn(string message) => Write("WARN", message);

        private static void Write(string level, string message)
        {
            try
            {
                lock (_sync)
                {
                    File.AppendAllText(LogFilePath, $"[{DateTime.UtcNow:O}] {level}: {message}{Environment.NewLine}");
                }
            }
            catch
            {
                // Best-effort logging: never throw from logger
            }
        }
    }
}


