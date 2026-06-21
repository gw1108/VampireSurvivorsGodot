extends GdUnitTestSuite

## Tests LevelUpScreen: it builds one button per offer option with correctly
## formatted "new" / "upgrade" labels, becomes visible on show_offer, clears old
## buttons on re-show, emits option_chosen(index) on a press (and re-hides), and
## survives an empty (max-state) offer without crashing.

const SCENE := "res://ui/level_up_screen.tscn"


func _screen() -> LevelUpScreen:
	var s: LevelUpScreen = load(SCENE).instantiate()
	add_child(s)  # triggers _ready (@onready + hide)
	return auto_free(s)


func _weapon_def(id: String, display_name: String) -> WeaponDef:
	var d := WeaponDef.new()
	d.id = id
	d.name = display_name
	return d


func _new_opt(def) -> Dictionary:
	return {"kind": "weapon", "def": def, "is_upgrade": false, "target": null, "target_level": 1}


func _upgrade_opt(def, target_level: int) -> Dictionary:
	return {"kind": "weapon", "def": def, "is_upgrade": true, "target": null, "target_level": target_level}


func _offer(options: Array) -> LevelUpOffer:
	var o := LevelUpOffer.new()
	o.options = options
	return o


func test_hidden_on_ready() -> void:
	var s := _screen()
	assert_bool(s.visible).is_false()


func test_show_offer_creates_one_button_per_option() -> void:
	var s := _screen()
	s.show_offer(_offer([_new_opt(_weapon_def("whip", "Whip")), _new_opt(_weapon_def("knife", "Knife"))]))
	assert_int(s._option_buttons.size()).is_equal(2)
	assert_bool(s.visible).is_true()


func test_new_option_label() -> void:
	var s := _screen()
	s.show_offer(_offer([_new_opt(_weapon_def("whip", "Whip"))]))
	assert_str(s._option_buttons[0].text).is_equal("NEW: Whip")


func test_upgrade_option_label() -> void:
	var s := _screen()
	s.show_offer(_offer([_upgrade_opt(_weapon_def("whip", "Whip"), 3)]))
	assert_str(s._option_buttons[0].text).is_equal("Whip Lv 2 → 3")


func test_reshow_clears_previous_buttons() -> void:
	var s := _screen()
	s.show_offer(_offer([_new_opt(_weapon_def("whip", "Whip")), _new_opt(_weapon_def("knife", "Knife"))]))
	s.show_offer(_offer([_new_opt(_weapon_def("axe", "Axe"))]))
	assert_int(s._option_buttons.size()).is_equal(1)
	assert_str(s._option_buttons[0].text).is_equal("NEW: Axe")


func test_pressing_button_emits_index_and_hides() -> void:
	var s := _screen()
	s.show_offer(_offer([_new_opt(_weapon_def("whip", "Whip")), _new_opt(_weapon_def("knife", "Knife"))]))
	var chosen: Array = []
	s.option_chosen.connect(func(i): chosen.append(i))
	s._option_buttons[1].pressed.emit()  # press the second option
	assert_array(chosen).is_equal([1])
	assert_bool(s.visible).is_false()


func test_empty_offer_does_not_crash() -> void:
	var s := _screen()
	s.show_offer(_offer([]))  # max-state offer
	assert_int(s._option_buttons.size()).is_equal(0)
	assert_bool(s.visible).is_true()
