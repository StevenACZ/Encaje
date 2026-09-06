#!/bin/bash
set -euo pipefail
bundle="${1:?Usage: sign-bundle.sh APP}"
distribution="${ENCAJE_DISTRIBUTION:-0}"
[[ "$distribution" == 0 || "$distribution" == 1 ]] || exit 64
if [[ "$distribution" == 1 ]]; then authority='Developer ID Application'; else authority='Apple Development'; fi
identity="${ENCAJE_SIGN_IDENTITY:-}"
if [[ -z "$identity" ]]; then
    identities=()
    while IFS= read -r candidate; do identities+=("$candidate"); done < <(
        security find-identity -v -p codesigning | awk -F '"' -v kind="$authority" 'index($2, kind ":") == 1 {print $2}'
    )
    [[ ${#identities[@]} == 1 ]] || {
        echo "Expected one $authority identity; set ENCAJE_SIGN_IDENTITY explicitly." >&2; exit 65;
    }
    identity="${identities[0]}"
fi
flags=(--force --options runtime --sign "$identity")
if [[ "$distribution" == 1 ]]; then flags+=(--timestamp); else flags+=(--timestamp=none); fi
framework="$bundle/Contents/Frameworks/Sparkle.framework"
for nested in XPCServices/Downloader.xpc XPCServices/Installer.xpc Updater.app Autoupdate; do
    codesign "${flags[@]}" --preserve-metadata=entitlements "$framework/Versions/B/$nested"
done
codesign "${flags[@]}" "$framework"
codesign "${flags[@]}" "$bundle"
codesign --verify --deep --strict "$bundle"
codesign -dvv "$bundle" 2>&1 | awk -v kind="$authority" 'index($0, "Authority=" kind ":") == 1 {found=1} END {exit !found}'
