extends Node2D
## The cursed page: black paper, faint gold ruled lines, margin rule.
## Snaps to the camera so the page feels infinite.

const LINE_COL := Color(0.91, 0.78, 0.42, 0.05)
const MARGIN_COL := Color(0.91, 0.78, 0.42, 0.12)

var main = null


func _process(_delta: float) -> void:
	if main == null or main.cam == null:
		return
	var c: Vector2 = main.cam.get_screen_center_position()
	var nx: float = snappedf(c.x, 8.0)
	var ny: float = snappedf(c.y, 8.0)
	if position.x != nx or position.y != ny:
		position = Vector2(nx, ny)
		queue_redraw()


func _draw() -> void:
	# Ruled lines across a generous region around the camera.
	for i in range(-24, 25):
		var y: float = float(i) * 72.0
		draw_line(Vector2(-1100, y), Vector2(1100, y), LINE_COL, 2.0)
	# Double margin rule, offset left like a real page.
	draw_line(Vector2(-260, -1800), Vector2(-260, 1800), MARGIN_COL, 2.0)
	draw_line(Vector2(-250, -1800), Vector2(-250, 1800), Color(0.91, 0.78, 0.42, 0.06), 2.0)
