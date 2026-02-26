# TranslationFiestaCSharp

**Repository**: [https://github.com/soficis/VibeTranslate](https://github.com/soficis/VibeTranslate)

Port of TranslationFiesta.py to a C# WinForms app targeting .NET 9.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override data root with `TF_APP_HOME`.

Features:
- Back-translation English -> Japanese -> English using the unofficial Google translate web endpoint
- Load text files (txt, md, html)
- Dark/Light toggle
- Copy and Save back-translated text

Build
- .NET 9 SDK required
- Open the folder in Visual Studio or use dotnet CLI

CLI build example:

```powershell
cd C:\Users\fanph\Desktop\Vibes\TranslationFiestaCSharp
dotnet build -c Release
```

Run
- Run from Visual Studio or:

```powershell
dotnet run --project TranslationFiestaCSharp.csproj
```
