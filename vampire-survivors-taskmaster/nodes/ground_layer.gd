extends Sprite2D

## Mad Forest ground (Option A): one repeating grass quad that follows the active
## camera and offsets its texture region by the camera's world position. Because
## the region offset == the quad position, the texel sampled at any world point
## is constant regardless of where the camera is -- so the ground reads as
## world-fixed and seamless (the grass tile repeats via texture_repeat) while only
## ever drawing a SINGLE on-screen quad (nothing far off-screen is rendered).
##
## Pixel-perfect: the follow target snaps to whole pixels so NEAREST sampling
## (inherited from the project's default_texture_filter) never sub-samples. Runs
## with PROCESS_MODE_ALWAYS so the ground stays put while the run is paused.

## Quad / region size in pixels. Comfortably exceeds the 1445x900 viewport (zoom
## 1) with margin, so the player never reaches an edge between frames.
const COVER := 4096.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -100
	centered = true
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	region_enabled = true
	region_rect = Rect2(Vector2.ZERO, Vector2(COVER, COVER))
	_follow()

func _process(_delta: float) -> void:
	_follow()

## Snap the quad (and its texture sample origin) to the camera so it always
## covers the view; equal position + region offset keeps the grass world-locked.
func _follow() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var target := cam.global_position if cam != null else global_position
	var snapped := Vector2(roundf(target.x), roundf(target.y))
	position = snapped
	region_rect.position = snapped
