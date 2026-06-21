class_name ResultsScreen extends Control

## End-of-run summary shown while GameState.phase == RESULTS: time survived, level,
## kills, gold, and a per-weapon total-damage table. Emits done when dismissed;
## RunController owns the phase change. Pure view — never touches GameState.
##
## Deviations vs the task sketch (kept consistent with this codebase):
##  - labels live under Panel/VBoxContainer and are reached via @onready refs.
##  - the summary is a Dictionary, so values are read with ["key"] — GDScript has no
##    dot-access on Dictionaries (opt.level / weapon_stat.name would be a runtime
##    error). weapon_stats is an Array of {"name", "total_damage"} dicts.

signal done

@onready var time_label: Label = $Panel/VBoxContainer/TimeLabel
@onready var level_label: Label = $Panel/VBoxContainer/LevelLabel
@onready var kills_label: Label = $Panel/VBoxContainer/KillsLabel
@onready var gold_label: Label = $Panel/VBoxContainer/GoldLabel
@onready var weapon_stats_label: Label = $Panel/VBoxContainer/WeaponStatsLabel
@onready var done_btn: Button = $Panel/VBoxContainer/DoneButton


func _ready() -> void:
	hide()
	done_btn.pressed.connect(_on_done)


func show_results(summary: Dictionary) -> void:
	time_label.text = "Time: %s" % summary["time_formatted"]
	level_label.text = "Level: %d" % summary["level"]
	kills_label.text = "Kills: %d" % summary["kills"]
	gold_label.text = "Gold: %d" % summary["gold"]

	var dps_text := ""
	for weapon_stat in summary["weapon_stats"]:
		dps_text += "%s: %d total damage\n" % [weapon_stat["name"], weapon_stat["total_damage"]]
	weapon_stats_label.text = dps_text

	show()
	done_btn.grab_focus()


func _on_done() -> void:
	hide()
	done.emit()
