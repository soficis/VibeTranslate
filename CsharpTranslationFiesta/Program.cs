using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;
using System.Text.RegularExpressions;
using System.IO;

namespace CsharpTranslationFiesta
{
    static class Program
    {
        // HTML text extraction functions (similar to F# version)
        static string ExtractTextFromHtml(string htmlContent)
        {
            try
            {
                // Remove script, style, code, and pre blocks using regex
                var scriptPattern = "<script[^>]*>.*?</script>";
                var stylePattern = "<style[^>]*>.*?</style>";
                var codePattern = "<code[^>]*>.*?</code>";
                var prePattern = "<pre[^>]*>.*?</pre>";

                var withoutScripts = Regex.Replace(htmlContent, scriptPattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutStyles = Regex.Replace(withoutScripts, stylePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutCode = Regex.Replace(withoutStyles, codePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutPre = Regex.Replace(withoutCode, prePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);

                // Remove all remaining HTML tags
                var tagPattern = "<[^>]+>";
                var withoutTags = Regex.Replace(withoutPre, tagPattern, "");

                // Normalize whitespace
                var normalized = Regex.Replace(withoutTags, @"\s+", " ");
                return normalized.Trim();
            }
            catch (Exception ex)
            {
                Logger.Error($"HTML parsing failed: {ex.Message}");
                return htmlContent; // Fallback to raw content
            }
        }

        // File loading function that handles different file types (similar to F# version)
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
                        return rawContent.Trim();
                    default:
                        return rawContent.Trim(); // Default to plain text
                }
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to load file {filePath}: {ex.Message}");
                throw;
            }
        }
    // Use TranslationClient for parsing and HTTP
    static readonly TranslationClient Translator = new TranslationClient();

        [STAThread]
        static void Main()
        {
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var form = new Form { Text = "TranslationFiesta - English ↔ Japanese", Width = 900, Height = 850, KeyPreview = true };

            // Menu
            var menu = new MenuStrip();
            var fileMenu = new ToolStripMenuItem("File");
            var miImport = new ToolStripMenuItem("Import File (.txt, .md, .html)") { ShortcutKeys = Keys.Control | Keys.O };
            var miSaveBack = new ToolStripMenuItem("Save Back") { ShortcutKeys = Keys.Control | Keys.S };
            var miCopyBack = new ToolStripMenuItem("Copy Back") { ShortcutKeys = Keys.Control | Keys.C };
            var miExit = new ToolStripMenuItem("Exit") { ShortcutKeys = Keys.Alt | Keys.F4 };
            fileMenu.DropDownItems.AddRange(new ToolStripItem[] { miImport, miSaveBack, miCopyBack, new ToolStripSeparator(), miExit });
            menu.Items.Add(fileMenu);
            form.MainMenuStrip = menu;
            form.Controls.Add(menu);

            // layout helpers under menu
            var yTop = menu.Height + 6;

            // toolbar
            var btnTheme = new Button { Text = "Dark", Left = 10, Top = yTop, Width = 80 };
            var btnLoad = new Button { Text = "Load File", Left = 100, Top = yTop, Width = 100 };
            var chkOfficial = new CheckBox { Text = "Use Official API", Left = 210, Top = yTop + 3, Width = 140 };
            var lblKey = new Label { Text = "API Key:", Left = 360, Top = yTop + 5, Width = 60 };
            var txtApiKey = new TextBox { Left = 420, Top = yTop + 2, Width = 250, UseSystemPasswordChar = true, Enabled = false };
            var lblFile = new Label { Text = "", Left = 10, Top = yTop + 34, Width = 860 };

            var lblInput = new Label { Text = "Input (English):", Left = 10, Top = yTop + 60, Width = 200 };
            var txtInput = new TextBox { Left = 10, Top = yTop + 82, Width = 860, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical };

            var btnTranslate = new Button { Text = "Backtranslate", Left = 10, Top = yTop + 272, Width = 140 };
            var btnCancel = new Button { Text = "Cancel", Left = 160, Top = yTop + 272, Width = 100, Enabled = false };
            var lblStatus = new Label { Text = "Ready", Left = 270, Top = yTop + 277, Width = 600 };
            var progress = new ProgressBar { Left = 270, Top = yTop + 298, Width = 600, Height = 10, Visible = false, Style = ProgressBarStyle.Marquee, MarqueeAnimationSpeed = 30 };

            var lblJa = new Label { Text = "Japanese (intermediate):", Left = 10, Top = yTop + 318, Width = 300 };
            var txtJa = new TextBox { Left = 10, Top = yTop + 340, Width = 860, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var lblBack = new Label { Text = "Back to English:", Left = 10, Top = yTop + 530, Width = 200 };
            var txtBack = new TextBox { Left = 10, Top = yTop + 552, Width = 860, Height = 180, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var btnCopy = new Button { Text = "Copy Back", Left = 10, Top = yTop + 742, Width = 100 };
            var btnSave = new Button { Text = "Save Back...", Left = 120, Top = yTop + 742, Width = 120 };

            form.Controls.AddRange(new Control[] { btnTheme, btnLoad, chkOfficial, lblKey, txtApiKey, lblFile, lblInput, txtInput, btnTranslate, btnCancel, lblStatus, progress, lblJa, txtJa, lblBack, txtBack, btnCopy, btnSave });

            var dark = false;
            btnTheme.Click += (s, e) =>
            {
                dark = !dark;
                btnTheme.Text = dark ? "Light" : "Dark";
                var bg = dark ? System.Drawing.Color.FromArgb(45, 45, 48) : System.Drawing.SystemColors.Control;
                var fg = dark ? System.Drawing.Color.White : System.Drawing.Color.Black;
                form.BackColor = bg;
                foreach (Control c in form.Controls)
                {
                    c.BackColor = bg;
                    c.ForeColor = fg;
                }
                txtInput.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtInput.ForeColor = fg;
                txtJa.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtJa.ForeColor = fg;
                txtBack.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtBack.ForeColor = fg;
                txtApiKey.BackColor = dark ? System.Drawing.Color.FromArgb(30, 30, 30) : System.Drawing.Color.White;
                txtApiKey.ForeColor = fg;
            };

            // Official API toggle
            chkOfficial.CheckedChanged += (s, e) =>
            {
                txtApiKey.Enabled = chkOfficial.Checked;
            };

            // File import (enhanced to support .txt, .md, .html like F# version)
            Action importFile = () =>
            {
                using var ofd = new OpenFileDialog();
                ofd.Filter = "Supported files (*.txt;*.md;*.html)|*.txt;*.md;*.html|Text files (*.txt)|*.txt|Markdown files (*.md)|*.md|HTML files (*.html)|*.html|All files (*.*)|*.*";
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
                            default:
                                statusMsg = $"Loaded: {fileName}";
                                break;
                        }

                        lblFile.Text = statusMsg;
                        setStatus(statusMsg, "green");
                        Logger.Info($"Successfully imported file: {ofd.FileName}");
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show("Failed to load file: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        setStatus("File import failed", "red");
                        Logger.Error($"File import failed: {ex.Message}");
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
                    System.IO.File.WriteAllText(sfd.FileName, txtBack.Text ?? string.Empty, Encoding.UTF8);
                    Logger.Info($"Saved back-translation to '{sfd.FileName}'");
                }
            };
            btnSave.Click += (s, e) => saveBack();
            miSaveBack.Click += (s, e) => saveBack();

            miExit.Click += (s, e) => form.Close();

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

            void setBusy(bool busy)
            {
                btnTranslate.Enabled = !busy;
                btnCancel.Enabled = busy;
                txtInput.Enabled = !busy;
                btnLoad.Enabled = !busy;
                btnCopy.Enabled = !busy;
                btnSave.Enabled = !busy;
                chkOfficial.Enabled = !busy;
                txtApiKey.Enabled = !busy && chkOfficial.Checked;
                progress.Visible = busy;
            }

            btnCancel.Click += (s, e) =>
            {
                cts?.Cancel();
            };

            btnTranslate.Click += async (s, e) =>
            {
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
                        return;
                    }

                    Translator.OfficialApiKey = chkOfficial.Checked ? (string.IsNullOrWhiteSpace(txtApiKey.Text) ? null : txtApiKey.Text) : null;

                    setStatus("Translating to Japanese...");
                    var ja = await Translator.TranslateAsync(input, "en", "ja", cts.Token);
                    txtJa.Text = ja;

                    setStatus("Translating back to English...");
                    var back = await Translator.TranslateAsync(ja, "ja", "en", cts.Token);
                    txtBack.Text = back;

                    setStatus("Done");
                }
                catch (HttpRequestException hre)
                {
                    MessageBox.Show("Network/HTTP error: " + hre.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Logger.Error($"HTTP error: {hre.Message}");
                }
                catch (TaskCanceledException)
                {
                    setStatus("Cancelled");
                    Logger.Warn("Translation cancelled by user");
                }
                catch (Exception ex)
                {
                    MessageBox.Show("Unexpected error: " + ex.Message, "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    Logger.Error($"Unexpected error: {ex}");
                }
                finally
                {
                    setBusy(false);
                    cts?.Dispose();
                    cts = null;
                }
            };

            Application.Run(form);
        }
    }
}
