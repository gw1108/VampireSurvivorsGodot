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
Bash CWD resets to repo root each iteration (not the Godot subdir), and BACKGROUNDED bash runs do not inherit a foreground `cd` either — use absolute `--path C:/.../vampire-survivors-taskmaster` and `cmd //d //c "cd /d <projdir> && ..."`, else commands silently run in the wrong place (symptom: `godot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd` → "Attempt to open script ... File not found").

### GDScript :=  inference on Variant fields hangs test runner
`var x := obj.field` OR `var x := obj.method()` where `obj` is untyped/Variant (e.g. an element from an untyped Array, or WeaponInstance.def) is a parse error; gdUnit4's `-d` flag turns it into an interactive Debugger Break that HANGS the run (and `--import` doesn't catch it). Use `var x = obj.field` (untyped) or `var x: int = obj.method()` (explicit type). Validate func-body parse errors with `godot --headless --check-only --script res://...` BEFORE the suite (catches what --import misses); always run the suite under `timeout 150 ...`; kill stray `godot.exe`/`Godot_*_console.exe` if it hangs.

### New class_name file needs --import (not just --check-only) before the suite
`--check-only` only PARSES a script — it does NOT register a new `class_name` in global_script_class_cache. If you add a new logic class and run only check-only, the gdUnit4 suite fails "Identifier <Class> not declared" → Debugger Break HANG. For any new class_name file run `godot --headless --path <proj> --import` (logs `update_scripts_classes | <Class>`) BEFORE the suite. Do BOTH for a new file: check-only (func-body parse errors) THEN import (registration).
CAVEAT: `--check-only --script X.gd` also does NOT load the cache, so it FALSELY reports "Could not find type <OtherClass>" when X references ANOTHER class_name that exists but isn't registered yet — a false alarm, not a real error. Use check-only only for errors WITHIN the single file; trust `--import` (full cache) for cross-class type resolution (re-running check-only after import clears the false alarm).

### Don't name vars/params after base-class properties
In ANY script that extends a class (gdUnit4 test suites AND production Node/Node2D/Control scripts), a local var/param named `name`/`position`/`scale`/etc. shadows the base property → "shadowing an already-declared property" warning (noisy, not fatal). Use distinct names (`display_name`, `base_name`, etc.).

### Autoloads not usable from class_name scripts
A `class_name` pure-logic script CANNOT reference an autoload singleton (e.g. `GameData`) — it fails global-class registration ("Identifier not declared"), which the gdUnit4 runner reports only as a cascade ("<Class> not declared"). Load resources directly by path (`load("res://data/...")`, Godot-cached) or pass data in. After fixing such a registration error, run a clean `godot --headless --path <proj> --import` BEFORE the suite — the runner caches global_script_class_cache and won't re-register otherwise.

### Adding data/ entries ripples into golden + pool-dependent tests
Adding a `.tres` to a dir that feeds the level-up offer pool (data/weapons, data/passives) changes EVERY golden/replay snapshot and breaks tests that pinned specific offer contents (they assumed the old small catalog). Expect, in the SAME change: re-capture golden snapshots, and rewrite pinned-offer tests to pool-independent invariants (assert "an owned weapon never appears as new" / check `_get_upgradeable_weapons` directly, not the shuffled 3-4 subset). `ProgressionSystem._load_defs` sorts by id so offer order stays deterministic across machines — keep new dir-loaders sorted. Also bump any `get_all_<x>().size()` count assertions and any `is_max_state` test (it must now fill+max BOTH weapon and passive slots).

### GameState.new().rng is randomly seeded -> build_offer tests are flaky
Godot auto-randomizes `RandomNumberGenerator` on creation, so `GameState.new().rng` differs every process. Any test that calls `ProgressionSystem.build_offer` WITHOUT pinning `gs.rng.seed` and then asserts something about the shown 3-4 options (e.g. "a weapon appears", "option 0 is a weapon") is flaky — it passes/fails depending on the random seed, and the larger the mixed weapon+passive pool the more often it lands wrong. Fix: assert seed-independent invariants (empty inventory -> NO option is an upgrade) OR build a CONTROLLED `LevelUpOffer` with the exact option you mean to test instead of using the shuffle. (The live game intentionally random-seeds in `start_run`; only tests need pinning.)
