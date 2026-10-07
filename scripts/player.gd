extends Node2D
## The Scribe. Moves via WASD/arrows or the touch joystick, auto-fires the
## quill at the nearest foe, grows through upgrades.

const RADIUS := 20.0
const FIRE_RANGE := 580.0

const GOLD := Color(0.91, 0.78, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.25)
const ROBE := Color(0.10, 0.09, 0.13)

var main = null

var max_hp := 110.0
var hp := 110.0
var speed := 305.0
var dmg := 12.0
var fire_rate := 2.2
var projectiles := 1
var pierce := 0
var magnet_r := 140.0
var regen := 0.0
var nova_level := 0

var aim := 0.0
var fire_acc := 0.0
var nova_acc := 0.0
var iframes := 0.0
var godmode := false  # QA screenshot mode only

# Sprite art (built lazily on first frame; textures shared via main.ART).
var body: Sprite2D = null
var quill_pivot: Node2D = null
var quill: Sprite2D = null
var body_s := 0.1875  # 512px art -> ~96px on screen
var anim_t := 0.0
var flash := 0.0
var last_pos := Vector2.ZERO
var move_k := 0.0


func reset() -> void:
	max_hp = 110.0
	hp = 110.0
	speed = 305.0
	dmg = 12.0
	fire_rate = 2.2
	projectiles = 1
	pierce = 0
	magnet_r = 140.0
	regen = 0.0
	nova_level = 0
	aim = 0.0
	fire_acc = 0.0
	nova_acc = 0.0
	iframes = 0.0
	position = Vector2.ZERO
	queue_redraw()


func heal(v: float) -> void:
	hp = minf(max_hp, hp + v)


func take_damage(d: float) -> void:
	if godmode or main.state != "playing":
		return
	if iframes > 0.0:
		return
	hp -= d
	iframes = 0.75
	flash = 0.12
	main.sfx.play("hurt")
	if hp <= 0.0:
		hp = 0.0
		main.on_player_death()


func _move_dir() -> Vector2:
	if main.autotest or main.shots:
		# QA bot: flee the centroid of nearby foes (avoids surround), vacuum
		# the nearest gem when the coast is clear — like a human kiting.
		var cx := 0.0
		var cy := 0.0
		var n := 0
		for e in main.enemies:
			if not is_instance_valid(e):
				continue
			var d2: float = global_position.distance_squared_to(e.global_position)
			if d2 < 200.0 * 200.0:
				cx += e.global_position.x
				cy += e.global_position.y
				n += 1
		if n > 0:
			var away := Vector2(global_position.x - cx / n, global_position.y - cy / n)
			if away.length_squared() > 1.0:
				away = away.normalized()
				var side := Vector2(-away.y, away.x)
				return (away + side * 0.35).normalized()
		var best_g = null
		var best_gd2 := 1e18
		for g in main.gems:
			if not is_instance_valid(g):
				continue
			var gd2: float = global_position.distance_squared_to(g.global_position)
			if gd2 < best_gd2:
				best_gd2 = gd2
				best_g = g
		if best_g != null:
			var to_g: Vector2 = best_g.global_position - global_position
			if to_g.length_squared() > 900.0:
				return to_g.normalized()
		return Vector2.from_angle(main.test_t * 0.42)
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if main.joystick != null:
		v += main.joystick.get_vector()
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _nearest_enemy() -> Variant:
	var best = null
	var best_d2 := FIRE_RANGE * FIRE_RANGE
	for e in main.enemies:
		if not is_instance_valid(e):
			continue
		var d2: float = global_position.distance_squared_to(e.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = e
	return best


func _fire(target_aim: float) -> void:
	var n: int = projectiles
	for i in n:
		var spread := 0.0
		if n > 1:
			spread = (float(i) - float(n - 1) * 0.5) * 0.14
		var d := Vector2.from_angle(target_aim + spread)
		main.spawn_bullet(global_position + d * 24.0, d, dmg, pierce, self)
	main.sfx.play("shoot")


func _nova() -> void:
	var radius := 190.0 + 45.0 * float(nova_level)
	var ndmg: float = 26.0 * float(nova_level) + 8.0 * float(main.level)
	main.ring_fx(global_position, radius)
	main.sfx.play("nova")
	# Iterate a copy: damage can kill and mutate main.enemies.
	var foes: Array = main.enemies.duplicate()
	for e in foes:
		if not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= radius + e.radius:
			e.take_damage(ndmg)


func _build_sprites() -> void:
	body = Sprite2D.new()
	body.texture = main.ART["scribe"]
	body.scale = Vector2(body_s, body_s)
	add_child(body)
	quill_pivot = Node2D.new()
	quill_pivot.position = Vector2(0, 6)
	add_child(quill_pivot)
	quill = Sprite2D.new()
	quill.texture = main.ART["quill"]
	var qs := 66.0 / 512.0
	quill.scale = Vector2(qs, qs)
	quill.position = Vector2(46, 0)
	quill.rotation = -PI * 0.74  # nib (bottom-left in art) -> pivot +x
	quill_pivot.add_child(quill)
	last_pos = position


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	if body == null:
		_build_sprites()
	# Move.
	position += _move_dir() * speed * delta
	# Sprite animation: idle bob, walk squash-and-stretch, lean, hit flash.
	anim_t += delta
	var vel: Vector2 = (position - last_pos) / maxf(delta, 0.0001)
	last_pos = position
	move_k = lerpf(move_k, clampf(vel.length() / maxf(speed, 1.0), 0.0, 1.0),
		minf(1.0, 10.0 * delta))
	var pulse: float = sin(anim_t * 11.0) * 0.045 * move_k
	body.position = Vector2(0, sin(anim_t * 3.2) * 2.5)
	body.scale = Vector2(body_s * (1.0 + pulse), body_s * (1.0 - pulse))
	body.rotation = clampf(vel.x * 0.00035, -0.14, 0.14)
	if flash > 0.0:
		flash -= delta
		var f: float = clampf(flash / 0.12, 0.0, 1.0)
		var fc := Color(1.0 + 1.4 * f, 1.0 + 1.2 * f, 1.0 + 0.7 * f)
		body.self_modulate = fc
		quill.self_modulate = fc
	else:
		body.self_modulate = Color.WHITE
		quill.self_modulate = Color.WHITE
	# Regen + iframes.
	if regen > 0.0:
		hp = minf(max_hp, hp + regen * delta)
	if iframes > 0.0:
		iframes -= delta
		modulate.a = 0.45 + 0.35 * sin(iframes * 40.0)
	else:
		modulate.a = 1.0
	# Aim at nearest foe (or keep last aim).
	var foe = _nearest_enemy()
	if foe != null:
		aim = (foe.global_position - global_position).angle()
	quill_pivot.rotation = aim
	# Auto-fire.
	fire_acc += delta
	var interval := 1.0 / maxf(0.2, fire_rate)
	while fire_acc >= interval:
		fire_acc -= interval
		_fire(aim)
	# Ink nova.
	if nova_level > 0:
		nova_acc += delta
		var nint := maxf(2.5, 6.5 - 0.6 * float(nova_level))
		if nova_acc >= nint:
			nova_acc = 0.0
			_nova()
