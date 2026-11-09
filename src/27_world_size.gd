# World size and height (gesture, buttons, labels)
# (Part of the Buckshot Roulette VR mod. Chain position 27: this file extends 26_handsaw.gd; see src/README.md.)
extends "26_handsaw.gd"

# World size / height by hand (iteration 11, ranges widened in 13)
const SIZE_MIN := 0.25                             # world size limits in the readout (1.0 = 100 %)

const SIZE_MAX := 2.0

const SIZE_ARM_S := 0.6                            # both grips must be held this long before the gesture starts

const SIZE_REF_M := 0.4                            # moving the hands this much apart / together doubles / halves the size

const SIZE_SMOOTH := 18.0

var size_arm_t := 0.0

var size_p0 := 1.0                 # world size (1.0 = default) when the gesture started

var size_s0 := 1.0                 # world_scale when it started

var size_y0 := 0.0                 # seat height (units) when it started

var size_d0 := 0.4                 # distance between the hands (metres) when it started

var size_hy0 := 0.0                # height of the hands (metres) when it started

var size_s := 1.0                  # smoothed values being applied

var size_y := 0.0

var size_key_a := -999

var size_key_b := -999

var size_snapped := false

var size_label_t := 0.0

var size_block_t := 0.0

var size_block_logged := false

var size_fail_logged := false

# The numbers the gesture is made of, pure maths so it can be tested without a headset:
# hands apart / together -> world size, hands down / up -> seat height. Returns (scale, seat y).
func _size_targets(ref_s: float, ref_y: float, def_s: float, def_y: float, p0: float, y0: float, d0: float, d: float,
		hy0: float, hy: float, cur_s: float) -> Vector2:
	# moving the hands SIZE_REF_M further apart doubles the size, SIZE_REF_M closer halves it - whatever the start distance.
	# p is the readout (1.0 = the reference size); the default sits at p_def (0.5) and is snapped to.
	var p := clampf(p0 * maxf(0.2, 1.0 + (d - d0) / SIZE_REF_M), SIZE_MIN, SIZE_MAX)
	var p_def := ref_s / def_s
	if absf(p - p_def) < 0.06 * p_def:
		p = p_def
	var y := _clamp_seat_y(y0 + (hy0 - hy) * cur_s, ref_y, def_s)
	if absf(y - def_y) < 0.02 * cur_s:
		y = def_y
	return Vector2(ref_s / p, y)

func _update_size(delta: float) -> void:
	if size_label_t > 0.0:
		size_label_t -= delta
		if size_label_t <= 0.0:
			size_label.visible = false
	var l := left_hand
	var r := right_hand
	var both := l.was_active and r.was_active and l.grip_sq and r.grip_sq
	var why := ""
	if not size_gesture:
		why = "switched off in the pause menu"
	elif pause_open:
		why = "paused"
	elif kick_on:
		why = "door kick running"
	elif needs_recenter:
		why = "waiting for a re-seat"
	elif pill_state == 1:
		why = "pill bottle in hand"
	elif _size_busy():
		why = "something is in your hands"
	var allowed := why == ""
	if both and not size_active:
		size_block_t += delta
		if not allowed and size_block_t > 0.5 and not size_block_logged:
			size_block_logged = true
			print("VRBoot: size gesture: both grips held but not started (", why, ")")
	else:
		size_block_t = 0.0
		size_block_logged = false
	if size_active:
		if not both or not allowed:
			_size_end()
		else:
			_size_step(delta)
		return
	if both and allowed:
		size_arm_t += delta
		if size_arm_t >= SIZE_ARM_S:
			size_arm_t = 0.0
			_size_begin()
	else:
		size_arm_t = 0.0

# The gesture must never start while a hand is busy: the shotgun, an item, the pump, the saw, the handcuffs.
func _size_busy() -> bool:
	if gun_state != 0 or item_hand != null or rit != "" or rit_hand != null or rit_hand2 != null or cuffed or mag_seen:
		return true
	if not size_active and (left_hand.holding or right_hand.holding):
		return true
	return false

func _size_begin() -> void:
	var a := _hand_raw(left_hand)
	var b := _hand_raw(right_hand)
	if is_nan(a.x) or is_nan(b.x):
		if not size_fail_logged:
			size_fail_logged = true
			print("VRBoot: size gesture: the controller positions could not be read")
		return
	var d := a.distance_to(b)
	# sanity check of the raw poses against the node positions (the same hands, scaled): if the raw ones look dead, use the nodes
	var dn := left_hand.grip.position.distance_to(right_hand.grip.position) / maxf(world_scale, 0.0001)
	if not size_use_nodes and d < 0.03 and dn > 0.05:
		size_use_nodes = true
		a = _hand_raw(left_hand)
		b = _hand_raw(right_hand)
		d = a.distance_to(b)
		print("VRBoot: size gesture: raw hand poses look unusable (", snappedf(d, 0.001), " m), measuring from the nodes instead")
	size_active = true
	size_s0 = world_scale
	size_p0 = _ref_scale() / world_scale
	size_y0 = seat.y
	size_d0 = d
	size_hy0 = (a.y + b.y) * 0.5
	size_s = world_scale
	size_y = seat.y
	size_key_a = -999
	size_key_b = -999
	size_snapped = false
	_size_hold_here()
	left_hand.holding = true
	right_hand.holding = true
	for h in [left_hand, right_hand]:
		(h as Hand).grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.08, 0.0)
	size_label.visible = true
	size_label_t = 0.0
	print("VRBoot: size gesture started (size ", int(round(size_p0 * 100.0)), "%, hands ", snappedf(d, 0.01),
		" m apart, nodes say ", snappedf(dn, 0.01), " m)")

func _size_step(delta: float) -> void:
	var a := _hand_raw(left_hand)
	var b := _hand_raw(right_hand)
	if is_nan(a.x) or is_nan(b.x):
		_size_end()
		return
	var t := _size_targets(_ref_scale(), _ref_seat_y(), _def_scale(), _def_seat().y, size_p0, size_y0, size_d0,
		a.distance_to(b), size_hy0, (a.y + b.y) * 0.5, size_s)
	var k := 1.0 - exp(-delta * SIZE_SMOOTH)
	size_s = lerpf(size_s, t.x, k)
	size_y = lerpf(size_y, t.y, k)
	_size_apply(size_s, size_y)
	# a little tick every 5 % of size and every 5 cm of height, a firmer one at exactly the default
	var p := _ref_scale() / world_scale
	var hcm := (seat.y - _ref_seat_y()) / world_scale * 100.0
	var ka := int(floor(p * 20.0))
	var kb := int(floor(hcm / 5.0))
	var at_default := absf(p - _ref_scale() / _def_scale()) < 0.001
	var firm := at_default and not size_snapped
	size_snapped = at_default
	if (ka != size_key_a or kb != size_key_b or firm) and size_key_a != -999:
		for h in [left_hand, right_hand]:
			(h as Hand).grip.trigger_haptic_pulse("haptic", 0.0, 0.5 if firm else 0.15, 0.03 if firm else 0.015, 0.0)
	size_key_a = ka
	size_key_b = kb
	size_label.text = "SIZE %d%%\nHEIGHT %+d CM" % [int(round(p * 100.0)), int(round(hcm))]
	size_label.global_position = (left_hand.grip.global_position + right_hand.grip.global_position) * 0.5 \
		+ Vector3.UP * (0.22 * world_scale)

# Moves the world scale and seat height. Your head stays pinned at the spot it had when the gesture started
# (the same way the F5 / F6 tuning keys work), so scaling can never slide you sideways or lift you.
func _size_apply(sc: float, y: float) -> void:
	world_scale = sc
	seat.y = y
	_apply_scale()
	_place_origin(true)

# Makes anchor + walk_off describe the spot you stand on right now (not at the table: there walk_off stays 0).
func _size_hold_here() -> void:
	if mode != "table" and _in_main_scene() and regime_big:
		_sync_walk_off()
		walk_off.y = 0.0

func _size_end() -> void:
	size_active = false
	left_hand.holding = false
	right_hand.holding = false
	size_key_a = -999
	_size_commit(size_s0, size_y0)
	size_label_t = 1.8
	for h in [left_hand, right_hand]:
		(h as Hand).grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.06, 0.0)
	print("VRBoot: size gesture done: world size ", int(round(_ref_scale() / world_scale * 100.0)), "%, height ",
		int(round((seat.y - _ref_seat_y()) / world_scale * 100.0)), " cm")

# The other set of values (car intro / menu <-> building) gets the same change, so you feel the same size everywhere.
func _size_commit(s0: float, y0: float) -> void:
	var ratio := world_scale / s0
	var dym := (seat.y - y0) / world_scale
	if regime_big:
		scale_small = clampf(scale_small * ratio, REF_SCALE_SMALL / SIZE_MAX, REF_SCALE_SMALL / SIZE_MIN)
		seat_small.y = _clamp_seat_y(seat_small.y + dym * scale_small, REF_SEAT_Y_SMALL, DEFAULT_SCALE_SMALL)
	else:
		scale_big = clampf(scale_big * ratio, REF_SCALE_BIG / SIZE_MAX, REF_SCALE_BIG / SIZE_MIN)
		seat_big.y = _clamp_seat_y(seat_big.y + dym * scale_big, REF_SEAT_Y_BIG, DEFAULT_SCALE_BIG)
	_save_settings()

# Pause menu: one step of world size (dp, in readout units: 0.05 = 5 %) and / or seat height (dcm, centimetres).
func _size_nudge(dp: float, dcm: float) -> void:
	var s0 := world_scale
	var y0 := seat.y
	var p0 := _ref_scale() / world_scale
	var p_def := _ref_scale() / _def_scale()
	var p := clampf(p0 + dp, SIZE_MIN, SIZE_MAX)
	if dp != 0.0 and (absf(p - p_def) < 0.5 * SIZE_STEP or (p0 - p_def) * (p - p_def) < 0.0):
		p = p_def                                       # stepping over the default stops on it
	var y := _clamp_seat_y(seat.y + dcm * 0.01 * world_scale, _ref_seat_y(), _def_scale())
	_size_hold_here()
	_size_apply(_ref_scale() / p, y)
	_size_commit(s0, y0)
	print("VRBoot: size ", int(round(p * 100.0)), "%, height ", int(round((seat.y - _ref_seat_y()) / world_scale * 100.0)), " cm (pause menu)")
	if pause_open:
		_pause_close()                  # open it again at the new size so the pointer still lines up
		_pause_open()

# Pause menu: back to the default size and height everywhere.
func _size_reset() -> void:
	scale_big = DEFAULT_SCALE_BIG
	seat_big = DEFAULT_SEAT_BIG
	scale_small = DEFAULT_SCALE_SMALL
	seat_small = DEFAULT_SEAT_SMALL
	world_scale = _def_scale()
	seat = _def_seat()
	_apply_scale()
	_size_hold_here()
	_place_origin(true)
	_save_settings()
	if pause_open:
		_pause_close()                  # open it again at the new size so the pointer still lines up
		_pause_open()
	print("VRBoot: size and height reset to the defaults")

func _make_size_label() -> void:
	size_label = Label3D.new()
	size_label.name = "VRBootSizeLabel"
	size_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	size_label.no_depth_test = true
	size_label.shaded = false
	size_label.font = _game_font()
	size_label.font_size = 56
	size_label.outline_size = 14
	size_label.pixel_size = 0.0006
	size_label.modulate = Color(1, 1, 1)
	size_label.outline_modulate = Color(0, 0, 0)
	size_label.render_priority = 105
	size_label.outline_render_priority = 104
	size_label.visible = false
	fx_root.add_child(size_label)


# ------------------------------------------------------------------ the controls sign on the bathroom wall (iteration 11)
