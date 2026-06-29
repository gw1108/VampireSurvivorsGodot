class_name PlayerState extends RefCounted

## Everything about Antonio. Created by GameManager with the starting kit
## (Whip; +20 Max HP -> 120; +1 Armor) and mutated in place by the pure
## systems. Plain data — no scene dependency.
##
## Inventory caps (6 weapons + 6 passives) are enforced by LevelingSystem, not
## here. `stats_dirty` is raised whenever inventory/level changes so the
## controller knows to re-run StatSystem.

var pos: Vector2
var vel: Vector2
var facing: Vector2 = Vector2.RIGHT  # last nonzero move dir; drives Whip/Knife

var hp: float = 120.0
var max_hp: float = 120.0
var iframe_timer: float = 0.0

var level: int = 1
var xp: float = 0.0
var xp_to_next: float = 5.0
var gold: int = 0
var kills: int = 0

var weapons: Array[WeaponInstance] = []   # <= 6
var passives: Array[PassiveInstance] = [] # <= 6
var stats: StatBlock

var reroll_charges: int = 0
var skip_charges: int = 0
var banish_charges: int = 0
var revival: int = 0

var stats_dirty: bool = true
