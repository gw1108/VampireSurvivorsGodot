class_name LevelCurve extends RefCounted

## XP threshold table for leveling. Static/const data — never instantiated as
## game state. Transcribed from the Vampire Survivors wiki (Level_up):
##   - 5 XP to reach L2, then +10 XP each level through L20;
##   - at L20 an extra +600 XP (and the player gains +100% Growth until L21);
##   - +13 XP each level from L21 through L40;
##   - at L40 an extra +2400 XP (and +100% Growth until L41);
##   - +16 XP each level from L41 onward.
## CUMULATIVE_XP[L] is the total XP required to have reached level L (L1 = 0),
## taken from the wiki's experience chart (it bakes in the +600/+2400 jumps).
## Indexed by level; index 0 is unused.

const CUMULATIVE_XP: PackedFloat32Array = [
	0.0,      # 0 (unused)
	0.0,      # 1
	5.0,      # 2
	20.0,     # 3
	45.0,     # 4
	80.0,     # 5
	125.0,    # 6
	180.0,    # 7
	245.0,    # 8
	320.0,    # 9
	405.0,    # 10
	500.0,    # 11
	605.0,    # 12
	720.0,    # 13
	845.0,    # 14
	980.0,    # 15
	1125.0,   # 16
	1280.0,   # 17
	1445.0,   # 18
	1620.0,   # 19
	1805.0,   # 20
	2600.0,   # 21  (+600 special at L20)
	2866.5,   # 22
	3146.0,   # 23
	3438.5,   # 24
	3744.0,   # 25
	4062.5,   # 26
	4394.0,   # 27
	4738.5,   # 28
	5096.0,   # 29
	5466.5,   # 30
	5850.0,   # 31
	6246.5,   # 32
	6656.0,   # 33
	7078.5,   # 34
	7514.0,   # 35
	7962.5,   # 36
	8424.0,   # 37
	8898.5,   # 38
	9386.0,   # 39
	9886.5,   # 40
	12800.0,  # 41  (+2400 special at L40)
	13448.0,  # 42
	14112.0,  # 43
	14792.0,  # 44
	15488.0,  # 45
	16200.0,  # 46
	16928.0,  # 47
	17672.0,  # 48
	18432.0,  # 49
	19208.0,  # 50
	20000.0,  # 51
	20808.0,  # 52
	21632.0,  # 53
	22472.0,  # 54
	23328.0,  # 55
	24200.0,  # 56
	25088.0,  # 57
	25992.0,  # 58
	26912.0,  # 59
	27848.0,  # 60
]

const MAX_TABLE_LEVEL: int = 60

## Levels at which the player gains +100% Growth until the next level.
const GROWTH_BONUS_LEVELS: PackedInt32Array = [20, 40]

## The one-time extra XP added at L20 / L40. These are already folded into
## CUMULATIVE_XP (xp_to_next(20) = 195 + 600 = 795), and are exposed here as
## named constants for systems that surface the specials in UI/logic. (A flat
## per-level `CURVE` array is intentionally omitted: the real curve has
## fractional values past L20, so xp_to_next()/CUMULATIVE_XP is the source of truth.)
const L20_BONUS_XP: int = 600
const L40_BONUS_XP: int = 2400


## Total XP required to have reached `level` (from level 1).
static func total_xp_for_level(level: int) -> float:
	var lvl: int = clampi(level, 1, MAX_TABLE_LEVEL)
	return CUMULATIVE_XP[lvl]


## XP required to advance from `level` to `level + 1`.
static func xp_to_next(level: int) -> float:
	var lvl: int = maxi(level, 1)
	if lvl < MAX_TABLE_LEVEL:
		return CUMULATIVE_XP[lvl + 1] - CUMULATIVE_XP[lvl]
	# Beyond the table, extend the L41+ rule of +16 XP per level.
	return (CUMULATIVE_XP[MAX_TABLE_LEVEL] - CUMULATIVE_XP[MAX_TABLE_LEVEL - 1]) \
		+ (lvl - (MAX_TABLE_LEVEL - 1)) * 16.0
