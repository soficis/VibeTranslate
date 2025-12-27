import tempfile
import unittest
import zipfile
from pathlib import Path

from TranslationFiestaLocal.local_service import ModelInstallRequest, ModelManager


class ModelManagerTests(unittest.TestCase):
    def test_verify_empty_is_not_ok(self) -> None:
        with tempfile.TemporaryDirectory(prefix="tf_models_") as temp_dir:
            manager = ModelManager(Path(temp_dir))
            result = manager.verify()
            self.assertFalse(result["ok"])

    def test_install_and_remove_with_local_zip(self) -> None:
        with tempfile.TemporaryDirectory(prefix="tf_models_") as temp_dir:
            base = Path(temp_dir)
            en_ja = base / "en-ja.zip"
            ja_en = base / "ja-en.zip"

            self._write_fake_model_zip(en_ja)
            self._write_fake_model_zip(ja_en)

            manager = ModelManager(base / "models")
            result = manager.install(
                ModelInstallRequest(en_ja_url=en_ja.as_uri(), ja_en_url=ja_en.as_uri())
            )
            self.assertTrue(result["ok"])
            self.assertTrue((manager.model_dir / "en-ja" / "ct2").exists())
            self.assertTrue((manager.model_dir / "ja-en" / "spm.model").exists())

            removed = manager.remove()
            self.assertTrue(removed["ok"])
            self.assertFalse(manager.model_dir.exists())

    @staticmethod
    def _write_fake_model_zip(path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(path, "w") as archive:
            archive.writestr("ct2/readme.txt", "fake model")
            archive.writestr("spm.model", "fake spm")


if __name__ == "__main__":
    unittest.main()

