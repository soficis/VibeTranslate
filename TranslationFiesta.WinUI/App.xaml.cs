using Microsoft.UI.Xaml;
using System;

namespace TranslationFiesta.WinUI
{
    public partial class App : Application
    {
        public App()
        {
            try
            {
                // Initialize logger safely
                Logger.Initialize();
                Logger.Info("App constructor starting.");
            }
            catch (Exception ex)
            {
                // If logger fails, continue without logging
                Console.WriteLine($"Logger initialization failed: {ex.Message}");
            }

            this.InitializeComponent();
        }

        protected override void OnLaunched(Microsoft.UI.Xaml.LaunchActivatedEventArgs args)
        {
            try
            {
                Logger.Info("App.OnLaunched called.");
                m_window = new MainWindow();
                m_window.Activate();
                Logger.Info("MainWindow created and activated.");
            }
            catch (Exception ex)
            {
                Logger.Error($"Failed to create main window: {ex.Message}", ex);
                // Fallback: try to show a basic window
                m_window = new Microsoft.UI.Xaml.Window();
                m_window.Title = "Translation Fiesta - Error";
                m_window.Activate();
            }
        }

        private Microsoft.UI.Xaml.Window? m_window;
    }
}
