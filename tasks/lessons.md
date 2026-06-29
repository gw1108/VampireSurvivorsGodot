# Lessons

### Verbatim game data source
Canonical VS numbers (weapon per-level curves, Mad Forest wave table, enemy/boss/Reaper stat blocks, drop tables) live in `.firecrawl/wiki-offline/<Page>.md` (one page per weapon/enemy/mechanic); the GDD references them as authoritative. Fan out parallel subagents (one per dataset) to extract verbatim, and cross-check against the GDD — they can disagree (e.g. the 500 hard enemy cap is in the GDD but NOT in the wiki).

### Float32 test comparisons
Values in a `PackedFloat32Array` are stored as 32-bit, so reading back e.g. `0.8` yields `0.80000001…`; assert with `is_equal_approx(...)`, not `==`. Integers and power-of-two fractions (1.0, 0.25, 12.5) round-trip exactly and compare fine with `==`.

### GDScript forward references
A typed `var x: SomeClass` fails to parse if `SomeClass`'s `class_name` file doesn't exist yet. When an early task's container references types from a later task (e.g. RunState -> EnemyPool), leave those fields untyped with a `# IntendedType (Task N)` comment; add the annotation once the class exists.

### Godot headless verify
Type-check + register class_names with `godot --headless --path <proj> --editor --quit-after 30` (grep output for `error`); run tests with a `SceneTree` script via `--script res://...` that calls `quit(failure_count)` — no gdUnit4 needed for plain-data checks.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.