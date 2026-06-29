extends Node2D

## Bridges engine input/rendering and PlayerState. Owns only engine I/O (the
## input device, sprite/health-bar nodes, and the camera); all gameplay state
## lives in PlayerState. The RunController calls _gather_input()/get_camera_rect()
## before the tick and render() after it. State note: gameplay state stays in
## PlayerState, not here.

var player_state: PlayerState

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var camera: Camera2D = $Camera2D

const CAMERA_ZOOM := 2          # integer zoom for pixel-perfect rendering
const INPUT_DEADZONE := 0.1

func _ready() -> void:
	if camera:
		camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)

func init(state: PlayerState) -> void:
	player_state = state
	position = state.pos

## 8-directional move intent from the keyboard (WASD / arrows).
func _gather_input() -> Vector2:
	return snap_to_8(Input.get_vector("move_left", "move_right", "move_up", "move_down"))

## Snap an analog vector to one of 8 unit directions. Pure + deadzoned: below the
## deadzone returns Vector2.ZERO, otherwise a unit vector on the nearest 45°.
static func snap_to_8(input: Vector2) -> Vector2:
	if input.length() <= INPUT_DEADZONE:
		return Vector2.ZERO
	return Vector2.from_angle(snappedf(input.angle(), PI / 4.0))

## Visible world rect of the camera (viewport size / zoom, centered on the
## player). The SpawnDirector reads this for off-screen spawning and culling.
func get_camera_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var world_size := viewport_size / Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	return Rect2(position - world_size * 0.5, world_size)

## Sync the visual node from PlayerState (called after the tick).
func render(state: PlayerState) -> void:
	position = state.pos
	if sprite:
		if state.facing.x < 0.0:
			sprite.flip_h = true
		elif state.facing.x > 0.0:
			sprite.flip_h = false
		var anim := "walk" if state.vel.length() > INPUT_DEADZONE else "idle"
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
			sprite.play(anim)
		# i-frame flash
		if state.iframe_timer > 0.0:
			sprite.modulate.a = 0.5 + 0.5 * sin(state.iframe_timer * 30.0)
		else:
			sprite.modulate.a = 1.0
	if health_bar:
		if state.max_hp > 0.0:
			health_bar.value = state.hp / state.max_hp * 100.0
		health_bar.visible = state.hp < state.max_hp
