class_name VSChestScreen
extends CanvasLayer
## Treasure-chest reward reveal. Shown when the player opens a chest (VSRun.open_chest): it
## dims the arena — the run stays "paused" via VSRun.phase == "chest" (entities gate on phase),
## like the level-up picker — and plays a cool opening animation before the player continues.
##
## The animation: the chest sits in the middle and pops open in a white burst, a tall rectangular
## beam of light shoots up flashing the same white->cyan punch the XP bar flashes on a level-up,
## and every obtainable item spews up the beam in a linear stream. A coin counter below ticks up
## toward the run's gold award — and the WHOLE animation's length scales with that award, so a
## richer chest lingers longer. Finally the item(s) the player actually gained rise into the
## centre with their names, and a Continue button resumes the run.
##
## Built in code to match the rest of the slice (see upgrade_screen.gd). Emits `continued` when
## the player dismisses it; VSRun resumes the run on that signal.

signal continued           ## player pressed Continue — VSRun resumes the run

## Opening pop + final reveal are fixed-length; only the middle "spew" stage scales with gold.
static var OPEN_DUR := BalanceData.get_value("chest_screen_open_dur", 0.45)
static var REVEAL_DUR := BalanceData.get_value("chest_screen_reveal_dur", 1.1)
## Spew stage seconds = clamp(gold * PER_GOLD, MIN, MAX) — "the length depends on how many coins".
static var SPEW_PER_GOLD := BalanceData.get_value("chest_screen_spew_per_gold", 0.09)
static var SPEW_MIN := BalanceData.get_value("chest_screen_spew_min", 1.2)
static var SPEW_MAX := BalanceData.get_value("chest_screen_spew_max", 5.0)

const BEAM_W := 46.0        # the bright rectangular core of the beam
const GLOW_W := 132.0       # a wide faint halo behind it so the beam reads as light, not a bar
static var SPAWN_GAP := BalanceData.get_value("chest_screen_spawn_gap", 0.07)     # seconds between spewed items
static var PARTICLE_MAX := int(BalanceData.get_value("chest_screen_particle_max", 44.0))    # hard cap on live spew sprites

var _active := false
var _finished := false
var _t := 0.0               # seconds since present()
var _spew_dur := SPEW_MIN
var _total := 0.0
var _gold := 0

var _root: Control
var _beam: ColorRect
var _beam_glow: ColorRect
var _flash: ColorRect       # full-screen white burst on the chest pop
var _chest: TextureRect
var _spew_holder: Control
var _coin_bar: HBoxContainer
var _coin_label: Label
var _reveal_holder: HBoxContainer
var _continue: Button

var _item_textures: Array = []   # every obtainable item's icon, cycled by the spew
var _particles: Array = []       # active spew sprites: { node, speed, vx, life, age }
var _spawn_accum := 0.0
var _item_idx := 0

func _ready() -> void:
	layer = 11                    # above the upgrade picker (10) and HUD
	visible = false
	_load_item_textures()

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	# Beam halo then core — created before the chest so the chest sprite draws on top of them.
	_beam_glow = ColorRect.new()
	_beam_glow.color = Color(0.35, 0.8, 1.0, 0.0)
	_beam_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_beam_glow)

	_beam = ColorRect.new()
	_beam.color = Color(1, 1, 1, 0.0)
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_beam)

	_spew_holder = Control.new()
	_spew_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spew_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_spew_holder)

	_chest = TextureRect.new()
	_chest.texture = load("res://art/pickup_chest.png")
	_chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # keep the pixel art crisp (VISUAL_RULES)
	_chest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_chest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_chest.custom_minimum_size = Vector2(150, 150)
	_chest.size = Vector2(150, 150)
	_chest.pivot_offset = Vector2(75, 75)
	_chest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chest)

	# Title banner across the top, treasure gold.
	var title := Label.new()
	title.text = "TREASURE!"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 54
	title.offset_bottom = 100
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.modulate = Color(1.0, 0.85, 0.3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title)

	# Reward reveal — the gained item(s) rise up into the centre; alpha + offset animate in present().
	_reveal_holder = HBoxContainer.new()
	_reveal_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	_reveal_holder.add_theme_constant_override("separation", 28)
	_reveal_holder.anchor_left = 0.0
	_reveal_holder.anchor_right = 1.0
	_reveal_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_holder.modulate = Color(1, 1, 1, 0.0)
	_root.add_child(_reveal_holder)

	# Coin counter row, centred below the chest.
	_coin_bar = HBoxContainer.new()
	_coin_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_coin_bar.add_theme_constant_override("separation", 10)
	_coin_bar.anchor_left = 0.0
	_coin_bar.anchor_right = 1.0
	_coin_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_coin_bar)

	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://art/gold_coin.png")
	coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.custom_minimum_size = Vector2(40, 40)
	coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_bar.add_child(coin_icon)

	_coin_label = Label.new()
	_coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_label.add_theme_font_size_override("font_size", 32)
	_coin_label.modulate = Color(1.0, 0.85, 0.3)
	_coin_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_bar.add_child(_coin_label)

	# Full-screen white burst for the chest pop; alpha driven each frame.
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	# Continue button, hidden until the animation finishes.
	_continue = Button.new()
	_continue.text = "Continue  [Enter]"
	_continue.custom_minimum_size = Vector2(240, 48)
	_continue.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_continue.pressed.connect(_on_continue_pressed)
	_continue.visible = false
	_root.add_child(_continue)

## Build the cycling spew pool: every obtainable item's icon (UPGRADE_POOL through the shared
## ICONS map). Loaded once; the animation streams these up the beam.
func _load_item_textures() -> void:
	for opt in VSRun.UPGRADE_POOL:
		var tex := _icon_for(str(opt["id"]))
		if tex != null:
			_item_textures.append(tex)

## Look up an item id's icon texture via the level-up screen's shared ICONS map (single source of
## truth so a new item's icon shows here too). Returns null when the id has no icon.
func _icon_for(id: String) -> Texture2D:
	if VSUpgradeScreen.ICONS.has(id):
		var path: String = VSUpgradeScreen.ICONS[id]
		if ResourceLoader.exists(path):
			return load(path)
	return null

## Open the reveal. granted_ids/granted_titles are the item(s) this chest actually gave (may be
## empty when the whole pool was maxed and it paid only gold); gold is the coin award. The total
## animation length scales with gold — a richer chest lingers longer.
func present(granted_ids: Array, granted_titles: Array, gold: int) -> void:
	_active = true
	_finished = false
	_t = 0.0
	_gold = maxi(gold, 0)
	_spew_dur = clampf(float(_gold) * SPEW_PER_GOLD, SPEW_MIN, SPEW_MAX)
	_total = OPEN_DUR + _spew_dur + REVEAL_DUR
	_spawn_accum = 0.0
	_item_idx = 0
	_clear_particles()
	_build_reveal(granted_ids, granted_titles)
	_continue.visible = false
	_coin_label.text = "+0"
	_flash.color = Color(1, 1, 1, 0.0)
	_layout()
	visible = true

## Position everything from the current viewport size so the reveal stays centred at any
## resolution. Called on present() and again if the viewport resizes mid-animation.
func _layout() -> void:
	var s := _root.size
	var cx := s.x * 0.5
	var chest_cy := s.y * 0.62
	_chest.position = Vector2(cx - 75.0, chest_cy - 75.0)
	# Beam rises from just above the chest to just under the title.
	var beam_bottom := chest_cy - 40.0
	var beam_top := s.y * 0.14
	_beam.position = Vector2(cx - BEAM_W * 0.5, beam_top)
	_beam.size = Vector2(BEAM_W, beam_bottom - beam_top)
	_beam_glow.position = Vector2(cx - GLOW_W * 0.5, beam_top)
	_beam_glow.size = Vector2(GLOW_W, beam_bottom - beam_top)
	# Reward reveal settles at ~40% height (upper-centre); coin row sits below the chest.
	_reveal_holder.offset_top = s.y * 0.36
	_reveal_holder.offset_bottom = s.y * 0.36 + 140.0
	_coin_bar.offset_top = s.y * 0.76
	_coin_bar.offset_bottom = s.y * 0.76 + 48.0
	_continue.offset_left = -120.0
	_continue.offset_right = 120.0
	_continue.offset_top = -104.0
	_continue.offset_bottom = -56.0

## Build the gained-item reveal cards (icon over name) that rise into the centre. When nothing was
## granted (pool maxed -> gold only), show a single gold "GOLD!" centrepiece instead.
func _build_reveal(ids: Array, titles: Array) -> void:
	for c in _reveal_holder.get_children():
		c.queue_free()
	if ids.is_empty():
		_reveal_holder.add_child(_reveal_card(load("res://art/gold_coin.png"), "GOLD!", Color(1.0, 0.85, 0.3)))
		return
	for i in ids.size():
		var tex := _icon_for(str(ids[i]))
		var name_str := str(titles[i]) if i < titles.size() else str(ids[i])
		_reveal_holder.add_child(_reveal_card(tex, name_str, Color(1, 1, 1)))

## One reveal card: a big icon with the item's name under it.
func _reveal_card(tex: Texture2D, name_str: String, tint: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(96, 96)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
	var lbl := Label.new()
	lbl.text = name_str
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.modulate = tint
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return box

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _finished:
		_update_particles(delta)   # let the last few spew sprites finish rising
		return

	var s := _root.size
	var cx := s.x * 0.5
	var chest_cy := s.y * 0.62

	# Stage 1 — chest pop: a quick squash-stretch + a white burst that fades over OPEN_DUR.
	if _t < OPEN_DUR:
		var f := _t / OPEN_DUR
		var sx := 1.0 + 0.28 * sin(f * PI)
		var sy := 1.0 - 0.18 * sin(f * PI) + 0.18 * f
		_chest.scale = Vector2(sx, sy)
		_flash.color = Color(1, 1, 1, 0.7 * (1.0 - f))
		return

	_chest.scale = Vector2(1.0, 1.0)
	_flash.color = Color(1, 1, 1, 0.0)
	var stage_t := _t - OPEN_DUR

	# Stage 2 — spew: beam flashes + items stream up + coins tick, over _spew_dur.
	if stage_t < _spew_dur:
		var grow := clampf(stage_t / 0.18, 0.0, 1.0)          # beam shoots up in the first 0.18s
		_drive_beam(stage_t, grow)
		var frac := stage_t / _spew_dur
		_coin_label.text = "+%d" % int(round(float(_gold) * frac))
		_spawn_accum += delta
		while _spawn_accum >= SPAWN_GAP and _particles.size() < PARTICLE_MAX:
			_spawn_accum -= SPAWN_GAP
			_spawn_particle(cx, chest_cy)
		_update_particles(delta)
		return

	# Stage 3 — reveal: gained item(s) rise into the centre, beam fades, coins hold at the total.
	var rt := clampf((stage_t - _spew_dur) / REVEAL_DUR, 0.0, 1.0)
	_drive_beam(stage_t, 1.0)
	_beam.modulate.a = 1.0 - rt
	_beam_glow.modulate.a = 1.0 - rt
	_coin_label.text = "+%d" % _gold
	# Rise + fade the reward group up into place (starts ~90px low, eases to rest).
	var ease := 1.0 - pow(1.0 - rt, 3.0)
	_reveal_holder.offset_top = s.y * 0.36 + 90.0 * (1.0 - ease)
	_reveal_holder.offset_bottom = _reveal_holder.offset_top + 140.0
	_reveal_holder.modulate.a = ease
	_update_particles(delta)
	if rt >= 1.0:
		_finish()

## Drive the rectangular beam's flashing colour — the same white->cyan punch the XP bar flashes on
## a level-up (VSHud.XP_FILL_COLOR -> XP_FLASH_COLOR, decaying over XP_FLASH_TIME), repeated so the
## beam pulses for the length of the reveal. `grow` (0..1) scales its height as it shoots up.
func _drive_beam(stage_t: float, grow: float) -> void:
	var period := VSHud.XP_FLASH_TIME
	var punch := 1.0 - fmod(stage_t, period) / period          # 1 at each punch, easing to 0
	var col := VSHud.XP_FILL_COLOR.lerp(VSHud.XP_FLASH_COLOR, punch)
	_beam.color = Color(col.r, col.g, col.b, 0.9)
	_beam.modulate.a = 1.0
	_beam_glow.color = Color(col.r, col.g, col.b, 0.22 + 0.18 * punch)
	_beam_glow.modulate.a = 1.0
	# Anchor the growth at the beam's bottom so it visibly shoots upward.
	var s := _root.size
	var beam_bottom := s.y * 0.62 - 40.0
	var beam_top := s.y * 0.14
	var full_h := beam_bottom - beam_top
	_beam.size.y = full_h * grow
	_beam.position.y = beam_bottom - full_h * grow
	_beam_glow.size.y = full_h * grow
	_beam_glow.position.y = beam_bottom - full_h * grow

## Spew one item icon up out of the chest along the beam — a straight, constant-velocity rise with
## a small horizontal spread, cycling through every obtainable item.
func _spawn_particle(cx: float, chest_cy: float) -> void:
	if _item_textures.is_empty():
		return
	var tex: Texture2D = _item_textures[_item_idx % _item_textures.size()]
	_item_idx += 1
	var node := TextureRect.new()
	node.texture = tex
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.custom_minimum_size = Vector2(34, 34)
	node.size = Vector2(34, 34)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := cx + randf_range(-BEAM_W * 0.5, BEAM_W * 0.5)
	node.position = Vector2(x - 17.0, chest_cy - 60.0)
	_spew_holder.add_child(node)
	_particles.append({
		"node": node,
		"speed": randf_range(280.0, 440.0),
		"vx": randf_range(-30.0, 30.0),
		"life": randf_range(0.9, 1.4),
		"age": 0.0,
	})

## Advance the spew sprites: constant upward rise, gentle horizontal drift, fade out near end of
## life, freed when spent or off the top.
func _update_particles(delta: float) -> void:
	for i in range(_particles.size() - 1, -1, -1):
		var p: Dictionary = _particles[i]
		var node: TextureRect = p["node"]
		if not is_instance_valid(node):
			_particles.remove_at(i)
			continue
		p["age"] += delta
		node.position.y -= float(p["speed"]) * delta
		node.position.x += float(p["vx"]) * delta
		var life_frac := float(p["age"]) / float(p["life"])
		node.modulate.a = clampf(1.0 - life_frac, 0.0, 1.0)
		if life_frac >= 1.0 or node.position.y < -40.0:
			node.queue_free()
			_particles.remove_at(i)

func _clear_particles() -> void:
	for p in _particles:
		var node = p.get("node")
		if node != null and is_instance_valid(node):
			node.queue_free()
	_particles.clear()

## Land the animation at its finished state: full reveal shown, coins at total, beam gone,
## Continue enabled and focused.
func _finish() -> void:
	if _finished:
		return
	_finished = true
	var s := _root.size
	_reveal_holder.offset_top = s.y * 0.36
	_reveal_holder.offset_bottom = s.y * 0.36 + 140.0
	_reveal_holder.modulate.a = 1.0
	_beam.modulate.a = 0.0
	_beam_glow.modulate.a = 0.0
	_flash.color = Color(1, 1, 1, 0.0)
	_coin_label.text = "+%d" % _gold
	_continue.visible = true
	_continue.grab_focus()

## Skip the rest of the animation and jump straight to the finished reveal.
func _skip_to_end() -> void:
	_t = _total
	_clear_particles()
	_chest.scale = Vector2(1.0, 1.0)
	_finish()

func _on_continue_pressed() -> void:
	_dismiss()

func _dismiss() -> void:
	if not _active:
		return
	_active = false
	visible = false
	_clear_particles()
	continued.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _finished:
			_dismiss()
		else:
			_skip_to_end()    # first Enter fast-forwards; a second dismisses
