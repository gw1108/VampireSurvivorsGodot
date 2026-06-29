"""
Extract individual item sprites from a spritesheet into per-item transparent PNGs.

Transparency styles are supported (see build_rgba):

  * "green" (default) -- chroma-key a vivid grass-green background. Robust to non-pure
    green, only removes background connected to the sheet border, and keeps edges solid.
  * "blue" -- the SAME chroma key on a BLUE screen (keys on blue-excess B - max(R,G)).
    Use it for a green sprite that would defeat a green key (e.g. a green clover). "red"
    works too; the only difference between these is which channel is the screen.
  * "dual" -- combine a white-background render and a black-background render of the same
    sheet to recover TRUE continuous alpha (soft edges, glows, glass) via difference
    matting; no color is "removed", so there is no colored fringe. Needs the extra file.

The default green sheet (`item_icons_green.png`) is an AI-generated 4x4 grid of items on a
vivid grass-green background. Unlike a naive chroma key, the green pipeline:

  * keys on chroma-EXCESS (the screen channel minus the max of the other two) so it
    doesn't depend on a pure (0,255,0) green,
  * only removes background that is connected to the sheet borders (so green/dark pixels
    *inside* a sprite are preserved),
  * builds a HARD binary matte at full resolution and relies on a premultiplied-alpha
    LANCZOS downscale to produce clean anti-aliasing only at the true silhouette, so
    sprite edges stay solid-colored instead of going translucent,
  * removes the dark 1-2px grid divider lines ONLY when they are actually detected,
  * converts the source to a lossless PNG first if it's a lossy/mismatched format
    (e.g. a JPEG saved with a .png extension), so no further quality is lost,
  * crops each item to a tight bounding box and writes correctly-named files.

Requires: numpy, opencv-python (cv2), Pillow.
"""

import argparse
import os
import numpy as np
import cv2
from PIL import Image

# --------------------------------------------------------------------------- #
# Tunable parameters
# --------------------------------------------------------------------------- #
# Chroma keying works on any screen colour by choosing which channel is the "screen".
# "chroma-excess" = screen_channel - max(other two): bg ~ +240, off-screen sprites ~ 0 or below.
CHROMA_CHANNELS = {"green": 1, "blue": 2, "red": 0}  # style/chroma name -> RGB channel index.
T_CHROMA = 80       # chroma-excess threshold: C - max(other two). bg ~ +240, sprites ~ 0.
T_CHROMA_STRONG = 150  # chroma-excess that is unambiguously background even when fully
                      # enclosed by a sprite (trapped chroma in the whip coils / ring hole).
                      # Solid sprite colors stay below this; true bg starts ~151.
T_DARK = 40        # brightness (max channel) below which a pixel is "near-black".
DIVIDER_BAND = 6   # px around each grid line / sheet edge where dark divider pixels may
                   # be removed. Dark removal is CONFINED to this band so a sprite's own
                   # dark pixels (e.g. the bible's cover) in the cell interior are never cut.
CHOKE = 1          # matte erosion iterations at full res (eats the 1px green halo).
PADDING = 6        # px of padding around each item's tight bbox (full res).
EMPTY_COV = 0.03   # cells with less foreground coverage than this are treated as empty.
EMPTY_ALPHA = 0.04 # dual style: alpha above this counts as foreground for bbox/empty checks.
MIN_COMP_AREA = 30 # isolate mode: connected components smaller than this are treated as speckle.
BG_POCKET_DIST = 30  # --fill-bg-pockets: RGB distance within which a pixel matches the sampled
                     # background colour. For sheets whose chroma colour is close to a legit
                     # sprite's colour (e.g. a muted green bg + a green gem), green-excess can't
                     # tell trapped background from the sprite, so fall back to bg-colour matching.
BG_POCKET_MIN = 600  # min area of an ENCLOSED bg-coloured blob to treat as a trapped pocket. A
                     # trapped pocket (rosary loop, vacuum gap) is one big contiguous blob; a
                     # same-hue sprite's bg-coloured pixels are small scattered facet highlights,
                     # so only blobs at/above this area are removed (tuned: gem facet ~520 < pocket).
SPRITE_GREEN_DIST = 45   # --keep-sprite-green: a green pixel farther than this (RGB) from the
                         # sampled background colour is a SPRITE, not background. Lets a green
                         # sprite (a clover) survive a green screen even though its green-excess
                         # would otherwise key it out with the background.
SPRITE_GREEN_MIN = 2000  # min area of such a sprite-green blob to rescue, vs the thin colour-
                         # shifted background slivers left near grid dividers (tuned: clover leaf
                         # blob ~17000 >> next-largest sliver ~1850).
DESPILL = True     # clamp the screen channel only on the thin inner edge ring (no global recolor).
SPRITE_SIZE = (64, 64)
ROWS, COLS = 4, 4

# (row, col) -> output sprite name. Cells not listed are skipped entirely.
# Row 0 col 2 is an empty green cell and is intentionally omitted. Duplicate item
# renditions on the sheet get a _2 suffix so every variant is preserved.
SPRITE_MAP = {
    (0, 0): "whip",
    (0, 1): "sword_thick",
    (0, 3): "magic_wand",
    (1, 0): "runetracer_tetrahedron",
    (1, 1): "runetracer_octahedron",
    (1, 2): "runetracer_tetrahedron_2",
    (1, 3): "runetracer_octahedron_2",
    (2, 0): "runetracer_dodecahedron",
    (2, 1): "garlic",
    (2, 2): "bible",
    (2, 3): "fire_wand",
    (3, 0): "garlic_2",
    (3, 1): "bible_2",
    (3, 2): "fire_wand_2",
    (3, 3): "lightning_ring",
}

# Second sheet (item_icons_2.png): a full 4x4 grid, no empty cells. Rows 0/1 are
# variant pairs of the same weapons; rows 2/3 are variant pairs of the same relics.
SPRITE_MAP_2 = {
    (0, 0): "sword_broad",
    (0, 1): "dagger",
    (0, 2): "wand_arcane",
    (0, 3): "shadow_staff",
    (1, 0): "sword_broad_2",
    (1, 1): "dagger_2",
    (1, 2): "wand_arcane_2",
    (1, 3): "shadow_staff_2",
    (2, 0): "holy_tome_blue",
    (2, 1): "holy_tome_red",
    (2, 2): "ring_blue",
    (2, 3): "ring_purple",
    (3, 0): "holy_tome_blue_2",
    (3, 1): "holy_tome_red_2",
    (3, 2): "ring_blue_2",
    (3, 3): "ring_purple_2",
}

_KERNEL3 = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))


def detect_dividers(brightness, rows=ROWS, cols=COLS):
    """Return True if dark grid-divider lines sit on the interior cell boundaries.

    We only want to strip a dark border when one actually exists, so we look for a
    consistently dark line near each interior boundary rather than assuming it.
    """
    h, w = brightness.shape
    for x0 in (w // cols * i for i in range(1, cols)):
        band = brightness[:, max(0, x0 - 3):x0 + 4]
        if band.size and band.mean(axis=0).min() < T_DARK:
            return True
    for y0 in (h // rows * i for i in range(1, rows)):
        band = brightness[max(0, y0 - 3):y0 + 4, :]
        if band.size and band.mean(axis=1).min() < T_DARK:
            return True
    return False


def divider_zone(h, w, band, rows=ROWS, cols=COLS):
    """Boolean mask that is True only within `band` px of a grid line or the sheet edge.

    Dark-divider removal is restricted to this zone so it stays at the borders and can
    never reach into the middle of a sprite.
    """
    zone = np.zeros((h, w), bool)
    zone[:band, :] = zone[-band:, :] = True          # top / bottom sheet edges
    zone[:, :band] = zone[:, -band:] = True          # left / right sheet edges
    for i in range(1, cols):                          # interior vertical grid lines
        x0 = w * i // cols
        zone[:, max(0, x0 - band):x0 + band] = True
    for i in range(1, rows):                          # interior horizontal grid lines
        y0 = h * i // rows
        zone[max(0, y0 - band):y0 + band, :] = True
    return zone


def _sample_bg_color(rgb):
    """Median RGB of the 1px sheet border = the chroma background colour."""
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]], axis=0)
    return np.median(border, axis=0)


def _chroma_excess(rgb, chroma="green"):
    """Screen-channel excess: rgb[chroma] - max(the other two channels).

    >0 means the pixel is that screen colour (background); <=0 means it is not. This is the
    chroma-key signal, generalised over the channel so green / blue / red screens all work.
    For chroma="green" this is exactly the original G - max(R,B).
    """
    ci = CHROMA_CHANNELS[chroma]
    others = [i for i in (0, 1, 2) if i != ci]
    return rgb[..., ci] - np.maximum(rgb[..., others[0]], rgb[..., others[1]])


def remove_bg_pockets(rgb, fg, dist_thresh=BG_POCKET_DIST, min_area=BG_POCKET_MIN,
                      chroma="green"):
    """Drop large enclosed regions that match the sampled background colour.

    The green-excess key fails when the chroma background is close in colour to a real
    sprite (this sheet: a muted green bg ~[4,163,63] and a green gem of nearly the same
    colour). Then trapped background inside an enclosed shape (the rosary's bead loop, the
    gap behind the vacuum handle) survives, because it is neither border-connected nor
    strong-green. It cannot be separated from the gem by colour OR threshold -- but it CAN
    by shape: a trapped pocket is one big contiguous bg-coloured blob, whereas a same-hue
    sprite's bg-coloured pixels are small scattered facet highlights. Remove only the big
    blobs. Returns a new foreground mask.
    """
    bg = _sample_bg_color(rgb)
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    near = ((dist < dist_thresh) & fg).astype(np.uint8)   # bg-coloured pixels still kept as fg
    if not near.any():
        return fg
    n, labels, stats, _ = cv2.connectedComponentsWithStats(near, connectivity=8)
    out = fg.copy()
    pocket = np.zeros(fg.shape, bool)
    removed = 0
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= min_area:
            pocket |= labels == i
            removed += 1
    if not removed:
        return fg
    out[pocket] = False
    # Also drop the thin GREENISH anti-aliased fringe hugging each pocket (boundary pixels
    # between the bg-coloured pocket and the sprite, just past dist_thresh). Restricting to
    # green-excess > T_CHROMA means a gold/red sprite edge touching the pocket is left intact.
    ring = cv2.dilate(pocket.astype(np.uint8), _KERNEL3, iterations=2).astype(bool) & out
    out[ring & (_chroma_excess(rgb, chroma) > T_CHROMA)] = False
    print(f"Removed {removed} trapped background-colour pocket(s) "
          f"(bg~{bg.astype(int).tolist()}, dist<{dist_thresh}, area>={min_area}).")
    return out


def protect_sprite_green(rgb, fg, dist_thresh=SPRITE_GREEN_DIST, min_area=SPRITE_GREEN_MIN,
                         chroma="green"):
    """Add back large green regions whose colour differs from the sampled background.

    Green-excess keys ANY green as background, so a green sprite on a green screen (a green
    clover, whose leaf green-excess can even exceed T_CHROMA_STRONG) is flood-filled away with
    the background. But the clover's green is a DIFFERENT green: far from the bg colour (dist
    ~50-98) where the flat background sits at dist <5. Rescue large connected blobs of green
    that ISN'T the background colour; the size gate skips the thin colour-shifted background
    slivers left near grid dividers. Returns a new foreground mask.
    """
    bg = _sample_bg_color(rgb)
    dist = np.sqrt(((rgb.astype(np.float32) - bg) ** 2).sum(axis=2))
    sprite_green = ((_chroma_excess(rgb, chroma) > T_CHROMA) & (dist > dist_thresh)).astype(np.uint8)
    if not sprite_green.any():
        return fg
    n, labels, stats, _ = cv2.connectedComponentsWithStats(sprite_green, connectivity=8)
    out = fg.copy()
    rescued = 0
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] >= min_area:
            out[labels == i] = True
            rescued += 1
    if rescued:
        print(f"Rescued {rescued} sprite-green region(s) far from bg colour "
              f"(bg~{bg.astype(int).tolist()}, dist>{dist_thresh}, area>={min_area}).")
    return out


def build_foreground_mask(rgb, rows=ROWS, cols=COLS, fill_bg_pockets=False,
                          protect_green=False, chroma="green"):
    """Build a hard binary foreground matte (bool HxW) from an int16 RGB array.

    `chroma` selects which screen colour is keyed out ("green"/"blue"/"red"); the logic is
    identical, only the channel differs. See _chroma_excess.
    """
    brightness = rgb.max(axis=2)
    chroma_excess = _chroma_excess(rgb, chroma)

    bg_candidate = chroma_excess > T_CHROMA

    has_dividers = detect_dividers(brightness, rows, cols)
    if has_dividers:
        # Fold the near-black divider lines into the background candidate, but ONLY
        # within a thin band around the grid lines/edges. This keeps dark removal at
        # the borders so a sprite's own dark interior (e.g. the bible cover) is never cut.
        zone = divider_zone(*brightness.shape, DIVIDER_BAND, rows, cols)
        bg_candidate = bg_candidate | ((brightness < T_DARK) & zone)
    print(f"Grid dividers detected: {has_dividers}")

    # Keep only background that is connected to the sheet border. Green-ish or dark
    # pixels enclosed inside a sprite form their own components and stay opaque.
    num, labels = cv2.connectedComponents(bg_candidate.astype(np.uint8), connectivity=8)
    border = np.concatenate([labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]])
    border_labels = set(int(v) for v in np.unique(border) if v != 0)
    background = np.isin(labels, list(border_labels)) if border_labels else np.zeros_like(labels, bool)

    # Also remove background-strength chroma ANYWHERE, even when not border-connected:
    # screen colour trapped inside the whip's coils or the lightning ring's center hole.
    background = background | (chroma_excess > T_CHROMA_STRONG)
    fg = ~background

    # Choke the matte by 1px to eat the partially-green halo ring at the silhouette.
    if CHOKE > 0:
        fg = cv2.erode(fg.astype(np.uint8), _KERNEL3, iterations=CHOKE).astype(bool)

    # Opt-in: strip trapped background-colour pockets the chroma-excess key can't (used when
    # the chroma colour is close to a real sprite's colour). See remove_bg_pockets.
    if fill_bg_pockets:
        fg = remove_bg_pockets(rgb, fg, chroma=chroma)
    # Opt-in: rescue a same-hue sprite the key wrongly removed (e.g. green-on-green screen).
    if protect_green:
        fg = protect_sprite_green(rgb, fg, chroma=chroma)
    return fg


def despill_ring(rgb, fg, chroma="green"):
    """Clamp the screen channel to max(other two) only on the 1px inner edge ring.

    Removes the screen-colour spill that haloes a silhouette, locally (not a global recolor).
    `chroma` picks the channel; for "green" this is the original clamp of G to max(R,B).
    """
    if not DESPILL:
        return rgb
    ci = CHROMA_CHANNELS[chroma]
    others = [i for i in (0, 1, 2) if i != ci]
    out = rgb.copy()
    ring = fg & cv2.dilate((~fg).astype(np.uint8), _KERNEL3, iterations=1).astype(bool)
    max_other = np.maximum(rgb[..., others[0]], rgb[..., others[1]])
    over = ring & (rgb[..., ci] > max_other)
    out[..., ci] = np.where(over, max_other, rgb[..., ci])
    return out


def _border_mean(rgb):
    """Mean brightness of the 1px image border (tells a white-bg apart from a black-bg)."""
    return (float(np.mean(rgb[0])) + float(np.mean(rgb[-1])) +
            float(np.mean(rgb[:, 0])) + float(np.mean(rgb[:, -1]))) / 4.0


def recover_alpha_dual(white_rgb, black_rgb):
    """Recover true RGBA from two renders of the same subject over white and over black.

    Difference matting: a pixel composited over a background B reads C*a + B*(1-a). Over
    black (B=0) it is C*a (already premultiplied); over white (B=255) it is C*a + 255*(1-a).
    The two renders therefore differ by 255*(1-a) per channel, so the distance between them
    yields alpha, and the black render divided by alpha yields the unmultiplied color. This
    recovers genuine PARTIAL alpha (soft edges, glows, glass) with no colored fringe, which a
    binary chroma key cannot. Technique from https://jidefr.medium.com/generating-transparent-
    background-images-with-nano-banana-pro-2-1866c88a33c5

    `white_rgb`/`black_rgb` are int16 HxWx3 of identical shape. Returns
    (alpha float HxW in [0,1], rgb uint8 HxWx3 unmultiplied).
    """
    W = white_rgb.astype(np.float32)
    K = black_rgb.astype(np.float32)
    dist = np.sqrt(((W - K) ** 2).sum(axis=2))
    bg_dist = np.sqrt(3.0) * 255.0
    alpha = np.clip(1.0 - dist / bg_dist, 0.0, 1.0)

    a3 = alpha[..., None]
    rgb = np.where(a3 > 0.01, np.clip(K / np.maximum(a3, 1e-6), 0, 255), 0)
    return alpha, rgb.astype(np.uint8)


def build_rgba(style, sources, rows=ROWS, cols=COLS, fill_bg_pockets=False,
               protect_green=False):
    """Produce a full-resolution RGBA plane plus a boolean foreground mask.

    The mask drives bbox/empty-cell detection; the RGBA carries the color and alpha that get
    sliced and downscaled. Styles:

      * "green"/"blue"/"red" -- chroma-key that screen colour to a HARD binary matte (the
        original green path, generalised over the channel).
      * "dual"  -- difference-matte a white-bg + black-bg pair into true continuous alpha.

    `sources` is {"main": rgb} for a chroma key, or {"white": rgb, "black": rgb} for dual.
    """
    if style == "dual":
        alpha, rgb = recover_alpha_dual(sources["white"], sources["black"])
        fg = alpha > EMPTY_ALPHA
        rgba = np.dstack([rgb, np.round(alpha * 255).astype(np.uint8)])
        return rgba, fg

    chroma = style if style in CHROMA_CHANNELS else "green"
    rgb = sources["main"]
    fg = build_foreground_mask(rgb, rows, cols, fill_bg_pockets=fill_bg_pockets,
                               protect_green=protect_green, chroma=chroma)
    rgb_u8 = np.clip(despill_ring(rgb, fg, chroma=chroma), 0, 255).astype(np.uint8)
    rgba = np.dstack([rgb_u8, fg.astype(np.uint8) * 255])
    return rgba, fg


def _square_canvas_rgba(rgba_u8):
    """Center a cropped RGBA item on a transparent square canvas (returns RGBA uint8)."""
    h, w = rgba_u8.shape[:2]
    s = max(h, w)
    canvas = np.zeros((s, s, 4), np.uint8)
    oy, ox = (s - h) // 2, (s - w) // 2
    canvas[oy:oy + h, ox:ox + w] = rgba_u8
    return canvas


def _downscale_premultiplied(rgba_u8, size):
    """Resize with premultiplied alpha so transparent (green) RGB never bleeds into the
    edges. Works for both down- and up-scaling. PIL's 'RGBa' mode is premultiplied;
    resizing in it and converting back to 'RGBA' un-premultiplies correctly."""
    img = Image.fromarray(rgba_u8, "RGBA").convert("RGBa")
    img = img.resize(size, Image.Resampling.LANCZOS)
    return img.convert("RGBA")


def _extract_cell(rgba_u8, fg, r, c, cell_h, cell_w, sprite_size):
    """Return a `sprite_size` RGBA sprite for grid cell (r, c), or None if it's empty."""
    y0, x0 = r * cell_h, c * cell_w
    cell_fg = fg[y0:y0 + cell_h, x0:x0 + cell_w]
    if cell_fg.mean() < EMPTY_COV:
        return None

    ys, xs = np.where(cell_fg)
    ymin, ymax = ys.min(), ys.max() + 1
    xmin, xmax = xs.min(), xs.max() + 1
    # Pad the tight bbox and clamp to the cell bounds.
    ymin, ymax = max(0, ymin - PADDING), min(cell_h, ymax + PADDING)
    xmin, xmax = max(0, xmin - PADDING), min(cell_w, xmax + PADDING)

    item_rgba = rgba_u8[y0 + ymin:y0 + ymax, x0 + xmin:x0 + xmax]
    canvas = _square_canvas_rgba(item_rgba)
    return _downscale_premultiplied(canvas, sprite_size)


def _isolate_masks(fg, rows, cols):
    """Group the foreground into per-cell item masks by connected-component centroid.

    Rigid grid slicing breaks when an item overflows its cell: a tall/large item crossing a
    grid line bleeds into the neighbour's sprite, and its own overflow gets clipped. Instead,
    label connected components on the WHOLE sheet and assign each to the cell its centroid
    lands in, so every item stays whole and no fragment leaks across a grid line. Returns
    {(r, c): bool mask over the full sheet}.
    """
    num, labels, stats, cent = cv2.connectedComponentsWithStats(
        fg.astype(np.uint8), connectivity=8)
    h, w = fg.shape
    cell_h, cell_w = h // rows, w // cols
    masks = {}
    for i in range(1, num):
        if stats[i, cv2.CC_STAT_AREA] < MIN_COMP_AREA:
            continue
        cx, cy = cent[i]
        r = min(rows - 1, int(cy // cell_h))
        c = min(cols - 1, int(cx // cell_w))
        m = masks.get((r, c))
        if m is None:
            m = np.zeros(fg.shape, bool)
            masks[(r, c)] = m
        m |= labels == i
    return masks


def _extract_cell_isolated(rgba_u8, mask, cell_area, sprite_size):
    """Like _extract_cell, but crop to a centroid-assigned component mask, not a grid cell.

    Pixels outside `mask` are forced transparent, so a padded bbox that happens to overlap a
    neighbour never leaks the neighbour's pixels in. Returns None if the cell has no item.
    """
    if mask is None or mask.sum() < EMPTY_COV * cell_area:
        return None
    ys, xs = np.where(mask)
    h, w = rgba_u8.shape[:2]
    ymin, ymax = max(0, ys.min() - PADDING), min(h, ys.max() + 1 + PADDING)
    xmin, xmax = max(0, xs.min() - PADDING), min(w, xs.max() + 1 + PADDING)
    crop = rgba_u8[ymin:ymax, xmin:xmax].copy()
    inside = mask[ymin:ymax, xmin:xmax]
    crop[..., 3] = np.where(inside, crop[..., 3], 0)
    canvas = _square_canvas_rgba(crop)
    return _downscale_premultiplied(canvas, sprite_size)


# Raster formats that store pixels losslessly. Anything else (notably JPEG) is
# re-encoded to PNG before processing.
LOSSLESS_FORMATS = {"PNG", "BMP", "TIFF", "TGA", "PPM", "PGM", "PBM"}


def ensure_png(sheet_path):
    """Guarantee the working source is a real, lossless PNG and return its path.

    Detects the file's ACTUAL decoded format (not just its extension). If it isn't a
    PNG, the pixels are re-saved as a PNG (in place when the path already ends in .png,
    e.g. a JPEG misnamed `.png`; otherwise next to the source).

    Note: this cannot undo compression artifacts already baked into a lossy source's
    pixels -- it only ensures a lossless working copy so no FURTHER quality is lost. For
    truly clean edges, re-export the sheet losslessly from the original art.
    """
    im = Image.open(sheet_path)
    fmt = (im.format or "").upper()
    if fmt == "PNG" and sheet_path.lower().endswith(".png"):
        im.close()
        return sheet_path

    # Copy pixels into a new image so we can close the source before overwriting it.
    converted = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
    im.close()

    png_path = os.path.splitext(sheet_path)[0] + ".png"
    converted.save(png_path, "PNG")

    if fmt in LOSSLESS_FORMATS:
        print(f"Source format is {fmt}; normalized to PNG -> {os.path.basename(png_path)}")
    else:
        # Lossy source (e.g. a JPEG -- even one misnamed .png): re-saving as a PNG
        # container CANNOT undo compression artifacts already baked into the pixels.
        # This is the usual cause of faintly translucent "solid" bodies in the dual
        # style, so make it impossible to miss.
        name = os.path.basename(sheet_path)
        print("  " + "!" * 72)
        print(f"  ! LOSSY SOURCE: {name} is actually {fmt or 'a non-PNG format'}, not a real PNG.")
        print(f"  ! Rewrote it as a true PNG -> {os.path.basename(png_path)}, but the {fmt or 'lossy'} compression")
        print( "  ! is ALREADY baked into the pixels and cannot be recovered by converting.")
        print( "  ! For clean dual-style alpha, re-export this render as a TRUE PNG from the")
        print( "  ! art/source tool -- the file must never have been saved as JPEG.")
        print("  " + "!" * 72)
    return png_path


def extract_sprites(sheet_path, output_dir, sprite_map=None, name_prefix=None,
                    rows=ROWS, cols=COLS, sprite_size=SPRITE_SIZE, overwrite=True,
                    style="green", black_path=None, isolate=None, fill_bg_pockets=False,
                    protect_green=False):
    """Slice `sheet_path` into per-item PNGs in `output_dir`.

    Naming is either explicit (`sprite_map`: {(row, col): name}) or automatic
    (`name_prefix`: non-empty cells are numbered gaplessly in row-major order, e.g.
    "item_3_01", "item_3_02", ...). `sprite_size` is the output px size per sprite.

    `style` picks how transparency is recovered: "green"/"blue"/"red" chroma-key that screen
    colour; "dual" difference-mattes this sheet (the white-bg render) against `black_path`
    (the black-bg render) to recover true partial alpha. See build_rgba / recover_alpha_dual.

    `isolate` groups each item by connected-component centroid instead of slicing strictly by
    grid cell, so items that overflow their cell stay whole and don't bleed into neighbours
    (see _isolate_masks). Defaults to on for "dual", off for "green" (which keeps the legacy
    grid behaviour). Pass True/False to force it.

    `fill_bg_pockets` (green style) removes large enclosed pockets that match the background
    colour -- trapped chroma inside loops/gaps that green-excess can't key when the chroma
    colour is close to a real sprite's colour. See remove_bg_pockets. Off by default.

    `protect_green` (green style) rescues a large green sprite the green key wrongly removed
    because its colour shares the green-screen hue (a green clover on a green screen). See
    protect_sprite_green. Off by default.
    """
    os.makedirs(output_dir, exist_ok=True)

    # When not overwriting in mapped mode, skip the whole sheet if every named target
    # already exists so we don't reprocess (or re-encode the source) for nothing.
    if sprite_map is not None and not overwrite:
        targets = [os.path.join(output_dir, f"{n}.png") for n in sprite_map.values()]
        if all(os.path.exists(p) for p in targets):
            print("All sprites for this sheet already exist; nothing to do.")
            return

    sheet_path = ensure_png(sheet_path)
    rgb = np.asarray(Image.open(sheet_path).convert("RGB"), dtype=np.int16)
    h, w = rgb.shape[:2]
    cell_h, cell_w = h // rows, w // cols
    print(f"Sheet {w}x{h}. Grid {cols}x{rows}. Cell {cell_w}x{cell_h}. "
          f"Output {sprite_size[0]}x{sprite_size[1]}. Style {style}.")

    if style == "dual":
        if not black_path:
            raise ValueError("style='dual' requires a black-background image (black_path).")
        black_path = ensure_png(black_path)
        black = np.asarray(Image.open(black_path).convert("RGB"), dtype=np.int16)
        if black.shape != rgb.shape:
            raise ValueError(
                f"White/black images must match in size: {(w, h)} vs "
                f"{(black.shape[1], black.shape[0])}.")
        # Be order-tolerant: the image with the brighter border is the white-bg render.
        if _border_mean(rgb) < _border_mean(black):
            print("White/black look swapped; using the brighter-border image as white.")
            rgb, black = black, rgb
        print("Recovering alpha from white+black pair...")
        rgba_u8, fg = build_rgba("dual", {"white": rgb, "black": black}, rows, cols)
    else:
        print("Building foreground matte...")
        rgba_u8, fg = build_rgba(style, {"main": rgb}, rows, cols,
                                 fill_bg_pockets=fill_bg_pockets, protect_green=protect_green)

    if isolate is None:
        isolate = (style == "dual")
    masks = _isolate_masks(fg, rows, cols) if isolate else None
    cell_area = cell_h * cell_w
    print(f"Item isolation (anti-bleed): {isolate}")

    if sprite_map is not None:
        cells = list(sprite_map.items())          # [((r, c), name), ...]
    else:
        cells = [((r, c), None) for r in range(rows) for c in range(cols)]

    counter = 0
    for (r, c), name in cells:
        # Mapped mode: name is known up front, so skip existing files before any work.
        if name is not None and not overwrite and \
                os.path.exists(os.path.join(output_dir, f"{name}.png")):
            print(f"Skipped (exists): {name}")
            continue

        if isolate:
            sprite = _extract_cell_isolated(rgba_u8, masks.get((r, c)), cell_area, sprite_size)
        else:
            sprite = _extract_cell(rgba_u8, fg, r, c, cell_h, cell_w, sprite_size)
        if sprite is None:
            print(f"Skipped (empty): {name if name else f'row {r}, col {c}'}")
            continue

        if name is None:                          # auto-name only the non-empty cells
            counter += 1
            name = f"{name_prefix}{counter:02d}"
            if not overwrite and os.path.exists(os.path.join(output_dir, f"{name}.png")):
                print(f"Skipped (exists): {name}")
                continue

        out_path = os.path.join(output_dir, f"{name}.png")
        sprite.save(out_path, "PNG")
        print(f"Saved: {out_path}")


# Per-sheet config. `map` gives explicit (row,col)->name; `prefix` instead auto-numbers
# non-empty cells. `rows`/`cols`/`size` default to 4/4/(64,64). Add new sheets here.
#
# For the white+black difference-matting style, add `"style": "dual"`, point `"file"` at the
# white-bg render and `"file_black"` at the black-bg render, e.g.:
#   {"file": "boss_white.png", "file_black": "boss_black.png", "style": "dual",
#    "prefix": "boss_", "rows": 2, "cols": 2, "size": (256, 256)},
SHEETS = [
    {"file": "item_icons_green.png", "map": SPRITE_MAP},
    {"file": "item_icons_2.png", "map": SPRITE_MAP_2},
    {"file": "item_icons_3.png", "prefix": "item_3_", "rows": 5, "cols": 5, "size": (256, 256)},
    {"file": "enemy_sprites.png", "prefix": "enemy_", "rows": 4, "cols": 4, "size": (256, 256)},
    {"file": "weapon_icons_test.png", "prefix": "weapon_", "rows": 3, "cols": 3, "size": (256, 256)},
    # retro_icon_02 is a four-leaf clover -- a GREEN sprite on the green screen. protect_green
    # keeps its inner leaf green (a different green from the bg) and only keys out the bg
    # around it; without it the green key removes the clover body. See protect_sprite_green.
    {"file": "retro_icon_sprites.png", "prefix": "retro_icon_", "rows": 4, "cols": 4,
     "size": (256, 256), "protect_green": True},
    # clover_sprites.png is two clovers (green + gold) on a BLUE screen -- blue was chosen so
    # the green clover keys cleanly (it is clearly not blue), no protect_green needed.
    {"file": "clover_sprites.png", "prefix": "clover_", "rows": 1, "cols": 2,
     "size": (256, 256), "style": "blue"},
]

def _run_sheet(sheet, script_dir, output_dir, overwrite):
    sheet_file = os.path.join(script_dir, sheet["file"])
    if not os.path.exists(sheet_file):
        print(f"Skipping {sheet['file']}: not found")
        return
    black_path = None
    if sheet.get("file_black"):
        black_path = os.path.join(script_dir, sheet["file_black"])
        if not os.path.exists(black_path):
            print(f"Skipping {sheet['file']}: black-bg pair {sheet['file_black']} not found")
            return
    print(f"\n=== Processing {sheet['file']} ===")
    extract_sprites(
        sheet_file, output_dir,
        sprite_map=sheet.get("map"), name_prefix=sheet.get("prefix"),
        rows=sheet.get("rows", 4), cols=sheet.get("cols", 4),
        sprite_size=sheet.get("size", (64, 64)), overwrite=overwrite,
        style=sheet.get("style", "green"), black_path=black_path,
        isolate=sheet.get("isolate"),
        fill_bg_pockets=sheet.get("fill_bg_pockets", False),
        protect_green=sheet.get("protect_green", False),
    )


def _dual_black_guess(white_name):
    """Guess the black-bg filename from the white-bg one (...white... -> ...black...)."""
    stem, ext = os.path.splitext(white_name)
    low = stem.lower()
    if "white" in low:
        i = low.index("white")
        return stem[:i] + "black" + stem[i + len("white"):] + ext
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Clean sprite sheets into the extracted/ folder. The default style "
                    "chroma-keys a green background; --style blue/red key those screens instead; "
                    "--style dual recovers true alpha from a white-bg + black-bg image pair.")
    parser.add_argument(
        "sheet", nargs="?",
        help="Sheet to (re)extract, e.g. enemy_sprites.png. For --style dual this is the "
             "white-background render. If omitted, every registered sheet is processed "
             "without replacing files that already exist.")
    parser.add_argument("--style", choices=("green", "blue", "red", "dual"), default=None,
                        help="Transparency method (default: green, or the registered sheet's). "
                             "green/blue/red pick the chroma screen colour; dual = white+black.")
    parser.add_argument("--black", metavar="FILE",
                        help="For --style dual: the matching black-background render.")
    parser.add_argument("--rows", type=int, help="Grid rows (override).")
    parser.add_argument("--cols", type=int, help="Grid cols (override).")
    parser.add_argument("--size", type=int, metavar="PX",
                        help="Output sprite size in px (square; override).")
    parser.add_argument("--prefix", help="Auto-name prefix for non-empty cells (override).")
    parser.add_argument("--isolate", dest="isolate", action="store_true", default=None,
                        help="Isolate each item by connected component so overflow doesn't "
                             "bleed across grid cells (default: on for dual, off for green).")
    parser.add_argument("--no-isolate", dest="isolate", action="store_false",
                        help="Disable item isolation; slice strictly by grid cell.")
    parser.add_argument("--fill-bg-pockets", dest="fill_bg_pockets", action="store_true",
                        help="Green style: remove large enclosed pockets that match the "
                             "background colour (trapped chroma inside loops/gaps). Use when the "
                             "chroma colour is close to a sprite's colour and green-excess leaks.")
    parser.add_argument("--keep-sprite-green", dest="protect_green", action="store_true",
                        help="Green style: rescue a large green sprite the key would remove "
                             "because it shares the green-screen hue (e.g. a green clover).")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_folder = os.path.join(script_dir, "extracted")

    if not args.sheet:
        # No file given: process all registered sheets without re-extracting existing files.
        for sheet in SHEETS:
            _run_sheet(sheet, script_dir, output_folder, overwrite=False)
        print("\nExtraction complete!")
        return

    # Single-file run. Start from a registered entry if one matches, then apply CLI overrides.
    wanted = os.path.basename(args.sheet)
    if not wanted.lower().endswith(".png"):
        wanted += ".png"
    match = next((s for s in SHEETS if s["file"].lower() == wanted.lower()), None)
    sheet = dict(match) if match else {"file": wanted}

    if args.style:
        sheet["style"] = args.style
    if args.black:
        sheet["file_black"] = os.path.basename(args.black)
    if args.rows:
        sheet["rows"] = args.rows
    if args.cols:
        sheet["cols"] = args.cols
    if args.size:
        sheet["size"] = (args.size, args.size)
    if args.prefix:
        sheet["prefix"] = args.prefix
    if args.isolate is not None:
        sheet["isolate"] = args.isolate
    if args.fill_bg_pockets:
        sheet["fill_bg_pockets"] = True
    if args.protect_green:
        sheet["protect_green"] = True

    # Dual needs a black-bg pair: use --black, else try a name convention (white -> black).
    if sheet.get("style") == "dual" and not sheet.get("file_black"):
        guess = _dual_black_guess(sheet["file"])
        if guess and os.path.exists(os.path.join(script_dir, guess)):
            sheet["file_black"] = guess
            print(f"Using black-bg pair by convention: {guess}")
        else:
            parser.error("--style dual requires --black FILE (or a *white*/*black* name pair).")

    # An unregistered file with no explicit naming gets a prefix from its stem.
    if not match and "map" not in sheet and "prefix" not in sheet:
        sheet["prefix"] = os.path.splitext(sheet["file"])[0] + "_"

    _run_sheet(sheet, script_dir, output_folder, overwrite=True)
    print("\nExtraction complete!")


if __name__ == "__main__":
    main()
