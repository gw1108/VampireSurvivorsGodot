class_name VSReaperVignette
extends CanvasLayer
## One-shot crimson vignette that flashes inward from the screen edges when the
## Reaper is summoned. The Reaper spawns off-screen on the far ring, so its arrival
## needs a screen-space cue to read as an event (matching the HUD 'THE REAPER COMES'
## banner) rather than a silent pop-in. Purely cosmetic: self-frees, no gameplay state.

const RISE := 0.15        # seconds to flash up to peak
const FADE := 1.1         # seconds to bleed back out
const PEAK_ALPHA := 0.55  # how solid the crimson edge gets at its height

## Flash a Reaper-arrival vignette over the whole screen, parented to `parent`.
static func spawn(parent: Node) -> void:
	parent.add_child(VSReaperVignette.new())

func _ready() -> void:
	layer = 5   # over the world, under the default-layer HUD banner
	var rect := TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture = _make_vignette()
	rect.modulate.a = 0.0
	add_child(rect)
	# Snap in, then bleed out and self-free so nothing lingers past the arrival beat.
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", PEAK_ALPHA, RISE)
	tw.tween_property(rect, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)

## Radial gradient: transparent through the centre, ramping to solid crimson at the
## edges so only the screen border reddens and the play area stays readable.
func _make_vignette() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.5, 1.0])
	grad.colors = PackedColorArray([Color(0.85, 0.02, 0.05, 0.0), Color(0.85, 0.02, 0.05, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex
