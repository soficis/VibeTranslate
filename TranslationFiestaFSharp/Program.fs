#nullable enable
#nowarn "FS0057"
namespace TranslationFiestaFSharp

open System
open System.Net.Http
open System.Text.RegularExpressions
open System.Text.Json
open System.Text
open System.IO
open System.Threading
open System.Threading.Tasks
open PhotinoNET

module FileOperations =
    let extractTextFromHtml (htmlContent: string) : string =
        try
            let scriptPattern = "<script[^>]*>.*?</script>"
            let stylePattern = "<style[^>]*>.*?</style>"
            let codePattern = "<code[^>]*>.*?</code>"
            let prePattern = "<pre[^>]*>.*?</pre>"

            let withoutScripts = Regex.Replace(htmlContent, scriptPattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
            let withoutStyles = Regex.Replace(withoutScripts, stylePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
            let withoutCode = Regex.Replace(withoutStyles, codePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)
            let withoutPre = Regex.Replace(withoutCode, prePattern, "", RegexOptions.Singleline ||| RegexOptions.IgnoreCase)

            let tagPattern = "<[^>]+>"
            let withoutTags = Regex.Replace(withoutPre, tagPattern, "")

            let normalized = Regex.Replace(withoutTags, @"\s+", " ")
            normalized.Trim()
        with _ -> htmlContent

    let loadTextFromFile (filePath: string) : Result<string, string> =
        try
            let extensionLower = (Path.GetExtension(filePath) |> Option.ofObj |> Option.defaultValue "").ToLower()
            let rawContent = File.ReadAllText(filePath, Encoding.UTF8)

            match extensionLower with
            | ".html" -> Ok (extractTextFromHtml rawContent)
            | ".md" | ".txt" -> Ok (rawContent.Trim())
            | ".epub" ->
                if EpubProcessor.loadEpub filePath then
                    let chapters = EpubProcessor.getChapters()
                    if not (List.isEmpty chapters) then
                        let firstChapterContent = EpubProcessor.getChapterContent(List.head chapters)
                        Ok (extractTextFromHtml(firstChapterContent.Trim()))
                    else Ok String.Empty
                else Error "Failed to load EPUB file."
            | _ -> Ok (rawContent.Trim())
        with ex ->
            Error (sprintf "Failed to load file %s: %s" filePath ex.Message)

module TranslationService =
    let httpClient = new HttpClient()

    let translateUnofficialAsync (text: string) (source: string) (target: string) : Async<Result<string, string>> =
        async {
            try
                let encodedText = Uri.EscapeDataString(text)
                let url = sprintf "https://translate.googleapis.com/translate_a/single?client=gtx&sl=%s&tl=%s&dt=t&q=%s" source target encodedText
                let! response = httpClient.GetAsync(url) |> Async.AwaitTask
                let! body = response.Content.ReadAsStringAsync() |> Async.AwaitTask

                if not response.IsSuccessStatusCode then
                    return Error (sprintf "HTTP %d" (int response.StatusCode))
                else if String.IsNullOrWhiteSpace body then
                    return Error "Empty response body"
                else
                    use doc = JsonDocument.Parse(body)
                    let root = doc.RootElement
                    if root.ValueKind = JsonValueKind.Array && root.GetArrayLength() > 0 then
                        let translationArray = root[0]
                        let sb = StringBuilder()
                        for sentence in translationArray.EnumerateArray() do
                            if sentence.ValueKind = JsonValueKind.Array && sentence.GetArrayLength() > 0 then
                                let partNullable = sentence[0].GetString()
                                match Option.ofObj partNullable with
                                | Some p -> sb.Append(p) |> ignore
                                | None -> ()
                        return Ok (sb.ToString())
                    else return Error "Invalid format"
            with ex -> return Error ex.Message
        }

type WebMessage = {
    command: string
    text: string
    provider: string
}

module Program =
    let handleWebMessage (window: PhotinoWindow) (message: string) =
        try
            let msg = JsonSerializer.Deserialize<WebMessage>(message, JsonSerializerOptions(PropertyNameCaseInsensitive = true))
            if not (isNull (box msg)) then
                match msg.command with
                | "translate" ->
                    async {
                        window.SendWebMessage(JsonSerializer.Serialize({| ``type`` = "status"; message = "Translating..."; isBusy = true |}))
                        let! result = TranslationService.translateUnofficialAsync msg.text "en" "ja"
                        match result with
                        | Ok res ->
                            window.SendWebMessage(JsonSerializer.Serialize({| ``type`` = "result"; text = res |}))
                            window.SendWebMessage(JsonSerializer.Serialize({| ``type`` = "status"; message = "Done"; isBusy = false |}))
                        | Error err ->
                            window.SendWebMessage(JsonSerializer.Serialize({| ``type`` = "error"; message = err |}))
                            window.SendWebMessage(JsonSerializer.Serialize({| ``type`` = "status"; message = "Error"; isBusy = false |}))
                    }
                    |> Async.Start
                | _ -> ()
        with ex ->
            Logger.error (sprintf "Message error: %A" ex)

    [<EntryPoint>]
    let main args =
        let window = new PhotinoWindow()
        window
            .SetTitle("TranslationFiesta F#")
            .SetSize(System.Drawing.Size(900, 800))
            .Center()
            .RegisterWebMessageReceivedHandler(fun (_sender: obj) (message: string) -> handleWebMessage window message)
            .Load("wwwroot/index.html")
            .WaitForClose() |> ignore
        0
