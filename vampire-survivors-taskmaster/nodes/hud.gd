extends Control

## In-run HUD overlay. A dumb view: every frame it reads the active run from the
## GameManager autoload and pushes the numbers onto its widgets. Carries no game
## logic and mutates no game state.
##
## Layout (authored in run.tscn): XP bar stretched along the top, survival timer
## top-center, level/gold/kills stacked top-right, weapon + passive icon rows
## top-left under the XP bar.
##
## Reconciliations with the task sketch:
##   * GameManager.run_state is the run root (not PlayerState directly); we read
##     run_state.player + run_state.elapsed.
##   * The XP fill guards xp_to_next == 0 (avoids a NaN right after a level-up
##     before StatSystem reseeds the curve) and clamps to [0, max_value].
##   * Inventory icons are rebuilt only when the weapon/passive COUNT changes,
##     not every frame (the sketch's own comment asked for this) -- per-frame
##     queue_free/add_child churn is wasteful and would fight the deferred-free
##     queue. Icon textures-by-id are wired by the art pass.

@onready var xp_bar: ProgressBar = $XPBar
@onready var timer_label: Label = $TimerLabel
@onready var gold_label: Label = $GoldLabel
@onready var kills_label: Label = $KillsLabel
@onready var level_label: Label = $LevelLabel
@onready var weapon_container: HBoxContainer = $WeaponContainer
@onready var passive_container: HBoxContainer = $PassiveContainer

@onready var game_manager := get_node("/root/GameManager")

const ICON_SIZE := Vector2(32, 32)

var _last_weapon_count: int = -1
var _last_passive_count: int = -1

func _process(_delta: float) -> void:
	var run_state = game_manager.run_state
	if run_state == null:
		return  # no active run (e.g. opened directly in the editor) -> inert
	var player: PlayerState = run_state.player
	var elapsed: float = run_state.elapsed

	# XP bar: fraction of the way to the next level.
	var ratio := 0.0
	if player.xp_to_next > 0.0:
		ratio = clampf(player.xp / player.xp_to_next, 0.0, 1.0)
	xp_bar.value = ratio * xp_bar.max_value

	# Survival timer, MM:SS.
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Top-right stats.
	level_label.text = "LV %d" % player.level
	gold_label.text = str(player.gold)
	kills_label.text = str(player.kills)

	_update_inventory(player)

## Rebuild the weapon / passive icon rows only when the owned count changes.
func _update_inventory(player: PlayerState) -> void:
	if player.weapons.size() != _last_weapon_count:
		_last_weapon_count = player.weapons.size()
		_rebuild_icons(weapon_container, _last_weapon_count)
	if player.passives.size() != _last_passive_count:
		_last_passive_count = player.passives.size()
		_rebuild_icons(passive_container, _last_passive_count)

func _rebuild_icons(container: HBoxContainer, count: int) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in count:
		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE
		# icon.texture is wired by id in the art pass.
		container.add_child(icon)
