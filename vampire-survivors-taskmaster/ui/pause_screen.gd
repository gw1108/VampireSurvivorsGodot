class_name PauseScreen extends Control

## Modal pause menu shown while GameState.phase == PAUSED. Emits resume_requested
## / quit_requested; RunController owns the phase changes. The pause action also
## closes the menu (toggle feel). Pure view: never touches GameState.

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	hide()
	resume_btn.pressed.connect(_on_resume)
	quit_btn.pressed.connect(_on_quit)


func _input(event: InputEvent) -> void:
	# While open, the pause key resumes (toggle). Guard `visible` so the same key
	# doesn't both open (RunController._unhandled_input) and close in one press.
	if visible and event.is_action_pressed("pause"):
		_on_resume()
		get_viewport().set_input_as_handled()


func show_pause() -> void:
	show()
	resume_btn.grab_focus()


func _on_resume() -> void:
	hide()
	resume_requested.emit()


func _on_quit() -> void:
	hide()
	quit_requested.emit()
