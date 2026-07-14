#requires -version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectRoot "Save-Display-Calibration.ps1") -NoRun

$script:Passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Name)

    if (-not $Condition) {
        throw "Assertion failed: $Name"
    }
    $script:Passed++
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)

    if ($Expected -ne $Actual) {
        throw "Assertion failed: $Name. Expected '$Expected', got '$Actual'."
    }
    $script:Passed++
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$ExpectedMessage,
        [string]$Name
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "Assertion failed: $Name. Expected error containing '$ExpectedMessage', got '$($_.Exception.Message)'."
        }
        $script:Passed++
        return
    }

    throw "Assertion failed: $Name. Expected an exception."
}

function New-TestIccProfile {
    param(
        [int]$MajorVersion = 4,
        [int]$VcgtSize = 18,
        [switch]$DuplicateVcgt,
        [int]$DeclaredSizeOverride = -1
    )

    $tagCount = if ($DuplicateVcgt) { 2 } else { 1 }
    $tagTableEnd = 132 + ($tagCount * 12)
    $vcgtOffset = ($tagTableEnd + 3) -band (-bnot 3)
    $actualLength = ($vcgtOffset + $VcgtSize + 3) -band (-bnot 3)
    if ($VcgtSize -eq 0) {
        $actualLength = $vcgtOffset
    }

    [byte[]]$profile = New-Object byte[] $actualLength
    $declaredSize = if ($DeclaredSizeOverride -ge 0) { $DeclaredSizeOverride } else { $actualLength }
    Write-U32BE -Bytes $profile -Offset 0 -Value $declaredSize
    $profile[8] = [byte]$MajorVersion
    [Array]::Copy([Text.Encoding]::ASCII.GetBytes("acsp"), 0, $profile, 36, 4)
    Write-U32BE -Bytes $profile -Offset 128 -Value $tagCount

    for ($i = 0; $i -lt $tagCount; $i++) {
        $entryOffset = 132 + ($i * 12)
        [Array]::Copy([Text.Encoding]::ASCII.GetBytes("vcgt"), 0, $profile, $entryOffset, 4)
        Write-U32BE -Bytes $profile -Offset ($entryOffset + 4) -Value $vcgtOffset
        Write-U32BE -Bytes $profile -Offset ($entryOffset + 8) -Value $VcgtSize
    }

    if ($VcgtSize -ge 4) {
        [Array]::Copy([Text.Encoding]::ASCII.GetBytes("vcgt"), 0, $profile, $vcgtOffset, 4)
    }

    return ,$profile
}

function New-IdentityRamp {
    [UInt16[]]$ramp = New-Object "UInt16[]" 768
    foreach ($channelOffset in @(0, 256, 512)) {
        for ($i = 0; $i -lt 256; $i++) {
            $ramp[$channelOffset + $i] = [uint16]($i * 257)
        }
    }
    return ,$ramp
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("display-calibration-saver-tests-{0}" -f [Guid]::NewGuid().ToString("N"))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null

try {
    [UInt16[]]$identityRamp = New-IdentityRamp
    Assert-True -Condition (Test-IdentityGammaRamp -Ramp $identityRamp) -Name "Identity ramp is detected"
    $adjustedRamp = [UInt16[]]$identityRamp.Clone()
    $adjustedRamp[384]--
    Assert-True -Condition (-not (Test-IdentityGammaRamp -Ramp $adjustedRamp)) -Name "Adjusted ramp is not identity"

    [byte[]]$vcgt = Build-VcgtTag16 -Ramp $identityRamp
    Assert-Equal -Expected 1554 -Actual $vcgt.Length -Name "vcgt length"
    Assert-Equal -Expected "vcgt" -Actual ([Text.Encoding]::ASCII.GetString($vcgt, 0, 4)) -Name "vcgt signature"
    Assert-Equal -Expected 3 -Actual (([int]$vcgt[12] -shl 8) -bor $vcgt[13]) -Name "vcgt channel count"
    Assert-Equal -Expected 256 -Actual (([int]$vcgt[14] -shl 8) -bor $vcgt[15]) -Name "vcgt entries per channel"
    Assert-Equal -Expected 2 -Actual (([int]$vcgt[16] -shl 8) -bor $vcgt[17]) -Name "vcgt bytes per entry"

    $v4SourcePath = Join-Path $temporaryRoot "valid-v4.icc"
    $v4OutputPath = Join-Path $temporaryRoot "valid-v4-output.icc"
    [IO.File]::WriteAllBytes($v4SourcePath, (New-TestIccProfile -MajorVersion 4))
    Patch-IccWithCapturedRamp -SourcePath $v4SourcePath -OutputPath $v4OutputPath -Ramp $identityRamp
    [byte[]]$v4Output = [IO.File]::ReadAllBytes($v4OutputPath)
    Assert-Equal -Expected $v4Output.Length -Actual (Read-U32BE -Bytes $v4Output -Offset 0) -Name "v4 declared size"
    Assert-Equal -Expected 1554 -Actual (Read-U32BE -Bytes $v4Output -Offset 140) -Name "v4 vcgt size"

    [byte[]]$digestInput = $v4Output.Clone()
    foreach ($range in @(@(44, 47), @(64, 67), @(84, 99))) {
        for ($i = $range[0]; $i -le $range[1]; $i++) {
            $digestInput[$i] = 0
        }
    }
    $md5 = [Security.Cryptography.MD5]::Create()
    try {
        [byte[]]$expectedProfileId = $md5.ComputeHash($digestInput)
    }
    finally {
        $md5.Dispose()
    }
    $actualProfileId = [BitConverter]::ToString($v4Output[84..99])
    Assert-Equal -Expected ([BitConverter]::ToString($expectedProfileId)) -Actual $actualProfileId -Name "v4 Profile ID"

    $v2SourcePath = Join-Path $temporaryRoot "valid-v2.icc"
    $v2OutputPath = Join-Path $temporaryRoot "valid-v2-output.icc"
    [byte[]]$v2Source = New-TestIccProfile -MajorVersion 2
    for ($i = 84; $i -lt 100; $i++) {
        $v2Source[$i] = 255
    }
    [IO.File]::WriteAllBytes($v2SourcePath, $v2Source)
    Patch-IccWithCapturedRamp -SourcePath $v2SourcePath -OutputPath $v2OutputPath -Ramp $identityRamp
    [byte[]]$v2Output = [IO.File]::ReadAllBytes($v2OutputPath)
    Assert-True -Condition (-not ($v2Output[84..99] | Where-Object { $_ -ne 0 })) -Name "v2 reserved Profile ID bytes are zero"

    $sizeMismatchPath = Join-Path $temporaryRoot "size-mismatch.icc"
    $sizeMismatchOutput = Join-Path $temporaryRoot "size-mismatch-output.icc"
    [IO.File]::WriteAllBytes($sizeMismatchPath, (New-TestIccProfile -DeclaredSizeOverride 132))
    Assert-Throws -Action {
        Patch-IccWithCapturedRamp -SourcePath $sizeMismatchPath -OutputPath $sizeMismatchOutput -Ramp $identityRamp
    } -ExpectedMessage "header size does not match" -Name "Declared size mismatch is rejected"
    Assert-True -Condition (-not [IO.File]::Exists($sizeMismatchOutput)) -Name "Rejected profile creates no output"

    $duplicatePath = Join-Path $temporaryRoot "duplicate-vcgt.icc"
    $duplicateOutput = Join-Path $temporaryRoot "duplicate-vcgt-output.icc"
    [IO.File]::WriteAllBytes($duplicatePath, (New-TestIccProfile -DuplicateVcgt))
    Assert-Throws -Action {
        Patch-IccWithCapturedRamp -SourcePath $duplicatePath -OutputPath $duplicateOutput -Ramp $identityRamp
    } -ExpectedMessage "multiple vcgt" -Name "Duplicate vcgt is rejected"

    $shortPath = Join-Path $temporaryRoot "short-vcgt.icc"
    $shortOutput = Join-Path $temporaryRoot "short-vcgt-output.icc"
    [IO.File]::WriteAllBytes($shortPath, (New-TestIccProfile -VcgtSize 0))
    Assert-Throws -Action {
        Patch-IccWithCapturedRamp -SourcePath $shortPath -OutputPath $shortOutput -Ramp $identityRamp
    } -ExpectedMessage "too small" -Name "Short vcgt has a controlled error"

    $atomicPath = Join-Path $temporaryRoot "atomic.bin"
    Write-BytesAtomically -Path $atomicPath -Bytes ([byte[]]@(1, 2, 3))
    Write-BytesAtomically -Path $atomicPath -Bytes ([byte[]]@(4, 5, 6, 7))
    Assert-Equal -Expected "4-5-6-7" -Actual (([IO.File]::ReadAllBytes($atomicPath)) -join "-") -Name "Atomic replacement content"

    $lockedPath = Join-Path $temporaryRoot "locked-output.bin"
    [IO.File]::WriteAllBytes($lockedPath, ([byte[]]@(8, 9, 10)))
    $lockStream = [IO.File]::Open($lockedPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
    $lockedWriteFailed = $false
    try {
        try {
            Write-BytesAtomically -Path $lockedPath -Bytes ([byte[]]@(11, 12, 13))
        }
        catch {
            $lockedWriteFailed = $true
        }
    }
    finally {
        $lockStream.Dispose()
    }
    Assert-True -Condition $lockedWriteFailed -Name "Locked destination rejects replacement"
    Assert-Equal -Expected "8-9-10" -Actual (([IO.File]::ReadAllBytes($lockedPath)) -join "-") -Name "Failed replacement preserves existing output"

    $atomicArtifacts = @(Get-ChildItem -Force -LiteralPath $temporaryRoot | Where-Object { $_.Name -match '^\..*\.(tmp|bak)$' })
    Assert-Equal -Expected 0 -Actual $atomicArtifacts.Count -Name "Atomic writes leave no temporary or backup files"

    Write-Host ("All tests passed: {0}" -f $script:Passed) -ForegroundColor Green
}
finally {
    if ([IO.Directory]::Exists($temporaryRoot)) {
        [IO.Directory]::Delete($temporaryRoot, $true)
    }
}
