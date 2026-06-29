extends SceneTree

## Headless test runner for the Task 9 SpawnDirector (pure logic).
##   godot --headless --path . --script res://test/spawn_director_test.gd
## Exit code == number of failed checks (0 == all passed).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== spawn_director_test ==")
	_test_minute_advance()
	_test_offscreen_pos()
	_test_periodic_quota_fill()
	_test_periodic_one_of_each_above_min()
	_test_periodic_hard_cap()
	_test_events_once_per_minute()
	_test_bosses_once_per_minute()
	_test_hp_per_level_scaling()
	_test_braziers()
	_test_cull()
	_test_reaper()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _make_state() -> RunState:
	var s := RunState.new()
	s.player = PlayerState.new()
	s.player.stats = StatBlock.new()  # curse 1.0
	s.enemies = EnemyPool.new()
	s.pickups = PickupPool.new()
	s.spawn = SpawnDirectorState.new()
	s.rng = RandomNumberGenerator.new()
	s.rng.seed = 7
	s.camera_world_rect = Rect2(-100, -100, 200, 200)
	return s

func _count_type(s: RunState, id: StringName) -> int:
	var n := 0
	for i in EnemyPool.CAPACITY:
		if s.enemies.alive[i] and s.enemies.type_id[i] == id:
			n += 1
	return n

func _test_minute_advance() -> void:
	var s := _make_state()
	SpawnDirector.step(s, GDB, 30.0)
	_check(s.spawn.minute == 0, "still minute 0 at 30s")
	SpawnDirector.step(s, GDB, 35.0)  # elapsed 65 -> minute 1
	_check(s.spawn.minute == 1, "minute advances to 1 past 60s")

func _test_offscreen_pos() -> void:
	var s := _make_state()
	for n in 20:
		var p := SpawnDirector._get_offscreen_spawn_pos(s)
		_check(not s.camera_world_rect.has_point(p), "spawn pos is outside the visible rect")

func _test_periodic_quota_fill() -> void:
	var s := _make_state()
	s.spawn.minute = 0  # wave 0: 15 zombies-ish, count 15
	s.spawn.periodic_timer = 0.0
	SpawnDirector._spawn_periodic(s, GDB, 0.1)
	_check(s.enemies.active_count == GDB.wave(0).count, "periodic fills to the minute quota (15)")

func _test_periodic_one_of_each_above_min() -> void:
	var s := _make_state()
	s.spawn.minute = 12  # 3 types [werewolf, ghost, skeleton], count 20
	# prefill to the quota so the next attempt takes the "one of each" branch
	var quota: int = GDB.wave(12).count
	for i in quota:
		s.enemies.spawn(&"zombie", Vector2(0, 0), GDB.enemy(&"zombie"))
	s.spawn.periodic_timer = 0.0
	var before: int = s.enemies.active_count
	SpawnDirector._spawn_periodic(s, GDB, 0.1)
	var types: int = GDB.wave(12).enemies.size()
	_check(s.enemies.active_count == before + types, "above minimum spawns one of each type (+3)")

func _test_periodic_hard_cap() -> void:
	var s := _make_state()
	s.spawn.minute = 11  # count 300
	s.spawn.periodic_timer = 0.0
	SpawnDirector._spawn_periodic(s, GDB, 0.1)
	_check(s.enemies.active_count == SpawnDirector.PERIODIC_CAP, "quota fill stops at PERIODIC_CAP (300)")
	# next call halts immediately (already at cap)
	s.spawn.periodic_timer = 0.0
	SpawnDirector._spawn_periodic(s, GDB, 0.1)
	_check(s.enemies.active_count == SpawnDirector.PERIODIC_CAP, "no periodic spawns past PERIODIC_CAP")

func _test_events_once_per_minute() -> void:
	var s := _make_state()
	s.spawn.minute = 2  # event = bat_swarm
	s.spawn.event_cursor = 1  # not yet processed minute 2
	SpawnDirector._spawn_events(s, GDB)
	_check(_count_type(s, &"bat_swarm") == SpawnDirector.SWARM_BATCH, "bat_swarm event spawns a batch")
	_check(s.spawn.event_cursor == 2, "event cursor advances to current minute")
	# fixed swarm enemies get a heading
	var found_vel := false
	for i in EnemyPool.CAPACITY:
		if s.enemies.alive[i] and s.enemies.type_id[i] == &"bat_swarm" and s.enemies.vel[i] != Vector2.ZERO:
			found_vel = true
			break
	_check(found_vel, "fixed swarm enemies are given a heading")
	# calling again same minute does not respawn
	var before: int = s.enemies.active_count
	SpawnDirector._spawn_events(s, GDB)
	_check(s.enemies.active_count == before, "event does not fire twice in the same minute")

func _test_bosses_once_per_minute() -> void:
	var s := _make_state()
	s.spawn.minute = 1  # boss = glowing_bat
	s.spawn.boss_cursor = 0
	SpawnDirector._spawn_bosses(s, GDB)
	_check(_count_type(s, &"glowing_bat") == 1, "minute-marker boss spawned")
	var boss_idx := -1
	for i in EnemyPool.CAPACITY:
		if s.enemies.alive[i] and s.enemies.type_id[i] == &"glowing_bat":
			boss_idx = i
			break
	_check(boss_idx >= 0 and s.enemies.is_boss[boss_idx], "boss flagged is_boss")
	SpawnDirector._spawn_bosses(s, GDB)
	_check(_count_type(s, &"glowing_bat") == 1, "boss not respawned same minute")

func _test_hp_per_level_scaling() -> void:
	var s := _make_state()
	s.player.level = 3
	var idx := SpawnDirector._spawn_enemy(s, GDB, &"glowing_bat", Vector2(0, 0))  # base hp 50, hp_per_level
	_check(is_equal_approx(s.enemies.hp[idx], 150.0), "boss hp scales with level (50*3)")
	_check(is_equal_approx(s.enemies.max_hp[idx], 150.0), "boss max_hp scales with level")
	# a non-scaling enemy is unaffected
	var z := SpawnDirector._spawn_enemy(s, GDB, &"zombie", Vector2(0, 0))  # hp 10, no flag
	_check(is_equal_approx(s.enemies.hp[z], 10.0), "non-scaling enemy keeps base hp")

func _test_braziers() -> void:
	var s := _make_state()
	# direct spawn: verify the synthetic brazier def
	var b := SpawnDirector._spawn_brazier(s, GDB, Vector2(0, 0))
	_check(s.enemies.type_id[b] == &"brazier", "brazier has brazier type id")
	_check(is_equal_approx(s.enemies.hp[b], GDB.BRAZIER_HP), "brazier hp from constant")
	_check(s.enemies.ai_kind[b] == EnemyPool.Ai.NONE, "brazier ai is none")
	# cap: prefill to BRAZIER_MAX, then an attempt adds none
	var s2 := _make_state()
	for i in GDB.BRAZIER_MAX:
		SpawnDirector._spawn_brazier(s2, GDB, Vector2(0, 0))
	s2.spawn.brazier_timer = 0.0
	SpawnDirector._spawn_braziers(s2, GDB, 0.1)
	_check(_count_type(s2, &"brazier") == GDB.BRAZIER_MAX, "braziers capped at BRAZIER_MAX")
	# cadence: brazier_timer resets after an attempt
	_check(is_equal_approx(s2.spawn.brazier_timer, GDB.BRAZIER_CADENCE), "brazier timer resets to cadence")

func _test_cull() -> void:
	var s := _make_state()  # rect [-100,-100,200,200], cull grows by 256 -> [-356..356]
	var far := Vector2(1000, 0)
	# fixed enemy far away -> culled
	var fixed_idx: int = s.enemies.spawn(&"bat_swarm", far, GDB.enemy(&"bat_swarm"))
	# homing enemy far away -> NOT culled (chases forever)
	var homing_idx: int = s.enemies.spawn(&"zombie", far, GDB.enemy(&"zombie"))
	# boss far away -> NOT culled
	var boss_idx: int = s.enemies.spawn(&"glowing_bat", far, GDB.enemy(&"glowing_bat"))
	# brazier far away -> NOT culled (ai none)
	var braz_idx := SpawnDirector._spawn_brazier(s, GDB, far)
	SpawnDirector._cull_distant_enemies(s)
	_check(not s.enemies.alive[fixed_idx], "distant fixed-direction enemy is culled")
	_check(s.enemies.alive[homing_idx], "distant homing enemy is NOT culled")
	_check(s.enemies.alive[boss_idx], "distant boss is NOT culled")
	_check(s.enemies.alive[braz_idx], "distant brazier is NOT culled")

func _test_reaper() -> void:
	var s := _make_state()
	s.player.level = 2
	# populate the field with normal enemies
	for i in 10:
		s.enemies.spawn(&"zombie", Vector2(0, 0), GDB.enemy(&"zombie"))
	s.elapsed = SpawnDirector.REAPER_TIME  # 30:00
	SpawnDirector.step(s, GDB, 0.1)
	_check(_count_type(s, &"zombie") == 0, "field cleared on Reaper spawn")
	_check(_count_type(s, &"reaper") == 1, "one Reaper spawned at 30:00")
	_check(is_equal_approx(s.spawn.reaper_timer, SpawnDirector.REAPER_RESPAWN), "reaper respawn timer set")
	# reaper hp scaled by level (655350 * 2)
	for i in EnemyPool.CAPACITY:
		if s.enemies.alive[i] and s.enemies.type_id[i] == &"reaper":
			_check(s.enemies.hp[i] > 655350.0, "reaper hp scaled by player level")
			break
	# a minute later, another Reaper spawns
	SpawnDirector.step(s, GDB, SpawnDirector.REAPER_RESPAWN)
	_check(_count_type(s, &"reaper") == 2, "an additional Reaper spawns each following minute")
