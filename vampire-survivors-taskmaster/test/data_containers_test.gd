extends SceneTree

## Headless test runner for the Task 1 plain-data containers.
## No test framework required: run with
##   godot --headless --path . --script res://test/data_containers_test.gd
## Exit code == number of failed checks (0 == all passed).

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== data_containers_test ==")
	_test_run_result()
	_test_passive_instance()
	_test_weapon_instance()
	_test_stat_block_defaults()
	_test_stat_block_clamp()
	_test_player_state()
	_test_run_state_graph()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_run_result() -> void:
	var r := RunResult.new()
	_check(r.survival_time == 0.0, "RunResult.survival_time default 0")
	_check(r.final_level == 1, "RunResult.final_level default 1")
	_check(r.total_kills == 0, "RunResult.total_kills default 0")
	_check(r.total_gold == 0, "RunResult.total_gold default 0")

func _test_passive_instance() -> void:
	var p := PassiveInstance.new()
	_check(p.id == &"", "PassiveInstance.id default empty StringName")
	_check(p.level == 1, "PassiveInstance.level default 1")

func _test_weapon_instance() -> void:
	var w := WeaponInstance.new()
	_check(w.id == &"", "WeaponInstance.id default empty StringName")
	_check(w.level == 1, "WeaponInstance.level default 1")
	_check(w.cooldown_timer == 0.0, "WeaponInstance.cooldown_timer default 0")
	_check(w.runtime is Dictionary and w.runtime.is_empty(), "WeaponInstance.runtime default empty Dictionary")
	# distinct instances must not share the runtime Dictionary
	var w2 := WeaponInstance.new()
	w.runtime["k"] = 1
	_check(w2.runtime.is_empty(), "WeaponInstance.runtime not shared across instances")

func _test_stat_block_defaults() -> void:
	var s := StatBlock.new()
	# additive baseline 0
	_check(s.max_health == 0.0, "StatBlock.max_health default 0")
	_check(s.recovery == 0.0, "StatBlock.recovery default 0")
	_check(s.armor == 0.0, "StatBlock.armor default 0")
	_check(s.amount == 0.0, "StatBlock.amount default 0")
	# multiplier baseline 1.0
	_check(s.might == 1.0, "StatBlock.might default 1.0")
	_check(s.area == 1.0, "StatBlock.area default 1.0")
	_check(s.speed == 1.0, "StatBlock.speed default 1.0")
	_check(s.duration == 1.0, "StatBlock.duration default 1.0")
	_check(s.cooldown == 1.0, "StatBlock.cooldown default 1.0")
	_check(s.move_speed == 1.0, "StatBlock.move_speed default 1.0")
	_check(s.magnet == 1.0, "StatBlock.magnet default 1.0")
	_check(s.luck == 1.0, "StatBlock.luck default 1.0")
	_check(s.growth == 1.0, "StatBlock.growth default 1.0")
	_check(s.greed == 1.0, "StatBlock.greed default 1.0")
	_check(s.curse == 1.0, "StatBlock.curse default 1.0")

func _test_stat_block_clamp() -> void:
	var s := StatBlock.new()
	s.might = 999.0
	s.cooldown = 0.0
	s.amount = 50.0
	s.armor = -5.0
	s.area = -1.0
	s.clamp_all()
	_check(s.might == StatBlock.MIGHT_MAX, "clamp_all caps might at MIGHT_MAX")
	_check(s.cooldown == StatBlock.COOLDOWN_MIN, "clamp_all floors cooldown at COOLDOWN_MIN")
	_check(s.amount == float(StatBlock.AMOUNT_MAX), "clamp_all caps amount at AMOUNT_MAX")
	_check(s.armor == 0.0, "clamp_all floors armor at 0")
	_check(s.area == 0.0, "clamp_all floors area at 0")

func _test_player_state() -> void:
	var p := PlayerState.new()
	_check(p.hp == 120.0, "PlayerState.hp default 120")
	_check(p.max_hp == 120.0, "PlayerState.max_hp default 120")
	_check(p.facing == Vector2.RIGHT, "PlayerState.facing default RIGHT")
	_check(p.level == 1, "PlayerState.level default 1")
	_check(p.xp == 0.0, "PlayerState.xp default 0")
	_check(p.xp_to_next == 5.0, "PlayerState.xp_to_next default 5")
	_check(p.stats_dirty == true, "PlayerState.stats_dirty default true")
	_check(p.weapons is Array and p.weapons.is_empty(), "PlayerState.weapons default empty")
	_check(p.passives is Array and p.passives.is_empty(), "PlayerState.passives default empty")
	_check(p.stats == null, "PlayerState.stats null until StatSystem populates it")
	# typed arrays accept the right element type
	p.weapons.append(WeaponInstance.new())
	p.passives.append(PassiveInstance.new())
	_check(p.weapons.size() == 1 and p.passives.size() == 1, "PlayerState typed arrays accept instances")
	# distinct players must not share the weapons array
	var p2 := PlayerState.new()
	_check(p2.weapons.is_empty(), "PlayerState.weapons not shared across instances")

func _test_run_state_graph() -> void:
	var st := RunState.new()
	_check(st.phase == RunState.Phase.PLAYING, "RunState.phase default PLAYING")
	_check(st.elapsed == 0.0, "RunState.elapsed default 0")
	_check(st.level_up_queue == 0, "RunState.level_up_queue default 0")
	_check(st.freeze_timer == 0.0, "RunState.freeze_timer default 0")
	_check(st.firebreath_timer == 0.0, "RunState.firebreath_timer default 0")
	# graph wiring works
	st.player = PlayerState.new()
	st.result = RunResult.new()
	st.rng = RandomNumberGenerator.new()
	st.camera_world_rect = Rect2(0, 0, 320, 180)
	_check(st.player is PlayerState, "RunState.player accepts PlayerState")
	_check(st.result is RunResult, "RunState.result accepts RunResult")
	_check(st.rng is RandomNumberGenerator, "RunState.rng accepts RandomNumberGenerator")
	_check(st.camera_world_rect.size == Vector2(320, 180), "RunState.camera_world_rect stores Rect2")
	# forward-referenced pool fields exist and default to null
	_check(st.enemies == null and st.projectiles == null and st.pickups == null, "RunState pool fields default null")
	_check(st.grid == null and st.spawn == null and st.floaters == null, "RunState grid/spawn/floaters default null")
