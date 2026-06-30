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

## Upgrade pool. On each level-up 3 of these are offered (so one is always left out —
## a real choice). Keys are matched in apply_upgrade(); titles/descs feed the picker UI.
const UPGRADES := [
	{"key": "damage", "title": "Power", "desc": "+1 projectile damage"},
	{"key": "firerate", "title": "Haste", "desc": "Fire 15% faster"},
	{"key": "speed", "title": "Swift", "desc": "+12% move speed"},
	{"key": "projectile", "title": "Multishot", "desc": "+1 projectile"},
	{"key": "garlic", "title": "Garlic", "desc": "Damaging aura around you"},
	{"key": "orbit", "title": "Blades", "desc": "Spinning blades that cut nearby foes"},
]

var player: VSPlayer
var weapon: VSWeapon
var aura: VSAura
var orbit: VSOrbit
var hud: VSHud
var adapter: Node
var camera: Camera2D
var _levelup_screen: VSLevelUpScreen

# Screen shake: a decaying camera offset, kicked by add_shake() (e.g. on player damage).
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_mag := 0.0

var phase := "playing"          # playing | level_up | game_over  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0
var xp := 0
var level := 1
var upgrade_levels := {}        # upgrade key -> times chosen; drives the HUD loadout readout
var frame_tick := 0
var arena_half := Vector2(900, 700)   # world half-extent around origin

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
		"choose_1": [KEY_1, KEY_KP_1],
		"choose_2": [KEY_2, KEY_KP_2],
		"choose_3": [KEY_3, KEY_KP_3],
	}
	for action in defaults.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in defaults[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)

func _build_world() -> void:
	var ground := VSGround.new()
	ground.arena_half = arena_half     # lay the tiled floor down first, beneath everything
	add_child(ground)

	player = VSPlayer.new()
	player.died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()
	camera = cam

	weapon = VSWeapon.new()
	weapon.run = self
	player.add_child(weapon)

	var spawner := VSSpawner.new()
	spawner.run = self
	add_child(spawner)

	hud = VSHud.new()
	add_child(hud)

	adapter = preload("res://scripts/agent/agent_adapter.gd").new()
	add_child(adapter)

func _process(delta: float) -> void:
	frame_tick += 1
	if phase == "playing":
		elapsed += delta
	_update_shake(delta)
	if hud:
		hud.refresh(self)

func add_shake(magnitude: float, duration: float) -> void:
	# Kick a screen shake; the strongest/longest pending kick wins (no stacking blowups).
	_shake_mag = maxf(_shake_mag, magnitude)
	_shake_dur = maxf(_shake_dur, duration)
	_shake_t = maxf(_shake_t, duration)

func _update_shake(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _shake_t <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_mag = 0.0
		return
	_shake_t -= delta
	var amt := _shake_mag * (_shake_t / _shake_dur)   # linear decay to 0
	camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))

func add_kill(at: Vector2, xp_value: int = 1) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	_spawn_gem(at, xp_value)

func _spawn_gem(at: Vector2, xp_value: int = 1) -> void:
	var g := VSGem.new()
	g.position = at
	g.xp_value = xp_value
	g.run = self
	add_child(g)

func collect_xp(amount: int) -> void:
	xp += amount
	AgentBridge.emit_event("sfx_played", {"name": "pickup"})
	Sfx.play("pickup")
	_check_level_up()

func _check_level_up() -> void:
	# Only fires while playing; the upgrade picker freezes the run until a choice is made.
	# Re-checked after each choice so a multi-level XP burst chains pickers instead of
	# silently swallowing levels.
	if phase != "playing":
		return
	var need := level * 5
	if xp >= need:
		xp -= need
		level += 1
		AgentBridge.emit_event("level_up", {"level": level})
		_show_level_up()

func _show_level_up() -> void:
	phase = "level_up"
	Sfx.duck_music(true)   # drop the ambient bed so the level-up arpeggio pops; restored on resume
	AgentBridge.emit_event("sfx_played", {"name": "levelup"})
	Sfx.play("levelup")
	var options := _roll_upgrades()
	var screen := VSLevelUpScreen.new()
	screen.setup(options, upgrade_levels)
	screen.chosen.connect(_on_upgrade_chosen)
	add_child(screen)
	_levelup_screen = screen
	AgentBridge.emit_event("level_up_choice", {"options": options})

func _roll_upgrades() -> Array:
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	return pool.slice(0, 3)

func _on_upgrade_chosen(key: String) -> void:
	apply_upgrade(key)
	upgrade_levels[key] = int(upgrade_levels.get(key, 0)) + 1
	if hud:
		hud.refresh_loadout(self)   # rebuild the corner readout only when the build changes
	if _levelup_screen and is_instance_valid(_levelup_screen):
		_levelup_screen.queue_free()
	_levelup_screen = null
	phase = "playing"
	Sfx.duck_music(false)   # modal closed: bring the ambient bed back up
	AgentBridge.emit_event("upgrade_chosen", {"key": key})
	_check_level_up()   # chain if the XP burst was worth more than one level (re-ducks if so)

func apply_upgrade(key: String) -> void:
	match key:
		"damage":
			if weapon:
				weapon.damage += 1.0
		"firerate":
			if weapon:
				weapon.fire_interval = maxf(0.12, weapon.fire_interval * 0.85)
		"speed":
			if player:
				player.speed *= 1.12
		"projectile":
			if weapon:
				weapon.projectile_count += 1
		"garlic":
			# First pick spawns the halo (child of the player so it follows); repeats level it.
			if player:
				if aura == null or not is_instance_valid(aura):
					aura = VSAura.new()
					aura.run = self
					player.add_child(aura)
				aura.level_up()
		"orbit":
			# First pick spawns the spinning ring (child of the player so it follows); repeats level it.
			if player:
				if orbit == null or not is_instance_valid(orbit):
					orbit = VSOrbit.new()
					orbit.run = self
					player.add_child(orbit)
				orbit.level_up()

func _on_player_died() -> void:
	if phase == "game_over":
		return
	phase = "game_over"
	AgentBridge.emit_event("death", {"type": "player"})
	# A distinct descending stinger so the run's end lands (the lethal hit only played "hurt").
	AgentBridge.emit_event("sfx_played", {"name": "gameover"})
	Sfx.play("gameover")

func _unhandled_input(event: InputEvent) -> void:
	if phase == "game_over" and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func reseed(value: int) -> void:
	seed(value)
