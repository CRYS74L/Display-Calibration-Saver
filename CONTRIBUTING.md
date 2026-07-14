# Contributing

Thank you for helping improve Display Calibration Saver.

## Good contributions

- Reproducible compatibility reports for calibration applications
- ICC/ICM files reduced to the smallest non-private test case
- Clear fixes for profile parsing, validation, and Windows display selection
- Documentation and translation improvements
- Tests that exercise malformed or unusual profile layouts

## Before opening an issue

1. Confirm that the adjustment changes the entire selected display, not only one application window.
2. Confirm that the source profile contains a `vcgt` tag.
3. Retry with Windows HDR disabled when the problem involves capture behavior.
4. Remove private metadata and personal profiles from any public attachment.
5. Include the exact error message shown by the script.

## Development

The project intentionally targets Windows PowerShell 5.1 and avoids external runtime dependencies.

Before submitting a change:

1. Keep compatibility with Windows PowerShell 5.1.
2. Do not add network access, telemetry, elevation, or background services.
3. Keep source profiles read-only by default.
4. Validate all binary offsets and lengths before reading or writing.
5. Update both English and Chinese documentation when user-visible behavior changes.
6. Add an entry to `CHANGELOG.md` for release-relevant changes.

## Pull requests

Keep pull requests focused. Explain:

- What changed
- Why the change is needed
- How it was tested
- Which profile versions or software scenarios are affected

By contributing, you agree that your contribution is licensed under the repository's MIT License.
