# Development

Requires macOS 14 or later, Apple Silicon and Swift 6. An Apple Development signing
identity is needed only for signed local bundles. Encaje uses SwiftPM, native AppKit/SwiftUI and Sparkle 2 for public updates.

## Compile without signing

```bash
swift test
swift build -c release --product Encaje
```

These checks need no signing credentials. CI runs them for pull requests.

## Build and install

```bash
make check
scripts/install-dev.sh
```

`make check` runs strict Swift formatting lint, unit tests and a signed Release
bundle build. Local installation must remain Apple Development signed with a
stable bundle identifier. Do not run the build copy while rebuilding it; use the
installed app for interactive testing. Development builds do not consume public
updates.

`ENCAJE_SIGN_IDENTITY` selects an installed development identity.
`ENCAJE_INSTALL_DIR` overrides the default `/Applications` destination. The
installer refuses to overwrite a running app and saves an existing installation
in `build/rollback-*.zip`.

To roll back, quit Encaje, extract the chosen archive into a separate folder with
`ditto -x -k`, verify the extracted app's signature with `codesign --verify --strict`,
and replace the installed bundle. Verify Apple Development signing before relaunch.

## Layout

- `Sources/EncajeCore`: grid zones, display navigation and serializable rules.
- `Sources/EncajeApp`: Accessibility, hotkeys, native controls, setup and updates.
- `Tests`: geometry, migration, modifiers, permissions and movement regressions.

Keep pure geometry in EncajeCore and AppKit/Accessibility work on the main actor
in EncajeApp. Preserve user window state for restoration and respect application
size constraints. A successful Accessibility call does not prove that the requested
frame was accepted; verify the resulting geometry.

## Validation and diagnostics

See [development validation](validation.md) for fixture benchmarks and interactive
checks. Test only owned windows; never reset TCC or modify other apps' preferences.

`ENCAJE_DEFAULTS_SUITE` selects isolated preferences. `ENCAJE_SHOW_SETTINGS` and
`ENCAJE_SHOW_POPOVER` open surfaces for QA. `--diagnostics` prints version, display
count, login status and Accessibility availability.

Performance instrumentation is opt-in. `ENCAJE_MOVEMENT_METRICS_FILE` records
content-free command timings; `ENCAJE_PERMISSION_METRICS_FILE` records aggregate
tracking timings. These measure command and tracking work, not presented-frame FPS.

Keep signing identities, credentials, preferences, captures and generated artifacts
out of the repository. Public distribution follows [releasing](releasing.md).
