extends GdUnitTestSuite

## Verifies GameState default values, composed objects, enum, and mutability.

func test_defaults() -> void:
	var g := GameState.new()
	assert_float(g.time_elapsed).is_equal(0.0)
	assert_int(g.current_minute).is_equal(0)
	assert_int(g.phase).is_equal(GameState.Phase.TITLE)
	assert_int(g.spawn_cursor).is_equal(0)
	assert_int(g.event_cursor).is_equal(0)
	assert_int(g.chest_count).is_equal(0)
	assert_int(g.kills).is_equal(0)
	assert_int(g.gold).is_equal(0)
	assert_int(g.pending_levelups).is_equal(0)


func test_default_arrays_empty() -> void:
	var g := GameState.new()
	assert_array(g.enemies).is_empty()
	assert_array(g.projectiles).is_empty()
	assert_array(g.zones).is_empty()
	assert_array(g.gems).is_empty()
	assert_array(g.pickups).is_empty()
	assert_array(g.chests).is_empty()
	assert_array(g.light_sources).is_empty()
	assert_dict(g.global_effects).is_empty()


func test_default_object_refs() -> void:
	var g := GameState.new()
	assert_object(g.rng).is_not_null()
	assert_bool(g.rng is RandomNumberGenerator).is_true()
	assert_object(g.player).is_not_null()
	assert_bool(g.player is PlayerState).is_true()
	assert_object(g.index).is_null()
	assert_object(g.current_offer).is_null()


func test_is_ref_counted() -> void:
	assert_bool(GameState.new() is RefCounted).is_true()


func test_phase_enum_values() -> void:
	assert_int(GameState.Phase.TITLE).is_equal(0)
	assert_int(GameState.Phase.PLAYING).is_equal(1)
	assert_int(GameState.Phase.PAUSED).is_equal(2)
	assert_int(GameState.Phase.LEVEL_UP).is_equal(3)
	assert_int(GameState.Phase.GAME_OVER).is_equal(4)
	assert_int(GameState.Phase.RESULTS).is_equal(5)


func test_mutability() -> void:
	var g := GameState.new()
	g.time_elapsed = 12.5
	g.current_minute = 1
	g.phase = GameState.Phase.PLAYING
	g.kills = 30
	g.gold = 250
	g.enemies.append("bat")
	assert_float(g.time_elapsed).is_equal(12.5)
	assert_int(g.current_minute).is_equal(1)
	assert_int(g.phase).is_equal(GameState.Phase.PLAYING)
	assert_int(g.kills).is_equal(30)
	assert_int(g.gold).is_equal(250)
	assert_int(g.enemies.size()).is_equal(1)


func test_default_collections_are_per_instance() -> void:
	var a := GameState.new()
	var b := GameState.new()
	a.enemies.append("bat")
	assert_array(b.enemies).is_empty()
