extends Node

## GameDatabase — read-only authored constants; the single source of truth for
## all game data. Registered as the `GameDatabase` autoload.
##
## All data is held in `const` containers (read-only at runtime); accessors are
## `static func` so pure systems can call `GameDatabase.weapon(id)` etc. Numbers
## are carried verbatim from the offline Vampire Survivors wiki
## (.firecrawl/wiki-offline/) and the project GDD
## (thoughts/shared/game-design/2026-06-25-ENG-vampire-survivors-clone.md);
## deviations for this slice are noted inline.
##
## WEAPON LEVEL CONVENTION: each weapon's `levels` is an 8-element array indexed
## by (level - 1); `levels[0]` is the level-1 base (empty delta). To resolve a
## weapon at level N, start from the base stats and add the deltas in
## `levels[1] .. levels[N-1]`. Delta keys:
##   dmg      flat damage added to base_dmg
##   amount   flat projectile count added to base amount (int)
##   area     additive to the area multiplier (0.1 == +10%)
##   speed    additive to the projectile-speed multiplier (0.2 == +20%)
##   cooldown seconds added to base cooldown (negative == faster)
##   duration seconds added to base duration
##   pierce   flat hits added to base pierce (int)
## `pierce = -1` on a base means infinite pierce / area-of-effect.

# ===================== Weapons (8) =====================
const WEAPONS := {
	&"whip": {
		name = "Whip", base_dmg = 10.0, cooldown = 1.35, amount = 1, area = 1.0,
		speed = 1.0, duration = 0.0, pierce = -1, knockback = 1.0, pattern = "slash",
		levels = [
			{},
			{amount = 1},
			{dmg = 5.0},
			{area = 0.1, dmg = 5.0},
			{dmg = 5.0},
			{area = 0.1, dmg = 5.0},
			{dmg = 5.0},
			{dmg = 5.0},
		],
	},
	&"knife": {
		name = "Knife", base_dmg = 6.5, cooldown = 1.0, amount = 1, area = 1.0,
		speed = 1.0, duration = 0.0, pierce = 1, knockback = 0.5, pattern = "directional",
		# Note: wiki also lowers firing interval at L4/L6/L8 (-0.06s total); the
		# per-level interval deltas are footnoted but not individually stated, so
		# only the explicit amount/damage/pierce deltas are modeled here.
		levels = [
			{},
			{amount = 1},
			{amount = 1, dmg = 5.0},
			{amount = 1},
			{pierce = 1},
			{amount = 1},
			{amount = 1, dmg = 5.0},
			{pierce = 1},
		],
	},
	&"magic_wand": {
		name = "Magic Wand", base_dmg = 10.0, cooldown = 1.2, amount = 1, area = 1.0,
		speed = 1.0, duration = 0.0, pierce = 1, knockback = 1.0, pattern = "nearest",
		levels = [
			{},
			{amount = 1},
			{cooldown = -0.2},
			{amount = 1},
			{dmg = 10.0},
			{amount = 1},
			{pierce = 1},
			{dmg = 10.0},
		],
	},
	&"runetracer": {
		name = "Runetracer", base_dmg = 10.0, cooldown = 3.0, amount = 1, area = 1.0,
		speed = 1.0, duration = 2.25, pierce = -1, knockback = 1.0, pattern = "bounce",
		# Wiki table duration deltas sum to +1.1s; the max-stat summary lists +1.0s
		# (L3/L6 entries footnoted). Table deltas used verbatim below.
		levels = [
			{},
			{dmg = 5.0, speed = 0.2},
			{duration = 0.3, dmg = 5.0},
			{amount = 1},
			{dmg = 5.0, speed = 0.2},
			{duration = 0.3, dmg = 5.0},
			{amount = 1},
			{duration = 0.5},
		],
	},
	&"garlic": {
		name = "Garlic", base_dmg = 5.0, cooldown = 1.3, amount = 0, area = 1.0,
		speed = 1.0, duration = 0.0, pierce = -1, knockback = 0.0, pattern = "aura",
		levels = [
			{},
			{area = 0.4, dmg = 2.0},
			{cooldown = -0.1, dmg = 1.0},
			{area = 0.2, dmg = 1.0},
			{cooldown = -0.1, dmg = 2.0},
			{area = 0.2, dmg = 1.0},
			{cooldown = -0.1, dmg = 1.0},
			{area = 0.2, dmg = 2.0},
		],
	},
	&"king_bible": {
		name = "King Bible", base_dmg = 10.0, cooldown = 3.0, amount = 1, area = 1.0,
		speed = 1.0, duration = 3.0, pierce = -1, knockback = 1.0, pattern = "orbit",
		levels = [
			{},
			{amount = 1},
			{area = 0.25, speed = 0.3},
			{duration = 0.5, dmg = 10.0},
			{amount = 1},
			{area = 0.25, speed = 0.3},
			{duration = 0.5, dmg = 10.0},
			{amount = 1},
		],
	},
	&"fire_wand": {
		name = "Fire Wand", base_dmg = 20.0, cooldown = 3.0, amount = 3, area = 1.0,
		speed = 0.75, duration = 0.0, pierce = 1, knockback = 1.0, pattern = "random",
		levels = [
			{},
			{dmg = 10.0},
			{dmg = 10.0, speed = 0.2},
			{dmg = 10.0},
			{dmg = 10.0, speed = 0.2},
			{dmg = 10.0},
			{dmg = 10.0, speed = 0.2},
			{dmg = 10.0},
		],
	},
	&"lightning_ring": {
		name = "Lightning Ring", base_dmg = 15.0, cooldown = 4.5, amount = 2, area = 1.0,
		speed = 1.0, duration = 0.0, pierce = -1, knockback = 1.0, pattern = "strike_random",
		levels = [
			{},
			{amount = 1},
			{area = 1.0, dmg = 10.0},
			{amount = 1},
			{area = 1.0, dmg = 20.0},
			{amount = 1},
			{area = 1.0, dmg = 20.0},
			{amount = 1},
		],
	},
}

# ===================== Passives (8) =====================
# stat: which StatBlock field this boosts. per_level: value gained each level.
# stacking: "additive" or "multiplicative" (Hollow Heart multiplies Max HP x1.2).
const PASSIVES := {
	&"spinach": { name = "Spinach", stat = "might", per_level = 0.10, max_level = 5, stacking = "additive" },
	&"armor": { name = "Armor", stat = "armor", per_level = 1.0, max_level = 5, stacking = "additive", retaliatory = 0.10 },
	&"hollow_heart": { name = "Hollow Heart", stat = "max_health", per_level = 0.20, max_level = 5, stacking = "multiplicative" },
	&"empty_tome": { name = "Empty Tome", stat = "cooldown", per_level = -0.08, max_level = 5, stacking = "additive" },
	&"candelabrador": { name = "Candelabrador", stat = "area", per_level = 0.10, max_level = 5, stacking = "additive" },
	&"bracer": { name = "Bracer", stat = "speed", per_level = 0.10, max_level = 5, stacking = "additive" },
	&"wings": { name = "Wings", stat = "move_speed", per_level = 0.10, max_level = 5, stacking = "additive" },
	&"duplicator": { name = "Duplicator", stat = "amount", per_level = 1.0, max_level = 2, stacking = "additive" },
}

# ===================== Enemies / Bosses / Reaper =====================
# ai: "homing" (chase player), "fixed" (fixed-direction swarm), "wavy".
# knockback_resist: 0 == none .. higher == more resistant; Reaper is negative
# (hits drag it toward the player). hp_per_level: base HP is multiplied by the
# player's level on spawn (the wiki "HP x Level" skill). immune: ignores
# instant-kill / debuff (the Reaper).
const ENEMIES := {
	# --- regular Mad Forest roster ---
	&"zombie": { name = "Zombie", hp = 10.0, power = 10.0, move_speed = 100.0, knockback_resist = 0.8, xp = 1.0, ai = "homing" },
	&"skeleton": { name = "Skeleton", hp = 15.0, power = 10.0, move_speed = 100.0, knockback_resist = 1.0, xp = 2.0, ai = "homing" },
	&"ghost": { name = "Ghost", hp = 10.0, power = 5.0, move_speed = 200.0, knockback_resist = 0.0, xp = 1.5, ai = "homing" },
	&"mudman_gray": { name = "Gray Mudman", hp = 70.0, power = 10.0, move_speed = 100.0, knockback_resist = 0.3, xp = 2.5, ai = "homing" },
	&"mudman_green": { name = "Green Mudman", hp = 150.0, power = 10.0, move_speed = 100.0, knockback_resist = 0.3, xp = 2.5, ai = "homing" },
	&"werewolf": { name = "Werewolf", hp = 180.0, power = 14.0, move_speed = 130.0, knockback_resist = 0.8, xp = 2.0, ai = "homing" },
	&"giant_bat": { name = "Giant Bat", hp = 270.0, power = 10.0, move_speed = 140.0, knockback_resist = 0.1, xp = 2.5, ai = "homing" },
	&"big_mummy": { name = "Big Mummy", hp = 500.0, power = 20.0, move_speed = 80.0, knockback_resist = 0.0, xp = 3.0, ai = "homing" },
	&"mantichana": { name = "Mantichana", hp = 500.0, power = 20.0, move_speed = 80.0, knockback_resist = 0.0, xp = 3.0, ai = "homing" },
	&"venus": { name = "Venus", hp = 500.0, power = 20.0, move_speed = 80.0, knockback_resist = 0.0, xp = 3.0, ai = "homing" },
	&"bat": { name = "Little Pipeestrello", hp = 1.0, power = 5.0, move_speed = 140.0, knockback_resist = 1.0, xp = 1.0, ai = "homing" },
	&"bat_red": { name = "Red-Eyed Pipeestrello", hp = 5.0, power = 5.0, move_speed = 140.0, knockback_resist = 1.0, xp = 1.0, ai = "homing" },
	&"flower_wall": { name = "Flower Wall", hp = 30.0, power = 1.0, move_speed = 20.0, knockback_resist = 1.0, xp = 2.0, ai = "homing", hp_per_level = true },
	# --- fixed-direction swarm variants ---
	&"ghost_swarm": { name = "Swarm Ghost", hp = 10.0, power = 5.0, move_speed = 700.0, knockback_resist = 0.0, xp = 1.5, ai = "fixed" },
	&"bat_swarm": { name = "Swarm Bat", hp = 1.0, power = 1.0, move_speed = 700.0, knockback_resist = 1.0, xp = 1.0, ai = "fixed" },
	# --- bosses (don't despawn; HP scales with level) ---
	&"glowing_bat": { name = "Glowing Bat", hp = 50.0, power = 10.0, move_speed = 140.0, knockback_resist = 1.0, xp = 30.0, ai = "homing", is_boss = true, hp_per_level = true },
	&"silver_bat": { name = "Silver Bat", hp = 50.0, power = 10.0, move_speed = 140.0, knockback_resist = 1.0, xp = 30.0, ai = "homing", is_boss = true, hp_per_level = true },
	&"giant_werewolf": { name = "Giant Werewolf", hp = 200.0, power = 20.0, move_speed = 130.0, knockback_resist = 0.1, xp = 2.0, ai = "homing", is_boss = true, hp_per_level = true },
	&"giant_mummy": { name = "Giant Mummy", hp = 250.0, power = 20.0, move_speed = 80.0, knockback_resist = 0.0, xp = 25.0, ai = "homing", is_boss = true, hp_per_level = true, freeze_resist = 1.1 },
	&"giant_mantichana": { name = "Giant Mantichana", hp = 150.0, power = 20.0, move_speed = 160.0, knockback_resist = 0.0, xp = 50.0, ai = "homing", is_boss = true, hp_per_level = true, freeze_resist = 1.1 },
	&"giant_blue_venus": { name = "Giant Blue Venus", hp = 150.0, power = 30.0, move_speed = 160.0, knockback_resist = 0.0, xp = 50.0, ai = "homing", is_boss = true, hp_per_level = true, freeze_resist = 1.1 },
	# --- the run-ender ---
	&"reaper": { name = "The Reaper", hp = 655350.0, power = 65535.0, move_speed = 1200.0, knockback_resist = -0.5, xp = 0.0, ai = "homing", is_boss = true, hp_per_level = true, immune = true },
}

# ===================== Enemy view art =====================
# SpriteFrames per enemy id, resolved by ViewSync. View-layer only: the stat
# data above stays free of resource coupling (EnemyPool/systems never read it).
# Visually-similar ids share one sheet -- bosses reuse their base creature and
# swarm variants reuse the base art -- so the 22-id roster maps onto 13 imports.
const ENEMY_SPRITE_FRAMES := {
	&"zombie": preload("res://assets/sprites/enemies/zombie.tres"),
	&"skeleton": preload("res://assets/sprites/enemies/skeleton.tres"),
	&"ghost": preload("res://assets/sprites/enemies/ghost.tres"),
	&"ghost_swarm": preload("res://assets/sprites/enemies/ghost.tres"),
	&"mudman_gray": preload("res://assets/sprites/enemies/mudman.tres"),
	&"mudman_green": preload("res://assets/sprites/enemies/mudman.tres"),
	&"werewolf": preload("res://assets/sprites/enemies/werewolf.tres"),
	&"giant_werewolf": preload("res://assets/sprites/enemies/werewolf.tres"),
	&"giant_bat": preload("res://assets/sprites/enemies/big_bat.tres"),
	&"glowing_bat": preload("res://assets/sprites/enemies/big_bat.tres"),
	&"bat": preload("res://assets/sprites/enemies/bat.tres"),
	&"bat_swarm": preload("res://assets/sprites/enemies/bat.tres"),
	&"bat_red": preload("res://assets/sprites/enemies/bat_albino.tres"),
	&"silver_bat": preload("res://assets/sprites/enemies/bat_albino.tres"),
	&"big_mummy": preload("res://assets/sprites/enemies/mummy.tres"),
	&"giant_mummy": preload("res://assets/sprites/enemies/mummy.tres"),
	&"mantichana": preload("res://assets/sprites/enemies/mantis.tres"),
	&"giant_mantichana": preload("res://assets/sprites/enemies/mantis_warrior.tres"),
	&"venus": preload("res://assets/sprites/enemies/piranha_plant.tres"),
	&"giant_blue_venus": preload("res://assets/sprites/enemies/piranha_plant.tres"),
	&"flower_wall": preload("res://assets/sprites/enemies/piranha_plant.tres"),
	&"reaper": preload("res://assets/sprites/enemies/grim_reaper.tres"),
}

# Pickup textures keyed by a view key (ViewSync maps PickupPool kind/gem_tier ->
# key). Plain Texture2D (Sprite2D pool, no animation). View-layer only.
# `chest` is a placeholder (no dedicated chest art): the large gold bag stands in.
const PICKUP_SPRITES := {
	&"gem_blue": preload("res://assets/sprites/pickups/gem_blue.png"),
	&"gem_green": preload("res://assets/sprites/pickups/gem_green.png"),
	&"gem_red": preload("res://assets/sprites/pickups/gem_red.png"),
	&"gold": preload("res://assets/sprites/pickups/gold_coin.png"),
	&"chicken": preload("res://assets/sprites/pickups/floor_chicken.png"),
	&"rosary": preload("res://assets/sprites/pickups/rosary.png"),
	&"orologion": preload("res://assets/sprites/pickups/frozen_clock.png"),
	&"vacuum": preload("res://assets/sprites/pickups/vacuum.png"),
	&"nduja": preload("res://assets/sprites/pickups/red_hot_chili_pepper.png"),
	&"rerollo": preload("res://assets/sprites/pickups/dice.png"),
	&"chest": preload("res://assets/sprites/pickups/chest.png"),
}

# Projectile textures keyed by the OWNING weapon id (ProjectilePool.owner_weapon).
# Plain Texture2D; ViewSync rotates/scales them. View-layer only.
const WEAPON_PROJECTILE_SPRITES := {
	&"whip": preload("res://assets/sprites/projectiles/whip.png"),
	&"knife": preload("res://assets/sprites/projectiles/knife.png"),
	&"magic_wand": preload("res://assets/sprites/projectiles/magic_wand.png"),
	&"runetracer": preload("res://assets/sprites/projectiles/runetracer.png"),
	&"garlic": preload("res://assets/sprites/projectiles/garlic.png"),
	&"king_bible": preload("res://assets/sprites/projectiles/king_bible.png"),
	&"fire_wand": preload("res://assets/sprites/projectiles/fire_wand.png"),
	&"lightning_ring": preload("res://assets/sprites/projectiles/lightning_ring.png"),
}

# ===================== Mad Forest per-minute wave table =====================
# One entry per minute 0..30 (index == minute). `count` is the periodic spawn
# minimum, `interval` the spawn interval in seconds. `boss` is the minute-marker
# boss id (or &"" for none). `event` is a swarm/formation event id (or &""):
# &"bat_swarm" / &"ghost_swarm" / &"flower_wall" — detailed event timing
# (timestamp/chance/repeats) lives in the wiki and is resolved by SpawnDirector.
# SLICE DEVIATION: Arcanas are out of scope, so the two Arcana-holder Glowing
# Bat bosses (minutes 11 and 21) are recorded as boss = &"" (they only spawn
# when Arcanas are enabled and award only an Arcana chest).
const MAD_FOREST_WAVES := [
	{ enemies = [&"bat_red"], count = 15, interval = 1.0, boss = &"", event = &"" }, # M0
	{ enemies = [&"zombie", &"bat"], count = 30, interval = 1.0, boss = &"glowing_bat", event = &"" }, # M1
	{ enemies = [&"bat", &"bat_red"], count = 50, interval = 0.5, boss = &"", event = &"bat_swarm" }, # M2
	{ enemies = [&"skeleton"], count = 40, interval = 0.25, boss = &"glowing_bat", event = &"bat_swarm" }, # M3
	{ enemies = [&"skeleton", &"ghost"], count = 30, interval = 1.0, boss = &"", event = &"bat_swarm" }, # M4
	{ enemies = [&"mudman_green"], count = 10, interval = 1.0, boss = &"mantichana", event = &"flower_wall" }, # M5
	{ enemies = [&"zombie", &"mudman_green"], count = 20, interval = 0.5, boss = &"", event = &"bat_swarm" }, # M6
	{ enemies = [&"bat_red", &"mudman_gray"], count = 80, interval = 0.5, boss = &"glowing_bat", event = &"bat_swarm" }, # M7
	{ enemies = [&"zombie"], count = 100, interval = 1.5, boss = &"giant_bat", event = &"bat_swarm" }, # M8
	{ enemies = [&"giant_bat", &"zombie"], count = 30, interval = 0.5, boss = &"silver_bat", event = &"bat_swarm" }, # M9
	{ enemies = [&"mudman_gray", &"mudman_green"], count = 10, interval = 0.5, boss = &"giant_mantichana", event = &"flower_wall" }, # M10
	{ enemies = [&"skeleton"], count = 300, interval = 0.1, boss = &"", event = &"bat_swarm" }, # M11 (arcana-only boss skipped)
	{ enemies = [&"werewolf", &"ghost", &"skeleton"], count = 20, interval = 0.25, boss = &"glowing_bat", event = &"bat_swarm" }, # M12
	{ enemies = [&"werewolf", &"ghost"], count = 150, interval = 0.5, boss = &"", event = &"ghost_swarm" }, # M13
	{ enemies = [&"giant_bat", &"werewolf"], count = 20, interval = 0.1, boss = &"silver_bat", event = &"" }, # M14
	{ enemies = [&"werewolf", &"giant_bat", &"mudman_green"], count = 100, interval = 0.1, boss = &"giant_werewolf", event = &"flower_wall" }, # M15
	{ enemies = [&"mantichana", &"mudman_gray", &"mudman_green"], count = 100, interval = 0.1, boss = &"glowing_bat", event = &"" }, # M16
	{ enemies = [&"big_mummy"], count = 20, interval = 1.0, boss = &"", event = &"" }, # M17
	{ enemies = [&"big_mummy", &"mudman_gray"], count = 60, interval = 0.5, boss = &"silver_bat", event = &"" }, # M18
	{ enemies = [&"big_mummy", &"mudman_gray"], count = 100, interval = 0.5, boss = &"", event = &"" }, # M19
	{ enemies = [&"big_mummy", &"mudman_green", &"giant_bat"], count = 100, interval = 0.1, boss = &"giant_mummy", event = &"bat_swarm" }, # M20
	{ enemies = [&"flower_wall"], count = 300, interval = 0.1, boss = &"venus", event = &"" }, # M21 (arcana-only glowing bat skipped)
	{ enemies = [&"flower_wall", &"big_mummy"], count = 200, interval = 0.1, boss = &"glowing_bat", event = &"" }, # M22
	{ enemies = [&"flower_wall", &"big_mummy"], count = 300, interval = 0.1, boss = &"silver_bat", event = &"" }, # M23
	{ enemies = [&"flower_wall", &"big_mummy"], count = 300, interval = 0.1, boss = &"venus", event = &"" }, # M24
	{ enemies = [&"venus"], count = 100, interval = 0.1, boss = &"giant_blue_venus", event = &"flower_wall" }, # M25
	{ enemies = [&"venus", &"flower_wall"], count = 150, interval = 0.1, boss = &"", event = &"" }, # M26
	{ enemies = [&"big_mummy", &"mudman_gray", &"mudman_green"], count = 300, interval = 0.1, boss = &"glowing_bat", event = &"ghost_swarm" }, # M27
	{ enemies = [&"giant_bat", &"glowing_bat"], count = 300, interval = 0.1, boss = &"", event = &"" }, # M28
	{ enemies = [&"glowing_bat", &"silver_bat"], count = 300, interval = 0.1, boss = &"glowing_bat", event = &"bat_swarm" }, # M29
	{ enemies = [], count = 0, interval = 60.0, boss = &"reaper", event = &"", clear_field = true }, # M30 (Reaper; field cleared)
]

# ===================== Spawn / stage rules =====================
const STAGE_TIME_LIMIT := 1800.0      # 30:00 in seconds
const REAPER_MINUTE := 30             # Reaper at 30:00, +1 each following minute
const ALIVE_CAP_PERIODIC := 300       # periodic spawns halt at 300 alive (wiki)
const ALIVE_CAP_HARD := 500           # hard on-screen ceiling (GDD)
const ENEMY_MOVE_SPEED_MULT := 1.1    # Mad Forest stage move-speed modifier

# Braziers (destructible light sources)
const BRAZIER_HP := 10.0
const BRAZIER_SPAWN_CHANCE := 0.10    # base 10% (max 50% with Luck; Luck not in slice)
const BRAZIER_MAX := 10
const BRAZIER_CADENCE := 1.0          # spawn attempt every 1s, off-screen
# Weighted drop table { pickup, weight, min_level }. Luck-gated clovers are out
# of scope (Luck not built). Rerollo weight is not stated in the wiki; assigned 1
# so the slice's Reroll charge has an in-run source.
const BRAZIER_DROPS := [
	{ pickup = &"gold_coin", weight = 50, min_level = 0 },
	{ pickup = &"coin_bag", weight = 10, min_level = 0 },
	{ pickup = &"rich_coin_bag", weight = 1, min_level = 5 },
	{ pickup = &"chicken", weight = 12, min_level = 0 },
	{ pickup = &"rosary", weight = 1, min_level = 8 },
	{ pickup = &"orologion", weight = 2, min_level = 4 },
	{ pickup = &"vacuum", weight = 2, min_level = 12 },
	{ pickup = &"nduja", weight = 1, min_level = 0 },
	{ pickup = &"rerollo", weight = 1, min_level = 0 },
]

# ===================== Chest / loot =====================
const CHEST_BEGINNER_LUCK := [1, 1, 3, 1, 1, 5]   # first 6 chests' fixed item counts
# Sequential 5 -> 3 -> 1 roll; representative Mad Forest base chances (per-boss in
# the wiki). ChestSystem applies Luck and the beginner-luck override.
const CHEST_COUNT_CHANCE := { "five" = 0.03, "three" = 0.10, "one" = 0.50 }
# Gold per chest by item count: [min, max] (x Greed).
const CHEST_GOLD := { "one" = [100, 200], "three" = [300, 600], "five" = [500, 1000] }

# ===================== Pickups =====================
const CHICKEN_HEAL := 30.0
const COIN_VALUES := { &"gold_coin": 1, &"coin_bag": 10, &"rich_coin_bag": 100, &"gold_pile": 1000 }

# ===================== XP / gems =====================
const GEM_BLUE_MAX := 2.0     # Blue gem: up to 2 XP
const GEM_GREEN_MAX := 9.0    # Green gem: up to 9 XP; Red: above 9
const GEM_GROUND_CAP := 400   # excess gems merge into one red gem
const XP_FOURTH_OPTION_LUCK := true  # 4th level-up option chance = 1 - 1/totalLuck

# ===================== Accessors =====================

static func weapon(id: StringName) -> Dictionary:
	return WEAPONS.get(id, {})

## Resolve one weapon stat to its FULL value at a given level: the base plus every
## per-level delta in `levels[1 .. level-1]` (the WEAPON LEVEL CONVENTION above).
## Mirrors WeaponSystem._resolve_weapon for a single key, so UI/preview code can
## read a stat without rebuilding the whole weapon. `stat` is a delta key
## (dmg/amount/area/speed/cooldown/duration/pierce); damage's base lives under
## `base_dmg`, so "dmg" is mapped to it (every other stat's base shares its key).
## NOTE: not special-cased for infinite pierce (base -1) — a caller reading
## `pierce` must treat a negative result as "infinite" itself.
static func weapon_stat_at_level(id: StringName, level: int, stat: String) -> float:
	var def := weapon(id)
	if def.is_empty():
		return 0.0
	var base_key := "base_dmg" if stat == "dmg" else stat
	var value: float = float(def.get(base_key, 0.0))
	var levels: Array = def.get("levels", [])
	for i in range(1, mini(level, levels.size())):
		value += float(levels[i].get(stat, 0.0))
	return value

static func passive(id: StringName) -> Dictionary:
	return PASSIVES.get(id, {})

static func enemy(id: StringName) -> Dictionary:
	return ENEMIES.get(id, {})

## SpriteFrames for an enemy id (view layer), or null if none is mapped.
static func enemy_sprite_frames(id: StringName) -> SpriteFrames:
	return ENEMY_SPRITE_FRAMES.get(id, null)

## Texture for a pickup view key (see PICKUP_SPRITES), or null if none is mapped.
static func pickup_sprite(key: StringName) -> Texture2D:
	return PICKUP_SPRITES.get(key, null)

## Texture for a weapon's projectile (by owning weapon id), or null if unmapped.
static func projectile_sprite(weapon_id: StringName) -> Texture2D:
	return WEAPON_PROJECTILE_SPRITES.get(weapon_id, null)

## Wave entry for the given minute. Minutes past the table clamp to the final
## (Reaper) entry, matching "one more Reaper every minute after 30:00".
static func wave(minute: int) -> Dictionary:
	if minute < 0:
		minute = 0
	if minute >= MAD_FOREST_WAVES.size():
		minute = MAD_FOREST_WAVES.size() - 1
	return MAD_FOREST_WAVES[minute]

## XP required to advance FROM `level` TO `level + 1`.
## L1->L2 = 5; +10/level through L20; +13/level L21-40; +16/level L41+; with
## one-time lumps of +600 at L20 and +2400 at L40 (the L20/L40 +100% Growth buff
## is a separate gameplay effect, not part of the requirement).
static func xp_to_next(level: int) -> float:
	var req := 5.0
	var l := 2
	while l <= level:
		if l <= 20:
			req += 10.0
		elif l <= 40:
			req += 13.0
		else:
			req += 16.0
		l += 1
	if level == 20:
		req += 600.0
	elif level == 40:
		req += 2400.0
	return req

## Gem tier StringName (&"blue"/&"green"/&"red") for a given XP value.
static func gem_tier(xp_value: float) -> StringName:
	if xp_value <= GEM_BLUE_MAX:
		return &"blue"
	elif xp_value <= GEM_GREEN_MAX:
		return &"green"
	return &"red"

## Roll one brazier drop pickup id from the weighted BRAZIER_DROPS table,
## considering only entries unlocked at `player_level` (their `min_level` gate).
## Returns the pickup id, or &"" if no entry is eligible. (Luck-gated rare drops
## are out of scope this slice -- see the BRAZIER_DROPS comment.)
static func roll_brazier_drop(rng: RandomNumberGenerator, player_level: int = 0) -> StringName:
	var total := 0
	for d in BRAZIER_DROPS:
		if int(d.get("min_level", 0)) <= player_level:
			total += int(d.get("weight", 0))
	if total <= 0:
		return &""
	var roll := rng.randi_range(1, total)
	var acc := 0
	for d in BRAZIER_DROPS:
		if int(d.get("min_level", 0)) > player_level:
			continue
		acc += int(d.get("weight", 0))
		if roll <= acc:
			return d["pickup"]
	return &""
