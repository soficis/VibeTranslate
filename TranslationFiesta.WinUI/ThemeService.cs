using Microsoft.UI.Xaml;

namespace TranslationFiesta.WinUI
{
    public static class ThemeService
    {
        public static void ApplyTheme(bool dark)
        {
            var dictionaries = Application.Current?.Resources?.MergedDictionaries;
            if (dictionaries == null) return;

            ResourceDictionary? light = null;
            ResourceDictionary? darkDict = null;
            foreach (var d in dictionaries)
            {
                var src = d.Source?.OriginalString ?? string.Empty;
                if (src.Contains("LightTheme.xaml")) light = d;
                if (src.Contains("DarkTheme.xaml")) darkDict = d;
            }

            if (dark)
            {
                if (light != null) dictionaries.Remove(light);
                if (darkDict != null && !dictionaries.Contains(darkDict)) dictionaries.Add(darkDict);
            }
            else
            {
                if (darkDict != null) dictionaries.Remove(darkDict);
                if (light != null && !dictionaries.Contains(light)) dictionaries.Add(light);
            }
        }
    }
}
