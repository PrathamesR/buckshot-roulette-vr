# Laser pointer, 2D panel, buttons and input
# (Part of the Buckshot Roulette VR mod. Chain position 34: this file extends 33_items.gd; see src/README.md.)
extends "33_items.gd"

const TRIGGER_ON := 0.7

const TRIGGER_OFF := 0.35

const STICK_BOTH_MS := 450                         # (iteration 36) both sticks clicked within this long = the Virtual Desktop overlay: the game does nothing

const PANEL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;
// (depth test off: the text must never sink into the room walls when the world is made smaller)
// The window texture is read raw (as stored, sRGB-coded). We remove its background there,
// then convert to linear ourselves, so the result does not depend on engine colour hints.
// Straight alpha (not additive): where the window is empty the quad adds nothing at all, whatever
// the engine does to the colour of the quad (fog tints a whole additive quad grey otherwise).
uniform sampler2D tex : filter_nearest;
uniform float brightness = 1.0;
uniform float black_cut = 0.03;
uniform vec3 bg = vec3(0.0);
vec3 to_linear(vec3 c) {
	vec3 t = step(vec3(0.04045), c);
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), t);
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	c = max(c - bg - vec3(black_cut), vec3(0.0));
	vec3 l = to_linear(c) * brightness;
	float a = clamp(max(l.r, max(l.g, l.b)), 0.0, 1.0);
	ALBEDO = (a > 0.0001) ? l / a : vec3(0.0);
	ALPHA = a;
}
"""

var world_hit_alias := ""           # the click target the pointing ray is on ("" = none)

var panel: MeshInstance3D

var stick_pend_hand: Hand = null   # (iteration 36) a stick click waits a moment to see whether the other stick follows

var stick_pend_due := 0

var pause_click_down := false

var panel_size := Vector2(2.0, 1.125)

var click_in_ui := false

var last_ui_px := NO_HIT

# The alias of the click target the ray hit ("" if it is not one).
func _hit_alias(res: Dictionary) -> String:
	if res.is_empty() or not res.has("collider"):
		return ""
	var col = res["collider"]
	if col == null or not is_instance_valid(col):
		return ""
	var p = col.get_parent()
	if p == null:
		return ""
	for ch in p.get_children():
		var a = ch.get("interactionAlias")
		if a != null:
			return str(a)
	return ""

func _update_pointer() -> void:
	help_hover = false
	if pause_open:
		_pause_pointer()
		return
	var phys := _physical_only()
	var h := active_hand
	world_hit = false
	world_hit_dist = INF
	ui_active = false
	ui_px = NO_HIT
	if h == null or not h.was_active:
		if mouse_ray != null and is_instance_valid(mouse_ray):
			mouse_ray.set("result", {})
		_ui_leave()
		return

	if help_shown and not pill_menu_active and not phys:
		var hhit := _ray_quad(h.ray_o, h.ray_d, help_quad.global_transform, HELP_SIZE)
		if hhit.x >= 0.0:
			help_hover = true
			help_hit_dist = hhit.z
			help_px = Vector2(hhit.x, hhit.y) * Vector2(HELP_PX)

	var max_len := RAY_MAX_UNITS
	var space := get_tree().root.world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(h.ray_o, h.ray_o + h.ray_d * max_len)
	var res := space.intersect_ray(q)
	if not res.is_empty() and _behind_wall(res["position"]):
		res = {}                        # the walls have no collision: do not reach through them
	# Aim assist in the building: small or far click targets (pills, doors, TV buttons) pull the
	# pointer in when you point close to them and nothing clickable is directly under the laser.
	assisted = false
	if _in_main_scene() and (mode == "follow" or walk_to_table) and not _has_branch(res):
		var a := _assist_hit(h.ray_o, h.ray_d, res)
		if not a.is_empty():
			res = a
			assisted = true
	if not res.is_empty():
		world_hit = true
		world_hit_pos = res["position"]
		world_hit_dist = h.ray_o.distance_to(world_hit_pos)
		world_hit_alias = _hit_alias(res)
	else:
		world_hit_alias = ""

	# The game reads this every frame instead of its own mouse ray.
	# In the bathroom everything is done by hand, so the (invisible) laser must not click anything there.
	var feed := res
	if not res.is_empty() and _alias_locked(_hit_alias(res)):
		feed = {}                       # a game item before you sit down: the laser passes it by
	if mouse_ray != null and is_instance_valid(mouse_ray):
		mouse_ray.set("result", {} if (phys or (restroom_stage and not pill_menu_active) or help_hover) else feed)

	# 2D interface panel: clickable in the menus and for the pill question; display only elsewhere in the building
	if panel_visible and not phys and (not _in_main_scene() or pill_menu_active):
		var px := _ray_panel(h.ray_o, h.ray_d)
		if px.x >= 0.0 and (pill_menu_active or last_panel_dist < world_hit_dist):
			ui_active = true
			ui_px = px
	if ui_active and pill_menu_active:
		_pill_hover(ui_px)
		if mouse_ray != null and is_instance_valid(mouse_ray):
			mouse_ray.set("result", {})      # the hidden 3D boxes must not compete with the panel
	if ui_active:
		if last_ui_px.distance_to(ui_px) > 0.4:
			_ui_motion(ui_px)
	else:
		_ui_leave()

func _ray_panel(o: Vector3, d: Vector3) -> Vector2:
	last_panel_dist = INF
	var t := panel.global_transform
	var n := t.basis.z.normalized()
	var denom := d.dot(n)
	if denom > -0.0001:
		return NO_HIT
	var dist := (t.origin - o).dot(n) / denom
	if dist < 0.0:
		return NO_HIT
	var local := t.affine_inverse() * (o + d * dist)
	var u := local.x / panel_size.x + 0.5
	var v := 0.5 - local.y / panel_size.y
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return NO_HIT
	last_panel_dist = dist
	return Vector2(u, v) * ui_size

func _ui_motion(px: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = px
	ev.global_position = px
	if last_ui_px.x >= 0.0:
		ev.relative = px - last_ui_px
	last_ui_px = px
	get_tree().root.push_input(ev, true)

func _ui_leave() -> void:
	if last_ui_px.x < 0.0:
		return
	var ev := InputEventMouseMotion.new()
	ev.position = Vector2(-50, -50)
	ev.global_position = ev.position
	last_ui_px = NO_HIT
	get_tree().root.push_input(ev, true)

func _ui_button(px: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = px
	ev.global_position = px
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	get_tree().root.push_input(ev, true)

func _world_button(pressed: bool) -> void:
	# A real mouse click far outside any 2D control: the game's InteractionManager sees it in _input.
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(-50, -50)
	ev.global_position = ev.position
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)

func _press_action(action: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


# ------------------------------------------------------------------ buttons

func _stick_pending() -> void:
	if stick_pend_hand == null or Time.get_ticks_msec() < stick_pend_due:
		return
	var hh := stick_pend_hand
	stick_pend_hand = null
	if gun_state == 1 and gun_hand == hh and gun_prop != null and not pause_open:
		_gun_cal_toggle()
	elif hh.side == "left":
		_recenter_by_hand()

func _update_buttons() -> void:
	_stick_pending()
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		if not hh.was_active:
			continue
		var c := hh.grip

		# trigger = click
		var trig := c.get_float("trigger")
		var down := trig > TRIGGER_ON or (hh.trigger_down and trig > TRIGGER_OFF) or c.is_button_pressed("trigger_click")
		if down and not hh.trigger_down:
			if hh != active_hand:
				active_hand = hh
				_update_pointer()
			click_in_ui = ui_active and not pill_menu_active and not pause_open and not (gun_state != 0 and hh == gun_hand) and hh != item_hand
			hh.world_click_sent = false
			if pause_open:
				pause_click_down = true
				_pause_button(true)
			elif gun_state != 0 and hh == gun_hand:
				_gun_trigger(hh)
			elif hh == item_hand:
				pass                      # carrying an item: the trigger does nothing
			elif help_hover:
				_help_click(hh)
			elif ui_active and pill_menu_active:
				_pill_click(ui_px, hh)
			elif ui_active:
				_ui_button(ui_px, true)
			else:
				_note_click_target()
				if not _laser_click_blocked():
					_world_button(true)
					hh.world_click_sent = true
			print("VRBoot: ", hh.side, " trigger  ui=", ui_active, " hit=", _describe_hit(),
				"" if ui_active or hh.world_click_sent else "  (not clickable with the laser)")
		elif not down and hh.trigger_down:
			if pause_click_down:
				pause_click_down = false
				_pause_button(false)
			elif click_in_ui:
				_ui_button(last_ui_px if last_ui_px.x >= 0.0 else NO_HIT, false)
			elif hh.world_click_sent:
				_world_button(false)
			hh.world_click_sent = false
		hh.trigger_down = down

		# A/X = accept, B/Y = cancel (B / Y also switches the TV off and closes the pause menu)
		var ax := c.is_button_pressed("ax_button")
		if ax != hh.ax_down:
			hh.ax_down = ax
			if not pause_open:
				_press_action("ui_accept", ax)
		var by := c.is_button_pressed("by_button")
		if by != hh.by_down:
			hh.by_down = by
			if by and pause_open:
				_pause_close()
				hh.by_swallow = true
			elif by and tv_state != 0:
				_tv_close(true)
				hh.by_swallow = true
			elif not by and hh.by_swallow:
				hh.by_swallow = false
			elif not pause_open and not gun_cal_on:
				_press_action("ui_cancel", by)

		# menu button = the pause menu (the game has none)
		var mb := c.is_button_pressed("menu_button")
		if mb != hh.menu_down:
			hh.menu_down = mb
			if mb:
				_pause_toggle()

		# (iteration 36) Left stick click: recenter (or the gun nudge mode in the gun hand). The right stick click does nothing any
		# more: it used to switch the 2D panel off, and Virtual Desktop's overlay (both sticks) switched the text off every time.
		# Both sticks together = that overlay: the game ignores both, and a single click waits a moment to see if the other follows.
		var click := c.is_button_pressed("primary_click")
		if click and not hh.stick_click_down:
			var now_ms := Time.get_ticks_msec()
			hh.stick_click_ms = now_ms
			var oth: Hand = right_hand if hh == left_hand else left_hand
			if oth.stick_click_down or now_ms - oth.stick_click_ms < STICK_BOTH_MS:
				stick_pend_hand = null                 # both sticks: nothing happens
			elif hh.side == "left" or (gun_state == 1 and gun_hand == hh and gun_prop != null and not pause_open):
				stick_pend_hand = hh
				stick_pend_due = now_ms + STICK_BOTH_MS
		hh.stick_click_down = click

		# left stick: menu arrows (it walks you instead while walking is possible)
		if gun_cal_on:
			hh.stick_dir = Vector2i.ZERO
		elif hh.side == "left" and walk_allowed:
			if hh.stick_dir.x != 0:
				_press_action("ui_left" if hh.stick_dir.x < 0 else "ui_right", false)
			if hh.stick_dir.y != 0:
				_press_action("ui_down" if hh.stick_dir.y < 0 else "ui_up", false)
			hh.stick_dir = Vector2i.ZERO
		elif hh.side == "left":
			var s := c.get_vector2("primary")
			var dir := Vector2i(_stick_axis(s.x, hh.stick_dir.x), _stick_axis(s.y, hh.stick_dir.y))
			if dir.x != hh.stick_dir.x:
				if hh.stick_dir.x != 0:
					_press_action("ui_left" if hh.stick_dir.x < 0 else "ui_right", false)
				if dir.x != 0:
					_press_action("ui_left" if dir.x < 0 else "ui_right", true)
			if dir.y != hh.stick_dir.y:
				if hh.stick_dir.y != 0:
					_press_action("ui_down" if hh.stick_dir.y < 0 else "ui_up", false)
				if dir.y != 0:
					_press_action("ui_down" if dir.y < 0 else "ui_up", true)
			hh.stick_dir = dir

func _stick_axis(v: float, current: int) -> int:
	if current == 0:
		if v > STICK_ON:
			return 1
		if v < -STICK_ON:
			return -1
		return 0
	if absf(v) < STICK_OFF:
		return 0
	return current

# Things you press with a finger (TV, pills, bathroom door) ignore the laser completely.
func _laser_click_blocked() -> bool:
	if _physical_only():
		return true
	if interaction == null or not is_instance_valid(interaction):
		return false
	var br = interaction.get("activeInteractionBranch")
	return br != null and is_instance_valid(br) and _is_poke(br)

func _describe_hit() -> String:
	if ui_active:
		return "panel px=%s" % [ui_px]
	var r = null
	if mouse_ray != null and is_instance_valid(mouse_ray):
		r = mouse_ray.get("result")
	if r is Dictionary and r.has("collider") and is_instance_valid(r["collider"]):
		var col: Node = r["collider"]
		var alias := ""
		if interaction != null and is_instance_valid(interaction):
			var branch = interaction.get("activeInteractionBranch")
			if branch != null and is_instance_valid(branch):
				alias = " alias=" + str(branch.get("interactionAlias"))
		return str(col.get_path()) + alias
	return "none"


# ------------------------------------------------------------------ panel

func _make_panel() -> void:
	var shader := Shader.new()
	shader.code = PANEL_SHADER
	panel_mat = ShaderMaterial.new()
	panel_mat.shader = shader
	panel_mat.render_priority = 101
	panel_mat.set_shader_parameter("tex", _ui_tex())
	var quad := QuadMesh.new()
	quad.size = panel_size
	panel = MeshInstance3D.new()
	panel.name = "VRBootPanel"
	panel.mesh = quad
	panel.material_override = panel_mat
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(panel)

func _update_panel() -> void:
	panel.visible = panel_visible
	if not panel_visible:
		return
	var main_scene := _in_main_scene()
	var title := cur_scene.get_node_or_null("title") as Node3D if cur_scene != null else null
	if title != null and game_cam != null and not main_scene:
		# Menu: lay the 2D interface exactly over the game camera's picture, in the plane of the 3D
		# title card, so buttons sit flush with it just like on a monitor.
		var gt := game_cam.global_transform
		var fwd := -gt.basis.z
		var dd := (title.global_position - gt.origin).dot(fwd)
		if dd < 0.5:
			dd = 2.5
		var dp := dd * 0.985
		var ph := 2.0 * dp * tan(deg_to_rad(game_cam.fov) * 0.5)
		var pw := ph * ui_size.x / ui_size.y
		if absf(panel_size.x - pw) > 0.001:
			panel_size = Vector2(pw, ph)
			(panel.mesh as QuadMesh).size = panel_size
		panel_key = "cam"
		panel.global_transform = Transform3D(gt.basis.orthonormalized(), gt.origin + fwd * dp)
		return
	# metres: [width, distance ahead, height above eye]
	var w := 1.5 if main_scene else 2.2
	var dist := 2.4 if main_scene else 1.8
	var up := 0.55 if main_scene else 0.0
	var near_face := main_scene and pill_state == 1 and xr_cam != null and is_instance_valid(xr_cam)
	if near_face:
		w = 1.3
		dist = 1.4
		up = -0.05
	var key := "%s|%s|%s|%s" % [main_scene, snappedf(world_scale, 0.01), anchor_pos if not near_face else Vector3.ZERO, near_face]
	if key != panel_key:
		panel_key = key
		panel_size = Vector2(w, w * ui_size.y / ui_size.x) * world_scale
		(panel.mesh as QuadMesh).size = panel_size
	var yb := Basis(Vector3.UP, anchor_yaw)
	var eye := anchor_pos + yb * seat
	if near_face:
		var fwd := -xr_cam.global_transform.basis.z
		fwd.y = 0.0
		if fwd.length() > 0.01:
			fwd = fwd.normalized()
			yb = Basis(Vector3.UP, atan2(-fwd.x, -fwd.z))
		eye = xr_cam.global_position
	panel.global_transform = Transform3D(yb, eye + yb * Vector3(0.0, up * world_scale, -dist * world_scale))


# ------------------------------------------------------------------ laser visuals

# At the table everything is done by hand; the laser only shows where the game truly needs a pointer: the menus, the pause
# menu, the floating panel, and the few words you can only point at.
func _laser_wanted() -> bool:
	if pause_open or ui_active or help_hover or pill_menu_active:
		return true
	if not _in_main_scene() or mode != "table":
		return true
	return world_hit and LASER_ALIASES.has(world_hit_alias)
