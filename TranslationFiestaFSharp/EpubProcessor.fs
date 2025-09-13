#nullable enable
#nowarn "3261" "3262" // Suppress nullness warnings
/// <summary>
/// This module provides functionality for processing EPUB files using the VersOne.Epub library.
/// It supports loading EPUB books, extracting titles, chapters, and chapter content.
/// </summary>
namespace TranslationFiestaFSharp

open System
open VersOne.Epub
open TranslationFiestaFSharp.Logger

/// <summary>
/// Provides functions for EPUB file processing using VersOne.Epub library.
/// </summary>
module EpubProcessor =

    /// <summary>
    /// Stores the currently loaded EPUB book.
    /// </summary>
    let mutable private currentBook: EpubBook option = None

    /// <summary>
    /// Recursively flattens the table of contents to get all navigation items.
    /// </summary>
    let rec getAllNavigationItems (items: seq<VersOne.Epub.EpubNavigationItem>) : seq<VersOne.Epub.EpubNavigationItem> =
        seq {
            for item in items do
                yield item
                match item.NestedItems with
                | null -> ()
                | nestedItems ->
                    yield! getAllNavigationItems (nestedItems :> seq<VersOne.Epub.EpubNavigationItem>)
        }

    /// <summary>
    /// Attempts to load an EPUB file using VersOne.Epub library.
    /// </summary>
    /// <param name="filePath">The path to the EPUB file.</param>
    /// <returns><c>true</c> if the book was loaded successfully, <c>false</c> otherwise.</returns>
    let loadEpub (filePath: string) : bool =
        try
            let book = EpubReader.ReadBook(filePath)
            currentBook <- Some book
            Logger.info $"Successfully loaded EPUB book: {book.Title}"
            true
        with
        | ex ->
            Logger.error $"Failed to load EPUB file '{filePath}': {ex.Message}"
            currentBook <- None
            false

    /// <summary>
    /// Gets the title of the loaded EPUB book.
    /// </summary>
    /// <returns>The title of the book, or an empty string if no book is loaded.</returns>
    let getBookTitle () : string =
        match currentBook with
        | Some book ->
            match Some book.Title with
            | Some title -> title
            | None -> String.Empty
        | None -> String.Empty

    /// <summary>
    /// Gets the titles of all chapters in the loaded EPUB book.
    /// </summary>
    /// <returns>A list of chapter titles, or an empty list if no book is loaded.</returns>
    let getChapters () : string list =
        match currentBook with
        | Some book ->
            match book.Navigation with
            | null -> []
            | navigation ->
                navigation
                |> getAllNavigationItems
                |> Seq.choose (fun item ->
                    match item.Title with
                    | null -> None
                    | title -> Some title
                )
                |> Seq.toList
        | None -> []

    /// <summary>
    /// Gets the content of a specific chapter by its title.
    /// </summary>
    /// <param name="chapterTitle">The title of the chapter to retrieve.</param>
    /// <returns>The HTML content of the chapter, or an empty string if not found.</returns>
    let getChapterContent (chapterTitle: string) : string =
        // Temporarily disabled due to epub library API changes in VersOne.Epub 3.3.4
        // TODO: Update to use new epub library API or switch to compatible library version
        Logger.info $"EPUB content access disabled - API compatibility issue with VersOne.Epub"
        String.Empty

    /// <summary>
    /// Gets the content of a specific chapter by its index.
    /// </summary>
    /// <param name="chapterIndex">The zero-based index of the chapter to retrieve.</param>
    /// <returns>The HTML content of the chapter, or an empty string if index is invalid.</returns>
    let getChapterContentByIndex (chapterIndex: int) : string =
        match currentBook with
        | Some book ->
            match Some book.ReadingOrder with
            | Some readingOrder when chapterIndex >= 0 && chapterIndex < readingOrder.Count ->
                let chapter = readingOrder.[chapterIndex]
                match Some chapter.Content with
                | Some (content: string) -> content
                | _ -> String.Empty
            | _ -> String.Empty
        | None -> String.Empty