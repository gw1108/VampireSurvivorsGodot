class_name VSRun
extends Node2D
## Main run controller for the Vampire Survivors vertical slice.
##
## Owns game state and builds the whole world IN CODE (no per-entity .tscn) so the
## slice stays robust to edit. It is the single source the AgentBridge adapter reads.
## Minimal but a real micro-loop: move, survive ramping waves, auto-attack, collect XP.
## Placeholder vector art for now — swapping in the SourceArt sprite packs is the
## obvious next step (see workshop/GOAL.md), and exactly what the playtest reviewer
## should flag.

var player: VSPlayer
var hud: VSHud
var adapter: Node
var upgrade_screen: VSUpgradeScreen
var shop_screen: VSShopScreen
var _spawner: VSSpawner
var _cam: Camera2D

# Camera screen-shake (trauma model). Impacts add trauma (0..1); it decays to 0 in
# ~0.2s and the per-frame offset scales with trauma^2 so a small hit reads as a subtle
# jolt, not nausea. Kept intentionally small — see FEEL-REVIEW's "no screen shake" note.
var _shake_trauma := 0.0
const SHAKE_DECAY := 5.0          # trauma/sec — full trauma dissipates in ~0.2s
const SHAKE_MAX_OFFSET := 14.0    # px of offset at trauma 1.0

var phase := "playing"          # playing | level_up | game_over | victory  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0

## Survival goal for the slice: outlast the escalating waves to this many seconds and the
## run is WON (VS's core loop is survive-to-the-clock, not endless). 5:00 sits just past the
## enemy HP/damage ramp cap (~6 min) so the late run is at its most dangerous right as the
## timer runs out. Named so it's the single knob to tune the run length.
const RUN_DURATION := 300.0

## The finale: rather than flipping straight to victory at RUN_DURATION, the run summons the
## Reaper (VS's death-at-the-clock enemy) and the player must outlast it for this many extra
## seconds before the win lands — a climactic last stand instead of a silent clock flip.
const REAPER_DURATION := 15.0
var reaper_active := false        # true once the Reaper has been summoned at the time limit
var reaper_deadline := 0.0        # elapsed time at which surviving the Reaper wins the run
var reaper_slain := false         # true if the player KILLED the Reaper (a kill-win) rather than outlasting it
var reaper_enemy: VSEnemy         # the summoned Reaper node, so the HUD can show its boss health bar

## Orologion time-stop: while `elapsed < freeze_until` every enemy halts in place (see
## VSEnemy._process). Set by the Freeze Clock pickup (VSFrozenClock); measured in the run's
## own `elapsed` clock so it pauses cleanly with the game during level-up.
var freeze_until := 0.0
var xp := 0
var level := 1
var gold := 0                   # run coins banked from coin pickups; seed of the VS meta-currency
var frame_tick := 0
var arena_half := Vector2(900, 700)   # world half-extent around origin

# Run-level stats mutated by level-up upgrades. Weapon/projectile/player read these so
# a single pickup meaningfully changes how the run plays.
var player_speed_mult := 1.0
var weapon_damage := 2.0
var weapon_fire_interval := 0.6
var weapon_count := 1
var garlic_level := 0            # 0 = Garlic aura not yet chosen; each pick grows it
var whip_level := 0              # 0 = Whip melee arc not yet chosen; each pick grows it
var bible_level := 0             # 0 = King Bible orbit not yet chosen; each pick grows it
var bible_evolved := false       # true once King Bible -> Unholy Vespers (the weapon reads this)
var whip_evolved := false        # true once Whip -> Bloody Tear (whip.gd reads this)
var garlic_evolved := false      # true once Garlic -> Soul Eater (garlic.gd reads this)
var projectile_evolved := false  # true once Magic Wand -> Holy Wand (weapon.gd reads this)

## Evolution ids already claimed this run, so _roll_upgrades stops re-offering a done evolution.
var evolved := {}

var _pending_levels := 0        # level-ups queued but not yet chosen (XP can span several)

## Discrete level per upgrade id (0 = never picked). Incremented on each pick and used
## to (a) cap upgrades at their `max` so the pool shrinks as things top out — no infinite
## single-stat stacking — and (b) show "Lv N → N+1" on the cards. Kept in lock-step with
## the per-weapon counters (garlic_level, whip_level, weapon_count, …) since every pick
## flows through _apply_upgrade.
var upgrade_levels := {}

## Pool the level-up screen draws 3 distinct choices from each time. `max` is the highest
## level each upgrade reaches — weapons cap at 8 (VS convention), passives lower — after
## which it stops appearing in the roll.
const UPGRADE_POOL := [
	{"id": "damage", "title": "Power", "desc": "+1 weapon damage", "max": 5},
	{"id": "firerate", "title": "Haste", "desc": "+15% fire rate", "max": 5},
	{"id": "speed", "title": "Swift Boots", "desc": "+12% move speed", "max": 5},
	{"id": "health", "title": "Vitality", "desc": "+20 max HP, heal 20", "max": 5},
	{"id": "multishot", "title": "Multishot", "desc": "+1 projectile", "max": 4},
	{"id": "garlic", "title": "Garlic", "desc": "Damaging aura around you (grows each pick)", "max": 8},
	{"id": "whip", "title": "Whip", "desc": "Melee arc lashing your facing side; both sides at Lv 2+", "max": 8},
	{"id": "bible", "title": "King Bible", "desc": "Holy books orbit you, striking enemies they pass through", "max": 8},
]

## The signature VS mechanic: a weapon maxed to its UPGRADE_POOL `max` PLUS its paired
## passive owned unlocks an evolved form with a boosted profile. Keyed off UPGRADE_POOL by
## `weapon` (must be at max level) and `passive` (must be owned, level >= 1). Each evolution
## id is applied once via _apply_upgrade and remembered in `evolved` so it stops re-rolling.
## Faithful to VS pairings where the passive exists in our pool: Bible+Power, Whip+Vitality
## (Hollow Heart), Garlic+Swift Boots. Add rows to grow the evolution roster.
const EVOLUTIONS := [
	{"id": "unholy_vespers", "title": "Unholy Vespers", "desc": "King Bible EVOLVED — more books, faster orbit, far deadlier sweeps", "weapon": "bible", "passive": "damage"},
	{"id": "bloody_tear", "title": "Bloody Tear", "desc": "Whip EVOLVED — a wider, longer, far deadlier lash on both flanks", "weapon": "whip", "passive": "health"},
	{"id": "soul_eater", "title": "Soul Eater", "desc": "Garlic EVOLVED — a wider, far deadlier devouring aura", "weapon": "garlic", "passive": "speed"},
	{"id": "holy_wand", "title": "Holy Wand", "desc": "Magic Wand EVOLVED — a relentless storm of extra bolts that pierce the horde", "weapon": "multishot", "passive": "firerate"},
]

## Permanent, between-run PowerUps bought in the shop with banked meta-coins. Each level
## boosts a starting stat, applied fresh every run start via _apply_meta_powerups. Levels
## + coins persist in MetaSave (user://meta_save.json); the shop screen reads this catalog
## for its rows (title/desc/cost/max) exactly as the level-up screen reads UPGRADE_POOL.
const POWERUPS := [
	{"id": "might", "title": "Might", "desc": "+2 starting weapon damage per level", "cost": 60, "max": 5},
	{"id": "armor", "title": "Armor", "desc": "+20 max HP per level", "cost": 80, "max": 5},
	{"id": "haste", "title": "Cooldown", "desc": "-5% weapon cooldown per level", "cost": 100, "max": 5},
	{"id": "boots", "title": "Moonwalker", "desc": "+5% move speed per level", "cost": 70, "max": 5},
]

## Coin price of buying the NEXT PowerUp level, given its catalog `base` cost and the count
## `level` already owned. VS-style rising prices: cost = base * (level + 1), so Lv 0->1 is the
## base and each further level costs one more base — late levels become a real coin sink.
static func powerup_cost(base: int, level: int) -> int:
	return base * (maxi(level, 0) + 1)

func _ready() -> void:
	_ensure_input()
	seed(hash("vs-slice"))            # deterministic-ish; override via set_seed command
	_build_world()

func _ensure_input() -> void:
	# Register move actions at runtime so we don't hand-edit project.godot's [input]
	# block (fragile). Works for both human play and the harness's synthesized input.
	var defaults := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"upgrade_1": [KEY_1, KEY_KP_1],
		"upgrade_2": [KEY_2, KEY_KP_2],
		"upgrade_3": [KEY_3, KEY_KP_3],
		"open_shop": [KEY_B],
	}
	for action in defaults.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in defaults[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)

func _build_world() -> void:
	_build_ground()

	player = VSPlayer.new()
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	add_child(player)

	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	# Zoom < 1 zooms the camera out, so the player and everything else read ~20% smaller.
	_cam.zoom = Vector2(0.8, 0.8)
	player.add_child(_cam)
	_cam.make_current()

	var weapon := VSWeapon.new()
	weapon.run = self
	player.add_child(weapon)

	# Second weapon: the Garlic aura. Inert until garlic_level > 0 (a level-up pick).
	# z_index below the player sprite so the aura reads as ground-level, under enemies.
	var garlic := VSGarlic.new()
	garlic.run = self
	garlic.z_index = -1
	player.add_child(garlic)

	# Third weapon: the Whip melee arc. Inert until whip_level > 0 (a level-up pick).
	# z_index above the player so the lash reads on top of enemies it sweeps.
	var whip := VSWhip.new()
	whip.run = self
	whip.z_index = 1
	player.add_child(whip)

	# Fourth weapon: the King Bible orbit. Inert until bible_level > 0 (a level-up pick).
	# z_index above the player so the books read on top of the enemies they sweep.
	var bible := VSKingBible.new()
	bible.run = self
	bible.z_index = 1
	player.add_child(bible)

	_spawner = VSSpawner.new()
	_spawner.run = self
	add_child(_spawner)

	# Scatter a few destructible candelabra across the arena. A weapon sweep shatters one
	# for a random bonus pickup (see VSCandelabra / drop_candelabra_bonus), rewarding
	# exploration and giving the lucky drops a source beyond rare kill drops.
	_spawn_candelabra()

	hud = VSHud.new()
	add_child(hud)

	upgrade_screen = VSUpgradeScreen.new()
	upgrade_screen.picked.connect(_on_upgrade_picked)
	add_child(upgrade_screen)

	# Between-run PowerUp shop, opened from the game-over screen (key B). Spends banked
	# meta-coins on permanent boosts; hidden until the run ends.
	shop_screen = VSShopScreen.new()
	add_child(shop_screen)

	# Establish the character (Antonio Belpaese) — his starting weapon (Whip) and initial
	# stats — before meta-PowerUps stack on top and before any firing.
	_init_character()

	# Apply persisted PowerUps to this run's starting stats. Runs after the player exists
	# (armor bumps max_health) but before any firing, so weapon_damage/interval land first.
	_apply_meta_powerups()

	adapter = preload("res://scripts/agent/agent_adapter.gd").new()
	add_child(adapter)

## Antonio Belpaese — the default (and currently only) playable character. Faithful to the
## offline wiki: he begins wielding the Whip (his starting weapon) and with +20 Max Health
## (120 total), and gains +10% Might (a global weapon-damage multiplier, see might_mult) every
## 10 levels. Applied once at run start; upgrade_levels["whip"] is kept in lock-step with
## whip_level so the HUD build panel and the level-up cap logic see the whip as owned at Lv 1.
func _init_character() -> void:
	whip_level = 1
	upgrade_levels["whip"] = 1
	if player:
		player.max_health += 20.0
		player.health = player.max_health

## Antonio's signature Might scaling: +10% weapon Damage for every 10 character levels,
## capped at +50% (reached at level 50), mirroring the wiki table (1-9 → x1.0, 10-19 → x1.1,
## …, 50+ → x1.5). Every weapon multiplies its damage by this so a higher-level Antonio hits
## harder across the board, not just via picked upgrades.
func might_mult() -> float:
	return 1.0 + 0.10 * float(clampi(level / 10, 0, 5))

## Read permanent PowerUps bought in the shop and fold them into this run's starting stats.
## Called once at run start so every run reflects the between-run meta-progression. Uses the
## POWERUPS catalog's ids; unknown/zero levels are simply no-ops.
func _apply_meta_powerups() -> void:
	var levels := MetaSave.load_powerups()
	var might := int(levels.get("might", 0))
	if might > 0:
		weapon_damage += 2.0 * might
	var armor := int(levels.get("armor", 0))
	if armor > 0 and player:
		player.max_health += 20.0 * armor
		player.health = player.max_health
	var haste := int(levels.get("haste", 0))
	if haste > 0:
		weapon_fire_interval *= pow(0.95, haste)
	var boots := int(levels.get("boots", 0))
	if boots > 0:
		player_speed_mult *= pow(1.05, boots)

## Repeating grass ground so the arena reads as a place — motion and position are
## legible against a textured field instead of flat gray (see FEEL-REVIEW). A single
## Sprite2D with region + texture-repeat tiles the 256px grass over the whole playfield
## (arena_half plus camera margin). Static at origin, deep z_index so it sits under all.
func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.texture = load("res://art/ground.png")
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	# Cover arena_half (±900,700) plus the visible camera margin so no gray shows at the edges.
	var extent := Vector2(2400, 2000)
	ground.region_rect = Rect2(-extent, extent * 2.0)
	ground.z_index = -100
	ground.z_as_relative = false
	add_child(ground)

func _process(delta: float) -> void:
	frame_tick += 1
	if phase == "playing":
		elapsed += delta
		if not reaper_active:
			if elapsed >= RUN_DURATION:
				_summon_reaper()
		elif elapsed >= reaper_deadline:
			_on_victory()
	_update_shake(delta)
	if hud:
		hud.refresh(self)

## Decay the camera trauma and jitter the camera offset accordingly. Offset scales
## with trauma^2 so shake ramps down smoothly; snaps back to zero when trauma is spent.
func _update_shake(delta: float) -> void:
	if _cam == null:
		return
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(0.0, _shake_trauma - SHAKE_DECAY * delta)
		var s := _shake_trauma * _shake_trauma
		_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * s
	elif _cam.offset != Vector2.ZERO:
		_cam.offset = Vector2.ZERO

## Add a burst of camera trauma (0..1), capped at 1.0. Called on impacts.
func add_camera_shake(amount: float) -> void:
	_shake_trauma = minf(1.0, _shake_trauma + amount)

func _on_player_damaged(_amount: float) -> void:
	add_camera_shake(0.5)

func add_kill(at: Vector2, xp_value: int = 1, gem_count: int = 1, is_elite: bool = false) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	_spawn_gems(at, xp_value, gem_count)
	_maybe_drop_food(at)
	_maybe_drop_coin(at, is_elite)
	_maybe_drop_rosary(at, is_elite)
	_maybe_drop_freeze_clock(at, is_elite)
	if is_elite:
		_maybe_drop_magnet(at)

## True while an Orologion freeze is active — enemies read this each frame and halt (see
## VSEnemy._process). Compared against the run's own `elapsed` clock so the freeze window
## pauses with the game rather than bleeding real seconds during a level-up.
func is_frozen() -> bool:
	return elapsed < freeze_until

## Bank gold from a collected coin. Kept as a method so pickups and any future
## meta-progression hooks share one entry point onto the run's currency.
func add_gold(amount: int) -> void:
	gold += maxi(amount, 0)

## Rarely drop a roast-chicken heal on a kill so the run has a survival-recovery lever.
## The chance is biased by missing HP: near-full health it's a rare treat (~1.2%), but as
## the player drops low it climbs (up to ~6%) so relief tends to arrive when it's needed —
## faithful to VS's "food shows up when you're in trouble" feel, without a guaranteed crutch.
func _maybe_drop_food(at: Vector2) -> void:
	if player == null or not player.alive:
		return
	var missing := 1.0 - clampf(player.health / maxf(player.max_health, 1.0), 0.0, 1.0)
	var chance := 0.012 + missing * 0.048
	if randf() < chance:
		var f := VSFood.new()
		f.position = at
		f.run = self
		add_child(f)
		AgentBridge.emit_event("spawn", {"type": "food", "pos": [at.x, at.y]})

## Occasionally drop a Magnet from an elite kill — a VS-faithful treat that vacuums every
## on-screen gem to the player. Elites are periodic mini-bosses, so a ~40% chance makes the
## pickup a recurring-but-not-guaranteed reward that punctuates the wave rhythm.
func _maybe_drop_magnet(at: Vector2) -> void:
	if randf() < 0.40:
		var m := VSMagnet.new()
		m.position = at
		m.run = self
		add_child(m)
		AgentBridge.emit_event("spawn", {"type": "magnet", "pos": [at.x, at.y]})

## Rarely drop a Rosary — the VS screen-clear treat that smites every on-screen enemy on
## pickup. Very rare from ordinary kills (~0.3%) so a clutch wipe feels like a lucky break,
## and a slightly better shot from an elite kill (~10%) as a mini-boss reward. Deliberately
## much rarer than food/coins: a mass clear is a run-swinging moment, not a staple.
func _maybe_drop_rosary(at: Vector2, is_elite: bool) -> void:
	var chance := 0.10 if is_elite else 0.003
	if randf() >= chance:
		return
	var r := VSRosary.new()
	r.position = at
	r.run = self
	add_child(r)
	AgentBridge.emit_event("spawn", {"type": "rosary", "pos": [at.x, at.y]})

## Rarely drop a Freeze Clock — the VS Orologion time-stop treat that halts every enemy on
## pickup (see VSFrozenClock). Same rarity tuning as the Rosary (~0.3% from ordinary kills,
## ~10% from an elite): a run-swinging breather that feels like a lucky break, not a staple.
## The Rosary's complement — a pause to reposition rather than a mass clear.
func _maybe_drop_freeze_clock(at: Vector2, is_elite: bool) -> void:
	var chance := 0.10 if is_elite else 0.003
	if randf() >= chance:
		return
	var c := VSFrozenClock.new()
	c.position = at
	c.run = self
	add_child(c)
	AgentBridge.emit_event("spawn", {"type": "frozen_clock", "pos": [at.x, at.y]})

## Occasionally drop a gold coin on a kill so the run banks a little meta-currency. Ordinary
## kills pay out rarely (~2%) and a single coin; elites are a jackpot — a guaranteed coin
## worth a small handful — so the "coins" economy grows a touch faster from mini-boss fights,
## faithful to VS where tougher enemies feed the between-run purse.
func _maybe_drop_coin(at: Vector2, is_elite: bool) -> void:
	var amount := 0
	if is_elite:
		amount = randi_range(3, 6)
	elif randf() < 0.02:
		amount = 1
	if amount <= 0:
		return
	var c := VSCoin.new()
	c.position = at
	c.run = self
	c.value = amount
	add_child(c)
	AgentBridge.emit_event("spawn", {"type": "coin", "pos": [at.x, at.y], "gold": amount})

## How many candelabra to scatter at run start, and how far from the player's origin the
## nearest may sit so they read as something to reach for rather than free at spawn.
const CANDELABRA_COUNT := 6
const CANDELABRA_MIN_DIST := 260.0

## Scatter the run's destructible candelabra across the arena (called once at run start).
## Placed at random interior points, nudged away from the player's start so they reward moving.
func _spawn_candelabra() -> void:
	for i in CANDELABRA_COUNT:
		var pos := Vector2.ZERO
		for _attempt in 8:
			pos = Vector2(
				randf_range(-arena_half.x + 80.0, arena_half.x - 80.0),
				randf_range(-arena_half.y + 80.0, arena_half.y - 80.0))
			if pos.length() >= CANDELABRA_MIN_DIST:
				break
		var c := VSCandelabra.new()
		c.position = pos
		c.run = self
		add_child(c)
		AgentBridge.emit_event("spawn", {"type": "candelabra", "pos": [pos.x, pos.y]})

## Roll a random bonus when a candelabra is shattered (VSCandelabra calls this on break).
## Faithful to VS's "lucky light": mostly a coin bag or floor chicken, sometimes a Magnet,
## rarely the Rosary screen-clear. Reuses the same pickup nodes the kill-drops spawn.
func drop_candelabra_bonus(at: Vector2) -> void:
	var roll := randf()
	if roll < 0.08:
		var r := VSRosary.new()
		r.position = at
		r.run = self
		add_child(r)
		AgentBridge.emit_event("spawn", {"type": "rosary", "pos": [at.x, at.y]})
	elif roll < 0.16:
		var fc := VSFrozenClock.new()
		fc.position = at
		fc.run = self
		add_child(fc)
		AgentBridge.emit_event("spawn", {"type": "frozen_clock", "pos": [at.x, at.y]})
	elif roll < 0.33:
		var m := VSMagnet.new()
		m.position = at
		m.run = self
		add_child(m)
		AgentBridge.emit_event("spawn", {"type": "magnet", "pos": [at.x, at.y]})
	elif roll < 0.66:
		var amount := randi_range(3, 8)
		var c := VSCoin.new()
		c.position = at
		c.run = self
		c.value = amount
		add_child(c)
		AgentBridge.emit_event("spawn", {"type": "coin", "pos": [at.x, at.y], "gold": amount})
	else:
		var f := VSFood.new()
		f.position = at
		f.run = self
		add_child(f)
		AgentBridge.emit_event("spawn", {"type": "food", "pos": [at.x, at.y]})

## Split a kill's XP across `count` gems scattered in a ring. Elites drop a burst
## so the big payout reads as a jackpot; ordinary kills drop a single gem.
func _spawn_gems(at: Vector2, total_xp: int, count: int) -> void:
	count = maxi(count, 1)
	var base := total_xp / count
	var rem := total_xp % count
	for i in count:
		var v := base + (1 if i < rem else 0)
		var offset := Vector2.ZERO
		if count > 1:
			var ang := TAU * float(i) / float(count)
			offset = Vector2(cos(ang), sin(ang)) * 18.0
		_spawn_gem(at + offset, maxi(v, 1))

func _spawn_gem(at: Vector2, xp_value: int = 1) -> void:
	var g := VSGem.new()
	g.position = at
	g.run = self
	g.value = xp_value
	add_child(g)

func collect_xp(amount: int) -> void:
	if phase != "playing":
		return
	xp += amount
	var need := _xp_to_next(level)
	while xp >= need:
		xp -= need
		level += 1
		_pending_levels += 1
		AgentBridge.emit_event("level_up", {"level": level})
		need = _xp_to_next(level)
	if _pending_levels > 0:
		_open_level_up()

# XP required to advance FROM the given level. A tiered VS-like curve: the
# per-level cost grows in steps (increments of 10/13/16) with the requirement
# steepening at level 20 and 40, mirroring the game's formula changes so late
# level-ups slow down and the weapon/passive max-level caps get approached over
# a run rather than instantly. Level 1 still costs 5 to preserve the early pace.
func _xp_to_next(lv: int) -> int:
	if lv < 20:
		return 5 + (lv - 1) * 10
	elif lv < 40:
		return 185 + (lv - 19) * 13
	else:
		return 445 + (lv - 39) * 16

func _open_level_up() -> void:
	var options := _roll_upgrades()
	if options.is_empty():
		# Every upgrade is maxed — still reward the level with a small heal, then resume
		# without a screen so the run never soft-locks on an empty picker.
		if player:
			player.health = minf(player.max_health, player.health + 20.0)
		_pending_levels -= 1
		if _pending_levels > 0:
			_open_level_up()
		else:
			phase = "playing"
		return
	phase = "level_up"
	upgrade_screen.present(options)

## Pick up to 3 distinct not-yet-maxed options, each annotated with its current level so
## the card can show "Lv N → N+1". Maxed upgrades are excluded so the pool shrinks over
## the run and picks stay meaningful. Returns [] only when everything is maxed.
func _roll_upgrades() -> Array:
	var options := []
	# Evolutions take priority: when a weapon is maxed and its paired passive owned, always
	# surface the evolved card so the player never misses the (one-shot) evolution window.
	for evo in EVOLUTIONS:
		if _evolution_available(evo):
			var card: Dictionary = evo.duplicate()
			card["evolution"] = true      # no "level" key -> the card skips the Lv N->N+1 line
			options.append(card)
	# Fill the remaining slots with normal not-yet-maxed upgrades.
	var pool := []
	for opt in UPGRADE_POOL:
		var lvl: int = upgrade_levels.get(opt["id"], 0)
		if lvl < int(opt["max"]):
			var display: Dictionary = opt.duplicate()
			display["level"] = lvl        # current level; the pick raises it to lvl+1
			pool.append(display)
	pool.shuffle()
	for opt in pool:
		if options.size() >= 3:
			break
		options.append(opt)
	return options.slice(0, mini(3, options.size()))

## An evolution is offerable when its weapon is at max level, its paired passive is owned
## (level >= 1, VS-style: the passive need only be present), and it hasn't been taken yet.
func _evolution_available(evo: Dictionary) -> bool:
	if evolved.has(evo["id"]):
		return false
	var w_lvl: int = upgrade_levels.get(evo["weapon"], 0)
	if w_lvl < _upgrade_max(evo["weapon"]):
		return false
	return int(upgrade_levels.get(evo["passive"], 0)) >= 1

## Look up an upgrade id's cap from UPGRADE_POOL (0 if unknown, so it never reads as maxed).
func _upgrade_max(id: String) -> int:
	for opt in UPGRADE_POOL:
		if opt["id"] == id:
			return int(opt["max"])
	return 0

func _on_upgrade_picked(id: String) -> void:
	_apply_upgrade(id)
	_pending_levels -= 1
	if _pending_levels > 0:
		_open_level_up()
	else:
		phase = "playing"

func _apply_upgrade(id: String) -> void:
	upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
	match id:
		"damage":
			weapon_damage += 1.0
		"firerate":
			weapon_fire_interval = maxf(0.12, weapon_fire_interval * 0.85)
		"speed":
			player_speed_mult *= 1.12
		"health":
			if player:
				player.max_health += 20.0
				player.health = minf(player.max_health, player.health + 20.0)
		"multishot":
			weapon_count += 1
		"garlic":
			garlic_level += 1
		"whip":
			whip_level += 1
		"bible":
			bible_level += 1
		"unholy_vespers":
			# King Bible -> Unholy Vespers: flag the evolution so VSKingBible swaps to its
			# boosted profile, and remember it so the card stops re-rolling.
			bible_evolved = true
			evolved[id] = true
		"bloody_tear":
			# Whip -> Bloody Tear: VSWhip reads whip_evolved for its boosted profile.
			whip_evolved = true
			evolved[id] = true
		"soul_eater":
			# Garlic -> Soul Eater: VSGarlic reads garlic_evolved for its boosted profile.
			garlic_evolved = true
			evolved[id] = true
		"holy_wand":
			# Magic Wand -> Holy Wand: VSWeapon reads projectile_evolved for its boosted profile.
			projectile_evolved = true
			evolved[id] = true
	AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})

func _on_player_died() -> void:
	if phase == "game_over" or phase == "victory":
		return
	phase = "game_over"
	# Bank this run's coins into the persisted meta purse so the VS "coins" economy
	# carries between runs (seed of a future PowerUp shop). Guarded above so a run
	# can only deposit once, never double-banking on repeated death signals.
	var meta_coins := MetaSave.add_coins(gold)
	AgentBridge.emit_event("death", {"type": "player", "run_gold": gold, "meta_coins": meta_coins})

## Reached RUN_DURATION — summon the finale Reaper instead of winning outright. The run stays
## in "playing" so the world keeps moving; surviving until reaper_deadline (REAPER_DURATION
## seconds later) is what flips it to victory via _process. Guarded by reaper_active so it fires
## exactly once, and only while still playing (a death at the buzzer must not raise the Reaper).
func _summon_reaper() -> void:
	if reaper_active or phase != "playing":
		return
	reaper_active = true
	reaper_deadline = elapsed + REAPER_DURATION
	add_camera_shake(1.0)   # the Reaper's arrival lands as the run's hardest jolt
	if _spawner:
		reaper_enemy = _spawner.spawn_reaper()   # keep the node so the HUD can bar its HP
	AgentBridge.emit_event("reaper", {"deadline": reaper_deadline})

## Player outlasted RUN_DURATION — the run is WON. Freezes the world (every entity halts on
## phase != "playing") and banks this run's coins into the meta purse exactly like death, so a
## survived run still pays into the between-run economy. Guarded so it fires once even if the
## victory and a death signal race on the same frame (whichever set a terminal phase first wins).
func _on_victory() -> void:
	if phase == "game_over" or phase == "victory":
		return
	phase = "victory"
	var meta_coins := MetaSave.add_coins(gold)
	AgentBridge.emit_event("victory", {"type": "player", "run_gold": gold, "meta_coins": meta_coins})

## The player actually KILLED the Reaper — a strong build overpowering the finale — instead of
## merely outlasting it. Flip straight to victory now rather than waiting out reaper_deadline, with
## the run's heaviest jolt, and flag reaper_slain so the HUD crowns the win 'YOU SLEW THE REAPER'.
## Guarded via _on_victory's phase check so a death on the same frame still can't be overridden.
func on_reaper_slain() -> void:
	if phase != "playing":
		return
	reaper_slain = true
	add_camera_shake(1.0)   # the heaviest jolt in the run — the finale falls
	_on_victory()

func _unhandled_input(event: InputEvent) -> void:
	if phase != "game_over" and phase != "victory":
		return
	# The shop swallows its own input while open; retry only fires from the bare
	# game-over screen so Enter doesn't yank the player out mid-purchase.
	if shop_screen and shop_screen.visible:
		return
	if event.is_action_pressed("open_shop"):
		get_viewport().set_input_as_handled()
		shop_screen.open()
	elif event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func reseed(value: int) -> void:
	seed(value)
