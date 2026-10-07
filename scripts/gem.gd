extends Node2D
## Glowing ink drop. Pops out on kill, vacuums into the Scribe in magnet range.

var main = null
var value := 1
var vel := Vector2.ZERO
var age := 0.0


func setup(pos: Vector2, p_value: int, p_main) -> void:
	global_position = pos
	value = p_value
	main = p_main
	var a: float = randf() * TAU
	vel = Vector2(cos(a), sin(a)) * randf_range(60.0, 190.0)


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	age += delta
	vel = vel * (1.0 - minf(1.0, 4.0 * delta))
	position += vel * delta
	var pp: Vector2 = main.player.global_position
	var d2: float = global_position.distance_squared_to(pp)
	var mr: float = main.player.magnet_r
	if d2 < mr * mr:
		var d: float = sqrt(maxf(d2, 1.0))
		var pull: float = 620.0 + 620.0 * (1.0 - d / mr)
		position += (pp - global_position) / d * pull * delta
		if d < 26.0:
			main.gems.erase(self)
			main.add_xp(value)
			main.sfx.play("gem")
			queue_free()


func _draw() -> void:
	var r: float = 6.0 + minf(float(value), 24.0) * 0.4
	var pulse: float = 1.0 + 0.16 * sin(age * 7.0)
	r *= pulse
	# Teardrop: circle head + tail triangle.
	draw_circle(Vector2(0, -r * 0.35), r * 0.62, Color(0.91, 0.78, 0.42, 0.30))
	var tri := PackedVector2Array([
		Vector2(-r * 0.55, -r * 0.1), Vector2(r * 0.55, -r * 0.1), Vector2(0, r * 0.9)])
	draw_colored_polygon(tri, Color(0.95, 0.82, 0.45, 0.95))
	draw_circle(Vector2(0, -r * 0.35), r * 0.30, Color(1.0, 0.97, 0.85))
