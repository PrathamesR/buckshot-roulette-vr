# Scene tracking: game references, anchor, regime, placement, scale
# (Part of the Buckshot Roulette VR mod. Chain position 07: this file extends 06_brackets.gd; see src/README.md.)
extends "06_brackets.gd"

const TABLE_MIN_X := -40.0                         # camera further left than this = intro / lobby area

const FOLLOW_SNAP_DIST := 6.0                      # outside the table: re-seat when the camera moved this far

const FOLLOW_SNAP_ANGLE := 0.7854                  # ... or turned this much (radians)

const BIG_MAX_Y := 30.0                            # in the main scene, camera below this = inside the building

const RECENTER_SETTLE := 0.15                      # seconds to wait after a scale change before re-seating

const CUT_DIST := 8.0                              # camera moved this far in ONE frame = a cut, not a walk

const TABLE_ENTER_DIST := 6.0                      # camera this close to "home" = we have arrived at the table

const REAIM_ANGLE := 0.5                           # radians; re-face the camera's new heading after a walk

const DETACH_FAR_M := 1.5                          # further than this when the game arrives = you walk there

var have_prev_cam := false

var still_t := 0.0

var hook_tries := 0

func _update_game_refs() -> void:
	if game_cam != null and not is_instance_valid(game_cam):
		game_cam = null
	var cam := get_tree().root.get_camera_3d()
	if cam != game_cam:
		game_cam = cam
		if cam != null:
			print("VRBoot: game camera ", cam.get_path(), " pos=", cam.global_position, " fov=", cam.fov)

	var scene := get_tree().current_scene
	if scene != cur_scene:
		cur_scene = scene
		interaction = null
		mouse_ray = null
		hook_tries = 0
		_request_recenter()
		mode = ""
		ui_active = false
		walk_off = Vector3.ZERO
		adr_tp_on = false
		adr_tp_re = false
		walk_to_table = false
		hold_for_dealer = false
		turn_dir = 0
		postfx_nodes.clear()
		retro_levels = Vector3.ZERO
		hint_nodes.clear()
		shape_cache.clear()
		poke_in.clear()
		poke_cool.clear()
		btn_state.clear()
		btn_prev.clear()
		btn_driven.clear()
		btn_held.clear()
		poke_boxes.clear()
		brief_node = null
		brief_end0_ok = false
		brief_placed = false
		nm_sign = null
		nm_find_t = 0.0
		nm_vis_seen = false
		nm_locked = false
		nm_lock_t = 0.0
		nm_hidden = false
		splat = null
		splat_search_t = 0.0
		splat_prev = 1.0
		restroom_stage = false
		pill_menu_active = false
		pill_yes = null
		pill_no = null
		tv_state = 0
		tv_close_pending = false
		bath_left = false
		if is_instance_valid(pill_prop):
			pill_prop.queue_free()
		pill_prop = null
		pill_hand = null
		pill_node = null
		pill_state = 0
		pill_busy = false
		kick_on = false
		kick_bath = false
		bath_pending = false
		orig_leg = null
		orig_leg_on = false
		club_pending = false
		club_nodes.clear()
		if is_instance_valid(kick_leg):
			kick_leg.queue_free()
		kick_leg = null
		left_hand.holding = false
		right_hand.holding = false
		env_logged = false
		if pause_open:
			_pause_close()
		gap_bath_open = false
		gap_back_open = false
		wall_fade = 0.0
		scan_times = [t_alive + 0.5, t_alive + 4.0]
		probe_times = [t_alive + 3.0, t_alive + 8.0]
		print("VRBoot: scene is now ", scene.name if scene != null else "(none)")

	if cur_scene != null and (interaction == null or not is_instance_valid(interaction)):
		interaction = null
		if hook_tries < 600:
			hook_tries += 1
			var im := cur_scene.find_child("interaction manager", true, false)
			if im != null:
				interaction = im
				var mr = im.get("mouseRay")
				if mr is Node:
					mouse_ray = mr
					mouse_ray.set_process(false)   # we feed MouseRaycast.result ourselves
				print("VRBoot: hooked interaction manager ", im.get_path(), " mouse_ray=", mouse_ray)

# Where the player's eyes should be (the "anchor") for the current moment.
#   table  : fixed at the game's "home" seat, ignores the game camera completely.
#   follow : the game camera walks us around (intro). We copy its POSITION only, smoothed,
#            never its rotation or bobbing, so a walk is a gentle glide instead of a spin.
func _update_anchor(delta: float) -> void:
	anchor_speed = 0.0
	if game_cam == null:
		return
	var changed := false
	var cp := game_cam.global_position
	var cut := have_prev_cam and not kick_on and cp.distance_to(prev_cam_pos) > CUT_DIST
	prev_cam_pos = cp
	have_prev_cam = true
	_set_regime(_in_main_scene() and cp.y < BIG_MAX_Y)
	var cam_yaw := _heading_of_vec(-game_cam.global_transform.basis.z, anchor_yaw)

	var want_table := false
	if _in_main_scene() and cp.x > TABLE_MIN_X:
		want_table = mode == "table" or mode == "" or cp.distance_to(HOME_POS) < TABLE_ENTER_DIST

	if want_table:
		if mode != "table":
			var came_walking := mode == "follow"
			mode = "table"
			anchor_pos = HOME_POS
			anchor_yaw = HOME_YAW
			walk_off = Vector3.ZERO
			hold_for_dealer = false
			if came_walking and stick_walk and regime_big and xr_cam != null \
					and _dist_to_seat() > DETACH_FAR_M * world_scale:
				# The game is ready for you at the table: do not teleport, let the player walk there.
				walk_to_table = true
				walk_to_table_t = 0.0
				walk_idle_t = 0.0
				print("VRBoot: walk to the dealer - distance to the seat = ", snappedf(_dist_to_seat(), 0.1))
			else:
				walk_to_table = false
				changed = true
	else:
		if mode != "follow" or cut or not glide:
			var hop := mode != "follow" or cut or cp.distance_to(anchor_pos) > FOLLOW_SNAP_DIST \
				or absf(wrapf(cam_yaw - anchor_yaw, -PI, PI)) > FOLLOW_SNAP_ANGLE
			if hop:
				mode = "follow"
				anchor_pos = cp
				anchor_yaw = cam_yaw
				still_t = 0.0
				walk_off = Vector3.ZERO
				hold_for_dealer = false
				changed = true
		else:
			var kxz := 1.0 - exp(-delta / 0.25)
			var ky := 1.0 - exp(-delta / 2.0)
			var np := anchor_pos
			np.x = lerpf(anchor_pos.x, cp.x, kxz)
			np.z = lerpf(anchor_pos.z, cp.z, kxz)
			np.y = lerpf(anchor_pos.y, cp.y, ky)
			var d := np - anchor_pos
			anchor_pos = np
			if delta > 0.0:
				anchor_speed = d.length() / delta
			if not needs_recenter and not hold_for_dealer and not kick_on and not adr_tp_on:
				origin.global_position += d       # carry the rig (and your lean) along
			# after the walk stops, face where the game camera ended up
			if delta > 0.0 and d.length() / delta < 0.4:
				still_t += delta
			else:
				still_t = 0.0
			if still_t > 0.8 and walk_idle_t > 1.5 and not hold_for_dealer and not kick_on \
					and walk_off.length() < 1.0 * world_scale \
					and absf(wrapf(cam_yaw - anchor_yaw, -PI, PI)) > REAIM_ANGLE:
				anchor_yaw = cam_yaw
				still_t = 0.0
				changed = true
	if changed:
		_request_recenter()
		print("VRBoot: seat mode=", mode, " anchor=", anchor_pos, " yaw_deg=", snappedf(rad_to_deg(anchor_yaw), 0.1),
			" scale=", snappedf(world_scale, 0.01), " big=", regime_big)

func _request_recenter() -> void:
	needs_recenter = true
	recenter_at = t_alive + RECENTER_SETTLE

# Two sets of scale + seat: one for the building (big), one for the car intro / menu (small).
func _set_regime(big: bool) -> void:
	if big == regime_big:
		return
	_store_regime()
	regime_big = big
	world_scale = scale_big if big else scale_small
	seat = seat_big if big else seat_small
	walk_off = Vector3.ZERO
	walk_to_table = false
	hold_for_dealer = false
	_apply_scale()
	_request_recenter()

func _store_regime() -> void:
	if regime_big:
		scale_big = world_scale
		seat_big = seat
	else:
		scale_small = world_scale
		seat_small = seat

# Moves the XR origin so that your head ends up exactly at the seat point.
# keep_yaw = true keeps your current facing (used while tuning), false turns you to face forward.
func _place_origin(keep_yaw: bool) -> void:
	var head_local := xr_cam.position
	var yaw: float
	if keep_yaw:
		yaw = origin.rotation.y
	else:
		var head_yaw := _heading_of_vec(-xr_cam.transform.basis.z, 0.0)
		yaw = anchor_yaw - head_yaw
	var b := Basis(Vector3.UP, yaw)
	var target := anchor_pos + walk_off + Basis(Vector3.UP, anchor_yaw) * seat
	origin.transform = Transform3D(b, target - b * head_local)

func _handle_tuning_keys(delta: float) -> void:
	var touched := false
	var k := 1.0 + 1.0 * delta
	if Input.is_key_pressed(KEY_F5):
		world_scale = clampf(world_scale / k, 0.5, 200.0)
		touched = true
	if Input.is_key_pressed(KEY_F6):
		world_scale = clampf(world_scale * k, 0.5, 200.0)
		touched = true
	var speed := 0.4 * world_scale * delta
	if Input.is_key_pressed(KEY_F7):
		seat.z += speed
		touched = true
	if Input.is_key_pressed(KEY_F8):
		seat.z -= speed
		touched = true
	if Input.is_key_pressed(KEY_F9):
		seat.y -= speed
		touched = true
	if Input.is_key_pressed(KEY_F10):
		seat.y += speed
		touched = true
	if touched:
		_apply_scale()
		_place_origin(true)   # keeps your head at the seat point, so scale never lifts you up or down

func _apply_scale() -> void:
	XRServer.world_scale = world_scale
	origin.world_scale = world_scale
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		hh.visual.scale = Vector3.ONE * world_scale
	dot.scale = Vector3.ONE * world_scale
	blackout.scale = Vector3.ONE * world_scale
	vignette.scale = Vector3.ONE * world_scale
	if size_label != null:
		size_label.scale = Vector3.ONE * world_scale
	panel_key = ""


# ------------------------------------------------------------------ hands
