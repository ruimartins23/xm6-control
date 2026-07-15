#!/bin/bash
# Builds XM6Control and packages it into a double-clickable .app bundle.
# No Xcode required -- this only needs the Swift toolchain (Command Line Tools).
#
# Code signing: if a signing identity named "XM6Dev" exists in the keychain
# (self-signed code-signing certificate created via Keychain Access), the app is
# signed with it so macOS keeps the Bluetooth permission grant across rebuilds.
# Otherwise it falls back to ad-hoc signing, which re-prompts after every rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="XM6 Control"
BUNDLE_ID="com.local.xm6control"
BUILD_DIR=".build/${CONFIG}"
APP_DIR=".build/${APP_NAME}.app"
SIGN_IDENTITY="XM6Dev"

echo "==> Building (${CONFIG})..."
swift build -c "${CONFIG}"

# The app icon is generated artwork, not checked into the repo. Create it on demand.
if [ ! -f "Sources/XM6Control/Resources/AppIcon.icns" ]; then
    echo "==> Generating app icon..."
    swift Scripts/make_icon.swift
fi

echo "==> Assembling ${APP_NAME}.app..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/XM6Control" "${APP_DIR}/Contents/MacOS/XM6Control"
cp "Sources/XM6Control/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Sources/XM6Control/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

# Optional hero photo: drop your own headphones.png into Resources and it appears in-app.
if [ -f "Sources/XM6Control/Resources/headphones.png" ]; then
    cp "Sources/XM6Control/Resources/headphones.png" "${APP_DIR}/Contents/Resources/headphones.png"
fi

# No -v flag: self-signed certs report CSSMERR_TP_NOT_TRUSTED (filtered by -v)
# yet still sign successfully.
if security find-identity -p codesigning 2>/dev/null | grep -q "\"${SIGN_IDENTITY}\""; then
    echo "==> Signing with ${SIGN_IDENTITY} (stable identity, no permission re-prompts)..."
    codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_DIR}"
else
    echo "==> Ad-hoc code signing (create an '${SIGN_IDENTITY}' certificate to avoid permission re-prompts)..."
    codesign --force --deep --sign - "${APP_DIR}"
fi

echo "==> Done: ${APP_DIR}"
echo "    Launch with: open \"${APP_DIR}\""
