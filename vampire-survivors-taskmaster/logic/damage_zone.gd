class_name DamageZone extends RefCounted

## An AoE source: Garlic aura, King Bible orbiters, Santa Water puddles,
## Lightning strikes, Peachone/Ebony bombards. Created by WeaponSystem;
## updated/resolved by CombatSystem; removed on lifetime end. Plain mutable data.
## `anchor` selects how `pos` is derived each tick.

enum Anchor { FOLLOW_PLAYER, WORLD, ORBIT }

var source_weapon = null
var anchor: int = Anchor.WORLD
var pos: Vector2 = Vector2.ZERO
var offset: Vector2 = Vector2.ZERO
var angle: float = 0.0
var radius: float = 32.0
var damage: float = 0.0
var tick_interval: float = 0.5
var tick_timer: float = 0.0
var lifetime: float = 1.0
var hit_ids: PackedInt64Array = []  # reset per damage tick
