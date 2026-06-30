extends Control

## Pause overlay (OverlayLayer/PauseScreen). Shown while GameManager is PAUSED;
## displays the current build (weapons + passives with levels) and offers
## Resume / Quit-to-menu. Runs while the tree is frozen (PROCESS_MODE_ALWAYS) so
## its buttons stay live during the pause.
##
## Reconciliation with the task sketch: _update_build_display guards a null
## run_state (the pause signal can only fire mid-run, but the guard keeps the
## screen inert if it is ever shown without one).

@onready var build_container: VBoxContainer = $Panel/BuildContainer
@onready var resume_button: Button = $Panel/ResumeButton
@onready var quit_button: Button = $Panel/QuitButton

@onready var game_manager := get_node("/root/GameManager")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	game_manager.state_changed.connect(_on_state_changed)
	resume_button.pressed.connect(_on_resume)
	quit_button.pressed.connect(_on_quit)

func _on_state_changed(new_state: int) -> void:
	visible = (new_state == game_manager.State.PAUSED)
	if visible:
		_update_build_display()

## Rebuild the "<id> LV<n>" lines for every owned weapon then passive.
func _update_build_display() -> void:
	for child in build_container.get_children():
		child.queue_free()
	if game_manager.run_state == null:
		return
	var player: PlayerState = game_manager.run_state.player
	for weapon in player.weapons:
		var label := Label.new()
		label.text = "%s LV%d" % [weapon.id, weapon.level]
		build_container.add_child(label)
	for passive in player.passives:
		var label := Label.new()
		label.text = "%s LV%d" % [passive.id, passive.level]
		build_container.add_child(label)

func _on_resume() -> void:
	game_manager.resume()

func _on_quit() -> void:
	game_manager.to_menu()
