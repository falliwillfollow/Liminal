#!/usr/bin/env bash
set -euo pipefail

# Notarizes a Godot macOS app bundle and produces a notarized DMG.
# Run this on macOS with Xcode command line tools installed.

APP_NAME="${APP_NAME:-Liminal}"
BUILD_DIR="${BUILD_DIR:-build/macos}"
EXPORT_ZIP="${EXPORT_ZIP:-build/Liminal-mac.zip}"
APP_PATH="${APP_PATH:-${BUILD_DIR}/${APP_NAME}.app}"
ZIP_PATH="${ZIP_PATH:-${BUILD_DIR}/${APP_NAME}-notary.zip}"
DMG_PATH="${DMG_PATH:-build/${APP_NAME}-macOS-notarized.dmg}"

: "${DEVELOPER_ID_APP_CERT:?Set DEVELOPER_ID_APP_CERT, e.g. 'Developer ID Application: Your Name (TEAMID)'}"

mkdir -p "${BUILD_DIR}"

if [[ ! -d "${APP_PATH}" ]]; then
  if [[ ! -f "${EXPORT_ZIP}" ]]; then
    echo "Missing app bundle and export zip:"
    echo "  APP_PATH=${APP_PATH}"
    echo "  EXPORT_ZIP=${EXPORT_ZIP}"
    exit 1
  fi
  rm -rf "${APP_PATH}"
  ditto -x -k "${EXPORT_ZIP}" "${BUILD_DIR}"
fi

echo "Signing app bundle..."
codesign --force --deep --options runtime --timestamp --sign "${DEVELOPER_ID_APP_CERT}" "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
spctl --assess --type exec --verbose=2 "${APP_PATH}"

echo "Submitting app bundle for notarization..."
ditto -c -k --keepParent "${APP_PATH}" "${ZIP_PATH}"
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" --wait
else
  : "${APPLE_ID:?Set APPLE_ID or NOTARY_KEYCHAIN_PROFILE}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD or NOTARY_KEYCHAIN_PROFILE}"
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID or NOTARY_KEYCHAIN_PROFILE}"
  xcrun notarytool submit "${ZIP_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait
fi

echo "Stapling app bundle..."
xcrun stapler staple "${APP_PATH}"
xcrun stapler validate "${APP_PATH}"

echo "Building DMG..."
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${APP_PATH}" -ov -format UDZO "${DMG_PATH}"
codesign --force --timestamp --sign "${DEVELOPER_ID_APP_CERT}" "${DMG_PATH}"

echo "Submitting DMG for notarization..."
if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  xcrun notarytool submit "${DMG_PATH}" --keychain-profile "${NOTARY_KEYCHAIN_PROFILE}" --wait
else
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait
fi

echo "Stapling DMG..."
xcrun stapler staple "${DMG_PATH}"
spctl --assess --type open --verbose=2 "${DMG_PATH}"

echo "Done."
echo "Notarized DMG: ${DMG_PATH}"
