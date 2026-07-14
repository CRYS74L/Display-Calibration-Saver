# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows semantic versioning.

## [Unreleased]

## [1.0.1] - 2026-07-15

### Fixed

- Reject ICC profiles whose declared size differs from the actual file length
- Reject duplicate or too-short `vcgt` entries with controlled errors
- Preserve an existing output file if writing its replacement fails
- Release display and dialog resources reliably when an operation fails

### Added

- Warn before saving an exact linear identity gamma ramp
- Let users choose both the output name and save location
- Add dependency-free regression tests for ICC v2/v4 output, Profile IDs, malformed profiles, identity detection, and atomic replacement
- Build and validate a Simplified-Chinese-first `v1.0.1` release package

### Changed

- Expand documentation for driver-dependent gamma-ramp behavior and strict ICC validation
- Run functional regression tests and release-package verification in GitHub Actions

## [1.0.0] - 2026-07-15

### Added

- Capture the calibration preview currently active on a selected Windows display
- Embed a 3 × 256 × 16-bit calibration table into an existing ICC/ICM `vcgt` tag
- Custom output naming and countdown duration
- ICC signature, tag-table, alignment, offset, and boundary validation
- ICC v2 reserved-field handling and ICC v4 Profile ID recalculation
- English and Simplified Chinese documentation
- GitHub issue templates and automated PowerShell syntax validation

[Unreleased]: https://github.com/CRYS74L/Display-Calibration-Saver/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/CRYS74L/Display-Calibration-Saver/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/CRYS74L/Display-Calibration-Saver/releases/tag/v1.0.0
