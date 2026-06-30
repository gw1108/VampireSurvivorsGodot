extends Node

## Thin placeholder audio service (autoload `AudioManager`). Owns a small pool of
## AudioStreamPlayers for one-shot SFX and a single looping music player, so
## gameplay code can fire `AudioManager.play(&"hit")` / `play_music(&"stage")`
## today and the actual streams can be dropped in later with no caller changes.
##
## Reconciliations with the task sketch (intentional):
##   * play() RETURNS the AudioStreamPlayer it used (or null) instead of void, so
##     callers/tests can observe which voice fired without inspecting the pool.
##     A null return means "no stream mapped" or "no free voice" -- a safe no-op.
##   * Bus assignment is guarded by AudioServer.get_bus_index so a missing bus
##     falls back to Master silently instead of erroring (the SFX/Music buses are
##     defined in res://default_bus_layout.tres; the guard keeps this robust if
##     that layout is ever absent).
##   * process_mode = ALWAYS so music/SFX are not frozen while the run is paused.

const POOL_SIZE := 8

var sfx_pool: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer

# Placeholder stream slots (assign real assets later; null == silent no-op).
var sfx_hit: AudioStream = null
var sfx_death: AudioStream = null
var sfx_gem: AudioStream = null
var sfx_levelup: AudioStream = null
var sfx_chest: AudioStream = null
var music_stage: AudioStream = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		_assign_bus(player, &"SFX")
		add_child(player)
		sfx_pool.append(player)
	music_player = AudioStreamPlayer.new()
	_assign_bus(music_player, &"Music")
	add_child(music_player)

## Fire a one-shot SFX for `event` on a free pool voice. Returns the voice used,
## or null when the event has no stream mapped or every voice is busy.
func play(event: StringName) -> AudioStreamPlayer:
	var stream := _stream_for(event)
	if stream == null:
		return null
	var player := _free_player()
	if player == null:
		return null
	player.stream = stream
	player.play()
	return player

func play_music(track: StringName) -> void:
	match track:
		&"stage":
			if music_stage != null:
				music_player.stream = music_stage
				music_player.play()

func stop_music() -> void:
	music_player.stop()

# --- helpers -----------------------------------------------------------------

func _stream_for(event: StringName) -> AudioStream:
	match event:
		&"hit": return sfx_hit
		&"death": return sfx_death
		&"gem": return sfx_gem
		&"levelup": return sfx_levelup
		&"chest": return sfx_chest
	return null

## First voice that is not currently playing, or null if all are busy.
func _free_player() -> AudioStreamPlayer:
	for player in sfx_pool:
		if not player.playing:
			return player
	return null

func _assign_bus(player: AudioStreamPlayer, bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		player.bus = bus
