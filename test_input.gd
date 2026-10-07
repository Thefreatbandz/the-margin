extends SceneTree
## Headless input-path test: verifies real input events (keyboard hold +
## touch drag) move the Scribe through the ACTUAL joystick/player code.
## Run: xvfb-run -a Godot --headless --path . --script test_input.gd
## (delete after use; not part of the shipped game)

var failures := []


func _init() -> void:
	call_deferred("_run")


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("PASS: ", name)
	else:
		failures.append(name)
		print("FAIL: ", name, " ", detail)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_game()
	await process_frame
	var player = main.player
	var joy = main.joystick

	# 1. Keyboard hold: 'D' for 60 frames should move the player +x.
	var p0: Vector2 = player.position
	_key(KEY_D, true)
	for i in 60:
		await process_frame
	_key(KEY_D, false)
	var p1: Vector2 = player.position
	check("keyboard hold D moves player +x", p1.x > p0.x + 50.0,
		"moved %.1f px" % (p1.x - p0.x))
	check("keyboard no vertical drift", absf(p1.y - p0.y) < 120.0,
		"dy=%.1f" % (p1.y - p0.y))

	# 2. Touch press on the joystick (left side) grabs it.
	# NOTE: headless test env artifact — root viewport is 64x64 while the
	# Control sees 1280x1280, so dispatched event coords get scaled by
	# view_rect/root_size on the way in. Pre-divide to compensate (real
	# devices don't have this mismatch).
	var iscale: float = joy.get_viewport_rect().size.x / float(root.size.x)
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.pressed = true
	t.position = Vector2(125, 1115) / iscale
	Input.parse_input_event(t)
	await process_frame
	var v: Vector2 = joy.get_vector()
	check("touch press engages joystick", joy._touch_id == 0,
		"touch_id=%d" % joy._touch_id)

	# 3. Touch drag up-right steers the player up-right.
	var p2: Vector2 = player.position
	for i in 30:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(125 + i * 3, 1115 - i * 3) / iscale
		d.relative = Vector2(3, -3)
		Input.parse_input_event(d)
		await process_frame
	var p3: Vector2 = player.position
	check("touch drag moves player", (p3 - p2).length() > 20.0,
		"moved %.1f px" % (p3 - p2).length())
	check("touch drag direction up-right", p3.x > p2.x and p3.y < p2.y,
		"delta=%s" % str(p3 - p2))

	# 4. Touch release resets the joystick.
	var tr := InputEventScreenTouch.new()
	tr.index = 0
	tr.pressed = false
	Input.parse_input_event(tr)
	await process_frame
	check("touch release zeroes joystick", joy.get_vector() == Vector2.ZERO,
		"vec=%s" % str(joy.get_vector()))

	if failures.is_empty():
		print("ALL INPUT TESTS PASSED")
	else:
		print("FAILURES: ", failures)
	quit(1 if not failures.is_empty() else 0)
