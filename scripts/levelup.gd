extends CanvasLayer
## Level-up overlay: pauses the game, offers 3 upgrade cards.
## process_mode is ALWAYS so cards stay clickable while paused.

const GOLD := Color(0.91, 0.78, 0.42)
const GOLD_DIM := Color(0.55, 0.45, 0.25)
const PAPER := Color(0.85, 0.82, 0.72)

var main = null
var current_ids: Array = []

var _root: Control
var _cards: HBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	_root.add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(cc)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	cc.add_child(vbox)

	var title := Label.new()
	title.text = "THE PAGE TURNS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "choose an ink"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", GOLD_DIM)
	vbox.add_child(sub)

	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 20)
	vbox.add_child(_cards)


func show_cards(upgrades: Array) -> void:
	current_ids.clear()
	for c in _cards.get_children():
		c.queue_free()
	for u in upgrades:
		current_ids.append(u["id"])
		_cards.add_child(_make_card(u))
	visible = true


func hide_cards() -> void:
	visible = false


func _make_card(u: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(205, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.08, 0.97)
	sb.border_color = GOLD_DIM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	var name_l := Label.new()
	name_l.text = String(u["name"])
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.add_theme_font_size_override("font_size", 27)
	name_l.add_theme_color_override("font_color", GOLD)
	vb.add_child(name_l)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = GOLD_DIM
	vb.add_child(rule)

	var desc_l := Label.new()
	desc_l.text = String(u["desc"])
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_l.add_theme_font_size_override("font_size", 21)
	desc_l.add_theme_color_override("font_color", PAPER)
	desc_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_l)

	var stacks: int = int(main.stacks.get(u["id"], 0))
	var owned := Label.new()
	owned.text = "owned %d" % stacks if stacks > 0 else "new ink"
	owned.add_theme_font_size_override("font_size", 18)
	owned.add_theme_color_override("font_color", GOLD_DIM)
	vb.add_child(owned)

	var uid: String = String(u["id"])
	panel.gui_input.connect(_on_card_input.bind(uid))
	return panel


func _on_card_input(event: InputEvent, uid: String) -> void:
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		tapped = (event as InputEventScreenTouch).pressed
	if tapped and main != null:
		main.choose_upgrade(uid)
