#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create_unix_launchers.sh --root <bundle-root> --platform <linux|macos>
EOF
}

root=""
platform=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      root="${2:-}"
      shift 2
      ;;
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$root" || -z "$platform" ]]; then
  usage
  exit 1
fi

if [[ "$platform" != "linux" && "$platform" != "macos" ]]; then
  echo "Unsupported platform: $platform" >&2
  exit 1
fi

if [[ ! -d "$root" ]]; then
  echo "Bundle root does not exist: $root" >&2
  exit 1
fi

root="$(cd "$root" && pwd)"
runner_name="run.sh"
bundle_launcher_name="launch.sh"
if [[ "$platform" == "macos" ]]; then
  runner_name="run.command"
  bundle_launcher_name="launch.command"
fi

get_app_display_name() {
  local app_name="$1"
  case "$app_name" in
    TranslationFiestaCSharp) printf '%s\n' "TranslationFiesta C#" ;;
    TranslationFiestaFSharp) printf '%s\n' "TranslationFiesta F#" ;;
    TranslationFiesta.WinUI) printf '%s\n' "TranslationFiesta C# WinUI" ;;
    TranslationFiestaElectron) printf '%s\n' "TranslationFiesta TypeScript" ;;
    TranslationFiestaFlutter) printf '%s\n' "TranslationFiesta Dart" ;;
    TranslationFiestaGo) printf '%s\n' "TranslationFiesta Go" ;;
    TranslationFiestaPy) printf '%s\n' "TranslationFiesta Python" ;;
    TranslationFiestaRuby) printf '%s\n' "TranslationFiesta Ruby" ;;
    TranslationFiestaSwift) printf '%s\n' "TranslationFiesta Swift" ;;
    *) printf '%s\n' "$app_name" ;;
  esac
}

resolve_relative_path() {
  local app_dir="$1"
  local target="$2"
  target="${target#"$app_dir"/}"
  printf '%s\n' "$target"
}

resolve_app_target_relative_path() {
  local app_dir="$1"
  local app_name="$2"
  local preferred_binary="$app_dir/$app_name"
  local preferred_app_bundle="$app_dir/$app_name.app"

  if [[ -f "$preferred_binary" && -x "$preferred_binary" ]]; then
    printf '%s\n' "$app_name"
    return 0
  fi

  if [[ "$platform" == "macos" && -d "$preferred_app_bundle" ]]; then
    printf '%s\n' "$app_name.app"
    return 0
  fi

  local candidates=()
  local name_matches=()
  while IFS= read -r path; do
    candidates+=("$path")
    if [[ "$(basename "$path")" == "$app_name" ]]; then
      name_matches+=("$path")
    fi
  done < <(
    find "$app_dir" -type f -perm -111 \
      ! -name 'createdump' \
      ! -name 'unins*' \
      ! -name '*.so' \
      ! -name '*.dylib' \
      ! -name '*.dll' \
      ! -path '*/ruby-runtime/*' | sort
  )

  if [[ ${#name_matches[@]} -gt 0 ]]; then
    resolve_relative_path "$app_dir" "${name_matches[0]}"
    return 0
  fi

  if [[ "$platform" == "macos" ]]; then
    local app_bundle_matches=()
    local app_bundle_candidates=()
    while IFS= read -r app_path; do
      app_bundle_candidates+=("$app_path")
      if [[ "$(basename "$app_path")" == "$app_name.app" ]]; then
        app_bundle_matches+=("$app_path")
      fi
    done < <(find "$app_dir" -type d -name '*.app' | sort)

    if [[ ${#app_bundle_matches[@]} -gt 0 ]]; then
      resolve_relative_path "$app_dir" "${app_bundle_matches[0]}"
      return 0
    fi

    if [[ ${#app_bundle_candidates[@]} -gt 0 ]]; then
      resolve_relative_path "$app_dir" "${app_bundle_candidates[0]}"
      return 0
    fi
  fi

  if [[ ${#candidates[@]} -gt 0 ]]; then
    resolve_relative_path "$app_dir" "${candidates[0]}"
    return 0
  fi

  return 1
}

write_app_launcher() {
  local app_dir="$1"
  local relative_target="$2"
  local launcher_path="$app_dir/$runner_name"
  local open_app="false"
  if [[ "$platform" == "macos" && "$relative_target" == *.app ]]; then
    open_app="true"
  fi

  cat >"$launcher_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail

script_dir="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
target="\$script_dir/$relative_target"

if [[ ! -e "\$target" ]]; then
  echo "Launch target not found: \$target" >&2
  exit 1
fi

if [[ "$open_app" == "true" ]]; then
  exec open "\$target" --args "\$@"
else
  exec "\$target" "\$@"
fi
EOF

  chmod +x "$launcher_path"
}

app_directories=()
while IFS= read -r directory; do
  app_directories+=("$directory")
done < <(find "$root" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#app_directories[@]} -eq 0 ]]; then
  echo "No app directories found under $root" >&2
  exit 1
fi

launchable_apps=()
for app_path in "${app_directories[@]}"; do
  app_name="$(basename "$app_path")"

  if [[ "$app_name" == "TranslationFiestaRuby" ]]; then
    ruby_runner="$app_path/$runner_name"
    if [[ ! -f "$ruby_runner" ]]; then
      echo "Ruby portable payload is missing $runner_name in $app_path" >&2
      exit 1
    fi
    launchable_apps+=("$app_name")
    continue
  fi

  if relative_target="$(resolve_app_target_relative_path "$app_path" "$app_name")"; then
    write_app_launcher "$app_path" "$relative_target"
    launchable_apps+=("$app_name")
  fi
done

if [[ ${#launchable_apps[@]} -eq 0 ]]; then
  echo "No launchable apps found under $root" >&2
  exit 1
fi

unique_apps=()
while IFS= read -r app; do
  unique_apps+=("$app")
done < <(printf '%s\n' "${launchable_apps[@]}" | sort -u)
launchable_apps=("${unique_apps[@]}")

build_script=""
root_leaf="$(basename "$root")"
if [[ "$root_leaf" =~ ^(linux|macos)-(x64|arm64)$ ]]; then
  arch="${BASH_REMATCH[2]}"
  candidate="$root/../../../scripts/build_${platform}_${arch}_release.sh"
  if [[ -f "$candidate" ]]; then
    build_script="$candidate"
  fi
fi

menu_lines=()
case_lines=()
number_resolve_lines=()
name_resolve_lines=()
index=1
for app_name in "${launchable_apps[@]}"; do
  display_name="$(get_app_display_name "$app_name")"
  menu_lines+=("  [$index] $display_name ($app_name)")
  case_lines+=("      $index) app=\"$app_name\" ;;")
  number_resolve_lines+=("    $index) app=\"$app_name\"; return 0 ;;")
  name_resolve_lines+=("    \"$app_name\") app=\"$app_name\"; return 0 ;;")
  name_resolve_lines+=("    \"$display_name\") app=\"$app_name\"; return 0 ;;")
  index=$((index + 1))
done

bundle_launcher_path="$root/$bundle_launcher_name"
{
  cat <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_script="__BUILD_SCRIPT__"
runner_name="__RUNNER_NAME__"
app="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

resolve_app_by_name() {
  local input="$1"
  case "$input" in
__NAME_CASES__
    *)
      return 1
      ;;
  esac
}

resolve_app_by_number() {
  local input="$1"
  case "$input" in
__NUM_RESOLVE_CASES__
    *)
      return 1
      ;;
  esac
}

if [[ -n "$app" ]]; then
  if resolve_app_by_number "$app"; then
    :
  elif resolve_app_by_name "$app"; then
    :
  else
    echo "Unknown app selection: $app" >&2
    exit 1
  fi
fi

while [[ -z "$app" ]]; do
  echo "TranslationFiesta portable launcher"
  echo
  echo "Select an app to launch:"
__MENU_LINES__
  if [[ -n "$build_script" && -f "$build_script" ]]; then
    echo "  [B] Build/Rebuild current bundle"
  fi
  echo "  [Q] Quit"
  read -r -p "Enter selection: " choice

  if [[ -z "$choice" ]]; then
    echo
    continue
  fi

  case "$choice" in
    [Qq])
      exit 0
      ;;
    [Bb])
      if [[ -n "$build_script" && -f "$build_script" ]]; then
        "$build_script"
      else
        echo "Build script not available."
      fi
      echo
      continue
      ;;
__NUM_CASES__
    *)
      if resolve_app_by_name "$choice"; then
        :
      else
        echo "Unknown app selection: $choice"
        echo
        continue
      fi
      ;;
  esac
done

target="$script_dir/$app/$runner_name"
if [[ ! -f "$target" ]]; then
  echo "Missing launcher script: $target" >&2
  exit 1
fi

exec "$target" "$@"
EOF
} > "$bundle_launcher_path"

name_cases=""
for line in "${name_resolve_lines[@]}"; do
  name_cases+="$line"$'\n'
done

num_cases=""
for line in "${case_lines[@]}"; do
  num_cases+="$line"$'\n'
done

num_resolve_cases=""
for line in "${number_resolve_lines[@]}"; do
  num_resolve_cases+="$line"$'\n'
done

menu_block=""
for line in "${menu_lines[@]}"; do
  menu_block+="  echo \"$line\""$'\n'
done

python3 - <<PY
from pathlib import Path

launcher_path = Path(r'''$bundle_launcher_path''')
content = launcher_path.read_text(encoding='utf-8')
content = content.replace('__BUILD_SCRIPT__', r'''$build_script''')
content = content.replace('__RUNNER_NAME__', r'''$runner_name''')
content = content.replace('__NAME_CASES__', r'''$name_cases''')
content = content.replace('__NUM_CASES__', r'''$num_cases''')
content = content.replace('__NUM_RESOLVE_CASES__', r'''$num_resolve_cases''')
content = content.replace('__MENU_LINES__', r'''$menu_block''')
launcher_path.write_text(content, encoding='utf-8')
PY

chmod +x "$bundle_launcher_path"
