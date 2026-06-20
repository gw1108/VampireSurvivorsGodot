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
_Generated 2026-06-20 13:58 by Convert-Wiki.ps1._
