open System
open System.Net.Http
open System.Text
open System.Text.Json
open System.Windows.Forms
open System.IO
open System.Threading

// Import our custom logger
open Logger

// Language simplification: fixed backtranslation English -> Japanese -> English
let defaultIntermediateLanguageCode = "ja"

// UI state
type UiState = {
    mutable IsDarkTheme: bool
    mutable UseOfficialApi: bool
    mutable ApiKey: string
}

// Shared HTTP client
let httpClient = new HttpClient()

// Translation functions
let translateUnofficialAsync (text: string) (source: string) (target: string) =
    async {
        try
            Logger.debug (sprintf "Unofficial translation: %s -> %s -> %s" source target text)
            let encodedText = Uri.EscapeDataString(text)
            let url = sprintf "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s" source target encodedText
            let! response = httpClient.GetAsync(url) |> Async.AwaitTask
            let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

            if not response.IsSuccessStatusCode then
                let errorMsg = sprintf "HTTP %d: %s" (int response.StatusCode) body
                Logger.error errorMsg
                return Error errorMsg
            else
                use doc = JsonDocument.Parse(body)
                let root = doc.RootElement

                if root.ValueKind <> JsonValueKind.Array then
                    let errorMsg = "Invalid response format"
                    Logger.error errorMsg
                    return Error errorMsg
                else
                    let translationArray = root.[0]
                    if translationArray.ValueKind <> JsonValueKind.Array || translationArray.GetArrayLength() = 0 then
                        let errorMsg = "No translation found in response"
                        Logger.error errorMsg
                        return Error errorMsg
                    else
                        let sb = StringBuilder()
                        for sentence in translationArray.EnumerateArray() do
                            if sentence.ValueKind = JsonValueKind.Array && sentence.GetArrayLength() > 0 then
                                let part = sentence.[0].GetString()
                                if not (String.IsNullOrEmpty part) then
                                    sb.Append(part) |> ignore

                        let result = sb.ToString()
                        Logger.info (sprintf "Unofficial translation successful: %d chars" result.Length)
                        return Ok result
        with ex ->
            let errorMsg = sprintf "Unofficial translation error: %s" ex.Message
            Logger.error errorMsg
            return Error errorMsg
    }

let translateOfficialAsync (text: string) (source: string) (target: string) (apiKey: string) =
    async {
        try
            Logger.debug (sprintf "Official translation: %s -> %s -> %s" source target text)
            if String.IsNullOrWhiteSpace apiKey then
                let errorMsg = "API key required for official endpoint"
                Logger.error errorMsg
                return Error errorMsg
            else
                let url = sprintf "https://translation.googleapis.com/language/translate/v2?key=%s" (Uri.EscapeDataString(apiKey))
                let payloadRecord: {| q: string array; target: string; source: string option; format: string |} =
                    {| q = [| text |]
                       target = target
                       source = (if source = "auto" then None else Some source)
                       format = "text" |}
                let payload = JsonSerializer.Serialize(payloadRecord)
                use content = new StringContent(payload, Encoding.UTF8, "application/json")

                let! response = httpClient.PostAsync(url, content) |> Async.AwaitTask
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                if not response.IsSuccessStatusCode then
                    let errorMsg = sprintf "HTTP %d: %s" (int response.StatusCode) body
                    Logger.error errorMsg
                    return Error errorMsg
                else
                    use doc = JsonDocument.Parse(body)
                    let translation = doc.RootElement.GetProperty("data").GetProperty("translations").[0].GetProperty("translatedText").GetString()
                    let result = if String.IsNullOrEmpty(translation) then "" else translation
                    Logger.info (sprintf "Official translation successful: %d chars" result.Length)
                    return Ok result
        with ex ->
            let errorMsg = sprintf "Official translation error: %s" ex.Message
            Logger.error errorMsg
            return Error errorMsg
    }

let translateWithRetriesAsync (text: string) (source: string) (target: string) (useOfficialApi: bool) (apiKey: string) (maxAttempts: int) (statusCallback: string -> unit) =
    async {
        if String.IsNullOrEmpty text then return Ok ""
        else
            let rnd = Random()

            let rec attemptLoop (attempt: int) =
                async {
                    try
                        let! result =
                            if useOfficialApi then
                                translateOfficialAsync text source target apiKey
                            else
                                translateUnofficialAsync text source target

                        return result
                    with
                    | :? HttpRequestException as hre ->
                        Logger.error (sprintf "HTTP error attempt %d: %s" attempt hre.Message)
                        if attempt >= maxAttempts then
                            return Error hre.Message
                        else
                            let delay = TimeSpan.FromSeconds(Math.Pow(2.0, float attempt)) + TimeSpan.FromMilliseconds(float (rnd.Next(0, 300)))
                            statusCallback (sprintf "HTTP error. Retrying in %.1fs (attempt %d/%d)" delay.TotalSeconds attempt maxAttempts)
                            do! Async.Sleep (int delay.TotalMilliseconds)
                            return! attemptLoop (attempt + 1)
                    | ex ->
                        Logger.error (sprintf "Translation error attempt %d: %s" attempt ex.Message)
                        if attempt >= maxAttempts then
                            return Error ex.Message
                        else
                            let delay = TimeSpan.FromSeconds(Math.Pow(2.0, float attempt)) + TimeSpan.FromMilliseconds(float (rnd.Next(0, 300)))
                            statusCallback (sprintf "Error. Retrying in %.1fs (attempt %d/%d)" delay.TotalSeconds attempt maxAttempts)
                            do! Async.Sleep (int delay.TotalMilliseconds)
                            return! attemptLoop (attempt + 1)
                }

            return! attemptLoop 1
    }

[<STAThread>]
do
    Application.EnableVisualStyles()
    Application.SetCompatibleTextRenderingDefault(false)

    // Main form
    let form = new Form(Text = "F# TranslationFiesta", Width = 900, Height = 650)

    // UI State
    let uiState = { IsDarkTheme = false; UseOfficialApi = false; ApiKey = "" }

    // Header controls
    let lblTitle = new Label(Text = "Backtranslation (English → ja → English)", Left = 10, Top = 30, Width = 600, Height = 25, Font = new System.Drawing.Font("Segoe UI", 10.0f, System.Drawing.FontStyle.Bold), TextAlign = System.Drawing.ContentAlignment.MiddleCenter)

    // Input text area
    let txtInput = new TextBox(Left = 10, Top = 65, Width = 600, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical)

    // Side panel controls
    let tglEndpoint = new CheckBox(Text = "Use Official API", Left = 620, Top = 65, Width = 160)
    let txtApiKey = new TextBox(Left = 620, Top = 95, Width = 260, Height = 25, PasswordChar = '*')
    let btnBacktranslate = new Button(Text = "Backtranslate", Left = 620, Top = 115, Width = 140)
    let btnImportTxt = new Button(Text = "Import .txt", Left = 620, Top = 150, Width = 140)
    let btnCopyResult = new Button(Text = "Copy Result", Left = 620, Top = 185, Width = 140)
    let btnSaveResult = new Button(Text = "Save Result", Left = 620, Top = 220, Width = 140)
    let tglTheme = new CheckBox(Text = "Dark Mode", Left = 620, Top = 255, Width = 140)

    // Intermediate result
    let lblIntermediate = new Label(Text = "Intermediate (ja):", Left = 10, Top = 195, Width = 200, Font = new System.Drawing.Font("Segoe UI", 9.0f, System.Drawing.FontStyle.Bold))
    let txtIntermediate = new TextBox(Left = 10, Top = 215, Width = 600, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true)

    // Final result
    let lblBack = new Label(Text = "Back to English:", Left = 10, Top = 345, Width = 200, Font = new System.Drawing.Font("Segoe UI", 9.0f, System.Drawing.FontStyle.Bold))
    let txtBack = new TextBox(Left = 10, Top = 365, Width = 600, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true)

    // Status and progress
    let lblStatus = new Label(Text = "Ready", Left = 10, Top = 495, Width = 500)
    let progressSpinner = new ProgressBar(Left = 520, Top = 495, Width = 120, Height = 20, Style = ProgressBarStyle.Marquee)
    progressSpinner.Visible <- false

    // No language pickers in simplified UI

    // Helper functions
    let setStatus text =
        lblStatus.Text <- text
        Logger.info (sprintf "Status: %s" text)

    let showSpinner show =
        progressSpinner.Visible <- show
        if show then
            progressSpinner.MarqueeAnimationSpeed <- 30
            Logger.debug "Progress spinner enabled"
        else
            progressSpinner.MarqueeAnimationSpeed <- 0
            Logger.debug "Progress spinner disabled"

    let disableUi () =
        btnBacktranslate.Enabled <- false
        btnImportTxt.Enabled <- false
        txtInput.Enabled <- false
        Logger.debug "UI disabled"

    let enableUi () =
        btnBacktranslate.Enabled <- true
        btnImportTxt.Enabled <- true
        txtInput.Enabled <- true
        Logger.debug "UI enabled"

    let setTheme isDark =
        uiState.IsDarkTheme <- isDark
        if isDark then
            // Dark theme colors
            let darkBg = System.Drawing.Color.FromArgb(32, 32, 32)
            let darkControlBg = System.Drawing.Color.FromArgb(45, 45, 48)
            let lightText = System.Drawing.Color.White
            let lightGray = System.Drawing.Color.LightGray
            
            form.BackColor <- darkBg
            form.ForeColor <- lightText
            
            // Theme all controls
            lblTitle.BackColor <- darkBg
            lblTitle.ForeColor <- lightText
            
            txtInput.BackColor <- darkControlBg
            txtInput.ForeColor <- lightText
            
            txtApiKey.BackColor <- darkControlBg
            txtApiKey.ForeColor <- lightText
            
            txtIntermediate.BackColor <- darkControlBg
            txtIntermediate.ForeColor <- lightText
            
            txtBack.BackColor <- darkControlBg
            txtBack.ForeColor <- lightText
            
            lblIntermediate.BackColor <- darkBg
            lblIntermediate.ForeColor <- lightText
            
            lblBack.BackColor <- darkBg
            lblBack.ForeColor <- lightText
            
            lblStatus.BackColor <- darkBg
            lblStatus.ForeColor <- lightGray
            
            // Buttons and checkboxes
            btnBacktranslate.BackColor <- darkControlBg
            btnBacktranslate.ForeColor <- lightText
            btnBacktranslate.FlatStyle <- FlatStyle.Flat
            
            btnImportTxt.BackColor <- darkControlBg
            btnImportTxt.ForeColor <- lightText
            btnImportTxt.FlatStyle <- FlatStyle.Flat
            
            btnCopyResult.BackColor <- darkControlBg
            btnCopyResult.ForeColor <- lightText
            btnCopyResult.FlatStyle <- FlatStyle.Flat
            
            btnSaveResult.BackColor <- darkControlBg
            btnSaveResult.ForeColor <- lightText
            btnSaveResult.FlatStyle <- FlatStyle.Flat
            
            tglEndpoint.BackColor <- darkBg
            tglEndpoint.ForeColor <- lightText
            
            tglTheme.BackColor <- darkBg
            tglTheme.ForeColor <- lightText
            
            setStatus "Dark mode enabled"
        else
            // Light theme (default Windows colors)
            form.BackColor <- System.Drawing.SystemColors.Control
            form.ForeColor <- System.Drawing.SystemColors.ControlText
            
            // Reset all controls to default
            lblTitle.BackColor <- System.Drawing.SystemColors.Control
            lblTitle.ForeColor <- System.Drawing.SystemColors.ControlText
            
            txtInput.BackColor <- System.Drawing.SystemColors.Window
            txtInput.ForeColor <- System.Drawing.SystemColors.WindowText
            
            txtApiKey.BackColor <- System.Drawing.SystemColors.Window
            txtApiKey.ForeColor <- System.Drawing.SystemColors.WindowText
            
            txtIntermediate.BackColor <- System.Drawing.SystemColors.Window
            txtIntermediate.ForeColor <- System.Drawing.SystemColors.WindowText
            
            txtBack.BackColor <- System.Drawing.SystemColors.Window
            txtBack.ForeColor <- System.Drawing.SystemColors.WindowText
            
            lblIntermediate.BackColor <- System.Drawing.SystemColors.Control
            lblIntermediate.ForeColor <- System.Drawing.SystemColors.ControlText
            
            lblBack.BackColor <- System.Drawing.SystemColors.Control
            lblBack.ForeColor <- System.Drawing.SystemColors.ControlText
            
            lblStatus.BackColor <- System.Drawing.SystemColors.Control
            lblStatus.ForeColor <- System.Drawing.SystemColors.ControlText
            
            // Reset buttons and checkboxes
            btnBacktranslate.BackColor <- System.Drawing.SystemColors.Control
            btnBacktranslate.ForeColor <- System.Drawing.SystemColors.ControlText
            btnBacktranslate.FlatStyle <- FlatStyle.Standard
            
            btnImportTxt.BackColor <- System.Drawing.SystemColors.Control
            btnImportTxt.ForeColor <- System.Drawing.SystemColors.ControlText
            btnImportTxt.FlatStyle <- FlatStyle.Standard
            
            btnCopyResult.BackColor <- System.Drawing.SystemColors.Control
            btnCopyResult.ForeColor <- System.Drawing.SystemColors.ControlText
            btnCopyResult.FlatStyle <- FlatStyle.Standard
            
            btnSaveResult.BackColor <- System.Drawing.SystemColors.Control
            btnSaveResult.ForeColor <- System.Drawing.SystemColors.ControlText
            btnSaveResult.FlatStyle <- FlatStyle.Standard
            
            tglEndpoint.BackColor <- System.Drawing.SystemColors.Control
            tglEndpoint.ForeColor <- System.Drawing.SystemColors.ControlText
            
            tglTheme.BackColor <- System.Drawing.SystemColors.Control
            tglTheme.ForeColor <- System.Drawing.SystemColors.ControlText
            
            setStatus "Light mode enabled"

    let copyResult () =
        if not (String.IsNullOrEmpty txtBack.Text) then
            Clipboard.SetText(txtBack.Text)
            setStatus "Result copied to clipboard"
        else
            setStatus "Nothing to copy"

    let saveResult () =
        let dlg = new SaveFileDialog()
        dlg.DefaultExt <- ".txt"
        dlg.Filter <- "Text documents (.txt)|*.txt|All files|*.*"
        dlg.FileName <- "backtranslation.txt"
        if dlg.ShowDialog() = DialogResult.OK then
            try
                File.WriteAllText(dlg.FileName, txtBack.Text, Encoding.UTF8)
                setStatus (sprintf "Saved to %s" dlg.FileName)
                Logger.info (sprintf "Result saved to file: %s" dlg.FileName)
            with ex ->
                let errorMsg = sprintf "Failed to save file: %s" ex.Message
                MessageBox.Show(errorMsg, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                setStatus "Save failed"
                Logger.error errorMsg

    // Event handlers
    tglEndpoint.CheckedChanged.Add(fun _ ->
        uiState.UseOfficialApi <- tglEndpoint.Checked
        txtApiKey.Enabled <- tglEndpoint.Checked
        if tglEndpoint.Checked then
            setStatus "Using official Google Cloud Translation API"
        else
            setStatus "Using unofficial translate.googleapis.com endpoint"
    )

    txtApiKey.TextChanged.Add(fun _ ->
        uiState.ApiKey <- txtApiKey.Text
        Logger.debug "API key updated"
    )

    tglTheme.CheckedChanged.Add(fun _ -> setTheme tglTheme.Checked)

    btnCopyResult.Click.Add(fun _ -> copyResult())
    btnSaveResult.Click.Add(fun _ -> saveResult())
    btnImportTxt.Click.Add(fun _ ->
        use ofd = new OpenFileDialog()
        ofd.Filter <- "Text files (*.txt)|*.txt|All files (*.*)|*.*"
        ofd.Multiselect <- false
        if ofd.ShowDialog() = DialogResult.OK then
            try
                txtInput.Text <- File.ReadAllText(ofd.FileName, Encoding.UTF8)
                setStatus (sprintf "Loaded %s" (Path.GetFileName ofd.FileName))
            with ex ->
                MessageBox.Show(sprintf "Failed to load file: %s" ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                setStatus "File import failed"
    )

    // Menu

    let menuStrip = new MenuStrip()
    let fileMenu = new ToolStripMenuItem("&File")
    fileMenu.DropDownItems.Add(new ToolStripMenuItem("&Import .txt", null, EventHandler(fun _ _ -> btnImportTxt.PerformClick()))) |> ignore
    fileMenu.DropDownItems.Add(new ToolStripMenuItem("&Copy Result", null, EventHandler(fun _ _ -> copyResult()))) |> ignore
    fileMenu.DropDownItems.Add(new ToolStripMenuItem("&Save Result", null, EventHandler(fun _ _ -> saveResult()))) |> ignore
    menuStrip.Items.Add(fileMenu) |> ignore
    form.MainMenuStrip <- menuStrip
    form.Controls.Add(menuStrip)

    // Main backtranslation logic
    btnBacktranslate.Click.Add(fun _ ->
        async {
            try
                disableUi()
                showSpinner true
                txtIntermediate.Text <- ""
                txtBack.Text <- ""

                try
                    let input = txtInput.Text
                    if String.IsNullOrWhiteSpace input then
                        MessageBox.Show("Please enter text to translate.", "No input", MessageBoxButtons.OK, MessageBoxIcon.Warning) |> ignore
                    else
                        let sourceCode = "en"
                        let targetCode = defaultIntermediateLanguageCode

                        setStatus (sprintf "Translating to %s..." targetCode)

                        let! r1 = translateWithRetriesAsync input sourceCode targetCode uiState.UseOfficialApi uiState.ApiKey 4 setStatus
                        match r1 with
                        | Error e ->
                            Logger.error (sprintf "Translation to target failed: %s" e)
                            MessageBox.Show(sprintf "Translation failed: %s" e, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                            setStatus "Error"
                        | Ok intermediate ->
                            txtIntermediate.Text <- intermediate
                            lblIntermediate.Text <- "Intermediate (ja):"

                            setStatus "Translating back to English..."

                            let! r2 = translateWithRetriesAsync intermediate targetCode "en" uiState.UseOfficialApi uiState.ApiKey 4 setStatus
                            match r2 with
                            | Error e2 ->
                                Logger.error (sprintf "Translation back to English failed: %s" e2)
                                MessageBox.Show(sprintf "Back translation failed: %s" e2, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                                setStatus "Error"
                            | Ok back ->
                                txtBack.Text <- back
                                setStatus "Backtranslation complete!"
                                Logger.info (sprintf "Backtranslation completed successfully: %d -> %d -> %d chars" input.Length intermediate.Length back.Length)
                with ex ->
                    Logger.error (sprintf "Backtranslation failed: %s" ex.Message)
                    MessageBox.Show(sprintf "Translation failed: %s" ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error) |> ignore
                    setStatus "Error"
            finally
                enableUi()
                showSpinner false
        } |> Async.StartImmediate)

    // Add all controls to form
    form.Controls.AddRange([|
        lblTitle :> Control
        txtInput :> Control
        tglEndpoint :> Control; txtApiKey :> Control; btnBacktranslate :> Control; btnImportTxt :> Control; btnCopyResult :> Control; btnSaveResult :> Control; tglTheme :> Control
        lblIntermediate :> Control; txtIntermediate :> Control
        lblBack :> Control; txtBack :> Control
        lblStatus :> Control; progressSpinner :> Control
    |])

    Logger.info "F# TranslationFiesta started"
    Application.Run(form)
