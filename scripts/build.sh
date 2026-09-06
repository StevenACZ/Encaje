#!/bin/bash
set -euo pipefail
cd -P "$(dirname "$0")/.."
distribution="${ENCAJE_DISTRIBUTION:-0}"
[[ "$distribution" == 0 || "$distribution" == 1 ]] || exit 64
output_dir="${ENCAJE_OUTPUT_DIR:-$PWD/build}"
if [[ "$distribution" == 1 && -z "${ENCAJE_OUTPUT_DIR:-}" ]]; then
    output_dir="$PWD/build/distribution"
fi
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
output="$output_dir/Encaje.app"
ensure_build_closed() {
    for encaje_pid in $(pgrep -x Encaje || true); do
        if [[ "$(ps -p "$encaje_pid" -o comm=)" == "$output/Contents/MacOS/Encaje" ]]; then
            echo 'Quit the build copy of Encaje before rebuilding it.' >&2
            exit 75
        fi
    done
}
ensure_build_closed
swift build -c release --arch arm64 --product Encaje \
    -Xswiftc -file-prefix-map -Xswiftc "$PWD=." \
    -Xswiftc -gnone
bundle_stage="$(mktemp -d "$output_dir/.encaje-bundle.XXXXXX")"
trap 'rm -rf "$bundle_stage"' EXIT
bundle="$bundle_stage/Encaje.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
bin_dir="$(swift build -c release --arch arm64 --show-bin-path)"
cp "$bin_dir/Encaje" "$bundle/Contents/MacOS/Encaje"
cp Assets/Info.plist "$bundle/Contents/Info.plist"
cp Assets/AppIcon.icns "$bundle/Contents/Resources/EncajeIcon.icns"
plist="$bundle/Contents/Info.plist"
if [[ -n "${APP_VERSION:-}" ]]; then
    [[ "$APP_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 64
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$plist"
fi
if [[ -n "${APP_BUILD:-}" ]]; then
    [[ "$APP_BUILD" =~ ^[1-9][0-9]*$ ]] || exit 64
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $APP_BUILD" "$plist"
fi
/usr/libexec/PlistBuddy -c 'Delete :EncajeDevelopmentBuild' "$plist" 2>/dev/null || true
if [[ "$distribution" == 1 ]]; then development=false; else development=true; fi
/usr/libexec/PlistBuddy -c "Add :EncajeDevelopmentBuild bool $development" "$plist"
frameworks=(.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-*/Sparkle.framework)
[[ ${#frameworks[@]} == 1 && -d "${frameworks[0]}" ]] || {
    echo 'Expected exactly one Sparkle macOS framework.' >&2; exit 66;
}
mkdir -p "$bundle/Contents/Frameworks"
ditto "${frameworks[0]}" "$bundle/Contents/Frameworks/Sparkle.framework"
binary="$bundle/Contents/MacOS/Encaje"
while IFS= read -r rpath; do
    if [[ "$rpath" == /* ]]; then install_name_tool -delete_rpath "$rpath" "$binary"; fi
done < <(otool -l "$binary" | awk '/cmd LC_RPATH/ {getline; getline; sub(/^ *path /, ""); sub(/ \(offset.*$/, ""); print}')
strip -S "$binary"
scripts/sign-bundle.sh "$bundle"
ensure_build_closed
if [[ -e "$output" ]]; then mv "$output" "$bundle_stage/previous.app"; fi
if ! mv "$bundle" "$output"; then
    if [[ -e "$bundle_stage/previous.app" ]]; then mv "$bundle_stage/previous.app" "$output"; fi
    exit 74
fi
echo "Built and verified: $output"
