class_name HUD extends Control

## Heads-up display: XP + HP bars and timer/level/gold/kills labels, refreshed
## from GameState every rendered frame by RunController. Pure view — reads state,
## never mutates it.

@onready var xp_bar: ProgressBar = $XPBar
@onready var hp_bar: ProgressBar = $HPBar
@onready var timer_label: Label = $TimerLabel
@onready var level_label: Label = $LevelLabel
@onready var gold_label: Label = $GoldLabel
@onready var kills_label: Label = $KillsLabel


func update_from_state(state: GameState) -> void:
	var player: PlayerState = state.player

	xp_bar.max_value = player.xp_to_next
	xp_bar.value = player.xp

	hp_bar.max_value = player.derived.max_health
	hp_bar.value = player.hp

	@warning_ignore("integer_division")
	var minutes := int(state.time_elapsed) / 60
	var seconds := int(state.time_elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	level_label.text = "Lv %d" % player.level
	gold_label.text = str(state.gold)
	kills_label.text = str(state.kills)
