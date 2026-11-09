# Developer tool: walkable-area map dump
# (Part of the Buckshot Roulette VR mod. Chain position 21: this file extends 20_poke.gd; see src/README.md.)
extends "20_poke.gd"

const MAP_X0 := -210.0

const MAP_X1 := -10.0

const MAP_Z0 := -45.0

const MAP_Z1 := 45.0

const MAP_CELL := 0.5

const MAP_PLANES := [-6.0, 2.0, 8.0]               # cut heights (red, green, blue): knee, chest, head level

var map_img: Image

var map_jobs: Array = []

var map_idx := 0

var map_faces := PackedVector3Array()

var map_xf := Transform3D.IDENTITY

var map_tri := 0

# Slices every mesh in the building at three heights and paints the cuts into walkmap.png, so the
# real walls can be compared with WALK_ROOMS. Runs a little each frame; takes a while, then is done.
func _start_map_dump() -> void:
	map_dump_state = 1
	var w := int((MAP_X1 - MAP_X0) / MAP_CELL)
	var h := int((MAP_Z1 - MAP_Z0) / MAP_CELL)
	map_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	map_img.fill(Color(0, 0, 0))
	map_jobs.clear()
	map_idx = 0
	map_faces = PackedVector3Array()
	for n in cur_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.layers == 0 or not mi.is_visible_in_tree():
			continue
		var wb: AABB = mi.global_transform * mi.get_aabb()
		if wb.end.x < MAP_X0 or wb.position.x > MAP_X1 or wb.end.z < MAP_Z0 or wb.position.z > MAP_Z1:
			continue
		var crosses := false
		for py in MAP_PLANES:
			if wb.position.y <= float(py) and wb.end.y >= float(py):
				crosses = true
		if crosses:
			map_jobs.append(mi)
	print("VRBoot: floor plan dump started, ", map_jobs.size(), " meshes")

func _map_dump_step() -> void:
	if map_dump_state != 1:
		return
	var budget := 100
	while budget > 0:
		if map_faces.is_empty():
			if map_idx >= map_jobs.size():
				_finish_map_dump()
				return
			var mi = map_jobs[map_idx]
			map_idx += 1
			if not is_instance_valid(mi) or (mi as MeshInstance3D).mesh == null:
				continue
			map_xf = (mi as MeshInstance3D).global_transform
			map_faces = (mi as MeshInstance3D).mesh.get_faces()
			map_tri = 0
			budget -= 5
			continue
		var i := map_tri * 3
		if i + 2 >= map_faces.size():
			map_faces = PackedVector3Array()
			continue
		_map_triangle(map_faces[i], map_faces[i + 1], map_faces[i + 2])
		map_tri += 1
		budget -= 1

func _map_triangle(a: Vector3, b: Vector3, c: Vector3) -> void:
	var w: Array[Vector3] = [map_xf * a, map_xf * b, map_xf * c]
	for pi in MAP_PLANES.size():
		var py: float = MAP_PLANES[pi]
		var pts: Array[Vector3] = []
		for e in 3:
			var p: Vector3 = w[e]
			var q: Vector3 = w[(e + 1) % 3]
			var dp := p.y - py
			var dq := q.y - py
			if (dp < 0.0) != (dq < 0.0):
				pts.append(p.lerp(q, dp / (dp - dq)))
		if pts.size() == 2:
			_map_line(pts[0], pts[1], pi)

func _map_line(a: Vector3, b: Vector3, ch: int) -> void:
	var len := maxf(absf(b.x - a.x), absf(b.z - a.z))
	var steps := mini(int(len / (MAP_CELL * 0.5)) + 1, 1200)
	for k in steps + 1:
		var p := a.lerp(b, float(k) / float(steps))
		_map_put(p.x, p.z, ch)

func _map_put(x: float, z: float, ch: int) -> void:
	var px := int((x - MAP_X0) / MAP_CELL)
	var py := int((MAP_Z1 - z) / MAP_CELL)
	if px < 0 or py < 0 or px >= map_img.get_width() or py >= map_img.get_height():
		return
	var c := map_img.get_pixel(px, py)
	if ch == 0:
		c.r = 1.0
	elif ch == 1:
		c.g = 1.0
	else:
		c.b = 1.0
	map_img.set_pixel(px, py, c)

func _finish_map_dump() -> void:
	map_dump_state = 2
	for r in _walk_rects(false):
		var rect: Rect2 = r
		var x := rect.position.x
		while x <= rect.end.x:
			_map_mark(x, rect.position.y)
			_map_mark(x, rect.end.y)
			x += MAP_CELL
		var z := rect.position.y
		while z <= rect.end.y:
			_map_mark(rect.position.x, z)
			_map_mark(rect.end.x, z)
			z += MAP_CELL
	for dx in range(-3, 4):
		for dz in range(-3, 4):
			_map_mark(HOME_POS.x + dx * MAP_CELL, HOME_POS.z + dz * MAP_CELL)
	var big := map_img.duplicate() as Image
	big.resize(map_img.get_width() * 3, map_img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var err := big.save_png("user://vr_mod/walkmap.png")
	print("VRBoot: floor plan saved (user://vr_mod/walkmap.png) err=", err, " x ", MAP_X0, "..", MAP_X1, " z ", MAP_Z0, "..", MAP_Z1)
	map_faces = PackedVector3Array()
	map_jobs.clear()

func _map_mark(x: float, z: float) -> void:
	var px := int((x - MAP_X0) / MAP_CELL)
	var py := int((MAP_Z1 - z) / MAP_CELL)
	if px < 0 or py < 0 or px >= map_img.get_width() or py >= map_img.get_height():
		return
	map_img.set_pixel(px, py, Color(1, 1, 1))



# ------------------------------------------------------------------ click targets, brackets, aim assist
