# Releasing Encaje

Release maintainers must complete these checks before publishing artifacts or an
update feed. A checklist is not evidence that a release has passed its gates.
Keep credentials and signing material outside the repository.

## Prepare

1. Review the source, repository history and assets for private data and generated
   artifacts. Confirm license and support links are ready for public use.
2. Set matching app version and build metadata. Cut the dated changelog entry and
   retain an empty `Unreleased` section.
3. Run `make check` on the final source. Review dependency versions and the bundled
   Sparkle framework. Keep the installed development app Apple Development signed.

The release pipeline is `make release`, writing to `build/release-artifacts`.
It uses the existing notarization Keychain profile and keeps credentials out of Git.

## Validate distribution

1. Build separate Developer ID signed distribution artifacts for Apple Silicon.
   Verify the app and all nested code signatures, notarize and staple the app and
   DMG, and assess them with macOS Gatekeeper.
2. Produce the update ZIP from the verified distribution app. Verify archive contents,
   version metadata and signatures after extraction; generate SHA-256 checksums.
3. Match the signing public key to `SUPublicEDKey` with `scripts/verify-update-key.sh`,
   then sign the ZIP and feed. Verify that appcast version,
   build number, minimum OS, enclosure URL, length and signature match the exact ZIP.
4. Test clean installation, Accessibility setup, optional restart, launch at login,
   retained settings and an update from an older test build. Check both acceptance
   and cancellation, failure recovery, and rejection of invalid update signatures.
5. Verify optional daily checks and explicit installation in a public build, and
   confirm that an Apple Development build does not consume the public update feed.
6. Keep the development installation intact during distribution QA. If temporary
   replacement is indispensable, restore and verify its Apple Development signature
   before completing the release.

## Publish and verify

1. Review final artifacts, checksums, changelog and rollback procedure. Confirm
   authorization for public publication and any repository visibility change.
2. Publish the versioned release with its DMG, update ZIP and checksums. Publish the
   signed appcast only after its referenced assets are downloadable.
3. Verify downloads against the published checksums, inspect the served appcast,
   and check the user-facing download and update paths.
4. Retain the previous verified release artifacts. If an update is faulty, stop
   advertising it in the feed and publish a corrected release with a higher build
   number; do not reuse a published build number or silently replace its binaries.

For the initial release scope, see [release plan](release-plan.md).
