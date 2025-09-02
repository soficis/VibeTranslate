using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Threading;

namespace CsharpTranslationFiesta
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

        public TranslationClient(HttpClient? http = null)
        {
            _http = http ?? new HttpClient();
        }

        public async Task<string> TranslateAsync(string text, string source, string target, CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(text)) return string.Empty;

            if (!string.IsNullOrWhiteSpace(OfficialApiKey))
            {
                return await TranslateWithOfficialApiAsync(text, source, target, cancellationToken).ConfigureAwait(false);
            }

            return await TranslateWithUnofficialApiAsync(text, source, target, cancellationToken).ConfigureAwait(false);
        }

        private async Task<string> TranslateWithUnofficialApiAsync(string text, string source, string target, CancellationToken cancellationToken)
        {
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
                    return ParseUnofficialResponse(body);
                }
                catch (Exception ex) when (attempt <= MaxRetries && IsTransient(ex))
                {
                    var delay = ComputeBackoffDelay(attempt);
                    Logger.Warn($"Unofficial API attempt {attempt} failed: {ex.Message}. Retrying in {delay.TotalMilliseconds} ms.");
                    await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
                }
            }
        }

        private async Task<string> TranslateWithOfficialApiAsync(string text, string source, string target, CancellationToken cancellationToken)
        {
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
                    return ParseOfficialResponse(doc);
                }
                catch (Exception ex) when (attempt <= MaxRetries && IsTransient(ex))
                {
                    var delay = ComputeBackoffDelay(attempt);
                    Logger.Warn($"Official API attempt {attempt} failed: {ex.Message}. Retrying in {delay.TotalMilliseconds} ms.");
                    await Task.Delay(delay, cancellationToken).ConfigureAwait(false);
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
    }
}
