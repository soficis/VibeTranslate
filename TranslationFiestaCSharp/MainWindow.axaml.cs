using Avalonia;
using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.Threading;
using Avalonia.Platform.Storage;
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Net.Http;

namespace TranslationFiestaCSharp
{
    public partial class MainWindow : Window
    {
        private readonly TranslationClient Translator = new TranslationClient();
        private CancellationTokenSource? cts;
        private AppSettings settings;

        public MainWindow()
        {
            InitializeComponent();

            settings = SettingsService.Load();
            
            // Set up initial state
            var providerId = ProviderIds.Normalize(settings.ProviderId);
            ProviderCombo.SelectedIndex = 0; // Simplified for Google
            
            // Window size
            if (settings.WindowWidth > 800) Width = settings.WindowWidth;
            if (settings.WindowHeight > 600) Height = settings.WindowHeight;
            if (settings.WindowX >= 0 && settings.WindowY >= 0)
            {
                Position = new Avalonia.PixelPoint(settings.WindowX, settings.WindowY);
            }

            TranslateBtn.Click += TranslateBtn_Click;
            CancelBtn.Click += CancelBtn_Click;
            ImportBtn.Click += ImportBtn_Click;
            SaveBtn.Click += SaveBtn_Click;
            CopyBtn.Click += CopyBtn_Click;
            BatchBtn.Click += BatchBtn_Click;

            Closed += MainWindow_Closed;
        }

        private void MainWindow_Closed(object? sender, EventArgs e)
        {
            SettingsService.SaveCurrentSettings(true, ProviderIds.GoogleUnofficial, (int)Width, (int)Height, Position.X, Position.Y);
        }

        private string LoadTextFromFile(string filePath)
        {
            try
            {
                var extension = Path.GetExtension(filePath).ToLower();
                var rawContent = File.ReadAllText(filePath, Encoding.UTF8);

                switch (extension)
                {
                    case ".html":
                        var extractedText = HtmlProcessor.ExtractTextFromHtml(rawContent);
                        Logger.Info($"Extracted text from HTML: {rawContent.Length} chars -> {extractedText.Length} chars");
                        return extractedText;
                    case ".md":
                    case ".txt":
                        return rawContent.Trim();
                    case ".epub":
                        Logger.Warn($"EPUB file {filePath} detected but EPUB processing is currently disabled.");
                        return string.Empty;
                    default:
                        return rawContent.Trim();
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load file {filePath}", ex);
                throw;
            }
        }

        private void SetStatus(string message)
        {
            Dispatcher.UIThread.Post(() => {
                StatusText.Text = message;
                Logger.Info($"Status: {message}");
            });
        }

        private void SetBusy(bool busy)
        {
            Dispatcher.UIThread.Post(() => {
                TranslateBtn.IsEnabled = !busy;
                CancelBtn.IsEnabled = busy;
                InputText.IsEnabled = !busy;
                ImportBtn.IsEnabled = !busy;
                CopyBtn.IsEnabled = !busy;
                SaveBtn.IsEnabled = !busy;
                ProviderCombo.IsEnabled = !busy;
                StatusProgress.IsVisible = busy;
            });
        }

        private async void ImportBtn_Click(object? sender, RoutedEventArgs e)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return;

            var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
            {
                Title = "Import File",
                AllowMultiple = false,
                FileTypeFilter = new[] 
                {
                    new FilePickerFileType("Supported files") { Patterns = new[] { "*.txt", "*.md", "*.html", "*.epub" } }
                }
            });

            if (files.Count >= 1)
            {
                try
                {
                    var filePath = files[0].Path.LocalPath;
                    var loadedText = LoadTextFromFile(filePath);
                    InputText.Text = loadedText;

                    var fileName = Path.GetFileName(filePath);
                    SetStatus($"Loaded: {fileName}");
                    
                    settings.LastFilePath = filePath;
                }
                catch (Exception ex)
                {
                    SetStatus("File import failed");
                    Logger.Error("File import failed", ex);
                }
            }
        }

        private async void SaveBtn_Click(object? sender, RoutedEventArgs e)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return;

            var file = await topLevel.StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
            {
                Title = "Save Back Translation",
                SuggestedFileName = "backtranslation.txt",
                DefaultExtension = ".txt"
            });

            if (file != null)
            {
                await using var stream = await file.OpenWriteAsync();
                using var writer = new StreamWriter(stream, Encoding.UTF8);
                await writer.WriteAsync(ResultText.Text ?? string.Empty);
                
                SetStatus($"Saved back-translation to {Path.GetFileName(file.Path.LocalPath)}");
                settings.LastSavePath = file.Path.LocalPath;
            }
        }

        private void CopyBtn_Click(object? sender, RoutedEventArgs e)
        {
            var clipboard = TopLevel.GetTopLevel(this)?.Clipboard;
            if (clipboard != null && !string.IsNullOrEmpty(ResultText.Text))
            {
                _ = clipboard.SetTextAsync(ResultText.Text);
                SetStatus("Copied back-translation to clipboard");
            }
        }

        private void CancelBtn_Click(object? sender, RoutedEventArgs e)
        {
            cts?.Cancel();
        }

        private async void BatchBtn_Click(object? sender, RoutedEventArgs e)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return;

            var folders = await topLevel.StorageProvider.OpenFolderPickerAsync(new FolderPickerOpenOptions
            {
                Title = "Select Directory for Batch Processing"
            });

            if (folders.Count >= 1)
            {
                var folderPath = folders[0].Path.LocalPath;
                Translator.ProviderId = ProviderIds.GoogleUnofficial;

                var batchProcessor = new BatchProcessor(Translator, (current, total) =>
                {
                    Dispatcher.UIThread.Post(() =>
                    {
                        StatusProgress.Value = (int)((double)current / total * 100);
                        StatusText.Text = $"Processing {current}/{total}...";
                    });
                });

                _ = Task.Run(() => batchProcessor.ProcessDirectoryAsync(folderPath));
            }
        }

        private async void TranslateBtn_Click(object? sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(InputText.Text))
            {
                SetStatus("Please enter English text to translate.");
                return;
            }

            var input = InputText.Text;
            try
            {
                SetBusy(true);
                cts = new CancellationTokenSource();
                IntermediateText.Text = string.Empty;
                ResultText.Text = string.Empty;

                Translator.ProviderId = ProviderIds.GoogleUnofficial;
                
                SetStatus("Translating to Japanese...");
                var ja = await Translator.TranslateAsync(input, "en", "ja", cts.Token);
                IntermediateText.Text = ja;

                SetStatus("Translating back to English...");
                var back = await Translator.TranslateAsync(ja, "ja", "en", cts.Token);
                ResultText.Text = back;

                StatusText.Foreground = Avalonia.Media.Brushes.Green;
                SetStatus("Done");
            }
            catch (HttpRequestException hre)
            {
                SetStatus("Network/HTTP error: " + hre.Message);
                Logger.Error("HTTP error during translation", hre);
            }
            catch (TaskCanceledException)
            {
                SetStatus("Cancelled");
                Logger.Warn("Translation cancelled by user");
            }
            catch (Exception ex)
            {
                SetStatus("Unexpected error: " + ex.Message);
                Logger.Error("Unexpected error during translation", ex);
            }
            finally
            {
                SetBusy(false);
                cts?.Dispose();
                cts = null;
            }
        }
    }
}
