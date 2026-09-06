# Security and privacy

## Data and permissions

Encaje uses macOS Accessibility to inspect and move windows and handle configured
shortcuts. Saved workspaces can contain application identifiers, window titles and
window geometry. Preferences, custom zone names and workspaces are stored locally.
Do not attach your preferences or workspace data to a public issue without reviewing
and removing private information.

Encaje does not request Screen Recording, Microphone, Full Disk Access or Automation
permission. The app does not require an account. Update checks and downloads contact
the public release infrastructure; the hosting provider can receive normal request
metadata such as your IP address. Optional daily checks can be disabled.

## Distribution and updates

Public release artifacts use Developer ID signing and notarization. Sparkle 2
verifies signed updates; installation requires a user action. Development builds
use Apple Development signing and do not consume the public update feed.
Download releases only from the project's
[GitHub Releases](https://github.com/StevenACZ/Encaje/releases).

## Reporting a vulnerability

Use **Report a vulnerability** in the repository's
[Security tab](https://github.com/StevenACZ/Encaje/security) when private reporting
is available. Include the affected version, impact and a minimal reproduction
without real private data or credentials.

If private reporting is unavailable, open an issue requesting a private contact
channel. Do not publish exploit details, secrets or sensitive user data in that
issue. Security fixes target the latest release; older versions do not have a
separate maintenance policy.
