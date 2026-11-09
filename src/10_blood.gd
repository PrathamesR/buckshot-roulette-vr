# Blood splash after a hit
# (Part of the Buckshot Roulette VR mod. Chain position 10: this file extends 09_fx.gd; see src/README.md.)
extends "09_fx.gd"

const SPLAT_DIST_M := 0.30                         # the blood layer (a red edge vignette) hangs this far (real metres) in front of your face...

const BLOOD_S := 3.4                               # the red edge of your view ebbs away over this long after the hit

const BLOOD_RISE_S := 0.10                         # ...and comes up in this long

const SPLAT_REACH := 3.8                           # ...and is this many times its distance wide and high (covers any headset's view)

const SPLAT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_test_disabled, depth_draw_never;
uniform float amount = 0.0;      // 0 = nothing, 1 = the strongest moment
uniform float age = 0.0;         // seconds since the hit
uniform float seed = 1.0;
uniform float reach = 7.6;       // the layer's width and height in its own units (tan of the viewing angle at its middle)
uniform vec2 grav = vec2(0.0, -1.0);     // where "down" is on the layer (x = your right, y = your up)

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.x, p.y, p.x) * 0.1031);
	float d = dot(p3, p3.yzx + 33.33);
	p3 += d;
	return fract((p3.x + p3.y) * p3.z);
}
vec2 h22(vec2 p) {
	vec3 p3 = fract(vec3(p.x * 0.1031, p.y * 0.1030, p.x * 0.0973));
	float d = dot(p3, p3.yzx + 33.33);
	p3 += d;
	return fract(vec2((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y));
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float e = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

// What VR games do instead of covering the view: the edges of the view turn red and the red creeps in and ebbs away. The
// middle of your view stays clear all the time. The rim is ragged (noise) and a few drops cling to it and run down.
void fragment() {
	if (amount <= 0.003) {
		discard;
	}
	vec2 q = vec2(UV.x - 0.5, 0.5 - UV.y) * reach;
	vec2 down = normalize(grav);
	float r = length(q);
	float n = 0.6 * vnoise(q * 2.1 + vec2(seed, seed * 0.7)) + 0.4 * vnoise(q * 5.3 - vec2(seed * 1.3, seed));
	float inner = mix(1.55, 0.78, amount);              // where the red begins (tan of the angle off the middle of your view)
	float soft = 0.55 + 0.35 * amount;
	float rim = smoothstep(inner + (n - 0.5) * 0.5, inner + soft + (n - 0.5) * 0.5, r);
	// drops on the rim, running down while it lasts
	float drops = 0.0;
	float cell = 0.30;
	vec2 g = floor(q / cell);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = g + vec2(float(i), float(j));
			vec2 rr = h22(id + vec2(seed, seed * 1.7));
			vec2 c = (id + 0.2 + 0.6 * rr) * cell;
			if (length(c) < inner + 0.1 || rr.x < 0.78) {
				continue;
			}
			float rad = (0.03 + 0.07 * h21(id * 1.7 + seed)) * (0.55 + 0.6 * amount);
			vec2 d = q - c;
			float al = dot(d, down);                 // > 0: further down than the drop's middle
			float ac = dot(d, vec2(-down.y, down.x));
			float tail_len = min(rad * (1.6 + 3.2 * age / (age + 2.0)) * (0.6 + h21(id)), 0.26);
			float tpos = -al / tail_len;             // 0 at the drop, 1 at the end of its streak (above it)
			float tw = rad * 0.45 * (1.0 - clamp(tpos, 0.0, 1.0));
			float tail = step(0.0, tpos) * (1.0 - smoothstep(0.85, 1.0, tpos)) * (1.0 - smoothstep(tw * 0.6, tw, abs(ac)));
			float head = 1.0 - smoothstep(0.7, 1.0, length(d) / rad);
			drops = max(drops, max(head, tail));
		}
	}
	float cov = max(rim * 0.9, drops * 0.95);
	float k = clamp(0.35 + 0.65 * rim + 0.2 * (n - 0.5), 0.0, 1.0);
	vec3 col = mix(vec3(0.42, 0.0, 0.03), vec3(0.92, 0.1, 0.13), k * 0.8);
	col = mix(col, vec3(0.28, 0.0, 0.02), clamp(r * 0.12, 0.0, 0.5));
	ALBEDO = col;
	ALPHA = cov * clamp(amount * 1.4, 0.0, 1.0);
}
"""

var splat_active := false

var splat_hp := -1                  # your health last frame (the red edge comes when it drops)

var splat_grav := Vector2(0.0, -1.0)

var splat_t0 := 0.0

var splat_mi: MeshInstance3D = null     # our blood: a shader that draws the spray, splats and drips sharply, on your visor

var splat_mat: ShaderMaterial = null

var splat_seed := 1.0

# How strong the red edge is, age seconds after the hit: it snaps up, throbs twice with the heartbeat, and ebbs away.
func _blood_amount(age: float) -> float:
	if age < 0.0 or age >= BLOOD_S:
		return 0.0
	var rise := smoothstep(0.0, BLOOD_RISE_S, age)
	var beat := 0.86 + 0.14 * cos(age * 9.0)
	var ebb := 1.0 - smoothstep(0.3, BLOOD_S, age)
	return rise * beat * ebb

# ------------------------------------------------------------------ the blood on your visor
# The game's blood is four 1080p pictures on a plane in front of ITS camera; stretched over a headset's view they looked
# blocky and odd. We keep the game's timing (its own "fade out" animation drives the plane's transparency 0 -> 1 over 2 s,
# started by the game when the dealer is killed) and draw the blood ourselves: a shader paints round splats with drips and
# a fine spray, sharp at any size, spreading out from the front over a fraction of a second. It sits on your visor: both
# eyes see it in the same place.
func _splat_begin(why: String) -> void:
	if splat_mat == null:
		return
	if splat_active and t_alive - splat_t0 < 0.6:
		return                                 # (the same hit, seen twice)
	splat_seed = float(randi() % 997) * 0.37 + 1.0
	splat_mat.set_shader_parameter("seed", splat_seed)
	splat_t0 = t_alive
	splat_active = true
	for hb in [left_hand, right_hand]:
		if (hb as Hand).was_active:
			(hb as Hand).grip.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.18, 0.0)      # the thump of a hit
	print("VRBoot: blood splash (red edge of the view) - ", why)

# The game only splashes blood when the dealer's last life goes. You get the red edge whenever YOU lose health too
# (a live shell from the dealer or from yourself).
func _splat_health_watch() -> void:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	var rm = ii.get("roundManager") if ii != null and is_instance_valid(ii) else null
	var hp = rm.get("health_player") if rm != null and is_instance_valid(rm) else null
	if hp == null:
		splat_hp = -1
		return
	var h := int(hp)
	if splat_hp >= 0 and h < splat_hp:
		_splat_begin("you lost health (" + str(splat_hp) + " -> " + str(h) + ")")
	splat_hp = h

func _update_splat() -> void:
	if not _in_main_scene() or xr_cam == null or not is_instance_valid(xr_cam) or cur_scene == null:
		splat_active = false
		if splat_mi != null and is_instance_valid(splat_mi):
			splat_mi.visible = false
		return
	if splat == null or not is_instance_valid(splat):
		splat = null
		if t_alive < splat_search_t:
			return
		splat_search_t = t_alive + 1.0
		var n := cur_scene.find_child("blood splatter plane", true, false)
		if not (n is GeometryInstance3D):
			return
		splat = n
		splat.layers = 0                   # the game's own picture is not drawn any more (it only tells us when the shot hit)
		splat_prev = 1.0
		print("VRBoot: blood layer found (", splat.get_path(), "): drawn by our own shader now")
	var tr := clampf(float(splat.get("transparency")), 0.0, 1.0)
	if splat_mi == null or not is_instance_valid(splat_mi):
		var sh := Shader.new()
		sh.code = SPLAT_SHADER
		splat_mat = ShaderMaterial.new()
		splat_mat.shader = sh
		splat_mat.render_priority = 100
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 2.0)
		splat_mi = MeshInstance3D.new()
		splat_mi.name = "VRBootBlood"
		splat_mi.mesh = quad
		splat_mi.material_override = splat_mat
		splat_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		splat_mi.extra_cull_margin = 4096.0
		fx_root.add_child(splat_mi)
	if tr < splat_prev - 0.02:
		# a new splash (the game's blood layer jumped from gone to there): ours starts, and runs on its own clock for longer
		_splat_begin("the game's blood")
	splat_prev = tr
	_splat_health_watch()
	if not splat_active:
		splat_mi.visible = false
		return
	var age := t_alive - splat_t0
	var life := _blood_amount(age)
	if age >= BLOOD_S or (age > BLOOD_RISE_S and life <= 0.004):     # (at age 0 the red edge has not risen yet: that is not the end)
		splat_active = false
		splat_mi.visible = false
		return
	var d := SPLAT_DIST_M * world_scale
	var cb: Basis = xr_cam.global_transform.basis.orthonormalized()
	var gl := cb.transposed() * Vector3.DOWN                  # which way is down, seen from your head
	var gv := Vector2(gl.x, gl.y)
	if gv.length() > 0.2:
		splat_grav = gv.normalized()
	splat_mat.set_shader_parameter("amount", life)
	splat_mat.set_shader_parameter("age", age)
	splat_mat.set_shader_parameter("reach", SPLAT_REACH * 2.0)
	splat_mat.set_shader_parameter("grav", splat_grav)
	var s := d * SPLAT_REACH
	splat_mi.visible = true
	splat_mi.global_transform = Transform3D(Basis(cb.x * s, cb.y * s, cb.z), xr_cam.global_position - cb.z * d)


# ------------------------------------------------------------------ the shotgun by hand
# Take it: squeeze the grip with a hand next to it (or click it with the laser - the game's grab is the same).
# Aim it at the dealer (straight ahead) or at yourself (muzzle toward your head), hold steady, pull the trigger.
# The shot itself is the game's own (InteractWith "text dealer" / "text you"), so every rule stays.
