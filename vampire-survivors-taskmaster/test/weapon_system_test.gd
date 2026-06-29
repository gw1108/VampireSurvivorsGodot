extends SceneTree

## Headless test runner for the Task 8 WeaponSystem.
##   godot --headless --path . --script res://test/weapon_system_test.gd
## Exit code == number of failed checks (0 == all passed).
## Uses the GameDatabase script class as `db` (weapon() is static -> clean call).

const GDB := preload("res://autoload/game_database.gd")

var _failures := 0
var _passes := 0

func _initialize() -> void:
	print("== weapon_system_test ==")
	_test_cooldown_gating()
	_test_whip_basic()
	_test_damage_excludes_might()
	_test_amount_scaling()
	_test_level_resolution()
	_test_cooldown_scaling()
	_test_magic_wand_aims_nearest()
	_test_magic_wand_no_enemy()
	_test_garlic_single_aura()
	_test_king_bible_orbit()
	_test_runetracer_bounce()
	_test_fire_and_lightning()
	_test_no_weapons()
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

# --- fixtures ----------------------------------------------------------------

func _state() -> RunState:
	var st := RunState.new()
	st.player = PlayerState.new()
	st.player.pos = Vector2.ZERO
	st.player.facing = Vector2.RIGHT
	StatSystem.recompute(st.player, GDB)  # neutral stats: might 1, amount 0, area 1, speed 1, cooldown 1
	st.enemies = EnemyPool.new()
	st.projectiles = ProjectilePool.new()
	st.rng = RandomNumberGenerator.new()
	st.rng.seed = 1
	st.camera_world_rect = Rect2(-500, -500, 1000, 1000)
	return st

func _add_weapon(st: RunState, id: StringName, level: int) -> void:
	var w := WeaponInstance.new()
	w.id = id
	w.level = level
	st.player.weapons.append(w)

func _add_enemy(st: RunState, pos: Vector2) -> int:
	return st.enemies.spawn(&"zombie", pos, GDB.enemy(&"zombie"))

func _alive_projs(st: RunState, owner: StringName = &"") -> Array:
	var out: Array = []
	for i in ProjectilePool.CAPACITY:
		if st.projectiles.alive[i] and (owner == &"" or st.projectiles.owner_weapon[i] == owner):
			out.append(i)
	return out

# --- tests -------------------------------------------------------------------

func _test_cooldown_gating() -> void:
	var st := _state()
	_add_weapon(st, &"whip", 1)
	WeaponSystem.step(st, GDB, 0.016)  # timer starts 0 -> fires immediately
	var after_first: int = st.projectiles.active_count
	_check(after_first == 1, "first step fires the weapon (timer started at 0)")
	WeaponSystem.step(st, GDB, 0.016)  # timer ~1.35 now -> should NOT fire
	_check(st.projectiles.active_count == after_first, "weapon does not re-fire before cooldown elapses")
	# advance past the whip cooldown and it fires again
	WeaponSystem.step(st, GDB, 2.0)
	_check(st.projectiles.active_count == after_first + 1, "weapon fires again once cooldown elapses")

func _test_whip_basic() -> void:
	var st := _state()
	_add_weapon(st, &"whip", 1)
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"whip")
	_check(ps.size() == 1, "whip L1 spawns one slash")
	var p: int = ps[0]
	_check(st.projectiles.pos[p] == Vector2(WeaponSystem.WHIP_RANGE, 0.0), "whip slash offset along facing")
	_check(st.projectiles.vel[p] == Vector2.ZERO, "whip slash is stationary")
	_check(st.projectiles.pierce_left[p] == -1, "whip pierces all (-1)")
	_check(st.projectiles.behavior[p] == ProjectilePool.Behavior.STRAIGHT, "whip uses STRAIGHT (stays put)")
	_approx(st.projectiles.area_scale[p], 1.0, "whip area_scale == stats.area (1.0)")

func _test_damage_excludes_might() -> void:
	# Damage stored must be the level-resolved BASE; Might is applied by collision.
	var st := _state()
	st.player.stats.might = 5.0
	_add_weapon(st, &"whip", 1)
	WeaponSystem.step(st, GDB, 0.016)
	var p: int = _alive_projs(st, &"whip")[0]
	_approx(st.projectiles.damage[p], 10.0, "whip damage is base 10, NOT 10*might (collision scales Might)")

func _test_amount_scaling() -> void:
	var st := _state()
	st.player.stats.amount = 2.0  # +2 projectiles
	_add_weapon(st, &"knife", 1)  # base amount 1 -> 3
	WeaponSystem.step(st, GDB, 0.016)
	_check(_alive_projs(st, &"knife").size() == 3, "stats.amount adds projectiles (1 base + 2 = 3 knives)")

func _test_level_resolution() -> void:
	# Whip L3: deltas L2{amount+1}, L3{dmg+5} -> 2 slashes, damage 15.
	var st := _state()
	_add_weapon(st, &"whip", 3)
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"whip")
	_check(ps.size() == 2, "whip L3 fires 2 slashes (level-2 amount delta applied)")
	_approx(st.projectiles.damage[ps[0]], 15.0, "whip L3 damage 10 + level-3 dmg delta 5 = 15")
	# second slash fires backward (alternating front/back)
	var positions := [st.projectiles.pos[ps[0]], st.projectiles.pos[ps[1]]]
	_check(Vector2(WeaponSystem.WHIP_RANGE, 0.0) in positions and Vector2(-WeaponSystem.WHIP_RANGE, 0.0) in positions,
		"whip slashes alternate front and back")

func _test_cooldown_scaling() -> void:
	# Magic Wand L3 base cooldown 1.2 + (-0.2 delta) = 1.0; stats.cooldown 0.5 -> 0.5.
	var st := _state()
	st.player.stats.cooldown = 0.5
	_add_enemy(st, Vector2(100, 0))
	_add_weapon(st, &"magic_wand", 3)
	WeaponSystem.step(st, GDB, 0.016)
	_approx(st.player.weapons[0].cooldown_timer, 0.5, "cooldown = (1.2 - 0.2) * 0.5 stats.cooldown")

func _test_magic_wand_aims_nearest() -> void:
	var st := _state()
	_add_enemy(st, Vector2(200, 0))   # to the right -> bolt should travel +x
	_add_enemy(st, Vector2(0, 500))   # farther
	_add_weapon(st, &"magic_wand", 1)
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"magic_wand")
	_check(ps.size() == 1, "magic wand L1 fires one bolt")
	_check(st.projectiles.vel[ps[0]].x > 0.0 and is_zero_approx(st.projectiles.vel[ps[0]].y),
		"magic wand bolt aims at the nearest enemy (+x)")
	_check(st.projectiles.pierce_left[ps[0]] == 1, "magic wand bolt pierces 1")

func _test_magic_wand_no_enemy() -> void:
	var st := _state()
	_add_weapon(st, &"magic_wand", 1)
	WeaponSystem.step(st, GDB, 0.016)
	_check(_alive_projs(st, &"magic_wand").is_empty(), "magic wand spawns nothing with no enemies")

func _test_garlic_single_aura() -> void:
	var st := _state()
	st.player.stats.amount = 5.0  # must NOT multiply the aura
	_add_weapon(st, &"garlic", 1)
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"garlic")
	_check(ps.size() == 1, "garlic spawns exactly one aura regardless of amount")
	_check(st.projectiles.behavior[ps[0]] == ProjectilePool.Behavior.AURA, "garlic uses AURA (follows player)")
	_check(st.projectiles.pierce_left[ps[0]] == -1, "garlic aura pierces all (-1)")

func _test_king_bible_orbit() -> void:
	var st := _state()
	_add_weapon(st, &"king_bible", 2)  # base amount 1 + L2 amount delta 1 = 2
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"king_bible")
	_check(ps.size() == 2, "king bible L2 spawns 2 orbiting bibles")
	for p in ps:
		_check(st.projectiles.behavior[p] == ProjectilePool.Behavior.ORBIT, "bible uses ORBIT")
		_check(st.projectiles.pierce_left[p] == -1, "bible pierces all (-1)")
		_check(st.projectiles.hit_cooldown[p] > 0.0, "bible has a re-tick cooldown")
		_approx(st.player.pos.distance_to(st.projectiles.pos[p]), WeaponSystem.BIBLE_RADIUS, "bible spawns at orbit radius")

func _test_runetracer_bounce() -> void:
	var st := _state()
	_add_weapon(st, &"runetracer", 1)
	WeaponSystem.step(st, GDB, 0.016)
	var ps := _alive_projs(st, &"runetracer")
	_check(ps.size() == 1, "runetracer L1 fires one shot")
	_check(st.projectiles.behavior[ps[0]] == ProjectilePool.Behavior.BOUNCE, "runetracer uses BOUNCE")
	_check(st.projectiles.pierce_left[ps[0]] == -1, "runetracer pierces all (-1)")
	_approx(st.projectiles.lifetime[ps[0]], 2.25, "runetracer lifetime == base duration 2.25")
	_approx(st.projectiles.vel[ps[0]].length(), WeaponSystem.BASE_PROJ_SPEED, "runetracer speed == base * 1.0 mults")

func _test_fire_and_lightning() -> void:
	var st := _state()
	_add_enemy(st, Vector2(150, 0))
	_add_weapon(st, &"fire_wand", 1)        # base amount 3
	_add_weapon(st, &"lightning_ring", 1)   # base amount 2
	WeaponSystem.step(st, GDB, 0.016)
	_check(_alive_projs(st, &"fire_wand").size() == 3, "fire wand fires 3 fireballs")
	var fl := _alive_projs(st, &"fire_wand")
	_check(st.projectiles.pierce_left[fl[0]] == 1, "fireball pierces 1")
	_approx(st.projectiles.damage[fl[0]], 20.0, "fireball base damage 20")
	var ls := _alive_projs(st, &"lightning_ring")
	_check(ls.size() == 2, "lightning ring strikes 2 times")
	_check(st.projectiles.pierce_left[ls[0]] == -1, "lightning strike is AoE (-1)")
	_check(st.projectiles.vel[ls[0]] == Vector2.ZERO, "lightning strike is stationary")

func _test_no_weapons() -> void:
	var st := _state()  # no weapons
	WeaponSystem.step(st, GDB, 0.016)
	_check(st.projectiles.active_count == 0, "no weapons -> no projectiles, no error")
