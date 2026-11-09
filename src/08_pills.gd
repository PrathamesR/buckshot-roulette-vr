# Bathroom pill bottle
# (Part of the Buckshot Roulette VR mod. Chain position 08: this file extends 07_game_scene.gd; see src/README.md.)
extends "07_game_scene.gd"

const PILL_GRAB_M := 0.10                          # a hand this close to the bottle can pick it up

const PILL_EAT_M := 0.16                           # the bottle this close to your mouth = swallowed

const PILL_MOUTH := Vector3(0.0, -0.10, -0.06)     # your mouth, in head space (metres)

const PILL_RETURN_S := 0.18                        # seconds the bottle takes to slide back onto the desk

var pill_rest := Transform3D.IDENTITY

var pill_from := Transform3D.IDENTITY

var pill_grab := Transform3D.IDENTITY

var pill_center := Vector3.ZERO

var pill_layers := 1

var pill_ret_t := 0.0

var pill_tick := 0.0

func _pill_available() -> bool:
	if pill_node == null or not is_instance_valid(pill_node) or bath_left or pill_busy:
		return false
	var intro := _intro()
	if intro == null:
		return false
	var br = intro.get("intbranch_pillbottle")
	if not (br is Node) or not _allowed(br):
		return false
	var pp = intro.get("parent_pills")
	return pp is Node3D and (pp as Node3D).visible

func _update_pill(delta: float) -> void:
	if pause_open:
		return
	if pill_state == 0:
		_pill_idle()
	elif pill_state == 1:
		_pill_held()
	elif pill_state == 2:
		_pill_slide(delta)

# On the desk: squeeze grip or trigger with a hand next to it to pick it up.
func _pill_idle() -> void:
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		var sq: bool = hh.grip_sq or hh.trigger_down
		var edge := sq and not hh.pill_down
		hh.pill_down = sq
		if not hh.was_active or size_active or not _pill_available():
			continue
		var ws := world_scale
		var box: AABB = pill_node.global_transform * pill_node.get_aabb()
		var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
		var d := _point_box_dist(reach, box)
		if d <= PILL_GRAB_M * 2.5 * ws:
			_pk_flat(box)                         # frame it so you can see it can be picked up
		if edge and d <= PILL_GRAB_M * ws:
			_pill_pick(hh)
			return

func _pill_pick(hh: Hand) -> void:
	pill_hand = hh
	pill_state = 1
	hh.holding = true
	pill_rest = pill_node.global_transform
	pill_layers = pill_node.layers
	pill_center = pill_node.get_aabb().get_center()
	pill_node.layers = 0                          # the real bottle is hidden while a copy is in your hand
	pill_prop = MeshInstance3D.new()
	pill_prop.name = "VRBootPillBottle"
	pill_prop.mesh = pill_node.mesh
	pill_prop.material_override = pill_node.material_override
	for i in pill_node.mesh.get_surface_count():
		pill_prop.set_surface_override_material(i, pill_node.get_surface_override_material(i))
	pill_prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(pill_prop)
	pill_prop.global_transform = pill_rest
	pill_grab = hh.grip.global_transform.affine_inverse() * pill_rest
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.1, 0.0)
	_pill_prompt(true)
	print("VRBoot: picked up the pill bottle with the ", hh.side, " hand")

func _pill_held() -> void:
	var hh := pill_hand
	if hh == null or not is_instance_valid(pill_prop):
		_pill_reset()
		return
	if not hh.was_active or not (hh.grip_sq or hh.trigger_down):
		_pill_release()
		return
	pill_prop.global_transform = hh.grip.global_transform * pill_grab
	var ws := world_scale
	var mouth := xr_cam.global_transform * (PILL_MOUTH * ws)
	var d := mouth.distance_to(pill_prop.global_transform * pill_center)
	if d < PILL_EAT_M * ws:
		_pill_eat(hh)
	elif d < 0.35 * ws and t_alive - pill_tick > 0.12:
		pill_tick = t_alive
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.15 + 0.35 * (1.0 - d / (0.35 * ws)), 0.03, 0.0)

# Let go anywhere but at your mouth: the bottle goes back on the desk.
func _pill_release() -> void:
	if pill_hand != null:
		pill_hand.holding = false
	pill_state = 2
	pill_ret_t = 0.0
	pill_from = pill_prop.global_transform if is_instance_valid(pill_prop) else pill_rest
	_pill_prompt(false)
	print("VRBoot: pill bottle put back on the desk")

func _pill_slide(delta: float) -> void:
	pill_ret_t += delta
	var k := clampf(pill_ret_t / PILL_RETURN_S, 0.0, 1.0)
	if is_instance_valid(pill_prop):
		pill_prop.global_transform = pill_from.interpolate_with(pill_rest, k * k * (3.0 - 2.0 * k))
	if k >= 1.0:
		_pill_reset()

# The game's pill question ("CONSUME PILLS?" plus its small print) fades in on the 2D layer while the
# bottle is in your hand. The YES / NO words are left out: lifting the bottle to your mouth is the answer.
func _pill_prompt(on: bool) -> void:
	var intro := _intro()
	if intro == null:
		return
	var ap = intro.get("animator_pillchoice")
	if not (ap is AnimationPlayer) or not is_instance_valid(ap):
		return
	var player := ap as AnimationPlayer
	if on:
		var host := player.get_parent()
		if host != null:
			for nm in ["pill choice yes", "pill choice no"]:
				var lab := host.get_node_or_null(nm) as CanvasItem
				if lab != null:
					lab.visible = false
		if player.has_animation("show"):
			player.play("show")
		var sp = intro.get("speaker_pillchoice")
		if sp is Node and is_instance_valid(sp) and sp.has_method("play"):
			sp.call("play")
	else:
		if player.has_animation("hide"):
			player.play("hide")
		var sp2 = intro.get("speaker_pillchoice")
		if sp2 is Node and is_instance_valid(sp2) and sp2.has_method("stop"):
			sp2.call("stop")

# Back to "on the desk": the real bottle shows again, the copy goes.
func _pill_reset() -> void:
	if pill_hand != null:
		pill_hand.holding = false
	pill_hand = null
	if is_instance_valid(pill_prop):
		pill_prop.queue_free()
	pill_prop = null
	if pill_node != null and is_instance_valid(pill_node) and not pill_busy:
		pill_node.layers = pill_layers
	pill_state = 0

# The bottle reached your mouth: the same as answering YES in the game's pill question.
func _pill_eat(hh: Hand) -> void:
	var intro := _intro()
	if intro == null:
		_pill_release()
		return
	print("VRBoot: swallowed the pill")
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.25, 0.0)
	pill_busy = true                              # the real bottle stays hidden from now on
	_pill_reset()
	if tv_state != 0:
		_tv_close(false)
	# what the game does when you decide about the pills: nothing else may be pressed meanwhile
	for nm in ["intbranch_bathroomdoor", "intbranch_pillbottle", "intbranch_crt"]:
		var br = intro.get(nm)
		if br is Node:
			br.set("interactionAllowed", false)
	var scr = intro.get("btn_screen")
	if scr is CanvasItem:
		scr.visible = false
	intro.call("SelectedPill", true)


# ------------------------------------------------------------------ the back-room door
