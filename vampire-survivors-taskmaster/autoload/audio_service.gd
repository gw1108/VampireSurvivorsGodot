extends Node

## Autoload singleton (registered as `AudioService`) providing a tiny round-robin
## pool of AudioStreamPlayers for one-shot SFX. Sound streams are placeholders
## (null) until real audio is authored and assigned via set_sound(); play() is a
## safe no-op for any name without a loaded stream, so gameplay systems can fire
## events (hit/death/level_up/...) today and get sound for free once it exists.
##
## No class_name: the autoload's global name `AudioService` is the accessor.

const POOL_SIZE: int = 8

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

# Event name -> stream. Null entries are intentional placeholders, not bugs.
var _sounds: Dictionary = {
	"hit": null,
	"death": null,
	"level_up": null,
	"pickup": null,
	"heal": null,
	"chest": null,
	"hurt": null,
	"weapon_fire": null,
}


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_pool.append(player)


## Play the SFX registered under `sound_name` on the next pooled player. No-op if
## the name is unknown or its stream is still a placeholder; only a real play
## advances the round-robin cursor.
func play(sound_name: String) -> void:
	var sound: AudioStream = _sounds.get(sound_name)
	if sound == null:
		return  # unknown name or no stream loaded yet
	var player := _sfx_pool[_pool_index]
	player.stream = sound
	player.play()
	_pool_index = (_pool_index + 1) % POOL_SIZE


## Assign (or replace) the stream for an event name. Called once real audio is
## available. `sound_name` avoids shadowing the inherited Node.name property.
func set_sound(sound_name: String, stream: AudioStream) -> void:
	_sounds[sound_name] = stream
