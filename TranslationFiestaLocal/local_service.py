#!/usr/bin/env python3
"""
TranslationFiestaLocal: local-only offline translation/backtranslation service.

Design goals:
- Same contract used by all apps via HTTP (`docs/translation_contract.md`).
- Deterministic fixture mode for tests/CI (`TF_LOCAL_FIXTURE=1`).
- Real inference via quantized models when installed locally (CTranslate2 + SentencePiece).
- Model management primitives: status/verify/install/remove.

Environment variables (subset; see `docs/OfflineModels.md`):
- TF_LOCAL_FIXTURE=1
- TF_LOCAL_MODEL_DIR=/path/to/models
- TF_LOCAL_URL / TF_LOCAL_HOST / TF_LOCAL_PORT
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from dataclasses import asdict, dataclass
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Dict, Optional, Sequence, Tuple

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 5055
SUPPORTED_PAIRS = {("en", "ja"), ("ja", "en")}


def _default_model_dir() -> Path:
    if sys.platform.startswith("win"):
        base = os.getenv("LOCALAPPDATA") or str(Path.home() / "AppData" / "Local")
        return Path(base) / "TranslationFiesta" / "models"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "TranslationFiesta" / "models"
    return Path.home() / ".cache" / "translationfiesta" / "models"


@dataclass(frozen=True)
class TranslationRequest:
    text: str
    source_lang: str
    target_lang: str
    request_id: Optional[str] = None


@dataclass(frozen=True)
class TranslationResult:
    translated_text: str
    source_lang: str
    target_lang: str
    backend: str


@dataclass(frozen=True)
class BackTranslationResult:
    original_text: str
    intermediate_text: str
    final_text: str
    source_lang: str
    intermediate_lang: str
    target_lang: str
    backend: str


@dataclass(frozen=True)
class ModelInstallRequest:
    en_ja_url: str = ""
    ja_en_url: str = ""
    en_ja_sha256: Optional[str] = None
    ja_en_sha256: Optional[str] = None
    preset: Optional[str] = None


class TranslationError(RuntimeError):
    def __init__(self, code: str, message: str, retryable: bool = False) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable

    def to_dict(self) -> Dict[str, Any]:
        return {"error": {"code": self.code, "message": self.message, "retryable": self.retryable}}


def _sha256_file(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def _download_file(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url) as response, dest.open("wb") as handle:
            shutil.copyfileobj(response, handle)
    except Exception as exc:
        raise TranslationError("network_error", f"Failed to download model: {exc}") from exc


class ModelManager:
    def __init__(self, model_dir: Path) -> None:
        self._model_dir = model_dir

    @property
    def model_dir(self) -> Path:
        return self._model_dir

    def status(self) -> Dict[str, Any]:
        en_ja_ok, en_ja_reason = self.verify_direction("en", "ja")
        ja_en_ok, ja_en_reason = self.verify_direction("ja", "en")
        return {
            "model_dir": str(self._model_dir),
            "en_ja": {"installed": en_ja_ok, "reason": en_ja_reason},
            "ja_en": {"installed": ja_en_ok, "reason": ja_en_reason},
        }

    def verify_direction(self, source: str, target: str) -> Tuple[bool, str]:
        direction_dir = self._model_dir / f"{source}-{target}"
        if not direction_dir.exists():
            return False, "missing directory"
        ct2_dir = direction_dir / "ct2"
        if not ct2_dir.exists():
            return False, "missing ct2/"

        shared_spm = direction_dir / "spm.model"
        src_spm = direction_dir / "source.spm"
        tgt_spm = direction_dir / "target.spm"
        if shared_spm.exists():
            return True, "ok"
        if src_spm.exists() and tgt_spm.exists():
            return True, "ok"
        return False, "missing SentencePiece model (spm.model or source.spm+target.spm)"

    def verify(self) -> Dict[str, Any]:
        status = self.status()
        ok = bool(status["en_ja"]["installed"] and status["ja_en"]["installed"])
        return {"ok": ok, **status}

    def remove(self) -> Dict[str, Any]:
        if self._model_dir.exists():
            shutil.rmtree(self._model_dir, ignore_errors=True)
        return {"ok": True, "model_dir": str(self._model_dir)}

    def install(self, request: ModelInstallRequest) -> Dict[str, Any]:
        if request.preset:
            return self._install_preset(request.preset)

        if not request.en_ja_url or not request.ja_en_url:
            raise TranslationError("user_error", "Provide en_ja_url and ja_en_url, or preset")

        self._model_dir.mkdir(parents=True, exist_ok=True)

        with tempfile.TemporaryDirectory(prefix="tf_local_models_") as temp_dir:
            temp_path = Path(temp_dir)
            en_ja_zip = temp_path / "en-ja.zip"
            ja_en_zip = temp_path / "ja-en.zip"
            _download_file(request.en_ja_url, en_ja_zip)
            _download_file(request.ja_en_url, ja_en_zip)

            if request.en_ja_sha256:
                actual = _sha256_file(en_ja_zip)
                if actual.lower() != request.en_ja_sha256.lower():
                    raise TranslationError("invalid_response", "en-ja checksum mismatch")
            if request.ja_en_sha256:
                actual = _sha256_file(ja_en_zip)
                if actual.lower() != request.ja_en_sha256.lower():
                    raise TranslationError("invalid_response", "ja-en checksum mismatch")

            self._extract_zip(en_ja_zip, self._model_dir / "en-ja")
            self._extract_zip(ja_en_zip, self._model_dir / "ja-en")

        return self.verify()

    def _install_preset(self, preset: str) -> Dict[str, Any]:
        preset_id = preset.strip().lower()
        if preset_id in ("default", "elanmt-tiny-int8", "elanmt_tiny_int8"):
            pack_dir = Path(__file__).resolve().parent / "model_packs"
            en_ja = pack_dir / "elanmt-tiny-int8-en-ja.zip"
            ja_en = pack_dir / "elanmt-tiny-int8-ja-en.zip"
            if not en_ja.exists() or not ja_en.exists():
                raise TranslationError(
                    "model_unavailable",
                    f"Default model pack not found under {pack_dir}.",
                )
            return self.install(
                ModelInstallRequest(
                    en_ja_url=en_ja.as_uri(),
                    ja_en_url=ja_en.as_uri(),
                    preset=None,
                )
            )
        raise TranslationError("user_error", f"Unknown preset: {preset}")

    @staticmethod
    def _extract_zip(zip_path: Path, dest_dir: Path) -> None:
        dest_dir.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(zip_path, "r") as archive:
                archive.extractall(dest_dir)
        except zipfile.BadZipFile as exc:
            raise TranslationError("invalid_response", f"Invalid zip archive: {zip_path.name}") from exc


class TranslationBackend:
    name = "backend"

    def translate(self, request: TranslationRequest) -> TranslationResult:
        raise NotImplementedError


class FixtureBackend(TranslationBackend):
    name = "fixture"

    def translate(self, request: TranslationRequest) -> TranslationResult:
        translated = f"[{request.source_lang}->{request.target_lang}] {request.text}".strip()
        return TranslationResult(
            translated_text=translated,
            source_lang=request.source_lang,
            target_lang=request.target_lang,
            backend=self.name,
        )


class CTranslate2Backend(TranslationBackend):
    name = "ctranslate2"

    def __init__(self, model_dir: Path) -> None:
        try:
            import ctranslate2  # type: ignore
            import sentencepiece as spm  # type: ignore
        except Exception as exc:
            raise TranslationError(
                "model_unavailable",
                "CTranslate2 backend unavailable (install python packages: ctranslate2, sentencepiece).",
            ) from exc

        self._ctranslate2 = ctranslate2
        self._spm = spm
        self._translators: Dict[Tuple[str, str], Any] = {}
        self._sp_processors: Dict[Tuple[str, str], Tuple[Any, Any]] = {}

        for source, target in SUPPORTED_PAIRS:
            direction_dir = model_dir / f"{source}-{target}"
            ct2_dir = direction_dir / "ct2"
            shared_spm = direction_dir / "spm.model"
            src_spm = direction_dir / "source.spm"
            tgt_spm = direction_dir / "target.spm"
            if not ct2_dir.exists() or not (shared_spm.exists() or (src_spm.exists() and tgt_spm.exists())):
                raise TranslationError(
                    "model_unavailable",
                    f"Missing local model files for {source}->{target} under {direction_dir}",
                )
            if shared_spm.exists():
                src_spm = shared_spm
                tgt_spm = shared_spm

            src_sp = spm.SentencePieceProcessor()
            src_sp.Load(str(src_spm))
            tgt_sp = spm.SentencePieceProcessor()
            tgt_sp.Load(str(tgt_spm))
            self._sp_processors[(source, target)] = (src_sp, tgt_sp)
            self._translators[(source, target)] = ctranslate2.Translator(str(ct2_dir), compute_type="int8")

    def translate(self, request: TranslationRequest) -> TranslationResult:
        src_sp, tgt_sp = self._sp_processors[(request.source_lang, request.target_lang)]
        translator = self._translators[(request.source_lang, request.target_lang)]
        tokens: Sequence[str] = src_sp.EncodeAsPieces(request.text)
        if not tokens:
            raise TranslationError("user_error", "Text is empty")

        try:
            results = translator.translate_batch([list(tokens)], beam_size=2, max_decoding_length=512)
            output_tokens: Sequence[str] = results[0].hypotheses[0]
            translated = tgt_sp.DecodePieces(list(output_tokens))
        except TranslationError:
            raise
        except Exception as exc:
            raise TranslationError("server_error", f"Local inference failed: {exc}") from exc

        translated = translated.strip()
        if not translated:
            raise TranslationError("invalid_response", "Local model returned empty translation")
        return TranslationResult(
            translated_text=translated,
            source_lang=request.source_lang,
            target_lang=request.target_lang,
            backend=self.name,
        )


class UnavailableBackend(TranslationBackend):
    name = "unavailable"

    def __init__(self, reason: str) -> None:
        self._reason = reason

    def translate(self, request: TranslationRequest) -> TranslationResult:
        raise TranslationError("model_unavailable", self._reason)


class LocalTranslationService:
    def __init__(self, backend: TranslationBackend, model_manager: ModelManager) -> None:
        self._backend = backend
        self._models = model_manager

    def translate(self, request: TranslationRequest) -> TranslationResult:
        self._validate_request(request)
        return self._backend.translate(request)

    def backtranslate(
        self, text: str, source_lang: str, intermediate_lang: str, target_lang: str
    ) -> BackTranslationResult:
        first = self.translate(TranslationRequest(text=text, source_lang=source_lang, target_lang=intermediate_lang))
        second = self.translate(
            TranslationRequest(text=first.translated_text, source_lang=intermediate_lang, target_lang=target_lang)
        )
        return BackTranslationResult(
            original_text=text,
            intermediate_text=first.translated_text,
            final_text=second.translated_text,
            source_lang=source_lang,
            intermediate_lang=intermediate_lang,
            target_lang=target_lang,
            backend=self._backend.name,
        )

    def health(self) -> Dict[str, Any]:
        return {
            "status": "ok",
            "backend": self._backend.name,
            "pairs": sorted([list(pair) for pair in SUPPORTED_PAIRS]),
            "models": self._models.status(),
        }

    def models_status(self) -> Dict[str, Any]:
        return self._models.status()

    def models_verify(self) -> Dict[str, Any]:
        return self._models.verify()

    def models_remove(self) -> Dict[str, Any]:
        return self._models.remove()

    def models_install(self, request: ModelInstallRequest) -> Dict[str, Any]:
        return self._models.install(request)

    @staticmethod
    def _validate_request(request: TranslationRequest) -> None:
        if not request.text.strip():
            raise TranslationError("user_error", "Text is empty")
        if (request.source_lang, request.target_lang) not in SUPPORTED_PAIRS:
            raise TranslationError("user_error", "Unsupported language pair")


def build_service() -> LocalTranslationService:
    model_dir = Path(os.getenv("TF_LOCAL_MODEL_DIR", "")).expanduser().resolve() if os.getenv("TF_LOCAL_MODEL_DIR") else _default_model_dir()
    models = ModelManager(model_dir)

    if os.getenv("TF_LOCAL_FIXTURE") == "1":
        return LocalTranslationService(FixtureBackend(), models)

    ok = models.verify()
    if ok.get("ok"):
        return LocalTranslationService(CTranslate2Backend(model_dir), models)
    return LocalTranslationService(UnavailableBackend("Local models not installed"), models)


def _read_body(handler: BaseHTTPRequestHandler) -> Dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length).decode("utf-8") if length else ""
    return json.loads(raw) if raw else {}


def _write_json(handler: BaseHTTPRequestHandler, status: int, payload: Dict[str, Any]) -> None:
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def make_handler(service: LocalTranslationService):
    class LocalHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path == "/health":
                _write_json(self, 200, service.health())
                return
            if self.path == "/models":
                _write_json(self, 200, service.models_status())
                return
            _write_json(self, 404, {"error": {"code": "not_found", "message": "Unknown route"}})

        def do_POST(self) -> None:
            try:
                payload = _read_body(self)

                if self.path == "/translate":
                    request = TranslationRequest(
                        text=str(payload.get("text", "")),
                        source_lang=str(payload.get("source_lang", "")),
                        target_lang=str(payload.get("target_lang", "")),
                        request_id=payload.get("request_id"),
                    )
                    result = service.translate(request)
                    _write_json(self, 200, asdict(result))
                    return

                if self.path == "/backtranslate":
                    result = service.backtranslate(
                        text=str(payload.get("text", "")),
                        source_lang=str(payload.get("source_lang", "en")),
                        intermediate_lang=str(payload.get("intermediate_lang", "ja")),
                        target_lang=str(payload.get("target_lang", "en")),
                    )
                    _write_json(self, 200, asdict(result))
                    return

                if self.path == "/models/verify":
                    _write_json(self, 200, service.models_verify())
                    return

                if self.path == "/models/remove":
                    _write_json(self, 200, service.models_remove())
                    return

                if self.path == "/models/install":
                    request = ModelInstallRequest(
                        en_ja_url=str(payload.get("en_ja_url", "")),
                        ja_en_url=str(payload.get("ja_en_url", "")),
                        en_ja_sha256=payload.get("en_ja_sha256"),
                        ja_en_sha256=payload.get("ja_en_sha256"),
                        preset=payload.get("preset") or ("elanmt-tiny-int8" if not payload else None),
                    )
                    _write_json(self, 200, service.models_install(request))
                    return

                _write_json(self, 404, {"error": {"code": "not_found", "message": "Unknown route"}})

            except json.JSONDecodeError:
                _write_json(self, 400, {"error": {"code": "invalid_json", "message": "Invalid JSON body"}})
            except TranslationError as exc:
                status = {
                    "user_error": 400,
                    "config_error": 400,
                    "invalid_response": 502,
                    "network_error": 503,
                    "model_unavailable": 503,
                }.get(exc.code, 500)
                _write_json(self, status, exc.to_dict())
            except Exception as exc:
                _write_json(self, 500, {"error": {"code": "server_error", "message": str(exc)}})

        def log_message(self, format: str, *args: Any) -> None:
            return

    return LocalHandler


def run_server(host: str, port: int, service: LocalTranslationService) -> None:
    server = HTTPServer((host, port), make_handler(service))
    server.serve_forever()


def _read_text(text_arg: Optional[str]) -> str:
    return text_arg if text_arg is not None else sys.stdin.read()


def _print_json(payload: Dict[str, Any]) -> None:
    print(json.dumps(payload, indent=2, ensure_ascii=False))


def main() -> int:
    parser = argparse.ArgumentParser(description="TranslationFiesta local service")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("health")
    subparsers.add_parser("models-status")
    subparsers.add_parser("models-verify")
    subparsers.add_parser("models-remove")

    models_install = subparsers.add_parser("models-install")
    models_install.add_argument("--preset")
    models_install.add_argument("--en-ja-url")
    models_install.add_argument("--ja-en-url")
    models_install.add_argument("--en-ja-sha256")
    models_install.add_argument("--ja-en-sha256")

    translate_parser = subparsers.add_parser("translate")
    translate_parser.add_argument("--source", default="en")
    translate_parser.add_argument("--target", default="ja")
    translate_parser.add_argument("--text")

    back_parser = subparsers.add_parser("backtranslate")
    back_parser.add_argument("--source", default="en")
    back_parser.add_argument("--intermediate", default="ja")
    back_parser.add_argument("--target", default="en")
    back_parser.add_argument("--text")

    serve_parser = subparsers.add_parser("serve")
    serve_parser.add_argument("--host", default=os.getenv("TF_LOCAL_HOST", DEFAULT_HOST))
    serve_parser.add_argument("--port", type=int, default=int(os.getenv("TF_LOCAL_PORT", str(DEFAULT_PORT))))

    args = parser.parse_args()
    service = build_service()

    if args.command == "health":
        _print_json(service.health())
        return 0
    if args.command == "models-status":
        _print_json(service.models_status())
        return 0
    if args.command == "models-verify":
        _print_json(service.models_verify())
        return 0
    if args.command == "models-remove":
        _print_json(service.models_remove())
        return 0
    if args.command == "models-install":
        if not args.preset and (not args.en_ja_url or not args.ja_en_url):
            raise SystemExit("models-install requires --preset or both --en-ja-url and --ja-en-url")
        _print_json(
            service.models_install(
                ModelInstallRequest(
                    en_ja_url=args.en_ja_url or "",
                    ja_en_url=args.ja_en_url or "",
                    en_ja_sha256=args.en_ja_sha256,
                    ja_en_sha256=args.ja_en_sha256,
                    preset=args.preset,
                )
            )
        )
        return 0
    if args.command == "translate":
        text = _read_text(args.text)
        result = service.translate(TranslationRequest(text=text, source_lang=args.source, target_lang=args.target))
        _print_json(asdict(result))
        return 0
    if args.command == "backtranslate":
        text = _read_text(args.text)
        result = service.backtranslate(text, args.source, args.intermediate, args.target)
        _print_json(asdict(result))
        return 0
    if args.command == "serve":
        run_server(args.host, args.port, service)
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
