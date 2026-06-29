# Missing Art Assets — Vampire Survivors (Godot Clone) Vertical Slice

Source GDD: `thoughts/shared/game-design/2026-06-25-ENG-vampire-survivors-clone.md`
Scope: a single stage (**Mad Forest**), one character (**Antonio**), **8 weapons + 8 passives**, core run loop only.

This document lists **every art asset the GDD requires** to build the slice, grouped by category, with a checklist, a count, recommended source resolution, and the animation/variant needs for each. Programmer-art placeholders are acceptable for the first playable (per the GDD's Art section) — treat this as the full target list, not a blocker.

> **Current state of the repo:** the Godot project at `vampire-survivors-taskmaster/` ships **no art yet** — only `icon.svg` and `project.godot`. Despite the GDD line that the project "already ships placeholder sprites," none are checked in. So **every item below is currently missing** and needs at minimum a placeholder.

> **Style target (all assets):** retro **pixel art**, top-down, integer-scaled, 1280×720 window with a zoomed-in pixel-art camera. Green grass field, gothic monster mobs, bright blue/green/red gem pickups, chunky white/lightning/fire weapon VFX, readable silhouettes against dense (up to 500-enemy) mobs. The single most important authority for the in-game look is **`Mad_Forest_gameplay.jpg`** (see reference index below).

---

## Reference Screenshot Index (`.firecrawl/wiki-offline/*.jpg`)

Every `.jpg` in `.firecrawl/wiki-offline/` is catalogued here as a visual reference. "In scope" = directly depicts something the slice must render; "Out of scope" = shows a meta/menu feature the slice cuts, but is still useful for **art style and icon reference**.

| Screenshot (`.jpg`) | Scope | What it shows / what to pull from it |
|---|---|---|
| **`Mad_Forest_gameplay.jpg`** | ⭐ In scope — primary | The canonical in-run look: green grass tiles + dirt path, Antonio center with **health bar under the sprite**, white **Whip** arc, blue **Magic Wand** bolts, dense zombie/skeleton/bat mobs, scattered **blue XP gems**, a **brazier/light source** (left), and the full **HUD** (XP bar top, inventory icons top-left, timer top-center, gold/kill/level top-right). Match this for grass color, sprite scale, and VFX weight. |
| **`Level_up_screen.jpg`** | ⭐ In scope — primary | The level-up panel layout: centered "Level Up!" box with 3 choice rows (icon + name + "New!"/level + description), the **full live stat readout rail** down the left (every stat with its small icon), the inventory grid top-left, and **Reroll / Skip / Banish** buttons on the right. Authority for the level-up UI and the **per-stat HUD icons**. |
| **`400px-Level_up_screen.jpg`** | In scope | Lower-resolution duplicate of `Level_up_screen.jpg`; same layout, useful as a thumbnail sanity-check of proportions. |
| **`Level_Up_with_max_weapons_and_passives.jpg`** | In scope | The level-up screen when the inventory is **full/maxed** — choices become **Big Coin Bag** and **Floor Chicken** (the slice's faithful fallback). Also shows the stat rail and a very dense enemy field (good crowd-readability reference). |
| **`Level_up_with_limit_break.jpg`** | Partly in scope | Level-up panel showing **4 options** at once and the **"Random once / Random always"** (Reroll) button styling. The Limit-Break duplicate-entries and the *Inlaid Library* tiled floor are **out of scope**, but the 4-option panel layout and button art are useful. |
| **`Main_menu_-_full.jpg`** | In scope (minimal) | Title screen: "VAMPIRE SURVIVORS" logo, Dracula/maiden background art, and menu buttons (Start, etc.). The slice needs only **Main menu → Start**; reference for logo treatment, button style, and background mood. The companion `300px-Main_menu_-_basic.png` (PNG, not jpg) is a smaller variant. |
| **`1.13_Collection_-_base_game_and_ED_items.jpg`** | In scope (icon source) | A grid of **every weapon / passive / pickup icon** in the game. Best single reference for designing the slice's **8 weapon icons + 8 passive icons + pickup icons** (find Whip, Knife, Magic Wand, Runetracer, Garlic, King Bible, Fire Wand, Lightning Ring, Spinach, Armor, Hollow Heart, Empty Tome, Candelabrador, Bracer, Wings, Duplicator in the grid). Most of the grid is out of scope (other weapons), but the slice's 16 icons all appear here. |
| **`1920px-PowerUps_menu.jpg`** | Out of scope (icon source) | The meta PowerUp shop (cut from the slice). **Very useful** because it shows each **stat icon at large size with its label**: Might, Armor, Max Health, Recovery, Cooldown, Area, Speed, Duration, Amount, Move Speed, Magnet, Luck, Growth, Greed, Curse, Revival. Use it to author the HUD/level-up stat-rail icons. |
| **`1920px-Character_selection.jpg`** | Out of scope (sprite source) | Character-select screen (cut — one character only). Useful for the **Antonio portrait/sprite** and another clean view of the stat-icon rail. |
| **`1920px-Unlocks_menu.jpg`** | Out of scope | Meta unlocks list (cut). Shows several passive icons again (Wings, Crown, etc.) at list size — minor icon reference. |
| **`1920px-Secrets_menu_in_base_game.jpg`** | Out of scope | "Cast Spell" secrets menu (cut). Style/border reference only. |
| **`Adventures_menu.jpg`** | Out of scope | Adventure mode menu (cut). Style/border reference only. |
| **`300px-Merchant_UI_example.jpg`** | Out of scope | In-run Merchant UI (cut — no shop in slice). Panel/border style reference only. |

---

## 1. Player Character — Antonio Belpaese

| ✓ | Asset | Count | Notes (recommended source res, animation) |
|---|---|---|---|
| [X] | Antonio body sprite | 1 | ~16–24 px tall, top-down. Single facing is acceptable for VS (sprite flips horizontally for left/right; up/down reuse the same body). |
| [X] | Antonio **portrait/icon** | 1 | For the result screen and (optional) menu. See `1920px-Character_selection.jpg`. This sprite is the same as the body sprite! |

---

## 2. Weapons — VFX Sprites & Inventory Icons (8 weapons)

Each weapon needs **(a) an inventory icon** (shown in the HUD top-left and on the level-up rows) and **(b) in-world VFX sprites/animations** for its attack. Icons all appear in `1.13_Collection_-_base_game_and_ED_items.jpg`; the in-world look for Whip and Magic Wand is visible in `Mad_Forest_gameplay.jpg`.

| ✓ | Weapon | Icon | In-world VFX needed | Notes |
|---|---|---|---|---|
| [✓] | **Whip** *(Antonio start)* | 1 | Horizontal white slash arc, facing-direction | Animated 2–3 frame arc; mirrors with facing. The signature white crescent in `Mad_Forest_gameplay.jpg`. |
| [✓] | **Knife** | 1 | Small thrown blade projectile | Single sprite, rotates/flies in facing direction; fast. |
| [✓] | **Magic Wand** | 1 | Glowing bolt projectile + small impact | Blue/white bolt seen in `Mad_Forest_gameplay.jpg`; targets nearest enemy. |
| [✓] | **Runetracer** | 1 | Bouncing rune/projectile | Spinning sprite that ricochets around the screen. |
| [✓] | **Garlic** | 1 | Translucent damaging **aura ring** around player | Pulsing circular sprite/shader centered on the player; scales with Area. |
| [✓] | **King Bible** | 1 | Orbiting book sprite(s) | One book sprite, instanced × Amount, orbiting the player. |
| [✓] | **Fire Wand** | 1 | Fireball projectile + flame impact/burst | Animated flame; fired at a random enemy. |
| [✓] | **Lightning Ring** | 1 | Lightning-strike bolt + ground flash | Vertical strike + brief flash at strike point; hits random enemies. |

> All projectile/VFX sprites should be designed to read at high density (dozens on screen) and to scale with the **Area** stat without becoming muddy.

---

## 3. Passive Items — Inventory Icons (8 passives)

Passives are **icon-only** in the slice (no in-world VFX) — purely stat boosts. All 8 icons appear in `1.13_Collection_-_base_game_and_ED_items.jpg`; the stat each maps to is shown labeled in `1920px-PowerUps_menu.jpg`.

| ✓ | Passive | Icon | Boosts |
|---|---|---|---|
| [✓] | **Spinach** | 1 | Might |
| [✓] | **Armor** | 1 | Armor (+ retaliatory) |
| [✓] | **Hollow Heart** | 1 | Max HP |
| [✓] | **Empty Tome** | 1 | Cooldown |
| [✓] | **Candelabrador** | 1 | Area |
| [✓] | **Bracer** | 1 | Projectile Speed |
| [✓] | **Wings** | 1 | Move Speed |
| [✓] | **Duplicator** | 1 | Amount |

---

## 4. Enemies — Mad Forest Roster

Each enemy needs a **body sprite + short walk cycle**, plus a shared **hit-flash** and **death** treatment (a brief flash/fade or a small puff is enough; a per-enemy death sprite is optional polish). Crowd readability is critical (up to 500 on screen). All visible in `Mad_Forest_gameplay.jpg`.

### Base enemies (7)

| ✓ | Enemy | Sprite + walk | Notes |
|---|---|---|---|
| [X] | **Zombie** | 1 | The baseline green mob filling `Mad_Forest_gameplay.jpg`. |
| [X] | **Skeleton** | 1 | |
| [X] | **Ghost** | 1 | Floaty/wavy movement; slightly translucent. |
| [X] | **Mudman** | 1 | Tanky; brown/earthy. |
| [X] | **Werewolf** | 1 | Faster (purple wolves visible mid-field). |
| [X] | **Giant Bat** | 1 | Flapping 2-frame wing animation. |
| [X] | **Big Mummy** | 1 | Large, slow. |

### Wave / event enemies (4)

| ✓ | Enemy / event | Sprite | Notes |
|---|---|---|---|
| [X] | **Pipistrello bats** (Bat Swarm) | 1 | Swarm variant; can reuse Giant Bat art recolored/scaled. |
| [X] | **Venus** | 1 | Plant enemy (event). |
| [X] | **Mantichana** | 1 | Event enemy. |
| [X] | **Flower Wall** | 1 (+ formation) | A wall/formation of flower enemies that sweeps the field. |

---

## 5. Bosses & Elites + The Reaper

Stronger minute-marker enemies that don't despawn and can drop a Treasure Chest. Often **upscaled/recolored** versions of base enemies, but each should be visually distinct (size, palette, glow).

| ✓ | Boss / Elite | Sprite + anim | Notes |
|---|---|---|---|
| [X] | **Glowing / Silver Bat** | 1 | Glow/silver-tinted Giant Bat. |
| [X] | **Giant Werewolf** | 1 | Upscaled werewolf. |
| [X] | **Giant Mummy** | 1 | Upscaled Big Mummy. |
| [X] | **Giant Blue Venus** | 1 | Upscaled blue Venus. |
| [X] | **The Reaper** | 1 | The run-ender. Large, ominous, distinct silhouette; subtle idle animation. Needs to read instantly as "danger." Optional spawn/screen-clear flash on arrival. |

---

## 6. Pickups & Gems

Small world sprites the player walks over. XP gems are by far the most numerous (cap 400 on ground) — they must read at a glance by color. Gems and gold visible in `Mad_Forest_gameplay.jpg`; chicken/coin-bag icons in `Level_Up_with_max_weapons_and_passives.jpg` and the Collection grid.

| ✓ | Pickup | Count | Notes |
|---|---|---|---|
| [X] | **XP Gem — Blue** (≤2 XP) | 1 | Bright blue; the common drop. |
| [X] | **XP Gem — Green** (≤9 XP) | 1 | |
| [X] | **XP Gem — Red** (9+ XP) | 1 | Largest/brightest; also the merged-overflow gem. |
| [X] | **Floor Chicken** | 1 | Heals 30 HP. |
| [X] | **Gold Coin** (+1) | 1 | |
| [X] | **Coin Bag** (+10) | 1 | |
| [X] | **Rich Coin Bag** (+100) | 1 | (a.k.a. Big Coin Bag, see fallback level-up reward). |
| [X] | **Rosary** | 1 | Screen-clear pickup. |
| [X] | **Orologion** | 1 | Freeze-all pickup (clock). |
| [X] | **Vacuum** | 1 | Pulls all on-screen gems. |
| [X] | **Nduja Fritta Tanto** | 1 | Fire-breath pickup (+ the player fire-breath VFX, 10 s). |
| [X] | **Rerollo** | 1 | +1 Reroll charge. |

---

## 7. World Props & Treasure

| ✓ | Asset | Count | Notes |
|---|---|---|---|
| [X] | **Treasure Chest** (closed) | 1 | Dropped by bosses; sprite + open animation/flash. |
| [X] | **Treasure Chest** (open / opening anim) | 1 | Burst of light on open (juice). |
| [ ] | **Light source / Brazier** | 1 | Destructible prop, HP 10; the lit brazier in `Mad_Forest_gameplay.jpg` (left). Needs lit idle (small flame animation) + a destroy puff. |

---

## 8. Environment / Stage — Mad Forest

| ✓ | Asset | Count | Notes |
|---|---|---|---|
| [X] | **Grass ground tile(s)** | 1–4 | Tileable green grass; the base field. The dominant texture in `Mad_Forest_gameplay.jpg`. Provide a couple of variants to avoid obvious tiling across the endless field. |
| [ ] | **Dirt / path tile** | 1–2 | The brown trodden path crossing the field. |
| [ ] | **Tree / foliage props** | 2–4 | Decorative dark-green trees/bushes scattered for depth (top-left of the gameplay shot). Non-colliding. |
| [ ] | **Ground scatter** (rocks, patches) | 2–4 | Optional small detail sprites to break up the grass. |

> The stage is effectively endless and near-obstacle-free; only braziers are destructible. A small tile set that repeats cleanly is enough.

---

## 9. UI / HUD

Layout authority: `Mad_Forest_gameplay.jpg` (in-run HUD) and `Level_up_screen.jpg` (level-up + stat rail). Most of these can be Godot Control nodes + a 9-slice panel rather than bespoke sprites, but the **icons** are real art.

### In-run HUD

| ✓ | Asset | Notes |
|---|---|---|
| [ ] | **XP bar** graphic | Full-width bar across the very top (fill + background). |
| [ ] | **Inventory slot frames** | Top-left grid holding weapon + passive icons (6 + 6). |
| [ ] | **Survival timer** styling/font | Top-center `MM:SS`. |
| [X] | **Gold icon** | Top-right, next to gold count. |
| [ ] | **Kill-count icon** (skull) | Top-right, next to kill count. |
| [ ] | **Level indicator** styling | Top-right ("LV 26" in the gameplay shot). |

### Per-stat icons (level-up rail + HUD)

The level-up screen's left rail shows **every stat with a small icon**. Author the full set (reference: large labeled versions in `1920px-PowerUps_menu.jpg`; in-context in `Level_up_screen.jpg`):

| ✓ | Stat icons (≈19) |
|---|---|
| [X] | Max Health, Recovery, Armor, Move Speed |
| [X] | Might, Speed (projectile), Duration, Area |
| [X] | Cooldown, Amount, Revival, Magnet |
| [X] | Luck, Growth, Greed, Curse |
| [X] | Reroll, Skip, Banish (counters at the bottom of the rail) |

> In the slice only some stats actually change, but the HUD rail renders all of them (per the screenshots), so the full icon set is needed.

### Level-up screen

| ✓ | Asset | Notes |
|---|---|---|
| [ ] | **"Level Up!" panel** frame | Centered gold-bordered box (9-slice). See `Level_up_screen.jpg`. |
| [ ] | **Choice row** background/frame | One per option (3, or 4 with luck). |
| [ ] | **"New!" / level tag** styling | Yellow "New!" or "Level:n" label per row. |
| [ ] | **Reroll button** | Right rail; usable via Rerollo. (Styling also in `Level_up_with_limit_break.jpg`.) |
| [ ] | **Skip button** | Right rail; **disabled** appearance at 0 charges this slice. |
| [ ] | **Banish button** | Right rail; **disabled** appearance at 0 charges this slice. |

### Other screens

| ✓ | Asset | Notes |
|---|---|---|
| [ ] | **Pause overlay** | Dimmed/half-moon dark overlay + "PAUSE" header + current build display (same visual treatment as the death screen). |
| [ ] | **Result / death overlay** | Dark overlay summarizing survival time, level, kills, gold → continue/restart. No revive prompt (Revival = 0). |
| [ ] | **Main menu** | Logo + Start button + background. Reference `Main_menu_-_full.jpg` (slice needs only Start → Mad Forest). |

---

## 10. VFX / "Juice" (feedback density is a priority)

| ✓ | Effect | Notes |
|---|---|---|
| [ ] | **Enemy hit flash** | White flash on damage (shader). |
| [ ] | **Knockback** | Pure code (no art), but verify sprites read while reversing for ~120 ms. |
| [ ] | **Death puff / fade** | Small dissipation when an enemy dies. |
| [ ] | **Gem-absorb streak** | Gems streak toward the player within Magnet radius; rising-pitch chain (audio) paired with a visual trail. |
| [ ] | **Screen-clear flash** | Full-screen flash on Rosary / Reaper spawn. |
| [ ] | **Level-up glow** | Brief burst/glow on the player when XP bar fills. |
| [ ] | **Player fire-breath VFX** | Cone of flames for the Nduja pickup (10 s). |
| [ ] | **Damage numbers** (optional) | Floating numbers — VS-style; nice-to-have for the slice. |

> Placeholder colored rectangles/circles are acceptable at every tier for the first playable; this list defines the eventual art target and the order to replace placeholders in.
