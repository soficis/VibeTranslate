using System;
using System.Collections.Generic;
using System.IO;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace TranslationFiesta.WinUI
{
    public class BatchProcessor
    {
        private readonly TranslationClient _translationClient;
        private readonly Action<int, int> _updateCallback;
        private bool _isRunning;
        private readonly List<TranslationResult> _batchResults = new();

        public BatchProcessor(TranslationClient translationClient, Action<int, int> updateCallback)
        {
            _translationClient = translationClient;
            _updateCallback = updateCallback;
        }

        public async Task ProcessDirectoryAsync(StorageFolder folder)
        {
            if (folder == null) return;

            _isRunning = true;
            _batchResults.Clear();
            var files = await folder.GetFilesAsync();
            int totalFiles = files.Count;

            for (int i = 0; i < totalFiles; i++)
            {
                if (!_isRunning) break;

                var file = files[i];
                string content = await FileIO.ReadTextAsync(file);
                var result = await _translationClient.BackTranslateAsync(content);

                // Create translation result for batch export
                double bleuScore = 0.0;
                if (result.QualityAssessment != null && !string.IsNullOrEmpty(result.QualityAssessment.BleuPercentage))
                {
                    // Parse BLEU percentage (e.g., "85.50%" -> 0.855)
                    var percentageStr = result.QualityAssessment.BleuPercentage.TrimEnd('%');
                    if (double.TryParse(percentageStr, out double percentage))
                    {
                        bleuScore = percentage / 100.0;
                    }
                }

                var translationResult = new TranslationResult(
                    content,
                    result.BackTranslation ?? "Translation failed",
                    "auto", // Source language detection
                    "auto", // Target language detection
                    bleuScore,
                    result.QualityAssessment?.ConfidenceLevel ?? "",
                    0.0, // Processing time not tracked in current implementation
                    "TranslationFiesta"
                );

                _batchResults.Add(translationResult);

                string translatedContent = $"Original:\n{content}\n\nIntermediate:\n{result.IntermediateTranslation}\n\nBacktranslation:\n{result.BackTranslation}";

                // Add quality assessment if available
                if (result.QualityAssessment != null)
                {
                    translatedContent += $"\n\n=== QUALITY ASSESSMENT ===\n";
                    translatedContent += $"BLEU Score: {result.QualityAssessment.BleuPercentage}\n";
                    translatedContent += $"Confidence: {result.QualityAssessment.ConfidenceLevel}\n";
                    translatedContent += $"Rating: {result.QualityAssessment.QualityRating}\n";
                    translatedContent += $"Assessment: {result.QualityAssessment.Description}\n";
                    translatedContent += $"Recommendations: {result.QualityAssessment.Recommendations}\n";
                }

                var newFile = await folder.CreateFileAsync($"{file.DisplayName}_translated{file.FileType}", CreationCollisionOption.GenerateUniqueName);
                await FileIO.WriteTextAsync(newFile, translatedContent);

                _updateCallback?.Invoke(i + 1, totalFiles);
            }
            _isRunning = false;
        }

        /// <summary>
        /// Export batch processing results to the specified format
        /// </summary>
        public void ExportBatchResults(string outputPath, string format = "pdf")
        {
            if (_batchResults.Count == 0)
            {
                throw new InvalidOperationException("No batch results available for export");
            }

            var metadata = new ExportMetadata
            {
                Title = $"Batch Translation Results - {_batchResults.Count} files",
                SourceLanguage = "Multiple",
                TargetLanguage = "Multiple",
                CreatedDate = DateTime.Now.ToString("O")
            };

            switch (format.ToLower())
            {
                case "pdf":
                    ExportManager.ExportToPdf(_batchResults, outputPath, metadata);
                    break;
                case "docx":
                    ExportManager.ExportToDocx(_batchResults, outputPath, metadata);
                    break;
                default:
                    throw new ArgumentException($"Unsupported export format: {format}");
            }
        }

        /// <summary>
        /// Get the current batch results
        /// </summary>
        public List<TranslationResult> GetBatchResults()
        {
            return new List<TranslationResult>(_batchResults);
        }

        /// <summary>
        /// Clear batch results
        /// </summary>
        public void ClearBatchResults()
        {
            _batchResults.Clear();
        }

        public void Stop()
        {
            _isRunning = false;
        }
    }
}