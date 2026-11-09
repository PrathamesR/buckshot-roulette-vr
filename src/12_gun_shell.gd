# Gun: shell eject, keep-the-gun logic, pump racking
# (Part of the Buckshot Roulette VR mod. Chain position 12: this file extends 11_hints.gd; see src/README.md.)
extends "11_hints.gd"

const GUN_EJECT_T := 1.55                          # the game's "player eject shell" animation lets the shell go at 1.6 s

const PUMP_TRAVEL := 1.2                           # how far the pump slides back (model units; the game's own animation uses 1.2)

const PUMP_SPRING := 8.0                           # model units per second the pump springs forward after you let go

var rit_goff := 0.0

var rit_pump_rest := {}             # pump node -> its y when at rest

var rit_down := {}                  # hand side -> grip squeezed last frame (second hands, pump)

var gun_trk_anim: Animation = null # (iteration 34) the game's "player eject shell" with its shell/rack tracks switched off

var gun_trk_off: Array = []

var gun_eject_name := "player eject shell"

var gun_eject_t := 1.55

var gun_shell_state := "blank"

func _gun_keep_ok(live: bool) -> bool:
	if live or (gun_aim != "self" and gun_aim != "dealer") or interaction == null:
		return false
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	if rm == null:
		return false
	if rm.get("barrelSawedOff") == true:
		return false
	if gun_aim == "dealer":
		# (iteration 36) a blank at a cuffed dealer: his turn is skipped (he only checks the cuffs) so you go again - the gun stays
		# in the hand. Not when he is about to break free: then it is his turn.
		if rm.get("dealerCuffed") != true:
			return false
		var di = ii.get("dealerIntelligence")
		if di == null or di.get("dealerAboutToBreakFree") == true:
			return false
	var sp = rm.get("shellSpawner")
	var seq = sp.get("sequenceArray") if sp != null else null
	return seq is Array and seq.size() > 1

# (iteration 34) After a blank at yourself with the gun kept: the game's own animation would eject the shell by itself and play
# its rack sounds. Those two tracks are switched off for this one animation; the shell is taken out of the sequence (the
# game's own bookkeeping, at the moment the game would have done it) without any picture or sound, and it leaves the gun
# only when you rack the pump (_gun_shell_fly).
func _gun_eject_hold(on: bool) -> bool:
	if not on:
		if gun_trk_anim != null:
			for i in gun_trk_off:
				if int(i) < gun_trk_anim.get_track_count():
					gun_trk_anim.track_set_enabled(int(i), true)
		gun_trk_anim = null
		gun_trk_off = []
		return true
	if gun_trk_anim != null:
		return true
	if gun_ctl == null or not is_instance_valid(gun_ctl):
		return false
	var an = gun_ctl.get("animator_shotgun")
	var aname := "player eject shell2" if gun_aim == "dealer" else "player eject shell"      # (iteration 36) the dealer-side eject
	if not (an is AnimationPlayer) or not (an as AnimationPlayer).has_animation(aname):
		return false
	var anim: Animation = (an as AnimationPlayer).get_animation(aname)
	if anim == null:
		return false
	gun_trk_off = []
	gun_eject_name = aname
	gun_eject_t = GUN_EJECT_T
	var has_m := false
	var t_m := INF
	for i in anim.get_track_count():
		var p := str(anim.track_get_path(i))
		var ty := anim.track_get_type(i)
		if (ty == Animation.TYPE_AUDIO and p.contains("rack shotgun")) or (ty == Animation.TYPE_METHOD and p.contains("shell eject manager")):
			anim.track_set_enabled(i, false)
			gun_trk_off.append(i)
			if ty == Animation.TYPE_METHOD:
				has_m = true
				if anim.track_get_key_count(i) > 0:
					t_m = minf(t_m, anim.track_get_key_time(i, 0))
	if not has_m:
		for i in gun_trk_off:
			anim.track_set_enabled(int(i), true)
		gun_trk_off = []
		return false                                  # the game's eject cannot be held back: the gun goes down as before
	if t_m < INF:
		gun_eject_t = maxf(t_m - 0.05, 0.0)
	gun_trk_anim = anim
	gun_eject_done = false
	print("VRBoot: shotgun kept - the game's own shell eject and rack sounds are held back (", gun_trk_off.size(), " tracks, '", gun_eject_name, "')")
	return true

func _gun_eject_watch() -> void:
	if gun_trk_anim == null or gun_ctl == null or not is_instance_valid(gun_ctl):
		return
	var an = gun_ctl.get("animator_shotgun")
	if an is AnimationPlayer and (an as AnimationPlayer).is_playing() and str((an as AnimationPlayer).current_animation) == gun_eject_name \
			and (an as AnimationPlayer).current_animation_position >= gun_eject_t:
		_gun_eject_book()

func _eject_em() -> Node:
	if cur_scene == null:
		return null
	var holder := cur_scene.find_child("shell parent_ejecting player side", true, false)
	return holder.get_node_or_null("shell eject manager") if holder != null else null

func _gun_eject_book() -> void:
	gun_eject_done = true
	var em := _eject_em()
	if em == null:
		return
	var sp = em.get("shellSpawner")
	var seq = sp.get("sequenceArray") if sp != null else null
	if not (seq is Array) or seq.is_empty():
		return
	gun_shell_state = str(seq[0])
	em.call("BeerEjection_player")
	var an = em.get("animator")
	if an is AnimationPlayer:
		(an as AnimationPlayer).stop()
	var mesh = em.get("mesh")
	if mesh is Node3D:
		(mesh as Node3D).visible = false
	gun_shell_pending = true
	print("VRBoot: the kept gun's shell (", gun_shell_state, ") is out of the sequence - it leaves the gun when the pump is racked")

# The pump is racked: the empty shell flies out of the gun in your hand.
func _gun_shell_fly(hand: Hand) -> void:
	gun_shell_pending = false
	var em := _eject_em()
	if em == null or fx_root == null:
		return
	var mesh = em.get("mesh")
	if not (mesh is MeshInstance3D) or (mesh as MeshInstance3D).mesh == null:
		return
	var c := MeshInstance3D.new()
	c.mesh = (mesh as MeshInstance3D).mesh
	var nsurf := c.mesh.get_surface_count()
	if nsurf > 0:
		c.set_surface_override_material(0, em.get("mat_brass"))
	if nsurf > 1:
		c.set_surface_override_material(1, em.get("mat_live") if gun_shell_state == "live" else em.get("mat_blank"))
	fx_root.add_child(c)
	var ws := world_scale
	var dir := gun_dir_cache.normalized()
	var port := hand.grip.global_position + dir * (0.2 * ws) + Vector3.UP * (0.03 * ws)
	var right := dir.cross(Vector3.UP)
	right = right.normalized() if right.length() > 0.1 else hand.grip.global_transform.basis.x.normalized()
	c.global_transform = Transform3D(Basis.from_euler(Vector3(-1.5708, -0.741067, 0.0)), port)
	var fy := (gun_main.global_position.y - 0.04) if gun_main != null and is_instance_valid(gun_main) else port.y - 0.5 * ws
	_fx_fall(c, right * 0.9 * ws + Vector3.UP * 1.3 * ws, Vector3(7.0, 11.0, 4.0), fy, 3.5)
	(fx_list[fx_list.size() - 1] as Dictionary)["snd"] = "drop"
	hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.05, 0.0)
	print("VRBoot: the empty shell left the gun with the rack")

func _pump_nodes() -> Array:
	var out: Array = []
	if gun_main == null or not is_instance_valid(gun_main):
		return out
	for nm in ["shotgun-forearm_001", "shotgun-forearm_003"]:
		var n := gun_main.find_child(nm, true, false)
		if n is Node3D:
			out.append(n)
	return out

func _pump_reset() -> void:
	for n in rit_pump_rest:
		if n is Node3D and is_instance_valid(n):
			(n as Node3D).position.y = float(rit_pump_rest[n])
	rit_pump_rest.clear()
	if rit_hand != null:
		rit_hand.holding = false
	rit_hand = null
	rit_pull = 0.0
	rit_pulled = false

# One frame of the pump, on the table or on the gun in your hand. frame = keep the pump framed (a ritual needs it).
# Returns -1 (no pump), 0 (nothing special), 1 (pulled all the way back just now) or 2 (a full rack).
func _pump_step(delta: float, frame: bool) -> int:
	var pn := _pump_nodes()
	var held := _gun_held_free() or (gun_state == 1 and gun_prop != null and is_instance_valid(gun_prop) and not gun_pairs.is_empty())
	if pn.is_empty() or not (gun_state == 0 or held):
		return -1
	var ws := world_scale
	for n in pn:
		if not rit_pump_rest.has(n):
			rit_pump_rest[n] = (n as Node3D).position.y
	var box := AABB()
	box.size = Vector3(-1.0, -1.0, -1.0)
	if held:
		for e in gun_pairs:
			var o: Node = e[0]
			for n in pn:
				if o == n or (n as Node).is_ancestor_of(o):
					var bc := _node_world_aabb(e[1], true)
					if bc.size.x >= 0.0:
						box = bc if box.size.x < 0.0 else box.merge(bc)
					break
	else:
		for n in pn:
			var b := _node_world_aabb(n, true)
			if b.size.x >= 0.0:
				box = b if box.size.x < 0.0 else box.merge(b)
	if box.size.x < 0.0:
		return -1
	var first: Node3D = pn[0]
	var pf: Transform3D = (first.get_parent() as Node3D).global_transform
	if held:
		pf = gun_prop.global_transform * (gun_main.global_transform.affine_inverse() * pf)
	var pinv := pf.affine_inverse()
	var rest0: float = rit_pump_rest[first]
	var res := 0
	var edges := {}
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		edges[hh.side] = hh.grip_sq and not bool(rit_down.get(hh.side, false))
		rit_down[hh.side] = hh.grip_sq
	if rit_hand == null:
		var show := frame
		for h in [left_hand, right_hand]:
			var hh: Hand = h
			if not hh.was_active or hh.holding:
				continue
			var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
			var dd := _point_box_dist(reach, box)
			if dd <= PUMP_GRAB_M * 2.5 * ws:
				show = true
			if bool(edges[hh.side]) and dd <= PUMP_GRAB_M * ws:
				rit_hand = hh
				hh.holding = true
				rit_goff = (pinv * reach).y - first.position.y
				hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)
				break
		if rit_hand == null and rit_pull <= 0.0 and show:
			poke_boxes.append(box)
		if rit_hand == null and rit_pull > 0.0:
			rit_pull = maxf(rit_pull - PUMP_SPRING * delta, 0.0)       # let go: the pump springs forward
			if rit_pull <= 0.0 and rit_pulled:
				res = 2
	else:
		var hh := rit_hand
		if not hh.was_active or not hh.grip_sq:
			hh.holding = false
			rit_hand = null
		else:
			var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
			var y := clampf((pinv * reach).y - rit_goff, rest0 - PUMP_TRAVEL, rest0)
			var np := rest0 - y
			if absf(np - rit_pull) > 0.02:
				rit_haptic_t -= delta
				if rit_haptic_t <= 0.0:
					rit_haptic_t = 0.07
					hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.12, 0.03, 0.0)
			rit_pull = np
			if frame:
				_ring_show(box.get_center() + Vector3.UP * (0.12 * ws), clampf(rit_pull / PUMP_PULL_OK, 0.0, 1.0), rit_pulled, 0.07)
	if rit_pull >= PUMP_PULL_OK and not rit_pulled:
		rit_pulled = true
		res = 1
		var hb: Hand = rit_hand if rit_hand != null else active_hand
		hb.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
		_fx_play(_anim_stream("player use beer", "back"))
	elif rit_pulled and rit_hand != null and rit_pull <= 0.2:
		res = 2                                  # pushed forward again while still holding it
		var hf: Hand = rit_hand
		hf.grip.trigger_haptic_pulse("haptic", 0.0, 0.8, 0.12, 0.0)
		hf.holding = false
		rit_hand = null
		rit_pull = 0.0
	for n in pn:
		(n as Node3D).position.y = float(rit_pump_rest[n]) - rit_pull
	if res == 2:
		_fx_play(_anim_stream("player use beer", "forward"))
	return res
