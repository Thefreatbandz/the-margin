extends Control
## Fixed bottom-left touch joystick. Handles touch AND mouse (mouse lets us
## QA on desktop). Drawn in-game: gold ring + knob on the black page.

const RADIUS := 95.0
const KNOB_R := 38.0

var main = null
var active := false

var _touch_id := -1
var _mouse_down := false
var _knob := Vector2.ZERO  # offset from base, unclamped pixels
var _has_input := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func set_active(a: bool) -> void:
	active = a
	visible = a
	_reset()


func _reset() -> void:
	_touch_id = -1
	_mouse_down = false
	_has_input = false
	_knob = Vector2.ZERO
	queue_redraw()


func _base_pos() -> Vector2:
	var vs: Vector2 = get_viewport_rect().size
	return Vector2(125.0, vs.y - 165.0)


func get_vector() -> Vector2:
	if not active or not _has_input:
		return Vector2.ZERO
	var v: Vector2 = _knob / RADIUS
	if v.length_squared() > 1.0:
		v = v.normalized()
	return v


func _input(event: InputEvent) -> void:
	if not active or main == null or main.state != "playing":
		return
	var vs: Vector2 = get_viewport_rect().size
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _touch_id == -1 and st.position.x < vs.x * 0.62:
			_touch_id = st.index
			_has_input = true
			_knob = st.position - _base_pos()
			_clamp_knob()
			queue_redraw()
		elif not st.pressed and st.index == _touch_id:
			_reset()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_id:
			_knob = sd.position - _base_pos()
			_clamp_knob()
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _mouse_down and not _has_input and mb.position.x < vs.x * 0.62:
				_mouse_down = true
				_has_input = true
				_knob = mb.position - _base_pos()
				_clamp_knob()
				queue_redraw()
			elif not mb.pressed and _mouse_down:
				_reset()
	elif event is InputEventMouseMotion:
		if _mouse_down:
			_knob = (event as InputEventMouseMotion).position - _base_pos()
			_clamp_knob()
			queue_redraw()


func _clamp_knob() -> void:
	if _knob.length() > RADIUS:
		_knob = _knob.normalized() * RADIUS


func _draw() -> void:
	if not active:
		return
	var base := _base_pos()
	# Base pad.
	draw_circle(base, RADIUS, Color(0.08, 0.08, 0.10, 0.45))
	draw_arc(base, RADIUS, 0.0, TAU, 48, Color(0.91, 0.78, 0.42, 0.55), 3.0)
	# Knob.
	var kp: Vector2 = base + _knob
	draw_circle(kp, KNOB_R, Color(0.91, 0.78, 0.42, 0.30))
	draw_arc(kp, KNOB_R, 0.0, TAU, 32, Color(0.91, 0.78, 0.42, 0.9), 3.0)
	draw_circle(kp, 8.0, Color(1.0, 0.96, 0.80, 0.9))
