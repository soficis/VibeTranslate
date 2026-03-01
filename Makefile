SHELL := /bin/bash
.ONESHELL:

.PHONY: \
	test-python test-go test-electron test-flutter test-ruby test-winui test-csharp test-rust \
	lint-python lint-go lint-electron lint-flutter lint-ruby lint-winui lint-csharp lint-rust \
	test-all lint-all

define require_cmd
	@command -v $(1) >/dev/null 2>&1 && $(1) --version >/dev/null 2>&1 || { \
		echo "Skipping $(2): unavailable command '$(1)'"; \
		exit 0; \
	}
endef

test-python:
	$(call require_cmd,python3,test-python)
	python3 -c "import importlib.util,sys; sys.exit(0 if importlib.util.find_spec('rapidfuzz') else 1)"
	if [ $$? -ne 0 ]; then
		echo "Skipping test-python: missing dependency 'rapidfuzz'"
		exit 0
	fi
	cd TranslationFiestaPy && PYTHONPATH=. pytest -q -s


test-go:
	$(call require_cmd,go,test-go)
	cd TranslationFiestaGo && go test ./...

test-electron:
	$(call require_cmd,npm,test-electron)
	cd TranslationFiestaElectron && npm test

test-flutter:
	$(call require_cmd,flutter,test-flutter)
	cd TranslationFiestaFlutter && flutter test

test-ruby:
	$(call require_cmd,bundle,test-ruby)
	cd TranslationFiestaRuby && bundle exec rspec

test-winui:
	$(call require_cmd,dotnet,test-winui)
	cd TranslationFiesta.WinUI && dotnet test

test-csharp:
	$(call require_cmd,dotnet,test-csharp)
	cd TranslationFiestaCSharp && dotnet test

test-rust:
	$(call require_cmd,cargo,test-rust)
	cd TranslationFiestaRust && cargo test

lint-python:
	$(call require_cmd,ruff,lint-python)
	cd TranslationFiestaPy && ruff check .

lint-go:
	$(call require_cmd,go,lint-go)
	cd TranslationFiestaGo && go vet ./...

lint-electron:
	$(call require_cmd,npm,lint-electron)
	cd TranslationFiestaElectron && npx tsc --noEmit

lint-flutter:
	$(call require_cmd,flutter,lint-flutter)
	cd TranslationFiestaFlutter && flutter analyze

lint-ruby:
	$(call require_cmd,bundle,lint-ruby)
	cd TranslationFiestaRuby && bundle exec rubocop

lint-winui:
	$(call require_cmd,dotnet,lint-winui)
	cd TranslationFiesta.WinUI && dotnet format TranslationFiesta.WinUI.csproj --verify-no-changes -v q

lint-csharp:
	$(call require_cmd,dotnet,lint-csharp)
	cd TranslationFiestaCSharp && dotnet format TranslationFiestaCSharp.csproj --verify-no-changes -v q

lint-rust:
	$(call require_cmd,cargo,lint-rust)
	cd TranslationFiestaRust && cargo fmt --check && cargo clippy --all-targets --all-features -- -D warnings

define run_targets
	@failed=0; \
	for target in $(1); do \
		echo "\n==> $$target"; \
		if $(MAKE) --no-print-directory $$target; then \
			echo "PASS $$target"; \
		else \
			echo "FAIL $$target"; \
			failed=1; \
		fi; \
	done; \
	exit $$failed
endef

test-all:
	$(call run_targets,test-python test-go test-electron test-flutter test-ruby test-winui test-csharp test-rust)

lint-all:
	$(call run_targets,lint-python lint-go lint-electron lint-flutter lint-ruby lint-winui lint-csharp lint-rust)
