extends Node2D
## Ink bolt fired by the Scribe's quill. Manual circle collision, no physics.

var main = null
var dir := Vector2.RIGHT
var speed := 760.0
var dmg := 12.0
var pierce := 0
var life := 1.4


func setup(pos: Vector2, p_dir: Vector2, p_dmg: float, p_pierce: int, p_speed: float, p_main) -> void:
	global_position = pos
	dir = p_dir
	dmg = p_dmg
	pierce = p_pierce
	speed = p_speed
	main = p_main


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	position += dir * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	# Hit test against live enemies (main.enemies is the single live list).
	var foes: Array = main.enemies
	for i in range(foes.size() - 1, -1, -1):
		var e = foes[i]
		if not is_instance_valid(e):
			continue
		var rr: float = e.radius + 9.0
		if global_position.distance_squared_to(e.global_position) < rr * rr:
			e.take_damage(dmg)
			e.position += dir * 14.0  # ink splatter shoves foes back
			main.sfx.play("hit")
			if pierce > 0:
				pierce -= 1
			else:
				queue_free()
				return


func _draw() -> void:
	# Glow halo + hot core: cheap "ink fire" look.
	draw_circle(Vector2.ZERO, 11.0, Color(0.91, 0.78, 0.42, 0.22))
	draw_circle(Vector2.ZERO, 5.5, Color(0.95, 0.82, 0.45))
	draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.96, 0.80))
