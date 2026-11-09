# Burner phone item
# (Part of the Buckshot Roulette VR mod. Chain position 24: this file extends 23_magnifier.gd; see src/README.md.)
extends "23_magnifier.gd"

const PHONE_OPEN := 2.5953                         # the game's own "use burner phone" animation: the flip part opens to this (z), after a peak of...

const PHONE_PEAK := 2.9155

const PHONE_EAR_M := 0.13                          # the open phone this close (real metres) to an ear...

const PHONE_EAR_S := 0.4                           # ...for this long: the screen animation starts (iteration 29)

const PHONE_ANIM_A := 1.1                          # the game's screen animation: the cracked screen starts at 1.1 s...

const PHONE_MSG_T := 3.2                           # ...the message comes at 3.2 s...

const PHONE_BOOM_V := 0.9                          # the two halves of the phone fly apart this fast (real m/s)

var phone_pivot: Node3D = null       # the burner phone's flip part

var phone_rest := Vector3.ZERO

var phone_mgr: Node = null

var phone_state := 0                 # 0 shut, 1 open (waiting for the ear), 2 the screen animation, 3 closing

var phone_t := 0.0

var phone_sent := false

var phone_ui: MeshInstance3D = null  # copies of the game's phone screen planes on the held phone (iteration 29)

var phone_ui2: MeshInstance3D = null

var phone_ear_t := 0.0

var phone_ra := 0.0

# ---- the burner phone (iteration 29): flick it open, put it to your ear, the game's own reveal plays on its screen -----------
# 0 shut -> (flick) 1 open, the plain screen shows and a hint says "put it to your ear" -> (ear) 2 the game's screen animation
# plays (the cracked screen zooms) and the game's message comes -> 3 it closes and is used up.
# The screen pictures are copies of the game's own `phone screen_UI` / `phone screen_UI2` planes (the game plays them only in
# its own hand animation), put onto the held phone's screen.
func _phone_ready(par: Node3D) -> bool:
	if phone_pivot != null and is_instance_valid(phone_pivot) and phone_pivot.get_parent() == par:
		return true
	var pv := par.get_node_or_null("burner phone pivot") as Node3D
	var mgr: Node = cur_scene.find_child("burner phone manager", true, false) if cur_scene != null else null
	if pv == null or mgr == null or not mgr.has_method("SendDialogue"):
		return false
	phone_pivot = pv
	phone_rest = pv.rotation
	phone_mgr = mgr
	phone_state = 0
	phone_t = 0.0
	phone_sent = false
	phone_ear_t = 0.0
	phone_ra = 0.0
	return true

func _phone_reset() -> void:
	if phone_pivot != null and is_instance_valid(phone_pivot) and not phone_pivot.is_queued_for_deletion():
		phone_pivot.rotation = phone_rest
	for n in [phone_ui, phone_ui2]:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	phone_ui = null
	phone_ui2 = null
	phone_pivot = null
	phone_mgr = null
	phone_state = 0
	phone_t = 0.0
	phone_sent = false
	phone_ear_t = 0.0
	phone_ra = 0.0

func _phone_angle(t: float) -> float:
	if t < 0.35:
		return PHONE_PEAK * smoothstep(0.0, 1.0, t / 0.35)
	return lerpf(PHONE_PEAK, PHONE_OPEN, clampf((t - 0.35) / 0.15, 0.0, 1.0))

# Copies of the game's two screen planes on the held phone's screen. Returns false when the game's planes cannot be found.
func _phone_ui_make(par: Node3D) -> bool:
	if phone_ui != null and is_instance_valid(phone_ui):
		return true
	var scr := par.find_child("burner phone screen", true, false) as Node3D
	if scr == null or cur_scene == null:
		return false
	var base := cur_scene.get_node_or_null("player item interaction parent/burner phone/burner phone parent/burner phone pivot/burner phone screen_main")
	if base == null:
		base = cur_scene.find_child("burner phone screen_main", true, false)
	if base == null:
		return false
	var made: Array = []
	for nm in ["phone screen_UI", "phone screen_UI2"]:
		var src := base.get_node_or_null(nm) as MeshInstance3D
		if src == null or src.mesh == null:
			return false
		var c := MeshInstance3D.new()
		c.name = "VRBoot" + nm.replace(" ", "_")
		c.mesh = src.mesh
		c.transform = src.transform
		c.layers = src.layers
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if src.material_override != null:
			c.material_override = src.material_override.duplicate()
		made.append(c)
	phone_ui = made[0]
	phone_ui2 = made[1]
	scr.add_child(phone_ui)
	scr.add_child(phone_ui2)
	phone_ui.visible = true
	phone_ui2.visible = false
	return true

# The game's own keys for the cracked screen (animation "player use burner phone", from 1.1 s to 6.1 s).
func _phone_ui2_set(ta: float) -> void:
	if phone_ui2 == null or not is_instance_valid(phone_ui2):
		return
	var m := phone_ui2.material_override as BaseMaterial3D
	if m == null:
		return
	var k := clampf((ta - 1.1) / 5.0, 0.0, 1.0)
	m.uv1_scale = Vector3.ONE * lerpf(0.19, 15.19, k)
	var o0 := Vector3(0.386, 0.321, 0.0)
	var o1 := Vector3(11.465, 11.465, 0.0)
	m.uv1_offset = o0.lerp(o1, clampf((ta - 1.1) / 6.59, 0.0, 1.0))

func _phone_ear_dist(par: Node3D) -> float:
	if xr_cam == null or not is_instance_valid(xr_cam):
		return INF
	var ws := world_scale
	var ref := _item_ref(par)
	var hb := xr_cam.global_transform.basis
	var hp := xr_cam.global_position - hb.y.normalized() * (0.02 * ws)
	var r := hb.x.normalized() * (0.085 * ws)
	return minf(ref.distance_to(hp + r), ref.distance_to(hp - r))

func _phone_snd() -> AudioStream:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	var snd = ii.get("sound_use_burnerphone") if ii != null else null
	return snd if snd is AudioStream else null

func _rit_phone_tick(hh: Hand, par: Node3D, delta: float) -> int:
	if not _phone_ready(par):
		return 2
	var ws := world_scale
	if phone_state == 0:
		if item_t >= FLICK_HOLD_S and _flicked(hh):
			phone_state = 1
			phone_t = 0.0
			phone_ear_t = 0.0
			phone_sent = false
			_phone_ui_make(par)
			_fx_play_seg(_phone_snd(), 0.55, 0.55)             # (iteration 34) only the click of the flip lid; the rest comes with the screen
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.1, 0.0)
			print("VRBoot: burner phone flicked open - waiting for it to be put to the ear")
		return 0
	phone_t += delta
	if phone_state == 1:
		phone_pivot.rotation = Vector3(phone_rest.x, phone_rest.y, phone_rest.z + _phone_angle(phone_t))
		_hint_tut("phone_ear", "PUT IT TO YOUR EAR", _item_ref(par) + Vector3.UP * (0.13 * ws))
		if _phone_ear_dist(par) <= PHONE_EAR_M * ws:
			phone_ear_t += delta
		else:
			phone_ear_t = maxf(phone_ear_t - delta * 2.0, 0.0)
		if phone_ear_t >= PHONE_EAR_S:
			phone_state = 2
			phone_ra = 0.0
			_tut_done("phone_ear")
			if phone_ui != null and is_instance_valid(phone_ui):
				phone_ui.visible = false
			if phone_ui2 != null and is_instance_valid(phone_ui2):
				phone_ui2.visible = true
			_phone_ui2_set(PHONE_ANIM_A)
			_fx_play_seg(_phone_snd(), PHONE_ANIM_A - 0.1, PHONE_MSG_T - PHONE_ANIM_A + 0.1)   # the game's sound from the cracked screen to the message
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.4, 0.15, 0.0)
			print("VRBoot: burner phone at the ear - the screen animation starts")
		return 0
	if not hh.grip_sq and item_t >= TITEM_MIN_S:
		return _phone_finish(hh, par)               # (let go while it plays: it is read at once)
	if phone_state == 2:
		phone_ra += delta
		_phone_ui2_set(PHONE_ANIM_A + phone_ra)
		if not phone_sent and phone_ra >= PHONE_MSG_T - PHONE_ANIM_A:
			return _phone_finish(hh, par)             # the message comes: the phone blows apart
	return 0

# (iteration 34) The message is out: instead of the game's closing and breaking in two, the phone goes off by itself - two halves
# (the lid with the cracked screen, the body) fly apart, the game's own breaking sound goes with it.
func _phone_finish(hh: Hand, par: Node3D) -> int:
	if not phone_sent:
		phone_sent = true
		phone_mgr.call("SendDialogue")
	var ws := world_scale
	var lid: Node3D = null
	if phone_pivot != null and is_instance_valid(phone_pivot):
		lid = _fx_clone_visual(phone_pivot)
	var body: Node3D = _fx_clone_solo(par as MeshInstance3D) if par is MeshInstance3D else _fx_clone_visual(par)
	if not _titem_consume(par, "burner phone", false):
		if lid != null:
			lid.queue_free()
		if body != null:
			body.queue_free()
		return 2
	var axis := (par.global_transform.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	var mid := _item_ref(par)
	var floor_y := _item_table_y()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if lid != null:
		_fx_fall(lid, -axis * PHONE_BOOM_V * ws + Vector3(rng.randf_range(-0.2, 0.2), 1.1, rng.randf_range(-0.2, 0.2)) * ws,
			Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)), floor_y, 1.6, true)
	if body != null:
		_fx_fall(body, axis * PHONE_BOOM_V * ws + Vector3(rng.randf_range(-0.2, 0.2), 1.3, rng.randf_range(-0.2, 0.2)) * ws,
			Vector3(rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0), rng.randf_range(-9.0, 9.0)), floor_y, 1.6, true)
	_fx_shards(mid)
	_fx_play_seg(_phone_snd(), 6.7, 0.75, 0.0)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.18, 0.0)
	_titem_end(false, "phone blew apart")
	get_tree().create_timer(0.6).timeout.connect(_perm_back)
	print("VRBoot: burner phone showed its message and blew apart")
	return 1
