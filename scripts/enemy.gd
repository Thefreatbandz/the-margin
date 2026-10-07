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
# v3 skeletal rig (shard/blot/scribble/redactor). Typo stays a text glyph.
var rig: Node2D = null
var anim: AnimationPlayer = null
var part_sprites: Array = []
var dying := false
var die_t := 0.0
var hit_t := 0.0
var lunge_t := 0.0
var lunge_cd := 0.0
var slam_cd := 3.0
var windup_t := 0.0
var slam_t := 0.0
var face := 0.0

const RIG_SCALE := {"shard": 0.115, "blot": 0.13, "scribble": 0.11, "redactor": 0.23}


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
		# Skeletal rig shared via main.ART (textures preloaded once).
		var r: Dictionary = Rig.enemy(kind, main.ART)
		rig = r["root"]
		anim = r["anim"]
		part_sprites = r["sprites"]
		var sc: float = float(RIG_SCALE.get(kind, 0.12))
		if elite:
			sc *= 1.55
		rig.scale = Vector2(sc, sc)
		add_child(rig)
		anim.play("move")


func take_damage(d: float) -> void:
	if main == null or main.state != "playing" or dying:
		return
	hp -= d
	hit_flash = 0.12
	if hp <= 0.0:
		dying = true
		die_t = 0.45
		if anim != null:
			anim.play("die")
	else:
		if hit_t <= 0.0 and anim != null:
			anim.play("hit")
			hit_t = 0.2
		_set_flash(1.0)


func _set_flash(f: float) -> void:
	var c := Color(1.0 + 1.6 * f, 1.0 + 1.4 * f, 1.0 + 0.8 * f)
	for s in part_sprites:
		if is_instance_valid(s):
			(s as Sprite2D).self_modulate = c


func _process(delta: float) -> void:
	if main == null or main.state != "playing":
		return
	wob += delta
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0:
			_set_flash(0.0)
	if touch_cd > 0.0:
		touch_cd -= delta
	# Dying: the collapse animation plays out, then the kill resolves.
	if dying:
		die_t -= delta
		if die_t <= 0.0:
			main.on_enemy_killed(self)
			queue_free()
		return
	var to_p: Vector2 = main.player.global_position - global_position
	var dist: float = to_p.length()
	# Face the player (rigged kinds only — typo glyphs stay upright).
	# Figures are drawn head-up (-y), so rotate head toward the player.
	if kind != "typo" and dist > 1.0:
		face = lerp_angle(face, to_p.angle() + PI * 0.5, minf(1.0, 8.0 * delta))
		rotation = face
	# Boss slam state machine (drives its own animations).
	if is_boss:
		_boss_slam(delta, dist)
	elif lunge_cd > 0.0:
		lunge_cd -= delta
	# Skeletal animation state: slam > hit > lunge > move.
	if anim != null:
		if windup_t > 0.0 or slam_t > 0.0:
			pass  # slam anims are driven by _boss_slam
		elif hit_t > 0.0:
			hit_t -= delta
		elif lunge_t > 0.0:
			lunge_t -= delta
			if lunge_t <= 0.0:
				anim.play("move")
		elif anim.current_animation != "move":
			anim.play("move")
		if not is_boss and lunge_t <= 0.0 and hit_t <= 0.0 and lunge_cd <= 0.0 \
				and dist < radius + 60.0 and dist > 1.0:
			anim.play("lunge")
			lunge_t = 0.35
			lunge_cd = 2.0 + randf() * 1.5
	# Chase with a slight sideways wobble so hordes don't perfectly stack.
	if dist > 1.0:
		var dir: Vector2 = to_p / dist
		var side := Vector2(-dir.y, dir.x)
		var w: float = sin(wob * 2.2 + wob_seed) * 0.35
		position += (dir + side * w).normalized() * spd * delta
	# Contact damage.
	if dist < radius + 20.0 and touch_cd <= 0.0:
		touch_cd = 1.0
		main.player.take_damage(dmg)
	# Typo glyphs and elite rings are still code-drawn.
	if kind == "typo" or elite:
		queue_redraw()


func _boss_slam(delta: float, dist: float) -> void:
	if slam_cd > 0.0:
		slam_cd -= delta
	if windup_t > 0.0:
		windup_t -= delta
		if windup_t <= 0.0:
			if anim != null:
				anim.play("slam")
			slam_t = 0.3
			main.ring_fx(global_position, 190.0)
			main.sfx.play("nova")
			if dist < 165.0:
				main.player.take_damage(38.0)
		return
	if slam_t > 0.0:
		slam_t -= delta
		if slam_t <= 0.0 and anim != null:
			anim.play("move")
		return
	if slam_cd <= 0.0 and dist < 190.0 and anim != null:
		anim.play("slam_windup")
		windup_t = 0.7
		slam_cd = 4.5


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
