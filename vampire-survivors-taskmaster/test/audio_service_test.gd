extends GdUnitTestSuite

## Tests the AudioService autoload stub (task 26): the SFX pool is built at
## startup, set_sound stores a stream, play() advances the round-robin cursor only
## when a real stream is loaded, and unknown/placeholder names are a safe no-op.
## State is reset before each test since AudioService is a shared singleton.

func before_test() -> void:
	AudioService._pool_index = 0
	for key in AudioService._sounds.keys():
		AudioService._sounds[key] = null


func _dummy_stream() -> AudioStream:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = 22050
	s.data = PackedByteArray([0, 0, 0, 0])
	return s


func test_pool_built_at_startup() -> void:
	assert_int(AudioService._sfx_pool.size()).is_equal(AudioService.POOL_SIZE)
	for p in AudioService._sfx_pool:
		assert_bool(p is AudioStreamPlayer).is_true()


func test_play_placeholder_sound_is_noop() -> void:
	AudioService.play("hit")  # known name, stream still null
	assert_int(AudioService._pool_index).is_equal(0)


func test_play_unknown_name_is_noop() -> void:
	AudioService.play("does_not_exist")
	assert_int(AudioService._pool_index).is_equal(0)


func test_set_sound_stores_stream() -> void:
	var s := _dummy_stream()
	AudioService.set_sound("hit", s)
	assert_object(AudioService._sounds.get("hit")).is_same(s)


func test_play_loaded_sound_advances_one_step() -> void:
	AudioService.set_sound("pickup", _dummy_stream())
	AudioService.play("pickup")
	assert_int(AudioService._pool_index).is_equal(1)


func test_play_wraps_round_robin() -> void:
	AudioService.set_sound("hit", _dummy_stream())
	for i in AudioService.POOL_SIZE:
		AudioService.play("hit")
	assert_int(AudioService._pool_index).is_equal(0)  # wrapped back to start
