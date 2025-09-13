using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.UI.Core;
using Microsoft.UI.Xaml.Automation.Peers;
using Microsoft.UI.Xaml.Automation.Provider;

namespace TranslationFiesta.WinUI
{
    public sealed partial class MainWindow : Window
    {
       private enum OutputFormat { Plain, Markdown, Html }
        private readonly TranslationClient _translator = new TranslationClient();
        private AppSettings _settings;
        private BatchProcessor? _currentBatchProcessor;
        private readonly TemplateManager _templateManager;

        public MainWindow()
        {
            InitializeComponent();
            this.Title = "Translation Fiesta";

            // Set window size programmatically (WinUI 3 doesn't support Width/Height in XAML)
            this.AppWindow.Resize(new Windows.Graphics.SizeInt32(1000, 700));

            // Load settings
            _settings = SettingsService.Load();

            // Apply settings to cost tracker
            _translator.CostTracker.SetMonthlyBudget(_settings.MonthlyBudget);

            // Wire up event handlers
            TranslateButton.Click += TranslateButton_Click;
            ImportButton.Click += ImportButton_Click;
            ExportButton.Click += ExportButton_Click;
            ExportPdfMenuItem.Click += ExportPdfMenuItem_Click;
            ExportDocxMenuItem.Click += ExportDocxMenuItem_Click;
            ExportTxtMenuItem.Click += ExportTxtMenuItem_Click;
            ClearButton.Click += ClearButton_Click;
            BatchButton.Click += BatchButton_Click;
            SwapLanguagesButton.Click += SwapLanguagesButton_Click;
            SourceCopyButton.Click += SourceCopyButton_Click;
            TargetCopyButton.Click += TargetCopyButton_Click;
            TargetSpeakButton.Click += TargetSpeakButton_Click;
            KeyboardShortcutsMenuItem.Click += KeyboardShortcutsMenuItem_Click;
            ManageTemplatesButton.Click += ManageTemplatesButton_Click;

            // Update character count when text changes
            SourceTextBox.TextChanged += SourceTextBox_TextChanged;
            TargetTextBox.TextChanged += TargetTextBox_TextChanged;

            // Initialize language selectors
            InitializeLanguageSelectors();

           // Initialize format selector
           InitializeFormatSelector();

            // Initialize cost display
            UpdateCostDisplay();

            _templateManager = new TemplateManager();
            _ = LoadTemplatesAsync();


            Logger.Info("Translation Fiesta initialized");

        }

        private void Window_KeyDown(object sender, Microsoft.UI.Xaml.Input.KeyRoutedEventArgs e)
        {
            var ctrlState = Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(Windows.System.VirtualKey.Control);
            var shiftState = Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(Windows.System.VirtualKey.Shift);

            bool isCtrlPressed = ctrlState.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);
            bool isShiftPressed = shiftState.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);

            if (isCtrlPressed)
            {
                switch (e.Key)
                {
                    case Windows.System.VirtualKey.Enter:
                        InvokeButton(TranslateButton);
                        Logger.Info("Keyboard shortcut: Ctrl+Enter (Translate)");
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.L:
                        InvokeButton(SwapLanguagesButton);
                        Logger.Info("Keyboard shortcut: Ctrl+L (Swap Languages)");
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.S:
                        InvokeButton(TargetSpeakButton);
                        Logger.Info("Keyboard shortcut: Ctrl+S (Speak Target Text)");
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.C:
                        if (isShiftPressed)
                        {
                            InvokeButton(SourceCopyButton);
                            Logger.Info("Keyboard shortcut: Ctrl+Shift+C (Copy Source Text)");
                        }
                        else
                        {
                            InvokeButton(TargetCopyButton);
                            Logger.Info("Keyboard shortcut: Ctrl+C (Copy Target Text)");
                        }
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.O:
                        InvokeButton(ImportButton);
                        Logger.Info("Keyboard shortcut: Ctrl+O (Import Text)");
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.E:
                        InvokeButton(ExportButton);
                        Logger.Info("Keyboard shortcut: Ctrl+E (Export Text)");
                        e.Handled = true;
                        break;

                    case Windows.System.VirtualKey.D:
                        InvokeButton(ClearButton);
                        Logger.Info("Keyboard shortcut: Ctrl+D (Clear Text)");
                        e.Handled = true;
                        break;
                }
            }
        }

        private void InvokeButton(FrameworkElement element)
        {
            if (element == null) return;

            DispatcherQueue.TryEnqueue(() =>
            {
                var peer = FrameworkElementAutomationPeer.FromElement(element);
                if (peer != null)
                {
                    if (peer.GetPattern(PatternInterface.Invoke) is IInvokeProvider invokeProvider)
                    {
                        invokeProvider.Invoke();
                    }
                }
            });
        }

        private void InitializeLanguageSelectors()
        {
            // Common languages for translation
            var languages = new[]
            {
                new { Code = "en", Name = "English" },
                new { Code = "es", Name = "Spanish" },
                new { Code = "fr", Name = "French" },
                new { Code = "de", Name = "German" },
                new { Code = "it", Name = "Italian" },
                new { Code = "pt", Name = "Portuguese" },
                new { Code = "ru", Name = "Russian" },
                new { Code = "ja", Name = "Japanese" },
                new { Code = "ko", Name = "Korean" },
                new { Code = "zh", Name = "Chinese" },
                new { Code = "ar", Name = "Arabic" },
                new { Code = "hi", Name = "Hindi" },
                new { Code = "nl", Name = "Dutch" },
                new { Code = "sv", Name = "Swedish" },
                new { Code = "da", Name = "Danish" },
                new { Code = "no", Name = "Norwegian" },
                new { Code = "fi", Name = "Finnish" },
                new { Code = "pl", Name = "Polish" },
                new { Code = "tr", Name = "Turkish" },
                new { Code = "cs", Name = "Czech" },
                new { Code = "hu", Name = "Hungarian" },
                new { Code = "th", Name = "Thai" },
                new { Code = "vi", Name = "Vietnamese" },
                new { Code = "id", Name = "Indonesian" },
                new { Code = "ms", Name = "Malay" }
            };

            // Populate source language combo
            foreach (var lang in languages)
            {
                SourceLanguageCombo.Items.Add(new ComboBoxItem
                {
                    Content = $"{lang.Name} ({lang.Code})",
                    Tag = lang.Code
                });
            }

            // Populate target language combo
            foreach (var lang in languages)
            {
                TargetLanguageCombo.Items.Add(new ComboBoxItem
                {
                    Content = $"{lang.Name} ({lang.Code})",
                    Tag = lang.Code
                });
            }

            // Set default selections
            SourceLanguageCombo.SelectedIndex = 0; // English
            TargetLanguageCombo.SelectedIndex = 7; // Japanese (common for back-translation)
        }

       private void InitializeFormatSelector()
       {
           FormatComboBox.ItemsSource = Enum.GetValues(typeof(OutputFormat));
           FormatComboBox.SelectedIndex = 2; // Default to HTML
       }

        private string GetSelectedLanguageCode(ComboBox comboBox)
        {
            if (comboBox.SelectedItem is ComboBoxItem selectedItem && selectedItem.Tag is string languageCode)
            {
                return languageCode;
            }
            return "en"; // Default to English if no selection
        }

        private async void TranslateButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                // Null checks for UI elements
                if (SourceTextBox == null || TargetTextBox == null || TranslateButton == null ||
                    SourceLanguageCombo == null || TargetLanguageCombo == null)
                {
                    Logger.Error("UI elements not initialized in TranslateButton_Click");
                    return;
                }

                var sourceText = SourceTextBox.Text?.Trim();
                if (string.IsNullOrWhiteSpace(sourceText))
                {
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = "Please enter text to translate.";
                });
                    return;
                }

                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TranslateButton != null)
                        TranslateButton.IsEnabled = false;
                });

                // Get selected languages from ComboBoxes
                var sourceLang = GetSelectedLanguageCode(SourceLanguageCombo);
                var targetLang = GetSelectedLanguageCode(TargetLanguageCombo);

                Logger.Info($"Starting backtranslation: {sourceLang} -> {targetLang}");

                var result = await _translator.BackTranslateAsync(sourceText, sourceLang, targetLang);

                var translation = result.BackTranslation ?? "Translation failed";

                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = translation;
                    UpdatePreview(translation);
                    UpdateCostDisplay();
                });

                Logger.Info("Backtranslation completed successfully");
            }
            catch (TaskCanceledException)
            {
                Logger.Info("Backtranslation was cancelled");
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = "Translation cancelled";
                });
            }
            catch (HttpRequestException ex)
            {
                Logger.Error($"Network error during backtranslation: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Network error: {ex.Message}";
                });
            }
            catch (Exception ex) when (ex.GetType().Name.Contains("Json"))
            {
                Logger.Error($"JSON parsing error during backtranslation: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Parsing error: {ex.Message}";
                });
            }
            catch (Exception ex)
            {
                Logger.Error($"Unexpected error during backtranslation: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Error: {ex.Message}";
                });
            }
            finally
            {
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TranslateButton != null)
                        TranslateButton.IsEnabled = true;
                });
            }
        }

        private async void ImportButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (SourceTextBox == null)
                {
                    Logger.Error("SourceTextBox not initialized in ImportButton_Click");
                    return;
                }

                var openPicker = new FileOpenPicker();
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(openPicker, hwnd);

                openPicker.SuggestedStartLocation = PickerLocationId.DocumentsLibrary;
                openPicker.FileTypeFilter.Add(".txt");
                openPicker.FileTypeFilter.Add(".html");
                openPicker.FileTypeFilter.Add(".md");

                var file = await openPicker.PickSingleFileAsync();
                if (file != null)
                {
                    var content = await FileIO.ReadTextAsync(file);
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        if (SourceTextBox != null)
                            SourceTextBox.Text = content;
                        UpdateCharCounts();
                    });
                    Logger.Info($"File imported: {file.Name}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Import failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Import failed: {ex.Message}";
                });
            }
        }

        private async void ExportButton_Click(Microsoft.UI.Xaml.Controls.SplitButton sender, Microsoft.UI.Xaml.Controls.SplitButtonClickEventArgs args)
        {
            try
            {
                // Default to PDF export when main button is clicked
                await ExportTranslationAsync("pdf");
            }
            catch (Exception ex)
            {
                Logger.Error($"Export failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Export failed: {ex.Message}";
                });
            }
        }

        private string GenerateExportContent()
        {
            if (TemplateComboBox.SelectedItem is TranslationTemplate selectedTemplate)
            {
                // Assuming you have access to bleuScore and qualityRating, otherwise pass null
                return _templateManager.ApplyTemplate(SourceTextBox.Text, TargetTextBox.Text, GetSelectedLanguageCode(SourceLanguageCombo), GetSelectedLanguageCode(TargetLanguageCombo), null, null, selectedTemplate);
            }
            return $"Source Text:\n{SourceTextBox.Text}\n\nBack-translation:\n{TargetTextBox.Text}";
        }

        private async void ExportPdfMenuItem_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await ExportTranslationAsync("pdf");
            }
            catch (Exception ex)
            {
                Logger.Error($"PDF export failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"PDF export failed: {ex.Message}";
                });
            }
        }

        private async void ExportDocxMenuItem_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await ExportTranslationAsync("docx");
            }
            catch (Exception ex)
            {
                Logger.Error($"DOCX export failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"DOCX export failed: {ex.Message}";
                });
            }
        }

        private async void ExportTxtMenuItem_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                await ExportTranslationAsync("txt");
            }
            catch (Exception ex)
            {
                Logger.Error($"TXT export failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"TXT export failed: {ex.Message}";
                });
            }
        }

        private async Task ExportTranslationAsync(string format)
        {
            if (string.IsNullOrWhiteSpace(TargetTextBox.Text))
            {
                TargetTextBox.Text = "No content to export.";
                return;
            }

            try
            {
                var savePicker = new FileSavePicker();
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(savePicker, hwnd);

                savePicker.SuggestedStartLocation = PickerLocationId.DocumentsLibrary;

                // Set file type based on format
                switch (format.ToLower())
                {
                    case "pdf":
                        savePicker.FileTypeChoices.Add("PDF Files", new System.Collections.Generic.List<string>() { ".pdf" });
                        savePicker.SuggestedFileName = "translation_results.pdf";
                        break;
                    case "docx":
                        savePicker.FileTypeChoices.Add("Word Documents", new System.Collections.Generic.List<string>() { ".docx" });
                        savePicker.SuggestedFileName = "translation_results.docx";
                        break;
                    case "txt":
                        savePicker.FileTypeChoices.Add("Text Files", new System.Collections.Generic.List<string>() { ".txt" });
                        savePicker.SuggestedFileName = "translation_results.txt";
                        break;
                }

                var file = await savePicker.PickSaveFileAsync();
                if (file != null)
                {
                    // Get selected languages
                    var sourceLang = GetSelectedLanguageCode(SourceLanguageCombo);
                    var targetLang = GetSelectedLanguageCode(TargetLanguageCombo);

                    // Create translation result
                    var translationResult = new TranslationResult(
                        SourceTextBox.Text,
                        TargetTextBox.Text,
                        sourceLang,
                        targetLang,
                        0.0, // Quality score - could be calculated if needed
                        "",
                        0.0, // Processing time - could be tracked if needed
                        "TranslationFiesta"
                    );

                    var translations = new List<TranslationResult> { translationResult };

                    // Create metadata
                    var metadata = new ExportMetadata
                    {
                        Title = "Translation Results",
                        SourceLanguage = sourceLang,
                        TargetLanguage = targetLang,
                        CreatedDate = DateTime.Now.ToString("O")
                    };

                    // Export based on format
                    string outputPath = file.Path;
                    switch (format.ToLower())
                    {
                        case "pdf":
                            ExportManager.ExportToPdf(translations, outputPath, metadata);
                            break;
                        case "docx":
                            ExportManager.ExportToDocx(translations, outputPath, metadata);
                            break;
                        case "txt":
                            var exportContent = GenerateExportContent();
                            await FileIO.WriteTextAsync(file, exportContent);
                            break;
                       case "md":
                           var markdownContent = $"# Translation Result\n\n**Source:**\n{SourceTextBox.Text}\n\n**Translation:**\n{TargetTextBox.Text}";
                           await FileIO.WriteTextAsync(file, markdownContent);
                           break;
                   }

                    Logger.Info($"Translation exported to {format.ToUpper()}: {file.Name}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Export failed: {ex.Message}", ex);
                TargetTextBox.Text = $"Export failed: {ex.Message}";
            }
        }

        private void ClearButton_Click(object sender, RoutedEventArgs e)
        {
            SourceTextBox.Text = string.Empty;
            TargetTextBox.Text = string.Empty;
            UpdateCharCounts();
            Logger.Info("Content cleared");
        }

        private async void BatchButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                var openPicker = new Windows.Storage.Pickers.FolderPicker();
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(openPicker, hwnd);

                openPicker.SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.DocumentsLibrary;
                openPicker.FileTypeFilter.Add("*");

                var folder = await openPicker.PickSingleFolderAsync();
                if (folder != null)
                {
                    _currentBatchProcessor = new BatchProcessor(_translator, (current, total) =>
                    {
                        // Update progress
                        Logger.Info($"Processing {current}/{total} files...");
                    });

                    await _currentBatchProcessor.ProcessDirectoryAsync(folder);
                    Logger.Info("Batch processing completed");

                    // Show export option for batch results
                    await ShowBatchExportDialog();
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Batch processing failed: {ex.Message}", ex);
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TargetTextBox != null)
                        TargetTextBox.Text = $"Batch processing failed: {ex.Message}";
                });
            }
        }

        private async Task ShowBatchExportDialog()
        {
            if (_currentBatchProcessor == null || _currentBatchProcessor.GetBatchResults().Count == 0)
            {
                return;
            }

            var dialog = new Microsoft.UI.Xaml.Controls.ContentDialog()
            {
                Title = "Batch Processing Complete",
                Content = $"Successfully processed {_currentBatchProcessor.GetBatchResults().Count} files.\n\nWould you like to export the results?",
                PrimaryButtonText = "Export as PDF",
                SecondaryButtonText = "Export as DOCX",
                CloseButtonText = "Skip"
            };

            dialog.XamlRoot = this.Content.XamlRoot;
            var result = await dialog.ShowAsync();

            if (result == Microsoft.UI.Xaml.Controls.ContentDialogResult.Primary)
            {
                await ExportBatchResultsAsync("pdf");
            }
            else if (result == Microsoft.UI.Xaml.Controls.ContentDialogResult.Secondary)
            {
                await ExportBatchResultsAsync("docx");
            }
        }

        private async Task ExportBatchResultsAsync(string format)
        {
            if (_currentBatchProcessor == null)
            {
                return;
            }

            try
            {
                var savePicker = new FileSavePicker();
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(savePicker, hwnd);

                savePicker.SuggestedStartLocation = PickerLocationId.DocumentsLibrary;

                switch (format.ToLower())
                {
                    case "pdf":
                        savePicker.FileTypeChoices.Add("PDF Files", new System.Collections.Generic.List<string>() { ".pdf" });
                        savePicker.SuggestedFileName = "batch_translation_results.pdf";
                        break;
                    case "docx":
                        savePicker.FileTypeChoices.Add("Word Documents", new System.Collections.Generic.List<string>() { ".docx" });
                        savePicker.SuggestedFileName = "batch_translation_results.docx";
                        break;
                }

                var file = await savePicker.PickSaveFileAsync();
                if (file != null)
                {
                    _currentBatchProcessor.ExportBatchResults(file.Path, format);
                    Logger.Info($"Batch results exported to {format.ToUpper()}: {file.Name}");
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Batch export failed: {ex.Message}", ex);
            }
        }

        // New methods for modern UI functionality
        private void SwapLanguagesButton_Click(object sender, RoutedEventArgs e)
        {
            var sourceIndex = SourceLanguageCombo.SelectedIndex;
            var targetIndex = TargetLanguageCombo.SelectedIndex;

            SourceLanguageCombo.SelectedIndex = targetIndex;
            TargetLanguageCombo.SelectedIndex = sourceIndex;

            // Swap text content
            var tempText = SourceTextBox.Text;
            SourceTextBox.Text = TargetTextBox.Text;
            TargetTextBox.Text = tempText;

            UpdateCharCounts();
            Logger.Info("Languages swapped");
        }

        private void SourceCopyButton_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(SourceTextBox.Text))
            {
                var dataPackage = new Windows.ApplicationModel.DataTransfer.DataPackage();
                dataPackage.SetText(SourceTextBox.Text);
                Windows.ApplicationModel.DataTransfer.Clipboard.SetContent(dataPackage);
                Logger.Info("Source text copied to clipboard");
            }
        }

        private void TargetCopyButton_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(TargetTextBox.Text))
            {
                var dataPackage = new Windows.ApplicationModel.DataTransfer.DataPackage();
                dataPackage.SetText(TargetTextBox.Text);
                Windows.ApplicationModel.DataTransfer.Clipboard.SetContent(dataPackage);
                Logger.Info("Target text copied to clipboard");
            }
        }

        private async void TargetSpeakButton_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(TargetTextBox.Text))
            {
                try
                {
                    using (var synthesizer = new Windows.Media.SpeechSynthesis.SpeechSynthesizer())
                    {
                        var synthesisStream = await synthesizer.SynthesizeTextToStreamAsync(TargetTextBox.Text);
                        var player = new Windows.Media.Playback.MediaPlayer();
                        player.Source = Windows.Media.Core.MediaSource.CreateFromStream(synthesisStream, synthesisStream.ContentType);
                        player.Play();
                    }
                    Logger.Info("Text-to-speech started");
                }
                catch (Exception ex)
                {
                    Logger.Error($"Text-to-speech failed: {ex.Message}", ex);
                }
            }
        }

        private void SourceTextBox_TextChanged(object sender, Microsoft.UI.Xaml.Controls.TextChangedEventArgs e)
        {
            UpdateCharCounts();
        }

        private void TargetTextBox_TextChanged(object sender, Microsoft.UI.Xaml.Controls.TextChangedEventArgs e)
        {
            UpdateCharCounts();
        }

        private void UpdateCharCounts()
        {
            SourceCharCount.Text = $"Characters: {SourceTextBox.Text?.Length ?? 0}";
            TargetCharCount.Text = $"Characters: {TargetTextBox.Text?.Length ?? 0}";
        }

        private void UpdateCostDisplay()
        {
            try
            {
                var monthlyStats = _translator.CostTracker.GetCurrentMonthStats();
                var budget = _translator.CostTracker.GetMonthlyBudget();
                var remaining = budget - monthlyStats.TotalCost;

                // Update monthly cost and character count
                MonthlyCostText.Text = $"This Month: ${monthlyStats.TotalCost:F2}";
                MonthlyCharText.Text = $"Chars: {monthlyStats.TotalCharacters:N0}";

                // Update budget status
                if (remaining >= 0)
                {
                    BudgetStatusText.Text = $"Budget: ${remaining:F2} remaining";
                    BudgetStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                        Microsoft.UI.Colors.Green);
                }
                else
                {
                    BudgetStatusText.Text = $"Budget: ${Math.Abs(remaining):F2} over budget";
                    BudgetStatusText.Foreground = new Microsoft.UI.Xaml.Media.SolidColorBrush(
                        Microsoft.UI.Colors.Red);
                }

                // Update average cost per translation
                CostPerTranslationText.Text = $"Avg Cost: ${monthlyStats.AverageCostPerTranslation:F4}";
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to update cost display: {ex.Message}", ex);
                MonthlyCostText.Text = "Cost tracking unavailable";
                BudgetStatusText.Text = "Budget status unavailable";
                CostPerTranslationText.Text = "Avg Cost: N/A";
            }
        }

        private async void KeyboardShortcutsMenuItem_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (this.Content == null)
                {
                    Logger.Error("Window content not initialized in KeyboardShortcutsMenuItem_Click");
                    return;
                }

                var shortcuts = new List<string>
                {
                    "Ctrl+Enter: Translate",
                    "Ctrl+L: Swap Languages",
                    "Ctrl+S: Speak Target Text",
                    "Ctrl+C: Copy Target Text",
                    "Ctrl+Shift+C: Copy Source Text",
                    "Ctrl+O: Import Text",
                    "Ctrl+E: Export Text",
                    "Ctrl+D: Clear Text"
                };

                var dialog = new ContentDialog
                {
                    Title = "Keyboard Shortcuts",
                    Content = string.Join("\n", shortcuts),
                    CloseButtonText = "Close",
                    XamlRoot = this.Content.XamlRoot
                };

                await dialog.ShowAsync();
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to show keyboard shortcuts dialog: {ex.Message}", ex);
            }
        }
        private void ManageTemplatesButton_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                if (_templateManager == null)
                {
                    Logger.Error("TemplateManager not initialized in ManageTemplatesButton_Click");
                    return;
                }

                var editorWindow = new TemplateEditor(_templateManager);
                editorWindow.Activate();
                editorWindow.Closed += async (s, args) =>
                {
                    try
                    {
                        await LoadTemplatesAsync();
                    }
                    catch (Exception ex)
                    {
                        Logger.Error($"Failed to reload templates after editor closed: {ex.Message}", ex);
                    }
                };
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to open template editor: {ex.Message}", ex);
                if (TargetTextBox != null)
                {
                    DispatcherQueue.TryEnqueue(() =>
                    {
                        if (TargetTextBox != null)
                            TargetTextBox.Text = $"Failed to open template editor: {ex.Message}";
                    });
                }
            }
        }

        private async Task LoadTemplatesAsync()
        {
            try
            {
                if (_templateManager == null)
                {
                    Logger.Error("TemplateManager not initialized in LoadTemplatesAsync");
                    return;
                }

                await _templateManager.LoadTemplatesAsync();
                var templates = _templateManager.GetTemplates();

                DispatcherQueue.TryEnqueue(() =>
                {
                    if (TemplateComboBox != null)
                    {
                        TemplateComboBox.ItemsSource = templates;
                        TemplateComboBox.DisplayMemberPath = "Name";
                        if (templates.Count > 0)
                        {
                            TemplateComboBox.SelectedIndex = 0;
                        }
                    }
                });
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load templates: {ex.Message}", ex);
            }
        }

        private async void UpdatePreview(string content)
        {
            try
            {
                // Null checks for UI elements
                if (FormatComboBox == null || PreviewWebView == null)
                {
                    Logger.Warning("UI elements not initialized in UpdatePreview");
                    return;
                }

                if (string.IsNullOrEmpty(content))
                {
                    Logger.Debug("Empty content provided to UpdatePreview");
                    return;
                }

                // Ensure we're on the UI thread
                DispatcherQueue.TryEnqueue(async () =>
                {
                    try
                    {
                        if (FormatComboBox?.SelectedItem is OutputFormat format && format == OutputFormat.Html)
                        {
                            await PreviewWebView?.EnsureCoreWebView2Async();
                            PreviewWebView?.NavigateToString(content);
                        }
                        else
                        {
                            await PreviewWebView?.EnsureCoreWebView2Async();
                            PreviewWebView?.NavigateToString($"<pre>{content}</pre>");
                        }
                    }
                    catch (Exception ex)
                    {
                        Logger.Error($"WebView2 operation failed in UpdatePreview: {ex.Message}", ex);
                        // Don't re-throw to prevent crash
                    }
                });
            }
            catch (Exception ex)
            {
                Logger.Error($"UpdatePreview failed: {ex.Message}", ex);
                // Don't re-throw to prevent crash
            }
        }
    }
}
