class_name VSHud
extends CanvasLayer
## Minimal heads-up display: HP / time / kills / level, plus a game-over banner.
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

var _stat: Label
var _build: Label
var _over: Label

func _ready() -> void:
	_stat = Label.new()
	_stat.position = Vector2(12, 8)
	_stat.add_theme_font_size_override("font_size", 16)
	add_child(_stat)

	# Second line: the run's mutable combat stats, so the player can read what
	# their level-up picks actually did.
	_build = Label.new()
	_build.position = Vector2(12, 30)
	_build.add_theme_font_size_override("font_size", 14)
	_build.modulate = Color(0.8, 0.9, 1.0)
	add_child(_build)

	_over = Label.new()
	_over.text = "YOU DIED\nPress Enter to retry"
	_over.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over.position = Vector2(300, 280)
	_over.add_theme_font_size_override("font_size", 28)
	_over.visible = false
	add_child(_over)

func refresh(run: VSRun) -> void:
	if _stat == null:
		return
	var hp := 0
	var max_hp := 0
	if run.player:
		hp = int(ceil(run.player.health))
		max_hp = int(round(run.player.max_health))
	_stat.text = "HP %d/%d    Time %ds    Kills %d    Lv %d (%d xp)" % [hp, max_hp, int(run.elapsed), run.kills, run.level, run.xp]
	var fire_rate := 1.0 / run.weapon_fire_interval if run.weapon_fire_interval > 0.0 else 0.0
	var move_speed := int(round(VSPlayer.SPEED * run.player_speed_mult))
	_build.text = "DMG %.0f    Rate %.2f/s    Speed %d    Shots %d" % [run.weapon_damage, fire_rate, move_speed, run.weapon_count]
	if run.garlic_level > 0:
		_build.text += "    Garlic Lv %d" % run.garlic_level
	if run.whip_level > 0:
		_build.text += "    Whip Lv %d" % run.whip_level
	_over.visible = run.phase == "game_over"
