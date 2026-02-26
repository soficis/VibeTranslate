namespace TranslationFiestaFSharp

module Logger =

    open System

    let private lockObj = obj()
    let private logFile = PortablePaths.logFilePath

    let private write level message =
        try
            lock lockObj (fun () ->
                    let logEntry = sprintf "[%s] %s: %s%s" (DateTime.UtcNow.ToString("O")) level message Environment.NewLine
                    System.IO.File.AppendAllText(logFile, logEntry)
            )
        with
        | _ -> () // Best effort logging; don't crash app

    let info message = write "INFO" message
    let error message = write "ERROR" message
    let debug message = write "DEBUG" message
