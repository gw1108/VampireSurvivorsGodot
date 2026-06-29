# Lessons

### Verbatim game data source
Canonical VS numbers (weapon per-level curves, Mad Forest wave table, enemy/boss/Reaper stat blocks, drop tables) live in `.firecrawl/wiki-offline/<Page>.md` (one page per weapon/enemy/mechanic); the GDD references them as authoritative. Fan out parallel subagents (one per dataset) to extract verbatim, and cross-check against the GDD — they can disagree (e.g. the 500 hard enemy cap is in the GDD but NOT in the wiki).

### Task-spec code is illustrative, not authoritative
Taskmaster `details` often contain example GDScript that is subtly wrong vs the GDD/wiki data — reconcile, don't copy. Seen so far: StatSystem spec applied Hollow Heart as additive `*=(1+per_level*level)` (=+100% @L5) but the wiki is multiplicative `*=(1+per_level)^level` (=+149%); and it used `cooldown -= value` assuming a positive per_level, but GameDatabase stores Empty Tome's per_level already-signed (-0.08), so additive `+=` is correct. Also WeaponSystem spec pre-multiplied damage by Might (`base_dmg * might`) but CollisionSystem already applies `damage * stats.might` at hit time — store PRE-Might base damage to avoid double-counting; used `999` for pierce-all but the pool convention is `-1` (infinite); called a nonexistent `spawn()`+assign API (real one is `spawn(pos, vel, params)`); and ignored per-level deltas entirely (resolve `base + levels[1..L-1]` so leveling actually changes the weapon). Cross-check spec formulas AND API shapes against the real deps before trusting them. And a "populate X" task may find X ALREADY populated under a different, load-bearing schema (Task 27: the wave table existed as `{enemies,count,interval,boss,event}` consumed by SpawnDirector; the sketch's `{base_count, events[], boss=null, MAD_FOREST_EVENTS}` would have regressed it) — check existing consumers before re-authoring; prefer verifying + an integrity test over rewriting. And watch one-time vs persistent effects (Task 30: the sketch added the XP +600/+2400 lump INSIDE the per-level loop, which persists it to every later level; the wiki funds only the single 20->21 / 40->41 step — `if level == 20` outside the loop is correct, lock it with `xp_to_next(21) < xp_to_next(20)`).

### WEAPONS base_dmg vs dmg delta key
In GameDatabase WEAPONS, a weapon's base damage is stored under `base_dmg`, but its per-level upgrade delta uses the key `dmg` — the two names DON'T match. Resolving "total damage at level N" must seed from `base_dmg` then add the `dmg` deltas (WeaponSystem._resolve_weapon and GameDatabase.weapon_stat_at_level both do this; the latter maps `"dmg"->"base_dmg"`). Every OTHER stat (amount/area/speed/cooldown/duration/pierce) shares one key between base and delta, so only damage needs the remap.

### RunState pool fields are untyped
RunState's enemies/projectiles/pickups/floaters/grid/spawn fields are untyped (Task 1 forward-refs), so `var x := state.enemies.spawn(...)` fails type inference everywhere downstream — annotate the result (`var x: int = ...`), and in system code cast pools to typed locals (`var enemies: EnemyPool = state.enemies`) for clean access. This bites inside system code too: `var dir := (state.enemies.pos[i] - ...)` is a parse error, and the failed compile then surfaces confusingly as "Nonexistent function 'step' in base 'GDScript'" at the call site — cast the pool to a typed local before any `:=` that reads its arrays. (A future cleanup could add the annotations to run_state.gd now that the classes exist.)

### Float32 test comparisons
Values in a `PackedFloat32Array` are stored as 32-bit, so reading back e.g. `0.8` yields `0.80000001…`; assert with `is_equal_approx(...)`, not `==`. Integers and power-of-two fractions (1.0, 0.25, 12.5) round-trip exactly and compare fine with `==`.

### GDScript forward references
A typed `var x: SomeClass` fails to parse if `SomeClass`'s `class_name` file doesn't exist yet. When an early task's container references types from a later task (e.g. RunState -> EnemyPool), leave those fields untyped with a `# IntendedType (Task N)` comment; add the annotation once the class exists.

### Building .tscn by hand
For a node-shell scene: write the script first, run an editor import to generate its `.gd.uid`, then reference it in the `.tscn` ext_resource with both `uid="uid://..."` and `path=`. Use `PlaceholderTexture2D` sub-resources (no external file/import) for headless-safe AnimatedSprite2D frames. Untyped `var x = scene.instantiate()` makes `var y := x.foo()` fail type inference — annotate the inner var's type.

### Headless tests that need get_tree()
A `SceneTree` test script's `_initialize()` runs before the root window is in the tree, so a Node added to `root` there has a null `get_tree()`. Drive such tests from `_process(delta)` (guard with a `_ran` bool, `quit()` + `return true`) instead — by the first frame the tree is live.

### Godot headless verify
Type-check + register class_names with `godot --headless --path <proj> --editor --quit-after 30` (grep output for `error`); run tests with a `SceneTree` script via `--script res://...` that calls `quit(failure_count)` — no gdUnit4 needed for plain-data checks. NOTE: `--check-only --script <file>` parses in isolation and does NOT load the global `class_name` registry, so a test referencing a sibling global class (e.g. `LevelingSystem`) falsely reports "Identifier not declared" — run the `--editor --quit-after` import first to refresh the class cache, then the `--script` run-mode test.

### Autoloads in headless --script tests
The autoload NODE is mounted (reachable at `/root/GameManager`), but its GDScript GLOBAL identifier (`GameManager`) is NOT resolvable at compile time in `--script` mode — a node script using `GameManager.foo()` fails to compile there. Use `get_node("/root/GameManager")` (runtime path), which also works in the real game. In tests, grab the real autoload via `root.get_node("GameManager")`; do NOT `add_child` your own copy under the same name (it collides → auto-renamed GameManager2, and the scene-under-test's `/root/GameManager` lookup hits the REAL one while your asserts watch the orphan). Also: a `.tscn` has no sibling `.uid` file (uid is in the `[gd_scene ... uid=]` header); only scripts get `.gd.uid`.

### PowerShell native-command output encoding
Don't capture a UTF-8 tool's stdout into a PS string (PS 5.1 decodes it as the OEM codepage, double-corrupting accents like `é`→`├⌐`). Write the file directly (pandoc `-o`), or set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before capturing.