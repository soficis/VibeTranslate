using System.Collections.Generic;
using Microsoft.UI.Xaml.Controls;

namespace TranslationFiesta.WinUI
{
    public sealed partial class MainWindow
    {
        private void InitializeProviderSelector()
        {
            var providers = new List<ProviderOption>
            {
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

        private void ApplyProviderSelection()
        {
            var providerId = ProviderIds.Normalize(ProviderCombo.SelectedValue?.ToString());
            _translator.ProviderId = providerId;
        }
    }
}
