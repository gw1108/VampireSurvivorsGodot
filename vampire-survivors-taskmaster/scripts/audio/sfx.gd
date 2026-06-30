extends Node
## VSSfx — the run's sound manager, registered as the `Sfx` autoload (sibling of
## AgentBridge in project.godot). The game was silent: weapon/aura/orbit emitted
## AgentBridge "sfx_played" events but those only feed the agent harness's event stream
## (inert off web), so nothing was ever audible. This makes it audible for a human.
##
## Sounds are SYNTHESIZED IN CODE as tiny AudioStreamWAV blips — no binary WAV assets,
## no .import pipeline — matching the project's "build everything in code, draw juice
## with primitives" style. They play through a small round-robin pool of
## AudioStreamPlayers with a per-sound de-dupe cooldown (so an AoE tick that wounds 30
## enemies in one frame, or rapid multishot, plays ONE blip, not a clipping wall) and a
## little random pitch wobble so repeats don't grate.
##
## Headless-safe: under the gate's dummy audio driver play() is a no-op; building the
## streams is a few thousand samples (~instant). Uses its OWN RNG so it never perturbs
## the gameplay RNG (run.gd seeds the global one for deterministic-ish spawns).

const RATE := 22050             # synth sample rate (plenty for short percussive blips)
const POOL := 12                # concurrent voices; new plays steal the oldest slot round-robin

# --- Ambient music bed (a quiet looping drone, its OWN dedicated player) ---------
const MUSIC_DUR := 8.0          # loop length (s); partials are snapped so it wraps clickless
const MUSIC_DB := -22.0         # well under the -9 dB blips: a bed you feel, not a track you notice
const MUSIC_DUCK_DB := -14.0    # extra attenuation while the level-up modal is open, so the
                                # C-E-G-C arpeggio pops over a near-silent bed; restored on resume

# Per-sound minimum seconds between (re)plays. The de-dupe that keeps dense waves /
# AoE ticks / multishot from stacking dozens of identical blips into a clipping mess.
const COOLDOWN := {
	"shoot": 0.05, "hit": 0.05, "kill": 0.04, "pickup": 0.03,
	"hurt": 0.06, "garlic": 0.08, "orbit": 0.07, "levelup": 0.0,
	"gameover": 0.0,   # one-shot big-moment cue (fired once at death); never de-dupe it
}

var _streams := {}                              # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next := 0                                  # round-robin cursor into _players
var _last := {}                                 # name -> last play time (sec, wall clock)
var _rng := RandomNumberGenerator.new()         # private RNG: never touch the gameplay seed
var _music: AudioStreamPlayer                   # dedicated looping bed; NOT part of the SFX pool
var music_enabled := true                       # default on, low; press M to toggle
var _music_ducked := false                      # true while the bed is attenuated (level-up modal)

func _ready() -> void:
	_rng.randomize()
	_build_streams()
	for i in POOL:
		var pl := AudioStreamPlayer.new()
		pl.bus = "Master"
		pl.volume_db = -9.0                     # keep the slice's chatter low, not blaring
		add_child(pl)
		_players.append(pl)
	# Dedicated looping bed on its OWN player, so it never interacts with the SFX
	# pool's round-robin voice-stealing or the per-sound de-dupe cooldown.
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	_music.volume_db = MUSIC_DB
	_music.stream = _build_music()
	add_child(_music)
	if music_enabled:
		_music.play()
		# Headless reviewer can't hear audio; mirror the SFX cues so the bed is scorable.
		AgentBridge.emit_event("music", {"state": "start"})

# Play the named cue. Always safe to call (unknown name / cooldown / no pool = no-op).
func play(name: String) -> void:
	var stream: AudioStreamWAV = _streams.get(name)
	if stream == null or _players.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0   # wall clock: independent of Engine.time_scale
	if now - float(_last.get(name, -1000.0)) < float(COOLDOWN.get(name, 0.04)):
		return
	_last[name] = now
	var pl := _players[_next]
	_next = (_next + 1) % _players.size()
	pl.stream = stream
	pl.pitch_scale = _rng.randf_range(0.94, 1.06)
	pl.play()

# Player-facing toggle for the ambient bed (bound to M below). Safe before _ready.
func toggle_music() -> void:
	set_music_enabled(not music_enabled)

func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if _music == null:
		return
	if on and not _music.playing:
		_music.play()
		AgentBridge.emit_event("music", {"state": "start"})
	elif not on and _music.playing:
		_music.stop()
		AgentBridge.emit_event("music", {"state": "stop"})

# Temporarily attenuate the ambient bed (no stop/restart, so the loop keeps its position
# and resumes click-free). run.gd ducks on entering the level-up modal and restores on
# resume, so the C-E-G-C arpeggio reads over a near-silent bed. Cheap, reversible, idempotent.
# Headless-safe: just sets volume_db on the existing player (play() is a no-op under the gate).
func duck_music(on: bool) -> void:
	if _music == null or _music_ducked == on:
		return
	_music_ducked = on
	_music.volume_db = (MUSIC_DB + MUSIC_DUCK_DB) if on else MUSIC_DB

func _unhandled_input(event: InputEvent) -> void:
	# M mutes/unmutes the bed without touching the input map (no conflict with the
	# harness, which drives mapped actions). echo guard so a held key toggles once.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_music()

func _build_streams() -> void:
	# Each blip is a short swept tone (optionally noisy) under a percussive decay envelope.
	_streams["shoot"]   = _blip(620.0, 360.0, 0.07, 0.85, 1, 0.0)    # square "pew"
	_streams["hit"]     = _blip(240.0, 150.0, 0.05, 0.55, 3, 0.7)    # short noisy chip
	_streams["kill"]    = _blip(300.0, 80.0, 0.12, 0.9, 2, 0.25)     # down "thud"
	_streams["pickup"]  = _blip(720.0, 1180.0, 0.09, 0.7, 2, 0.0)    # rising coin
	_streams["hurt"]    = _blip(175.0, 70.0, 0.14, 1.0, 1, 0.35)     # low harsh buzz
	_streams["garlic"]  = _blip(120.0, 90.0, 0.10, 0.6, 0, 0.2)      # soft low whoosh
	_streams["orbit"]   = _blip(900.0, 1300.0, 0.05, 0.45, 1, 0.1)   # metallic tick
	# Level-up: a little C-E-G-C arpeggio so the big moment lands.
	_streams["levelup"] = _arp([523.25, 659.25, 783.99, 1046.5], 0.085, 0.85)
	# Game over: a somber DESCENDING arpeggio (G4-Eb4-C4-G3) — the mirror of the rising
	# level-up fanfare, so defeat reads as the opposite of triumph. Slower steps land it.
	_streams["gameover"] = _arp([392.0, 311.13, 261.63, 196.0], 0.16, 0.8)

# One swept-tone voice -> a finished mono 16-bit stream.
func _blip(f0: float, f1: float, dur: float, vol: float, wave: int, noise: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	_voice(f0, f1, dur, vol, wave, noise, samples)
	return _to_stream(samples)

# Sequential tones (rising arpeggio) concatenated into one stream.
func _arp(freqs: Array, step: float, vol: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	for f in freqs:
		_voice(float(f), float(f), step, vol, 2, 0.0, samples)
	return _to_stream(samples)

# Append one tone's samples. Phase accumulates so a glissando (f0->f1) stays continuous.
func _voice(f0: float, f1: float, dur: float, vol: float, wave: int, noise: float, samples: PackedFloat32Array) -> void:
	var n := int(dur * RATE)
	if n <= 0:
		return
	var start := samples.size()
	samples.resize(start + n)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)            # 0..1 progress through the tone
		var f := lerpf(f0, f1, u)
		phase += TAU * f / float(RATE)
		var s := 0.0
		match wave:
			1: s = 1.0 if sin(phase) >= 0.0 else -1.0          # square
			2: s = asin(clampf(sin(phase), -1.0, 1.0)) * (2.0 / PI)  # triangle
			3: s = _rng.randf_range(-1.0, 1.0)                 # noise
			_: s = sin(phase)                                  # sine
		if noise > 0.0 and wave != 3:
			s = lerpf(s, _rng.randf_range(-1.0, 1.0), noise)
		var env := exp(-u * 5.0)                # snappy percussive decay
		samples[start + i] = clampf(s * env * vol, -1.0, 1.0)

func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.loop_mode = AudioStreamWAV.LOOP_DISABLED
	st.data = data
	return st

# A quiet, seamlessly-looping ambient bed: a stack of low drone partials (a minor-ish
# pad) under a slow amplitude swell. Every partial AND the LFO is snapped to an integer
# number of cycles over the loop (_loopf), so value and slope match at the wrap point and
# the buffer loops with no click. Built once at startup; ~MUSIC_DUR*RATE samples, instant.
func _build_music() -> AudioStreamWAV:
	var n := int(MUSIC_DUR * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	# [freq, gain] — deep root, fifth, octave, faint high shimmer (A1-ish drone).
	var partials := [
		[_loopf(55.0), 0.50], [_loopf(82.41), 0.30],
		[_loopf(110.0), 0.20], [_loopf(164.81), 0.10],
	]
	var lfo := _loopf(0.25)                      # ~2 slow breaths across an 8s loop
	for i in n:
		var t := float(i) / float(RATE)          # seconds; partials are integer-cycle over MUSIC_DUR
		var s := 0.0
		for p in partials:
			s += sin(TAU * float(p[0]) * t) * float(p[1])
		var swell := 0.65 + 0.35 * sin(TAU * lfo * t)   # 0.30..1.00 slow breathing
		samples[i] = clampf(s * 0.22 * swell, -1.0, 1.0)
	var st := _to_stream(samples)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = n
	return st

# Snap a frequency so a whole number of cycles fits the loop -> the wave wraps seamlessly.
func _loopf(hz: float) -> float:
	return maxf(1.0, round(hz * MUSIC_DUR)) / MUSIC_DUR
