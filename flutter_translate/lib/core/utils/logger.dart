/// Clean Code logging system with thread-safe operations
/// Following Single Responsibility principle and meaningful naming
library;

import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Log levels following Clean Code naming conventions
enum LogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR');

  const LogLevel(this.value);
  final String value;
}

/// Thread-safe logger implementation with file output
/// Single Responsibility: Handle all logging operations
class Logger {
  static Logger? _instance;
  static const String _logFileName = 'flutter_translate.log';
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');

  late File _logFile;
  final StreamController<String> _logController =
      StreamController<String>.broadcast();
  bool _isInitialized = false;

  /// Private constructor for singleton pattern
  Logger._();

  /// Get the singleton instance
  static Logger get instance {
    _instance ??= Logger._();
    return _instance!;
  }

  /// Initialize the logger with file output
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final logPath = '${directory.path}/$_logFileName';
      _logFile = File(logPath);

      // Ensure log file exists
      if (!await _logFile.exists()) {
        await _logFile.create(recursive: true);
      }

      _isInitialized = true;
      info('Logger initialized successfully');
    } catch (e) {
      // Fallback to stdout if file logging fails
      stderr.writeln('Failed to initialize logger: $e');
      _isInitialized = false;
    }
  }

  /// Log a debug message
  void debug(String message) => _log(LogLevel.debug, message);

  /// Log an info message
  void info(String message) => _log(LogLevel.info, message);

  /// Log a warning message
  void warning(String message) => _log(LogLevel.warning, message);

  /// Log an error message
  void error(String message) => _log(LogLevel.error, message);

  /// Internal logging method with thread-safe file operations
  void _log(LogLevel level, String message) {
    final timestamp = _dateFormat.format(DateTime.now().toUtc());
    final logEntry = '[$timestamp] ${level.value}: $message\n';

    // Add to stream for real-time updates if needed
    _logController.add(logEntry);

    if (!_isInitialized) {
      // Fallback to console if not initialized
      print(logEntry.trim());
      return;
    }

    // Write to file asynchronously and safely
    _writeToFile(logEntry);
  }

  /// Thread-safe file writing operation
  void _writeToFile(String logEntry) async {
    try {
      await _logFile.writeAsString(
        logEntry,
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      // Best effort logging - don't crash the app
      stderr.writeln('Failed to write to log file: $e');
    }
  }

  /// Get the current log file path
  String? get logFilePath => _isInitialized ? _logFile.path : null;

  /// Stream of log entries for real-time monitoring
  Stream<String> get logStream => _logController.stream;

  /// Clean up resources
  void dispose() {
    _logController.close();
  }

  /// Get recent log entries (useful for debugging)
  Future<List<String>> getRecentLogs({int maxLines = 100}) async {
    if (!_isInitialized) return [];

    try {
      final content = await _logFile.readAsString();
      final lines =
          content.split('\n').where((line) => line.trim().isNotEmpty).toList();

      return lines.length > maxLines
          ? lines.sublist(lines.length - maxLines)
          : lines;
    } catch (e) {
      error('Failed to read recent logs: $e');
      return [];
    }
  }

  /// Clear the log file (useful for testing or user request)
  Future<void> clearLogs() async {
    if (!_isInitialized) return;

    try {
      await _logFile.writeAsString('', mode: FileMode.write);
      info('Log file cleared');
    } catch (e) {
      error('Failed to clear log file: $e');
    }
  }
}

/// Convenience functions for easy logging
void logDebug(String message) => Logger.instance.debug(message);
void logInfo(String message) => Logger.instance.info(message);
void logWarning(String message) => Logger.instance.warning(message);
void logError(String message) => Logger.instance.error(message);
