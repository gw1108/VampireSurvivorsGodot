extends GdUnitTestSuite

## Loads and validates the Mad Forest stage + its enemy roster against wiki specs.

const STAGE_PATH := "res://data/stage_mad_forest.tres"
const ENEMY_DIR := "res://data/enemies/"


func _enemy(id: String) -> EnemyDef:
	return load(ENEMY_DIR + id + ".tres")


func test_stage_loads() -> void:
	var s = load(STAGE_PATH)
	assert_object(s).is_not_null()
	assert_bool(s is StageDef).is_true()


func test_stage_header() -> void:
	var s: StageDef = load(STAGE_PATH)
	assert_str(s.id).is_equal("mad_forest")
	assert_str(s.name).is_equal("Mad Forest")
	assert_float(s.duration).is_equal(1800.0)
	assert_int(s.starting_spawn_count).is_equal(10)
	assert_int(s.reaper_minute).is_equal(30)
	assert_float(s.brazier_interval).is_equal(60.0)
	assert_float(s.stat_modifiers["enemy_move_speed"]).is_equal(1.1)  # wiki: x1.1


func test_wave_script_complete_and_ordered() -> void:
	var s: StageDef = load(STAGE_PATH)
	assert_int(s.waves.size()).is_equal(30)  # minutes 0..29
	for i in 30:
		var w: Dictionary = s.waves[i]
		assert_int(w["minute"]).is_equal(i)  # strictly ordered, one per minute
		assert_bool(w["enemy_ids"].size() > 0).is_true()
		assert_bool(w["min_alive"] > 0).is_true()
		assert_bool(w["interval"] > 0.0).is_true()


func test_wave_known_wiki_values() -> void:
	var s: StageDef = load(STAGE_PATH)
	# Minute 3: Skeleton, min_alive 40, interval 0.25 (wiki).
	assert_array(s.waves[3]["enemy_ids"]).contains(["skeleton"])
	assert_int(s.waves[3]["min_alive"]).is_equal(40)
	assert_float(s.waves[3]["interval"]).is_equal(0.25)
	# Minute 11: min_alive ramps to 300 (wiki).
	assert_int(s.waves[11]["min_alive"]).is_equal(300)


func test_bosses() -> void:
	var s: StageDef = load(STAGE_PATH)
	assert_int(s.bosses.size()).is_equal(2)
	assert_int(s.bosses[0]["minute"]).is_equal(8)
	assert_str(s.bosses[0]["enemy_id"]).is_equal("giant_bat")
	assert_int(s.bosses[1]["minute"]).is_equal(15)
	assert_str(s.bosses[1]["enemy_id"]).is_equal("werewolf")


func test_events() -> void:
	var s: StageDef = load(STAGE_PATH)
	assert_int(s.events.size()).is_equal(4)
	var kinds: Array = []
	for e: Dictionary in s.events:
		kinds.append(e["kind"])
	assert_array(kinds).contains(["bat_swarm", "flower_wall", "ghost_swarm"])


func test_all_referenced_enemies_exist() -> void:
	var s: StageDef = load(STAGE_PATH)
	var referenced := {}
	for w: Dictionary in s.waves:
		for id: String in w["enemy_ids"]:
			referenced[id] = true
	for b: Dictionary in s.bosses:
		referenced[b["enemy_id"]] = true
	for id: String in referenced:
		var e = _enemy(id)
		assert_object(e).is_not_null()
		assert_bool(e is EnemyDef).is_true()
		assert_str(e.id).is_equal(id)


func test_basic_enemy_stats_match_wiki() -> void:
	var bat := _enemy("bat")
	assert_float(bat.hp).is_equal(1.0)
	assert_float(bat.power).is_equal(5.0)
	assert_float(bat.speed).is_equal(140.0)
	var skel := _enemy("skeleton")
	assert_float(skel.hp).is_equal(15.0)
	assert_float(skel.power).is_equal(10.0)
	var ghost := _enemy("ghost")
	assert_float(ghost.hp).is_equal(10.0)
	assert_float(ghost.speed).is_equal(200.0)


func test_reaper_is_lethal_boss() -> void:
	var r := _enemy("reaper")
	assert_float(r.power).is_equal(65535.0)  # the one-shot damage
	assert_float(r.hp).is_equal(655350.0)
	assert_float(r.speed).is_equal(1200.0)
	assert_bool(r.is_boss).is_true()
	assert_float(r.knockback_resist).is_equal(1.0)


func test_giant_bat_is_boss() -> void:
	var gb := _enemy("giant_bat")
	assert_bool(gb.is_boss).is_true()
	assert_float(gb.hp).is_equal(500.0)
	assert_float(gb.knockback_resist).is_equal(1.0)
