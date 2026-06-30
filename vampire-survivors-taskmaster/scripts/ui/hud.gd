class_name VSHud
extends CanvasLayer
## Minimal heads-up display: HP / time / kills / level, plus a game-over banner.
## Built in code; replace with the Kenney UI pack art as the UI lane matures.

var _stat: Label
var _over: Label

func _ready() -> void:
	_stat = Label.new()
	_stat.position = Vector2(12, 8)
	_stat.add_theme_font_size_override("font_size", 16)
	add_child(_stat)

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
	if run.player:
		hp = int(ceil(run.player.health))
	_stat.text = "HP %d    Time %ds    Kills %d    Lv %d (%d xp)" % [hp, int(run.elapsed), run.kills, run.level, run.xp]
	_over.visible = run.phase == "game_over"
