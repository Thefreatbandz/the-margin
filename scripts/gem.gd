extends Node2D
## Glowing ink drop. Pops out on kill, vacuums into the Scribe in magnet range.

var main = null
var value := 1
var vel := Vector2.ZERO
var age := 0.0
var spr: Sprite2D = null
var gem_base := 1.0
var magneted := false


func setup(pos: Vector2, p_value: int, p_main) -> void:
	global_position = pos
	value = p_value
	main = p_main
	var a: float = randf() * TAU
	vel = Vector2(cos(a), sin(a)) * randf_range(60.0, 190.0)
	if main != null:
		spr = Sprite2D.new()
		spr.texture = main.ART["gem"]
		var r: float = 6.0 + minf(float(value), 24.0) * 0.4
		gem_base = (r * 2.0 * 1.35) / (512.0 * 0.8)
		spr.scale = Vector2(gem_base, gem_base)
		add_child(spr)


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	age += delta
	vel = vel * (1.0 - minf(1.0, 4.0 * delta))
	position += vel * delta
	var pp: Vector2 = main.player.global_position
	var d2: float = global_position.distance_squared_to(pp)
	var mr: float = main.player.magnet_r
	magneted = d2 < mr * mr
	if magneted:
		var d: float = sqrt(maxf(d2, 1.0))
		var pull: float = 620.0 + 620.0 * (1.0 - d / mr)
		position += (pp - global_position) / d * pull * delta
		if d < 26.0:
			main.gems.erase(self)
			main.add_xp(value)
			main.sfx.play("gem")
			queue_free()
	# Sprite animation: gentle spin, pulse; stretch toward the Scribe when vacuumed.
	if spr != null:
		var pulse: float = 1.0 + 0.16 * sin(age * 7.0)
		if magneted:
			spr.rotation = (pp - global_position).angle() - PI * 0.5
			spr.scale = Vector2(gem_base * 0.8 * pulse, gem_base * 1.35 * pulse)
		else:
			spr.rotation += delta * 2.5
			spr.scale = Vector2(gem_base * pulse, gem_base * pulse)
