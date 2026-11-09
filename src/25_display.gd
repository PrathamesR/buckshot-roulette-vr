# Retro colours, PC monitor view
# (Part of the Buckshot Roulette VR mod. Chain position 25: this file extends 24_phone.gd; see src/README.md.)
extends "24_phone.gd"

# Retro colours (iteration 14). The game finishes every picture with a screen shader that rounds each colour
# down to 7 levels (floor(c * 7) / 7, on the final picture). A screen shader cannot run in the headset, but the
# engine's own last step can do the same: a one-dimensional colour look-up table, applied after tone-mapping
# and the game's brightness/contrast/saturation. The table below is that staircase.
const RETRO_LUT_W := 1024

# The monitor picture hides the head-locked effect spheres (they are meant for your eyes only).
const LAYER_HEAD_ONLY := 1 << 19

const MONITOR_FOV := 74.0

const MONITOR_NEAR_M := 0.05

const DUMP_WALKMAP := true                         # write a floor plan of the real geometry (walkmap.png) once, for tuning

var spec_vp: SubViewport           # what the PC monitor shows

var spec_cam: Camera3D

var spec_layer: CanvasLayer

var spec_rect: TextureRect

var spec_pos := Vector3.ZERO

var spec_yaw := 0.0

var spec_pitch := 0.0

var spec_has := false

var ui_checked := false

var ui_check_frames := 0

var retro_lut_levels := Vector3.ZERO

var retro_lut: ImageTexture

var retro_env: Environment

var retro_applied := false

var retro_prev_lut: Texture

var retro_prev_enabled := false

# The game paints a posterising shader over its picture in every scene: floor(colour * N) / N per colour, with
# N = 7. Read N from the game's own effect (before it is hidden) so the headset matches the monitor exactly.
func _read_retro_levels() -> void:
	for n in postfx_nodes:
		if not is_instance_valid(n):
			continue
		for ch in n.get_children():
			var ci := ch as CanvasItem
			if ci == null or not ci.is_visible_in_tree():
				continue
			var sm := ci.material as ShaderMaterial
			if sm == null or sm.shader == null:
				continue
			var r = sm.get_shader_parameter("RED_COMPONENT")
			var g = sm.get_shader_parameter("GREEN_COMPONENT")
			var b = sm.get_shader_parameter("BLUE_COMPONENT")
			if r == null or g == null or b == null:
				continue
			retro_levels = Vector3(maxf(float(r), 1.0), maxf(float(g), 1.0), maxf(float(b), 1.0))
			print("VRBoot: retro colours: the game rounds to ", retro_levels, " levels in this scene")
			return

# A 1-D look-up table: texel i answers for the colour (i + 0.5) / W. A pure white stays pure white, as in the game.
func _build_retro_lut(levels: Vector3) -> ImageTexture:
	var w := RETRO_LUT_W
	var img := Image.create(w, 1, false, Image.FORMAT_RGBA8)
	for i in w:
		var x := (float(i) + 0.5) / float(w)
		var c := Color(_quant(x, levels.x), _quant(x, levels.y), _quant(x, levels.z), 1.0)
		if i == w - 1:
			c = Color(1.0, 1.0, 1.0, 1.0)
		img.set_pixel(i, 0, c)
	return ImageTexture.create_from_image(img)

func _retro_restore() -> void:
	if retro_applied and retro_env != null:
		retro_env.adjustment_color_correction = retro_prev_lut
		retro_env.adjustment_enabled = retro_prev_enabled
	retro_applied = false

# Keeps the table on the current scene's environment (each scene has its own), and takes it off again when
# the setting is switched off or the scene has no such effect.
func _update_retro(delta: float) -> void:
	retro_t -= delta
	if retro_t > 0.0:
		return
	retro_t = 0.25
	var world := get_tree().root.world_3d
	var env: Environment = world.environment if world != null else null
	if env != retro_env:
		_retro_restore()
		retro_env = env
	if env == null:
		return
	var want := retro_look and retro_levels != Vector3.ZERO
	if want:
		if retro_lut == null or retro_lut_levels != retro_levels:
			retro_lut = _build_retro_lut(retro_levels)
			retro_lut_levels = retro_levels
			if retro_applied:
				env.adjustment_color_correction = retro_lut
		if not retro_applied:
			retro_prev_lut = env.adjustment_color_correction
			retro_prev_enabled = env.adjustment_enabled
			env.adjustment_enabled = true
			env.adjustment_color_correction = retro_lut
			retro_applied = true
			print("VRBoot: retro colours on (", retro_levels, " levels, colour table in the environment)")
	elif retro_applied:
		_retro_restore()
		print("VRBoot: retro colours off")


# ------------------------------------------------------------------ PC monitor

# The window itself only draws the game's 2D (the 3D inside it is switched off for speed). To give the monitor a
# picture without letting it leak into the floating panel (which reads the window), the 2D is drawn a second time
# into a copy that has no picture in it (same canvas, shared with the window), and the monitor picture is put
# under the window's 2D in its own layer. The picture is a second camera in a viewport of its own, at the size
# of the window, level and smoothed so it is calm to watch.
func _make_monitor() -> void:
	var vr := get_tree().root.get_visible_rect().size
	if vr.x < 16.0 or vr.y < 16.0:
		vr = ui_size
	ui_vp = SubViewport.new()
	ui_vp.name = "VRBootUiCopy"
	ui_vp.size = Vector2i(int(vr.x), int(vr.y))
	ui_vp.disable_3d = true
	ui_vp.transparent_bg = true
	ui_vp.gui_disable_input = true
	ui_vp.world_2d = get_tree().root.world_2d
	ui_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(ui_vp)

	spec_vp = SubViewport.new()
	spec_vp.name = "VRBootMonitorView"
	spec_vp.size = Vector2i(int(vr.x), int(vr.y))
	spec_vp.transparent_bg = false
	spec_vp.gui_disable_input = true
	spec_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(spec_vp)
	spec_cam = Camera3D.new()
	spec_cam.name = "VRBootMonitorCamera"
	spec_cam.fov = MONITOR_FOV
	spec_cam.near = MONITOR_NEAR_M
	spec_cam.far = 4000.0
	spec_cam.cull_mask = 1048575 & ~LAYER_HEAD_ONLY
	spec_vp.add_child(spec_cam)
	spec_cam.current = true
	# the comfort vignette and the fade ball are for your eyes only (the window already draws the game's own fades)
	if vignette != null:
		vignette.layers = LAYER_HEAD_ONLY
	if blackout != null:
		blackout.layers = LAYER_HEAD_ONLY

	spec_layer = CanvasLayer.new()
	spec_layer.name = "VRBootMonitorLayer"
	spec_layer.layer = -100
	add_child(spec_layer)
	spec_rect = TextureRect.new()
	spec_rect.name = "VRBootMonitorPicture"
	spec_rect.texture = spec_vp.get_texture()
	spec_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spec_rect.stretch_mode = TextureRect.STRETCH_SCALE
	spec_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spec_rect.position = Vector2.ZERO
	spec_rect.size = vr
	spec_layer.add_child(spec_rect)
	_monitor_apply()

func _monitor_apply() -> void:
	if ui_vp == null or spec_vp == null:
		return
	var mode := SubViewport.UPDATE_ALWAYS if monitor_view else SubViewport.UPDATE_DISABLED
	ui_vp.render_target_update_mode = mode
	spec_vp.render_target_update_mode = mode
	spec_layer.visible = monitor_view
	if panel_mat != null:
		panel_mat.set_shader_parameter("tex", _ui_tex())
	if not monitor_view:
		spec_has = false

func _update_monitor(delta: float) -> void:
	if spec_cam == null or not monitor_view or xr_cam == null or not is_instance_valid(xr_cam):
		return
	_monitor_selfcheck()
	var gt := xr_cam.global_transform
	var f := -gt.basis.z
	var yaw := atan2(-f.x, -f.z)
	var pitch := asin(clampf(f.y, -1.0, 1.0))
	if not spec_has or spec_pos.distance_to(gt.origin) > 3.0 * maxf(world_scale, 1.0):
		spec_pos = gt.origin
		spec_yaw = yaw
		spec_pitch = pitch
		spec_has = true
	else:
		var ap := 1.0 - exp(-delta * 18.0)
		var ar := 1.0 - exp(-delta * 8.0)
		spec_pos = spec_pos.lerp(gt.origin, ap)
		spec_yaw = lerp_angle(spec_yaw, yaw, ar)
		spec_pitch = lerpf(spec_pitch, pitch, ar)
	spec_cam.near = MONITOR_NEAR_M * maxf(world_scale, 1.0)
	spec_cam.global_transform = Transform3D(Basis.from_euler(Vector3(spec_pitch, spec_yaw, 0.0)), spec_pos)

# While the game's black fade rectangle covers the whole window, the 2D copy must be black and solid too. If it
# is empty instead, the shared canvas did not work on this machine: fall back to the old way (the panel reads the
# window itself, no picture on the monitor) for this session rather than leave the panel blank.
func _monitor_selfcheck() -> void:
	if ui_checked or ui_vp == null:
		return
	if blocker_alpha_raw < 0.97 or t_alive < 1.0:
		ui_check_frames = 0
		return
	ui_check_frames += 1
	if ui_check_frames < 4:
		return
	ui_checked = true
	var img := ui_vp.get_texture().get_image()
	if img == null or img.is_empty():
		print("VRBoot: monitor self-check: the 2D copy cannot be read")
		return
	var a := img.get_pixel(3, 3).a
	print("VRBoot: monitor self-check: 2D copy corner alpha ", snappedf(a, 0.01), " while the game's fade is ", snappedf(blocker_alpha_raw, 0.01))
	if a < 0.5:
		monitor_view = false
		_monitor_apply()
		print("VRBoot: monitor view switched off for this session (the 2D copy stayed empty); the panel reads the window directly")


# ------------------------------------------------------------------ scene scans and window probe

# Right after a scene loads: find the game's screen-copy post effects (they paint grey/posterised
# over the 2D window we show on the panel, so they are switched off) and every click target.
func _update_scene_scan() -> void:
	if cur_scene == null:
		return
	if not scan_times.is_empty() and t_alive >= float(scan_times[0]):
		scan_times.pop_front()
		postfx_nodes = cur_scene.find_children("*", "BackBufferCopy", true, false)
		_read_retro_levels()
		if _in_main_scene():
			hint_nodes = cur_scene.find_children("interaction branch*", "Node", true, false)
			_index_special_branches()
			_hide_clutter()
			if DUMP_WALKMAP and map_dump_state == 0 and t_alive > 3.0:
				_start_map_dump()
			if not hand_res.has("right_open"):
				_capture_hands_from_scene()
		print("VRBoot: scan: ", postfx_nodes.size(), " screen-copy effects hidden, ", hint_nodes.size(), " click targets")
	for n in postfx_nodes:
		if is_instance_valid(n) and n.visible:
			n.visible = false
	var due := false
	for i in range(probe_times.size() - 1, -1, -1):
		if t_alive >= float(probe_times[i]):
			probe_times.remove_at(i)
			due = true
	if due:
		_probe_root()
