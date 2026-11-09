# Expired medicine item (strip, pills)
# (Part of the Buckshot Roulette VR mod. Chain position 29: this file extends 28_pause_menu.gd; see src/README.md.)
extends "28_pause_menu.gd"

const MED_FLICK_W := 4.5                           # (iteration 33) a flick for the medicine: the hand turns at least this fast (rad/s), either hand

const MED_GRAB_M := 0.07                           # the other hand's reach to the end of the blister strip / to the pill

const MED_FLICK_M := 0.30                          # a flick of the other hand this close (real metres) to the box / strip counts

const MED_PULL_LEN := 1.60                         # (item units) how far the game's animation pulls the strip out of the box

const MED_DONE := 0.6                             # pulled this far (share of the way) and let go: the strip stays out

const MED_STRIP_OUT := Vector3(-2.16168, -0.266077, -0.0252647)   # where the game's animation leaves the strip (item space)

const MED_STRIP_ROT := 0.212633                    # ...and how far it tilts (around z)

var med_strip: MeshInstance3D = null # the medicine's blister strip (iteration 27)

var med_pill: MeshInstance3D = null  # ...the pill on it

var med_pillnode: MeshInstance3D = null  # ...the pill flying to / lying in the other hand

var med_rest := {}

var med_state := 0                   # 0 strip in the box, 1 strip out, 2 the pill flies to the other hand, 3 the pill is in that hand

var med_p := 0.0                     # how far the strip is out (0..1)

var med_auto := false                # the strip slides out by itself (a flick)

var med_anim := 0.0

var med_hand: Hand = null            # the hand that pulls the strip / holds the pill

var med_down := true

var med_grab0 := 0.0                 # where the pulling hand took the strip (along the box) and how far it was out then

var med_grab_p := 0.0

var med_fly := 0.0

var med_fly_from := Vector3.ZERO

var med_fly_q := Quaternion.IDENTITY

var med_end_loc := Vector3.ZERO      # the strip's far end (its own space), where it is taken

# ---- the prescription medicine (iteration 27): pull (or flick) the strip out of the box with the other hand, flick again and a
# pill drops into that hand, then eat the pill (hold it at your mouth). The game's own medicine (heal or hurt) runs then.
func _med_ready(par: Node3D) -> bool:
	if med_strip != null and is_instance_valid(med_strip) and med_strip.get_parent() == par:
		return true
	var st := par.get_node_or_null("expired medicine blister pack") as MeshInstance3D
	if st == null or st.mesh == null:
		return false
	var pl := st.get_node_or_null("expired medicine cap") as MeshInstance3D
	if pl == null or pl.mesh == null:
		return false
	med_strip = st
	med_pill = pl
	med_rest = {"pos": st.position, "rot": st.rotation, "pill": pl.visible}
	var sb := st.mesh.get_aabb()
	med_end_loc = Vector3(sb.position.x, sb.get_center().y, sb.get_center().z)
	med_state = 0
	med_p = 0.0
	med_auto = false
	med_anim = 0.0
	med_hand = null
	med_down = true
	med_pillnode = null
	return true

func _med_reset() -> void:
	if med_strip != null and is_instance_valid(med_strip) and not med_strip.is_queued_for_deletion() and med_rest.has("pos"):
		med_strip.position = med_rest["pos"]
		med_strip.rotation = med_rest["rot"]
	if med_pill != null and is_instance_valid(med_pill) and not med_pill.is_queued_for_deletion() and med_rest.has("pill"):
		med_pill.visible = bool(med_rest["pill"])
	if med_pillnode != null and is_instance_valid(med_pillnode):
		med_pillnode.queue_free()
	med_pillnode = null
	med_strip = null
	med_pill = null
	med_rest = {}
	med_state = 0
	med_p = 0.0
	med_auto = false
	med_anim = 0.0
	med_hand = null
	med_down = true
	med_fly = 0.0

func _med_set_strip(p: float) -> void:
	med_p = clampf(p, 0.0, 1.0)
	var rp: Vector3 = med_rest["pos"]
	var rr: Vector3 = med_rest["rot"]
	med_strip.position = rp.lerp(MED_STRIP_OUT, med_p)
	med_strip.rotation = Vector3(rr.x, rr.y, rr.z + MED_STRIP_ROT * med_p)

func _med_release_hand() -> void:
	if med_hand != null:
		med_hand.holding = false
		if rit_hand2 == med_hand:
			rit_hand2 = null
	med_hand = null

# The pill in the open hand: flat on the palm, a little ahead of the hand.
func _med_pill_xf(h2: Hand) -> Transform3D:
	var ws := world_scale
	var gx := h2.grip.global_transform
	var gb := gx.basis.orthonormalized()
	var yb: Vector3 = -gb.x if h2.side == "right" else gb.x
	var xb: Vector3 = gb.y
	var zb := xb.cross(yb).normalized()
	var bs := Basis(xb, yb, zb) * Basis.from_scale(item_scale)
	return Transform3D(bs, gx.origin + gb * (Vector3(0.0, 0.0, -0.045) * ws) + yb * (0.012 * ws))

func _med_pill_take(h2: Hand) -> void:
	var pn := MeshInstance3D.new()
	pn.name = "VRBootMedPill"
	pn.mesh = med_pill.mesh
	pn.material_override = med_pill.material_override
	for i in med_pill.mesh.get_surface_count():
		var m := med_pill.get_surface_override_material(i)
		if m != null:
			pn.set_surface_override_material(i, m)
	pn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(pn)
	pn.global_transform = med_pill.global_transform
	med_fly_q = med_pill.global_transform.basis.orthonormalized().get_rotation_quaternion()
	med_fly_from = pn.global_position
	med_pill.visible = false
	med_pillnode = pn
	med_hand = h2
	h2.holding = true
	rit_hand2 = h2
	rit_drink = 0.0
	med_fly = 0.0
	med_state = 2
	h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: a pill pops out of the strip")

# The hand lost its tracking with the pill in it: the pill goes back onto the strip.
func _med_pill_back() -> void:
	if med_pillnode != null and is_instance_valid(med_pillnode):
		med_pillnode.queue_free()
	med_pillnode = null
	if med_pill != null and is_instance_valid(med_pill):
		med_pill.visible = bool(med_rest.get("pill", true))
	_med_release_hand()
	med_state = 1
	rit_drink = 0.0
	print("VRBoot: the pill went back onto the strip")

func _rit_med_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var ws := world_scale
	if xr_cam == null or not is_instance_valid(xr_cam) or not _med_ready(par):
		return 2
	var h2: Hand = right_hand if hh == left_hand else left_hand
	var sq: bool = h2.grip_sq
	var edge: bool = sq and not med_down
	med_down = sq
	var reach := h2.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	var free2: bool = h2.was_active and not h2.holding
	if med_state == 0:
		if med_auto:
			med_anim += delta
			_med_set_strip(smoothstep(0.0, 1.0, med_anim / 0.25))
			if med_anim >= 0.25:
				med_auto = false
				_med_set_strip(1.0)
				med_state = 1
				print("VRBoot: medicine strip flicked out")
			return 0
		if med_hand != null:
			# the strip is in the other hand: it comes out along the box's own length as far as that hand pulls it
			var px: float = (par.global_transform.affine_inverse() * reach).x
			var still: bool = h2.was_active and sq
			if still:
				_med_set_strip(med_grab_p + (med_grab0 - px) / MED_PULL_LEN)
			if med_p >= 0.999 or (not still and med_p >= MED_DONE):
				_med_release_hand()
				med_state = 1
				h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
				print("VRBoot: medicine strip pulled out")
			elif not still:
				_med_release_hand()
			return 0
		if med_p > 0.0:
			_med_set_strip(move_toward(med_p, 0.0, delta * 3.0))      # let go too early: it slides back in
		if free2:
			var st_end: Vector3 = med_strip.global_transform * med_end_loc
			var dd := reach.distance_to(st_end)
			if dd <= MED_GRAB_M * ws * 2.0:
				var bx := _node_world_aabb(med_strip, true)
				if bx.size.x >= 0.0:
					poke_boxes.append(bx)                  # frame it: it can be pulled
			if edge and dd <= MED_GRAB_M * ws:
				med_hand = h2
				h2.holding = true
				rit_hand2 = h2
				med_grab0 = (par.global_transform.affine_inverse() * reach).x
				med_grab_p = med_p
				h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)
				print("VRBoot: medicine strip taken with the ", h2.side, " hand")
			elif item_t >= FLICK_HOLD_S and ((reach.distance_to(_item_ref(par)) <= MED_FLICK_M * ws and _flicked(h2, MED_FLICK_W)) or _flicked(hh, MED_FLICK_W)):
				med_auto = true
				med_anim = 0.0
				h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)
		return 0
	if med_state == 1:
		if med_p < 1.0:
			_med_set_strip(move_toward(med_p, 1.0, delta * 5.0))
		if free2:
			var pc: Vector3 = med_pill.global_transform * med_pill.mesh.get_aabb().get_center()
			var dd2 := reach.distance_to(pc)
			if dd2 <= MED_GRAB_M * ws * 2.0:
				var bx2 := _node_world_aabb(med_pill, true)
				if bx2.size.x >= 0.0:
					poke_boxes.append(bx2)                 # frame it: it can be taken
			if (edge and dd2 <= MED_GRAB_M * ws) or (item_t >= FLICK_HOLD_S and ((dd2 <= MED_FLICK_M * ws and _flicked(h2, MED_FLICK_W)) or _flicked(hh, MED_FLICK_W))):
				_med_pill_take(h2)
		return 0
	# 2 / 3: the pill flies to the other hand and lies there: to the mouth
	if not h2.was_active or med_pillnode == null or not is_instance_valid(med_pillnode):
		_med_pill_back()
		return 0
	var tgt := _med_pill_xf(h2)
	if med_state == 2:
		med_fly = minf(med_fly + delta / 0.25, 1.0)
		var s := smoothstep(0.0, 1.0, med_fly)
		var o := med_fly_from.lerp(tgt.origin, s) + Vector3.UP * (sin(s * PI) * 0.05 * ws)
		var q := med_fly_q.slerp(tgt.basis.orthonormalized().get_rotation_quaternion(), s)
		med_pillnode.global_transform = Transform3D(Basis(q) * Basis.from_scale(item_scale), o)
		if med_fly >= 1.0:
			med_state = 3
			rit_drink = 0.0
			h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.05, 0.0)
		return 0
	med_pillnode.global_transform = tgt
	if _cig_mouth(h2, tgt.origin, delta):
		return _med_finish(h2, par)
	return 0

func _med_finish(hh: Hand, par: Node3D) -> int:
	var ii = interaction.get("itemInteraction")
	var med = ii.get("medicine") if ii != null else null
	if med == null:
		return 2
	if not _titem_consume(par, "expired medicine", true):
		return 2
	if med_pillnode != null and is_instance_valid(med_pillnode):
		med_pillnode.queue_free()
	med_pillnode = null
	var snd = ii.get("sound_use_medicine")
	if snd is AudioStream:
		_fx_play(snd)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.12, 0.0)
	_titem_end(false, "swallowed")
	med.call("UseMedicine")                                    # the game's own: heal or hurt, and it gives the table back
	print("VRBoot: the pill was eaten")
	return 1
