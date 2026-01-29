#!/bin/bash
set -euo pipefail

REPO="Priyans-hu/tokenmeter"
APP_NAME="TokenMeter"
INSTALL_DIR="/Applications"

echo "Installing ${APP_NAME}..."

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: ${APP_NAME} only supports macOS."
  exit 1
fi

# Get latest release download URL
DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep "browser_download_url.*\.zip" \
  | head -1 \
  | cut -d '"' -f 4)

if [[ -z "${DOWNLOAD_URL}" ]]; then
  echo "Error: Could not find latest release."
  exit 1
fi

VERSION=$(echo "${DOWNLOAD_URL}" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
echo "Found ${APP_NAME} ${VERSION}"

# Download to temp dir
TMPDIR=$(mktemp -d)
trap 'rm -rf "${TMPDIR}"' EXIT

echo "Downloading..."
curl -sL "${DOWNLOAD_URL}" -o "${TMPDIR}/${APP_NAME}.zip"

echo "Extracting..."
unzip -q "${TMPDIR}/${APP_NAME}.zip" -d "${TMPDIR}"

# Remove old version if exists
if [[ -d "${INSTALL_DIR}/${APP_NAME}.app" ]]; then
  echo "Removing existing ${APP_NAME}..."
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

# Move to Applications
echo "Installing to ${INSTALL_DIR}..."
mv "${TMPDIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

# Remove quarantine attribute
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}.app" 2>/dev/null || true

echo ""
echo "${APP_NAME} ${VERSION} installed successfully!"
echo ""
echo "Launch from Applications or Spotlight."
echo "⭐ Star us on GitHub: https://github.com/Priyans-hu/tokenmeter"
