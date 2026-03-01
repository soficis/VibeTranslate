#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# build_macos_x64_release.sh
#
# Builds the full macOS x64 (Intel) portable release bundle.
# Equivalent of scripts/build_windows_x64_release.ps1 for macOS Intel.
#
# Prerequisites: Swift toolchain, Node.js/npm, Go, Flutter, Python 3,
#                Ruby + Bundler, and Wails CLI.
# ---------------------------------------------------------------------------
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

arch="x64"
go_platform="darwin/amd64"
electron_arch="x64"
root="$repo_root/dist/release/macos-$arch"

# Clean previous build
if [[ -d "$root" ]]; then
  echo "Cleaning previous release directory: $root"
  rm -rf "$root"
fi
mkdir -p "$root"

echo "Building TranslationFiesta macOS $arch release bundle from: $repo_root"
echo "Output: $root"

# ---------------------------------------------------------------------------
# Swift
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaSwift"
(
  cd TranslationFiestaSwift
  swift build -c release
)

mkdir -p "$root/TranslationFiestaSwift"
cp "$repo_root/TranslationFiestaSwift/.build/release/TranslationFiestaSwift" \
   "$root/TranslationFiestaSwift/TranslationFiestaSwift"
chmod +x "$root/TranslationFiestaSwift/TranslationFiestaSwift"

# ---------------------------------------------------------------------------
# Electron
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaElectron"
(
  cd TranslationFiestaElectron
  npm ci
  npm run build
  npx electron-packager . TranslationFiestaElectron \
    --platform=darwin --arch="$electron_arch" \
    --out "$root/TranslationFiestaElectron" \
    --overwrite --prune=true
)

# ---------------------------------------------------------------------------
# Flutter
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaFlutter"
flutter config --enable-macos-desktop
(
  cd TranslationFiestaFlutter
  flutter clean
  flutter pub get
  flutter build macos --release
)

mkdir -p "$root/TranslationFiestaFlutter"
app_bundle="$(find "$repo_root/TranslationFiestaFlutter/build/macos/Build/Products/Release" \
  -maxdepth 1 -type d -name '*.app' | head -n1)"
if [[ -z "$app_bundle" ]]; then
  echo "Unable to locate Flutter macOS app bundle." >&2
  exit 1
fi
cp -R "$app_bundle" "$root/TranslationFiestaFlutter/"

# ---------------------------------------------------------------------------
# Go (Wails)
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaGo (Wails)"
(
  cd TranslationFiestaGo
  go run github.com/wailsapp/wails/v2/cmd/wails@v2.11.0 build \
    -platform "$go_platform" -clean -o TranslationFiestaGo
)

mkdir -p "$root/TranslationFiestaGo"
go_build_root="$repo_root/TranslationFiestaGo/build/bin"
if [[ ! -d "$go_build_root" ]]; then
  echo "Go build output directory not found: $go_build_root" >&2
  exit 1
fi
cp -R "$go_build_root"/. "$root/TranslationFiestaGo/"

# Verify the binary or .app bundle exists
if [[ ! -d "$root/TranslationFiestaGo/TranslationFiestaGo.app" && \
      ! -f "$root/TranslationFiestaGo/TranslationFiestaGo" ]]; then
  binary="$(find "$root/TranslationFiestaGo" -maxdepth 1 -type f -name 'TranslationFiestaGo*' | head -n1)"
  if [[ -n "$binary" ]]; then
    cp "$binary" "$root/TranslationFiestaGo/TranslationFiestaGo"
  else
    echo "Go build output not found. Expected TranslationFiestaGo(.app) in $go_build_root." >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Python (PyInstaller)
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaPy"
python3 -m pip install --upgrade pip
pip3 install -r TranslationFiestaPy/requirements.lock
pip3 install pyinstaller

python_out_root="$repo_root/TranslationFiestaPy/out"
rm -rf "$python_out_root"
mkdir -p "$python_out_root"

(
  cd TranslationFiestaPy
  pyinstaller --noconfirm --clean --onedir \
    --name TranslationFiestaPy \
    --collect-submodules tkinterweb \
    --collect-data tkinterweb \
    --collect-submodules tkinterweb_tkhtml \
    --collect-data tkinterweb_tkhtml \
    --distpath "$python_out_root/dist" \
    --workpath "$python_out_root/build" \
    --specpath "$python_out_root/spec" \
    TranslationFiesta.py
)

mkdir -p "$root/TranslationFiestaPy"
cp -R "$python_out_root/dist/TranslationFiestaPy/"* "$root/TranslationFiestaPy/"

# ---------------------------------------------------------------------------
# Ruby (self-contained runtime bundle)
# ---------------------------------------------------------------------------
echo ""
echo "==> Building TranslationFiestaRuby"
(
  cd TranslationFiestaRuby
  gem install rake --no-document
  export BUNDLE_PATH="vendor/bundle"
  export BUNDLE_DEPLOYMENT="false"
  export BUNDLE_FROZEN="false"
  bundle install --jobs 4 --retry 3
)

ruby_prefix="$(ruby -e "require 'rbconfig'; print RbConfig::CONFIG['prefix']")"
ruby_target="$root/TranslationFiestaRuby"
mkdir -p "$ruby_target"

# Copy app payload
for path in Gemfile Gemfile.lock translation_fiesta.gemspec bin lib config vendor; do
  cp -R "$repo_root/TranslationFiestaRuby/$path" "$ruby_target/$path"
done

# Copy Ruby runtime
if [[ ! -d "$ruby_prefix" ]]; then
  echo "Ruby runtime path not found: $ruby_prefix" >&2
  exit 1
fi
cp -R "$ruby_prefix" "$ruby_target/ruby-runtime"

# Verify critical Ruby runtime files
if [[ ! -f "$ruby_target/ruby-runtime/bin/ruby" ]]; then
  echo "Bundled Ruby runtime is missing ruby binary." >&2
  exit 1
fi

# Generate macOS launcher (.command for double-click support)
cat >"$ruby_target/run.command" <<'RUBY_LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
runtime_bin="$PWD/ruby-runtime/bin"
export PATH="$runtime_bin:$PATH"
export BUNDLE_GEMFILE="$PWD/Gemfile"
export BUNDLE_PATH="$PWD/vendor/bundle"
exec "$runtime_bin/ruby" bin/translation_fiesta
RUBY_LAUNCHER
chmod +x "$ruby_target/run.command"

# ---------------------------------------------------------------------------
# Generate portable launchers
# ---------------------------------------------------------------------------
echo ""
echo "==> Generating portable launchers"
launcher_script="$repo_root/scripts/create_unix_launchers.sh"
if [[ ! -x "$launcher_script" ]]; then
  chmod +x "$launcher_script"
fi
"$launcher_script" --root "$root" --platform macos

echo ""
echo "Done. Built macOS $arch apps under:"
echo "  $root"
echo "From repo root, run './launch_portable.sh' for the interactive launcher wizard."
