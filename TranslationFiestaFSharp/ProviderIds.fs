namespace TranslationFiestaFSharp

module ProviderIds =
    let Local = "local"
    let GoogleUnofficial = "google_unofficial"

    let normalize (value: string) =
        let trimmed =
            if isNull value then ""
            else value.Trim().ToLowerInvariant()
        match trimmed with
        | v when v = Local -> Local
        | "unofficial" -> GoogleUnofficial
        | "google_unofficial_free" -> GoogleUnofficial
        | "google_free" -> GoogleUnofficial
        | "googletranslate" -> GoogleUnofficial
        | "" -> GoogleUnofficial
        | _ -> GoogleUnofficial

