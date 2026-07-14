#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$NoRun
)

$ErrorActionPreference = "Stop"
$ScriptVersion = "1.0.1"

Add-Type -AssemblyName System.Windows.Forms

if (-not ("GammaRampNative" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class GammaRampNative
{
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr CreateDC(
        string pwszDriver,
        string pwszDevice,
        string pszPort,
        IntPtr pdm
    );

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool DeleteDC(IntPtr hdc);

    [DllImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetDeviceGammaRamp(
        IntPtr hDC,
        IntPtr lpRamp
    );
}
"@
}

function Read-U32BE {
    param([byte[]]$Bytes, [int]$Offset)
    return (
        ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
    )
}

function Write-U32BE {
    param([byte[]]$Bytes, [int]$Offset, [uint32]$Value)
    $Bytes[$Offset]     = [byte](($Value -shr 24) -band 0xFF)
    $Bytes[$Offset + 1] = [byte](($Value -shr 16) -band 0xFF)
    $Bytes[$Offset + 2] = [byte](($Value -shr 8) -band 0xFF)
    $Bytes[$Offset + 3] = [byte]($Value -band 0xFF)
}

function Write-BytesAtomically {
    param(
        [string]$Path,
        [byte[]]$Bytes
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $directory = [IO.Path]::GetDirectoryName($fullPath)
    $fileName = [IO.Path]::GetFileName($fullPath)
    $operationId = [Guid]::NewGuid().ToString("N")
    $temporaryPath = Join-Path $directory (".{0}.{1}.tmp" -f $fileName, $operationId)
    $backupPath = Join-Path $directory (".{0}.{1}.bak" -f $fileName, $operationId)

    try {
        $stream = New-Object IO.FileStream(
            $temporaryPath,
            [IO.FileMode]::CreateNew,
            [IO.FileAccess]::Write,
            [IO.FileShare]::None
        )
        try {
            $stream.Write($Bytes, 0, $Bytes.Length)
            $stream.Flush($true)
        }
        finally {
            $stream.Dispose()
        }

        if ([IO.File]::Exists($fullPath)) {
            [IO.File]::Replace($temporaryPath, $fullPath, $backupPath)
        }
        else {
            [IO.File]::Move($temporaryPath, $fullPath)
        }
    }
    finally {
        if ([IO.File]::Exists($temporaryPath)) {
            [IO.File]::Delete($temporaryPath)
        }
        if ([IO.File]::Exists($backupPath)) {
            [IO.File]::Delete($backupPath)
        }
    }
}


function Update-IccProfileId {
    param([byte[]]$ProfileBytes)

    if ($ProfileBytes.Length -lt 128) {
        throw "The ICC profile is too small to update its header."
    }

    $majorVersion = [int]$ProfileBytes[8]

    # ICC v2 reserves bytes 84-99 and requires them to be zero.
    if ($majorVersion -lt 4) {
        for ($i = 84; $i -lt 100; $i++) {
            $ProfileBytes[$i] = 0
        }
        return
    }

    # ICC v4 Profile ID is the MD5 digest of the complete profile with
    # the profile flags, rendering intent, and Profile ID fields zeroed.
    [byte[]]$digestInput = New-Object byte[] $ProfileBytes.Length
    [Array]::Copy($ProfileBytes, $digestInput, $ProfileBytes.Length)

    foreach ($range in @(@(44, 47), @(64, 67), @(84, 99))) {
        for ($i = $range[0]; $i -le $range[1]; $i++) {
            $digestInput[$i] = 0
        }
    }

    $md5 = [Security.Cryptography.MD5]::Create()
    try {
        [byte[]]$digest = $md5.ComputeHash($digestInput)
    }
    finally {
        $md5.Dispose()
    }

    [Array]::Copy($digest, 0, $ProfileBytes, 84, 16)
}

function Select-IccFile {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    try {
        $dialog.Title = "Select the source ICC/ICM profile"
        $dialog.Filter = "ICC/ICM profiles (*.icc;*.icm)|*.icc;*.icm|All files (*.*)|*.*"
        $dialog.Multiselect = $false

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw "No source profile was selected."
        }

        return $dialog.FileName
    }
    finally {
        $dialog.Dispose()
    }
}

function Select-Display {
    $screens = [System.Windows.Forms.Screen]::AllScreens

    Write-Host ""
    Write-Host "Select the display whose active gamma ramp should be captured:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $screens.Count; $i++) {
        $screen = $screens[$i]
        $primary = if ($screen.Primary) { " (Primary)" } else { "" }
        Write-Host ("[{0}] {1}  {2}x{3}{4}" -f
            ($i + 1),
            $screen.DeviceName,
            $screen.Bounds.Width,
            $screen.Bounds.Height,
            $primary
        )
    }

    while ($true) {
        $answer = Read-Host "Display number"
        $index = 0
        if ([int]::TryParse($answer, [ref]$index)) {
            if ($index -ge 1 -and $index -le $screens.Count) {
                return $screens[$index - 1].DeviceName
            }
        }
        Write-Host "Invalid display number. Try again." -ForegroundColor Yellow
    }
}

function Get-OutputPath {
    param([string]$SourcePath)

    $directory = [IO.Path]::GetDirectoryName($SourcePath)
    $stem = [IO.Path]::GetFileNameWithoutExtension($SourcePath)
    $defaultName = "{0}-captured.icm" -f $stem

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    try {
        $dialog.Title = "Save the captured ICC/ICM profile"
        $dialog.Filter = "ICM profile (*.icm)|*.icm|ICC profile (*.icc)|*.icc"
        $dialog.DefaultExt = "icm"
        $dialog.AddExtension = $true
        $dialog.OverwritePrompt = $true
        $dialog.RestoreDirectory = $true
        $dialog.InitialDirectory = $directory
        $dialog.FileName = $defaultName

        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw "No output profile was selected."
        }

        $outputPath = [IO.Path]::GetFullPath($dialog.FileName)
        if ($outputPath -eq [IO.Path]::GetFullPath($SourcePath)) {
            throw "The output path must be different from the source profile."
        }

        return $outputPath
    }
    finally {
        $dialog.Dispose()
    }
}

function Get-CountdownSeconds {
    $answer = Read-Host "Capture countdown in seconds [15]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return 15
    }

    $seconds = 0
    if (-not [int]::TryParse($answer, [ref]$seconds)) {
        throw "Countdown must be a whole number."
    }
    if ($seconds -lt 1 -or $seconds -gt 300) {
        throw "Countdown must be between 1 and 300 seconds."
    }

    return $seconds
}

function Capture-GammaRamp {
    param([string]$DeviceName)

    $hdc = [GammaRampNative]::CreateDC(
        "DISPLAY",
        $DeviceName,
        $null,
        [IntPtr]::Zero
    )
    if ($hdc -eq [IntPtr]::Zero) {
        throw "Could not open display device $DeviceName."
    }

    $size = 3 * 256 * 2
    $buffer = [IntPtr]::Zero

    try {
        $buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal($size)
        if (-not [GammaRampNative]::GetDeviceGammaRamp($hdc, $buffer)) {
            throw "The graphics driver did not return the active gamma ramp."
        }

        $raw = New-Object byte[] $size
        [Runtime.InteropServices.Marshal]::Copy($buffer, $raw, 0, $size)

        $ramp = New-Object 'UInt16[]' (3 * 256)
        for ($i = 0; $i -lt $ramp.Length; $i++) {
            $ramp[$i] = [BitConverter]::ToUInt16($raw, $i * 2)
        }

        return $ramp
    }
    finally {
        if ($buffer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer)
        }
        [void][GammaRampNative]::DeleteDC($hdc)
    }
}

function Build-VcgtTag16 {
    param([UInt16[]]$Ramp)

    if ($Ramp.Length -ne 768) {
        throw "Unexpected gamma-ramp length."
    }

    # vcgt signature + reserved + table type + table metadata + RGB tables.
    $tagSize = 18 + (3 * 256 * 2)
    $tag = New-Object byte[] $tagSize

    $signature = [Text.Encoding]::ASCII.GetBytes("vcgt")
    [Array]::Copy($signature, 0, $tag, 0, 4)

    Write-U32BE -Bytes $tag -Offset 8 -Value 0

    # 3 channels, 256 entries per channel, 2 bytes per entry.
    $tag[12] = 0
    $tag[13] = 3
    $tag[14] = 1
    $tag[15] = 0
    $tag[16] = 0
    $tag[17] = 2

    $position = 18
    for ($i = 0; $i -lt $Ramp.Length; $i++) {
        $value = [uint16]$Ramp[$i]
        $tag[$position] = [byte](($value -shr 8) -band 0xFF)
        $tag[$position + 1] = [byte]($value -band 0xFF)
        $position += 2
    }

    return $tag
}

function Test-IdentityGammaRamp {
    param([UInt16[]]$Ramp)

    if ($Ramp.Length -ne 768) {
        throw "Unexpected gamma-ramp length."
    }

    foreach ($channelOffset in @(0, 256, 512)) {
        for ($i = 0; $i -lt 256; $i++) {
            if ($Ramp[$channelOffset + $i] -ne [uint16]($i * 257)) {
                return $false
            }
        }
    }

    return $true
}

function Patch-IccWithCapturedRamp {
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [UInt16[]]$Ramp
    )

    [byte[]]$source = [IO.File]::ReadAllBytes($SourcePath)

    if ($source.Length -lt 132) {
        throw "The selected file is too small to be a valid ICC profile."
    }

    $acsp = [Text.Encoding]::ASCII.GetString($source, 36, 4)
    if ($acsp -ne "acsp") {
        throw "The selected file does not contain the ICC 'acsp' signature."
    }

    $declaredSize = Read-U32BE -Bytes $source -Offset 0
    if ($declaredSize -gt $source.Length) {
        throw "The ICC header declares a size larger than the actual file."
    }
    if ($declaredSize -lt 132) {
        throw "The ICC header declares an implausibly small profile size."
    }
    if ($declaredSize -ne $source.Length) {
        throw "The ICC header size does not match the actual file length."
    }

    $tagCount = Read-U32BE -Bytes $source -Offset 128
    if ($tagCount -gt 4096) {
        throw "The ICC tag count is implausibly large."
    }

    $tagTableEnd = 132 + ([uint64]$tagCount * 12)
    if ($tagTableEnd -gt $declaredSize) {
        throw "The ICC tag table extends beyond the file boundary."
    }

    $vcgtEntryOffset = -1
    $vcgtEntryCount = 0
    $vcgtOffset = 0
    $vcgtSize = 0
    [uint64]$maxOtherEnd = 0

    for ($i = 0; $i -lt $tagCount; $i++) {
        $entry = 132 + ($i * 12)
        if ($entry + 12 -gt $declaredSize) {
            throw "The ICC tag table is truncated."
        }

        $signature = [Text.Encoding]::ASCII.GetString($source, $entry, 4)
        $offset = Read-U32BE -Bytes $source -Offset ($entry + 4)
        $size = Read-U32BE -Bytes $source -Offset ($entry + 8)

        [uint64]$tagEnd = [uint64]$offset + [uint64]$size
        if ($offset -lt $tagTableEnd) {
            throw "ICC tag '$signature' overlaps the profile header or tag table."
        }
        if (($offset % 4) -ne 0) {
            throw "ICC tag '$signature' is not aligned to a 4-byte boundary."
        }
        if ($tagEnd -gt $declaredSize) {
            throw "ICC tag '$signature' extends beyond the file boundary."
        }

        if ($signature -eq "vcgt") {
            $vcgtEntryCount++
            if ($vcgtEntryCount -gt 1) {
                throw "The source profile contains multiple vcgt tag entries."
            }
            $vcgtEntryOffset = $entry
            $vcgtOffset = $offset
            $vcgtSize = $size
        }
        else {
            if ($tagEnd -gt $maxOtherEnd) {
                $maxOtherEnd = $tagEnd
            }
        }
    }

    if ($vcgtEntryOffset -lt 0) {
        throw "The source profile does not contain a vcgt tag."
    }
    if ($vcgtSize -lt 4) {
        throw "The source vcgt tag is too small to contain a type signature."
    }
    if (([uint64]$vcgtOffset + [uint64]$vcgtSize) -gt $declaredSize) {
        throw "The source vcgt tag extends beyond the file boundary."
    }
    $vcgtType = [Text.Encoding]::ASCII.GetString($source, $vcgtOffset, 4)
    if ($vcgtType -ne "vcgt") {
        throw "The vcgt tag table entry does not point to a vcgt data block."
    }
    if ($maxOtherEnd -gt $vcgtOffset) {
        throw "The vcgt tag is not the final data block, so it cannot be safely expanded in place."
    }

    [byte[]]$newVcgt = Build-VcgtTag16 -Ramp $Ramp
    $unpaddedLength = $vcgtOffset + $newVcgt.Length
    $newFileLength = ($unpaddedLength + 3) -band (-bnot 3)

    [byte[]]$result = New-Object byte[] $newFileLength
    [Array]::Copy($source, 0, $result, 0, $vcgtOffset)
    [Array]::Copy($newVcgt, 0, $result, $vcgtOffset, $newVcgt.Length)

    Write-U32BE -Bytes $result -Offset 0 -Value $newFileLength
    Write-U32BE -Bytes $result -Offset ($vcgtEntryOffset + 8) -Value $newVcgt.Length
    Update-IccProfileId -ProfileBytes $result

    Write-BytesAtomically -Path $OutputPath -Bytes $result
}

if ($NoRun) {
    return
}

try {
    Clear-Host
    Write-Host ("Display Calibration Saver {0}" -f $ScriptVersion) -ForegroundColor Cyan
    Write-Host "=============================="
    Write-Host "Save the calibration preview currently active on a Windows display as an ICC/ICM profile."
    Write-Host "No calibration slider values are estimated or hard-coded."
    Write-Host ""

    $sourcePath = Select-IccFile
    $outputPath = Get-OutputPath -SourcePath $sourcePath
    $deviceName = Select-Display
    $countdown = Get-CountdownSeconds

    Write-Host ""
    Write-Host "Capture procedure:" -ForegroundColor Cyan
    Write-Host "1. Press Enter to start the countdown."
    Write-Host "2. Switch to the calibration application."
    Write-Host "3. Set any desired preview adjustments."
    Write-Host "4. Keep that preview active until the countdown ends."
    Write-Host "5. The active display-calibration curve will be captured automatically."
    Write-Host ""
    [void](Read-Host "Press Enter when ready")

    for ($seconds = $countdown; $seconds -ge 1; $seconds--) {
        Write-Host ("Capturing in {0} second(s)..." -f $seconds)
        Start-Sleep -Seconds 1
    }

    $ramp = Capture-GammaRamp -DeviceName $deviceName
    if (Test-IdentityGammaRamp -Ramp $ramp) {
        Write-Host ""
        Write-Host "Warning: the captured gamma ramp is a linear identity curve." -ForegroundColor Yellow
        Write-Host "Saving it may remove calibration instead of preserving an adjusted preview." -ForegroundColor Yellow
        $continue = Read-Host "Save the identity curve anyway? [y/N]"
        if ($continue -notmatch '^(?i:y|yes)$') {
            throw "Capture cancelled because the active gamma ramp is an identity curve."
        }
    }

    Patch-IccWithCapturedRamp `
        -SourcePath $sourcePath `
        -OutputPath $outputPath `
        -Ramp $ramp

    $redEnd = $ramp[255]
    $greenEnd = $ramp[511]
    $blueEnd = $ramp[767]
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $outputPath).Hash

    Write-Host ""
    Write-Host "Capture completed." -ForegroundColor Green
    Write-Host ("Output: {0}" -f $outputPath)
    Write-Host ("White-end R/G/B: {0} / {1} / {2}" -f $redEnd, $greenEnd, $blueEnd)
    Write-Host ("SHA-256: {0}" -f $hash)
    Write-Host ""
    Write-Host "Install and apply the generated profile using your normal Windows color-management workflow."
}
catch {
    Write-Host ""
    Write-Host ("Error: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
