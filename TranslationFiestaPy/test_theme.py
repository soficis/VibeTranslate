from ui.theme import build_themes, toggle_button_label


def test_build_themes_contains_required_keys():
    themes = build_themes()
    assert "light" in themes
    assert "dark" in themes
    for key in ("bg", "fg", "text_bg", "text_fg", "button_bg", "button_fg", "label_bg", "label_fg"):
        assert key in themes["light"]
        assert key in themes["dark"]


def test_toggle_button_label_matches_theme():
    assert toggle_button_label("dark") == "☀️ Light"
    assert toggle_button_label("light") == "🌙 Dark"
