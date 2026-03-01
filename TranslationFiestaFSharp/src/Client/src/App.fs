module App

open Elmish
open Feliz
open Fable.Core
open Fable.Core.JsInterop
open Fable.Core.JS
open Browser.Dom
open Elmish.React

[<Emit("window.external.sendMessage($0)")>]
let sendMessageToPhotino (msg: string) : unit = jsNative

[<Emit("window.ReceiveWebMessage = $0")>]
let setReceiveWebMessage (f: string -> unit) : unit = jsNative

[<Emit("navigator.clipboard.writeText($0)")>]
let copyToClipboard (text: string) : unit = jsNative

type IncomingMessage = {
    ``type``: string
    text: string option
    message: string option
    isBusy: bool option
}

type State = {
    InputText: string
    ResultText: string
    StatusMessage: string
    IsBusy: bool
    IntermediateText: string
}

type Msg =
    | InputTextChanged of string
    | TranslateClicked
    | ReceivedWebMessage of string
    | ImportClicked
    | CopyClicked

let defaultProviderId = "google_unofficial"

let listenForPhotinoMessages (dispatch: Msg -> unit) =
    setReceiveWebMessage (fun msg -> dispatch (ReceivedWebMessage msg))

let init () : State * Cmd<Msg> =
    { InputText = ""
      ResultText = ""
      StatusMessage = "Ready"
      IsBusy = false
      IntermediateText = "" }, Cmd.ofEffect listenForPhotinoMessages

let update (msg: Msg) (state: State) : State * Cmd<Msg> =
    match msg with
    | InputTextChanged text ->
        { state with InputText = text }, Cmd.none
    | TranslateClicked ->
        if System.String.IsNullOrWhiteSpace(state.InputText) then
            state, Cmd.none
        else
            let jsMsg =
                {| command = "translate"; text = state.InputText; provider = defaultProviderId |}
                |> JSON.stringify
            
            sendMessageToPhotino jsMsg
            { state with IsBusy = true; StatusMessage = "Translating..."; ResultText = ""; IntermediateText = "" }, Cmd.none
            
    | ReceivedWebMessage jsonStr ->
        try
            let parsed = JSON.parse(jsonStr) |> unbox<IncomingMessage>
            match parsed.``type`` with
            | "status" ->
                { state with StatusMessage = Option.defaultValue state.StatusMessage parsed.message; IsBusy = Option.defaultValue state.IsBusy parsed.isBusy }, Cmd.none
            | "result" ->
                { state with ResultText = Option.defaultValue state.ResultText parsed.text }, Cmd.none
            | "intermediate" ->
                { state with IntermediateText = Option.defaultValue state.IntermediateText parsed.text }, Cmd.none
            | "error" ->
                { state with StatusMessage = Option.defaultValue "Error" parsed.message; IsBusy = false }, Cmd.none
            | _ -> state, Cmd.none
        with _ ->
            state, Cmd.none
            
    | ImportClicked ->
        sendMessageToPhotino (JSON.stringify({| command = "importFile" |}))
        state, Cmd.none

    | CopyClicked ->
        if not (System.String.IsNullOrWhiteSpace(state.ResultText)) then
            copyToClipboard state.ResultText
        state, Cmd.none

let renderPanel (title: string) (content: ReactElement) =
    Html.div [
        prop.style [ style.custom("flex", "1"); style.custom("display", "flex"); style.custom("flex-direction", "column") ]
        prop.children [
            Html.div [
                prop.style [ style.custom("color", "#9ca3af"); style.custom("font-size", "12px"); style.custom("font-weight", "600"); style.custom("text-transform", "uppercase"); style.custom("letter-spacing", "1px"); style.custom("margin-bottom", "8px") ]
                prop.children [ Html.text title ]
            ]
            content
        ]
    ]

let view (state: State) (dispatch: Msg -> unit) : ReactElement =
    Html.div [
        prop.style [
            style.custom("display", "flex")
            style.custom("flex-direction", "column")
            style.custom("height", "100vh")
            style.custom("padding", "20px")
            style.custom("background-color", "#121212")
            style.custom("color", "#ffffff")
            style.custom("font-family", "Inter, sans-serif")
            style.custom("box-sizing", "border-box")
        ]
        prop.children [
            // Top Panel
            renderPanel "Original Text" (
                Html.textarea [
                    prop.style [
                        style.custom("flex", "1")
                        style.custom("background-color", "#1e1e1e")
                        style.custom("color", "#e5e5e5")
                        style.custom("border", "2px solid #333333")
                        style.custom("border-radius", "8px")
                        style.custom("padding", "12px")
                        style.custom("font-size", "16px")
                        style.custom("line-height", "1.5")
                        style.custom("resize", "none")
                        style.custom("outline", "none")
                    ]
                    prop.placeholder "Enter text to translate..."
                    prop.value state.InputText
                    prop.onTextChange (fun v -> dispatch (InputTextChanged v))
                ]
            )

            // Middle Panel
            Html.div [
                prop.style [ style.custom("display", "flex"); style.custom("align-items", "center"); style.custom("justify-content", "space-between"); style.custom("padding", "12px 0px") ]
                prop.children [
                    Html.div [
                        Html.button [
                            prop.style [ style.custom("background-color", "#2d2d2d"); style.custom("color", "#ffffff"); style.custom("border", "1px solid #404040"); style.custom("border-radius", "4px"); style.custom("padding", "8px 16px"); style.custom("cursor", "pointer"); style.custom("font-size", "14px") ]
                            prop.text "Import File"
                            prop.onClick (fun _ -> dispatch ImportClicked)
                        ]
                    ]
                    Html.div [
                        prop.style [ style.custom("display", "flex"); style.custom("align-items", "center"); style.custom("gap", "12px") ]
                        prop.children [
                            Html.span [
                                prop.style [ style.custom("color", "#9ca3af"); style.custom("font-size", "14px") ]
                                prop.text state.StatusMessage
                            ]
                            Html.button [
                                prop.style [
                                    style.custom("background-color", "#3b82f6")
                                    style.custom("color", "#ffffff")
                                    style.custom("border", "none")
                                    style.custom("border-radius", "20px")
                                    style.custom("padding", "10px 24px")
                                    style.custom("font-weight", "600")
                                    style.custom("cursor", if state.IsBusy then "not-allowed" else "pointer")
                                ]
                                prop.text (if state.IsBusy then "Translating..." else "Translate")
                                prop.disabled state.IsBusy
                                prop.onClick (fun _ -> dispatch TranslateClicked)
                            ]
                        ]
                    ]
                ]
            ]

            // Bottom Panel
            Html.div [
                prop.style [ style.custom("flex", "1"); style.custom("display", "flex"); style.custom("gap", "20px") ]
                prop.children [
                    renderPanel "Intermediate (Japanese)" (
                        Html.textarea [
                            prop.style [ style.custom("flex", "1"); style.custom("background-color", "#1a1a1a"); style.custom("color", "#a3a3a3"); style.custom("border", "1px solid #2a2a2a"); style.custom("border-radius", "8px"); style.custom("padding", "12px"); style.custom("resize", "none") ]
                            prop.readOnly true
                            prop.value state.IntermediateText
                        ]
                    )
                    renderPanel "Final Result (English)" (
                        Html.div [
                            prop.style [ style.custom("flex", "1"); style.custom("position", "relative") ]
                            prop.children [
                                Html.textarea [
                                    prop.style [ style.custom("width", "100%"); style.custom("height", "100%"); style.custom("background-color", "#1e1e1e"); style.custom("color", "#ffffff"); style.custom("border", "2px solid #333333"); style.custom("border-radius", "8px"); style.custom("padding", "12px"); style.custom("resize", "none") ]
                                    prop.readOnly true
                                    prop.value state.ResultText
                                ]
                                if not (System.String.IsNullOrWhiteSpace(state.ResultText)) then
                                    Html.button [
                                        prop.style [ style.custom("position", "absolute"); style.custom("bottom", "12px"); style.custom("right", "12px"); style.custom("background-color", "#2d2d2d"); style.custom("color", "#ffffff"); style.custom("border", "1px solid #404040") ]
                                        prop.text "Copy"
                                        prop.onClick (fun _ -> dispatch CopyClicked)
                                    ]
                            ]
                        ]
                    )
                ]
            ]
        ]
    ]

let program =
    Program.mkProgram init update view
    |> Program.withReactSynchronous "root"
