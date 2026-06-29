# Game Design Document: Vampire Survivors (Godot Clone) — First-Playable Vertical Slice

> **Source vision:** `.firecrawl/vampire-survivors-gameplay-extracted.md` (high-level pitch).
> **Canonical data:** the offline Vampire Survivors wiki under `.firecrawl/wiki-offline/` (exact rosters, stats, formulas). This GDD treats those numbers as authoritative — the slice is a faithful clone of one Mad Forest run, not a re-balance.
> **Scope locked:** single stage (Mad Forest), one character (Antonio), ~8 weapons + ~8 passives, **core run loop only** — no weapon evolutions, no meta-progression, no Golden Eggs, no Arcanas, no alt modes.

## Concept
**An auto-attacking horde-survival roguelite: play Antonio on the Mad Forest and survive escalating swarms for up to 30 minutes while your weapons fire themselves — the only thing you steer is your feet and the build you assemble on the way up.**

The player walks an endless field. Monsters pour in from all sides and hurt only on contact, so survival is about positioning, not aiming. Weapons attack automatically; killed monsters drop experience gems; gems level you up; each level offers a choice of new weapons or passive stat boosts. The fun is the runaway power curve — a single timid whip at minute 0 becomes a screen-filling storm of fire, lightning, and orbiting bibles by minute 20 — held against an enemy spawn curve that escalates even faster, culminating in the unkillable Reaper at the time limit.

## Genre & References
- **Genre:** Horde-survival / "bullet-heaven" roguelite (auto-attacker).
- **Primary reference:** *Vampire Survivors* (poncle) — a direct clone of its core single-stage run. Lineage: *Magic Survival*.
- **Tone:** retro-gothic, tongue-in-cheek; pixel-art monster-mob power fantasy.

## Platform & Audience
- **Platform:** Desktop, **Windows primary** (Godot 4 exports cross-platform; macOS/Linux are free follow-ons, not targets).
- **Input:** Keyboard — **WASD or Arrow keys** to move (8-directional). `ESC` to pause; mouse or keyboard to navigate menus and the level-up screen. No gamepad/touch in the first playable.
- **Audience:** Fans of roguelite / horde-survivor games wanting short (≤30 min), pick-up-and-play sessions with build variety. Single-player only.

## Core Gameplay Loop
**Moment-to-moment (seconds):** move to dodge contact damage and herd toward loot → weapons auto-fire at/around you → enemies die and drop XP gems → walk over gems (and within Magnet radius) to absorb them.

**Build loop (minutes):** XP fills the bar → **Level Up** pauses the action and offers 3–4 choices (new weapon, weapon upgrade, or passive) → pick one → power compounds → the spawn director raises enemy count/strength each minute → repeat.

**Run loop (one session):** survive the escalating curve for the stage's 30-minute soft limit → at 30:00 all enemies clear and **The Reaper** spawns (one more every following minute) → the run ends in death. Reaching 30:00 counts as a successful completion. There is no between-run spend in this slice (no shop); the result screen shows the run's stats. What makes it satisfying: constant legible feedback of numbers going up, the screen filling with your own effects, and the gamble of each level-up choice.

## Player Verbs & Controls
| Verb | Trigger | Notes |
|---|---|---|
| **Move** | WASD / Arrows | 8-directional. The only continuous input. Sets facing for directional weapons (Whip, Knife). |
| **Collect** | Automatic on overlap | XP gems, gold, chicken, and items are picked up by touching them or pulling them in via **Magnet** radius. |
| **Choose upgrade** | Level-up screen (mouse/keys) | Pick 1 of 3–4 offered weapons/passives. |
| **Reroll / Skip / Banish** | Buttons on level-up screen | Re-draw options / forgo for partial XP / remove an item from future pools. Charge handling: see "Level-Up Choice Screen". |
| **Pause** | `ESC` | Overlay; shows current build. |
| ~~Attack~~ | — | **No attack input.** All weapons fire automatically on their own cooldowns. |

## Mechanics & Rules

### Player Stat Model
The player has a fixed set of stats; weapons read these multipliers when they fire. Base values, caps, stacking, and the passive that boosts each. **Passives present in this slice are bolded;** the rest stay at base value (no in-run source) and exist in the model for weapons/character bonuses to act on.

| Stat | Base | Cap | Stacking | Passive (per-lvl → max) |
|---|---|---|---|---|
| **Max Health** | 100 | none | Multiplicative | **Hollow Heart ×1.2/lvl → ×2.49 @L5** |
| Recovery (HP/s) | 0 | none | Additive | Pummarola — *not in slice* |
| **Armor** (flat dmg reduction) | 0 | retaliatory cap +500% | Additive | **Armor +1/lvl → +5** |
| **Move Speed** | 100% | none | Additive | **Wings +10% → +50%** |
| **Might** (damage ×) | 100% | 1000% | Additive | **Spinach +10% → +50%** |
| **Area** | 100% | 1000% | Additive | **Candelabrador +10% → +50%** |
| **Speed** (projectile) | 100% | 500% | Additive | **Bracer +10% → +50%** |
| Duration | 100% | 500% | Additive | Spellbinder — *not in slice* |
| **Cooldown** | 100% | −90% floor | Additive (neg = faster) | **Empty Tome −8% → −40%** |
| **Amount** (extra projectiles) | 0 | +10 | Additive | **Duplicator +1 → +2** |
| Magnet (pickup radius) | 30 | none | Multiplicative | Attractorb — *not in slice* (Vacuum pickup still works) |
| Luck | 100% | none | Additive | Clover — *not in slice* |
| Growth (XP gain) | 100% | none | Additive | Crown — *not in slice* |
| Greed (gold gain) | 100% | none | Additive | Stone Mask — *not in slice* |
| Curse (enemy buff) | 100% | none | Additive | Skull O'Maniac — *not in slice* |
| Revival | 0 | none | Additive | Tirajisú — *not in slice; Revival stays 0 → death is final* |

### Damage, Crit, Knockback, I-Frames
- **Damage** = `weaponBaseDamage × totalMight`. Armor's retaliatory bonus multiplies on top.
- **Damage taken** = `enemyPower − Armor`, always ≥ 1.
- **Invulnerability frames:** base **240 ms** after taking a hit (and after certain heals).
- **Knockback:** on hit, the enemy's movement reverses × a knockback multiplier for ~120 ms. Bosses and the Reaper resist.
- **Critical hits:** per-weapon crit chance/multiplier; only certain weapons crit natively. Luck multiplies the chance (`crit = baseCritChance × totalLuck`); Luck stays at base 100% in this slice (no Clover/shop), so crits use base weapon values.

### Leveling & XP
- **XP source:** experience gems only, value × Growth.
- **Gem tiers by color:** **Blue ≤2 XP**, **Green ≤9 XP**, **Red 9+**. On-ground cap **400 gems** (excess merges into one red gem).
- **XP curve:** L1→L2 = 5 XP; per-level requirement rises **+10 XP/level through L20**, **+13/level L21–40**, **+16/level L41+**, with lump additions of **+600 XP at L20** and **+2400 XP at L40** (offset by a temporary +100% Growth at those levels). Cumulative: ~405 XP to L10, ~1,805 to L20.

### Level-Up Choice Screen
- Action pauses. Player is offered **3 options**, upgraded to **4** with luck: `chanceFourth = 1 − (1 / totalLuck)` (base ~0 extra chance at 100% Luck).
- Options are unique weapons/passives (no repeats in one level-up), weighted by item rarity; maxed and already-full items are excluded.
- **Inventory cap: 6 weapons + 6 passives.** Once full and maxed, level-ups instead offer **gold or Floor Chicken**.
- **Reroll / Skip / Banish (faithful-zero in this slice):** all three buttons appear on the screen but start at **0** charges, because their normal source — the meta PowerUp shop — is out of scope. **Reroll** is fed by the in-run **Rerollo** pickup (+1 each), so it becomes usable mid-run; **Skip** and **Banish** have no in-run source, so they render but stay **disabled** this slice.

### Weapons System
Each weapon auto-fires on its own cooldown with its own targeting/movement pattern, scaling off the player stats above. Weapons max at **level 8**. **Slice weapon set (8):** Antonio starts with the **Whip**; the other seven are obtainable via level-up.

| Weapon | Base Dmg | Cooldown | Amount | Pattern / targeting |
|---|---|---|---|---|
| **Whip** *(Antonio start)* | 10 | 1.35s | 1 | Horizontal slash in facing dir, pierces |
| **Knife** | 6.5 | 1.0s | 1 | Fast, in facing direction |
| **Magic Wand** | 10 | 1.2s | 1 | Bolt at nearest enemy |
| **Runetracer** | 10 | 3.0s | 1 | Bounces around the screen |
| **Garlic** | 5 | 1.3s | — | Damaging aura around player |
| **King Bible** | 10 | 3.0s | 1 | Orbits the player |
| **Fire Wand** | 20 | 3.0s | 3 | Fireball at random enemy |
| **Lightning Ring** | 15 | 4.5s | 2 | Strikes random enemies |

Per-weapon level 2–8 upgrade curves (each step grants some of: +Amount, +damage, +area, +speed, −cooldown, +pierce, +duration) are captured per-weapon in the wiki and carried into implementation verbatim. **Weapon evolutions are out of scope** (see Non-Goals) — these eight stay in their base forms, upgraded through level 8 only.

### Passive Items
**Slice passive set (8)** — each boosts one stat (per-level values in the Stat Model table). With evolutions out of scope, passives are purely stat boosts here:
**Spinach** (Might), **Armor** (Armor + retaliatory), **Hollow Heart** (Max HP), **Empty Tome** (Cooldown), **Candelabrador** (Area), **Bracer** (projectile Speed), **Wings** (Move Speed), **Duplicator** (Amount).

### Treasure Chests & Loot
- Dropped by **bosses** (not light sources), on the faithful Mad Forest boss schedule. Roll **1, 3, or 5** items, determined sequentially (5→3→1) with Luck scaling each tier.
- **Beginner's luck:** the first 6 chests follow a fixed **1-1-3-1-1-5** sequence.
- Chest items are **weapon/passive upgrades or new weapons/passives (from the slice's 8+8 pool) plus gold** — **no evolutions** in this slice.
- Gold per chest: 1-item 100–200, 3-item 300–600, 5-item 500–1,000 (× Greed). A full/maxed inventory converts chest items to gold bags.

### Pickups
| Pickup | Effect |
|---|---|
| **Experience Gem** | XP (Blue/Green/Red tiers) — the core progression currency. |
| **Floor Chicken** | Heals **30 HP**. |
| **Gold Coin / Coin Bag / Rich Coin Bag** | +1 / +10 / +100 gold. In this slice gold is a **HUD/run-score stat only** (no shop to spend it). |
| **Rosary** | Screen-clear: kills all non-immune enemies. |
| **Orologion** | Freezes all enemies for 10s. |
| **Vacuum** | Pulls all on-screen XP gems to the player. |
| **Nduja Fritta Tanto** | Player breathes fire for 10s. |
| **Rerollo** | +1 Reroll charge. |

### Curse / Luck / Greed (run modifiers)
- **Curse** raises enemy frequency, quantity, speed, and HP by its %; `effectiveSpawnInterval = spawnInterval / totalCurse`. Stays at base 100% in this slice (no Skull/shop). Hard on-screen enemy cap **500**.
- **Luck / Greed** stay at base 100% (no Clover/Stone Mask/shop) — they exist in the model but aren't built up in this slice.

### Death & Revival
- HP reaches 0 → if the player has **Revival** charges, revive **once per charge at 50% Max HP** in place with a burst of i-frames; otherwise the run ends and the result screen shows.
- Revival in this slice = **0** (no Tirajisú/shop, faithful-zero) → **death is always final**; on 0 HP the run ends and the result screen shows. No mid-run save; a run cannot be resumed.

## Game Objects & Entities

### Player Character — Antonio Belpaese
Moves in 8 directions, owns the stat model, carries up to 6 weapons + 6 passives. Health bar rendered under the sprite. **Starting weapon:** Whip. **Starting modifiers:** +20 Max HP (120 total), +1 Armor. **Level-up bonus:** +10% Might every 10 levels (max +50% at L50). The other three Belpaese starters are documented but **out of scope** (one playable character in this slice).

### Enemies
Stat model: **HP, Power (contact damage), Move Speed, Knockback resist, XP value.** Default AI = home toward the player; some move in a **fixed direction** (swarms), some **floaty/wavy**. Hard on-screen cap **500** (periodic spawns stop at 300 alive; bosses/events still spawn). Mad Forest roster:

| Enemy | HP | Power | Move Spd | XP |
|---|---|---|---|---|
| Zombie | 10 | 10 | 100 | 1 |
| Skeleton | 15 | 10 | 100 | 2 |
| Ghost | 10 | 5 | 200 | 1.5 |
| Mudman | 70–150 | 10 | 100 | 2.5 |
| Werewolf | 180 | 14 | 130 | 2 |
| Giant Bat | 270 | 10 | 140 | 2.5 |
| Big Mummy | 500 | 20 | 80 | 3 |
| (+ Pipeestrello bats, Venus, Mantichana, Flower Wall as waves/events) | | | | |

### Bosses & Elites
Stronger, often resistant minute-marker enemies (Glowing/Silver Bat, Giant Werewolf, Giant Mummy, Giant Blue Venus, etc.) that **don't despawn** and have a chance to drop a Treasure Chest.

### The Reaper
The run-ender. Spawns at the stage time limit (**30:00 for Mad Forest**), one additional Reaper every following minute. HP 655,350, **Power 65,535 (one-shots)**, Move Speed 1,200, negative knockback (hits drag it toward you). Resists freeze partially, immune to instant-kill/debuff. Clears the field on spawn.

### Light Sources (braziers)
Destructible props (HP 10). On destruction, roll the pickup drop table (Luck-weighted). Mad Forest: 10% spawn chance, up to 10 on screen, attempts every 1s, spawned off-screen.

### Experience Gems & Chests
Gems are the progression currency; chests (boss drops) are the build-spike currency. See Pickups / Treasure Chests.

## Win / Lose Conditions
- **Lose:** player HP hits 0 with no Revival charges → run ends, result/death screen.
- **Successful completion:** survive to **30:00**. Enemies clear, the Reaper spawns, reaching/passing the limit counts as a completed run. There is no hard victory — the Reaper guarantees eventual death; **survival time is the score**.

## Progression & Difficulty
- **In-run power:** levels → weapon/passive choices → compounding stats; boss chests deliver burst upgrades. No evolutions and no carried-over meta stats in this slice.
- **In-run difficulty:** the **per-minute Mad Forest wave table** drives escalation — enemy minimums and cadence ramp from 15 enemies @ 1.0s intervals (0:00) to 300 enemies @ 0.1s intervals (late game), tougher enemy types and bosses introduced each minute, swarm/formation events (Bat Swarm, Ghost Swarm, Flower Wall) at set timestamps, and the Reaper wall at 30:00. The full minute-by-minute table is implemented verbatim — **faithful and untuned**: the slice ships the real Mad Forest curve as-is.
- **Between-run progression:** none in this slice (no shop, unlocks, or Golden Eggs).

## World / Level Structure
- **Stage:** **Mad Forest** — an open, grassy, near-obstacle-free field; the only destructibles are braziers. Authored stage parameters (spawn table, modifiers, events), Normal modifiers only (no Hyper/Inverse).
- **Boundaries:** effectively endless — the field repeats/extends so the player never hits a hard wall; enemies spawn just off-screen on all four sides.
- **Camera:** follows the player at a fixed pixel-art zoom that renders Antonio at ~50×62 px on screen (see Art & Visual Direction and the Visual GDD).

## Art & Visual Direction
- **Style:** retro **pixel art**, top-down, matching the *Vampire Survivors* look in `Mad_Forest_gameplay.jpg` — green grass tiles, gothic monster sprites, bright blue/green/red gem pickups, chunky weapon VFX (white whip arcs, lightning, fire), readable silhouettes against dense mobs.
- **Resolution / presentation:** **1445×900 default window (windowed)**, **resizable**, with a **fullscreen** mode. The world is drawn through a player-following **pixel-art camera** whose zoom magnifies native pixel-art sprites to fixed on-screen sizes (the classic VS zoomed-in field of view). Pixels stay crisp via NEAREST filtering (see `VISUAL_RULES.md`); **resizing the window or going fullscreen changes how much of the field is visible, not the on-screen size of sprites** — the HUD re-anchors to the new window edges.
- **On-screen object sizes (at the default window/zoom):** the player (Antonio) is **~50×62 px**; **XP gems are ~20×20 px** (about a third of the player's height); **most weapon projectiles, pickups, and enemies are ≈ the player's size or smaller**. Exceptions: large/boss enemies (Werewolf, Giant Bat, Big Mummy, the giant variants, the Reaper) and area-weapon VFX (whip arc, Garlic aura, Lightning, fire) may exceed player size and scale with the **Area** stat. The full size table and the in-run HUD / level-up screen layouts live in the companion **Visual GDD** (`2026-06-25-ENG-vampire-survivors-visual-gdd.md`).
- **First-playable assets:** **programmer-art placeholders are acceptable** for the slice (the existing project already ships placeholder sprites for grass, enemy, boss, and the three gem tiers); art polish is a later pass.
- **Readability priority:** with up to 500 enemies on screen, player position, the health bar, gems, and incoming contact must stay legible — effects and mobs must not wash out the player.

## Audio Direction
Looping retro **chiptune/synth** background track for the stage (energetic, gothic). Punchy, layered SFX: weapon fire (per weapon family), enemy hit/death, XP-gem absorb (rising pitch as you chain), level-up chime, chest open, and an ominous Reaper sting. Audio's role is feedback density — every kill and pickup should "pop" so the screen-filling chaos stays satisfying rather than noisy. (Placeholder audio acceptable for the slice.)

## UI / UX
Grounded in `Mad_Forest_gameplay.jpg` and `400px-Level_up_screen.jpg`; exact relative placement and proportions are specified in the companion **Visual GDD** (`2026-06-25-ENG-vampire-survivors-visual-gdd.md`).
- **HUD (in-run):** XP bar across the very top; weapon + passive inventory icons top-left; **survival timer** top-center; **gold** and **kill count** top-right with the level indicator; player **health bar** under the character sprite.
- **Level-up screen:** action pauses; centered "Level Up!" panel lists 3–4 choices (icon, name, "New!"/level, description); left rail shows the full live stat readout and inventory grid; right side has **Reroll / Skip / Banish** buttons with remaining counts (Reroll usable via Rerollo pickups; Skip/Banish disabled at 0 this slice).
- **Pause screen:** dimmed overlay with "PAUSE" header (same visual treatment as the death overlay) showing the current build.
- **Result / death screen:** dark overlay summarizing the run (survival time, level, kills, gold) → continue/restart back to menu. (No revive prompt — Revival is 0 in this slice.)
- **Menu flow:** **Main menu → Start → straight into Mad Forest as Antonio.** No character-select screen (one character) and no shop/unlock menus in this slice.
- **Game feel / juice:** hit flashes, knockback, gem-absorb streaks, screen-clear flashes — feedback density is the priority.

## Scope

### MVP (first playable)
A single-stage vertical slice that proves the full core run:
- **Stage:** Mad Forest, full 30-minute session with the exact per-minute wave table, bosses, swarm events, and the Reaper wall. Normal modifiers only.
- **Character:** Antonio only (Whip start; +20 HP, +1 Armor; +Might-per-10-levels bonus). No character-select screen.
- **Weapons (8):** Whip, Knife, Magic Wand, Runetracer, Garlic, King Bible, Fire Wand, Lightning Ring — with full per-level (2–8) upgrade curves, base forms only.
- **Passives (8):** Spinach, Armor, Hollow Heart, Empty Tome, Candelabrador, Bracer, Wings, Duplicator.
- **Systems:** 8-dir movement, auto-attacking weapons, the stat model, XP/leveling, the 3–4 option level-up screen (Reroll fed by Rerollo pickups; Skip/Banish present but disabled at 0 charges), enemy spawn director + bosses + swarm events, Treasure Chests (item upgrades + gold), pickups (gems, chicken, gold, Rosary, Orologion, Vacuum, Nduja, Rerollo), light sources, contact damage + i-frames, death (Revival = 0, death final), the Reaper, HUD, pause, result screen.
- **Presentation:** 1445×900 default window (resizable + fullscreen), pixel-art camera zoom (player ~50×62, XP gems ~20×20 on screen — see Visual GDD); programmer-art placeholders OK; placeholder audio OK.

### Non-Goals
- Weapon **evolutions** and the full Treasure Chest evolution logic.
- **Meta-progression**: the gold PowerUp shop, character/weapon/stage unlocks, achievements, **Golden Eggs**.
- **Arcanas** and the Randomazzo.
- Alt modes: **Hyper, Inverse, Endless, Limit Break**.
- The other 30+ stages and the 200+ character roster (only Mad Forest + Antonio).
- The full weapon/passive catalog beyond the slice's 8 + 8.
- DLC content, Adventure mode, online/co-op multiplayer, controller/touch input.

## Technical Constraints
- **Engine:** **Godot 4** (existing project skeleton at `vampire-survivors-taskmaster/` with placeholder assets and a `project.godot`).
- **Performance:** must hold a stable frame rate with **up to 500 live enemies** + hundreds of gems and projectiles on screen — pooling, simplified per-entity logic, and spatial culling are hard requirements, not optimizations.
- **Save:** none required in this slice (no meta-progression to persist); a run cannot be saved/resumed mid-session.
- **Determinism:** none required (no replays/online); standard RNG.
