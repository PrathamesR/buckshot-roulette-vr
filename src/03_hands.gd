# The hands: building, shaders, poses, inputs, per-frame visuals
# (Part of the Buckshot Roulette VR mod. Chain position 03: this file extends 02_common.gd; see src/README.md.)
extends "02_common.gd"

const LASER_IDLE_M := 4.0                          # laser length when it hits nothing (metres)

const HAND_DIR := "user://vr_mod/hands/"           # the game's hand meshes, extracted next to this script

const HAND_M_PER_UNIT := 0.0475                    # the dealer's hand mesh is 4.0 units long; a real hand is ~0.19 m

const HAND_PITCH_DEG := 0.0                        # tilt the hand up (+) or down (-) in the grip frame

const TIP_RIGHT := Vector3(0.0267, 0.0181, -0.1363)   # the index fingertip in the controller's grip frame (metres)

const GRIP_ON := 0.6

const GRIP_OFF := 0.4

const HAND_TONE := 0.58                            # how bright the skin ends up on screen (after the game's colour grading)

const HAND_FORM := 0.45                            # edge darkening that gives the flat-lit hand some shape

# The game grades its picture (brightness 1.49, contrast 0.8, saturation 0.26, ACES) after everything is
# drawn, which turns an unlit skin texture into plain white. This shader works backwards through that
# grading so the hand lands on the screen as the skin texture's own colour.
const HAND_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform float has_skin = 1.0;
uniform vec3 base_col = vec3(0.90, 0.72, 0.47);
uniform float tone = 0.58;
uniform float form = 0.45;
uniform vec3 bcs = vec3(1.49, 0.8, 0.26);
uniform float aces_on = 1.0;
vec3 lin_to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 srgb_to_lin(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 inv_tonemap(vec3 y) {
	if (aces_on < 0.5) {
		return y;
	}
	vec3 yw = clamp(y, vec3(0.0), vec3(0.97)) * 0.78107;
	vec3 qa = vec3(1.0) - yw * 0.983729;
	vec3 qb = vec3(0.0245786) - yw * 0.432951;
	vec3 qc = vec3(0.000090537) + yw * 0.238081;
	vec3 a = (-qb + sqrt(qb * qb + 4.0 * qa * qc)) / (2.0 * qa);
	return a / 1.8;
}
void fragment() {
	vec3 raw = base_col;
	if (has_skin > 0.5) {
		raw = lin_to_srgb(texture(skin, UV).rgb);
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 t = raw * tone * mix(1.0 - form, 1.0, sqrt(facing));
	vec3 m = vec3((t.r + t.g + t.b) / 3.0);
	vec3 c2 = m + (t - m) / max(bcs.z, 0.05);
	vec3 c1 = vec3(0.5) + (c2 - vec3(0.5)) / max(bcs.y, 0.05);
	vec3 p = clamp(c1 / max(bcs.x, 0.05), 0.0, 1.0);
	ALBEDO = inv_tonemap(srgb_to_lin(p));
}
"""

# The same hand, lit like every other thing in the room: it takes the colour and brightness of the game's
# own lights (dim in the lobby, warm and bright at the table, a flash when the shotgun fires). A little
# self-light keeps it from ever going completely black.
const HAND_LIT_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform float has_skin = 1.0;
uniform vec3 base_col = vec3(0.90, 0.72, 0.47);
uniform float tone = 0.58;
uniform float form = 0.45;
uniform vec3 bcs = vec3(1.49, 0.8, 0.26);
uniform float aces_on = 1.0;
uniform float lit_gain = 1.0;
uniform float lit_floor = 0.12;
vec3 srgb_to_lin2(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	vec3 a = srgb_to_lin2(base_col);
	if (has_skin > 0.5) {
		a = texture(skin, UV).rgb;
	}
	ALBEDO = a * lit_gain;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	EMISSION = ALBEDO * lit_floor;
}
"""

# Finger bending for the hand poses. These numbers describe the dealer's open right hand (measured from
# the mesh): HP_D runs along the fingers (wrist -> tip is -D), HP_N is the palm normal, HP_L runs across
# the hand, and HP_A is the axis every finger joint bends around. Per finger:
#   [L_from, L_to, D of knuckle, D of middle joint, D of fingertip joint, then (N, L) of each of the three joints]
const HP_N := Vector3(-0.15119447, -0.92701735, 0.34318955)

const HP_D := Vector3(-0.98850404, 0.14178990, -0.05249180)

const HP_L := Vector3(0.0, -0.34718073, -0.93779824)

const HP_A := Vector3(0.0, 0.34718073, 0.93779824)

const HP_FINGERS := {
	"index": [-0.8, 0.05, 0.26, 0.86, 1.45, -0.712223, -0.172634, -0.867502, -0.267827, -0.791558, -0.33342],
	"middle": [0.05, 0.6, 0.3, 0.95, 1.61, -0.560131, 0.356102, -0.674063, 0.345247, -0.756383, 0.378752],
	"ring": [0.6, 1.22, 0.3, 0.73, 1.26, -0.485271, 0.947405, -0.525929, 0.908926, -0.534899, 1.017669],
	"pinky": [1.22, 9.0, 0.24, 0.8, 1.2, -0.388581, 1.373762, -0.24186, 1.544081, -0.183822, 1.625875],
}

const HP_CURL := Vector3(1.3962634, 1.6580628, 1.0471976)   # knuckle 80, middle joint 95, tip joint 60 degrees

const HP_RAMP := 0.2                                         # how smoothly a joint bends along the finger

const HP_EDGE := 0.07                                        # how smoothly one finger hands over to the next

# The hand shapes (which fingers are curled). "fist" is the game's own fist mesh.
const POSES := {
	"open": [],
	"point": ["middle", "ring", "pinky"],
	"trigger": ["index"],
	"thumbsup": ["index", "middle", "ring", "pinky"],
	"flip": ["index", "ring", "pinky"],
}

var laser_on := false              # the laser is drawn this frame

var pose_meshes := {}              # "R_point", "L_open", ... -> mesh built from the dealer's open right hand

var hand_shader: Shader

var hand_mats: Array = []          # the ShaderMaterials on the hands (their grading is refreshed a few times a second)

var grade_t := 0.0

var skin_logged := false

var hand_dirty := false

var hand_shader_lit: Shader

func _make_hand(side: String, color: Color) -> Hand:
	var h := Hand.new()
	h.side = side
	h.tip_local = TIP_RIGHT if side == "right" else Vector3(-TIP_RIGHT.x, TIP_RIGHT.y, TIP_RIGHT.z)
	var tracker := "left_hand" if side == "left" else "right_hand"

	h.grip = XRController3D.new()
	h.grip.name = "Grip_" + side
	h.grip.tracker = tracker
	origin.add_child(h.grip)

	h.aim = XRController3D.new()
	h.aim.name = "Aim_" + side
	h.aim.tracker = tracker
	h.aim.pose = "aim"
	origin.add_child(h.aim)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	var vis := Node3D.new()
	var box_root := Node3D.new()
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.035, 0.13)
	body.mesh = box
	body.position = Vector3(0, 0, 0.03)
	body.material_override = mat
	box_root.add_child(body)
	var tip := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.02
	ball.height = 0.04
	tip.mesh = ball
	tip.position = Vector3(0, 0, -0.05)
	tip.material_override = mat
	box_root.add_child(tip)
	vis.add_child(box_root)
	h.box_root = box_root
	h.grip.add_child(vis)
	h.visual = vis

	h.laser_mat = StandardMaterial3D.new()
	h.laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h.laser_mat.albedo_color = Color(1, 1, 1)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.003
	cyl.bottom_radius = 0.003
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	h.laser = MeshInstance3D.new()
	h.laser.mesh = cyl
	h.laser.material_override = h.laser_mat
	h.laser.visible = false
	fx_root.add_child(h.laser)
	return h

func _make_dot() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1)
	mat.no_depth_test = true
	var s := SphereMesh.new()
	s.radius = 0.01
	s.height = 0.02
	s.radial_segments = 8
	s.rings = 4
	dot = MeshInstance3D.new()
	dot.mesh = s
	dot.material_override = mat
	dot.visible = false
	fx_root.add_child(dot)


# ------------------------------------------------------------------ the game's own hands

# The dealer's hand meshes were copied out of the game next to this script (vr_mod/hands/*.tres).
# They only hold the mesh and a reference to the game's skin texture; the texture itself is read
# from the game at run time. If the files are missing we borrow the meshes from the table scene.
func _load_hand_resources() -> void:
	for key in ["right_open", "left_open", "right_fist"]:
		var path: String = HAND_DIR + "hand_%s.tres" % key
		if not ResourceLoader.exists(path):
			continue
		var m := ResourceLoader.load(path) as Mesh
		if m == null:
			print("VRBoot: could not load hand model ", path)
			continue
		hand_res[key] = m
	print("VRBoot: hand models loaded: ", hand_res.keys())

# Fallback: take the meshes straight from the running table scene.
func _capture_hands_from_scene() -> void:
	if cur_scene == null or hand_res.has("right_open"):
		return
	var base := cur_scene.get_node_or_null("dealer hands main1/dealer hands parent")
	if base == null:
		return
	var spec := {
		"right_open": "hand parent_right/dealer hand right_default",
		"left_open": "hand parent left/dealer hand left_default",
		"right_fist": "hand parent_right/dealer hand right_fist",
	}
	for key in spec:
		var mi := base.get_node_or_null(str(spec[key])) as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var m := mi.mesh.duplicate() as Mesh
		m.set_meta("vr_scale", mi.transform.basis.get_scale().x)
		hand_res[key] = m
	hand_dirty = true
	print("VRBoot: borrowed hand models from the scene: ", hand_res.keys())

func _rebuild_hand_visuals() -> void:
	hand_dirty = false
	hand_mats.clear()
	if pose_meshes.is_empty():
		_build_pose_meshes()
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		for k in hh.poses:
			(hh.poses[k] as Node).queue_free()
		hh.poses.clear()
		hh.pose = ""
		var is_left := hh.side == "left"
		var prefix := "L_" if is_left else "R_"
		if not pose_meshes.is_empty():
			var open_mesh: Mesh = pose_meshes[prefix + "open"]
			var skin := _make_hand_material(open_mesh.surface_get_material(0))
			for pname in POSES:
				var mi := _make_hand_mi(pose_meshes[prefix + str(pname)], is_left, false, skin)
				mi.visible = false
				hh.visual.add_child(mi)
				hh.poses[pname] = mi
			if hand_res.has("right_fist"):
				var fm: Mesh = hand_res["right_fist"]
				var fmi := _make_hand_mi(fm, is_left, true, _make_hand_material(fm.surface_get_material(0)))
				fmi.visible = false
				hh.visual.add_child(fmi)
				hh.poses["fist"] = fmi
			(hh.poses["open"] as MeshInstance3D).visible = true
			hh.pose = "open"
		hh.box_root.visible = hh.poses.is_empty()

# One mesh per hand shape and side: "R_point", "L_thumbsup", ... Built from the dealer's open right hand by
# bending the finger joints; the left hand is the same thing mirrored.
func _build_pose_meshes() -> void:
	pose_meshes.clear()
	if not hand_res.has("right_open"):
		return
	var src: Mesh = hand_res["right_open"]
	var ns := float(src.get_meta("vr_scale", 1.0))
	var bb := src.get_aabb()
	var palm := Vector3(bb.end.x - 1.0 / ns, bb.get_center().y, bb.get_center().z)
	var t0 := Time.get_ticks_msec()
	for pname in POSES:
		var curled: Array = POSES[pname]
		pose_meshes["R_" + str(pname)] = src if curled.is_empty() else _build_pose_mesh(src, curled, false, palm)
		pose_meshes["L_" + str(pname)] = _build_pose_mesh(src, curled, true, palm)
	print("VRBoot: hand shapes built: ", POSES.keys(), " in ", Time.get_ticks_msec() - t0, " ms")

func _build_pose_mesh(src: Mesh, curled: Array, mirror: bool, palm: Vector3) -> ArrayMesh:
	var arr: Array = src.surface_get_arrays(0)
	var res := _deform_hand(arr[Mesh.ARRAY_VERTEX], arr[Mesh.ARRAY_NORMAL], curled)
	var ov: PackedVector3Array = res[0]
	var on: PackedVector3Array = res[1]
	var oi: PackedInt32Array = (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
	var op := palm
	if mirror:
		# a mirror image turns the triangles inside out: flip the vertex order back
		for i in ov.size():
			var v := ov[i]
			v.z = -v.z
			ov[i] = v
			var nn := on[i]
			nn.z = -nn.z
			on[i] = nn
		var t := 0
		while t + 2 < oi.size():
			var tmp := oi[t + 1]
			oi[t + 1] = oi[t + 2]
			oi[t + 2] = tmp
			t += 3
		op.z = -op.z
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = ov
	out[Mesh.ARRAY_NORMAL] = on
	if arr[Mesh.ARRAY_TEX_UV] != null:
		out[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_INDEX] = oi
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	m.surface_set_material(0, src.surface_get_material(0))
	m.set_meta("vr_scale", src.get_meta("vr_scale", 1.0))
	m.set_meta("palm", op)
	return m

# Bends the listed fingers of the open right hand. Returns [vertices, normals].
func _deform_hand(verts: PackedVector3Array, norms: PackedVector3Array, curled: Array) -> Array:
	var out_v := verts.duplicate()
	var out_n := norms.duplicate()
	var count := verts.size()
	var axis := HP_A.normalized()
	for fname in curled:
		var f: Array = HP_FINGERS[fname]
		var l0: float = f[0]
		var l1: float = f[1]
		for i in count:
			var p := verts[i]
			var lv := p.dot(HP_L)
			var w := smoothstep(l0 - HP_EDGE, l0 + HP_EDGE, lv) * (1.0 - smoothstep(l1 - HP_EDGE, l1 + HP_EDGE, lv))
			if w <= 0.0001:
				continue
			var dv := p.dot(HP_D)
			var q := p
			var qn := norms[i]
			for jidx in [2, 1, 0]:
				var dj: float = f[2 + jidx]
				var s := smoothstep(dj - HP_RAMP, dj + HP_RAMP, dv)
				if s <= 0.0:
					continue
				var rot := Basis(axis, HP_CURL[jidx] * s)
				var jp := HP_D * dj + HP_N * float(f[5 + jidx * 2]) + HP_L * float(f[6 + jidx * 2])
				q = jp + rot * (q - jp)
				qn = rot * qn
			out_v[i] = out_v[i] + (q - p) * w
			out_n[i] = out_n[i] + (qn - norms[i]) * w
	for i in count:
		out_n[i] = out_n[i].normalized()
	return [out_v, out_n]

# Puts a hand mesh into the controller's grip frame (-Z = fingers forward, +Y = thumb up).
# The dealer's meshes: fingers along -X, palm side -Y (the fingers curl towards it), wrist cut at +X.
# right_open has its thumb at +Z, which makes it a right hand; the fist has it at -Z (a left hand).
func _make_hand_mi(mesh: Mesh, is_left: bool, is_fist: bool, mat: Material) -> MeshInstance3D:
	var ns := float(mesh.get_meta("vr_scale", 1.0))
	var bb := mesh.get_aabb()
	# right hand: thumb (+Z) up, palm (-Y) turned to the left (towards the body)
	var rx := Vector3(0.0, 0.0, 1.0)
	var ry := Vector3(1.0, 0.0, 0.0)
	var rz := Vector3(0.0, 1.0, 0.0)
	if is_left:
		# left hand: thumb (-Z) up, palm (-Y) turned to the right
		ry = Vector3(-1.0, 0.0, 0.0)
		rz = Vector3(0.0, -1.0, 0.0)
	var flip := Basis.IDENTITY
	if is_fist and not is_left:
		flip = Basis.from_scale(Vector3(1.0, 1.0, -1.0))   # the fist mesh is a left hand: mirror it for the right
	var lin := Basis(Vector3.RIGHT, deg_to_rad(HAND_PITCH_DEG)) * Basis(rx, ry, rz) * flip \
		* Basis.from_scale(Vector3.ONE * (HAND_M_PER_UNIT * ns))
	# the middle of the palm sits on the controller's grip point (shapes built from the open hand share its anchor)
	var palm := Vector3(bb.end.x - 1.0 / ns, bb.get_center().y, bb.get_center().z)
	if mesh.has_meta("palm"):
		palm = mesh.get_meta("palm")
	var mi := MeshInstance3D.new()
	mi.name = "VRBootHand_" + ("left" if is_left else "right") + ("_fist" if is_fist else "")
	mi.mesh = mesh
	mi.transform = Transform3D(lin, -(lin * palm))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, mat)
	return mi

func _hand_shader() -> Shader:
	if hand_lit:
		if hand_shader_lit == null:
			hand_shader_lit = Shader.new()
			hand_shader_lit.code = HAND_LIT_SHADER
		return hand_shader_lit
	if hand_shader == null:
		hand_shader = Shader.new()
		hand_shader.code = HAND_SHADER
	return hand_shader

func _apply_hand_shader() -> void:
	var sh := _hand_shader()
	for m in hand_mats:
		(m as ShaderMaterial).shader = sh

func _make_hand_material(src: Material) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _hand_shader()
	var tex: Texture2D = null
	if src is BaseMaterial3D:
		tex = (src as BaseMaterial3D).albedo_texture
	if tex == null:
		var fallback_path := "res://models/dealer hands main/dealer hands main1_skin base hand_left.png"
		if ResourceLoader.exists(fallback_path):
			tex = ResourceLoader.load(fallback_path) as Texture2D
	if tex != null:
		sm.set_shader_parameter("skin", tex)
		sm.set_shader_parameter("has_skin", 1.0)
	else:
		sm.set_shader_parameter("has_skin", 0.0)
	sm.set_shader_parameter("tone", HAND_TONE)
	sm.set_shader_parameter("form", HAND_FORM)
	hand_mats.append(sm)
	grade_t = 0.0
	if not skin_logged:
		skin_logged = true
		print("VRBoot: hand skin texture ", "%dx%d" % [tex.get_width(), tex.get_height()] if tex != null else "MISSING (plain colour)")
	return sm

# Keeps the hands' (and the pause menu's) colour matched to the game's current grading (it animates in some scenes).
func _update_hand_grade(delta: float) -> void:
	grade_t -= delta
	if grade_t > 0.0 or (hand_mats.is_empty() and pause_mat == null and help_mat == null):
		return
	grade_t = 0.25
	var bcs := Vector3(1.0, 1.0, 1.0)
	var aces := 0.0
	var world := get_tree().root.world_3d
	var env: Environment = world.environment if world != null else null
	if env != null:
		if env.adjustment_enabled:
			bcs = Vector3(env.adjustment_brightness, env.adjustment_contrast, env.adjustment_saturation)
		aces = 1.0 if env.tonemap_mode == Environment.TONE_MAPPER_ACES else 0.0
		if not env_logged:
			env_logged = true
			print("VRBoot: environment: fog=", env.fog_enabled, " density=", env.fog_density, " colour=", env.fog_light_color,
				" volumetric=", env.volumetric_fog_enabled, " glow=", env.glow_enabled, " tonemap=", env.tonemap_mode)
	for m in hand_mats:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("bcs", bcs)
		sm.set_shader_parameter("aces_on", aces)
	var retro_on := 1.0 if (retro_look and retro_levels != Vector3.ZERO) else 0.0
	if pause_mat != null:
		pause_mat.set_shader_parameter("bcs", bcs)
		pause_mat.set_shader_parameter("aces_on", aces)
		pause_mat.set_shader_parameter("retro", retro_on)
	if help_mat != null:
		help_mat.set_shader_parameter("bcs", bcs)
		help_mat.set_shader_parameter("aces_on", aces)
		help_mat.set_shader_parameter("retro", retro_on)

func _update_hand_poses() -> void:
	if hand_dirty:
		_rebuild_hand_visuals()
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		var active: bool = hh.grip.get_is_active()
		if active != hh.was_active:
			hh.was_active = active
			print("VRBoot: ", hh.side, " controller ", "tracked" if active else "lost",
				"  aim_pose_ok=", hh.aim.get_has_tracking_data())
		hh.visual.visible = active
		if hh != gun_hand and hh != gun_sup_hand and hh != gun_pump_hand:
			hh.visual.transform = Transform3D(Basis.from_scale(Vector3.ONE * world_scale), Vector3.ZERO)   # back on the controller
		if not active:
			continue
		_read_hand_inputs(hh)
		if not hh.poses.is_empty():
			var want := _choose_pose(hh)
			if want != hh.pose:
				for k in hh.poses:
					(hh.poses[k] as MeshInstance3D).visible = str(k) == want
				hh.pose = want
				if not hh.pose_seen.has(want):
					hh.pose_seen[want] = true
					print("VRBoot: ", hh.side, " hand shape: ", want)
		var src: XRController3D = hh.aim if hh.aim.get_has_tracking_data() else hh.grip
		var t := src.global_transform
		hh.ray_o = t.origin
		hh.ray_d = (-t.basis.z).normalized()
	if not active_hand.was_active:
		if left_hand.was_active and not right_hand.was_active:
			active_hand = left_hand
		elif right_hand.was_active:
			active_hand = right_hand

# Squeeze and thumb state for the hand shapes. Thumb contact needs the touch sensors; the log says
# whether this headset's controllers report them.
func _read_hand_inputs(hh: Hand) -> void:
	var c := hh.grip
	var g := c.get_float("grip")
	if hh.grip_sq:
		if g < GRIP_OFF:
			hh.grip_sq = false
	elif g > GRIP_ON:
		hh.grip_sq = true
	hh.thumb_on = c.is_button_pressed("ax_touch") or c.is_button_pressed("by_touch") \
		or c.is_button_pressed("primary_touch") or c.is_button_pressed("ax_button") \
		or c.is_button_pressed("by_button") or c.is_button_pressed("primary_click")
	hh.active_frames += 1
	if hh.active_frames == 90:
		var have := []
		for nm in ["trigger_touch", "grip_touch", "ax_touch", "by_touch", "primary_touch"]:
			if c.get_input(nm) != null:
				have.append(nm)
		hh.touch_ok = c.get_input("ax_touch") != null and c.get_input("by_touch") != null
		print("VRBoot: ", hh.side, " controller touch sensors reported: ", have,
			"  thumbs-up shape ", "on" if hh.touch_ok else "off (no thumb sensing; a squeezed fist stays a fist)")

func _choose_pose(hh: Hand) -> String:
	if inv_dealer and hh == item_hand and dealer_key != "" and hh.poses.has(dealer_key):
		return dealer_key
	if hh == gun_hand and gun_state != 0 and gun_prop != null:
		_ensure_gun_pose(hh)
		if hh.poses.has("gun"):
			return "gun"
	var want := "open"
	var trig := hh.trigger_down or hh.grip.get_float("trigger") > 0.6
	if hh.holding:
		want = "fist"
	elif hh.grip_sq:
		if trig:
			if hh.ax_down and hh.by_down:
				want = "flip"
			elif hh.touch_ok and not hh.thumb_on:
				want = "thumbsup"
			else:
				want = "fist"
		else:
			want = "point"
	elif trig:
		want = "trigger"
	elif hh.near_poke:
		want = "point"
	if not hh.poses.has(want):
		want = "open"
	return want


# ------------------------------------------------------------------ pointer

func _update_visuals() -> void:
	var tint := Color(0.85, 0.85, 0.85)
	var hover := 0
	if interaction != null and is_instance_valid(interaction):
		var br = interaction.get("activeInteractionBranch")
		if br != null and is_instance_valid(br) and bool(br.get("interactionAllowed")) and not _hint_hidden(br):
			if bool(br.get("interactionInvalid")):
				tint = Color(1.0, 0.3, 0.3)
				hover = 2
			else:
				tint = Color(0.3, 1.0, 0.4)
				hover = 1
	if ui_active or help_hover:
		tint = Color(0.4, 0.8, 1.0)

	# in the bathroom everything is pressed with a finger: no laser until the pill question appears
	var hide_laser := _physical_only() or (restroom_stage and not ui_active and not pause_open and not help_hover) \
		or not _laser_wanted()
	laser_on = not hide_laser
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		if not hh.was_active or hide_laser or (gun_state != 0 and hh == gun_hand) or hh == item_hand:
			hh.laser.visible = false
			continue
		var is_active := hh == active_hand
		var length := LASER_IDLE_M * world_scale * (1.0 if is_active else 0.3)
		if is_active:
			if ui_active:
				length = last_panel_dist
			elif help_hover:
				length = help_hit_dist
			elif world_hit:
				length = world_hit_dist
		var d := hh.ray_d
		var ref := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
		var bx := ref.cross(d).normalized()
		var bz := bx.cross(d).normalized()
		var thick := world_scale * (1.0 if is_active else 0.5)
		hh.laser.global_transform = Transform3D(Basis(bx * thick, d * length, bz * thick), hh.ray_o + d * (length * 0.5))
		hh.laser_mat.albedo_color = tint if is_active else Color(0.5, 0.5, 0.55)
		hh.laser.visible = true

		if is_active:
			if hover != hh.hover_id and hover != 0:
				hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.04, 0.0)
			hh.hover_id = hover

	var ah := active_hand
	if ah != null and ah.was_active and not hide_laser and (ui_active or help_hover or world_hit):
		dot.visible = true
		var dd := last_panel_dist if ui_active else (help_hit_dist if help_hover else world_hit_dist)
		dot.global_position = ah.ray_o + ah.ray_d * dd
		(dot.material_override as StandardMaterial3D).albedo_color = tint
	else:
		dot.visible = false


# ------------------------------------------------------------------ world size and height by hand (iteration 11)
