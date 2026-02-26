#!/usr/bin/env python3

from pathlib import Path

import app_paths
from settings_storage import SettingsStorage
from translation_services import TranslationMemory


def test_settings_storage_uses_tf_app_home(monkeypatch, tmp_path):
    data_root = tmp_path / "portable_data"
    monkeypatch.setenv("TF_APP_HOME", str(data_root))

    settings = SettingsStorage()
    settings.set_theme("dark")
    info = settings.get_file_info()
    settings_file = Path(info["settings_file"])

    assert settings_file == data_root / "settings.json"
    assert settings_file.exists()


def test_settings_default_theme_is_dark(monkeypatch, tmp_path):
    data_root = tmp_path / "portable_data"
    monkeypatch.setenv("TF_APP_HOME", str(data_root))

    settings = SettingsStorage()
    assert settings.get_theme() == "dark"


def test_translation_memory_uses_tf_app_home(monkeypatch, tmp_path):
    data_root = tmp_path / "portable_data"
    monkeypatch.setenv("TF_APP_HOME", str(data_root))

    memory = TranslationMemory(cache_size=5)
    memory.store("hello", "ja", "こんにちは")

    assert (data_root / "tm_cache.json").exists()


def test_default_data_root_is_app_local(monkeypatch, tmp_path):
    monkeypatch.delenv("TF_APP_HOME", raising=False)
    monkeypatch.setattr(app_paths, "_default_app_root", lambda: tmp_path)

    data_root = app_paths.get_data_root()
    settings_file = app_paths.get_settings_file()

    assert data_root == tmp_path / "data"
    assert settings_file == tmp_path / "data" / "settings.json"
    assert data_root.exists()
