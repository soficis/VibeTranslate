using Microsoft.UI.Xaml;
using System.Linq;

namespace TranslationFiesta.WinUI
{
    public static class ThemeService
    {
        public static void ApplyTheme(bool dark)
        {
            var app = Application.Current;
            if (app == null) return;
            var dictionaries = app.Resources.MergedDictionaries;
            var light = dictionaries.FirstOrDefault(d => d.Source?.OriginalString?.Contains("LightTheme.xaml") == true);
            var darkd = dictionaries.FirstOrDefault(d => d.Source?.OriginalString?.Contains("DarkTheme.xaml") == true);
            if (dark)
            {
                if (light != null) dictionaries.Remove(light);
                if (darkd != null && !dictionaries.Contains(darkd)) dictionaries.Add(darkd);
            }
            else
            {
                if (darkd != null) dictionaries.Remove(darkd);
                if (light != null && !dictionaries.Contains(light)) dictionaries.Add(light);
            }
        }
    }
}
