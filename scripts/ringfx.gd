extends Node2D
## Expanding gold ring used by the Ink Nova upgrade. Frees itself.

var t := 0.0
var dur := 0.45
var rmax := 220.0


func setup(pos: Vector2, radius: float) -> void:
	global_position = pos
	rmax = radius


func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = t / dur
	var r: float = maxf(1.0, rmax * k)
	var a: float = 0.85 * (1.0 - k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(0.91, 0.78, 0.42, a), 1.0 + 7.0 * (1.0 - k))
