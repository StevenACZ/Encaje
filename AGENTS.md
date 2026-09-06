# Encaje

Public macOS window manager. Swift 6, SwiftPM, macOS 14+, Apple Silicon.

- Support English and Spanish UI; keep code and documentation in English.
- Prefer small native AppKit/SwiftUI components; keep dependencies minimal (Sparkle for signed updates).
- Pure geometry and serializable contracts belong to EncajeCore.
- AX operations, input interception and UI belong to EncajeApp, MainActor isolated.
- Never reset TCC or modify other applications' preferences for tests.
- Local installations must be Apple Development signed with a stable bundle ID.
- Default Shift hotkeys: Q/W/E, A/S/D, Z/X/C form the spatial grid.
- Matching hotkeys consume uppercase letters; explain this and offer pause/exclusions.
- No continuous animations while idle. Permission tracking runs only when visible.
- Before permission grant, the guide cannot rely on trusted Accessibility APIs.
- Preserve user window state for undo; handle constrained windows honestly.
- No generated explanatory comments. Only document essential constraints.
- Full gate: make check (Swift format lint, swift test, signed Release bundle).
- Do not test the build bundle while rebuilding it; use the installed copy.
- Permission guide stays inside Settings content with pixel-aligned geometry.
- Keep generated artifacts, signing identities and private data out of Git.
- Root owns integration, Git, installation and real UI verification.
- Use explicit closures for MainActor Binding setters; Swift 6.3.3 crashes on method references.
- AX success is not frame acceptance: verify actual geometry, including same-display resize clipping.
- Readiness text must use the full model.ready state, not permission alone.
- Cross-display acceptance must cover a full round trip between unequal screen sizes; verify the realized frame after settling.
