# Game Design Document: Vampire Survivors — Vertical Slice (Godot Recreation)

> Reference data lives in `.firecrawl/wiki-offline/` (offline Vampire Survivors wiki). This GDD is the
> authoritative *design* spec; the wiki pages are the authoritative *number tables* it points to.

## Concept
**A faithful recreation of a single Vampire Survivors run: stand in an open field, your weapons fire on their own, and survive a 30-minute tide of monsters by collecting XP, leveling up, and stacking weapon/passive upgrades into a build that eventually mows down the screen.**

The player controls **one character (Antonio)** on the **Mad Forest** stage. Movement is the only direct input — all weapons attack automatically. Killing enemies drops experience gems; collecting them triggers level-ups that offer a choice of new weapons or passive power-ups. The tension is the gap between the rising enemy density and the player's growing power: early on you weave through gaps to survive, and by the late game your build clears hordes effortlessly — until the 30:00 mark, when The Reaper arrives to end the run. The compelling hook is the **build-craft power fantasy**: small per-level decisions compound into a screen-filling engine of destruction.

## Genre & References
- **Genre:** Survivors-like / "bullet heaven" — auto-attacking horde-survival roguelite, 2D top-down.
- **Primary reference:** *Vampire Survivors* (poncle). This project is an explicit recreation of its first stage and core systems, "as is."
- **Recreation fidelity:** Faithful to the original's numbers and rules (damage, cooldowns, spawn tables, XP curve, etc.) as captured in the offline wiki, scoped to a single-stage, single-character vertical slice.

## Platform & Audience
- **Engine/Platform:** Godot 4.6.2, desktop (Windows primary; the engine exports cross-platform).
- **Input:** Keyboard — **WASD or arrow keys to move**. Menu navigation by mouse and/or keyboard. (Gamepad is a non-goal for the slice.)
- **Orientation/Resolution:** 16:9 landscape, pixel-art native resolution upscaled (target 1920×1080 window; see Art).
- **Audience:** Fans of survivors-likes / roguelites; also serves as an LLM-capability test bed (per project README). Single-player only.

## Core Gameplay Loop
**Moment-to-moment (in-run):**
1. **Move** to dodge enemies and reposition (weapons fire automatically on their own cooldowns).
2. **Kill** enemies → they drop **experience gems** (and occasionally gold, chicken, or pickups).
3. **Collect** gems within your Magnet radius → fill the XP bar.
4. **Level up** → game pauses, choose 1 of 3–4 offered weapons/passives (or upgrade an owned one).
5. **Grow stronger**, push into denser waves, open **chests** dropped by bosses (multi-item upgrades + gold).
6. Repeat, escalating until the **30:00** survival mark → **The Reaper** spawns and ends the run.

**Between-run loop:** none in the slice. The run is self-contained — gold is collected and shown as a **score stat** only, and there is no persistent meta-progression (no shop, unlocks, or golden eggs).

## Player Verbs & Controls
- **Move** — WASD / arrow keys (8-directional). The only continuous input.
- **Aim (implicit)** — facing direction (last moved direction) determines aim for directional weapons (Knife, Whip, Axe).
- **Collect** — automatic on contact / within Magnet radius (no pickup button).
- **Choose upgrade** — on level-up screen: click/select one of the offered options. (Reroll / Skip / Banish are **out of scope** for the slice.)
- **Pause** — Esc/dedicated key → pause overlay.
- **Revive** — button on death screen if a Revival charge is held (Revival is only obtainable in-run via the Tirajisú passive).
- Everything else (attacking, targeting) is fully automatic.

## Mechanics & Rules

### Time & Win/Survival Structure
- Mad Forest soft time limit: **30:00**. Surviving to 30:00 = successful completion.
- At **30:00** all on-screen enemies are cleared and **The Reaper** spawns; one additional Reaper spawns every following minute. The Reaper deals one-shot damage (65,535) — the run is meant to end here unless a Revival is held.

### Stats Model (player)
Player stats are multipliers/additions applied on top of each weapon's base stats. Base values and how each applies:

| Stat | Base | Notes / cap | Applies to |
|---|---|---|---|
| Might | 100% | cap +900% | multiplies all weapon damage |
| Area | 100% | cap +900% | weapon AoE size |
| Cooldown | 100% | floor 10% (−90%) | time between attacks (lower = faster) |
| Amount | 0 | cap +10 | extra projectiles per cast |
| Duration | 100% | cap +400% | how long effects/zones last |
| Speed (projectile) | 100% | cap +400% | projectile travel speed |
| Move Speed | 100% | — | character movement |
| Max Health | 100 (Antonio: 120) | — | HP pool |
| Recovery | 0 HP/s | — | passive regen |
| Armor | 0 (Antonio: 1) | flat −1 dmg each (min 1 dmg taken) | damage reduction |
| Magnet | 30 | — | pickup/gem collection radius |
| Luck | 100% | — | drop quality, chest quality, 4th option, crit |
| Growth | 100% | — | XP gained from gems |
| Greed | 100% | — | gold gained |
| Curse | 100% | no cap | ↑ enemy HP/speed/quantity/spawn-rate |
| Revival | 0 | via Tirajisú (max 2) | extra lives (revive @ 50% HP) |

Full per-stat caps/stacking: see `Player_stats.md` and the per-stat pages.

### Damage, Crit, Knockback, i-frames
- **Damage:** `weaponBaseDamage × Might` (per hit). Many AoE weapons hit every enemy in their area (effective infinite pierce); projectile weapons have finite Pierce.
- **Critical hits:** only crit-capable weapons (Whip 20%/×2, Knife 30%/×3, Axe 30%/×2, etc.). Crit chance scales with Luck.
- **Knockback:** pushes enemies back briefly; multiplier = weapon-dealt × enemy-taken; bosses largely resist it.
- **Invulnerability frames:** base **240 ms** of i-frames after taking damage (also granted briefly after level-up resume).
- **Contact damage:** enemies damage the player on contact (per-enemy Power), gated by the player's i-frames.

### Spawn Director
- **Wave system:** one wave per in-game minute; each wave defines the enemy types, a **minimum alive count**, and a **spawn interval**. The director tops up toward the minimum at the interval. (Full Mad Forest per-minute table in `Mad_Forest.md`.)
- **Caps:** periodic spawning halts at **300 alive** (only bosses + map-event enemies still spawn); hard cap **500 alive** regardless of Curse.
- **Curse:** `effectiveSpawnInterval = baseInterval / totalCurse`; also raises enemy HP, move speed, and wave minimums. (Base Curse 100%; no Curse sources in the slice unless added.)
- **Map events:** Bat Swarm, Ghost Swarm, Flower Wall — see World/Level Structure.
- **Bosses:** appear ~per minute, don't despawn off-screen, may drop a Treasure Chest.

### Leveling & XP
- Start at level 1; **5 XP** to reach L2. Per-level requirement increments: **+10 XP/level (L1–20), +13 (L21–40), +16 (L41+)**, with extra **+600 XP at L20** and **+2400 XP at L40** (and a temporary +100% Growth at those thresholds). Cumulative values: L5≈80, L10≈405, L20≈1,805, L30≈5,466, L40≈9,886, L50≈19,208. Full table: `Level_up.md`.
- **XP from gems** is multiplied by Growth.
- **Experience gems:** Blue (≤2 XP) / Green (≤9 XP) / Red (9+). If >400 gems are on the ground, no new gems spawn and further XP funnels into a single red gem.

### Level-Up Choice Screen
- On level-up the game pauses and offers **3 or 4** distinct options (weapons/passives/upgrades). 4th-option chance = `1 − (1/totalLuck)`. Choosing an unowned item adds it; choosing an owned one upgrades it +1 level.
- **Inventory caps:** max **6 weapons** and **6 passives**. Once both are full (and nothing left to upgrade), level-ups instead grant **gold or Floor Chicken**.
- **Reroll / Skip / Banish:** **out of scope** for the slice (no reroll/skip/banish controls).

### Treasure Chests
- **Chests** drop from **bosses** (chance per boss). Each contains **1, 3, or 5** items (upgrades to owned weapons/passives) plus gold (×Greed). Count is rolled L5→L3→L1 sequentially against Luck-scaled chances; fallback = 1 item. First six chests of a save follow the fixed **1-1-3-1-1-5** "beginner's luck" sequence.
- **All-maxed fallback:** if everything is maxed, chest items become coin bags (gold).
- **Weapon evolutions are out of scope** for the slice (deferred). Chests grant standard multi-item upgrades + gold only — no weapon ever evolves. (The full base-weapon → evolved-weapon map is documented in the per-weapon wiki pages for a future extension.)

### Pickups (in-world)
- **Floor Chicken** — heals **30 HP**.
- **Gold:** Coin (+1), Coin Bag (+10), Rich Coin Bag (+100), Big Coin Bag (+25), all ×Greed.
- **Magnet item / Vacuum** — collects all on-screen XP gems.
- **Rosary** — kills all on-screen non-immune enemies (screen clear).
- **Orologion** — freezes all enemies for 10 s.
- **Nduja / Sorbetto** — temporary fire/ice breath for 10 s.
- **Little Clover** (+10% Luck) and others — see `Pickups.md` for the full weighted drop table. Drop weights scale with Luck. (Reroll-related pickups like Rerollo are excluded since Reroll is out of scope.)

### Death & Revival
- On reaching 0 HP: if **Revival ≥ 1** (from Tirajisú), consume one and revive in place at **50% Max HP** with a burst of i-frames. Otherwise the run ends → **death screen** (red half-moon overlay, "Game Over", Revive button if available, Quit button) → **Results / Run Summary** screen → main menu.
- You **cannot save a run in progress**.

## Game Objects & Entities

### Player Character — Antonio Belpaese
The single playable character for the slice.
- **Starting weapon:** Whip.
- **Starting stats:** Max Health **120** (+20 over base 100), **Armor +1**; all other stats at base.
- **Unique growth:** **+10% Might every 10 levels**, capped at +50% (L1–9: +0%; L10–19: +10%; L20–29: +20%; L30–39: +30%; L40–49: +40%; L50+: +50%).
- Has the full stat block, an inventory of up to 6 weapons + 6 passives, an XP bar, an HP bar, and a level. Takes contact damage gated by i-frames.

### Weapons (14 base, all max level 8)
Auto-firing on individual cooldowns. Behavior summary (full stat blocks + 8-level curves in the per-weapon wiki pages):

| Weapon | Targeting / pattern | Base dmg | Base cooldown | Notable |
|---|---|---|---|---|
| Whip | horizontal slash, facing dir, AoE | 10 | 1.35s | 20% crit ×2; +proj alternate sides (Antonio start) |
| Magic Wand | nearest enemy, projectile | 10 | 1.2s | reliable single-target |
| Knife | faced direction, fast projectile | 6.5 | 1.0s | 30% crit ×3; high amount scaling |
| Axe | thrown up in an arc, high pierce | 20 | 4.0s | scales hard with Area |
| Cross | nearest enemy, boomerang, AoE | 5 | 2.0s | returns to player |
| King Bible | orbiting ring around player, AoE | 10 | 3.0s | duration-gated orbit |
| Fire Wand | random enemy, heavy hit | 20 | 3.0s | 3 base projectiles |
| Garlic | aura around player, AoE | 5 | 1.3s | per-hit delay; +knockback/−freeze-res |
| Santa Water | ground damage zones | 10 | 4.5s | drops at nearest then circular |
| Lightning Ring | random enemies, strike AoE | 15 | 4.5s | huge Area scaling |
| Runetracer | random dir, bouncing, infinite pierce | 10 | 3.0s | bounces off edges |
| Pentagram | screen-wipe (kills all) | — | 90s | also erases drops (Luck mitigates) |
| Peachone | circling bombard zone (CW), AoE | 10 | 1.0s | unions with Ebony Wings |
| Ebony Wings | circling bombard zone (CCW), AoE | 10 | 1.0s | unions with Peachone |

### Passives (15 base)
Stat-boosting items (full per-level values in `Passive_Items.md` and per-item pages):
Spinach (+Might), Hollow Heart (+Max HP, multiplicative), Pummarola (+Recovery), Empty Tome (−Cooldown), Candelabrador (+Area), Bracer (+Speed), Spellbinder (+Duration), Duplicator (+Amount, max 2), Crown (+Growth), Stone Mask (+Greed), Clover (+Luck), Wings (+Move Speed), Attractorb (+Magnet, multiplicative), Tirajisú (+Revival, max 2), Armor item (+Armor).

### Enemies (Mad Forest roster)
Standard behavior is **homing/chase** toward the player; some variants use **Fixed Direction** (swarm bats) or are **Floaty/wavy**. Bosses have HP-×-level scaling, resist freeze, and don't despawn. Representative stat blocks (full set on per-enemy wiki pages):

| Enemy | HP | Power | Move Spd | XP | Role |
|---|---|---|---|---|---|
| Pipeestrello (bat) | 1–15 | 4–6 | 100–140 | 1 | basic swarmer (first wave) |
| Skeleton | 15 | 10 | 100 | 2 | basic |
| Zombie | (wiki) | (wiki) | slow | (wiki) | basic |
| Ghost | (wiki) | (wiki) | (wiki) | (wiki) | mid |
| Green/Gray Mudman | (wiki) | (wiki) | (wiki) | (wiki) | mid |
| Werewolf | (wiki) | (wiki) | fast | (wiki) | mid/late |
| Big Mummy | (wiki) | (wiki) | (wiki) | (wiki) | late tank |
| Venus / Flower Wall | (wiki) | (wiki) | (wiki) | (wiki) | late / formation (HP×Level) |
| Glowing/Silver/Giant Bat | 50★ etc | 10 | 140 | 30 | bosses (chest drops) |
| The Reaper | 655,350 (×lvl) | 65,535 | 1,200 | 0 | end-of-run, one-shot |

Boss/elite enemies for Mad Forest and their per-minute timings + chest-drop chances are fully enumerated in `Mad_Forest.md`.

### Pickups, Chests, Gems
As described under Mechanics. Chests are boss-dropped objects that open into upgrade (+ gold, + possibly evolution) rewards.

## Win / Lose Conditions
- **Completion:** survive to **30:00** — the run is considered successfully completed. (The Reaper then ends the session.)
- **Lose / run-end:** HP reaches 0 with no Revival remaining → death → Results screen. (Being one-shot by the Reaper is the intended terminal state of a completed run.)
- There is no permanent "game over"; the player returns to the menu and runs again.

## Progression & Difficulty
- **In-run difficulty curve:** driven by the Mad Forest per-minute wave script — rising minimum alive counts (15 → 300) and shrinking spawn intervals (1.0s → 0.1s), tougher enemy types over time, and periodic boss/swarm/formation events, culminating in the Reaper at 30:00.
- **In-run power curve:** XP → level-ups → weapon/passive upgrades (to max level 8), plus boss-chest multi-item upgrades. The player's power should outpace enemy density by mid-game if the build is coherent. Antonio's +Might-every-10-levels reinforces the late-game spike. (Weapon evolutions, which would normally be the biggest spike, are deferred.)
- **Between-run progression:** none in the slice — **PowerUp shop, character unlocks, and Golden Eggs are out of scope**. **Gold is a score stat only** (collected and displayed, never spent); the run is fully self-contained.

## World / Level Structure
- **Single stage: Mad Forest.** Open, effectively boundless map (camera follows player; the layout is a repeating/auto-scrolling tiled field with very few obstacles). Time limit 30:00.
- **Stage modifiers (Normal):** player move speed ×1.1, enemy move speed ×1.1, XP ×1, gold ×1, Luck ×0, 10 starting spawns.
- **Destructibles:** **Light sources** (braziers) — 10 HP, ~10% spawn chance (max 50% w/ Luck), max 10 alive; destroying drops from a weighted pool (gold, chicken, gems, pickups).
- **Map events:**
  - **Bat Swarm** — a line of fast fixed-direction bats sweeps across the map (timed second-marks per minute, with chances/repeats per `Mad_Forest.md`).
  - **Ghost Swarm** — a line of ghosts sweeps across (later minutes).
  - **Flower Wall** — a ring of Flower-Wall enemies spawns around the player and closes in (minutes 5, 10, 15, 21+, etc.).
- **Spawn directions:** enemies appear from all four sides around the player ("Standard" wave type).
- The complete 30-minute wave/boss/event/Reaper script is in `Mad_Forest.md` and is the authoritative level definition.

## Art & Visual Direction
- **Style:** **Placeholder / programmer art** for the slice — simple colored sprites/shapes standing in for the character, enemies, weapons, pickups, and tiles. Real pixel-art assets can be swapped in later without changing systems.
- **Layout/feel:** top-down/oblique; camera centered on the player; native low-res canvas scaled to 1080p. Even with placeholder art, juice matters: damage feedback, gem sparkle, magnet streaks, level-up flash, screen-clear effects.
- **Reference for later art (not assets to ship):** `Mad_Forest_gameplay.jpg`, `Level_up_screen.jpg`, `Level_Up_with_max_weapons_and_passives.jpg` show the intended final look and HUD layout.

## Audio Direction
- **Scope:** minimal/placeholder for the slice (simple SFX stubs; music optional). Audio is not a focus of the recreation slice.
- **Key SFX (stubs acceptable):** weapon fire, enemy hit/death, level-up jingle, gem/coin pickup, chicken heal, chest open, Reaper arrival, player hurt/death.
- **Role:** reinforce feedback for mass kills and level-ups; can be elaborated when real assets land.

## UI / UX
- **HUD (in-run):** XP bar (top), timer, level, gold count, kill count; HP bar near the character; current weapon/passive icons. (Matches the layout visible in `Mad_Forest_gameplay.jpg`.)
- **Level-up screen:** pause overlay listing 3–4 options with icons/descriptions; shows max-state when weapons/passives are full (per `Level_up_screen.jpg`). No Reroll/Skip/Banish controls in the slice.
- **Pause screen:** overlay with "PAUSE" header on a black half-moon overlay (same visual family as the death screen).
- **Death screen:** death animation → SFX → red half-moon overlay fades in → "Game Over"; Revive button (if a Tirajisú charge remains) + Quit button.
- **Results / Run Summary:** "Results" header; left column = stage/difficulty/gold-multiplier, survived time, gold earned, level reached, enemies defeated, and a per-weapon table (Weapon | LV | Damage | Time | DPS); right column = character + owned weapons/passives/pickups; Done → main menu.
- **Main menu:** minimal — start run (Antonio, Mad Forest) and quit. No character-select (single character) and no shop (no meta) in the slice.

## Scope

### MVP (first playable / the vertical slice)
- **Stage:** Mad Forest, full 30-minute wave/boss/event script + Reaper.
- **Character:** **Antonio Belpaese only** (Whip start; 120 HP; +1 Armor; +10% Might every 10 levels).
- **Weapons/Passives:** **all 14 base weapons + all 15 base passives**, with full per-level upgrade curves.
- **Core systems (in):** movement, auto-attacking weapons, enemy spawn director with caps, contact damage + i-frames, XP/gems/leveling, level-up choice screen (3/4 options, pick-only), HP/healing/Recovery, death + revival (Tirajisú) + results, light sources, map events (Bat/Ghost Swarm, Flower Wall), The Reaper.
- **Treasure chests (in):** boss-dropped 1/3/5-item chests granting upgrades + gold (beginner's-luck sequence).
- **Gold:** drops, chest gold, and completion gold all exist, displayed as a **score stat** (no spending, no persistence).

### Non-Goals (out of scope for the slice)
- **Weapon evolutions** and the Vandalier union (the full map is in the wiki for a later extension).
- Reroll / Skip / Banish.
- Between-run meta: PowerUp shop, character unlocks, Golden Eggs.
- Other characters (the other 3 Belpaese and the full ~207 roster), character-select screen.
- Other stages, Adventures mode, DLC content.
- Arcanas; run modifiers (Hyper / Endless / Limit Break).
- Achievements / collection UI.
- Online/multiplayer, gamepad support, mobile/touch controls.

## Technical Constraints
- **Engine:** Godot 4.6.2, GDScript (assumed).
- **Performance target:** must handle the 500-enemy hard cap plus hundreds of projectiles/gems on screen at 60 FPS — pooling and efficient collision are required (this is the main technical risk).
- **Save:** none required — the run is self-contained and there is no persistent meta-progression (gold is a per-run score stat). No mid-run save.
- **Reference data:** all numeric tables sourced from `.firecrawl/wiki-offline/`.
