import tempfile
import unittest
from pathlib import Path

from TranslationFiestaLocal.local_service import (
    BackTranslationResult,
    FixtureBackend,
    LocalTranslationService,
    ModelManager,
    TranslationError,
    TranslationRequest,
)


class LocalServiceTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temp_dir = tempfile.TemporaryDirectory(prefix="tf_local_test_")
        self.addCleanup(self._temp_dir.cleanup)
        models = ModelManager(Path(self._temp_dir.name))
        self.service = LocalTranslationService(FixtureBackend(), models)

    def test_translate_fixture(self) -> None:
        request = TranslationRequest(text="Hello", source_lang="en", target_lang="ja")
        result = self.service.translate(request)
        self.assertIn("en->ja", result.translated_text)

    def test_backtranslate_fixture(self) -> None:
        result = self.service.backtranslate("Hello", "en", "ja", "en")
        self.assertIsInstance(result, BackTranslationResult)
        self.assertIn("en->ja", result.intermediate_text)
        self.assertIn("ja->en", result.final_text)

    def test_empty_text_is_error(self) -> None:
        request = TranslationRequest(text=" ", source_lang="en", target_lang="ja")
        with self.assertRaises(TranslationError):
            self.service.translate(request)


if __name__ == "__main__":
    unittest.main()
