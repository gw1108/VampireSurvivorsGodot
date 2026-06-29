extends Control

## Main menu screen. Start launches directly into Mad Forest as Antonio via the
## GameManager autoload; Quit exits the app. Buttons are wired by scene-unique
## name (`%Name`) so the script does not depend on the exact node hierarchy.

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var game_manager := get_node("/root/GameManager")

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()

func _on_start() -> void:
	game_manager.start_run()

func _on_quit() -> void:
	get_tree().quit()
