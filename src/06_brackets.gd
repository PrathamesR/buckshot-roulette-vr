# Highlight frames (brackets), branch boxes, game highlight suppression
# (Part of the Buckshot Roulette VR mod. Chain position 06: this file extends 05_bathroom.gd; see src/README.md.)
extends "05_bathroom.gd"

const ASSIST_MIN_ANGLE := 0.06                     # aim assist cone (radians) around small click targets

const KEYS_ALIAS := "signature machine button"       # 28 keys: no faint frames around all of them

const BRACKET_UNIT := 6.6                          # highlight sizes are in these game units per metre, NOT the world scale

const BRACKET_MIN_M := 0.06                        # smallest half-size of the pointed-at highlight

const BRACKET_MIN_DIM_M := 0.05                    # ... and of the faint ones

const BRACKET_PAD_M := 0.025

const HINT_MAX_UNITS := 220.0                      # dim "you can click this" brackets up to this far away

const BRACKET_MAX_M := 4.0                         # ignore click targets bigger than this (walls)

var bracket_shown := ""

# Keeps the game in "mouse" mode: its joypad mode would draw its own [ ] marks on everything.
func _suppress_game_highlights() -> void:
	if not _in_main_scene() or interaction == null or not is_instance_valid(interaction):
		return
	var intro := _intro()
	if intro == null:
		return
	var ctl = intro.get("controller")
	if not (ctl is Node) or not is_instance_valid(ctl):
		return
	if bool(ctl.get("dynamicallySwappingDevice")):
		ctl.set("dynamicallySwappingDevice", false)
	var cur = intro.get("cursor")
	if cur is Node and bool(cur.get("controller_active")):
		ctl.call("SetMainControllerState", false)
		print("VRBoot: switched the game's joypad highlight mode off")

# The player's own leg (it stays behind where it last was) and the game's 3D highlight frames are not wanted.
func _hide_clutter() -> void:
	var count := 0
	for pat in ["player leg*", "bracket selection 3d*"]:
		for node in cur_scene.find_children(str(pat), "", true, false):
			var all: Array = [node]
			all.append_array(node.find_children("*", "VisualInstance3D", true, false))
			for n in all:
				if n is VisualInstance3D:
					(n as VisualInstance3D).layers = 0
					count += 1
	print("VRBoot: hid ", count, " leg / highlight-frame meshes")


# ------------------------------------------------------------------ walking limits

# Collision shapes belonging to one "interaction branch" (cached): [[CollisionShape3D, local AABB], ...]
func _branch_info(br: Node) -> Dictionary:
	var id := br.get_instance_id()
	if shape_cache.has(id):
		return shape_cache[id]
	var shapes: Array = []
	var body: Node = null
	var parent := br.get_parent()
	if parent != null:
		for cs in parent.find_children("*", "CollisionShape3D", true, false):
			var shp: Shape3D = (cs as CollisionShape3D).shape
			if shp == null:
				continue
			var dm := shp.get_debug_mesh()
			if dm == null:
				continue
			shapes.append([cs, dm.get_aabb()])
			var b := cs.get_parent()
			if body == null and b is CollisionObject3D and b.get_parent() == parent:
				body = b
	var info := {"shapes": shapes, "body": body}
	shape_cache[id] = info
	return info

# World-space box around a click target. size.x < 0 means "no usable shape".
func _branch_world_box(br: Node, visible_only: bool) -> AABB:
	var info := _branch_info(br)
	var box := AABB()
	var first := true
	for e in info["shapes"]:
		var cs: CollisionShape3D = e[0]
		if not is_instance_valid(cs) or cs.disabled:
			continue
		if visible_only and not cs.is_visible_in_tree():
			continue
		var tr: Transform3D = cs.global_transform
		var wb: AABB = tr * (e[1] as AABB)
		if first:
			box = wb
			first = false
		else:
			box = box.merge(wb)
	if first:
		box.size = Vector3(-1.0, -1.0, -1.0)
	return box

func _has_branch(res: Dictionary) -> bool:
	if res.is_empty() or not res.has("collider"):
		return false
	var col = res["collider"]
	if col == null or not is_instance_valid(col):
		return false
	var p = col.get_parent()
	if p == null:
		return false
	for ch in p.get_children():
		if ch.get("interactionAlias") != null:
			return true
	return false

# The click target closest to where the laser points, if it is within a small cone.
func _assist_hit(o: Vector3, d: Vector3, res: Dictionary) -> Dictionary:
	var real_dist := INF
	if not res.is_empty():
		real_dist = o.distance_to(res["position"])
	var best := {}
	var best_score := 1.0
	for n in hint_nodes:
		if not is_instance_valid(n) or not bool(n.get("interactionAllowed")) or _hint_hidden(n) or _alias_locked(_alias_of(n)):
			continue
		var info := _branch_info(n)
		var body = info["body"]
		if body == null or not is_instance_valid(body):
			continue
		var box := _branch_world_box(n, true)
		if box.size.x < 0.0:
			continue
		var c := box.get_center()
		if _behind_wall(c):
			continue
		var to := c - o
		var dist := to.length()
		if dist < 0.5 or dist > RAY_MAX_UNITS:
			continue
		var radius := minf(box.size.length() * 0.5, BRACKET_MAX_M * world_scale)
		if real_dist < dist - radius - 1.0:
			continue                    # something solid is in front of it
		var ang := d.angle_to(to / dist)
		var tol := maxf(ASSIST_MIN_ANGLE, asin(clampf(radius / dist, 0.0, 0.99)) * 1.3)
		var score := ang / tol
		if score < best_score:
			best_score = score
			best = {"collider": body, "position": c, "normal": -d, "collider_id": body.get_instance_id(),
				"rid": RID(), "shape": 0}
	return best

var br_verts := PackedVector3Array()

var br_cols := PackedColorArray()

func _update_brackets() -> void:
	bracket_im.clear_surfaces()
	br_verts.clear()
	br_cols.clear()
	bracket_shown = ""
	if _in_main_scene() and xr_cam != null and not ui_active:
		var head := xr_cam.global_position
		var hover_br: Node = null
		if interaction != null and is_instance_valid(interaction) and world_hit and _laser_wanted():
			var br = interaction.get("activeInteractionBranch")
			if br != null and is_instance_valid(br) and bool(br.get("interactionAllowed")) and not _hint_hidden(br) \
					and not _alias_locked(_alias_of(br)):
				hover_br = br
		# dim hints for everything you can click right now (while you are moving around the building)
		if hint_dim and (mode == "follow" or walk_to_table):
			var a := 0.30 + 0.10 * sin(t_alive * 3.0)
			for n in hint_nodes:
				if not is_instance_valid(n) or n == hover_br or _hint_hidden(n) or _alias_of(n) == KEYS_ALIAS or _alias_locked(_alias_of(n)):
					continue
				if not bool(n.get("interactionAllowed")) or bool(n.get("interactionInvalid")):
					continue
				var box := _branch_world_box(n, true)
				if box.size.x < 0.0 or head.distance_to(box.get_center()) > HINT_MAX_UNITS or _behind_wall(box.get_center()):
					continue
				var odn := _branch_oriented(n, true)
				if odn.is_empty():
					_add_bracket_for_box(box, head, Color(1.0, 1.0, 1.0, a), false)
				else:
					_add_bracket_face(odn, head, Color(1.0, 1.0, 1.0, a), false)
		# (iteration 37) the double-or-nothing buttons are framed while they can be pressed (pulsing); green when the laser is on one
		for n in hint_nodes:
			if not is_instance_valid(n) or n == hover_br or not LASER_ALIASES.has(_alias_of(n)):
				continue
			if not bool(n.get("interactionAllowed")) or bool(n.get("interactionInvalid")):
				continue
			var dbox := _branch_world_box(n, false)
			if dbox.size.x < 0.0:
				continue
			var dcol := Color(0.35, 1.0, 0.45, 0.65 + 0.3 * sin(t_alive * 4.0))
			var ddo := _branch_oriented(n, false)
			if ddo.is_empty():
				_add_bracket_for_box(dbox, head, dcol, true)
			else:
				_add_bracket_face(ddo, head, dcol, true)
		if hover_br != null:
			var hbox := _branch_world_box(hover_br, false)
			if hbox.size.x < 0.0:
				hbox = AABB(world_hit_pos - Vector3.ONE * (0.1 * world_scale), Vector3.ONE * (0.2 * world_scale))
			var col := Color(0.35, 1.0, 0.45, 0.95)
			if bool(hover_br.get("interactionInvalid")):
				col = Color(1.0, 0.35, 0.35, 0.95)
			var odh := _branch_oriented(hover_br, false)
			if odh.is_empty():
				_add_bracket_for_box(hbox, head, col, true)
			else:
				_add_bracket_face(odh, head, col, true)
			bracket_shown = str(hover_br.get("interactionAlias"))
		# a fingertip is close to something you press by hand: frame it
		for pb in poke_boxes:
			var pcol := Color(0.35, 1.0, 0.45, 0.95)
			if pb is Dictionary:
				if (pb as Dictionary).has("flat"):
					_add_bracket_flat((pb as Dictionary)["flat"], head, pcol, true, true)
				elif (pb as Dictionary).has("face"):
					_add_bracket_face((pb as Dictionary)["face"], head, pcol, true, true)
			else:
				_add_bracket_for_box(pb, head, pcol, true, true)
	bracket.visible = br_verts.size() > 0
	if br_verts.size() > 0:
		bracket_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in br_verts.size():
			bracket_im.surface_set_color(br_cols[i])
			bracket_im.surface_add_vertex(br_verts[i])
		bracket_im.surface_end()

# Draws "[ ]" in a plane that faces your head, sized to the box (plus a little padding).
func _add_bracket_for_box(box: AABB, head: Vector3, col: Color, strong: bool, tight := false) -> void:
	var ws := BRACKET_UNIT           # not the world scale: when you are smaller, the things are smaller and so are their frames
	var center := box.get_center()
	var n := head - center
	var dist := n.length()
	if dist < 0.01:
		return
	n /= dist
	var ref := Vector3.UP if absf(n.y) < 0.98 else Vector3.RIGHT
	var right := ref.cross(n).normalized()
	var up := n.cross(right).normalized()
	var minx := INF
	var maxx := -INF
	var miny := INF
	var maxy := -INF
	for i in 8:
		var d := box.get_endpoint(i) - center
		var x := d.dot(right)
		var y := d.dot(up)
		minx = minf(minx, x)
		maxx = maxf(maxx, x)
		miny = minf(miny, y)
		maxy = maxf(maxy, y)
	var hw := (maxx - minx) * 0.5
	var hh := (maxy - miny) * 0.5
	var c2 := center + right * ((minx + maxx) * 0.5) + up * ((miny + maxy) * 0.5)
	_add_bracket_shape(c2, right, up, hw, hh, dist, col, strong, tight)

# "[ ]" drawn in the plane spanned by right and up around the point c2, half-width hw, half-height hh (dist = how far your head
# is, for the line width). The plane is the caller's choice: facing your head (the old way) or the object's own plane.
func _add_bracket_shape(c2: Vector3, right: Vector3, up: Vector3, hw: float, hh: float, dist: float, col: Color, strong: bool, tight: bool) -> void:
	var ws := BRACKET_UNIT           # not the world scale: when you are smaller, the things are smaller and so are their frames
	# "tight" = things you press with a fingertip (TV buttons, pill bottle): hug the real shape
	var minh := (BRACKET_MIN_M if strong else BRACKET_MIN_DIM_M) * ws
	if tight:
		minh = 0.010 * ws
	hw = maxf(hw, minh)
	hh = maxf(hh, minh)
	if hw > BRACKET_MAX_M * world_scale or hh > BRACKET_MAX_M * world_scale:
		return                           # a wall or a whole room, not a button
	var pad := BRACKET_PAD_M * ws + 0.05 * maxf(hw, hh)
	if tight:
		pad = 0.004 * ws + 0.10 * maxf(hw, hh)
	var sc := 1.0 + (0.03 * sin(t_alive * 7.0) if strong else 0.0)
	hw = (hw + pad) * sc
	hh = (hh + pad) * sc
	var th := clampf(dist * 0.004, 0.006 * ws, 0.04 * ws)
	if tight:
		th = clampf(dist * 0.004, 0.003 * ws, 0.02 * ws)
	elif strong:
		th *= 1.4
	th = minf(th, 0.22 * minf(hw, hh))
	var arm := clampf(0.55 * minf(hw, hh), th * 3.0, hw)
	# left bracket
	_add_rect(c2, right, up, -hw, -hh, -hw + th, hh, col)
	_add_rect(c2, right, up, -hw, hh - th, -hw + arm, hh, col)
	_add_rect(c2, right, up, -hw, -hh, -hw + arm, -hh + th, col)
	# right bracket
	_add_rect(c2, right, up, hw - th, -hh, hw, hh, col)
	_add_rect(c2, right, up, hw - arm, hh - th, hw, hh, col)
	_add_rect(c2, right, up, hw - arm, -hh, hw, -hh + th, col)

# Frame lying on the table under a thing (an item, the shotgun, a slot): the box's footprint, on the table plane.
func _add_bracket_flat(box: AABB, head: Vector3, col: Color, strong: bool, tight := false) -> void:
	# lies ON the table: the click boxes reach below the felt, a frame at their bottom was hidden by the table (iteration 26)
	var fy := box.position.y
	var ts := _table_surface_y()
	if not is_nan(ts) and box.end.y >= ts - 0.02 * BRACKET_UNIT:
		fy = maxf(fy, ts)
	var c := Vector3(box.position.x + box.size.x * 0.5, fy + 0.012 * BRACKET_UNIT, box.position.z + box.size.z * 0.5)
	var dist := head.distance_to(c)
	if dist < 0.01:
		return
	_add_bracket_shape(c, Vector3.RIGHT, Vector3.BACK, box.size.x * 0.5, box.size.z * 0.5, dist, col, strong, tight)

# The click box of a branch in its own orientation: {"center", "basis", "half"} (half = half extents along the basis axes), or {}.
func _branch_oriented(br: Node, visible_only: bool) -> Dictionary:
	var info := _branch_info(br)
	var shapes: Array = []
	var basis := Basis.IDENTITY
	var best_vol := -1.0
	for e in info["shapes"]:
		var cs: CollisionShape3D = e[0]
		if not is_instance_valid(cs) or cs.disabled:
			continue
		if visible_only and not cs.is_visible_in_tree():
			continue
		var bb: AABB = e[1]
		var gt := cs.global_transform
		var vol := bb.size.x * bb.size.y * bb.size.z * absf(gt.basis.determinant())
		shapes.append([gt, bb])
		if vol > best_vol:
			best_vol = vol
			basis = gt.basis.orthonormalized()
	if shapes.is_empty():
		return {}
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	var inv := basis.transposed()
	for s in shapes:
		var gt: Transform3D = s[0]
		var bb: AABB = s[1]
		for i in 8:
			var l: Vector3 = inv * (gt * bb.get_endpoint(i))
			mn = Vector3(minf(mn.x, l.x), minf(mn.y, l.y), minf(mn.z, l.z))
			mx = Vector3(maxf(mx.x, l.x), maxf(mx.y, l.y), maxf(mx.z, l.z))
	return {"center": basis * ((mn + mx) * 0.5), "basis": basis, "half": (mx - mn) * 0.5}

# Frame lying on the face of an oriented box that looks at you: the door's plane for a door, the button's face for a button.
# A slab (a door, a plate) uses its big face; a chunky box uses whichever face looks most at your head.
func _add_bracket_face(od: Dictionary, head: Vector3, col: Color, strong: bool, tight := false) -> void:
	var bs: Basis = od["basis"]
	var half: Vector3 = od["half"]
	var center: Vector3 = od["center"]
	var axes := [bs.x.normalized(), bs.y.normalized(), bs.z.normalized()]
	var hv := [half.x, half.y, half.z]
	var to_head := head - center
	if to_head.length() < 0.01:
		return
	to_head = to_head.normalized()
	var ni := 0
	for i in 3:
		if float(hv[i]) < float(hv[ni]):
			ni = i
	var mid := 1.0e20                                   # the next smallest half extent
	for i in 3:
		if i != ni:
			mid = minf(mid, float(hv[i]))
	if float(hv[ni]) > 0.5 * mid:
		var bd := -1.0
		for i in 3:
			var dd := absf((axes[i] as Vector3).dot(to_head))
			if dd > bd:
				bd = dd
				ni = i
	var n: Vector3 = axes[ni]
	if n.dot(to_head) < 0.0:
		n = -n
	var ia := (ni + 1) % 3
	var ib := (ni + 2) % 3
	var iu := ia if absf((axes[ia] as Vector3).dot(Vector3.UP)) >= absf((axes[ib] as Vector3).dot(Vector3.UP)) else ib
	var ir := ib if iu == ia else ia
	var c2 := center + n * (float(hv[ni]) + 0.004 * BRACKET_UNIT)
	_add_bracket_shape(c2, axes[ir], axes[iu], float(hv[ir]), float(hv[iu]), head.distance_to(c2), col, strong, tight)

# Things a hand can reach, framed: items, the shotgun and slots lie in the table's plane, buttons and doors in their own.
func _pk_flat(box: AABB) -> void:
	if box.size.x >= 0.0:
		poke_boxes.append({"flat": box})

func _pk_face(br: Node) -> void:
	var od := _branch_oriented(br, false)
	if not od.is_empty():
		poke_boxes.append({"face": od})
		return
	var bx := _branch_world_box(br, false)
	if bx.size.x >= 0.0:
		poke_boxes.append(bx)

func _add_rect(c: Vector3, right: Vector3, up: Vector3, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	var p00 := c + right * x0 + up * y0
	var p10 := c + right * x1 + up * y0
	var p11 := c + right * x1 + up * y1
	var p01 := c + right * x0 + up * y1
	for p in [p00, p10, p11, p00, p11, p01]:
		br_verts.push_back(p)
		br_cols.push_back(col)


# ------------------------------------------------------------------ retro colours
