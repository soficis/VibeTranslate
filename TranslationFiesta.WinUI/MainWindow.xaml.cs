using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Input;
using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using System.IO;
using System.Security.Cryptography;

namespace TranslationFiesta.WinUI
{
    public partial class MainWindow : Window
    {
        private static readonly HttpClient http = new HttpClient();

        public MainWindow()
        {
            this.InitializeComponent();

            // populate languages
            var langs = new (string Code, string Name)[]
            {
                ("auto","Auto-detect"),("en","English"),("ja","Japanese"),("es","Spanish"),("fr","French"),("de","German"),("zh-CN","Chinese (Simplified)")
            };
            foreach (var l in langs)
            {
                CmbSource.Items.Add(new ComboBoxItem { Tag = l.Code, Content = l.Name });
                CmbTarget.Items.Add(new ComboBoxItem { Tag = l.Code, Content = l.Name });
            }
            CmbSource.SelectedIndex = 0;
            CmbTarget.SelectedIndex = 1;

            // Load persisted settings and API key
            try
            {
                var s = SettingsService.Load();
                if (!string.IsNullOrEmpty(s.LastSource))
                {
                    var idx = FindIndexByTag(CmbSource, s.LastSource);
                    if (idx >= 0) CmbSource.SelectedIndex = idx;
                }
                if (!string.IsNullOrEmpty(s.LastTarget))
                {
                    var idx = FindIndexByTag(CmbTarget, s.LastTarget);
                    if (idx >= 0) CmbTarget.SelectedIndex = idx;
                }
                TglTheme.IsOn = s.DarkMode;
            }
            catch { }

            try
            {
                var existingKey = SecureStore.GetApiKey();
                if (!string.IsNullOrEmpty(existingKey)) TxtApiKey.Text = existingKey;
            }
            catch { }

            BtnBacktranslate.Click += async (_, __) => await RunBacktranslateAsync();
            BtnCopy.Click += (_, __) => CopyResult();
            BtnSave.Click += async (_, __) => await SaveResultAsync();

            // shortcuts
            var copy = new Microsoft.UI.Xaml.Input.KeyboardAccelerator { Key = Windows.System.VirtualKey.C, Modifiers = Windows.System.VirtualKeyModifiers.Control };
            copy.Invoked += (s, e) => CopyResult();
            this.KeyboardAccelerators.Add(copy);

            var save = new Microsoft.UI.Xaml.Input.KeyboardAccelerator { Key = Windows.System.VirtualKey.S, Modifiers = Windows.System.VirtualKeyModifiers.Control };
            save.Invoked += async (s, e) => await SaveResultAsync();
            this.KeyboardAccelerators.Add(save);

            TglTheme.Toggled += (_, __) =>
            {
                SetTheme(TglTheme.IsOn);
                ThemeService.ApplyTheme(TglTheme.IsOn);
            };

            // Save API key when the user leaves the textbox
            TxtApiKey.LostFocus += (_, __) =>
            {
                try
                {
                    var key = TxtApiKey.Text?.Trim();
                    if (!string.IsNullOrEmpty(key)) SecureStore.SaveApiKey(key);
                }
                catch { }
            };

            // Persist settings on close
            this.Closed += (_, __) =>
            {
                try
                {
                    var s = new AppSettings();
                    var src = (CmbSource.SelectedItem as ComboBoxItem)?.Tag as string;
                    var tgt = (CmbTarget.SelectedItem as ComboBoxItem)?.Tag as string;
                    s.LastSource = src;
                    s.LastTarget = tgt;
                    s.DarkMode = TglTheme.IsOn;
                    SettingsService.Save(s);
                }
                catch { }
            };

            Logger.Info("WinUI MainWindow initialized");
        }

        private void SetTheme(bool dark)
        {
            this.RequestedTheme = dark ? ElementTheme.Dark : ElementTheme.Light;
            ThemeService.ApplyTheme(dark);
        }

        private void CopyResult()
        {
            var text = TxtResult.Text;
            if (!string.IsNullOrEmpty(text))
            {
                var dataPackage = new Windows.ApplicationModel.DataTransfer.DataPackage();
                dataPackage.SetText(text);
                Windows.ApplicationModel.DataTransfer.Clipboard.SetContent(dataPackage);
                Logger.Info("Copied result to clipboard");
            }
        }

        private async Task SaveResultAsync()
        {
            var picker = new Windows.Storage.Pickers.FileSavePicker();
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
            picker.SuggestedStartLocation = Windows.Storage.Pickers.PickerLocationId.DocumentsLibrary;
            picker.FileTypeChoices.Add("Plain Text", new[] { ".txt" });
            picker.SuggestedFileName = "translation.txt";
            var file = await picker.PickSaveFileAsync();
            if (file != null)
            {
                await Windows.Storage.FileIO.WriteTextAsync(file, TxtResult.Text);
                Logger.Info($"Saved result to {file.Path}");
            }
        }

        // Simple translate using unofficial endpoint or official depending on toggle
        private async Task<string> TranslateAsync(string text, string source, string target)
        {
            if (TglEndpoint.IsOn)
            {
                var apiKey = SecureStore.GetApiKey();
                if (string.IsNullOrEmpty(apiKey)) throw new InvalidOperationException("API key is required for official endpoint.");
                var url = $"https://translation.googleapis.com/language/translate/v2?key={Uri.EscapeDataString(apiKey)}";
                var payload = JsonSerializer.Serialize(new { q = new[] { text }, target = target, source = source == "auto" ? null : source, format = "text" });
                using var content = new StringContent(payload, Encoding.UTF8, "application/json");
                using var resp = await http.PostAsync(url, content).ConfigureAwait(false);
                var body = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
                if (!resp.IsSuccessStatusCode) throw new HttpRequestException(body);
                using var doc = JsonDocument.Parse(body);
                return doc.RootElement.GetProperty("data").GetProperty("translations")[0].GetProperty("translatedText").GetString() ?? string.Empty;
            }
            else
            {
                var q = Uri.EscapeDataString(text);
                var url2 = $"https://translate.googleapis.com/translate_a/single?client=gtx&sl={source}&tl={target}&dt=t&q={q}";
                using var resp2 = await http.GetAsync(url2).ConfigureAwait(false);
                resp2.EnsureSuccessStatusCode();
                var bodyStr = await resp2.Content.ReadAsStringAsync().ConfigureAwait(false);
                using var doc2 = JsonDocument.Parse(bodyStr);
                var root = doc2.RootElement;
                var sb = new StringBuilder();
                foreach (var sentence in root[0].EnumerateArray())
                {
                    sb.Append(sentence[0].GetString());
                }
                return sb.ToString();
            }
        }

        private async Task RunBacktranslateAsync()
        {
            try
            {
                PrgSpinner.IsActive = true;
                BtnBacktranslate.IsEnabled = false;
                var input = TxtInput.Text ?? string.Empty;
                if (string.IsNullOrWhiteSpace(input)) return;
                var src = ((ComboBoxItem)CmbSource.SelectedItem).Tag as string ?? "auto";
                var tgt = ((ComboBoxItem)CmbTarget.SelectedItem).Tag as string ?? "en";
                if (TglAutoDetect.IsOn) src = "auto";
                var translated = await TranslateAsync(input, src, tgt);
                TxtResult.Text = translated;
                var back = await TranslateAsync(translated, tgt, "en");
                TxtResult.Text = back;
            }
            catch (Exception ex)
            {
                Logger.Error($"Backtranslate failed: {ex.Message}");
                var dlg = new ContentDialog { Title = "Error", Content = ex.Message, CloseButtonText = "OK" };
                await dlg.ShowAsync();
            }
            finally
            {
                PrgSpinner.IsActive = false;
                BtnBacktranslate.IsEnabled = true;
            }
        }

        private int FindIndexByTag(ComboBox cmb, string tag)
        {
            for (int i = 0; i < cmb.Items.Count; i++)
            {
                if (cmb.Items[i] is ComboBoxItem cbi && (cbi.Tag as string) == tag) return i;
            }
            return -1;
        }
    }
}
