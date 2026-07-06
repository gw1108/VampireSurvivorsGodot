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
var chest_screen: VSChestScreen
var shop_screen: VSShopScreen
var title_screen: VSTitleScreen
var _spawner: VSSpawner
var _cam: Camera2D

# Camera screen-shake (trauma model). Impacts add trauma (0..1); it decays to 0 in
# ~0.2s and the per-frame offset scales with trauma^2 so a small hit reads as a subtle
# jolt, not nausea. Kept intentionally small — see FEEL-REVIEW's "no screen shake" note.
var _shake_trauma := 0.0
const SHAKE_DECAY := 5.0          # trauma/sec — full trauma dissipates in ~0.2s
const SHAKE_MAX_OFFSET := 14.0    # px of offset at trauma 1.0

# Evolution slow-mo: on the run's rarest power spike (a weapon fusion) we dip Engine.time_scale
# for a brief bullet-time beat, then ease it back to 1.0, so the moment lands with real heft.
# Driven off the wall clock (Time.get_ticks_msec, unaffected by time_scale) rather than the
# scaled process delta, so the recovery always finishes in SLOWMO_DURATION real seconds and
# restores time_scale cleanly no matter how far it dipped. See _celebrate_evolution / _update_slowmo.
const SLOWMO_SCALE := 0.4         # dip target — 40% speed at the instant of the fusion
const SLOWMO_DURATION := 0.15     # real seconds to ease from SLOWMO_SCALE back up to 1.0
var _slowmo_active := false
var _slowmo_start_ms := 0

var phase := "title"            # title | playing | level_up | chest | paused | game_over | victory  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0

## Survival goal for the slice: outlast the escalating waves to this many seconds and the
## run is WON (VS's core loop is survive-to-the-clock, not endless). Matches the real Mad
## Forest stage's 30:00 run length (see .firecrawl/wiki-offline/Mad_Forest.htm's per-minute
## wave table), with the enemy HP/damage ramp reaching its ceiling right as the timer runs
## out. Named so it's the single knob to tune the run length.
const RUN_DURATION := 1800.0

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

## Nduja Fritta Tanta berserk window: while `elapsed < nduja_until` the player takes no contact
## damage and burns nearby enemies with a fiery aura (see VSPlayer._process). Set by the Nduja
## pickup (VSNduja); measured in the run's own `elapsed` clock so it pauses cleanly during level-up.
var nduja_until := 0.0

## Gold Fever window: while `elapsed < gold_fever_until`, kills have a bonus chance to drop
## extra gold (see _maybe_drop_gold_fever_coin / add_kill). Started by the Gilded Clover pickup
## (VSGildedClover); measured in the run's own `elapsed` clock so it pauses cleanly during level-up,
## same as the freeze/nduja windows above.
var gold_fever_until := 0.0
const GOLD_FEVER_DURATION := 10.0     # Gilded_Clover.md: Gold Fever lasts 10 seconds
const GOLD_FEVER_KILL_CHANCE := 0.75  # Gilded_Clover.md: 75% chance a kill drops a bonus coin

## Luck stat (Luck.md): base is 100% ("TotalLuck"), and this holds the +N% additive bonus on
## top of that base — the wiki displays only this difference, e.g. a Little Clover pickup adds
## LUCK_GAIN (10.0) here. No cap; Little Clover can be collected infinitely per the wiki. Only
## Little Clover feeds this in the current slice (Clover passive / character starting Luck /
## Golden Egg are out of scope — see tasks/lessons.md).
var luck_bonus := 0.0

## MetaSave unlock id for the Clover ("luck") level-up passive. Faithful to VS, the Clover
## upgrade only enters the level-up pool once the player has found their first Little Clover
## drop (set on pickup via VSLittleClover). A fresh profile has no unlocks, so it's gated
## from the very first run too. See _roll_upgrades and MetaSave.is_unlocked/unlock.
const CLOVER_UNLOCK_ID := "clover"
var xp := 0
var level := 1
var gold := 0                   # run coins banked from coin pickups; seed of the VS meta-currency
var frame_tick := 0
var arena_half := Vector2(900, 700)   # world half-extent around origin

# Run-level stats mutated by level-up upgrades. Weapon/projectile/player read these so
# a single pickup meaningfully changes how the run plays.
var player_speed_mult := 1.0
## Magic Wand's current damage. Starting value + per-Power-pick growth live in
## res://data/balance.csv ("magic_wand_base_damage" / "magic_wand_damage_per_level") so a
## designer can retune them without touching this script.
var weapon_damage := BalanceData.get_value("magic_wand_base_damage", 2.0)
var weapon_fire_interval := 0.6
## Meta-PowerUp contributions to the build-wide multipliers, so the shop's generically-worded
## "Might" / "Cooldown" upgrades reach EVERY weapon, not just the Magic Wand (which reads
## weapon_damage / weapon_fire_interval directly). Set once at run start in _apply_meta_powerups;
## folded into power_mult() / haste_mult() — the ratios every OTHER weapon consumes. 1.0 = neutral,
## so a fresh VSRun (no _apply_meta_powerups) behaves exactly as before.
var meta_power_mult := 1.0   # >=1.0 damage bonus for non-wand weapons from meta Might
var meta_haste_mult := 1.0   # <=1.0 cooldown reduction for non-wand weapons from meta Cooldown
var weapon_count := 0            # 0 = Magic Wand not yet chosen; each Multishot pick grows it
var area_mult := 1.0             # Candelabrador: scales AoE weapon reach/radius (garlic, whip, bible, lightning)
var projectile_speed_mult := 1.0  # Bracer: scales how fast thrown/fired projectiles travel
var pickup_range_mult := 1.0     # Attractorb: scales the magnet radius of gems/coins/food so pickups fly in from farther
var xp_gain_mult := 1.0          # Growth: multiplies XP collected from gems so leveling accelerates as it stacks
var armor := 0                   # Armor: flat damage subtracted from each hit the player takes (min 1 gets through)
var recovery := 0.0              # Recovery (Pummarola): HP regenerated per second, ticked in _process while playing
var garlic_level := 0            # 0 = Garlic aura not yet chosen; each pick grows it
var whip_level := 0              # 0 = Whip melee arc not yet chosen; each pick grows it
var bible_level := 0             # 0 = King Bible orbit not yet chosen; each pick grows it
var lightning_level := 0         # 0 = Lightning Ring not yet chosen; each pick grows it
var knife_level := 0             # 0 = Knife directional throw not yet chosen; each pick grows it
var runetracer_level := 0        # 0 = Runetracer bouncing rune not yet chosen; each pick grows it
var fire_wand_level := 0          # 0 = Fire Wand fireball not yet chosen; each pick grows it
var bible_evolved := false       # true once King Bible -> Unholy Vespers (the weapon reads this)
var whip_evolved := false        # true once Whip -> Bloody Tear (whip.gd reads this)
var garlic_evolved := false      # true once Garlic -> Soul Eater (garlic.gd reads this)
var projectile_evolved := false  # true once Magic Wand -> Holy Wand (weapon.gd reads this)
var knife_evolved := false       # true once Knife -> Thousand Edges (knife.gd reads this)
var fire_wand_evolved := false   # true once Fire Wand -> Hellfire (fire_wand.gd reads this)
var lightning_evolved := false   # true once Lightning Ring -> Thunder Loop (lightning.gd reads this)
var runetracer_evolved := false  # true once Runetracer -> NO FUTURE (runetracer.gd reads this)

## Evolution ids already claimed this run, so _roll_upgrades stops re-offering a done evolution.
var evolved := {}

var _pending_levels := 0        # level-ups queued but not yet chosen (XP can span several)

## The first two level-up hands offer WEAPONS ONLY (no passive stat items), so a fresh run
## front-loads weapon variety before passives dilute the pool. Counts level-ups actually
## resolved (picked or skipped); rerolls don't advance it, so a rerolled first/second hand
## stays weapons-only. Read in _roll_upgrades.
var _levelups_resolved := 0

## Carries the sub-integer remainder when xp_gain_mult scales a gem's XP, so the Growth
## passive isn't lost to rounding on the many 1-XP gems — fractions bank until they make a
## whole point. Reset only at run start (nothing to carry between runs).
var _xp_remainder := 0.0

## Fraction of the next level's XP requirement granted when a level-up is Skipped, matching
## the GDD's "forgo for partial XP" verb. Small so skipping a genuinely bad hand helps a
## little without ever undercutting the value of an actual pick.
const SKIP_XP_FRACTION := 0.25

## Consolation-pick rewards. When a build nears (or reaches) fully maxed, the upgrade pool can
## no longer fill a 3-card hand; per the GDD ("full & maxed → level-ups instead offer gold or
## Floor Chicken") we pad the hand with these instead of shrinking it or silently resolving.
## Floor Chicken heals 30 HP (GDD Pickups table); the coin bag banks a flat run-gold reward.
## A third, larger "Gold Sack" reward keeps the three padded slots distinct — a fully-maxed hand
## needs to fill all three, and cycling only Gold/Chicken would repeat Gold twice (see _roll_upgrades).
const BONUS_GOLD_AMOUNT := 30
const BONUS_GOLD_BIG_AMOUNT := 75
const BONUS_CHICKEN_HEAL := 30.0

## Per-run reroll budget for the level-up picker (VS-style build agency). Each reroll
## re-rolls the current hand via _roll_upgrades(); Skip is always free. Kept small so it's
## a meaningful choice, not a slot machine. This is the BASE budget; the Reroll PowerUp
## (see POWERUPS / _apply_meta_powerups) adds to it, and a rare candelabra bonus grants +1
## mid-run (see drop_candelabra_bonus), so build agency scales with investment.
var rerolls_left := 3

## Discrete level per upgrade id (0 = never picked). Incremented on each pick and used
## to (a) cap upgrades at their `max` so the pool shrinks as things top out — no infinite
## single-stat stacking — and (b) show "Lv N → N+1" on the cards. Kept in lock-step with
## the per-weapon counters (garlic_level, whip_level, weapon_count, …) since every pick
## flows through _apply_upgrade.
var upgrade_levels := {}

## Inventory cap (GDD "Inventory cap: 6 weapons + 6 passives"): the player can OWN at most six
## weapons and six passives. Once six of a kind are owned, the level-up roll stops offering a
## seventh — only already-owned items of that kind keep appearing (for their upgrades) until
## maxed, at which point the hand pads with Gold/Floor Chicken consolation (see _roll_upgrades).
const MAX_WEAPONS := 6
const MAX_PASSIVES := 6

## The eight auto-firing weapons in UPGRADE_POOL; every other pool id is a passive stat item.
## `multishot` is Antonio's Magic Wand (each pick adds a bolt). Used to bucket a pool entry as
## weapon-vs-passive when enforcing the inventory cap above.
const WEAPON_IDS := ["multishot", "garlic", "whip", "bible", "lightning", "knife", "runetracer", "fire_wand"]

## Pool the level-up screen draws 3 distinct choices from each time. `max` is the highest
## level each upgrade reaches — weapons cap at 8 (VS convention), passives lower — after
## which it stops appearing in the roll.
const UPGRADE_POOL := [
	{"id": "damage", "title": "Power", "desc": "+1 weapon damage", "max": 5},
	{"id": "firerate", "title": "Haste", "desc": "+15% fire rate", "max": 5},
	{"id": "speed", "title": "Swift Boots", "desc": "+12% move speed", "max": 5},
	{"id": "health", "title": "Vitality", "desc": "+20 max HP, heal 20", "max": 5},
	{"id": "multishot", "title": "Multishot", "desc": "+1 projectile", "max": 4},
	{"id": "area", "title": "Candelabrador", "desc": "+10% weapon area (aura/whip/bible/lightning reach)", "max": 5},
	{"id": "projspeed", "title": "Bracer", "desc": "+15% projectile speed", "max": 5},
	{"id": "attract", "title": "Attractorb", "desc": "+30% pickup range (gems, coins, food fly in from farther)", "max": 4},
	{"id": "growth", "title": "Growth", "desc": "+8% XP gained (levels come faster)", "max": 5},
	{"id": "armor", "title": "Armor", "desc": "-1 damage taken per hit (min 1 always lands)", "max": 3},
	{"id": "recovery", "title": "Pummarola", "desc": "+0.2 HP recovered per second", "max": 5},
	{"id": "luck", "title": "Clover", "desc": "+10% Luck", "max": 5},
	{"id": "garlic", "title": "Garlic", "desc": "Damaging aura around you (grows each pick)", "max": 8},
	{"id": "whip", "title": "Whip", "desc": "Melee arc lashing your facing side; both sides at Lv 2+", "max": 8},
	{"id": "bible", "title": "King Bible", "desc": "Holy books orbit you, striking enemies they pass through", "max": 8},
	{"id": "lightning", "title": "Lightning Ring", "desc": "Bolts smite random enemies across the field, splashing on impact", "max": 8},
	{"id": "knife", "title": "Knife", "desc": "Fast blades hurled where you're facing; more per throw as it grows", "max": 8},
	{"id": "runetracer", "title": "Runetracer", "desc": "A spinning rune that bounces around the arena, striking everything it passes through", "max": 8},
	{"id": "fire_wand", "title": "Fire Wand", "desc": "Lobs a fireball at a random enemy that detonates on impact, splashing everything nearby", "max": 8},
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
	{"id": "thousand_edges", "title": "Thousand Edges", "desc": "Knife EVOLVED — a near-continuous stream of blades, more per throw, far deadlier", "weapon": "knife", "passive": "firerate"},
	{"id": "hellfire", "title": "Hellfire", "desc": "Fire Wand EVOLVED — a piercing fireball that tears straight through the horde, no longer stopping to detonate", "weapon": "fire_wand", "passive": "damage"},
	{"id": "thunder_loop", "title": "Thunder Loop", "desc": "Lightning Ring EVOLVED — more bolts, a wider blast, and every strike re-cracks a second time for double the smiting", "weapon": "lightning", "passive": "projspeed"},
	{"id": "no_future", "title": "NO FUTURE", "desc": "Runetracer EVOLVED — more runes caroming faster and longer, each a bigger, harder-hitting hazard that owns the whole arena", "weapon": "runetracer", "passive": "area"},
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
	{"id": "reroll", "title": "Reroll", "desc": "+1 level-up reroll per run per level", "cost": 90, "max": 5},
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
		"upgrade_4": [KEY_4, KEY_KP_4],
		"upgrade_5": [KEY_5, KEY_KP_5],
		"upgrade_reroll": [KEY_R],
		"upgrade_skip": [KEY_F],
		"open_shop": [KEY_B],
		"pause": [KEY_ESCAPE],
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

	# Fifth weapon: the Lightning Ring — random-target smites across the field. Inert until
	# lightning_level > 0 (a level-up pick). z_index above the player so its bolts read on top.
	var lightning := VSLightning.new()
	lightning.run = self
	lightning.z_index = 1
	player.add_child(lightning)

	# Sixth weapon: the Knife — fast directional throws in the player's facing. Inert until
	# knife_level > 0 (a level-up pick). z_index above the player so its blades read on top.
	var knife := VSKnife.new()
	knife.run = self
	knife.z_index = 1
	player.add_child(knife)

	# Seventh weapon: the Runetracer — a rune that bounces around the arena. Inert until
	# runetracer_level > 0 (a level-up pick). Mounted on the player only to source its spawn
	# point; each fired rune lives in world space as a child of the run so it caroms freely.
	var runetracer := VSRunetracer.new()
	runetracer.run = self
	player.add_child(runetracer)

	# Eighth weapon: the Fire Wand — lobs a detonating fireball at a random enemy. Inert until
	# fire_wand_level > 0 (a level-up pick). Mounted on the player only to source its spawn point;
	# each fireball lives in world space as a child of the run so it flies and explodes freely.
	var fire_wand := VSFireWand.new()
	fire_wand.run = self
	player.add_child(fire_wand)

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
	upgrade_screen.rerolled.connect(_on_upgrade_rerolled)
	upgrade_screen.skipped.connect(_on_upgrade_skipped)
	add_child(upgrade_screen)

	# Treasure-chest reward reveal — plays the chest-open animation (beam, item spew, coin
	# ramp) when a chest is opened, then resumes the run on `continued` (see open_chest).
	chest_screen = VSChestScreen.new()
	chest_screen.continued.connect(_on_chest_continue)
	add_child(chest_screen)

	# Between-run PowerUp shop, opened from the game-over screen (key B). Spends banked
	# meta-coins on permanent boosts; hidden until the run ends.
	shop_screen = VSShopScreen.new()
	shop_screen.closed.connect(_on_shop_closed)
	add_child(shop_screen)

	# Establish the character (Antonio Belpaese) — his starting weapon (Whip) and initial
	# stats — before meta-PowerUps stack on top and before any firing.
	_init_character()

	# Apply persisted PowerUps to this run's starting stats. Runs after the player exists
	# (armor bumps max_health) but before any firing, so weapon_damage/interval land first.
	_apply_meta_powerups()

	adapter = preload("res://scripts/agent/agent_adapter.gd").new()
	add_child(adapter)

	# Title / main menu (GDD: "Main menu -> Start -> straight into Mad Forest"). The run boots
	# frozen in the "title" phase — nothing keys off "title", only "playing" — and enters play on
	# Start. HARNESS-SAFE: when the AgentBridge is live we auto-start before the first frame, so an
	# autonomous playtest never stalls on a menu it has no button for (the harness only sees "playing").
	title_screen = VSTitleScreen.new()
	title_screen.start_requested.connect(start_run)
	title_screen.shop_requested.connect(_open_shop_from_title)
	add_child(title_screen)
	if AgentBridge.is_active():
		start_run()
	else:
		title_screen.open()

## Antonio Belpaese — the default (and currently only) playable character. Faithful to the
## GDD/offline wiki: he begins wielding the Whip (his starting weapon), with +20 Max Health
## (120 total) and +1 Armor, and gains +10% Might (a global weapon-damage multiplier, see
## might_mult) every 10 levels. Applied once at run start; upgrade_levels["whip"] is kept in
## lock-step with whip_level so the HUD build panel and level-up cap logic see the whip owned at Lv 1.
func _init_character() -> void:
	whip_level = 1
	upgrade_levels["whip"] = 1
	armor += 1
	if player:
		player.max_health += 20.0
		player.health = player.max_health

## Antonio's signature Might scaling: +10% weapon Damage for every 10 character levels,
## capped at +50% (reached at level 50), mirroring the wiki table (1-9 → x1.0, 10-19 → x1.1,
## …, 50+ → x1.5). Every weapon multiplies its damage by this so a higher-level Antonio hits
## harder across the board, not just via picked upgrades.
func might_mult() -> float:
	return 1.0 + 0.10 * float(clampi(level / 10, 0, 5))

## Global damage multiplier from Power level-up picks, so every OTHER owned weapon (whip,
## garlic, bible, lightning, knife, runetracer, fire wand) gets the build-wide bonus their card
## text promises, not just the Magic Wand (which reads weapon_damage directly instead). A flat
## +20%/pick on its own independent constant, NOT derived from weapon_damage's ratio — deriving
## it from the wand's own (small-base, flat +1/pick) curve made Power ~3-4x more DPS-efficient
## per pick than a weapon's own card once a build owns 2-3 weapons (playtest-tuning found via
## analysis, no Godot binary in this pass's env to play it live — see ws-01kwn3dwqxkrqqp3drjrp3wdgh).
const POWER_MULT_PER_PICK := 0.2   # +20% weapon damage per Power pick, max 5 picks => +100%
## Meta "Might" shop upgrade's build-wide slice: +10% weapon damage per level for every non-wand
## weapon (max 5 levels => +50%), stacked into power_mult via meta_power_mult. The wand's slice is
## its own flat +2/level on weapon_damage (see _apply_meta_powerups) — an independent constant, not
## derived from the wand's small-base flat curve, for the same DPS-balance reason as POWER_MULT_PER_PICK.
const META_MIGHT_MULT_PER_LEVEL := 0.10
func power_mult() -> float:
	return (1.0 + POWER_MULT_PER_PICK * float(upgrade_levels.get("damage", 0))) * meta_power_mult

## Global fire-rate multiplier from Haste level-up picks: mirrors power_mult() but shrinks every
## other weapon's own attack interval. Same independent-constant fix as power_mult() above.
const HASTE_MULT_PER_PICK := 0.2   # +20% attack speed per Haste pick, max 5 picks => +100%
func haste_mult() -> float:
	return meta_haste_mult / (1.0 + HASTE_MULT_PER_PICK * float(upgrade_levels.get("firerate", 0)))

## Read permanent PowerUps bought in the shop and fold them into this run's starting stats.
## Called once at run start so every run reflects the between-run meta-progression. Uses the
## POWERUPS catalog's ids; unknown/zero levels are simply no-ops.
func _apply_meta_powerups() -> void:
	var levels := MetaSave.load_powerups()
	var might := int(levels.get("might", 0))
	if might > 0:
		# Magic Wand reads weapon_damage directly; every OTHER weapon reads power_mult(), so fold
		# the shop's generically-worded Might into both — otherwise 7 of 8 weapons ignore it.
		weapon_damage += 2.0 * might
		meta_power_mult *= 1.0 + META_MIGHT_MULT_PER_LEVEL * might
	var armor := int(levels.get("armor", 0))
	if armor > 0 and player:
		player.max_health += 20.0 * armor
		player.health = player.max_health
	var haste := int(levels.get("haste", 0))
	if haste > 0:
		# Same split for Cooldown: the wand reads weapon_fire_interval directly; other weapons read
		# haste_mult(). pow(0.95, haste) is the same -5%/level ratio the shop card promises.
		weapon_fire_interval *= pow(0.95, haste)
		meta_haste_mult *= pow(0.95, haste)
	var boots := int(levels.get("boots", 0))
	if boots > 0:
		player_speed_mult *= pow(1.05, boots)
	var reroll := int(levels.get("reroll", 0))
	if reroll > 0:
		rerolls_left += reroll

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
		# Recovery (Pummarola): regenerate HP over time, capped at max_health so it tops up but
		# never overheals. Ticks only while playing (halts on the level-up/pause freeze) and only
		# on a living player, mirroring the other playing-phase stat effects.
		if recovery > 0.0 and player and player.alive and player.health < player.max_health:
			player.health = minf(player.max_health, player.health + recovery * delta)
		if not reaper_active:
			if elapsed >= RUN_DURATION:
				_summon_reaper()
		elif elapsed >= reaper_deadline:
			_on_victory()
	_update_shake(delta)
	_update_slowmo()
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

## Advance the evolution slow-mo, easing Engine.time_scale from SLOWMO_SCALE back to 1.0 over
## SLOWMO_DURATION real seconds. Timed off the wall clock so the recovery is immune to the very
## time_scale it's ramping (a scaled-delta tween would slow its own recovery into a crawl). Any
## exit from "playing" — the level-up/pause freeze, game-over, victory, restart — snaps time_scale
## back to 1.0 immediately so the dip never bleeds into a frozen screen or a later run.
func _update_slowmo() -> void:
	if not _slowmo_active:
		return
	if phase != "playing":
		Engine.time_scale = 1.0
		_slowmo_active = false
		return
	var t := float(Time.get_ticks_msec() - _slowmo_start_ms) / 1000.0 / SLOWMO_DURATION
	if t >= 1.0:
		Engine.time_scale = 1.0
		_slowmo_active = false
	else:
		Engine.time_scale = lerpf(SLOWMO_SCALE, 1.0, t)

## Begin the evolution slow-mo dip. Sets time_scale straight to SLOWMO_SCALE; _update_slowmo
## eases it back each frame. Idempotent-ish: a re-trigger simply restarts the window.
func _start_slowmo() -> void:
	_slowmo_active = true
	_slowmo_start_ms = Time.get_ticks_msec()
	Engine.time_scale = SLOWMO_SCALE

## Add a burst of camera trauma (0..1), capped at 1.0. Called on impacts.
func add_camera_shake(amount: float) -> void:
	_shake_trauma = minf(1.0, _shake_trauma + amount)

func _on_player_damaged(_amount: float) -> void:
	add_camera_shake(0.5)

## Weak fodder (a fresh bat's ~1-15 HP) shouldn't guarantee an XP gem on every kill — only
## tankier threats should feel like a sure payout. Chance ramps linearly from a 25% floor
## at/below GEM_DROP_FLOOR_HP up to a guaranteed drop at GEM_DROP_CEIL_HP (ELITE/REAPER
## territory), so the horde's early chaff reads as a gamble rather than a loot pinata.
## Lives in res://data/balance.csv so a designer can retune the curve without touching this
## script, same as the weapon damage/interval and player speed tunables above.
static var GEM_DROP_FLOOR_HP := BalanceData.get_value("gem_drop_floor_hp", 15.0)
static var GEM_DROP_FLOOR_CHANCE := BalanceData.get_value("gem_drop_floor_chance", 0.25)
static var GEM_DROP_CEIL_HP := BalanceData.get_value("gem_drop_ceil_hp", 180.0)

func _gem_drop_chance(enemy_max_health: float) -> float:
	if enemy_max_health <= GEM_DROP_FLOOR_HP:
		return GEM_DROP_FLOOR_CHANCE
	if enemy_max_health >= GEM_DROP_CEIL_HP:
		return 1.0
	var t := (enemy_max_health - GEM_DROP_FLOOR_HP) / (GEM_DROP_CEIL_HP - GEM_DROP_FLOOR_HP)
	return lerpf(GEM_DROP_FLOOR_CHANCE, 1.0, t)

func add_kill(at: Vector2, xp_value: int = 1, gem_count: int = 1, is_elite: bool = false, enemy_max_health: float = 3.0) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	# Wiki-faithful drop model (Pickups.md / Light_source.md): a defeated enemy drops ONLY an
	# Experience Gem, rolled against its own HP-scaled chance (_gem_drop_chance). Coins, Floor
	# Chicken, Rosary, Orologion, Vacuum/Magnet, etc. are LIGHT-SOURCE drops — they come from
	# shattering a candelabra (drop_candelabra_bonus), NOT from kills. Two deliberate exceptions,
	# both distinct from the baseline enemy drop: a "boss" elite (the Mad Forest wave table's
	# Bosses & Treasure column) additionally drops a Treasure Chest ("Dropped by strong enemies"),
	# and an active Gold Fever buff (the Gilded Clover mechanic) makes kills cough up bonus gold.
	if randf() < _gem_drop_chance(enemy_max_health):
		_spawn_gems(at, xp_value, gem_count)
	_maybe_drop_gold_fever_coin(at)
	if is_elite:
		_maybe_drop_chest(at)

## True while an Orologion freeze is active — enemies read this each frame and halt (see
## VSEnemy._process). Compared against the run's own `elapsed` clock so the freeze window
## pauses with the game rather than bleeding real seconds during a level-up.
func is_frozen() -> bool:
	return elapsed < freeze_until

## True while a Nduja Fritta Tanta buff is active — the player reads this each frame to ignore
## contact damage and sear nearby enemies (see VSPlayer._process). Compared against the run's own
## `elapsed` clock so the berserk window pauses with the game rather than bleeding real seconds.
func is_nduja_active() -> bool:
	return elapsed < nduja_until

## True while a Gold Fever (started by the Gilded Clover pickup) is active — add_kill reads
## this each kill to roll the bonus coin drop. Compared against the run's own `elapsed` clock
## so the window pauses with the game rather than bleeding real seconds during a level-up.
func is_gold_fever_active() -> bool:
	return elapsed < gold_fever_until

## Start (or refresh to the full 10s) a Gold Fever. Called by VSGildedClover on pickup.
func start_gold_fever() -> void:
	gold_fever_until = elapsed + GOLD_FEVER_DURATION

## Extend an active Gold Fever by `seconds` when a coin is collected (Gilded_Clover.md: Gold
## Coin/Coin Bag/Rich Coin Bag add 0.5/5/10s). No-op when no fever is running, and clamped so
## the timer can only ever be topped back up to — never past — the full GOLD_FEVER_DURATION.
func extend_gold_fever(seconds: float) -> void:
	if not is_gold_fever_active():
		return
	gold_fever_until = minf(gold_fever_until + seconds, elapsed + GOLD_FEVER_DURATION)

## Wiki's "TotalLuck" — the internal value the drop-weight/spawn-rate formulas key off, equal
## to 100 plus the displayed +N% Luck bonus (Luck.md "Mechanics" section).
func total_luck() -> float:
	return 100.0 + luck_bonus

## Luck's "fourth level-up option" (Luck.md "Mechanics" > "Fourth level up option"):
## chanceFourth = 1 - (1 / totalLuck), with totalLuck read as a ratio (100% Luck = 1.0). So base
## Luck (total_luck() == 100) yields 0% and every point of Luck widens the odds — e.g. +30% Luck
## (total 130) gives ~0.23, +50% (Clover maxed, total 150) ~0.33. Rolled per level-up in
## _roll_upgrades to sometimes widen the hand to a 4th real card. Returns a probability in [0, 1).
func _chance_fourth_option() -> float:
	var tl := total_luck()
	if tl <= 0.0:
		return 0.0
	return clampf(1.0 - (100.0 / tl), 0.0, 1.0)

## Critical hits (GDD "Damage, Crit, Knockback, I-Frames"). Every weapon hit rolls for a crit
## that deals CRIT_MULTIPLIER× damage. Faithful to the GDD's `crit = baseCritChance × totalLuck`:
## the slice's base weapons carry NO native crit chance, so at base 100% Luck the chance is 0 and
## damage is untouched (which also keeps the damage-assertion tests deterministic). Crit is instead
## the Clover/Luck build's payoff — the chance rises with the +Luck bonus (each Little Clover ~+5%),
## giving Luck a raw-damage identity it previously lacked (it only nudged drop weights and spawns).
## One global run stat rather than per-weapon: the wiki's per-weapon crit tables are out of the
## slice's data scope. Capped below certainty so crits stay a spike, not the norm.
const CRIT_CHANCE_PER_LUCK := 0.005   # +0.5% crit chance per +1% Luck bonus (~+5% per Little Clover)
const CRIT_CHANCE_MAX := 0.75
const CRIT_MULTIPLIER := 2.0

## Per-hit damage variance (offline wiki Damage.md: "Base damage ... has a random variance").
## Every weapon rolls its BASE damage within +/-DAMAGE_VARIANCE each time it fires/strikes,
## BEFORE flat per-level growth and the Might/Power multipliers apply. So a base-10 weapon with
## no level-ups and no Might lands anywhere in 5-15 per hit. Weapons multiply their BASE_DAMAGE
## by this each attack; the flat per-level bonus is added AFTER (only the base varies, per design).
const DAMAGE_VARIANCE := 0.5
func damage_variance() -> float:
	return randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

## Roll a crit for a single weapon hit of `amount` damage. Returns the (possibly doubled) damage
## and whether it critted, so the caller can flag the floating number. No Luck bonus -> no crit.
func roll_crit(amount: float) -> Dictionary:
	var chance := minf(luck_bonus * CRIT_CHANCE_PER_LUCK, CRIT_CHANCE_MAX)
	if chance > 0.0 and randf() < chance:
		return {"amount": amount * CRIT_MULTIPLIER, "crit": true}
	return {"amount": amount, "crit": false}

## Bank gold from a collected coin. Kept as a method so pickups and any future
## meta-progression hooks share one entry point onto the run's currency.
func add_gold(amount: int) -> void:
	gold += maxi(amount, 0)

## Count of chests opened this run, so open_chest can follow VS's fixed "beginner's luck" item
## sequence for the first six chests before settling to single-item drops.
var chests_opened := 0

## VS beginner's luck: the first six Treasure Chests grant this fixed sequence of item counts
## (1-1-3-1-1-5) — a couple of small spikes building to a big five-item jackpot — after which
## chests settle to a single item. Luck scaling that would bump these is base-100% in this slice.
const CHEST_LUCK_SEQ := [1, 1, 3, 1, 1, 5]

## Drop a Treasure Chest at an elite (mini-boss) kill — the VS "bosses drop chests" build-spike.
## Guaranteed per elite so power ramps on the ~35s elite cadence (the GDD's answer to the lean
## slice being hard past the midpoint). Suppressed once the finale Reaper is loose: that kill ends
## the run, so a chest there would never be collectible.
func _maybe_drop_chest(at: Vector2) -> void:
	if reaper_active:
		return
	var c := VSChest.new()
	c.position = at
	c.run = self
	add_child(c)
	AgentBridge.emit_event("spawn", {"type": "chest", "pos": [at.x, at.y]})

## Open a Treasure Chest (VSChest calls this on pickup): grant a burst of random not-yet-maxed
## upgrades (count from the beginner's-luck sequence) plus gold, then hand the gained item(s) and
## coin award to the VSChestScreen reveal animation so the spike reads as a crowned moment. Any
## item that can't be granted because everything is maxed converts to extra gold — faithful to VS's
## "full inventory → gold bag". No evolutions come from chests (slice scope).
func open_chest(at: Vector2) -> void:
	var count: int = CHEST_LUCK_SEQ[chests_opened] if chests_opened < CHEST_LUCK_SEQ.size() else 1
	chests_opened += 1
	add_camera_shake(0.5)
	var granted := 0
	var ids: Array[String] = []
	var titles: Array[String] = []
	for i in count:
		var id := _random_open_upgrade()
		if id == "":
			break   # everything maxed — remaining items convert to gold below
		_apply_upgrade(id)
		ids.append(id)
		titles.append(_upgrade_title(id))
		granted += 1
	var gold_award := count * randi_range(4, 8) + (count - granted) * 12
	add_gold(gold_award)
	# Freeze the run (entities gate on phase != "playing", like the level-up picker) and play the
	# chest-open reveal animation; the player resumes it via Continue -> _on_chest_continue.
	if chest_screen:
		phase = "chest"
		chest_screen.present(ids, titles, gold_award)
	elif hud:
		# Fallback for a headless run with no chest screen: the old centered HUD banner.
		hud.show_chest_reveal(titles, gold_award)
	AgentBridge.emit_event("chest_open", {"items": granted, "gold": gold_award})
	_maybe_drop_chest_consumable(at)

## Resume the run once the player dismisses the chest reveal (VSChestScreen.continued). The reward
## was already applied in open_chest; opening a chest never grants XP, so there's no pending
## level-up to chain into — we simply return to play.
func _on_chest_continue() -> void:
	if phase == "chest":
		phase = "playing"

## Occasionally have an opened chest also cough up a consumable power-up — the Nduja berserk,
## the Rosary screen-clear, or the Orologion freeze — so chests hand out temporary run-swinging
## treats, not just permanent upgrades and gold. Kept to a small chance (~15%) so it stays a
## lucky surprise; when it fires it picks one of the three treats at random. Spawned at the
## player (the chest's own position, where they're standing) so it's grabbed almost instantly.
func _maybe_drop_chest_consumable(at: Vector2) -> void:
	if randf() >= 0.15:
		return
	var here := player.position if (player != null and is_instance_valid(player)) else at
	var node: Node2D
	var kind: String
	match randi() % 3:
		0:
			node = VSNduja.new()
			kind = "nduja"
		1:
			node = VSRosary.new()
			kind = "rosary"
		_:
			node = VSFrozenClock.new()
			kind = "frozen_clock"
	node.position = here
	node.set("run", self)
	add_child(node)
	AgentBridge.emit_event("spawn", {"type": kind, "pos": [here.x, here.y]})

## Pick a random upgrade id that hasn't hit its cap yet (weapons, passives — never evolutions,
## which live outside UPGRADE_POOL). Returns "" when everything is maxed so open_chest pays gold.
func _random_open_upgrade() -> String:
	var pool := []
	for opt in UPGRADE_POOL:
		if int(upgrade_levels.get(opt["id"], 0)) < int(opt["max"]):
			pool.append(opt["id"])
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]

## Human-readable title for an upgrade id, for the chest's floating item labels.
func _upgrade_title(id: String) -> String:
	for opt in UPGRADE_POOL:
		if opt["id"] == id:
			return opt["title"]
	return id

## While a Gold Fever is active (see start_gold_fever, started by the Gilded Clover pickup),
## every kill has GOLD_FEVER_KILL_CHANCE to drop an extra Gold Coin (Gilded_Clover.md: "75%
## chance it drops a Gold Coin"). This is the ONLY coin a kill ever drops — the ordinary coin
## economy comes from shattering candelabra (drop_candelabra_bonus), not kills. Greed's coin-
## value multiplier doesn't exist in this slice yet, so the bonus is a flat 1 gold, matching
## the candelabra table's own Gold Coin tier.
func _maybe_drop_gold_fever_coin(at: Vector2) -> void:
	if not is_gold_fever_active() or randf() >= GOLD_FEVER_KILL_CHANCE:
		return
	var c := VSCoin.new()
	c.position = at
	c.run = self
	c.value = 1
	# Fever kill-coins only trickle the timer up (Gilded_Clover.md's 0.01s); the fever still
	# has to be renewed by grabbing light-source coin bags, keeping the HUD countdown honest.
	c.tier = VSCoin.Tier.KILL_DROP
	add_child(c)
	AgentBridge.emit_event("spawn", {"type": "coin", "pos": [at.x, at.y], "gold": 1})

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

## Light source drop table straight from the wiki's Light_source.md "Drops" table: relative
## weight and the player level each entry unlocks at (items below their min_level are excluded
## from the roll, matching the wiki's "unlock level is ignored ... even if the player were to
## hit it" note — they simply aren't in the pool yet). Gold Coin/Coin Bag/Rich Coin Bag are the
## wiki's three coin tiers (values 1/10/100) mapped onto the one VSCoin node via `coin_value`.
## Rerollo's own weight/level are undocumented on the wiki (shown as "?"); given the same
## rarity tier as Rosary/Nduja/Rich Coin Bag since it's an equally uncommon treat.
## `luck_scaled` mirrors Pickups.md's "Drop rate affected by Luck" column: Gold Coin, Coin Bag
## and Little Clover are "No" (their weight is flat); everything else is "Yes" and gets scaled
## by total_luck() in _candelabra_weight below.
const CANDELABRA_TABLE := [
	{"id": "gold_coin", "weight": 50.0, "min_level": 0, "coin_value": 1, "luck_scaled": false},
	{"id": "coin_bag", "weight": 10.0, "min_level": 0, "coin_value": 10, "luck_scaled": false},
	{"id": "rich_coin_bag", "weight": 1.0, "min_level": 5, "coin_value": 100, "luck_scaled": true},
	{"id": "rosary", "weight": 1.0, "min_level": 8, "coin_value": 0, "luck_scaled": true},
	{"id": "nduja", "weight": 1.0, "min_level": 0, "coin_value": 0, "luck_scaled": true},
	{"id": "orologion", "weight": 2.0, "min_level": 4, "coin_value": 0, "luck_scaled": true},
	{"id": "vacuum", "weight": 2.0, "min_level": 12, "coin_value": 0, "luck_scaled": true},
	{"id": "floor_chicken", "weight": 12.0, "min_level": 0, "coin_value": 0, "luck_scaled": true},
	{"id": "gilded_clover", "weight": 1.0, "min_level": 30, "coin_value": 0, "luck_scaled": true},
	{"id": "little_clover", "weight": 0.5, "min_level": 0, "coin_value": 0, "luck_scaled": false},
	{"id": "rerollo", "weight": 1.0, "min_level": 0, "coin_value": 0, "luck_scaled": false},
]

## Effective pool weight for one CANDELABRA_TABLE entry: Luck.md's "itemWeight = rarity *
## totalLuck" formula, normalized by /100 so the wiki-calibrated flat weights above keep their
## already-tuned proportions at base (0%) Luck and only shift as Luck rises/falls from there —
## applying the raw ~100-130 totalLuck value directly would blow those weights out of proportion
## against the two flat (non-luck-scaled) coin entries.
func _candelabra_weight(entry: Dictionary) -> float:
	var w: float = float(entry["weight"])
	if bool(entry.get("luck_scaled", false)):
		w *= total_luck() / 100.0
	return w

## Roll a random bonus when a candelabra is shattered (VSCandelabra calls this on break),
## weighted per CANDELABRA_TABLE (see _candelabra_weight for the Luck scaling). Reuses the same
## pickup nodes the kill-drops spawn; Rerollo is granted straight to the run's reroll budget
## (no pickup node).
func drop_candelabra_bonus(at: Vector2) -> void:
	var pool := []
	var total := 0.0
	for entry in CANDELABRA_TABLE:
		if level >= int(entry["min_level"]):
			pool.append(entry)
			total += _candelabra_weight(entry)
	var roll := randf() * total
	var picked: Dictionary = pool.back()
	for entry in pool:
		roll -= _candelabra_weight(entry)
		if roll < 0.0:
			picked = entry
			break
	match String(picked["id"]):
		"nduja":
			var n := VSNduja.new()
			n.position = at
			n.run = self
			add_child(n)
			AgentBridge.emit_event("spawn", {"type": "nduja", "pos": [at.x, at.y]})
		"rerollo":
			# No pickup node — the HUD reroll readout refreshes every frame, so the +1 shows
			# immediately. Pop a floating "+1 Reroll" tinted the same violet as the HUD token.
			rerolls_left += 1
			VSFloatText.spawn(self, at, "+1 Reroll", Color(0.72, 0.6, 1.0))
			AgentBridge.emit_event("reroll_bonus", {"rerolls_left": rerolls_left})
		"rosary":
			var r := VSRosary.new()
			r.position = at
			r.run = self
			add_child(r)
			AgentBridge.emit_event("spawn", {"type": "rosary", "pos": [at.x, at.y]})
		"orologion":
			var fc := VSFrozenClock.new()
			fc.position = at
			fc.run = self
			add_child(fc)
			AgentBridge.emit_event("spawn", {"type": "frozen_clock", "pos": [at.x, at.y]})
		"vacuum":
			var m := VSMagnet.new()
			m.position = at
			m.run = self
			add_child(m)
			AgentBridge.emit_event("spawn", {"type": "magnet", "pos": [at.x, at.y]})
		"floor_chicken":
			var f := VSFood.new()
			f.position = at
			f.run = self
			add_child(f)
			AgentBridge.emit_event("spawn", {"type": "food", "pos": [at.x, at.y]})
		"little_clover":
			var lc := VSLittleClover.new()
			lc.position = at
			lc.run = self
			add_child(lc)
			AgentBridge.emit_event("spawn", {"type": "little_clover", "pos": [at.x, at.y]})
		"gilded_clover":
			var gc := VSGildedClover.new()
			gc.position = at
			gc.run = self
			add_child(gc)
			AgentBridge.emit_event("spawn", {"type": "gilded_clover", "pos": [at.x, at.y]})
		_:
			# gold_coin / coin_bag / rich_coin_bag — same node, wiki-accurate value tier.
			var amount: int = int(picked["coin_value"])
			var c := VSCoin.new()
			c.position = at
			c.run = self
			c.value = amount
			# Tag the tier so a pickup during Gold Fever extends it by the right amount
			# (Gilded_Clover.md: 0.5/5/10s for Gold Coin/Coin Bag/Rich Coin Bag).
			match String(picked["id"]):
				"coin_bag":
					c.tier = VSCoin.Tier.COIN_BAG
				"rich_coin_bag":
					c.tier = VSCoin.Tier.RICH_COIN_BAG
				_:
					c.tier = VSCoin.Tier.GOLD_COIN
			add_child(c)
			AgentBridge.emit_event("spawn", {"type": "coin", "pos": [at.x, at.y], "gold": amount})

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

## GDD leveling rule: at most MAX_GROUND_GEMS loose XP gems exist on the ground at once; any
## excess merges into a single (red) gem. Bounds the live gem-node count so a late-game field
## that out-drops the player's pickup rate never balloons into thousands of per-frame nodes.
const MAX_GROUND_GEMS := 400

func _spawn_gem(at: Vector2, xp_value: int = 1) -> void:
	# On-ground gem cap: once the field already holds MAX_GROUND_GEMS gems, fold this drop's XP
	# into the nearest existing gem (which reddens/fattens) instead of adding another node, so the
	# reward is conserved and stays roughly where it fell while the node count holds at the cap.
	# Skipped when the run isn't in the scene tree (get_tree() null — only in standalone unit tests
	# that new() a VSRun without adding it), where there's no group to query and no cap to enforce.
	var tree := get_tree()
	if tree != null:
		var gems := tree.get_nodes_in_group("gems")
		if gems.size() >= MAX_GROUND_GEMS:
			var target: VSGem = null
			var best_d := INF
			for node in gems:
				var gm := node as VSGem
				if gm == null:
					continue
				var dd := gm.position.distance_squared_to(at)
				if dd < best_d:
					best_d = dd
					target = gm
			if target != null:
				target.absorb(xp_value)
				return
	var g := VSGem.new()
	g.position = at
	g.run = self
	g.value = xp_value
	add_child(g)

func collect_xp(amount: int) -> void:
	if phase != "playing":
		return
	# Growth scales incoming XP; bank the sub-integer remainder so the bonus accrues even on
	# the many 1-XP gems (where a per-gem round would otherwise discard it entirely).
	var scaled := float(amount) * xp_gain_mult + _xp_remainder
	var gained := int(floor(scaled))
	_xp_remainder = scaled - float(gained)
	xp += gained
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
		# Defensive fallback only: _roll_upgrades now pads a maxed build with Gold/Floor Chicken
		# consolation cards, so a non-empty hand is expected. If it is ever empty anyway, reward
		# the level with a small heal and resume without a screen so the run never soft-locks.
		if player:
			player.health = minf(player.max_health, player.health + 20.0)
		_pending_levels -= 1
		if _pending_levels > 0:
			_open_level_up()
		else:
			phase = "playing"
		return
	phase = "level_up"
	upgrade_screen.present(options, rerolls_left, self)

## Pick up to 3 distinct not-yet-maxed options (4 on a Luck roll — see below), each annotated
## with its current level so the card can show "Lv N → N+1". Maxed upgrades are excluded so the
## pool shrinks over the run and picks stay meaningful. Returns [] only when everything is maxed.
func _roll_upgrades() -> Array:
	var options := []
	# Evolutions take priority: when a weapon is maxed and its paired passive owned, always
	# surface the evolved card so the player never misses the (one-shot) evolution window.
	for evo in EVOLUTIONS:
		if _evolution_available(evo):
			var card: Dictionary = evo.duplicate()
			card["evolution"] = true      # no "level" key -> the card skips the Lv N->N+1 line
			options.append(card)
	# Inventory cap (GDD 6 weapons + 6 passives): tally what's already owned so a not-yet-owned
	# item of a full category can be withheld below. Only counts pool items (level >= 1), so
	# evolutions and consolation ids never inflate the count.
	var owned_weapons := 0
	var owned_passives := 0
	for opt in UPGRADE_POOL:
		if int(upgrade_levels.get(opt["id"], 0)) >= 1:
			if WEAPON_IDS.has(opt["id"]):
				owned_weapons += 1
			else:
				owned_passives += 1
	# Fill the remaining slots with normal not-yet-maxed upgrades.
	# The first two resolved level-ups offer weapons only — passive stat items are withheld so a
	# fresh run leads with weapon choices (see _levelups_resolved).
	var weapons_only := _levelups_resolved < 2
	var pool := []
	for opt in UPGRADE_POOL:
		if weapons_only and not WEAPON_IDS.has(opt["id"]):
			continue
		# Clover is unlock-gated (VS-style): it only joins the pool once the player has found
		# their first Little Clover, persisted in MetaSave so the unlock carries across runs.
		if opt["id"] == "luck" and not MetaSave.is_unlocked(CLOVER_UNLOCK_ID):
			continue
		var lvl: int = upgrade_levels.get(opt["id"], 0)
		if lvl >= int(opt["max"]):
			continue
		# A brand-new item (level 0) is withheld once its category's inventory is full; already-owned
		# items keep offering their upgrades regardless, so a full build still climbs to max level.
		if lvl == 0:
			if WEAPON_IDS.has(opt["id"]):
				if owned_weapons >= MAX_WEAPONS:
					continue
			elif owned_passives >= MAX_PASSIVES:
				continue
		var display: Dictionary = opt.duplicate()
		display["level"] = lvl        # current level; the pick raises it to lvl+1
		pool.append(display)
	pool.shuffle()
	# Guarantee at least one weapon powerup in every hand that CAN offer one: if the shuffled pool
	# holds a weapon (new or upgradable) but no weapon already leads the hand (an evolution card
	# counts), move one weapon to the front so the fill loop always includes it. The rest stays
	# shuffled, so WHICH weapon and which passives fill the other slots is still random.
	if not _options_have_weapon(options):
		for i in pool.size():
			if WEAPON_IDS.has(pool[i]["id"]):
				pool.insert(0, pool.pop_at(i))
				break
	# Luck's fourth level-up option (Luck.md > Mechanics): a Luck-scaled chance to widen the hand
	# from 3 to 4 REAL cards. The extra slot is only granted when a genuine upgrade can fill it —
	# it is never padded with consolation below, so stacking Luck feels like more real choices, not
	# more filler. Base Luck (100) never triggers it; Clover / Little Clover / a Luck PowerUp do.
	var max_real := 4 if randf() < _chance_fourth_option() else 3
	for opt in pool:
		if options.size() >= max_real:
			break
		options.append(opt)
	# Pad any short hand (a near- or fully-maxed build leaves fewer than 3 real upgrades) with
	# GDD-faithful consolation picks — a coin bag or a Floor Chicken heal — so a level-up always
	# presents a full, rewarding choice instead of shrinking or (when everything is maxed)
	# silently resolving. Consolation ids are handled specially in _apply_upgrade and never enter
	# the inventory. Only fires late-run: early on the pool always fills all three slots.
	# Three distinct entries so a fully-maxed hand (which needs all three slots padded) never
	# repeats a card; cycling only two would show Gold twice. Ordered so shorter hands still lead
	# with the smaller consolations before the larger Gold Sack.
	var pad := [
		{"id": "bonus_gold", "title": "Gold", "desc": "+%d Gold" % BONUS_GOLD_AMOUNT},
		{"id": "bonus_chicken", "title": "Roast Chicken", "desc": "Heals %d HP" % int(BONUS_CHICKEN_HEAL)},
		{"id": "bonus_gold_big", "title": "Gold Sack", "desc": "+%d Gold" % BONUS_GOLD_BIG_AMOUNT},
	]
	var pi := 0
	while options.size() < 3:
		options.append(pad[pi % pad.size()].duplicate())
		pi += 1
	return options.slice(0, max_real)

## True when the hand already contains a weapon powerup — either an evolution card (itself a
## weapon upgrade) or a base weapon pick (id in WEAPON_IDS). Used to decide whether _roll_upgrades
## must force a weapon into an otherwise all-passive hand.
func _options_have_weapon(opts: Array) -> bool:
	for o in opts:
		if bool(o.get("evolution", false)) or WEAPON_IDS.has(o.get("id", "")):
			return true
	return false

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
	_levelups_resolved += 1
	_pending_levels -= 1
	if _pending_levels > 0:
		_open_level_up()
	else:
		phase = "playing"

## Spend a reroll to re-roll the SAME level-up (the pending count is untouched), giving a
## fresh hand from _roll_upgrades(). Guarded on budget so a stale signal can't overspend.
func _on_upgrade_rerolled() -> void:
	if rerolls_left <= 0:
		return
	rerolls_left -= 1
	AgentBridge.emit_event("upgrade_reroll", {"rerolls_left": rerolls_left})
	_open_level_up()

## Wave off this level-up with no pick — resolves one pending level and resumes (or opens the
## next queued level-up). Skip is always free; the run never soft-locks on a declined hand.
## GDD (Player Verbs) frames Skip as "forgo for partial XP", so declining a weak hand still
## nudges the build forward: bank a quarter of the next level's requirement toward it, capped
## just below the threshold so a skip never itself grants a free level-up. Carried in `xp`, so
## the reward simply shortens the gem grind to the next real pick.
func _on_upgrade_skipped() -> void:
	AgentBridge.emit_event("upgrade_skip", {"level": level})
	var need := _xp_to_next(level)
	xp = mini(xp + int(ceil(need * SKIP_XP_FRACTION)), need - 1)
	_levelups_resolved += 1
	_pending_levels -= 1
	if _pending_levels > 0:
		_open_level_up()
	else:
		phase = "playing"

func _apply_upgrade(id: String) -> void:
	# Consolation picks offered when the upgrade pool is exhausted (see _roll_upgrades). A coin
	# bag or a Floor Chicken heal — these aren't inventory items, so they bypass upgrade_levels
	# bookkeeping entirely (no ITEMS row, never counted toward maxed) and resolve here.
	match id:
		"bonus_gold":
			add_gold(BONUS_GOLD_AMOUNT)
			AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})
			return
		"bonus_gold_big":
			add_gold(BONUS_GOLD_BIG_AMOUNT)
			AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})
			return
		"bonus_chicken":
			if player:
				player.health = minf(player.max_health, player.health + BONUS_CHICKEN_HEAL)
			AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})
			return
	upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
	match id:
		"damage":
			weapon_damage += BalanceData.get_value("magic_wand_damage_per_level", 1.0)
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
		"area":
			area_mult *= 1.10
		"projspeed":
			projectile_speed_mult *= 1.15
		"attract":
			pickup_range_mult *= 1.30
		"growth":
			xp_gain_mult *= 1.08
		"armor":
			armor += 1
		"recovery":
			recovery += 0.2   # +0.2 HP/s per level, additive; max level 5 = +1.0 HP/s (Pummarola)
		"luck":
			luck_bonus += 10.0
		"garlic":
			garlic_level += 1
		"whip":
			whip_level += 1
		"bible":
			bible_level += 1
		"lightning":
			lightning_level += 1
		"knife":
			knife_level += 1
		"runetracer":
			runetracer_level += 1
		"fire_wand":
			fire_wand_level += 1
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
		"thousand_edges":
			# Knife -> Thousand Edges: VSKnife reads knife_evolved for its boosted profile.
			knife_evolved = true
			evolved[id] = true
		"hellfire":
			# Fire Wand -> Hellfire: VSFireWand reads fire_wand_evolved for its boosted,
			# piercing profile.
			fire_wand_evolved = true
			evolved[id] = true
		"thunder_loop":
			# Lightning Ring -> Thunder Loop: VSLightning reads lightning_evolved for its
			# boosted profile (more bolts, wider splash, a re-strike per bolt).
			lightning_evolved = true
			evolved[id] = true
		"no_future":
			# Runetracer -> NO FUTURE: VSRunetracer reads runetracer_evolved for its boosted
			# profile (more runes, faster carom, bigger hits, longer life).
			runetracer_evolved = true
			evolved[id] = true
	# Weapon evolution is the run's biggest, rarest power spike — crown it with a jolt, a centered
	# HUD banner, and a bloom at the player so the moment reads as a "wow" rather than a silent flag
	# flip. `evolved.has(id)` is true exactly for an evolution just applied (the match set it above);
	# every ordinary upgrade leaves `evolved` untouched, so this fires only on the fusion moment.
	if evolved.has(id):
		_celebrate_evolution(id)
	AgentBridge.emit_event("upgrade_chosen", {"id": id, "level": level})

## Fanfare for a weapon evolution: a hard camera jolt (matched to the Reaper-arrival tier), a brief
## slow-mo dip (see _start_slowmo) for weight, the centered HUD "WEAPON EVOLVED!" banner naming the
## evolved form, and a gold bloom at the player.
func _celebrate_evolution(id: String) -> void:
	add_camera_shake(1.0)
	_start_slowmo()
	if hud:
		hud.show_evolution(_evolution_title(id))
	if player and is_instance_valid(player):
		VSPickupFlash.spawn(self, player.position, Color(1.0, 0.85, 0.3))

## The display title of an evolution id (e.g. "bloody_tear" -> "Bloody Tear"), read from
## EVOLUTIONS. Returns "" if the id isn't an evolution, so a non-evolution never banners.
func _evolution_title(id: String) -> String:
	for evo in EVOLUTIONS:
		if evo["id"] == id:
			return evo["title"]
	return ""

## Debug-only (agent gate): fast-forward the given weapon to its max level and its paired
## evolution passive to level 1, then grant a level-up so the very next picker surfaces that
## weapon's evolution card (evolutions always lead the hand — see _roll_upgrades). Lets the
## harness reach the normally-many-levels-deep evolution moment to verify the WEAPON EVOLVED!
## fanfare. Called from agent_adapter's force_evolution command; inert in real builds.
func force_evolution_ready(weapon_id: String) -> void:
	var evo: Dictionary = {}
	for e in EVOLUTIONS:
		if e["weapon"] == weapon_id:
			evo = e
			break
	if evo.is_empty():
		return
	upgrade_levels[weapon_id] = _upgrade_max(weapon_id)
	var passive: String = evo["passive"]
	upgrade_levels[passive] = maxi(1, int(upgrade_levels.get(passive, 0)))
	_pending_levels += 1
	_open_level_up()

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

## Toggle the paused breather. Reuses the very freeze the level-up screen relies on: every
## entity halts on phase != "playing", so flipping to "paused" stops the player, the horde,
## every weapon, the spawner, and the elapsed/reaper clocks in one move, and "playing" resumes
## them exactly where they stood. Only meaningful from active play (guarded by the caller).
func _set_paused(on: bool) -> void:
	phase = "paused" if on else "playing"
	AgentBridge.emit_event("pause", {"paused": on})
	if hud:
		hud.refresh(self)

## Leave the title screen and begin the run. Idempotent (guards on the title phase) so a double
## Start press — or a race between the Start button, the keyboard, and the harness auto-start —
## can only ever kick the run off once.
func start_run() -> void:
	if phase != "title":
		return
	phase = "playing"
	if title_screen:
		title_screen.close()
	AgentBridge.emit_event("start", {})

## Open the between-run PowerUp shop from the title (so meta-coins can be spent before the first
## dive). Hides the title while the shop is up; _on_shop_closed brings the menu back on dismiss.
func _open_shop_from_title() -> void:
	if title_screen:
		title_screen.close()
	if shop_screen:
		shop_screen.open()

## The PowerUp shop was dismissed. From the title we restore the menu (buy PowerUps, then Start);
## from the game-over screen the shop simply hides back to the run summary, so guard on the phase.
func _on_shop_closed() -> void:
	if phase == "title" and title_screen:
		title_screen.open()

func _unhandled_input(event: InputEvent) -> void:
	# Title / main menu: Enter (or the focused Start button) begins the run; B drops into the
	# PowerUp shop. The world stays frozen in the "title" phase until Start fires.
	if phase == "title":
		if shop_screen and shop_screen.visible:
			return   # the shop owns its own input while it's open
		if event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			start_run()
		elif event.is_action_pressed("open_shop"):
			get_viewport().set_input_as_handled()
			_open_shop_from_title()
		return
	# ESC pause/resume, but only over active play — never over the level-up picker, the shop,
	# or the end screen (each owns its own flow), so a stray ESC can't strand the run.
	if event.is_action_pressed("pause") and (phase == "playing" or phase == "paused"):
		get_viewport().set_input_as_handled()
		_set_paused(phase == "playing")
		return
	# While paused the overlay is a minimal menu: ESC (handled above) resumes, Enter restarts
	# the run — mirroring the game-over retry so a stuck build can be abandoned without dying.
	if phase == "paused" and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
		return
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
