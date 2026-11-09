# Gun: take, release, put down, clone, make, free-hand updates
# (Part of the Buckshot Roulette VR mod. Chain position 19: this file extends 18_inverter.gd; see src/README.md.)
extends "18_inverter.gd"

const GUN_GRAB_M := 0.085                          # a hand this close (real metres) to the shotgun's axis (grip squeeze) takes it - and only if no item is nearer

const GUN_HOLD_MAX_S := 60.0                       # the game never gave the shotgun back for this long: let go of it

const GUN_BOX_M := 0.02                            # a hand this close (real metres) to the frame shown on the shotgun takes it (iteration 29)

const GUN_WARM_AFTER_S := 2.0                      # the shotgun's look is prepared this long after the table is ready

const GUN_LIT_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_tex = 0.0;
uniform float rough = 0.7;
uniform float metal = 0.0;
uniform float floor_k = 0.10;
void fragment() {
	vec3 a = albedo.rgb;
	if (use_tex > 0.5) {
		a *= texture(tex, UV).rgb;
	}
	ALBEDO = a;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
	// the game's lights hardly reach a gun held in front of your face: a little self-light of its OWN colour keeps it from going
	// black (no grey haze and no rim any more: that made it look pale and "highlighted")
	EMISSION = a * floor_k;
}
"""

const GUN_PUT_NEAR_M := 0.30                       # a hand this close (real metres) to where the shotgun lies, with the grip let go, puts it down

const GUN_PUT_MAX_S := 20.0                        # real seconds after which the game puts it down for you

const GUN_PUT_SNAP_S := 0.3                        # the gun settles onto the table this fast

const GUN_AFTER_MAX_S := 7.0                       # no put-down request from the game this long after the bang: the gun hands itself back

const GUN_PLACE_ANIM := "player place on table after eject"   # the game's own animation that puts the shotgun down

var gun_lit_shader: Shader = null

var gun_warm_t := 0.0

var gun_warm_done := false

var gun_warm_n := 0

var gun_warm_node: Node3D = null

var gun_ign_ms := -1000

var gun_keep := false               # (iteration 33) the turn goes on after this shot: the gun stays in your hand

var gun_flash: MeshInstance3D = null

var gun_col: StaticBody3D = null    # its collider: layer 0 while the gun is held / being shot

var gun_vis_before := true

var gun_col_seen := false           # the collider was seen switched on (so "off" really means the game took the gun)

var gun_down := {}                  # hand side -> grip squeezed last frame

var gun_flash_t := 0.0

var gun_banged := false             # the shot went off (state 2)

var gun_after := 0.0                # seconds since the bang

var gun_rest_xf := Transform3D.IDENTITY   # the game's shotgun as it lies on the table

var gun_hold_on := false           # Engine.time_scale is held low until you put the shotgun down

var gun_hold_ms := 0

var gun_snap_t := 0.0

var gun_snap_from := Transform3D.IDENTITY

var gun_near_prev := false

func _gun_nodes() -> bool:
	if gun_ctl != null and is_instance_valid(gun_ctl) and gun_main != null and is_instance_valid(gun_main) \
			and gun_col != null and is_instance_valid(gun_col) and gun_branch != null and is_instance_valid(gun_branch):
		return true
	gun_ctl = null
	gun_main = null
	gun_col = null
	gun_branch = null
	if interaction == null or not is_instance_valid(interaction) or not _in_main_scene():
		return false
	var sg = interaction.get("shotgun")
	if not (sg is Node) or not is_instance_valid(sg):
		return false
	var col = sg.get("collider_shotgun")
	if not (col is StaticBody3D) or not is_instance_valid(col):
		return false
	var mesh: Node = (col as Node).get_parent()
	var mainp: Node = mesh.get_parent() if mesh != null else null
	if not (mainp is Node3D) or mesh == null:
		return false
	var br: Node = null
	for c in mesh.get_children():
		if _alias_of(c) == "shotgun":
			br = c
			break
	if br == null:
		return false
	gun_ctl = sg
	gun_col_seen = false
	gun_col = col
	gun_main = mainp
	gun_branch = br
	return true

func _update_gun(delta: float) -> void:
	_gun_boost_watch()
	_gun_hold_watch()
	if (gun_sup_hand != null or gun_pump_hand != null) and ((gun_state != 1 and gun_state != 2) or gun_prop == null or not is_instance_valid(gun_prop)):
		_gun_sup_drop()
	if pause_open:
		return
	if not _in_main_scene() or interaction == null or not is_instance_valid(interaction) or not _gun_nodes():
		if gun_state != 0:
			_gun_release("left the game")
		return
	if gun_state == 3:
		# shot done, the game's own gun is back in charge: wait until it has put itself on the table (its collider is back)
		gun_t += delta
		if gun_col.collision_layer != 0 and gun_t > 0.3:
			_gun_sync_grips()
			gun_state = 0
			gun_col_seen = true
			print("VRBoot: shotgun is back on the table")
		elif gun_t > GUN_HOLD_MAX_S:
			_gun_sync_grips()
			gun_state = 0
			gun_col_seen = false
		return
	if gun_state == 0:
		gun_flash_t = 0.0
		_gun_warm_tick(delta)
		if gun_col.collision_layer != 0:
			gun_col_seen = true
			var rb := _branch_world_box(gun_branch, false)
			if rb.size.x >= 0.0:
				gun_rest_box = rb
				gun_rest_xf = gun_main.global_transform
				gun_rest_ok = true
		elif gun_col_seen and mode == "table":
			# the game has taken the shotgun (laser click): it comes into the hand as well
			var hh0: Hand = active_hand if (active_hand != null and active_hand.was_active) else right_hand
			_gun_take(hh0, false)
			return
		var ws := world_scale
		# (a hand that holds an item - the glass, the beer - does not stop the OTHER hand from taking the shotgun)
		var avail := mode == "table" and not walk_to_table and not size_active and pill_state == 0 and not item_handoff \
			and (rit == "" or (rit == "beer_rack" and rit_hand == null)) and not cuffed and _gun_perm_ok() and not _alias_locked("shotgun")
		grab_gun_ok = avail
		var gbox := _node_world_aabb(gun_main, true) if avail else AABB()
		for h in [left_hand, right_hand]:
			var hh: Hand = h
			var sq: bool = hh.grip_sq
			var edge: bool = sq and not bool(gun_down.get(hh.side, false))
			gun_down[hh.side] = sq
			if edge and hh.was_active and (not avail or hh.holding):
				_gun_ignored(hh, hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws))
			if not avail or not hh.was_active or hh.holding:
				continue
			var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
			var d := _gun_eff_dist(reach)              # 0 inside the frame shown on the gun, else to its axis (its click box is far bigger)
			if d > GUN_GRAB_M * 2.0 * ws:
				continue
			if rit == "beer_rack":
				var pbx := AABB()
				pbx.size = Vector3(-1.0, -1.0, -1.0)
				for pn in _pump_nodes():
					var pb2 := _node_world_aabb(pn, true)
					if pb2.size.x >= 0.0:
						pbx = pb2 if pbx.size.x < 0.0 else pbx.merge(pb2)
				if pbx.size.x >= 0.0 and _point_box_dist(reach, pbx) <= PUMP_GRAB_M * 2.0 * ws:
					continue                           # (iteration 32) right at the pump: that squeeze racks it on the table
			if grab_items_ok and item_im != null and is_instance_valid(item_im):
				var pk := _titem_pick(item_im, reach)
				if float(pk[1]) <= d:
					continue                           # an item is nearer: it gets this squeeze (see _titem_try_take)
			if gun_rest_ok and gun_rest_box.size.x >= 0.0:
				_pk_flat(gun_rest_box)                 # frame it: it can be taken (the same frame as where it goes, iteration 28)
			elif gbox.size.x >= 0.0:
				_pk_flat(gbox)
			if d <= GUN_GRAB_M * ws:
				if edge:
					_gun_take(hh, false, true)
					return
		return
	if gun_state == 5:
		_gun_settle(delta)
		return
	# in the hand (1), being shot (2) or waiting to be put down (4)
	var hand := gun_hand
	if hand == null or gun_prop == null or not is_instance_valid(gun_prop):
		_gun_release("lost the hand")
		return
	var rdt := delta / maxf(Engine.time_scale, 0.001) if gun_hold_on else delta     # real seconds while the game is held
	gun_t += rdt
	_gun_pose(hand, rdt)
	if gun_state == 4:
		_gun_put_update(hand)
		return
	if gun_state == 1:
		if not gun_game and gun_col.collision_layer == 0:
			gun_game = true                     # the game took the shotgun meanwhile (laser click)
		if gun_game and bool(interaction.get("fs_dec")):
			gun_state = 2                       # chosen with the laser on the 3D words
			gun_t = 0.0
			print("VRBoot: shotgun - the game has the choice")
			_gun_boost_start()
		elif gun_cal_on:
			_gun_cal_tick(hand, rdt)
		else:
			if not gun_game:
				_gun_free_update(hand, rdt)
				if gun_state != 1:
					return
			_gun_aim_update(hand, delta)
	if gun_cal_on and gun_state != 1:
		_gun_cal_end()
	if gun_state == 1 or gun_state == 2:
		_gun_sup_update(hand, gun_state == 1 and not gun_cal_on)
	if gun_state == 2:
		if gun_fire_t > 0.0:
			gun_fire_t -= rdt
			if gun_fire_t <= 0.0:
				interaction.call("InteractWith", gun_fire_alias)
				_gun_boost_start()
		var bang := false
		var live := false
		for k in ["speaker_live", "speaker_blank"]:
			var sp = gun_ctl.get(k)
			if sp is Node and bool(sp.get("playing")):
				bang = true
				if k == "speaker_live":
					live = true
		if bang and not gun_bang_prev:
			_gun_boost_end("bang")
			gun_banged = true
			gun_after = 0.0
			gun_keep = _gun_keep_ok(live)
			if gun_keep and not _gun_eject_hold(true):      # (iteration 34) the game's own eject (shell, rack sounds) stays away: you rack it
				gun_keep = false                            # (iteration 36) ...which cannot be done for this animation: the gun goes down
			gun_recoil = 1.0
			hand.grip.trigger_haptic_pulse("haptic", 0.0, 1.0, 0.2, 0.0)
			if live and gun_flash != null:
				gun_flash_t = 0.09
			print("VRBoot: shotgun fired (", "live" if live else "blank", ")")
		gun_bang_prev = bang
		if gun_flash != null and is_instance_valid(gun_flash):
			gun_flash_t = maxf(gun_flash_t - delta, 0.0)
			gun_flash.visible = gun_flash_t > 0.0
		if gun_banged:
			gun_after += delta
			if gun_put_t < 0.0 and not (gun_keep and gun_after <= GUN_AFTER_MAX_S):
				if _gun_place_anim():
					_gun_put_start()
					return
				if gun_after > GUN_AFTER_MAX_S and gun_col.collision_layer == 0:
					gun_put_t = GUN_PUT_DELAY_S      # the game never asked: the gun hands itself back as before
					print("VRBoot: shotgun - the game did not ask for it to be put down; handing it back")
		if gun_keep and not gun_eject_done:
			_gun_eject_watch()
		if gun_put_t >= 0.0:
			gun_put_t += delta
			if gun_put_t >= GUN_PUT_DELAY_S + GUN_PUT_S:
				_gun_handback()
				return
		if gun_keep and gun_banged and gun_put_t < 0.0 and gun_col.collision_layer != 0 and gun_after > 1.5:
			_gun_rehold()
			return
		if gun_col.collision_layer != 0 and gun_t > 1.0:
			_gun_release("the game gave it back")
		elif gun_t > GUN_HOLD_MAX_S:
			_gun_release("timeout")

func _gun_take(hh: Hand, call_game: bool, defer: bool = false) -> void:
	gun_hand = hh
	gun_state = 1
	gun_game = call_game or not defer             # a hand pick-up is only visual until the trigger: the game's own pick-up (items off) comes then
	gun_fire_t = 0.0
	gun_sup_w = 0.0
	gun_sup_ok = false
	_gun_sup_drop()
	gun_sup_down[("left" if hh == right_hand else "right")] = true      # a squeeze that is already on is not a new grab
	gun_t = 0.0
	gun_aim = ""
	gun_aim_t = 0.0
	gun_locked = false
	gun_recoil = 0.0
	gun_bang_prev = false
	hh.holding = true
	gun_vis_before = gun_main.visible
	if call_game:
		interaction.set("activeInteractionBranch", gun_branch)
		interaction.call("MainInteractionEvent")
	gun_gy = GUN_MODEL_GRIP.y
	gun_put_t = -1.0
	gun_banged = false
	gun_keep = false
	gun_need_rack = false
	gun_after = 0.0
	gun_prop = _gun_clone()
	if gun_prop == null:
		gun_pairs.clear()
		gun_prop = _gun_make()
	gun_main.visible = false
	fx_root.add_child(gun_prop)
	_gun_pose(hh, 0.0)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.12, 0.0)
	print("VRBoot: took the shotgun with the ", hh.side, " hand", "" if (call_game or defer) else " (the game grabbed it)")

# (iteration 33) A blank at yourself with shells left and the barrel whole: the turn goes on, so the gun does not have to go
# down on the table (the game puts its own copy down meanwhile; this one stays in your hand).
# (iteration 37) While you hold one of the dealer's items (or have just drunk a stolen beer) the game keeps the shotgun switched off,
# but the saw, the beer's rack and the rest need it: it can be taken by hand all the same.
func _gun_perm_ok() -> bool:
	return _allowed(gun_branch) or steal_held or rit == "beer_rack"

# The game has put its gun back on the table and the turn goes on: the hand's gun becomes a fresh pick-up (as at the start of a turn).
func _gun_rehold() -> void:
	if not gun_eject_done:
		_gun_eject_book()
	_gun_eject_hold(false)
	var hh := gun_hand
	_pump_reset()
	gun_sup_w = 0.0
	_gun_boost_end("held again")
	_gun_hold_end("held again")
	gun_banged = false
	gun_keep = false
	gun_pairs.clear()
	if gun_main != null and is_instance_valid(gun_main):
		gun_main.visible = true
	if gun_prop != null and is_instance_valid(gun_prop):
		gun_prop.queue_free()
	gun_prop = null
	gun_flash = null
	gun_put_t = -1.0
	_gun_sync_grips()
	if hh == null or not hh.was_active:
		gun_hand = null
		if hh != null:
			hh.holding = false
		gun_state = 0
		print("VRBoot: shotgun back on the table (the hand was lost)")
		return
	print("VRBoot: shotgun - the turn goes on, the gun stays in your hand")
	_gun_take(hh, false, true)
	gun_need_rack = true                      # the next shell has to be put in the chamber: rack the pump with the other hand

func _gun_release(why: String) -> void:
	_gun_eject_hold(false)
	gun_shell_pending = false
	gun_keep = false
	gun_need_rack = false
	_gun_cal_end()
	_pump_reset()
	_gun_sup_drop()
	gun_sup_w = 0.0
	_gun_boost_end("released")
	_gun_hold_end("released")
	gun_banged = false
	gun_pairs.clear()
	if gun_main != null and is_instance_valid(gun_main):
		gun_main.visible = gun_vis_before
	if gun_prop != null and is_instance_valid(gun_prop):
		gun_prop.queue_free()
	gun_prop = null
	gun_flash = null
	if gun_hand != null:
		gun_hand.holding = false
	gun_hand = null
	gun_state = 0
	gun_put_t = -1.0
	gun_aim = ""
	gun_locked = false
	gun_recoil = 0.0
	if gun_put_label != null:
		gun_put_label.visible = false
	print("VRBoot: shotgun back on the table (", why, ")")

# The shot is done: our copy hands over to the game's own gun (already in the same pose), which ejects the shell and
# puts itself on the table with its own animations. We only wait until it has (state 3), without grabbing it again.
func _gun_handback() -> void:
	_gun_eject_hold(false)
	gun_shell_pending = false
	gun_keep = false
	gun_need_rack = false
	_pump_reset()
	gun_sup_w = 0.0
	_gun_boost_end("handed back")
	_gun_hold_end("handed back")
	gun_banged = false
	gun_pairs.clear()
	if gun_main != null and is_instance_valid(gun_main):
		gun_main.visible = gun_vis_before
	if gun_prop != null and is_instance_valid(gun_prop):
		gun_prop.queue_free()
	gun_prop = null
	gun_flash = null
	if gun_hand != null:
		gun_hand.holding = false
	gun_hand = null
	_gun_sync_grips()
	gun_state = 3
	gun_t = 0.0
	gun_put_t = -1.0
	gun_aim = ""
	gun_locked = false
	gun_recoil = 0.0
	print("VRBoot: shotgun - after the shot the game's own gun takes over and puts itself on the table")

# The game is about to put the shotgun on the table itself (its own animation). Instead it waits for you: the game is
# held almost still, a frame and a sign show where the gun goes, and the turn goes on once you have put it down.
func _gun_place_anim() -> bool:
	if gun_ctl == null or not is_instance_valid(gun_ctl):
		return false
	var an = gun_ctl.get("animator_shotgun")
	if not (an is AnimationPlayer) or not is_instance_valid(an):
		return false
	return (an as AnimationPlayer).is_playing() and (an as AnimationPlayer).current_animation == GUN_PLACE_ANIM

func _gun_put_start() -> void:
	if not gun_rest_ok or not is_equal_approx(Engine.time_scale, 1.0) or gun_hand == null:
		gun_put_t = GUN_PUT_DELAY_S
		print("VRBoot: shotgun - cannot ask you to put it down here; handing it back")
		return
	gun_state = 4
	gun_t = 0.0
	gun_near_prev = false
	gun_hold_ms = Time.get_ticks_msec()
	gun_hold_on = true
	_game_ts_stop()
	Engine.time_scale = GUN_HOLD_TS
	gun_hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.1, 0.0)
	print("VRBoot: shotgun - the game waits until you put the shotgun down on the table")

# The game's own slow-motion helper keeps writing its end value into Engine.time_scale every frame once it has been
# used (it never switches itself off): stop it, or it would undo our speed changes.
func _game_ts_stop() -> void:
	if gun_ctl == null or not is_instance_valid(gun_ctl):
		return
	var t = gun_ctl.get("timescale")
	if t is Node and is_instance_valid(t):
		t.set("moving", false)

func _gun_hold_end(why: String) -> void:
	if not gun_hold_on:
		return
	gun_hold_on = false
	if is_equal_approx(Engine.time_scale, GUN_HOLD_TS):
		Engine.time_scale = 1.0
	print("VRBoot: shotgun - normal game speed again (", why, ", ", Time.get_ticks_msec() - gun_hold_ms, " ms real)")

func _gun_hold_watch() -> void:
	if not gun_hold_on:
		return
	if gun_state != 4 or not _in_main_scene():
		_gun_hold_end("state changed")
	elif not is_equal_approx(Engine.time_scale, GUN_HOLD_TS):
		gun_hold_on = false             # the game set its own speed meanwhile: leave that alone, and do not keep you waiting
		print("VRBoot: shotgun - the game changed its own speed; the gun goes down by itself")
		_gun_put_down("game speed changed")

func _gun_put_update(hand: Hand) -> void:
	var ws := world_scale
	var spot: Vector3 = gun_rest_xf * GUN_MODEL_GRIP        # where the stock lies when the gun is on the table
	var near := hand.grip.global_position.distance_to(spot) <= GUN_PUT_NEAR_M * ws
	_pk_flat(gun_rest_box)                                  # the frame
	if near != gun_near_prev:
		gun_near_prev = near
		if near:
			hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.3, 0.05, 0.0)
	_ring_show(gun_rest_box.get_center() + Vector3.UP * (0.12 * ws), -1.0, near, 0.07)
	var waited := float(Time.get_ticks_msec() - gun_hold_ms) / 1000.0
	if near and not hand.grip_sq:
		_gun_put_down("put down")
	elif waited > GUN_PUT_MAX_S:
		_gun_put_down("timeout")

func _gun_put_down(how: String) -> void:
	_gun_hold_end(how)
	if gun_put_label != null:
		gun_put_label.visible = false
	if gun_hand != null:
		gun_hand.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
		gun_hand.holding = false
	gun_hand = null
	gun_snap_from = gun_prop.global_transform
	gun_snap_t = 0.0
	gun_state = 5
	print("VRBoot: shotgun put down (", how, ")")

# Our copy settles onto the table while the game's own gun (hidden) finishes its own put-down; then they swap.
func _gun_settle(delta: float) -> void:
	gun_snap_t += delta
	if gun_prop == null or not is_instance_valid(gun_prop):
		_gun_handback()
		return
	var w := clampf(gun_snap_t / GUN_PUT_SNAP_S, 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	gun_prop.global_transform = gun_snap_from.interpolate_with(gun_rest_xf, w)
	var inv := gun_main.global_transform.affine_inverse()
	for e in gun_pairs:
		var o: MeshInstance3D = e[0]
		var c: MeshInstance3D = e[1]
		if is_instance_valid(o) and is_instance_valid(c):
			c.transform = inv * o.global_transform
			c.visible = _gun_part_vis(o)
	if gun_snap_t >= GUN_PUT_SNAP_S and gun_col.collision_layer != 0 and not _gun_place_anim():
		_gun_handback()
	elif gun_snap_t > 3.0:
		_gun_handback()

# so that a grip squeeze that is still on does not count as a new squeeze
func _gun_sync_grips() -> void:
	for h in [left_hand, right_hand]:
		gun_down[(h as Hand).side] = (h as Hand).grip_sq

func _gun_grab_dist(p: Vector3) -> float:
	if gun_main == null or not is_instance_valid(gun_main) or not gun_main.visible:
		return INF
	var a: Vector3 = gun_main.global_transform * Vector3(0.0, -5.6, 0.0)
	var b: Vector3 = gun_main.global_transform * Vector3(0.0, 5.6, 0.0)
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ---- the shotgun: ready for the first grab (iteration 29) --------------------------------------------------------------------
# The first time our copy of the shotgun is drawn the graphics card has to prepare its look (a pause of a moment, right when
# you take the gun). So it is drawn once, tiny, in front of you a couple of seconds after the table is ready.
func _gun_warm_tick(delta: float) -> void:
	if gun_warm_done or xr_cam == null or not is_instance_valid(xr_cam) or fx_root == null:
		return
	if gun_warm_node == null:
		if mode != "table" or gun_main == null or not is_instance_valid(gun_main):
			return
		gun_warm_t += delta
		if gun_warm_t < GUN_WARM_AFTER_S:
			return
		var c := _gun_clone()
		gun_pairs.clear()
		if c == null:
			gun_warm_done = true
			return
		fx_root.add_child(c)
		c.scale = Vector3.ONE * (0.0006 * world_scale)
		gun_warm_node = c
		gun_warm_n = 0
	if not is_instance_valid(gun_warm_node):
		gun_warm_node = null
		gun_warm_done = true
		return
	var hb := xr_cam.global_transform.basis
	gun_warm_node.global_position = xr_cam.global_position - hb.z.normalized() * world_scale - hb.y.normalized() * (0.2 * world_scale)
	gun_warm_n += 1
	if gun_warm_n >= 4:
		gun_warm_node.queue_free()
		gun_warm_node = null
		gun_warm_done = true
		print("VRBoot: shotgun look prepared (no pause when you take it)")

# The distance used for "whose squeeze is it": 0 inside the frame that is shown on the gun, otherwise to its axis (while a hand
# holds an item - and the other hand works on it - only the axis counts, as before).
func _gun_eff_dist(p: Vector3) -> float:
	if item_hand == null and rit_hand == null and gun_rest_ok and gun_rest_box.size.x >= 0.0 and gun_main != null and is_instance_valid(gun_main) \
			and gun_main.visible and _point_box_dist(p, gun_rest_box) <= GUN_BOX_M * world_scale:
		return 0.0
	return _gun_grab_dist(p)

# Why a squeeze next to the gun did not take it (for the log; at most once a second).
func _gun_ignored(hh: Hand, reach: Vector3) -> void:
	var now := Time.get_ticks_msec()
	if now - gun_ign_ms < 1000:
		return
	if _gun_eff_dist(reach) > GUN_GRAB_M * 4.0 * world_scale:
		return
	gun_ign_ms = now
	print("VRBoot: squeeze at the shotgun ignored (", hh.side, "): mode=", mode, " walk=", walk_to_table, " size=", size_active, " pill=", pill_state,
		" handoff=", item_handoff, " rit=", rit, " cuffed=", cuffed, " allowed=", _allowed(gun_branch), " locked=", _alias_locked("shotgun"),
		" holding=", hh.holding)

# Is this part of the game's gun shown in the copy? (The muzzle flash cone is left out: it is a flash, not a part of the gun.)
func _gun_part_vis(o: Node) -> bool:
	var p: Node = o.get_parent()
	if p != null and str(p.name).begins_with("muzzle flash"):
		return false
	return _vis_between(o, gun_main)

func _vis_between(n: Node, top: Node) -> bool:
	var x: Node = n
	while x != null and x != top:
		if x is Node3D and not (x as Node3D).visible:
			return false
		x = x.get_parent()
	return true

# A visual copy of every mesh of the game's shotgun (same meshes and materials, so it looks exactly like the game's).
func _gun_clone() -> Node3D:
	if gun_main == null or not is_instance_valid(gun_main):
		return null
	var meshes: Array = []
	_collect_meshes(gun_main, meshes)
	if meshes.is_empty():
		return null
	gun_k = maxf(gun_main.global_transform.basis.x.length(), 0.0001)
	var root := Node3D.new()
	root.name = "VRBootShotgun"
	gun_pairs.clear()
	var lit_cache := {}
	var n_std := 0
	var n_other := 0
	for o in meshes:
		var mi: MeshInstance3D = o
		var c := MeshInstance3D.new()
		c.mesh = mi.mesh
		c.layers = mi.layers
		c.cast_shadow = mi.cast_shadow
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is StandardMaterial3D and (m as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
					and (m as StandardMaterial3D).shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				n_std += 1
				if not lit_cache.has(m):
					lit_cache[m] = _gun_lit_material(m as StandardMaterial3D)
				c.set_surface_override_material(i, lit_cache[m])
			elif m != null:
				n_other += 1
				c.set_surface_override_material(i, m)
		root.add_child(c)
		gun_pairs.append([mi, c])
	print("VRBoot: shotgun copy: ", n_std, " plain surfaces lit by our shader, ", n_other, " other surfaces as in the game")
	return root

# The gun's own look, but with a little light of its own: held in front of your face the game's lights hardly reach it and it
# came out as a black cut-out.
func _gun_lit_material(m: StandardMaterial3D) -> ShaderMaterial:
	if gun_lit_shader == null:
		gun_lit_shader = Shader.new()
		gun_lit_shader.code = GUN_LIT_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = gun_lit_shader
	sm.set_shader_parameter("albedo", m.albedo_color)
	if m.albedo_texture != null:
		sm.set_shader_parameter("tex", m.albedo_texture)
		sm.set_shader_parameter("use_tex", 1.0)
	sm.set_shader_parameter("rough", m.roughness)
	sm.set_shader_parameter("metal", clampf(m.metallic, 0.0, 0.4))
	return sm

# The shotgun is in your hand but the game does not know yet: the other hand can use items, the pump, the saw.
func _gun_held_free() -> bool:
	return gun_state == 1 and not gun_game and gun_prop != null and is_instance_valid(gun_prop) and not gun_pairs.is_empty()

# The gun's frame (model space -> world): the copy in your hand, or the game's gun on the table.
func _gun_xf() -> Transform3D:
	if gun_state == 1 and gun_prop != null and is_instance_valid(gun_prop):
		return gun_prop.global_transform
	return gun_main.global_transform

# What shows the game's part o: its copy while the gun is in your hand, else the part itself.
func _gun_stand_in(o: Node3D) -> Node3D:
	if gun_state == 1 and not gun_pairs.is_empty():
		for e in gun_pairs:
			if e[0] == o and is_instance_valid(e[1]):
				return e[1]
	return o

# The box around the gun in your hand.
func _gun_held_box() -> AABB:
	var out := AABB()
	out.size = Vector3(-1.0, -1.0, -1.0)
	for e in gun_pairs:
		var c = e[1]
		if c is MeshInstance3D and is_instance_valid(c) and (c as MeshInstance3D).visible:
			var b := _node_world_aabb(c, false)
			if b.size.x >= 0.0:
				out = b if out.size.x < 0.0 else out.merge(b)
	return out

# Picked up but not fired: the pump can be worked with the other hand; opening the hand over the gun's place puts it back.
func _gun_free_update(hand: Hand, delta: float) -> void:
	var ws := world_scale
	if rit == "":
		var pr := _pump_step(delta, gun_need_rack)
		if pr == 2 and gun_need_rack:
			gun_need_rack = false
			_tut_done("rack")
			if gun_shell_pending:
				_gun_shell_fly(hand)                  # (iteration 34) the shell leaves the gun now, with the rack
			print("VRBoot: shotgun racked - ready for the next shot")
		if gun_need_rack:
			_hint_tut("rack", "RACK THE PUMP\nWITH YOUR OTHER HAND", hand.grip.global_position + Vector3.UP * (0.2 * ws), TUT_LONG_K)
	if mode != "table" or cuffed:
		_gun_release("the game moved on")
		return
	if rit != "" or item_hand != null or rit_hand != null or hand.grip_sq or not gun_rest_ok:
		return
	var spot: Vector3 = gun_rest_xf * GUN_MODEL_GRIP
	var d := hand.grip.global_position.distance_to(spot)
	if d <= GUN_PUT_NEAR_M * 2.5 * ws:
		_pk_flat(gun_rest_box)
		if d <= GUN_PUT_NEAR_M * ws:
			_gun_release("put back")

# Our own (fallback) shotgun for the hand (metres; scaled by the world size). Muzzle along -Z, the pistol grip at the origin.
func _gun_make() -> Node3D:
	var root := Node3D.new()
	root.name = "VRBootShotgun"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.1, 0.1, 0.11)
	metal.metallic = 0.3
	metal.roughness = 0.55
	metal.emission_enabled = true
	metal.emission = Color(0.05, 0.05, 0.055)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.22, 0.13, 0.07)
	wood.roughness = 0.85
	wood.emission_enabled = true
	wood.emission = Color(0.06, 0.035, 0.02)
	var parts := [
		[Vector3(0.03, 0.03, 0.5), Vector3(0.0, 0.035, -0.31), 0.0, metal],     # barrel
		[Vector3(0.026, 0.026, 0.4), Vector3(0.0, 0.0, -0.27), 0.0, metal],     # magazine tube
		[Vector3(0.052, 0.05, 0.17), Vector3(0.0, -0.002, -0.27), 0.0, wood],   # pump
		[Vector3(0.05, 0.075, 0.22), Vector3(0.0, 0.0, -0.03), 0.0, metal],     # receiver
		[Vector3(0.045, 0.1, 0.27), Vector3(0.0, -0.02, 0.2), -6.0, wood],      # stock
		[Vector3(0.038, 0.11, 0.05), Vector3(0.0, -0.075, 0.04), 14.0, wood],   # pistol grip
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = p[0]
		mi.mesh = bm
		mi.position = p[1]
		mi.rotation.x = deg_to_rad(float(p[2]))
		mi.material_override = p[3]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	# muzzle flash
	gun_flash = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.09
	fm.height = 0.18
	gun_flash.mesh = fm
	gun_flash.position = Vector3(0.0, 0.035, -0.62)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.92, 0.65)
	gun_flash.material_override = fmat
	gun_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gun_flash.visible = false
	root.add_child(gun_flash)
	return root


# ------------------------------------------------------------------ bathroom: TV and pill bottle by hand
