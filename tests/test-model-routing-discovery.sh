#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  printf 'BLOCKIERT: PowerShell 7 (pwsh) wird fuer den plattformuebergreifenden Routing-Test benoetigt. / BLOCKED: PowerShell 7 (pwsh) is required for the cross-platform routing test.\n' >&2
  exit 3
fi

if ! pwsh -NoLogo -NoProfile -Command 'if ($PSVersionTable.PSVersion.Major -lt 7) { exit 1 }' >/dev/null 2>&1; then
  printf 'BLOCKIERT: Gefundenes pwsh ist aelter als Version 7. / BLOCKED: The detected pwsh is older than version 7.\n' >&2
  exit 3
fi

exec pwsh -NoLogo -NoProfile -File "$script_dir/test-model-routing-discovery.ps1" "$@"
