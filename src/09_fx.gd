# Visual effects and clones: shatter, toss, shards, animation helpers
# (Part of the Buckshot Roulette VR mod. Chain position 09: this file extends 08_pills.gd; see src/README.md.)
extends "08_pills.gd"

const FX_FADE_S := 2.0                             # used-up things fade out this long (opacity 1 -> 0, linear): the game's own barrel grows back with the opposite (SegmentManager.dur 2 s)

func _fx_clone_visual(src: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "VRBootProp"
	fx_root.add_child(root)
	root.global_transform = Transform3D(src.global_transform.basis.orthonormalized(), src.global_transform.origin)
	var meshes: Array = []
	if src is MeshInstance3D:
		meshes.append(src)
	_collect_meshes(src, meshes)
	for o in meshes:
		var mi: MeshInstance3D = o
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var c := MeshInstance3D.new()
		c.mesh = mi.mesh
		c.material_override = mi.material_override
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m != null:
				c.set_surface_override_material(i, m)
		root.add_child(c)
		c.global_transform = mi.global_transform
	return root

# Lets a node fall to the table, bounce, lie there a moment and fade away (opacity down over FX_FADE_S).
func _fx_fall(n: Node3D, vel: Vector3, spin: Vector3, floor_y: float, life: float, fade := false) -> void:
	fx_list.append({"n": n, "v": vel, "w": spin, "t": 0.0, "floor": floor_y, "life": life, "b": 0, "snd": "", "fade": fade})

func _fx_toss(par: Node3D) -> void:
	var c := _fx_clone_visual(par)
	var ws := world_scale
	var v := Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3)) * ws
	_fx_fall(c, v, Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), item_floor_y, 1.6)

func _fx_update(delta: float) -> void:
	var ws := world_scale
	var i := fx_list.size() - 1
	while i >= 0:
		var e: Dictionary = fx_list[i]
		var n = e["n"]
		if not (n is Node3D) or not is_instance_valid(n):
			fx_list.remove_at(i)
			i -= 1
			continue
		var nd: Node3D = n
		var v: Vector3 = e["v"]
		var t: float = e["t"] + delta
		e["t"] = t
		v.y -= 9.8 * ws * delta
		var p := nd.global_position + v * delta
		var w: Vector3 = e["w"]
		if p.y <= float(e["floor"]):
			p.y = float(e["floor"])
			if v.y < -0.2 * ws and int(e["b"]) < 3:
				v.y = -v.y * 0.3
				e["b"] = int(e["b"]) + 1
				if str(e["snd"]) != "" and int(e["b"]) == 1:
					_fx_drop_sound()
			else:
				v.y = 0.0
			v.x *= 0.8
			v.z *= 0.8
			w *= 0.6
		e["v"] = v
		e["w"] = w
		nd.global_position = p
		if w.length() > 0.01:
			nd.global_transform = Transform3D(Basis(Vector3(1, 0, 0), w.x * delta) * Basis(Vector3(0, 1, 0), w.y * delta) \
				* Basis(Vector3(0, 0, 1), w.z * delta) * nd.global_transform.basis, p)
		var life: float = e["life"]
		if t > life:
			var k := clampf(1.0 - (t - life) / FX_FADE_S, 0.0, 1.0)
			var fm = (nd as MeshInstance3D).material_override if nd is MeshInstance3D else null
			if bool(e.get("fade", false)) and not bool(e.get("fadet", false)) and fm is StandardMaterial3D:
				var fc := (fm as StandardMaterial3D).albedo_color
				fc.a = minf(fc.a, k * float(e.get("a0", 1.0)))
				(fm as StandardMaterial3D).albedo_color = fc
			else:
				# opacity falls linearly to nothing (the exact opposite of the game's barrel growing back), the size stays
				if nd is GeometryInstance3D:
					(nd as GeometryInstance3D).transparency = clampf(1.0 - k, 0.0, 1.0)
				var gl: Array = []
				_collect_geoms(nd, gl)
				for g in gl:
					(g as GeometryInstance3D).transparency = clampf(1.0 - k, 0.0, 1.0)
			if k <= 0.0:
				nd.queue_free()
				fx_list.remove_at(i)
		i -= 1

func _fx_drop_sound() -> void:
	if cur_scene == null:
		return
	var sd := cur_scene.find_child("shell drop manager", true, false)
	if sd != null and sd.has_method("PlayShellDropSound"):
		sd.call("PlayShellDropSound")

# The glass breaks: pieces of the lens (clear) and of the frame (dark) fly out, fall on the table, bounce, lie there and fade.
func _fx_shatter(lens_c: Vector3, lens_n: Vector3, lens_r: float, ref: Vector3, floor_y: float) -> void:
	var ws := world_scale
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ref_up := Vector3.UP if absf(lens_n.y) < 0.98 else Vector3.RIGHT
	var ax := ref_up.cross(lens_n).normalized()
	var ay := lens_n.cross(ax).normalized()
	for i in 16:
		var ang := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * lens_r
		var out := ax * cos(ang) + ay * sin(ang)
		var p := lens_c + out * rr
		var sz := rng.randf_range(0.008, 0.022) * ws
		var am := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-sz, -sz * 0.6, 0.0), Vector3(sz * rng.randf_range(0.6, 1.2), -sz * 0.3, 0.0), Vector3(sz * rng.randf_range(-0.4, 0.3), sz * rng.randf_range(0.7, 1.2), 0.0)])
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(0.82, 0.94, 1.0, 0.7)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		mi.global_position = p
		mi.global_transform = Transform3D(Basis.looking_at(lens_n, ay) * Basis(Vector3(0.0, 0.0, 1.0), rng.randf() * TAU), p)
		var v := out * rng.randf_range(0.2, 0.7) * ws + lens_n * rng.randf_range(-0.2, 0.4) * ws + Vector3.UP * rng.randf_range(0.1, 0.5) * ws
		_fx_fall(mi, v, Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)), floor_y + 0.002 * ws, 1.4, true)
		fx_list[fx_list.size() - 1]["a0"] = 0.7
	for i in 6:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.008, 0.02), rng.randf_range(0.004, 0.01), rng.randf_range(0.01, 0.03)) * ws
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.16, 0.16, 0.17, 1.0)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(mi)
		mi.global_position = lens_c.lerp(ref, rng.randf())
		var v2 := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.7), rng.randf_range(-0.4, 0.4)) * ws
		_fx_fall(mi, v2, Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)), floor_y + 0.005 * ws, 1.4, true)
	_fx_shards(Vector3(lens_c.x, maxf(floor_y, lens_c.y - lens_r) + 0.01 * ws, lens_c.z))

func _fx_shards(at: Vector3) -> void:
	var ws := world_scale
	var p := CPUParticles3D.new()
	p.name = "VRBootShards"
	p.amount = 34
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.01 * ws
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 180.0
	p.initial_velocity_min = 0.25 * ws
	p.initial_velocity_max = 0.9 * ws
	p.gravity = Vector3(0.0, -9.8 * ws, 0.0)
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	var q := QuadMesh.new()
	q.size = Vector2(0.006, 0.006) * ws
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.9, 0.9)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	fx_root.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)

# A sound out of one of the game's own animations (all of its sound clips are inside them): the first audio key whose file
# name contains the word.
func _anim_stream(anim_name: String, word: String) -> AudioStream:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii == null:
		return null
	var an = ii.get("animator_playerHands")
	if not (an is AnimationPlayer):
		return null
	if not (an as AnimationPlayer).has_animation(anim_name):
		return null
	var anim: Animation = (an as AnimationPlayer).get_animation(anim_name)
	if anim == null:
		return null
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_AUDIO:
			continue
		for k in anim.track_get_key_count(i):
			var s: AudioStream = anim.audio_track_get_key_stream(i, k)
			if s != null and s.resource_path.to_lower().contains(word):
				return s
	return null

func _fx_play(s: AudioStream, db: float = -2.0, from := 0.0) -> AudioStreamPlayer:
	if s == null:
		return null
	var ap := AudioStreamPlayer.new()
	ap.stream = s
	ap.volume_db = db
	fx_root.add_child(ap)
	ap.play(from)
	ap.finished.connect(ap.queue_free)
	return ap


# ---- using an item up (what the game does around its animation, without the animation) --------------------------------------

# The box of a part of the shotgun as you see it: the copy on the gun in your hand, or the game's own part.
func _gun_part_box(n: Node) -> AABB:
	var out := AABB()
	out.size = Vector3(-1.0, -1.0, -1.0)
	if gun_state == 1 and not gun_pairs.is_empty():
		for e in gun_pairs:
			var o: Node = e[0]
			if o == n or n.is_ancestor_of(o):
				var c = e[1]
				if is_instance_valid(c):
					var b := _node_world_aabb(c, false)
					if b.size.x >= 0.0:
						out = b if out.size.x < 0.0 else out.merge(b)
		return out
	return _node_world_aabb(n, false)

# A loose visual copy of a part of the gun in your hand (what falls to the table when it is sawn off).
func _fx_clone_gun_part(n: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "VRBootProp"
	fx_root.add_child(root)
	var xf: Transform3D = gun_prop.global_transform * (gun_main.global_transform.affine_inverse() * n.global_transform)
	root.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
	for e in gun_pairs:
		var o: Node = e[0]
		var c = e[1]
		if not (o == n or n.is_ancestor_of(o)) or not is_instance_valid(c) or not (c as MeshInstance3D).visible:
			continue
		var d := MeshInstance3D.new()
		d.mesh = (c as MeshInstance3D).mesh
		d.material_override = (c as MeshInstance3D).material_override
		if d.mesh != null:
			for i in d.mesh.get_surface_count():
				var m := (c as MeshInstance3D).get_surface_override_material(i)
				if m != null:
					d.set_surface_override_material(i, m)
		root.add_child(d)
		d.global_transform = (c as MeshInstance3D).global_transform
	return root

# A piece of a sound (the game keeps all of the phone's sounds in one 10.9 s file that goes with its own animation): from `from`
# for `dur` seconds, the end fading out.
func _fx_play_seg(s: AudioStream, from: float, dur: float, db: float = -2.0) -> void:
	var ap := _fx_play(s, db, from)
	if ap == null:
		return
	var tw := ap.create_tween()
	tw.tween_interval(maxf(dur - 0.12, 0.0))
	tw.tween_property(ap, "volume_db", -40.0, 0.12)
	tw.tween_callback(ap.queue_free)

# One mesh of a node copied alone (no children).
func _fx_clone_solo(src: MeshInstance3D) -> Node3D:
	var root := Node3D.new()
	root.name = "VRBootProp"
	fx_root.add_child(root)
	root.global_transform = Transform3D(src.global_transform.basis.orthonormalized(), src.global_transform.origin)
	if src.mesh != null:
		var c := MeshInstance3D.new()
		c.mesh = src.mesh
		c.material_override = src.material_override
		for i in src.mesh.get_surface_count():
			var m := src.get_surface_override_material(i)
			if m != null:
				c.set_surface_override_material(i, m)
		root.add_child(c)
		c.global_transform = src.global_transform
	return root
