package utils

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDataRootUsesEnvOverride(t *testing.T) {
	resetDataRootForTest()
	t.Cleanup(resetDataRootForTest)

	override := t.TempDir()
	t.Setenv("TF_APP_HOME", override)

	root, err := DataRoot()
	if err != nil {
		t.Fatalf("expected no error resolving data root: %v", err)
	}

	if root != override {
		t.Fatalf("expected data root %q, got %q", override, root)
	}
}

func TestDataRootDefaultsToExecutableDirectory(t *testing.T) {
	resetDataRootForTest()
	t.Cleanup(resetDataRootForTest)

	t.Setenv("TF_APP_HOME", "")

	executablePath, err := os.Executable()
	if err != nil {
		t.Fatalf("expected executable path: %v", err)
	}

	expected := filepath.Join(filepath.Dir(executablePath), "data")
	root, err := DataRoot()
	if err != nil {
		t.Fatalf("expected no error resolving default data root: %v", err)
	}

	if root != expected {
		t.Fatalf("expected default data root %q, got %q", expected, root)
	}
}

func TestIsBundledWebView2RuntimeReturnsTrueForExpectedLayout(t *testing.T) {
	runtimeDir := filepath.Join(t.TempDir(), "webview2-runtime")
	if err := os.MkdirAll(runtimeDir, 0o755); err != nil {
		t.Fatalf("expected runtime directory creation to succeed: %v", err)
	}

	executablePath := filepath.Join(runtimeDir, "msedgewebview2.exe")
	if err := os.WriteFile(executablePath, []byte("stub"), 0o644); err != nil {
		t.Fatalf("expected runtime executable creation to succeed: %v", err)
	}

	if !isBundledWebView2Runtime(runtimeDir) {
		t.Fatalf("expected %q to be detected as bundled webview2 runtime", runtimeDir)
	}
}

func TestIsBundledWebView2RuntimeReturnsFalseWhenExecutableMissing(t *testing.T) {
	runtimeDir := filepath.Join(t.TempDir(), "webview2-runtime")
	if err := os.MkdirAll(runtimeDir, 0o755); err != nil {
		t.Fatalf("expected runtime directory creation to succeed: %v", err)
	}

	if isBundledWebView2Runtime(runtimeDir) {
		t.Fatalf("expected %q to be rejected when msedgewebview2.exe is missing", runtimeDir)
	}
}
