<#
.SYNOPSIS
    Build an offline, LLM-traversable copy of manually-saved MediaWiki pages.

.DESCRIPTION
    Converts saved wiki source files in the wiki folder into clean Markdown:
      *.htm / *.html        -> read as HTML   (the 'action=render' save)
      *.wiki / *.wikitext / *.mediawiki -> read as MediaWiki (the 'action=raw' save)
    Each <Title>.* becomes <Title>.md (only when the .md is missing, unless -Force).

    Cleanup is done by pandoc + clean-wiki.lua:
      - leftover raw HTML is stripped, sprite/icon images removed,
      - MediaWiki chrome (edit links, nav boxes, TOC, ...) is removed,
      - table cells are flattened so tables render as clean pipe tables,
      - internal wiki links are rewritten to local "<Title>.md" navigation.

    Always regenerates index.md, manifest.json, and AGENTS.md so they reflect
    whatever pages are present.

    Manual workflow: in a browser open
      https://vampire.survivors.wiki/index.php?title=<Page>&action=render
    Save As -> "Web Page, HTML only" into the wiki folder. IMPORTANT: name the file
    after the exact wiki page Title (e.g. Weapons.htm, Soul_Eater.htm) so that links
    between pages resolve to the right <Title>.md file. Then run this script.

.PARAMETER WikiDir
    Folder holding the saved pages. Defaults to '<script dir>\wiki-offline'.

.PARAMETER Force
    Reconvert sources -> .md even if the .md already exists.

.EXAMPLE
    .\Convert-Wiki.ps1
.EXAMPLE
    .\Convert-Wiki.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$WikiDir = (Join-Path $PSScriptRoot 'wiki-offline'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$LuaFilter = Join-Path $PSScriptRoot 'clean-wiki.lua'
$generated = @('index.md', 'AGENTS.md', 'README.md')
$srcExts   = @('.html', '.htm', '.wiki', '.wikitext', '.mediawiki')

# --- helpers ---------------------------------------------------------------

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

# Pandoc reader for a source extension, or $null if it is not a wiki source.
function Get-Reader {
    param([string]$Ext)
    switch ($Ext.ToLower()) {
        '.htm'       { 'html' }
        '.html'      { 'html' }
        '.wiki'      { 'mediawiki' }
        '.wikitext'  { 'mediawiki' }
        '.mediawiki' { 'mediawiki' }
        default      { $null }
    }
}

# --- setup -----------------------------------------------------------------

if (-not (Test-Path $WikiDir)) {
    New-Item -ItemType Directory -Path $WikiDir -Force | Out-Null
    Write-Host "Created $WikiDir"
}
$WikiDir = (Resolve-Path $WikiDir).Path

$srcFiles = Get-ChildItem -Path $WikiDir -File | Where-Object { Get-Reader $_.Extension }
$needConvert = $srcFiles | Where-Object {
    $md = Join-Path $WikiDir ([System.IO.Path]::GetFileNameWithoutExtension($_.Name) + '.md')
    $Force -or -not (Test-Path $md)
}

if ($needConvert) {
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) {
        Write-Error "pandoc is required but was not found on PATH. Install it (e.g. 'winget install --id JohnMacFarlane.Pandoc') and re-run."
        exit 1
    }
    if (-not (Test-Path $LuaFilter)) {
        Write-Error "Lua filter not found: $LuaFilter (it should sit next to this script)."
        exit 1
    }
}

# --- 1. convert sources -> clean md ---------------------------------------

$converted = 0
$skipped = 0

foreach ($f in $srcFiles) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
    $mdPath = Join-Path $WikiDir "$base.md"
    if ((Test-Path $mdPath) -and -not $Force) { $skipped++; continue }

    $reader = Get-Reader $f.Extension
    Write-Host "Converting $($f.Name) [$reader] -> $base.md"

    $pandocArgs = @(
        '-f', $reader,
        # markdown writer keeps tables (gfm drops block-content cells to [TABLE]);
        # disabling simple/multiline tables biases flattened tables to pipe tables.
        '-t', 'markdown-simple_tables-multiline_tables',
        '--wrap=none',                          # pipe-table rows stay on one line
        '--strip-comments',                     # drop <!-- ... -->
        "--lua-filter=$LuaFilter",
        '-o', $mdPath,                          # pandoc writes UTF-8 directly...
        $f.FullName                             # ...so accents survive (no PS stdout re-decode)
    )
    & pandoc @pandocArgs
    $converted++
}

# --- 2. collect pages (this is the offline traversal boundary) ------------

$pages =
    Get-ChildItem -Path $WikiDir -Filter '*.md' -File |
    Where-Object { $generated -notcontains $_.Name } |
    Sort-Object Name |
    ForEach-Object {
        $title = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        $srcName = $null
        foreach ($ext in $srcExts) {
            if (Test-Path (Join-Path $WikiDir "$title$ext")) { $srcName = "$title$ext"; break }
        }
        [PSCustomObject]@{
            title        = $title
            displayTitle = ($title -replace '_', ' ')
            file         = $_.Name
            source       = $srcName
        }
    }

$pageCount = @($pages).Count
$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm')

# --- 3. manifest.json ------------------------------------------------------

$manifest = [ordered]@{
    source       = 'https://vampire.survivors.wiki'
    sourceFormat = 'MediaWiki action=render/raw -> clean Markdown, pipe tables (pandoc + clean-wiki.lua)'
    generated    = $stamp
    pageCount    = $pageCount
    pages        = @($pages)
}
Write-Utf8NoBom -Path (Join-Path $WikiDir 'manifest.json') -Content ($manifest | ConvertTo-Json -Depth 5)

# --- 4. index.md -----------------------------------------------------------

$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine('# Vampire Survivors Wiki - Offline Index')
[void]$sb.AppendLine()
[void]$sb.AppendLine("_$pageCount page(s) available offline. Generated $stamp._")
[void]$sb.AppendLine()
if ($pageCount -eq 0) {
    [void]$sb.AppendLine('_No pages saved yet. Save `<Title>.html` files into this folder and re-run the script._')
} else {
    foreach ($p in $pages) {
        [void]$sb.AppendLine("- [$($p.displayTitle)]($($p.file))")
    }
}
Write-Utf8NoBom -Path (Join-Path $WikiDir 'index.md') -Content ($sb.ToString())

# --- 5. AGENTS.md ----------------------------------------------------------

$agents = @'
# Offline Wiki - Agent Guide

This folder is a **partial, offline snapshot** of the Vampire Survivors wiki
(https://vampire.survivors.wiki), saved manually for offline reasoning and traversal.

## Layout
- Each wiki page is a Markdown file named `<Title>.md` (spaces become underscores).
  Example: the "Soul Eater" page is `Soul_Eater.md`.
- `index.md` lists every page available offline - start there.
- `manifest.json` is the machine-readable `{title -> file}` map and defines the
  **boundary** of what exists offline.
- The original saved source (`<Title>.html` or `<Title>.wiki`) sits beside each
  `.md`; reason over the `.md` files.

## Traversal rules
1. Links inside a page point to sibling `.md` files, e.g. `[Garlic](Garlic.md)`.
2. Follow a link **only if** its target file is present / listed in `manifest.json`.
3. If a link target is **not** in the manifest, that page was not saved - treat it as
   a dead end and do not invent its contents.

## Provenance
- Converted to clean Markdown via pandoc + `clean-wiki.lua`.
- Raw HTML, sprite/icon images, and MediaWiki chrome (edit links, nav boxes, TOC)
  are stripped. Tables render as pipe tables; multi-item cells are joined inline
  with "; ".
- Boilerplate sections are dropped (External links, Update history, Trivia), so a
  page holds gameplay facts only.
'@
$agents += "`n_Generated $stamp by Convert-Wiki.ps1._`n"
Write-Utf8NoBom -Path (Join-Path $WikiDir 'AGENTS.md') -Content $agents

# --- done ------------------------------------------------------------------

Write-Host ""
Write-Host "Done. Converted: $converted | Skipped (already had .md): $skipped | Pages indexed: $pageCount"
Write-Host "Folder: $WikiDir"
