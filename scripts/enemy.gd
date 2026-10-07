extends Node2D
## One foe of the cursed tome. Chases the Scribe, deals contact damage,
## dies into an ink drop. Kinds: typo, shard, blot, scribble, redactor.

const GOLD := Color(0.91, 0.78, 0.42)
const PAPER := Color(0.85, 0.82, 0.72)

var main = null
var kind := "typo"
var hp := 10.0
var max_hp := 10.0
var spd := 90.0
var dmg := 8.0
var xp_value := 1
var radius := 16.0
var elite := false
var is_boss := false

var letter := "e"
var touch_cd := 0.0
var hit_flash := 0.0
var wob := 0.0
var wob_seed := 0.0


func setup(p_kind: String, stats: Dictionary, p_elite: bool, pos: Vector2, p_main) -> void:
	kind = p_kind
	main = p_main
	elite = p_elite
	is_boss = (p_kind == "redactor")
	hp = float(stats["hp"])
	max_hp = hp
	spd = float(stats["spd"])
	dmg = float(stats["dmg"])
	xp_value = int(stats["xp"])
	radius = float(stats["r"])
	global_position = pos
	wob_seed = randf() * TAU
	if elite and not is_boss:
		hp *= 9.0
		max_hp = hp
		spd *= 0.92
		dmg *= 1.6
		xp_value *= 6
		radius *= 1.55
	if kind == "typo":
		var letters := "etaoinshrdlcumwfgypbvkjxqz"
		letter = letters[randi() % letters.length()]


func take_damage(d: float) -> void:
	if main == null or main.state != "playing":
		return
	hp -= d
	hit_flash = 0.12
	if hp <= 0.0:
		main.on_enemy_killed(self)
		queue_free()


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	wob += delta
	if hit_flash > 0.0:
		hit_flash -= delta
	if touch_cd > 0.0:
		touch_cd -= delta
	# Chase with a slight sideways wobble so hordes don't perfectly stack.
	var to_p: Vector2 = main.player.global_position - global_position
	var dist: float = to_p.length()
	if dist > 1.0:
		var dir: Vector2 = to_p / dist
		var side := Vector2(-dir.y, dir.x)
		var w: float = sin(wob * 2.2 + wob_seed) * 0.35
		position += (dir + side * w).normalized() * spd * delta
	# Contact damage.
	if dist < radius + 20.0 and touch_cd <= 0.0:
		touch_cd = 0.8
		main.player.take_damage(dmg)
	queue_redraw()


func _flash_col(base: Color) -> Color:
	if hit_flash > 0.0:
		return base.lerp(Color.WHITE, 0.75)
	return base


func _draw() -> void:
	match kind:
		"typo":
			_draw_typo()
		"shard":
			_draw_shard()
		"blot":
			_draw_blot()
		"scribble":
			_draw_scribble()
		"redactor":
			_draw_redactor()


func _draw_typo() -> void:
	# A living letter, glowing gold (red-rimmed when elite).
	var fs := int(radius * 2.1)
	if elite:
		draw_circle(Vector2.ZERO, radius + 6.0, Color(0.85, 0.25, 0.2, 0.25))
	var font: Font = ThemeDB.fallback_font
	var col: Color = _flash_col(GOLD)
	draw_string(font, Vector2(-float(fs) * 0.32, float(fs) * 0.36), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)


func _draw_shard() -> void:
	# Jagged torn-page fragment, paper white with a gold edge.
	var s := radius
	var pts := PackedVector2Array([
		Vector2(0, -s * 1.2), Vector2(s * 0.55, -s * 0.5), Vector2(s * 1.1, -s * 0.7),
		Vector2(s * 0.7, 0), Vector2(s * 1.0, s * 0.6), Vector2(s * 0.3, s * 0.5),
		Vector2(0, s * 1.1), Vector2(-s * 0.4, s * 0.5), Vector2(-s * 1.0, s * 0.7),
		Vector2(-s * 0.6, 0), Vector2(-s * 1.1, -s * 0.6), Vector2(-s * 0.5, -s * 0.5)])
	var col: Color = _flash_col(PAPER)
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _flash_col(GOLD_DIM()), 2.0)
	if elite:
		draw_arc(Vector2.ZERO, s * 1.35, 0, TAU, 24, Color(0.85, 0.25, 0.2, 0.8), 3.0)


func GOLD_DIM() -> Color:
	return Color(0.55, 0.45, 0.25)


func _draw_blot() -> void:
	# Wobbling ink blob: dark body, violet rim.
	var w: float = 1.0 + 0.12 * sin(wob * 5.0 + wob_seed)
	var body := Color(0.13, 0.08, 0.20)
	var rim := Color(0.55, 0.35, 0.85)
	if hit_flash > 0.0:
		body = body.lerp(Color.WHITE, 0.6)
		rim = rim.lerp(Color.WHITE, 0.6)
	for i in 5:
		var a: float = float(i) / 5.0 * TAU + wob_seed
		var off := Vector2(cos(a), sin(a)) * radius * 0.42 * w
		draw_circle(off, radius * 0.72 * w, body)
	draw_arc(Vector2.ZERO, radius * 1.02 * w, 0, TAU, 28, rim, 3.0)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.18, Color(0.75, 0.6, 1.0, 0.8))
	if elite:
		draw_arc(Vector2.ZERO, radius * 1.3 * w, 0, TAU, 28, Color(0.85, 0.25, 0.2, 0.8), 3.0)


func _draw_scribble() -> void:
	# Frantic margin scribble: chaotic red-orange strokes.
	var col := Color(1.0, 0.48, 0.24)
	if hit_flash > 0.0:
		col = Color.WHITE
	var pts := PackedVector2Array()
	var n := 9
	for i in n + 1:
		var a: float = float(i) / float(n) * TAU * 2.5 + wob_seed
		var r: float = radius * (0.55 + 0.45 * absf(sin(float(i) * 2.7 + wob_seed)))
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_polyline(pts, col, 3.5)
	draw_polyline(pts, Color(1.0, 0.48, 0.24, 0.3), 8.0)
	if elite:
		draw_arc(Vector2.ZERO, radius * 1.3, 0, TAU, 24, Color(0.85, 0.25, 0.2, 0.8), 3.0)


func _draw_redactor() -> void:
	# THE REDACTOR: a towering black bar, redaction stripes, burning eyes.
	var w := radius * 1.7
	var h := radius * 2.1
	var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
	draw_rect(rect, Color(0.02, 0.02, 0.03))
	draw_rect(rect, Color(0.85, 0.25, 0.2, 0.9), false, 4.0)
	# White redaction bars (the censored lines).
	var bc := Color(0.92, 0.90, 0.84)
	if hit_flash > 0.0:
		bc = Color.WHITE
	for i in 3:
		var y: float = -h * 0.28 + float(i) * h * 0.26
		draw_rect(Rect2(-w * 0.38, y, w * 0.76, h * 0.13), bc)
	# Burning eyes above the bars.
	var flicker: float = 0.75 + 0.25 * sin(wob * 9.0)
	draw_circle(Vector2(-w * 0.2, -h * 0.38), 7.0 * flicker, Color(1.0, 0.3, 0.15))
	draw_circle(Vector2(w * 0.2, -h * 0.38), 7.0 * flicker, Color(1.0, 0.3, 0.15))
	draw_circle(Vector2.ZERO, w * 0.75, Color(0.85, 0.25, 0.2, 0.10))
