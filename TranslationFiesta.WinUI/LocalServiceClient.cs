using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;

namespace TranslationFiesta.WinUI
{
    public class LocalServiceClient
    {
        private const string DefaultBaseUrl = "http://127.0.0.1:5055";
        private const string DefaultScriptPath = "TranslationFiestaLocal/local_service.py";
        private static readonly JsonSerializerOptions JsonOptions = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        private readonly HttpClient _http;
        private readonly string _baseUrl;
        private readonly bool _autoStart;
        private bool _started;
        private readonly object _lock = new object();

        public LocalServiceClient(HttpClient http)
        {
            _http = http;
            _baseUrl = (Environment.GetEnvironmentVariable("TF_LOCAL_URL") ?? DefaultBaseUrl).Trim().TrimEnd('/');
            _autoStart = IsAutoStartEnabled(Environment.GetEnvironmentVariable("TF_LOCAL_AUTOSTART"));
        }

        public static void ApplyEnvironment(string? baseUrl, string? modelDir, bool autoStart)
        {
            if (string.IsNullOrWhiteSpace(baseUrl))
            {
                Environment.SetEnvironmentVariable("TF_LOCAL_URL", null);
            }
            else
            {
                Environment.SetEnvironmentVariable("TF_LOCAL_URL", baseUrl.Trim());
            }

            if (string.IsNullOrWhiteSpace(modelDir))
            {
                Environment.SetEnvironmentVariable("TF_LOCAL_MODEL_DIR", null);
            }
            else
            {
                Environment.SetEnvironmentVariable("TF_LOCAL_MODEL_DIR", modelDir.Trim());
            }

            Environment.SetEnvironmentVariable("TF_LOCAL_AUTOSTART", autoStart ? "1" : "0");
        }

        public async Task<string> TranslateAsync(string text, string source, string target, CancellationToken cancellationToken)
        {
            await EnsureAvailableAsync(cancellationToken).ConfigureAwait(false);

            var payload = new Dictionary<string, string>
            {
                ["text"] = text,
                ["source_lang"] = source,
                ["target_lang"] = target
            };

            using var response = await _http.PostAsJsonAsync($"{_baseUrl}/translate", payload, cancellationToken).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                ThrowLocalError(body, (int)response.StatusCode);
            }

            var parsed = JsonSerializer.Deserialize<LocalTranslateResponse>(body, JsonOptions);
            if (parsed?.Error != null)
            {
                throw new HttpRequestException($"Local service error ({parsed.Error.Code}): {parsed.Error.Message}");
            }

            var translated = parsed?.TranslatedText ?? string.Empty;
            if (string.IsNullOrWhiteSpace(translated))
            {
                throw new HttpRequestException("Local service returned empty translation.");
            }

            return translated.Trim();
        }

        public async Task<string> GetModelsStatusAsync(CancellationToken cancellationToken)
        {
            await EnsureAvailableAsync(cancellationToken).ConfigureAwait(false);
            using var response = await _http.GetAsync($"{_baseUrl}/models", cancellationToken).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                ThrowLocalError(body, (int)response.StatusCode);
            }
            return body;
        }

        public async Task<string> VerifyModelsAsync(CancellationToken cancellationToken)
        {
            await EnsureAvailableAsync(cancellationToken).ConfigureAwait(false);
            using var response = await _http.PostAsync($"{_baseUrl}/models/verify", new StringContent("{}", Encoding.UTF8, "application/json"), cancellationToken).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                ThrowLocalError(body, (int)response.StatusCode);
            }
            return body;
        }

        public async Task<string> RemoveModelsAsync(CancellationToken cancellationToken)
        {
            await EnsureAvailableAsync(cancellationToken).ConfigureAwait(false);
            using var response = await _http.PostAsync($"{_baseUrl}/models/remove", new StringContent("{}", Encoding.UTF8, "application/json"), cancellationToken).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                ThrowLocalError(body, (int)response.StatusCode);
            }
            return body;
        }

        public async Task<string> InstallDefaultModelsAsync(CancellationToken cancellationToken)
        {
            await EnsureAvailableAsync(cancellationToken).ConfigureAwait(false);
            using var response = await _http.PostAsync($"{_baseUrl}/models/install", new StringContent("{}", Encoding.UTF8, "application/json"), cancellationToken).ConfigureAwait(false);
            var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
            if (!response.IsSuccessStatusCode)
            {
                ThrowLocalError(body, (int)response.StatusCode);
            }
            return body;
        }

        private async Task EnsureAvailableAsync(CancellationToken cancellationToken)
        {
            if (await CheckHealthAsync(cancellationToken).ConfigureAwait(false))
            {
                return;
            }

            if (!_autoStart)
            {
                throw new HttpRequestException("Local service unavailable and autostart disabled.");
            }

            StartLocalService();

            for (var attempt = 0; attempt < 10; attempt++)
            {
                if (await CheckHealthAsync(cancellationToken).ConfigureAwait(false))
                {
                    return;
                }
                await Task.Delay(TimeSpan.FromMilliseconds(250), cancellationToken).ConfigureAwait(false);
            }

            throw new HttpRequestException("Local service did not become healthy.");
        }

        private async Task<bool> CheckHealthAsync(CancellationToken cancellationToken)
        {
            try
            {
                using var response = await _http.GetAsync($"{_baseUrl}/health", cancellationToken).ConfigureAwait(false);
                if (!response.IsSuccessStatusCode) return false;
                var body = await response.Content.ReadAsStringAsync(cancellationToken).ConfigureAwait(false);
                var health = JsonSerializer.Deserialize<LocalHealthResponse>(body, JsonOptions);
                return string.Equals(health?.Status, "ok", StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        private void StartLocalService()
        {
            lock (_lock)
            {
                if (_started) return;

                var scriptPath = (Environment.GetEnvironmentVariable("TF_LOCAL_SCRIPT") ?? DefaultScriptPath).Trim();
                scriptPath = Path.GetFullPath(scriptPath, Directory.GetCurrentDirectory());

                var python = Environment.GetEnvironmentVariable("PYTHON");
                if (string.IsNullOrWhiteSpace(python))
                {
                    python = "python";
                }

                try
                {
                    var startInfo = new ProcessStartInfo
                    {
                        FileName = python,
                        Arguments = $"\"{scriptPath}\" serve",
                        WorkingDirectory = Path.GetDirectoryName(scriptPath) ?? Directory.GetCurrentDirectory(),
                        CreateNoWindow = true,
                        UseShellExecute = false
                    };
                    Process.Start(startInfo);
                    _started = true;
                    Logger.Info($"Local service start requested: {scriptPath}");
                }
                catch (Exception ex)
                {
                    Logger.Error("Failed to start local service.", ex);
                    throw;
                }
            }
        }

        private static void ThrowLocalError(string body, int statusCode)
        {
            try
            {
                var payload = JsonSerializer.Deserialize<LocalErrorEnvelope>(body, JsonOptions);
                if (payload?.Error != null)
                {
                    throw new HttpRequestException($"Local service error ({payload.Error.Code}): {payload.Error.Message}");
                }
            }
            catch
            {
                // ignore parse failures
            }
            throw new HttpRequestException($"Local service HTTP {statusCode}.");
        }

        private static bool IsAutoStartEnabled(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return true;
            var normalized = value.Trim().ToLowerInvariant();
            return normalized != "0" && normalized != "false" && normalized != "no";
        }

        private sealed class LocalErrorEnvelope
        {
            [JsonPropertyName("error")]
            public LocalServiceError? Error { get; set; }
        }

        private sealed class LocalTranslateResponse
        {
            [JsonPropertyName("translated_text")]
            public string? TranslatedText { get; set; }

            [JsonPropertyName("error")]
            public LocalServiceError? Error { get; set; }
        }

        private sealed class LocalHealthResponse
        {
            [JsonPropertyName("status")]
            public string? Status { get; set; }
        }

        private sealed class LocalServiceError
        {
            [JsonPropertyName("code")]
            public string? Code { get; set; }

            [JsonPropertyName("message")]
            public string? Message { get; set; }
        }
    }
}
