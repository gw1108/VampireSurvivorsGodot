class_name VSSpawner
extends Node2D
## Time-based wave spawner. Spawns enemies on a ring just outside view around the
## player; the rate ramps up over the run, AND each enemy hardens with time survived
## (more HP, a little more contact damage, bigger + red-shifted so it reads). It also
## varies the wave in KIND — fast fragile "ghost" swarmers and rare slow/tanky "brute"
## walls mix in more often the longer you survive — so escalation isn't purely toughness.
## Capped for performance. The hardening is what makes the Power/Multishot upgrades matter.

const MAX_ENEMIES := 90
const SPAWN_RING := 520.0
const GHOST_SPRITE := preload("res://art/enemy_ghost.png")
const BRUTE_SPRITE := preload("res://art/enemy_brute.png")

var run: VSRun
var _accum := 0.0

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null:
		return
	var rate := 1.0 + run.elapsed / 20.0   # enemies/sec, ramps with time survived
	_accum += rate * delta
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one()

func _spawn_one() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= MAX_ENEMIES:
		return
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.position = pos
	e.run = run
	e.target = run.player
	_apply_kind(e)          # pick bat vs ghost first; sets base stats + sprite
	_apply_difficulty(e)    # then harden HP/damage/visual on top, whatever the kind
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "enemy", "kind": e.kind, "pos": [pos.x, pos.y]})

func _apply_kind(e: VSEnemy) -> void:
	# Vary the wave in KIND, not just toughness. As the run wears on, two specials mix into the
	# slow sturdy bats, their odds ramping with time survived (one randf() partitions the roll,
	# the rest stay bats — so bats never vanish):
	#   - a rare slow/tanky "brute": a high-HP, high-contact WALL you can't chip down standing
	#     still, so it rewards kiting and makes Power/Multishot earn their keep;
	#   - a fast/fragile "ghost" swarmer that forces movement.
	# The player at 210 outruns both. _apply_difficulty() then hardens whichever kind this is,
	# so even specials gain HP/damage tiers over a long run.
	var brute_chance := clampf((run.elapsed - 30.0) / 180.0, 0.0, 0.18)  # rare; none before 30s
	var ghost_chance := clampf((run.elapsed - 5.0) / 120.0, 0.0, 0.5)
	var roll := randf()
	if roll < brute_chance:
		e.kind = "brute"
		e.sprite = BRUTE_SPRITE
		e.speed = 42.0           # slower than the bat's 62 — a shambling wall you kite around
		e.health = 20.0          # very tanky: soaks shots, so Power/Multishot earn their keep
		e.contact_damage = 14.0  # heavy touch (bat 8 / ghost 5) — getting cornered really hurts
		e.base_scale = 1.5       # reads BIG so the wall is legible at a glance
		e.radius = 22.0          # body matches the 1.5x sprite — a real wall to kite, not a small hitbox you clip past
		e.xp_value = 5           # drops a richer RED gem (~5 bats' worth) so soaking the 20-HP wall pays off — feeds the mid-run power spike
	elif roll < brute_chance + ghost_chance:
		e.kind = "ghost"
		e.sprite = GHOST_SPRITE
		e.speed = 112.0          # ~1.8x the bat's 62 — quick, but slower than the player's 210
		e.health = 2.0           # fragile: one or two shots, but they swarm in fast
		e.contact_damage = 5.0   # lighter touch than the bat's 8; danger is the pile-up, not one hit

func _apply_difficulty(e: VSEnemy) -> void:
	# Waves harden over the run: a new toughness tier every 30s survived. Later bats take
	# more hits and hit a little harder, and read as bigger + darker-red so the escalation
	# is legible (per VISUAL_RULES/GOAL). Stat growth is capped so a long run plateaus into
	# a grind, never an un-killable wall; speed is left constant (fast enemies feel unfair).
	var tier := int(run.elapsed / 30.0)
	if tier <= 0:
		return
	var stat_tier := mini(tier, 10)
	e.health += float(stat_tier)                    # +1 HP per tier, up to +10
	e.contact_damage += float(stat_tier) * 0.5      # gentler: up to +5 contact damage
	var vis := clampf(float(tier), 0.0, 6.0)
	e.base_scale *= 1.0 + vis * 0.05                # tier growth (up to ~1.30x) stacks on the kind's base
	e.radius *= 1.0 + vis * 0.05                    # body grows with the sprite so a hardened enemy's hitbox stays honest
	e.tier_tint = Color(1.0, 1.0 - vis * 0.07, 1.0 - vis * 0.07)   # hardened red-shift
