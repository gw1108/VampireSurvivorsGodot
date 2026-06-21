class_name MainMenu extends Control

## Title screen shown at boot. Emits start_game / quit_game; RunController owns
## the response (start a run / quit the app). Pure view — never touches GameState.
##
## Deviation from the task sketch: _on_quit emits quit_game instead of calling
## get_tree().quit() directly. That keeps the view testable (a test would
## otherwise terminate the runner) and makes the declared quit_game signal live,
## matching how PauseScreen surfaces quit_requested.

signal start_game
signal quit_game

@onready var start_btn: Button = $Panel/VBoxContainer/StartButton
@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	start_btn.pressed.connect(_on_start)
	quit_btn.pressed.connect(_on_quit)
	start_btn.grab_focus()


func _on_start() -> void:
	start_game.emit()


func _on_quit() -> void:
	quit_game.emit()
