# Pause menu
# (Part of the Buckshot Roulette VR mod. Chain position 28: this file extends 27_world_size.gd; see src/README.md.)
extends "27_world_size.gd"

const HEIGHT_STEP_CM := 2.0                        # ...and one press of the height buttons moves the seat by this many cm

const PAUSE_HAND_SCALE := 0.5                      # the pause menu held in the left hand is this share of its old size

var pause_hand_pos := Vector3.ZERO

var pause_hand_ok := false

var pause_quad: MeshInstance3D

var pause_btns := {}

var pause_confirm := ""

var pause_px := NO_HIT

var pause_last := NO_HIT

var pause_size := Vector2i(1000, 892)

var pause_world := Vector2(1.1, 0.981)  # metres

# A small 2D menu of our own (the game has none), drawn into its own viewport and shown on a quad.
func _make_pause() -> void:
	pause_vp = SubViewport.new()
	pause_vp.name = "VRBootPauseUI"
	pause_vp.size = pause_size
	pause_vp.disable_3d = true
	pause_vp.transparent_bg = false
	pause_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(pause_vp)

	var th := Theme.new()
	th.default_font = _game_font()
	th.default_font_size = 34
	th.set_stylebox("normal", "Button", _box(UI_BLACK, UI_WHITE, 3))
	th.set_stylebox("hover", "Button", _box(UI_LIME, UI_LIME, 3))
	th.set_stylebox("pressed", "Button", _box(UI_WHITE, UI_WHITE, 3))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", UI_WHITE)
	th.set_color("font_hover_color", "Button", UI_BLACK)
	th.set_color("font_pressed_color", "Button", UI_BLACK)
	th.set_color("font_color", "Label", UI_WHITE)

	var root := Control.new()
	root.theme = th
	root.size = Vector2(pause_size)
	pause_vp.add_child(root)
	var frame := ColorRect.new()
	frame.color = UI_WHITE
	frame.size = Vector2(pause_size)
	root.add_child(frame)
	var bg := ColorRect.new()
	bg.color = UI_BLACK
	bg.position = Vector2(6, 6)
	bg.size = Vector2(pause_size) - Vector2(12, 12)
	root.add_child(bg)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 62)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 12)
	title.size = Vector2(pause_size.x, 80)
	root.add_child(title)
	var defs := [["resume", "Resume"], ["recenter", "Recenter here"], ["sizem", ""], ["sizep", ""], ["hm", ""], ["hp", ""],
		["sizereset", ""], ["sizegest", ""], ["vignette", ""], ["walk", ""],
		["panel", ""], ["hints", ""], ["handlit", ""], ["helpsign", ""],
		["retro", ""], ["monitor", ""], ["menu", ""], ["quit", ""]]
	var bw := (float(pause_size.x) - 120.0 - 24.0) * 0.5
	for i in defs.size():
		var b := Button.new()
		b.position = Vector2(60.0 + float(i % 2) * (bw + 24.0), 104.0 + float(i >> 1) * 84.0)
		b.size = Vector2(bw, 70)
		b.text = str(defs[i][1])
		b.add_theme_font_size_override("font_size", 26)
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pause_pressed.bind(str(defs[i][0])))
		root.add_child(b)
		pause_btns[str(defs[i][0])] = b

	var shader := Shader.new()
	# (iteration 32) depth-tested again: your other hand, the table and the dealer are in front of it when they are nearer
	shader.code = PAUSE_SHADER.replace("render_mode unshaded, cull_disabled;", "render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;")
	pause_mat = ShaderMaterial.new()
	pause_mat.shader = shader
	pause_mat.render_priority = 102
	pause_mat.set_shader_parameter("tex", pause_vp.get_texture())
	var quad := QuadMesh.new()
	quad.size = pause_world
	pause_quad = MeshInstance3D.new()
	pause_quad.name = "VRBootPauseQuad"
	pause_quad.mesh = quad
	pause_quad.material_override = pause_mat
	pause_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pause_quad.visible = false
	fx_root.add_child(pause_quad)
	_pause_refresh()

func _pause_refresh() -> void:
	(pause_btns["vignette"] as Button).text = "Comfort vignette: " + ("ON" if comfort_vignette else "OFF")
	(pause_btns["walk"] as Button).text = "Stick walking: " + ("ON" if stick_walk else "OFF")
	(pause_btns["panel"] as Button).text = "Floating panel: " + ("ON" if panel_visible else "OFF")
	(pause_btns["hints"] as Button).text = "Item hints [ ]: " + ("ON" if hint_dim else "OFF")
	(pause_btns["handlit"] as Button).text = "Hands lit by game: " + ("ON" if hand_lit else "OFF")
	(pause_btns["sizegest"] as Button).text = "Two-hand size: " + ("ON" if size_gesture else "OFF")
	(pause_btns["sizem"] as Button).text = "World smaller  (%d%%)" % int(round(_ref_scale() / world_scale * 100.0))
	(pause_btns["sizep"] as Button).text = "World bigger"
	(pause_btns["hm"] as Button).text = "Seat lower  (%+d cm)" % int(round((seat.y - _ref_seat_y()) / world_scale * 100.0))
	(pause_btns["hp"] as Button).text = "Seat higher"
	(pause_btns["sizereset"] as Button).text = "Reset size and height"
	(pause_btns["helpsign"] as Button).text = "Bathroom sign: " + ("ON" if (help_sign and not help_hidden_run) else "OFF")
	(pause_btns["retro"] as Button).text = "Retro colours: " + ("ON" if retro_look else "OFF")
	(pause_btns["monitor"] as Button).text = "PC monitor view: " + ("ON" if monitor_view else "OFF")
	(pause_btns["menu"] as Button).text = "Press again: main menu" if pause_confirm == "menu" else "Main menu"
	(pause_btns["quit"] as Button).text = "Press again: quit game" if pause_confirm == "quit" else "Quit game"

func _pause_toggle() -> void:
	if pause_open:
		_pause_close()
	else:
		_pause_open()

func _pause_open() -> void:
	if pause_open or not _in_main_scene() or xr_cam == null:
		return
	pause_open = true
	pause_confirm = ""
	_pause_refresh()
	var ws := world_scale
	var cam := xr_cam.global_transform
	var fwd := -cam.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.2:
		fwd = Vector3(-sin(anchor_yaw), 0.0, -cos(anchor_yaw))
	fwd = fwd.normalized()
	var pos := cam.origin + fwd * (1.1 * ws)
	pos.y = cam.origin.y - 0.08 * ws
	(pause_quad.mesh as QuadMesh).size = pause_world * ws
	pause_quad.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), pos)
	pause_quad.visible = true
	pause_hand_ok = false
	_pause_follow()
	pause_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_tree().paused = true
	print("VRBoot: paused")

func _pause_close() -> void:
	if not pause_open:
		return
	pause_open = false
	pause_confirm = ""
	pause_hand_ok = false
	get_tree().paused = false
	pause_quad.visible = false
	pause_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_pause_leave()
	print("VRBoot: resumed")

func _pause_pressed(id: String) -> void:
	if id != "menu" and id != "quit":
		pause_confirm = ""
	match id:
		"resume":
			_pause_close()
		"recenter":
			_pause_close()
			_recenter_by_hand()
		"vignette":
			comfort_vignette = not comfort_vignette
			_save_settings()
		"walk":
			stick_walk = not stick_walk
			_save_settings()
		"panel":
			panel_visible = not panel_visible
			_save_settings()
		"hints":
			hint_dim = not hint_dim
			_save_settings()
		"handlit":
			hand_lit = not hand_lit
			_apply_hand_shader()
			_save_settings()
		"sizegest":
			size_gesture = not size_gesture
			_save_settings()
		"sizem":
			_size_nudge(-SIZE_STEP, 0.0)
		"sizep":
			_size_nudge(SIZE_STEP, 0.0)
		"hm":
			_size_nudge(0.0, -HEIGHT_STEP_CM)
		"hp":
			_size_nudge(0.0, HEIGHT_STEP_CM)
		"sizereset":
			_size_reset()
		"helpsign":
			if help_hidden_run:
				help_hidden_run = false
				help_sign = true
			else:
				help_sign = not help_sign
			_save_settings()
		"retro":
			retro_look = not retro_look
			retro_t = 0.0
			_save_settings()
		"monitor":
			monitor_view = not monitor_view
			_monitor_apply()
			_save_settings()
		"menu":
			if pause_confirm == "menu":
				_pause_close()
				print("VRBoot: leaving to the main menu")
				get_tree().change_scene_to_file("res://scenes/menu.tscn")
				return
			pause_confirm = "menu"
		"quit":
			if pause_confirm == "quit":
				print("VRBoot: quit from the pause menu")
				get_tree().paused = false
				get_tree().quit()
				return
			pause_confirm = "quit"
	_pause_refresh()

# World-space ray against a quad: returns (u, v, distance), or (-1, -1, INF) when it misses.
func _ray_quad(o: Vector3, d: Vector3, t: Transform3D, size: Vector2) -> Vector3:
	var n := t.basis.z.normalized()
	var denom := d.dot(n)
	if absf(denom) < 0.0001:
		return Vector3(-1.0, -1.0, INF)
	var dist := (t.origin - o).dot(n) / denom
	if dist < 0.0:
		return Vector3(-1.0, -1.0, INF)
	var local := t.affine_inverse() * (o + d * dist)
	var u := local.x / size.x + 0.5
	var v := 0.5 - local.y / size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector3(-1.0, -1.0, INF)
	return Vector3(u, v, dist)

# The menu is held in the left hand like a tablet (above it, a little towards you, turned to your face). Without a left
# controller it stays where it opened.
func _pause_follow() -> void:
	var lh := left_hand
	if lh == null or lh.grip == null or not lh.was_active or xr_cam == null or not is_instance_valid(xr_cam):
		return
	var ws := world_scale
	var head := xr_cam.global_position
	var want := lh.grip.global_transform.origin + Vector3.UP * (0.11 * ws)
	var tow := head - want
	if tow.length() > 0.001:
		want += tow.normalized() * (0.05 * ws)
	if head.distance_to(want) < 0.30 * ws:
		want = head + (want - head).normalized() * (0.30 * ws)       # never nearer than a reading distance
	if not pause_hand_ok:
		pause_hand_pos = want
	else:
		pause_hand_pos = pause_hand_pos.lerp(want, 1.0 - exp(-get_process_delta_time() * 22.0))
	var away := (pause_hand_pos - head).normalized()
	var upref := Vector3.UP if absf(away.y) < 0.98 else Vector3.BACK
	(pause_quad.mesh as QuadMesh).size = pause_world * ws * PAUSE_HAND_SCALE
	pause_quad.global_transform = Transform3D(Basis.looking_at(away, upref), pause_hand_pos)
	pause_hand_ok = true

func _pause_size() -> Vector2:
	return pause_world * world_scale * (PAUSE_HAND_SCALE if pause_hand_ok else 1.0)

func _pause_pointer() -> void:
	_pause_follow()
	var h := active_hand
	ui_active = false
	ui_px = NO_HIT
	world_hit = false
	world_hit_dist = INF
	if mouse_ray != null and is_instance_valid(mouse_ray):
		mouse_ray.set("result", {})
	if h == null or not h.was_active:
		_pause_leave()
		return
	var hit := _ray_quad(h.ray_o, h.ray_d, pause_quad.global_transform, _pause_size())
	if hit.x < 0.0:
		_pause_leave()
		return
	ui_active = true                      # the laser turns blue and stops at the menu
	last_panel_dist = hit.z
	pause_px = Vector2(hit.x, hit.y) * Vector2(pause_size)
	if pause_last.distance_to(pause_px) > 0.4:
		var ev := InputEventMouseMotion.new()
		ev.position = pause_px
		ev.global_position = pause_px
		if pause_last.x >= 0.0:
			ev.relative = pause_px - pause_last
		pause_last = pause_px
		pause_vp.push_input(ev, true)

func _pause_leave() -> void:
	if pause_last.x < 0.0:
		return
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(-50, -50)
	ev.global_position = ev.position
	pause_last = NO_HIT
	pause_vp.push_input(ev, true)

func _pause_button(pressed: bool) -> void:
	var at := pause_px if pause_px.x >= 0.0 else (pause_last if pause_last.x >= 0.0 else Vector2(-50, -50))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	pause_vp.push_input(ev, true)

# Sit down where you are: the same as clicking the left stick.
func _recenter_by_hand() -> void:
	needs_recenter = false
	walk_off = Vector3.ZERO
	walk_to_table = false
	hold_for_dealer = false
	_place_origin(false)
	print("VRBoot: recentered by hand")


# ------------------------------------------------------------------ fades
