# Technical details

## Capture path

The script opens a display device context for the selected Windows display and calls `GetDeviceGammaRamp`. Windows returns three arrays containing 256 unsigned 16-bit entries each, ordered as red, green, and blue.

No color-temperature or tint formula is implemented. The values are copied from the active display state.

`GetDeviceGammaRamp` is a legacy, driver-dependent GDI path. A successful read contains three arrays of 256 `WORD` values, but it does not represent every HDR, Advanced Color, shader, overlay, or hardware-LUT transformation. If the captured table is an exact linear identity ramp, the interactive workflow warns before saving it.

## ICC output

The source profile acts as the characterization base. The current version requires one existing `vcgt` tag and replaces that tag with a table containing:

| Field | Value |
|---|---:|
| Table type | 0 |
| Channels | 3 |
| Entries per channel | 256 |
| Bytes per entry | 2 |
| RGB payload | 1536 bytes |

The profile-size field and `vcgt` tag-size field are updated. The resulting file is padded to a 4-byte boundary.

The completed byte array is written to a temporary file in the destination directory, flushed to disk, and then moved or atomically replaced. A failed write therefore leaves an existing destination file unchanged.

## Validation

Before writing, the script verifies:

- The `acsp` ICC signature
- A declared profile size that exactly matches the file length
- A plausible tag count and a complete tag table within the declared profile
- Tag offsets outside the header and tag table
- 4-byte tag alignment
- Tag boundaries within the declared profile length
- Exactly one `vcgt` tag-table entry
- A `vcgt` data block large enough to contain its type signature
- A real `vcgt` data block at the referenced offset
- That no other referenced tag data extends past the start of `vcgt`

The final restriction allows the `vcgt` block to be expanded from an 8-bit table to a 16-bit table without relocating unrelated tags.

## ICC version handling

For ICC v2 profiles, header bytes 84–99 are reserved and are set to zero.

For ICC v4 profiles, bytes 84–99 contain the Profile ID. The script recalculates the MD5-based ID after the file has been rebuilt. During digest calculation, the profile flags, rendering intent, and Profile ID fields are zeroed as required by the ICC calculation procedure.

## Why a source profile is required

A captured gamma ramp is calibration data, not a complete device characterization. The source profile supplies the display primaries, tone-response information, white-point description, and other color-management metadata. Reusing a source profile is only appropriate when the display and its hardware settings still match the state for which that profile was created.

## Automated validation

Run the dependency-free regression suite with Windows PowerShell 5.1:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

The tests cover ICC v2/v4 output, Profile ID calculation, `vcgt` serialization, malformed profile rejection, identity-ramp detection, and atomic replacement behavior. Release packages are built with:

```powershell
.\tools\Build-Release.ps1 -Version 1.0.1
```

GitHub Actions parses every PowerShell file, runs the regression suite, rebuilds the package, and verifies that each archived file matches the repository source.
