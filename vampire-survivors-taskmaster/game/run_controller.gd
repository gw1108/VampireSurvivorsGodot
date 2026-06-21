class_name RunController extends Node2D

## The composition root for one run. Owns GameState, gathers input, and drives
## every pure system in a fixed order each physics tick. UI layers listen to the
## three signals; they never touch GameState directly.
##
## Deviations from the task sketch (kept consistent with this codebase):
##  - defs are loaded BY PATH (_load_stage/_load_character/_load_weapon), NOT via
##    the GameData autoload: a `class_name` script cannot reference an autoload at
##    global-class registration time (same constraint SpawnDirector documents).
##  - starting enemies use SpawnDirector.spawn_starting() (the real public API,
##    which honours StageDef.starting_spawn_count) instead of the sketch's private
##    _spawn_wave_topup(state, waves[0]) loop.
##  - _create_player_from_def() (undefined in the sketch) builds the PlayerState
##    from the CharacterDef: starting weapon + StatSystem recompute/resolve, hp at
##    full, revivals seeded from the resolved Revival stat.
##  - game-over is surfaced: when HealthSystem flips the phase to GAME_OVER, the
##    tick emits run_ended (the sketch silently left the phase changed).
##  - the per-tick pipeline lives in _tick(delta, input_dir) so it can be driven
##    deterministically in tests without the Input singleton.

signal level_up_started(offer: LevelUpOffer)
signal run_ended(summary: Dictionary)
signal phase_changed(phase: int)

const POST_LEVELUP_IFRAMES: float = 0.5
const DEFAULT_STAGE_ID: String = "mad_forest"

var state: GameState = null
var _stage_def: StageDef = null
var _presentation: PresentationLayer = null  # optional view (Main.tscn: World/)
var _pause_screen: PauseScreen = null  # optional menu (Main.tscn: UI/)
var _main_menu: MainMenu = null  # optional title screen (Main.tscn: UI/)
var _camera: Camera2D = null  # optional follow-camera (Main.tscn: World/)
var _bg_material: ShaderMaterial = null  # optional scrolling background material
var _hud: HUD = null  # optional heads-up display (Main.tscn: UI/)


func _ready() -> void:
	_ensure_stage()
	_presentation = get_node_or_null("World/PresentationLayer") as PresentationLayer
	_camera = get_node_or_null("World/Camera2D") as Camera2D
	_hud = get_node_or_null("UI/HUD") as HUD
	var bg := get_node_or_null("Background/BackgroundRect") as CanvasItem
	if bg != null and bg.material is ShaderMaterial:
		_bg_material = bg.material
	_pause_screen = get_node_or_null("UI/PauseScreen") as PauseScreen
	if _pause_screen != null:
		_pause_screen.resume_requested.connect(_on_resume_requested)
		_pause_screen.quit_requested.connect(_on_quit_requested)
	_main_menu = get_node_or_null("UI/MainMenu") as MainMenu
	if _main_menu != null:
		_main_menu.start_game.connect(_on_start_requested)
		_main_menu.quit_game.connect(_on_quit_game)


func _physics_process(delta: float) -> void:
	if state == null or state.phase != GameState.Phase.PLAYING:
		return
	_tick(delta, _get_input_direction())


## Open the pause menu on the pause action (only while actively playing).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state != null and state.phase == GameState.Phase.PLAYING:
		_open_pause()


func _open_pause() -> void:
	_set_phase(GameState.Phase.PAUSED)
	if _pause_screen != null:
		_pause_screen.show_pause()


func _on_resume_requested() -> void:
	if state != null and state.phase == GameState.Phase.PAUSED:
		_set_phase(GameState.Phase.PLAYING)


## Quit from pause -> end the run (the results flow handles GAME_OVER).
func _on_quit_requested() -> void:
	if state == null:
		return
	_set_phase(GameState.Phase.GAME_OVER)
	run_ended.emit(_build_summary())


## Main menu Start -> begin a run and hide the title screen.
func _on_start_requested() -> void:
	start_run()
	if _main_menu != null:
		_main_menu.hide()


## Main menu Quit -> exit the application.
func _on_quit_game() -> void:
	get_tree().quit()


## Render step: mirror the current state onto the view every frame (runs in all
## phases so the frozen frame still renders during LEVEL_UP / GAME_OVER).
func _process(_delta: float) -> void:
	if state == null:
		return
	if _presentation != null:
		_presentation.sync(state)
	if _hud != null:
		_hud.update_from_state(state)
	_follow_camera(state.player.pos)


## Center the camera on the player and scroll the tiled background to match.
func _follow_camera(target: Vector2) -> void:
	if _camera != null:
		_camera.position = target
	if _bg_material != null:
		_bg_material.set_shader_parameter("camera_pos", target)


## The ordered system pipeline for one simulation step. Split out from
## _physics_process so tests can supply a synthetic input direction.
func _tick(delta: float, input_dir: Vector2) -> void:
	StatSystem.resolve(state.player, _stage_def)              # 2. stats
	MovementSystem.step_player(state.player, input_dir, delta)  # 3. player move
	SpawnDirector.step(state, _stage_def, delta)              # 4. spawning
	MovementSystem.step_enemies(state, delta)                 # 5. enemy move
	SpatialIndex.rebuild(state.index, state.enemies, state.gems, state.pickups)  # 6. index
	WeaponSystem.step(state, delta)                           # 7. weapons
	CombatSystem.step(state, delta)                           # 8. combat
	PickupSystem.step(state, delta)                           # 9. pickups
	HealthSystem.step(state, delta)                           # 10. health

	# 11. phase resolution — death takes precedence over a queued level-up.
	if state.phase == GameState.Phase.GAME_OVER:
		_end_run()
		return
	if state.pending_levelups > 0 and state.phase == GameState.Phase.PLAYING:
		state.current_offer = ProgressionSystem.build_offer(state)
		_set_phase(GameState.Phase.LEVEL_UP)
		level_up_started.emit(state.current_offer)


func _get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Begin a fresh run with the given character. Rebuilds GameState from scratch.
func start_run(character_id: String = "antonio") -> void:
	_ensure_stage()
	state = GameState.new()
	state.rng.seed = int(Time.get_ticks_usec())
	state.index = SpatialIndex.new()
	state.player = _create_player_from_def(_load_character(character_id))
	SpawnDirector.spawn_starting(state, _stage_def)
	_set_phase(GameState.Phase.PLAYING)


## UI calls this with the chosen level-up option index. Applies it, then either
## presents the next queued offer or resumes play with brief i-frames.
func on_option_chosen(index: int) -> void:
	if state == null:
		return
	ProgressionSystem.apply_choice(state, index)
	state.current_offer = null
	if state.pending_levelups > 0:
		state.current_offer = ProgressionSystem.build_offer(state)
		level_up_started.emit(state.current_offer)
	else:
		state.player.iframe_timer = POST_LEVELUP_IFRAMES
		_set_phase(GameState.Phase.PLAYING)


# --- internals ---

func _create_player_from_def(char_def) -> PlayerState:
	var p := PlayerState.new()
	p.character_def = char_def
	p.level = 1
	p.xp = 0.0
	p.xp_to_next = LevelCurve.xp_to_next(1)
	if char_def != null and char_def.starting_weapon_id != "":
		var wdef = _load_weapon(char_def.starting_weapon_id)
		if wdef != null:
			var w := WeaponInstance.new()
			w.def = wdef
			w.level = 1
			p.weapons.append(w)
	StatSystem.recompute_block(p, char_def)
	StatSystem.resolve(p, _stage_def)
	p.hp = p.derived.max_health  # start at full health
	p.revivals = int(p.derived.revival)
	return p


func _end_run() -> void:
	phase_changed.emit(GameState.Phase.GAME_OVER)  # HealthSystem set the phase directly
	run_ended.emit(_build_summary())


func _build_summary() -> Dictionary:
	return {
		"kills": state.kills,
		"gold": state.gold,
		"level": state.player.level,
		"time_survived": state.time_elapsed,
	}


func _set_phase(phase: int) -> void:
	state.phase = phase
	phase_changed.emit(phase)


func _ensure_stage() -> void:
	if _stage_def == null:
		_stage_def = _load_stage(DEFAULT_STAGE_ID)


func _load_stage(id: String) -> StageDef:
	return _load_def("res://data/stage_%s.tres" % id)


func _load_character(id: String):
	return _load_def("res://data/character_%s.tres" % id)


func _load_weapon(id: String):
	return _load_def("res://data/weapons/%s.tres" % id)


func _load_def(path: String):
	return load(path) if ResourceLoader.exists(path) else null
