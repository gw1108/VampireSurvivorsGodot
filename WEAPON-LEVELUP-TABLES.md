# Per-weapon level-up table tasks

One workshop task per weapon: make each weapon follow its wiki level-up table exactly, the same
way the **Whip** already does. These are copy-paste-ready backlog items — enqueue them into
`workshop/backlog.json` (or a Ralph lane) and drain one per pass.

## The precedent to follow (Whip)

The Whip was converted from ad-hoc linear growth (`DAMAGE_PER_LEVEL` etc.) to a per-level table:

- **`vampire-survivors-taskmaster/data/whip_levels.csv`** — one row per level, one column per stat
  that changes, cumulative absolutes (each row fully describes the weapon at that level).
- **`vampire-survivors-taskmaster/data/whip_levels.csv.import`** — `importer="keep"` so Godot leaves
  the CSV FileAccess-readable instead of importing it as a Translation CSV (copy it, rename the paths).
- **`scripts/weapons/whip.gd`** — a static, column-name-driven loader (`_ensure_levels`/`_row`) cached
  across instances, that clamps levels past the table to the highest row (Limit Break) and reconstructs
  the wiki deltas if the CSV is missing so the weapon never breaks. The old linear
  `*_damage_per_level` / range-per-level constants were dropped.

Follow that shape for each weapon below. Keep the wiki base stat in `balance.csv` (e.g.
`<weapon>_base_damage`) and remove the now-superseded `<weapon>_damage_per_level` /
`<weapon>_interval_per_level` rows it replaces. Base damage still rolls `run.damage_variance()`
and multiplies by `run.might_mult()` / `run.power_mult()` exactly as today. Verify with
`ralph/gate.ps1` (headless import + gdUnit4). All 7 weapons cap at **level 8**.

Wiki sources live under `.firecrawl/wiki-offline/`.

---

## Task: King Bible follows its wiki level-up table

**Files:** `scripts/weapons/king_bible.gd`, new `data/king_bible_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `King_Bible.md`. Base: damage 10, area 100%, amount 1, duration 3.0s, orbit speed 100%. Max: damage 30, area 150%, amount 4, duration 4.0s, speed 160%.

| Level | Effect |
|---|---|
| 1 | Orbits around the character. |
| 2 | Fires 1 more projectile. |
| 3 | Base Area up by 25%. Base Speed up by 30%. |
| 4 | Effect lasts 0.5 seconds longer. Base Damage up by 10. |
| 5 | Fires 1 more projectile. |
| 6 | Base Area up by 25%. Base Speed up by 30%. |
| 7 | Effect lasts 0.5 seconds longer. Base Damage up by 10. |
| 8 | Fires 1 more projectile. |

Suggested `king_bible_levels.csv` (cumulative absolutes) — columns `level,amount,bonus_damage,area_mult,speed_mult`:

```
level,amount,bonus_damage,area_mult,speed_mult
1,1,0,1.0,1.0
2,2,0,1.0,1.0
3,2,0,1.25,1.3
4,2,10,1.25,1.3
5,3,10,1.25,1.3
6,3,10,1.5,1.6
7,3,20,1.5,1.6
8,4,20,1.5,1.6
```

Notes: current code derives book count from `1 + lvl/2` (gives 1→5) — replace with the table's
`amount` column (1,2,2,2,3,3,3,4). `speed_mult` scales `ANGULAR_SPEED`. Duration is cosmetic for a
persistent orbit; either drop the column or model it as book lifetime if you add one. Set
`king_bible_base_damage` to the wiki base 10 and delete `king_bible_damage_per_level`.

---

## Task: Lightning Ring follows its wiki level-up table

**Files:** `scripts/weapons/lightning.gd`, new `data/lightning_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Lightning_Ring.md`. Base: damage 15, area 100%, amount 2. Max: damage 65, area 400%, amount 6. (Ignores Speed/Duration.)

| Level | Effect |
|---|---|
| 1 | Strikes at random enemies. |
| 2 | Fires 1 more projectile. |
| 3 | Base Area up by 100%. Base Damage up by 10. |
| 4 | Fires 1 more projectile. |
| 5 | Base Area up by 100%. Base Damage up by 20. |
| 6 | Fires 1 more projectile. |
| 7 | Base Area up by 100%. Base Damage up by 20. |
| 8 | Fires 1 more projectile. |

Suggested `lightning_levels.csv` — columns `level,amount,bonus_damage,area_mult`:

```
level,amount,bonus_damage,area_mult
1,2,0,1.0
2,3,0,1.0
3,3,10,2.0
4,4,10,2.0
5,4,30,3.0
6,5,30,3.0
7,5,50,4.0
8,6,50,4.0
```

Notes: set `lightning_base_damage` to wiki base 15, delete `lightning_damage_per_level`. `amount` =
number of strikes per volley; `area_mult` scales the strike hitbox radius.

---

## Task: Garlic follows its wiki level-up table

**Files:** `scripts/weapons/garlic.gd`, new `data/garlic_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Garlic.md`. Base: damage 5, area 100%, cooldown 1.3s. Max: damage 15, area 200%, cooldown 1.0s. (Ignores Amount/Duration/Speed.)

| Level | Effect |
|---|---|
| 1 | Damages nearby enemies. Reduces resistance to knockback and freeze. |
| 2 | Base Area up by 40%. Base Damage up by 2. |
| 3 | Cooldown reduced by 0.1 seconds. Base Damage up by 1. |
| 4 | Base Area up by 20%. Base Damage up by 1. |
| 5 | Cooldown reduced by 0.1 seconds. Base Damage up by 2. |
| 6 | Base Area up by 20%. Base Damage up by 1. |
| 7 | Cooldown reduced by 0.1 seconds. Base Damage up by 1. |
| 8 | Base Area up by 20%. Base Damage up by 2. |

Suggested `garlic_levels.csv` — columns `level,bonus_damage,area_mult,cooldown`:

```
level,bonus_damage,area_mult,cooldown
1,0,1.0,1.3
2,2,1.4,1.3
3,3,1.4,1.2
4,4,1.6,1.2
5,6,1.6,1.1
6,7,1.8,1.1
7,8,1.8,1.0
8,10,2.0,1.0
```

Notes: **the current `garlic_base_damage` is 0 with `+1/level` — the wiki base is 5.** Fixing this is
the point of the task. Set `garlic_base_damage` to 5, delete `garlic_damage_per_level`. `cooldown`
replaces the static `garlic_tick_interval` per-level (or keep tick separate and treat this as the
aura's damage pulse interval — match the wiki 1.3→1.0).

---

## Task: Fire Wand follows its wiki level-up table

**Files:** `scripts/weapons/fire_wand.gd`, new `data/fire_wand_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Fire_Wand.md`. Base: damage 20, amount 3, projectile speed 75%. Max: damage 90, speed 135%. (Amount stays 3; ignores Duration.)

| Level | Effect |
|---|---|
| 1 | Fires at a random enemy, deals heavy damage. |
| 2 | Base Damage up by 10. |
| 3 | Base Damage up by 10. Base Speed up by 20%. |
| 4 | Base Damage up by 10. |
| 5 | Base Damage up by 10. Base Speed up by 20%. |
| 6 | Base Damage up by 10. |
| 7 | Base Damage up by 10. Base Speed up by 20%. |
| 8 | Base Damage up by 10. |

Suggested `fire_wand_levels.csv` — columns `level,bonus_damage,speed_mult` (speed_mult relative to L1):

```
level,bonus_damage,speed_mult
1,0,1.0
2,10,1.0
3,20,1.2
4,30,1.2
5,40,1.4
6,50,1.4
7,60,1.6
8,70,1.6
```

Notes: set `fire_wand_base_damage` to 20 (already), delete `fire_wand_damage_per_level`. Amount is a
constant 3 — no `amount` column needed. `speed_mult` scales projectile travel speed.

---

## Task: Knife follows its wiki level-up table

**Files:** `scripts/weapons/knife.gd`, new `data/knife_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Knife.md`. Base: damage 6.5, amount 1, pierce 1, projectile interval 0.1s. Max: damage 16.5, amount 6, pierce 3, interval 0.04s. (Ignores Duration.)

| Level | Effect |
|---|---|
| 1 | Fires quickly in the faced direction. |
| 2 | Fires 1 more projectile. |
| 3 | Fires 1 more projectile. Base Damage up by 5. |
| 4 | Fires 1 more projectile. (projectile interval reduced) |
| 5 | Passes through 1 more enemy. |
| 6 | Fires 1 more projectile. (projectile interval reduced) |
| 7 | Fires 1 more projectile. Base Damage up by 5. |
| 8 | Passes through 1 more enemy. (projectile interval reduced) |

Suggested `knife_levels.csv` — columns `level,amount,bonus_damage,pierce,proj_interval`:

```
level,amount,bonus_damage,pierce,proj_interval
1,1,0,1,0.10
2,2,0,1,0.10
3,3,5,1,0.10
4,4,5,1,0.08
5,4,5,2,0.08
6,5,5,2,0.06
7,6,10,2,0.06
8,6,10,3,0.04
```

Notes: `proj_interval` is the spacing between the shots in a multi-knife burst (NOT the between-throw
cooldown — that stays `knife_base_interval`). Wire `pierce` into the projectile's pass-through count.
Set `knife_base_damage` to 6.5, delete `knife_damage_per_level`.

---

## Task: Runetracer follows its wiki level-up table

**Files:** `scripts/weapons/runetracer.gd`, new `data/runetracer_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Runetracer.md`. Base: damage 10, amount 1, speed 100%, duration 2.25s. Max: damage 30, amount 3, speed 140%, duration ~3.25s.

| Level | Effect |
|---|---|
| 1 | Passes through enemies, bounces around. |
| 2 | Base Damage up by 5. Base Speed up by 20%. |
| 3 | Effect lasts 0.3 seconds longer. Base Damage up by 5. |
| 4 | Fires 1 more projectile. |
| 5 | Base Damage up by 5. Base Speed up by 20%. |
| 6 | Effect lasts 0.3 seconds longer. Base Damage up by 5. |
| 7 | Fires 1 more projectile. |
| 8 | Effect lasts 0.5 seconds longer. |

Suggested `runetracer_levels.csv` — columns `level,amount,bonus_damage,speed_mult,duration`:

```
level,amount,bonus_damage,speed_mult,duration
1,1,0,1.0,2.25
2,1,5,1.2,2.25
3,1,10,1.2,2.55
4,2,10,1.2,2.55
5,2,15,1.4,2.55
6,2,20,1.4,2.85
7,3,20,1.4,2.85
8,3,20,1.4,3.35
```

Notes: the wiki's per-row duration deltas (+0.3,+0.3,+0.5 = +1.1) overshoot its stated max of 3.25 by
0.1 — a wiki inconsistency; pick the max total (3.25) or the per-row sum (3.35) and note the choice.
`duration` = bounce lifetime; `speed_mult` scales bounce speed. Set `runetracer_base_damage` to 10,
delete `runetracer_damage_per_level`.

---

## Task: Magic Wand follows its wiki level-up table

**Files:** `scripts/weapons/weapon.gd` (the Magic Wand / base auto-weapon), new `data/magic_wand_levels.csv` (+`.import`), `data/balance.csv`.
**Wiki:** `Magic_Wand.md`. Base: damage 10, amount 1, pierce 1, cooldown 1.2s. Max: damage 30, amount 4, pierce 2, cooldown 1.0s. (Ignores Duration.)

| Level | Effect |
|---|---|
| 1 | Fires at the nearest enemy. |
| 2 | Fires 1 more projectile. |
| 3 | Cooldown reduced by 0.2 seconds. |
| 4 | Fires 1 more projectile. |
| 5 | Base Damage up by 10. |
| 6 | Fires 1 more projectile. |
| 7 | Passes through 1 more enemy. |
| 8 | Base Damage up by 10. |

Suggested `magic_wand_levels.csv` — columns `level,amount,bonus_damage,pierce,cooldown`:

```
level,amount,bonus_damage,pierce,cooldown
1,1,0,1,1.2
2,2,0,1,1.2
3,2,0,1,1.0
4,3,0,1,1.0
5,3,10,1,1.0
6,4,10,1,1.0
7,4,10,2,1.0
8,4,20,2,1.0
```

Notes: **do this weapon last / carefully.** The Magic Wand is special — its damage is currently
entangled with the `Power` passive (`magic_wand_base_damage` + accumulated `weapon_damage`, split in
`weapon.gd` so only the base varies). Introduce a proper `bonus_damage` per-level column and untangle
it from Power the same way `spinach_mult()` was separated, so the wand's own leveling (base 10 → 30)
is distinct from the Power/Might multiplier. Keep `Empty Tome`/Haste applying on top via `haste_mult()`.
