extends Control

## Game-over result screen (OverlayLayer/ResultScreen). Shown when the run ends;
## reports survival time, final level, kills and gold, and offers Restart /
## Quit-to-menu. Runs while the tree is frozen (PROCESS_MODE_ALWAYS) so its
## buttons stay live after the sim has stopped.

@onready var time_label: Label = $Panel/TimeLabel
@onready var level_label: Label = $Panel/LevelLabel
@onready var kills_label: Label = $Panel/KillsLabel
@onready var gold_label: Label = $Panel/GoldLabel
@onready var restart_button: Button = $Panel/RestartButton
@onready var menu_button: Button = $Panel/MenuButton

@onready var game_manager := get_node("/root/GameManager")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	game_manager.game_over_triggered.connect(_on_game_over)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)

func _on_game_over(result: RunResult) -> void:
	visible = true
	var minutes := int(result.survival_time) / 60
	var seconds := int(result.survival_time) % 60
	time_label.text = "Time: %02d:%02d" % [minutes, seconds]
	level_label.text = "Level: %d" % result.final_level
	kills_label.text = "Kills: %d" % result.total_kills
	gold_label.text = "Gold: %d" % result.total_gold

func _on_restart() -> void:
	visible = false
	game_manager.restart()

func _on_menu() -> void:
	visible = false
	game_manager.to_menu()
