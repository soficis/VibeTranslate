# TranslationFiestaRust

Rust desktop + CLI port of VibeTranslate/TranslationFiesta, built for feature parity with the existing ecosystem ports.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable.
- Override runtime data root with `TF_APP_HOME`.

## Feature parity targets

- EN -> JA -> EN backtranslation pipeline (default) with configurable source/intermediate language codes
- Provider support: Google Translate unofficial endpoint (`google_unofficial`)
- Retry/backoff, blocked/rate-limited response mapping, and robust error status
- Translation memory with persistent SQLite storage, search, clear, and stats
- File import: `.txt`, `.md`, `.html`, `.epub`
- HTML text extraction and EPUB chapter aggregation
- Batch processing for selected files or folders with progress and cancellation
- Export formats: `.txt`, `.md`, `.html`, `.json`, `.csv`, `.xml`, `.pdf`, `.docx`
- Modern dark-first desktop UI with tabs: Translate, Batch, Memory, Export, Settings
- CLI commands for automation: `translate`, `file`, `batch`, `memory`

## Run

```bash
cd TranslationFiestaRust
cargo run
```

Run CLI commands:

```bash
cargo run -- translate "Hello world"
cargo run -- file ./sample.md --output ./result.html --format html
cargo run -- batch ./docs --output ./batch_report.pdf --format pdf
cargo run -- memory stats
```

## Quality gates

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```
