extends SceneTree

## Headless test for the Task 21 AudioManager autoload (placeholder).
##   godot --headless --path . --script res://test/audio_manager_test.gd
## Exit code == number of failed checks (0 == all passed).
## Runs in _process so the autoload node + its AudioStreamPlayer children and the
## audio buses are live. The global identifier AudioManager is not resolvable in
## --script mode, so we reach the autoload via /root/AudioManager.

var _failures := 0
var _passes := 0
var _ran := false

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	print("== audio_manager_test ==")
	var am = root.get_node_or_null("AudioManager")
	_check(am != null, "AudioManager autoload present at /root/AudioManager")
	if am == null:
		print("== %d passed, %d failed ==" % [_passes, _failures])
		quit(_failures)
		return true

	# Buses defined by default_bus_layout.tres.
	_check(AudioServer.get_bus_index(&"SFX") != -1, "SFX bus exists")
	_check(AudioServer.get_bus_index(&"Music") != -1, "Music bus exists")

	# Pool + music player wired up.
	_check(am.sfx_pool.size() == am.POOL_SIZE, "SFX pool sized to POOL_SIZE (%d)" % am.POOL_SIZE)
	_check(am.sfx_pool[0] is AudioStreamPlayer, "pool holds AudioStreamPlayers")
	_check(am.sfx_pool[0].bus == &"SFX", "pool voices routed to the SFX bus")
	_check(am.sfx_pool[0].get_parent() == am, "pool voices parented to the manager")
	_check(am.music_player is AudioStreamPlayer, "music player created")
	_check(am.music_player.bus == &"Music", "music player routed to the Music bus")

	# play() with no stream mapped is a safe no-op.
	am.sfx_hit = null
	_check(am.play(&"hit") == null, "play() with no stream returns null (no-op)")
	_check(am.play(&"unknown_event") == null, "play() with unknown event returns null")

	# play() with a stream picks a free voice and routes the stream onto it.
	var dummy := AudioStreamWAV.new()
	dummy.format = AudioStreamWAV.FORMAT_8_BITS
	dummy.mix_rate = 22050
	dummy.data = PackedByteArray([0, 0, 0, 0])
	am.sfx_hit = dummy
	var voice = am.play(&"hit")
	_check(voice != null, "play() with a mapped stream returns a voice")
	_check(voice != null and voice.stream == dummy, "voice plays the mapped stream")
	_check(am.sfx_pool.has(voice), "the voice is one of the pool players")

	# play_music is a no-op without a track but does not crash; stop_music safe.
	am.music_stage = null
	am.play_music(&"stage")
	_check(am.music_player.playing == false, "play_music with no stream stays stopped")
	am.stop_music()  # must not crash
	_check(true, "stop_music is safe")

	# leave the pool idle
	for p in am.sfx_pool:
		p.stop()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)
	return true

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)
