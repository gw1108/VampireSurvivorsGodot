class_name StatBlock extends RefCounted

## Fully-resolved derived stats that weapons/systems read when acting.
## Recomputed by StatSystem (Task 5) from base + character + passives + level;
## never mutated directly by other systems. This container only holds the
## values, their neutral defaults, and the documented caps.
##
## Convention: multiplier stats are 1.0 at baseline (100%); additive/flat
## stats are 0.0 at baseline. StatSystem is the source of truth for how each
## value is built up — the caps below mirror the GDD stat model.

# --- Caps (mirror the GDD; enforced by clamp_all and by StatSystem) ---
const MIGHT_MAX := 10.0      # +1000% damage
const COOLDOWN_MIN := 0.1    # cooldown floor of -90%
const AMOUNT_MAX := 10       # +10 projectiles max

# --- Flat / additive stats (baseline 0) ---
var max_health: float = 0.0  # bonus Max HP added to base
var recovery: float = 0.0    # HP regenerated per second
var armor: float = 0.0       # flat damage reduction
var amount: float = 0.0      # extra projectiles (capped at AMOUNT_MAX)

# --- Multiplier stats (baseline 1.0 == 100%) ---
var move_speed: float = 1.0
var might: float = 1.0        # damage multiplier (capped at MIGHT_MAX)
var area: float = 1.0
var speed: float = 1.0        # projectile speed
var duration: float = 1.0
var cooldown: float = 1.0     # cooldown multiplier (floored at COOLDOWN_MIN)
var magnet: float = 1.0       # pickup radius
var luck: float = 1.0
var growth: float = 1.0       # XP gain
var greed: float = 1.0        # gold gain
var curse: float = 1.0        # enemy quantity/speed/health scaling

## Clamp every value to its documented cap / non-negative floor. StatSystem
## calls this after summing contributions so callers can trust the values.
func clamp_all() -> void:
	max_health = maxf(0.0, max_health)
	recovery = maxf(0.0, recovery)
	armor = maxf(0.0, armor)
	amount = clampf(amount, 0.0, float(AMOUNT_MAX))

	move_speed = maxf(0.0, move_speed)
	might = clampf(might, 0.0, MIGHT_MAX)
	area = maxf(0.0, area)
	speed = maxf(0.0, speed)
	duration = maxf(0.0, duration)
	cooldown = maxf(COOLDOWN_MIN, cooldown)
	magnet = maxf(0.0, magnet)
	luck = maxf(0.0, luck)
	growth = maxf(0.0, growth)
	greed = maxf(0.0, greed)
	curse = maxf(0.0, curse)
