extends GdUnitTestSuite

## Tests HUD.update_from_state: XP/HP bar ranges+values, MM:SS timer formatting,
## and level/gold/kills label text. Also verifies RunController feeds the HUD each
## rendered frame.

const HUD_SCENE := "res://ui/hud.tscn"


func _hud() -> HUD:
	var h: HUD = load(HUD_SCENE).instantiate()
	add_child(h)  # triggers @onready
	return auto_free(h)


func _controller() -> RunController:
	return auto_free(RunController.new())


func test_xp_bar_reflects_player_xp() -> void:
	var h := _hud()
	var gs := GameState.new()
	gs.player.xp = 3.0
	gs.player.xp_to_next = 5.0
	h.update_from_state(gs)
	assert_float(h.xp_bar.max_value).is_equal(5.0)
	assert_float(h.xp_bar.value).is_equal(3.0)


func test_hp_bar_reflects_player_hp() -> void:
	var h := _hud()
	var gs := GameState.new()
	gs.player.hp = 80.0
	gs.player.derived.max_health = 120.0
	h.update_from_state(gs)
	assert_float(h.hp_bar.max_value).is_equal(120.0)
	assert_float(h.hp_bar.value).is_equal(80.0)


func test_timer_formats_mm_ss() -> void:
	var h := _hud()
	var gs := GameState.new()
	gs.time_elapsed = 75.4  # 1:15
	h.update_from_state(gs)
	assert_str(h.timer_label.text).is_equal("01:15")


func test_timer_pads_seconds() -> void:
	var h := _hud()
	var gs := GameState.new()
	gs.time_elapsed = 605.0  # 10:05
	h.update_from_state(gs)
	assert_str(h.timer_label.text).is_equal("10:05")


func test_stat_labels() -> void:
	var h := _hud()
	var gs := GameState.new()
	gs.player.level = 7
	gs.gold = 42
	gs.kills = 123
	h.update_from_state(gs)
	assert_str(h.level_label.text).is_equal("Lv 7")
	assert_str(h.gold_label.text).is_equal("42")
	assert_str(h.kills_label.text).is_equal("123")


func test_run_controller_updates_hud_each_frame() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._hud = _hud()
	rc.state.kills = 9
	rc.state.gold = 5
	rc._process(0.016)
	assert_str(rc._hud.kills_label.text).is_equal("9")
	assert_str(rc._hud.gold_label.text).is_equal("5")
	assert_str(rc._hud.level_label.text).is_equal("Lv 1")
