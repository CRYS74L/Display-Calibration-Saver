# Display Calibration Saver

[![Windows](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D4)](https://github.com/CRYS74L/Display-Calibration-Saver)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)](https://learn.microsoft.com/powershell/)
[![Validation](https://github.com/CRYS74L/Display-Calibration-Saver/actions/workflows/powershell-check.yml/badge.svg)](https://github.com/CRYS74L/Display-Calibration-Saver/actions/workflows/powershell-check.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**English** · [简体中文](README.zh-CN.md)

Save the display-calibration preview currently active on Windows as a reusable ICC/ICM profile.

Display Calibration Saver is designed for the awkward case where calibration software can preview the exact white-point, tint, brightness, or tone adjustment you need, but cannot save that adjusted state. The utility captures the calibration curve that is actually active on the selected display and embeds it into a copy of an existing profile.

> The calibration application performs the color calculation. Display Calibration Saver preserves the result; it does not estimate slider values or imitate a vendor algorithm.

## Quick start

1. Download and extract the latest release ZIP.
2. Double-click `Run.cmd`.
3. Select a source ICC/ICM profile that already contains a `vcgt` tag.
4. Choose an output name, display, and countdown duration.
5. Start the countdown and switch to your calibration application.
6. Enable the preview you want to keep and leave it active.
7. When the countdown ends, install and apply the generated profile.

The source profile is never overwritten unless you deliberately choose an existing output file and confirm replacement.

## Why this exists

Many calibration tools temporarily apply preview adjustments to the Windows per-display gamma ramp before saving. If their save step fails, the desired display state may still be active in memory. This project turns that temporary state into a reusable profile.

The workflow is intentionally narrow:

```text
compatible calibration preview
        ↓
active per-display calibration curve
        ↓
copy of the selected ICC/ICM profile
        ↓
new vcgt table containing the captured curve
```

## Features

- Captures the active calibration curve from a selected Windows display
- Preserves the source profile and creates a separate output file
- Stores 256 entries per RGB channel at 16-bit precision
- Supports custom output names and countdown durations
- Validates ICC signatures, tag tables, offsets, alignment, and file boundaries
- Handles ICC v2 reserved header bytes and recalculates ICC v4 Profile IDs
- Runs with built-in Windows PowerShell 5.1
- Requires no installation, administrator privileges, telemetry, or network access

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or later
- A source ICC/ICM profile containing a `vcgt` tag
- A calibration application that applies its preview through the Windows per-display gamma ramp

## Compatibility

The project is not tied to a particular vendor. It can work with any application that exposes its preview through the standard Windows display gamma-ramp path.

A confirmed use case is Datacolor SpyderTune: when the preview is correct but its adjusted profile cannot be saved, Display Calibration Saver can preserve the previewed result.

Other calibration tools and profile loaders may also work. The easiest practical test is whether the adjustment changes the whole desktop on the selected display rather than only one application window.

## What it cannot capture

Display Calibration Saver does not record every visible color transformation. It cannot directly preserve adjustments that exist only in:

- An application's own preview window, shader, or rendering pipeline
- A game's filter or post-processing layer
- A monitor's hardware controls or internal LUT
- A separate 3D LUT pipeline
- Some HDR and advanced-color paths
- Driver overlays that bypass the standard Windows gamma ramp

## How it works

During a compatible preview, the calibration application writes three 256-entry, 16-bit channel tables to the selected display's video LUT. The utility reads those active values through the Windows GDI `GetDeviceGammaRamp` API and writes the exact table into the source profile's `vcgt` tag.

The generated profile keeps the source profile's characterization data. Only the display-calibration table is replaced. See [Technical details](docs/TECHNICAL.md) for the file-layout and validation rules.

## Important limitations

- The source profile must already contain a `vcgt` tag.
- In version 1.0, `vcgt` must be the final profile data block so it can be expanded without relocating unrelated tags.
- Capturing a calibration curve does not create a new measurement-based characterization of the display.
- The generated profile remains valid only for the display state and hardware settings used by the source profile.
- The tool cannot verify visual accuracy without a measuring instrument.

## Troubleshooting

Common failure cases, multi-monitor notes, HDR limitations, and profile-format errors are covered in [Troubleshooting](docs/TROUBLESHOOTING.md).

## Privacy and security

Everything runs locally. The project makes no network requests, uploads no profiles, collects no telemetry, and requests no elevation. The complete PowerShell source is included in every release.

Security reports are covered by [SECURITY.md](SECURITY.md).

## Contributing

Bug reports, reproducible compatibility findings, documentation improvements, and carefully scoped patches are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Disclaimer

Display Calibration Saver is an independent utility and is not affiliated with or endorsed by Datacolor, Microsoft, or any other calibration-software or hardware vendor.

## License

Released under the [MIT License](LICENSE).
