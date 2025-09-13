using System;
using System.IO;

namespace TranslationFiestaCSharp
{
    /// <summary>
    /// Simple test program to verify HTML processing functionality
    /// </summary>
    public static class TestHtmlProcessing
    {
        public static void RunTest()
        {
            try
            {
                Console.WriteLine("Testing HTML Processing Functionality");
                Console.WriteLine("=====================================");

                // Test with the sample HTML file
                string testFilePath = "test_sample.html";

                if (!File.Exists(testFilePath))
                {
                    Console.WriteLine($"Test file '{testFilePath}' not found.");
                    return;
                }

                Console.WriteLine($"Loading HTML from: {testFilePath}");
                string htmlContent = File.ReadAllText(testFilePath, System.Text.Encoding.UTF8);

                Console.WriteLine($"\nOriginal HTML length: {htmlContent.Length} characters");
                Console.WriteLine("First 200 characters of original HTML:");
                Console.WriteLine(htmlContent.Substring(0, Math.Min(200, htmlContent.Length)));
                Console.WriteLine("...");

                // Extract text using HtmlProcessor
                Console.WriteLine("\nProcessing HTML with HtmlProcessor...");
                string extractedText = HtmlProcessor.ExtractTextFromHtml(htmlContent);

                Console.WriteLine($"\nExtracted text length: {extractedText.Length} characters");
                Console.WriteLine("\nExtracted text content:");
                Console.WriteLine("=====================================");
                Console.WriteLine(extractedText);
                Console.WriteLine("=====================================");

                // Test with advanced options
                Console.WriteLine("\nTesting advanced options...");
                string extractedWithOptions = HtmlProcessor.ExtractTextFromHtml(htmlContent, preserveLineBreaks: true, includeAltText: true);
                Console.WriteLine("With line breaks preserved and alt text included:");
                Console.WriteLine(extractedWithOptions);

                Console.WriteLine("\nHTML processing test completed successfully!");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Test failed with error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
            }
        }
    }
}