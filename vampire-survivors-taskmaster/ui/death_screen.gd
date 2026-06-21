class_name DeathScreen extends Control

## Modal overlay shown when GameState.phase == GAME_OVER. Offers Revive (only when
## a revival remains) and Continue. Emits revive_requested / continue_requested;
## RunController owns the phase changes. Pure view — never touches GameState.
##
## Deviations vs the task sketch (kept consistent with this codebase):
##  - buttons live under Panel/VBoxContainer (matching PauseScreen) and are reached
##    via @onready refs, not inline $Panel/X each call.
##  - in this codebase HealthSystem auto-consumes revivals on death BEFORE the phase
##    flips to GAME_OVER, so has_revival is normally false and the Revive button
##    stays hidden. The button + signal are kept wired so the view is complete and
##    testable, and correct if a manual-revive policy is ever adopted.

signal revive_requested
signal continue_requested

@onready var revive_btn: Button = $Panel/VBoxContainer/ReviveButton
@onready var continue_btn: Button = $Panel/VBoxContainer/ContinueButton


func _ready() -> void:
	hide()
	revive_btn.pressed.connect(_on_revive)
	continue_btn.pressed.connect(_on_continue)


func show_death(has_revival: bool) -> void:
	revive_btn.visible = has_revival
	revive_btn.disabled = not has_revival
	show()
	# Focus the actionable default: Revive when offered, else Continue.
	if has_revival:
		revive_btn.grab_focus()
	else:
		continue_btn.grab_focus()


func _on_revive() -> void:
	hide()
	revive_requested.emit()


func _on_continue() -> void:
	hide()
	continue_requested.emit()
