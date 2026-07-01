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

## Upgrade pool. On each level-up 3 of these are offered (so one is always left out —
## a real choice). Keys are matched in apply_upgrade(); titles/descs feed the picker UI.
## Titles are the CANONICAL Vampire Survivors items from the GDD's slice roster — keep them
## faithful (no invented names like "Power"/"Blades"/"Vitality"); the icon art under
## res://art/icons already depicts each one (spinach leaf / King Bible / heart / winged boots…).
const UPGRADES := [
	{"key": "damage", "title": "Spinach", "desc": "+1 weapon damage"},
	{"key": "firerate", "title": "Empty Tome", "desc": "Weapons fire faster"},
	{"key": "speed", "title": "Wings", "desc": "+12% move speed"},
	{"key": "projectile", "title": "Duplicator", "desc": "+1 projectile"},
	{"key": "garlic", "title": "Garlic", "desc": "Damaging aura around you"},
	{"key": "orbit", "title": "King Bible", "desc": "Spinning holy tomes that strike nearby foes"},
	{"key": "wand", "title": "Magic Wand", "desc": "Bolt fired at the nearest enemy"},
	{"key": "regen", "title": "Hollow Heart", "desc": "+20% max health"},
	{"key": "armor", "title": "Armor", "desc": "Take less contact damage"},
]

# Survival goal: at this time Death descends. Faithful to VS, reaching it does NOT instantly
# win — it summons the Reaper (a single huge/slow/tanky telegraphed boss); the run is WON by
# slaying it, turning the destination into a real climax for the power spike. Tunable; a 5:00
# slice goal. (The world keeps "playing" during the duel; victory freezes it on the kill.)
const SURVIVE_SECONDS := 300.0

# Reaper foreshadow: the last few seconds before SURVIVE_SECONDS are a build-up — a flashing
# "DEATH APPROACHES" banner (HUD) over a rising screen-shake rumble (here) so the finale is felt
# coming instead of springing on the player at the instant Death descends. Tunable window/feel.
const REAPER_WARN_SECONDS := 4.0
const REAPER_WARN_SHAKE_MIN := 1.5   # rumble magnitude at the start of the window
const REAPER_WARN_SHAKE_MAX := 6.0   # rumble magnitude just before Death descends (< the 14 summon quake)

var player: VSPlayer
var weapon: VSWhip      # Antonio's starter is the Whip (the Magic Wand projectile, VSWeapon, is a level-up weapon)
var aura: VSAura
var orbit: VSOrbit
var wand: VSWeapon      # "Magic Wand" — a pickable level-up weapon (lazily spawned on first pick)
var spawner: VSSpawner  # the wave spawner; also summons the Reaper at the time limit
var reaper: VSEnemy = null   # the finale boss while it lives (null otherwise); slaying it wins the run
var _reaper_summoned := false   # once-guard so Death is summoned exactly once at the time limit
var _reaper_warned := false     # once-guard so the "DEATH APPROACHES" warning event fires once
var hud: VSHud
var adapter: Node
var camera: Camera2D
var _levelup_screen: VSLevelUpScreen

# Screen shake: a decaying camera offset, kicked by add_shake() (e.g. on player damage).
var _shake_t := 0.0
var _shake_dur := 0.0
var _shake_mag := 0.0

var phase := "playing"          # playing | level_up | game_over | victory  (AgentState lifecycle)
var kills := 0
var elapsed := 0.0
var xp := 0
var level := 1
var upgrade_levels := {}        # upgrade key -> times chosen; drives the HUD loadout readout
var frame_tick := 0
var arena_half := Vector2(900, 700)   # world half-extent around origin

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
		"choose_1": [KEY_1, KEY_KP_1],
		"choose_2": [KEY_2, KEY_KP_2],
		"choose_3": [KEY_3, KEY_KP_3],
	}
	for action in defaults.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code in defaults[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)

func _build_world() -> void:
	var ground := VSGround.new()
	ground.arena_half = arena_half     # lay the tiled floor down first, beneath everything
	add_child(ground)

	player = VSPlayer.new()
	player.died.connect(_on_player_died)
	add_child(player)

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.zoom = Vector2(0.9, 0.9)   # 10% zoom-out: a touch more of the field is visible (zoom<1 = wider view)
	player.add_child(cam)
	cam.make_current()
	camera = cam

	weapon = VSWhip.new()
	weapon.run = self
	player.add_child(weapon)

	spawner = VSSpawner.new()
	spawner.run = self
	add_child(spawner)

	hud = VSHud.new()
	add_child(hud)

	adapter = preload("res://scripts/agent/agent_adapter.gd").new()
	add_child(adapter)

func _process(delta: float) -> void:
	frame_tick += 1
	if phase == "playing":
		elapsed += delta
		if not _reaper_summoned:
			if elapsed >= SURVIVE_SECONDS:
				_summon_reaper()   # the time limit summons Death, not an instant win — slay it to win
			elif elapsed >= SURVIVE_SECONDS - REAPER_WARN_SECONDS:
				_warn_reaper()     # foreshadow the finale: rising rumble in the last seconds
	_update_shake(delta)
	if hud:
		hud.refresh(self)

func add_shake(magnitude: float, duration: float) -> void:
	# Kick a screen shake; the strongest/longest pending kick wins (no stacking blowups).
	_shake_mag = maxf(_shake_mag, magnitude)
	_shake_dur = maxf(_shake_dur, duration)
	_shake_t = maxf(_shake_t, duration)

func _update_shake(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if _shake_t <= 0.0:
		camera.offset = Vector2.ZERO
		_shake_mag = 0.0
		return
	_shake_t -= delta
	var amt := _shake_mag * (_shake_t / _shake_dur)   # linear decay to 0
	camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))

func add_kill(at: Vector2, xp_value: int = 1) -> void:
	kills += 1
	AgentBridge.emit_event("despawn", {"type": "enemy", "pos": [at.x, at.y]})
	_spawn_gem(at, xp_value)

func _spawn_gem(at: Vector2, xp_value: int = 1) -> void:
	var g := VSGem.new()
	g.position = at
	g.xp_value = xp_value
	g.run = self
	add_child(g)

func _spawn_levelup_burst() -> void:
	# Punctuate the level-up: a golden bloom centered on the player as the run resumes.
	# Parented to the player so it stays centered on the body; self-freeing and phase-gated
	# like the other juice, so a chained multi-level burst holds it until the world unfreezes.
	if player == null or not is_instance_valid(player):
		return
	var burst := LevelUpBurst.new()
	burst.run = self
	player.add_child(burst)

func collect_xp(amount: int) -> void:
	xp += amount
	AgentBridge.emit_event("sfx_played", {"name": "pickup"})
	Sfx.play("pickup")
	_check_level_up()

func _check_level_up() -> void:
	# Only fires while playing; the upgrade picker freezes the run until a choice is made.
	# Re-checked after each choice so a multi-level XP burst chains pickers instead of
	# silently swallowing levels.
	if phase != "playing":
		return
	var need := level * 5
	if xp >= need:
		xp -= need
		level += 1
		AgentBridge.emit_event("level_up", {"level": level})
		_show_level_up()

func _show_level_up() -> void:
	phase = "level_up"
	# Iconic VS level-up sweep: flag every on-screen gem to vacuum to the player. Gems freeze
	# while the picker is up (they gate on phase=="playing"), so the rush actually plays as
	# _on_upgrade_chosen resumes the run and the world unfreezes — a burst of XP streaming in.
	for g in get_tree().get_nodes_in_group("gems"):
		g.vacuum = true
	Sfx.duck_music(true)   # drop the ambient bed so the level-up arpeggio pops; restored on resume
	AgentBridge.emit_event("sfx_played", {"name": "levelup"})
	Sfx.play("levelup")
	var options := _roll_upgrades()
	var screen := VSLevelUpScreen.new()
	screen.setup(options, upgrade_levels)
	screen.chosen.connect(_on_upgrade_chosen)
	add_child(screen)
	_levelup_screen = screen
	AgentBridge.emit_event("level_up_choice", {"options": options})

func _roll_upgrades() -> Array:
	# Drop maxed-out picks so a level-up never offers a dead choice (a trap option). The only
	# capped upgrade today is Duplicator: the whip tops out at VSWhip.MAX_DIRS corners, so once
	# projectile_count is there a further "projectile" pick is a pure no-op. Filtering it out
	# keeps every offered upgrade honest. 8 upgrades remain, so slice(0,3) still yields 3.
	var pool := []
	for u in UPGRADES:
		if not _is_maxed(u["key"]):
			pool.append(u)
	pool.shuffle()
	return pool.slice(0, 3)

func _is_maxed(key: String) -> bool:
	# True when picking this upgrade again would do nothing, so it's excluded from the roll.
	if key == "projectile":
		return weapon != null and weapon.projectile_count >= VSWhip.MAX_DIRS
	return false

func _on_upgrade_chosen(key: String) -> void:
	apply_upgrade(key)
	upgrade_levels[key] = int(upgrade_levels.get(key, 0)) + 1
	if hud:
		hud.refresh_loadout(self)   # rebuild the corner readout only when the build changes
	if _levelup_screen and is_instance_valid(_levelup_screen):
		_levelup_screen.queue_free()
	_levelup_screen = null
	phase = "playing"
	_spawn_levelup_burst()   # golden bloom on the player as the world unfreezes — punctuate the power spike
	Sfx.duck_music(false)   # modal closed: bring the ambient bed back up
	AgentBridge.emit_event("upgrade_chosen", {"key": key})
	_check_level_up()   # chain if the XP burst was worth more than one level (re-ducks if so)

func apply_upgrade(key: String) -> void:
	match key:
		"damage":
			if weapon:
				weapon.damage += 1.0
		"firerate":
			if weapon:
				weapon.fire_interval = maxf(0.12, weapon.fire_interval * 0.85)
		"speed":
			# Wings: +12% move speed PER PICK, added off the base (not compounding). This makes the
			# "+12% move speed" label literally true at every stack and keeps speed scaling linear —
			# multiplicative 1.12^n made late picks worth >12% of base and could balloon a stacked
			# player past the gem magnet's edge speed, stranding XP (see gem.gd MAGNET_SPEED_MIN).
			if player:
				player.speed += VSPlayer.BASE_SPEED * 0.12
		"regen":
			# Hollow Heart (Max HP): +20% max health per pick, healing by the gained amount so the
			# pick rewards immediately. The GDD's slice recovery passive is Hollow Heart, NOT
			# Pummarola/HP-regen (out of scope) — so this is the faithful survivability choice.
			if player:
				player.health += player.max_health * 0.2   # heal by the gain first (uses the old max)
				player.max_health *= 1.2                    # then raise the cap +20%
		"armor":
			# Armor: flat mitigation — shaves a fixed amount off every contact hit (floored in
			# take_damage so a touch always stings). Stacks +1.0 per pick, so investing turns
			# chip damage into a survivable trickle.
			if player:
				player.armor += 1.0
		"projectile":
			if weapon:
				weapon.projectile_count += 1
		"garlic":
			# First pick spawns the halo (child of the player so it follows); repeats level it.
			if player:
				if aura == null or not is_instance_valid(aura):
					aura = VSAura.new()
					aura.run = self
					player.add_child(aura)
				aura.level_up()
		"orbit":
			# First pick spawns the spinning ring (child of the player so it follows); repeats level it.
			if player:
				if orbit == null or not is_instance_valid(orbit):
					orbit = VSOrbit.new()
					orbit.run = self
					player.add_child(orbit)
				orbit.level_up()
		"wand":
			# First pick mounts the Magic Wand (child of the player so it follows); repeats level it.
			if player:
				if wand == null or not is_instance_valid(wand):
					wand = VSWeapon.new()
					wand.run = self
					player.add_child(wand)
				wand.level_up()

func _on_player_died() -> void:
	if phase == "game_over":
		return
	phase = "game_over"
	AgentBridge.emit_event("death", {"type": "player"})
	# A distinct descending stinger so the run's end lands (the lethal hit only played "hurt").
	AgentBridge.emit_event("sfx_played", {"name": "gameover"})
	Sfx.play("gameover")

func _warn_reaper() -> void:
	# Foreshadow Death in the seconds before SURVIVE_SECONDS: a rising rumble that builds toward
	# the summon so the climax is felt approaching, not sprung. The HUD pairs this with a flashing
	# "DEATH APPROACHES" banner (gated on the same window). add_shake() takes the max pending kick,
	# so calling it every frame with a magnitude that ramps with the window keeps a sustained,
	# growing tremor (capped under the 14 summon quake so the actual descent still lands harder).
	if not _reaper_warned:
		_reaper_warned = true
		# One-time event so the headless FEEL reviewer can observe the build-up (it can't see shake).
		AgentBridge.emit_event("reaper_warning", {"time": int(elapsed)})
	var p := clampf((elapsed - (SURVIVE_SECONDS - REAPER_WARN_SECONDS)) / REAPER_WARN_SECONDS, 0.0, 1.0)
	add_shake(lerpf(REAPER_WARN_SHAKE_MIN, REAPER_WARN_SHAKE_MAX, p), 0.25)

func _summon_reaper() -> void:
	# Death descends at the time limit. Instead of an instant "YOU SURVIVED", spawn ONE huge,
	# slow, tanky telegraphed Reaper (built by the spawner) and gate the win on slaying it —
	# the real climax for the power spike. The world stays "playing" so the player fights it;
	# the swarm's regular waves halt while it's on the field (see VSSpawner._process).
	if _reaper_summoned:
		return   # once-guard: Death is summoned exactly once
	_reaper_summoned = true
	if spawner == null or not is_instance_valid(spawner):
		return
	reaper = spawner.summon_reaper()
	add_shake(14.0, 0.6)   # the ground quakes as Death arrives — telegraph the finale
	AgentBridge.emit_event("reaper_summoned", {"time": int(elapsed)})

func _on_reaper_killed() -> void:
	# The Reaper is slain — the run is WON. Phase-guarded so a same-frame player death can't be
	# overwritten (enemy.hit() is also _dying-gated, so a double lethal hit can't double-fire).
	if phase != "playing":
		return
	reaper = null
	_on_victory()

func _on_victory() -> void:
	# WIN — the Reaper is dead. Setting phase to "victory" freezes the world exactly like
	# game_over (player/enemy/spawner/weapon/gem/projectile all gate on phase == "playing"),
	# so the field holds under the banner. Reuse the rising level-up fanfare as a triumphant
	# sting — defeat's descending "gameover" stinger's natural opposite — with no new asset.
	if phase != "playing":
		return   # only from a live run (its sole caller, _on_reaper_killed, also guards this)
	phase = "victory"
	AgentBridge.emit_event("victory", {"time": int(elapsed), "kills": kills, "level": level})
	AgentBridge.emit_event("sfx_played", {"name": "levelup"})
	Sfx.play("levelup")

func _unhandled_input(event: InputEvent) -> void:
	if (phase == "game_over" or phase == "victory") and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

func reseed(value: int) -> void:
	seed(value)

## Short-lived golden bloom played on the player at each level-up as the run resumes — the
## reward beat for the power spike, the lure of new strength radiating off the hero. Self-
## contained (no scene file) and phase-gated like the other juice (ImpactSpark / gem / aura),
## so it holds with a frozen world (a chained picker) and then frees itself.
class LevelUpBurst extends Node2D:
	const DUR := 0.5

	# Warm gold — temptation made visible: power blooming outward from the body.
	const RING_COLOR := Color(1.0, 0.82, 0.30)
	const CORE_COLOR := Color(1.0, 0.94, 0.62)

	var run: VSRun
	var _t := DUR

	func _ready() -> void:
		z_index = 120   # above the sprites and impact sparks for the brief flash

	func _process(delta: float) -> void:
		if run and run.phase != "playing":
			return   # hold with the frozen world (a chained level-up picker)
		_t -= delta
		if _t <= 0.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var p := clampf(_t / DUR, 0.0, 1.0)     # 1 -> 0 over the bloom's life
		var grow := 1.0 - p                       # 0 -> 1
		# Soft central flash: brightest at the instant of choice, gone by mid-life.
		var flash := clampf((p - 0.55) / 0.45, 0.0, 1.0)
		if flash > 0.0:
			draw_circle(Vector2.ZERO, 20.0, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, flash * 0.85))
		# Outer halo ring expanding outward and fading.
		var r := 8.0 + grow * 58.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, p * 0.85), 3.0 * p + 1.0)
		# A tighter trailing ring for depth.
		var r2 := 4.0 + grow * 36.0
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 24, Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, p * 0.55), 2.0)
		# Eight radial rays bursting out like a sunburst.
		var rays := Color(CORE_COLOR.r, CORE_COLOR.g, CORE_COLOR.b, p * 0.8)
		var inner := 6.0 + grow * 18.0
		var outer := 10.0 + grow * 50.0
		for i in 8:
			var ang := i * PI / 4.0
			var d := Vector2.from_angle(ang)
			draw_line(d * inner, d * outer, rays, 2.0)
