using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
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
                // Show explicit startup error details instead of a blank window.
                m_window = new Microsoft.UI.Xaml.Window();
                m_window.Title = "Translation Fiesta - Error";
                m_window.Content = new ScrollViewer
                {
                    Content = new TextBlock
                    {
                        Text = $"Startup failed:\n{ex.Message}\n\nCheck data\\logs\\translationfiesta.log for details.",
                        TextWrapping = TextWrapping.Wrap,
                        Margin = new Thickness(16)
                    }
                };
                m_window.Activate();
            }
        }

        private Microsoft.UI.Xaml.Window? m_window;
    }
}
