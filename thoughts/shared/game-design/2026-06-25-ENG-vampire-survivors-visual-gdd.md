# Visual GDD: Vampire Survivors (Godot Clone) — Display, Sizing & Screen Layouts

> **Companion to** `2026-06-25-ENG-vampire-survivors-clone.md` (the main GDD). This file is the source of truth for **screen resolution, on-screen object sizes, and the relative placement/proportions of the two gameplay screens**. The main GDD owns *what* to build; this file owns *how big things are and where they sit*.
> **Technical rendering rules** (NEAREST filtering, no mipmaps, pixel-consistent scaling) live in `VISUAL_RULES.md` and still apply — nothing here overrides them.
> **Reference screenshots:** `.firecrawl/wiki-offline/Mad_Forest_gameplay.jpg` (in-run HUD) and `.firecrawl/wiki-offline/400px-Level_up_screen.jpg` (level-up screen). All percentages below are read off those frames and expressed against the 1445×900 default window.

---

## 1. Display & Resolution

| Property | Spec |
|---|---|
| **Default window** | **1445 × 900**, **windowed** on launch. |
| **Resizable** | Yes — the window can be freely resized by the user. |
| **Fullscreen** | Supported via a toggle (e.g. `Alt`+`Enter` / `F11`). |
| **Aspect ratio** | 1445:900 ≈ **1.606** (~16:10). |
| **Rendering** | Player-following **Camera2D** with a fixed pixel-art **zoom**; native pixel-art sprites are magnified to the on-screen sizes in §2. NEAREST filter, no mipmaps (see `VISUAL_RULES.md`). |

**Scaling behavior (important):** the camera zoom keeps **sprite on-screen size constant** regardless of window size. Resizing the window or entering fullscreen **reveals more or less of the Mad Forest field** — it does **not** stretch or shrink sprites, and it does **not** change pixel crispness. The HUD is a screen-space overlay that **re-anchors to the new window edges** (top bar stays at the top, left rail stays at the left, etc.). This means at wider/larger windows the player simply sees a bigger slice of the battlefield around the (still-centered) character.

> Implementation note: "on-screen size" = native sprite pixels × camera zoom. The §2 targets are the **design intent**; pick native sprite sizes and a camera zoom that land near them while keeping scaling pixel-consistent per `VISUAL_RULES.md`. Treat the numbers as targets (±~10%), not pixel-exact contracts.

---

## 2. On-Screen Object Sizes

All sizes are **on-screen pixels at the default 1445×900 window / default camera zoom**. The **player is the reference unit**; "most" gameplay objects are player-size or smaller, with bosses and area VFX as the explicit exceptions.

| Object | On-screen size | Relative to player |
|---|---|---|
| **Player — Antonio** (reference) | **~50 × 62** | 1.0× (reference) |
| **XP gem** (Blue / Green / Red) | **~20 × 20** | ~⅓ of player height |
| Other small pickups (gold coin, Rerollo, Rosary, Orologion, Vacuum, Nduja) | ~20–40 | ≤ player |
| Floor Chicken / Treasure Chest | ~40–55 | ≈ player or smaller |
| Common enemies (Zombie, Skeleton, Ghost, Mudman) | ~40–60 tall | ≈ player or a touch smaller |
| Weapon projectiles (Knife, Magic Wand bolt, Runetracer, King Bible, Fire Wand ball) | ~25–50 | ≈ player or smaller |
| Braziers / light sources | ~45–60 | ≈ player |
| **Large / boss enemies** (Werewolf, Giant Bat, Big Mummy, giant variants) | up to ~1.5–2× player in their largest dimension | **exception — larger than player** |
| **The Reaper** | distinctly larger / imposing (boss silhouette) | **exception — larger than player** |
| **Area-weapon VFX** (Whip arc, Garlic aura, Lightning Ring, Fire Wand flames) | can span well beyond the player; **scale with the Area stat** | **exception — grows past player** |

**Rule of thumb for content authoring:** if it's a routine enemy, projectile, or pickup, draw/scale it to **≤ ~50×62 on screen**. Only bosses/elites and area-effect VFX are allowed to exceed that, and area VFX must visibly grow when the **Area** stat increases (per the main GDD stat model).

---

## 3. In-Run HUD Layout

Grounded in `Mad_Forest_gameplay.jpg`. The HUD is a **screen-space overlay anchored to the window edges**; the world (camera-space) sits behind it with the player locked to screen center. Percentages are fractions of window width (x) / height (y); px values are at 1445×900.

```
┌───────────────────── XP progress bar — full width, top edge ─────────────────────┐
│ [W][W][W][W][W][W]              ⏱ 08:22  (timer, centered)        ☠ 3867   🪙 1001  LV 26 │
│ [P][P][P][P][P][P]                                                                 │
│                                                                                   │
│                                                                                   │
│                                       🧍  ← player (screen center)                 │
│                                       ▬▬  ← red HP bar, directly under sprite      │
│                                                                                   │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

| Element | Anchor / position | Approx. placement & size |
|---|---|---|
| **XP progress bar** | Top edge, full width | x 0–100%, y 0%; height ~12–16 px (~1.5% of height). Blue fill, depletes/refills per level. |
| **Weapon inventory row** | Top-left, just below XP bar | First row of up to **6** weapon icons; left margin ~8 px; icons ~32×32 (~2.2% width). |
| **Passive inventory row** | Directly below weapon row, top-left | Second row of up to **6** passive icons, same icon size. |
| **Survival timer** | Top-center, horizontally centered | Centered at x 50%; baseline ~3–5% from top (just under XP bar). Large numerals, `MM:SS`. |
| **Level indicator** | Top-right corner | `LV n`, right-aligned at the very top-right. |
| **Kill count** | Top-right, left of/below level | Skull icon + count, right-aligned. |
| **Gold count** | Top-right, beside kills | Coin icon + count, right-aligned. |
| **Player sprite** | Screen center (world-space) | Fixed at x≈50%, y≈50%; ~50×62 px. Camera follows, so the player stays centered while the field scrolls. |
| **Player health bar** | Under the player sprite (world-space) | Red bar directly beneath the sprite, width ≈ player width (~50 px), height ~5–6 px, ~4–6 px gap below the feet. |

---

## 4. Level-Up Screen Layout

Grounded in `400px-Level_up_screen.jpg`. Action **pauses** and the gameplay behind is **dimmed**. Three vertical regions plus the persistent top bar.

```
┌───────────────────────────── XP bar (still visible) ─────────────────────────────┐
│                                  ⏱ 00:15  (timer)                                  │
│ ┌── stat rail ──┐     ┌──────────── Level Up! ────────────┐      ┌────────────┐    │
│ │  inv grid     │     │  [icon]  Name                New! │      │   REROLL   │    │
│ │  Max Health 27│     │          one-line description     │      │   n left   │    │
│ │  Armor       0│     │ ───────────────────────────────── │      ├────────────┤    │
│ │  Might     +35│     │  [icon]  Name                Lv 3 │      │    SKIP    │    │
│ │   ...         │     │          one-line description     │      │   n left   │    │
│ │  Reroll      n│     │ ───────────────────────────────── │      ├────────────┤    │
│ │  Skip        n│     │  [icon]  Name                New! │      │   BANISH   │    │
│ │  Banish      n│     │          one-line description     │      │   n left   │    │
│ └───────────────┘     └───────────────────────────────────┘      └────────────┘    │
│    left ~18% w               center ~46% w                         right ~18% w     │
└───────────────────────────────────────────────────────────────────────────────────┘
```

| Region | Anchor / position | Approx. placement & size | Contents |
|---|---|---|---|
| **Top bar** | Top edge | XP bar (full width) + survival timer centered at x 50%, y ~2% | Persist from the HUD; timer keeps showing run time while paused. |
| **Center "Level Up!" panel** | Horizontally centered | x ~27–73% (width ~46%, ~660 px); y ~10–90% (height ~80%, ~720 px) | Header **"Level Up!"** at top, then **3 choice rows (4 with Luck)** evenly stacked, each a horizontal strip: weapon/passive **icon** (left, ~48×48), **name** + `New!`/`Lv n` (top line), **one-line description** (below). Thin dividers between rows. |
| **Left stat rail** | Pinned to left edge, full height | x 0–~18% (~260 px) | **Inventory grid** at the very top (current weapons + passives as icons), then the **full live stat readout** — one stat per line with its current value: Max Health, Recovery, Armor, Move Speed, Might, Duration, Area, Cooldown, Amount, Speed, Luck, Growth, Greed, Curse, Magnet, Revival — followed by the **Reroll / Skip / Banish** charge counts. |
| **Right button column** | Pinned to right edge, full height | x ~82–100% (~260 px) | Three vertically-stacked buttons: **REROLL** (top), **SKIP** (mid), **BANISH** (bottom), each with its remaining-charge count beneath (`n left`). |

**Slice-specific state (matches the main GDD):** **Reroll** starts at 0 and becomes usable via the in-run **Rerollo** pickup; **Skip** and **Banish** render but stay **disabled at 0** charges (their meta-shop source is out of scope). The reference screenshot shows `10 left` on each because that is a meta-progressed save — in this slice all three start at **0**.

---

## 5. Pause & Result Screens (sizing notes)

These reuse the same overlay treatment as the level-up dim:

- **Pause screen:** full-window dimmed overlay, centered **"PAUSE"** header, current build shown (same visual treatment as the death overlay). HUD remains anchored to the edges behind the dim.
- **Result / death screen:** full-window dark overlay, centered summary block (survival time, level, kills, gold) → continue/restart. No revive prompt (Revival = 0 in this slice).

These do not introduce new object sizes; they inherit the HUD/level-up panel proportions above.
