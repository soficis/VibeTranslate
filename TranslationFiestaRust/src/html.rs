use scraper::{Html, Selector};

pub fn extract_text_from_html(html_content: &str) -> String {
    if html_content.trim().is_empty() {
        return String::new();
    }

    let mut document = Html::parse_document(html_content);

    let blacklist = ["script", "style", "code", "pre", "noscript", "iframe"];
    for tag in blacklist {
        if let Ok(selector) = Selector::parse(tag) {
            let elements: Vec<_> = document.select(&selector).map(|el| el.id()).collect();
            for element in elements {
                if let Some(mut node) = document.tree.get_mut(element) {
                    node.detach();
                }
            }
        }
    }

    let text = document
        .root_element()
        .text()
        .map(str::trim)
        .filter(|chunk| !chunk.is_empty())
        .collect::<Vec<_>>()
        .join(" ");

    normalize_whitespace(&text)
}

pub fn escape_html(value: &str) -> String {
    value
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;")
}

pub fn normalize_whitespace(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .trim()
        .to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn strips_script_and_style_tags() {
        let html = r#"
            <html>
              <head><style>body { color: red; }</style></head>
              <body>
                <script>alert('x');</script>
                <p>Hello <strong>world</strong></p>
              </body>
            </html>
        "#;

        let result = extract_text_from_html(html);
        assert_eq!(result, "Hello world");
    }

    #[test]
    fn escapes_html_entities() {
        assert_eq!(
            escape_html("<hi> & \"bye\""),
            "&lt;hi&gt; &amp; &quot;bye&quot;"
        );
    }
}
