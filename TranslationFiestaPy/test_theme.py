from ui.qt_theme import get_qss


def test_get_qss_uses_dark_palette_by_default():
    qss = get_qss()
    assert "#1C1C1E" in qss
    assert "#0A84FF" in qss


def test_get_qss_dark_palette_contains_dark_tokens():
    qss = get_qss("dark")
    assert "#1C1C1E" in qss
    assert "#2C2C2E" in qss
    assert "#0A84FF" in qss


def test_get_qss_light_palette_contains_light_tokens():
    qss = get_qss("light")
    assert "#F2F2F7" in qss
    assert "#FFFFFF" in qss
    assert "#007AFF" in qss
