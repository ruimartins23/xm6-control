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

# App icon. The hero photo is the canonical artwork when it is present, so the Dock
# icon matches the headphones the app controls; the generated vector artwork is the
# fallback for a checkout without a photo.
ICON_SRC="Sources/XM6Control/Resources/headphones.png"
ICON_OUT="Sources/XM6Control/Resources/AppIcon.icns"
if [ -f "${ICON_SRC}" ]; then
    if [ ! -f "${ICON_OUT}" ] || [ "${ICON_SRC}" -nt "${ICON_OUT}" ] || [ "Scripts/make_icon_from_photo.swift" -nt "${ICON_OUT}" ]; then
        echo "==> Generating app icon from headphones.png..."
        swift Scripts/make_icon_from_photo.swift
        iconutil -c icns ".build/AppIcon.iconset" -o "${ICON_OUT}"
    fi
elif [ ! -f "${ICON_OUT}" ]; then
    echo "==> Generating app icon (vector artwork)..."
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
