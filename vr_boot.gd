extends "src/36_cuffs.gd"
# Buckshot Roulette VR - the entry point (autoload "VRBoot"; override.cfg points at this file).
# The mod is split into modules in src/ (a chain: each file extends the one before it, see src/README.md); this file holds the
# three engine callbacks that drive everything every frame (_ready, _process, _input). Not part of the original game.
#
# Buckshot Roulette VR - iteration 33 (not part of the original game).
#
# What this does
#   * Renders the game's 3D world to the headset in its own XR viewport.
#   * Seats you at the game's "home" camera spot and ignores the game's camera motion.
#   * Shows both controllers with a laser pointer. The laser replaces the mouse: it feeds the
#     game's own hover/click code, so every rule of the game still applies.
#   * Draws [ ] brackets around whatever you can click (bright = pointed at, dim = available).
#   * Lets you walk with the thumbstick inside the building (lobby, restroom, signing room).
#   * Mirrors the game's 2D interface (menus, text) on a floating panel and lets you click it.
#   * Bathroom by hand: poke the door, the TV and its buttons with your index finger (the TV
#     comes on where it stands, no camera move); pick up the pill bottle and bring it to your
#     mouth to swallow, or let go and it goes back on the desk.
#   * Hands change shape with your fingers: open, pointing, trigger, fist, thumbs up.
#   * A pause menu (left menu button) with recenter, comfort options, main menu and quit.
#   * World size and height: pause menu buttons (iteration 24). The two-hand gesture of iteration 11 (squeeze BOTH grips and
#     hold: hands apart = bigger world, hands down = taller) is still there but off by default, and never starts while a
#     hand holds the shotgun or an item.
#   * A controls sign on the bathroom wall (point + trigger, or touch the button, to take it down).
#   * Both doors (bathroom, back room) are kicked open where you stand; nothing carries you along.
#   * Game items cannot be selected before you have sat down at the table.
#   * The name machine's keys can be pressed with a fingertip (iteration 15: only once the machine has
#     stopped moving and your hand has been clear of the keys; the touch zone is a few millimetres).
#   * Retro colours (iteration 14): the game's 7-levels-per-colour posterising, as on the PC.
#   * The shotgun by hand (iteration 16/17): squeeze the grip next to it, it comes into your hand (the game's own
#     model); point it at the dealer or at yourself, hold steady a moment, pull the trigger. The game does the rest;
#     its slow build-up to the bang is sped up, and aimed at yourself the hand slides toward the pump so the long
#     gun fits in front of your face. After the shot the game waits for you to put the gun down on the table (frame + sign).
#   * No laser at all until you have sat down at the table: the bathroom, the lobby and the doors are all done by hand.
#   * The blood from a shot is a red edge of your view that throbs and ebbs away (iteration 24), your controllers thump.
#   * At the table the laser only shows for the few things that still need it; items, shotgun, handcuffs, the money
#     briefcase (latches and lid, touched with a fingertip) and the cigarette (into your mouth) are all by hand.
#   * Frames around reachable things lie in the object's own plane: on the table for items and the shotgun, on the door or
#     the button face for those.
#   * Doors by fingertip (bathroom, back room); the TV is started with its X button.
#   * The PC monitor shows what you see (a calm, level copy of your view).
#   * Items by hand (iterations 25-27): beer, cigarettes, handsaw, magnifying glass (smash it on the table; what is left of the
#     glass is a window onto the shell), inverter (turn its dial with the other hand), prescription medicine (pull the strip,
#     flick a pill into your hand, eat it).
# Idle unless the game was started with --xr-mode on.
#
# Controls
#   Trigger (either hand)  click (that hand becomes the pointer)
#   Grip (either hand)     grab the pill bottle (bathroom); also makes the hand point
#   A / X                  accept        B / Y   cancel (closes the TV / the pause menu)
#   Left stick             walk (in the building) / menu arrows (everywhere else)
#   Right stick            snap-turn left / right (in the building)
#   Left stick click       recenter (sit comfortably, look at the table, press)
#   Right stick click      show / hide the floating panel
#   Left menu button       pause menu (in the game room and the building)
#   Both grips, held       world size and height (only if "Two-hand size" is switched on in the pause menu)
#
# Tuning keys on the keyboard (hold them down while wearing the headset)
#   F5 / F6    world BIGGER / SMALLER        F7 / F8    seat BACK / FORWARD
#   F9 / F10   seat DOWN / UP                F11        save    F12   reset
#   F4         show / hide panel             F3         show / hide the picture on the PC monitor
#   F2         intro walk: smooth glide <-> hop
#   F1         stick walking on / off

# Comfort vignette: a soft dark ring that closes in on the edges of your view while you walk.
const VIGNETTE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;
uniform float vig = 0.0;
void fragment() {
	vec3 d = normalize(VERTEX);
	float a = acos(clamp(-d.z, -1.0, 1.0));
	float a_in = mix(1.35, 0.62, vig);
	float edge = smoothstep(a_in, a_in + 0.40, a);
	ALBEDO = vec3(0.0);
	ALPHA = edge * clamp(vig * 1.6, 0.0, 1.0);
}
"""

var xr_interface: XRInterface

var xr_vp: SubViewport

var bracket_mat: StandardMaterial3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # the pause menu pauses the game, not us
	process_priority = -10
	xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface == null or not xr_interface.is_initialized():
		print("VRBoot: OpenXR not active (start the game with --xr-mode on). Staying idle.")
		set_process(false)
		set_process_input(false)
		return

	_load_settings()
	world_scale = scale_small
	seat = seat_small
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.set_default_clear_color(Color.BLACK)
	# The window only feeds the floating panel; clear it to "nothing" so no background colour leaks in.
	get_tree().root.transparent_bg = true

	var rt_size := xr_interface.get_render_target_size()
	xr_vp = SubViewport.new()
	xr_vp.name = "VRBootViewport"
	xr_vp.size = Vector2i(int(rt_size.x), int(rt_size.y))
	xr_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(xr_vp)

	origin = XROrigin3D.new()
	origin.name = "VRBootOrigin"
	xr_cam = XRCamera3D.new()
	xr_cam.name = "VRBootCamera"
	xr_cam.near = 0.05
	origin.add_child(xr_cam)
	xr_vp.add_child(origin)

	fx_root = Node3D.new()
	fx_root.name = "VRBootFx"
	xr_vp.add_child(fx_root)

	# Head-locked sphere that stands in for the game's black 2D "viewblocker" fades.
	blackout_mat = StandardMaterial3D.new()
	blackout_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blackout_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blackout_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	blackout_mat.no_depth_test = true
	blackout_mat.render_priority = 100
	blackout_mat.albedo_color = Color(0, 0, 0, 0)
	var bs := SphereMesh.new()
	bs.radius = 0.5
	bs.height = 1.0
	bs.radial_segments = 16
	bs.rings = 8
	blackout = MeshInstance3D.new()
	blackout.mesh = bs
	blackout.material_override = blackout_mat
	blackout.visible = false
	xr_cam.add_child(blackout)

	# Comfort vignette (head-locked, only visible while walking).
	var vshader := Shader.new()
	vshader.code = VIGNETTE_SHADER
	vignette_mat = ShaderMaterial.new()
	vignette_mat.shader = vshader
	vignette_mat.render_priority = 99
	var vs := SphereMesh.new()
	vs.radius = 0.5
	vs.height = 1.0
	vs.radial_segments = 24
	vs.rings = 12
	vignette = MeshInstance3D.new()
	vignette.mesh = vs
	vignette.material_override = vignette_mat
	vignette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vignette.visible = false
	xr_cam.add_child(vignette)

	# [ ] brackets around clickable things. Vertices are written in world space every frame.
	bracket_mat = StandardMaterial3D.new()
	bracket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bracket_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bracket_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bracket_mat.no_depth_test = true
	bracket_mat.vertex_color_use_as_albedo = true
	bracket_mat.render_priority = 80
	bracket_im = ImmediateMesh.new()
	bracket = MeshInstance3D.new()
	bracket.name = "VRBootBrackets"
	bracket.mesh = bracket_im
	bracket.material_override = bracket_mat
	bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bracket.extra_cull_margin = 16384.0
	fx_root.add_child(bracket)

	# A tall soft pillar of light over the dealer's seat while you are walking there.
	beacon_mat = StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beacon_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon_mat.albedo_color = Color(0.35, 1.0, 0.6, 0.14)
	beacon_mat.render_priority = 70
	var bm := CylinderMesh.new()
	bm.top_radius = 1.0
	bm.bottom_radius = 1.0
	bm.height = 1.0
	bm.radial_segments = 24
	bm.rings = 1
	beacon = MeshInstance3D.new()
	beacon.name = "VRBootBeacon"
	beacon.mesh = bm
	beacon.material_override = beacon_mat
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.visible = false
	fx_root.add_child(beacon)

	left_hand = _make_hand("left", Color(0.25, 0.55, 1.0))
	right_hand = _make_hand("right", Color(1.0, 0.55, 0.2))
	active_hand = right_hand
	_make_dot()
	_make_monitor()
	_make_panel()
	_make_pause()
	_make_help()
	_make_size_label()
	_make_gun_label()
	_make_hint_label()
	_make_ring()
	_load_hand_resources()
	_rebuild_hand_visuals()

	XRServer.world_scale = world_scale
	origin.world_scale = world_scale
	xr_vp.use_xr = true
	get_tree().root.disable_3d = true     # the window draws only the game's 2D; the monitor picture has its own viewport
	_apply_scale()

	var vr := get_tree().root.get_visible_rect().size
	if vr.x > 0.0 and vr.y > 0.0:
		ui_size = vr
	print("VRBoot: iteration 19 ready. Render target per eye: ", rt_size, " world_scale=", world_scale,
		" seat=", seat, " ui_size=", ui_size)


# ------------------------------------------------------------------ frame loop

func _process(delta: float) -> void:
	if origin == null:
		return
	t_alive += delta
	var head_start := xr_cam.global_position if xr_cam != null else Vector3.ZERO
	var origin_start := origin.global_transform
	_update_game_refs()
	_suppress_game_highlights()
	_update_door(delta)
	_update_anchor(delta)
	_update_blackout()
	_update_scene_scan()
	_handle_tuning_keys(delta)
	if needs_recenter and t_alive > recenter_at:
		if (kick_on or hold_for_dealer) and not (mode == "table" and not walk_to_table):
			_sync_walk_off()           # you are not where the game camera is: a re-seat must keep you where you stand
			# (but once the game is at the table and you are not walking there, the re-seat MUST seat you: iteration 15
			#  left you in the lobby with walking off - the "stuck" the user saw)
		_place_origin(false)
		needs_recenter = false
	_update_hand_poses()
	_update_hand_grade(delta)
	_update_retro(delta)
	_update_bounds(delta)
	_flick_update(delta)
	_name_machine_guard(delta)
	_update_poke(delta)
	_update_btn_spring(delta)
	_update_tv(delta)
	_update_pill(delta)
	_update_gun(delta)
	_update_items(delta)
	_paper_update(delta)
	_update_cuffs(delta)
	_update_brief(delta)
	_cig_update(delta)
	_hint_finish()
	_ring_finish()
	_update_walk(delta)
	_update_size(delta)
	_update_help(delta)
	_update_pointer()
	_map_dump_step()
	_update_buttons()
	_update_splat()
	_update_brackets()
	_update_panel()
	_update_visuals()
	_update_monitor(delta)
	_diagnostics(delta)
	_rig_guard(head_start, origin_start, delta)

func _input(event: InputEvent) -> void:
	# While the TV is on, "back" (Esc, B) switches it off - the game's own handler would also fade the screen.
	if tv_state != 0 and not pause_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("exit game")):
		get_viewport().set_input_as_handled()
		_tv_close(true)
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_P:
			_pause_toggle()
		KEY_F3:
			monitor_view = not monitor_view
			_monitor_apply()
			print("VRBoot: PC monitor view = ", "on" if monitor_view else "off")
		KEY_F4:
			panel_visible = not panel_visible
		KEY_F1:
			stick_walk = not stick_walk
			print("VRBoot: stick walking = ", "on" if stick_walk else "off")
		KEY_F2:
			glide = not glide
			print("VRBoot: intro walk = ", "glide" if glide else "hop")
		KEY_F11:
			_save_settings()
		KEY_F12:
			world_scale = _def_scale()
			seat = _def_seat()
			_apply_scale()
			_place_origin(true)
			print("VRBoot: reset to defaults")


# ------------------------------------------------------------------ game hookup
