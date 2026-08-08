#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
pwsh -NoLogo -NoProfile -File "$script_dir/test-model-routing-discovery.ps1"
