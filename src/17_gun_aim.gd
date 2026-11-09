# Gun: pose, two-hand hold, nudge, aim, trigger, slow-motion boost
# (Part of the Buckshot Roulette VR mod. Chain position 17: this file extends 16_locomotion.gd; see src/README.md.)
extends "16_locomotion.gd"

const GUN_SUP_GRAB_M := 0.10                       # (iteration 37) the other hand this close (real metres) to the barrel axis (grip squeeze) holds the gun

const GUN_SUP_MIN_M := 0.10                        # ...at least this far in front of the gun hand

const GUN_AIM_S := 0.35                            # the aim must be steady this long before the trigger fires

const GUN_SELF_DEG := 24.0                         # barrel this close to pointing at your head = "you"

const GUN_DEALER_YAW_DEG := 30.0                   # muzzle within this of straight ahead (sideways) = "dealer"

const GUN_DEALER_PITCH_DEG := 35.0                 # ...and within this up / down

# How the hand sits on the gun: the game's own grip. The game has a hand mesh for exactly this ("dealer hand_shotgun right", a
# child of the gun): the back of the hand on the right of the neck, the fingers under it, the thumb on top, the arm running back
# along the stock. The game's hand is about 1.4 times the size of a real one, so it is shrunk (0.72) around the neck and nudged a
# little so that the fingers do not sink into the wood. Columns = the hand mesh's X, Y, Z axes in model units, ORG = its origin.
# (The left hand is the mirror image: the gun is symmetric.)
const GUN_HAND_LIN := Basis(Vector3(0.14902, -0.67812, 0.19065), Vector3(0.37295, 0.24127, 0.56665), Vector3(-0.59758, -0.01853, 0.40119))

const GUN_HAND_ORG := Vector3(0.05247, -2.70904, -0.33464)

const GUN_MODEL_MUZZLE := Vector3(0.0, 6.6, 0.1)   # the muzzle end of the model

const GUN_SLIDE_MAX_Y := 6.0                       # aimed at yourself the hand may slide along the gun up to near the muzzle

const GUN_FACE_R_M := 0.16                         # (iteration 38) the barrel line passes this close to your mouth/face = you aim at yourself

const GUN_MUZZLE_FACE_M := 0.13                    # ...or the muzzle itself is this close to your mouth (in it, at the lips)

const GUN_SELF_GAP_M := 0.14                       # ...so that the muzzle stays this far (real metres) from your eyes

const GUN_SELF_FADE_DEG := 55.0                    # the grip starts to slide when the barrel is this close to pointing at your head

const GUN_SLIDE_RATE := 9.0                        # how fast the gun slides through the hand (per second)

const GUN_FIRE_TS := 8.0                           # game speed while it plays the build-up to the shot (it waits about 2.75 s)

const GUN_CAL_RATE := 0.03                        # nudge mode: real metres per second at full stick

const GUN_HAND_HOLE := Vector3(-0.0066, 0.0038, -0.0171)    # where the neck passes through the hand, from the controller's grip point (real metres, right hand; x is mirrored for the left)

const GUN_FIRE_MAX_S := 2.0                        # real seconds after which the speed-up is dropped whatever happens

var gun_cal_by := false

var gun_sup_b := Basis.IDENTITY

var gun_sup_ref: Hand = null       # the hand that gun_sup_g was measured for

var gun_sup_g := Vector3.ZERO      # where that hand was, from the gun hand, in the gun hand's own frame when it took hold

var gun_sup_rel := Transform3D.IDENTITY   # the holding hand's look, in the gun's frame

var gun_pump_node: Node3D = null

var gun_pump_rel := Transform3D.IDENTITY

var gun_muzzle := Vector3.ZERO

var boost_on := false               # Engine.time_scale is raised until the bang

var boost_ms := 0

# The shotgun follows the hand's pointing direction. The game's own model: the hand holds the wrist of the stock;
# aimed at yourself the hand slides along the gun toward the pump so that the muzzle stops short of your face
# (the real gun is about as long as your arm).
func _gun_sup_drop() -> void:
	gun_pump_hand = null
	gun_pump_node = null
	if gun_sup_hand != null:
		gun_sup_hand.holding = false
		gun_sup_hand = null
	gun_sup_ref = null

# (iteration 37) The other hand takes hold of the gun in the hand: grip squeeze with the hand on the barrel (10 cm or more in
# front of the gun hand), at any time. The hand stays on the gun where it took hold; the gun follows the line between the hands.
# (The pump keeps its own grab: a hand at the pump racks it - that one is _pump_step.)
func _gun_pump_clone() -> Node3D:
	for n in _pump_nodes():
		for e in gun_pairs:
			var o: Node = e[0]
			if o == n or (n as Node).is_ancestor_of(o):
				return e[1] as Node3D
	return null

func _gun_sup_update(hand: Hand, may_grab: bool) -> void:
	if rit_hand != null and gun_state == 1 and not gun_pairs.is_empty() and gun_prop != null and is_instance_valid(gun_prop):
		if gun_pump_hand != rit_hand:
			var cl := _gun_pump_clone()
			if cl != null and is_instance_valid(cl):
				gun_pump_hand = rit_hand
				gun_pump_node = cl
				gun_pump_rel = cl.global_transform.affine_inverse() * rit_hand.visual.global_transform
		if gun_pump_hand == rit_hand and gun_pump_node != null and is_instance_valid(gun_pump_node):
			rit_hand.visual.global_transform = gun_pump_node.global_transform * gun_pump_rel     # the hand sits on the pump
	else:
		gun_pump_hand = null
		gun_pump_node = null
	if gun_sup_hand != null:
		var sh := gun_sup_hand
		if not sh.was_active or not sh.grip_sq or gun_prop == null or not is_instance_valid(gun_prop) or gun_pairs.is_empty() or gun_cal_on:
			print("VRBoot: ", sh.side, " hand let go of the gun")
			_gun_sup_drop()
		gun_sup_down[sh.side] = sh.grip_sq
		if gun_sup_hand != null:
			return
	var h2: Hand = right_hand if hand == left_hand else left_hand
	var sq: bool = h2.grip_sq
	var edge: bool = sq and not bool(gun_sup_down.get(h2.side, false))
	gun_sup_down[h2.side] = sq
	if not may_grab or not edge or not h2.was_active or h2.holding or rit != "" or rit_hand != null or gun_pairs.is_empty() \
			or gun_prop == null or not is_instance_valid(gun_prop):
		return
	var ws := world_scale
	var reach := h2.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
	var from: Vector3 = hand.grip.global_position
	var axis: Vector3 = gun_muzzle - from
	if axis.length() < 0.05:
		return
	var an := axis.normalized()
	var p0 := from + an * (GUN_SUP_MIN_M * ws)
	if (reach - from).dot(an) < GUN_SUP_MIN_M * ws:
		return
	var on_axis: Vector3 = Geometry3D.get_closest_point_to_segment(reach, p0, gun_muzzle)
	if reach.distance_to(on_axis) > GUN_SUP_GRAB_M * ws:
		return
	gun_sup_hand = h2
	gun_sup_ref = null
	gun_sup_w = 0.0
	h2.holding = true
	gun_sup_rel = gun_prop.global_transform.affine_inverse() * h2.visual.global_transform
	h2.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: the ", h2.side, " hand holds the gun too (", snappedf(reach.distance_to(from) / ws, 0.01), " m from the gun hand)")

func _gun_pose(hh: Hand, delta: float) -> void:
	var src: XRController3D = hh.aim if hh.aim.get_has_tracking_data() else hh.grip
	var b: Basis = src.global_transform.basis.orthonormalized()
	# (iteration 37) Two hands: the other hand - on the pump or holding the barrel anywhere (see _gun_sup_update) - keeps the point it
	# holds on the line from the gun hand to it, whatever it is: the gun turns the least that does it (the roll stays the gun hand's).
	var sup: Hand = rit_hand if (rit_hand != null and rit_hand != hh) else gun_sup_hand
	if (gun_state == 1 or gun_state == 2) and sup != null and sup != hh and sup.was_active and not gun_pairs.is_empty():
		var sv: Vector3 = sup.grip.global_position - hh.grip.global_position
		if sup != gun_sup_ref:
			gun_sup_ref = sup
			gun_sup_g = b.inverse() * sv                  # at this moment the gun is exactly where the gun hand has it: no jump
			gun_sup_w = 0.0
		var cur: Vector3 = b * gun_sup_g
		if sv.length() > 0.08 * world_scale and cur.length() > 0.001 and cur.normalized().angle_to(sv.normalized()) < deg_to_rad(80.0):
			gun_sup_b = (Basis(Quaternion(cur.normalized(), sv.normalized())) * b).orthonormalized()
			gun_sup_ok = true
			gun_sup_w = minf(gun_sup_w + delta * 8.0, 1.0)
		else:
			gun_sup_w = maxf(gun_sup_w - delta * 6.0, 0.0)
	else:
		gun_sup_ref = null
		gun_sup_w = maxf(gun_sup_w - delta * 6.0, 0.0)
	if gun_sup_w > 0.0 and gun_sup_ok:
		b = Basis(Quaternion(b).slerp(Quaternion(gun_sup_b), gun_sup_w)).orthonormalized()
	gun_recoil = maxf(gun_recoil - delta * 5.0, 0.0)
	var aimed := b
	if gun_recoil > 0.0:
		b = Basis(b.x.normalized(), deg_to_rad(14.0) * gun_recoil) * b
	gun_dir_cache = -aimed.z
	var hp := hh.grip.global_position
	if gun_pairs.is_empty():
		# fallback model of our own (metres, scaled by the world size)
		gun_prop.global_transform = Transform3D(b.scaled(Vector3.ONE * world_scale), hp)
		gun_muzzle = gun_prop.global_transform * Vector3(0.0, 0.035, -0.56)
		return
	var ws := world_scale
	# the game's fist closes a little ahead of the controller's grip point: the stock goes there
	var sgn := -1.0 if hh.side == "left" else 1.0
	var hole := Vector3((GUN_HAND_HOLE.x + gun_cal.x) * sgn, GUN_HAND_HOLE.y + gun_cal.y, GUN_HAND_HOLE.z + gun_cal.z)
	hp = hh.grip.global_transform * (hole * ws)
	var to_head := xr_cam.global_position - hp
	var d := to_head.length()
	var want := 0.0
	if d > 0.05 and d < 1.2 * ws:
		want = clampf(inverse_lerp(deg_to_rad(GUN_SELF_FADE_DEG), deg_to_rad(GUN_SELF_DEG), gun_dir_cache.angle_to(to_head)), 0.0, 1.0)
	if _gun_face_aim(hp, gun_dir_cache, false):
		want = 1.0                                       # (iteration 38) the barrel line runs through the mouth: slide the gun short of the face
	var target := GUN_MODEL_GRIP.y
	if want > 0.0:
		var reach := maxf(d - GUN_SELF_GAP_M * ws, 0.5)          # how far the muzzle may stand in front of the hand
		var gy_self := clampf(GUN_MODEL_MUZZLE.y - reach / gun_k, GUN_MODEL_GRIP.y, GUN_SLIDE_MAX_Y)
		target = lerpf(GUN_MODEL_GRIP.y, gy_self, want)
	gun_gy = target if delta <= 0.0 else lerpf(gun_gy, target, clampf(1.0 - exp(-GUN_SLIDE_RATE * delta), 0.0, 1.0))
	# model +Y (barrel) -> hand -Z (forward), model +Z (up) -> hand +Y, model +X (right) -> hand +X
	var mb: Basis = b * (Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)) * gun_k)
	var grip := Vector3(GUN_MODEL_GRIP.x, gun_gy, GUN_MODEL_GRIP.z)
	gun_prop.global_transform = Transform3D(mb, hp - mb * grip)
	if gun_put_t > GUN_PUT_DELAY_S:
		# after the shot: glide into the game's own gun (wherever its animation has it right now)
		var w := clampf((gun_put_t - GUN_PUT_DELAY_S) / GUN_PUT_S, 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		var tgt := gun_main.global_transform
		var qb := Basis(Quaternion(mb.orthonormalized()).slerp(Quaternion(tgt.basis.orthonormalized()), w)) * gun_k
		gun_prop.global_transform = Transform3D(qb, gun_prop.global_transform.origin.lerp(tgt.origin, w))
	gun_muzzle = gun_prop.global_transform * GUN_MODEL_MUZZLE
	_gun_hand_follow(hh, ws)
	if gun_sup_hand != null and is_instance_valid(gun_sup_hand.visual):
		gun_sup_hand.visual.global_transform = gun_prop.global_transform * gun_sup_rel         # the holding hand sits on the gun
	# the parts of the game's gun (the pump slides, the muzzle flash model flashes) follow their originals
	var inv := gun_main.global_transform.affine_inverse()
	for e in gun_pairs:
		var o: MeshInstance3D = e[0]
		var c: MeshInstance3D = e[1]
		if not is_instance_valid(o) or not is_instance_valid(c):
			continue
		c.transform = inv * o.global_transform
		c.visible = _gun_part_vis(o)

# Nudge mode (click the stick of the hand that holds the shotgun): the gun - and the hand fixed to it - moves in your hand
# until it feels right. Stick of the gun hand: sideways / up-down. Stick of the other hand: in / out (along the barrel).
# B / Y of the other hand: back to the standard place. Click again: saved. Nothing can fire meanwhile.
func _gun_cal_toggle() -> void:
	if gun_cal_on:
		_gun_cal_end()
		return
	gun_cal_on = true
	gun_cal_by = false
	if gun_hand != null:
		gun_hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: gun hand nudge mode on (now ", gun_cal, ")")

func _gun_cal_end() -> void:
	if not gun_cal_on:
		return
	gun_cal_on = false
	_save_settings()
	print("VRBoot: gun hand nudge saved: ", gun_cal)

func _gun_cal_tick(hand: Hand, dt: float) -> void:
	var other: Hand = left_hand if hand == right_hand else right_hand
	var s := hand.grip.get_vector2("primary")
	var s2 := Vector2.ZERO
	if other.was_active:
		s2 = other.grip.get_vector2("primary")
	if s.length() < 0.2:
		s = Vector2.ZERO
	if absf(s2.y) < 0.2:
		s2.y = 0.0
	var sgn := -1.0 if hand.side == "left" else 1.0
	gun_cal.x = clampf(gun_cal.x + s.x * GUN_CAL_RATE * dt * sgn, -GUN_CAL_MAX, GUN_CAL_MAX)
	gun_cal.y = clampf(gun_cal.y + s.y * GUN_CAL_RATE * dt, -GUN_CAL_MAX, GUN_CAL_MAX)
	gun_cal.z = clampf(gun_cal.z - s2.y * GUN_CAL_RATE * dt, -GUN_CAL_MAX, GUN_CAL_MAX)
	var by := other.was_active and other.grip.is_button_pressed("by_button")
	if by and not gun_cal_by:
		gun_cal = Vector3.ZERO
		hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	gun_cal_by = by
	var cb: Basis = xr_cam.global_transform.basis.orthonormalized()
	var at: Vector3 = xr_cam.global_position - cb.z * (0.55 * world_scale) - cb.y * (0.16 * world_scale)
	_hint_show("MOVE THE GUN IN YOUR HAND\nSTICK: SIDE / UP   OTHER STICK: IN / OUT\nB / Y: RESET   CLICK: SAVE", at, true)

# The hand is fixed to the gun's neck, not to the controller: it moves, turns and kicks with the gun, and when the gun
# slides away from you while you point it at yourself the hand goes with it (nothing glides through the fist).
func _gun_hand_follow(hh: Hand, _ws: float) -> void:
	var lin := GUN_HAND_LIN
	var org := GUN_HAND_ORG
	if hh.side == "left":
		# the mirror image (x -> -x before and after; the hand mesh itself is mirrored in _ensure_gun_pose)
		lin = Basis(Vector3(lin.x.x, -lin.x.y, -lin.x.z), Vector3(-lin.y.x, lin.y.y, lin.y.z), Vector3(-lin.z.x, lin.z.y, lin.z.z))
		org = Vector3(-org.x, org.y, org.z)
	hh.visual.global_transform = gun_prop.global_transform * Transform3D(lin, org)

# The game's own gun hand (a mesh inside the game's gun node: borrowed at run time, nothing is copied) as one more shape of
# this hand. Its units are the gun model's, so it sits on the gun's transform (see _gun_hand_follow).
func _ensure_gun_pose(hh: Hand) -> void:
	if hh.poses.has("gun") or gun_main == null or not is_instance_valid(gun_main):
		return
	var src := gun_main.find_child("dealer hand_shotgun right", true, false) as MeshInstance3D
	if src == null or src.mesh == null:
		return
	var mesh: Mesh = src.mesh
	var mi := MeshInstance3D.new()
	mi.name = "VRBootGunHand_" + hh.side
	mi.mesh = mesh
	if hh.side == "left":
		mi.transform = Transform3D(Basis.from_scale(Vector3(-1.0, 1.0, 1.0)), Vector3.ZERO)
	var mat := _make_hand_material(mesh.surface_get_material(0))
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	hh.visual.add_child(mi)
	hh.poses["gun"] = mi
	print("VRBoot: the game's gun hand is the ", hh.side, " hand's grip shape")


# ------------------------------------------------------------------ the item box by hand
# The game hands out an item when its "briefcase intake" is clicked (ItemManager.GrabItem) and puts it into a slot of the
# table when a slot is clicked (PlaceDownItem). By hand: squeeze the grip with a hand inside the box to take an item, carry
# it, and let go over the table: it goes into the free slot nearest to it. Both steps are the game's own functions.

# The game waits about 2.75 s (timers) between "shoot at the dealer/yourself" and the bang. Its timers and animations
# follow Engine.time_scale, so we run the game faster until the speaker plays, then back to normal.
func _gun_boost_start() -> void:
	if boost_on or not is_equal_approx(Engine.time_scale, 1.0):
		return
	boost_on = true
	boost_ms = Time.get_ticks_msec()
	_game_ts_stop()
	Engine.time_scale = GUN_FIRE_TS
	print("VRBoot: shotgun - the game's build-up to the shot runs x", GUN_FIRE_TS, " faster")

func _gun_boost_end(why: String) -> void:
	if not boost_on:
		return
	boost_on = false
	if is_equal_approx(Engine.time_scale, GUN_FIRE_TS):
		Engine.time_scale = 1.0           # (if the game has set its own slow motion meanwhile we leave that alone)
	print("VRBoot: shotgun - normal game speed again (", why, ", ", Time.get_ticks_msec() - boost_ms, " ms real)")

func _gun_boost_watch() -> void:
	if not boost_on:
		return
	if Time.get_ticks_msec() - boost_ms > int(GUN_FIRE_MAX_S * 1000.0):
		_gun_boost_end("timeout")
	elif gun_state != 2 or not _in_main_scene():
		_gun_boost_end("state changed")

# (iteration 38) Aimed at your face, measured at the mouth: the line of the barrel passes within GUN_FACE_R_M of it. The old test (angle to
# the eyes, hand >= 12 cm away) failed when the gun was held close or low: the angle grows as the muzzle comes nearer.
func _gun_face_aim(hp: Vector3, dir: Vector3, muzzle_too: bool, loose := 1.0) -> bool:
	var ws := world_scale
	var mp := _mouth_point()
	var to := mp - hp
	var d := to.length()
	if d < 0.02 * ws or d > 1.25 * ws:
		return false
	var t := to.dot(dir)
	if t > 0.0 and (to - dir * t).length() <= GUN_FACE_R_M * ws * loose:
		return true
	return muzzle_too and gun_muzzle.distance_to(mp) <= GUN_MUZZLE_FACE_M * ws * loose and dir.dot(to / d) > 0.3

func _gun_aim_update(hh: Hand, delta: float) -> void:
	var ws := world_scale
	var dir: Vector3 = gun_dir_cache
	var head := xr_cam.global_position
	var to_head := head - hh.grip.global_position
	var cand := ""
	# "you": the barrel line runs through your head and the hand is held out at about the gun's length from it
	if to_head.length() > 0.12 * ws and to_head.length() < 1.1 * ws and dir.angle_to(to_head) < deg_to_rad(GUN_SELF_DEG):
		cand = "self"
	elif _gun_face_aim(hh.grip.global_position, dir, true, 1.5 if gun_aim == "self" else 1.0):
		cand = "self"                                    # (iteration 38) at / in the mouth
	else:
		var fwd := Basis(Vector3.UP, HOME_YAW) * Vector3(0.0, 0.0, -1.0)
		var flat := Vector3(dir.x, 0.0, dir.z)
		if flat.length() > 0.2:
			var pitch := rad_to_deg(asin(clampf(dir.y, -1.0, 1.0)))
			var ahead := (gun_muzzle - head).dot(fwd)
			if flat.normalized().angle_to(fwd) < deg_to_rad(GUN_DEALER_YAW_DEG) \
					and absf(pitch) < GUN_DEALER_PITCH_DEG and ahead > 0.25 * ws:
				cand = "dealer"
	if cand != gun_aim:
		gun_aim = cand
		gun_aim_t = 0.0
	else:
		gun_aim_t += delta
	var locked := gun_aim != "" and gun_aim_t >= GUN_AIM_S
	if locked != gun_locked:
		gun_locked = locked
		if locked:
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.35, 0.05, 0.0)
			print("VRBoot: shotgun aimed at ", "the dealer" if gun_aim == "dealer" else "yourself", " - the trigger fires")

func _gun_trigger(hh: Hand) -> void:
	if gun_state != 1:
		return
	if gun_need_rack:
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.04, 0.0)
		print("VRBoot: shotgun trigger - the pump has to be racked first")
		return
	if not gun_locked:
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.04, 0.0)
		print("VRBoot: shotgun trigger - not aimed at the dealer or at you yet")
		return
	var alias := "text dealer" if gun_aim == "dealer" else "text you"
	if not gun_game:
		# the game learns of the shotgun only now: its own pick-up (items off, the words), the shot follows a moment later
		if rit != "" or item_hand != null or not _allowed(gun_branch):
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.04, 0.0)
			print("VRBoot: shotgun trigger - not now (an item is in use, or the game does not allow it)")
			return
		gun_game = true
		_pump_reset()
		interaction.call("InteractWith", "shotgun")
		gun_fire_alias = alias
		gun_fire_t = 0.25
		gun_state = 2
		gun_t = 0.0
		gun_bang_prev = false
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
		print("VRBoot: shotgun fired at ", "the dealer" if gun_aim == "dealer" else "yourself", " ('", alias, "') after the game's pick-up")
		return
	gun_state = 2
	gun_t = 0.0
	gun_bang_prev = false
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: shotgun fired at ", "the dealer" if gun_aim == "dealer" else "yourself", " ('", alias, "')")
	interaction.call("InteractWith", alias)
	_gun_boost_start()
