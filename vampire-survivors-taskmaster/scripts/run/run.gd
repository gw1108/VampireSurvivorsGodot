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

var phase := "playing"          # playing | game_over  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0
var xp := 0
var level := 1
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
	}
	for action in defaults.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in defaults[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)

func _build_world() -> void:
	player = VSPlayer.new()
	player.died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	cam.make_current()

	var weapon := VSWeapon.new()
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
	if hud:
		hud.refresh(self)

func add_kill(at: Vector2) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	_spawn_gem(at)

func _spawn_gem(at: Vector2) -> void:
	var g := VSGem.new()
	g.position = at
	g.run = self
	add_child(g)

func collect_xp(amount: int) -> void:
	xp += amount
	var need := level * 5
	if xp >= need:
		xp -= need
		level += 1
		AgentBridge.emit_event("level_up", {"level": level})

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
