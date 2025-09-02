# CsharpTranslationFiesta

Port of TranslationFiesta.py to a C# WinForms app targeting .NET 9.

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
cd C:\Users\fanph\Desktop\Vibes\CsharpTranslationFiesta
dotnet build -c Release
```

Run
- Run from Visual Studio or:

```powershell
dotnet run --project CsharpTranslationFiesta.csproj
```
