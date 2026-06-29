# Lessons

### Verbatim game data source
Canonical VS numbers (weapon per-level curves, Mad Forest wave table, enemy/boss/Reaper stat blocks, drop tables) live in `.firecrawl/wiki-offline/<Page>.md` (one page per weapon/enemy/mechanic); the GDD references them as authoritative. Fan out parallel subagents (one per dataset) to extract verbatim, and cross-check against the GDD — they can disagree (e.g. the 500 hard enemy cap is in the GDD but NOT in the wiki).

### Task-spec code is illustrative, not authoritative
Taskmaster `details` often contain example GDScript that is subtly wrong vs the GDD/wiki data — reconcile, don't copy. Seen so far: StatSystem spec applied Hollow Heart as additive `*=(1+per_level*level)` (=+100% @L5) but the wiki is multiplicative `*=(1+per_level)^level` (=+149%); and it used `cooldown -= value` assuming a positive per_level, but GameDatabase stores Empty Tome's per_level already-signed (-0.08), so additive `+=` is correct. Cross-check spec formulas against the data before trusting them.

### Float32 test comparisons
Values in a `PackedFloat32Array` are stored as 32-bit, so reading back e.g. `0.8` yields `0.80000001…`; assert with `is_equal_approx(...)`, not `==`. Integers and power-of-two fractions (1.0, 0.25, 12.5) round-trip exactly and compare fine with `==`.

### GDScript forward references
A typed `var x: SomeClass` fails to parse if `SomeClass`'s `class_name` file doesn't exist yet. When an early task's container references types from a later task (e.g. RunState -> EnemyPool), leave those fields untyped with a `# IntendedType (Task N)` comment; add the annotation once the class exists.

### Building .tscn by hand
For a node-shell scene: write the script first, run an editor import to generate its `.gd.uid`, then reference it in the `.tscn` ext_resource with both `uid="uid://..."` and `path=`. Use `PlaceholderTexture2D` sub-resources (no external file/import) for headless-safe AnimatedSprite2D frames. Untyped `var x = scene.instantiate()` makes `var y := x.foo()` fail type inference — annotate the inner var's type.

### Headless tests that need get_tree()
A `SceneTree` test script's `_initialize()` runs before the root window is in the tree, so a Node added to `root` there has a null `get_tree()`. Drive such tests from `_process(delta)` (guard with a `_ran` bool, `quit()` + `return true`) instead — by the first frame the tree is live.

### Godot headless verify
Type-check + register class_names with `godot --headless --path <proj> --editor --quit-after 30` (grep output for `error`); run tests with a `SceneTree` script via `--script res://...` that calls `quit(failure_count)` — no gdUnit4 needed for plain-data checks.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.