using System;
using Microsoft.UI.Xaml;

namespace TranslationFiesta.WinUI
{
    public static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            WinRT.ComWrappersSupport.InitializeComWrappers();
            Application.Start((p) => new App());
        }
    }
}
