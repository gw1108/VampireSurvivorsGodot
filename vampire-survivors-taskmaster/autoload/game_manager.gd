extends Node

## Top-level screen state machine + run lifecycle (autoload `GameManager`).
## Owns the FSM Menu -> Playing <-> Paused -> LevelUp -> GameOver, creates and
## destroys the RunState graph, and drives get_tree().paused. Runs with
## PROCESS_MODE_ALWAYS so it keeps working while the sim is frozen by pause.

enum State { MENU, PLAYING, PAUSED, LEVEL_UP, GAME_OVER }

signal state_changed(new_state: State)
signal run_started(run_state: RunState)
signal level_up_requested()
signal game_over_triggered(result: RunResult)

const RUN_SCENE := "res://scenes/run.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

var current_state: State = State.MENU
var run_state: RunState = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Build a fresh RunState with Antonio's starting kit (Whip; 120 HP) and empty
## pools, then enter Playing and load the run scene.
func start_run() -> void:
	run_state = _build_run_state()
	current_state = State.PLAYING
	get_tree().paused = false
	run_started.emit(run_state)
	state_changed.emit(current_state)
	_change_scene(RUN_SCENE)

## Assemble the RunState graph (Antonio kit, empty pools, seeded RNG). Split out
## from start_run so it can be built/inspected without the scene side effect.
func _build_run_state() -> RunState:
	var rs := RunState.new()
	rs.player = PlayerState.new()
	rs.player.pos = Vector2.ZERO
	rs.player.hp = 120.0
	rs.player.max_hp = 120.0
	var whip := WeaponInstance.new()
	whip.id = &"whip"
	whip.level = 1
	rs.player.weapons.append(whip)
	rs.enemies = EnemyPool.new()
	rs.projectiles = ProjectilePool.new()
	rs.pickups = PickupPool.new()
	rs.floaters = FloatingTextPool.new()
	rs.grid = SpatialGrid.new()
	rs.spawn = SpawnDirectorState.new()
	rs.rng = RandomNumberGenerator.new()
	rs.rng.randomize()
	rs.result = RunResult.new()
	rs.phase = RunState.Phase.PLAYING
	return rs

func pause() -> void:
	if current_state != State.PLAYING:
		return
	current_state = State.PAUSED
	get_tree().paused = true
	state_changed.emit(current_state)

func resume() -> void:
	if current_state != State.PAUSED:
		return
	current_state = State.PLAYING
	get_tree().paused = false
	state_changed.emit(current_state)

func open_level_up() -> void:
	if current_state != State.PLAYING:
		return
	current_state = State.LEVEL_UP
	get_tree().paused = true
	level_up_requested.emit()
	state_changed.emit(current_state)

## Called when one level-up choice resolves. Drains the queue one at a time:
## if more are pending, re-request the next; otherwise resume Playing.
func close_level_up() -> void:
	if current_state != State.LEVEL_UP:
		return
	if run_state != null:
		run_state.level_up_queue -= 1
	if run_state != null and run_state.level_up_queue > 0:
		level_up_requested.emit()
	else:
		current_state = State.PLAYING
		get_tree().paused = false
		state_changed.emit(current_state)

func game_over(result: RunResult) -> void:
	current_state = State.GAME_OVER
	if run_state != null:
		run_state.result = result
	get_tree().paused = true
	game_over_triggered.emit(result)
	state_changed.emit(current_state)

func to_menu() -> void:
	run_state = null
	current_state = State.MENU
	get_tree().paused = false
	state_changed.emit(current_state)
	_change_scene(MENU_SCENE)

func restart() -> void:
	to_menu()
	start_run()

## Change scene only if the target exists. Until the scene tasks land the scene
## files are absent, so this is a safe no-op (the FSM still drives state),
## and it works unchanged once the scenes are added.
func _change_scene(path: String) -> void:
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("GameManager: scene not found yet, skipping change: %s" % path)
