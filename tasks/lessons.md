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
`var x := obj.field` OR `var x := obj.method()` where `obj` is untyped/Variant (e.g. an element from an untyped Array, or WeaponInstance.def) is a parse error; gdUnit4's `-d` flag turns it into an interactive Debugger Break that HANGS the run (and `--import` doesn't catch it). Use `var x = obj.field` (untyped) or `var x: int = obj.method()` (explicit type). Validate func-body parse errors with `godot --headless --check-only --script res://...` BEFORE the suite (catches what --import misses); always run the suite under `timeout 150 ...`; kill stray `godot.exe`/`Godot_*_console.exe` if it hangs.

### New class_name file needs --import (not just --check-only) before the suite
`--check-only` only PARSES a script — it does NOT register a new `class_name` in global_script_class_cache. If you add a new logic class and run only check-only, the gdUnit4 suite fails "Identifier <Class> not declared" → Debugger Break HANG. For any new class_name file run `godot --headless --path <proj> --import` (logs `update_scripts_classes | <Class>`) BEFORE the suite. Do BOTH for a new file: check-only (func-body parse errors) THEN import (registration).
CAVEAT: `--check-only --script X.gd` also does NOT load the cache, so it FALSELY reports "Could not find type <OtherClass>" when X references ANOTHER class_name that exists but isn't registered yet — a false alarm, not a real error. Use check-only only for errors WITHIN the single file; trust `--import` (full cache) for cross-class type resolution (re-running check-only after import clears the false alarm).

### Don't name vars/params after base-class properties
In ANY script that extends a class (gdUnit4 test suites AND production Node/Node2D/Control scripts), a local var/param named `name`/`position`/`scale`/etc. shadows the base property → "shadowing an already-declared property" warning (noisy, not fatal). Use distinct names (`display_name`, `base_name`, etc.).

### Autoloads not usable from class_name scripts
A `class_name` pure-logic script CANNOT reference an autoload singleton (e.g. `GameData`) — it fails global-class registration ("Identifier not declared"), which the gdUnit4 runner reports only as a cascade ("<Class> not declared"). Load resources directly by path (`load("res://data/...")`, Godot-cached) or pass data in. After fixing such a registration error, run a clean `godot --headless --path <proj> --import` BEFORE the suite — the runner caches global_script_class_cache and won't re-register otherwise.
