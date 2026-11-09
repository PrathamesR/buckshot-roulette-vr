# Small shared helpers: aliases, permissions, box maths, mouth point, seat/size references
# (Part of the Buckshot Roulette VR mod. Chain position 02: this file extends 01_forward.gd; see src/README.md.)
extends "01_forward.gd"

const HEIGHT_DOWN_M := 0.3                         # how far below / above the reference seat height you can go (metres at the default size)

const HEIGHT_UP_M := 0.5

# Game items (everything except the bathroom and lobby things) cannot be selected before you have sat down.
const PRESEAT_ALIASES := ["crt", "crt button", "bathroom door", "pill bottle", "pill choice yes", "pill choice no", "backroom door"]

const POKE_ALIASES := ["crt", "crt button", "bathroom door", "backroom door", "latch left", "latch right", "briefcase lid"]   # pressed with a finger, never the laser

const HIDE_HINT_ALIASES := ["pill choice yes", "pill choice no", "pill bottle"]   # no laser hints; the bottle is picked up by hand

var table_y := NAN                  # the playing surface of the table (the biggest upward-facing part of its mesh)

var table_y_for: Node = null

var size_raw_logged := false

func _in_main_scene() -> bool:
	return cur_scene != null and cur_scene.name == "main"

# Which room an x position is in (bit mask; the two doorways belong to both neighbours). 0 = not a room we know.
func _room_mask(x: float) -> int:
	if not regime_big or x < -190.0:
		return 0
	if x < -140.0:
		return 1
	if x < -134.0:
		return 3
	if x < -39.5:
		return 2
	if x < -35.0:
		return 6
	return 4

# True when p is in another room than your head (so a wall is between you and it).
func _behind_wall(p: Vector3) -> bool:
	if xr_cam == null or not _in_main_scene():
		return false
	var mh := _room_mask(xr_cam.global_position.x)
	var mt := _room_mask(p.x)
	return mh != 0 and mt != 0 and (mh & mt) == 0

# Before you sit down only the bathroom and lobby things work (see PRESEAT_ALIASES); everything on the table waits.
func _items_locked() -> bool:
	return _in_main_scene() and regime_big and (mode != "table" or walk_to_table or hold_for_dealer)

func _alias_locked(a: String) -> bool:
	return a != "" and not PRESEAT_ALIASES.has(a) and _items_locked()

# Before you have sat down everything is done by hand (doors, TV, pills, name machine, waiver): no laser, no dot,
# and nothing the trigger can click. The pause menu and the 2D menu scene keep their pointer.
func _physical_only() -> bool:
	return _in_main_scene() and not pause_open and _items_locked()

func _is_finger(n: Node) -> bool:
	var a := _alias_of(n)
	return FINGER_ALIASES.has(a)             # (iteration 34) the waiver is touched with a fingertip again, as before iteration 32

func _def_scale() -> float:
	return DEFAULT_SCALE_BIG if regime_big else DEFAULT_SCALE_SMALL

func _def_seat() -> Vector3:
	return DEFAULT_SEAT_BIG if regime_big else DEFAULT_SEAT_SMALL

# What "SIZE 100 %" and "HEIGHT +0 CM" mean in the readout.
func _ref_scale() -> float:
	return REF_SCALE_BIG if regime_big else REF_SCALE_SMALL

func _ref_seat_y() -> float:
	return REF_SEAT_Y_BIG if regime_big else REF_SEAT_Y_SMALL

# Where a controller really is in your play space, in metres, with no world scale applied (so it does not
# depend on the size you are changing). NAN when it cannot be read.
func _hand_raw(hh: Hand) -> Vector3:
	var bad := Vector3(NAN, NAN, NAN)
	if not hh.was_active:
		return bad
	if size_use_nodes and world_scale > 0.0001:
		return hh.grip.position / world_scale
	var p: XRPose = hh.grip.get_pose()
	if p != null:
		return p.transform.origin
	if not size_raw_logged:
		size_raw_logged = true
		print("VRBoot: size gesture: no raw hand pose, using the node positions")
	if world_scale > 0.0001:
		return hh.grip.position / world_scale
	return bad

# The game's own menu font (loaded from its data at run time, nothing is copied). Null = the engine default.
func _game_font() -> Font:
	if ui_font == null:
		if ResourceLoader.exists(UI_FONT_PATH):
			ui_font = load(UI_FONT_PATH) as Font
		if ui_font == null:
			print("VRBoot: the game's font could not be loaded, using the default one")
	return ui_font

func _clamp_seat_y(y: float, ref_y: float, def_s: float) -> float:
	return clampf(y, ref_y - HEIGHT_DOWN_M * def_s, ref_y + HEIGHT_UP_M * def_s)

func _box(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	return sb

func _seat_point() -> Vector3:
	return HOME_POS + Basis(Vector3.UP, HOME_YAW) * seat

func _dist_to_seat() -> float:
	var h := xr_cam.global_position
	var s := _seat_point()
	return Vector2(h.x - s.x, h.z - s.z).length()

func _alias_of(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return ""
	var a = n.get("interactionAlias")
	return str(a) if a != null else ""

func _is_poke(n: Node) -> bool:
	return POKE_ALIASES.has(_alias_of(n))

func _hint_hidden(n: Node) -> bool:
	var a := _alias_of(n)
	return POKE_ALIASES.has(a) or HIDE_HINT_ALIASES.has(a)

func _allowed(n: Node) -> bool:
	return n != null and is_instance_valid(n) and bool(n.get("interactionAllowed")) \
		and not bool(n.get("interactionInvalid"))

# The box (world) around the visible meshes of a node and everything below it (size.x < 0 = none).
func _node_world_aabb(n: Node, visible_only: bool) -> AABB:
	var out := AABB()
	out.size = Vector3(-1.0, -1.0, -1.0)
	if n == null or not is_instance_valid(n):
		return out
	var meshes: Array = []
	if n is MeshInstance3D:
		meshes.append(n)
	_collect_meshes(n, meshes)
	var first := true
	for o in meshes:
		var mi: MeshInstance3D = o
		if mi.mesh == null or not mi.is_inside_tree():
			continue
		if visible_only and not mi.is_visible_in_tree():
			continue
		var bb: AABB = mi.global_transform * mi.mesh.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out

# (iteration 34) The numbers of a dealer hand shape for one hand: the base hand as measured, the other hand the mirror image.
func _refl(t: Vector3) -> Basis:
	var n := t.normalized()
	return Basis(Vector3.RIGHT - 2.0 * n * n.x, Vector3.UP - 2.0 * n * n.y, Vector3.BACK - 2.0 * n * n.z)

func _collect_geoms(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		_collect_geoms(c, out)

# Your mouth: just below your eyes.
func _mouth_point() -> Vector3:
	return xr_cam.global_position - xr_cam.global_transform.basis.y.normalized() * (0.06 * world_scale)

# The lowest point of the item's box if it lay where it came from: the table's height under it.
func _item_table_y() -> float:
	var up: Node3D = null
	if item_node != null and is_instance_valid(item_node):
		up = item_node.get_parent() as Node3D
	if up == null:
		return item_floor_y
	var xf: Transform3D = up.global_transform * item_home
	var y := INF
	for i in 8:
		y = minf(y, (xf * item_loc.get_endpoint(i)).y)
	return y

func _collect_meshes(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		_collect_meshes(c, out)

# The tip of the index finger (world space).
func _hand_tip(hh: Hand) -> Vector3:
	return hh.grip.global_transform * (hh.tip_local * world_scale)

func _point_box_dist(p: Vector3, box: AABB) -> float:
	var dx := maxf(maxf(box.position.x - p.x, p.x - box.end.x), 0.0)
	var dy := maxf(maxf(box.position.y - p.y, p.y - box.end.y), 0.0)
	var dz := maxf(maxf(box.position.z - p.z, p.z - box.end.z), 0.0)
	return Vector3(dx, dy, dz).length()

func _rect_dist(p: Vector2, rs: Array) -> float:
	var best := INF
	for r in rs:
		var rect: Rect2 = r
		var dx := maxf(maxf(rect.position.x - p.x, p.x - rect.end.x), 0.0)
		var dz := maxf(maxf(rect.position.y - p.y, p.y - rect.end.y), 0.0)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best

# The playing surface of the table: the height of the biggest upward-facing part of the game's table mesh (found once per scene).
func _table_surface_y() -> float:
	if cur_scene == null or not is_instance_valid(cur_scene):
		return NAN
	if table_y_for == cur_scene:
		return table_y
	table_y_for = cur_scene
	table_y = NAN
	var area := {}
	for nm in ["main tabletop", "main tabletop2"]:
		var mi := cur_scene.find_child(nm, true, false) as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.is_inside_tree():
			continue
		var fc: PackedVector3Array = mi.mesh.get_faces()
		var xf := mi.global_transform
		var i := 0
		while i + 2 < fc.size():
			var a := xf * fc[i]
			var b := xf * fc[i + 1]
			var c := xf * fc[i + 2]
			var cr := (c - a).cross(b - a)                 # (Godot's front faces run clockwise: this is the outward normal)
			var ar := cr.length() * 0.5
			if ar > 0.000001 and cr.normalized().y > 0.9:
				var k := roundi((a.y + b.y + c.y) / 3.0 / 0.02)
				area[k] = float(area.get(k, 0.0)) + ar
			i += 3
	var best_k := 0
	var best_a := 0.0
	for k in area.keys():
		if float(area[k]) > best_a:
			best_a = float(area[k])
			best_k = int(k)
	if best_a > 0.0:
		table_y = float(best_k) * 0.02
		print("VRBoot: the table's surface is at y=", snappedf(table_y, 0.001), " (frames lie on it)")
	return table_y

func _quant(x: float, n: float) -> float:
	return floorf(x * n) / n

func _ui_tex() -> Texture2D:
	if monitor_view and ui_vp != null:
		return ui_vp.get_texture()
	return get_tree().root.get_texture()

# Compass heading (radians) of a direction vector, ignoring pitch.
func _heading_of_vec(f: Vector3, fallback: float) -> float:
	f.y = 0.0
	if f.length() < 0.2:
		return fallback
	f = f.normalized()
	return atan2(-f.x, -f.z)
