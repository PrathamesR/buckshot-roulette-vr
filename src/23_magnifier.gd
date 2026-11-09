# Magnifying glass item (smash, lens, window onto the shell)
# (Part of the Buckshot Roulette VR mod. Chain position 23: this file extends 22_adrenaline.gd; see src/README.md.)
extends "22_adrenaline.gd"

const MAG_LIFE_S := 5.0                            # the broken glass is gone this long after it broke (iteration 28)

const MAG_LENS_Y := 0.78                           # the lens's middle along the glass (0 = end of the handle, 1 = far end)

const MAG_LENS_R := 0.80                           # the clear part of the lens, as a share of the glass's radius

const MAG_SEE_S := 0.7                             # the shell seen through the glass this long: you have looked, the glass is spent

const MAG_SHELL_M := 0.11                          # the shell magnified in the glass is about this long (real metres)

const MAG_SMASH_V := 0.6                           # a downward stroke at least this fast (real m/s)...

const MAG_SMASH_NEAR_M := 0.09                     # ...with the glass this close to the table breaks it

const MAG_ANIM_OFF := Vector3(0.148208, -0.804758, 0.0)           # the game's animation props -> the table item's own space

const MAG_LENS_C := Vector3(0.1847, 1.3513, -0.008)               # the middle of the whole glass in the item's own space

const MAG_LENS_RAD := 0.8148                       # ...and its radius (item units), both read from the game's lens model

const MAG_LENS_SURF := "magnifying glass.001"      # the glass surface of the game's magnifier models

const MAG_MASK_N := 96                             # the broken glass as a picture: pixels per side

const MAG_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never;
uniform vec3 lens_c = vec3(0.0);
uniform vec3 lens_n = vec3(0.0, 0.0, 1.0);
uniform float lens_r = 0.1;
uniform vec3 lens_u = vec3(1.0, 0.0, 0.0);
uniform vec3 lens_v = vec3(0.0, 1.0, 0.0);
uniform float use_mask = 0.0;
uniform sampler2D lens_mask : filter_linear, repeat_disable;
uniform vec4 base_col : source_color = vec4(1.0);
uniform float vis = 1.0;
varying vec3 wpos;
varying vec3 wnrm;

// The shell is only drawn where the glass is between your eye and it: a window onto what is inside the gun.
// Whole round glass: a disc. The game's broken glass: only the pieces of glass that are left (a picture of them, lens_mask).
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 d = wpos - eye;
	float den = dot(lens_n, d);
	if (abs(den) < 0.00001) {
		discard;
	}
	float t = dot(lens_n, lens_c - eye) / den;
	if (t < 0.02 || t > 1.0) {
		discard;
	}
	vec3 q = eye + d * t - lens_c;
	float edge = 1.0;
	if (use_mask > 0.5) {
		vec2 uv = vec2(dot(q, lens_u), dot(q, lens_v)) + vec2(0.5);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			discard;
		}
		float mk = texture(lens_mask, uv).r;
		if (mk < 0.5) {
			discard;
		}
		edge = smoothstep(0.5, 0.8, mk);
	} else {
		float rr = length(q) / lens_r;
		if (rr > 1.0) {
			discard;
		}
		edge = 1.0 - smoothstep(0.82, 1.0, rr);
	}
	vec3 l = normalize(vec3(0.35, 0.8, 0.45));
	float lit = 0.5 + 0.5 * max(dot(normalize(wnrm), l), 0.0);
	ALBEDO = base_col.rgb * lit;
	ALPHA = edge * vis;
}
"""

var mag_seen_t := 0.0               # how long the shell has been in the glass so far

var mag_view: MeshInstance3D = null # the shell, magnified, drawn only inside the lens

var mag_mats: Array = []

var mag_shell := ""                 # "live" / "blank": which shell mag_view shows

var mag_long := 0.1                 # the model's longest side and its middle (model units)

var mag_center := Vector3.ZERO

var mag_orient := Basis.IDENTITY    # turns the model's long side along the gun's barrel

var mag_spin := 0.0

var mag_prev_ref := Vector3.ZERO

var mag_vel := Vector3.ZERO

var mag_vel_ok := false

var mag_shader: Shader = null

var mag_life_t := 0.0                # seconds since the glass broke (iteration 28)

var mag_stage := 0                   # 0 the whole glass: break it. 1 broken: look through what is left, let go to be rid of it (iteration 27)

var mag_broken: MeshInstance3D = null    # the game's own broken-glass model, on the held glass

var mag_mask: ImageTexture = null    # the pieces of glass that are left, as a picture

var mag_lens_c := Vector3.ZERO       # the whole glass's middle and radius (the item's own space)

var mag_lens_rad := 1.0

var mag_hidden := {}                 # what we hid when the glass broke (node -> its layers)

# ---- the magnifying glass (iteration 27): smash it on the table; it breaks into the game's own broken-glass model, and what is
# left of the glass is a window onto the shell in the open breech. Let go of it and it is gone.
func _rit_mag_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var ws := world_scale
	var ref := _item_ref(par)
	var gun_ok: bool = (gun_state == 0 or _gun_held_free()) and gun_main != null and is_instance_valid(gun_main) \
		and not (gun_state == 0 and not gun_main.visible)
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	var seq = rm.get("shellSpawner").get("sequenceArray") if rm != null else null
	var seq_ok: bool = (seq is Array) and not seq.is_empty() and xr_cam != null and is_instance_valid(xr_cam)
	if mag_stage == 0 and not (gun_ok and seq_ok):
		return 2
	var pxf := par.global_transform
	var ty := _item_table_y()
	if not mag_vel_ok:
		mag_prev_ref = ref
		mag_vel = Vector3.ZERO
		mag_vel_ok = true
	mag_vel = mag_vel.lerp((ref - mag_prev_ref) / maxf(delta, 0.0001), 1.0 - exp(-delta * 25.0))
	mag_prev_ref = ref
	if mag_stage == 0:
		# the whole glass: nothing to see through it yet. It has to be broken first: a downward stroke onto the table.
		_hint_tut("mag_break", "BREAK THE GLASS", ref + Vector3.UP * (0.13 * ws))
		var low := INF
		for i in 8:
			low = minf(low, (pxf * item_loc.get_endpoint(i)).y)
		if low <= ty + MAG_SMASH_NEAR_M * ws and mag_vel.y < -MAG_SMASH_V * ws:
			_mag_break(hh, par, ref, maxf(ty, low))
		return 0
	# broken: the shell in the open breech shows through what is left of the glass (for MAG_LIFE_S seconds)
	mag_life_t += delta
	if mag_life_t >= MAG_LIFE_S:
		print("VRBoot: the broken glass is gone after ", MAG_LIFE_S, " s")
		return _mag_gone(hh, par)
	if gun_ok and seq_ok:
		var lens := _mag_lens(par)
		var lc: Vector3 = lens[0]
		var ln: Vector3 = lens[1]
		var lr: float = lens[2]
		var breech := _mag_breech()
		_mag_view_update(str(seq[0]), breech, lc, ln, lr, delta, lens[3], lens[4])
		var eye := xr_cam.global_position
		var d := breech - eye
		var den := ln.dot(d)
		var inside := false
		if absf(den) > 0.0001:
			var t := ln.dot(lc - eye) / den
			if t > 0.05 and t < 0.98:
				inside = (eye + d * t).distance_to(lc) <= lr * 0.85
		if inside and not mag_seen:
			mag_seen_t += delta
			rit_haptic_t -= delta
			if rit_haptic_t <= 0.0:
				rit_haptic_t = 0.08
				hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.1 + 0.3 * clampf(mag_seen_t / MAG_SEE_S, 0.0, 1.0), 0.04, 0.0)
			if mag_seen_t >= MAG_SEE_S:
				mag_seen = true
				print("VRBoot: the shell (", str(seq[0]), ") was seen through the broken magnifying glass")
		if gun_state == 0 and gun_rest_ok:
			_pk_flat(gun_rest_box)
	else:
		_mag_view_hide()
	if item_t >= TITEM_MIN_S and not hh.grip_sq:
		return _mag_gone(hh, par)
	return 0

# Where the glass is: [middle, which way it faces, radius, and (broken only) the glass's own across / up axes divided by its
# width, for the picture of what is left of it].
func _mag_lens(par: Node3D) -> Array:
	var pxf := par.global_transform
	var n := (pxf.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	var sc := pxf.basis.get_scale()
	if mag_mask != null and mag_broken != null and is_instance_valid(mag_broken):
		var c: Vector3 = pxf * mag_lens_c
		var u := (pxf.basis * Vector3(0.0, 0.0, 1.0)).normalized() / (2.0 * mag_lens_rad * sc.z)
		var v := (pxf.basis * Vector3(0.0, 1.0, 0.0)).normalized() / (2.0 * mag_lens_rad * sc.y)
		return [c, n, mag_lens_rad * sc.z, u, v]
	var c2: Vector3 = pxf * (item_loc.position + item_loc.size * Vector3(0.5, MAG_LENS_Y, 0.5))
	var r2: float = item_loc.size.z * 0.5 * sc.z * MAG_LENS_R
	return [c2, n, r2, Vector3.ZERO, Vector3.ZERO]

func _mag_break(hh: Hand, par: Node3D, ref: Vector3, floor_y: float) -> void:
	_tut_done("mag_break")
	var swapped := _mag_swap(par)
	mag_stage = 1
	mag_life_t = 0.0
	mag_seen = false
	mag_seen_t = 0.0
	var pxf := par.global_transform
	var lens := _mag_lens(par)
	var lc: Vector3 = lens[0]
	var ln: Vector3 = lens[1]
	var lr: float = lens[2]
	var upv := (pxf.basis * Vector3(0.0, 1.0, 0.0)).normalized()
	_fx_shatter(lc + upv * (lr * 0.6), ln, lr * 0.45, ref, floor_y)      # the part of the glass that is missing flies off
	var snd := _anim_stream("player use magnifier", "magnifier")
	if snd == null:
		snd = _anim_stream("player use magnifier", "crack")
	_fx_play(snd)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.2, 0.0)
	print("VRBoot: magnifying glass smashed on the table", " - the game's broken glass is in the hand now" if swapped else "")

# The whole glass is hidden and the game's own broken-glass model is put where it was (a child, so it goes with the hand).
func _mag_swap(par: Node3D) -> bool:
	var src: MeshInstance3D = null
	if cur_scene != null:
		src = cur_scene.find_child("magnifying glass broken", true, false) as MeshInstance3D
	if src == null or src.mesh == null:
		return false
	var lens := par.get_node_or_null("magnifying glass lens") as MeshInstance3D
	mag_lens_c = MAG_LENS_C
	mag_lens_rad = MAG_LENS_RAD
	if lens != null and lens.mesh != null:
		var lb := lens.mesh.get_aabb()
		mag_lens_c = lens.transform * lb.get_center()
		mag_lens_rad = lb.size.z * 0.5
	var b := MeshInstance3D.new()
	b.name = "VRBootMagBroken"
	b.mesh = src.mesh
	b.material_override = src.material_override
	for i in src.mesh.get_surface_count():
		var m := src.get_surface_override_material(i)
		if m != null:
			b.set_surface_override_material(i, m)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.layers = par.layers
	b.position = MAG_ANIM_OFF
	par.add_child(b)
	mag_hidden.clear()
	mag_hidden[par] = par.layers
	par.layers = 0
	if lens != null:
		mag_hidden[lens] = lens.layers
		lens.layers = 0
	mag_broken = b
	mag_mask = _mag_build_mask(src.mesh)
	return true

# What is left of the glass, as a picture (white = glass): the game's broken model, the glass part of it, seen from the side
# the glass faces. If its triangles cannot be read, the whole round glass without its top is used instead.
func _mag_build_mask(mesh: Mesh) -> ImageTexture:
	var data := PackedByteArray()
	var surf := -1
	var am := mesh as ArrayMesh
	if am != null:
		for i in am.get_surface_count():
			if am.surface_get_name(i) == MAG_LENS_SURF:
				surf = i
	if surf < 0:
		surf = mesh.get_surface_count() - 1
	if surf >= 0:
		var arr := mesh.surface_get_arrays(surf)
		if arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] is PackedVector3Array:
			var ix := PackedInt32Array()
			if arr.size() > Mesh.ARRAY_INDEX and arr[Mesh.ARRAY_INDEX] is PackedInt32Array:
				ix = arr[Mesh.ARRAY_INDEX]
			data = _mag_raster(arr[Mesh.ARRAY_VERTEX], ix)
	var lit := 0
	for i in data.size():
		if data[i] > 0:
			lit += 1
	if data.size() != MAG_MASK_N * MAG_MASK_N or lit < MAG_MASK_N * MAG_MASK_N / 40:
		data = _mag_raster_fallback()
		print("VRBoot: the broken glass's triangles could not be read - the round glass without its top is used")
	var img := Image.create_from_data(MAG_MASK_N, MAG_MASK_N, false, Image.FORMAT_L8, data)
	return ImageTexture.create_from_image(img)

# Fills the triangles of the glass into a picture of the glass's square (across = the model's z, up = its y).
func _mag_raster(vs: PackedVector3Array, ix: PackedInt32Array) -> PackedByteArray:
	var n := MAG_MASK_N
	var data := PackedByteArray()
	data.resize(n * n)
	var cnt := ix.size() if ix.size() >= 3 else vs.size()
	var tri_n := int(cnt / 3.0)
	var sc := float(n) / (2.0 * mag_lens_rad)
	for t in tri_n:
		var p: Array = []
		for k in 3:
			var vi := ix[t * 3 + k] if ix.size() >= 3 else t * 3 + k
			if vi < 0 or vi >= vs.size():
				p.clear()
				break
			var v := vs[vi]
			p.append(Vector2((v.z + MAG_ANIM_OFF.z - mag_lens_c.z) * sc + n * 0.5, (v.y + MAG_ANIM_OFF.y - mag_lens_c.y) * sc + n * 0.5))
		if p.size() < 3:
			continue
		var a: Vector2 = p[0]
		var b: Vector2 = p[1]
		var c: Vector2 = p[2]
		var den := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
		if absf(den) < 0.00001:
			continue
		var x0 := maxi(int(floorf(minf(minf(a.x, b.x), c.x) - 0.5)), 0)
		var x1 := mini(int(ceilf(maxf(maxf(a.x, b.x), c.x) + 0.5)), n - 1)
		var y0 := maxi(int(floorf(minf(minf(a.y, b.y), c.y) - 0.5)), 0)
		var y1 := mini(int(ceilf(maxf(maxf(a.y, b.y), c.y) + 0.5)), n - 1)
		for py in range(y0, y1 + 1):
			for px in range(x0, x1 + 1):
				var qx := px + 0.5
				var qy := py + 0.5
				var l1 := ((b.y - c.y) * (qx - c.x) + (c.x - b.x) * (qy - c.y)) / den
				var l2 := ((c.y - a.y) * (qx - c.x) + (a.x - c.x) * (qy - c.y)) / den
				var l3 := 1.0 - l1 - l2
				if l1 >= -0.002 and l2 >= -0.002 and l3 >= -0.002:    # (a pixel exactly on an edge counts for both sides: no hairline gaps)
					data[py * n + px] = 255
	return data

func _mag_raster_fallback() -> PackedByteArray:
	var n := MAG_MASK_N
	var data := PackedByteArray()
	data.resize(n * n)
	for py in n:
		for px in n:
			var lz := ((px + 0.5) / n - 0.5) * 2.0
			var ly := ((py + 0.5) / n - 0.5) * 2.0
			if lz * lz + ly * ly <= 0.96 and ly <= 0.52:
				data[py * n + px] = 255
	return data

# The broken glass is let go: it falls to the table, lies a moment and fades away (it does not shrink), and the item is spent.
func _mag_gone(hh: Hand, par: Node3D) -> int:
	var ws := world_scale
	if mag_broken != null and is_instance_valid(mag_broken):
		var c := _fx_clone_visual(mag_broken)
		var v := Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2)) * ws
		_fx_fall(c, v, Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)), item_floor_y + 0.05 * ws, 1.0, true)
		fx_list[fx_list.size() - 1]["fadet"] = true
	if not _titem_consume(par, "magnifying glass", false):
		return 2
	_titem_end(false, "broken glass let go")
	_perm_back()
	print("VRBoot: the broken magnifying glass was let go - it is gone")
	return 1

# The open breech of the shotgun (where the game shows the shell), on the gun on the table or the one in your hand.
func _mag_breech() -> Vector3:
	var ex := cur_scene.find_child("shell examine", true, false) if cur_scene != null else null
	if ex != null:
		var sh = ex.get("shellParent")
		if sh is Node3D and is_instance_valid(sh):
			return _gun_stand_in(sh as Node3D).global_position
	return _gun_xf() * Vector3(0.0, 0.5, 0.0)

func _mag_color(m: Material, fallback: Color) -> Color:
	if m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		if sm.emission_enabled and sm.emission.get_luminance() > sm.albedo_color.get_luminance():
			return sm.emission
		return sm.albedo_color
	return fallback

# The shell as a model, one material per surface, all drawn through the lens window (MAG_SHADER).
func _mag_view_make(shell: String) -> void:
	_mag_view_free()
	var ex := cur_scene.find_child("shell examine", true, false) if cur_scene != null else null
	var src_mesh: MeshInstance3D = null
	if ex != null:
		var m = ex.get("mesh")
		if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
			src_mesh = m
	var live_col := Color(0.9, 0.1, 0.08)
	var blank_col := Color(0.15, 0.3, 0.95)
	var brass_col := Color(0.78, 0.58, 0.2)
	mag_view = MeshInstance3D.new()
	mag_view.name = "VRBootMagShell"
	mag_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mag_view.extra_cull_margin = 4096.0
	if mag_shader == null:
		mag_shader = Shader.new()
		mag_shader.code = MAG_SHADER
	var cols: Array = []
	if src_mesh != null:
		mag_view.mesh = src_mesh.mesh
		for i in src_mesh.mesh.get_surface_count():
			if i == 1:
				var tm = ex.get("mat_live") if shell == "live" else ex.get("mat_blank")
				cols.append(_mag_color(tm, live_col if shell == "live" else blank_col))
			else:
				cols.append(_mag_color(src_mesh.get_active_material(i), brass_col))
	else:
		var cyl := CylinderMesh.new()                    # (no model found: a plain round shell)
		cyl.top_radius = 0.5
		cyl.bottom_radius = 0.5
		cyl.height = 2.0
		mag_view.mesh = cyl
		cols.append(live_col if shell == "live" else blank_col)
	mag_mats.clear()
	for i in cols.size():
		var sm := ShaderMaterial.new()
		sm.shader = mag_shader
		sm.render_priority = 110
		sm.set_shader_parameter("base_col", cols[i])
		mag_view.set_surface_override_material(i, sm)
		mag_mats.append(sm)
	var bb: AABB = mag_view.mesh.get_aabb()
	var li := 0
	for i in 3:
		if bb.size[i] > bb.size[li]:
			li = i
	mag_long = maxf(bb.size[li], 0.0001)
	mag_center = bb.get_center()
	var lax := Vector3.ZERO
	lax[li] = 1.0
	mag_orient = Basis(Quaternion(lax, Vector3.UP))
	mag_shell = shell
	fx_root.add_child(mag_view)

func _mag_view_free() -> void:
	if mag_view != null and is_instance_valid(mag_view):
		mag_view.queue_free()
	mag_view = null
	mag_mats.clear()
	mag_shell = ""

func _mag_view_hide() -> void:
	if mag_view != null and is_instance_valid(mag_view):
		mag_view.visible = false

func _mag_view_update(shell: String, breech: Vector3, lens_c: Vector3, lens_n: Vector3, lens_r: float, delta: float, \
		lens_u := Vector3.ZERO, lens_v := Vector3.ZERO) -> void:
	if mag_view == null or not is_instance_valid(mag_view) or mag_shell != shell:
		_mag_view_make(shell)
	mag_spin = fmod(mag_spin + delta * 2.2, TAU)
	var gb := _gun_xf().basis.orthonormalized()
	var sc := (MAG_SHELL_M * world_scale) / mag_long
	var bs := gb * Basis(Vector3.UP, mag_spin) * mag_orient * Basis.from_scale(Vector3.ONE * sc)
	mag_view.global_transform = Transform3D(bs, breech - bs * mag_center)
	mag_view.visible = true
	var um := 1.0 if (mag_mask != null and lens_u.length_squared() > 0.0) else 0.0
	for m in mag_mats:
		var sm := m as ShaderMaterial
		sm.set_shader_parameter("lens_c", lens_c)
		sm.set_shader_parameter("lens_n", lens_n)
		sm.set_shader_parameter("lens_r", lens_r)
		sm.set_shader_parameter("lens_u", lens_u)
		sm.set_shader_parameter("lens_v", lens_v)
		sm.set_shader_parameter("use_mask", um)
		if mag_mask != null:
			sm.set_shader_parameter("lens_mask", mag_mask)

# The glass is gone, put back or the turn ended: nothing is seen any more, the whole glass is back as it was.
func _mag_reset() -> void:
	mag_seen = false
	mag_seen_t = 0.0
	mag_vel_ok = false
	for n in mag_hidden.keys():
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			(n as VisualInstance3D).layers = int(mag_hidden[n])
	mag_hidden.clear()
	if mag_broken != null and is_instance_valid(mag_broken) and not mag_broken.is_queued_for_deletion():
		mag_broken.queue_free()
	mag_broken = null
	mag_mask = null
	mag_stage = 0
	mag_life_t = 0.0
	_mag_view_free()
