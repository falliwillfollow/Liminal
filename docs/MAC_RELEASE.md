# macOS Official Distribution (Signed + Notarized)

This project can already be exported as a mac app zip:

- `build/Liminal-mac.zip`

To make it feel official on macOS (no scary Gatekeeper warning), you need:

1. Apple Developer Program membership.
2. A **Developer ID Application** certificate.
3. Notarization credentials.

## Option A: One-command local notarization on a Mac

Use:

- `scripts/release/notarize_macos.sh`

Example:

```bash
export DEVELOPER_ID_APP_CERT="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="you@example.com"
export APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
export APPLE_TEAM_ID="TEAMID1234"
bash scripts/release/notarize_macos.sh
```

Output:

- `build/Liminal-macOS-notarized.dmg`

Notes:

- If `build/macos/Liminal.app` is missing, the script unpacks `build/Liminal-mac.zip`.
- You can use a keychain profile instead of Apple ID/password:
  - `export NOTARY_KEYCHAIN_PROFILE="your-profile-name"`

## Option B: GitHub Actions notarized build

Workflow file:

- `.github/workflows/macos-notarized-build.yml`

Required repository secrets:

- `MACOS_DEVELOPER_ID_APP_CERT_BASE64` (base64 of `.p12`)
- `MACOS_DEVELOPER_ID_APP_CERT_PASSWORD`
- `MACOS_TEMP_KEYCHAIN_PASSWORD`
- `DEVELOPER_ID_APP_CERT` (exact certificate identity string)
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

Run workflow manually from Actions tab:

- **macOS Notarized Build**

Artifacts:

- `build/Liminal-mac.zip`
- `build/Liminal-macOS-notarized.dmg`
