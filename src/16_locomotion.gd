# Walking, turning, blackout, rig guard, bounds
# (Part of the Buckshot Roulette VR mod. Chain position 16: this file extends 15_help_sign.gd; see src/README.md.)
extends "15_help_sign.gd"

const WALK_SPEED_M := 2.0                          # stick walking speed, metres per second

const WALK_LEASH_M := 14.0                         # how far you may roam from where the game put you (the whole lobby)

const WALK_RADIUS_M := 0.3                         # keep this far from solid things

const WALK_DEAD := 0.2                             # stick dead zone

const WALK_YIELD_SPEED_M := 0.6                    # the game is walking us (door, cutscene) above this speed

const SNAP_TURN := 0.5236                          # 30 degrees

const ARRIVE_M := 1.0                              # this close to the seat = you sit down

const WALK_TABLE_IDLE_S := 12.0                    # no stick input for this long = sit down for you

const STUCK_FAR_M := 2.0                           # at the table but further than this from the seat, with walking off, for 2 s = sat down for you

# Where you may walk (world X/Z in game units): [x, z, width, depth]. Measured from the game's floor tiles and doors.
const WALK_ROOMS := [
	Rect2(-172.0, -11.5, 33.0, 22.5),              # restroom
	Rect2(-135.0, -12.5, 96.5, 22.5),              # lobby
	Rect2(-36.0, -13.0, 24.0, 26.0),               # back room, up to the dealer's seat
]

const WALK_GAP_BATH := Rect2(-140.0, -6.8, 6.0, 8.4)    # bathroom doorway (shut until you open it)

const WALK_GAP_BACK := Rect2(-39.5, -4.8, 4.5, 9.6)     # back-room doorway

const BOUNDS_LEAN_M := 0.25                        # you may lean this far through a wall before the picture fades

const BOUNDS_FADE_M := 0.30                        # ... and it is fully black this much further

var blockers: Array = []

var blockers_scene: Node

var logos: Array = []              # the studio logo shown first in the main menu intro

var walk_move := 0.0              # 0..1 smoothed "I am walking" amount, drives the vignette

var stuck_t := 0.0                  # seconds at the table, far from the seat, with walking off

var jump_log_t := -10.0

var bounds_log_t := 0.0

var prev_blackout := 0.0

# The game hides the 3D view behind a black 2D rectangle ("viewblocker"). That cannot reach the
# headset, so we read its opacity and draw the same thing on a sphere around your head.
func _update_blackout() -> void:
	if cur_scene != blockers_scene:
		blockers_scene = cur_scene
		blockers.clear()
		if cur_scene != null:
			blockers = cur_scene.find_children("viewbl*", "ColorRect", true, false)
			logos.clear()
			if cur_scene.name == "menu":
				logos = cur_scene.find_children("ratchet", "TextureRect", true, false)
			print("VRBoot: fade blockers found: ", blockers.size(), "  intro logos: ", logos.size())
	var best := 0.0
	var best_col := Color(0, 0, 0)
	for b in blockers:
		if not is_instance_valid(b):
			continue
		var ci: CanvasItem = b
		if not ci.is_visible_in_tree():
			continue
		var a := 1.0
		var c = ci.get("color")
		if c is Color:
			a *= c.a
		a *= ci.self_modulate.a
		var n: Node = ci
		while n is CanvasItem:
			a *= (n as CanvasItem).modulate.a
			n = n.get_parent()
		if a > best:
			best = a
			best_col = c if c is Color else Color(0, 0, 0)
	blocker_alpha_raw = best
	# the game shows its first logo over the 3D background after two seconds; here the background
	# stays hidden until that logo has gone, then the game's own fade brings the menu in
	for lg in logos:
		if is_instance_valid(lg) and (lg as CanvasItem).is_visible_in_tree() and (lg as CanvasItem).modulate.a > 0.02:
			best = 1.0
			best_col = Color(0, 0, 0)
			break
	if prev_blackout > 0.5 and best < 0.05:
		probe_times.append(t_alive + 1.2)   # look at the window texture just after a fade-in
	prev_blackout = best
	if wall_fade > best:
		best = wall_fade                    # your head is through a wall: the picture goes dark
		best_col = Color(0, 0, 0)
	blackout_alpha = best
	blackout.visible = best > 0.004
	if blackout.visible:
		blackout_mat.albedo_color = Color(best_col.r, best_col.g, best_col.b, minf(best, 1.0))


# ------------------------------------------------------------------ walking

func _update_walk(delta: float) -> void:
	walk_idle_t += delta
	# stuck guard: at the table, not on your way there, far from the seat and unable to walk = sit down
	if mode == "table" and not walk_to_table and not needs_recenter and not kick_on and not hold_for_dealer \
			and not pause_open and not size_active and _in_main_scene() and regime_big \
			and xr_cam != null and is_instance_valid(xr_cam):
		if _dist_to_seat() > STUCK_FAR_M * world_scale:
			stuck_t += delta
			if stuck_t > 2.0:
				stuck_t = 0.0
				print("VRBoot: stuck guard - you were ", snappedf(_dist_to_seat() / world_scale, 0.1),
					" m from the seat with walking off; sat you down")
				_arrive_at_table()
		else:
			stuck_t = 0.0
	else:
		stuck_t = 0.0
	if hold_for_dealer:
		hold_t += delta
		if bath_pending and hold_t > 4.0:
			bath_pending = false          # the kick never started: let go
			hold_for_dealer = false
		if hold_t > 60.0:
			hold_for_dealer = false
	walk_allowed = stick_walk and _in_main_scene() and regime_big and not needs_recenter \
		and (mode == "follow" or walk_to_table) and not pause_open
	var target_move := 0.0
	if walk_allowed:
		target_move = _walk_input(delta)
		if walk_to_table:
			walk_to_table_t += delta
			if _dist_to_seat() < ARRIVE_M * world_scale \
					or (walk_idle_t > WALK_TABLE_IDLE_S and walk_to_table_t > 2.0) \
					or walk_to_table_t > 90.0:
				_arrive_at_table()
	elif walk_to_table and (not stick_walk or not _in_main_scene() or not regime_big):
		_arrive_at_table()

	var show_beacon := (walk_to_table or (hold_for_dealer and not kick_bath and not bath_pending)) and walk_allowed
	beacon.visible = show_beacon
	if show_beacon:
		beacon.global_position = _seat_point()
		beacon.scale = Vector3(ARRIVE_M * world_scale, 3.2 * world_scale, ARRIVE_M * world_scale)
		beacon_mat.albedo_color = Color(0.35, 1.0, 0.6, 0.10 + 0.06 * sin(t_alive * 3.0))

	var rate := 6.0 if target_move > walk_move else 2.5
	walk_move = move_toward(walk_move, target_move, delta * rate)
	var v := walk_move if comfort_vignette else 0.0
	vignette.visible = v > 0.01
	if vignette.visible:
		vignette_mat.set_shader_parameter("vig", v)

# Left stick = walk (relative to where your head looks), right stick = 30 degree snap turns.
# Returns how hard you are walking (0..1) for the comfort vignette.
func _walk_input(delta: float) -> float:
	var mv := Vector2.ZERO
	var tx := 0.0
	if left_hand.was_active and not gun_cal_on:
		mv = left_hand.grip.get_vector2("primary")
	if right_hand.was_active and not gun_cal_on:
		tx = right_hand.grip.get_vector2("primary").x

	if turn_dir == 0:
		if absf(tx) > STICK_ON:
			turn_dir = 1 if tx > 0.0 else -1
			_turn_rig(-float(turn_dir) * SNAP_TURN)
			walk_idle_t = 0.0
	elif absf(tx) < STICK_OFF:
		turn_dir = 0

	var free_walk := walk_to_table or hold_for_dealer or kick_on
	if not free_walk and not adr_tp_on and anchor_speed > WALK_YIELD_SPEED_M * world_scale:
		# The game itself is walking us somewhere (a door, a cutscene): hand control back smoothly.
		var k := 1.0 - exp(-delta / 0.8)
		var back := -walk_off * k
		walk_off += back
		origin.global_position += back
		return 0.0

	var ml := mv.length()
	if ml < WALK_DEAD:
		return 0.0
	var amt := minf((ml - WALK_DEAD) / (1.0 - WALK_DEAD), 1.0)
	var dir2 := mv / ml
	var h := _heading_of_vec(-xr_cam.global_transform.basis.z, anchor_yaw)
	var fwd := Vector3(-sin(h), 0.0, -cos(h))
	var rgt := Vector3(cos(h), 0.0, -sin(h))
	var step := (fwd * dir2.y + rgt * dir2.x) * (WALK_SPEED_M * world_scale * amt * delta)
	step = _bounds_clip(step)         # never through a wall
	if not free_walk:
		step = _walk_clip(step)     # on the way to the dealer nothing may block you
		var want := walk_off + step
		var leash := WALK_LEASH_M * world_scale
		if want.length() > leash:
			want = want.normalized() * leash
		step = want - walk_off
		walk_off = want
	if step.length() < 0.00001:
		return 0.0
	origin.global_position += step
	walk_idle_t = 0.0
	return amt

# Do not walk into solid things: a short ray from your head along the step, with sliding.
func _walk_clip(step: Vector3) -> Vector3:
	if step.length() < 0.00001:
		return step
	var head := xr_cam.global_position
	var space := get_tree().root.world_3d.direct_space_state
	var rad := WALK_RADIUS_M * world_scale
	var tries: Array[Vector3] = [step, Vector3(step.x, 0.0, 0.0), Vector3(0.0, 0.0, step.z)]
	for s in tries:
		var l := s.length()
		if l < 0.00001:
			continue
		var q := PhysicsRayQueryParameters3D.create(head, head + s / l * (l + rad))
		if space.intersect_ray(q).is_empty():
			return s
	return Vector3.ZERO

# Rotates the whole rig around your head (so you turn on the spot).
func _turn_rig(angle: float) -> void:
	var head := xr_cam.global_position
	var rot := Basis(Vector3.UP, angle)
	var t := origin.global_transform
	t.origin = head + rot * (t.origin - head)
	t.basis = rot * t.basis
	origin.global_transform = t

func _arrive_at_table() -> void:
	walk_to_table = false
	hold_for_dealer = false
	walk_off = Vector3.ZERO
	walk_move = 1.0                 # the vignette fades out and hides the small hop into the seat
	needs_recenter = false
	_place_origin(false)
	print("VRBoot: seated at the table")

# Makes anchor + walk_off describe where your head really is (the game camera may be elsewhere).
func _sync_walk_off() -> void:
	if xr_cam == null or not is_instance_valid(xr_cam):
		return
	walk_off = xr_cam.global_position - anchor_pos - Basis(Vector3.UP, anchor_yaw) * seat

# Last line of defence: nothing but your own walking may carry you away while the door kick plays.
func _rig_guard(head_start: Vector3, origin_start: Transform3D, delta: float) -> void:
	if xr_cam == null or not is_instance_valid(xr_cam) or delta <= 0.0:
		return
	var jump := xr_cam.global_position - head_start
	var jh := Vector3(jump.x, 0.0, jump.z)
	var thr := 2.0 + 25.0 * delta
	if jh.length() <= thr:
		return
	var info := " (needs_recenter=" + str(needs_recenter) + " hold=" + str(hold_for_dealer) + " mode=" + mode \
		+ " anchor=" + str(anchor_pos) + " walk_off=" + str(walk_off) + " to_table=" + str(walk_to_table) + ")"
	if kick_on and mode != "table":
		origin.global_transform = origin_start
		needs_recenter = false
		if guard_prints < 12:
			guard_prints += 1
			print("VRBoot: guard: undid a sudden move of ", snappedf(jh.length(), 0.1), " units during the door kick", info)
	elif t_alive - jump_log_t > 1.0:
		jump_log_t = t_alive
		print("VRBoot: rig jumped ", snappedf(jh.length(), 0.1), " units in one frame", info)

func _walk_rects(doors_as_flags: bool) -> Array:
	var rs: Array = []
	for r in WALK_ROOMS:
		rs.append(r)
	if not doors_as_flags or gap_bath_open:
		rs.append(WALK_GAP_BATH)
	if not doors_as_flags or gap_back_open:
		rs.append(WALK_GAP_BACK)
	return rs

func _update_bounds(delta: float) -> void:
	var target := 0.0
	bounds_on = false
	if _in_main_scene() and regime_big and (mode == "follow" or walk_to_table) \
			and game_cam != null and xr_cam != null and not needs_recenter:
		var gc := Vector2(game_cam.global_position.x, game_cam.global_position.z)
		var all := _walk_rects(false)
		# only inside the building areas we know; elsewhere (cutscenes) the game moves us freely
		if _rect_dist(gc, all) <= 4.0 * world_scale:
			bounds_on = true
			var head := Vector2(xr_cam.global_position.x, xr_cam.global_position.z)
			# you can only be past a doorway if you got through it: treat that door as open from now on
			if head.x > -135.0 and head.x < -39.0:
				gap_bath_open = true
			if head.x > -36.0:
				gap_back_open = true
			# only what YOU add counts: if the game's own camera stands near a wall (a close-up), that is fine
			var pen := maxf(_rect_dist(head, all) - _rect_dist(gc, all), 0.0)
			target = clampf((pen - BOUNDS_LEAN_M * world_scale) / (BOUNDS_FADE_M * world_scale), 0.0, 1.0)
	wall_fade = move_toward(wall_fade, target, delta * (6.0 if target > wall_fade else 2.0))

# A walking step that keeps your head inside the rooms (slides along walls).
func _bounds_clip(step: Vector3) -> Vector3:
	if not bounds_on or xr_cam == null:
		return step
	var head := xr_cam.global_position
	var p0 := Vector2(head.x, head.z)
	var rs := _walk_rects(true)
	var d0 := _rect_dist(p0, rs)
	var tries: Array[Vector3] = [step, Vector3(step.x, 0.0, 0.0), Vector3(0.0, 0.0, step.z)]
	for s in tries:
		if s.length() < 0.00001:
			continue
		var d1 := _rect_dist(p0 + Vector2(s.x, s.z), rs)
		if d1 <= 0.0 or (d0 > 0.0 and d1 < d0):
			return s
	if t_alive - bounds_log_t > 3.0:
		bounds_log_t = t_alive
		print("VRBoot: wall - stopped at (", snappedf(head.x, 0.1), ", ", snappedf(head.z, 0.1), ")")
	return Vector3.ZERO



# ------------------------------------------------------------------ floor plan dump (tuning aid)
