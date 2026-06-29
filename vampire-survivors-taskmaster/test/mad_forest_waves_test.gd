extends SceneTree

## Headless validation of the Task 27 Mad Forest wave table.
##   godot --headless --path . --script res://test/mad_forest_waves_test.gd
## Exit code == number of failed checks (0 == all passed).
##
## This guards the data SpawnDirector consumes: 31 entries (minutes 0..30), a
## coherent {enemies, count, interval, boss, event} schema, and — critically —
## referential integrity: every enemy/boss id resolves in ENEMIES and every
## event resolves to one of the swarm enemies SpawnDirector actually spawns.
## A bad id here is a silent run-time spawn failure, so it is asserted, not hoped.

const GDB := preload("res://autoload/game_database.gd")

# Events SpawnDirector._spawn_event_batch knows how to resolve (each is also an
# ENEMIES key it spawns a batch of).
const KNOWN_EVENTS := [&"bat_swarm", &"ghost_swarm", &"flower_wall"]

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== mad_forest_waves_test ==")
	_test_shape()
	_test_referential_integrity()
	_test_events_resolve()
	_test_reaper_finale()
	_test_accessor_clamps()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _test_shape() -> void:
	var waves: Array = GDB.MAD_FOREST_WAVES
	# minutes 0..30 inclusive == 31 entries (M30 is the Reaper finale)
	_check(waves.size() == 31, "wave table covers minutes 0..30 (31 entries), got %d" % waves.size())
	for m in range(waves.size()):
		var w: Dictionary = waves[m]
		_check(w.has("enemies") and w.enemies is Array, "M%d has an enemies array" % m)
		_check(w.has("count") and int(w.count) >= 0, "M%d count is non-negative" % m)
		_check(w.has("interval") and float(w.interval) > 0.0, "M%d interval is positive" % m)
		_check(w.has("boss"), "M%d has a boss field" % m)
		_check(w.has("event"), "M%d has an event field" % m)
		# the periodic minimum never asks for more than the hard on-screen ceiling
		_check(int(w.count) <= GDB.ALIVE_CAP_HARD, "M%d count within hard cap 500" % m)

func _test_referential_integrity() -> void:
	var waves: Array = GDB.MAD_FOREST_WAVES
	for m in range(waves.size()):
		var w: Dictionary = waves[m]
		for eid in w.enemies:
			_check(not GDB.enemy(eid).is_empty(), "M%d enemy '%s' exists in ENEMIES" % [m, eid])
		var boss: StringName = w.boss
		if boss != &"":
			_check(not GDB.enemy(boss).is_empty(), "M%d boss '%s' exists in ENEMIES" % [m, boss])

func _test_events_resolve() -> void:
	var waves: Array = GDB.MAD_FOREST_WAVES
	for m in range(waves.size()):
		var ev: StringName = waves[m].event
		if ev == &"":
			continue
		_check(ev in KNOWN_EVENTS, "M%d event '%s' is one SpawnDirector handles" % [m, ev])
		# the event id is itself the swarm enemy SpawnDirector spawns a batch of
		_check(not GDB.enemy(ev).is_empty(), "M%d event '%s' resolves to an ENEMIES entry" % [m, ev])

func _test_reaper_finale() -> void:
	var waves: Array = GDB.MAD_FOREST_WAVES
	var m30: Dictionary = waves[30]
	_check(m30.boss == &"reaper", "M30 spawns the Reaper")
	_check(m30.get("clear_field", false) == true, "M30 clears the field on Reaper spawn")
	_check((m30.enemies as Array).is_empty(), "M30 has no periodic roster (field is cleared)")
	var reaper: Dictionary = GDB.enemy(&"reaper")
	_check(reaper.get("is_boss", false) == true, "Reaper is flagged is_boss")
	_check(reaper.get("immune", false) == true, "Reaper is immune (instant-kill proof)")
	# REAPER_MINUTE constant lines up with the table's finale index
	_check(GDB.REAPER_MINUTE == 30, "REAPER_MINUTE constant == 30")

func _test_accessor_clamps() -> void:
	# wave() must clamp out-of-range minutes to the finale / first entry.
	_check(GDB.wave(-5).hash() == GDB.MAD_FOREST_WAVES[0].hash(), "wave(<0) clamps to minute 0")
	_check(GDB.wave(999).boss == &"reaper", "wave(past table) clamps to the Reaper finale")
	_check(GDB.wave(30).get("clear_field", false) == true, "wave(30) returns the Reaper finale entry")
