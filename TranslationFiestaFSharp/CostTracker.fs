#nullable enable
#nowarn "3261" // Suppress nullness warnings
/// <summary>
/// This module provides functionality for tracking translation costs, managing budgets,
/// and generating cost reports. It has been refactored according to Clean Code principles
/// to improve readability, maintainability, and efficiency, with a strong emphasis on
/// immutability and thread-safe state management.
///
/// Key Refactorings:
/// - **Immutability**: The core state (`CostTrackerState`) is now immutable. All operations
///   that modify the state return a new state, or dispatch messages to a `MailboxProcessor`
///   for thread-safe updates.
/// - **Thread-Safe State Management**: Introduced a `MailboxProcessor` (`costTrackerMailbox`)
///   to manage the `CostTrackerState`, ensuring all state modifications are sequential
///   and thread-safe, eliminating the need for manual `lock` statements for the main state.
/// - **Robust Error Handling**: Operations involving file I/O (`LoadData`, `SaveData`)
///   now explicitly return `Result` types, allowing for graceful error handling.
/// - **Clear Structure and Separation of Concerns**:
///     - `CostTrackerState` record encapsulates all mutable data.
///     - `CostTrackerMessage` discriminated union defines all possible state transitions.
///     - `CostTracker` type now primarily dispatches messages to the mailbox and queries the current state.
///     - Persistence logic (`FileOperations` module) is separated from core business logic.
/// - **Meaningful Naming**: Ensured all types, functions, and parameters have clear, descriptive names.
/// - **XML Documentation**: Added comprehensive XML documentation to all public types and members
///   to enhance clarity and discoverability.
///
/// Namespace-Level Type Definitions:
/// The core types (CostEntry, Budget, CostTrackerState, CostTrackerMessage) have been moved to namespace
/// level to eliminate scoping barriers between modules, resolving FS0039 "type not defined" errors.
/// This allows FileOperations and other modules to access these types directly.
/// </summary>
namespace TranslationFiestaFSharp

open System
open System.IO
open System.Text.Json
open System.Collections.Generic // Still used for Dictionary in JSON deserialization of dynamic objects
open System.Threading.Tasks // For Async operations
open TranslationFiestaFSharp.Logger
open TranslationFiestaFSharp.Logger

/// <summary>
/// Represents a single entry of translation cost.
/// </summary>
type CostEntry = {
    Timestamp: int64
    Characters: int
    CostUSD: float
    SourceLang: string
    TargetLang: string
    Implementation: string
    APIVersion: string
}

/// <summary>
/// Represents the budget configuration and current usage.
/// </summary>
type Budget = {
    MonthlyLimitUSD: float
    CurrentMonthUsageUSD: float
    AlertThresholdPercent: float
    LastResetTimestamp: int64
}

/// <summary>
/// Represents the overall state of the CostTracker, including cost entries and budget.
/// This record is immutable.
/// </summary>
type CostTrackerState = {
    CostEntries: CostEntry list
    Budget: Budget
}

/// <summary>
/// Messages that can be sent to the CostTracker's MailboxProcessor to update its state.
/// </summary>
type CostTrackerMessage =
    | LoadData
    | SaveData
    | TrackTranslation of characters: int * sourceLang: string * targetLang: string * implementation: string * apiVersion: string
    | SetBudget of monthlyLimitUSD: float * alertThresholdPercent: float
    | ResetBudget
    | AddAlertCallback of callback: Action<string, float>
    | GetBudgetStatus of AsyncReplyChannel<IDictionary<string, obj option>>
    | GetCostReport of days: int * groupByImplementation: bool * AsyncReplyChannel<IDictionary<string, obj option>>
    | GetRecentEntries of limit: int * AsyncReplyChannel<CostEntry list>
    | ClearOldEntries of daysToKeep: int * AsyncReplyChannel<int>
    | GetState of AsyncReplyChannel<CostTrackerState>

module CostTracker =

    /// <summary>
    /// Calculates the cost in USD for a given number of characters.
    /// </summary>
    /// <param name="characters">The number of characters translated.</param>
    /// <returns>The calculated cost in USD.</returns>
    let private costPerMillionChars = 20.0
    let calculateCost (characters: int) : float =
        if characters <= 0 then 0.0
        else (float characters / 1_000_000.0) * costPerMillionChars

    /// <summary>
    /// Provides file system operations specifically for the CostTracker,
    /// encapsulating common file actions with <see cref="Result<'T, string>"/> for error handling.
    /// </summary>
    module FileOperations =
        open System.IO
        open System.Text.Json
        open System
        open System.Collections.Generic

        /// <summary>
        /// The default path for storing cost tracking data.
        /// </summary>
        let private defaultStoragePath = Path.Combine(AppContext.BaseDirectory, "translation_costs.json")

        /// <summary>
        /// Ensures that the directory for a given file path exists, creating it if necessary.
        /// </summary>
        /// <param name="filePath">The full path to the file for which the directory should exist.</param>
        /// <returns>A <see cref="Result{unit, string}"/> indicating success or an error message.</returns>
        let ensureDirectoryExists (filePath: string) : Result<unit, string> =
            try
                let directory = Path.GetDirectoryName(filePath)
                let directoryOpt = Option.ofObj directory
                match directoryOpt with
                | Some "" | None -> Ok () // No directory to create
                | Some dir ->
                    Directory.CreateDirectory(dir) |> ignore
                    Ok ()
            with ex ->
                Error (sprintf "Failed to create directory for path '%s': %s" filePath ex.Message)

        /// <summary>
        /// Reads cost tracking data from the specified JSON file.
        /// </summary>
        /// <param name="filePath">The path to the JSON file.</param>
        /// <returns>A <see cref="Result{CostTrackerState, string}"/> containing the loaded state
        /// on success, or an error message on failure.</returns>
        let loadData (filePath: string) : Result<CostTrackerState, string> =
            try
                if not (File.Exists filePath) then
                    Ok { CostEntries = []; Budget = { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L } }
                else
                    let json = File.ReadAllText filePath
                    let data = JsonSerializer.Deserialize<IDictionary<string, JsonElement>>(json)
                    match data with
                    | null ->
                        Ok { CostEntries = []; Budget = { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L } }
                    | data when data.Count = 0 -> // Handle empty dictionary case
                        Ok { CostEntries = []; Budget = { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L } }
                    | data ->
                        let costEntries =
                            let success, jsonElement = data.TryGetValue "cost_entries"
                            match success, jsonElement with
                            | true, jsonEl when jsonEl.ValueKind = JsonValueKind.Array ->
                                jsonEl.EnumerateArray()
                                |> Seq.toList
                                |> List.choose (fun item ->
                                    try
                                        let deserialized = JsonSerializer.Deserialize<CostEntry>(item.GetRawText())
                                        Option.ofObj deserialized
                                    with _ -> None)
                            | _ -> []

                        let budget =
                            let success, jsonElement = data.TryGetValue "budget"
                            match success, jsonElement with
                            | true, jsonEl when jsonEl.ValueKind = JsonValueKind.Object ->
                                let deserialized = JsonSerializer.Deserialize<Budget>(jsonEl.GetRawText())
                                Option.ofObj deserialized
                                |> Option.defaultValue { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L }
                            | _ -> { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L }

                        Ok { CostEntries = costEntries; Budget = budget }
            with ex ->
                Error (sprintf "Failed to load cost data from '%s': %s" filePath ex.Message)

        /// <summary>
        /// Saves the provided cost tracking state to the specified JSON file.
        /// </summary>
        /// <param name="filePath">The path to the JSON file.</param>
        /// <param name="state">The <see cref="CostTrackerState"/> to save.</param>
        /// <returns>A <see cref="Result{unit, string}"/> indicating success or an error message.</returns>
        let saveData (filePath: string) (state: CostTrackerState) : Result<unit, string> =
            try
                ensureDirectoryExists filePath
                |> Result.bind (fun _ ->
                    let data = dict [
                        "cost_entries", box state.CostEntries
                        "budget", box state.Budget
                        "last_updated", box (DateTimeOffset.UtcNow.ToUnixTimeSeconds())
                    ]
                    let json = JsonSerializer.Serialize(data, JsonSerializerOptions(WriteIndented = true))
                    File.WriteAllText(filePath, json)
                    Ok ()
                )
            with ex ->
                Error (sprintf "Failed to save cost data to '%s': %s" filePath ex.Message)

    /// <summary>
    /// Manages the application's cost tracking state in a thread-safe manner using a MailboxProcessor.
    /// </summary>
    type CostTracker(storagePath: string) =
        let mutable alertCallbacks = ResizeArray<Action<string, float>>()

        // MailboxProcessor for thread-safe state management
        let costTrackerMailbox = MailboxProcessor.Start(fun inbox ->
            let rec loop (state: CostTrackerState) =
                async {
                    let! msg = inbox.Receive()

                    let newState =
                        match msg with
                        | LoadData ->
                            match FileOperations.loadData storagePath with
                            | Ok loadedState -> loadedState
                            | Error e ->
                                Logger.error (sprintf "Failed to load cost data: %s" e)
                                state // Return current state on error

                        | SaveData ->
                            match FileOperations.saveData storagePath state with
                            | Ok _ -> Logger.info "Cost data saved successfully."
                            | Error e -> Logger.error (sprintf "Failed to save cost data: %s" e)
                            state // State doesn't change on save operation

                        | TrackTranslation (characters, sourceLang, targetLang, implementation, apiVersion) ->
                            let costUSD = calculateCost characters
                            let entry = {
                                Timestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
                                Characters = characters
                                CostUSD = costUSD
                                SourceLang = sourceLang
                                TargetLang = targetLang
                                Implementation = implementation
                                APIVersion = apiVersion
                            }
                            let newCostEntries = entry :: state.CostEntries
                            let newBudget = { state.Budget with CurrentMonthUsageUSD = state.Budget.CurrentMonthUsageUSD + costUSD }
                            Logger.info (sprintf "Tracked translation: %d chars, $%.6f, %s->%s, total this month:  $%.2f"
                                           characters costUSD sourceLang targetLang newBudget.CurrentMonthUsageUSD)
                            { state with CostEntries = newCostEntries; Budget = newBudget }

                        | SetBudget (monthlyLimitUSD, alertThresholdPercent) ->
                            Logger.info (sprintf "Budget set to $%.2f/month with %.1f%% alert threshold"
                                           monthlyLimitUSD alertThresholdPercent)
                            { state with Budget = { state.Budget with MonthlyLimitUSD = monthlyLimitUSD; AlertThresholdPercent = alertThresholdPercent } }

                        | ResetBudget ->
                            Logger.info "Monthly budget usage reset to $0.00"
                            { state with Budget = { state.Budget with CurrentMonthUsageUSD = 0.0; LastResetTimestamp = DateTimeOffset.UtcNow.ToUnixTimeSeconds() } }

                        | AddAlertCallback callback ->
                            alertCallbacks.Add callback
                            state // State doesn't change on adding callback

                        | GetBudgetStatus replyChannel ->
                            let usagePercent =
                                if state.Budget.MonthlyLimitUSD > 0.0 then
                                    (state.Budget.CurrentMonthUsageUSD / state.Budget.MonthlyLimitUSD) * 100.0
                                else 0.0

                            let isNearLimit =
                                if state.Budget.MonthlyLimitUSD <= 0.0 then false
                                else usagePercent >= state.Budget.AlertThresholdPercent

                            let isOverLimit = state.Budget.CurrentMonthUsageUSD >= state.Budget.MonthlyLimitUSD

                            let status = dict [
                                "monthly_limit_usd", Some (box state.Budget.MonthlyLimitUSD)
                                "current_month_usage_usd", Some (box state.Budget.CurrentMonthUsageUSD)
                                "usage_percent", Some (box usagePercent)
                                "alert_threshold_percent", Some (box state.Budget.AlertThresholdPercent)
                                "is_near_limit", Some (box isNearLimit)
                                "is_over_limit", Some (box isOverLimit)
                                "remaining_budget_usd", Some (box (max 0.0 (state.Budget.MonthlyLimitUSD - state.Budget.CurrentMonthUsageUSD)))
                            ]
                            replyChannel.Reply(status)
                            state // State doesn't change on query

                        | GetCostReport (days, groupByImplementation, replyChannel) ->
                            let cutoffTime = DateTimeOffset.UtcNow.AddDays(float -days).ToUnixTimeSeconds()

                            let recentEntries =
                                state.CostEntries
                                |> List.filter (fun e -> e.Timestamp >= int64 cutoffTime)

                            let totalCost = recentEntries |> List.sumBy (fun e -> e.CostUSD)
                            let totalChars = recentEntries |> List.sumBy (fun e -> e.Characters)

                            let report = dict [
                                "period_days", Some (box days)
                                "total_cost_usd", Some (box totalCost)
                                "total_characters", Some (box totalChars)
                                "average_cost_per_char", Some (box (if totalChars > 0 then totalCost / float totalChars else 0.0))
                                "entry_count", Some (box recentEntries.Length)
                                "cost_per_million_chars", Some (box costPerMillionChars)
                            ]

                            if groupByImplementation then
                                let grouped = recentEntries |> List.groupBy (fun e -> e.Implementation)
                                let implStats =
                                    grouped
                                    |> List.map (fun (impl, entries) ->
                                        impl, dict [
                                            "total_cost_usd", Some (box (entries |> List.sumBy (fun e -> e.CostUSD)))
                                            "total_characters", Some (box (entries |> List.sumBy (fun e -> e.Characters)))
                                            "entry_count", Some (box entries.Length)
                                        ])
                                    |> dict

                                report.Add("by_implementation", Some (implStats :> obj))

                            replyChannel.Reply(report)
                            state // State doesn't change on query

                        | GetRecentEntries (limit, replyChannel) ->
                            let recent =
                                state.CostEntries
                                |> List.sortByDescending (fun e -> e.Timestamp)
                                |> List.take (min limit state.CostEntries.Length)
                            replyChannel.Reply recent
                            state // State doesn't change on query

                        | ClearOldEntries (daysToKeep, replyChannel) ->
                            let cutoffTime = DateTimeOffset.UtcNow.AddDays(float -daysToKeep).ToUnixTimeSeconds()
                            let originalCount = state.CostEntries.Length
                            let filteredEntries = state.CostEntries |> List.filter (fun e -> e.Timestamp >= cutoffTime)
                            let removedCount = originalCount - filteredEntries.Length

                            if removedCount > 0 then
                                Logger.info (sprintf "Cleared %d old cost entries (kept last %d days)" removedCount daysToKeep)
                                replyChannel.Reply removedCount
                                { state with CostEntries = filteredEntries } // Return new state with filtered entries
                            else
                                replyChannel.Reply 0
                                state // No change if nothing removed

                        | GetState replyChannel ->
                            replyChannel.Reply state
                            state // State doesn't change on query
                    // Check budget alerts after state update (if it was a tracking message)
                    if (match msg with | TrackTranslation _ -> true | _ -> false) then
                        let isOverLimit = newState.Budget.CurrentMonthUsageUSD >= newState.Budget.MonthlyLimitUSD
                        let usagePercent =
                            if newState.Budget.MonthlyLimitUSD > 0.0 then
                                (newState.Budget.CurrentMonthUsageUSD / newState.Budget.MonthlyLimitUSD) * 100.0
                            else 0.0
                        let isNearLimit = usagePercent >= newState.Budget.AlertThresholdPercent

                        if isOverLimit then
                            Logger.info (sprintf "Cost Alert [BUDGET_EXCEEDED]: Monthly budget exceeded! Current usage: $%.2f, Limit: $%.2f" newState.Budget.CurrentMonthUsageUSD newState.Budget.MonthlyLimitUSD)
                            for callback in alertCallbacks do
                                try
                                    callback.Invoke("BUDGET_EXCEEDED", newState.Budget.CurrentMonthUsageUSD)
                                with ex ->
                                    Logger.error (sprintf "Alert callback failed: %s" ex.Message)
                        elif isNearLimit then
                            Logger.info (sprintf "Cost Alert [BUDGET_WARNING]: Approaching budget limit: %.1f%% used ($%.2f of $%.2f)" usagePercent newState.Budget.CurrentMonthUsageUSD newState.Budget.MonthlyLimitUSD)
                            for callback in alertCallbacks do
                                try
                                    callback.Invoke("BUDGET_WARNING", newState.Budget.CurrentMonthUsageUSD)
                                with ex ->
                                    Logger.error (sprintf "Alert callback failed: %s" ex.Message)
                    // Save data after any state-modifying operation
                    if (match msg with | TrackTranslation _ | SetBudget _ | ResetBudget | ClearOldEntries _ -> true | _ -> false) then
                        inbox.Post SaveData // Post a message to save data asynchronously

                    return! loop newState
                }

            // Initial state for the mailbox
            loop { CostEntries = []; Budget = { MonthlyLimitUSD = 50.0; CurrentMonthUsageUSD = 0.0; AlertThresholdPercent = 80.0; LastResetTimestamp = 0L } }
        )


        /// <summary>
        /// Initializes the CostTracker by loading data from storage.
        /// </summary>
        member this.Initialize() =
            costTrackerMailbox.Post LoadData

        /// <summary>
        /// Tracks a translation event, updating character count and cost.
        /// </summary>
        /// <param name="characters">The number of characters translated.</param>
        /// <param name="sourceLang">The source language code.</param>
        /// <param name="targetLang">The target language code.</param>
        /// <param name="implementation">The translation service implementation used (e.g., "fsharp").</param>
        /// <param name="apiVersion">The API version used (e.g., "v2").</param>
        member this.TrackTranslation(characters: int, sourceLang: string, targetLang: string, implementation: string, apiVersion: string) =
            costTrackerMailbox.Post (TrackTranslation (characters, sourceLang, targetLang, implementation, apiVersion))

        /// <summary>
        /// Sets the monthly budget limit and alert threshold.
        /// </summary>
        /// <param name="monthlyLimitUSD">The new monthly budget limit in USD.</param>
        /// <param name="alertThresholdPercent">The percentage of the budget at which to trigger an alert.</param>
        member this.SetBudget(monthlyLimitUSD: float, alertThresholdPercent: float) =
            costTrackerMailbox.Post (SetBudget (monthlyLimitUSD, alertThresholdPercent))

        /// <summary>
        /// Gets the current budget status, including usage, limits, and alert indicators.
        /// </summary>
        /// <returns>A dictionary containing budget status details.</returns>
        member this.GetBudgetStatus() : Async<IDictionary<string, obj option>> =
            costTrackerMailbox.PostAndAsyncReply(fun reply -> GetBudgetStatus reply)

        /// <summary>
        /// Generates a cost report for a specified number of days, with an option to group by implementation.
        /// </summary>
        /// <param name="days">The number of past days to include in the report.</param>
        /// <param name="groupByImplementation">True to group costs by translation implementation, false otherwise.</param>
        /// <returns>A dictionary containing the cost report details.</returns>
        member this.GetCostReport(days: int, groupByImplementation: bool) : Async<IDictionary<string, obj option>> =
            costTrackerMailbox.PostAndAsyncReply(fun reply -> GetCostReport (days, groupByImplementation, reply))

        /// <summary>
        /// Gets a list of recent cost entries, up to a specified limit.
        /// </summary>
        /// <param name="limit">The maximum number of recent entries to retrieve.</param>
        /// <returns>A list of recent <see cref="CostEntry"/> records.</returns>
        member this.GetRecentEntries(limit: int) : Async<CostEntry list> =
            costTrackerMailbox.PostAndAsyncReply(fun reply -> GetRecentEntries (limit, reply))

        /// <summary>
        /// Clears old cost entries, keeping only those from the last specified number of days.
        /// </summary>
        /// <param name="daysToKeep">The number of days for which to keep entries.</param>
        /// <returns>The number of entries removed.</returns>
        member this.ClearOldEntries(daysToKeep: int) : Async<int> =
            costTrackerMailbox.PostAndAsyncReply(fun reply -> ClearOldEntries (daysToKeep, reply))

        /// <summary>
        /// Resets the monthly budget usage to zero and updates the last reset timestamp.
        /// </summary>
        member this.ResetBudget() =
            costTrackerMailbox.Post ResetBudget

        /// <summary>
        /// Adds a callback function to be invoked when budget alerts are triggered.
        /// </summary>
        /// <param name="callback">The action to invoke, receiving the alert type and current usage.</param>
        member this.AddAlertCallback(callback: Action<string, float>) =
            costTrackerMailbox.Post (AddAlertCallback callback)


    /// <summary>
    /// Global CostTracker instance.
    /// This instance is initialized once and can be accessed throughout the application.
    /// </summary>
    let private globalCostTracker = CostTracker(Path.Combine(AppContext.BaseDirectory, "translation_costs.json"))

    /// <summary>
    /// Initializes the global cost tracker instance. This should be called once at application startup.
    /// </summary>
    let initializeGlobalCostTracker () =
        globalCostTracker.Initialize()

    /// <summary>
    /// Provides access to the global <see cref="CostTracker"/> instance.
    /// </summary>
    /// <returns>The singleton <see cref="CostTracker"/> instance.</returns>
    let getGlobalCostTracker () = globalCostTracker

    /// <summary>
    /// Convenience function to track translation cost using the global CostTracker instance.
    /// </summary>
    /// <param name="characters">The number of characters translated.</param>
    /// <param name="sourceLang">The source language code.</param>
    /// <param name="targetLang">The target language code.</param>
    /// <param name="implementation">The translation service implementation used (e.g., "fsharp").</param>
    /// <param name="apiVersion">The API version used (e.g., "v2").</param>
    let trackTranslationCost characters sourceLang targetLang implementation apiVersion =
        globalCostTracker.TrackTranslation(characters, sourceLang, targetLang, implementation, apiVersion)