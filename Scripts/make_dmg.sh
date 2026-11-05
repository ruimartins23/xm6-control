#!/bin/bash
# Packages XM6 Control as a drag-to-install disk image: the standard way a Mac app
# is distributed. Open the DMG, drag the app onto the Applications shortcut, eject.
#
# Output: dist/XM6-Control-<version>.dmg
#
# Uses only tools that ship with macOS (hdiutil, SetFile, codesign), so it needs
# nothing beyond the Command Line Tools the build already requires.
set -euo pipefail

cd "$(dirname "$0")/.."
REPO_DIR="$(pwd)"

APP_NAME="XM6 Control"
APP_DIR=".build/${APP_NAME}.app"
SIGN_IDENTITY="XM6Dev"

./Scripts/build_app.sh

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_DIR}/Contents/Info.plist")
OUT_DIR="${REPO_DIR}/dist"
# Hyphens rather than spaces, so the file survives being a download URL.
OUT="${OUT_DIR}/XM6-Control-${VERSION}.dmg"

# Everything below happens in a temporary directory, not in the checkout. If the
# checkout is in an iCloud-synced folder, iCloud's File Provider keeps re-adding
# Finder metadata to the app bundle, and a bundle carrying that metadata fails the
# strict signature check Gatekeeper applies to downloads: it opens as "damaged" on
# someone else's Mac. $TMPDIR is never synced.
WORK=$(mktemp -d "${TMPDIR:-/tmp}/xm6-dmg.XXXXXX")
MOUNT_POINT=""
cleanup() {
    if [ -n "${MOUNT_POINT}" ]; then
        hdiutil detach -quiet "${MOUNT_POINT}" 2>/dev/null || true
    fi
    rm -rf "${WORK}"
}
trap cleanup EXIT

STAGE="${WORK}/stage"
APP_COPY="${STAGE}/${APP_NAME}.app"
mkdir -p "${STAGE}" "${OUT_DIR}"

echo "==> Preparing a clean, signed copy..."
# ditto rather than cp -R: it keeps the bundle structure and symlinks exactly.
ditto "${APP_DIR}" "${APP_COPY}"
xattr -cr "${APP_COPY}" 2>/dev/null || true
if security find-identity -p codesigning 2>/dev/null | grep -q "\"${SIGN_IDENTITY}\""; then
    codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_COPY}"
else
    codesign --force --deep --sign - "${APP_COPY}"
fi
# The check Gatekeeper effectively applies to a download. Refuse to package a copy
# that would fail it.
codesign --verify --deep --strict "${APP_COPY}"

ln -s /Applications "${STAGE}/Applications"

echo "==> Building disk image..."
SCRATCH="${WORK}/rw.dmg"
hdiutil create -quiet -volname "${APP_NAME}" -srcfolder "${STAGE}" \
    -fs HFS+ -format UDRW -ov "${SCRATCH}"

# Mounted with -nobrowse so Finder doesn't pop the volume open on the desktop while
# the script is working on it.
MOUNT_POINT=$(hdiutil attach -nobrowse -noverify -noautoopen "${SCRATCH}" \
    | awk -F '\t' '/\/Volumes\// { print $NF; exit }')

# The app icon as the volume icon, so the mounted disk is recognisable in Finder's
# sidebar instead of showing a generic drive.
cp "${REPO_DIR}/Sources/XM6Control/Resources/AppIcon.icns" "${MOUNT_POINT}/.VolumeIcon.icns"
SetFile -c icnC "${MOUNT_POINT}/.VolumeIcon.icns"
SetFile -a C "${MOUNT_POINT}"

hdiutil detach -quiet "${MOUNT_POINT}"
MOUNT_POINT=""

echo "==> Compressing..."
FINAL="${WORK}/final.dmg"
hdiutil convert -quiet "${SCRATCH}" -format UDZO -imagekey zlib-level=9 -o "${FINAL}"

# The disk image itself is deliberately left unsigned. Signing it with a self-signed
# certificate gains nothing (no other Mac trusts that certificate), and unsigned
# images are what open-source Mac apps normally ship. What Gatekeeper evaluates is
# the app inside, which is signed above. With an Apple Developer ID, this is where
# the image would be signed and sent for notarization.
rm -f "${OUT}"
cp "${FINAL}" "${OUT}"

echo "==> Done: ${OUT#${REPO_DIR}/} ($(du -h "${OUT}" | cut -f1 | tr -d ' '))"
