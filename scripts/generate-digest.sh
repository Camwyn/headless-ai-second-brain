#!/usr/bin/env bash
# Shell wrapper for generate-digest.ps1
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v pwsh >/dev/null 2>&1; then
    pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/generate-digest.ps1" "$@"
elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/generate-digest.ps1" "$@"
else
    echo "[generate-digest] Error: Neither 'pwsh' nor 'powershell' was found on PATH." >&2
    exit 1
fi
