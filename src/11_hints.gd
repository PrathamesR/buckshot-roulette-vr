# On-screen hints, rings, gun label, tutorial messages
# (Part of the Buckshot Roulette VR mod. Chain position 11: this file extends 10_blood.gd; see src/README.md.)
extends "10_blood.gd"

const TUT_KEYS := ["mag_break", "phone_ear", "adr_cap", "rack"]   # (iteration 36) all the tutorial words there are

const TUT_PATH := "user://vr_mod/vr_tutorial.cfg"  # (iteration 34) which tutorial words have been shown already

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled;
uniform float frac = -1.0;
uniform float hot = 0.0;
uniform vec4 lime : source_color = vec4(0.776471, 0.87451, 0.380392, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.x, -p.y) / 6.2831853;
	if (ang < 0.0) {
		ang += 1.0;
	}
	float px = 0.03;
	float band = (1.0 - smoothstep(0.98 - px, 0.98, r)) * smoothstep(0.52 - px, 0.52, r);
	float track = (1.0 - smoothstep(0.88 - px, 0.88, r)) * smoothstep(0.62 - px, 0.62, r);
	vec3 on_col = vec3(1.0);
	if (hot > 0.5) {
		on_col = lime.rgb;
	}
	if (frac >= 0.0 && ang <= frac) {
		on_col = lime.rgb;
	}
	ALBEDO = mix(vec3(0.0), on_col, track);
	ALPHA = band * 0.95;
}
"""

var ring_mi: MeshInstance3D        # a small round marker (progress ring) instead of words

var ring_mat: ShaderMaterial

var ring_used := false

var tut_seen := {}                 # (iteration 34) tutorial words that have been shown (and done) once

var hint_used := false             # something asked for the hint this frame

func _make_gun_label() -> void:
	gun_put_label = Label3D.new()
	gun_put_label.name = "VRBootPutDown"
	gun_put_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gun_put_label.no_depth_test = true
	gun_put_label.shaded = false
	gun_put_label.font = _game_font()
	gun_put_label.font_size = 72
	gun_put_label.outline_size = 16
	gun_put_label.pixel_size = 0.0006
	gun_put_label.modulate = Color(1, 1, 1)
	gun_put_label.outline_modulate = Color(0, 0, 0)
	gun_put_label.render_priority = 105
	gun_put_label.outline_render_priority = 104
	gun_put_label.text = "PUT THE SHOTGUN DOWN"
	gun_put_label.visible = false
	fx_root.add_child(gun_put_label)

func _make_hint_label() -> void:
	hint_label = Label3D.new()
	hint_label.name = "VRBootHint"
	hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint_label.no_depth_test = true
	hint_label.shaded = false
	hint_label.font = _game_font()
	hint_label.font_size = 56
	hint_label.outline_size = 14
	hint_label.pixel_size = 0.0006
	hint_label.modulate = Color(1, 1, 1)
	hint_label.outline_modulate = Color(0, 0, 0)
	hint_label.render_priority = 105
	hint_label.outline_render_priority = 104
	hint_label.visible = false
	fx_root.add_child(hint_label)

# A round marker instead of words: white = here / this far, lime = now / done; frac >= 0 draws the progress as a lime arc.
# It hides itself when nothing asks for it (see _ring_finish).
func _make_ring() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	ring_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RING_SHADER
	ring_mat.shader = sh
	ring_mat.render_priority = 100
	ring_mi = MeshInstance3D.new()
	ring_mi.name = "VRBootRing"
	ring_mi.mesh = q
	ring_mi.material_override = ring_mat
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_mi.visible = false
	fx_root.add_child(ring_mi)

# (the round markers are gone since iteration 26: the "[ ]" frames are the only highlight; the callers stay as they are)
func _ring_show(_at: Vector3, _frac: float, _hot: bool, _radius_m: float) -> void:
	return

func _ring_finish() -> void:
	if ring_mi != null and not ring_used:
		ring_mi.visible = false
	ring_used = false

# (iteration 34) Tutorial words are shown the first time a tool is used, never again after it has been done once.
func _tut_load() -> void:
	tut_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(TUT_PATH) == OK:
		for k in cfg.get_section_keys("seen"):
			tut_seen[k] = true
		tut_enabled = bool(cfg.get_value("tut", "on", true))
	if _tut_all_seen():
		tut_enabled = false

func _tut_all_seen() -> bool:
	for k in TUT_KEYS:
		if not tut_seen.has(k):
			return false
	return true

func _tut_save() -> void:
	var cfg := ConfigFile.new()
	for k in tut_seen:
		cfg.set_value("seen", str(k), true)
	cfg.set_value("tut", "on", tut_enabled)
	cfg.save(TUT_PATH)

# The check box on the bathroom sign: tutorial words on again (every one is shown once more) or off.
func _tut_set(on: bool) -> void:
	if not tut_loaded:
		_tut_load()
	tut_enabled = on
	if on:
		tut_seen.clear()
	_tut_save()
	print("VRBoot: tutorial messages ", "on (all of them will show once more)" if on else "off")

func _tut_toggle() -> void:
	if not tut_loaded:
		_tut_load()
	_tut_set(not tut_enabled)

func _tut_new(key: String) -> bool:
	if not tut_loaded:
		_tut_load()
	return tut_enabled and not tut_seen.has(key)

func _hint_tut(key: String, text: String, at: Vector3, size_k := 1.0) -> void:
	if _tut_new(key):
		_hint_show(text, at, true, size_k)

func _tut_done(key: String) -> void:
	if not _tut_new(key):
		return
	tut_seen[key] = true
	if _tut_all_seen():
		tut_enabled = false                           # (iteration 36) the check box turns itself off once all of them have been played
	_tut_save()
	print("VRBoot: tutorial words '", key, "' shown once - not shown again")

# Show the hint for this frame (white = how, lime = "now"). It hides itself when nothing asks for it.
func _hint_show(text: String, at: Vector3, lime: bool, size_k := 1.0) -> void:
	if hint_label == null:
		return
	hint_used = true
	hint_label.visible = true
	hint_label.scale = Vector3.ONE * world_scale * size_k
	hint_label.global_position = at
	hint_label.text = text
	hint_label.modulate = UI_LIME if lime else Color(1, 1, 1)

func _hint_finish() -> void:
	if hint_label != null and not hint_used:
		hint_label.visible = false
	hint_used = false
