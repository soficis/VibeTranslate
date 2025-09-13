namespace TranslationFiestaFSharp

open System
open System.IO
open System.Security.Cryptography
open System.Text

module SecureStore =

    // Result type for functional error handling
    type SecureStoreResult<'T> =
        | Success of 'T
        | Error of string

    // Configuration for secure storage
    type SecureStoreConfig = {
        AppName: string
        StorePath: string
    }

    // Default configuration
    let defaultConfig = {
        AppName = "TranslationFiestaFSharp"
        StorePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "TranslationFiestaFSharp", "secure.bin")
    }

    // Core DPAPI operations using functional patterns
    module DpApi =

        // Protect data using Windows DPAPI
        let protect (data: byte[]) : SecureStoreResult<byte[]> =
            try
                let protectedData = ProtectedData.Protect(data, null, DataProtectionScope.CurrentUser)
                Success protectedData
            with ex ->
                Error (sprintf "Failed to protect data: %s" ex.Message)

        // Unprotect data using Windows DPAPI
        let unprotect (protectedData: byte[]) : SecureStoreResult<byte[]> =
            try
                let unprotectedData = ProtectedData.Unprotect(protectedData, null, DataProtectionScope.CurrentUser)
                Success unprotectedData
            with ex ->
                Error (sprintf "Failed to unprotect data: %s" ex.Message)

    // File operations with functional error handling
    module FileOps =

        // Ensure directory exists
        let ensureDirectory (path: string) : SecureStoreResult<unit> =
            try
                let directory = Path.GetDirectoryName(path)
                match directory with
                | null -> () // Or log a warning if appropriate
                | dir when not (String.IsNullOrEmpty dir) -> Directory.CreateDirectory(dir) |> ignore
                | _ -> ()
                Success ()
            with ex ->
                Error (sprintf "Failed to create directory: %s" ex.Message)

        // Write bytes to file
        let writeBytes (path: string) (data: byte[]) : SecureStoreResult<unit> =
            try
                File.WriteAllBytes(path, data)
                Success ()
            with ex ->
                Error (sprintf "Failed to write file: %s" ex.Message)

        // Read bytes from file
        let readBytes (path: string) : SecureStoreResult<byte[]> =
            try
                if not (File.Exists path) then
                    Error "File does not exist"
                else
                    let data = File.ReadAllBytes(path)
                    Success data
            with ex ->
                Error (sprintf "Failed to read file: %s" ex.Message)

        // Delete file if it exists
        let deleteFile (path: string) : SecureStoreResult<unit> =
            try
                if File.Exists path then
                    File.Delete path
                Success ()
            with ex ->
                Error (sprintf "Failed to delete file: %s" ex.Message)

    // Main secure storage operations
    type SecureStore(config: SecureStoreConfig) =

        // Store API key securely
        member this.SaveApiKey(apiKey: string) : SecureStoreResult<unit> =
            if String.IsNullOrWhiteSpace apiKey then
                Error "API key cannot be empty"
            else
                // Convert string to bytes
                let apiKeyBytes = Encoding.UTF8.GetBytes(apiKey.Trim())

                // Protect the data
                match DpApi.protect apiKeyBytes with
                | Error e -> Error e
                | Success protectedData ->
                    // Ensure directory exists
                    match FileOps.ensureDirectory config.StorePath with
                    | Error e -> Error e
                    | Success () ->
                        // Write protected data to file
                        FileOps.writeBytes config.StorePath protectedData

        // Retrieve API key securely
        member this.GetApiKey() : SecureStoreResult<string> =
            // Read protected data from file
            match FileOps.readBytes config.StorePath with
            | Error e -> Error e
            | Success protectedData ->
                // Unprotect the data
                match DpApi.unprotect protectedData with
                | Error e -> Error e
                | Success unprotectedData ->
                    // Convert bytes back to string
                    try
                        let apiKey = Encoding.UTF8.GetString(unprotectedData)
                        Success apiKey
                    with ex ->
                        Error (sprintf "Failed to decode API key: %s" ex.Message)

        // Clear stored API key
        member this.ClearApiKey() : SecureStoreResult<unit> =
            FileOps.deleteFile config.StorePath

        // Check if API key exists
        member this.HasApiKey() : bool =
            File.Exists config.StorePath

    // Module-level functions for convenience
    let private defaultStore = SecureStore(defaultConfig)

    // Save API key using default configuration
    let saveApiKey (apiKey: string) : SecureStoreResult<unit> =
        defaultStore.SaveApiKey(apiKey)

    // Get API key using default configuration
    let getApiKey () : SecureStoreResult<string> =
        defaultStore.GetApiKey()

    // Clear API key using default configuration
    let clearApiKey () : SecureStoreResult<unit> =
        defaultStore.ClearApiKey()

    // Check if API key exists using default configuration
    let hasApiKey () : bool =
        defaultStore.HasApiKey()

    // Create a custom secure store instance
    let createSecureStore (appName: string) : SecureStore =
        let customConfig = {
            AppName = appName
            StorePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), appName, "secure.bin")
        }
        SecureStore(customConfig)