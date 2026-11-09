# Adrenaline item and stealing
# (Part of the Buckshot Roulette VR mod. Chain position 22: this file extends 21_map_dump.gd; see src/README.md.)
extends "21_map_dump.gd"

const ADR_NEAR_M := 0.09                           # the needle tip this close (real metres) to your other forearm...

const ADR_ARM_OFF := 0.10                          # ...(the forearm is this far behind the controller's grip)

const ADR_JAB_V := 0.6                             # ...and moving towards it at least this fast (real m/s) = a jab; or held there ADR_DWELL_S

const ADR_DWELL_S := 0.7

const ADR_HIT_S := 3.42                            # the game's own timings after the injection: the pulse effect...

const ADR_STEAL_S := 5.5                           # ...and the dealer's items open for stealing

const ADR_CAP_GRAB_M := 0.05                       # the other hand's reach (real metres) to the syringe's cap (iteration 33)

const ADR_CAP_PULL_M := 0.07                       # the cap pulled this far (real metres) off the needle end is off

const ADR_ARM_BOX := 0.05                          # the framed spot on the forearm: half the size of the frame (real metres)

const ADR_STUCK_S := 3.4                           # the syringe stays stuck in the arm this long (until the pulse)

const ADR_TP_FRAC := 0.55                          # at the pulse your head moves this share of the way to the dealer's items

const ADR_TP_MAX_S := 20.0                         # ...and is back in the seat at the latest after this long

var adr_local: Array = []            # the syringe's needle tip and direction in its own space

var adr_ok := false

var adr_tip_prev := Vector3.ZERO

var adr_vel := Vector3.ZERO

var adr_near_t := 0.0

var adr_buzz := false

var adr_stuck: Node3D = null         # the syringe stuck in the forearm

var adr_stuck_hand: Hand = null

var adr_stuck_rel := Transform3D.IDENTITY

var adr_stuck_t := 0.0

var adr_tp_t := 0.0

var adr_tp_seen := false

var adr_cap: MeshInstance3D = null  # (iteration 33) the syringe's cap...

var adr_cap_rest := Transform3D.IDENTITY

var adr_cap_state := 0              # 0 on the needle, 1 in the other hand, 2 off

var adr_cap_hand: Hand = null

var adr_cap_rel := Transform3D.IDENTITY

var adr_cap_down := true

# ---- adrenaline (iteration 29): jab the needle into your own other forearm - it stays stuck there ---------------------------
# The needle end is where the game's `adrenaline cap` sits. The spot on the free forearm is framed. Tip in the frame and either
# a quick thrust towards it or 0.7 s of holding it there: the syringe is used up (the game's sound), it stays stuck in the arm
# until the pulse (ADR_HIT_S), `AdrenalineHit` plays, your head moves to the middle of the table (_adr_tp_begin) and 5.5 s after
# the injection (the game's own timing) the dealer's items open for stealing - you take them with your hand.
func _adr_ready(par: Node3D) -> bool:
	if adr_local.size() == 2:
		return true
	var cap := par.get_node_or_null("adrenaline cap") as MeshInstance3D
	if cap == null or cap.mesh == null:
		return false
	var cb: AABB = cap.mesh.get_aabb()
	var c_loc: Vector3 = par.global_transform.affine_inverse() * (cap.global_transform * cb.get_center())
	var mid := item_loc.get_center()
	var d: Vector3 = c_loc - mid
	var ax := 0
	for i in 3:
		if absf(d[i]) > absf(d[ax]):
			ax = i
	if absf(d[ax]) < 0.05 * maxf(item_loc.size[ax], 0.001):
		return false
	var dir := Vector3.ZERO
	dir[ax] = signf(d[ax])
	adr_local = [mid + dir * (item_loc.size[ax] * 0.5), dir]
	return true

# (iteration 33) The cap on the needle comes off first: squeeze the other hand next to it and pull it off the needle end.
func _adr_cap_tick(h2: Hand, par: Node3D) -> int:
	var ws := world_scale
	if adr_cap == null or not is_instance_valid(adr_cap):
		var cp := par.get_node_or_null("adrenaline cap") as MeshInstance3D
		if cp == null or cp.mesh == null:
			adr_cap_state = 2                      # no cap on this model: nothing to take off
			return 0
		adr_cap = cp
		adr_cap_rest = cp.transform
		adr_cap_state = 0
		adr_cap_down = true
	var sq: bool = h2.grip_sq
	var edge: bool = sq and not adr_cap_down
	adr_cap_down = sq
	var reach := h2.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	if adr_cap_state == 0:
		_hint_tut("adr_cap", "TAKE THE CAP OFF\nWITH YOUR OTHER HAND", _item_ref(par) + Vector3.UP * (0.13 * ws), TUT_LONG_K)
		if not h2.holding:
			var cc: Vector3 = adr_cap.global_transform * adr_cap.mesh.get_aabb().get_center()
			var dd := reach.distance_to(cc)
			if dd <= ADR_CAP_GRAB_M * ws * 2.0:
				var bx := _node_world_aabb(adr_cap, true)
				if bx.size.x >= 0.0:
					poke_boxes.append(bx)          # frame it: it can be taken off
			if edge and dd <= ADR_CAP_GRAB_M * ws:
				adr_cap_state = 1
				_tut_done("adr_cap")
				adr_cap_hand = h2
				h2.holding = true
				rit_hand2 = h2
				adr_cap_rel = h2.grip.global_transform.affine_inverse() * adr_cap.global_transform
				h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)
				print("VRBoot: syringe cap taken with the ", h2.side, " hand")
		return 0
	# 1: the cap is in the other hand
	if not h2.was_active or not sq:
		adr_cap.transform = adr_cap_rest          # let go too early: it is back on the needle
		adr_cap_state = 0
		h2.holding = false
		if rit_hand2 == h2:
			rit_hand2 = null
		adr_cap_hand = null
		return 0
	adr_cap.global_transform = h2.grip.global_transform * adr_cap_rel
	var rest_p: Vector3 = par.global_transform * adr_cap_rest.origin
	if adr_cap.global_position.distance_to(rest_p) >= ADR_CAP_PULL_M * ws:
		var c := _fx_clone_visual(adr_cap)         # the cap falls away
		adr_cap.visible = false
		_fx_fall(c, Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2)) * ws, Vector3(randf_range(-6.0, 6.0), randf_range(-6.0, 6.0), randf_range(-6.0, 6.0)), item_floor_y, 1.6, true)
		adr_cap_state = 2
		h2.holding = false
		if rit_hand2 == h2:
			rit_hand2 = null
		adr_cap_hand = null
		h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
		print("VRBoot: syringe cap off - the needle is bare")
	return 0

func _adr_reset() -> void:
	if adr_cap != null and is_instance_valid(adr_cap) and not adr_cap.is_queued_for_deletion():
		adr_cap.transform = adr_cap_rest
		adr_cap.visible = true
	adr_cap = null
	adr_cap_state = 0
	adr_cap_hand = null
	adr_local = []
	adr_ok = false
	adr_near_t = 0.0
	adr_buzz = false
	adr_vel = Vector3.ZERO

func _rit_adr_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var h2: Hand = left_hand if hh == right_hand else right_hand
	if h2 == null or not h2.was_active or not _adr_ready(par):
		return 2
	if adr_cap_state < 2:
		return _adr_cap_tick(h2, par)
	var ws := world_scale
	var pxf := par.global_transform
	var tip: Vector3 = pxf * (adr_local[0] as Vector3)
	var axis: Vector3 = (pxf.basis * (adr_local[1] as Vector3)).normalized()
	if not adr_ok:
		adr_tip_prev = tip
		adr_vel = Vector3.ZERO
		adr_ok = true
	adr_vel = adr_vel.lerp((tip - adr_tip_prev) / maxf(delta, 0.0001), 1.0 - exp(-delta * 25.0))
	adr_tip_prev = tip
	var arm: Vector3 = h2.grip.global_transform * (Vector3(0.0, 0.0, ADR_ARM_OFF) * ws)      # the forearm lies behind the grip
	var e := Vector3.ONE * (ADR_ARM_BOX * ws)
	poke_boxes.append(AABB(arm - e, e * 2.0))                                              # frame it: that is where it goes
	var to := arm - tip
	var dist := to.length()
	var near := dist > 0.0001 and dist <= ADR_NEAR_M * ws and axis.dot(to / dist) >= 0.5
	if near:
		if not adr_buzz:
			adr_buzz = true
			h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.05, 0.0)
		adr_near_t += delta
	else:
		adr_buzz = false
		adr_near_t = maxf(adr_near_t - delta * 2.0, 0.0)
	if (near and adr_vel.dot(axis) >= ADR_JAB_V * ws) or adr_near_t >= ADR_DWELL_S:
		return _adr_finish(hh, h2, par, tip, arm)
	return 0

func _adr_finish(hh: Hand, h2: Hand, par: Node3D, tip: Vector3, arm: Vector3) -> int:
	var ii = interaction.get("itemInteraction")
	if ii == null:
		return 2
	var stuck := _fx_clone_visual(par)                # (it stays in the arm: the real one is used up)
	if not _titem_consume(par, "adrenaline", false):
		stuck.queue_free()
		return 2
	stuck.global_position += arm - tip
	adr_stuck = stuck
	adr_stuck_hand = h2
	adr_stuck_rel = h2.grip.global_transform.affine_inverse() * stuck.global_transform
	adr_stuck_t = 0.0
	var snd = ii.get("sound_use_adrenaline")
	if snd is AudioStream:
		_fx_play(snd)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.8, 0.2, 0.0)
	h2.grip.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.4, 0.0)
	_titem_end(false, "injected")
	get_tree().create_timer(ADR_HIT_S).timeout.connect(_adr_hit)
	get_tree().create_timer(ADR_STEAL_S).timeout.connect(_adr_steal)
	print("VRBoot: adrenaline injected into the other arm")
	return 1

# The syringe sticks in the forearm and moves with it until the pulse, then drops away.
func _adr_stuck_tick(delta: float) -> void:
	if adr_stuck == null:
		return
	if not is_instance_valid(adr_stuck):
		adr_stuck = null
		return
	adr_stuck_t += delta
	if adr_stuck_hand != null and adr_stuck_hand.was_active and adr_stuck_t < ADR_STUCK_S:
		adr_stuck.global_transform = adr_stuck_hand.grip.global_transform * adr_stuck_rel
		return
	_fx_fall(adr_stuck, Vector3(0.0, 0.25 * world_scale, 0.0), Vector3(2.0, 1.0, 3.0), item_floor_y, 1.0, true)
	adr_stuck = null

func _adr_hit() -> void:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii != null and is_instance_valid(ii) and _in_main_scene():
		ii.call("AdrenalineHit")
		_adr_tp_begin()

func _adr_steal() -> void:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii == null or not is_instance_valid(ii) or not _in_main_scene():
		return
	var items = ii.get("items")
	if items != null and is_instance_valid(items):
		items.call("SetupItemSteal")

# ---- the head at the middle of the table while you steal ---------------------------------------------------------------------
# As soon as the adrenaline hits (the light gets brighter) you are moved (not the table) towards the dealer's items so that you
# can pick them up with your hands. When you take one (or the stealing is over) you are back in your seat.
func _adr_tp_begin() -> void:
	if adr_tp_on or xr_cam == null or not is_instance_valid(xr_cam) or origin == null or item_im == null or not is_instance_valid(item_im):
		return
	var arr = item_im.get("itemArray_instances_dealer")
	if not (arr is Array):
		return
	var c := Vector3.ZERO
	var n := 0
	for it in arr:
		if is_instance_valid(it) and it is Node3D and not (it as Node).is_queued_for_deletion() and (it as Node).is_inside_tree():
			c += (it as Node3D).global_position
			n += 1
	if n == 0:
		print("VRBoot: no dealer items to reach - you stay in your seat")
		return
	c /= float(n)
	var s := xr_cam.global_position
	var d := (c - s) * ADR_TP_FRAC
	d.y = 0.0
	if d.length() < 0.2 * world_scale:
		return
	origin.global_position += d
	adr_tp_on = true
	adr_tp_t = 0.0
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	adr_tp_seen = ii != null and is_instance_valid(ii) and ii.get("stealing") == true
	_sync_walk_off()
	print("VRBoot: you are moved to the middle of the table (", snappedf(d.length() / world_scale, 0.01), " m) to reach the dealer's items")

func _adr_tp_end(why: String) -> void:
	if not adr_tp_on:
		return
	adr_tp_on = false
	walk_off = Vector3.ZERO
	if xr_cam != null and is_instance_valid(xr_cam) and origin != null:
		_place_origin(true)
	print("VRBoot: back in your seat (", why, ")")

# ---- stealing from the dealer by hand (iteration 29) ------------------------------------------------------------------------
# The dealer's items stay where they are (they are not brought to you). `steal_on` = the game lets you take one right now.
func _steal_update(_im: Node, delta: float) -> void:
	_adr_stuck_tick(delta)
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii == null or not is_instance_valid(ii):
		steal_on = false
		if adr_tp_on:
			_adr_tp_end("left the game")
		return
	var stealing: bool = ii.get("stealing") == true
	steal_on = stealing and ii.get("stealing_fs") == true
	if adr_tp_on:
		adr_tp_t += delta
		_sync_walk_off()
		if stealing:
			adr_tp_seen = true
		if adr_tp_seen and not stealing:
			_adr_tp_end("the stealing is over")
		elif adr_tp_t > ADR_TP_MAX_S:
			_adr_tp_end("timeout")
	elif adr_tp_re:
		if not stealing:
			adr_tp_re = false
		elif steal_on and item_node == null:
			adr_tp_re = false
			_adr_tp_begin()

func _is_stolen(ind: Node) -> bool:
	if ind == null or ind.get("isDealerItem") != true:
		return false
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	return ii != null and is_instance_valid(ii) and ii.get("stealing") == true

# What the game does around a stolen item it is used up by hand (PickupItemFromTable + InteractWith, without the animation).
func _steal_consume(par: Node3D, iname: String, toss: bool) -> bool:
	var ii = interaction.get("itemInteraction")
	if ii == null:
		return false
	var rm = ii.get("roundManager")
	var perm = ii.get("perm")
	var items = ii.get("items")
	var hands = ii.get("hands")
	if rm == null or perm == null or items == null or hands == null:
		return false
	perm.call("SetIndicators", false)
	perm.call("SetInteractionPermissions", false)
	perm.call("RevertDescriptionUI")
	var cur = ii.get("cursor")
	if cur != null:
		cur.call("SetCursor", false, false)
	rm.call("ClearDeskUI", true)
	items.call("Counter", false)
	hands.call("RemoveItem_Remote", par)
	items.call("RevertItemSteal")
	var cam = ii.get("camera")
	if cam != null:
		cam.call("BeginLerp", "home")
	ii.set("stealing_fs", false)
	ii.set("pos_hand", ii.get("pos_hand_main"))
	ii.set("rot_hand", ii.get("rot_hand_main"))
	var am = ii.get("amounts")
	if am != null:
		var arr = am.get("array_amounts")
		if arr is Array:
			for res in arr:
				if str(res.get("itemName")) == iname:
					var dv = res.get("amount_dealer")
					if dv != null:
						res.set("amount_dealer", int(dv) - 1)
					res.set("amount_player", int(res.get("amount_player")) - 1)
					break
	var turn = rm.get("playerCurrentTurnItemArray")
	if turn is Array and not (iname in turn):
		turn.append(iname)
	ii.set("stealing", false)
	if toss:
		_fx_toss(par)
	par.queue_free()
	ii.call("CheckAchievement_koni")
	ii.call("CheckAchievement_full")
	print("VRBoot: stolen '", iname, "' used by hand")
	return true
