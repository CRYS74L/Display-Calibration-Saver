#requires -version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot "dist"
}

$mainScript = Join-Path $projectRoot "Save-Display-Calibration.ps1"
$scriptText = Get-Content -Raw -Encoding UTF8 -LiteralPath $mainScript
if ($scriptText -notmatch ('\$ScriptVersion\s*=\s*"{0}"' -f [regex]::Escape($Version))) {
    throw "Save-Display-Calibration.ps1 does not declare version $Version."
}

$packageFiles = @(
    "Run.cmd",
    "Save-Display-Calibration.ps1",
    "LICENSE",
    "README.md",
    "README.en.md"
)

foreach ($relativePath in $packageFiles) {
    if (-not [IO.File]::Exists((Join-Path $projectRoot $relativePath))) {
        throw "Release input is missing: $relativePath"
    }
}

$outputDirectoryFullPath = [IO.Path]::GetFullPath($OutputDirectory)
[IO.Directory]::CreateDirectory($outputDirectoryFullPath) | Out-Null
$archivePath = Join-Path $outputDirectoryFullPath ("Display-Calibration-Saver-v{0}.zip" -f $Version)
$stagingDirectory = Join-Path ([IO.Path]::GetTempPath()) ("display-calibration-saver-release-{0}" -f [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($stagingDirectory) | Out-Null

try {
    foreach ($relativePath in $packageFiles) {
        [IO.File]::Copy(
            (Join-Path $projectRoot $relativePath),
            (Join-Path $stagingDirectory $relativePath),
            $false
        )
    }

    if ([IO.File]::Exists($archivePath)) {
        [IO.File]::Delete($archivePath)
    }
    Compress-Archive -Path (Join-Path $stagingDirectory "*") -DestinationPath $archivePath -CompressionLevel Optimal
}
finally {
    if ([IO.Directory]::Exists($stagingDirectory)) {
        [IO.Directory]::Delete($stagingDirectory, $true)
    }
}

Write-Output $archivePath
