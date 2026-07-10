class_name VSPickup
extends RefCounted
## Shared pickup tuning. Every pickup (gem, coin, food, chest, treats) renders at the same
## size and is grabbed at the same distance, so a single balance row tunes them all and
## pickup-range upgrades behave uniformly.

## Rendered size in px of a pickup sprite's longest side — the XP gem's 12x16 footprint.
static var TARGET_SIZE := BalanceData.get_value("pickup_sprite_size", 16.0)

## Grab distance in px shared by every pickup (added to the player's own pickup radius).
static var GRAB_RADIUS := BalanceData.get_value("pickup_grab_radius", 26.0)

## Magnetize radius in px shared by every pickup, before the player's magnet stat
## (run.pickup_range_mult) scales it up.
static var MAGNET_RADIUS := BalanceData.get_value("pickup_magnet_radius", 95.0)

## Attraction speed in px/sec shared by every pickup while magnetizing toward the player.
static var MAGNET_SPEED := BalanceData.get_value("pickup_magnet_speed", 240.0)

## Scale `sprite` so its texture's longest side renders at TARGET_SIZE px, regardless of
## the source canvas (art ranges from 12px gems to 256px canvases).
static func apply(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var longest := maxf(sprite.texture.get_width(), sprite.texture.get_height())
	if longest > 0.0:
		sprite.scale = Vector2.ONE * (TARGET_SIZE / longest)
