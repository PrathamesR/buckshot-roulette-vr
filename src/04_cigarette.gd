# Cigarettes: pack, flick, hold, mouth, burn, smoke
# (Part of the Buckshot Roulette VR mod. Chain position 04: this file extends 03_hands.gd; see src/README.md.)
extends "03_hands.gd"

const CIG_MOUTH_M := 0.12                          # the cigarette (in your fist) this close (real metres) to your mouth...

const CIG_DWELL_S := 0.4                           # ...for this long: it is in your mouth, you are healed at once

const CIG_BURN_S := 10.0                           # the cigarette in your mouth burns down in this time

const CIG_TAKE_M := 0.075                          # the other hand's reach to the cigarette that sticks out of the open pack (real metres)

const CIG_LID_OPEN := -2.79253                     # the game's own "use cigarettes" animation: the lid opens to this (rotation x)...

const CIG_PEEK_Z := -1.70                          # ...and a cigarette slides out this far (its z in the pack's own units; -0.756 = inside)

const CIG_FILTER_Y := 0.52                         # the filter end of the cigarette model (its own y)

const CIG_LEN_M := 0.085                           # its length

var cig_t := -1.0                  # seconds the cigarette in your mouth has burned (-1 = none)

var cig_root: Node3D = null        # ...and what it looks like: paper, ash, ember, smoke

var cig_body: MeshInstance3D = null

var cig_filter: MeshInstance3D = null

var cig_ash: MeshInstance3D = null

var cig_ember: MeshInstance3D = null

var cig_smoke: CPUParticles3D = null

var smoke_tex: Texture2D = null

var cig_pk_state := 0               # 0 pack closed, 1 open (a cigarette sticks out), 2 the other hand holds the cigarette

var cig_pk_lid: Node3D = null

var cig_pk_cig: Node3D = null

var cig_pk_rest := {}

var cig_pk_anim := 0.0

var cig_pk_down := false

# A cigarette (iteration 26, the way the game's own animation does it): flick the pack open, take a cigarette out with the
# OTHER hand, put it in your mouth. It is in your mouth at once (the game's own heal runs now) and burns for CIG_BURN_S.
func _cig_pack_ready(par: Node3D) -> bool:
	if cig_pk_lid != null and is_instance_valid(cig_pk_lid) and cig_pk_cig != null and is_instance_valid(cig_pk_cig) \
			and cig_pk_lid.get_parent() == par:
		return true
	var lid := par.get_node_or_null("cigarette box_lid") as Node3D
	var cg := par.get_node_or_null("cigarette box_cigarette") as Node3D
	if lid == null or cg == null:
		return false
	cig_pk_lid = lid
	cig_pk_cig = cg
	cig_pk_rest = {"lid": lid.rotation, "pos": cg.position, "rot": cg.rotation, "vis": cg.visible}
	cig_pk_state = 0
	cig_pk_anim = 0.0
	cig_pk_down = false
	return true

func _cig_pack_reset() -> void:
	if cig_pk_lid != null and is_instance_valid(cig_pk_lid) and cig_pk_rest.has("lid"):
		cig_pk_lid.rotation = cig_pk_rest["lid"]
	if cig_pk_cig != null and is_instance_valid(cig_pk_cig) and cig_pk_rest.has("pos"):
		cig_pk_cig.position = cig_pk_rest["pos"]
		cig_pk_cig.rotation = cig_pk_rest["rot"]
		cig_pk_cig.visible = bool(cig_pk_rest["vis"])
	cig_pk_lid = null
	cig_pk_cig = null
	cig_pk_rest = {}
	cig_pk_state = 0
	cig_pk_anim = 0.0
	cig_pk_down = false

func _cig_pack_anim(delta: float) -> void:
	cig_pk_anim += delta
	var r: Vector3 = cig_pk_rest["lid"]
	cig_pk_lid.rotation = Vector3(lerpf(r.x, CIG_LID_OPEN, smoothstep(0.0, 0.18, cig_pk_anim)), r.y, r.z)
	if cig_pk_state == 1:
		var p0: Vector3 = cig_pk_rest["pos"]
		cig_pk_cig.position = Vector3(p0.x, p0.y, lerpf(p0.z, CIG_PEEK_Z, smoothstep(0.10, 0.45, cig_pk_anim)))
		cig_pk_cig.rotation = cig_pk_rest["rot"]

# The cigarette in the other hand: its filter end at the fingertips, pointing forward. Returns where its filter end is.
# (iteration 37) The model's long axis: x = the filter end's own y, y = +1 when the burning end lies towards +y, else -1.
func _cig_axis(cg: Node3D) -> Vector2:
	var lo := INF
	var hi := -INF
	var inv := cg.global_transform.affine_inverse()
	var stack: Array = [cg]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var rel: Transform3D = inv * (n as MeshInstance3D).global_transform
			var bb: AABB = (n as MeshInstance3D).mesh.get_aabb()
			for i in 8:
				var y: float = (rel * bb.get_endpoint(i)).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
	if lo > hi or hi - lo < 0.01:
		return Vector2(CIG_FILTER_Y, -1.0)
	if absf(lo - CIG_FILTER_Y) < absf(hi - CIG_FILTER_Y):
		return Vector2(lo, 1.0)
	return Vector2(hi, -1.0)

# The cigarette in the other hand, the way it is held: the filter end in the fist, the rest sticking out of the front of the fist
# forward and a little up (before iteration 37 it was the other way round: the burning end in the hand). Returns where the filter is.
func _cig_hold_apply(h2: Hand) -> Vector3:
	var ws := world_scale
	var gx := h2.grip.global_transform
	var gb := gx.basis.orthonormalized()
	var ax := _cig_axis(cig_pk_cig)
	var dirv := (-gb.z + gb.y * 0.45).normalized()
	var yb := dirv * ax.y
	var xb := (gb.x - yb * gb.x.dot(yb)).normalized()
	var zb := xb.cross(yb).normalized()
	var bs := Basis(xb, yb, zb) * Basis.from_scale(item_scale)
	var filt := gx.origin + gb * (Vector3(0.0, 0.012, -0.012) * ws)
	cig_pk_cig.global_transform = Transform3D(bs, filt - bs * Vector3(0.0, ax.x, 0.0))
	return filt

# A point held at your mouth for CIG_DWELL_S: true when it is done.
func _cig_mouth(hh: Hand, p: Vector3, delta: float) -> bool:
	var near := p.distance_to(_mouth_point()) <= CIG_MOUTH_M * world_scale
	if near:
		rit_drink += delta
		rit_haptic_t -= delta
		if rit_haptic_t <= 0.0:
			rit_haptic_t = 0.1
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.15, 0.04, 0.0)
	else:
		rit_drink = maxf(rit_drink - delta * 0.8, 0.0)
	return rit_drink >= CIG_DWELL_S

func _rit_cig_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var ws := world_scale
	if xr_cam == null or not is_instance_valid(xr_cam):
		return 2
	if not _cig_pack_ready(par):
		if _cig_mouth(hh, _item_ref(par), delta):          # (an unknown model: the pack itself goes to the mouth, as before)
			return _cig_finish(hh, par, false)
		return 0
	var h2: Hand = right_hand if hh == left_hand else left_hand
	if cig_pk_state == 0:
		if item_t >= FLICK_HOLD_S and _flicked(hh):
			cig_pk_state = 1
			cig_pk_anim = 0.0
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)
			print("VRBoot: cigarette pack flicked open")
		return 0
	_cig_pack_anim(delta)
	if cig_pk_state == 1:
		# (iteration 32) or the open pack itself to your mouth: the cigarette that sticks out goes between the lips
		if cig_pk_anim >= 0.5 and h2.holding == false:
			var cbx := _node_world_aabb(cig_pk_cig, true)
			if cbx.size.x >= 0.0 and _cig_mouth(hh, cbx.get_center(), delta):
				print("VRBoot: cigarette taken straight from the pack with the mouth")
				return _cig_finish(hh, par, true)
		var sq2: bool = h2.grip_sq
		var edge2: bool = sq2 and not cig_pk_down
		cig_pk_down = sq2
		if h2.was_active and not h2.holding and cig_pk_anim >= 0.3:
			var reach := h2.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
			var cp: Vector3 = cig_pk_cig.global_transform * Vector3(0.0, 0.2, 0.0)
			var d := reach.distance_to(cp)
			if d <= CIG_TAKE_M * ws * 1.8:
				var cbox := _node_world_aabb(cig_pk_cig, true)
				if cbox.size.x >= 0.0:
					poke_boxes.append(cbox)                # frame it: it can be taken
			if edge2 and d <= CIG_TAKE_M * ws:
				cig_pk_state = 2
				cig_pk_down = true
				rit_hand2 = h2
				h2.holding = true
				rit_drink = 0.0
				h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
				print("VRBoot: cigarette taken out of the pack with the ", h2.side, " hand")
		return 0
	# 2: the other hand holds it: to the mouth
	if not h2.was_active or not h2.grip_sq:
		cig_pk_state = 1
		cig_pk_anim = 1.0
		cig_pk_down = false
		if rit_hand2 != null:
			rit_hand2.holding = false
		rit_hand2 = null
		rit_drink = 0.0
		print("VRBoot: cigarette put back into the pack")
		return 0
	var filt := _cig_hold_apply(h2)
	if _cig_mouth(h2, filt, delta):
		return _cig_finish(h2, par, true)
	return 0

func _cig_finish(hh: Hand, par: Node3D, pack: bool) -> int:
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	if rm == null:
		return 2
	if pack and cig_pk_cig != null and is_instance_valid(cig_pk_cig):
		cig_pk_cig.visible = false                           # (it is in your mouth now: the empty pack that falls has none)
	if not _titem_consume(par, "cigarettes", pack):
		return 2
	var pd = rm.get("playerData")
	if pd != null:
		pd.set("stat_cigSmoked", int(pd.get("stat_cigSmoked")) + 1)
	var imgr = ii.get("itemManager")
	if imgr != null:
		imgr.set("numberOfCigs_player", int(imgr.get("numberOfCigs_player")) - 1)
	var hc := cur_scene.find_child("health counter", true, false) if cur_scene != null else null
	if hc != null:
		hc.call("UpdateDisplayRoutineCigarette_Player")        # the heal: now, not at the end of the game's animation
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.12, 0.0)
	_titem_end(false, "smoked")
	_cig_light()
	get_tree().create_timer(2.0).timeout.connect(_perm_back)   # the health display of the game takes a moment
	print("VRBoot: cigarette in the mouth - healed now, it burns for ", CIG_BURN_S, " s")
	return 1

func _cig_light() -> void:
	_cig_free()
	cig_root = Node3D.new()
	cig_root.name = "VRBootCigarette"
	fx_root.add_child(cig_root)
	var mat_p := StandardMaterial3D.new()
	mat_p.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_p.albedo_color = Color(0.96, 0.96, 0.94)
	var mat_f := StandardMaterial3D.new()
	mat_f.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_f.albedo_color = Color(0.86, 0.72, 0.5)
	var mat_a := StandardMaterial3D.new()
	mat_a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_a.albedo_color = Color(0.32, 0.32, 0.33)
	var mat_e := StandardMaterial3D.new()
	mat_e.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_e.albedo_color = Color(1.0, 0.5, 0.12)
	for e in [["cig_body", mat_p], ["cig_filter", mat_f], ["cig_ash", mat_a]]:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.radial_segments = 8
		cyl.rings = 1
		mi.mesh = cyl
		mi.material_override = e[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cig_root.add_child(mi)
		match str(e[0]):
			"cig_body":
				cig_body = mi
			"cig_filter":
				cig_filter = mi
			"cig_ash":
				cig_ash = mi
	cig_ember = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radial_segments = 8
	sp.rings = 4
	cig_ember.mesh = sp
	cig_ember.material_override = mat_e
	cig_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cig_root.add_child(cig_ember)
	cig_smoke = CPUParticles3D.new()
	cig_smoke.amount = 22
	cig_smoke.lifetime = 2.6
	cig_smoke.direction = Vector3(0.0, 1.0, 0.0)
	cig_smoke.spread = 22.0
	cig_smoke.initial_velocity_min = 0.02 * world_scale
	cig_smoke.initial_velocity_max = 0.05 * world_scale
	cig_smoke.gravity = Vector3(0.0, 0.03 * world_scale, 0.0)
	cig_smoke.scale_amount_min = 0.7
	cig_smoke.scale_amount_max = 1.3
	cig_smoke.angle_min = 0.0
	cig_smoke.angle_max = 360.0
	cig_smoke.angular_velocity_min = -25.0
	cig_smoke.angular_velocity_max = 25.0
	var grow := Curve.new()                            # a puff swells as it drifts up
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.9))
	cig_smoke.scale_amount_curve = grow
	var sq := QuadMesh.new()
	sq.size = Vector2(0.03, 0.03) * world_scale
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.billboard_keep_scale = true
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.86, 0.86, 0.88, 0.55)
	sm.albedo_texture = _smoke_puff_texture()          # a soft round puff, not a square
	sm.no_depth_test = false
	sq.material = sm
	cig_smoke.mesh = sq
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(0.15, Color(1, 1, 1, 0.5))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0.0))
	cig_smoke.color_ramp = grad
	cig_root.add_child(cig_smoke)
	cig_t = 0.0
	_cig_update(0.0)

# A soft round puff (white in the middle, clear at the rim, a little uneven) for the cigarette smoke.
func _smoke_puff_texture() -> Texture2D:
	if smoke_tex != null:
		return smoke_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var dx := (float(x) + 0.5) / float(n) * 2.0 - 1.0
			var dy := (float(y) + 0.5) / float(n) * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var wob := 0.10 * sin(atan2(dy, dx) * 5.0 + 1.3) + 0.06 * sin(atan2(dy, dx) * 9.0)
			var a := clampf(1.0 - (r + wob) / 0.95, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	smoke_tex = ImageTexture.create_from_image(img)
	return smoke_tex

func _cig_free() -> void:
	if cig_root != null and is_instance_valid(cig_root):
		cig_root.queue_free()
	cig_root = null
	cig_body = null
	cig_filter = null
	cig_ash = null
	cig_ember = null
	cig_smoke = null
	cig_t = -1.0

# The cigarette sticks out of your mouth (a little down, in the lower middle of your view) and burns shorter.
func _cig_update(delta: float) -> void:
	if cig_t < 0.0:
		return
	if cig_root == null or not is_instance_valid(cig_root) or xr_cam == null or not is_instance_valid(xr_cam) or not _in_main_scene():
		_cig_free()
		return
	cig_t += delta
	if cig_t >= CIG_BURN_S:
		print("VRBoot: the cigarette burned down")
		_cig_free()
		return
	var ws := world_scale
	var cb := xr_cam.global_transform.basis.orthonormalized()
	var fwd := -cb.z
	var dir := (fwd * cos(0.22) - cb.y * sin(0.22)).normalized()          # a little down from straight ahead
	var m := xr_cam.global_position - cb.y * (0.07 * ws) + fwd * (0.03 * ws)
	var frac := 1.0 - cig_t / CIG_BURN_S
	var full := CIG_LEN_M * ws
	var filt := 0.28 * full
	var tipd := filt + (full - filt) * (0.1 + 0.9 * frac)           # distance of the glowing end from the lips
	var ash := minf(0.12 * full, tipd - filt)
	var rad := 0.0038 * ws
	var up_ref := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	var bx := up_ref.cross(dir).normalized()
	var bz := bx.cross(dir).normalized()
	var by := dir                                                   # a cylinder's own axis is y
	# (centre, length) of each segment along the stick, the cylinder is built along dir
	for e in [[cig_filter, 0.0, filt], [cig_body, filt, tipd - ash], [cig_ash, tipd - ash, tipd]]:
		var n: MeshInstance3D = e[0]
		if n == null:
			continue
		var d0: float = e[1]
		var d1: float = e[2]
		var ln := maxf(d1 - d0, 0.0001)
		(n.mesh as CylinderMesh).top_radius = rad
		(n.mesh as CylinderMesh).bottom_radius = rad
		(n.mesh as CylinderMesh).height = ln
		n.global_transform = Transform3D(Basis(bx, by, bz), m + dir * ((d0 + d1) * 0.5))
	var tip := m + dir * tipd
	var flick := 0.85 + 0.15 * sin(cig_t * 17.0)
	(cig_ember.mesh as SphereMesh).radius = rad * 1.15 * flick
	(cig_ember.mesh as SphereMesh).height = rad * 2.3 * flick
	cig_ember.global_position = tip
	cig_smoke.global_position = tip
	cig_smoke.emitting = cig_t < CIG_BURN_S - 1.0
