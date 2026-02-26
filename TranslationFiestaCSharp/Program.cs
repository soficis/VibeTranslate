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
        private const string AppDisplayName = "TranslationFiesta C#";

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

            var form = new Form
            {
                Text = AppDisplayName,
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

            // Common fonts
            var uiFont = new System.Drawing.Font("Segoe UI", 10f);
            var labelFont = new System.Drawing.Font("Segoe UI", 8.25f, System.Drawing.FontStyle.Bold);
            var titleFont = new System.Drawing.Font("Segoe UI", 14f, System.Drawing.FontStyle.Bold);
            var heroFont = new System.Drawing.Font("Segoe UI", 10f, System.Drawing.FontStyle.Bold);

            // Create controls with responsive sizing
            var pad = 24;
            var availableWidth = form.ClientSize.Width - (2 * pad);

            // Header row
            var lblTitle = new Label { Text = AppDisplayName, Left = pad, Top = yTop, Width = 320, Height = 28, Font = titleFont };
            var providerOptions = new[]
            {
                new ProviderOption { Id = ProviderIds.GoogleUnofficial, Name = "Google Translate (Unofficial / Free)" }
            };
            var cmbProvider = new ComboBox { Left = pad + 280, Top = yTop, Width = 280, Height = 28, DropDownStyle = ComboBoxStyle.DropDownList, Font = uiFont };
            cmbProvider.DataSource = providerOptions;
            cmbProvider.DisplayMember = "Name";
            cmbProvider.ValueMember = "Id";
            cmbProvider.SelectedValue = providerId;

            // Input section
            var lblInput = new Label { Text = "INPUT", Left = pad, Top = yTop + 40, Width = 100, Font = labelFont };
            var txtInput = new TextBox { Left = pad, Top = yTop + 58, Width = availableWidth, Height = 120, Multiline = true, ScrollBars = ScrollBars.Vertical, Font = uiFont };

            // Action row
            var actionTop = yTop + 188;
            var btnTranslate = new Button { Text = "\u29BF Backtranslate", Left = pad, Top = actionTop, Width = 160, Height = 36, Font = heroFont };
            var btnLoad = new Button { Text = "Import", Left = pad + 168, Top = actionTop, Width = 90, Height = 36, Font = uiFont };
            var btnSave = new Button { Text = "Save", Left = pad + 266, Top = actionTop, Width = 90, Height = 36, Font = uiFont };
            var btnCopy = new Button { Text = "Copy", Left = pad + 364, Top = actionTop, Width = 90, Height = 36, Font = uiFont };
            var btnBatch = new Button { Text = "Batch", Left = pad + 462, Top = actionTop, Width = 90, Height = 36, Font = uiFont };
            var btnCancel = new Button { Text = "Cancel", Left = pad + 560, Top = actionTop, Width = 90, Height = 36, Enabled = false, Font = uiFont };

            var lblStatus = new Label { Text = "Ready", Left = pad, Top = actionTop + 44, Width = availableWidth, Font = uiFont };
            var progress = new ProgressBar { Left = pad, Top = actionTop + 68, Width = availableWidth, Height = 4, Visible = false, Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 30 };

            // Side-by-side output panels
            var outputTop = actionTop + 80;
            var gap = 12;
            var panelWidth = (availableWidth - gap) / 2;

            var lblJa = new Label { Text = "INTERMEDIATE (JA)", Left = pad, Top = outputTop, Width = panelWidth, Font = labelFont };
            var txtJa = new TextBox { Left = pad, Top = outputTop + 18, Width = panelWidth, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true, Font = uiFont };

            var lblBack = new Label { Text = "RESULT (EN)", Left = pad + panelWidth + gap, Top = outputTop, Width = panelWidth, Font = labelFont };
            var txtBack = new TextBox { Left = pad + panelWidth + gap, Top = outputTop + 18, Width = panelWidth, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true, Font = uiFont };

            // Hidden controls (kept for compatibility)
            var btnTheme = new Button { Text = "", Width = 0, Height = 0, Visible = false };
            var lblFile = new Label { Text = "", Width = 0, Height = 0, Visible = false };
            var lblProvider = new Label { Text = "", Width = 0, Height = 0, Visible = false };

            form.Controls.AddRange(new Control[] { lblTitle, cmbProvider, lblInput, txtInput, btnTranslate, btnLoad, btnSave, btnCopy, btnBatch, btnCancel, lblStatus, progress, lblJa, txtJa, lblBack, txtBack, btnTheme, lblFile, lblProvider });

            var dark = true; // Always dark mode
            // Apply initial theme
            ApplyTheme();

            void ApplyTheme()
            {
                // Unified dark palette
                var bgColor = System.Drawing.Color.FromArgb(15, 20, 25);    // #0F1419
                var surface = System.Drawing.Color.FromArgb(26, 31, 46);    // #1A1F2E
                var elevated = System.Drawing.Color.FromArgb(36, 42, 56);    // #242A38
                var borderColor = System.Drawing.Color.FromArgb(46, 54, 72);    // #2E3648
                var textPrimary = System.Drawing.Color.FromArgb(232, 236, 241); // #E8ECF1
                var textSecondary = System.Drawing.Color.FromArgb(139, 149, 165); // #8B95A5
                var accent = System.Drawing.Color.FromArgb(59, 130, 246);  // #3B82F6
                var accentHover = System.Drawing.Color.FromArgb(37, 99, 235);   // #2563EB

                form.BackColor = bgColor;
                form.ForeColor = textPrimary;

                // Apply to all controls
                foreach (Control c in form.Controls)
                {
                    if (c is MenuStrip) continue;
                    c.BackColor = bgColor;
                    c.ForeColor = textPrimary;
                }

                // Section labels
                lblInput.ForeColor = textSecondary;
                lblJa.ForeColor = textSecondary;
                lblBack.ForeColor = textSecondary;
                lblStatus.ForeColor = textSecondary;

                // Text inputs
                txtInput.BackColor = surface;
                txtInput.ForeColor = textPrimary;
                txtInput.BorderStyle = BorderStyle.FixedSingle;
                txtJa.BackColor = surface;
                txtJa.ForeColor = textPrimary;
                txtJa.BorderStyle = BorderStyle.FixedSingle;
                txtBack.BackColor = surface;
                txtBack.ForeColor = textPrimary;
                txtBack.BorderStyle = BorderStyle.FixedSingle;

                // Provider combo
                cmbProvider.BackColor = surface;
                cmbProvider.ForeColor = textPrimary;
                cmbProvider.FlatStyle = FlatStyle.Flat;

                // Secondary buttons
                void StyleSecondary(Button btn)
                {
                    btn.BackColor = elevated;
                    btn.ForeColor = textPrimary;
                    btn.FlatStyle = FlatStyle.Flat;
                    btn.FlatAppearance.BorderColor = borderColor;
                    btn.FlatAppearance.BorderSize = 1;
                    btn.FlatAppearance.MouseOverBackColor = surface;
                }
                StyleSecondary(btnLoad);
                StyleSecondary(btnSave);
                StyleSecondary(btnCopy);
                StyleSecondary(btnBatch);
                StyleSecondary(btnCancel);

                // Hero button (Backtranslate)
                btnTranslate.BackColor = accent;
                btnTranslate.ForeColor = System.Drawing.Color.White;
                btnTranslate.FlatStyle = FlatStyle.Flat;
                btnTranslate.FlatAppearance.BorderSize = 0;
                btnTranslate.FlatAppearance.MouseOverBackColor = accentHover;

                // Menu
                menu.BackColor = bgColor;
                menu.ForeColor = textPrimary;
                menu.Renderer = new ToolStripProfessionalRenderer(new DarkColorTable());
            }

            btnTheme.Click += (s, e) =>
            {
                // Theme toggle disabled — always dark
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
                ofd.InitialDirectory = !string.IsNullOrWhiteSpace(settings.LastFilePath)
                    ? Path.GetDirectoryName(settings.LastFilePath) ?? PortablePaths.DataRoot
                    : PortablePaths.DataRoot;
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
                sfd.InitialDirectory = !string.IsNullOrWhiteSpace(settings.LastSavePath)
                    ? Path.GetDirectoryName(settings.LastSavePath) ?? PortablePaths.ExportsDirectory
                    : PortablePaths.ExportsDirectory;
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
                var pad = 24;
                var availableWidth = form.ClientSize.Width - (2 * pad);
                var yTop = menu.Height + 6;
                var gap = 12;
                var panelWidth = (availableWidth - gap) / 2;

                // Header
                cmbProvider.Left = pad + 280;
                cmbProvider.Width = Math.Min(280, availableWidth - 280);

                // Input
                txtInput.Width = availableWidth;
                var inputHeight = Math.Max(80, (form.ClientSize.Height - 360) / 3);
                txtInput.Height = inputHeight;

                // Action row
                var actionTop = txtInput.Top + txtInput.Height + 10;
                btnTranslate.Top = actionTop;
                btnLoad.Top = actionTop;
                btnSave.Top = actionTop;
                btnCopy.Top = actionTop;
                btnBatch.Top = actionTop;
                btnCancel.Top = actionTop;
                lblStatus.Top = actionTop + 44;
                lblStatus.Width = availableWidth;
                progress.Top = actionTop + 68;
                progress.Width = availableWidth;

                // Side-by-side outputs
                var outputTop = actionTop + 80;
                var outputHeight = Math.Max(80, form.ClientSize.Height - outputTop - 40);
                lblJa.Top = outputTop;
                lblJa.Width = panelWidth;
                txtJa.Left = pad;
                txtJa.Top = outputTop + 18;
                txtJa.Width = panelWidth;
                txtJa.Height = outputHeight;

                lblBack.Left = pad + panelWidth + gap;
                lblBack.Top = outputTop;
                lblBack.Width = panelWidth;
                txtBack.Left = pad + panelWidth + gap;
                txtBack.Top = outputTop + 18;
                txtBack.Width = panelWidth;
                txtBack.Height = outputHeight;
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

    /// <summary>
    /// Custom color table for dark-mode MenuStrip rendering.
    /// </summary>
    sealed class DarkColorTable : ProfessionalColorTable
    {
        public override System.Drawing.Color MenuStripGradientBegin => System.Drawing.Color.FromArgb(15, 20, 25);
        public override System.Drawing.Color MenuStripGradientEnd => System.Drawing.Color.FromArgb(15, 20, 25);
        public override System.Drawing.Color MenuItemSelected => System.Drawing.Color.FromArgb(36, 42, 56);
        public override System.Drawing.Color MenuItemSelectedGradientBegin => System.Drawing.Color.FromArgb(36, 42, 56);
        public override System.Drawing.Color MenuItemSelectedGradientEnd => System.Drawing.Color.FromArgb(36, 42, 56);
        public override System.Drawing.Color MenuItemBorder => System.Drawing.Color.FromArgb(46, 54, 72);
        public override System.Drawing.Color MenuBorder => System.Drawing.Color.FromArgb(46, 54, 72);
        public override System.Drawing.Color ImageMarginGradientBegin => System.Drawing.Color.FromArgb(26, 31, 46);
        public override System.Drawing.Color ImageMarginGradientEnd => System.Drawing.Color.FromArgb(26, 31, 46);
        public override System.Drawing.Color ImageMarginGradientMiddle => System.Drawing.Color.FromArgb(26, 31, 46);
        public override System.Drawing.Color ToolStripDropDownBackground => System.Drawing.Color.FromArgb(26, 31, 46);
        public override System.Drawing.Color SeparatorDark => System.Drawing.Color.FromArgb(46, 54, 72);
        public override System.Drawing.Color SeparatorLight => System.Drawing.Color.FromArgb(46, 54, 72);
    }
}
