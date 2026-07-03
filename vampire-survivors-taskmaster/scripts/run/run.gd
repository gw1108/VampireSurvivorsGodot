class_name VSRun
extends Node2D
## Main run controller for the Vampire Survivors vertical slice.
##
## Owns game state and builds the whole world IN CODE (no per-entity .tscn) so the
## slice stays robust to edit. It is the single source the AgentBridge adapter reads.
## Minimal but a real micro-loop: move, survive ramping waves, auto-attack, collect XP.
## Placeholder vector art for now — swapping in the SourceArt sprite packs is the
## obvious next step (see workshop/GOAL.md), and exactly what the playtest reviewer
## should flag.

var player: VSPlayer
var hud: VSHud
var adapter: Node
var upgrade_screen: VSUpgradeScreen
var _cam: Camera2D

# Camera screen-shake (trauma model). Impacts add trauma (0..1); it decays to 0 in
# ~0.2s and the per-frame offset scales with trauma^2 so a small hit reads as a subtle
# jolt, not nausea. Kept intentionally small — see FEEL-REVIEW's "no screen shake" note.
var _shake_trauma := 0.0
const SHAKE_DECAY := 5.0          # trauma/sec — full trauma dissipates in ~0.2s
const SHAKE_MAX_OFFSET := 14.0    # px of offset at trauma 1.0

var phase := "playing"          # playing | level_up | game_over  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0
var xp := 0
var level := 1
var frame_tick := 0
var arena_half := Vector2(900, 700)   # world half-extent around origin

# Run-level stats mutated by level-up upgrades. Weapon/projectile/player read these so
# a single pickup meaningfully changes how the run plays.
var player_speed_mult := 1.0
var weapon_damage := 2.0
var weapon_fire_interval := 0.6
var weapon_count := 1
var garlic_level := 0            # 0 = Garlic aura not yet chosen; each pick grows it
var whip_level := 0              # 0 = Whip melee arc not yet chosen; each pick grows it

var _pending_levels := 0        # level-ups queued but not yet chosen (XP can span several)

## Pool the level-up screen draws 3 distinct choices from each time.
const UPGRADE_POOL := [
	{"id": "damage", "title": "Power", "desc": "+1 weapon damage"},
	{"id": "firerate", "title": "Haste", "desc": "+15% fire rate"},
	{"id": "speed", "title": "Swift Boots", "desc": "+12% move speed"},
	{"id": "health", "title": "Vitality", "desc": "+20 max HP, heal 20"},
	{"id": "multishot", "title": "Multishot", "desc": "+1 projectile"},
	{"id": "garlic", "title": "Garlic", "desc": "Damaging aura around you (grows each pick)"},
	{"id": "whip", "title": "Whip", "desc": "Melee arc lashing your facing side; both sides at Lv 2+"},
]

func _ready() -> void:
	_ensure_input()
	seed(hash("vs-slice"))            # deterministic-ish; override via set_seed command
	_build_world()

func _ensure_input() -> void:
	# Register move actions at runtime so we don't hand-edit project.godot's [input]
	# block (fragile). Works for both human play and the harness's synthesized input.
	var defaults := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"upgrade_1": [KEY_1, KEY_KP_1],
		"upgrade_2": [KEY_2, KEY_KP_2],
		"upgrade_3": [KEY_3, KEY_KP_3],
	}
	for action in defaults.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in defaults[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)

func _build_world() -> void:
	_build_ground()

	player = VSPlayer.new()
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	add_child(player)

	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	# Zoom < 1 zooms the camera out, so the player and everything else read ~20% smaller.
	_cam.zoom = Vector2(0.8, 0.8)
	player.add_child(_cam)
	_cam.make_current()

	var weapon := VSWeapon.new()
	weapon.run = self
	player.add_child(weapon)

	# Second weapon: the Garlic aura. Inert until garlic_level > 0 (a level-up pick).
	# z_index below the player sprite so the aura reads as ground-level, under enemies.
	var garlic := VSGarlic.new()
	garlic.run = self
	garlic.z_index = -1
	player.add_child(garlic)

	# Third weapon: the Whip melee arc. Inert until whip_level > 0 (a level-up pick).
	# z_index above the player so the lash reads on top of enemies it sweeps.
	var whip := VSWhip.new()
	whip.run = self
	whip.z_index = 1
	player.add_child(whip)

	var spawner := VSSpawner.new()
	spawner.run = self
	add_child(spawner)

	hud = VSHud.new()
	add_child(hud)

	upgrade_screen = VSUpgradeScreen.new()
	upgrade_screen.picked.connect(_on_upgrade_picked)
	add_child(upgrade_screen)

	adapter = preload("res://scripts/agent/agent_adapter.gd").new()
	add_child(adapter)

## Repeating grass ground so the arena reads as a place — motion and position are
## legible against a textured field instead of flat gray (see FEEL-REVIEW). A single
## Sprite2D with region + texture-repeat tiles the 256px grass over the whole playfield
## (arena_half plus camera margin). Static at origin, deep z_index so it sits under all.
func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.texture = load("res://art/ground.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	# Cover arena_half (±900,700) plus the visible camera margin so no gray shows at the edges.
	var extent := Vector2(2400, 2000)
	ground.region_rect = Rect2(-extent, extent * 2.0)
	ground.z_index = -100
	ground.z_as_relative = false
	add_child(ground)

func _process(delta: float) -> void:
	frame_tick += 1
	if phase == "playing":
		elapsed += delta
	_update_shake(delta)
	if hud:
		hud.refresh(self)

## Decay the camera trauma and jitter the camera offset accordingly. Offset scales
## with trauma^2 so shake ramps down smoothly; snaps back to zero when trauma is spent.
func _update_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - SHAKE_DECAY * delta)
		var s := _shake_trauma * _shake_trauma
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * s
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

## Add a burst of camera trauma (0..1), capped at 1.0. Called on impacts.
func add_camera_shake(amount: float) -> void:
	_shake_trauma = minf(1.0, _shake_trauma + amount)

func _on_player_damaged(_amount: float) -> void:
	add_camera_shake(0.5)

func add_kill(at: Vector2, xp_value: int = 1, gem_count: int = 1) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	_spawn_gems(at, xp_value, gem_count)

## Split a kill's XP across `count` gems scattered in a ring. Elites drop a burst
## so the big payout reads as a jackpot; ordinary kills drop a single gem.
func _spawn_gems(at: Vector2, total_xp: int, count: int) -> void:
	count = maxi(count, 1)
	var base := total_xp / count
	var rem := total_xp % count
	for i in count:
		var v := base + (1 if i < rem else 0)
		var offset := Vector2.ZERO
		if count > 1:
			var ang := TAU * float(i) / float(count)
			offset = Vector2(cos(ang), sin(ang)) * 18.0
		_spawn_gem(at + offset, maxi(v, 1))

func _spawn_gem(at: Vector2, xp_value: int = 1) -> void:
	var g := VSGem.new()
	g.position = at
	g.run = self
	g.value = xp_value
	add_child(g)

func collect_xp(amount: int) -> void:
	if phase != "playing":
		return
	xp += amount
	var need := level * 5
	while xp >= need:
		xp -= need
		level += 1
		_pending_levels += 1
		AgentBridge.emit_event("level_up", {"level": level})
		need = level * 5
	if _pending_levels > 0:
		_open_level_up()

func _open_level_up() -> void:
	phase = "level_up"
	upgrade_screen.present(_roll_upgrades())

## Pick 3 distinct options from the pool (or the whole pool if it is smaller).
func _roll_upgrades() -> Array:
	var pool := UPGRADE_POOL.duplicate()
	pool.shuffle()
	return pool.slice(0, mini(3, pool.size()))

func _on_upgrade_picked(id: String) -> void:
	_apply_upgrade(id)
	_pending_levels -= 1
	if _pending_levels > 0:
		_open_level_up()
	else:
		phase = "playing"

func _apply_upgrade(id: String) -> void:
	match id:
		"damage":
			weapon_damage += 1.0
		"firerate":
			weapon_fire_interval = maxf(0.12, weapon_fire_interval * 0.85)
		"speed":
			player_speed_mult *= 1.12
		"health":
			if player:
				player.max_health += 20.0
				player.health = minf(player.max_health, player.health + 20.0)
		"multishot":
			weapon_count += 1
		"garlic":
			garlic_level += 1
		"whip":
			whip_level += 1
	AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})

func _on_player_died() -> void:
	if phase == "game_over":
		return
	phase = "game_over"
	AgentBridge.emit_event("death", {"type": "player"})

func _unhandled_input(event: InputEvent) -> void:
	if phase == "game_over" and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func reseed(value: int) -> void:
	seed(value)
