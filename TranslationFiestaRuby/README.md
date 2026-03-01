# TranslationFiesta Ruby

Native **wxRuby3 desktop app** + CLI for EN → JA → EN back-translation.

## Portable runtime

- Portable archives only (no installers).
- Runtime data default: `./data` beside the executable/launcher.
- Override runtime data root with `TF_APP_HOME`.

## What changed

- The Sinatra web UI was removed.
- Ruby now launches a native cross-platform desktop interface (wxRuby3).
- CLI remains available for automation and scripting.

## Features

- Apple-inspired, clean native desktop layout with focused translation workflow
- Back-translation with Google Unofficial provider
- File import: `.txt`, `.md`, `.html`, `.epub`
- Export: `.txt`, `.md`, `.html`, `.pdf`, `.docx`
- Persistent settings and translation memory in portable data root

## Portable end-user launch (no Ruby install required)

Use the packaged launcher from a release bundle:

- Windows: `run.cmd` (or `run.ps1`)
- Linux: `run.sh`
- macOS: `run.command`

## Quick start from source (developer machine)

```bash
cd TranslationFiestaRuby
bundle install
bundle exec ruby bin/translation_fiesta
```

## CLI usage

Run CLI by passing `--cli`:

```bash
bundle exec ruby bin/translation_fiesta --cli translate "Hello world"
bundle exec ruby bin/translation_fiesta --cli file ./sample.txt
bundle exec ruby bin/translation_fiesta --cli batch ./documents --threads 4
```

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `TF_APP_HOME` | (unset) | Override portable runtime data root |
| `TF_USE_MOCK` | (unset) | Use mock translation repository when set to `1` |
| `TF_DEFAULT_API` | `google_unofficial` | Default provider id |

## Data layout

By default all runtime files are stored under:

```text
./data/
  settings.json
  translation_memory.db
  logs/
  exports/
```

## Development tasks

```bash
rake run       # Desktop app
rake desktop   # Desktop app (alias)
rake cli       # CLI
rake setup_db  # Initialize translation memory db
rake spec
rake rubocop
```
