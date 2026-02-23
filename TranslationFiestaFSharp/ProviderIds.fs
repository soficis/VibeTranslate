namespace TranslationFiestaFSharp

module ProviderIds =
    let Local = "local"
    let GoogleUnofficial = "google_unofficial"
    let GoogleOfficial = "google_official"

    let normalize (value: string) =
        let trimmed =
            if isNull value then ""
            else value.Trim().ToLowerInvariant()
        match trimmed with
        | v when v = Local -> Local
        | v when v = GoogleOfficial -> GoogleOfficial
        | "official" -> GoogleOfficial
        | "google" -> GoogleOfficial
        | "google_cloud" -> GoogleOfficial
        | "googlecloud" -> GoogleOfficial
        | "unofficial" -> GoogleUnofficial
        | "google_unofficial_free" -> GoogleUnofficial
        | "google_free" -> GoogleUnofficial
        | "googletranslate" -> GoogleUnofficial
        | "" -> GoogleUnofficial
        | _ -> GoogleUnofficial

    let isOfficial (providerId: string) =
        normalize providerId = GoogleOfficial

