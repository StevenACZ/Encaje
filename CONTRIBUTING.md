# Contributing to Encaje

Bug reports and focused pull requests are welcome. Use
[Issues](https://github.com/StevenACZ/Encaje/issues) for reproducible bugs and
feature proposals; read [SECURITY.md](SECURITY.md) before reporting a vulnerability.

Include your macOS version, Encaje version, steps to reproduce, and expected versus
actual behavior. For movement problems, describe display arrangement and scaling,
and whether the target app imposes window-size limits. Remove private window
titles, document contents and account information from reports and screenshots.

## Changes

1. Read [development setup](docs/development.md) and the repository's `AGENTS.md`.
2. Keep changes focused and follow the existing Swift formatting and architecture.
3. Add regression coverage for behavioral changes; use isolated preferences and
   owned test windows for interactive checks.
4. Run `make check` and any relevant checks in [validation](docs/validation.md).
5. Describe the user-visible result, validation performed and remaining limitations
   in your pull request. Add a concise `CHANGELOG.md` entry under `Unreleased`.

Keep user-facing strings in English and Spanish. Do not commit signing identities,
credentials, personal preferences, captures, build outputs or rollback archives.
Never reset system permissions or change another application's preferences for a test.

Contributions are distributed under the project's [MIT license](LICENSE).
