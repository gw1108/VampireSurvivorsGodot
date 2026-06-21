extends GdUnitTestSuite

## Tests HealthSystem: i-frame gating + countdown, armor mitigation (min 1),
## passive recovery (with max clamp), one-enemy-per-contact, combined-index
## filtering (gems ignored), revival, and the game-over death transition.

func _enemy(pos: Vector2, power: float) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = 100.0
	var d := EnemyDef.new()
	d.power = power
	e.def = d
	return e


func _gem(pos: Vector2) -> Gem:
	var g := Gem.new()
	g.pos = pos
	return g


func _rebuild(state: GameState) -> void:
	state.index = SpatialIndex.new()
	SpatialIndex.rebuild(state.index, state.enemies, state.gems, state.pickups)


# --- i-frames ---

func test_iframes_block_contact_damage() -> void:
	var gs := GameState.new()
	gs.player.iframe_timer = 0.5
	gs.enemies = [_enemy(gs.player.pos, 10.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(100.0)  # invulnerable -> no damage


func test_contact_damage_applies_and_sets_iframes() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(gs.player.pos, 10.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(90.0)
	assert_float(gs.player.iframe_timer).is_equal(HealthSystem.IFRAME_DURATION)


func test_iframe_timer_ticks_down() -> void:
	var gs := GameState.new()
	gs.player.iframe_timer = 0.5
	_rebuild(gs)  # no enemies
	HealthSystem.step(gs, 0.1)
	assert_float(gs.player.iframe_timer).is_equal(0.4)


# --- armor ---

func test_armor_reduces_damage() -> void:
	var gs := GameState.new()
	gs.player.derived.armor = 3.0
	gs.enemies = [_enemy(gs.player.pos, 10.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(93.0)  # 10 - 3


func test_armor_floors_damage_at_one() -> void:
	var gs := GameState.new()
	gs.player.derived.armor = 100.0
	gs.enemies = [_enemy(gs.player.pos, 5.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(99.0)  # min 1 damage despite huge armor


# --- recovery ---

func test_recovery_heals_over_time() -> void:
	var gs := GameState.new()
	gs.player.hp = 50.0
	gs.player.derived.recovery = 10.0
	_rebuild(gs)
	HealthSystem.step(gs, 0.1)
	assert_float(gs.player.hp).is_equal(51.0)  # 50 + 10*0.1


func test_recovery_clamped_to_max_health() -> void:
	var gs := GameState.new()
	gs.player.hp = 99.5
	gs.player.derived.recovery = 10.0
	gs.player.derived.max_health = 100.0
	_rebuild(gs)
	HealthSystem.step(gs, 0.1)  # +1 would overshoot to 100.5
	assert_float(gs.player.hp).is_equal(100.0)


func test_recovery_noop_at_full_health() -> void:
	var gs := GameState.new()
	gs.player.hp = 100.0
	gs.player.derived.recovery = 10.0
	_rebuild(gs)
	HealthSystem.step(gs, 0.1)
	assert_float(gs.player.hp).is_equal(100.0)


# --- contact selection ---

func test_only_one_enemy_deals_contact_damage() -> void:
	var gs := GameState.new()
	gs.enemies = [_enemy(gs.player.pos, 10.0), _enemy(gs.player.pos, 10.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(90.0)  # one hit, not two


func test_gem_in_hitbox_is_ignored() -> void:
	var gs := GameState.new()
	gs.gems = [_gem(gs.player.pos)]  # gem, no enemies
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(100.0)
	assert_float(gs.player.iframe_timer).is_equal(0.0)


func test_null_def_enemy_deals_no_damage() -> void:
	var gs := GameState.new()
	var e := Enemy.new()
	e.pos = gs.player.pos
	e.def = null
	gs.enemies = [e]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(100.0)


# --- death / revival ---

func test_revival_restores_half_health() -> void:
	var gs := GameState.new()
	gs.phase = GameState.Phase.PLAYING
	gs.player.hp = 0.0
	gs.player.revivals = 1
	gs.player.derived.max_health = 100.0
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_equal(50.0)
	assert_int(gs.player.revivals).is_equal(0)
	assert_float(gs.player.iframe_timer).is_equal(HealthSystem.REVIVE_IFRAME_DURATION)
	assert_int(gs.phase).is_equal(GameState.Phase.PLAYING)  # not game over


func test_death_without_revival_sets_game_over() -> void:
	var gs := GameState.new()
	gs.phase = GameState.Phase.PLAYING
	gs.player.hp = 0.0
	gs.player.revivals = 0
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_int(gs.phase).is_equal(GameState.Phase.GAME_OVER)


func test_contact_damage_can_trigger_game_over() -> void:
	var gs := GameState.new()
	gs.phase = GameState.Phase.PLAYING
	gs.player.hp = 5.0
	gs.player.revivals = 0
	gs.enemies = [_enemy(gs.player.pos, 10.0)]
	_rebuild(gs)
	HealthSystem.step(gs, 0.016)
	assert_float(gs.player.hp).is_less_equal(0.0)
	assert_int(gs.phase).is_equal(GameState.Phase.GAME_OVER)
