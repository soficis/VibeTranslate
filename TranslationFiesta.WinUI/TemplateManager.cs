using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace TranslationFiesta.WinUI;

public class TranslationTemplate
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public bool IsDefault { get; set; } = false;
}

public class TemplateManager
{
    private readonly string _templatesFilePath;
    private List<TranslationTemplate> _templates;

    public TemplateManager()
    {
        var appDataPath = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
        var appName = "TranslationFiesta";
        var templatesDirectory = Path.Combine(appDataPath, appName, "Templates");
        Directory.CreateDirectory(templatesDirectory);
        _templatesFilePath = Path.Combine(templatesDirectory, "templates.json");
        _templates = new List<TranslationTemplate>();
    }

    public async Task LoadTemplatesAsync()
    {
        try
        {
            if (File.Exists(_templatesFilePath))
            {
                var json = await File.ReadAllTextAsync(_templatesFilePath);
                _templates = JsonSerializer.Deserialize<List<TranslationTemplate>>(json) ?? new List<TranslationTemplate>();
            }
            else
            {
                _templates = GetDefaultTemplates();
                await SaveTemplatesAsync();
            }
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to load templates: {ex.Message}");
            _templates = GetDefaultTemplates();
        }
    }

    public async Task SaveTemplatesAsync()
    {
        try
        {
            var json = JsonSerializer.Serialize(_templates, new JsonSerializerOptions { WriteIndented = true });
            await File.WriteAllTextAsync(_templatesFilePath, json);
        }
        catch (Exception ex)
        {
            Logger.Error($"Failed to save templates: {ex.Message}");
        }
    }

    public List<TranslationTemplate> GetTemplates() => _templates;

    public async Task AddTemplateAsync(TranslationTemplate template)
    {
        _templates.Add(template);
        await SaveTemplatesAsync();
    }

    public async Task UpdateTemplateAsync(TranslationTemplate template)
    {
        var existingTemplate = _templates.Find(t => t.Id == template.Id);
        if (existingTemplate != null)
        {
            existingTemplate.Name = template.Name;
            existingTemplate.Description = template.Description;
            existingTemplate.Content = template.Content;
            await SaveTemplatesAsync();
        }
    }

    public async Task DeleteTemplateAsync(Guid templateId)
    {
        var template = _templates.Find(t => t.Id == templateId);
        if (template != null && !template.IsDefault)
        {
            _templates.Remove(template);
            await SaveTemplatesAsync();
        }
    }

    public string ApplyTemplate(string original, string translation, string sourceLang, string targetLang, double? bleuScore, int? qualityRating, TranslationTemplate template)
    {
        var content = template.Content;
        content = content.Replace("{original}", original);
        content = content.Replace("{translation}", translation);
        content = content.Replace("{source_lang}", sourceLang);
        content = content.Replace("{target_lang}", targetLang);
        content = content.Replace("{date}", DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"));
        content = content.Replace("{bleu_score}", bleuScore?.ToString("F2") ?? "N/A");
        content = content.Replace("{quality_rating}", qualityRating?.ToString() ?? "N/A");
        return content;
    }

    private List<TranslationTemplate> GetDefaultTemplates()
    {
        return new List<TranslationTemplate>
        {
            new()
            {
                Id = Guid.NewGuid(),
                Name = "Professional Report",
                Description = "A formal report template for professional use.",
                Content = "Source ({source_lang}): {original}\nTarget ({target_lang}): {translation}\nDate: {date}\nBLEU Score: {bleu_score}\nQuality Rating: {quality_rating}/5",
                IsDefault = true
            },
            new()
            {
                Id = Guid.NewGuid(),
                Name = "Simple Translation List",
                Description = "A simple list of original and translated text.",
                Content = "{original} => {translation}",
                IsDefault = true
            },
            new()
            {
                Id = Guid.NewGuid(),
                Name = "Quality Assessment",
                Description = "Template for quality assessment reports.",
                Content = "## Quality Assessment Report\n\n- **Source Text**: {original}\n- **Translated Text**: {translation}\n- **Source Language**: {source_lang}\n- **Target Language**: {target_lang}\n- **BLEU Score**: {bleu_score}\n- **Quality Rating**: {quality_rating}",
                IsDefault = true
            }
        };
    }
}