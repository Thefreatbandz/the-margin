extends SceneTree
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.start_game()
	await process_frame
	# Spawn a redactor directly left of the player: player should be EAST of boss.
	var e = load("res://scripts/enemy.gd").new()
	main.world.add_child(e)
	e.setup("redactor", {"hp": 2400.0, "spd": 52.0, "dmg": 32.0, "xp": 150, "r": 58.0},
		false, main.player.global_position + Vector2(-300, 0), main)
	main.enemies.append(e)
	for i in 120:
		await process_frame
	# Player is EAST of boss -> to_p.angle() = 0 -> face target = PI/2.
	# Head (local -y) should point EAST: head world offset should be +x.
	var head: Bone2D = e.rig.get_node("Fx/Skel/Hips/Torso/Head")
	var hips: Bone2D = e.rig.get_node("Fx/Skel/Hips")
	var d: Vector2 = head.global_position - hips.global_position
	print("enemy rotation deg=", rad_to_deg(e.rotation), " head->hips dir=", d.normalized(), " (expect ~(1,0))")
	quit()
