extends Node2D

const MAPS := [
	{"name":"Greenhaven Village","theme":0,"goal":0,"enemy":"Training Slime"},
	{"name":"Forgotten Meadow","theme":0,"goal":8,"enemy":"Moss Slime"},
	{"name":"Whispering Woods","theme":1,"goal":12,"enemy":"Wild Boar"},
	{"name":"Misty Lake","theme":2,"goal":15,"enemy":"Bog Wisp"},
	{"name":"Sunken Ruins","theme":3,"goal":18,"enemy":"Stone Guard"},
	{"name":"Ashen Pass","theme":4,"goal":22,"enemy":"Cinder Imp"},
	{"name":"Frostfang Ridge","theme":5,"goal":25,"enemy":"Frost Wolf"},
	{"name":"Moonlit Marsh","theme":6,"goal":28,"enemy":"Night Stalker"},
	{"name":"Dragonbone Valley","theme":4,"goal":32,"enemy":"Drake"},
	{"name":"Ancient Citadel","theme":3,"goal":36,"enemy":"Citadel Knight"}
]
const MAP_SIZE := Vector2(1800, 1250)
const SAVE_PATH := "user://astaga_naga_save.cfg"
var player := {"pos": Vector2(900, 625), "hp": 100.0, "max_hp": 100.0, "level": 1, "xp": 0, "next_xp": 30, "gold": 0, "damage": 22.0, "speed": 190.0, "potions": 3, "kills": 0, "weapon": 0, "armor": 0, "skill_cd": 0.0, "attack_cd": 0.0, "hurt_cd": 0.0}
var mobs: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var current_map := 0
var map_kills := 0
var total_kills := 0
var move_input := Vector2.ZERO
var joystick_id := -1
var attack_held := false
var skill_held := false
var dead := false
var toast_text := "Welcome to Greenhaven!"
var toast_time := 3.0
var ui_layer: CanvasLayer
var hud_label: Label
var message_label: Label
var map_label: Label
var stick_center := Vector2.ZERO
var stick_knob := Vector2.ZERO
var last_face := Vector2.RIGHT
var npc_panel: PanelContainer
var gold_label: Label
var inventory_label: Label
var attack_button: Button
var skill_button: Button
var potion_button: Button
var next_button: Button
var talk_button: Button

func _ready() -> void:
	_load_game()
	_build_ui()
	_spawn_mobs()
	queue_redraw()

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	var hud := PanelContainer.new()
	hud.position = Vector2(12, 10)
	hud.custom_minimum_size = Vector2(230, 110)
	root.add_child(hud)
	var v := VBoxContainer.new()
	hud.add_child(v)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 15)
	v.add_child(hud_label)
	gold_label = Label.new()
	v.add_child(gold_label)
	inventory_label = Label.new()
	inventory_label.add_theme_font_size_override("font_size", 12)
	v.add_child(inventory_label)

	map_label = Label.new()
	map_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_label.offset_left = -300
	map_label.offset_top = 12
	map_label.offset_right = -14
	map_label.offset_bottom = 46
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	map_label.add_theme_font_size_override("font_size", 15)
	root.add_child(map_label)

	message_label = Label.new()
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_left = -220
	message_label.offset_top = 68
	message_label.offset_right = 220
	message_label.offset_bottom = 105
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Color("#ffe8a3"))
	root.add_child(message_label)

	var stick := Label.new()
	stick.text = "◉"
	stick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stick.add_theme_font_size_override("font_size", 52)
	stick.add_theme_color_override("font_color", Color(0.85, 0.94, 0.94, 0.7))
	stick.position = Vector2(25, 405)
	stick.size = Vector2(150, 150)
	root.add_child(stick)

	var actions := HBoxContainer.new()
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.offset_left = -355
	actions.offset_top = -130
	actions.offset_right = -16
	actions.offset_bottom = -16
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	potion_button = _make_button("✚\nPotion", Vector2(72, 72))
	potion_button.pressed.connect(_use_potion)
	actions.add_child(potion_button)
	skill_button = _make_button("✦\nSkill", Vector2(76, 76))
	skill_button.pressed.connect(_use_skill)
	actions.add_child(skill_button)
	attack_button = _make_button("⚔\nAttack", Vector2(88, 88))
	attack_button.add_theme_color_override("font_color", Color("#fff0bd"))
	attack_button.pressed.connect(_attack)
	actions.add_child(attack_button)

	var utility := HBoxContainer.new()
	utility.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	utility.offset_left = 12
	utility.offset_top = -54
	utility.offset_right = 360
	utility.offset_bottom = -10
	utility.add_theme_constant_override("separation", 6)
	root.add_child(utility)
	talk_button = _make_button("Talk / Shop", Vector2(112, 42))
	talk_button.pressed.connect(_interact)
	utility.add_child(talk_button)
	next_button = _make_button("Map / Quest", Vector2(112, 42))
	next_button.pressed.connect(_advance_map)
	utility.add_child(next_button)
	var save_button := _make_button("Save", Vector2(76, 42))
	save_button.pressed.connect(_save_game)
	utility.add_child(save_button)

func _make_button(caption: String, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("#fff4d4"))
	b.add_theme_stylebox_override("normal", _button_style(Color("#795535")))
	b.add_theme_stylebox_override("pressed", _button_style(Color("#b77c46")))
	return b

func _button_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color("#e6d5a0")
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s

func _spawn_mobs() -> void:
	mobs.clear()
	for i in range(16):
		_spawn_one()

func _spawn_one() -> void:
	var names := ["Moss Slime", "Wild Boar", "Shadow Imp", "Bog Wisp", "Stone Guard"]
	var colors := [Color("#72bd62"), Color("#b7794c"), Color("#9b77c8"), Color("#71c8cb"), Color("#9da6a5")]
	var idx := randi_range(0, names.size() - 1)
	var elite := randf() < 0.08 or (map_kills >= int(MAPS[current_map].goal) and current_map > 0)
	var max_hp := float(40 + current_map * 12 + (24 if elite else 0))
	var pos := Vector2(randf_range(70, MAP_SIZE.x - 70), randf_range(70, MAP_SIZE.y - 70))
	if pos.distance_to(player.pos) < 250:
		pos = (player.pos + Vector2(randf_range(-420, 420), randf_range(-360, 360))).clamp(Vector2(60, 60), MAP_SIZE - Vector2(60, 60))
	mobs.append({"pos": pos, "hp": max_hp, "max_hp": max_hp, "name": ("Elite " if elite else "") + names[idx], "color": Color("#ffb84f") if elite else colors[idx], "dmg": 5.0 + current_map * 1.3 + (4 if elite else 0), "xp": 8 + current_map * 2, "gold": 2 + current_map, "radius": 16.0 if not elite else 22.0, "speed": 40.0 + current_map * 2.0, "cd": randf_range(0.3, 1.0), "hurt": 0.0, "dead": false, "respawn": 0.0, "elite": elite, "phase": randf_range(0, 8)})

func _process(delta: float) -> void:
	var dt := minf(delta, 0.04)
	toast_time = maxf(0.0, toast_time - dt)
	player.attack_cd = maxf(0.0, player.attack_cd - dt)
	player.skill_cd = maxf(0.0, player.skill_cd - dt)
	player.hurt_cd = maxf(0.0, player.hurt_cd - dt)
	if not dead:
		player.pos += move_input * float(player.speed) * dt
		player.pos = player.pos.clamp(Vector2(24, 24), MAP_SIZE - Vector2(24, 24))
		if move_input.length() > 0.15:
			last_face = move_input.normalized()
		if attack_held and player.attack_cd <= 0.0:
			_attack()
		if skill_held and player.skill_cd <= 0.0:
			_use_skill()
		_update_mobs(dt)
		_update_drops(dt)
	_update_particles(dt)
	_update_hud()
	queue_redraw()

func _update_mobs(dt: float) -> void:
	for m in mobs:
		if m.dead:
			m.respawn -= dt
			if m.respawn <= 0:
				m.dead = false
				m.hp = m.max_hp
				m.pos = Vector2(randf_range(60, MAP_SIZE.x - 60), randf_range(60, MAP_SIZE.y - 60))
			continue
		m.hurt = maxf(0.0, m.hurt - dt)
		m.cd -= dt
		var diff: Vector2 = player.pos - m.pos
		var dist := diff.length()
		if dist < 330 and dist > float(m.radius) + 22:
			m.pos += diff.normalized() * float(m.speed) * dt
		elif dist <= float(m.radius) + 24 and m.cd <= 0 and player.hurt_cd <= 0:
			player.hp -= float(m.dmg)
			player.hurt_cd = 0.65
			m.cd = 1.2
			_burst(player.pos, Color("#ff7777"), 5)
			if player.hp <= 0:
				player.hp = 0
				dead = true
				_toast("Kamu tumbang! Gunakan potion untuk bangkit.")

func _update_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.life -= dt
		if d.pos.distance_to(player.pos) < 115:
			d.pos = d.pos.move_toward(player.pos, 300 * dt)
		if d.pos.distance_to(player.pos) < 22:
			player.gold += d.gold
			player.xp += d.xp
			_gain_xp()
			drops.remove_at(i)
		elif d.life <= 0:
			drops.remove_at(i)

func _gain_xp() -> void:
	while int(player.xp) >= int(player.next_xp):
		player.xp -= int(player.next_xp)
		player.level += 1
		player.next_xp = int(float(player.next_xp) * 1.42)
		player.max_hp += 12
		player.hp = player.max_hp
		player.damage += 3
		player.speed += 2
		_toast("LEVEL UP! Level %d" % player.level)

func _attack() -> void:
	if dead:
		return
	if player.attack_cd > 0:
		return
	player.attack_cd = 0.48
	var hit_count := 0
	for m in mobs:
		if m.dead:
			continue
		var diff: Vector2 = m.pos - player.pos
		var dist := diff.length()
		if dist <= 76 + float(m.radius) and (dist < 1 or diff.normalized().dot(last_face) > -0.05):
			m.hp -= float(player.damage + int(player.weapon) * 6)
			m.hurt = 0.22
			_burst(m.pos, Color("#fff0b2"), 7)
			_float_text(m.pos, "-%d" % int(player.damage + int(player.weapon) * 6), Color("#fff1a1"))
			hit_count += 1
			if m.hp <= 0:
				_kill_mob(m)
	if hit_count == 0:
		_burst(player.pos + last_face * 35, Color("#dff7ff"), 5)
	else:
		_burst(player.pos + last_face * 48, Color("#fff0a6"), 10)

func _use_skill() -> void:
	if dead:
		if player.potions > 0:
			_use_potion()
		return
	if player.skill_cd > 0:
		_toast("Skill cooldown: %.1fs" % player.skill_cd)
		return
	player.skill_cd = 8.0
	_burst(player.pos, Color("#7feaff"), 28)
	_float_text(player.pos + Vector2(0, -42), "ARCANE PULSE!", Color("#a8f4ff"))
	for m in mobs:
		if not m.dead and m.pos.distance_to(player.pos) < 175:
			m.hp -= 42 + current_map * 4
			m.hurt = 0.3
			_burst(m.pos, Color("#7feaff"), 10)
			if m.hp <= 0:
				_kill_mob(m)

func _use_potion() -> void:
	if player.potions <= 0:
		_toast("Potion habis!")
		return
	if dead:
		dead = false
		player.hp = minf(float(player.max_hp), 50.0)
		player.hurt_cd = 1.2
		player.potions -= 1
		_toast("Bangkit dengan potion!")
	elif player.hp < player.max_hp:
		player.hp = minf(float(player.max_hp), float(player.hp) + 45.0)
		player.potions -= 1
		_toast("Potion memulihkan 45 HP")
	else:
		_toast("HP masih penuh")

func _kill_mob(m: Dictionary) -> void:
	m.dead = true
	m.respawn = 6.0
	total_kills += 1
	map_kills += 1
	_burst(m.pos, m.color, 18)
	drops.append({"pos": m.pos, "xp": int(m.xp), "gold": int(m.gold), "life": 12.0})
	_float_text(m.pos + Vector2(0, -25), "+%d EXP" % int(m.xp), Color("#8de6ff"))
	_float_text(m.pos + Vector2(12, -40), "+%d G" % int(m.gold), Color("#ffe08a"))
	_toast("Monster dikalahkan! Loot menarik EXP dan gold.")
	if current_map == 0:
		_toast("Village aman. Pilih Map / Quest untuk berpetualang.")
	elif map_kills >= int(MAPS[current_map].goal):
		_toast("Quest selesai! Map / Quest membuka area berikutnya.")

func _advance_map() -> void:
	if current_map == 0:
		current_map = 1
		map_kills = 0
		player.pos = Vector2(900, 625)
		_spawn_mobs()
		_toast("Quest dimulai: kalahkan %d monster." % int(MAPS[current_map].goal))
		return
	if map_kills < int(MAPS[current_map].goal):
		_toast("Quest: %d / %d monster" % [map_kills, int(MAPS[current_map].goal)])
		return
	if current_map >= MAPS.size() - 1:
		_toast("Citadel cleared! Kamu menamatkan 10 map.")
		return
	current_map += 1
	map_kills = 0
	player.pos = Vector2(900, 625)
	player.hp = minf(float(player.max_hp), float(player.hp) + 30)
	_spawn_mobs()
	_toast("Map terbuka: " + str(MAPS[current_map].name))

func _interact() -> void:
	if current_map != 0:
		_toast("Tidak ada NPC dekat sini. Kembali ke Village setelah quest.")
		return
	_toast("Elder: Selamat datang! Shop: 25 gold = potion, 60 gold = upgrade senjata.")
	if player.gold >= 60:
		player.gold -= 60
		player.weapon += 1
		_toast("Senjata ditingkatkan!")
	elif player.gold >= 25:
		player.gold -= 25
		player.potions += 1
		_toast("Potion dibeli seharga 25 gold.")
	else:
		_toast("Elder: Kumpulkan gold dari monster untuk membeli item.")

func _update_particles(dt: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= dt
		p.pos += p.vel * dt
		p.vel *= maxf(0.0, 1.0 - dt * 2.2)
		p.vel.y += 28 * dt
		if p.life <= 0:
			particles.remove_at(i)

func _burst(pos: Vector2, color: Color, amount: int = 8) -> void:
	for i in range(amount):
		var angle := randf() * TAU
		var speed := randf_range(35, 125)
		particles.append({"pos": pos, "vel": Vector2(cos(angle), sin(angle)) * speed, "life": randf_range(0.2, 0.55), "max": 0.55, "color": color, "size": randf_range(2, 5), "text": ""})

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	particles.append({"pos": pos, "vel": Vector2(randf_range(-8, 8), -34), "life": 0.85, "max": 0.85, "color": color, "size": 13, "text": text})

func _draw() -> void:
	var camera: Vector2 = (player.pos - get_viewport_rect().size / 2.0).clamp(Vector2.ZERO, MAP_SIZE - get_viewport_rect().size)
	draw_set_transform(-camera)
	_draw_world()
	for d in drops:
		draw_circle(d.pos, 7, Color("#ffe08a"))
		draw_circle(d.pos, 3, Color("#fff4cf"))
	for m in mobs:
		if not m.dead:
			_draw_mob(m)
	_draw_player()
	for p in particles:
		var alpha := clampf(float(p.life) / float(p.max), 0.0, 1.0)
		if str(p.text) != "":
			draw_string(ThemeDB.fallback_font, p.pos, str(p.text), HORIZONTAL_ALIGNMENT_CENTER, -1, int(p.size), Color(p.color, alpha))
		else:
			draw_circle(p.pos, float(p.size), Color(p.color, alpha))
	draw_set_transform(Vector2.ZERO)

func _draw_world() -> void:
	var base_colors := [Color("#6b9957"), Color("#315c3e"), Color("#548ba0"), Color("#887a60"), Color("#9a6548"), Color("#a8c7d6"), Color("#4e6b51")]
	var base: Color = base_colors[int(MAPS[current_map].theme)]
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), base)
	for y in range(0, int(MAP_SIZE.y), 48):
		for x in range(0, int(MAP_SIZE.x), 48):
			var n := abs((x / 48 * 17 + y / 48 * 31) % 7)
			var tint: Color = base.lightened(0.04) if n == 0 else base.darkened(0.06) if n == 1 else base
			draw_rect(Rect2(x, y, 48, 48), tint)
			if n == 2:
				draw_rect(Rect2(x + 13, y + 16, 3, 3), Color("#c2d17a"))
	for i in range(36):
		var x := float((i * 311 + 127) % 1720 + 40)
		var y := float((i * 197 + 83) % 1170 + 40)
		if current_map == 0:
			_draw_tree(Vector2(x, y), 0.8 + float(i % 3) * 0.1)
		elif i % 3 == 0:
			draw_circle(Vector2(x, y), 17, base.darkened(0.18))
			draw_circle(Vector2(x - 5, y - 5), 10, base.lightened(0.12))
		else:
			draw_rect(Rect2(x, y, 4, 4), [Color("#f3d878"), Color("#e9a9c5"), Color("#f4eee0")][i % 3])
	draw_line(Vector2(0, 960), Vector2(1740, 270), Color("#c9b77e"), 46.0, true)
	draw_line(Vector2(0, 960), Vector2(1740, 270), Color("#8f7950"), 58.0, true)
	if current_map == 0:
		draw_rect(Rect2(790, 400, 220, 150), Color("#9b6d43"))
		draw_rect(Rect2(780, 380, 240, 45), Color("#b44e43"))
		draw_rect(Rect2(865, 465, 55, 85), Color("#513b2d"))
		draw_circle(Vector2(1015, 520), 18, Color("#e5bb7a"))
		draw_string(ThemeDB.fallback_font, Vector2(940, 370), "GREENHAVEN", HORIZONTAL_ALIGNMENT_CENTER, -1, 20, Color("#fff0c5"))

func _draw_tree(pos: Vector2, scale: float) -> void:
	draw_rect(Rect2(pos.x - 5 * scale, pos.y - 1 * scale, 10 * scale, 24 * scale), Color("#57412d"))
	draw_circle(pos + Vector2(0, -9 * scale), 20 * scale, Color("#315c3e"))
	draw_circle(pos + Vector2(-7 * scale, -15 * scale), 12 * scale, Color("#477c49"))
	draw_circle(pos + Vector2(6 * scale, -18 * scale), 9 * scale, Color("#629454"))

func _draw_mob(m: Dictionary) -> void:
	var pos: Vector2 = m.pos
	draw_ellipse(pos + Vector2(0, 10), Vector2(20, 8), Color("#1b2b2270"))
	var bounce := absf(sin(Time.get_ticks_msec() / 250.0 + float(m.phase))) * 3.0
	var color: Color = m.color if m.hurt <= 0 else Color("#fff2ce")
	draw_circle(pos + Vector2(0, -bounce), float(m.radius), color)
	draw_circle(pos + Vector2(-5, -3 - bounce), 3, Color("#f3f0d5"))
	draw_circle(pos + Vector2(5, -3 - bounce), 3, Color("#f3f0d5"))
	draw_rect(Rect2(pos + Vector2(-float(m.radius), -float(m.radius) - 10), Vector2(float(m.radius) * 2, 4)), Color("#29242b"))
	draw_rect(Rect2(pos + Vector2(-float(m.radius), -float(m.radius) - 10), Vector2(float(m.radius) * 2 * clampf(float(m.hp) / float(m.max_hp), 0, 1), 4)), Color("#ed5d54"))
	if m.elite:
		draw_string(ThemeDB.fallback_font, pos + Vector2(0, -float(m.radius) - 17), "ELITE", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color("#ffcf75"))

func draw_ellipse(pos: Vector2, radius: Vector2, color: Color) -> void:
	# Keep the active world-camera transform intact; use a simple pixel-art shadow.
	draw_circle(pos + Vector2(0, 4), maxf(radius.x, radius.y) * 0.72, color)

func _draw_player() -> void:
	var pos: Vector2 = player.pos
	draw_circle(pos + Vector2(0, 12), 18, Color("#1b2b2270"))
	var moving := move_input.length() > 0.15
	var bob := absf(sin(Time.get_ticks_msec() / 90.0)) * 2.0 if moving else 0.0
	draw_rect(Rect2(pos + Vector2(-10, -7 + bob), Vector2(20, 24)), Color("#4d5f9c"))
	draw_rect(Rect2(pos + Vector2(-8, -20 + bob), Vector2(16, 15)), Color("#f0bd8c"))
	draw_rect(Rect2(pos + Vector2(-9, -24 + bob), Vector2(18, 7)), Color("#593b2e"))
	draw_rect(Rect2(pos + Vector2(-8, 14 + bob), Vector2(7, 10)), Color("#332e46"))
	draw_rect(Rect2(pos + Vector2(2, 14 + bob), Vector2(7, 10)), Color("#332e46"))
	var sword_end := pos + last_face * 39 + Vector2(0, -4)
	draw_line(pos + last_face * 9 + Vector2(0, -3), sword_end, Color("#dbe5ec"), 5.0, true)
	draw_line(pos + last_face * 15 + Vector2(0, -5), sword_end, Color("#ffffff"), 1.5, true)
	if player.hurt_cd > 0 and int(Time.get_ticks_msec() / 80) % 2 == 0:
		draw_arc(pos, 27, 0, TAU, 32, Color("#fff4cf"), 2.0)

func _update_hud() -> void:
	if is_instance_valid(hud_label):
		hud_label.text = "LV %d  •  HP %d/%d\nEXP %d/%d\nKills %d  •  Quest %d/%d" % [player.level, int(player.hp), int(player.max_hp), int(player.xp), int(player.next_xp), total_kills, map_kills, int(MAPS[current_map].goal)]
		gold_label.text = "◆ %d gold  •  Potions %d" % [player.gold, player.potions]
		inventory_label.text = "Weapon +%d  •  Armor +%d  •  Skill %s" % [player.weapon, player.armor, "READY" if player.skill_cd <= 0 else "%.1fs" % player.skill_cd]
		map_label.text = "%02d / 10  •  %s" % [current_map + 1, MAPS[current_map].name]
		message_label.text = toast_text if toast_time > 0 else ""

func _toast(text: String) -> void:
	toast_text = text
	toast_time = 2.4

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed and e.position.x < 230 and e.position.y > get_viewport_rect().size.y * 0.55:
			joystick_id = e.index
			stick_center = Vector2(100, get_viewport_rect().size.y - 85)
			_update_stick(e.position)
		elif not e.pressed and e.index == joystick_id:
			joystick_id = -1
			move_input = Vector2.ZERO
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == joystick_id:
			_update_stick(d.position)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W: move_input.y = -1
			KEY_DOWN, KEY_S: move_input.y = 1
			KEY_LEFT, KEY_A: move_input.x = -1
			KEY_RIGHT, KEY_D: move_input.x = 1
			KEY_SPACE, KEY_J: _attack()
			KEY_K: _use_skill()
			KEY_P: _use_potion()
			KEY_E: _interact()
			KEY_M: _advance_map()
	elif event is InputEventKey and not event.pressed:
		match event.keycode:
			KEY_UP, KEY_W, KEY_DOWN, KEY_S: move_input.y = 0
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D: move_input.x = 0

func _update_stick(pos: Vector2) -> void:
	var delta := pos - stick_center
	var max_dist := 54.0
	move_input = (delta / max_dist).limit_length(1.0)
	move_input.y = clampf(move_input.y, -1.0, 1.0)

func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_map", current_map)
	cfg.set_value("progress", "map_kills", map_kills)
	cfg.set_value("progress", "total_kills", total_kills)
	for key in player:
		cfg.set_value("player", key, player[key])
	var err := cfg.save(SAVE_PATH)
	_toast("Progress tersimpan offline." if err == OK else "Gagal menyimpan progres.")

func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	current_map = clampi(int(cfg.get_value("progress", "current_map", 0)), 0, MAPS.size() - 1)
	map_kills = int(cfg.get_value("progress", "map_kills", 0))
	total_kills = int(cfg.get_value("progress", "total_kills", 0))
	for key in player:
		player[key] = cfg.get_value("player", key, player[key])
	player.pos = Vector2(900, 625)
