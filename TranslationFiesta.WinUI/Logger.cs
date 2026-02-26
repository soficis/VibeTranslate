using System;
using System.Collections.Concurrent;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace TranslationFiesta.WinUI
{
    public enum LogLevel
    {
        Debug,
        Info,
        Warning,
        Error,
        Performance
    }

    public static class Logger
    {
        private static readonly ConcurrentQueue<string> _logQueue = new ConcurrentQueue<string>();
        private static readonly CancellationTokenSource _cancellationTokenSource = new CancellationTokenSource();
        private static Task? _logWriterTask;
        private static readonly string LogFile = PortablePaths.LogFile;
        private static bool _isInitialized = false;
        public static LogLevel MinimumLogLevel { get; set; } = LogLevel.Info; // Default to Info
        private static int LogFileMaxSizeKB = 5 * 1024; // 5 MB
        private static int LogFileMaxBackups = 2; // Keep 2 backup files

        public static void Initialize(bool isDebugMode = false)
        {
            if (_isInitialized) return;

            if (isDebugMode)
            {
                MinimumLogLevel = LogLevel.Debug;
            }

            var logDir = Path.GetDirectoryName(LogFile);
            if (!string.IsNullOrEmpty(logDir))
            {
                Directory.CreateDirectory(logDir);
            }

            _logWriterTask = Task.Run(() => ProcessLogQueue(_cancellationTokenSource.Token));
            _isInitialized = true;
            Log(LogLevel.Info, "Logger initialized successfully.");
            if (isDebugMode)
            {
                Log(LogLevel.Debug, "Logger running in DEBUG mode.");
            }
        }

        public static void Debug(string msg) => Log(LogLevel.Debug, msg);
        public static void Info(string msg) => Log(LogLevel.Info, msg);
        public static void Warning(string msg) => Log(LogLevel.Warning, msg);
        public static void Error(string msg, Exception? ex = null) => Log(LogLevel.Error, msg, ex);
        public static void Performance(string msg) => Log(LogLevel.Performance, msg);

        public static void Log(LogLevel level, string msg, Exception? ex = null)
        {
            if (level < MinimumLogLevel)
            {
                return; // Filter out messages below the minimum log level
            }

            string formattedMsg = FormatLogEntry(level, msg, ex);
            EnqueueLog(formattedMsg);
        }

        private static string FormatLogEntry(LogLevel level, string msg, Exception? ex)
        {
            string exceptionDetails = ex != null ? $"{Environment.NewLine}Exception: {ex.GetType().Name} - {ex.Message}{Environment.NewLine}StackTrace: {ex.StackTrace}" : string.Empty;
            return $"[{DateTime.UtcNow:O}] [{level.ToString().ToUpper()}]: {msg}{exceptionDetails}";
        }

        private static void EnqueueLog(string formattedLogEntry)
        {
            if (!_isInitialized)
            {
                // Fallback to console if not initialized
                Console.Error.WriteLine(formattedLogEntry);
                return;
            }

            _logQueue.Enqueue(formattedLogEntry);
        }

        private static async Task ProcessLogQueue(CancellationToken cancellationToken)
        {
            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    // Process any queued messages
                    while (_logQueue.TryDequeue(out string? logEntry))
                    {
                        await WriteToFile(logEntry + Environment.NewLine);
                    }

                    // Wait a short time before checking again
                    await Task.Delay(100, cancellationToken);
                }
                catch (OperationCanceledException)
                {
                    // Cancellation requested, exit gracefully
                    break;
                }
                catch (Exception ex)
                {
                    // Log any unexpected errors to console as fallback
                    Console.Error.WriteLine($"Logger error: {ex.Message}");
                }
            }

            // Process any remaining messages before shutting down
            while (_logQueue.TryDequeue(out string? logEntry))
            {
                try
                {
                    await WriteToFile(logEntry + Environment.NewLine);
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Logger shutdown flush failed: {ex.Message}");
                }
            }
        }

        private static async Task WriteToFile(string logEntry)
        {
            try
            {
                FileInfo logFileInfo = new FileInfo(LogFile);
                if (logFileInfo.Exists && logFileInfo.Length / 1024 >= LogFileMaxSizeKB)
                {
                    RotateLogFiles();
                }
                await File.AppendAllTextAsync(LogFile, logEntry);
            }
            catch (Exception ex)
            {
                // Fallback: try to write to a temp file if the main log fails
                try
                {
                    var tempLog = Path.Combine(Path.GetTempPath(), "TranslationFiesta_critical_error.log");
                    await File.AppendAllTextAsync(tempLog, $"[{DateTime.UtcNow:O}] [CRITICAL]: Failed to write to main log. Original Log: {logEntry}{Environment.NewLine}Exception: {ex.Message}{Environment.NewLine}");
                }
                catch (Exception fallbackEx)
                {
                    Console.Error.WriteLine($"Logger critical fallback write failed: {fallbackEx.Message}");
                }
            }
        }

        private static void RotateLogFiles()
        {
            // Delete oldest backup if max backups reached
            string oldestBackup = $"{LogFile}.{LogFileMaxBackups}";
            if (File.Exists(oldestBackup))
            {
                File.Delete(oldestBackup);
            }

            // Shift existing backups
            for (int i = LogFileMaxBackups - 1; i >= 1; i--)
            {
                string currentBackup = $"{LogFile}.{i}";
                string nextBackup = $"{LogFile}.{i + 1}";
                if (File.Exists(currentBackup))
                {
                    File.Move(currentBackup, nextBackup);
                }
            }

            // Rename current log file to first backup
            if (File.Exists(LogFile))
            {
                File.Move(LogFile, $"{LogFile}.1");
            }
        }

        public static void Dispose()
        {
            if (!_isInitialized) return;

            _cancellationTokenSource.Cancel();
            _logWriterTask?.Wait(); // Wait for the writer task to finish processing remaining logs
            _cancellationTokenSource.Dispose();
            _isInitialized = false;
        }
    }
}
