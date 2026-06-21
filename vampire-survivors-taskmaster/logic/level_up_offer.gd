class_name LevelUpOffer extends RefCounted

## The 3-4 options presented on a level-up. Built by ProgressionSystem when a
## level-up fires; consumed when the player chooses; cleared on resume.
## Each entry in `options` is a Dictionary {kind, def, is_upgrade, target_level}.
## `is_max_state` flags the full-inventory (gold/chicken) display. Mutable data.

var options: Array = []  # Array of {kind, def, is_upgrade, target_level}
var is_max_state: bool = false
