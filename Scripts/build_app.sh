#!/bin/bash
# Builds XM6Control and packages it into a double-clickable .app bundle.
# Xcode 26+ adds the Control Center extension; older toolchains build the same
# menu-bar app without that extension using SwiftPM.
#
# Code signing: if a signing identity named "XM6Dev" exists in the keychain
# (self-signed code-signing certificate created via Keychain Access), the app is
# signed with it so macOS keeps the Bluetooth permission grant across rebuilds.
# Otherwise it falls back to ad-hoc signing, which re-prompts after every rebuild.
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP_NAME="XM6 Control"
BUILD_DIR=".build/${CONFIG}"
APP_DIR=".build/${APP_NAME}.app"
SIGN_IDENTITY="XM6Dev"
XCODE_DERIVED_DATA=".build/xcode"

case "${CONFIG}" in
    debug) XCODE_CONFIGURATION="Debug" ;;
    release) XCODE_CONFIGURATION="Release" ;;
    *)
        echo "error: configuration must be 'debug' or 'release'" >&2
        exit 2
        ;;
esac

build_with_cache_recovery() (
    local build_log
    build_log="$(mktemp -t xm6-control-build.XXXXXX)"
    trap 'rm -f "${build_log}"' EXIT

    if swift build -c "${CONFIG}" 2>&1 | tee "${build_log}"; then
        return 0
    fi

    # Swift's precompiled headers contain absolute ModuleCache paths. If the
    # checkout is moved, an otherwise valid incremental build fails until the
    # path-bound artifacts are removed.
    if grep -Eq \
        "PCH was compiled with module cache path|PCH file .* was built from a different branch" \
        "${build_log}"; then
        echo "==> Stale Swift module cache detected; cleaning and retrying..."
        swift package clean
        swift build -c "${CONFIG}"
        return
    fi

    return 1
)

supports_control_center_build() {
    local sdk_version sdk_major
    sdk_version="$(xcrun --sdk macosx --show-sdk-version 2>/dev/null || true)"
    sdk_major="${sdk_version%%.*}"
    [[ "${sdk_major}" =~ ^[0-9]+$ ]] && [ "${sdk_major}" -ge 26 ]
}

assemble_legacy_app() {
    echo "==> Building menu-bar app with SwiftPM (${CONFIG})..."
    build_with_cache_recovery

    echo "==> Assembling ${APP_NAME}.app..."
    rm -rf "${APP_DIR}"
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"

    cp "${BUILD_DIR}/XM6Control" "${APP_DIR}/Contents/MacOS/XM6Control"
    cp "Sources/XM6Control/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"
    cp "Sources/XM6Control/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
}

assemble_control_center_app() {
    echo "==> Building app and Control Center extension with Xcode (${XCODE_CONFIGURATION})..."
    xcodebuild \
        -project XM6Control.xcodeproj \
        -scheme XM6ControlApp \
        -configuration "${XCODE_CONFIGURATION}" \
        -destination "platform=macOS,arch=$(uname -m)" \
        -derivedDataPath "${XCODE_DERIVED_DATA}" \
        CODE_SIGNING_ALLOWED=NO \
        build

    local built_app
    built_app="${XCODE_DERIVED_DATA}/Build/Products/${XCODE_CONFIGURATION}/${APP_NAME}.app"
    if [ ! -d "${built_app}/Contents/PlugIns/XM6ControlWidgets.appex" ]; then
        echo "error: Xcode build did not embed XM6ControlWidgets.appex" >&2
        return 1
    fi

    rm -rf "${APP_DIR}"
    ditto "${built_app}" "${APP_DIR}"
}

sign_app() {
    local identity="$1"
    local control_extension="${APP_DIR}/Contents/PlugIns/XM6ControlWidgets.appex"

    if [ -d "${control_extension}" ]; then
        codesign \
            --force \
            --sign "${identity}" \
            --entitlements "Extensions/XM6ControlWidgets/XM6ControlWidgets.entitlements" \
            "${control_extension}"
    fi
    codesign --force --sign "${identity}" "${APP_DIR}"
}

# The app icon is generated artwork, not checked into the repo. Create it on demand.
if [ ! -f "Sources/XM6Control/Resources/AppIcon.icns" ]; then
    echo "==> Generating app icon..."
    swift Scripts/make_icon.swift
fi

if supports_control_center_build; then
    assemble_control_center_app
else
    assemble_legacy_app
    echo "==> Control Center tiles require the macOS 26 SDK; menu-bar controls are included."
fi

# Optional hero photo: drop your own headphones.png into Resources and it appears in-app.
if [ -f "Sources/XM6Control/Resources/headphones.png" ]; then
    cp "Sources/XM6Control/Resources/headphones.png" "${APP_DIR}/Contents/Resources/headphones.png"
fi

# No -v flag: self-signed certs report CSSMERR_TP_NOT_TRUSTED (filtered by -v)
# yet still sign successfully.
if security find-identity -p codesigning 2>/dev/null | grep -q "\"${SIGN_IDENTITY}\""; then
    echo "==> Signing with ${SIGN_IDENTITY} (stable identity, no permission re-prompts)..."
    sign_app "${SIGN_IDENTITY}"
else
    echo "==> Ad-hoc code signing (create an '${SIGN_IDENTITY}' certificate to avoid permission re-prompts)..."
    sign_app -
fi

echo "==> Done: ${APP_DIR}"
echo "    Launch with: open \"${APP_DIR}\""
