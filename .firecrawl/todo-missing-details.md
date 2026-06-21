# Missing Details — Systems & Features Needing Specification

Source: `vampire-survivors-gameplay-extracted.md` is a high-level vision pitch, not a buildable spec.
Each item below needs concrete definitions (lists, numbers, rules, formulas) before implementation.

## 1. Weapons System
- [X] Define the full weapon list (names + descriptions)
- [X] Per-weapon base stats: damage, cooldown/fire rate, area, projectile speed, duration, amount/count, pierce, knockback
- [X] Per-weapon behavior/pattern: movement, targeting logic (nearest/facing/random/orbiting), collision
- [X] Upgrade curve: what each level (~8) does to each weapon

## 2. Passives / Power-Ups System
- [ ] Define the full passive list (names + descriptions)
- [ ] Define the player stat model (Might, Area, Cooldown, Speed, Duration, Amount, Move Speed, Max HP, Recovery, Armor, Magnet, Luck, Growth, Greed, Curse, Revival)
- [ ] Numeric effect per level for each passive, plus stacking rules

## 3. Character System
- [ ] Roster: how many characters and who they are
- [ ] Per-character starting weapon, stat modifiers, and unique ability
- [ ] Per-character level-up bonuses (if any)

## 4. Enemy & Spawn System
- [ ] Enemy roster: types, HP, contact damage, move speed, XP value, behavior
- [ ] Spawn director: density curve, which enemies per minute, formations/swarms, on-screen caps
- [ ] Elites/bosses that drop chests: which enemies, when, how often
- [ ] The Reaper: stats, behavior, spawn rules beyond time limit
- [ ] Enemy movement AI (chase vs. patterns)

## 5. Stage / Level System
- [ ] Define what "auto-generated, repeating layout" means (tiling, wraparound, bounds)
- [ ] Stage list: each stage's time limit, spawn tables, unique hazards/events
- [ ] Destructible objects (light sources/braziers): what they are and what they drop

## 6. Progression & XP
- [ ] XP curve: XP required per level and scaling
- [ ] Experience gem tiers and values
- [ ] Level-up choice screen: 3 vs. 4 options, plus Reroll / Skip / Banish mechanics

## 7. Pickups & Items
- [ ] Define the list of "other helpful items" (magnet, screen-clear bomb, gold bag, score items, etc.)
- [ ] Floor chicken heal amount; gold coin values
- [ ] Drop rates for all pickups

## 8. Chest & Loot Logic
- [ ] Rules for 1 / 3 / 5 item rolls and how the count is determined
- [ ] Exact trigger logic for evolution-via-chest

## 9. Meta-Progression (Between Runs)
- [ ] PowerUp shop: full list of persistent upgrades, effects, and gold costs
- [ ] Gold economy: earnings per run, from coins, and completion bonus
- [ ] Unlock conditions ("challenges") for every character, stage, weapon, and modifier
- [ ] Golden eggs: acquisition rate, stats granted, persistence
- [ ] Achievements / collection system (if included)

## 10. Core Formulas & Rules
- [ ] Damage formula (damage, knockback, crit if any, player invincibility frames)
- [ ] Curse effect on enemy count/speed/HP
- [ ] Luck effect on drops/chests; Greed effect on gold
- [ ] Death / revival handling, continue/restart flow

## 11. UI/UX & Technical
- [ ] HUD layout, level-up screen, pause menu, results screen, minimap
- [ ] Controls/input scheme (keyboard/gamepad)
- [ ] Save system for meta-progression
- [ ] Target resolution / art style / sprite specs and audio direction
