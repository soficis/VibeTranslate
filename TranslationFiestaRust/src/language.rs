pub fn is_supported_language_code(code: &str) -> bool {
    let trimmed = code.trim();
    if trimmed.is_empty() {
        return false;
    }

    let mut segments = trimmed.split('-');
    let Some(primary) = segments.next() else {
        return false;
    };

    if !(primary.len() == 2 || primary.len() == 3)
        || !primary.chars().all(|ch| ch.is_ascii_alphabetic())
    {
        return false;
    }

    for segment in segments {
        let len = segment.len();
        if !(2..=8).contains(&len) || !segment.chars().all(|ch| ch.is_ascii_alphanumeric()) {
            return false;
        }
    }

    true
}

pub fn normalize_language_code(code: &str) -> Option<String> {
    if !is_supported_language_code(code) {
        return None;
    }

    Some(code.trim().to_ascii_lowercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_basic_and_bcp47_codes() {
        assert!(is_supported_language_code("en"));
        assert!(is_supported_language_code("ja"));
        assert!(is_supported_language_code("pt-BR"));
        assert!(is_supported_language_code("zh-Hans"));
        assert!(is_supported_language_code("zh-CN"));
    }

    #[test]
    fn rejects_invalid_codes() {
        assert!(!is_supported_language_code(""));
        assert!(!is_supported_language_code("e"));
        assert!(!is_supported_language_code("english"));
        assert!(!is_supported_language_code("en_au"));
        assert!(!is_supported_language_code("en-"));
    }
}
