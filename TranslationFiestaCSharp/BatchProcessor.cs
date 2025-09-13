using System;
using System.IO;
using System.Threading.Tasks;

namespace TranslationFiestaCSharp
{
    public class BatchProcessor
    {
        private readonly TranslationClient _translationClient;
        private readonly BLEUScorer _bleuScorer;
        private readonly Action<int, int> _updateCallback;
        private bool _isRunning;

        public BatchProcessor(TranslationClient translationClient, Action<int, int> updateCallback)
        {
            _translationClient = translationClient;
            _bleuScorer = new BLEUScorer();
            _updateCallback = updateCallback;
        }

        public async Task ProcessDirectoryAsync(string directoryPath)
        {
            _isRunning = true;
            var files = Directory.GetFiles(directoryPath, "*.*", SearchOption.AllDirectories);
            var textFiles = Array.FindAll(files, f => f.EndsWith(".txt") || f.EndsWith(".md") || f.EndsWith(".html"));
            int totalFiles = textFiles.Length;

            Logger.Info($"Starting batch processing for {totalFiles} files in {directoryPath}");

            for (int i = 0; i < totalFiles; i++)
            {
                if (!_isRunning) break;

                var file = textFiles[i];
                Logger.Info($"Processing file {i + 1}/{totalFiles}: {Path.GetFileName(file)}");

                try
                {
                    string originalContent = await File.ReadAllTextAsync(file);

                    // Perform back-translation: English -> Japanese -> English
                    string japaneseContent = await _translationClient.TranslateAsync(originalContent, "en", "ja");
                    string backtranslatedContent = await _translationClient.TranslateAsync(japaneseContent, "ja", "en");

                    // Calculate BLEU score for quality assessment
                    var qualityAssessment = _bleuScorer.AssessTranslationQuality(originalContent, backtranslatedContent);

                    // Log quality assessment
                    Logger.Info($"Batch translation quality assessment for {Path.GetFileName(file)}: BLEU={qualityAssessment.BleuScore:F2}, Confidence={qualityAssessment.ConfidenceLevel}, Rating={qualityAssessment.QualityRating}");

                    // Save translated file with quality assessment
                    await SaveTranslatedFileAsync(file, backtranslatedContent, originalContent, qualityAssessment);

                }
                catch (Exception ex)
                {
                    Logger.Error($"Failed to process file {Path.GetFileName(file)}", ex);
                }

                _updateCallback?.Invoke(i + 1, totalFiles);
            }

            _isRunning = false;
            Logger.Info("Batch processing completed.");
        }

        private async Task SaveTranslatedFileAsync(string originalFilePath, string translatedContent,
            string originalContent, TranslationQualityAssessment assessment)
        {
            string directory = Path.GetDirectoryName(originalFilePath) ?? "";
            string fileNameWithoutExt = Path.GetFileNameWithoutExtension(originalFilePath);
            string extension = Path.GetExtension(originalFilePath);
            string newFileName = $"{fileNameWithoutExt}_translated{extension}";
            string newFilePath = Path.Combine(directory, newFileName);

            try
            {
                using (var writer = new StreamWriter(newFilePath, false, System.Text.Encoding.UTF8))
                {
                    await writer.WriteLineAsync(translatedContent);
                    await writer.WriteLineAsync();
                    await writer.WriteLineAsync("=== QUALITY ASSESSMENT ===");
                    await writer.WriteLineAsync($"BLEU Score: {assessment.BleuPercentage}");
                    await writer.WriteLineAsync($"Confidence: {assessment.ConfidenceLevel}");
                    await writer.WriteLineAsync($"Rating: {assessment.QualityRating}");
                    await writer.WriteLineAsync($"Assessment: {assessment.Description}");
                    await writer.WriteLineAsync($"Recommendations: {assessment.Recommendations}");
                }

                Logger.Info($"Saved translated file with quality assessment to {newFilePath}");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to save translated file {newFilePath}", ex);
            }
        }

        public void Stop()
        {
            _isRunning = false;
        }
    }
}