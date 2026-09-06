#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
fixture_dir="$(mktemp -d /tmp/encaje-fixture.XXXXXX)"
fixture="$fixture_dir/Encaje Performance Fixture.app"
mkdir -p "$fixture/Contents/MacOS"
swiftc -swift-version 6 scripts/fixtures/WindowFixture.swift -o "$fixture/Contents/MacOS/EncajeFixture"
cat > "$fixture/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.stevenacz.Encaje.PerformanceFixture</string>
<key>CFBundleName</key><string>Encaje Performance Fixture</string>
<key>CFBundleExecutable</key><string>EncajeFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
identity="${ENCAJE_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F '"' '/Apple Development/ {print $2; exit}')}"
test -n "$identity"
codesign --force --sign "$identity" "$fixture"
codesign --verify --strict "$fixture"
printf '%s\n' "$fixture"
