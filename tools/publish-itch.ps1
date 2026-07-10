<#
.SYNOPSIS
    One-command publish to itch.io: fixed target + auto-incrementing version.

.DESCRIPTION
    Wraps upload-itch.ps1 with the project's itch target hardcoded and the build
    version auto-bumped each run. The version lives in tools/itch-version.txt
    (semver); every publish increments the patch number and stamps it on the build.

.PARAMETER Bump
    Which part of the version to increment: patch (default), minor, or major.

.PARAMETER SkipExport
    Push whatever is already in build/web without re-exporting.

.EXAMPLE
    ./tools/publish-itch.ps1
    ./tools/publish-itch.ps1 -Bump minor
#>
[CmdletBinding()]
param(
    [ValidateSet("patch", "minor", "major")]
    [string]$Bump = "minor",

    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"

$Target      = "georgewang/cosmic-vampire-survivors-v2:html5"
$VersionFile = Join-Path $PSScriptRoot "itch-version.txt"
$Uploader    = Join-Path $PSScriptRoot "upload-itch.ps1"

# --- Read + bump version ---------------------------------------------------
if (Test-Path $VersionFile) {
    $raw = (Get-Content $VersionFile -Raw).Trim()
} else {
    $raw = "0.1.0"
}
# Be tolerant of stale/malformed values: take the first three integer groups,
# padding missing ones with 0 (so "0.2", "0.2.0.1", or "v0.2.0" all normalize).
$nums = [regex]::Matches($raw, '\d+') | ForEach-Object { [int]$_.Value }
if ($nums.Count -eq 0) {
    throw "itch-version.txt has no version number ('$raw'); expected MAJOR.MINOR.PATCH"
}
$parts = @(0, 0, 0)
for ($i = 0; $i -lt [Math]::Min(3, $nums.Count); $i++) { $parts[$i] = $nums[$i] }
$current = ($parts -join '.')
switch ($Bump) {
    "major" { $parts = @($parts[0] + 1, 0, 0) }
    "minor" { $parts = @($parts[0], $parts[1] + 1, 0) }
    "patch" { $parts = @($parts[0], $parts[1], $parts[2] + 1) }
}
$new = ($parts -join '.')

Write-Host "==> Version $current -> $new" -ForegroundColor Cyan

# --- Publish ---------------------------------------------------------------
# The uploader's final action is the native `butler push`, so $LASTEXITCODE
# after it returns reflects butler's result. Don't advance the version on failure.
& $Uploader -Target $Target -UserVersion $new -SkipExport:$SkipExport
if ($LASTEXITCODE -ne 0) {
    throw "Publish failed (butler exit $LASTEXITCODE); version left at $current."
}

# Only advance the stored version once the upload actually succeeded.
Set-Content -Path $VersionFile -Value $new -Encoding ascii -NoNewline
Write-Host "==> Recorded version $new in $VersionFile" -ForegroundColor Green
