using System;
using System.IO;
using System.Threading.Tasks;

namespace TranslationFiestaCSharp
{
    public class BatchProcessor
    {
        private readonly TranslationClient _translationClient;
        private readonly Action<int, int> _updateCallback;
        private bool _isRunning;

        public BatchProcessor(TranslationClient translationClient, Action<int, int> updateCallback)
        {
            _translationClient = translationClient;
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

                    await SaveTranslatedFileAsync(file, backtranslatedContent);

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

        private async Task SaveTranslatedFileAsync(string originalFilePath, string translatedContent)
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
                }

                Logger.Info($"Saved translated file to {newFilePath}");
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
