extends Node2D
## THE MARGIN v1 — cursed-tome survivors-like.
## Builds the whole scene in code (root scene is just this script).

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const GemScript := preload("res://scripts/gem.gd")
const BgScript := preload("res://scripts/bg.gd")
const HudScript := preload("res://scripts/hud.gd")
const JoystickScript := preload("res://scripts/joystick.gd")
const LevelUpScript := preload("res://scripts/levelup.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const RingFxScript := preload("res://scripts/ringfx.gd")

const GOLD := Color(0.91, 0.78, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.25)
const PAPER := Color(0.85, 0.82, 0.72)

# kind -> base stats. unlock = seconds when the kind joins the horde.
const ETYPES := {
	"typo": {"hp": 16.0, "spd": 88.0, "dmg": 6.0, "xp": 1, "r": 15.0, "unlock": 0.0, "w": 100.0},
	"shard": {"hp": 46.0, "spd": 82.0, "dmg": 14.0, "xp": 3, "r": 19.0, "unlock": 45.0, "w": 70.0},
	"blot": {"hp": 95.0, "spd": 64.0, "dmg": 20.0, "xp": 6, "r": 23.0, "unlock": 110.0, "w": 55.0},
	"scribble": {"hp": 160.0, "spd": 122.0, "dmg": 26.0, "xp": 10, "r": 21.0, "unlock": 180.0, "w": 45.0},
}

const UPGRADES := [
	{"id": "dmg", "name": "Sharpened Nib", "desc": "+25% ink damage", "max": 99},
	{"id": "rate", "name": "Swift Strokes", "desc": "+18% fire rate", "max": 99},
	{"id": "speed", "name": "Fleet Foot", "desc": "+10% move speed", "max": 8},
	{"id": "hp", "name": "Thick Vellum", "desc": "+25 max HP, heal 25", "max": 10},
	{"id": "magnet", "name": "Wide Margins", "desc": "+45% pickup radius", "max": 6},
	{"id": "multi", "name": "Twin Nibs", "desc": "+1 ink bolt per shot", "max": 3},
	{"id": "pierce", "name": "Through the Page", "desc": "Bolts pierce +1 enemy", "max": 4},
	{"id": "nova", "name": "Ink Nova", "desc": "Periodic burst burns nearby foes", "max": 3},
	{"id": "regen", "name": "Self-Inking", "desc": "Regenerate +0.8 HP /s", "max": 5},
]

const MAX_ENEMIES := 150
const MAX_GEMS := 240
const BOSS_EVERY := 300.0

var state := "title"  # title | playing | levelup | dead
var run_time := 0.0
var kills := 0
var level := 1
var xp := 0
var xp_next := 8
var stacks := {}
var pending_levelups := 0
var enemies: Array = []
var gems: Array = []
var boss_active := false
var boss_ref = null
var boss_count := 0
var next_boss_at := BOSS_EVERY
var spawn_acc := 0.0
var muted := false
var rng := RandomNumberGenerator.new()

var player = null
var cam: Camera2D = null
var hud = null
var joystick = null
var levelup_ui = null
var sfx = null
var world: Node2D = null

var title_layer: CanvasLayer
var title_hint: Label
var death_layer: CanvasLayer
var death_stats: Label
var blink_t := 0.0

# QA hooks (command-line only; never active in the shipped game).
var autotest := false
var soak := false
var shots := false
var shots_quiet := false  # shots mode: stop opening the level-up overlay
var shot_step := 0
var shot_frames := 0
var test_t := 0.0


# ---------------------------------------------------------------- build

func _label(text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	soak = "--soak" in args
	shots = "--shots" in args

	# Page background.
	var bg = BgScript.new()
	bg.main = self
	add_child(bg)

	# World holds everything gameplay.
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	# Player.
	player = PlayerScript.new()
	player.main = self
	world.add_child(player)

	# Camera.
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.make_current()

	# Ink-dust motes drifting across the page.
	var dust := CPUParticles2D.new()
	dust.amount = 70
	dust.lifetime = 7.0
	dust.preprocess = 7.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(420, 700)
	dust.direction = Vector2(0.3, -1.0)
	dust.spread = 35.0
	dust.initial_velocity_min = 8.0
	dust.initial_velocity_max = 26.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 1.5
	dust.scale_amount_max = 3.5
	dust.color = Color(0.91, 0.78, 0.42, 0.35)
	add_child(dust)

	# Sound.
	sfx = SfxScript.new()
	add_child(sfx)

	# HUD + joystick + level-up overlay.
	hud = HudScript.new()
	hud.main = self
	add_child(hud)
	hud.visible = false

	var joy_layer := CanvasLayer.new()
	joy_layer.layer = 10
	add_child(joy_layer)
	joystick = JoystickScript.new()
	joystick.main = self
	joy_layer.add_child(joystick)

	levelup_ui = LevelUpScript.new()
	levelup_ui.main = self
	add_child(levelup_ui)

	_build_title()
	_build_death()

	if autotest or soak or shots:
		if shots:
			player.godmode = true
			shots_quiet = true  # the forced level-up in step 2 re-enables it
			# Keep ticking (for _shots_tick) even while the tree is paused
			# for the level-up overlay. The title stays up until step 0
			# of the shot script starts the game.
			process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			start_game()
		if autotest or soak:
			if not ("--realtime" in args):
				Engine.time_scale = 8.0


func _build_title() -> void:
	title_layer = CanvasLayer.new()
	title_layer.layer = 30
	add_child(title_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.add_child(root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 1)
	root.add_child(bg)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	cc.add_child(vb)

	# Gold rule lines framing the title, like a book plate.
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(420, 3)
	rule.color = GOLD_DIM
	var rc := CenterContainer.new()
	rc.add_child(rule)
	vb.add_child(rc)

	var t := _label("THE MARGIN", 108, GOLD)
	vb.add_child(t)
	vb.add_child(_label("a cursed-tome survivors tale", 26, PAPER))
	vb.add_child(_label("you are the Scribe — the ink wants you dead", 22, GOLD_DIM))

	title_hint = _label("— tap or press any key to begin —", 28, GOLD)
	vb.add_child(title_hint)
	vb.add_child(_label("WASD / arrows · touch joystick", 20, GOLD_DIM))


func _build_death() -> void:
	death_layer = CanvasLayer.new()
	death_layer.layer = 30
	death_layer.visible = false
	add_child(death_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_layer.add_child(root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	root.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	cc.add_child(vb)
	vb.add_child(_label("BLOTTED OUT", 84, Color(0.9, 0.3, 0.22)))
	death_stats = _label("", 26, PAPER)
	vb.add_child(death_stats)

	var btn := Button.new()
	btn.text = "WRITE AGAIN"
	btn.custom_minimum_size = Vector2(320, 76)
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	var bs := StyleBoxFlat.new()
	bs.bg_color = GOLD
	bs.set_corner_radius_all(10)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bs)
	btn.add_theme_stylebox_override("pressed", bs)
	btn.pressed.connect(_on_restart_pressed)
	var bc := CenterContainer.new()
	bc.add_child(btn)
	vb.add_child(bc)


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if state != "title":
		return
	var begin := false
	if event is InputEventKey:
		begin = (event as InputEventKey).pressed and not (event as InputEventKey).echo
	elif event is InputEventScreenTouch:
		begin = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		begin = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if begin:
		start_game()


# ---------------------------------------------------------------- flow

func start_game() -> void:
	if state == "playing" or state == "levelup":
		return
	state = "playing"
	run_time = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_next = 8
	stacks.clear()
	pending_levelups = 0
	boss_active = false
	boss_ref = null
	boss_count = 0
	next_boss_at = BOSS_EVERY
	spawn_acc = 0.0
	test_t = 0.0
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	for g in gems:
		if is_instance_valid(g):
			g.queue_free()
	enemies.clear()
	gems.clear()
	player.reset()
	hud.hide_boss()
	hud.visible = true
	hud.set_mute_label(muted)
	joystick.set_active(true)
	title_layer.visible = false
	death_layer.visible = false
	get_tree().paused = false


func on_player_death() -> void:
	if state != "playing":
		return
	state = "dead"
	sfx.play("death")
	joystick.set_active(false)
	var t := int(run_time)
	death_stats.text = "survived %02d:%02d   ·   level %d   ·   %d kills" % [t / 60, t % 60, level, kills]
	death_layer.visible = true


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func toggle_mute() -> void:
	muted = not muted
	sfx.set_muted(muted)
	hud.set_mute_label(muted)


# ---------------------------------------------------------------- xp / levels

func xp_for_level(lv: int) -> int:
	return 8 + (lv - 1) * 6


func add_xp(v: int) -> void:
	if state != "playing":
		return
	xp += v
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = xp_for_level(level)
		pending_levelups += 1
	if pending_levelups > 0 and state == "playing" and not shots_quiet:
		_open_levelup()


func _pick_upgrades() -> Array:
	var avail: Array = []
	for u in UPGRADES:
		if int(stacks.get(u["id"], 0)) < int(u["max"]):
			avail.append(u)
	avail.shuffle()
	return avail.slice(0, 3)


func _open_levelup() -> void:
	state = "levelup"
	get_tree().paused = true
	sfx.play("levelup")
	levelup_ui.show_cards(_pick_upgrades())


func choose_upgrade(uid: String) -> void:
	if state != "levelup":
		return
	apply_upgrade(uid)
	pending_levelups = maxf(0, pending_levelups - 1)
	if pending_levelups > 0:
		levelup_ui.show_cards(_pick_upgrades())
	else:
		levelup_ui.hide_cards()
		get_tree().paused = false
		state = "playing"


func apply_upgrade(uid: String) -> void:
	stacks[uid] = int(stacks.get(uid, 0)) + 1
	match uid:
		"dmg":
			player.dmg *= 1.25
		"rate":
			player.fire_rate *= 1.18
		"speed":
			player.speed *= 1.10
		"hp":
			player.max_hp += 25.0
			player.heal(25.0)
		"magnet":
			player.magnet_r *= 1.45
		"multi":
			player.projectiles += 1
		"pierce":
			player.pierce += 1
		"nova":
			player.nova_level += 1
		"regen":
			player.regen += 0.8


# ---------------------------------------------------------------- spawning

func _spawn_pos() -> Vector2:
	var a: float = rng.randf() * TAU
	var r: float = rng.randf_range(860.0, 980.0)
	return player.global_position + Vector2(cos(a), sin(a)) * r


func _pick_kind() -> String:
	var total := 0.0
	var cands: Array = []
	for k in ETYPES.keys():
		var st: Dictionary = ETYPES[k]
		if run_time >= float(st["unlock"]):
			cands.append(k)
			total += float(st["w"])
	if cands.is_empty():
		return "typo"
	var roll: float = rng.randf() * total
	for k in cands:
		roll -= float(ETYPES[k]["w"])
		if roll <= 0.0:
			return k
	return cands.back()


func spawn_enemy() -> void:
	var kind := _pick_kind()
	var st: Dictionary = ETYPES[kind]
	var hp_scale := 1.0 + (run_time / 60.0) * 0.35
	var s2 := st.duplicate()
	s2["hp"] = float(st["hp"]) * hp_scale
	var elite := run_time >= 100.0 and rng.randf() < 0.06
	var e = EnemyScript.new()
	world.add_child(e)
	e.setup(kind, s2, elite, _spawn_pos(), self)
	enemies.append(e)


func spawn_boss() -> void:
	var scale := 1.0 + float(boss_count) * 0.85
	var stats := {"hp": 2400.0 * scale, "spd": 52.0, "dmg": 32.0, "xp": 150, "r": 58.0}
	if shots:
		# QA: the drained upgrade stack would one-shot the boss otherwise.
		stats["hp"] = float(stats["hp"]) * 60.0
	var e = EnemyScript.new()
	world.add_child(e)
	e.setup("redactor", stats, false, _spawn_pos(), self)
	enemies.append(e)
	boss_active = true
	boss_ref = e
	boss_count += 1
	next_boss_at = run_time + BOSS_EVERY
	hud.show_boss()
	sfx.play("boss")


func on_enemy_killed(e) -> void:
	if state != "playing" and state != "levelup":
		return
	enemies.erase(e)
	kills += 1
	add_gem(e.global_position, e.xp_value)
	if e.is_boss:
		boss_active = false
		boss_ref = null
		hud.hide_boss()


func add_gem(pos: Vector2, value: int) -> void:
	if gems.size() >= MAX_GEMS:
		var oldest = gems.pop_front()
		if is_instance_valid(oldest):
			add_xp(oldest.value)
			oldest.queue_free()
	var g = GemScript.new()
	world.add_child(g)
	g.setup(pos, value, self)
	gems.append(g)


func spawn_bullet(pos: Vector2, dir: Vector2, dmg: float, pierce: int, p) -> void:
	var b = BulletScript.new()
	world.add_child(b)
	b.setup(pos, dir, dmg, pierce, 760.0, self)


func ring_fx(pos: Vector2, radius: float) -> void:
	var r = RingFxScript.new()
	world.add_child(r)
	r.setup(pos, radius)


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	test_t += delta
	if shots:
		_shots_tick()
	if state == "title":
		blink_t += delta
		if title_hint != null:
			title_hint.modulate.a = 0.55 + 0.45 * sin(blink_t * 4.0)
		return
	if state != "playing":
		if autotest or soak:
			_autotest_tick()
		return

	run_time += delta
	cam.global_position = player.global_position

	# Spawning.
	spawn_acc += delta
	var interval := maxf(0.18, 0.7 - run_time * 0.0013)
	if boss_active:
		interval *= 1.7
	if spawn_acc >= interval:
		spawn_acc = 0.0
		if enemies.size() < MAX_ENEMIES:
			var batch := 1 + int(run_time / 70.0)
			batch = mini(batch, 6)
			for i in batch:
				spawn_enemy()

	# Boss schedule.
	if run_time >= next_boss_at and not boss_active:
		spawn_boss()
	if boss_active and is_instance_valid(boss_ref):
		hud.set_boss_hp(boss_ref.hp, boss_ref.max_hp)

	hud.update_hud(player.hp, player.max_hp, xp, xp_next, level, run_time, kills)

	if autotest or soak:
		_autotest_tick()


func _autotest_tick() -> void:
	# Auto-pick the first card so soaks don't stall on the overlay.
	if state == "levelup" and levelup_ui.current_ids.size() > 0:
		choose_upgrade(levelup_ui.current_ids[0])
	var target := 30.0 if autotest else 150.0
	if run_time >= target or state == "dead":
		print("AUTOTEST_SUMMARY died=%s kills=%d level=%d time=%.1f enemies=%d gems=%d hp=%.0f upgrades=%s" % [
			state == "dead", kills, level, run_time, enemies.size(), gems.size(),
			player.hp, str(stacks)])
		get_tree().quit()


func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err := img.save_png("/home/hatch/workspace/margin/qa/%s.png" % name)
	print("SHOT %s err=%d" % [name, err])


func _shots_tick() -> void:
	# Scripted screenshot run under Xvfb: title -> gameplay -> levelup -> boss.
	shot_frames += 1
	match shot_step:
		0:
			if shot_frames >= 12:
				_save_shot("title")
				shot_step = 5
				shot_frames = 0
		5:
			# Let the async title shot land before starting the game.
			if shot_frames >= 15:
				shot_step = 1
				shot_frames = 0
				start_game()
		1:
			if run_time >= 12.0:
				_save_shot("gameplay")
				shot_step = 15
				shot_frames = 0
		15:
			# Let the async gameplay shot land before forcing a level-up.
			if shot_frames >= 15:
				shot_step = 2
				shot_frames = 0
				shots_quiet = false
				add_xp(9999)
		2:
			if state == "levelup" and shot_frames >= 18:
				_save_shot("levelup")
				shot_step = 25
				shot_frames = 0
		25:
			# Let the async level-up shot land before draining the picks.
			if shot_frames >= 15:
				shot_step = 3
				shot_frames = 0
				# Drain every pending level-up so the game resumes.
				var guard := 0
				while state == "levelup" and levelup_ui.current_ids.size() > 0 and guard < 200:
					choose_upgrade(levelup_ui.current_ids[0])
					guard += 1
		3:
			if shot_frames == 5:
				shots_quiet = true  # no more overlays while framing the boss
				spawn_boss()
			# Keep the boss framed next to the player for the shot.
			if shot_frames >= 5 and is_instance_valid(boss_ref):
				boss_ref.global_position = player.global_position + Vector2(170, -110)
			if shot_frames >= 70:
				_save_shot("boss")
				shot_step = 4
				shot_frames = 0
		4:
			if shot_frames >= 10:
				print("SHOTS_DONE")
				get_tree().quit()
