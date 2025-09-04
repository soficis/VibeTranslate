package utils

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

// LogLevel represents the severity level of a log message
type LogLevel int

const (
	DEBUG LogLevel = iota
	INFO
	WARN
	ERROR
)

// Logger provides structured logging functionality
type Logger struct {
	level  LogLevel
	logger *log.Logger
	file   *os.File
}

// Global logger instance
var globalLogger *Logger

// NewLogger creates a new logger instance
func NewLogger(level LogLevel, logFile string) (*Logger, error) {
	var file *os.File
	var err error

	if logFile != "" {
		// Create log directory if it doesn't exist
		logDir := filepath.Dir(logFile)
		if err := os.MkdirAll(logDir, 0755); err != nil {
			return nil, fmt.Errorf("failed to create log directory: %w", err)
		}

		file, err = os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
		if err != nil {
			return nil, fmt.Errorf("failed to open log file: %w", err)
		}
	}

	logger := &Logger{
		level:  level,
		logger: log.New(file, "", log.LstdFlags),
		file:   file,
	}

	return logger, nil
}

// GetLogger returns the global logger instance
func GetLogger() *Logger {
	return globalLogger
}

// InitLogger initializes the global logger
func InitLogger(level LogLevel, logFile string) error {
	logger, err := NewLogger(level, logFile)
	if err != nil {
		return err
	}

	globalLogger = logger
	return nil
}

// Close closes the logger and its file handle
func (l *Logger) Close() error {
	if l.file != nil {
		return l.file.Close()
	}
	return nil
}

// log writes a message to the log with the specified level
func (l *Logger) log(level LogLevel, format string, args ...interface{}) {
	if level < l.level {
		return
	}

	levelStr := l.getLevelString(level)
	timestamp := time.Now().Format("2006-01-02 15:04:05")

	message := fmt.Sprintf(format, args...)
	logEntry := fmt.Sprintf("[%s] %s: %s", timestamp, levelStr, message)

	if l.logger != nil {
		l.logger.Println(logEntry)
	} else {
		fmt.Println(logEntry)
	}
}

// Debug logs a debug message
func (l *Logger) Debug(format string, args ...interface{}) {
	l.log(DEBUG, format, args...)
}

// Info logs an info message
func (l *Logger) Info(format string, args ...interface{}) {
	l.log(INFO, format, args...)
}

// Warn logs a warning message
func (l *Logger) Warn(format string, args ...interface{}) {
	l.log(WARN, format, args...)
}

// Error logs an error message
func (l *Logger) Error(format string, args ...interface{}) {
	l.log(ERROR, format, args...)
}

// getLevelString returns the string representation of a log level
func (l *Logger) getLevelString(level LogLevel) string {
	switch level {
	case DEBUG:
		return "DEBUG"
	case INFO:
		return "INFO"
	case WARN:
		return "WARN"
	case ERROR:
		return "ERROR"
	default:
		return "UNKNOWN"
	}
}

// Convenience functions for global logger
func Debug(format string, args ...interface{}) {
	if globalLogger != nil {
		globalLogger.Debug(format, args...)
	}
}

func Info(format string, args ...interface{}) {
	if globalLogger != nil {
		globalLogger.Info(format, args...)
	}
}

func Warn(format string, args ...interface{}) {
	if globalLogger != nil {
		globalLogger.Warn(format, args...)
	}
}

func Error(format string, args ...interface{}) {
	if globalLogger != nil {
		globalLogger.Error(format, args...)
	}
}
