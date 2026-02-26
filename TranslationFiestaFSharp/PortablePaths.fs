#nullable enable

namespace TranslationFiestaFSharp

module PortablePaths =
    open System
    open System.IO

    let private ensureDirectory (path: string) =
        Directory.CreateDirectory(path) |> ignore
        path

    let dataRoot =
        let overridePath = Environment.GetEnvironmentVariable("TF_APP_HOME")
        match overridePath with
        | null -> Path.Combine(AppContext.BaseDirectory, "data")
        | value when String.IsNullOrWhiteSpace(value) -> Path.Combine(AppContext.BaseDirectory, "data")
        | value -> Path.GetFullPath(value)
        |> ensureDirectory

    let settingsFilePath = Path.Combine(dataRoot, "settings.json")
    let translationMemoryFilePath = Path.Combine(dataRoot, "tm_cache.json")
    let logsDirectory = Path.Combine(dataRoot, "logs") |> ensureDirectory
    let logFilePath = Path.Combine(logsDirectory, "fsharptranslate.log")
    let exportsDirectory = Path.Combine(dataRoot, "exports") |> ensureDirectory
