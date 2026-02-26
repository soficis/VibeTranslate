namespace TranslationFiestaFSharp

module ProviderIds =
    let GoogleUnofficial = "google_unofficial"

    let normalize (value: string | null) =
        let trimmed =
            match value with
            | null -> ""
            | text -> text.Trim().ToLowerInvariant()
        match trimmed with
        | "unofficial" -> GoogleUnofficial
        | "google_unofficial_free" -> GoogleUnofficial
        | "google_free" -> GoogleUnofficial
        | "googletranslate" -> GoogleUnofficial
        | "" -> GoogleUnofficial
        | _ -> GoogleUnofficial

