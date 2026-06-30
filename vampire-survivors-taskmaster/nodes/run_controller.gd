extends Node2D

## The run conductor: owns the authoritative per-frame tick. Each frame it gathers
## input, steps every PURE system over RunState in a fixed order, dispatches the
## collision outcomes (XP, consumable pickups, boss-drop chests, collected
## chests), ages timed effects, runs the death/level-up checks, then syncs the
## dumb view nodes. All game logic lives in the pure systems; this node only
## orchestrates and requests screen transitions through GameManager.
##
## Reconciliations with the task sketch:
##   * LevelingSystem.add_xp RETURNS the levels gained -> we add it to
##     run_state.level_up_queue (the queue lives on RunState, not PlayerState).
##   * A boss death SPAWNS a Treasure Chest pickup at the death spot; chests are
##     OPENED only when the player collects them (collision -> collected_chests).
##     The sketch opened on boss death directly and never dropped the pickup.
##   * process_mode = ALWAYS so _input can resume the game while the tree is
##     paused; _process still early-returns whenever state != PLAYING.

var run_state: RunState
var player_shell: Node2D
var view_sync: Node

@onready var game_manager := get_node("/root/GameManager")
@onready var game_db := get_node("/root/GameDatabase")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player_shell = $World/Player
	view_sync = $ViewSync
	run_state = game_manager.run_state
	if run_state == null:
		return  # opened without an active run (e.g. directly in the editor) -> inert
	player_shell.init(run_state.player)
	view_sync.init(run_state, game_db)

func _process(delta: float) -> void:
	if run_state == null:
		return
	if game_manager.current_state != game_manager.State.PLAYING:
		return
	_tick(delta)

## One authoritative simulation step over RunState.
func _tick(delta: float) -> void:
	var player: PlayerState = run_state.player

	# 1. gather input + publish the camera's world rect for spawn/cull
	player.vel = player_shell._gather_input()
	run_state.camera_world_rect = player_shell.get_camera_rect()

	# 2. recompute derived stats if the inventory/level changed
	if player.stats_dirty:
		StatSystem.recompute(player, game_db)

	# 3-7. step the pure systems in fixed order
	SpawnDirector.step(run_state, game_db, delta)
	SpatialIndex.rebuild(run_state.grid, run_state.enemies)
	MovementSystem.step(run_state, delta)
	WeaponSystem.step(run_state, game_db, delta)
	var result := CollisionSystem.resolve(run_state, game_db, delta)

	# 8. dispatch the collision outcomes
	_dispatch(result)

	# 9. age timed run-effects (freeze / fire-breath)
	EffectsSystem.tick_effects(run_state, delta)

	# 10. death takes precedence over a same-tick level-up
	if player.hp <= 0.0 and player.revival == 0:
		_fill_result()
		game_manager.game_over(run_state.result)
		return

	# 11. level-up -> hand off to the (auto-pausing) level-up screen
	if run_state.level_up_queue > 0:
		game_manager.open_level_up()
		return

	# 12. sync the view nodes from the freshly stepped state
	_sync_views()

func _dispatch(result) -> void:
	var enemies: EnemyPool = run_state.enemies
	var pickups: PickupPool = run_state.pickups

	if result.xp_gained > 0.0:
		run_state.level_up_queue += LevelingSystem.add_xp(run_state.player, game_db, result.xp_gained)

	for effect in result.collected_effects:
		EffectsSystem.apply_pickup(run_state, effect.kind, effect.value)

	# each boss death drops a chest the player can walk over
	for boss_idx in result.boss_deaths:
		pickups.spawn(PickupPool.Kind.CHEST, enemies.pos[boss_idx], 0.0)

	# each collected chest is opened now (auto-grants items + gold)
	for _seed in result.collected_chests:
		_show_chest_reveal(ChestSystem.open(run_state.player, run_state.spawn, game_db, run_state.rng))

func _fill_result() -> void:
	run_state.result.survival_time = run_state.elapsed
	run_state.result.final_level = run_state.player.level
	run_state.result.total_kills = run_state.player.kills
	run_state.result.total_gold = run_state.player.gold

func _sync_views() -> void:
	view_sync.sync_all()
	player_shell.render(run_state.player)

func _show_chest_reveal(_chest_result: Dictionary) -> void:
	pass  # non-blocking reveal overlay lands with the OverlayLayer task

func _input(event: InputEvent) -> void:
	if run_state == null:
		return
	if event.is_action_pressed("pause"):
		if game_manager.current_state == game_manager.State.PLAYING:
			game_manager.pause()
		elif game_manager.current_state == game_manager.State.PAUSED:
			game_manager.resume()
