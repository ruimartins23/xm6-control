#!/bin/bash
# Builds "XM6 Control.app" with its WidgetKit extension embedded.
#
# Needs full Xcode: a widget extension is an .appex bundle with App Intents metadata,
# which only xcodebuild produces. `swift build` still builds the app alone (no widget)
# with just the Command Line Tools.
#
# Code signing: Xcode refuses to sign the extension's entitlements without a development
# team, so xcodebuild runs unsigned and the bundle is signed here instead. If a
# signing identity named "XM6Dev" exists (self-signed code-signing certificate from
# Keychain Access) it is used, so macOS keeps the Bluetooth grant across rebuilds;
# otherwise the bundle is signed ad hoc.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-Release}"
APP_NAME="XM6 Control"
DERIVED=".build/xcode"
APP_DIR=".build/${APP_NAME}.app"
APPEX="${APP_DIR}/Contents/PlugIns/XM6Widget.appex"
SIGN_IDENTITY="XM6Dev"

# App icon. The hero photo is the canonical artwork when present, so the Dock icon
# matches the headphones the app controls; vector artwork is the fallback.
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

if command -v xcodegen >/dev/null; then
    xcodegen generate --quiet
fi

echo "==> Building (${CONFIG})..."
xcodebuild -quiet \
    -project XM6Control.xcodeproj \
    -scheme XM6ControlApp \
    -configuration "${CONFIG}" \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGNING_ALLOWED=NO \
    build

rm -rf "${APP_DIR}"
cp -R "${DERIVED}/Build/Products/${CONFIG}/${APP_NAME}.app" "${APP_DIR}"

# No -v flag: self-signed certs report CSSMERR_TP_NOT_TRUSTED (filtered by -v)
# yet still sign successfully.
if security find-identity -p codesigning 2>/dev/null | grep -q "\"${SIGN_IDENTITY}\""; then
    IDENTITY="${SIGN_IDENTITY}"
    echo "==> Signing with ${SIGN_IDENTITY} (stable identity, no permission re-prompts)..."
else
    IDENTITY="-"
    echo "==> Ad-hoc signing (create an '${SIGN_IDENTITY}' certificate to avoid permission re-prompts)..."
fi
# Inside out: the extension first, then the app that seals it.
codesign --force --sign "${IDENTITY}" --entitlements Config/XM6Widget.entitlements "${APPEX}"
codesign --force --sign "${IDENTITY}" "${APP_DIR}"

echo "==> Done: ${APP_DIR}"
echo "    Install with: ditto \"${APP_DIR}\" \"/Applications/${APP_NAME}.app\""
