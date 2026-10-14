#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [ ! -d "${ROOT_DIR}/Bubomb.app" ]; then
    echo "💣 Bubomb.app not found. Building now..."
    bash "${SCRIPT_DIR}/build_app.sh"
fi

echo "🚀 Launching Bubomb..."
open "${ROOT_DIR}/Bubomb.app"
echo "💥 Bubomb is now active in your macOS menu bar!"
