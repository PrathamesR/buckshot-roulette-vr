# Table items by hand: pick, carry, use, end (dispatcher)
# (Part of the Buckshot Roulette VR mod. Chain position 31: this file extends 30_item_use.gd; see src/README.md.)
extends "30_item_use.gd"

const TITEM_GRAB_M := 0.07                         # a hand this close (real metres) to an item on the table, with the grip squeezed, picks it up (the nearest of items and shotgun wins)

const TITEM_HEAD_M := 0.32                         # "to your face": the item this close (real metres) to your face

const TITEM_GUN_M := 0.22                          # "on the shotgun": this close (real metres) to the shotgun lying on the table

const TITEM_DEALER_FRAC := 0.72                    # "to the dealer": your hand this fraction of the way (or less) from your head to the dealer's...

const TITEM_DEALER_REACH_M := 0.40                 # ...or this far (real metres) straight out from your head, whichever is nearer (the world size changes how far he is)

# Where each item is used. Letting go of it there uses it (the game's own pick-up-and-use runs); letting go anywhere else puts it back.
# "rit" = used by hand for real (see _rit_*): beer (drink, rack the shotgun), cigarettes, magnifying glass (smash it, look through
# what is left), handsaw (saw the end of the barrel), inverter (turn the dial), medicine (strip, pill, eat). Handcuffs: held out
# to the dealer until he takes them.
const TITEM_ZONES := {"beer": "rit", "cigarettes": "rit", "expired medicine": "rit", "magnifying glass": "rit", "burner phone": "rit", \
	"adrenaline": "rit", "handsaw": "rit", "inverter": "rit", "handcuffs": "dealer"}

# Where an item goes when the hand version cannot be done right now (no shells, a model that is not as expected): the old way.
const TITEM_FALLBACK := {"expired medicine": "head", "inverter": "gun", "burner phone": "head", "adrenaline": "head"}

const DEALER_TAKE_S := 0.7                         # held out to the dealer this long: he takes the handcuffs

var item_zone_in := false           # the carried item is where it would be used

var item_zone_t := 0.0

var rit_held_t := 0.0

var flick_prev := {}                # hand side -> last grip basis

var flick_w := {}                   # hand side -> how fast the hand turns now (rad/s)

var flick_t := {}                   # hand side -> seconds since its last flick

func _titem_consume(par: Node3D, iname: String, toss := true) -> bool:
	var ii = interaction.get("itemInteraction")
	if ii == null:
		return false
	if steal_held and par == item_node:
		steal_held = false
		return _steal_consume(par, iname, toss)
	var rm = ii.get("roundManager")
	var perm = ii.get("perm")
	if rm == null or perm == null:
		return false
	perm.call("SetIndicators", false)
	perm.call("SetInteractionPermissions", false)
	perm.call("RevertDescriptionUI")
	var cur = ii.get("cursor")
	if cur != null:
		cur.call("SetCursor", false, false)
	rm.call("ClearDeskUI", true)
	ii.call("RemovePlayerItemFromGrid", par)
	var am = ii.get("amounts")
	if am != null:
		var arr = am.get("array_amounts")
		if arr is Array:
			for res in arr:
				if str(res.get("itemName")) == iname:
					res.set("amount_player", int(res.get("amount_player")) - 1)
					break
	var turn = rm.get("playerCurrentTurnItemArray")
	if turn is Array and not (iname in turn):
		turn.append(iname)
	if toss:
		_fx_toss(par)
	par.queue_free()
	ii.call("CheckAchievement_koni")
	ii.call("CheckAchievement_full")
	return true

func _perm_back() -> void:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii != null and is_instance_valid(ii):
		ii.call("EnablePermissions")


# ---- the pump of the shotgun on the table: grabbed, pulled back, pushed forward -----------------------------------------------

# ---- the items already on the table: pick one up (squeeze the grip with your hand on it), it sits in your fist, and then
# you use it for real: bring it where it is used (see TITEM_ZONES). Beer, magnifying glass and handsaw are used by hand
# (see _rit_*); handcuffs are held out to the dealer, who takes them; the rest are used by letting go in their zone. Nothing
# happens in the game until you really use it, so a wrong pick-up is just put back.
func _titem_try_take(hh: Hand, im: Node, edge: bool) -> bool:
	var ws := world_scale
	var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	var pk := _titem_pick(im, reach)
	var best: Node = pk[0]
	var best_d: float = pk[1]
	var best_box: AABB = pk[2]
	if best == null:
		return false
	if grab_gun_ok and _gun_eff_dist(reach) < best_d:
		return false                                   # the shotgun is nearer: it gets this squeeze
	if best_d <= TITEM_GRAB_M * 2.0 * ws:
		_pk_flat(best_box)                             # frame it: it can be picked up
	if edge and best_d <= TITEM_GRAB_M * ws:
		_titem_take(hh, best)
		return true
	return false

func _titem_take(hh: Hand, br: Node) -> void:
	var par := br.get_parent() as Node3D
	var ind: Node = par.get_child(0)
	item_home = par.transform
	item_br = br
	item_node = par
	item_hand = hh
	item_t = 0.0
	item_zone_in = false
	item_zone_t = 0.0
	item_handoff = false
	item_slot = -1
	rit_drink = 0.0
	rit_stroke = 0.0
	rit_hand2 = null
	ind.set("lerpEnabled", false)                      # the game's hover lift must not fight the hand
	ind.set("interactionAllowed", false)
	_item_hold_begin(par, str(br.get("itemName")))
	rit_prev = _item_ref(par)
	hh.holding = true
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: picked up '", str(br.get("itemName")), "' from the table with the ", hh.side, " hand")
	if _is_stolen(ind):
		# one of the dealer's items: the game's 7 s clock stops while you hold it; you are back in your seat to use it
		steal_held = true
		var iit = interaction.get("itemInteraction")
		var itm = iit.get("items") if iit != null else null
		if itm != null and is_instance_valid(itm):
			itm.call("Counter", false)
		_adr_tp_end("you took one")

func _titem_carry(im: Node, delta: float) -> void:
	var hh := item_hand
	var par := item_node
	var br := item_br
	if par == null or not is_instance_valid(par) or br == null or not is_instance_valid(br) or hh == null or not hh.was_active \
			or par.is_queued_for_deletion() or not par.is_inside_tree():
		_titem_end(false, "taken" if item_handoff else "lost it")
		return
	item_t += delta
	if item_handoff:
		# the dealer is taking the handcuffs: they stay in your hand until the game's animation has them
		_item_hold_apply(hh, par)
		_cuffs_retarget(par)
		if item_t > 6.0:
			_titem_end(false, "handoff timeout")
		return
	if not _allowed(br) or (gun_state != 0 and not _gun_held_free()) or bool(im.get("moving")) or cuffed:
		_titem_end(true, "not allowed any more")       # the game changed turns (or is busy): it goes back
		return
	_item_hold_apply(hh, par)
	var ws := world_scale
	var iname := str(br.get("itemName"))
	var zone: String = str(TITEM_ZONES.get(iname, "head"))
	var ref := _item_ref(par)
	if zone == "rit":
		var r := _rit_item_tick(iname, hh, par, br, delta)
		if r == 1:
			return                                     # used up by hand
		if r == 0:
			if item_t >= TITEM_MIN_S and not hh.grip_sq:
				_titem_end(true, "put back")
			return
		zone = str(TITEM_FALLBACK.get(iname, "gun"))   # (2) the hand version is not possible here: the old way
	var inz := _titem_in_zone(zone, ref, ws)
	if inz != item_zone_in:
		item_zone_in = inz
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.35, 0.05, 0.0)
	item_zone_t = item_zone_t + delta if inz else 0.0
	if zone == "gun" and gun_rest_ok:
		_pk_flat(gun_rest_box)                         # the frame shows where it goes
	# no words: a ring where it goes (the face, the shotgun), lime when it is there; held out to the dealer it fills up
	if zone == "dealer":
		if inz:
			_ring_show(ref + Vector3.UP * (0.10 * ws), clampf(item_zone_t / DEALER_TAKE_S, 0.0, 1.0), true, 0.05)
		else:
			var dd := _dealer_from_head()
			if dd[0] != Vector3.ZERO and xr_cam != null and is_instance_valid(xr_cam):
				var tgt: Vector3 = xr_cam.global_position + (dd[0] as Vector3) * (_dealer_need(ws, float(dd[1])) * 1.25)
				tgt.y = ref.y + 0.10 * ws
				_ring_show(tgt, -1.0, false, 0.05)                  # hold it out there
	elif zone == "head" and xr_cam != null and is_instance_valid(xr_cam):
		_ring_show(xr_cam.global_position - xr_cam.global_transform.basis.y.normalized() * (0.06 * ws), -1.0, inz, 0.06)
	elif inz:
		_ring_show(ref + Vector3.UP * (0.10 * ws), -1.0, true, 0.05)
	if zone == "dealer" and item_zone_t >= DEALER_TAKE_S:
		_titem_use(br)                                 # the dealer takes them out of your hand
		return
	if item_t >= TITEM_MIN_S and not hh.grip_sq:
		if inz:
			_titem_use(br)
		else:
			_titem_end(true, "put back")

# Is a carried item (at world point p) where it is used?
func _titem_in_zone(zone: String, p: Vector3, ws: float) -> bool:
	if xr_cam == null or not is_instance_valid(xr_cam):
		return false
	var head := xr_cam.global_position
	match zone:
		"head":
			var mouth := head - xr_cam.global_transform.basis.y.normalized() * (0.06 * ws)
			return p.distance_to(mouth) <= TITEM_HEAD_M * ws
		"gun":
			if gun_main == null or not is_instance_valid(gun_main) or not (_gun_held_free() or (gun_state == 0 and gun_main.visible)):
				return false
			var gx := _gun_xf()
			var a: Vector3 = gx * Vector3(0.0, -3.5, 0.0)
			var b: Vector3 = gx * Vector3(0.0, 5.0, 0.0)
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			return p.distance_to(a + ab * t) <= TITEM_GUN_M * ws
		"dealer":
			var dd := _dealer_from_head()
			var dir: Vector3 = dd[0]
			var hl: float = dd[1]
			if dir == Vector3.ZERO or hl <= 0.5 * ws:
				return false
			var v := p - head
			v.y = 0.0
			var fwd := v.dot(dir)
			var side := absf(v.x * dir.z - v.z * dir.x)
			return fwd >= _dealer_need(ws, hl) and side <= fwd * 1.2
	return false

# Where the dealer is as seen from your head: [unit direction on the table plane, distance]. Direction ZERO = unknown.
func _dealer_from_head() -> Array:
	var out := [Vector3.ZERO, 0.0]
	if xr_cam == null or not is_instance_valid(xr_cam) or cur_scene == null:
		return out
	var dn := cur_scene.get_node_or_null("dealer model parent") as Node3D
	if dn == null:
		return out
	var hv := dn.global_position - xr_cam.global_position
	hv.y = 0.0
	var l := hv.length()
	if l < 0.001:
		return out
	return [hv / l, l]

# How far straight out from your head the hand has to be to count as "held out to the dealer".
func _dealer_need(ws: float, hl: float) -> float:
	return minf(TITEM_DEALER_REACH_M * ws, hl * (1.0 - TITEM_DEALER_FRAC))

func _titem_use(br: Node) -> void:
	var hh := item_hand
	var par := item_node
	var iname := str(br.get("itemName"))
	var ind: Node = par.get_child(0)
	ind.set("lerpEnabled", true)                       # the game does its own thing with the item from here
	ind.set("interactionAllowed", true)
	if iname == "handcuffs":
		_cuffs_retarget(par)                           # the dealer's animation starts where your hand holds the cuffs
	interaction.set("activeInteractionBranch", br)
	interaction.call("MainInteractionEvent")
	if bool(br.get("interactionAllowed")):
		_titem_end(true, "the game did not take it")   # still allowed = nothing happened: put it back
		return
	if hh != null:
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
	print("VRBoot: used '", iname, "' by hand")
	if iname == "handcuffs":
		var ii = interaction.get("itemInteraction")
		if ii != null:
			ii.set("moving", false)                    # the game's own glide of the item stops: your hand keeps it until it is taken
		item_handoff = true
		item_t = 0.0
		return
	_titem_end(false, "used")

func _titem_end(restore: bool, why: String) -> void:
	if steal_held:
		steal_held = false
		var iit = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
		if restore and iit != null and is_instance_valid(iit) and iit.get("stealing") == true:
			var itm = iit.get("items")
			if itm != null and is_instance_valid(itm):
				itm.call("Counter", true)             # put back: the game's 7 s clock runs again
			adr_tp_re = true
	_mag_reset()
	_cig_pack_reset()
	_saw_reset()
	_inv_reset()
	_med_reset()
	_phone_reset()
	_adr_reset()
	var par := item_node
	if par != null and is_instance_valid(par) and not par.is_queued_for_deletion() and restore:
		par.transform = item_home
		var ind: Node = par.get_child(0) if par.get_child_count() > 0 else null
		if ind != null:
			ind.call("SnapToMin")
			ind.set("lerpEnabled", true)
			ind.set("interactionAllowed", true)
	if item_hand != null:
		item_hand.holding = false
	if rit_hand2 != null:
		rit_hand2.holding = false
	rit_hand2 = null
	if rit_snd != null and is_instance_valid(rit_snd):
		rit_snd.stop()
		rit_snd.queue_free()
	rit_snd = null
	rit_drink = 0.0
	rit_stroke = 0.0
	item_handoff = false
	item_zone_t = 0.0
	item_hand = null
	item_node = null
	item_br = null
	item_slot = -1
	item_zone_in = false
	print("VRBoot: table item carrying ended (", why, ")")

# ---- what goes on after the item is used up --------------------------------------------------------------------------------
func _rit_tick(delta: float) -> void:
	rit_t += delta
	match rit:
		"beer_rack":
			var r := _pump_step(delta, true)
			if r == -1 or r == 2 or rit_t > 90.0:
				_pump_reset()
				_beer_eject()
				rit = "beer_wait"
				rit_t = 0.0
		"beer_wait":
			if rit_t >= 1.6:
				rit = ""
				var ii = interaction.get("itemInteraction")
				var rm = ii.get("roundManager") if ii != null else null
				if rit_final and rm != null:
					if _gun_held_free():
						_gun_release("new round")      # the shotgun goes back for the next round
					rm.call("StartRound", true)
				else:
					_perm_back()
		"examine":
			if rit_pulled and rit_pull >= PUMP_PULL_OK * 0.8:
				rit_held_t += delta
			var r := _pump_step(delta, true)
			var done := false
			if r == -1:
				done = rit_t > 6.0
			elif r == 2:
				if rit_held_t >= 0.8:
					done = true
				else:
					rit_pulled = false
			elif rit_t > 90.0 or (not rit_pulled and rit_hand == null and rit_t > 20.0):
				done = true                          # (nobody pulled the pump for a while: the glass is spent, the shell hides again)
			if done:
				_pump_reset()
				var ex := cur_scene.find_child("shell examine", true, false) if cur_scene != null else null
				if ex != null:
					ex.call("RevertShell")
				rit = ""
				_perm_back()
				print("VRBoot: shell examined")

func _rit_abort(why: String) -> void:
	_pump_reset()
	rit = ""
	print("VRBoot: item ritual aborted (", why, ")")

# How fast each hand turns (rad/s). A flick of the wrist is a quick turn: it flips a pack or a knife open.
func _flick_update(delta: float) -> void:
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		if hh == null or hh.grip == null or not is_instance_valid(hh.grip):
			continue
		var b := hh.grip.global_transform.basis.orthonormalized()
		if flick_prev.has(hh.side) and delta > 0.0001:
			var pb: Basis = flick_prev[hh.side]
			var q := (b * pb.inverse()).get_rotation_quaternion()
			var w := q.get_angle() / delta
			flick_w[hh.side] = lerpf(float(flick_w.get(hh.side, 0.0)), w, 1.0 - exp(-delta * 40.0))
		flick_prev[hh.side] = b
		flick_t[hh.side] = float(flick_t.get(hh.side, 9.0)) + delta

func _flicked(hh: Hand, thr: float = FLICK_W) -> bool:
	if float(flick_w.get(hh.side, 0.0)) >= thr and float(flick_t.get(hh.side, 9.0)) >= 0.5:
		flick_t[hh.side] = 0.0
		return true
	return false
