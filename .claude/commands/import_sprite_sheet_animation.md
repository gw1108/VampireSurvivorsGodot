---
name: import_sprite_sheet_animation
description: Import a grid sprite sheet into the Godot 4.6 project as a playable frame animation (AnimatedSprite2D + SpriteFrames) for characters, enemies, or one-shot VFX. Determines the sheet's grid, imports under res:// with pixel-art settings, builds the SpriteFrames (editor dialog or in code), and wires up looping cycles or self-freeing one-shots. Honors the project's NEAREST-filter rule.
model: sonnet
---

# Import Sprite Sheet Animation (Godot 4.6)

You take a **grid sprite sheet** (a single image whose frames are laid out in evenly-spaced columns
and rows) and turn it into a **playable Godot 4.6 animation**. This is the same pipeline for an enemy
walk cycle, a player attack, or a one-shot VFX like an explosion — only the loop flag and playback
wiring differ.

## Hard rule: pixel-art, always NEAREST

This is a pixel-art project. Read `VISUAL_RULES.md` (repo root). The short version, which this skill
**must not violate**:

- **Never** set a node's `texture_filter` to linear or `*_WITH_MIPMAPS`. New sprite nodes inherit the
  project default (Nearest) — leave them alone.
- **No mipmaps** on imports; **Lossless** compression.
- If a sheet is smooth/HD or oversized, fix the **art** (resize to target pixel size), never the
  filter. See Step 5.

## Starting point

The parameter is a path to a sprite sheet (e.g. `SourceArt/sheets/Poof.png`), optionally with a known
grid (`cols x rows`) and target FPS / loop. If no sheet was provided, respond with:

```
Point me at the sprite sheet you want imported (and its grid, if you know it) and I'll import it.
```

Then wait.

## Steps

### 1. Determine the grid

Frame the sheet as **`cols × rows`**; frames read **left → right, top → bottom**.

- Frame size = `image_width / cols` × `image_height / rows`.
- If the grid is unknown: open the image, count evenly-spaced columns and rows, and confirm the cell
  size looks consistent. A clean pixel-art sheet divides evenly (`width % cols == 0` and
  `height % rows == 0`). If it doesn't divide evenly, either the grid guess is wrong or the sheet
  needs re-cutting (see Step 5) — prefer the editor dialog (Step 3a), which slices fractional cells.
- When unsure of frame boundaries on a transparent sheet, detect them from **gaps in the alpha
  channel**: columns/rows that are fully transparent separate the frames. (This is just analysis — do
  not commit a script for it.)

### 2. Get the sheet into `res://` and import it

Godot only imports files under the project folder, so copy the source PNG into the Godot project:

- Destination convention: `vampire-survivors-taskmaster/assets/<category>/…` — e.g.
  `assets/vfx/<name>.png` for effects, `assets/sprites/<entity>/…` for characters/enemies. Keep
  `SourceArt/` as the untouched source of truth; copy, don't move.
- Select the texture in the FileSystem dock → **Import** tab → set **Compress = Lossless**,
  **Mipmaps → Generate = off**, no filter override → **Reimport**.
- Leave **Process → Size Limit** at 0 (no downscale). Only resize when a sheet has non-integer cells
  or is oversized — and prefer offline resizing for that (Step 5).

### 3a. Build the SpriteFrames in the editor (recommended)

1. Add an **`AnimatedSprite2D`** node to your scene.
2. Inspector → **Animation → Sprite Frames** → `<empty>` → **New SpriteFrames**; click it to open the
   **SpriteFrames** bottom panel.
3. In that panel's toolbar click **"Add frames from a Sprite Sheet"** (the grid-with-plus icon — *not*
   "Add frames from file"). Pick the imported PNG.
4. In the **Select Frames** dialog set **Horizontal = cols** and **Vertical = rows** (Size auto-fills;
   set Separation/Offset only if the sheet has gutters). Select the frames you want (Select All, or
   click-then-shift-click a range; you can omit trailing near-empty frames).
5. Click **Add N Frame(s)**.
6. Back in the panel, set the animation **Speed (FPS)** and the **Loop** toggle:
   - **Loop OFF** for one-shot VFX (required for the self-free pattern in Step 4).
   - **Loop ON** for cycles (idle/walk/run).
7. For multi-animation entities, rename the default animation and add more animations
   (`idle`, `walk`, `death`, …), repeating 3–6 for each. Set `autoplay`, or call `play("name")`.

### 3b. Build the SpriteFrames in code (alternative)

Useful for batching many sheets. Frames are added left→right, top→bottom:

```gdscript
# Builds a SpriteFrames from an evenly-divided grid sheet.
static func build_anim(sheet: Texture2D, cols: int, rows: int, fps: float, loop: bool,
		anim := "default") -> SpriteFrames:
	var sf := SpriteFrames.new()
	if not sf.has_animation(anim):
		sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	var fw: int = sheet.get_width() / cols   # use clean (evenly-divisible) sheets; see Step 5
	var fh: int = sheet.get_height() / rows
	for row in rows:
		for col in cols:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(col * fw, row * fh, fw, fh)
			sf.add_frame(anim, frame)
	return sf
```

Lightweight option without a SpriteFrames resource — a `Sprite2D` with `hframes`/`vframes` and a
driven `frame` (good for trivial one-shots):

```gdscript
extends Sprite2D
@export var fps := 12.0
var _t := 0.0
func _ready() -> void:
	hframes = 5  # cols
	vframes = 8  # rows
func _process(delta: float) -> void:
	_t += delta * fps
	var f := int(_t)
	if f >= hframes * vframes:
		queue_free()      # one-shot; or `f %= hframes * vframes` to loop
		return
	frame = f
```

### 4. Playback patterns

- **One-shot VFX** (explosion, poof, hit spark): Loop **off**, play once, free on finish.

```gdscript
extends AnimatedSprite2D
# Requires the animation's Loop = OFF, otherwise animation_finished never fires.
func _ready() -> void:
	animation_finished.connect(queue_free)
	play()
```

  Spawn it at the effect location and forget it; it removes itself. (If you later spawn these in
  large volumes, a pool can replace instantiate/`queue_free` behind a single spawn helper.)

- **Looping cycles** (characters, enemies): Loop **on**, named animations; switch with
  `play("walk")` / `play("idle")` driven by state, and use `flip_h` for facing.

### 5. Oversized or smooth source art under the NEAREST rule

The NEAREST rule means smooth/HD sheets won't be "fixed" by filtering — handle the art, never the
filter. But **don't resize by default**; follow `VISUAL_RULES.md` → *Resizing source art*:

- **Resize only if** the sheet has **non-integer cell sizes** (`width / cols` or `height / rows`
  isn't a whole number) **or** it's **unreasonably large** for the project. Otherwise import as-is.
- **When you resize, the goal is to** (a) make every cell a whole-pixel size — fixing the non-integer
  grid — and/or (b) bring the sheet to a reasonable size in the Godot project.
- Prefer **offline** resizing — slice the sheet, resize each frame, re-pack — for clean integer cells
  and no cross-frame seam bleed. Reserve Import **Process → Size Limit** for single, non-sliced
  textures; on a sheet it scales proportionally and won't guarantee integer cells.
- Avoid **non-integer runtime scale**; prefer integer scale and a fixed base resolution.
- Never enable mipmaps or switch to linear to hide aliasing.

### 6. Verify

- The SpriteFrames preview shows correctly-sliced frames (no bleed across cell edges, no half-frames).
- Run the scene: a one-shot plays once and the node frees itself (watch the remote scene tree for
  leaks); a cycle loops cleanly.
- Rendering is sharp/Nearest — no linear blur. Tune **FPS** and (for cycles) frame selection by feel.

## Worked examples (the three sheets in `SourceArt/sheets/`)

These are **examples** for illustrating the procedure, not assets to import now. Grids verified
(read order L→R, T→B). All are one-shots (Loop off).

| Sheet | Image px | Grid (cols×rows) | Frame px | Frames | Divides evenly? | Suggested FPS |
|---|---|---|---|---|---|---|
| `ExplosionSheet.png` | 4270×3840 | 5 × 8 | 854 × 480 | 40 | **yes** — clean integers | ~24–30; trim trailing near-empty frames |
| `Poof.png` | 512×512 | 3 × 3 | ≈170.7 × 170.7 | 9 | **no** — 512 ÷ 3 | ~18 |
| `Sparkle.png` | 4096×3277 | 5 × 4 | ≈819.2 × 819.25 | 20 | **no** — 4096 ÷ 5, 3277 ÷ 4 | ~28 |

`ExplosionSheet` slices into clean 854×480 cells. `Poof` and `Sparkle` do **not** divide into integer
cells — under the pixel-art rule, pre-resize them to a clean target size (Step 5) before final import,
or use the editor's *Add frames from sprite sheet* dialog, which slices fractional cells.

## Notes

- `SourceArt/sheets/extract_sprites.py` is a **separate, upstream** tool — it chroma-keys / alpha-cuts
  sheets into individual *static* sprite PNGs (default 64×64). It does **not** build animations; use it
  to prepare source art, then this skill to animate a grid sheet.
- Folder convention inside the Godot project: effects under `res://assets/vfx/`, entity sprites under
  `res://assets/sprites/<entity>/`. Keep originals in `SourceArt/`.
- Tune FPS, frame counts, and loop choices by feel per the project's testing philosophy — animation
  timing is dialed in by watching it run, not specified up front.
