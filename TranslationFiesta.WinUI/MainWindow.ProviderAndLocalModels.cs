using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace TranslationFiesta.WinUI
{
    public sealed partial class MainWindow
    {
        private void InitializeProviderSelector()
        {
            var providers = new List<ProviderOption>
            {
                new ProviderOption { Id = ProviderIds.Local, Name = "Local (Offline)" },
                new ProviderOption { Id = ProviderIds.GoogleUnofficial, Name = "Google Translate (Unofficial / Free)" }
            };

            ProviderCombo.ItemsSource = providers;
            ProviderCombo.DisplayMemberPath = "Name";
            ProviderCombo.SelectedValuePath = "Id";

            var providerId = ProviderIds.Normalize(_settings.ProviderId);
            _settings.ProviderId = providerId;
            ProviderCombo.SelectedValue = providerId;

            ProviderCombo.SelectionChanged += ProviderCombo_SelectionChanged;

            ApplyProviderSelection();
        }

        private void ProviderCombo_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            var providerId = ProviderIds.Normalize(ProviderCombo.SelectedValue?.ToString());
            _settings.ProviderId = providerId;
            SettingsService.Save(_settings);
            ApplyProviderSelection();
        }

        private async void LocalModelsButton_Click(object sender, RoutedEventArgs e)
        {
            await ShowLocalModelsDialogAsync();
        }

        private async Task ShowLocalModelsDialogAsync()
        {
            var serviceUrlBox = new TextBox
            {
                Text = _settings.LocalServiceUrl ?? string.Empty,
                PlaceholderText = "http://127.0.0.1:5055"
            };
            var modelDirBox = new TextBox
            {
                Text = _settings.LocalModelDir ?? string.Empty,
                PlaceholderText = "Override model directory (optional)"
            };
            var autoStartToggle = new ToggleSwitch
            {
                Header = "Auto-start local service",
                IsOn = _settings.LocalAutoStart
            };
            var statusBox = new TextBox
            {
                IsReadOnly = true,
                TextWrapping = TextWrapping.Wrap,
                AcceptsReturn = true,
                MinHeight = 120
            };

            var refreshButton = new Button { Content = "Refresh" };
            var verifyButton = new Button { Content = "Verify" };
            var removeButton = new Button { Content = "Remove" };

            async Task UpdateStatusAsync(Func<CancellationToken, Task<string>> action)
            {
                try
                {
                    statusBox.Text = "Working...";
                    var body = await action(CancellationToken.None);
                    statusBox.Text = body;
                }
                catch (Exception ex)
                {
                    statusBox.Text = ex.Message;
                }
            }

            refreshButton.Click += async (_, __) => await UpdateStatusAsync(_modelsClient.GetModelsStatusAsync);
            verifyButton.Click += async (_, __) => await UpdateStatusAsync(_modelsClient.VerifyModelsAsync);
            removeButton.Click += async (_, __) => await UpdateStatusAsync(_modelsClient.RemoveModelsAsync);
            var installButton = new Button { Content = "Install Default" };
            installButton.Click += async (_, __) => await UpdateStatusAsync(_modelsClient.InstallDefaultModelsAsync);

            var actionsRow = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Spacing = 8,
                Children = { refreshButton, verifyButton, removeButton, installButton }
            };

            var panel = new StackPanel
            {
                Spacing = 12,
                Children =
                {
                    new TextBlock { Text = "Service URL" },
                    serviceUrlBox,
                    new TextBlock { Text = "Model Directory" },
                    modelDirBox,
                    autoStartToggle,
                    new TextBlock { Text = "Model Status" },
                    statusBox,
                    actionsRow
                }
            };

            var dialog = new ContentDialog
            {
                Title = "Local Model Manager",
                Content = panel,
                PrimaryButtonText = "Save",
                CloseButtonText = "Close",
                XamlRoot = Content.XamlRoot
            };

            dialog.PrimaryButtonClick += (_, __) =>
            {
                _settings.LocalServiceUrl = serviceUrlBox.Text.Trim();
                _settings.LocalModelDir = modelDirBox.Text.Trim();
                _settings.LocalAutoStart = autoStartToggle.IsOn;
                SettingsService.Save(_settings);
                ApplyLocalSettings(_settings);
            };

            await dialog.ShowAsync();
            await UpdateStatusAsync(_modelsClient.GetModelsStatusAsync);
        }

        private void ApplyProviderSelection()
        {
            var providerId = ProviderIds.Normalize(ProviderCombo.SelectedValue?.ToString());
            _translator.ProviderId = providerId;
        }
    }
}
