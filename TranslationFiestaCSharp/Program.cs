using System;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;
using System.IO;
using TranslationFiestaCSharp;

namespace TranslationFiestaCSharp
{
    static class Program
    {
        static string ExtractTextFromHtml(string htmlContent)
        {
            return HtmlProcessor.ExtractTextFromHtml(htmlContent);
        }

        static string LoadTextFromFile(string filePath)
        {
            try
            {
                var extension = Path.GetExtension(filePath).ToLower();
                var rawContent = File.ReadAllText(filePath, Encoding.UTF8);

                switch (extension)
                {
                    case ".html":
                        var extractedText = ExtractTextFromHtml(rawContent);
                        Logger.Info($"Extracted text from HTML: {rawContent.Length} chars -> {extractedText.Length} chars");
                        return extractedText;
                    case ".md":
                    case ".txt":
                        Logger.Debug($"Loading plain text/markdown from {filePath}");
                        return rawContent.Trim();
                    case ".epub":
                        // EPUB support temporarily disabled due to EpubSharp compatibility issues with .NET 9.0
                        Logger.Warn($"EPUB file {filePath} detected but EPUB processing is currently disabled. EpubSharp library needs to be updated for .NET 9.0 compatibility.");
                        return string.Empty;
                    default:
                        Logger.Debug($"Loading raw content as plain text from {filePath}");
                        return rawContent.Trim(); // Default to plain text
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load file {filePath}", ex);
                throw;
            }
        }
    // Use TranslationClient for parsing and HTTP
    static readonly TranslationClient Translator = new TranslationClient();

    private sealed class ProviderOption
    {
        public string Id { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
    }

        static void Main(string[] args)
        {
            // Initialize Windows Forms for GUI mode
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Load settings
            var settings = SettingsService.Load();
            var providerId = ProviderIds.Normalize(settings.ProviderId);

            // Make window responsive to screen size
            var screen = Screen.PrimaryScreen;
            var screenWidth = screen?.Bounds.Width ?? 1920; // Default to 1920 if screen is null
            var screenHeight = screen?.Bounds.Height ?? 1080; // Default to 1080 if screen is null

            // Calculate responsive window size (80% of screen size, but not larger than saved settings)
            var defaultWidth = Math.Min((int)(screenWidth * 0.8), Math.Max(settings.WindowWidth, 900));
            var defaultHeight = Math.Min((int)(screenHeight * 0.8), Math.Max(settings.WindowHeight, 800));

            var form = new Form {
                Text = "TranslationFiesta - English ↔ Japanese",
                Width = defaultWidth,
                Height = defaultHeight,
                MinimumSize = new System.Drawing.Size(800, 600),
                KeyPreview = true
            };

            // Apply window position if saved
            if (settings.WindowX >= 0 && settings.WindowY >= 0)
            {
                form.StartPosition = FormStartPosition.Manual;
                form.Location = new System.Drawing.Point(settings.WindowX, settings.WindowY);
            }

            // Register text variations for dynamic UI

            // Menu
            var menu = new MenuStrip();
            var fileMenu = new ToolStripMenuItem("File");
            var miImport = new ToolStripMenuItem("Import File (.txt, .md, .html, .epub)") { ShortcutKeys = Keys.Control | Keys.O };
            var miSaveBack = new ToolStripMenuItem("Save Back") { ShortcutKeys = Keys.Control | Keys.S };
            var miCopyBack = new ToolStripMenuItem("Copy Back") { ShortcutKeys = Keys.Control | Keys.C };
            var miExit = new ToolStripMenuItem("Exit") { ShortcutKeys = Keys.Alt | Keys.F4 };
            fileMenu.DropDownItems.AddRange(new ToolStripItem[] { miImport, miSaveBack, miCopyBack, new ToolStripSeparator(), miExit });
            menu.Items.Add(fileMenu);
            form.MainMenuStrip = menu;
            form.Controls.Add(menu);

            // layout helpers under menu
            var yTop = menu.Height + 6;

            // Create controls with responsive sizing
            var margin = 10;
            var availableWidth = form.ClientSize.Width - (2 * margin);

            var btnTheme = new Button { Text = settings.DarkMode ? "Light" : "Dark", Left = margin, Top = yTop, Width = 80 };
            var btnLoad = new Button { Text = "Load File", Left = margin + 90, Top = yTop, Width = 100 };
            var btnBatch = new Button { Text = "Batch Process", Left = margin + 200, Top = yTop, Width = 120 };
            var providerOptions = new[]
            {
                new ProviderOption { Id = ProviderIds.GoogleUnofficial, Name = "Google Translate (Unofficial / Free)" }
            };
            var lblProvider = new Label { Text = "Provider:", Left = margin + 330, Top = yTop + 5, Width = 70 };
            var cmbProvider = new ComboBox { Left = margin + 400, Top = yTop + 2, Width = 210, DropDownStyle = ComboBoxStyle.DropDownList };
            cmbProvider.DataSource = providerOptions;
            cmbProvider.DisplayMember = "Name";
            cmbProvider.ValueMember = "Id";
            cmbProvider.SelectedValue = providerId;
            var lblFile = new Label { Text = "", Left = margin, Top = yTop + 34, Width = availableWidth };

            var lblInput = new Label { Text = "Input (English):", Left = margin, Top = yTop + 60, Width = 200 };
            var txtInput = new TextBox { Left = margin, Top = yTop + 82, Width = availableWidth, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical };

            var btnTranslate = new Button { Text = "Translate", Left = margin, Top = yTop + 272, Width = 140 };
            var btnCancel = new Button { Text = "Cancel", Left = margin + 150, Top = yTop + 272, Width = 100, Enabled = false };
            btnCancel.FlatStyle = FlatStyle.System;
            var lblStatus = new Label { Text = "Ready", Left = margin + 260, Top = yTop + 277, Width = Math.Max(400, availableWidth - 270) };
            var progress = new ProgressBar { Left = margin + 260, Top = yTop + 298, Width = Math.Max(400, availableWidth - 270), Height = 10, Visible = false, Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 30 };

            var lblJa = new Label { Text = "Japanese (intermediate):", Left = margin, Top = yTop + 318, Width = 300 };
            var txtJa = new TextBox { Left = margin, Top = yTop + 340, Width = availableWidth, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var lblBack = new Label { Text = "Back to English:", Left = margin, Top = yTop + 530, Width = 200 };
            var txtBack = new TextBox { Left = margin, Top = yTop + 552, Width = availableWidth, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var btnCopy = new Button { Text = "Copy Back", Left = margin, Top = yTop + 742, Width = 100 };
            var btnSave = new Button { Text = "Save Back...", Left = margin + 110, Top = yTop + 742, Width = 120 };

            form.Controls.AddRange(new Control[] { btnTheme, btnLoad, btnBatch, lblProvider, cmbProvider, lblFile, lblInput, txtInput, btnTranslate, btnCancel, lblStatus, progress, lblJa, txtJa, lblBack, txtBack, btnCopy, btnSave });

            var dark = settings.DarkMode;
            // Apply initial theme
            ApplyTheme();

            void ApplyTheme()
            {
                var bg = dark ? System.Drawing.Color.FromArgb(45, 45, 48) : System.Drawing.SystemColors.Control;
                var fg = dark ? System.Drawing.Color.White : System.Drawing.Color.Black;
                form.BackColor = bg;

                foreach (Control c in form.Controls)
                {
                    c.BackColor = bg;
                    c.ForeColor = fg;

                    // Special handling for buttons to ensure disabled state is visible
                    if (c is Button button)
                    {
                        if (dark)
                        {
                            button.BackColor = button.Enabled ? System.Drawing.Color.FromArgb(70, 70, 74) : System.Drawing.Color.FromArgb(55, 55, 58);
                            button.ForeColor = System.Drawing.Color.White;
                            button.FlatStyle = FlatStyle.Flat;
                            button.FlatAppearance.BorderColor = System.Drawing.Color.FromArgb(100, 100, 104);
                        }
                        else
                        {
                            button.BackColor = System.Drawing.SystemColors.Control;
                            button.ForeColor = System.Drawing.Color.Black;
                            button.FlatStyle = FlatStyle.Standard;
                        }
                    }
                }

                txtInput.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtInput.ForeColor = fg;
                txtJa.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtJa.ForeColor = fg;
                txtBack.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtBack.ForeColor = fg;
            }

            btnTheme.Click += (s, e) =>
            {
                dark = !dark;
                btnTheme.Text = dark ? "Light" : "Dark";
                ApplyTheme();

                // Save theme setting
                SettingsService.SaveCurrentSettings(dark, GetSelectedProviderId(), form.Width, form.Height, form.Location.X, form.Location.Y);
            };

            // Provider selection
            cmbProvider.SelectedIndexChanged += (s, e) =>
            {
                SettingsService.SaveCurrentSettings(dark, GetSelectedProviderId(), form.Width, form.Height, form.Location.X, form.Location.Y);
            };

            // File import (enhanced to support .txt, .md, .html, .epub like F# version)
            Action importFile = () =>
            {
                using var ofd = new OpenFileDialog();
                ofd.Filter = "Supported files (*.txt;*.md;*.html;*.epub)|*.txt;*.md;*.html;*.epub|Text files (*.txt)|*.txt|Markdown files (*.md)|*.md|HTML files (*.html)|*.html|EPUB files (*.epub)|*.epub|All files (*.*)|*.*";
                if (ofd.ShowDialog() == DialogResult.OK)
                {
                    try
                    {
                        var loadedText = LoadTextFromFile(ofd.FileName);
                        txtInput.Text = loadedText;

                        var fileName = Path.GetFileName(ofd.FileName);
                        var extension = Path.GetExtension(ofd.FileName).ToLower();
                        string statusMsg;

                        switch (extension)
                        {
                            case ".html":
                                statusMsg = $"Loaded HTML: {fileName} ({loadedText.Length} chars extracted)";
                                break;
                            case ".md":
                                statusMsg = $"Loaded Markdown: {fileName}";
                                break;
                            case ".txt":
                                statusMsg = $"Loaded Text: {fileName}";
                                break;
                            case ".epub":
                                statusMsg = $"Loaded EPUB: {fileName} (First chapter extracted)";
                                break;
                            default:
                                statusMsg = $"Loaded: {fileName}";
                                break;
                        }

                        lblFile.Text = statusMsg;
                        setStatus(statusMsg);
                        Logger.Info($"Successfully imported file: {ofd.FileName}");

                        // Save last file path
                        SettingsService.SaveCurrentSettings(dark, GetSelectedProviderId(), form.Width, form.Height, form.Location.X, form.Location.Y, ofd.FileName);
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show("Failed to load file: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        setStatus("File import failed");
                        Logger.Error($"File import failed", ex);
                    }
                }
            };

            btnLoad.Click += (s, e) => importFile();
            miImport.Click += (s, e) => importFile();

            // Copy
            Action copyBack = () =>
            {
                if (!string.IsNullOrEmpty(txtBack.Text))
                {
                    Clipboard.SetText(txtBack.Text);
                    Logger.Info("Copied back-translation to clipboard");
                }
                else
                {
                    Logger.Warn("Attempted to copy empty back-translation to clipboard.");
                }
            };
            btnCopy.Click += (s, e) => copyBack();
            miCopyBack.Click += (s, e) => copyBack();

            // Save
            Action saveBack = () =>
            {
                using var sfd = new SaveFileDialog();
                sfd.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*";
                sfd.FileName = "backtranslation.txt";
                if (sfd.ShowDialog() == DialogResult.OK)
                {
                    var content = txtBack.Text ?? string.Empty;

                    System.IO.File.WriteAllText(sfd.FileName, content, Encoding.UTF8);
                    Logger.Info($"Saved back-translation to '{sfd.FileName}'");

                    // Save last save path
                    SettingsService.SaveCurrentSettings(dark, GetSelectedProviderId(), form.Width, form.Height, form.Location.X, form.Location.Y, settings.LastFilePath, sfd.FileName);
                }
                else
                {
                    Logger.Debug("Save back-translation dialog cancelled.");
                }
            };
            btnSave.Click += (s, e) => saveBack();
            miSaveBack.Click += (s, e) => saveBack();

            miExit.Click += (s, e) => form.Close();

            // Save settings on form closing
            // Handle window resizing for responsive layout
            void ResizeControls()
            {
                var margin = 10;
                var availableWidth = form.ClientSize.Width - (2 * margin);

                lblFile.Width = availableWidth;
                txtInput.Width = availableWidth;
                txtJa.Width = availableWidth;
                txtBack.Width = availableWidth;
                lblStatus.Width = Math.Max(400, availableWidth - 270);
                progress.Width = Math.Max(400, availableWidth - 270);
            }

            form.Resize += (s, e) => ResizeControls();

            form.FormClosing += (s, e) =>
            {
                SettingsService.SaveCurrentSettings(dark, GetSelectedProviderId(), form.Width, form.Height, form.Location.X, form.Location.Y);
            };

            form.KeyDown += (s, e) =>
            {
                if (e.Control && e.KeyCode == Keys.S) { e.SuppressKeyPress = true; saveBack(); }
                if (e.Control && e.KeyCode == Keys.C) { e.SuppressKeyPress = true; copyBack(); }
                if (e.Control && e.KeyCode == Keys.O) { e.SuppressKeyPress = true; importFile(); }
            };

            // Translation flow
            CancellationTokenSource? cts = null;

            void setStatus(string message)
            {
                lblStatus.Text = message;
                Logger.Info($"Status: {message}");
            }

            string GetSelectedProviderId()
            {
                return ProviderIds.Normalize(cmbProvider.SelectedValue?.ToString() ?? ProviderIds.GoogleUnofficial);
            }

            // Initialize settings and log them
            Logger.Debug($"Initial settings loaded: DarkMode={settings.DarkMode}, ProviderId={providerId}, WindowSize={settings.WindowWidth}x{settings.WindowHeight}, WindowPos=({settings.WindowX},{settings.WindowY}), LastFilePath='{settings.LastFilePath}', LastSavePath='{settings.LastSavePath}'");

            void setBusy(bool busy)
            {
                btnTranslate.Enabled = !busy;
                btnCancel.Enabled = busy;
                txtInput.Enabled = !busy;
                btnLoad.Enabled = !busy;
                btnCopy.Enabled = !busy;
                btnSave.Enabled = !busy;
                cmbProvider.Enabled = !busy;
                progress.Visible = busy;
            }

            btnCancel.Click += (s, e) =>
            {
                cts?.Cancel();
            };

            btnTranslate.Click += async (s, e) =>
            {
                var stopwatch = Stopwatch.StartNew();
                try
                {
                    setBusy(true);
                    cts = new CancellationTokenSource();
                    txtJa.Text = string.Empty;
                    txtBack.Text = string.Empty;

                    var input = txtInput.Text;
                    if (string.IsNullOrWhiteSpace(input))
                    {
                        MessageBox.Show("Please enter English text to translate.", "No input", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        setBusy(false);
                        Logger.Warn("Translation attempted with empty input.");
                        return;
                    }

                    var selectedProvider = GetSelectedProviderId();
                    Translator.ProviderId = selectedProvider;
                    Logger.Debug($"Translation initiated. Input length: {input.Length} chars. ProviderId={selectedProvider}");

                    setStatus("Translating to Japanese...");
                    var jaStopwatch = Stopwatch.StartNew();
                    var ja = await Translator.TranslateAsync(input, "en", "ja", cts.Token);
                    jaStopwatch.Stop();
                    txtJa.Text = ja;
                    Logger.Performance("Translation to Japanese", jaStopwatch.Elapsed);
                    Logger.Debug($"Japanese translation length: {ja.Length} chars");


                    setStatus("Translating back to English...");
                    var backStopwatch = Stopwatch.StartNew();
                    var back = await Translator.TranslateAsync(ja, "ja", "en", cts.Token);
                    backStopwatch.Stop();
                    txtBack.Text = back;
                    Logger.Performance("Translation back to English", backStopwatch.Elapsed);
                    Logger.Debug($"Back-translation length: {back.Length} chars");
                    lblStatus.ForeColor = System.Drawing.Color.Green;
                    setStatus("Done");

                    Logger.Info("Translation process completed successfully.");
                }
                catch (HttpRequestException hre)
                {
                    MessageBox.Show("Network/HTTP error: " + hre.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Logger.Error($"HTTP error during translation", hre);
                }
                catch (TaskCanceledException)
                {
                    setStatus("Cancelled");
                    Logger.Warn("Translation cancelled by user");
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Unexpected error: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Logger.Error($"Unexpected error during translation", ex);
                }
                finally
                {
                    stopwatch.Stop();
                    Logger.Performance("Total Translation Process", stopwatch.Elapsed);
                    setBusy(false);
                    cts?.Dispose();
                    cts = null;
                }
            };

            btnBatch.Click += (s, e) =>
            {
                using var fbd = new FolderBrowserDialog();
                if (fbd.ShowDialog() == DialogResult.OK)
                {
                    var selectedProvider = GetSelectedProviderId();
                    Translator.ProviderId = selectedProvider;

                    var batchProcessor = new BatchProcessor(Translator, (current, total) =>
                    {
                        form.Invoke((Action)(() =>
                        {
                            progress.Value = (int)((double)current / total * 100);
                            lblStatus.Text = $"Processing {current}/{total}...";
                        }));
                    });

                    Task.Run(() => batchProcessor.ProcessDirectoryAsync(fbd.SelectedPath));
                }
            };
            
            // Initialize and start the UI update timer

            Application.Run(form);
        }
    }
}
