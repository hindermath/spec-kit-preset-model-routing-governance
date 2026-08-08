#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
command -v pwsh >/dev/null 2>&1 || {
  printf 'BLOCKED: pwsh 7 is required for portable model-routing resolution.\n' >&2
  exit 3
}
exec pwsh -NoLogo -NoProfile -File "$script_dir/resolve-model-routing.ps1" "$@"
