#!/usr/bin/env bash
set -euo pipefail

# run.sh - small dev helper for building and opening the app bundle
# Usage: ./run.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
BUILD_BIN="$PROJECT_DIR/.build/arm64-apple-macosx/debug/TranslationFiestaSwift"
APP_BUNDLE="$PROJECT_DIR/TranslationFiestaSwift.app"
APP_EXEC="$APP_BUNDLE/Contents/MacOS/TranslationFiestaSwift"

echo "Building TranslationFiestaSwift..."
swift build --product TranslationFiestaSwift

if [ ! -f "$BUILD_BIN" ]; then
  echo "Build completed but binary not found at: $BUILD_BIN" >&2
  exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
  echo "App bundle not found at: $APP_BUNDLE" >&2
  echo "You may need to create the app bundle or run from the project that contains the .app." >&2
  exit 1
fi

echo "Copying binary into app bundle..."
cp -f "$BUILD_BIN" "$APP_EXEC"
chmod +x "$APP_EXEC"

echo "Opening app bundle (new instance)..."
/usr/bin/open -n "$APP_BUNDLE"

echo "Done."
