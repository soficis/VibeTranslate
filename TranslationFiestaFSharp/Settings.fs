#nullable enable

namespace TranslationFiestaFSharp

module Settings =
    open System
    open System.IO
    open System.Text.Json
    open TranslationFiestaFSharp

    type Result<'T> =
        | Success of 'T
        | Error of string

    type AppSettings = {
        IsDarkTheme: bool
        ProviderId: string
        UseOfficialApi: bool
        CostTrackingEnabled: bool
        LocalServiceUrl: string
        LocalModelDir: string
        LocalAutoStart: bool
        WindowWidth: int
        WindowHeight: int
        WindowX: int
        WindowY: int
        LastFilePath: string
        LastSavePath: string
        FontSize: int
        ShowLineNumbers: bool
        AutoCopyResults: bool
        MaxRetries: int
        TimeoutSeconds: int
        AutoSaveResults: bool
    }

    let private settingsFilePath =
        let appData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData)
        Path.Combine(appData, "TranslationFiestaFSharp", "settings.json")

    let loadSettings () : Result<AppSettings> =
        try
            if File.Exists settingsFilePath then
                let json = File.ReadAllText settingsFilePath
                match JsonSerializer.Deserialize<AppSettings>(json) with
                | null -> Error "Failed to deserialize settings: invalid JSON format"
                | settings ->
                    let normalized =
                        if String.IsNullOrWhiteSpace settings.ProviderId then
                            if settings.UseOfficialApi then ProviderIds.GoogleOfficial else ProviderIds.GoogleUnofficial
                        else
                            ProviderIds.normalize settings.ProviderId
                    let serviceUrl =
                        if String.IsNullOrWhiteSpace settings.LocalServiceUrl then ""
                        else settings.LocalServiceUrl
                    let modelDir =
                        if String.IsNullOrWhiteSpace settings.LocalModelDir then ""
                        else settings.LocalModelDir
                    Success {
                        settings with
                            ProviderId = normalized
                            UseOfficialApi = ProviderIds.isOfficial normalized
                            LocalServiceUrl = serviceUrl
                            LocalModelDir = modelDir
                    }
            else
                // Default settings
                Success {
                    IsDarkTheme = false
                    ProviderId = ProviderIds.GoogleUnofficial
                    UseOfficialApi = false
                    CostTrackingEnabled = false
                    LocalServiceUrl = ""
                    LocalModelDir = ""
                    LocalAutoStart = true
                    WindowWidth = 900
                    WindowHeight = 650
                    WindowX = -1
                    WindowY = -1
                    LastFilePath = ""
                    LastSavePath = ""
                    FontSize = 9
                    ShowLineNumbers = false
                    AutoCopyResults = false
                    MaxRetries = 4
                    TimeoutSeconds = 30
                    AutoSaveResults = false
                }
        with ex ->
            Error $"Failed to load settings: {ex.Message}"

    let saveSettings (settings: AppSettings) : Result<unit> =
        try
            let dir = Path.GetDirectoryName(settingsFilePath)
            match dir with
            | null -> ()
            | dir when not (Directory.Exists dir) ->
                Directory.CreateDirectory(dir) |> ignore
            | _ -> ()
            let options = JsonSerializerOptions()
            options.WriteIndented <- true
            let json = JsonSerializer.Serialize(settings, options)
            File.WriteAllText(settingsFilePath, json)
            Success ()
        with ex ->
            Error $"Failed to save settings: {ex.Message}"
