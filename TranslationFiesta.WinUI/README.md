Translation Fiesta — WinUI 3 edition

This is a WinUI 3 (Windows App SDK) version of Translation Fiesta. It uses WinUI controls and Fluent styles for a Windows 11 look, provides dark mode, secure DPAPI-based storage for API keys, and persistent user settings.

Requirements
- Windows 10 19041+ or Windows 11
- .NET 9 SDK
- Windows App SDK (Microsoft.WindowsAppSDK) and Visual Studio or MSBuild with WinUI support

Build
Use Visual Studio 2022/2023 with the "Windows App SDK" workload, or install the Windows App SDK and MSBuild tooling that supports WinUI 3.

Run (locally via Visual Studio)
- Open the solution in Visual Studio and run the WinUI project.

Publish & Packaging (MSIX)
1. Build a Release of the WinUI app.
2. Use the included script to create an MSIX package (requires MakeAppx.exe from the Windows SDK):

```powershell
.\tools\package-winui-msix.ps1 -AppExecutablePath "C:\path\to\TranslationFiesta.WinUI\bin\Release\net9.0-windows10.0.19041.0\win10-x64\TranslationFiesta.WinUI.exe" -OutputMsix "C:\path\to\out\TranslationFiesta.msix"
```

3. Sign the MSIX using SignTool and a code-signing certificate. Unsigned MSIX packages may require special install steps on target machines.

Notes
- Secure storage uses DPAPI (ProtectedData) to encrypt the API key per user.
- Theme resources (LightTheme.xaml, DarkTheme.xaml, Controls.xaml) are under `Themes/` and can be extended.
- For full Fluent visuals, further customization of ResourceDictionaries and use of WinUI brushes is recommended.
