extends GdUnitTestSuite

## Tests the chest system (task 30): beginner's-luck count sequence, luck-scaled
## counts afterwards, chest opening (item application + gold when maxed), boss-death
## chest drops in CombatSystem, and chest opening on pickup in PickupSystem.

func _state() -> GameState:
	var gs := GameState.new()
	gs.index = SpatialIndex.new()
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	return gs


func _synthetic_weapon(id: String, level: int) -> WeaponInstance:
	var w := WeaponInstance.new()
	var d := WeaponDef.new()
	d.id = id
	w.def = d
	w.level = level
	return w


func _synthetic_passive(id: String, level: int) -> PassiveInstance:
	var p := PassiveInstance.new()
	var d := PassiveDef.new()
	d.id = id
	d.max_level = level
	p.def = d
	p.level = level
	return p


func _boss(pos: Vector2, boss := true) -> Enemy:
	var e := Enemy.new()
	e.pos = pos
	e.hp = 1.0
	e.is_boss = boss
	var d := EnemyDef.new()
	d.id = "boss"
	d.xp_value = 10.0
	e.def = d
	return e


func _killing_projectile(pos: Vector2) -> Projectile:
	var p := Projectile.new()
	p.pos = pos
	p.damage = 1000.0
	p.pierce_left = 1
	p.lifetime = 1.0
	return p


# --- determine_chest_count ---

func test_beginners_luck_sequence() -> void:
	var gs := _state()
	var counts: Array = []
	for i in ProgressionSystem.BEGINNER_LUCK_SEQUENCE.size():
		gs.chest_count = i
		counts.append(ProgressionSystem.determine_chest_count(gs))
	assert_array(counts).is_equal([1, 1, 3, 1, 1, 5])


func test_high_luck_after_sequence_gives_five() -> void:
	var gs := _state()
	gs.chest_count = ProgressionSystem.BEGINNER_LUCK_SEQUENCE.size()  # past the script
	gs.player.derived.luck = 100.0  # 0.1 * 100 = 10 > any randf() -> always 5
	assert_int(ProgressionSystem.determine_chest_count(gs)).is_equal(5)


func test_count_after_sequence_in_valid_range() -> void:
	var gs := _state()
	gs.chest_count = ProgressionSystem.BEGINNER_LUCK_SEQUENCE.size()
	gs.player.derived.luck = 1.0
	gs.rng.seed = 12345
	var c := ProgressionSystem.determine_chest_count(gs)
	assert_bool(c == 1 or c == 3 or c == 5).is_true()


# --- open_chest ---

func test_open_chest_applies_items() -> void:
	var gs := _state()  # empty inventory -> pool non-empty
	var chest := Chest.new()
	chest.rolled_count = 3
	var results := ProgressionSystem.open_chest(gs, chest)
	assert_int(results.size()).is_equal(3)
	for r in results:
		assert_bool(r.has("type") and r["type"] == "gold").is_false()  # not maxed -> real items
	assert_int(gs.player.weapons.size() + gs.player.passives.size()).is_greater_equal(1)


func test_open_chest_single_item_enters_inventory() -> void:
	var gs := _state()
	var chest := Chest.new()
	chest.rolled_count = 1
	ProgressionSystem.open_chest(gs, chest)
	assert_int(gs.player.weapons.size() + gs.player.passives.size()).is_equal(1)


func test_open_chest_gives_gold_when_maxed() -> void:
	var gs := _state()
	for i in ProgressionSystem.MAX_WEAPONS:
		gs.player.weapons.append(_synthetic_weapon("w%d" % i, ProgressionSystem.WEAPON_MAX_LEVEL))
	for i in ProgressionSystem.MAX_PASSIVES:
		gs.player.passives.append(_synthetic_passive("p%d" % i, 5))
	var chest := Chest.new()
	chest.rolled_count = 2
	var results := ProgressionSystem.open_chest(gs, chest)
	assert_int(results.size()).is_equal(2)
	assert_int(gs.gold).is_equal(2 * ProgressionSystem.CHEST_GOLD_REWARD)
	for r in results:
		assert_str(r["type"]).is_equal("gold")


# --- CombatSystem: boss death drops a chest ---

func test_boss_death_spawns_chest() -> void:
	var gs := _state()
	gs.enemies.append(_boss(Vector2.ZERO))
	gs.projectiles.append(_killing_projectile(Vector2.ZERO))
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	CombatSystem.step(gs, 0.016)
	assert_int(gs.enemies.size()).is_equal(0)        # boss killed
	assert_int(gs.chests.size()).is_equal(1)         # chest dropped
	assert_int(gs.chests[0].rolled_count).is_equal(1)  # first chest -> beginner luck[0]


func test_normal_death_does_not_spawn_chest() -> void:
	var gs := _state()
	gs.enemies.append(_boss(Vector2.ZERO, false))  # not a boss
	gs.projectiles.append(_killing_projectile(Vector2.ZERO))
	SpatialIndex.rebuild(gs.index, gs.enemies, gs.gems, gs.pickups)
	CombatSystem.step(gs, 0.016)
	assert_int(gs.enemies.size()).is_equal(0)
	assert_int(gs.chests.size()).is_equal(0)


# --- PickupSystem: walking over a chest opens it ---

func test_pickup_opens_chest() -> void:
	var gs := _state()
	var chest := Chest.new()
	chest.pos = gs.player.pos
	chest.rolled_count = 1
	gs.chests.append(chest)
	PickupSystem.step(gs, 0.016)
	assert_int(gs.chests.size()).is_equal(0)       # collected + removed
	assert_int(gs.chest_count).is_equal(1)         # counter bumped
	assert_int(gs.player.weapons.size() + gs.player.passives.size()).is_equal(1)  # item applied
