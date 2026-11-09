# Fingertip pressing: TV buttons, briefcase, key machine, click targets
# (Part of the Buckshot Roulette VR mod. Chain position 20: this file extends 19_gun_hold.gd; see src/README.md.)
extends "19_gun_hold.gd"

const DOOR_ALIASES := ["bathroom door", "backroom door"]   # touched with a fingertip, opened with the trigger

const POKE_COOLDOWN := 0.6                         # seconds before the same thing can be pressed again

const POKE_NEAR_M := 0.25                          # a "[ ]" appears around a pressable thing when a fingertip is this close

const KEY_PAD_M := 0.008                           # a name-machine key counts as touched this close (real metres, each axis at its own scale)

const KEY_STAY := 1.6                              # ...and stays "touched" until the fingertip is this many times further away

const KEY_CLEAR_M := 0.04                          # a hand must first be this far from every key before it can press one

const KEY_SETTLE_S := 0.6                          # the name machine must have stood still this long before any key reacts

const KEY_ALIAS := "signature machine button"

const BTN_ALIAS := "crt button"                    # the TV's four caps: pushed down by a fingertip, they click at the bottom

const BTN_FIRE := 0.85                             # a cap clicks once it is pushed this far (fraction of its travel)

const BTN_RELEASE := 0.4                           # ...and clicks again only after the finger came back up this far

const BTN_ENTRY := 0.3                             # the fingertip must come from the front: at most this deep the frame before

const BTN_PAD_M := 0.004                           # real metres around a cap that still count as "on it"

const BTN_SPRING_S := 0.08                         # a released cap springs back up in this long

const BRIEF_PRESS_M := 0.010                       # a latch is pushed this deep (real metres) to go

const BRIEF_LID_GRAB_M := 0.07                     # a hand this close to the lid can take hold of it

const BRIEF_LIFT_M := 0.10                         # ...and lifts it this far (real metres) to open it

var door_trig := {}                # hand side -> the trigger was pulled last frame (a door opens on a fresh pull)

var key_ref_xf := Transform3D()    # where the name machine's key rows were when it last moved

var key_ref_ok := false

var key_still_since := 0.0        # time the name machine last moved

var key_ready := false             # the name machine has stood still long enough

var key_diag_t := -100.0

var brief_prev := {}                # hand|latch -> the fingertip's height over the latch's face last frame

var brief_state := {}               # hand|latch -> 0 outside, 1 came in through the face, 2 pressed, 3 came in from the side

var brief_grip := {}

var brief_lid_hand: Hand = null

var brief_lid_y0 := 0.0

var brief_haptic_t := 0.0

var key_armed := {}                # hand side -> it was clear of the keys after the machine settled

var key_log_left := 12             # how many key presses still get a detailed log line

# Remember that you asked the game to take you to the dealer: from now on YOU walk there.
func _note_click_target() -> void:
	if interaction == null or not is_instance_valid(interaction):
		return
	var br = interaction.get("activeInteractionBranch")
	if br == null or not is_instance_valid(br):
		return
	if str(br.get("interactionAlias")) == "backroom door" and bool(br.get("interactionAllowed")) \
			and bool(br.get("interactionInvalid")):
		print("VRBoot: too far from the back-room door - walk up to it first")
		if active_hand != null:
			active_hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.12, 0.0)
		return
	if not bool(br.get("interactionAllowed")) or bool(br.get("interactionInvalid")):
		return
	if str(br.get("interactionAlias")) == "backroom door":
		gap_back_open = true
	if str(br.get("interactionAlias")) == "backroom door" and stick_walk and regime_big and mode == "follow":
		if needs_recenter:
			_place_origin(false)         # finish a pending re-seat NOW, while anchor + walk_off still say where you are
			needs_recenter = false
		hold_for_dealer = true
		hold_t = 0.0
		_sync_walk_off()
		print("VRBoot: back-room door clicked - you stay where you stand")


# ------------------------------------------------------------------ bathroom: finger presses and the pill menu

# Remember the branches we treat specially (found by their alias).
func _index_special_branches() -> void:
	pill_yes = null
	pill_no = null
	if pill_state == 0 and cur_scene != null:
		var pn := cur_scene.find_child("pill bottle main", true, false)
		pill_node = pn as MeshInstance3D
		print("VRBoot: pill bottle mesh: ", pill_node.get_path() if pill_node != null else "NOT FOUND")
	for n in hint_nodes:
		match _alias_of(n):
			"pill choice yes":
				pill_yes = n
			"pill choice no":
				pill_no = n

# The game's own 2D buttons behind the pill menu's YES and NO: [[Control, alias], ...]
func _pill_buttons() -> Array:
	var out: Array = []
	if interaction == null or not is_instance_valid(interaction):
		return out
	var intro = interaction.get("intro")
	if intro == null:
		return out
	for pair in [["btn_pillsYes", "pill choice yes"], ["btn_pillsNo", "pill choice no"]]:
		var b = intro.get(pair[0])
		if b is Control and is_instance_valid(b):
			out.append([b, pair[1]])
	return out

# Which of YES / NO is under this point of the 2D screen ("" = neither). The target is a bit generous.
func _pill_choice_at(px: Vector2) -> String:
	for e in _pill_buttons():
		var c: Control = e[0]
		var local := c.get_global_transform().affine_inverse() * px
		if Rect2(Vector2.ZERO, c.size).grow(3.0).has_point(local):
			return str(e[1])
	return ""

# The distance from a fingertip to a pressable thing (0 = touching it).
func _tip_distance(n: Node, tip: Vector3) -> float:
	var info := _branch_info(n)
	var per_axis := _alias_of(n) == KEY_ALIAS     # the keys are thin plates: every axis needs its own scale
	var best := INF
	for e in info["shapes"]:
		var cs: CollisionShape3D = e[0]
		if not is_instance_valid(cs) or cs.disabled:
			continue
		var gt := cs.global_transform
		var sc := maxf(gt.basis.get_scale().x, 0.0001)
		var local := gt.affine_inverse() * tip
		var bb: AABB = e[1]
		var dx := maxf(maxf(bb.position.x - local.x, local.x - bb.end.x), 0.0)
		var dy := maxf(maxf(bb.position.y - local.y, local.y - bb.end.y), 0.0)
		var dz := maxf(maxf(bb.position.z - local.z, local.z - bb.end.z), 0.0)
		var d := Vector3(dx, dy, dz).length() * sc
		if per_axis:
			var s3 := gt.basis.get_scale().abs()
			d = Vector3(dx * s3.x, dy * s3.y, dz * s3.z).length()
		best = minf(best, d)
	return best

# The row of keys of the name machine moves as one (it rises when the waiver is signed). Keys must not react to
# a machine sweeping through your hands: wait until it has stood still, and until the hand has been clear.
func _key_machine_update(fingers: Array, ws: float) -> void:
	var kn: Node = null
	for n in fingers:
		if _alias_of(n) == KEY_ALIAS:
			kn = n
			break
	if kn == null:
		if key_ready or key_ref_ok:
			print("VRBoot: name machine keys gone")
		key_ref_ok = false
		key_ready = false
		key_armed.clear()
		return
	var row: Node = kn.get_parent()
	if row != null:
		row = row.get_parent()          # the node all the keys hang from (it does not move when a key goes down)
	if not (row is Node3D):
		row = kn.get_parent()
	if not (row is Node3D):
		return
	var xf: Transform3D = (row as Node3D).global_transform
	var moved := not key_ref_ok
	if key_ref_ok:
		var bs: Basis = xf.basis
		var rb: Basis = key_ref_xf.basis
		var ref_len := maxf(rb.x.length(), 0.0001)
		if (xf.origin - key_ref_xf.origin).length() > 0.01 * ws \
				or (bs.x - rb.x).length() > 0.01 * ref_len \
				or (bs.y - rb.y).length() > 0.01 * ref_len \
				or (bs.z - rb.z).length() > 0.01 * ref_len:
			moved = true
	if moved:
		key_ref_xf = xf
		key_ref_ok = true
		key_still_since = t_alive
		if key_ready or t_alive - key_diag_t > 6.0:
			key_diag_t = t_alive
			print("VRBoot: name machine is moving; keys wait")
		key_ready = false
		key_armed.clear()
		return
	if not key_ready and t_alive - key_still_since >= KEY_SETTLE_S:
		key_ready = true
		print("VRBoot: name machine has settled; keys react once your hands are clear of them")

func _update_poke(_delta: float) -> void:
	poke_boxes.clear()
	restroom_stage = false
	pill_menu_active = false
	left_hand.near_poke = false
	right_hand.near_poke = false
	if pause_open or not _in_main_scene() or interaction == null or not is_instance_valid(interaction):
		return
	pill_menu_active = _allowed(pill_yes) or _allowed(pill_no)
	var targets: Array = []              # pressed only by fingertip (the bathroom things)
	var fingers: Array = []              # pressed by fingertip or laser (the name machine's keys)
	var crt_body := false
	for n in hint_nodes:
		if is_instance_valid(n) and _allowed(n):
			if _is_poke(n):
				if _alias_of(n) == "crt":
					crt_body = true       # the TV's picture is not a button: its X button (below) starts it
				else:
					targets.append(n)
			elif _is_finger(n) and not _alias_locked(_alias_of(n)) and not _nm_dead(n):
				fingers.append(n)
	if crt_body and tv_state == 0:
		var crt1 := _crt()
		var xb = crt1.get("branch_exit") if crt1 != null else null
		if xb is Node and is_instance_valid(xb) and not targets.has(xb):
			targets.append(xb)            # the game keeps X switched off until the TV runs: we allow touching it to start
	restroom_stage = not targets.is_empty() or crt_body
	if brief_lid_hand != null:
		var lid_there := false
		for tn in targets:
			if _alias_of(tn) == "briefcase lid":
				lid_there = true
		if not lid_there:
			brief_lid_hand.holding = false
			brief_lid_hand = null
	if targets.is_empty() and fingers.is_empty():
		poke_in.clear()
		_key_machine_update(fingers, world_scale)
		return
	var all: Array = targets + fingers
	var ws := world_scale
	_key_machine_update(fingers, ws)
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		if not hh.was_active:
			continue
		var tip := _hand_tip(hh)
		var trig_now: bool = hh.trigger_down
		var trig_edge: bool = trig_now and not bool(door_trig.get(hh.side, false))
		door_trig[hh.side] = trig_now
		# only the closest target can be touched (28 keys sit side by side)
		var dists: Array = []
		var best := -1
		var best_d := INF
		for i in all.size():
			var d := _tip_distance(all[i], tip)
			dists.append(d)
			if d < best_d:
				best_d = d
				best = i
		var key_d := INF                 # the nearest key to this fingertip
		for i in all.size():
			if _alias_of(all[i]) == KEY_ALIAS:
				key_d = minf(key_d, float(dists[i]))
		if key_ready:
			if key_d >= KEY_CLEAR_M * ws and not bool(key_armed.get(hh.side, false)):
				key_armed[hh.side] = true
				print("VRBoot: ", hh.side, " hand is clear of the keys; it can press now")
		else:
			key_armed[hh.side] = false
		if best >= 0 and best_d <= POKE_NEAR_M * ws:
			hh.near_poke = true
			_pk_face(all[best])
		for i in all.size():
			var n: Node = all[i]
			var id: int = n.get_instance_id()
			var key := "%s|%d" % [hh.side, id]
			var is_key := _alias_of(n) == KEY_ALIAS
			var was := bool(poke_in.get(key, false))
			var pad := (KEY_PAD_M if is_key else POKE_PAD_M) * ws
			if is_key and was:
				pad *= KEY_STAY                  # no flicker at the edge of a key
			var touching: bool = i == best and float(dists[i]) <= pad
			poke_in[key] = touching
			if _alias_of(n) == "latch left" or _alias_of(n) == "latch right":
				if hh.holding:
					brief_state.erase(key)
				else:
					_brief_press_step(n, hh, tip, ws, key)
				continue
			if _alias_of(n) == "briefcase lid":
				_brief_lid_step(n, hh, ws)
				continue
			if _alias_of(n) == BTN_ALIAS:
				# the TV's caps are real buttons: they sink under the fingertip and click at the bottom
				if hh.holding:
					btn_state.erase("%s|%d" % [hh.side, (n.get_parent() as Node).get_instance_id()])
				else:
					_btn_step(n, hh, tip, ws)
				continue
			if DOOR_ALIASES.has(_alias_of(n)):
				# a door is touched to find it and opened by pulling the trigger while the fingertip is on it
				if touching and trig_edge and not hh.holding and t_alive >= float(poke_cool.get(id, 0.0)):
					poke_cool[id] = t_alive + POKE_COOLDOWN
					_poke_fire(n, hh)
				continue
			var key_ok := (not is_key) or (key_ready and bool(key_armed.get(hh.side, false)))
			if touching and not was and not hh.holding and key_ok and t_alive >= float(poke_cool.get(id, 0.0)):
				poke_cool[id] = t_alive + (0.25 if _is_finger(n) else POKE_COOLDOWN)
				if is_key and key_log_left > 0:
					key_log_left -= 1
					print("VRBoot: key touch: ", hh.side, " hand, distance ", snappedf(float(dists[i]) / ws * 100.0, 0.1), " cm (real)")
				_poke_fire(n, hh)

# A latch of the money briefcase is a button: the fingertip has to come in through its face and push it in (BRIEF_PRESS_M, or
# a bit over half of its thickness when it is thinner). Touching it, or sweeping past it from the side, does nothing.
func _brief_press_step(n: Node, hh: Hand, tip: Vector3, ws: float, key: String) -> void:
	var od := _branch_oriented(n, false)
	if od.is_empty() or xr_cam == null or not is_instance_valid(xr_cam):
		return
	var bs: Basis = od["basis"]
	var half: Vector3 = od["half"]
	var c: Vector3 = od["center"]
	var axes := [bs.x.normalized(), bs.y.normalized(), bs.z.normalized()]
	var hv := [half.x, half.y, half.z]
	var to_head := xr_cam.global_position - c
	var ni := 0
	var bd := -1.0
	for i in 3:
		var dd := absf((axes[i] as Vector3).dot(to_head.normalized()))
		if dd > bd:
			bd = dd
			ni = i
	var nrm: Vector3 = axes[ni]
	if nrm.dot(to_head) < 0.0:
		nrm = -nrm
	var hn: float = hv[ni]
	var rel := tip - c
	var sdist := rel.dot(nrm)                              # > hn: in front of the face
	var depth := hn - sdist                                # how far in below the face
	var side_ok := true
	for i in 3:
		if i != ni and absf(rel.dot(axes[i] as Vector3)) > float(hv[i]) + 0.012 * ws:
			side_ok = false
	var prev := float(brief_prev.get(key, 9999.0))
	brief_prev[key] = sdist
	var inside := side_ok and depth > 0.0 and depth < 2.0 * hn + 0.02 * ws
	var st := int(brief_state.get(key, 0))
	if not inside:
		brief_state[key] = 0
		return
	if st == 0:
		if prev >= hn - 0.004 * ws:
			st = 1
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.03, 0.0)
		else:
			st = 3
	if st == 1 and depth >= clampf(hn * 1.1, 0.004 * ws, BRIEF_PRESS_M * ws):
		st = 2
		if t_alive >= float(poke_cool.get(n.get_instance_id(), 0.0)):
			poke_cool[n.get_instance_id()] = t_alive + 0.3
			_poke_fire(n, hh)
	brief_state[key] = st

# The lid: take hold of it (grip squeezed with the hand on it) and lift it; at BRIEF_LIFT_M it opens, as the game's own click does.
func _brief_lid_step(n: Node, hh: Hand, ws: float) -> void:
	var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	var sq: bool = hh.grip_sq
	var edge: bool = sq and not bool(brief_grip.get(hh.side, false))
	brief_grip[hh.side] = sq
	if brief_lid_hand == hh:
		if not sq:
			hh.holding = false
			brief_lid_hand = null
			return
		var lift := reach.y - brief_lid_y0
		if lift > 0.0:
			brief_haptic_t -= get_process_delta_time()
			if brief_haptic_t <= 0.0:
				brief_haptic_t = 0.07
				hh.grip.trigger_haptic_pulse("haptic", 0.0, clampf(lift / (BRIEF_LIFT_M * ws), 0.0, 1.0) * 0.5, 0.04, 0.0)
		if lift >= BRIEF_LIFT_M * ws:
			hh.holding = false
			brief_lid_hand = null
			_poke_fire(n, hh)
		return
	if hh.holding or not edge:
		return
	var bx := _branch_world_box(n, false)
	if bx.size.x >= 0.0 and _point_box_dist(reach, bx) <= BRIEF_LID_GRAB_M * ws:
		brief_lid_hand = hh
		brief_lid_y0 = reach.y
		hh.holding = true
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)

# One TV button cap and one fingertip. The cap is a small cube that sinks along its own axis (the game's y_up / y_down).
# The fingertip has to come in from the front; the cap follows it down, clicks near the bottom (_poke_fire does what the
# game's own click would do) and comes back up when the finger does. A hand that sweeps in from the side does nothing.
func _btn_step(n: Node, hh: Hand, tip: Vector3, ws: float) -> void:
	var cap := n.get_parent() as MeshInstance3D
	if cap == null or cap.get_child_count() < 2 or cap.get_parent() == null or not (cap.get_parent() is Node3D):
		return
	var drv: Node = cap.get_child(1)
	if drv.get("y_up") == null or drv.get("y_down") == null:
		return
	var y_up := float(drv.get("y_up"))
	var travel := y_up - float(drv.get("y_down"))
	if travel < 0.001:
		return
	var par := cap.get_parent() as Node3D
	var pxf := par.global_transform
	var sc := maxf(pxf.basis.get_scale().y, 0.0001)
	var lt := pxf.affine_inverse() * tip
	var bb := cap.get_aabb()
	var pad := BTN_PAD_M * ws / sc
	var cx := cap.position.x
	var cz := cap.position.z
	var inside := lt.x >= cx + bb.position.x - pad and lt.x <= cx + bb.end.x + pad \
		and lt.z >= cz + bb.position.z - pad and lt.z <= cz + bb.end.z + pad
	var depth := (y_up + bb.end.y - lt.y) / travel       # 0 = fingertip on the cap's face, 1 = pushed all the way down
	var cid := cap.get_instance_id()
	var key := "%s|%d" % [hh.side, cid]
	var prev := float(btn_prev.get(key, -9.0))
	btn_prev[key] = depth
	var st := int(btn_state.get(key, 0))
	if not inside or depth <= 0.0 or depth > 3.0:
		btn_state[key] = 0
		return
	if st == 0:
		if prev > -9.0 and prev <= BTN_ENTRY:
			st = 1
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.02, 0.0)
		else:
			st = 3
	if st == 3:
		btn_state[key] = 3
		return
	if not bool(drv.get("moving")):
		cap.position.y = y_up - clampf(depth, 0.0, 1.0) * travel
		btn_driven[cid] = cap
		btn_held[cid] = t_alive
	if st == 1 and depth >= BTN_FIRE:
		st = 2
		if t_alive >= float(poke_cool.get(n.get_instance_id(), 0.0)):
			poke_cool[n.get_instance_id()] = t_alive + 0.15
			_poke_fire(n, hh)
	elif st == 2 and depth < BTN_RELEASE:
		st = 1
	btn_state[key] = st

# A cap nobody is holding goes back up (unless the game is animating it itself).
func _update_btn_spring(delta: float) -> void:
	if btn_driven.is_empty():
		return
	for cid in btn_driven.keys():
		var cap = btn_driven[cid]
		if not (cap is Node3D) or not is_instance_valid(cap) or cap.get_child_count() < 2:
			btn_driven.erase(cid)
			continue
		if t_alive - float(btn_held.get(cid, 0.0)) < 0.06:
			continue
		var drv: Node = cap.get_child(1)
		if bool(drv.get("moving")):
			continue
		var y_up := float(drv.get("y_up"))
		var travel := maxf(y_up - float(drv.get("y_down")), 0.001)
		var y := move_toward((cap as Node3D).position.y, y_up, travel * delta / BTN_SPRING_S)
		(cap as Node3D).position.y = y
		if y >= y_up - 0.0005:
			(cap as Node3D).position.y = y_up
			btn_driven.erase(cid)

func _poke_fire(n: Node, hh: Hand) -> void:
	var alias := _alias_of(n)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.9, 0.12, 0.0)
	if alias == "crt":
		return                            # the picture itself does nothing any more: the X button starts the TV
	if alias == "crt button" and str(n.get("crtButton_alias")) == "exit":
		if tv_state == 0:
			_tv_open()
			var crt0 := _crt()
			var sp0 = crt0.get("speaker_buttonpress") if crt0 != null else null
			if sp0 is Node:
				sp0.call("play")
			print("VRBoot: pressed the TV's X with the ", hh.side, " hand - TV starts")
		else:
			_tv_close(true)
			print("VRBoot: pressed the TV's X with the ", hh.side, " hand")
		return
	if alias == "backroom door":
		interaction.set("activeInteractionBranch", n)
		_note_click_target()              # same as a laser click: you stay where you stand, the lobby stays until you are through
	if alias == "bathroom door":
		if tv_state != 0:
			_tv_close(false)
		if pill_state == 1:
			_pill_release()
		bath_left = true
		gap_bath_open = true
		if stick_walk and regime_big and mode == "follow":
			if needs_recenter:
				_place_origin(false)           # finish a pending re-seat NOW, while anchor + walk_off still say where you are
				needs_recenter = false
			hold_for_dealer = true
			hold_t = 0.0
			bath_pending = true
			_sync_walk_off()
	interaction.set("activeInteractionBranch", n)
	interaction.call("MainInteractionEvent")
	if alias == KEY_ALIAS:
		var kname := str(n.get("signatureButton_letterAlias"))
		if kname == "" or kname == "<null>":
			kname = str(n.get("signatureButton_specialAlias"))
		print("VRBoot: pressed key '", kname, "' with the ", hh.side, " hand")
		return
	print("VRBoot: pressed '", alias, "' with the ", hh.side, " hand")

# While the pill question is up: point at YES / NO on the floating panel. Hovering lights the word up
# (the game does that when its button gets focus); the trigger picks it.
func _pill_hover(px: Vector2) -> void:
	var over := _pill_choice_at(px)
	for e in _pill_buttons():
		var c: Control = e[0]
		if not c.is_visible_in_tree():
			continue
		if str(e[1]) == over:
			if not c.has_focus():
				c.grab_focus()
		elif c.has_focus():
			c.release_focus()

func _pill_click(px: Vector2, hh: Hand) -> void:
	var alias := _pill_choice_at(px)
	if alias == "":
		return
	var br: Node = pill_yes if alias == "pill choice yes" else pill_no
	if not _allowed(br):
		return
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.8, 0.1, 0.0)
	print("VRBoot: pill menu - ", alias)
	interaction.call("InteractWith", alias)
