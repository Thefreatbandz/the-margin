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
var spr: Sprite2D = null  # sprite art for shard/blot/scribble/redactor
var spr_base := 1.0


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
	if kind != "typo" and main != null:
		# Sprite art shared via main.ART (one texture, never duplicated).
		spr = Sprite2D.new()
		spr.texture = main.ART[kind]
		spr_base = (radius * 2.0) / (512.0 * 0.85)
		spr.scale = Vector2(spr_base, spr_base)
		add_child(spr)


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
		touch_cd = 1.0
		main.player.take_damage(dmg)
	# Procedural sprite animation: wobble, bob, hit flash, boss menace pulse.
	if spr != null:
		var w1: float = sin(wob * 2.6 + wob_seed)
		var w2: float = sin(wob * 3.9 + wob_seed * 1.7)
		spr.rotation = w1 * 0.10
		var s: float = spr_base * (1.0 + 0.05 * w2)
		if is_boss:
			s *= 1.0 + 0.06 * sin(wob * 2.1)
		spr.scale = Vector2(s, s)
		if hit_flash > 0.0:
			var f: float = clampf(hit_flash / 0.12, 0.0, 1.0)
			spr.self_modulate = Color(1.0 + 1.6 * f, 1.0 + 1.4 * f, 1.0 + 0.8 * f)
		else:
			spr.self_modulate = Color.WHITE
	# Typo glyphs and elite rings are still code-drawn; sprites need no redraw.
	if kind == "typo" or elite:
		queue_redraw()


func _flash_col(base: Color) -> Color:
	if hit_flash > 0.0:
		return base.lerp(Color.WHITE, 0.75)
	return base


func _draw() -> void:
	# Elites keep their red warning ring; typos are living glyphs.
	if elite and not is_boss:
		draw_arc(Vector2.ZERO, radius * 1.3, 0, TAU, 28,
			Color(0.85, 0.25, 0.2, 0.8), 3.0)
	if kind == "typo":
		_draw_typo()


func _draw_typo() -> void:
	# A living letter: wobble drift, breathing size, squash-and-stretch.
	var fs := int(radius * 2.1 * (1.0 + 0.08 * sin(wob * 5.0 + wob_seed)))
	var off := Vector2(sin(wob * 6.0 + wob_seed) * 3.0,
		cos(wob * 4.2 + wob_seed) * 2.0)
	var sq: float = 0.10 * sin(wob * 7.0 + wob_seed)
	if elite:
		draw_circle(Vector2.ZERO, radius + 6.0, Color(0.85, 0.25, 0.2, 0.25))
	draw_set_transform(off, 0.0, Vector2(1.0 + sq, 1.0 - sq))
	var font: Font = ThemeDB.fallback_font
	var col: Color = _flash_col(GOLD)
	draw_string(font, Vector2(-float(fs) * 0.32, float(fs) * 0.36), letter,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
