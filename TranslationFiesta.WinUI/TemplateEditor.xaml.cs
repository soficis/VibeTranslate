using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;

namespace TranslationFiesta.WinUI
{
    public sealed partial class TemplateEditor : Window
    {
        private readonly TemplateManager _templateManager;
        private TranslationTemplate _currentTarget;

        public TemplateEditor(TemplateManager templateManager, TranslationTemplate? template = null)
        {
            this.InitializeComponent();
            _templateManager = templateManager;
            _currentTarget = template ?? new TranslationTemplate();

            if (template != null)
            {
                TemplateNameTextBox.Text = template.Name;
                TemplateDescriptionTextBox.Text = template.Description;
                TemplateContentTextBox.Text = template.Content;
            }
        }

        private async void SaveButton_Click(object sender, RoutedEventArgs e)
        {
            _currentTarget.Name = TemplateNameTextBox.Text;
            _currentTarget.Description = TemplateDescriptionTextBox.Text;
            _currentTarget.Content = TemplateContentTextBox.Text;

            if (_currentTarget.Id == Guid.Empty)
            {
                _currentTarget.Id = Guid.NewGuid();
                await _templateManager.AddTemplateAsync(_currentTarget);
            }
            else
            {
                await _templateManager.UpdateTemplateAsync(_currentTarget);
            }
            this.Close();
        }

        private void CancelButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void VariableButton_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button button)
            {
                string token = string.Empty;

                if (button.Tag is string tag && !string.IsNullOrWhiteSpace(tag))
                {
                    token = $"{{{tag.Trim()}}}";
                }
                else if (button.Content?.ToString() is string content && !string.IsNullOrWhiteSpace(content))
                {
                    token = content;
                }

                if (string.IsNullOrWhiteSpace(token))
                {
                    return;
                }

                var selectionStart = TemplateContentTextBox.SelectionStart;
                var currentText = TemplateContentTextBox.Text ?? string.Empty;
                TemplateContentTextBox.Text = currentText.Insert(selectionStart, token);
                TemplateContentTextBox.SelectionStart = selectionStart + token.Length;
            }
        }

        private void TemplateContentTextBox_TextChanged(object sender, TextChangedEventArgs e)
        {
            UpdatePreview();
        }

        private void UpdatePreview()
        {
            var previewTemplate = new TranslationTemplate { Content = TemplateContentTextBox.Text };
            PreviewTextBlock.Text = _templateManager.ApplyTemplate(
                "Sample original text.",
                "Sample translated text.",
                "en-US",
                "es-ES",
                previewTemplate);
        }
    }
}
