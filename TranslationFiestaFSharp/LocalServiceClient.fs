namespace TranslationFiestaFSharp

module LocalServiceClient =
    open System
    open System.Diagnostics
    open System.IO
    open System.Net.Http
    open System.Text
    open System.Text.Json
    open TranslationFiestaFSharp.Logger

    let private defaultBaseUrl = "http://127.0.0.1:5055"
    let private defaultScriptPath = "TranslationFiestaLocal/local_service.py"
    let private startLock = obj()
    let mutable private started = false

    let applyEnvironment (serviceUrl: string) (modelDir: string) (autoStart: bool) =
        if String.IsNullOrWhiteSpace serviceUrl then
            Environment.SetEnvironmentVariable("TF_LOCAL_URL", null)
        else
            Environment.SetEnvironmentVariable("TF_LOCAL_URL", serviceUrl)
        if String.IsNullOrWhiteSpace modelDir then
            Environment.SetEnvironmentVariable("TF_LOCAL_MODEL_DIR", null)
        else
            Environment.SetEnvironmentVariable("TF_LOCAL_MODEL_DIR", modelDir)
        Environment.SetEnvironmentVariable("TF_LOCAL_AUTOSTART", if autoStart then "1" else "0")

    let private getBaseUrl () =
        let envValue = Environment.GetEnvironmentVariable("TF_LOCAL_URL")
        let baseUrl =
            if String.IsNullOrWhiteSpace envValue then defaultBaseUrl
            else envValue.Trim()
        baseUrl.TrimEnd('/')

    let private isAutoStartEnabled () =
        let raw = Environment.GetEnvironmentVariable("TF_LOCAL_AUTOSTART")
        if String.IsNullOrWhiteSpace raw then true
        else
            let value = raw.Trim().ToLowerInvariant()
            value <> "0" && value <> "false" && value <> "no"

    let private startLocalService () =
        lock startLock (fun () ->
            if started then () else
                let scriptEnv = Environment.GetEnvironmentVariable("TF_LOCAL_SCRIPT")
                let scriptPath =
                    if String.IsNullOrWhiteSpace scriptEnv then defaultScriptPath
                    else scriptEnv.Trim()
                let fullPath = Path.GetFullPath(scriptPath)
                let pythonEnv = Environment.GetEnvironmentVariable("PYTHON")
                let pythonExe =
                    if String.IsNullOrWhiteSpace pythonEnv then "python"
                    else pythonEnv

                let startInfo = ProcessStartInfo()
                startInfo.FileName <- pythonExe
                startInfo.Arguments <- sprintf "\"%s\" serve" fullPath
                let workDir = Path.GetDirectoryName(fullPath)
                if String.IsNullOrWhiteSpace workDir then
                    startInfo.WorkingDirectory <- Environment.CurrentDirectory
                else
                    startInfo.WorkingDirectory <- workDir
                startInfo.CreateNoWindow <- true
                startInfo.UseShellExecute <- false

                try
                    Process.Start(startInfo) |> ignore
                    started <- true
                    Logger.info (sprintf "Local service start requested: %s" fullPath)
                with ex ->
                    Logger.error (sprintf "Failed to start local service: %s" ex.Message)
        )

    let private checkHealthAsync (httpClient: HttpClient) =
        async {
            let baseUrl = getBaseUrl ()
            try
                let! response = httpClient.GetAsync(baseUrl + "/health") |> Async.AwaitTask
                if response.IsSuccessStatusCode then
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    use doc = JsonDocument.Parse(body)
                    let status = doc.RootElement.GetProperty("status").GetString()
                    if String.Equals(status, "ok", StringComparison.OrdinalIgnoreCase) then
                        return Ok ()
                    else
                        return Error "Local service is not ready"
                else
                    return Error (sprintf "Local service health HTTP %d" (int response.StatusCode))
            with ex ->
                return Error ex.Message
        }

    let private ensureAvailableAsync (httpClient: HttpClient) =
        async {
            let! health = checkHealthAsync httpClient
            match health with
            | Ok _ -> return Ok ()
            | Error _ ->
                if not (isAutoStartEnabled ()) then
                    return Error "Local service unavailable and autostart disabled"
                else
                    startLocalService ()
                    let mutable lastError = "Local service unavailable"
                    let mutable attempt = 0
                    let mutable ready = false
                    while attempt < 10 && not ready do
                        let! retry = checkHealthAsync httpClient
                        match retry with
                        | Ok _ ->
                            ready <- true
                        | Error err ->
                            lastError <- err
                            attempt <- attempt + 1
                            do! Async.Sleep 250

                    if ready then return Ok ()
                    else return Error lastError
        }

    let translateAsync (httpClient: HttpClient) (text: string) (source: string) (target: string) : Async<Result<string, string>> =
        async {
            let! available = ensureAvailableAsync httpClient
            match available with
            | Error err -> return Error err
            | Ok _ ->
                try
                    let baseUrl = getBaseUrl ()
                    let payload =
                        JsonSerializer.Serialize(
                            {| text = text; source_lang = source; target_lang = target |}
                        )
                    use content = new StringContent(payload, Encoding.UTF8, "application/json")
                    let! response = httpClient.PostAsync(baseUrl + "/translate", content) |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    if not response.IsSuccessStatusCode then
                        return Error (sprintf "Local service HTTP %d" (int response.StatusCode))
                    else
                        use doc = JsonDocument.Parse(body)
                        let mutable errorElement = Unchecked.defaultof<JsonElement>
                        if doc.RootElement.TryGetProperty("error", &errorElement) then
                            let messageElement = errorElement.GetProperty("message")
                            let message = messageElement.GetString()
                            return Error (if String.IsNullOrWhiteSpace message then "Local service error" else message)
                        else
                            let translated = doc.RootElement.GetProperty("translated_text").GetString()
                            if String.IsNullOrWhiteSpace translated then
                                return Error "Local service returned empty translation"
                            else
                                return Ok translated
                with ex ->
                    return Error ex.Message
        }

    let modelsStatusAsync (httpClient: HttpClient) : Async<Result<string, string>> =
        async {
            let! available = ensureAvailableAsync httpClient
            match available with
            | Error err -> return Error err
            | Ok _ ->
                try
                    let baseUrl = getBaseUrl ()
                    let! response = httpClient.GetAsync(baseUrl + "/models") |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    if not response.IsSuccessStatusCode then
                        return Error (sprintf "Local service HTTP %d" (int response.StatusCode))
                    else
                        return Ok body
                with ex ->
                    return Error ex.Message
        }

    let modelsVerifyAsync (httpClient: HttpClient) : Async<Result<string, string>> =
        async {
            let! available = ensureAvailableAsync httpClient
            match available with
            | Error err -> return Error err
            | Ok _ ->
                try
                    let baseUrl = getBaseUrl ()
                    use content = new StringContent("{}", Encoding.UTF8, "application/json")
                    let! response = httpClient.PostAsync(baseUrl + "/models/verify", content) |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    if not response.IsSuccessStatusCode then
                        return Error (sprintf "Local service HTTP %d" (int response.StatusCode))
                    else
                        return Ok body
                with ex ->
                    return Error ex.Message
        }

    let modelsRemoveAsync (httpClient: HttpClient) : Async<Result<string, string>> =
        async {
            let! available = ensureAvailableAsync httpClient
            match available with
            | Error err -> return Error err
            | Ok _ ->
                try
                    let baseUrl = getBaseUrl ()
                    use content = new StringContent("{}", Encoding.UTF8, "application/json")
                    let! response = httpClient.PostAsync(baseUrl + "/models/remove", content) |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    if not response.IsSuccessStatusCode then
                        return Error (sprintf "Local service HTTP %d" (int response.StatusCode))
                    else
                        return Ok body
                with ex ->
                    return Error ex.Message
        }

    let modelsInstallDefaultAsync (httpClient: HttpClient) : Async<Result<string, string>> =
        async {
            let! available = ensureAvailableAsync httpClient
            match available with
            | Error err -> return Error err
            | Ok _ ->
                try
                    let baseUrl = getBaseUrl ()
                    use content = new StringContent("{}", Encoding.UTF8, "application/json")
                    let! response = httpClient.PostAsync(baseUrl + "/models/install", content) |> Async.AwaitTask
                    let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask
                    if not response.IsSuccessStatusCode then
                        return Error (sprintf "Local service HTTP %d" (int response.StatusCode))
                    else
                        return Ok body
                with ex ->
                    return Error ex.Message
        }
