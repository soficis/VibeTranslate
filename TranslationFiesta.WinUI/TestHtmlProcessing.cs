using System;

namespace TranslationFiesta.WinUI
{
    public static class TestHtmlProcessing
    {
        public static void Test()
        {
            // Sample HTML content for testing
            string htmlContent = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <title>Test Document</title>
    <style>
        body { font-family: Arial; }
        .highlight { background-color: yellow; }
    </style>
</head>
<body>
    <h1>Welcome to TranslationFiesta</h1>
    <p>This is a <strong>test</strong> document with various HTML elements.</p>
    <p>It contains & entities and <tags> that should be processed.</p>

    <script>
        console.log('This script should be removed');
    </script>

    <img src='logo.png' alt='Company Logo' width='200'>
    <img src='diagram.jpg' alt='Process Diagram'>

    <footer>
        <p>&copy; 2024 TranslationFiesta</p>
    </footer>
</body>
</html>";

            try
            {
                Logger.Info("Testing HTML processing...");

                // Test basic text extraction
                string extractedText = HtmlProcessor.ExtractTextFromHtml(htmlContent);
                Logger.Info($"Basic extraction result: {extractedText}");

                // Test with options
                string extractedWithOptions = HtmlProcessor.ExtractTextFromHtml(htmlContent, true, true);
                Logger.Info($"Extraction with options result: {extractedWithOptions}");

                Logger.Info("HTML processing test completed successfully");
            }
            catch (Exception ex)
            {
                Logger.Error($"HTML processing test failed: {ex.Message}");
            }
        }
    }
}