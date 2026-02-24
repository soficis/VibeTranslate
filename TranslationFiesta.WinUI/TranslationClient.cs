using System;
using System.Collections;
using System.Collections.Specialized;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using FuzzySharp;

namespace TranslationFiesta.WinUI
{
    /// <summary>
    /// Translation client supporting local and unofficial Google Translate providers.
    /// </summary>
    public class TranslationClient
    {
        private static readonly HttpClient _httpClient = new HttpClient();
        private static readonly JsonSerializerOptions _jsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true,
            WriteIndented = true
        };
        private LocalServiceClient _localClient;

        public string ProviderId { get; set; } = ProviderIds.GoogleUnofficial;

        public TranslationClient()
        {
            _localClient = new LocalServiceClient(_httpClient);
        }

        public void ApplyLocalSettings(string? baseUrl, string? modelDir, bool autoStart)
        {
            LocalServiceClient.ApplyEnvironment(baseUrl, modelDir, autoStart);
            _localClient = new LocalServiceClient(_httpClient);
        }

        static TranslationClient()
        {
            // Configure HttpClient with automatic decompression
            var handler = new HttpClientHandler
            {
                AutomaticDecompression = System.Net.DecompressionMethods.GZip | System.Net.DecompressionMethods.Deflate | System.Net.DecompressionMethods.Brotli
            };
            _httpClient = new HttpClient(handler);

            var userAgent = Environment.GetEnvironmentVariable("TF_UNOFFICIAL_USER_AGENT");
            var defaultUserAgent = string.IsNullOrWhiteSpace(userAgent)
                ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
                : userAgent;
            _httpClient.DefaultRequestHeaders.Add("User-Agent", defaultUserAgent);
            _httpClient.DefaultRequestHeaders.Add("Accept", "application/json,text/plain,*/*");
            _httpClient.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.9");
            _httpClient.DefaultRequestHeaders.Add("Accept-Encoding", "gzip, deflate, br");
            _httpClient.DefaultRequestHeaders.Add("DNT", "1");
            _httpClient.DefaultRequestHeaders.Add("Connection", "keep-alive");
            _httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Dest", "empty");
            _httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Mode", "cors");
            _httpClient.DefaultRequestHeaders.Add("Sec-Fetch-Site", "cross-site");
            _httpClient.Timeout = TimeSpan.FromSeconds(30);
        }

        /// <summary>
        /// Translates text using either local or unofficial Google Translate API.
        /// </summary>
        private readonly TranslationMemory _tm = new TranslationMemory();

        public async Task<string> TranslateAsync(string text, string fromLang, string toLang, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(text))
                throw new ArgumentException("Text cannot be null or empty", nameof(text));

            var providerId = ProviderIds.Normalize(ProviderId);

            // Check cache
            var cacheResult = _tm.Lookup(text, toLang, providerId);
            if (cacheResult != null)
            {
                Logger.Info($"Cache hit for {text.Substring(0, Math.Min(50, text.Length))}...");
                return cacheResult;
            }

            // Check fuzzy cache
            var fuzzyResult = _tm.FuzzyLookup(text, toLang, providerId);
            if (fuzzyResult != null && !string.IsNullOrEmpty(fuzzyResult.Item1))
            {
                Logger.Info($"Fuzzy cache hit (score: {fuzzyResult.Item2:F2}) for {text.Substring(0, Math.Min(50, text.Length))}...");
                return fuzzyResult.Item1;
            }

            string translatedText;
            switch (providerId)
            {
                case ProviderIds.Local:
                    translatedText = await TranslateLocalAsync(text, fromLang, toLang, cancellationToken);
                    break;
                default:
                    translatedText = await TranslateUnofficialAsync(text, fromLang, toLang, cancellationToken);
                    break;
            }

            // Store in cache
            _tm.Store(text, toLang, providerId, translatedText);

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

        /// <summary>
        /// Uses unofficial Google Translate (free, no API key required)
        /// </summary>
        private async Task<string> TranslateUnofficialAsync(string text, string fromLang, string toLang, CancellationToken cancellationToken)
        {
            try
            {
                Logger.Info($"Using unofficial Google Translate: {fromLang} -> {toLang}");

                // Split long text into smaller chunks to avoid API limits
                const int maxChunkLength = 5000;
                if (text.Length > maxChunkLength)
                {
                    var chunks = SplitTextIntoChunks(text, maxChunkLength);
                    var translatedChunks = new List<string>();

                    foreach (var chunk in chunks)
                    {
                        var translatedChunk = await TranslateChunkAsync(chunk, fromLang, toLang, cancellationToken);
                        translatedChunks.Add(translatedChunk);
                        await Task.Delay(100, cancellationToken); // Rate limiting
                    }

                    return string.Join(" ", translatedChunks);
                }
                else
                {
                    return await TranslateChunkAsync(text, fromLang, toLang, cancellationToken);
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Unofficial API translation failed: {ex.Message}");
                throw new Exception($"Unofficial Google Translate failed: {ex.Message}", ex);
            }
        }

        private async Task<string> TranslateLocalAsync(string text, string fromLang, string toLang, CancellationToken cancellationToken)
        {
            return await _localClient.TranslateAsync(text, fromLang, toLang, cancellationToken);
        }

        private async Task<string> TranslateChunkAsync(string text, string fromLang, string toLang, CancellationToken cancellationToken)
        {
            const int maxRetries = 3;
            for (int attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    // Encode the text for URL
                    var encodedText = HttpUtility.UrlEncode(text);

                    // Use a simpler, more reliable Google Translate API endpoint
                    var url = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={fromLang}&tl={toLang}&dt=t&q={encodedText}";

                    Logger.Debug($"Unofficial API request URL: {url}");

                    var response = await _httpClient.GetAsync(url, cancellationToken);
                    if (response.StatusCode == System.Net.HttpStatusCode.TooManyRequests)
                    {
                        var retryDelay = response.Headers.RetryAfter?.Delta ?? TimeSpan.FromSeconds(Math.Pow(2, attempt));
                        if (attempt < maxRetries)
                        {
                            await Task.Delay(retryDelay, cancellationToken);
                            continue;
                        }
                        throw new TranslationProviderException("rate_limited", "Provider rate limited");
                    }
                    if (response.StatusCode == System.Net.HttpStatusCode.Forbidden)
                    {
                        throw new TranslationProviderException("blocked", "Provider blocked or captcha detected");
                    }
                    if (!response.IsSuccessStatusCode)
                    {
                        throw new TranslationProviderException("invalid_response", $"HTTP {(int)response.StatusCode}");
                    }

                    // Read response as bytes to handle encoding properly
                    var responseBytes = await response.Content.ReadAsByteArrayAsync(cancellationToken);

                    // Clean the byte array first
                    responseBytes = CleanByteResponse(responseBytes);

                    // Convert to string
                    string responseJson = System.Text.Encoding.UTF8.GetString(responseBytes);
                    Logger.Debug($"Unofficial API response length: {responseJson.Length}");

                    // Additional string cleaning
                    responseJson = CleanJsonResponseString(responseJson);
                    
                    if (string.IsNullOrWhiteSpace(responseJson))
                        throw new TranslationProviderException("invalid_response", "Empty response from unofficial API");

                    var lowered = responseJson.ToLowerInvariant();
                    if (lowered.Contains("<html") || lowered.Contains("captcha"))
                        throw new TranslationProviderException("blocked", "Provider blocked or captcha detected");

                    // Parse the unofficial API response
                    using var doc = JsonDocument.Parse(responseJson);
                    var rootArray = doc.RootElement;

                    if (rootArray.ValueKind != JsonValueKind.Array || rootArray.GetArrayLength() == 0)
                        throw new Exception("Invalid response format from unofficial API");

                    var resultArray = rootArray[0];
                    if (resultArray.ValueKind != JsonValueKind.Array || resultArray.GetArrayLength() == 0)
                        throw new Exception("No translation results in response");

                    var translatedText = new StringBuilder();

                    for (int i = 0; i < resultArray.GetArrayLength(); i++)
                    {
                        if (resultArray[i].ValueKind == JsonValueKind.Array && 
                            resultArray[i].GetArrayLength() > 0 && 
                            resultArray[i][0].ValueKind == JsonValueKind.String)
                        {
                            var translation = resultArray[i][0].GetString();
                            if (!string.IsNullOrEmpty(translation))
                            {
                                translatedText.Append(translation);
                            }
                        }
                    }

                    var finalResult = translatedText.ToString().Trim();
                    if (string.IsNullOrEmpty(finalResult))
                        throw new TranslationProviderException("invalid_response", "Empty translation result from unofficial API");

                    Logger.Info($"Unofficial API translation successful: {text.Length} -> {finalResult.Length} chars (attempt {attempt})");
                    return finalResult;
                }
                catch (HttpRequestException ex) when (attempt < maxRetries)
                {
                    Logger.Warning($"Unofficial API attempt {attempt} failed: {ex.Message}. Retrying...");
                    await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt)), cancellationToken);
                }
                catch (JsonException ex)
                {
                    Logger.Error($"Failed to parse response JSON: {ex.Message}");
                    if (attempt == maxRetries)
                        throw new Exception($"Failed to parse translation response: {ex.Message}", ex);
                    await Task.Delay(TimeSpan.FromSeconds(Math.Pow(2, attempt)), cancellationToken);
                }
                catch (Exception ex) when (attempt == maxRetries)
                {
                    Logger.Error($"All {maxRetries} attempts failed. Last error: {ex.Message}");
                    throw;
                }
            }

            throw new Exception("Translation failed after all retry attempts");
        }

        private byte[] CleanByteResponse(byte[] responseBytes)
        {
            if (responseBytes == null || responseBytes.Length == 0)
                return Array.Empty<byte>();

            // Handle UTF-8 BOM (EF BB BF)
            if (responseBytes.Length >= 3 &&
                responseBytes[0] == 0xEF &&
                responseBytes[1] == 0xBB &&
                responseBytes[2] == 0xBF)
            {
                Logger.Info("Detected and removing UTF-8 BOM from byte response");
                return responseBytes.Skip(3).ToArray();
            }

            // Handle other invalid leading bytes
            int startIndex = 0;
            while (startIndex < responseBytes.Length && responseBytes[startIndex] < 32 &&
                   responseBytes[startIndex] != '\n' && responseBytes[startIndex] != '\r' && responseBytes[startIndex] != '\t')
            {
                startIndex++;
            }

            if (startIndex > 0 && startIndex < responseBytes.Length)
            {
                Logger.Info($"Cleaned byte response by removing {startIndex} invalid bytes");
                return responseBytes.Skip(startIndex).ToArray();
            }

            return responseBytes.Length > 0 ? responseBytes : Array.Empty<byte>();
        }

        private string CleanJsonResponseString(string response)
        {
            if (string.IsNullOrEmpty(response))
                return response;

            // Remove any leading/trailing whitespace
            response = response.Trim();

            // Ensure response starts with '[' for JSON array
            if (!response.StartsWith("["))
            {
                Logger.Warning("Response doesn't start with '[', attempting to fix...");
                response = "[" + response;
            }

            // Remove any trailing invalid characters after the closing bracket
            int lastBracketIndex = response.LastIndexOf(']');
            if (lastBracketIndex >= 0)
            {
                response = response.Substring(0, lastBracketIndex + 1);
            }

            return response;
        }

        private List<string> SplitTextIntoChunks(string text, int maxLength)
        {
            var chunks = new List<string>();
            var words = text.Split(new[] { ' ', '\n', '\r', '\t' }, StringSplitOptions.RemoveEmptyEntries);

            var currentChunk = new StringBuilder();
            foreach (var word in words)
            {
                if (currentChunk.Length + word.Length + 1 > maxLength)
                {
                    if (currentChunk.Length > 0)
                    {
                        chunks.Add(currentChunk.ToString().Trim());
                        currentChunk.Clear();
                    }
                }

                if (currentChunk.Length > 0)
                    currentChunk.Append(" ");
                currentChunk.Append(word);
            }

            if (currentChunk.Length > 0)
                chunks.Add(currentChunk.ToString().Trim());

            return chunks;
        }

        /// <summary>
        /// Performs backtranslation with quality assessment
        /// </summary>
        public async Task<BackTranslationResult> BackTranslateAsync(string text, string? sourceLang = null, string? targetLang = null, CancellationToken cancellationToken = default)
        {
            try
            {
                Logger.Info("Starting backtranslation process");

                // Step 1: Source to Target language
                var sourceLangCode = sourceLang ?? "en";
                var targetLangCode = targetLang ?? "ja";
                var intermediate = await TranslateAsync(text, sourceLangCode, targetLangCode, cancellationToken);
                Logger.Info($"{sourceLangCode} -> {targetLangCode}: {text.Length} -> {intermediate.Length} chars");

                // Step 2: Target language back to Source
                var backToSource = await TranslateAsync(intermediate, targetLangCode, sourceLangCode, cancellationToken);
                Logger.Info($"{targetLangCode} -> {sourceLangCode}: {intermediate.Length} -> {backToSource.Length} chars");

                // Calculate BLEU score for quality assessment
                var bleuScorer = new BLEUScorer();
                var qualityAssessment = bleuScorer.AssessTranslationQuality(text, backToSource);

                return new BackTranslationResult
                {
                    OriginalText = text,
                    IntermediateTranslation = intermediate,
                    BackTranslation = backToSource,
                    QualityAssessment = qualityAssessment
                };
            }
            catch (Exception ex)
            {
                Logger.Error($"Backtranslation failed: {ex.Message}");
                throw new Exception($"Backtranslation failed: {ex.Message}", ex);
            }
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
            public TMetrics Metrics { get; } = new TMetrics();

            public TranslationMemory(int cacheSize = 1000, string persistencePath = "tm_cache.json", double similarityThreshold = 0.8)
            {
                this.cacheSize = cacheSize;
                this.persistencePath = persistencePath;
                this.similarityThreshold = similarityThreshold;
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
                    // Note: LRU functionality simplified - MoveToEnd not available in OrderedDictionary
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

            public Tuple<string, double>? FuzzyLookup(string source, string targetLang, string providerId)
            {
                var stopwatch = Stopwatch.StartNew();
                providerId = ProviderIds.Normalize(providerId);
                double bestScore = 0;
                string? bestTranslation = null;
                foreach (DictionaryEntry entry in cache)
                {
                    if (entry.Value is TranslationEntry e && e.TargetLang == targetLang && e.ProviderId == providerId)
                    {
                        var score = Fuzz.Ratio(source, e.Source) / 100.0;
                        if (score > bestScore && score >= similarityThreshold)
                        {
                            bestScore = score;
                            bestTranslation = e.Translation;
                        }
                    }
                }
                if (!string.IsNullOrEmpty(bestTranslation))
                {
                    Metrics.FuzzyHits++;
                    stopwatch.Stop();
                    Metrics.TotalTime += stopwatch.Elapsed.TotalMilliseconds;
                    Metrics.TotalLookups++;
                    return Tuple.Create(bestTranslation!, bestScore);
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
                // Note: LRU functionality simplified - MoveToEnd/GetKey not available in OrderedDictionary
                if (cache.Count > cacheSize)
                {
                    // Remove oldest entry (first in ordered dictionary)
                    var firstKey = cache.Cast<DictionaryEntry>().First().Key;
                    cache.Remove(firstKey);
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

    /// <summary>
    /// Result of a backtranslation operation
    /// </summary>
    public class BackTranslationResult
    {
        public string? OriginalText { get; set; }
        public string? IntermediateTranslation { get; set; }
        public string? BackTranslation { get; set; }
        public TranslationQualityAssessment? QualityAssessment { get; set; }

        public override string ToString()
        {
            var result = $"Original: {OriginalText}\nIntermediate: {IntermediateTranslation}\nBack: {BackTranslation}";
            if (QualityAssessment != null)
            {
                result += $"\nBLEU Score: {QualityAssessment.BleuPercentage} ({QualityAssessment.ConfidenceLevel})";
            }
            return result;
        }
    }
}
