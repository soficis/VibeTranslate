package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

var (
	dataRootOnce sync.Once
	dataRootPath string
	dataRootErr  error
)

func DataRoot() (string, error) {
	dataRootOnce.Do(func() {
		override := strings.TrimSpace(os.Getenv("TF_APP_HOME"))
		if override != "" {
			overridePath, err := filepath.Abs(override)
			if err != nil {
				dataRootErr = fmt.Errorf("resolve TF_APP_HOME: %w", err)
				return
			}
			dataRootPath, dataRootErr = ensureDir(filepath.Clean(overridePath))
			return
		}

		executablePath, err := os.Executable()
		if err != nil {
			dataRootErr = fmt.Errorf("resolve executable path: %w", err)
			return
		}

		executableDir := filepath.Dir(executablePath)
		dataRootPath, dataRootErr = ensureDir(filepath.Join(executableDir, "data"))
	})

	return dataRootPath, dataRootErr
}

func BundledWebView2RuntimePath() (string, bool) {
	executablePath, err := os.Executable()
	if err != nil {
		return "", false
	}

	executableDir := filepath.Dir(executablePath)
	candidates := []string{
		filepath.Join(executableDir, "webview2-runtime"),
		filepath.Join(executableDir, "WebView2Runtime"),
	}

	for _, candidate := range candidates {
		if isBundledWebView2Runtime(candidate) {
			return candidate, true
		}
	}

	return "", false
}

func MustDataRoot() string {
	root, err := DataRoot()
	if err != nil {
		panic(err)
	}
	return root
}

func isBundledWebView2Runtime(path string) bool {
	info, err := os.Stat(path)
	if err != nil || !info.IsDir() {
		return false
	}

	webViewExecutable := filepath.Join(path, "msedgewebview2.exe")
	fileInfo, err := os.Stat(webViewExecutable)
	if err != nil || fileInfo.IsDir() {
		return false
	}

	return true
}

func DataFile(fileName string) string {
	return filepath.Join(MustDataRoot(), fileName)
}

func EnsureDataSubdir(dirName string) string {
	path, err := ensureDir(filepath.Join(MustDataRoot(), dirName))
	if err != nil {
		panic(err)
	}
	return path
}

func ensureDir(path string) (string, error) {
	if err := os.MkdirAll(path, 0o755); err != nil {
		return "", err
	}
	return path, nil
}

func resetDataRootForTest() {
	dataRootOnce = sync.Once{}
	dataRootPath = ""
	dataRootErr = nil
}
