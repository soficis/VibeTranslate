using System;
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using FuzzySharp;

namespace TranslationFiestaCSharp
{
    public class TranslationClient
    {
        private readonly HttpClient _http;
        private readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        public string? OfficialApiKey { get; set; }
        public int MaxRetries { get; set; } = 4;
        public TimeSpan BaseRetryDelay { get; set; } = TimeSpan.FromMilliseconds(300);

        private readonly TranslationMemory _tm = new TranslationMemory();

        public TranslationClient(HttpClient? http = null)
        {
            _http = http ?? new HttpClient();
        }

        public async Task<string> TranslateAsync(string text, string source, string target, CancellationToken cancellationToken = default)
        {
            Logger.Debug($"TranslateAsync called with source='{source}', target='{target}', text length={text.Length}");
            if (string.IsNullOrWhiteSpace(text))
            {
                Logger.Warn("TranslateAsync called with empty or whitespace text.");
                return string.Empty;
            }

            // Check cache
            var cacheResult = _tm.Lookup(text, target);
            if (cacheResult != null)
            {
                Logger.Info($"Cache hit for {text.Substring(0, Math.Min(50, text.Length))}...");
                return cacheResult;
            }

            // Check fuzzy cache
            var fuzzyResult = _tm.FuzzyLookup(text, target);
            if (fuzzyResult.HasValue && fuzzyResult.Value.Translation != null)
            {
                var (translation, score) = fuzzyResult.Value;
                Logger.Info($"Fuzzy cache hit (score: {score:F2}) for {text.Substring(0, Math.Min(50, text.Length))}...");
                return translation;
            }

            string translatedText;
            if (!string.IsNullOrWhiteSpace(OfficialApiKey))
            {
                Logger.Debug("Using official API for translation.");
                translatedText = await TranslateWithOfficialApiAsync(text, source, target, cancellationToken).ConfigureAwait(false);
            }
            else
            {
                Logger.Debug("Using unofficial API for translation.");
                translatedText = await TranslateWithUnofficialApiAsync(text, source, target, cancellationToken).ConfigureAwait(false);
            }

            // Store in cache
            _tm.Store(text, target, translatedText);

            return translatedText;
        }

        public TMetrics GetTMStats()
        {
            return _tm.GetStats();
        }

        public void ClearTMCache()
        {
            _tm.ClearCache();
        }

        private async Task<string> TranslateWithUnofficialApiAsync(string text, string source, string target, CancellationToken cancellationToken)
        {
            var stopwatch = Stopwatch.StartNew();
            Logger.Debug($"Starting unofficial API translation for text length {text.Length}");
            var query = Uri.EscapeDataString(text);
            var url = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source}&tl={target}&dt=t&q={query}";

            int attempt = 0;
            while (true)
            {
                attempt++;
                try
                {
                    using var response = await _http.GetAsync(url, cancellationToken).ConfigureAwait(false);
                    response.EnsureSuccessStatusCode();
                    var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                    var translatedText = ParseUnofficialResponse(body);
                    stopwatch.Stop();
                    Logger.Performance($"Unofficial API translation successful after {attempt} attempts", stopwatch.Elapsed);
                    return translatedText;
                }
                catch (Exception ex) when (attempt <= MaxRetries && IsTransient(ex))
                {
                    var delay = ComputeBackoffDelay(attempt);
                    Logger.Error($"Unofficial API attempt {attempt} failed. Retrying in {delay.TotalMilliseconds:F2} ms.", ex);
                    await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    stopwatch.Stop();
                    Logger.Error($"Unofficial API translation failed after {attempt} attempts", ex);
                    throw;
                }
            }
        }

        private async Task<string> TranslateWithOfficialApiAsync(string text, string source, string target, CancellationToken cancellationToken)
        {
            var stopwatch = Stopwatch.StartNew();
            Logger.Debug($"Starting official API translation for text length {text.Length}");
            // Google Cloud Translation v2: https://translation.googleapis.com/language/translate/v2
            // Body: { q: string, source: string, target: string, format?: "text" }
            var url = $"https://translation.googleapis.com/language/translate/v2?key={OfficialApiKey}";

            var payload = new
            {
                q = text,
                source = source,
                target = target,
                format = "text"
            };

            int attempt = 0;
            while (true)
            {
                attempt++;
                try
                {
                    using var response = await _http.PostAsJsonAsync(url, payload, _jsonOptions, cancellationToken).ConfigureAwait(false);
                    response.EnsureSuccessStatusCode();
                    using var stream = await response.Content.ReadAsStreamAsync(cancellationToken).ConfigureAwait(false);
                    using var doc = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken).ConfigureAwait(false);
                    var translatedText = ParseOfficialResponse(doc);
                    stopwatch.Stop();
                    Logger.Performance($"Official API translation successful after {attempt} attempts", stopwatch.Elapsed);

                    // Track cost for successful official API translation
                    try
                    {
                        CostTracker.TrackTranslationCost(
                            translatedText.Length,
                            source,
                            target,
                            "csharp",
                            "v2"
                        );
                    }
                    catch (Exception ex)
                    {
                        Logger.Warn($"Failed to track translation cost: {ex.Message}");
                    }

                    return translatedText;
                }
                catch (Exception ex) when (attempt <= MaxRetries && IsTransient(ex))
                {
                    var delay = ComputeBackoffDelay(attempt);
                    Logger.Error($"Official API attempt {attempt} failed. Retrying in {delay.TotalMilliseconds:F2} ms.", ex);
                    await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
                }
                catch (Exception ex)
                {
                    stopwatch.Stop();
                    Logger.Error($"Official API translation failed after {attempt} attempts", ex);
                    throw;
                }
            }
        }

        private static string ParseUnofficialResponse(string body)
        {
            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Array) return string.Empty;
            if (!root[0].ValueKind.Equals(JsonValueKind.Array)) return string.Empty;

            var builder = new StringBuilder();
            foreach (var sentence in root[0].EnumerateArray())
            {
                if (sentence.ValueKind == JsonValueKind.Array && sentence.GetArrayLength() > 0)
                {
                    var part = sentence[0].GetString();
                    if (!string.IsNullOrEmpty(part)) builder.Append(part);
                }
            }
            return builder.ToString();
        }

        private static string ParseOfficialResponse(JsonDocument doc)
        {
            // Expected shape: { data: { translations: [ { translatedText: "..." }, ... ] } }
            if (!doc.RootElement.TryGetProperty("data", out var data)) return string.Empty;
            if (!data.TryGetProperty("translations", out var translations)) return string.Empty;
            if (translations.ValueKind != JsonValueKind.Array) return string.Empty;

            var builder = new StringBuilder();
            foreach (var tr in translations.EnumerateArray())
            {
                if (tr.TryGetProperty("translatedText", out var textProp))
                {
                    var part = textProp.GetString();
                    if (!string.IsNullOrEmpty(part)) builder.Append(part);
                }
            }
            return builder.ToString();
        }

        private static bool IsTransient(Exception ex)
        {
            return ex is HttpRequestException || ex is TaskCanceledException || ex is OperationCanceledException;
        }

        private TimeSpan ComputeBackoffDelay(int attempt)
        {
            var jitter = TimeSpan.FromMilliseconds(Random.Shared.Next(50, 150));
            var exp = Math.Pow(2, Math.Clamp(attempt - 1, 0, 10));
            var delay = TimeSpan.FromMilliseconds(BaseRetryDelay.TotalMilliseconds * exp) + jitter;
            return delay;
        }

        public class TranslationEntry
        {
            public string Source { get; set; } = string.Empty;
            public string Translation { get; set; } = string.Empty;
            public string TargetLang { get; set; } = string.Empty;
            public DateTime AccessTime { get; set; }
        }

        public class TMetrics
        {
            public int Hits { get; set; }
            public int Misses { get; set; }
            public int FuzzyHits { get; set; }
            public int TotalLookups { get; set; }
            public double TotalTime { get; set; } = 0;
            public double HitRate => TotalLookups > 0 ? (double)(Hits + FuzzyHits) / TotalLookups : 0;
            public double AvgLookupTime => TotalLookups > 0 ? TotalTime / TotalLookups : 0;
        }

        public class TranslationMemory
        {
            private readonly OrderedDictionary cache = new OrderedDictionary();
            private int cacheSize;
            private readonly string persistencePath;
            private double similarityThreshold;
            private readonly JsonSerializerOptions _jsonOptions;
            public TMetrics Metrics { get; } = new TMetrics();

            public TranslationMemory(int cacheSize = 1000, string persistencePath = "tm_cache.json", double similarityThreshold = 0.8)
            {
                this.cacheSize = cacheSize;
                this.persistencePath = persistencePath;
                this.similarityThreshold = similarityThreshold;
                _jsonOptions = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };
                LoadCache();
            }

            private string GetKey(string source, string targetLang) => $"{source}:{targetLang}";

            public string? Lookup(string source, string targetLang)
            {
                var stopwatch = Stopwatch.StartNew();
                var key = GetKey(source, targetLang);
                if (cache.Contains(key))
                {
                    Metrics.Hits++;
                    stopwatch.Stop();
                    Metrics.TotalTime += stopwatch.Elapsed.TotalMilliseconds;
                    Metrics.TotalLookups++;
                    return ((TranslationEntry)cache[key]!).Translation;
                }
                Metrics.Misses++;
                stopwatch.Stop();
                Metrics.TotalTime += stopwatch.Elapsed.TotalMilliseconds;
                Metrics.TotalLookups++;
                return null;
            }

            public (string? Translation, double Score)? FuzzyLookup(string source, string targetLang)
            {
                var stopwatch = Stopwatch.StartNew();
                double bestScore = 0;
                string? bestTranslation = null;
                foreach (DictionaryEntry entry in cache)
                {
                    if (entry.Value is TranslationEntry e && e.TargetLang == targetLang)
                    {
                        var score = Fuzz.Ratio(source, e.Source) / 100.0;
                        if (score > bestScore && score >= similarityThreshold)
                        {
                            bestScore = score;
                            bestTranslation = e.Translation;
                        }
                    }
                }
                if (bestTranslation != null)
                {
                    Metrics.FuzzyHits++;
                    stopwatch.Stop();
                    Metrics.TotalTime += stopwatch.Elapsed.TotalMilliseconds;
                    Metrics.TotalLookups++;
                    return (bestTranslation, bestScore);
                }
                Metrics.Misses++;
                stopwatch.Stop();
                Metrics.TotalTime += stopwatch.Elapsed.TotalMilliseconds;
                Metrics.TotalLookups++;
                return null;
            }

            public void Store(string source, string targetLang, string translation)
            {
                var key = GetKey(source, targetLang);
                var entry = new TranslationEntry
                {
                    Source = source,
                    Translation = translation,
                    TargetLang = targetLang,
                    AccessTime = DateTime.Now
                };
                cache[key] = entry;
                if (cache.Count > cacheSize)
                {
                    cache.RemoveAt(0);
                }
                Persist();
            }

            public TMetrics GetStats()
            {
                var stats = new TMetrics
                {
                    Hits = Metrics.Hits,
                    Misses = Metrics.Misses,
                    FuzzyHits = Metrics.FuzzyHits,
                    TotalLookups = Metrics.TotalLookups,
                    TotalTime = Metrics.TotalTime
                };
                return stats;
            }

            public void ClearCache()
            {
                cache.Clear();
                Metrics.Hits = 0;
                Metrics.Misses = 0;
                Metrics.FuzzyHits = 0;
                Metrics.TotalLookups = 0;
                Metrics.TotalTime = 0;
                Persist();
            }

            private void Persist()
            {
                try
                {
                    var data = new
                    {
                        config = new { max_size = cacheSize, threshold = similarityThreshold },
                        cache = cache.Values.Cast<TranslationEntry>().ToArray(),
                        metrics = Metrics
                    };
                    var json = JsonSerializer.Serialize(data, _jsonOptions);
                    File.WriteAllText(persistencePath, json);
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to persist cache: {ex.Message}");
                }
            }

            private void LoadCache()
            {
                try
                {
                    if (!File.Exists(persistencePath)) return;
                    var json = File.ReadAllText(persistencePath);
                    var data = JsonSerializer.Deserialize<JsonElement>(json, _jsonOptions);
                    if (data.TryGetProperty("config", out var config))
                    {
                        if (config.TryGetProperty("max_size", out var sizeProp))
                        {
                            cacheSize = sizeProp.GetInt32();
                        }
                        if (config.TryGetProperty("threshold", out var threshProp))
                        {
                            similarityThreshold = threshProp.GetDouble();
                        }
                    }
                    if (data.TryGetProperty("cache", out var cacheProp) && cacheProp.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var entryElem in cacheProp.EnumerateArray())
                        {
                            var entry = JsonSerializer.Deserialize<TranslationEntry>(entryElem.GetRawText(), _jsonOptions);
                            if (entry != null)
                            {
                                var key = GetKey(entry.Source, entry.TargetLang);
                                cache[key] = entry;
                            }
                        }
                    }
                    if (data.TryGetProperty("metrics", out var metricsProp))
                    {
                        var metrics = JsonSerializer.Deserialize<TMetrics>(metricsProp.GetRawText(), _jsonOptions);
                        if (metrics != null)
                        {
                            Metrics.Hits = metrics.Hits;
                            Metrics.Misses = metrics.Misses;
                            Metrics.FuzzyHits = metrics.FuzzyHits;
                            Metrics.TotalLookups = metrics.TotalLookups;
                            Metrics.TotalTime = metrics.TotalTime;
                        }
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Failed to load cache: {ex.Message}");
                }
            }
        }
    }
}
