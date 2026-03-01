<div align="center">

# 🌐 VibeTranslate

### A Multi-Platform Translation App

![VibeTranslate Banner](./assets/banner.png)

Polyglot monorepo of translation ports with a shared feature set: **EN↔JA back-translation**, file processing, and standardized provider UX.

[Quick Start](#-quick-setup) • [Apps](#-the-vibe-ecosystem) • [Building](#-building--testing) •

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
| 🍎 | `TranslationFiestaSwift` | Swift / SwiftUI | ⚠️ *Best-Effort Build* |
| 🏗️ | **ARM64 Builds** | All Platforms | ⚠️ *Best-Effort Builds* |

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

### 📦 Windows ARM64 Release Bundle

For ARM64 architecture builds on Windows (requires ARM64 versions of .NET 10, Node.js, Go, Ruby, and Flutter):

First, install the required ARM64 SDKs:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install_windows_arm64_sdks.ps1
```

Then build the ARM64 portable release bundle:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_windows_arm64_release.ps1
```

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
