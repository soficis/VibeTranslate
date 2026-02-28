#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# install_prerequisites_macos.sh
#
# Installs all SDKs and tools required to build every VibeTranslate app on
# macOS (Apple Silicon or Intel).
#
# What gets installed (via Homebrew unless noted):
#   • Xcode Command Line Tools  (system installer — provides Swift & clang)
#   • Node.js (LTS)
#   • Go
#   • Flutter  (via Homebrew cask)
#   • Python 3
#   • Ruby  (latest via Homebrew, not the system Ruby)
#   • Bundler  (Ruby gem)
#   • Wails CLI (go install)
#
# Usage:
#   chmod +x scripts/install_prerequisites_macos.sh
#   ./scripts/install_prerequisites_macos.sh          # install everything
#   ./scripts/install_prerequisites_macos.sh --check  # dry-run status check
# ---------------------------------------------------------------------------
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}ℹ${RESET}  $*"; }
success() { echo -e "${GREEN}✔${RESET}  $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET}  $*"; }
fail()    { echo -e "${RED}✘${RESET}  $*"; }
header()  { echo -e "\n${BOLD}── $* ──${RESET}"; }

CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

# Track overall status
MISSING=()

# ── Helper: check if a command exists ────────────────────────────────────────
has() { command -v "$1" &>/dev/null; }

# ── Helper: print version or "not found" ────────────────────────────────────
check_tool() {
  local name="$1"
  local cmd="$2"
  shift 2
  if has "$cmd"; then
    local ver
    ver="$("$cmd" "$@" 2>&1 | head -n1)" || ver="(installed)"
    success "$name: $ver"
  else
    fail "$name: not found"
    MISSING+=("$name")
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Status Check
# ═══════════════════════════════════════════════════════════════════════════════
print_status() {
  header "Prerequisite Status"
  check_tool "Xcode CLI Tools"  xcode-select  --version
  check_tool "Homebrew"         brew           --version
  check_tool "Swift"            swift          --version
  check_tool "Node.js"          node           --version
  check_tool "npm"              npm            --version
  check_tool "Go"               go             version
  check_tool "Flutter"          flutter        --version
  check_tool "Python 3"         python3        --version
  check_tool "pip3"             pip3           --version
  check_tool "Ruby"             ruby           --version
  check_tool "Bundler"          bundle         --version
  check_tool "Wails CLI"        wails          version

  echo ""
  if [[ ${#MISSING[@]} -eq 0 ]]; then
    success "${BOLD}All prerequisites are installed!${RESET}"
  else
    warn "${BOLD}Missing (${#MISSING[@]}): ${MISSING[*]}${RESET}"
  fi
}

if $CHECK_ONLY; then
  print_status
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  Installation
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${BOLD}🌐 VibeTranslate — macOS Prerequisite Installer${RESET}"
echo "This script will install all SDKs needed to build every app in the repo."
echo ""

# ── 1. Xcode Command Line Tools ─────────────────────────────────────────────
header "1/8  Xcode Command Line Tools"
if xcode-select -p &>/dev/null; then
  success "Already installed at $(xcode-select -p)"
else
  info "Installing Xcode Command Line Tools (a system dialog may appear)..."
  xcode-select --install 2>/dev/null || true
  # Wait for the installation to complete
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  success "Xcode CLI Tools installed."
fi

# ── 2. Homebrew ──────────────────────────────────────────────────────────────
header "2/8  Homebrew"
if has brew; then
  success "Already installed: $(brew --version | head -n1)"
  info "Updating Homebrew..."
  brew update
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  success "Homebrew installed."
fi

# ── 3. Node.js (LTS) ────────────────────────────────────────────────────────
header "3/8  Node.js"
if has node; then
  success "Already installed: $(node --version)"
else
  info "Installing Node.js (LTS) via Homebrew..."
  brew install node
  success "Node.js installed: $(node --version)"
fi

# ── 4. Go ────────────────────────────────────────────────────────────────────
header "4/8  Go"
if has go; then
  success "Already installed: $(go version)"
else
  info "Installing Go via Homebrew..."
  brew install go
  success "Go installed: $(go version)"
fi

# ── 5. Flutter ───────────────────────────────────────────────────────────────
header "5/8  Flutter"
if has flutter; then
  success "Already installed: $(flutter --version | head -n1)"
else
  info "Installing Flutter via Homebrew..."
  brew install --cask flutter
  success "Flutter installed."
fi

# Accept Android licenses (non-interactive, ignore failures if no Android SDK)
info "Running flutter doctor..."
flutter doctor --android-licenses 2>/dev/null || true
flutter config --enable-macos-desktop 2>/dev/null || true

# ── 6. Python 3 ─────────────────────────────────────────────────────────────
header "6/8  Python 3"
if has python3; then
  success "Already installed: $(python3 --version)"
else
  info "Installing Python 3 via Homebrew..."
  brew install python
  success "Python installed: $(python3 --version)"
fi

# Ensure pip is available and up-to-date
info "Ensuring pip3 is up to date..."
python3 -m pip install --upgrade pip 2>/dev/null || python3 -m ensurepip --upgrade 2>/dev/null || true

# Install PyInstaller (needed for release builds)
info "Installing PyInstaller..."
pip3 install pyinstaller 2>/dev/null || python3 -m pip install pyinstaller

# ── 7. Ruby + Bundler ────────────────────────────────────────────────────────
header "7/8  Ruby + Bundler"
if brew list ruby &>/dev/null; then
  success "Homebrew Ruby already installed: $(ruby --version)"
else
  info "Installing Ruby via Homebrew (replaces macOS system Ruby)..."
  brew install ruby

  # Add Homebrew Ruby to PATH
  ruby_bin="$(brew --prefix ruby)/bin"
  if [[ -d "$ruby_bin" ]]; then
    export PATH="$ruby_bin:$PATH"
  fi
  success "Ruby installed: $(ruby --version)"
fi

# Bundler
if has bundle; then
  success "Bundler already installed: $(bundle --version)"
else
  info "Installing Bundler..."
  gem install bundler --no-document
  success "Bundler installed."
fi

# ── 8. Wails CLI ─────────────────────────────────────────────────────────────
header "8/8  Wails CLI"
if has wails; then
  success "Already installed: $(wails version 2>&1 | head -n1)"
else
  info "Installing Wails CLI via go install..."
  go install github.com/wailsapp/wails/v2/cmd/wails@latest
  success "Wails CLI installed."
fi

# ═══════════════════════════════════════════════════════════════════════════════
#  Final Summary
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
MISSING=()
print_status

echo ""
if [[ ${#MISSING[@]} -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}🎉 All prerequisites installed successfully!${RESET}"
else
  echo -e "${YELLOW}${BOLD}Some items could not be verified. You may need to:${RESET}"
  echo "  1. Open a new terminal so PATH changes take effect."
  echo "  2. Add Homebrew Ruby/Go to your shell profile:"
  echo "       export PATH=\"\$(brew --prefix ruby)/bin:\$PATH\""
  echo "       export PATH=\"\$(go env GOPATH)/bin:\$PATH\""
  echo "  3. Re-run this script with --check to verify."
fi

echo ""
echo "You're ready to build! Try:"
echo "  scripts/build_macos_arm64_release.sh   # Apple Silicon"
echo "  scripts/build_macos_x64_release.sh     # Intel"
