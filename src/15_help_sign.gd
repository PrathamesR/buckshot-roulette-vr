# Bathroom controls sign and the tutorial check box
# (Part of the Buckshot Roulette VR mod. Chain position 15: this file extends 14_settings.gd; see src/README.md.)
extends "14_settings.gd"

# The controls sign: on the dark metal plate to the right of the bathroom door (the open stall door, node Cube_117).
# Its room-facing surface is the plane through (-139.51, 5.71) and (-143.26, 18.37); it faces (-0.9588, 0, -0.2840).
const HELP_POS := Vector3(-141.5, 7.9, 12.0)         # game units, 0.12 in front of that plane

const HELP_CLOSE := Rect2(300.0, 694.0, 500.0, 82.0)   # the 'take down' button, in sign pixels

const HELP_CHECK := Rect2(50.0, 562.0, 1000.0, 90.0)   # (iteration 36) the 'see tutorial messages' check box row, in sign pixels

const HELP_GRACE_S := 1.5                          # a freshly shown sign ignores touches this long

var help_check_fill: ColorRect

var help_t0 := 0.0                 # time the sign was last shown

var help_prev_z := {}              # hand side -> fingertip distance in front of the sign last frame

var help_btn_bg: ColorRect

var help_close_hot := false

var help_btn_label: Label

func _make_help() -> void:
	help_vp = SubViewport.new()
	help_vp.name = "VRBootHelpUI"
	help_vp.size = HELP_PX
	help_vp.disable_3d = true
	help_vp.transparent_bg = false
	help_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(help_vp)

	var font := _game_font()
	var root := Control.new()
	root.size = Vector2(HELP_PX)
	help_vp.add_child(root)
	var frame := ColorRect.new()
	frame.color = UI_WHITE
	frame.size = Vector2(HELP_PX)
	root.add_child(frame)
	var bg := ColorRect.new()
	bg.color = UI_BLACK
	bg.position = Vector2(6, 6)
	bg.size = Vector2(HELP_PX) - Vector2(12, 12)
	root.add_child(bg)
	var title := Label.new()
	title.text = "CONTROLS"
	if font != null:
		title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", UI_LIME)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 18)
	title.size = Vector2(HELP_PX.x, 84)
	root.add_child(title)

	# (iteration 37) two columns, one fixed-height row each (the long MENU text used to run into the check box)
	var rows := [
		["TOUCH", "Poke the TV and the door."],
		["PILLS", "Lift the bottle to your mouth."],
		["MOVE", "Left stick walks, right turns."],
		["MENU", "The menu button on your left controller opens the menu."],
	]
	var row_y := 116.0
	var row_h := 104.0
	for ri in rows.size():
		var e: Array = rows[ri]
		var ry: float = row_y + row_h * float(ri)
		var hl := Label.new()
		hl.text = str(e[0])
		if font != null:
			hl.add_theme_font_override("font", font)
		hl.add_theme_font_size_override("font_size", 40)
		hl.add_theme_color_override("font_color", UI_LIME)
		hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hl.position = Vector2(50.0, ry)
		hl.size = Vector2(230.0, row_h)
		root.add_child(hl)
		var bl := Label.new()
		bl.text = str(e[1])
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if font != null:
			bl.add_theme_font_override("font", font)
		bl.add_theme_font_size_override("font_size", 34)
		bl.add_theme_color_override("font_color", UI_WHITE)
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		bl.position = Vector2(300.0, ry)
		bl.size = Vector2(float(HELP_PX.x) - 350.0, row_h)
		root.add_child(bl)
		var ln := ColorRect.new()
		ln.color = Color(1.0, 1.0, 1.0, 0.35)
		ln.position = Vector2(50.0, ry + row_h - 1.0)
		ln.size = Vector2(float(HELP_PX.x) - 100.0, 2.0)
		root.add_child(ln)

	# (iteration 36) the check box: SEE TUTORIAL MESSAGES
	var cb_frame := ColorRect.new()
	cb_frame.color = UI_WHITE
	cb_frame.position = HELP_CHECK.position + Vector2(0.0, 17.0)
	cb_frame.size = Vector2(56.0, 56.0)
	root.add_child(cb_frame)
	var cb_in := ColorRect.new()
	cb_in.color = UI_BLACK
	cb_in.position = Vector2(4.0, 4.0)
	cb_in.size = Vector2(48.0, 48.0)
	cb_frame.add_child(cb_in)
	help_check_fill = ColorRect.new()
	help_check_fill.color = UI_LIME
	help_check_fill.position = Vector2(8.0, 8.0)
	help_check_fill.size = Vector2(32.0, 32.0)
	help_check_fill.visible = false
	cb_in.add_child(help_check_fill)
	var cb_label := Label.new()
	cb_label.text = "SEE TUTORIAL MESSAGES"
	if font != null:
		cb_label.add_theme_font_override("font", font)
	cb_label.add_theme_font_size_override("font_size", 42)
	cb_label.add_theme_color_override("font_color", UI_WHITE)
	cb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb_label.position = HELP_CHECK.position + Vector2(84.0, 0.0)
	cb_label.size = Vector2(HELP_CHECK.size.x - 84.0, HELP_CHECK.size.y)
	root.add_child(cb_label)

	help_btn_bg = ColorRect.new()
	help_btn_bg.color = UI_WHITE
	help_btn_bg.position = HELP_CLOSE.position
	help_btn_bg.size = HELP_CLOSE.size
	root.add_child(help_btn_bg)
	var inner := ColorRect.new()
	inner.color = UI_BLACK
	inner.position = Vector2(3, 3)
	inner.size = HELP_CLOSE.size - Vector2(6, 6)
	help_btn_bg.add_child(inner)
	help_btn_label = Label.new()
	help_btn_label.text = "TAKE DOWN"
	if font != null:
		help_btn_label.add_theme_font_override("font", font)
	help_btn_label.add_theme_font_size_override("font_size", 44)
	help_btn_label.add_theme_color_override("font_color", UI_WHITE)
	help_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	help_btn_label.position = HELP_CLOSE.position
	help_btn_label.size = HELP_CLOSE.size
	root.add_child(help_btn_label)

	var shader := Shader.new()
	shader.code = PAUSE_SHADER
	help_mat = ShaderMaterial.new()
	help_mat.shader = shader
	help_mat.set_shader_parameter("tex", help_vp.get_texture())
	help_mat.set_shader_parameter("tone", 0.85)
	var quad := QuadMesh.new()
	quad.size = HELP_SIZE
	help_quad = MeshInstance3D.new()
	help_quad.name = "VRBootHelpSign"
	help_quad.mesh = quad
	help_quad.material_override = help_mat
	help_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	help_quad.visible = false
	fx_root.add_child(help_quad)

# Where the sign hangs: flat on the plate, facing into the room (local +Z = the plate's room-facing normal).
func _help_transform() -> Transform3D:
	return Transform3D(Basis(Vector3(-0.284034, 0.0, 0.958814), Vector3.UP, Vector3(-0.958814, 0.0, -0.284034)), HELP_POS)

func _help_in_check(px: Vector2) -> bool:
	return px.x >= 0.0 and HELP_CHECK.has_point(px)

func _help_check_toggle(hh: Hand) -> void:
	_tut_toggle()
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	_help_check_refresh()

func _help_check_refresh() -> void:
	if not tut_loaded:
		_tut_load()
	if help_check_fill != null:
		help_check_fill.visible = tut_enabled

func _help_in_close(px: Vector2) -> bool:
	return px.x >= 0.0 and HELP_CLOSE.has_point(px)

# Shows the sign while you are in the bathroom (and only then); handles the fingertip touch.
func _update_help(_delta: float) -> void:
	var want := help_sign and not help_hidden_run and not pause_open and _in_main_scene() and regime_big and not kick_on \
		and xr_cam != null and is_instance_valid(xr_cam) and _room_mask(xr_cam.global_position.x) == 1
	if want != help_shown:
		help_shown = want
		help_quad.visible = want
		help_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if want else SubViewport.UPDATE_DISABLED
		if want:
			help_quad.global_transform = _help_transform()
			help_t0 = t_alive
			help_prev_z.clear()
		print("VRBoot: bathroom sign ", "shown" if want else "hidden")
	if not help_shown:
		help_hover = false
		return
	_help_check_refresh()
	var hot := help_hover and _help_in_close(help_px)
	if hot != help_close_hot:
		help_close_hot = hot
		help_btn_bg.color = UI_LIME if hot else UI_WHITE
		(help_btn_bg.get_child(0) as ColorRect).color = UI_LIME if hot else UI_BLACK
		help_btn_label.add_theme_color_override("font_color", UI_BLACK if hot else UI_WHITE)
	var inv := help_quad.global_transform.affine_inverse()
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		if not hh.was_active or hh.holding:
			continue
		var lp := inv * _hand_tip(hh)
		# only a deliberate push counts: the fingertip comes from the side you are on, up to the sign
		var zone := POKE_PAD_M * 2.0 * world_scale
		var head_side := 1.0
		if xr_cam != null and is_instance_valid(xr_cam):
			head_side = 1.0 if (inv * xr_cam.global_position).z >= 0.0 else -1.0
		var zin := lp.z * head_side
		var had_prev: bool = help_prev_z.has(hh.side)
		var prev_zin: float = float(help_prev_z.get(hh.side, 0.0))
		help_prev_z[hh.side] = zin
		if t_alive - help_t0 < HELP_GRACE_S or not had_prev:
			continue
		if absf(lp.z) > zone or absf(lp.x) > HELP_SIZE.x * 0.5 or absf(lp.y) > HELP_SIZE.y * 0.5:
			continue
		if prev_zin < zone:
			continue                      # it was already at the sign (or behind it): not a push
		var px := Vector2(lp.x / HELP_SIZE.x + 0.5, 0.5 - lp.y / HELP_SIZE.y) * Vector2(HELP_PX)
		if _help_in_close(px):
			_help_close(hh, "touch")
			return
		if _help_in_check(px):
			_help_check_toggle(hh)
			return

func _help_click(hh: Hand) -> void:
	hh.world_click_sent = false
	if _help_in_close(help_px):
		_help_close(hh, "trigger")
	elif _help_in_check(help_px):
		_help_check_toggle(hh)
	else:
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.03, 0.0)

func _help_close(hh: Hand, how: String) -> void:
	help_hidden_run = true                # only for this run: it is back next time you start the game
	help_hover = false
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.1, 0.0)
	print("VRBoot: bathroom sign taken down (", how, ", ", hh.side, " hand) until you restart the game; the pause menu can bring it back")



# ------------------------------------------------------------------ pause menu
