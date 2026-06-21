extends GdUnitTestSuite

## Tests SpawnDirector: clock/minute, wave top-up + interval, cap enforcement,
## ring positioning, bosses, events, and the Reaper trigger (+1/min).

func _mad_forest() -> StageDef:
	return GameData.get_stage("mad_forest")


func _fresh_state() -> GameState:
	var gs := GameState.new()
	gs.rng.seed = 42
	return gs


func test_step_advances_clock_and_minute() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()
	SpawnDirector.step(gs, stage, 61.0)
	assert_float(gs.time_elapsed).is_equal_approx(61.0, 0.001)
	assert_int(gs.current_minute).is_equal(1)


func test_wave_topup_fires_on_interval() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()  # minute 0: min_alive 20, interval 1.5
	# Not enough time accumulated -> no spawns.
	SpawnDirector.step(gs, stage, 1.0)
	assert_int(gs.enemies.size()).is_equal(0)
	# Cross the interval -> top up to min_alive.
	SpawnDirector.step(gs, stage, 1.0)
	assert_int(gs.enemies.size()).is_equal(20)


func test_topup_respects_soft_cap() -> void:
	var gs := _fresh_state()
	var stage := StageDef.new()
	stage.waves = [{"minute": 0, "enemy_ids": ["bat"], "min_alive": 1000, "interval": 1.0}]
	stage.max_alive_soft = 300
	stage.max_alive_hard = 500
	stage.reaper_minute = 30
	SpawnDirector.step(gs, stage, 1.0)  # interval fires; min_alive 1000 but soft cap 300
	assert_int(gs.enemies.size()).is_equal(300)


func test_ring_position_within_bounds() -> void:
	var gs := _fresh_state()
	var center := Vector2(123, -45)
	for i in 20:
		var p := SpawnDirector._random_ring_pos(center, 400.0, 500.0, gs.rng)
		var d := center.distance_to(p)
		assert_bool(d >= 400.0 and d <= 500.0).is_true()


func test_starting_spawns() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()  # starting_spawn_count 10
	SpawnDirector.spawn_starting(gs, stage)
	assert_int(gs.enemies.size()).is_equal(10)


func test_boss_spawns_on_its_minute() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()  # boss giant_bat @ minute 8
	gs.current_minute = 7
	gs.time_elapsed = 8 * 60 - 0.1
	SpawnDirector.step(gs, stage, 0.2)  # cross into minute 8
	assert_int(gs.current_minute).is_equal(8)
	var giant_bats := 0
	for e in gs.enemies:
		if e.def != null and e.def.id == "giant_bat" and e.is_boss:
			giant_bats += 1
	assert_int(giant_bats).is_equal(1)


func test_event_spawns_swarm() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()  # bat_swarm @ minute 3, count 20
	gs.current_minute = 2
	gs.time_elapsed = 3 * 60 - 0.05
	SpawnDirector.step(gs, stage, 0.1)  # cross into minute 3 (interval 0.25 not reached)
	var swarm := 0
	for e in gs.enemies:
		if e.fixed_direction and e.floaty:
			swarm += 1
	assert_int(swarm).is_equal(20)


func test_reaper_clears_board_and_spawns_at_30() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()
	# Pre-populate the board with normal enemies.
	for i in 50:
		gs.enemies.append(Enemy.new())
	gs.current_minute = 29
	gs.time_elapsed = 30 * 60 - 0.1
	SpawnDirector.step(gs, stage, 0.2)  # cross into minute 30
	assert_int(gs.current_minute).is_equal(30)
	assert_int(gs.enemies.size()).is_equal(1)  # board cleared, one Reaper
	var reaper = gs.enemies[0]
	assert_str(reaper.def.id).is_equal("reaper")
	assert_float(reaper.hp).is_equal(655350.0)  # from the def, not 65535
	assert_bool(reaper.is_boss).is_true()


func test_reaper_plus_one_per_minute() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()
	gs.current_minute = 30
	gs.enemies.append(SpawnDirector._create_enemy(gs, "reaper"))  # the first reaper
	gs.time_elapsed = 31 * 60 - 0.1
	SpawnDirector.step(gs, stage, 0.2)  # cross into minute 31
	assert_int(gs.current_minute).is_equal(31)
	assert_int(gs.enemies.size()).is_equal(2)  # +1 reaper, board NOT cleared


func test_no_normal_topup_after_reaper() -> void:
	var gs := _fresh_state()
	var stage := _mad_forest()
	gs.current_minute = 31
	SpawnDirector.step(gs, stage, 10.0)  # would normally spawn a wave
	assert_int(gs.enemies.size()).is_equal(0)  # reaper-only phase: no top-ups
