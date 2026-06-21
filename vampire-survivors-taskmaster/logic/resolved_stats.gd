class_name ResolvedStats extends RefCounted

## The per-tick effective stat values, computed by StatSystem from a StatBlock
## after applying multipliers and caps. Other systems read these final numbers
## (never the raw StatBlock). Plain mutable data — no behavior.

var might: float = 1.0
var area: float = 1.0
var cooldown: float = 1.0
var amount: int = 0
var duration: float = 1.0
var speed: float = 1.0
var move_speed: float = 1.0
var max_health: float = 100.0
var recovery: float = 0.0
var armor: float = 0.0
var magnet: float = 64.0  # pixels
var luck: float = 1.0
var growth: float = 1.0
var greed: float = 1.0
var curse: float = 1.0
var revival: int = 0
