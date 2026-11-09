# The waiver / GOD letter (paper) and its reading
# (Part of the Buckshot Roulette VR mod. Chain position 35: this file extends 34_pointer.gd; see src/README.md.)
extends "34_pointer.gd"

const PP_GRAB_M := 0.12                            # a hand this close (real metres) to a paper letter takes it with a grip squeeze (iteration 32)

const PP_MIN_M := 0.22                             # a paper letter in the hand is at least this long (real metres)...

const PP_MAX_M := 0.32                             # ...and at most this long

const PP_READ_M := 0.38                            # the waiver this close to your eyes counts as read...

const PP_READ_S := 0.5                             # ...after this long

const PP_AUTO_S := 5.0                             # a waiver held this long counts as read anyway

const PP_GOD_AFTER_MS := 900                       # the game's god form has been up this long: it floats to you instead

const PP_CAP_S := 20.0                             # a floating god form nobody takes goes away after this long

var pp_kind := ""                  # a paper letter in play: "waiver" (name machine) or "god"

var pp_root: Node3D = null         # its copy that floats or sits in your hand

var pp_src: Node3D = null          # the game's own paper (see-through meanwhile)

var pp_hand: Hand = null

var pp_hid: Dictionary = {}

var pp_f := Vector3(0.0, 0.0, 1.0) # in the copy's own frame: the front of the sheet...

var pp_u := Vector3(0.0, 1.0, 0.0) # ...and its up

var pp_c := Vector3.ZERO           # its middle

var pp_size := Vector3.ONE

var pp_k := 1.0

var pp_pose := Transform3D.IDENTITY

var pp_t := 0.0

var pp_held_t := 0.0

var pp_read := 0.0

var pp_fired := false

var pp_down := {}

var pp_slow := false

var pp_seen_ms := -1

var pp_wv_wait := 0.0

var pp_fb := false

var pp_god_done := false

var pp_scene: Node = null

var pp_rel_b := Basis.IDENTITY     # (iteration 34) the paper's place in the hand (rigid)

var pp_rel_o := Vector3.ZERO

var pp_goal_o := Vector3.ZERO

var pp_rel_t := 0.0

var pp_auto := false               # (iteration 36) the god form flew into the hand by itself: no grip squeeze needed yet

var pp_rel_dur := 0.22

# ---- the two paper letters (iteration 32) ----------------------------------------------------------------------------------
# The name machine's waiver and the "god" form that comes up at the first item grab: each is picked up with one hand (grip
# squeeze next to it) and held. The game's own paper is hidden meanwhile (made see-through) and a copy sits in your hand.
#   waiver: bring it up to your eyes (or just hold it a few seconds): the game's own pick-up runs (the machine comes up).
#           Open the hand: the paper falls away. Open it before that: it lies back on the table.
#   god:    the game's form floats up in front of you and waits (the game's clock is nearly stopped meanwhile). Take it,
#           read it, open the hand: the game goes on and puts it away.
func _paper_local_box(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var bb: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).mesh.get_aabb()
			out = bb if first else out.merge(bb)
			first = false
	if first:
		out = AABB(Vector3(-0.1, -0.1, -0.1), Vector3(0.2, 0.2, 0.2))
	return out

# The signed unit axis (in the node's own frame) that points most along w, leaving out the axis `skip` (-1 = none).
func _paper_axis(bs: Basis, w: Vector3, skip: int) -> int:
	var bi := -1
	var bd := -1.0
	for i in 3:
		if i == skip:
			continue
		var d := absf(bs[i].normalized().dot(w))
		if d > bd:
			bd = d
			bi = i
	return bi

func _paper_xf(nw: Vector3, uw: Vector3, centre: Vector3, k: float) -> Transform3D:
	var n := nw.normalized() if nw.length() > 0.0001 else Vector3.BACK
	var u := uw - n * uw.dot(n)
	if u.length() < 0.01:
		u = n.cross(Vector3.RIGHT)
	u = u.normalized()
	var r := u.cross(n).normalized()
	var fn := Basis(r, u, n)
	var fr := pp_u.cross(pp_f)
	var fl := Basis(fr, pp_u, pp_f)
	var bs := fn * fl.transposed() * Basis.from_scale(Vector3.ONE * k)
	return Transform3D(bs, centre - bs * pp_c)

func _paper_god_node() -> MeshInstance3D:
	if cur_scene == null:
		return null
	var rf := cur_scene.find_child("release form_god", true, false)
	if rf == null:
		return null
	var g := rf.get_node_or_null("release form1_001") as MeshInstance3D
	if g == null or g.mesh == null:
		return null
	return g

func _paper_unhide(hid: Dictionary) -> void:
	for k in hid:
		if k is GeometryInstance3D and is_instance_valid(k):
			(k as GeometryInstance3D).transparency = float(hid[k])

# (iteration 36) The copy of the paper in the hand was dark whenever the room's lights did not reach it (and black from the front):
# every material of it is made light-independent and double-sided, and a small light of its own sits on it for any other kind.
func _paper_bright(root: Node3D) -> void:
	var meshes: Array = []
	_collect_meshes(root, meshes)
	for o in meshes:
		var mi: MeshInstance3D = o
		if mi.mesh == null:
			continue
		var base: Material = mi.material_override
		for i in mi.mesh.get_surface_count():
			var m: Material = base
			if m == null:
				m = mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
				d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				d.cull_mode = BaseMaterial3D.CULL_DISABLED
				d.emission_enabled = false
				mi.set_surface_override_material(i, d)
		if base is StandardMaterial3D:
			mi.material_override = null
		mi.layers = 1 | (1 << 19)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var l := OmniLight3D.new()
	l.name = "VRBootPaperLight"
	l.light_energy = 2.0
	l.omni_range = 4.0 * world_scale
	l.light_cull_mask = 1 << 19
	l.shadow_enabled = false
	root.add_child(l)

# The hand that takes the god form by itself: the free hand that is nearest to it (a hand that holds something is left alone).
func _paper_auto_hand() -> Hand:
	var c := pp_root.global_transform * pp_c
	var best: Hand = null
	var bd := INF
	for h in [right_hand, left_hand]:
		var hh: Hand = h
		if not hh.was_active or hh.holding or (gun_state != 0 and gun_hand == hh):
			continue
		var d := hh.grip.global_position.distance_to(c)
		if d < bd - 0.001:
			bd = d
			best = hh
	return best

func _paper_begin(kind: String, src: Node3D) -> bool:
	if xr_cam == null or not is_instance_valid(xr_cam) or fx_root == null:
		return false
	var root := _fx_clone_visual(src)
	if root.get_child_count() == 0:
		root.queue_free()
		return false
	var bb := _paper_local_box(root)
	var rb := root.global_transform.basis
	var cw := root.global_transform * bb.get_center()
	var head := xr_cam.global_position
	var nw := (head - cw).normalized() if kind == "god" else Vector3.UP
	var uw := Vector3.UP
	if kind != "god":
		uw = Vector3(cw.x - head.x, 0.0, cw.z - head.z)
		if uw.length() < 0.01:
			uw = -xr_cam.global_transform.basis.z
	# the thin side of the sheet is its front; its up is the other side that points most along "up"
	var ti := 0
	for i in 3:
		if bb.size[i] < bb.size[ti]:
			ti = i
	var fa := rb[ti].normalized()
	if fa.dot(nw) < 0.0:
		fa = -fa
	var ui := _paper_axis(rb, uw, ti)
	var ua := rb[ui].normalized()
	if ua.dot(uw) < 0.0:
		ua = -ua
	pp_f = rb.transposed() * fa
	pp_u = rb.transposed() * ua
	pp_c = bb.get_center()
	pp_size = bb.size
	var ws := world_scale
	var lmax := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	pp_k = clampf(lmax, PP_MIN_M * ws, PP_MAX_M * ws) / maxf(lmax, 0.0001)
	pp_root = root
	pp_src = src
	pp_kind = kind
	pp_hand = null
	pp_pose = root.global_transform
	pp_t = 0.0
	pp_held_t = 0.0
	pp_read = 0.0
	pp_fired = false
	pp_down.clear()
	pp_hid = {}
	var meshes: Array = []
	if src is MeshInstance3D:
		meshes.append(src)
	_collect_meshes(src, meshes)
	for o in meshes:
		var gi := o as GeometryInstance3D
		if gi != null:
			pp_hid[gi] = gi.transparency
			gi.transparency = 1.0
	if kind == "god" and is_equal_approx(Engine.time_scale, 1.0):
		Engine.time_scale = GUN_HOLD_TS
		pp_slow = true
	print("VRBoot: paper '", kind, "' ready to be taken: ", (bb.size * pp_k / ws).snapped(Vector3.ONE * 0.001), " m")
	_paper_bright(root)
	pp_auto = false
	if kind == "god":
		var ah := _paper_auto_hand()
		if ah != null:
			pp_auto = true
			_paper_take(ah)                                # (iteration 36) it flies into a free hand by itself
	return true

func _paper_end(why: String, fall: bool) -> void:
	if pp_slow:
		if is_equal_approx(Engine.time_scale, GUN_HOLD_TS):
			Engine.time_scale = 1.0
		pp_slow = false
	var hid := pp_hid
	pp_hid = {}
	if pp_hand != null:
		pp_hand.holding = false
	if pp_root != null and is_instance_valid(pp_root):
		if fall and xr_cam != null and is_instance_valid(xr_cam):
			var ws := world_scale
			var fy := minf(pp_root.global_position.y, xr_cam.global_position.y - 0.4 * ws) - 0.3 * ws
			_fx_fall(pp_root, Vector3(0.0, -0.2 * ws, 0.0), Vector3(0.6, 0.3, 0.5), fy, 1.4, true)
		else:
			pp_root.queue_free()
	var later := pp_fired or pp_kind == "god"
	pp_root = null
	pp_src = null
	pp_hand = null
	var kind := pp_kind
	pp_kind = ""
	if kind == "god":
		pp_god_done = true
	if later:
		get_tree().create_timer(3.5).timeout.connect(func(): _paper_unhide(hid))     # (the game puts its own paper away first)
	else:
		_paper_unhide(hid)
	print("VRBoot: paper '", kind, "' ended (", why, ")")

func _paper_take(hh: Hand) -> void:
	pp_hand = hh
	hh.holding = true
	pp_held_t = 0.0
	# (iteration 34) the sheet is fixed in the hand from now on: it faces you as it did when you took it, then it turns, moves and
	# tilts exactly with the hand (it used to turn back towards your head all the time)
	if pp_root != null and is_instance_valid(pp_root) and xr_cam != null and is_instance_valid(xr_cam):
		var ws := world_scale
		var gx := hh.grip.global_transform
		var gb := gx.basis.orthonormalized()
		var u := (gb.y * 0.5 + Vector3.UP * 0.5).normalized()
		var hgt := absf(pp_size.dot(pp_u)) * pp_k
		var c0 := gx.origin + gb * (Vector3(0.0, 0.0, -0.04) * ws) + u * (hgt * 0.38)
		var face := _paper_xf(xr_cam.global_position - c0, u, c0, pp_k)
		pp_rel_b = gb.inverse() * face.basis
		pp_rel_o = gb.inverse() * ((pp_root.global_transform * pp_c) - gx.origin)
		pp_goal_o = gb.inverse() * (c0 - gx.origin)
		pp_rel_t = 0.0
		pp_rel_dur = 0.6 if pp_auto else 0.22
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: paper '", pp_kind, "' taken with the ", hh.side, " hand")

func _paper_update(delta: float) -> void:
	if pp_scene != cur_scene:
		pp_scene = cur_scene
		pp_god_done = false
		pp_fb = false
		pp_wv_wait = 0.0
	if not _in_main_scene() or cur_scene == null or xr_cam == null:
		if pp_kind != "":
			_paper_end("left the scene", false)
		return
	if pp_kind == "":
		_paper_idle(delta)
	else:
		_paper_tick(delta)

func _paper_idle(delta: float) -> void:
	var ws := world_scale
	var now := Time.get_ticks_msec()
	# the god form: after the game's own form has come up (about a second), it floats in front of you instead
	var nodes := _item_nodes()
	var g := _paper_god_node()
	if not pp_god_done and not nodes.is_empty() and g != null and g.visible:
		var sp = (nodes[0] as Node).get("speaker_god")
		var an := g.get_parent().get_node_or_null("animator_god release form") as AnimationPlayer
		var live: bool = (sp is AudioStreamPlayer2D and (sp as AudioStreamPlayer2D).playing) or (an != null and an.is_playing())
		if live:
			if pp_seen_ms < 0:
				pp_seen_ms = now
			elif now - pp_seen_ms >= PP_GOD_AFTER_MS:
				pp_seen_ms = -1
				_paper_begin("god", g)
				return
		else:
			pp_seen_ms = -1
	else:
		pp_seen_ms = -1
	# (iteration 34) the waiver on the table is not picked up by hand any more: a fingertip on it (see FINGER_ALIASES)
	pp_wv_wait = 0.0

func _paper_tick(delta: float) -> void:
	var ws := world_scale
	var rd := delta / maxf(Engine.time_scale, 0.001) if pp_slow else delta
	pp_t += rd
	if pp_root == null or not is_instance_valid(pp_root) or pp_src == null or not is_instance_valid(pp_src):
		_paper_end("lost", false)
		return
	if pp_kind == "waiver" and nm_locked:
		_paper_end("the name is in", true)
		return
	if pp_t > PP_CAP_S and pp_hand == null:
		_paper_end("nobody took it", true)
		return
	if pp_held_t > 120.0:
		_paper_end("held too long", true)
		return
	var head := xr_cam.global_position
	var edges := {}
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		edges[hh.side] = hh.grip_sq and not bool(pp_down.get(hh.side, false))
		pp_down[hh.side] = hh.grip_sq
	var tgt := pp_pose
	if pp_hand == null:
		# floating in front of you (the god form)
		var f := -xr_cam.global_transform.basis.z
		f.y = 0.0
		f = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
		var c := head + f * (0.42 * ws) + Vector3.DOWN * (0.10 * ws)
		tgt = _paper_xf(head - c, Vector3.UP, c, pp_k)
		var bx := _node_world_aabb(pp_root, true)
		for h in [left_hand, right_hand]:
			var hh: Hand = h
			if not hh.was_active or hh.holding or bx.size.x < 0.0:
				continue
			var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
			var dd := _point_box_dist(reach, bx)
			if dd <= PP_GRAB_M * 2.5 * ws:
				poke_boxes.append(bx)
			if bool(edges[hh.side]) and dd <= PP_GRAB_M * ws and pp_t > 0.3:
				_paper_take(hh)
				break
	else:
		var hh := pp_hand
		pp_held_t += rd
		if pp_auto and hh.grip_sq:
			pp_auto = false                            # you have squeezed: from now on letting go lets it fall
		if pp_auto and pp_held_t > PP_CAP_S:
			_paper_end("nobody gripped it", true)
			return
		if not hh.was_active or (not hh.grip_sq and not pp_auto):
			if pp_kind == "waiver" and not pp_fired:
				_paper_end("put back", false)
			else:
				_paper_end("let go", true)
			return
		var gx := hh.grip.global_transform
		var gb := gx.basis.orthonormalized()
		pp_rel_t += rd
		var kk := smoothstep(0.0, 1.0, clampf(pp_rel_t / pp_rel_dur, 0.0, 1.0))
		var cw := gx.origin + gb * pp_rel_o.lerp(pp_goal_o, kk)
		var pbs := gb * pp_rel_b
		tgt = Transform3D(pbs, cw - pbs * pp_c)
		pp_pose = tgt                              # no smoothing: it is in your hand
		if pp_kind == "waiver" and not pp_fired:
			var ctr := pp_root.global_transform * pp_c
			if ctr.distance_to(head) <= PP_READ_M * ws:
				pp_read += rd
			else:
				pp_read = maxf(pp_read - rd, 0.0)
			if pp_read >= PP_READ_S or pp_held_t >= PP_AUTO_S:
				var br = nm_sign.get("intrbranch_waiver") if nm_sign != null and is_instance_valid(nm_sign) else null
				if _allowed(br):
					pp_fired = true
					hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
					interaction.set("activeInteractionBranch", br)
					interaction.call("MainInteractionEvent")
					print("VRBoot: the waiver is read - the game's pick-up runs (the name machine comes up)")
				else:
					pp_held_t = 0.0
	pp_pose = tgt if pp_hand != null else pp_pose.interpolate_with(tgt, 1.0 - exp(-rd * 12.0))
	pp_root.global_transform = pp_pose
