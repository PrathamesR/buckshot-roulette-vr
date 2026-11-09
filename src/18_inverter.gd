# Inverter item
# (Part of the Buckshot Roulette VR mod. Chain position 18: this file extends 17_gun_aim.gd; see src/README.md.)
extends "17_gun_aim.gd"

const INV_GRAB_M := 0.05                           # the other hand's reach (real metres) to the inverter's dial (measured to the dial's box)

const INV_FLIP := 2.84                             # the game's animation turns the dial about this far (radians)

const INV_GO := 1.07                               # ...and it goes when it has been turned this far (iteration 34: 120 degrees of your own turn feel like 180 on the tracked hand)

const INV_CLICK := 0.26                            # a small click in the controller every time the dial has turned this much

var inv_dial: MeshInstance3D = null  # the inverter's dial (iteration 27)

var inv_rest := 0.0                  # ...its rest turn (around its own y)

var inv_angle := 0.0                 # ...how far it is turned now

var inv_hand: Hand = null            # the hand that holds the dial

var inv_prev_r := Vector3.ZERO       # ...where that hand was around the dial's axis last frame

var inv_prev_b := Basis.IDENTITY

var inv_click := 0.0

var inv_down := true

var inv_grab_loc := Vector3.ZERO   # where the turning hand took the dial (in the dial's own frame)

# ---- the inverter (iteration 27): hold it in one hand and turn its dial with the other, as far as the game's own animation
# turns it. The shell in the chamber is flipped then (live <-> blank); nothing says which it is now.
func _inv_ready(par: Node3D) -> bool:
	if inv_dial != null and is_instance_valid(inv_dial) and inv_dial.get_parent() == par:
		return true
	var d := par.get_node_or_null("inverter dial") as MeshInstance3D
	if d == null or d.mesh == null:
		return false
	inv_dial = d
	inv_rest = d.rotation.y
	inv_angle = 0.0
	inv_hand = null
	inv_prev_r = Vector3.ZERO
	inv_click = 0.0
	inv_down = true
	return true

func _inv_reset() -> void:
	inv_dealer = false
	dealer_key = ""
	dealer_sp = {}
	if inv_dial != null and is_instance_valid(inv_dial) and not inv_dial.is_queued_for_deletion():
		var r := inv_dial.rotation
		r.y = inv_rest
		inv_dial.rotation = r
	inv_dial = null
	inv_hand = null
	inv_angle = 0.0
	inv_click = 0.0
	inv_prev_r = Vector3.ZERO
	inv_down = true

func _inv_apply() -> void:
	var r := inv_dial.rotation
	r.y = inv_rest + clampf(inv_angle / INV_GO, -1.0, 1.0) * INV_FLIP      # (iteration 33) the dial shows the whole turn by the time it goes
	inv_dial.rotation = r

# Where a point is around the dial's axis (the part of the way from the dial's pivot that is across the axis).
func _inv_radial(p: Vector3, pivot: Vector3, axis: Vector3) -> Vector3:
	var v := p - pivot
	return v - axis * v.dot(axis)

func _rit_inv_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var ws := world_scale
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	var seq = rm.get("shellSpawner").get("sequenceArray") if rm != null else null
	if not (seq is Array) or seq.is_empty() or not _inv_ready(par):
		return 2
	var h2: Hand = right_hand if hh == left_hand else left_hand
	var sq: bool = h2.grip_sq
	var edge: bool = sq and not inv_down
	inv_down = sq
	var axis := ((inv_dial.get_parent() as Node3D).global_transform.basis * Vector3.UP).normalized()
	var pivot := inv_dial.global_position
	var reach := h2.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	var gb := h2.grip.global_transform.basis.orthonormalized()
	if inv_hand == null:
		if absf(inv_angle) > 0.0001:                       # let go too early: the dial springs back
			inv_angle = move_toward(inv_angle, 0.0, delta * 9.0)
			_inv_apply()
		if h2.was_active and not h2.holding:
			var bx := _node_world_aabb(inv_dial, true)
			if bx.size.x >= 0.0:
				var dd := _point_box_dist(reach, bx)
				if dd <= INV_GRAB_M * ws * 2.0:
					poke_boxes.append(bx)                  # frame it: it can be turned
				if edge and dd <= INV_GRAB_M * ws:
					inv_hand = h2
					h2.holding = true
					rit_hand2 = h2
					inv_prev_r = _inv_radial(reach, pivot, axis)
					inv_prev_b = gb
					inv_grab_loc = inv_dial.global_transform.affine_inverse() * reach
					inv_click = floorf(absf(inv_angle) / INV_CLICK)
					h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
					print("VRBoot: inverter dial taken with the ", h2.side, " hand")
		return 0
	# the dial is in the other hand: it follows the turn of that hand around the dial's axis (a sweep of the hand around the
	# dial, or a twist of the hand when it is right at the dial)
	var still: bool = h2.was_active and sq
	if still:
		h2.visual.global_position += inv_dial.global_transform * inv_grab_loc - reach      # (iteration 32) the hand stays on the dial
	if still:
		var rv := _inv_radial(reach, pivot, axis)
		var dq := (gb * inv_prev_b.inverse()).get_rotation_quaternion()
		if dq.w < 0.0:
			dq = Quaternion(-dq.x, -dq.y, -dq.z, -dq.w)
		var tw := 2.0 * atan2(dq.x * axis.x + dq.y * axis.y + dq.z * axis.z, dq.w)
		var da := tw
		var rl := rv.length() / ws
		var prl := inv_prev_r.length() / ws
		var wgt := clampf((minf(rl, prl) - 0.015) / 0.015, 0.0, 1.0)
		if wgt > 0.0:
			da = wgt * inv_prev_r.signed_angle_to(rv, axis) + (1.0 - wgt) * tw
		inv_prev_r = rv
		inv_prev_b = gb
		inv_angle = clampf(inv_angle + da, -INV_GO, INV_GO)
		_inv_apply()
		var stp := floorf(absf(inv_angle) / INV_CLICK)
		if stp != inv_click:
			inv_click = stp
			h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.03, 0.0)       # a click of the dial
	if absf(inv_angle) >= INV_GO:
		return _inv_finish(hh, h2, par, seq)
	if not still:
		inv_hand = null
		h2.holding = false
		if rit_hand2 == h2:
			rit_hand2 = null
		print("VRBoot: inverter dial let go (", snappedf(inv_angle, 0.01), " rad) - it springs back")
	return 0

func _inv_finish(hh: Hand, h2: Hand, par: Node3D, seq: Array) -> int:
	var ii = interaction.get("itemInteraction")
	var r := inv_dial.rotation
	r.y = inv_rest + signf(inv_angle) * INV_FLIP
	inv_dial.rotation = r                                      # (the used inverter that falls has its dial turned right over)
	if not _titem_consume(par, "inverter", true):
		return 2
	seq[0] = "blank" if str(seq[0]) == "live" else "live"     # the game's own effect
	var snd = ii.get("sound_use_inverter") if ii != null else null
	if snd is AudioStream:
		_fx_play(snd)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.12, 0.0)
	h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.12, 0.0)
	_titem_end(false, "inverted")
	get_tree().create_timer(1.2).timeout.connect(_perm_back)
	print("VRBoot: inverter turned - the shell in the chamber is flipped")
	return 1
