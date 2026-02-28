<div align="center">

# 🌐 VibeTranslate

### A Multi-Platform Translation App

![VibeTranslate Banner](./assets/banner.png)

Polyglot monorepo of translation ports with a shared feature set: **EN↔JA back-translation**, file processing, and standardized provider UX.

[Quick Start](#-quick-setup) • [Apps](#-the-vibe-ecosystem) • [Building](#-building--testing) • [License](#-license)

</div>

---

## 🚀 Quick Setup

The fastest way to get started is using our portable launchers. **No SDKs or installations required** for end-users.

### 📥 Download & Run

1. Download the latest release from the [Releases](https://github.com/soficis/VibeTranslate/releases) page.
2. Extract the archive (`.zip` for Windows/macOS, `.tar.gz` for Linux).
3. Run the launcher for your platform:

| Platform | Launcher Command |
| :--- | :--- |
| **Windows** | `.\launch_portable.cmd` |
| **Linux / macOS** | `./launch_portable.sh` |

> [!TIP]
> Each app stores its own settings/cache in a local `./data` directory. You can override this by setting the `TF_APP_HOME` environment variable.

---

## 🎭 The Vibe Ecosystem

VibeTranslate is available across a massive variety of tech stacks. All ports maintain feature parity and a consistent experience.

| Icon | App / Port | Technology | Status |
| :--: | :--- | :--- | :--- |
| 🐍 | `TranslationFiestaPy` | Python + Tkinter | ✅ Stable |
| 🔷 | `TranslationFiestaCSharp` | C# WinForms | ✅ Stable |
| 💠 | `TranslationFiestaFSharp` | F# WinForms | ✅ Stable |
| 🎨 | `TranslationFiesta.WinUI` | C# WinUI 3 | ✅ Stable |
| 🐹 | `TranslationFiestaGo` | Go + Wails | ✅ Stable |
| 💎 | `TranslationFiestaRuby` | Ruby + wxRuby | ✅ Stable |
| 💙 | `TranslationFiestaFlutter` | Flutter | ✅ Stable |
| ⚛️ | `TranslationFiestaElectron` | TS + Electron | ✅ Stable |
| 🍎 | `TranslationFiestaSwift` | Swift / SwiftUI | ✅ Stable (macOS ARM64) |
| 🏗️ | **macOS x64** | Intel / Rosetta 2 | ⚠️ *Untested Best-Effort* |

---

## 🔌 Standardized Providers

Every port supports a unified provider interface, ensuring your translation results are consistent regardless of the app you choose.

- **Google Translate (Unofficial / Free)**: Standard across all ports.

---

## 🛠️ Building & Testing

For developers who want to dive into the source, a unified root `Makefile` handles everything.

```bash
make test-all    # Run all unit tests
make lint-all    # Lint all source code
make test-python # Run tests for specific language
```

### 📦 Windows Release Bundle

To build the full Windows x64 portable release bundle (requires .NET 10, Node.js, Go, Ruby, and Flutter):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows_x64_release.ps1
```

### 🍎 macOS Release Bundle

To build the full macOS portable release bundle (requires Swift, Node.js, Go, Ruby, Flutter, and Python):

```bash
# Apple Silicon (ARM64) - Recommended / Primary
scripts/build_macos_arm64_release.sh

# Intel (x64) - Best Effort / Untested
scripts/build_macos_x64_release.sh
```

> [!NOTE]
> If you encounter a "Permission Denied" error, run `chmod +x scripts/*.sh` to make the build scripts executable. Always run build scripts from the **repository root**.

---

## 📜 Detailed Build Instructions

<details>
<summary>Click to view per-app build commands</summary>

### Python (Tkinter)

```bash
cd TranslationFiestaPy && pip install -r requirements.txt && python TranslationFiesta.py
```

### .NET (C# / F# / WinUI)

```bash
cd TranslationFiestaCSharp && dotnet run
# OR
cd TranslationFiestaFSharp && dotnet run
# OR
cd TranslationFiesta.WinUI && dotnet run
```

### Go (Wails)

```bash
cd TranslationFiestaGo && go run main.go
# OR (Developer Mode)
wails dev
```

### Ruby (wxRuby)

```bash
cd TranslationFiestaRuby && bundle install && ruby bin/translation_fiesta
```

### Flutter

```bash
cd TranslationFiestaFlutter && flutter pub get && flutter run
```

### Electron (TypeScript)

```bash
cd TranslationFiestaElectron && npm install && npm run dev
```

### Swift (SwiftUI)

```bash
cd TranslationFiestaSwift && swift run
```

</details>

---

<div align="center">

## ⚖️ License

Licensed under **GNU General Public License v3.0 (GPLv3)**.

</div>
