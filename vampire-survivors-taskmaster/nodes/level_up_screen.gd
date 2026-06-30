extends Control

## Level-up overlay (OverlayLayer/LevelUpScreen). Shown when GameManager emits
## level_up_requested; presents the 3-4 LevelingSystem options, a live stat rail,
## and the Reroll/Skip/Banish controls. Selecting an option applies it through
## LevelingSystem and hands control back via GameManager.close_level_up (which
## drains the queue: another pending level-up re-fires level_up_requested, an
## empty queue resumes the run). Runs while the tree is frozen
## (PROCESS_MODE_ALWAYS) so its buttons stay live during the pause.
##
## Reconciliations with the task sketch:
##   * DRAW vs RENDER are split. The sketch's _on_reroll called reroll() (which
##     already redraws via make_options) AND then _generate_options() (a SECOND
##     make_options draw) -- discarding the reroll result and double-advancing
##     the run RNG. Here reroll() draws once and _render_options() only paints
##     the existing current_options.
##   * Option labels use the def's `name` (there is no `description` field in
##     GameDatabase); the raw id (e.g. "magic_wand") is the fallback.
##   * _update_stat_rail is implemented (the sketch left it a stub): one line per
##     StatBlock field, multipliers shown as %, flats as values.
##   * Skip/Banish stay disabled this slice (no charges are sourced yet); only
##     Reroll is wired, matching the sketch.

signal choice_made(choice: Dictionary)

@onready var title_label: Label = $Panel/TitleLabel
@onready var options_container: VBoxContainer = $Panel/OptionsContainer
@onready var stat_rail: VBoxContainer = $Panel/StatRail
@onready var reroll_button: Button = $Panel/RerollButton
@onready var skip_button: Button = $Panel/SkipButton
@onready var banish_button: Button = $Panel/BanishButton

@onready var game_manager := get_node("/root/GameManager")
@onready var game_db := get_node("/root/GameDatabase")

var current_options: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	game_manager.level_up_requested.connect(_on_level_up_requested)
	reroll_button.pressed.connect(_on_reroll)

func _on_level_up_requested() -> void:
	if game_manager.run_state == null:
		return
	visible = true
	title_label.text = "LEVEL UP!"
	_draw_options()
	_update_stat_rail()
	_update_buttons()

## Draw a fresh option set from LevelingSystem, then paint it.
func _draw_options() -> void:
	var player: PlayerState = game_manager.run_state.player
	var rng: RandomNumberGenerator = game_manager.run_state.rng
	current_options = LevelingSystem.make_options(player, game_db, rng)
	_render_options()

## Paint the option buttons from current_options (no redraw -> no extra RNG use).
func _render_options() -> void:
	for child in options_container.get_children():
		child.free()
	for i in range(current_options.size()):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(300, 56)
		btn.text = _option_text(current_options[i])
		btn.pressed.connect(_on_option_selected.bind(i))
		options_container.add_child(btn)

func _option_text(opt: Dictionary) -> String:
	match opt["type"]:
		"new_weapon":
			return "%s - NEW!" % _def_name(game_db.weapon(opt["id"]), opt["id"])
		"weapon_upgrade":
			return "%s - LV %d" % [_def_name(game_db.weapon(opt["id"]), opt["id"]), int(opt["level"])]
		"new_passive":
			return "%s - NEW!" % _def_name(game_db.passive(opt["id"]), opt["id"])
		"passive_upgrade":
			return "%s - LV %d" % [_def_name(game_db.passive(opt["id"]), opt["id"]), int(opt["level"])]
		"gold":
			return "+%d Gold" % int(opt["value"])
		"chicken":
			return "Floor Chicken (+%d HP)" % int(game_db.CHICKEN_HEAL)
	return "?"

func _def_name(def: Dictionary, id) -> String:
	return String(def.get("name", str(id)))

func _on_option_selected(index: int) -> void:
	var choice: Dictionary = current_options[index]
	LevelingSystem.apply_choice(game_manager.run_state.player, game_db, choice)
	choice_made.emit(choice)
	visible = false
	game_manager.close_level_up()

func _on_reroll() -> void:
	var player: PlayerState = game_manager.run_state.player
	if player.reroll_charges <= 0:
		return
	current_options = LevelingSystem.reroll(player, game_db, game_manager.run_state.rng)
	_render_options()
	_update_buttons()

func _update_buttons() -> void:
	var player: PlayerState = game_manager.run_state.player
	reroll_button.text = "Reroll (%d)" % player.reroll_charges
	reroll_button.disabled = player.reroll_charges <= 0
	skip_button.text = "Skip (0)"
	skip_button.disabled = true   # not sourced this slice
	banish_button.text = "Banish (0)"
	banish_button.disabled = true # not sourced this slice

## One line per derived stat: multipliers as %, flats as raw values.
func _update_stat_rail() -> void:
	for child in stat_rail.get_children():
		child.free()
	var stats: StatBlock = game_manager.run_state.player.stats
	if stats == null:
		return
	_add_stat_line("Might", "%d%%" % roundi(stats.might * 100.0))
	_add_stat_line("Area", "%d%%" % roundi(stats.area * 100.0))
	_add_stat_line("Speed", "%d%%" % roundi(stats.speed * 100.0))
	_add_stat_line("Cooldown", "%d%%" % roundi(stats.cooldown * 100.0))
	_add_stat_line("Duration", "%d%%" % roundi(stats.duration * 100.0))
	_add_stat_line("Amount", "+%d" % roundi(stats.amount))
	_add_stat_line("Move Speed", "%d%%" % roundi(stats.move_speed * 100.0))
	_add_stat_line("Max HP", "+%d" % roundi(stats.max_health))
	_add_stat_line("Armor", "%d" % roundi(stats.armor))
	_add_stat_line("Recovery", "%.1f/s" % stats.recovery)
	_add_stat_line("Magnet", "%d%%" % roundi(stats.magnet * 100.0))
	_add_stat_line("Luck", "%d%%" % roundi(stats.luck * 100.0))
	_add_stat_line("Growth", "%d%%" % roundi(stats.growth * 100.0))
	_add_stat_line("Greed", "%d%%" % roundi(stats.greed * 100.0))
	_add_stat_line("Curse", "%d%%" % roundi(stats.curse * 100.0))

func _add_stat_line(stat_name: String, value: String) -> void:
	var label := Label.new()
	label.text = "%s: %s" % [stat_name, value]
	stat_rail.add_child(label)
