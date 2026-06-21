extends GdUnitTestSuite

## Verifies the GameData autoload loaded the data layer and exposes it correctly.

func test_weapon_loaded() -> void:
	var whip := GameData.get_weapon("whip")
	assert_object(whip).is_not_null()
	assert_bool(whip is WeaponDef).is_true()
	assert_str(whip.id).is_equal("whip")
	assert_float(whip.base_damage).is_equal(10.0)


func test_enemies_loaded() -> void:
	for id in ["bat", "skeleton", "ghost", "giant_bat", "werewolf", "reaper"]:
		var e := GameData.get_enemy(id)
		assert_object(e).is_not_null()
		assert_bool(e is EnemyDef).is_true()
		assert_str(e.id).is_equal(id)
	assert_float(GameData.get_enemy("reaper").power).is_equal(65535.0)


func test_character_loaded() -> void:
	var antonio := GameData.get_character("antonio")
	assert_object(antonio).is_not_null()
	assert_bool(antonio is CharacterDef).is_true()
	assert_float(antonio.max_health).is_equal(120.0)


func test_stage_loaded() -> void:
	var stage := GameData.get_stage("mad_forest")
	assert_object(stage).is_not_null()
	assert_bool(stage is StageDef).is_true()
	assert_int(stage.waves.size()).is_equal(30)


func test_unknown_id_returns_null() -> void:
	assert_object(GameData.get_weapon("does_not_exist")).is_null()
	assert_object(GameData.get_enemy("does_not_exist")).is_null()
	assert_object(GameData.get_stage("does_not_exist")).is_null()


func test_get_all_weapons() -> void:
	var all := GameData.get_all_weapons()
	assert_int(all.size()).is_greater_equal(1)
	var ids: Array = []
	for w in all:
		ids.append(w.id)
	assert_array(ids).contains(["whip"])


func test_get_all_enemies() -> void:
	assert_int(GameData.get_all_enemies().size()).is_equal(6)


func test_get_all_passives_empty_but_typed() -> void:
	# No passives authored yet; must return an (empty) array without error.
	assert_int(GameData.get_all_passives().size()).is_equal(0)


func test_level_curve_delegation() -> void:
	assert_float(GameData.get_xp_for_level(1)).is_equal(5.0)
	assert_float(GameData.get_xp_for_level(2)).is_equal(15.0)
	assert_float(GameData.get_total_xp_for_level(20)).is_equal(1805.0)
