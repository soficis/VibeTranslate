#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wizard="$script_dir/scripts/unix_launch_wizard.sh"

if [[ ! -f "$wizard" ]]; then
  echo "Missing launcher script: $wizard" >&2
  exit 1
fi

if [[ ! -x "$wizard" ]]; then
  chmod +x "$wizard"
fi

"$wizard" "$@"
