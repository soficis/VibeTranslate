Free Google Translate WinForms (no API key)

This Windows Forms app performs a back-translation using the unofficial Google Translate web endpoint (no API key required): English -> Japanese -> English.

Notes
- This uses the public web endpoint (`https://translate.googleapis.com/translate_a/single?client=gtx...`) used by some web clients. It's unofficial, may be rate-limited, change without notice, or be blocked by Google.
- For reliable production use, prefer the official Google Cloud Translation API (paid) and proper client libraries.

Requirements
- .NET 7 SDK (or newer)

Build and run (PowerShell)
```powershell
# build
dotnet build "C:\Users\fanph\Desktop\Vibes\FreeTranslateWin\FreeTranslateWin.csproj"
# run
dotnet run --project "C:\Users\fanph\Desktop\Vibes\FreeTranslateWin\FreeTranslateWin.csproj"
```

Usage
1. Start the app.
2. Paste English text and click "Backtranslate".
3. The app shows the Japanese intermediate text and the back-translated English result.
