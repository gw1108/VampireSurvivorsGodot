extends GdUnitTestSuite

## Golden-path replay: a fixed seed + a recorded frame-indexed input sequence
## driven through the REAL RunController._tick pipeline for a fixed number of
## frames. Two guarantees:
##   - determinism: replaying the same seed+inputs twice yields an identical state;
##   - golden outcome: that state matches a frozen snapshot, so ANY behavioural
##     change in ANY system (movement, spawning, combat, pickups, progression)
##     trips this test. Update EXPECTED_* deliberately when a change is intended.
##
## Level-ups are auto-resolved (always pick option 0) so the run keeps simulating
## headlessly the way a player tapping "first choice" would — exercising stats
## recompute and item acquisition too. The board start is made deterministic by
## clearing start_run's time-seeded spawns and re-running spawn_starting under the
## golden seed.

const GOLDEN_SEED: int = 12345
const GOLDEN_RUN_FRAMES: int = 900  # 15 sim-seconds at 60 Hz

# [frame, input_vector] — input changes take effect at the given frame and hold.
const GOLDEN_INPUT_SEQUENCE: Array = [
	[0, Vector2.RIGHT],
	[90, Vector2.DOWN],
	[180, Vector2.LEFT],
	[270, Vector2.UP],
	[360, Vector2(1, 1)],
	[450, Vector2(-1, 1)],
	[540, Vector2(-1, -1)],
	[630, Vector2(1, -1)],
	[720, Vector2.ZERO],
	[810, Vector2.RIGHT],
]

# --- frozen golden outcome (captured from a real run of this seed+sequence) ---
# If an INTENTIONAL system change moves these, re-capture from the [golden] print
# line below and update them in the same commit.
const EXPECTED_KILLS: int = 65
const EXPECTED_LEVEL: int = 4
const EXPECTED_GOLD: int = 0
const EXPECTED_WEAPONS: int = 2  # task-29: some level-ups now grant passives instead
const EXPECTED_PASSIVES: int = 1
const EXPECTED_PENDING_LEVELUPS: int = 0


func _run() -> RunController:
	return auto_free(RunController.new())


## Build a fully deterministic run: real Antonio player, but the time-seeded
## starting board is discarded and rebuilt under GOLDEN_SEED.
func _start_golden(rc: RunController) -> void:
	rc.start_run("antonio")
	rc.state.enemies.clear()
	rc.state.gems.clear()
	rc.state.pickups.clear()
	rc.state.projectiles.clear()
	rc.state.zones.clear()
	rc.state.spawn_cursor = 0
	rc.state.spawn_timer = 0.0
	rc.state.time_elapsed = 0.0
	rc.state.current_minute = 0
	rc.state.kills = 0
	rc.state.gold = 0
	rc.state.rng.seed = GOLDEN_SEED  # also resets the generator's state
	SpawnDirector.spawn_starting(rc.state, rc._stage_def)  # deterministic starting board


func _run_golden_path(_seed: int) -> GameState:
	var rc := _run()
	_start_golden(rc)

	var frame := 0
	var input_idx := 0
	var current_input := Vector2.ZERO
	while frame < GOLDEN_RUN_FRAMES and rc.state.phase != GameState.Phase.GAME_OVER:
		# Apply any input scheduled exactly at this frame.
		if input_idx < GOLDEN_INPUT_SEQUENCE.size() and GOLDEN_INPUT_SEQUENCE[input_idx][0] == frame:
			current_input = GOLDEN_INPUT_SEQUENCE[input_idx][1]
			input_idx += 1

		rc._tick(1.0 / 60.0, current_input)

		# Auto-resolve any queued level-up (pick the first option) so the run keeps
		# flowing, mirroring a player who always takes choice 0.
		var guard := 0
		while rc.state.phase == GameState.Phase.LEVEL_UP and guard < 50:
			rc.on_option_chosen(0)
			guard += 1

		frame += 1
	return rc.state


# --- determinism: same seed + same inputs -> identical state ---

func test_golden_path_determinism() -> void:
	var a := _run_golden_path(GOLDEN_SEED)
	var b := _run_golden_path(GOLDEN_SEED)
	assert_float(a.time_elapsed).is_equal(b.time_elapsed)
	assert_int(a.kills).is_equal(b.kills)
	assert_int(a.gold).is_equal(b.gold)
	assert_int(a.player.level).is_equal(b.player.level)
	assert_int(a.pending_levelups).is_equal(b.pending_levelups)
	assert_int(a.enemies.size()).is_equal(b.enemies.size())
	assert_int(a.gems.size()).is_equal(b.gems.size())
	assert_vector(a.player.pos).is_equal(b.player.pos)
	assert_float(a.player.hp).is_equal(b.player.hp)


# --- golden outcome (capture pass prints the values to freeze) ---

func test_golden_path_expected_outcome() -> void:
	var s := _run_golden_path(GOLDEN_SEED)
	# Diagnostic line — read this to re-capture EXPECTED_* if a change is intentional.
	prints("[golden] frames=%d kills=%d level=%d gold=%d phase=%d hp=%.4f pos=%s enemies=%d gems=%d pending=%d xp=%.4f weapons=%d passives=%d"
		% [GOLDEN_RUN_FRAMES, s.kills, s.player.level, s.gold, s.phase, s.player.hp,
			str(s.player.pos), s.enemies.size(), s.gems.size(), s.pending_levelups,
			s.player.xp, s.player.weapons.size(), s.player.passives.size()])

	# The run completed all frames without dying (stayed in PLAYING).
	assert_int(s.phase).is_equal(GameState.Phase.PLAYING)
	# Frozen golden outcome for GOLDEN_SEED + GOLDEN_INPUT_SEQUENCE.
	assert_int(s.kills).is_equal(EXPECTED_KILLS)
	assert_int(s.player.level).is_equal(EXPECTED_LEVEL)
	assert_int(s.gold).is_equal(EXPECTED_GOLD)
	assert_int(s.player.weapons.size()).is_equal(EXPECTED_WEAPONS)
	assert_int(s.player.passives.size()).is_equal(EXPECTED_PASSIVES)
	assert_int(s.pending_levelups).is_equal(EXPECTED_PENDING_LEVELUPS)
