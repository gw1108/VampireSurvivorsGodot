# Missing Details — Systems & Features Needing Specification

Source: `vampire-survivors-gameplay-extracted.md` is a high-level vision pitch, not a buildable spec.
Each item below needs concrete definitions (lists, numbers, rules, formulas) before implementation.

## 1. Weapons System
- [X] Define the full weapon list (names + descriptions)
- [X] Per-weapon base stats: damage, cooldown/fire rate, area, projectile speed, duration, amount/count, pierce, knockback
- [X] Per-weapon behavior/pattern: movement, targeting logic (nearest/facing/random/orbiting), collision
- [X] Upgrade curve: what each level (~8) does to each weapon

## 2. Passives / Power-Ups System
- [X] Define the full passive list (names + descriptions) — `Passive_Items.md` master table + per-item pages
- [X] Define the player stat model (Might, Area, Cooldown, Speed, Duration, Amount, Move Speed, Max HP, Recovery, Armor, Magnet, Luck, Growth, Greed, Curse, Revival) — `Player_stats.md` master table + per-stat pages (base/cap/stacking)
- [X] Numeric effect per level for each passive, plus stacking rules — each passive page gives per-level values, max bonus, and Additive/Multiplicative stacking

## 3. Character System
- [X] Roster: how many characters and who they are — `Characters.md` lists the full roster (~207) by name w/ counts
- [X] Per-character starting weapon, stat modifiers, and unique ability — *only the 4 Belpaese starters have detail pages (Antonio/Gennaro/Imelda/Pasqualina); the other ~203 are names only*
- [X] Per-character level-up bonuses (if any) — *only the 4 Belpaese starters have level-up scaling tables*

## 4. Enemy & Spawn System
- [X] Enemy roster: types, HP, contact damage, move speed, XP value, behavior — `Enemies.md` roster + stat definitions; per-enemy stat blocks (HP/Power/MSpeed/KB/XP) on detail pages
- [X] Spawn director: density curve, which enemies per minute, formations/swarms, on-screen caps — `Enemies.md` (wave system, 300/500-alive caps, curse spawn formula) + `Mad_Forest.md` per-minute curve + swarm/formation event pages
- [X] Elites/bosses that drop chests: which enemies, when, how often — `Enemies.md` + `Mad_Forest.md` (bosses per minute w/ chest-drop %) + `Treasure_Chest.md`
- [X] The Reaper: stats, behavior, spawn rules beyond time limit — `The_Reaper.md` (full stat block, one-shot behavior, one/min after time limit, per-stage spawn minute)
- [X] Enemy movement AI (chase vs. patterns) — `Enemies.md` "Skills" (homing/chase default, Fixed Direction, Floaty/wavy) + event pages

## 5. Stage / Level System
- [X] Stage list: each stage's time limit, spawn tables, unique hazards/events — *`Stages.md` gives the full stage list w/ time limits, modifiers, hazards/events & unlocks; per-minute spawn tables exist only for Mad Forest (other stage detail pages not captured)*
- [X] Destructible objects (light sources/braziers): what they are and what they drop — `Light_source.md` (10 HP, full weighted drop table, per-stage spawn chance/cap, cadence)

## 6. Progression & XP
- [X] XP curve: XP required per level and scaling — `Level_up.md` (explicit per-band formula + cumulative XP-by-level data L1–60)
- [X] Experience gem tiers and values — `Experience_Gem.md` (Blue ≤2 / Green ≤9 / Red 9+)
- [X] Level-up choice screen: 3 vs. 4 options, plus Reroll / Skip / Banish mechanics — `Level_up.md` (3/4 options w/ 4th-option luck formula) + `Banish.md`/`Reroll.md`/`Skip.md`

## 7. Pickups & Items
- [X] Define the list of "other helpful items" (magnet, screen-clear bomb, gold bag, score items, etc.) — `Pickups.md` full table (Rosary=screen-clear, Vacuum, Orologion=freeze, coin bags, Nduja/Sorbetto, clovers, etc.)
- [X] Floor chicken heal amount; gold coin values — `Floor_Chicken.md` (30 HP) + coin values (Coin 1 / Bag 10 / Rich Bag 100 / Pile 1000) in `Pickups.md` & `Gold_Coin_*` pages
- [X] Drop rates for all pickups — `Pickups.md` rarity weights + `Luck.md` selection formula (`itemWeight = rarity · totalLuck`)

## 8. Chest & Loot Logic
- [X] Rules for 1 / 3 / 5 item rolls and how the count is determined — `Treasure_Chest.md` (sequential L3→L2→L1 rolls, luck formula, worked example, Beginner's Luck sequence)
- [X] Exact trigger logic for evolution-via-chest — `Treasure_Chest.md` (Bronze<10:00 vs Silver≥10:00, Yellow Sign, one evolution per chest)

## 9. Meta-Progression (Between Runs)
- [X] PowerUp shop: full list of persistent upgrades, effects, and gold costs — `PowerUps.md` 27-entry table (per-rank effect, max, cost) + cost-escalation formula
- [X] Gold economy: earnings per run, from coins, and completion bonus — `Gold_Coin_(currency).md` (sources, chest gold 60–500, Greed/Stone Mask/Hyper multipliers up to ~4x, Reaper-death award)
- [X] Unlock conditions ("challenges") for every character, stage, weapon, and modifier — `Achievements.md` 449-entry unlocks table + `Secrets.md`/`Relics.md`/`Arcanas.md`
- [X] Golden eggs: acquisition rate, stats granted, persistence — *stats granted (+1% per stat) & persistence ("permanent, per character") covered across stat pages/`Pickups.md`; acquisition rate/drop probability not quantified*
- [X] Achievements / collection system (if included) — `Achievements.md` + `Collection.md` (full roster, totals, completion requirements)

## 10. Core Formulas & Rules
- [X] Damage formula (damage, knockback, crit if any, player invincibility frames) — `Might.md` (multiplies all weapon damage) + weapon base/per-level damage + `Critical_Hit.md` + `Knockback.md` + `Invulnerability_Time.md` (240ms base)
- [X] Curse effect on enemy count/speed/HP — `Curse.md` (raises speed/HP/spawn freq/quantity by Curse %, spawn formula, 500 cap)
- [X] Luck effect on drops/chests; Greed effect on gold — `Luck.md` (drop/chest formulas, 4th option) + `Greed.md` (gold multiplier, stage multipliers)
- [X] Death / revival handling, continue/restart flow — *`Revival.md` fully covers death→revival (1 revive @ 50% HP, i-frames, revive button, Reaper-revive gold bonus); Death_screen.md covers how the death overlay works.

## 11. UI/UX & Technical
- [X] HUD layout, level-up screen, pause menu, results screen — *`Level_up.md` covers the level-up screen and `Relics.md` covers pause-menu map/grimoire features; Mad_Forest_gameplay.jpg covers the general game and the HUD is visible in the screenshot. Level_up_screen.jpg and Level_Up_with_max_weapons_and_passives.jpg show how the level up screen should look. Pause screen is similar to the death screen of just an overlay with PAUSE in the header and a black half moon overlay.
- [X] Controls/input scheme (keyboard/gamepad) — WASD or arrow keys to move.
- [X] Save system for meta-progression — You cannot save an in progress run. However, meta progression is auto saved when you die.
