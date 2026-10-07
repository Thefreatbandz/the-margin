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
var magnet_r := 115.0
var regen := 0.0
var nova_level := 0

var aim := 0.0
var fire_acc := 0.0
var nova_acc := 0.0
var iframes := 0.0
var godmode := false  # QA screenshot mode only


func reset() -> void:
	max_hp = 110.0
	hp = 110.0
	speed = 305.0
	dmg = 12.0
	fire_rate = 2.2
	projectiles = 1
	pierce = 0
	magnet_r = 115.0
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
	main.sfx.play("hurt")
	if hp <= 0.0:
		hp = 0.0
		main.on_player_death()


func _move_dir() -> Vector2:
	if main.autotest or main.shots:
		# QA: lazy loop so combat happens on its own.
		return Vector2.from_angle(main.test_t * 0.5)
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


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	# Move.
	position += _move_dir() * speed * delta
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
	queue_redraw()


func _draw() -> void:
	# Soft ink-glow underfoot.
	draw_circle(Vector2.ZERO, 30.0, Color(0.91, 0.78, 0.42, 0.07))
	# Cloak.
	var cloak := PackedVector2Array([
		Vector2(0, -30), Vector2(-22, 20), Vector2(0, 11), Vector2(22, 20)])
	draw_colored_polygon(cloak, ROBE)
	draw_polyline(PackedVector2Array([Vector2(-22, 20), Vector2(0, -30), Vector2(22, 20)]), GOLD_DIM, 2.0)
	# Hood + gold-rimmed face shadow.
	draw_circle(Vector2(0, -16), 11.0, Color(0.07, 0.06, 0.09))
	draw_arc(Vector2(0, -16), 11.0, 0.0, TAU, 20, GOLD_DIM, 2.0)
	# Eyes like candle flames.
	draw_circle(Vector2(-4, -17), 2.4, GOLD)
	draw_circle(Vector2(4, -17), 2.4, GOLD)
	# Quill aimed at the nearest foe.
	var d := Vector2.from_angle(aim)
	var base: Vector2 = d * 14.0
	draw_line(base, base + d * 30.0, GOLD, 3.5)
	draw_line(base + d * 30.0, base + d * 38.0, Color(1.0, 0.96, 0.80), 2.0)
	draw_circle(base + d * 40.0, 3.2, Color(1.0, 0.96, 0.80))
