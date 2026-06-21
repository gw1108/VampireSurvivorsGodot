# Lessons

### MediaWiki link rewriting
This wiki emits `/w/<Title>` short URLs (not `/wiki/` or `?title=`) — match `/w/` when rewriting internal links to local `.md`.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.

### Godot project location
The Godot 4.6 project is in `vampire-survivors-taskmaster/`, not the repo root — all `res://` paths and `godot --path` resolve there.

### gdUnit4 / Godot 4.6.2 compat
Bundled gdUnit4 needed a vendored patch to compile against 4.6.2 (`get_as_text(true)`→`get_as_text()`); see AgentMD.md before reinstalling the addon.

### Shell CWD per loop turn
Bash CWD resets to repo root each iteration (not the Godot subdir) — use absolute `--path` and `cmd //d //c "cd /d <projdir> && ..."`, else commands silently run in the wrong place.

### GDScript :=  inference on Variant fields hangs test runner
`var x := obj.field` where the field is untyped (e.g. WeaponInstance.def) is a parse error; gdUnit4's `-d` flag turns it into an interactive Debugger Break that HANGS the run (and `--import` doesn't catch it). Use `var x = obj.field`. Always run the suite under `timeout 150 ...`; kill stray `godot.exe`/`Godot_*_console.exe` if it hangs.

### Autoloads not usable from class_name scripts
A `class_name` pure-logic script CANNOT reference an autoload singleton (e.g. `GameData`) — it fails global-class registration ("Identifier not declared"), which the gdUnit4 runner reports only as a cascade ("<Class> not declared"). Load resources directly by path (`load("res://data/...")`, Godot-cached) or pass data in. After fixing such a registration error, run a clean `godot --headless --path <proj> --import` BEFORE the suite — the runner caches global_script_class_cache and won't re-register otherwise.
