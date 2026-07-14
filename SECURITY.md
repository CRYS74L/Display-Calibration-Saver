# Security Policy

## Supported versions

Security fixes are applied to the latest published version.

## Reporting a vulnerability

Do not publish private ICC profiles, display serial numbers, user paths, or other personal metadata in a public issue.

For ordinary input-validation or crash bugs, open a GitHub issue with a minimal reproduction. For a report that would expose sensitive information, contact the repository owner through the email address listed on the owner's GitHub profile.

Please include:

- A concise description of the impact
- The affected version
- Reproduction steps using a sanitized profile when possible
- Whether the issue can overwrite or corrupt files outside the selected output path

## Security model

Display Calibration Saver:

- Makes no network requests
- Requests no administrator privileges
- Does not install a service or scheduled task
- Reads one user-selected profile and the selected display's active gamma ramp
- Writes only to the user-selected output path

Users are encouraged to review the included PowerShell source before running it in environments with strict script-execution policies.
