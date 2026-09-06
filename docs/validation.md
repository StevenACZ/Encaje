# Development validation

Run `make check` for formatting, unit tests and the Apple Development signed bundle.
The tests cover grid bounds and gutters, asymmetric display traversal, constrained
windows, display disconnection, rule migration, modifier combinations, setup
persistence, permission-card placement and conditional AX resize correction.

## Controlled window benchmark

Build and open the dedicated test fixture:

```bash
scripts/build-fixture.sh
```

The script prints its generated app path. Open that app, then run the installed
Encaje binary with `ENCAJE_QA=1` and `--benchmark-pid <fixture-pid>`.
The command rejects any process outside the fixture's exact bundle/window allowlist.

The benchmark alternates old and optimized AX command paths on one fixture,
compares final geometry using independent scalar reads, and restores its original
frame. It also exercises Z → Q → E → Z → Q with one command per step. Any
mismatched final rectangle or failed restoration fails acceptance, regardless of
how quickly the AX calls return.

Initialize `NSApplication.shared` before any headless `NSScreen` query. Read
`visibleFrame` fresh for the current test; an uninitialized probe can report the
wrong usable area on a secondary display.

The measured duration covers synchronous AX work and bounded verification. It
excludes physical keyboard delivery, event-queue delay before the command, and
compositor presentation. A fast failed resize is not an improvement; AX success
alone does not establish the intended window size. AppKit may clip an initial
resize by its previous position even on the same display; the engine conditionally
retries when the observed size proves that correction is needed.

## Interactive checks

- Record Command+W without closing Settings; record Control+Option+key; cancel and
  clear recording; reject exact duplicates while allowing distinct modifiers.
- Use the full navigation row, edit a named temporary zone, drag a selection and
  change its numeric bounds. Restore or remove only that test zone.
- Save/restore/delete an owned test workspace; preserve unrelated windows.
- Add/remove a temporary exclusion; check startup preference without retaining a
  changed login setting after QA.
- Open/close the menu panel by icon, outside click and Escape; Configuration/About
  must retain focus, and closed views must release monitors/rendering work.
- Check the app icon in both its UI and the system's representation.
- After closing the UI and settling for at least one minute, sample process CPU
  and memory over multiple intervals. Report bundle size separately from ignored
  development caches and rollback artifacts.

## Unequal-display return regression

Exercise right → left → neighboring right → neighboring left → right → original
left → original right with one physical keypress per step. Verify complete usable
height in both directions after settling; an outward-only test misses stale AppKit
screen limits on the return. Corrections run only for unchanged clipped frames and
use per-window tickets so a workspace batch does not cancel earlier windows.

Permission image layout is verified against a 256-point source image: the hosted
native drag view must remain 58 × 58 points. App-owned before/after rendering can
verify this without resetting Accessibility or requesting screen recording.
