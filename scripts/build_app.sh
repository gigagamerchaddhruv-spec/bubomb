#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

echo "💣 Building Bubomb (Release configuration)..."
swift build -c release --product Bubomb

BIN_PATH="${ROOT_DIR}/.build/release/Bubomb"
if [ ! -f "${BIN_PATH}" ]; then
    echo "❌ Error: Binary not found at ${BIN_PATH}"
    exit 1
fi

APP_NAME="Bubomb.app"
APP_DIR="${ROOT_DIR}/${APP_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Assembling ${APP_NAME} bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy binary
cp "${BIN_PATH}" "${MACOS_DIR}/Bubomb"
chmod +x "${MACOS_DIR}/Bubomb"

# Copy Info.plist
cp "${ROOT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy Icon
if [ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Ad-hoc code signing for macOS
echo "🔏 Signing application bundle (ad-hoc)..."
codesign --force --deep --sign - "${APP_DIR}"

echo "🔍 Verifying code signature..."
codesign --verify --deep --strict "${APP_DIR}"

echo "✅ Successfully built and bundled: ${APP_DIR}"
echo "👉 Run with: open ${APP_NAME}"
