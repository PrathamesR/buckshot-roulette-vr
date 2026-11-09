# Saved settings, scene scan, diagnostics, probes
# (Part of the Buckshot Roulette VR mod. Chain position 14: this file extends 13_name_machine.gd; see src/README.md.)
extends "13_name_machine.gd"

const SETTINGS_PATH := "user://vr_mod/vr_settings.cfg"

var probe_saves := 0

var diag_timer := 0.0

# Looks at the corners of the 2D window texture. A flat grey there is the "grey box" behind the
# menu; it is measured and subtracted on the panel. Also logs what it saw and saves a few PNGs.
func _probe_root() -> void:
	var tex := _ui_tex()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty() or img.is_compressed():
		print("VRBoot: probe: window texture not readable")
		return
	var w := img.get_width()
	var h := img.get_height()
	var pts: Array[Vector2i] = [Vector2i(3, 3), Vector2i(w - 4, 3), Vector2i(3, h - 4), Vector2i(w - 4, h - 4)]
	var cmin := Color(1, 1, 1, 1)
	var txt := ""
	for p in pts:
		var c := img.get_pixelv(p)
		cmin.r = minf(cmin.r, c.r)
		cmin.g = minf(cmin.g, c.g)
		cmin.b = minf(cmin.b, c.b)
		txt += "(%d,%d,%d,%d) " % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), roundi(c.a * 255.0)]
	var mid := img.get_pixelv(Vector2i(w / 2, h / 2))
	var strongest := maxf(cmin.r, maxf(cmin.g, cmin.b))
	var bg := Vector3.ZERO
	if strongest < 0.45:
		bg = Vector3(cmin.r, cmin.g, cmin.b)
	panel_mat.set_shader_parameter("bg", bg)
	print("VRBoot: probe: window ", w, "x", h, " corners ", txt, " centre (", roundi(mid.r * 255.0), ",",
		roundi(mid.g * 255.0), ",", roundi(mid.b * 255.0), ",", roundi(mid.a * 255.0), ") bg subtracted=", bg,
		" scene=", cur_scene.name if cur_scene != null else "-")
	if probe_saves < 3:
		probe_saves += 1
		img.save_png("user://vr_mod/window_probe_%d.png" % probe_saves)


# ------------------------------------------------------------------ misc

# (iteration 35) Is the text still there? The width of a word in the game's font (0 = the font is broken), how many labels are on screen,
# the state of the hint label. A broken font is loaded again and given to the mod's labels.
func _text_diag() -> String:
	var fw := -1.0
	if ui_font != null:
		fw = ui_font.get_string_size("MENU", HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
		if fw <= 0.0:
			var nf := ResourceLoader.load(UI_FONT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Font
			if nf != null:
				ui_font = nf
				for l in [hint_label, gun_put_label, size_label]:
					if l != null and is_instance_valid(l):
						(l as Label3D).font = nf
				for v in [pause_vp, help_vp]:
					if v != null and is_instance_valid(v) and (v as SubViewport).theme != null:
						(v as SubViewport).theme.default_font = nf
				print("VRBoot: the game's font gave no text width - loaded again")
	var shown := 0
	var total := 0
	for n in get_tree().root.find_children("*", "Label3D", true, false):
		total += 1
		if (n as Label3D).is_visible_in_tree() and str((n as Label3D).text) != "":
			shown += 1
	return str(" text[font_w=", snappedf(fw, 0.1), " labels=", shown, "/", total, " hint=", hint_label != null and hint_label.visible, "] ts=",
		snappedf(Engine.time_scale, 0.01), " tree_paused=", get_tree().paused)

func _diagnostics(delta: float) -> void:
	diag_timer += delta
	if diag_timer < 5.0:
		return
	diag_timer = 0.0
	print("VRBoot: [5s] scene=", cur_scene.name if cur_scene != null else "-", " mode=", mode,
		" head_local=", xr_cam.position, " hands=", left_hand.was_active, "/", right_hand.was_active,
		" interaction=", interaction != null, " hit=", world_hit, " ui=", ui_active,
		" blackout=", snappedf(blackout_alpha, 0.01), " glide=", glide,
		" walk=", walk_allowed, " to_table=", walk_to_table, " hold=", hold_for_dealer,
		" walk_off=", walk_off, " assist=", assisted, " hints=", hint_nodes.size(),
		" head_xz=(", snappedf(xr_cam.global_position.x, 0.1), ", ", snappedf(xr_cam.global_position.z, 0.1), ")",
		" bounds=", bounds_on, " wall_fade=", snappedf(wall_fade, 0.01), " doors_open=", gap_bath_open, "/", gap_back_open,
		" restroom=", restroom_stage, " pills=", pill_menu_active,
		" tv=", tv_state, " pill=", pill_state, " pause=", pause_open, _text_diag())

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and int(cfg.get_value("vr", "version", 2)) >= 3:
		scale_big = float(cfg.get_value("vr", "scale_big", DEFAULT_SCALE_BIG))
		seat_big = cfg.get_value("vr", "seat_big", DEFAULT_SEAT_BIG)
		scale_small = float(cfg.get_value("vr", "scale_small", DEFAULT_SCALE_SMALL))
		seat_small = cfg.get_value("vr", "seat_small", DEFAULT_SEAT_SMALL)
		panel_visible = true                           # (iteration 36) the panel always starts on (a saved "off" hid all of the game text for good)
		monitor_view = bool(cfg.get_value("vr", "monitor_view", true))
		retro_look = bool(cfg.get_value("vr", "retro_look", true))
		glide = bool(cfg.get_value("vr", "glide", true))
		stick_walk = bool(cfg.get_value("vr", "stick_walk", true))
		comfort_vignette = bool(cfg.get_value("vr", "vignette", true))
		hint_dim = bool(cfg.get_value("vr", "hint_dim", false))
		hand_lit = bool(cfg.get_value("vr", "hand_lit", true))
		size_gesture = bool(cfg.get_value("vr", "size_gesture2", false))
		help_sign = bool(cfg.get_value("vr", "help_sign", true))
		gun_cal = Vector3(clampf(float(cfg.get_value("vr", "gun_cal_x", 0.0)), -GUN_CAL_MAX, GUN_CAL_MAX), \
			clampf(float(cfg.get_value("vr", "gun_cal_y", 0.0)), -GUN_CAL_MAX, GUN_CAL_MAX), \
			clampf(float(cfg.get_value("vr", "gun_cal_z", 0.0)), -GUN_CAL_MAX, GUN_CAL_MAX))

func _save_settings() -> void:
	_store_regime()
	var cfg := ConfigFile.new()
	cfg.set_value("vr", "version", 3)
	cfg.set_value("vr", "scale_big", scale_big)
	cfg.set_value("vr", "seat_big", seat_big)
	cfg.set_value("vr", "scale_small", scale_small)
	cfg.set_value("vr", "seat_small", seat_small)
	cfg.set_value("vr", "panel_visible", panel_visible)
	cfg.set_value("vr", "monitor_view", monitor_view)
	cfg.set_value("vr", "retro_look", retro_look)
	cfg.set_value("vr", "glide", glide)
	cfg.set_value("vr", "stick_walk", stick_walk)
	cfg.set_value("vr", "vignette", comfort_vignette)
	cfg.set_value("vr", "hint_dim", hint_dim)
	cfg.set_value("vr", "hand_lit", hand_lit)
	cfg.set_value("vr", "size_gesture2", size_gesture)
	cfg.set_value("vr", "help_sign", help_sign)
	cfg.set_value("vr", "gun_cal_x", gun_cal.x)
	cfg.set_value("vr", "gun_cal_y", gun_cal.y)
	cfg.set_value("vr", "gun_cal_z", gun_cal.z)
	var err := cfg.save(SETTINGS_PATH)
	print("VRBoot: saved (err ", err, ") big: scale=", scale_big, " seat=", seat_big,
		"  small: scale=", scale_small, " seat=", seat_small)
