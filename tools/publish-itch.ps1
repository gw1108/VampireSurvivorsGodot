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
    [string]$Bump = "patch",

    [switch]$SkipExport
)

$ErrorActionPreference = "Stop"

$Target      = "georgewang/cosmic-vampire-survivors-v2:html5"
$VersionFile = Join-Path $PSScriptRoot "itch-version.txt"
$Uploader    = Join-Path $PSScriptRoot "upload-itch.ps1"

# --- Read + bump version ---------------------------------------------------
if (Test-Path $VersionFile) {
    $current = (Get-Content $VersionFile -Raw).Trim()
} else {
    $current = "0.1.0"
}
if ($current -notmatch '^\d+\.\d+\.\d+$') {
    throw "itch-version.txt is malformed ('$current'); expected MAJOR.MINOR.PATCH"
}
$parts = $current.Split('.') | ForEach-Object { [int]$_ }
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
