#!/usr/bin/env bash
set -euo pipefail

app_name=""
arch=""
rebuild="false"
no_build_prompt="false"
app_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      arch="${2:-}"
      shift 2
      ;;
    --rebuild)
      rebuild="true"
      shift
      ;;
    --no-build-prompt)
      no_build_prompt="true"
      shift
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        app_args+=("$1")
        shift
      done
      ;;
    *)
      if [[ -z "$app_name" ]]; then
        app_name="$1"
      else
        app_args+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ -n "$arch" && "$arch" != "x64" && "$arch" != "arm64" ]]; then
  echo "Unsupported architecture: $arch (expected x64 or arm64)" >&2
  exit 1
fi

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_root/.." && pwd)"
release_root="$repo_root/dist/release"
launcher_generator="$repo_root/scripts/create_unix_launchers.sh"

platform=""
uname_out="$(uname -s)"
case "$uname_out" in
  Linux*)
    platform="linux"
    launcher_name="launch.sh"
    ;;
  Darwin*)
    platform="macos"
    launcher_name="launch.command"
    ;;
  *)
    echo "Unsupported platform for unix launcher wizard: $uname_out" >&2
    exit 1
    ;;
esac

get_build_script_for_arch() {
  local bundle_arch="$1"
  local candidate="$repo_root/scripts/build_${platform}_${bundle_arch}_release.sh"
  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
  fi
}

invoke_bundle_build() {
  local bundle_arch="$1"
  local build_script
  build_script="$(get_build_script_for_arch "$bundle_arch" || true)"
  if [[ -z "$build_script" ]]; then
    echo "No local build script is available for ${platform}-${bundle_arch}." >&2
    exit 1
  fi

  "$build_script"
}

get_bundle_dirs() {
  if [[ ! -d "$release_root" ]]; then
    return 0
  fi

  find "$release_root" -mindepth 1 -maxdepth 1 -type d -name "${platform}-*" | sort
}

select_bundle_root() {
  local selected_arch="$1"
  local allow_prompt="$2"
  local bundle_dirs=()
  while IFS= read -r dir; do
    bundle_dirs+=("$dir")
  done < <(get_bundle_dirs)

  if [[ -n "$selected_arch" ]]; then
    local target="$release_root/${platform}-${selected_arch}"
    if [[ -d "$target" ]]; then
      printf '%s\n' "$target"
      return 0
    fi
    return 0
  fi

  if [[ ${#bundle_dirs[@]} -eq 1 ]]; then
    printf '%s\n' "${bundle_dirs[0]}"
    return 0
  fi

  if [[ ${#bundle_dirs[@]} -gt 1 && "$allow_prompt" == "true" ]]; then
    echo "Select ${platform} bundle architecture:"
    local i=1
    for dir in "${bundle_dirs[@]}"; do
      echo "  [$i] $(basename "$dir")"
      i=$((i + 1))
    done

    while true; do
      read -r -p "Enter selection (or Q): " choice
      if [[ "$choice" =~ ^[Qq]$ ]]; then
        return 0
      fi

      if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if (( choice >= 1 && choice <= ${#bundle_dirs[@]} )); then
          printf '%s\n' "${bundle_dirs[choice-1]}"
          return 0
        fi
      fi

      for dir in "${bundle_dirs[@]}"; do
        if [[ "$(basename "$dir")" == "$choice" ]]; then
          printf '%s\n' "$dir"
          return 0
        fi
      done

      echo "Unknown selection: $choice"
    done
  fi
}

preferred_arch="x64"
machine_arch="$(uname -m)"
if [[ "$machine_arch" == "aarch64" || "$machine_arch" == "arm64" ]]; then
  preferred_arch="arm64"
fi

selected_arch="$arch"
if [[ "$rebuild" == "true" ]]; then
  if [[ -z "$selected_arch" ]]; then
    selected_arch="$preferred_arch"
  fi
  invoke_bundle_build "$selected_arch"
fi

bundle_root="$(select_bundle_root "$selected_arch" "true" || true)"
if [[ -z "$bundle_root" ]]; then
  if [[ "$no_build_prompt" == "true" ]]; then
    echo "No ${platform} bundle found under $release_root" >&2
    exit 1
  fi

  build_arch="$selected_arch"
  if [[ -z "$build_arch" ]]; then
    build_arch="x64"
  fi

  build_script="$(get_build_script_for_arch "$build_arch" || true)"
  if [[ -z "$build_script" ]]; then
    echo "No bundle found for ${platform}-${build_arch} and no local build script exists for that architecture." >&2
    exit 1
  fi

  read -r -p "${platform}-${build_arch} bundle not found. Build now? [Y/n] " choice
  if [[ -z "$choice" || "$choice" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
    invoke_bundle_build "$build_arch"
    bundle_root="$(select_bundle_root "$build_arch" "false" || true)"
  fi
fi

if [[ -z "$bundle_root" ]]; then
  echo "Launch cancelled."
  exit 1
fi

if [[ ! -x "$launcher_generator" ]]; then
  chmod +x "$launcher_generator"
fi
"$launcher_generator" --root "$bundle_root" --platform "$platform"

bundle_launcher="$bundle_root/$launcher_name"
if [[ ! -f "$bundle_launcher" ]]; then
  echo "Bundle launcher not found after generation: $bundle_launcher" >&2
  exit 1
fi

if [[ -z "$app_name" ]]; then
  "$bundle_launcher"
else
  "$bundle_launcher" "$app_name" "${app_args[@]}"
fi
