param()

$ErrorActionPreference = "Stop"
. (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\NativePathEncoding.ps1")

function Assert-BytesEqual {
    param([byte[]]$Actual, [byte[]]$Expected, [string]$Label)
    if ($Actual.Length -ne $Expected.Length) {
        throw "$Label length mismatch: $($Actual.Length) != $($Expected.Length)"
    }
    for ($index = 0; $index -lt $Actual.Length; $index++) {
        if ($Actual[$index] -ne $Expected[$index]) {
            throw "$Label differs at byte $index"
        }
    }
}

$ascii = "C:\Users\Test\AppData\Local\MajestyHD\setting.bin"
Assert-BytesEqual (
    ConvertTo-MajestyNarrowPathBytes -Path $ascii -UtilityName "Test" -CodePage 1252
) ([Text.Encoding]::GetEncoding(1252).GetBytes($ascii)) "ASCII path"

$accented = "C:\Users\José\AppData\Local\MajestyHD\setting.bin"
Assert-BytesEqual (
    ConvertTo-MajestyNarrowPathBytes -Path $accented -UtilityName "Test" -CodePage 1252
) ([Text.Encoding]::GetEncoding(1252).GetBytes($accented)) "Representable accented path"

$rejected = $false
$unrepresentable = "C:\Users\$([char]0x4E2D)\AppData\Local\MajestyHD\setting.bin"
try {
    ConvertTo-MajestyNarrowPathBytes `
        -Path $unrepresentable `
        -UtilityName "Test" `
        -CodePage 1252 | Out-Null
}
catch {
    $rejected = $true
    if ($_ -notmatch "No game files were changed") {
        throw "The rejection did not promise a non-mutating failure: $_"
    }
}
if (-not $rejected) {
    throw "An unrepresentable path was accepted by Windows-1252 conversion."
}

$native = ConvertTo-MajestyNarrowPathBytes -Path $ascii -UtilityName "Test"
if ($native.Length -eq 0) {
    throw "Native Windows path conversion returned no bytes."
}

$installer = Get-Content (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\Install-ModPersistence.ps1") -Raw
$conversionAt = $installer.IndexOf('[byte[]]$preferencePathBytes = ConvertTo-MajestyNarrowPathBytes')
$readAt = $installer.IndexOf('[IO.File]::ReadAllBytes($exePath)')
$writeAt = $installer.IndexOf('[IO.File]::WriteAllBytes($exePath, $patchedBytes)')
if ($conversionAt -lt 0 -or $readAt -lt 0 -or $writeAt -lt 0 -or $conversionAt -gt $readAt -or $conversionAt -gt $writeAt) {
    throw "Preference-path validation must occur before executable reads and writes."
}

Write-Host "Native preference-path encoding tests passed."
