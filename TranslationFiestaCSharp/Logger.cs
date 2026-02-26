using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;

namespace TranslationFiestaCSharp
{
    public static class Logger
    {
        private static readonly object _sync = new object();
        private static readonly string LogFilePath = PortablePaths.LogFile;
        private static readonly long MaxLogFileSize = 5 * 1024 * 1024; // 5 MB
        private static readonly int MaxLogFiles = 5; // Keep up to 5 log files
        public static bool IsDebugEnabled { get; set; } = false; // Default to false

        public enum LogLevel
        {
            Debug,
            Info,
            Warn,
            Error,
            Performance
        }

        public static void Info(string message, [CallerMemberName] string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber] int lineNumber = 0) =>
            Write(LogLevel.Info, message, null, memberName, filePath, lineNumber);

        public static void Error(string message, Exception? exception = null, [CallerMemberName] string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber] int lineNumber = 0) =>
            Write(LogLevel.Error, message, exception, memberName, filePath, lineNumber);

        public static void Debug(string message, [CallerMemberName] string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber] int lineNumber = 0)
        {
            if (IsDebugEnabled)
            {
                Write(LogLevel.Debug, message, null, memberName, filePath, lineNumber);
            }
        }

        public static void Warn(string message, [CallerMemberName] string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber] int lineNumber = 0) =>
            Write(LogLevel.Warn, message, null, memberName, filePath, lineNumber);

        public static void Performance(string message, TimeSpan duration, [CallerMemberName] string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber] int lineNumber = 0) =>
            Write(LogLevel.Performance, $"{message} - Duration: {duration.TotalMilliseconds:F2}ms", null, memberName, filePath, lineNumber);

        private static void Write(LogLevel level, string message, Exception? exception, string memberName, string filePath, int lineNumber)
        {
            try
            {
                lock (_sync)
                {
                    CheckForLogFileRotation();

                    var logMessage = $"[{DateTime.UtcNow:O}] [{level.ToString().ToUpper()}] ";
                    if (!string.IsNullOrEmpty(memberName))
                    {
                        logMessage += $"[{Path.GetFileNameWithoutExtension(filePath)}.{memberName}:{lineNumber}] ";
                    }
                    logMessage += $"{message}";

                    if (exception != null)
                    {
                        logMessage += $"{Environment.NewLine}Exception: {exception.GetType().Name} - {exception.Message}{Environment.NewLine}{exception.StackTrace}";
                    }

                    File.AppendAllText(LogFilePath, $"{logMessage}{Environment.NewLine}");
                }
            }
            catch
            {
                // Best-effort logging: never throw from logger
            }
        }

        private static void CheckForLogFileRotation()
        {
            FileInfo logFile = new FileInfo(LogFilePath);
            if (logFile.Exists && logFile.Length >= MaxLogFileSize)
            {
                // Rotate log files
                for (int i = MaxLogFiles - 1; i >= 1; i--)
                {
                    string oldFilePath = $"{LogFilePath}.{i}";
                    string newFilePath = $"{LogFilePath}.{i + 1}";

                    if (File.Exists(newFilePath))
                    {
                        File.Delete(newFilePath);
                    }
                    if (File.Exists(oldFilePath))
                    {
                        File.Move(oldFilePath, newFilePath);
                    }
                }
                if (File.Exists(LogFilePath))
                {
                    File.Move(LogFilePath, $"{LogFilePath}.1");
                }
            }
        }
    }
}

