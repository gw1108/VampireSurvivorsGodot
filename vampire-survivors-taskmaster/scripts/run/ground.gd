class_name VSGround
extends Node2D
## The trampled field the night keeps reclaiming.
##
## Bare dirt paths worn through the grass mark where the countless survivors who
## came before walked, fled, and fell — the arena remembers every run. Mechanically
## this is just a tiled floor laid beneath the whole world: it gives the eye fixed
## landmarks so the player can read their own motion and position against a moving
## camera (FEEL-REVIEW flagged the empty flat-gray arena). Static — drawn once, far
## below everything; the camera simply pans across the ground as the run unfolds.

const TILE := preload("res://art/ground.png")
const MARGIN := Vector2(800, 640)   # tile a full viewport past the arena so the raw outer edge never shows
const DUSK := Color(0.72, 0.74, 0.80)   # dim + faintly cool: the field sits under nightfall so foreground pops

# The field's edge — where movement is clamped (VSPlayer / VSRun.arena_half). Past it the night
# reclaims the ground, so the playable rectangle reads instead of ending in an invisible wall.
const NIGHT := Color(0.0, 0.0, 0.02)        # the dark the field fades into beyond the rim
const RIM := Color(0.13, 0.10, 0.06, 0.9)   # worn-dirt shadow line tracing the exact clamp boundary
const RIM_WIDTH := 3.0
const VIGNETTE_BAND := 220.0                 # px the night creeps inward toward the rim
const VIGNETTE_STEPS := 6                    # stacked rings → a stepped (pixel-friendly) falloff, not a smooth gradient
const VIGNETTE_STEP_ALPHA := 0.2            # per ring; ~0.74 darkening accumulates at the outer edge

var arena_half := Vector2(900, 700)   # set by VSRun to match its world extent

func _ready() -> void:
	z_index = -100                                       # beneath player, enemies, gems, projectiles, VFX
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # required for draw_texture_rect(..., tile=true)

func _draw() -> void:
	# Snap the covered area up to whole tiles so the repeat stays phase-aligned and seam-free at the edges.
	var tile := TILE.get_size()
	var outer := arena_half + MARGIN
	outer.x = ceilf(outer.x / tile.x) * tile.x
	outer.y = ceilf(outer.y / tile.y) * tile.y
	draw_texture_rect(TILE, Rect2(-outer, outer * 2.0), true, DUSK)

	# Night reclaims everything past the playable rectangle: stack translucent rings that deepen the
	# dark from the rim outward, so the field's edge reads as a soft falloff into night, not a hard line.
	for i in VIGNETTE_STEPS:
		var inner := arena_half + Vector2.ONE * (VIGNETTE_BAND * float(i) / float(VIGNETTE_STEPS))
		_draw_ring(inner, outer, Color(NIGHT.r, NIGHT.g, NIGHT.b, VIGNETTE_STEP_ALPHA))

	# A worn-dirt rim traces the exact clamp boundary so the edge stays unambiguous up close.
	draw_rect(Rect2(-arena_half, arena_half * 2.0), RIM, false, RIM_WIDTH)

func _draw_ring(inner: Vector2, outer: Vector2, color: Color) -> void:
	# The rectangular band between an inner and outer half-extent (both centered on origin), drawn as
	# four non-overlapping rects so the inner playable rectangle is left untouched.
	var band_h := outer.y - inner.y
	draw_rect(Rect2(-outer, Vector2(outer.x * 2.0, band_h)), color)                                  # top
	draw_rect(Rect2(Vector2(-outer.x, inner.y), Vector2(outer.x * 2.0, band_h)), color)              # bottom
	draw_rect(Rect2(Vector2(-outer.x, -inner.y), Vector2(outer.x - inner.x, inner.y * 2.0)), color)  # left
	draw_rect(Rect2(Vector2(inner.x, -inner.y), Vector2(outer.x - inner.x, inner.y * 2.0)), color)   # right
