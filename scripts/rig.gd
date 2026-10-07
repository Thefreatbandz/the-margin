class_name Rig
extends RefCounted
## Paper-doll skeletal rigs for THE MARGIN v3.
## Builds Skeleton2D + Bone2D hierarchies with rigid Sprite2D parts parented
## to bones (no vertex skinning — cheap enough for 150 enemies), plus an
## AnimationPlayer with eased keyframes per character.
##
## Structure per rig:
##   root (Node2D, game-scaled)
##     Fx (Node2D — hit/die scale punches; rest = identity)
##       Skel (Skeleton2D, positioned at -origin so the figure centers on root)
##         Hips (Bone2D) -> Torso/Body ... limbs
##       AimPivot (Node2D, scribe only — rotation driven by live aim)
##         ArmSpr (Sprite2D)
##       Anim (AnimationPlayer)
##
## Returns: {"root":, "anim":, "bones": {name: Bone2D}, "sprites": [Sprite2D],
##           "aim": AimPivot or null}

const CUBIC := Tween.TRANS_CUBIC
const QUINT := Tween.TRANS_QUINT
const BACK := Tween.TRANS_BACK
const SINE := Tween.TRANS_SINE


static func _bone(parent: Node, bname: String, at_fig: Vector2,
		parent_fig: Vector2) -> Bone2D:
	# at_fig / parent_fig are in FIGURE coordinates (composite-canvas space).
	# Bone2D.position is relative to the parent bone, so subtract.
	var b := Bone2D.new()
	b.name = bname
	b.position = at_fig - parent_fig
	parent.add_child(b)
	return b


static func _spr(parent: Node, tex: Texture2D, at: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	parent.add_child(s)
	return s


static func _new_anim() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	return a


static func _trk(a: Animation, path: String, prop: String, keys: Array,
		trans: int = CUBIC) -> void:
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath(path + ":" + prop))
	for k in keys:
		var ki := a.track_insert_key(ti, float(k[0]), k[1])
		a.track_set_key_transition(ti, ki, trans)


static func _fin(ap: AnimationPlayer, a: Animation, aname: String,
		length: float, loop: bool) -> void:
	a.length = length
	if loop:
		a.loop_mode = Animation.LOOP_LINEAR
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	lib.add_animation(aname, a)


static func _base(tex: Dictionary) -> Dictionary:
	var root := Node2D.new()
	root.name = "Rig"
	var fx := Node2D.new()
	fx.name = "Fx"
	root.add_child(fx)
	var skel := Skeleton2D.new()
	skel.name = "Skel"
	fx.add_child(skel)
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	fx.add_child(ap)
	return {"root": root, "fx": fx, "skel": skel, "anim": ap,
		"bones": {}, "sprites": [], "aim": null}


static func _blends(ap: AnimationPlayer, pairs: Array, t: float) -> void:
	for p in pairs:
		ap.set_blend_time(p[0], p[1], t)


# ---------------------------------------------------------------- scribe ---
static func scribe(tex: Dictionary) -> Dictionary:
	var r := _base(tex)
	var skel: Skeleton2D = r["skel"]
	var ap: AnimationPlayer = r["anim"]
	var bones: Dictionary = r["bones"]
	var sprites: Array = r["sprites"]
	skel.position = Vector2(-400, -520)

	var hips := _bone(skel, "Hips", Vector2(400, 800), Vector2.ZERO)
	var torso := _bone(hips, "Torso", Vector2(400, 620), Vector2(400, 800))
	var head := _bone(torso, "Head", Vector2(400, 450), Vector2(400, 620))
	var arm_l := _bone(torso, "ArmL", Vector2(264, 590), Vector2(400, 620))
	var panel_l := _bone(hips, "PanelL", Vector2(397, 710), Vector2(400, 800))
	var panel_r := _bone(hips, "PanelR", Vector2(593, 710), Vector2(400, 800))
	bones["Hips"] = hips
	bones["Torso"] = torso
	bones["Head"] = head
	bones["ArmL"] = arm_l
	bones["PanelL"] = panel_l
	bones["PanelR"] = panel_r
	sprites.append(_spr(torso, tex["scribe_torso"], Vector2(0, -64)))
	sprites.append(_spr(head, tex["scribe_hood"], Vector2(0, -164)))
	sprites.append(_spr(arm_l, tex["scribe_arm_l"], Vector2(-0.5, 201.5)))
	sprites.append(_spr(panel_l, tex["scribe_panel_l"], Vector2(0.5, 227.5)))
	sprites.append(_spr(panel_r, tex["scribe_panel_r"], Vector2(0, 235.5)))

	# Quill arm on an aim-driven pivot (rotation set from live aim each frame;
	# animations only punch its position, never its rotation).
	var fx: Node2D = r["fx"]
	var aim := Node2D.new()
	aim.name = "AimPivot"
	aim.position = Vector2(136, 70)
	fx.add_child(aim)
	var arm_spr := _spr(aim, tex["scribe_arm_r"], Vector2(182, -50))
	arm_spr.name = "ArmSpr"
	sprites.append(arm_spr)
	r["aim"] = aim

	var B := "Fx/Skel/"
	# idle — slow breathing, cloth sway (2.4s loop)
	var idle := _new_anim()
	_trk(idle, B + "Hips", "position", [[0, Vector2(400, 800)], [0.6, Vector2(400, 806)], [1.2, Vector2(400, 800)], [1.8, Vector2(400, 794)], [2.4, Vector2(400, 800)]])
	_trk(idle, B + "Hips/Torso", "rotation", [[0, 0.0], [0.6, 0.035], [1.2, 0.0], [1.8, -0.035], [2.4, 0.0]])
	_trk(idle, B + "Hips/Torso/Head", "rotation", [[0, 0.0], [0.6, -0.05], [1.2, 0.0], [1.8, 0.05], [2.4, 0.0]])
	_trk(idle, B + "Hips/Torso/ArmL", "rotation", [[0, 0.0], [0.6, 0.12], [1.2, 0.0], [1.8, -0.12], [2.4, 0.0]])
	_trk(idle, B + "Hips/PanelL", "rotation", [[0, 0.0], [0.6, 0.14], [1.2, 0.0], [1.8, -0.14], [2.4, 0.0]])
	_trk(idle, B + "Hips/PanelR", "rotation", [[0, 0.0], [0.6, -0.14], [1.2, 0.0], [1.8, 0.14], [2.4, 0.0]])
	_trk(idle, "Fx/AimPivot/ArmSpr", "position", [[0, Vector2(182, -50)], [1.2, Vector2(182, -44)], [2.4, Vector2(182, -50)]])
	_fin(ap, idle, "idle", 2.4, true)

	# walk — bob, limb swing, robe flow (0.7s loop)
	var walk := _new_anim()
	_trk(walk, B + "Hips", "position", [[0, Vector2(400, 800)], [0.175, Vector2(400, 790)], [0.35, Vector2(400, 800)], [0.525, Vector2(400, 790)], [0.7, Vector2(400, 800)]])
	_trk(walk, B + "Hips", "rotation", [[0, 0.0], [0.175, 0.04], [0.35, 0.0], [0.525, -0.04], [0.7, 0.0]])
	_trk(walk, B + "Hips/Torso", "rotation", [[0, 0.0], [0.175, 0.06], [0.35, 0.0], [0.525, -0.06], [0.7, 0.0]])
	_trk(walk, B + "Hips/Torso/Head", "rotation", [[0, 0.0], [0.175, -0.06], [0.35, 0.0], [0.525, 0.06], [0.7, 0.0]])
	_trk(walk, B + "Hips/Torso/ArmL", "rotation", [[0, 0.0], [0.175, 0.4], [0.35, 0.0], [0.525, -0.4], [0.7, 0.0]])
	_trk(walk, B + "Hips/PanelL", "rotation", [[0, 0.0], [0.175, 0.25], [0.35, 0.0], [0.525, -0.25], [0.7, 0.0]])
	_trk(walk, B + "Hips/PanelR", "rotation", [[0, 0.0], [0.175, -0.25], [0.35, 0.0], [0.525, 0.25], [0.7, 0.0]])
	_trk(walk, "Fx/AimPivot/ArmSpr", "position", [[0, Vector2(182, -50)], [0.35, Vector2(182, -58)], [0.7, Vector2(182, -50)]])
	_fin(ap, walk, "walk", 0.7, true)

	# attack — quill jab along the aim (0.3s once; rotation stays aim-driven)
	var atk := _new_anim()
	_trk(atk, "Fx/AimPivot/ArmSpr", "position", [[0, Vector2(182, -50)], [0.09, Vector2(232, -50)], [0.3, Vector2(182, -50)]], QUINT)
	_trk(atk, B + "Hips/Torso", "rotation", [[0, 0.0], [0.09, 0.05], [0.3, 0.0]], QUINT)
	_fin(ap, atk, "attack", 0.3, false)

	# hit — scale punch (0.22s once; white flash handled in code)
	var hit := _new_anim()
	_trk(hit, "Fx", "scale", [[0, Vector2.ONE], [0.07, Vector2(1.08, 1.08)], [0.22, Vector2.ONE]], QUINT)
	_fin(ap, hit, "hit", 0.22, false)

	# die — crumple and fade (0.55s once)
	var die := _new_anim()
	_trk(die, "Fx", "rotation", [[0, 0.0], [0.55, 1.35]])
	_trk(die, "Fx", "position", [[0, Vector2.ZERO], [0.55, Vector2(0, 60)]])
	_trk(die, "Fx", "modulate:a", [[0, 1.0], [0.35, 1.0], [0.55, 0.0]])
	_fin(ap, die, "die", 0.55, false)

	_blends(ap, [["idle", "walk"], ["walk", "idle"], ["idle", "attack"], ["walk", "attack"],
		["attack", "idle"], ["attack", "walk"], ["idle", "hit"], ["walk", "hit"],
		["hit", "idle"], ["hit", "walk"]], 0.1)
	return r


# ---------------------------------------------------------------- enemies --
# kind: "blot" | "scribble" | "shard" | "redactor". "typo" has no rig.
static func enemy(kind: String, tex: Dictionary) -> Dictionary:
	var r := _base(tex)
	var skel: Skeleton2D = r["skel"]
	var ap: AnimationPlayer = r["anim"]
	var bones: Dictionary = r["bones"]
	var sprites: Array = r["sprites"]
	var B := "Fx/Skel/"
	var hips: Bone2D
	var move_len := 1.1

	match kind:
		"blot":
			skel.position = Vector2(-350, -350)
			hips = _bone(skel, "Hips", Vector2(350, 350), Vector2.ZERO)
			var body := _bone(hips, "Body", Vector2(350, 292), Vector2(350, 350))
			var tl := _bone(body, "TendrilL", Vector2(151, 200), Vector2(350, 292))
			var tr := _bone(body, "TendrilR", Vector2(548, 200), Vector2(350, 292))
			bones["Hips"] = hips
			bones["Body"] = body
			bones["TendrilL"] = tl
			bones["TendrilR"] = tr
			sprites.append(_spr(body, tex["blot_body"], Vector2(0, 0)))
			sprites.append(_spr(tl, tex["blot_tendril_l"], Vector2(0.5, 232)))
			sprites.append(_spr(tr, tex["blot_tendril_r"], Vector2(0.5, 232)))
			var mv := _new_anim()
			_trk(mv, B + "Hips", "position", [[0, Vector2(350, 350)], [0.275, Vector2(350, 342)], [0.55, Vector2(350, 350)], [0.825, Vector2(350, 358)], [1.1, Vector2(350, 350)]])
			_trk(mv, B + "Hips/Body", "scale", [[0, Vector2.ONE], [0.275, Vector2(1.07, 0.93)], [0.55, Vector2.ONE], [0.825, Vector2(0.95, 1.05)], [1.1, Vector2.ONE]])
			_trk(mv, B + "Hips/Body/TendrilL", "rotation", [[0, 0.0], [0.275, 0.28], [0.55, 0.0], [0.825, -0.28], [1.1, 0.0]])
			_trk(mv, B + "Hips/Body/TendrilR", "rotation", [[0, 0.0], [0.275, -0.28], [0.55, 0.0], [0.825, 0.28], [1.1, 0.0]])
			_fin(ap, mv, "move", move_len, true)
		"scribble":
			skel.position = Vector2(-350, -340)
			hips = _bone(skel, "Hips", Vector2(350, 340), Vector2.ZERO)
			var body2 := _bone(hips, "Body", Vector2(350, 284), Vector2(350, 340))
			var ll := _bone(body2, "LegsL", Vector2(255, 205), Vector2(350, 284))
			var lr := _bone(body2, "LegsR", Vector2(445, 205), Vector2(350, 284))
			bones["Hips"] = hips
			bones["Body"] = body2
			bones["LegsL"] = ll
			bones["LegsR"] = lr
			sprites.append(_spr(body2, tex["scribble_body"], Vector2(0, 0)))
			sprites.append(_spr(ll, tex["scribble_legs_l"], Vector2(0.5, 226)))
			sprites.append(_spr(lr, tex["scribble_legs_r"], Vector2(0.5, 226)))
			var mv2 := _new_anim()
			_trk(mv2, B + "Hips", "position", [[0, Vector2(350, 340)], [0.275, Vector2(350, 332)], [0.55, Vector2(350, 340)], [0.825, Vector2(350, 348)], [1.1, Vector2(350, 340)]])
			_trk(mv2, B + "Hips/Body", "rotation", [[0, 0.0], [0.275, 0.06], [0.55, 0.0], [0.825, -0.06], [1.1, 0.0]])
			_trk(mv2, B + "Hips/Body/LegsL", "rotation", [[0, -0.18], [0.275, 0.14], [0.55, -0.18], [0.825, -0.5], [1.1, -0.18]])
			_trk(mv2, B + "Hips/Body/LegsR", "rotation", [[0, 0.18], [0.275, -0.14], [0.55, 0.18], [0.825, 0.5], [1.1, 0.18]])
			_fin(ap, mv2, "move", move_len, true)
		"shard":
			skel.position = Vector2(-350, -450)
			hips = _bone(skel, "Hips", Vector2(350, 450), Vector2.ZERO)
			var body3 := _bone(hips, "Body", Vector2(349.5, 435), Vector2(350, 450))
			var wing := _bone(body3, "Wing", Vector2(410, 300), Vector2(349.5, 435))
			bones["Hips"] = hips
			bones["Body"] = body3
			bones["Wing"] = wing
			sprites.append(_spr(body3, tex["shard_body"], Vector2(0, 0)))
			sprites.append(_spr(wing, tex["shard_wing"], Vector2(101, -28.5)))
			var mv3 := _new_anim()
			_trk(mv3, B + "Hips", "position", [[0, Vector2(350, 450)], [0.275, Vector2(350, 442)], [0.55, Vector2(350, 450)], [0.825, Vector2(350, 458)], [1.1, Vector2(350, 450)]])
			_trk(mv3, B + "Hips/Body", "rotation", [[0, 0.0], [0.275, 0.07], [0.55, 0.0], [0.825, -0.07], [1.1, 0.0]])
			_trk(mv3, B + "Hips/Body/Wing", "rotation", [[0, 0.0], [0.275, 0.2], [0.55, 0.0], [0.825, -0.2], [1.1, 0.0]])
			_fin(ap, mv3, "move", move_len, true)
		"redactor":
			skel.position = Vector2(-400, -620)
			hips = _bone(skel, "Hips", Vector2(400, 700), Vector2.ZERO)
			var torso := _bone(hips, "Torso", Vector2(400, 528), Vector2(400, 700))
			var head := _bone(torso, "Head", Vector2(400, 350), Vector2(400, 528))
			var al := _bone(torso, "ArmL", Vector2(157, 345), Vector2(400, 528))
			var ar := _bone(torso, "ArmR", Vector2(642, 345), Vector2(400, 528))
			bones["Hips"] = hips
			bones["Torso"] = torso
			bones["Head"] = head
			bones["ArmL"] = al
			bones["ArmR"] = ar
			sprites.append(_spr(torso, tex["redactor_torso"], Vector2(0, 0)))
			sprites.append(_spr(head, tex["redactor_head"], Vector2(-0.5, -57)))
			sprites.append(_spr(al, tex["redactor_arm_l"], Vector2(0.5, 234.5)))
			sprites.append(_spr(ar, tex["redactor_arm_r"], Vector2(0.5, 234.5)))
			move_len = 2.2
			var mv4 := _new_anim()
			_trk(mv4, B + "Hips", "position", [[0, Vector2(400, 700)], [0.55, Vector2(400, 694)], [1.1, Vector2(400, 700)], [1.65, Vector2(400, 706)], [2.2, Vector2(400, 700)]], SINE)
			_trk(mv4, B + "Hips/Torso", "rotation", [[0, 0.0], [0.55, 0.035], [1.1, 0.0], [1.65, -0.035], [2.2, 0.0]], SINE)
			_trk(mv4, B + "Hips/Torso/Head", "rotation", [[0, 0.0], [0.55, -0.05], [1.1, 0.0], [1.65, 0.05], [2.2, 0.0]], SINE)
			_trk(mv4, B + "Hips/Torso/ArmL", "rotation", [[0, 0.0], [0.55, 0.1], [1.1, 0.0], [1.65, -0.1], [2.2, 0.0]], SINE)
			_trk(mv4, B + "Hips/Torso/ArmR", "rotation", [[0, 0.0], [0.55, -0.1], [1.1, 0.0], [1.65, 0.1], [2.2, 0.0]], SINE)
			_fin(ap, mv4, "move", move_len, true)
			# slam_windup — arms rise, torso leans back, head shakes (0.7s)
			var wu := _new_anim()
			_trk(wu, B + "Hips/Torso/ArmL", "rotation", [[0, 0.0], [0.7, -2.2]])
			_trk(wu, B + "Hips/Torso/ArmR", "rotation", [[0, 0.0], [0.7, 2.2]])
			_trk(wu, B + "Hips/Torso", "rotation", [[0, 0.0], [0.7, -0.12]])
			_trk(wu, B + "Hips/Torso/Head", "rotation", [[0, 0.0], [0.15, 0.12], [0.3, -0.12], [0.45, 0.12], [0.6, -0.12], [0.7, 0.0]])
			_fin(ap, wu, "slam_windup", 0.7, false)
			# slam — arms smash down with overshoot (0.3s)
			var sl := _new_anim()
			_trk(sl, B + "Hips/Torso/ArmL", "rotation", [[0, -2.2], [0.3, 0.55]], BACK)
			_trk(sl, B + "Hips/Torso/ArmR", "rotation", [[0, 2.2], [0.3, -0.55]], BACK)
			_trk(sl, B + "Hips/Torso", "position", [[0, Vector2(0, -172)], [0.12, Vector2(0, -108)], [0.3, Vector2(0, -172)]], QUINT)
			_trk(sl, "Fx", "scale", [[0, Vector2.ONE], [0.12, Vector2(1.14, 0.84)], [0.3, Vector2.ONE]], QUINT)
			_fin(ap, sl, "slam", 0.3, false)

	# shared one-shots: lunge / hit / die
	var lunge := _new_anim()
	_trk(lunge, "Fx", "scale", [[0, Vector2.ONE], [0.12, Vector2(1.22, 0.82)], [0.35, Vector2.ONE]], QUINT)
	# Lunge along local -y (the figure's head/forward, rotated toward the player).
	_trk(lunge, "Fx", "position", [[0, Vector2.ZERO], [0.12, Vector2(0, -38)], [0.35, Vector2.ZERO]], QUINT)
	_fin(ap, lunge, "lunge", 0.35, false)

	var hit := _new_anim()
	_trk(hit, "Fx", "scale", [[0, Vector2.ONE], [0.07, Vector2(0.88, 0.88)], [0.2, Vector2.ONE]], QUINT)
	_fin(ap, hit, "hit", 0.2, false)

	var die := _new_anim()
	_trk(die, "Fx", "scale", [[0, Vector2.ONE], [0.12, Vector2(1.18, 1.18)], [0.45, Vector2(0.02, 0.02)]], QUINT)
	_trk(die, "Fx", "modulate:a", [[0, 1.0], [0.25, 1.0], [0.45, 0.0]])
	_fin(ap, die, "die", 0.45, false)

	_blends(ap, [["move", "hit"], ["hit", "move"], ["move", "lunge"], ["lunge", "move"],
		["move", "slam_windup"], ["slam_windup", "slam"], ["slam", "move"]], 0.08)
	return r
