using System;
using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;
using HtmlAgilityPack;
using HtmlDocument = HtmlAgilityPack.HtmlDocument;
using HtmlNode = HtmlAgilityPack.HtmlNode;
using HtmlNodeType = HtmlAgilityPack.HtmlNodeType;

namespace TranslationFiestaCSharp
{
    /// <summary>
    /// HTML processing utility similar to Python's BeautifulSoup functionality
    /// Provides robust HTML parsing, tag removal, and text extraction
    /// </summary>
    public static class HtmlProcessor
    {
        /// <summary>
        /// Extracts clean text content from HTML, removing scripts, styles, and normalizing whitespace
        /// </summary>
        /// <param name="htmlContent">The raw HTML content to process</param>
        /// <returns>Clean, normalized text content</returns>
        public static string ExtractTextFromHtml(string htmlContent)
        {
            Logger.Debug($"ExtractTextFromHtml (basic) called with content length: {htmlContent.Length}");
            var stopwatch = Stopwatch.StartNew();

            if (string.IsNullOrWhiteSpace(htmlContent))
            {
                Logger.Warn("ExtractTextFromHtml (basic) called with empty or whitespace content.");
                return string.Empty;
            }

            try
            {
                // Load HTML document
                var htmlDoc = new HtmlDocument();
                htmlDoc.LoadHtml(htmlContent);
                Logger.Debug("HTML document loaded.");

                // Remove unwanted elements
                RemoveUnwantedElements(htmlDoc);
                Logger.Debug("Unwanted elements removed.");

                // Extract text content
                var textContent = ExtractTextContent(htmlDoc);
                Logger.Debug($"Extracted raw text content length: {textContent.Length}");

                // Normalize and clean the text
                var normalizedText = NormalizeText(textContent);
                stopwatch.Stop();
                Logger.Performance("Basic HTML text extraction", stopwatch.Elapsed);
                Logger.Info($"Successfully extracted text from HTML (basic). Result length: {normalizedText.Length}");
                return normalizedText;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                Logger.Error($"HTML processing failed. Falling back to regex extraction.", ex);
                // Fallback to basic regex processing
                return FallbackTextExtraction(htmlContent);
            }
        }

        /// <summary>
        /// Removes script, style, and other unwanted elements from the HTML document
        /// </summary>
        private static void RemoveUnwantedElements(HtmlDocument htmlDoc)
        {
            // Remove script tags and their content
            RemoveElementsByTagName(htmlDoc, "script");

            // Remove style tags and their content
            RemoveElementsByTagName(htmlDoc, "style");

            // Remove link tags (CSS)
            RemoveElementsByTagName(htmlDoc, "link");

            // Remove meta tags
            RemoveElementsByTagName(htmlDoc, "meta");

            // Remove noscript tags
            RemoveElementsByTagName(htmlDoc, "noscript");

            // Remove iframe tags
            RemoveElementsByTagName(htmlDoc, "iframe");

            // Remove object/embed tags
            RemoveElementsByTagName(htmlDoc, "object");
            RemoveElementsByTagName(htmlDoc, "embed");

            // Remove form elements (optional - may contain useful content)
            // RemoveElementsByTagName(htmlDoc, "form");
            // RemoveElementsByTagName(htmlDoc, "input");
            // RemoveElementsByTagName(htmlDoc, "button");
        }

        /// <summary>
        /// Removes all elements with the specified tag name
        /// </summary>
        private static void RemoveElementsByTagName(HtmlDocument htmlDoc, string tagName)
        {
            var elements = htmlDoc.DocumentNode.SelectNodes($"//{tagName}");
            if (elements != null)
            {
                foreach (var element in elements)
                {
                    element.Remove();
                }
            }
        }

        /// <summary>
        /// Extracts text content from the HTML document
        /// </summary>
        private static string ExtractTextContent(HtmlDocument htmlDoc)
        {
            var stringBuilder = new StringBuilder();

            // Get the body content, or the entire document if no body
            var rootNode = htmlDoc.DocumentNode.SelectSingleNode("//body") ?? htmlDoc.DocumentNode;

            // Extract text recursively
            ExtractTextFromNode(rootNode, stringBuilder);

            return stringBuilder.ToString();
        }

        /// <summary>
        /// Recursively extracts text from HTML nodes
        /// </summary>
        private static void ExtractTextFromNode(HtmlNode node, StringBuilder stringBuilder)
        {
            // Skip comment nodes
            if (node.NodeType == HtmlNodeType.Comment)
                return;

            // If it's a text node, add its content
            if (node.NodeType == HtmlNodeType.Text)
            {
                var text = HtmlEntity.DeEntitize(node.InnerText);
                if (!string.IsNullOrWhiteSpace(text))
                {
                    stringBuilder.Append(text);
                    stringBuilder.Append(' '); // Add space between text elements
                }
                return;
            }

            // Skip certain elements that shouldn't contribute text
            var tagName = node.Name.ToLower();
            if (ShouldSkipElement(tagName))
                return;

            // Process child nodes
            foreach (var child in node.ChildNodes)
            {
                ExtractTextFromNode(child, stringBuilder);
            }

            // Add line breaks for block-level elements
            if (IsBlockElement(tagName))
            {
                stringBuilder.AppendLine();
            }
        }

        /// <summary>
        /// Determines if an element should be skipped during text extraction
        /// </summary>
        private static bool ShouldSkipElement(string tagName)
        {
            // Elements that are already removed but check again just in case
            var skipElements = new[] { "script", "style", "link", "meta", "noscript", "iframe", "object", "embed" };
            return Array.Exists(skipElements, element => element == tagName);
        }

        /// <summary>
        /// Determines if an element is a block-level element that should get line breaks
        /// </summary>
        private static bool IsBlockElement(string tagName)
        {
            var blockElements = new[] {
                "div", "p", "h1", "h2", "h3", "h4", "h5", "h6",
                "ul", "ol", "li", "blockquote", "pre", "code",
                "table", "tr", "td", "th", "thead", "tbody", "tfoot",
                "article", "section", "header", "footer", "nav", "aside",
                "br", "hr"
            };
            return Array.Exists(blockElements, element => element == tagName);
        }

        /// <summary>
        /// Normalizes text by cleaning up whitespace and formatting
        /// </summary>
        private static string NormalizeText(string text)
        {
            if (string.IsNullOrEmpty(text))
                return string.Empty;

            // Replace multiple whitespace characters with single space
            text = Regex.Replace(text, @"\s+", " ");

            // Remove excessive line breaks
            text = Regex.Replace(text, @"(\r?\n\s*){3,}", "\n\n");

            // Trim whitespace from start and end
            text = text.Trim();

            // Remove leading/trailing whitespace from each line
            var lines = text.Split(new[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
            var normalizedLines = new System.Collections.Generic.List<string>();

            foreach (var line in lines)
            {
                var trimmedLine = line.Trim();
                if (!string.IsNullOrWhiteSpace(trimmedLine))
                {
                    normalizedLines.Add(trimmedLine);
                }
            }

            return string.Join("\n", normalizedLines);
        }

        /// <summary>
        /// Fallback text extraction using regex when HtmlAgilityPack fails
        /// </summary>
        private static string FallbackTextExtraction(string htmlContent)
        {
            try
            {
                // Remove script, style, code, and pre blocks using regex
                var scriptPattern = "<script[^>]*>.*?</script>";
                var stylePattern = "<style[^>]*>.*?</style>";
                var codePattern = "<code[^>]*>.*?</code>";
                var prePattern = "<pre[^>]*>.*?</pre>";
                var linkPattern = "<link[^>]*>.*?</link>";
                var metaPattern = "<meta[^>]*>.*?</meta>";
                var noscriptPattern = "<noscript[^>]*>.*?</noscript>";

                var withoutScripts = Regex.Replace(htmlContent, scriptPattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutStyles = Regex.Replace(withoutScripts, stylePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutCode = Regex.Replace(withoutStyles, codePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutPre = Regex.Replace(withoutCode, prePattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutLinks = Regex.Replace(withoutPre, linkPattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutMeta = Regex.Replace(withoutLinks, metaPattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);
                var withoutNoscript = Regex.Replace(withoutMeta, noscriptPattern, "", RegexOptions.Singleline | RegexOptions.IgnoreCase);

                // Remove all remaining HTML tags
                var tagPattern = "<[^>]+>";
                var withoutTags = Regex.Replace(withoutNoscript, tagPattern, "");

                // Decode HTML entities
                withoutTags = HtmlEntity.DeEntitize(withoutTags);

                // Normalize whitespace
                return NormalizeText(withoutTags);
            }
            catch (Exception ex)
            {
                Logger.Error($"Fallback HTML processing failed. Returning original content as last resort.", ex);
                return htmlContent; // Return original content as last resort
            }
        }

        /// <summary>
        /// Extracts text from HTML with additional options
        /// </summary>
        public static string ExtractTextFromHtml(string htmlContent, bool preserveLineBreaks, bool includeAltText)
        {
            Logger.Debug($"ExtractTextFromHtml (advanced) called with content length: {htmlContent.Length}, preserveLineBreaks={preserveLineBreaks}, includeAltText={includeAltText}");
            var stopwatch = Stopwatch.StartNew();

            if (string.IsNullOrWhiteSpace(htmlContent))
            {
                Logger.Warn("ExtractTextFromHtml (advanced) called with empty or whitespace content.");
                return string.Empty;
            }

            try
            {
                var htmlDoc = new HtmlDocument();
                htmlDoc.LoadHtml(htmlContent);
                Logger.Debug("HTML document loaded for advanced extraction.");

                RemoveUnwantedElements(htmlDoc);
                Logger.Debug("Unwanted elements removed for advanced extraction.");

                var textContent = ExtractTextContentWithOptions(htmlDoc, preserveLineBreaks, includeAltText);
                var normalizedText = NormalizeText(textContent);
                stopwatch.Stop();
                Logger.Performance("Advanced HTML text extraction", stopwatch.Elapsed);
                Logger.Info($"Successfully extracted text from HTML (advanced). Result length: {normalizedText.Length}");
                return normalizedText;
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                Logger.Error($"Advanced HTML processing failed. Falling back to basic method.", ex);
                return ExtractTextFromHtml(htmlContent); // Fallback to basic method
            }
        }

        /// <summary>
        /// Extracts text content with additional options
        /// </summary>
        private static string ExtractTextContentWithOptions(HtmlDocument htmlDoc, bool preserveLineBreaks, bool includeAltText)
        {
            var stringBuilder = new StringBuilder();
            var rootNode = htmlDoc.DocumentNode.SelectSingleNode("//body") ?? htmlDoc.DocumentNode;

            ExtractTextFromNodeWithOptions(rootNode, stringBuilder, preserveLineBreaks, includeAltText);
            return stringBuilder.ToString();
        }

        /// <summary>
        /// Extracts text from nodes with additional options
        /// </summary>
        private static void ExtractTextFromNodeWithOptions(HtmlNode node, StringBuilder stringBuilder, bool preserveLineBreaks, bool includeAltText)
        {
            if (node.NodeType == HtmlNodeType.Comment)
                return;

            if (node.NodeType == HtmlNodeType.Text)
            {
                var text = HtmlEntity.DeEntitize(node.InnerText);
                if (!string.IsNullOrWhiteSpace(text))
                {
                    stringBuilder.Append(text);
                    if (!preserveLineBreaks)
                        stringBuilder.Append(' ');
                }
                return;
            }

            var tagName = node.Name.ToLower();

            // Handle images with alt text
            if (includeAltText && tagName == "img")
            {
                var altText = node.GetAttributeValue("alt", "");
                if (!string.IsNullOrWhiteSpace(altText))
                {
                    stringBuilder.Append($"[Image: {altText}] ");
                }
                return;
            }

            if (ShouldSkipElement(tagName))
                return;

            foreach (var child in node.ChildNodes)
            {
                ExtractTextFromNodeWithOptions(child, stringBuilder, preserveLineBreaks, includeAltText);
            }

            if (preserveLineBreaks && IsBlockElement(tagName))
            {
                stringBuilder.AppendLine();
            }
        }
    }
}