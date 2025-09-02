using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace FreeTranslateWin
{
    static class Program
    {
        // single HttpClient for the app
        static readonly HttpClient http = new HttpClient();

        // Translate using the unofficial public endpoint. No API key.
        static async Task<string> TranslateAsync(string text, string source, string target)
        {
            if (string.IsNullOrWhiteSpace(text)) return string.Empty;
            var q = Uri.EscapeDataString(text);
            var url = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source}&tl={target}&dt=t&q={q}";
            using var resp = await http.GetAsync(url).ConfigureAwait(false);
            resp.EnsureSuccessStatusCode();
            var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);

            using var doc = JsonDocument.Parse(body);
            var root = doc.RootElement;
            if (root.ValueKind != JsonValueKind.Array) return string.Empty;
            if (!root[0].ValueKind.Equals(JsonValueKind.Array)) return string.Empty;

            var sb = new StringBuilder();
            foreach (var sentence in root[0].EnumerateArray())
            {
                if (sentence.ValueKind == JsonValueKind.Array && sentence.GetArrayLength() > 0)
                {
                    var part = sentence[0].GetString();
                    if (!string.IsNullOrEmpty(part)) sb.Append(part);
                }
            }
            return sb.ToString();
        }

        [STAThread]
        static void Main()
        {
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var form = new Form { Text = "Backtranslate (Free Google) - English ↔ Japanese", Width = 820, Height = 700 };

            var lblInput = new Label { Text = "Input (English):", Left = 10, Top = 14, Width = 200 };
            var txtInput = new TextBox { Left = 10, Top = 36, Width = 780, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical };

            var btn = new Button { Text = "Backtranslate", Left = 10, Top = 210, Width = 140 };
            var lblStatus = new Label { Text = "Ready", Left = 160, Top = 215, Width = 630 };

            var lblJa = new Label { Text = "Japanese (intermediate):", Left = 10, Top = 246, Width = 300 };
            var txtJa = new TextBox { Left = 10, Top = 268, Width = 780, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var lblBack = new Label { Text = "Back to English:", Left = 10, Top = 436, Width = 200 };
            var txtBack = new TextBox { Left = 10, Top = 458, Width = 780, Height = 160, Multiline = true, ScrollBars = ScrollBars.Vertical, ReadOnly = true };

            var btnCopy = new Button { Text = "Copy Back", Left = 10, Top = 626, Width = 100 };
            var btnSave = new Button { Text = "Save Back...", Left = 120, Top = 626, Width = 120 };

            form.Controls.AddRange(new Control[] { lblInput, txtInput, btn, lblStatus, lblJa, txtJa, lblBack, txtBack, btnCopy, btnSave });

            btn.Click += async (s, e) =>
            {
                try
                {
                    btn.Enabled = false;
                    txtInput.Enabled = false;
                    lblStatus.Text = "Translating to Japanese...";
                    txtJa.Text = string.Empty;
                    txtBack.Text = string.Empty;

                    var input = txtInput.Text;
                    if (string.IsNullOrWhiteSpace(input))
                    {
                        MessageBox.Show("Please enter English text to translate.", "No input", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                        return;
                    }

                    var ja = await TranslateAsync(input, "en", "ja");
                    txtJa.Text = ja;

                    lblStatus.Text = "Translating back to English...";
                    var back = await TranslateAsync(ja, "ja", "en");
                    txtBack.Text = back;

                    lblStatus.Text = "Done";
                }
                catch (HttpRequestException hre)
                {
                    MessageBox.Show($"Network/HTTP error: {hre.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                catch (Exception ex)
                {
                    MessageBox.Show($"Unexpected error: {ex.Message}", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
                finally
                {
                    btn.Enabled = true;
                    txtInput.Enabled = true;
                }
            };

            btnCopy.Click += (s, e) => { if (!string.IsNullOrEmpty(txtBack.Text)) Clipboard.SetText(txtBack.Text); };
            btnSave.Click += (s, e) =>
            {
                using var dlg = new SaveFileDialog { Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*", FileName = "backtranslation.txt" };
                if (dlg.ShowDialog() == DialogResult.OK)
                    System.IO.File.WriteAllText(dlg.FileName, txtBack.Text ?? string.Empty, Encoding.UTF8);
            };

            Application.Run(form);
        }
    }
}
