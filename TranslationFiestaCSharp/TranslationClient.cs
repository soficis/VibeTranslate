using System;
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace TranslationFiestaCSharp
{
    public class TranslationClient
    {
        private readonly HttpClient _http;

        public string ProviderId { get; set; } = ProviderIds.GoogleUnofficial;
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

            var providerId = ProviderIds.Normalize(ProviderId);

            // Check cache
            var cacheResult = _tm.Lookup(text, target, providerId);
            if (cacheResult != null)
            {
                Logger.Info($"Cache hit for {text.Substring(0, Math.Min(50, text.Length))}...");
                return cacheResult;
            }

            Logger.Debug("Using unofficial API for translation.");
            var translatedText = await TranslateWithUnofficialApiAsync(text, source, target, cancellationToken).ConfigureAwait(false);

            // Store in cache
            _tm.Store(text, target, providerId, translatedText);

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
                    using var request = new HttpRequestMessage(HttpMethod.Get, url);
                    request.Headers.TryAddWithoutValidation("Accept", "application/json,text/plain,*/*");
                    var userAgent = Environment.GetEnvironmentVariable("TF_UNOFFICIAL_USER_AGENT");
                    if (!string.IsNullOrWhiteSpace(userAgent))
                    {
                        request.Headers.TryAddWithoutValidation("User-Agent", userAgent);
                    }

                    using var response = await _http.SendAsync(request, cancellationToken).ConfigureAwait(false);
                    var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);

                    if (response.StatusCode == (HttpStatusCode)429)
                    {
                        var retryAfter = response.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(2);
                        if (attempt <= MaxRetries)
                        {
                            await Task.Delay(retryAfter, cancellationToken).ConfigureAwait(false);
                            continue;
                        }
                        throw new TranslationProviderException("rate_limited", "Provider rate limited");
                    }

                    if (response.StatusCode == HttpStatusCode.Forbidden)
                    {
                        throw new TranslationProviderException("blocked", "Provider blocked or captcha detected");
                    }

                    if (!response.IsSuccessStatusCode)
                    {
                        throw new TranslationProviderException("invalid_response", $"HTTP {(int)response.StatusCode}");
                    }

                    if (string.IsNullOrWhiteSpace(body))
                    {
                        throw new TranslationProviderException("invalid_response", "Empty response body");
                    }

                    var lowered = body.ToLowerInvariant();
                    if (lowered.Contains("<html") || lowered.Contains("captcha"))
                    {
                        throw new TranslationProviderException("blocked", "Provider blocked or captcha detected");
                    }

                    var translatedText = ParseUnofficialResponse(body);
                    if (string.IsNullOrWhiteSpace(translatedText))
                    {
                        throw new TranslationProviderException("invalid_response", "No translation segments returned");
                    }
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
            public string ProviderId { get; set; } = ProviderIds.GoogleUnofficial;
            public DateTime AccessTime { get; set; }
        }

        public class TMetrics
        {
            public int Hits { get; set; }
            public int Misses { get; set; }
            public int TotalLookups { get; set; }
            public double TotalTime { get; set; } = 0;
            public double HitRate => TotalLookups > 0 ? (double)Hits / TotalLookups : 0;
            public double AvgLookupTime => TotalLookups > 0 ? TotalTime / TotalLookups : 0;
        }

        public class TranslationMemory
        {
            private readonly OrderedDictionary cache = new OrderedDictionary();
            private int cacheSize;
            private readonly string persistencePath;
            private readonly JsonSerializerOptions _jsonOptions;
            public TMetrics Metrics { get; } = new TMetrics();

            public TranslationMemory(int cacheSize = 1000, string? persistencePath = null)
            {
                this.cacheSize = cacheSize;
                this.persistencePath = persistencePath ?? PortablePaths.TranslationMemoryFile;
                _jsonOptions = new JsonSerializerOptions
                {
                    PropertyNamingPolicy = JsonNamingPolicy.CamelCase
                };
                LoadCache();
            }

            private string GetKey(string source, string targetLang, string providerId) => $"{source}:{targetLang}:{providerId}";

            public string? Lookup(string source, string targetLang, string providerId)
            {
                var stopwatch = Stopwatch.StartNew();
                providerId = ProviderIds.Normalize(providerId);
                var key = GetKey(source, targetLang, providerId);
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

            public void Store(string source, string targetLang, string providerId, string translation)
            {
                providerId = ProviderIds.Normalize(providerId);
                var key = GetKey(source, targetLang, providerId);
                var entry = new TranslationEntry
                {
                    Source = source,
                    Translation = translation,
                    TargetLang = targetLang,
                    ProviderId = providerId,
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
                        config = new { max_size = cacheSize },
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
                    }
                    if (data.TryGetProperty("cache", out var cacheProp) && cacheProp.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var entryElem in cacheProp.EnumerateArray())
                        {
                            var entry = JsonSerializer.Deserialize<TranslationEntry>(entryElem.GetRawText(), _jsonOptions);
                            if (entry != null)
                            {
                                entry.ProviderId = ProviderIds.Normalize(entry.ProviderId);
                                var key = GetKey(entry.Source, entry.TargetLang, entry.ProviderId);
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
