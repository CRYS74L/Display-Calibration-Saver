# Troubleshooting

## The generated profile looks unchanged

- Confirm that the calibration application's preview was still active when the countdown ended.
- Confirm that the preview changes the entire selected display rather than only the application's own window.
- Make sure the correct display was selected in the tool.
- Compare the reported white-end values, but remember that some curves change mostly in the midtones and may keep the white endpoint unchanged.

## All endpoints are 65535

This does not automatically mean capture failed. A curve may preserve the maximum endpoint while changing intermediate entries. Apply the generated profile and compare it with the source profile.

## “The source profile does not contain a vcgt tag”

The selected profile contains characterization data but no embedded video-card calibration table. Version 1.0 cannot add a brand-new tag-table entry. Use a source profile that already contains `vcgt`.

## “The vcgt tag is not the final data block”

The profile stores referenced data after `vcgt`. Version 1.0 refuses to relocate all following tags because doing so incorrectly could corrupt the profile. Try another profile from the same calibration workflow or open an issue with a sanitized sample.

## The wrong display changes

Windows and some display drivers may expose gamma ramps differently on cloned displays, docks, or multi-GPU systems. Disable display cloning, verify the selected `\\.\DISPLAYn` device, and retry.

## HDR is enabled

The standard Windows gamma ramp does not represent every HDR or Advanced Color transformation. Disable HDR for a controlled test. A successful SDR capture does not guarantee equivalent HDR behavior.

## The calibration software resets the preview

Some applications restore the previous gamma ramp when they lose focus or when a dialog closes. Increase or shorten the countdown so capture occurs while the preview is visibly active.

## PowerShell execution is blocked

`Run.cmd` starts the script with a process-local execution-policy bypass. Domain policy or security software can still block unsigned scripts. Review the source and follow the policy required by your organization; do not weaken system-wide policy solely for this tool.

## Windows reloads another calibration later

Windows Color Management, vendor software, DisplayCAL Profile Loader, or another calibration loader may overwrite the gamma ramp after login, wake, display reconfiguration, or application launch. Ensure only the intended loader applies the generated profile.
