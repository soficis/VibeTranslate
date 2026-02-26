#nullable enable
#nowarn "FS0057"
namespace TranslationFiestaFSharp

/// <summary>
/// Main application wiring: UI setup, provider selection, and translation workflows.
/// </summary>

/// <summary>
/// Represents the application's immutable UI state.
/// </summary>
type UIState = {
    IsDarkTheme: bool
    ProviderId: string
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
    InputText: string
    IntermediateTranslation: string
    FinalTranslation: string
    CurrentStatus: string
    IsProcessing: bool
    OutputFormat: string
}

/// <summary>
/// Messages for updating the application state.
/// </summary>
type AppMessage =
    | LoadSettings
    | SaveSettings
    | UpdateTheme of bool
    | UpdateProvider of string
    | UpdateInputText of string
    | SetIntermediateResult of string
    | SetFinalResult of string
    | SetStatus of string
    | SetProcessing of bool
    | SetWindowSizeAndPosition of int * int * int * int
    | SaveFile of string * string * string // filePath, inputText, backTranslatedText
    | CopyResult
    | ImportFile of string
    | TriggerBacktranslation
    | TriggerBatchProcess
    | GetState of AsyncReplyChannel<UIState>

type ProviderOption = { Id: string; Name: string }

module Program =
    open System
    open System.Net.Http
    open System.Text.RegularExpressions
    open System.Text.Json
    open System.Text
    open System.IO
    open TranslationFiestaFSharp.Logger
    open System.Windows.Forms
    open System.Linq
    open System.Threading
    open System.Timers
    open System.Drawing
    open System.Windows.Forms.VisualStyles
    open TranslationFiestaFSharp.Settings
    open TranslationFiestaFSharp.ExportManager
    open TranslationFiestaFSharp.BatchProcessor
    open TranslationFiestaFSharp.EpubProcessor

    [<Literal>]
    let AppDisplayName = "TranslationFiesta F#"

    /// <summary>
    /// Initial default state for the application.
    /// </summary>
    let initialUIState = {
        IsDarkTheme = true
        ProviderId = ProviderIds.GoogleUnofficial
        WindowWidth = 1024
        WindowHeight = 720
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
        InputText = ""
        IntermediateTranslation = ""
        FinalTranslation = ""
        CurrentStatus = "Ready"
        IsProcessing = false
        OutputFormat = "HTML"
    }

    /// <summary>
    /// Default intermediate language code for backtranslation (English -> Japanese -> English).
    /// </summary>
    let defaultIntermediateLanguageCode = "ja"

    /// <summary>
    /// Shared HTTP client for API calls.
    /// </summary>
    let httpClient = new HttpClient()

    /// <summary>
    /// Helper module for HTML text extraction and file loading.
    /// </summary>
    module FileOperations =
        open System
        open System.Text.RegularExpressions
        open System.Text
        open System.IO
        /// <summary>
        /// Extracts plain text from an HTML string by removing script, style, code, pre blocks and all remaining HTML tags, then normalizes whitespace.
        /// </summary>
        /// <param name="htmlContent">The HTML string to process.</param>
        /// <returns>The extracted plain text.</returns>
        let extractTextFromHtml (htmlContent: string) : string =
            try
                // Remove script, style, code, and pre blocks using regex
                let scriptPattern = "<script[^>]*>.*?</script>"
                let stylePattern = "<style[^>]*>.*?</style>"
                let codePattern = "<code[^>]*>.*?</code>"
                let prePattern = "<pre[^>]*>.*?</pre>"

                let withoutScripts = Regex.Replace(htmlContent, scriptPattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
                let withoutStyles = Regex.Replace(withoutScripts, stylePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
                let withoutCode = Regex.Replace(withoutStyles, codePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
                let withoutPre = Regex.Replace(withoutCode, prePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)

                // Remove all remaining HTML tags
                let tagPattern = "<[^>]+>"
                let withoutTags = Regex.Replace(withoutPre, tagPattern, "")

                // Normalize whitespace
                let normalized = Regex.Replace(withoutTags, @"\s+", " ")
                normalized.Trim()
            with ex ->
                Logger.error (sprintf "HTML parsing failed: %s" ex.Message)
                htmlContent // Fallback to raw content

        /// <summary>
        /// Loads text content from a file, handling different file types (HTML, Markdown, Text, EPUB).
        /// </summary>
        /// <param name="filePath">The path to the file.</param>
        /// <returns>A Result indicating success with the loaded text or an error message.</returns>
        let loadTextFromFile (filePath: string) : FSharp.Core.Result<string, string> =
            try
                let extension = Path.GetExtension(filePath)
                let extensionLower =
                    match extension with
                    | null | "" -> ""
                    | ext -> ext.ToLower()
                let rawContent = File.ReadAllText(filePath, Encoding.UTF8)

                match extensionLower with
                | ".html" ->
                    let extractedText = extractTextFromHtml rawContent
                    Logger.debug (sprintf "Extracted text from HTML: %d chars -> %d chars" rawContent.Length extractedText.Length)
                    FSharp.Core.Result.Ok extractedText
                | ".md" | ".txt" ->
                    FSharp.Core.Result.Ok (rawContent.Trim())
                | ".epub" ->
                    if EpubProcessor.loadEpub filePath then
                        let chapters = EpubProcessor.getChapters()
                        if not (List.isEmpty chapters) then
                            let firstChapterContent = EpubProcessor.getChapterContent(List.head chapters)
                            Logger.info (sprintf "Loaded EPUB: %s. Extracted first chapter content (%d chars)." (EpubProcessor.getBookTitle()) firstChapterContent.Length)
                            FSharp.Core.Result.Ok (extractTextFromHtml(firstChapterContent.Trim()))
                        else
                            Logger.info (sprintf "EPUB file %s loaded but contains no chapters." filePath)
                            FSharp.Core.Result.Ok String.Empty
                    else
                        FSharp.Core.Result.Error "Failed to load EPUB file."
                | _ ->
                    FSharp.Core.Result.Ok (rawContent.Trim()) // Default to plain text
            with ex ->
                FSharp.Core.Result.Error (sprintf "Failed to load file %s: %s" filePath ex.Message)


/// <summary>
/// Manages the application's shared state in a thread-safe manner using a MailboxProcessor.
/// </summary>
module SharedState =
    open System
    open System.IO
    open System.Windows.Forms
    open TranslationFiestaFSharp.Logger
    open Settings

    let mutable translationAgent: MailboxProcessor<AppMessage> option = None

    /// <summary>
    /// Sets the translation agent for handling translation messages.
    /// </summary>
    let setTranslationAgent (agent: MailboxProcessor<AppMessage>) =
        translationAgent <- Some agent

    let mailbox = MailboxProcessor.Start(fun inbox ->
        let rec loop (state: UIState) =
            async {
                let! msg = inbox.Receive()
                let newState =
                    match msg with
                    | LoadSettings ->
                        match Settings.loadSettings() with
                        | Settings.Success settings ->
                            Logger.info "Settings loaded successfully"
                            { state with
                                IsDarkTheme = settings.IsDarkTheme
                                ProviderId = settings.ProviderId
                                WindowWidth = settings.WindowWidth
                                WindowHeight = settings.WindowHeight
                                WindowX = settings.WindowX
                                WindowY = settings.WindowY
                                LastFilePath = settings.LastFilePath
                                LastSavePath = settings.LastSavePath
                                FontSize = settings.FontSize
                                ShowLineNumbers = settings.ShowLineNumbers
                                AutoCopyResults = settings.AutoCopyResults
                                MaxRetries = settings.MaxRetries
                                TimeoutSeconds = settings.TimeoutSeconds
                                AutoSaveResults = settings.AutoSaveResults
                            }
                        | Settings.Error e ->
                            Logger.error (sprintf "Failed to load settings: %s" e)
                            state // Return current state on error
                    | SaveSettings ->
                        let settingsToSave = {
                            IsDarkTheme = state.IsDarkTheme
                            ProviderId = state.ProviderId
                            WindowWidth = state.WindowWidth
                            WindowHeight = state.WindowHeight
                            WindowX = state.WindowX
                            WindowY = state.WindowY
                            LastFilePath = state.LastFilePath
                            LastSavePath = state.LastSavePath
                            FontSize = state.FontSize
                            ShowLineNumbers = state.ShowLineNumbers
                            AutoCopyResults = state.AutoCopyResults
                            MaxRetries = state.MaxRetries
                            TimeoutSeconds = state.TimeoutSeconds
                            AutoSaveResults = state.AutoSaveResults
                        }
                        match Settings.saveSettings settingsToSave with
                        | Settings.Success () -> Logger.info "Settings saved successfully"
                        | Settings.Error e -> Logger.error (sprintf "Failed to save settings: %s" e)
                        state
                    | UpdateTheme isDark -> { state with IsDarkTheme = isDark }
                    | UpdateProvider providerId ->
                        let normalized = ProviderIds.normalize providerId
                        { state with ProviderId = normalized }
                    | UpdateInputText text -> { state with InputText = text }
                    | SetIntermediateResult text -> { state with IntermediateTranslation = text }
                    | SetFinalResult text -> { state with FinalTranslation = text }
                    | SetStatus text -> { state with CurrentStatus = text }
                    | SetProcessing isProcessing -> { state with IsProcessing = isProcessing }
                    | SetWindowSizeAndPosition (w, h, x, y) -> { state with WindowWidth = w; WindowHeight = h; WindowX = x; WindowY = y }
                    | SaveFile (filePath, inputText, backTranslatedText) ->
                        let exportResult =
                            let translations = [{
                                OriginalText = inputText
                                TranslatedText = backTranslatedText
                                SourceLanguage = "en"
                                TargetLanguage = "ja"
                                ProcessingTime = 0.0
                                ApiUsed = ""
                                Timestamp = System.DateTime.UtcNow.ToString("o")
                            }]
                            // Default to HTML format since output format selector was removed
                            ExportManager.exportToHtml translations filePath None None

                        match exportResult with
                        | FSharp.Core.Result.Ok path ->
                            Logger.info (sprintf "Result saved to file: %s" path)
                            { state with LastSavePath = path; CurrentStatus = (sprintf "Saved to %s" path) }
                        | FSharp.Core.Result.Error e ->
                            Logger.error (sprintf "Failed to save file: %s" (e.ToString()))
                            { state with CurrentStatus = "Save failed" }

                    | CopyResult ->
                        if not (String.IsNullOrEmpty state.FinalTranslation) then
                            Clipboard.SetText(state.FinalTranslation)
                            { state with CurrentStatus = "Result copied to clipboard" }
                        else
                            { state with CurrentStatus = "Nothing to copy" }
                    | ImportFile filePath ->
                        let extension = Path.GetExtension(filePath)
                        let extensionLower =
                            match extension with
                            | null | "" -> ""
                            | ext -> ext.ToLower()
                        match Program.FileOperations.loadTextFromFile filePath with
                        | FSharp.Core.Result.Ok content ->
                            let fileName = Path.GetFileName filePath
                            let statusMsg =
                                match extensionLower with
                                | ".html" -> sprintf "Loaded HTML: %s (%d chars extracted)" fileName content.Length
                                | ".md" -> sprintf "Loaded Markdown: %s" fileName
                                | ".txt" -> sprintf "Loaded Text: %s" fileName
                                | _ -> sprintf "Loaded: %s" fileName
                            Logger.info (sprintf "Successfully imported file: %s" filePath)
                            { state with InputText = content; LastFilePath = filePath; CurrentStatus = statusMsg }
                        | FSharp.Core.Result.Error e ->
                            Logger.error (sprintf "File import failed: %s" e)
                            { state with CurrentStatus = "File import failed" }
                    | TriggerBacktranslation ->
                        match translationAgent with
                        | Some agent ->
                            Logger.info "Forwarding TriggerBacktranslation to translation agent"
                            agent.Post TriggerBacktranslation
                        | None ->
                            Logger.error "Translation agent not available"
                        state
                    | TriggerBatchProcess ->
                        match translationAgent with
                        | Some agent ->
                            Logger.info "Forwarding TriggerBatchProcess to translation agent"
                            agent.Post TriggerBatchProcess
                        | None ->
                            Logger.error "Translation agent not available"
                        state
                    | GetState reply -> reply.Reply(state); state

                // This is a simplified approach for demonstration; in a real app,
                // you might have subscribers to state changes.
                // For now, assume UI directly queries state or gets updates via Invoke.
                do! loop newState
            }
        loop Program.initialUIState)

    /// <summary>
    /// Sends a message to the shared state mailbox.
    /// </summary>
    let dispatch (msg: AppMessage) = mailbox.Post msg

    /// <summary>
    /// Synchronously gets the current application state. Use with caution as it blocks.
    /// Prefer dispatching messages and reacting to state changes asynchronously.
    /// </summary>
    let getState () : UIState = mailbox.PostAndReply(GetState)


/// <summary>
/// Contains functions for interacting with translation APIs.
/// </summary>
module TranslationService =
    open System
    open System.Net
    open System.Net.Http
    open System.Text.Json
    open System.Text
    open TranslationFiestaFSharp.Logger
    open TranslationFiestaFSharp
    /// <summary>
    /// Translates text using the unofficial Google Translate API endpoint.
    /// </summary>
    /// <param name="text">The text to translate.</param>
    /// <param name="source">The source language code (e.g., "en").</param>
    /// <param name="target">The target language code (e.g., "ja").</param>
    /// <returns>An async Result indicating success with the translated text or an error message.</returns>
    let translateUnofficialAsync (text: string) (source: string) (target: string) : Async<FSharp.Core.Result<string, string>> =
        async {
            try
                Logger.debug (sprintf "Unofficial translation: %s -> %s for text starting with '%s...'" source target (text.Substring(0, min 20 text.Length)))
                let encodedText = Uri.EscapeDataString(text)
                let url = sprintf "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s" source target encodedText
                let! response = Program.httpClient.GetAsync(url) |> Async.AwaitTask
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                let computedResult : FSharp.Core.Result<string, string> =
                    match response.StatusCode with
                    | System.Net.HttpStatusCode.TooManyRequests ->
                        let errorMsg = "rate_limited: provider rate limited"
                        Logger.error errorMsg
                        FSharp.Core.Result.Error errorMsg
                    | System.Net.HttpStatusCode.Forbidden ->
                        let errorMsg = "blocked: provider blocked or captcha detected"
                        Logger.error errorMsg
                        FSharp.Core.Result.Error errorMsg
                    | _ when not response.IsSuccessStatusCode ->
                        let errorMsg = sprintf "invalid_response: HTTP %d" (int response.StatusCode)
                        Logger.error errorMsg
                        FSharp.Core.Result.Error errorMsg
                    | _ ->
                        if String.IsNullOrWhiteSpace body then
                            let errorMsg = "invalid_response: empty body"
                            Logger.error errorMsg
                            FSharp.Core.Result.Error errorMsg
                        else
                            let bodyLower = body.ToLowerInvariant()
                            if bodyLower.Contains("<html") || bodyLower.Contains("captcha") then
                                let errorMsg = "blocked: provider blocked or captcha detected"
                                Logger.error errorMsg
                                FSharp.Core.Result.Error errorMsg
                            else
                                use doc = System.Text.Json.JsonDocument.Parse(body)
                                let root = doc.RootElement

                                if root.ValueKind <> System.Text.Json.JsonValueKind.Array then
                                    let errorMsg = "invalid_response: unexpected json root"
                                    Logger.error errorMsg
                                    FSharp.Core.Result.Error errorMsg
                                else
                                    let translationArray = root.[0]
                                    if translationArray.ValueKind <> System.Text.Json.JsonValueKind.Array || translationArray.GetArrayLength() = 0 then
                                        let errorMsg = "invalid_response: no translation segments"
                                        Logger.error errorMsg
                                        FSharp.Core.Result.Error errorMsg
                                    else
                                        let sb = System.Text.StringBuilder()
                                        for sentence in translationArray.EnumerateArray() do
                                            if sentence.ValueKind = System.Text.Json.JsonValueKind.Array && sentence.GetArrayLength() > 0 then
                                                let partNullable = sentence.[0].GetString()
                                                let part =
                                                    match Option.ofObj partNullable with
                                                    | Some p when not (String.IsNullOrEmpty p) -> p
                                                    | _ -> ""
                                                if not (String.IsNullOrEmpty part) then
                                                    sb.Append(part) |> ignore

                                        let result : string = sb.ToString()
                                        if String.IsNullOrWhiteSpace result then
                                            let errorMsg = "invalid_response: empty translation"
                                            Logger.error errorMsg
                                            FSharp.Core.Result.Error errorMsg
                                        else
                                            Logger.info (sprintf "Unofficial translation successful: %d chars" result.Length)
                                            FSharp.Core.Result.Ok result

                return computedResult
            with ex ->
                let errorMsg = sprintf "network_error: %s" ex.Message
                Logger.error errorMsg
                return FSharp.Core.Result.Error errorMsg
        }

    /// <summary>
    /// Detects language for input text. Falls back to English.
    /// </summary>
    let detectLanguageAsync (_text: string) : Async<FSharp.Core.Result<string, string>> = async {
        return FSharp.Core.Result.Ok "en"
    }

    /// <summary>
    /// Translates text with retry logic for transient errors.
    /// </summary>
    /// <param name="text">The text to translate.</param>
    /// <param name="source">The source language code.</param>
    /// <param name="target">The target language code.</param>
    /// <param name="providerId">Provider selection identifier.</param>
    /// <param name="maxAttempts">The maximum number of retry attempts.</param>
    /// <param name="statusCallback">A callback function to update status messages in the UI.</param>
    /// <returns>An async Result indicating success with the translated text or an error message.</returns>
    let translateWithRetriesAsync (text: string) (source: string) (target: string) (providerId: string) (maxAttempts: int) (statusCallback: string -> unit) : Async<FSharp.Core.Result<string, string>> =
        async {
            if String.IsNullOrEmpty text then return FSharp.Core.Result.Ok ""
            else
                let rnd = Random()
                let normalizedProvider = ProviderIds.normalize providerId
                let isRetryable (error: string) =
                    error.StartsWith("rate_limited") || error.StartsWith("network_error") || error.StartsWith("timeout")

                let rec attemptLoop (attempt: int) =
                    async {
                        try
                            let! result = translateUnofficialAsync text source target
                            match result with
                            | Ok _ -> return result
                            | Error err when attempt < maxAttempts && isRetryable err ->
                                let delay = TimeSpan.FromSeconds(Math.Pow(2.0, float attempt)) + TimeSpan.FromMilliseconds(float (rnd.Next(0, 300)))
                                statusCallback (sprintf "Retrying in %.1fs (attempt %d/%d)" delay.TotalSeconds attempt maxAttempts)
                                do! Async.Sleep (int delay.TotalMilliseconds)
                                return! attemptLoop (attempt + 1)
                            | Error _ -> return result
                        with
                        | :? HttpRequestException as hre ->
                            Logger.error (sprintf "HTTP error attempt %d: %s" attempt hre.Message)
                            if attempt >= maxAttempts then
                                return FSharp.Core.Result.Error hre.Message
                            else
                                let delay = TimeSpan.FromSeconds(Math.Pow(2.0, float attempt)) + TimeSpan.FromMilliseconds(float (rnd.Next(0, 300)))
                                statusCallback (sprintf "HTTP error. Retrying in %.1fs (attempt %d/%d)" delay.TotalSeconds attempt maxAttempts)
                                do! Async.Sleep (int delay.TotalMilliseconds)
                                return! attemptLoop (attempt + 1)
                        | ex ->
                            Logger.error (sprintf "Translation error attempt %d: %s" attempt ex.Message)
                            if attempt >= maxAttempts then
                                return FSharp.Core.Result.Error ex.Message
                            else
                                let delay = TimeSpan.FromSeconds(Math.Pow(2.0, float attempt)) + TimeSpan.FromMilliseconds(float (rnd.Next(0, 300)))
                                statusCallback (sprintf "Error. Retrying in %.1fs (attempt %d/%d)" delay.TotalSeconds attempt maxAttempts)
                                do! Async.Sleep (int delay.TotalMilliseconds)
                                return! attemptLoop (attempt + 1)
                    }

                return! attemptLoop 1
        }

/// <summary>
/// Manages the UI elements and their interactions.
/// </summary>
module UI =
    open System.Windows.Forms
    open System.IO
    open System
    open System.Text.Json
    open System.Net.Http
    open System.Drawing
    open System.ComponentModel
    open System.Timers
    open TranslationFiestaFSharp
    let mutable form: Form = Unchecked.defaultof<Form>
    let mutable lblTitle: Label = Unchecked.defaultof<Label>
    let mutable txtInput: TextBox = Unchecked.defaultof<TextBox>
    let mutable lblProvider: Label = Unchecked.defaultof<Label>
    let mutable cmbProvider: ComboBox = Unchecked.defaultof<ComboBox>
    let mutable btnBacktranslate: Button = Unchecked.defaultof<Button>
    let mutable btnImportTxt: Button = Unchecked.defaultof<Button>
    let mutable btnBatchProcess: Button = Unchecked.defaultof<Button>
    let mutable btnCopyResult: Button = Unchecked.defaultof<Button>
    let mutable btnSaveResult: Button = Unchecked.defaultof<Button>
    let mutable tglTheme: CheckBox = Unchecked.defaultof<CheckBox>
    let mutable lblFormat: Label = Unchecked.defaultof<Label>
    let mutable cmbFormat: ComboBox = Unchecked.defaultof<ComboBox>
    let mutable lblIntermediate: Label = Unchecked.defaultof<Label>
    let mutable txtIntermediate: TextBox = Unchecked.defaultof<TextBox>
    let mutable lblBack: Label = Unchecked.defaultof<Label>
    let mutable txtBack: TextBox = Unchecked.defaultof<TextBox>
    let mutable lblStatus: Label = Unchecked.defaultof<Label>
    let mutable progressSpinner: ProgressBar = Unchecked.defaultof<ProgressBar>


    /// <summary>
    /// Initializes static text for UI elements (dynamic text disabled).
    /// </summary>
    let initializeDynamicText () =
        // Dynamic text engine disabled - using static text instead
        ()

    /// <summary>
    /// Updates static text on UI elements (no dynamic changes).
    /// </summary>
    let updateDynamicText () =
        // Dynamic text updates disabled
        ()

    /// <summary>
    /// Adjusts the layout of controls based on the current window size for responsive design.
    /// Uses unified 3-panel layout: Header -> Input -> Action Row -> Side-by-side outputs -> Status.
    /// </summary>
    /// <param name="width">Current window width.</param>
    /// <param name="height">Current window height.</param>
    let adjustLayoutForSize (width: int) (height: int) =
        form.Invoke(Action(fun () ->
            try
                let pad = 24
                let minWidth = 700
                let minHeight = 550
                let w = Math.Max(width, minWidth)
                let h = Math.Max(height, minHeight)
                let contentWidth = w - pad * 2 - 16 // account for form chrome

                // -- Row 1: Header (title + provider dropdown) --
                lblTitle.Left <- pad
                lblTitle.Top <- pad
                lblTitle.Width <- 260
                lblTitle.Height <- 28

                let providerWidth = Math.Min(300, contentWidth - 280)
                cmbProvider.Width <- providerWidth
                cmbProvider.Left <- contentWidth + pad - providerWidth
                cmbProvider.Top <- pad
                lblProvider.Visible <- false // hidden; provider label not needed

                // -- Row 2: Input card --
                let inputTop = pad + 40
                let inputHeight = Math.Max(80, (h - 300) / 3)
                lblFormat.Left <- pad
                lblFormat.Top <- inputTop
                lblFormat.Width <- 100
                txtInput.Left <- pad
                txtInput.Top <- inputTop + 20
                txtInput.Width <- contentWidth
                txtInput.Height <- inputHeight

                // -- Row 3: Action row --
                let actionTop = txtInput.Top + txtInput.Height + 12
                btnBacktranslate.Left <- pad
                btnBacktranslate.Top <- actionTop
                btnBacktranslate.Width <- 160
                btnBacktranslate.Height <- 36

                btnImportTxt.Left <- btnBacktranslate.Left + btnBacktranslate.Width + 8
                btnImportTxt.Top <- actionTop
                btnImportTxt.Width <- 90
                btnImportTxt.Height <- 36

                btnSaveResult.Left <- btnImportTxt.Left + btnImportTxt.Width + 8
                btnSaveResult.Top <- actionTop
                btnSaveResult.Width <- 90
                btnSaveResult.Height <- 36

                btnBatchProcess.Left <- btnSaveResult.Left + btnSaveResult.Width + 8
                btnBatchProcess.Top <- actionTop
                btnBatchProcess.Width <- 90
                btnBatchProcess.Height <- 36

                btnCopyResult.Left <- btnBatchProcess.Left + btnBatchProcess.Width + 8
                btnCopyResult.Top <- actionTop
                btnCopyResult.Width <- 90
                btnCopyResult.Height <- 36

                // Theme toggle hidden (always dark)
                tglTheme.Visible <- false

                // -- Row 4: Side-by-side output panels --
                let outputTop = actionTop + 48
                let gap = 12
                let panelWidth = (contentWidth - gap) / 2
                let outputHeight = Math.Max(80, h - outputTop - 70)

                lblIntermediate.Left <- pad
                lblIntermediate.Top <- outputTop
                lblIntermediate.Width <- panelWidth
                txtIntermediate.Left <- pad
                txtIntermediate.Top <- outputTop + 20
                txtIntermediate.Width <- panelWidth
                txtIntermediate.Height <- outputHeight

                lblBack.Left <- pad + panelWidth + gap
                lblBack.Top <- outputTop
                lblBack.Width <- panelWidth
                txtBack.Left <- pad + panelWidth + gap
                txtBack.Top <- outputTop + 20
                txtBack.Width <- panelWidth
                txtBack.Height <- outputHeight

                // -- Row 5: Status bar --
                lblStatus.Left <- pad
                lblStatus.Top <- txtIntermediate.Top + txtIntermediate.Height + 8
                lblStatus.Width <- contentWidth - 140
                progressSpinner.Left <- contentWidth + pad - 120
                progressSpinner.Top <- lblStatus.Top

                Logger.debug (sprintf "Layout adjusted for size: %dx%d" w h)
            with ex ->
                Logger.error (sprintf "Error adjusting layout: %s" ex.Message)
        )) |> ignore

    /// <summary>
    /// Sets the status text in the UI and logs it.
    /// </summary>
    /// <param name="text">The status message to display.</param>
    let setStatus (text: string) =
        form.Invoke(Action(fun () ->
            // Only update if the text has actually changed to prevent flashing
            if lblStatus.Text <> text then
                lblStatus.Text <- text
                Logger.info (sprintf "Status: %s" text)
        )) |> ignore

    /// <summary>
    /// Shows or hides the progress spinner.
    /// </summary>
    /// <param name="show">True to show, false to hide.</param>
    let showSpinner (show: bool) =
        form.Invoke(Action(fun () ->
            progressSpinner.Visible <- show
            if show then
                progressSpinner.MarqueeAnimationSpeed <- 30
                Logger.debug "Progress spinner enabled"
            else
                progressSpinner.MarqueeAnimationSpeed <- 0
                Logger.debug "Progress spinner disabled"
        )) |> ignore

    /// <summary>
    /// Disables relevant UI controls during processing.
    /// </summary>
    let disableUi () =
        form.Invoke(Action(fun () ->
            btnBacktranslate.Enabled <- false
            btnImportTxt.Enabled <- false
            txtInput.Enabled <- false
            btnBatchProcess.Enabled <- false
            cmbProvider.Enabled <- false
            Logger.debug "UI disabled"
        )) |> ignore

    /// <summary>
    /// Enables relevant UI controls after processing.
    /// </summary>
    let enableUi () =
        form.Invoke(Action(fun () ->
            btnBacktranslate.Enabled <- true
            btnImportTxt.Enabled <- true
            txtInput.Enabled <- true
            btnBatchProcess.Enabled <- true
            cmbProvider.Enabled <- true
            Logger.debug "UI enabled"
        )) |> ignore

    /// <summary>
    /// Applies the specified theme (dark or light) to the UI controls.
    /// </summary>
    /// <param name="isDark">True for dark theme, false for light theme.</param>
    let applyTheme (isDark: bool) =
        form.Invoke(Action(fun () ->
            // Unified dark palette — always dark
            let bgColor      = System.Drawing.Color.FromArgb(15, 20, 25)      // #0F1419
            let surfaceColor = System.Drawing.Color.FromArgb(26, 31, 46)      // #1A1F2E
            let elevated     = System.Drawing.Color.FromArgb(36, 42, 56)      // #242A38
            let borderColor  = System.Drawing.Color.FromArgb(46, 54, 72)      // #2E3648
            let textPrimary  = System.Drawing.Color.FromArgb(232, 236, 241)   // #E8ECF1
            let textSecondary= System.Drawing.Color.FromArgb(139, 149, 165)   // #8B95A5
            let accent       = System.Drawing.Color.FromArgb(59, 130, 246)    // #3B82F6
            let accentHover  = System.Drawing.Color.FromArgb(37, 99, 235)     // #2563EB

            form.BackColor <- bgColor
            form.ForeColor <- textPrimary

            // Title
            lblTitle.BackColor <- bgColor
            lblTitle.ForeColor <- textPrimary

            // Section labels
            lblFormat.BackColor <- bgColor
            lblFormat.ForeColor <- textSecondary
            lblIntermediate.BackColor <- bgColor
            lblIntermediate.ForeColor <- textSecondary
            lblBack.BackColor <- bgColor
            lblBack.ForeColor <- textSecondary
            lblStatus.BackColor <- bgColor
            lblStatus.ForeColor <- textSecondary
            lblProvider.BackColor <- bgColor
            lblProvider.ForeColor <- textSecondary

            // Text inputs
            let styleTextBox (tb: TextBox) =
                tb.BackColor <- surfaceColor
                tb.ForeColor <- textPrimary
                tb.BorderStyle <- BorderStyle.FixedSingle
            styleTextBox txtInput
            styleTextBox txtIntermediate
            styleTextBox txtBack

            // Provider combo
            cmbProvider.BackColor <- surfaceColor
            cmbProvider.ForeColor <- textPrimary
            cmbProvider.FlatStyle <- FlatStyle.Flat

            // Secondary buttons
            let styleSecondary (btn: Button) =
                btn.BackColor <- elevated
                btn.ForeColor <- textPrimary
                btn.FlatStyle <- FlatStyle.Flat
                btn.FlatAppearance.BorderColor <- borderColor
                btn.FlatAppearance.BorderSize <- 1
                btn.FlatAppearance.MouseOverBackColor <- surfaceColor
            styleSecondary btnImportTxt
            styleSecondary btnBatchProcess
            styleSecondary btnCopyResult
            styleSecondary btnSaveResult

            // Hero button (Backtranslate)
            btnBacktranslate.BackColor <- accent
            btnBacktranslate.ForeColor <- System.Drawing.Color.White
            btnBacktranslate.FlatStyle <- FlatStyle.Flat
            btnBacktranslate.FlatAppearance.BorderSize <- 0
            btnBacktranslate.FlatAppearance.MouseOverBackColor <- accentHover

            tglTheme.BackColor <- bgColor
            tglTheme.ForeColor <- textPrimary
        )) |> ignore

    /// <summary>
    /// Initializes all UI controls and adds them to the form.
    /// </summary>
    /// <param name="uiState">The initial application state.</param>
    let initializeControls (uiState: UIState) =
        Logger.info "Initializing UI controls..."
        form <- new Form(Text = Program.AppDisplayName, Width = uiState.WindowWidth, Height = uiState.WindowHeight)
        form.WindowState <- FormWindowState.Normal
        form.ShowInTaskbar <- true
        form.Visible <- true
        form.MinimumSize <- new System.Drawing.Size(700, 550)

        // Set window position - ensure it's not stuck in top-left corner
        form.StartPosition <- FormStartPosition.CenterScreen // Always start centered for better UX

        if uiState.WindowX >= 0 && uiState.WindowY >= 0 then
            // Use saved position if valid, but only after centering first
            let screen = System.Windows.Forms.Screen.PrimaryScreen
            let workingArea = 
                match screen with
                | null -> System.Windows.Forms.Screen.AllScreens.[0].WorkingArea
                | s -> s.WorkingArea

            // Ensure the saved position is within screen bounds and not too close to edges
            let validX = Math.Max(50, Math.Min(uiState.WindowX, workingArea.Width - uiState.WindowWidth - 50))
            let validY = Math.Max(50, Math.Min(uiState.WindowY, workingArea.Height - uiState.WindowHeight - 50))

            // Only use saved position if it's significantly different from center
            let centerX = (workingArea.Width - uiState.WindowWidth) / 2
            let centerY = (workingArea.Height - uiState.WindowHeight) / 2
            let distanceFromCenter = Math.Sqrt(float ((validX - centerX) * (validX - centerX) + (validY - centerY) * (validY - centerY)))

            if distanceFromCenter > 200.0 then // Only restore if more than 200 pixels from center
                form.Location <- new System.Drawing.Point(validX, validY)
                Logger.info (sprintf "Restored window position: %d, %d" validX validY)
            else
                Logger.info "Window position too close to center, using center position"
        else
            Logger.info "No saved position, centering window on screen"

        Logger.info "UI form created successfully"

        initializeDynamicText()

        let uiFont = new System.Drawing.Font("Segoe UI", 10.0f)
        let labelFont = new System.Drawing.Font("Segoe UI", 8.0f, System.Drawing.FontStyle.Bold)
        let titleFont = new System.Drawing.Font("Segoe UI", 14.0f, System.Drawing.FontStyle.Bold)
        let heroFont  = new System.Drawing.Font("Segoe UI", 10.0f, System.Drawing.FontStyle.Bold)

        lblTitle <- new Label(Text = Program.AppDisplayName, Left = 24, Top = 24, Width = 320, Height = 28, Font = titleFont, TextAlign = System.Drawing.ContentAlignment.MiddleLeft)

        lblProvider <- new Label(Text = "Provider:", Left = 0, Top = 0, Width = 0, Height = 0, Visible = false) // hidden
        cmbProvider <- new ComboBox(Left = 0, Top = 24, Width = 280, Height = 28, DropDownStyle = ComboBoxStyle.DropDownList, Font = uiFont)
        let providerOptions =
            [|
                { Id = ProviderIds.GoogleUnofficial; Name = "Google Translate (Unofficial / Free)" }
            |]
        cmbProvider.DataSource <- providerOptions
        cmbProvider.DisplayMember <- "Name"
        cmbProvider.ValueMember <- "Id"
        cmbProvider.SelectedValue <- uiState.ProviderId

        // Section label for input card
        lblFormat <- new Label(Text = "INPUT", Left = 24, Top = 64, Width = 100, Height = 16, Font = labelFont)
        txtInput <- new TextBox(Left = 24, Top = 84, Width = 600, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, Text = uiState.InputText, Font = uiFont)

        // Action row buttons
        btnBacktranslate <- new Button(Text = "\u29BF Backtranslate", Left = 24, Top = 220, Width = 160, Height = 36, Font = heroFont)
        btnImportTxt <- new Button(Text = "Import", Left = 192, Top = 220, Width = 90, Height = 36, Font = uiFont)
        btnSaveResult <- new Button(Text = "Save", Left = 290, Top = 220, Width = 90, Height = 36, Font = uiFont)
        btnBatchProcess <- new Button(Text = "Batch", Left = 388, Top = 220, Width = 90, Height = 36, Font = uiFont)
        btnCopyResult <- new Button(Text = "Copy", Left = 486, Top = 220, Width = 90, Height = 36, Font = uiFont)

        tglTheme <- new CheckBox(Text = "Dark Mode", Left = 0, Top = 0, Width = 0, Checked = true, Visible = false) // always dark

        // Side-by-side output panels
        lblIntermediate <- new Label(Text = "INTERMEDIATE (JA)", Left = 24, Top = 270, Width = 300, Height = 16, Font = labelFont)
        txtIntermediate <- new TextBox(Left = 24, Top = 290, Width = 300, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true, Text = uiState.IntermediateTranslation, Font = uiFont)
        lblBack <- new Label(Text = "RESULT (EN)", Left = 336, Top = 270, Width = 300, Height = 16, Font = labelFont)
        txtBack <- new TextBox(Left = 336, Top = 290, Width = 300, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true, Text = uiState.FinalTranslation, Font = uiFont)

        lblStatus <- new Label(Text = uiState.CurrentStatus, Left = 24, Top = 420, Width = 500, Font = uiFont)
        progressSpinner <- new ProgressBar(Left = 520, Top = 420, Width = 120, Height = 20, Style = ProgressBarStyle.Marquee)
        progressSpinner.Visible <- false

        // Set up initial responsive layout after controls are created
        adjustLayoutForSize form.Width form.Height

        // Add all controls to form
        form.Controls.AddRange([|
            lblTitle :> Control; txtInput :> Control; lblProvider :> Control; cmbProvider :> Control;
            btnBacktranslate :> Control; btnImportTxt :> Control; btnBatchProcess :> Control;
            btnCopyResult :> Control; btnSaveResult :> Control; tglTheme :> Control;
            lblFormat :> Control; lblIntermediate :> Control; txtIntermediate :> Control;
            lblBack :> Control; txtBack :> Control; lblStatus :> Control; progressSpinner :> Control
        |])

        // Set up window event handlers
        form.Resize.Add(fun _ ->
            // Adjust layout when user resizes the window
            adjustLayoutForSize form.Width form.Height
        )

        form.FormClosed.Add(fun _ ->
            // UI update timer disabled, so no need to stop/dispose
            SharedState.dispatch (SetWindowSizeAndPosition (form.Width, form.Height, form.Location.X, form.Location.Y))
            SharedState.dispatch SaveSettings
            Logger.info "Application closed, settings saved"
        )


    /// <summary>
    /// Sets up all event handlers for UI controls.
    /// </summary>
    let setupEventHandlers () =
        cmbProvider.SelectedIndexChanged.Add(fun _ ->
            let selected = cmbProvider.SelectedValue
            let providerId =
                match selected with
                | null -> ProviderIds.GoogleUnofficial
                | value ->
                    match value.ToString() with
                    | null -> ProviderIds.GoogleUnofficial
                    | text -> ProviderIds.normalize text
            SharedState.dispatch (UpdateProvider providerId)
        )

        tglTheme.CheckedChanged.Add(fun _ ->
            SharedState.dispatch (UpdateTheme tglTheme.Checked)
        )


        txtInput.TextChanged.Add(fun _ ->
            SharedState.dispatch (UpdateInputText txtInput.Text)
        )

        btnCopyResult.Click.Add(fun _ -> SharedState.dispatch CopyResult)
        btnSaveResult.Click.Add(fun _ ->
            let dlg = new SaveFileDialog()
            dlg.DefaultExt <- ".txt"
            dlg.Filter <- "Text documents (.txt)|*.txt|All files|*.*"
            dlg.FileName <- "backtranslation.txt"
            let currentState = SharedState.getState()
            dlg.InitialDirectory <-
                if String.IsNullOrWhiteSpace(currentState.LastSavePath) then
                    PortablePaths.exportsDirectory
                else
                    match Path.GetDirectoryName(currentState.LastSavePath) with
                    | null -> PortablePaths.exportsDirectory
                    | directory when String.IsNullOrWhiteSpace(directory) -> PortablePaths.exportsDirectory
                    | directory -> directory
            if dlg.ShowDialog() = DialogResult.OK then
                SharedState.dispatch (SaveFile (dlg.FileName, currentState.InputText, currentState.FinalTranslation))
            )

        btnImportTxt.Click.Add(fun _ ->
            use ofd = new OpenFileDialog()
            ofd.Filter <- "Supported files (*.txt;*.md;*.html;*.epub)|*.txt;*.md;*.html;*.epub|Text files (*.txt)|*.txt|Markdown files (*.md)|*.md|HTML files (*.html)|*.html|EPUB files (*.epub)|*.epub|All files (*.*)|*.*"
            ofd.Multiselect <- false
            let currentState = SharedState.getState()
            ofd.InitialDirectory <-
                if String.IsNullOrWhiteSpace(currentState.LastFilePath) then
                    PortablePaths.dataRoot
                else
                    match Path.GetDirectoryName(currentState.LastFilePath) with
                    | null -> PortablePaths.dataRoot
                    | directory when String.IsNullOrWhiteSpace(directory) -> PortablePaths.dataRoot
                    | directory -> directory
            if ofd.ShowDialog() = DialogResult.OK then
                SharedState.dispatch (ImportFile ofd.FileName)
        )

        btnBacktranslate.Click.Add(fun _ ->
            SharedState.dispatch TriggerBacktranslation
        )

        btnBatchProcess.Click.Add(fun _ ->
            SharedState.dispatch TriggerBatchProcess
        )




    /// <summary>
    /// Subscribes to state changes from the SharedState module and updates the UI accordingly.
    /// This ensures the UI is reactive to state changes.
    /// </summary>
    let subscribeToStateChanges () =
        let timer = new System.Timers.Timer(250.0) // Reduced frequency to prevent excessive updates
        timer.Elapsed.Add(fun _ ->
            try
                let state = SharedState.getState()
                form.Invoke(Action(fun () ->
                    try
                        txtInput.Text <- state.InputText
                        txtIntermediate.Text <- state.IntermediateTranslation
                        txtBack.Text <- state.FinalTranslation
                        // Use setStatus to prevent flashing from redundant updates
                        setStatus state.CurrentStatus
                        let selectedProviderId =
                            match cmbProvider.SelectedValue with
                            | null -> None
                            | value ->
                                match value.ToString() with
                                | null -> None
                                | text -> Some text

                        if selectedProviderId <> Some state.ProviderId then
                            cmbProvider.SelectedValue <- state.ProviderId

                        applyTheme true // Always dark theme

                        if state.IsProcessing then disableUi() else enableUi()
                        showSpinner state.IsProcessing

                        // Preview removed - no longer needed

                        // Only update form dimensions, not position (to avoid overriding user manual positioning)
                        if form.Width <> state.WindowWidth || form.Height <> state.WindowHeight then
                            form.Width <- state.WindowWidth
                            form.Height <- state.WindowHeight
                            // Trigger responsive layout adjustment when window is resized
                            adjustLayoutForSize form.Width form.Height
                    with ex ->
                        Logger.error (sprintf "Error updating UI: %s" ex.Message)
                )) |> ignore
            with ex ->
                Logger.error (sprintf "Error in state change subscription: %s" ex.Message)
        )
        timer.Start()

/// <summary>
/// Contains core application logic and workflows.
/// </summary>
module ApplicationLogic =
    open System
    open System.Windows.Forms
    open TranslationFiestaFSharp.Logger
    open BatchProcessor
    /// <summary>
    /// Runs the backtranslation workflow, handling UI updates and API calls.
    /// </summary>
    let runTranslationWorkflowAsync () =
        async {
            UI.disableUi()
            UI.showSpinner true
            SharedState.dispatch (SetProcessing true)
            SharedState.dispatch (SetIntermediateResult "")
            SharedState.dispatch (SetFinalResult "")

            let currentState = SharedState.getState()
            let input = currentState.InputText

            if String.IsNullOrWhiteSpace input then
                MessageBox.Show("Please enter text to translate.", "No input", MessageBoxButtons.OK, MessageBoxIcon.Warning) |> ignore
                SharedState.dispatch (SetStatus "No input")
            else
                let sourceCode = "en"
                let targetCode = Program.defaultIntermediateLanguageCode // Using the default intermediate language

                if String.IsNullOrEmpty sourceCode || sourceCode.Length <> 2 then
                    MessageBox.Show("Invalid source language. Please select a valid 2-letter code.", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning) |> ignore

                if String.IsNullOrEmpty targetCode || targetCode.Length <> 2 then
                    MessageBox.Show("Invalid target language. Please select a valid 2-letter code.", "Validation Error", MessageBoxButtons.OK, MessageBoxIcon.Warning) |> ignore

                SharedState.dispatch (SetStatus (sprintf "Translating to %s..." targetCode))

                let! r1 = TranslationService.translateWithRetriesAsync input sourceCode targetCode currentState.ProviderId currentState.MaxRetries UI.setStatus
                match r1 with
                | FSharp.Core.Result.Error e ->
                    Logger.error (sprintf "Translation to target failed: %s" e)
                    MessageBox.Show(sprintf "Translation failed: %s" e, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                    SharedState.dispatch (SetStatus "Error")
                | FSharp.Core.Result.Ok intermediate ->
                    SharedState.dispatch (SetIntermediateResult intermediate)
                    UI.lblIntermediate.Text <- (sprintf "Intermediate (%s):" targetCode) // Update label dynamically

                    SharedState.dispatch (SetStatus "Translating back to English...")

                    let! r2 = TranslationService.translateWithRetriesAsync intermediate targetCode sourceCode currentState.ProviderId currentState.MaxRetries UI.setStatus
                    match r2 with
                    | FSharp.Core.Result.Error e2 ->
                        Logger.error (sprintf "Translation back to English failed: %s" e2)
                        MessageBox.Show(sprintf "Back translation failed: %s" e2, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                        SharedState.dispatch (SetStatus "Error")
                    | FSharp.Core.Result.Ok back ->
                        SharedState.dispatch (SetFinalResult back)

                        UI.form.Invoke(Action(fun () -> UI.lblStatus.ForeColor <- System.Drawing.Color.Green)) |> ignore

                        let statusText =
                            if currentState.AutoCopyResults then
                                "Backtranslation complete! (Result copied to clipboard)"
                            else
                                "Backtranslation complete!"

                        SharedState.dispatch (SetStatus statusText)

                        Logger.info (sprintf "Backtranslation completed successfully: %d -> %d -> %d chars" input.Length intermediate.Length back.Length)

                        if currentState.AutoCopyResults then
                            SharedState.dispatch CopyResult

            SharedState.dispatch (SetProcessing false)
            UI.enableUi()
            UI.showSpinner false
        }

    /// <summary>
    /// Runs the batch processing workflow.
    /// </summary>
    let runBatchProcessWorkflowAsync () =
        async {
            UI.disableUi()
            UI.showSpinner true
            SharedState.dispatch (SetProcessing true)

            let currentState = SharedState.getState()
            let sourceCode = "en"
            let targetCode = Program.defaultIntermediateLanguageCode // Using the default intermediate language

            let translateFile (filePath: string) =
                async {
                    match Program.FileOperations.loadTextFromFile filePath with
                    | FSharp.Core.Result.Ok text ->
                        let! result = TranslationService.translateWithRetriesAsync text sourceCode targetCode currentState.ProviderId currentState.MaxRetries UI.setStatus
                        return result
                    | FSharp.Core.Result.Error e ->
                        Logger.error (sprintf "Failed to load file for batch processing: %s - %s" filePath e)
                        return FSharp.Core.Result.Error e
                }

            let updateCallback completed total =
                UI.form.Invoke(Action(fun () ->
                    UI.setStatus (sprintf "Processing %d/%d" completed total)
                    UI.progressSpinner.Value <- (int)((float completed / float total) * 100.0)
                )) |> ignore

            let! results = BatchProcessor.processDirectory translateFile updateCallback
            ()
            SharedState.dispatch (SetStatus "Batch processing complete!")

            SharedState.dispatch (SetProcessing false)
            UI.enableUi()
            UI.showSpinner false
        }

/// <summary>
/// Main entry point of the application.
/// </summary>
module Main =
    [<System.STAThread>]
    [<EntryPoint>]
    let main argv =
        try
            Logger.info "Starting F# TranslationFiesta application..."
            System.Windows.Forms.Application.EnableVisualStyles()
            System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false)

            // Load initial settings into SharedState
            Logger.info "Loading settings..."
            SharedState.dispatch LoadSettings

            // Get the initial state after loading to initialize UI
            Logger.info "Getting initial state..."
            let initialState = SharedState.getState()
            // Initialize UI controls
            Logger.info "Initializing UI controls..."
            UI.initializeControls initialState
            UI.applyTheme initialState.IsDarkTheme // Apply theme initially
            UI.setupEventHandlers()
            UI.subscribeToStateChanges()

            // Setup message handlers for UI-triggered actions
            Logger.info "Setting up message handlers..."
            let translationAgent = MailboxProcessor.Start(fun inbox ->

                let rec messageLoop () =
                    async {
                        let! msg = inbox.Receive()
                        match msg with
                        | TriggerBacktranslation ->
                            Logger.info "Received TriggerBacktranslation message, starting workflow..."
                            do! ApplicationLogic.runTranslationWorkflowAsync()
                        | TriggerBatchProcess ->
                            Logger.info "Received TriggerBatchProcess message, starting workflow..."
                            do! ApplicationLogic.runBatchProcessWorkflowAsync()
                        | _ -> () // Ignore other messages in this specific handler
                        return! messageLoop ()
                    }
                messageLoop()
            )

            // Override the SharedState TriggerBacktranslation handler to use our agent
            SharedState.setTranslationAgent translationAgent

            Logger.info "F# TranslationFiesta started successfully"

            // Ensure the form is visible before running the application
            Logger.info "Ensuring form is visible..."
            try
                UI.form.Show()
                UI.form.BringToFront()
                Logger.info "Form is now visible"
            with
            | :? System.NullReferenceException ->
                Logger.error "UI form is null - cannot display application"

            Logger.info "Starting Windows Forms application loop..."
            System.Windows.Forms.Application.Run(UI.form)

            Logger.info "Application shutting down normally"
            0 // Return 0 for success
        with ex ->
            Logger.error (sprintf "Fatal error during application startup: %s\n%s" ex.Message ex.StackTrace)
            printfn "Fatal error: %s" ex.Message
            printfn "Stack trace: %s" ex.StackTrace
            -1 // Return error code
