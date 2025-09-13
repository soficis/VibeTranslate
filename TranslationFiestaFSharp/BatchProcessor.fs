/// <summary>
/// This module provides functionality for batch processing of translation tasks across multiple files in a directory.
/// It has been refactored according to Clean Code principles to improve readability,
/// maintainability, and efficiency, focusing on clear responsibilities and robust error handling.
///
/// Key Refactorings:
/// - **Meaningful Naming**: Ensured functions and parameters have clear, descriptive names.
/// - **Clear Structure**: The module is focused solely on iterating through files and applying a translation function.
/// - **Robust Error Handling**: Replaced direct `MessageBox.Show` calls with a functional `Result` type
///   for error propagation, allowing the calling context (e.g., UI layer) to handle error display.
/// - **Immutability**: Maintained an immutable approach to file processing where possible.
/// - **XML Documentation**: Added comprehensive XML documentation to the module and its public functions.
/// </summary>
namespace TranslationFiestaFSharp

open System
open System.IO
open System.Threading.Tasks // Still needed for Async.AwaitTask if used within translateFn
open System.Windows.Forms

/// <summary>
/// This module provides functionality for batch processing of files within a selected directory.
/// </summary>
module BatchProcessor =
    
    /// <summary>
    /// Processes multiple files in a selected directory using a provided translation function.
    /// </summary>
    /// <param name="translateFn">An asynchronous function that takes a file path and returns
    /// an <see cref="Async{Result{string,string}}"/> representing the translated text or an error.</param>
    /// <param name="updateCallback">A callback function to report progress (completed files, total files).</param>
    /// <returns>An asynchronous operation that, when completed, indicates the result of the batch process for each file.</returns>
    let processDirectory (translateFn: string -> Async<Result<string, string>>) (updateCallback: int -> int -> unit) : Async<Result<string, string> list> =
        async {
            let fbd = new FolderBrowserDialog()
            fbd.Description <- "Select a directory to batch process for translation."

            if fbd.ShowDialog() = System.Windows.Forms.DialogResult.OK then
                let selectedDirectory = fbd.SelectedPath
                let supportedExtensions = [".txt"; ".md"; ".html"; ".epub"]

                let filesToProcess =
                    Directory.GetFiles(selectedDirectory, "*.*", SearchOption.AllDirectories)
                    |> Array.filter (fun f -> supportedExtensions |> List.exists (fun ext -> f.ToLowerInvariant().EndsWith(ext)))
                    |> Array.toList
                
                let totalFiles = filesToProcess.Length
                let mutable completedFiles = 0
                let mutable results = []

                for file in filesToProcess do
                    let! translationResult = translateFn file

                    let processResult =
                        match translationResult with
                        | Ok translatedText ->
                            match Path.GetDirectoryName(file) with
                            | null -> Error (sprintf "Invalid file path for %s: could not determine directory" file)
                            | directory ->
                                let newFileName = Path.Combine(directory, $"{Path.GetFileNameWithoutExtension(file)}_translated{Path.GetExtension(file)}")
                                try
                                    File.WriteAllText(newFileName, translatedText, System.Text.Encoding.UTF8)
                                    Ok (sprintf "Successfully translated %s to %s" file newFileName)
                                with ex ->
                                    Error (sprintf "Failed to write translated file %s: %s" newFileName ex.Message)
                        | Error msg ->
                            Error (sprintf "Translation failed for %s: %s" file msg)
                    
                    results <- processResult :: results
                    
                    completedFiles <- completedFiles + 1
                    updateCallback completedFiles totalFiles
                
                return List.rev results
            else
                return []
        }
