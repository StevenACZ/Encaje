# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [1.3.1] - 2026-09-25

### Fixed

- On a Mac where Encaje is already set up, launching it no longer flashes the setup window and the welcome for a few seconds.

## [1.3.0] - 2026-09-25

### Changed

- First launch asks for Accessibility in one setup window with a short reason. Open Settings shows a guide inside System Settings that follows its window and lets you drag Encaje's icon into the list; once access is on, a short welcome plays and closes by itself. Macs where Encaje is already set up skip it.

## [1.2.0] - 2026-09-23

### Added

- Windows glide into place when you use a shortcut, undo or restore, in about a fifth of a second. Turn it off with "Animate windows" in Preferences; it also stays off while Reduce Motion is on. Moves to another display stay instant.

### Changed

- Window spacing now starts at 0 pt, so windows sit edge to edge unless you choose a spacing in Preferences. A spacing you already set is kept.
- Preferences icons share one column and the spacing slider sits next to its label.

### Fixed

- A window that its app keeps taller or wider than a bottom zone is moved back inside the screen instead of ending partly below it.
- Warnings after a shortcut, such as "This application limits its window size or position", now disappear on their own after a few seconds.

## [1.1.3] - 2026-09-18

### Fixed

- The settings window is a little taller and Preferences is more compact, so the Updates card is no longer cut off at the bottom.
- The disabled "Save current" and "Restore" buttons in Workspaces stay readable in Light appearance.
- Switches that are off are clearly visible on the settings cards in Light appearance.
- The zone grid lines and the small footnotes in Zones and Preferences are easier to read in both appearances.

## [1.1.2] - 2026-09-18

### Fixed

- Quiet checks keep running while an update is on offer and after a failed update, so a newer version shows up without restarting Encaje. The card only changes when a newer version is actually found, a failed update keeps its Retry, and nothing is ever installed without "Install now".
- Pressing Update while a slow check is still running no longer ends in a failed update: the download waits for that check to finish and still stops at "Ready to install".

## [1.1.1] - 2026-09-18

### Changed

- New versions show up on their own within minutes: Encaje checks quietly when you open the menu bar panel, after waking and every 30 minutes (only while automatic checks are on).

### Fixed

- Retry and Update never install on their own: a prepared update always stops at "Ready to install" and waits for "Install now".
- "Check for updates" always answers now: if a quiet check is still running it shows "Checking…" and runs your check as soon as that one ends.
- Pressing Update right after a quiet check no longer does nothing: the download starts as soon as that check finishes and still stops at "Ready to install".

## [1.1.0] - 2026-09-18

### Added

- An update card in the menu bar panel with download progress, a percentage and a
  ready-to-install state offering Install now or Later.
- A redesigned About window with the version and build number, update status and
  actions, and links to the project and its issue tracker.

### Changed

- Made the menu bar panel opaque instead of translucent.
- Install now quits and reopens Encaje by itself once the update is installed.
- Moved the update card above the pause/resume button in the menu bar panel.
- Use blue consistently for Accessibility setup and green for granted access, preserving the app brand.

## [1.0.1] - 2026-09-06

### Changed

- Simplified Settings and Welcome windows with integrated native window controls.
- Reduced unused space at the bottom of the menu bar panel.

### Fixed

- Made the entire painted pause/resume button clickable, including its empty edges.
- Expanded add, dismiss and restore-defaults button targets.
- Aligned the language selector with the switches in Preferences.

## [1.0.0] - 2026-09-06

First public release.

### Added

- Custom grid zones with drag selection, exact cell controls, names and spacing.
- Configurable shortcuts using Command, Option, Control and Shift, with an editable
  spatial layout for Shift + Q/W/E, A/S/D and Z/X/C.
- Undo and redo for zone geometry, plus selectable reference outlines to compare zones.
- Window movement across neighboring displays, original-size restore and saved workspaces.
- Native Accessibility setup with verified permission state and restart recovery.
- A menu bar panel with pause/resume, configuration, About and Quit.
- Application exclusions and optional launch at login.
- Instant, persistent system-language, English and Spanish preferences.
- Signed in-app updates through Sparkle 2, with optional daily checks, explicit
  installation and separation from development builds.
