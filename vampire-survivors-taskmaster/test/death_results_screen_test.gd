extends GdUnitTestSuite

## Tests DeathScreen (revive button gated on has_revival, signal emission) and
## ResultsScreen (label/weapon-table formatting from a summary Dictionary), plus
## RunController's GAME_OVER -> death -> continue -> RESULTS -> done flow and the
## extended _build_summary (time_formatted + per-weapon damage_dealt table).

const DEATH_SCENE := "res://ui/death_screen.tscn"
const RESULTS_SCENE := "res://ui/results_screen.tscn"


func _death() -> DeathScreen:
	var s: DeathScreen = load(DEATH_SCENE).instantiate()
	add_child(s)  # triggers _ready (hide + connect buttons)
	return auto_free(s)


func _results() -> ResultsScreen:
	var s: ResultsScreen = load(RESULTS_SCENE).instantiate()
	add_child(s)
	return auto_free(s)


func _controller() -> RunController:
	return auto_free(RunController.new())


func _summary() -> Dictionary:
	return {
		"kills": 12,
		"gold": 34,
		"level": 5,
		"time_survived": 125.0,
		"time_formatted": "02:05",
		"weapon_stats": [
			{"name": "Whip", "total_damage": 200},
			{"name": "Magic Wand", "total_damage": 75},
		],
	}


# --- DeathScreen view ---

func test_death_hidden_on_ready() -> void:
	var s := _death()
	assert_bool(s.visible).is_false()


func test_show_death_with_revival_shows_button() -> void:
	var s := _death()
	s.show_death(true)
	assert_bool(s.visible).is_true()
	assert_bool(s.revive_btn.visible).is_true()
	assert_bool(s.revive_btn.disabled).is_false()


func test_show_death_without_revival_hides_button() -> void:
	var s := _death()
	s.show_death(false)
	assert_bool(s.visible).is_true()
	assert_bool(s.revive_btn.visible).is_false()
	assert_bool(s.revive_btn.disabled).is_true()


func test_revive_button_emits_and_hides() -> void:
	var s := _death()
	s.show_death(true)
	var fired: Array = []
	s.revive_requested.connect(func(): fired.append(true))
	s.revive_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


func test_continue_button_emits_and_hides() -> void:
	var s := _death()
	s.show_death(false)
	var fired: Array = []
	s.continue_requested.connect(func(): fired.append(true))
	s.continue_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


# --- ResultsScreen view ---

func test_results_hidden_on_ready() -> void:
	var s := _results()
	assert_bool(s.visible).is_false()


func test_results_labels_format_from_summary() -> void:
	var s := _results()
	s.show_results(_summary())
	assert_bool(s.visible).is_true()
	assert_str(s.time_label.text).is_equal("Time: 02:05")
	assert_str(s.level_label.text).is_equal("Level: 5")
	assert_str(s.kills_label.text).is_equal("Kills: 12")
	assert_str(s.gold_label.text).is_equal("Gold: 34")


func test_results_weapon_table() -> void:
	var s := _results()
	s.show_results(_summary())
	assert_str(s.weapon_stats_label.text).contains("Whip: 200 total damage")
	assert_str(s.weapon_stats_label.text).contains("Magic Wand: 75 total damage")


func test_results_done_emits_and_hides() -> void:
	var s := _results()
	s.show_results(_summary())
	var fired: Array = []
	s.done.connect(func(): fired.append(true))
	s.done_btn.pressed.emit()
	assert_int(fired.size()).is_equal(1)
	assert_bool(s.visible).is_false()


# --- RunController integration ---

func test_summary_includes_time_formatted_and_weapon_stats() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc.state.time_elapsed = 65.0  # 01:05
	var summary := rc._build_summary()
	assert_str(summary["time_formatted"]).is_equal("01:05")
	assert_bool(summary.has("weapon_stats")).is_true()
	# Antonio starts with one weapon (whip); its stat row carries a name + total.
	assert_int((summary["weapon_stats"] as Array).size()).is_equal(1)
	assert_bool(summary["weapon_stats"][0].has("total_damage")).is_true()


func test_continue_advances_to_results() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._results_screen = _results()
	rc.state.player.hp = 0.0
	rc.state.player.revivals = 0
	rc._tick(0.016, Vector2.ZERO)  # -> GAME_OVER, _end_run stashes summary
	rc._on_continue_requested()
	assert_int(rc.state.phase).is_equal(GameState.Phase.RESULTS)
	assert_bool(rc._results_screen.visible).is_true()


func test_results_done_returns_to_title() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc._on_results_done()
	assert_int(rc.state.phase).is_equal(GameState.Phase.TITLE)


func test_revive_request_restores_player_and_resumes() -> void:
	var rc := _controller()
	rc.start_run("antonio")
	rc.state.player.revivals = 1
	rc.state.player.hp = 0.0
	rc._on_revive_requested()
	assert_int(rc.state.phase).is_equal(GameState.Phase.PLAYING)
	assert_int(rc.state.player.revivals).is_equal(0)
	assert_float(rc.state.player.hp).is_greater(0.0)
