class_name VSSpawner
extends Node2D
## Time-based wave spawner. Spawns enemies on a ring just outside view around the
## player; the base trickle's rate and concurrent-count follow Mad Forest's real
## per-minute spawn table (see DENSITY_SCHEDULE). Capped for performance.

const MAX_ENEMIES := 90         # baseline concurrent-enemy render budget for most of the run
# Late-run escalation lever. The wiki's DENSITY_SCHEDULE climbs to 300 in the endgame, but every
# count past MAX_ENEMIES clamps to the baseline, so the endgame would otherwise read as one flat
# 90-enemy crush. Ramp the cap up over the final third so the late escalation the wiki intends
# actually shows on screen, up to the GDD's "periodic spawns stop at 300 alive" — the real
# Mad Forest late-game population. Now affordable because VSEnemy._separation is O(n) (see below).
const MAX_ENEMIES_LATE := 300   # cap the final-third ramp climbs toward (GDD: 300-alive periodic cap)
# Perf gate (historical). VSEnemy._separation USED to walk the whole 'enemies' group per enemy per
# frame — a clean O(n²) curve that ate the frame past ~130 enemies. It is now backed by a shared
# uniform spatial grid (VSEnemy._ensure_grid / _grid): each enemy scans only the 3×3 block of cells
# around it, so the horde's per-frame separation cost is ~O(n). That is what unlocks the 300-alive
# cap above. Any FURTHER raise past SEPARATION_SAFE_CAP should first re-profile the general per-node
# cost (Sprite2D + _process + weapon/VFX hit-testing), which is now the dominant term, not separation.
const SEPARATION_SAFE_CAP := 300  # max late cap validated with the O(n) grid-backed _separation
const LATE_RAMP_START := 0.667  # fraction of RUN_DURATION where the cap begins to climb (~20:00)
const SPAWN_RING := 520.0
const ELITE_INTERVAL := 35.0   # seconds between mini-boss spawns
const ELITE_FIRST := 35.0      # delay before the first elite appears
const WAVE_INTERVAL := 60.0    # seconds between minute-milestone wave surges
const WAVE_BASE := 8           # enemies in the first (1:00) surge
const WAVE_GROWTH := 6         # extra enemies per subsequent minute mark
const WAVE_OVERFLOW := 40      # headroom a surge may push past MAX_ENEMIES

# Directional swarm surge: a dense marching LINE that pours in from one random flank
# (spaced perpendicular to its approach) rather than a surrounding ring — VS's iconic
# "wall of enemies" you juke around, giving the move-only loop a directional threat to
# flee instead of only concentric pressure. Fires on its own cadence between the minute
# waves; count grows slowly with time survived and it shares the cap so it stays bounded.
const SURGE_INTERVAL := 22.0   # seconds between directional swarm walls
const SURGE_FIRST := 45.0      # delay before the first wall (after the early trickle finds its feet)
const SURGE_BASE := 6          # enemies in the line at SURGE_FIRST
const SURGE_GROWTH := 0.06     # extra line-members per second survived
const SURGE_MAX := 16          # cap the line length so a wall never becomes a full encirclement
const SURGE_SPACING := 46.0    # px between adjacent enemies along the wall

# Pincer variant: rarely, and only later in the run, a surge arrives as TWO mirrored walls
# marching in from opposite flanks (dir and -dir) at once, so the player must thread the gap
# between them along the shared perpendicular axis instead of simply fleeing one wall. Reuses
# the single-wall math for each side and shares MAX_ENEMIES, so it stays bounded.
const PINCER_FIRST := 150.0    # seconds survived before a surge may become a pincer
const PINCER_CHANCE := 0.25    # chance an eligible (late-run) surge doubles into a pincer

var run: VSRun
var _accum := 0.0
var _next_elite := ELITE_FIRST
var _next_wave := WAVE_INTERVAL
var _next_surge := SURGE_FIRST

func _ready() -> void:
	# Enforce the perf gate at load: separation is now O(n) via VSEnemy's uniform grid, so the late
	# cap can sit at the GDD's 300-alive population. Any raise past SEPARATION_SAFE_CAP should first
	# re-profile the now-dominant per-node cost (Sprite2D + _process + weapon hit-testing), not
	# separation. Debug-build only, so it never costs a shipped frame.
	assert(MAX_ENEMIES_LATE <= SEPARATION_SAFE_CAP,
		"MAX_ENEMIES_LATE > SEPARATION_SAFE_CAP: re-profile the per-node enemy cost (Sprite2D + _process + weapon hit-testing — now the dominant term, separation is O(n) via VSEnemy._grid) before raising the enemy cap further.")

func _process(delta: float) -> void:
	if run == null or run.phase != "playing" or run.player == null:
		return
	# Base trickle paced by Mad Forest's real per-minute spawn table: the "spawn interval
	# (seconds)" column sets how fast enemies enter (rate = 1/interval) and the "Enemy
	# minimum" column sets the concurrent population this stretch maintains. Both come from
	# DENSITY_SCHEDULE so the field ebbs and flows (the 5:00/10:00 lulls that frame the real
	# stage's minibosses read through) instead of pinning at the flat cap for the whole run.
	var density := _density()
	var rate: float = 1.0 / density.interval   # enemies/sec entering this minute
	var soft_cap: int = mini(int(density.count), _max_cap())
	_accum += rate * delta
	while _accum >= 1.0:
		_accum -= 1.0
		_spawn_one(soft_cap)
	if run.elapsed >= _next_elite:
		_next_elite += ELITE_INTERVAL
		_spawn_elite()
	# Each minute mark crescendos into a coordinated ring-burst so the run visibly
	# escalates toward RUN_DURATION. The final minute is skipped — the Reaper finale
	# owns that beat.
	if run.elapsed >= _next_wave and _next_wave < VSRun.RUN_DURATION:
		var minute := int(round(_next_wave / WAVE_INTERVAL))
		_next_wave += WAVE_INTERVAL
		_spawn_wave(minute)
	# Directional swarm walls fire between the minute rings for a different threat shape.
	# Skipped once the Reaper finale is imminent so the last beat belongs to the boss.
	if run.elapsed >= _next_surge and _next_surge < VSRun.RUN_DURATION - WAVE_INTERVAL:
		_next_surge += SURGE_INTERVAL
		_spawn_surge()

## Spawn a single base-trickle enemy on the ring, honoring the per-minute soft cap (the
## clamped "Enemy minimum" population target) so low-density minutes stay a genuine lull
## rather than refilling to the hard MAX_ENEMIES ceiling.
func _spawn_one(cap: int) -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= cap:
		return
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = _pick_type()
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "enemy", "pos": [pos.x, pos.y]})

## Spawn a single elite/mini-boss on the ring. Bypasses the enemy cap so the
## boss always shows up, and tags its event so tooling can tell it apart.
func _spawn_elite() -> void:
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.ELITE
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	AgentBridge.emit_event("spawn", {"type": "elite", "pos": [pos.x, pos.y]})

## Minute-milestone surge: drop a full ring of enemies around the player in one beat so the
## survival clock reads as escalating waves (a VS "wave" event) rather than a smooth trickle.
## Count grows with each minute mark; the burst may briefly exceed MAX_ENEMIES by WAVE_OVERFLOW
## so the crescendo lands, but stays bounded for performance.
func _spawn_wave(minute: int) -> void:
	var count := WAVE_BASE + maxi(minute - 1, 0) * WAVE_GROWTH
	var ceiling := _max_cap() + WAVE_OVERFLOW
	var base_ang := randf() * TAU
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= ceiling:
			break
		# Evenly space the ring (with a little jitter) so it reads as a coordinated surge.
		var ang := base_ang + TAU * float(i) / float(count) + randf_range(-0.12, 0.12)
		var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)
	AgentBridge.emit_event("wave", {"minute": minute, "count": count})

## Directional swarm wall: spawn a line of enemies off a single random flank, spaced
## perpendicular to their approach, so the horde sometimes arrives as a wall marching in
## from one side (the player flees perpendicular to it) instead of a surrounding ring.
## Length grows with time survived but is capped so it never becomes a full encirclement;
## shares MAX_ENEMIES so a wall never blows the performance budget.
func _spawn_surge() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= _max_cap():
		return
	var count := clampi(SURGE_BASE + int(run.elapsed * SURGE_GROWTH), SURGE_BASE, SURGE_MAX)
	# The flank the wall comes from; its perpendicular spread axis is derived per wall.
	var dir := Vector2.from_angle(randf() * TAU)
	# Later in the run a surge occasionally doubles into a PINCER: a second mirrored wall
	# marches in from the opposite flank (-dir) at the same time, forcing the player to thread
	# the gap between them rather than just fleeing one wall.
	var pincer := run.elapsed >= PINCER_FIRST and randf() < PINCER_CHANCE
	_spawn_wall(dir, count)
	if pincer:
		_spawn_wall(-dir, count)
	AgentBridge.emit_event("surge", {"count": count, "dir": [dir.x, dir.y], "pincer": pincer})
	# Telegraph the incoming wall on the HUD: flash an edge arrow pointing at the flank it
	# marches in from, so the player gets a beat to juke before it closes. The HUD holds a single
	# arrow, so a pincer telegraphs only the primary flank — its mirror stays a late-run surprise.
	if run.hud:
		run.hud.telegraph_surge(dir)

## Spawn one marching wall of `count` enemies off the `dir` flank, spaced evenly along the
## axis perpendicular to their approach and centered on the flank point. Honors MAX_ENEMIES on
## every enemy so a single wall — or a pincer's second wall — never blows the performance budget.
func _spawn_wall(dir: Vector2, count: int) -> void:
	var perp := dir.orthogonal()
	var center := run.player.position + dir * SPAWN_RING
	for i in count:
		if get_tree().get_nodes_in_group("enemies").size() >= _max_cap():
			break
		# Space members evenly along the wall, centered on the flank point.
		var lane := (float(i) - float(count - 1) * 0.5) * SURGE_SPACING
		var pos := center + perp * lane
		pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
		pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
		var e := VSEnemy.new()
		e.type = _pick_type()
		e.position = pos
		e.run = run
		e.target = run.player
		run.add_child(e)

## Summon the finale Reaper on the spawn ring. Modeled on _spawn_elite (bypasses the
## enemy cap, tags its event) but injects the single, near-unkillable REAPER that VSRun
## triggers at the survival time limit for the run's climactic last stand. Returns the
## node so the run can hand it to the HUD for the boss health bar.
func spawn_reaper() -> VSEnemy:
	var ang := randf() * TAU
	var pos := run.player.position + Vector2(cos(ang), sin(ang)) * SPAWN_RING
	pos.x = clampf(pos.x, -run.arena_half.x, run.arena_half.x)
	pos.y = clampf(pos.y, -run.arena_half.y, run.arena_half.y)
	var e := VSEnemy.new()
	e.type = VSEnemy.Type.REAPER
	e.position = pos
	e.run = run
	e.target = run.player
	run.add_child(e)
	# Telegraph the off-ring arrival with a crimson screen vignette so it reads as an
	# event, echoing the HUD 'THE REAPER COMES' banner.
	VSReaperVignette.spawn(run)
	AgentBridge.emit_event("spawn", {"type": "reaper", "pos": [pos.x, pos.y]})
	return e

## Roster schedule modeled directly on Mad Forest's real per-minute wave table
## (.firecrawl/wiki-offline/Mad_Forest.htm, "Waves" section: 0:00 Pipeestrello,
## 1:00 Zombie, 3:00 Skeleton, 5:00 Green Mudman, 12:00 Werewolf, 16:00 Mantichana,
## 25:00 Venus, etc). RUN_DURATION is already 1800s (30:00), matching Mad Forest's
## real time limit exactly, so minute marks below map 1:1 — no stretching needed.
## Green/Gray Mudman and Werewolf now have their own VSEnemy.Type + sprite, so the bands
## where the wiki introduces them point at the real archetypes (MUDMAN from 5:00, WEREWOLF
## from 12:00). The remaining named enemies without a distinct sprite yet stay role-mapped:
## Pipeestrello -> BAT, Big Mummy -> MUMMY, Venus/Mantichana -> MANTIS_WARRIOR.
## Each entry's weights apply from its minute mark until the next entry's.
const ROSTER_SCHEDULE := [
	{"min": 0.0,  "weights": {VSEnemy.Type.BAT: 1.0}},
	{"min": 1.0,  "weights": {VSEnemy.Type.ZOMBIE: 0.4, VSEnemy.Type.BAT: 0.6}},
	{"min": 2.0,  "weights": {VSEnemy.Type.BAT: 1.0}},
	{"min": 3.0,  "weights": {VSEnemy.Type.SKELETON: 1.0}},
	{"min": 4.0,  "weights": {VSEnemy.Type.SKELETON: 0.6, VSEnemy.Type.GHOST: 0.4}},
	{"min": 5.0,  "weights": {VSEnemy.Type.MUDMAN: 1.0}},
	{"min": 6.0,  "weights": {VSEnemy.Type.ZOMBIE: 0.5, VSEnemy.Type.MUDMAN: 0.5}},
	{"min": 7.0,  "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.MUDMAN: 0.5}},
	{"min": 8.0,  "weights": {VSEnemy.Type.ZOMBIE: 1.0}},
	{"min": 9.0,  "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.ZOMBIE: 0.5}},
	{"min": 10.0, "weights": {VSEnemy.Type.MUDMAN: 1.0}},
	{"min": 11.0, "weights": {VSEnemy.Type.SKELETON: 1.0}},
	{"min": 12.0, "weights": {VSEnemy.Type.WEREWOLF: 0.4, VSEnemy.Type.GHOST: 0.3, VSEnemy.Type.SKELETON: 0.3}},
	{"min": 13.0, "weights": {VSEnemy.Type.WEREWOLF: 0.5, VSEnemy.Type.GHOST: 0.5}},
	{"min": 14.0, "weights": {VSEnemy.Type.BAT: 0.5, VSEnemy.Type.WEREWOLF: 0.5}},
	{"min": 15.0, "weights": {VSEnemy.Type.WEREWOLF: 0.4, VSEnemy.Type.BAT: 0.3, VSEnemy.Type.MUDMAN: 0.3}},
	{"min": 16.0, "weights": {VSEnemy.Type.MANTIS_WARRIOR: 0.3, VSEnemy.Type.MUDMAN: 0.7}},
	{"min": 17.0, "weights": {VSEnemy.Type.MUMMY: 1.0}},
	{"min": 20.0, "weights": {VSEnemy.Type.MUMMY: 0.5, VSEnemy.Type.MUDMAN: 0.2, VSEnemy.Type.BAT: 0.3}},
	{"min": 22.0, "weights": {VSEnemy.Type.MUMMY: 1.0}},
	{"min": 25.0, "weights": {VSEnemy.Type.MANTIS_WARRIOR: 0.5, VSEnemy.Type.MUMMY: 0.5}},
	{"min": 27.0, "weights": {VSEnemy.Type.MUMMY: 0.5, VSEnemy.Type.MUDMAN: 0.3, VSEnemy.Type.MANTIS_WARRIOR: 0.2}},
]

## Per-minute base-spawn pacing transcribed verbatim from Mad Forest's real wave table
## (.firecrawl/wiki-offline/Mad_Forest.htm, the "Spawn interval (seconds)" and "Enemy
## minimum" columns, 0:00 through 29:00). `interval` is the seconds between base spawns
## (rate = 1/interval, tightening from 1.0s early to 0.1s in the endgame); `count` is the
## concurrent enemy population the stage maintains. RUN_DURATION is already 1800s (30:00),
## matching Mad Forest exactly, so these minute marks map 1:1 — no stretching. The wiki's
## counts climb to 300, far past what this slice renders smoothly, so they're clamped to the render
## budget (_max_cap(), which itself ramps up over the final third so the endgame still escalates);
## the LOW values (the 5:00/10:00/etc. lulls the real stage uses to
## frame its minibosses) read through and thin the field. Each row holds from its minute mark
## until the next. Waves/surges/elites keep their own cadence and the hard cap — this governs
## only the ambient trickle.
const DENSITY_SCHEDULE := [
	{"min": 0.0,  "interval": 1.0,  "count": 15},
	{"min": 1.0,  "interval": 1.0,  "count": 30},
	{"min": 2.0,  "interval": 0.5,  "count": 50},
	{"min": 3.0,  "interval": 0.25, "count": 40},
	{"min": 4.0,  "interval": 1.0,  "count": 30},
	{"min": 5.0,  "interval": 1.0,  "count": 10},
	{"min": 6.0,  "interval": 0.5,  "count": 20},
	{"min": 7.0,  "interval": 0.5,  "count": 80},
	{"min": 8.0,  "interval": 1.5,  "count": 100},
	{"min": 9.0,  "interval": 0.5,  "count": 30},
	{"min": 10.0, "interval": 0.5,  "count": 10},
	{"min": 11.0, "interval": 0.1,  "count": 300},
	{"min": 12.0, "interval": 0.25, "count": 20},
	{"min": 13.0, "interval": 0.5,  "count": 150},
	{"min": 14.0, "interval": 0.1,  "count": 20},
	{"min": 15.0, "interval": 0.1,  "count": 100},
	{"min": 16.0, "interval": 0.1,  "count": 100},
	{"min": 17.0, "interval": 1.0,  "count": 20},
	{"min": 18.0, "interval": 0.5,  "count": 60},
	{"min": 19.0, "interval": 0.5,  "count": 100},
	{"min": 20.0, "interval": 0.1,  "count": 100},
	{"min": 21.0, "interval": 0.1,  "count": 300},
	{"min": 22.0, "interval": 0.1,  "count": 200},
	{"min": 23.0, "interval": 0.1,  "count": 300},
	{"min": 24.0, "interval": 0.1,  "count": 300},
	{"min": 25.0, "interval": 0.1,  "count": 100},
	{"min": 26.0, "interval": 0.1,  "count": 150},
	{"min": 27.0, "interval": 0.1,  "count": 300},
	{"min": 28.0, "interval": 0.1,  "count": 300},
	{"min": 29.0, "interval": 0.1,  "count": 300},
]

## The concurrent-enemy render budget for the current run time. Holds at MAX_ENEMIES for the first
## two-thirds, then ramps linearly to MAX_ENEMIES_LATE across the final third so the endgame's
## saturated DENSITY_SCHEDULE counts (100->300, all previously clamped flat to 90) actually read as
## escalating population on screen instead of one unchanging crush. Every population cap in the
## spawner routes through this so the late-game field grows as one coherent budget.
func _max_cap() -> int:
	var frac := run.elapsed / VSRun.RUN_DURATION
	if frac <= LATE_RAMP_START:
		return MAX_ENEMIES
	var t := clampf((frac - LATE_RAMP_START) / (1.0 - LATE_RAMP_START), 0.0, 1.0)
	return int(lerpf(float(MAX_ENEMIES), float(MAX_ENEMIES_LATE), t))

## The DENSITY_SCHEDULE row in effect for the current run time (same band lookup as
## _pick_type): the last row whose minute mark has passed.
func _density() -> Dictionary:
	var minute := run.elapsed / 60.0
	var row: Dictionary = DENSITY_SCHEDULE[0]
	for band in DENSITY_SCHEDULE:
		if minute >= band.min:
			row = band
		else:
			break
	return row

func _pick_type() -> int:
	var minute := run.elapsed / 60.0
	var weights: Dictionary = ROSTER_SCHEDULE[0].weights
	for band in ROSTER_SCHEDULE:
		if minute >= band.min:
			weights = band.weights
		else:
			break
	return _roll_weighted(weights)

## Weighted pick over a {Type: weight} dictionary; weights need not sum to 1.
func _roll_weighted(weights: Dictionary) -> int:
	var total := 0.0
	for w in weights.values():
		total += w
	var roll := randf() * total
	var acc := 0.0
	for type in weights:
		acc += weights[type]
		if roll < acc:
			return type
	return weights.keys().back()
