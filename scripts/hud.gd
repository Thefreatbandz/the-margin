extends CanvasLayer
## In-game HUD: HP bar, XP bar, level, timer, kills, boss bar, mute toggle.
## Gold-on-black, built in code.

const GOLD := Color(0.91, 0.78, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.25)
const HP_COL := Color(0.85, 0.30, 0.22)

var main = null

var level_label: Label
var time_label: Label
var kills_label: Label
var hp_bar: ProgressBar
var xp_bar: ProgressBar
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var mute_btn: Button


func _bar(bg_col: Color, fill_col: Color, w: float, h: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 100.0
	b.value = 100.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(w, h)
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_col
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_col
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Left column: level / time / kills.
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(16, 12)
	left.add_theme_constant_override("separation", 2)
	root.add_child(left)
	level_label = _label("LV 1", 30, GOLD)
	time_label = _label("00:00", 26, Color(0.85, 0.82, 0.72))
	kills_label = _label("KILLS 0", 22, GOLD_DIM)
	left.add_child(level_label)
	left.add_child(time_label)
	left.add_child(kills_label)

	# Center column: HP bar, XP bar, boss bar.
	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.offset_left = -200.0
	center.offset_right = 200.0
	center.offset_top = 12.0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 6)
	root.add_child(center)
	hp_bar = _bar(Color(0.10, 0.08, 0.08, 0.85), HP_COL, 400, 20)
	xp_bar = _bar(Color(0.08, 0.08, 0.10, 0.85), GOLD, 400, 10)
	center.add_child(hp_bar)
	center.add_child(xp_bar)

	boss_box = VBoxContainer.new()
	boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_box.add_theme_constant_override("separation", 4)
	var boss_label := _label("THE REDACTOR", 24, Color(1.0, 0.35, 0.25))
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_label)
	boss_bar = _bar(Color(0.10, 0.06, 0.06, 0.9), Color(0.85, 0.25, 0.2), 440, 16)
	boss_box.add_child(boss_bar)
	boss_box.visible = false
	center.add_child(boss_box)

	# Mute toggle, top-right.
	mute_btn = Button.new()
	mute_btn.text = "SOUND ON"
	mute_btn.anchor_left = 1.0
	mute_btn.anchor_right = 1.0
	mute_btn.offset_left = -168.0
	mute_btn.offset_right = -16.0
	mute_btn.offset_top = 12.0
	mute_btn.offset_bottom = 56.0
	mute_btn.add_theme_font_size_override("font_size", 20)
	mute_btn.add_theme_color_override("font_color", GOLD)
	var mbs := StyleBoxFlat.new()
	mbs.bg_color = Color(0.08, 0.08, 0.10, 0.85)
	mbs.border_color = GOLD_DIM
	mbs.set_border_width_all(2)
	mbs.set_corner_radius_all(6)
	mute_btn.add_theme_stylebox_override("normal", mbs)
	mute_btn.add_theme_stylebox_override("hover", mbs)
	mute_btn.add_theme_stylebox_override("pressed", mbs)
	mute_btn.pressed.connect(_on_mute_pressed)
	root.add_child(mute_btn)


func _on_mute_pressed() -> void:
	if main == null:
		return
	main.toggle_mute()


func set_mute_label(muted: bool) -> void:
	mute_btn.text = "SOUND OFF" if muted else "SOUND ON"


func show_boss() -> void:
	boss_box.visible = true


func hide_boss() -> void:
	boss_box.visible = false


func set_boss_hp(hp: float, max_hp: float) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = maxf(0.0, hp)


func update_hud(hp: float, max_hp: float, xp: int, xp_next: int, level: int, run_time: float, kills: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = maxf(0.0, hp)
	xp_bar.max_value = float(xp_next)
	xp_bar.value = float(xp)
	level_label.text = "LV %d" % level
	var t := int(run_time)
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	kills_label.text = "KILLS %d" % kills
