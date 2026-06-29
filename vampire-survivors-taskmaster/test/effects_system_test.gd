extends SceneTree

## Headless test runner for the Task 11 EffectsSystem.
##   godot --headless --path . --script res://test/effects_system_test.gd
## Exit code == number of failed checks (0 == all passed).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== effects_system_test ==")
	_test_chicken()
	_test_gold()
	_test_rosary()
	_test_orologion_nduja()
	_test_vacuum()
	_test_rerollo()
	_test_tick_freeze()
	_test_tick_firebreath()
	print("== %d passed, %d failed ==" % [_passes, _failures])
	quit(_failures)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		printerr("  FAIL: ", msg)

func _approx(a: float, b: float, msg: String) -> void:
	_check(is_equal_approx(a, b), "%s (got %f, want %f)" % [msg, a, b])

func _state() -> RunState:
	var st := RunState.new()
	st.player = PlayerState.new()
	st.player.pos = Vector2.ZERO
	StatSystem.recompute(st.player, GDB)  # max_health 120, greed 1, might 1, luck 1
	st.enemies = EnemyPool.new()
	st.projectiles = ProjectilePool.new()
	st.pickups = PickupPool.new()
	st.rng = RandomNumberGenerator.new()
	st.rng.seed = 1
	return st

func _add_enemy(st: RunState, id: StringName) -> int:
	return st.enemies.spawn(id, Vector2(50, 0), GDB.enemy(id))

func _test_chicken() -> void:
	var st := _state()
	st.player.hp = 50.0
	EffectsSystem.apply_pickup(st, PickupPool.Kind.CHICKEN, 0.0)
	_approx(st.player.hp, 80.0, "chicken heals 30")
	st.player.hp = 110.0
	EffectsSystem.apply_pickup(st, PickupPool.Kind.CHICKEN, 0.0)
	_approx(st.player.hp, 120.0, "chicken clamps to max_health 120")

func _test_gold() -> void:
	var st := _state()
	EffectsSystem.apply_pickup(st, PickupPool.Kind.GOLD, 10.0)
	_check(st.player.gold == 10, "gold adds value at greed 1")
	st.player.stats.greed = 2.0
	EffectsSystem.apply_pickup(st, PickupPool.Kind.GOLD, 10.0)
	_check(st.player.gold == 30, "gold scales by greed (10 + 10*2)")

func _test_rosary() -> void:
	var st := _state()
	_add_enemy(st, &"zombie")
	_add_enemy(st, &"skeleton")
	_add_enemy(st, &"ghost")
	_add_enemy(st, &"reaper")  # immune
	EffectsSystem.apply_pickup(st, PickupPool.Kind.ROSARY, 0.0)
	_check(st.enemies.active_count == 1, "Rosary clears all non-immune enemies")
	# the surviving one is the Reaper
	var reaper_alive := false
	for i in EnemyPool.CAPACITY:
		if st.enemies.alive[i] and st.enemies.type_id[i] == &"reaper":
			reaper_alive = true
	_check(reaper_alive, "Rosary spares the immune Reaper")
	_check(st.pickups.gem_count == 0, "Rosary grants no gems")

func _test_orologion_nduja() -> void:
	var st := _state()
	EffectsSystem.apply_pickup(st, PickupPool.Kind.OROLOGION, 0.0)
	_approx(st.freeze_timer, EffectsSystem.FREEZE_DURATION, "Orologion sets freeze_timer to 10")
	EffectsSystem.apply_pickup(st, PickupPool.Kind.NDUJA, 0.0)
	_approx(st.firebreath_timer, EffectsSystem.FIREBREATH_DURATION, "Nduja sets firebreath_timer to 10")

func _test_vacuum() -> void:
	var st := _state()
	var g1: int = st.pickups.spawn(PickupPool.Kind.GEM, Vector2(300, 0), 1.0, PickupPool.GemTier.BLUE)
	var g2: int = st.pickups.spawn(PickupPool.Kind.GEM, Vector2(-300, 0), 1.0, PickupPool.GemTier.BLUE)
	var gold: int = st.pickups.spawn(PickupPool.Kind.GOLD, Vector2(0, 300), 5.0)
	EffectsSystem.apply_pickup(st, PickupPool.Kind.VACUUM, 0.0)
	_check(st.pickups.magnetized[g1] and st.pickups.magnetized[g2], "Vacuum magnetizes all gems")
	_check(not st.pickups.magnetized[gold], "Vacuum leaves non-gem pickups alone")

func _test_rerollo() -> void:
	var st := _state()
	EffectsSystem.apply_pickup(st, PickupPool.Kind.REROLLO, 0.0)
	EffectsSystem.apply_pickup(st, PickupPool.Kind.REROLLO, 0.0)
	_check(st.player.reroll_charges == 2, "Rerollo grants a reroll charge each")

func _test_tick_freeze() -> void:
	var st := _state()
	st.freeze_timer = 0.25
	EffectsSystem.tick_effects(st, 0.1)
	_approx(st.freeze_timer, 0.15, "freeze_timer decays by delta")
	EffectsSystem.tick_effects(st, 1.0)
	_approx(st.freeze_timer, 0.0, "freeze_timer floors at 0")

func _test_tick_firebreath() -> void:
	var st := _state()
	st.player.stats.might = 3.0  # must NOT be baked into stored damage
	st.firebreath_timer = 10.0
	EffectsSystem.tick_effects(st, 0.1)
	_approx(st.firebreath_timer, 9.9, "firebreath_timer decays")
	_check(st.projectiles.active_count == 1, "active fire-breath emits one aura per tick")
	# find the emitted projectile
	var p := -1
	for i in ProjectilePool.CAPACITY:
		if st.projectiles.alive[i]:
			p = i
			break
	_approx(st.projectiles.damage[p], 20.0, "fire-breath damage is base 20 (pre-Might; collision scales)")
	_check(st.projectiles.behavior[p] == ProjectilePool.Behavior.AURA, "fire-breath is an AURA")
	_check(st.projectiles.pierce_left[p] == -1, "fire-breath is AoE (pierce -1)")
	_approx(st.projectiles.area_scale[p], EffectsSystem.FIREBREATH_AREA, "fire-breath area 1.5")
	# once the timer hits 0, no more emits
	st.firebreath_timer = 0.05
	EffectsSystem.tick_effects(st, 0.1)  # zeroes it but still emits this tick
	EffectsSystem.tick_effects(st, 0.1)  # timer already 0 -> no emit
	_check(st.projectiles.active_count == 2, "no emit once fire-breath has expired")
