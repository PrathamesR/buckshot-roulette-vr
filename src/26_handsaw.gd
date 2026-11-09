# Handsaw item
# (Part of the Buckshot Roulette VR mod. Chain position 26: this file extends 25_display.gd; see src/README.md.)
extends "25_display.gd"

const SAW_BLADE_OPEN := 2.649                      # the game's own "use handsaw" animation: the blade swings out to this (rotation y)

const SAW_SND_LOOP_A := 1.0                        # the saw sound (a part of the game's clip): this part is the sawing, repeated...

const SAW_SND_LOOP_B := 1.75

const SAW_SND_END := 1.8                           # ...and from here the clip is the cut-through and the piece dropping

const SAW_NEAR_M := 0.05                           # the saw this close to the end of the barrel

const SAW_STROKE_M := 0.8                          # real metres of sawing needed

var saw_blade: Node3D = null

var saw_open := false

var saw_open_t := 0.0

var saw_rest := 0.0

var saw_idle := 0.0

func _saw_segment() -> Node:
	if gun_main == null or not is_instance_valid(gun_main):
		return null
	var s := gun_main.find_child("shotgun cut segment", true, false)
	if s is Node3D:
		if gun_state == 0 and (s as Node3D).is_visible_in_tree():
			return s
		if _gun_held_free() and _vis_between(s, gun_main):
			return s                                   # (its copy on the gun in your hand shows it)
	return null

func _saw_blade_ready(par: Node3D) -> bool:
	if saw_blade != null and is_instance_valid(saw_blade) and saw_blade.get_parent() == par:
		return true
	var b := par.get_node_or_null("handsaw blade") as Node3D
	if b == null:
		return false
	saw_blade = b
	saw_rest = b.rotation.y
	saw_open = false
	saw_open_t = 0.0
	saw_idle = 0.0
	return true

func _saw_reset() -> void:
	if saw_blade != null and is_instance_valid(saw_blade):
		saw_blade.rotation.y = saw_rest
	saw_blade = null
	saw_open = false
	saw_open_t = 0.0
	saw_idle = 0.0

func _rit_saw_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var seg := _saw_segment()
	if seg == null or not (gun_state == 0 or _gun_held_free()):
		return 2
	if _saw_blade_ready(par):
		if not saw_open:
			# a folding blade: flick the cutter open (as the game's own animation does) before you can cut
			if item_t >= FLICK_HOLD_S and _flicked(hh):
				saw_open = true
				saw_open_t = 0.0
				rit_prev = _item_ref(par)
				rit_stroke = 0.0
				hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.08, 0.0)
				var ap := _fx_play(_anim_stream("player use handsaw", "handsaw"), -4.0)
				if ap != null:
					get_tree().create_timer(0.7).timeout.connect(func():
						if is_instance_valid(ap):
							ap.stop()
							ap.queue_free())
				print("VRBoot: cutter flicked open")
		if saw_open and saw_open_t < 0.2:
			saw_open_t += delta
			saw_blade.rotation.y = lerpf(saw_rest, SAW_BLADE_OPEN, smoothstep(0.0, 0.12, saw_open_t))
		if not saw_open:
			rit_prev = _item_ref(par)                  # (the strokes are counted from the moment it is open)
			return 0
	var ws := world_scale
	var ref := _item_ref(par)
	var segbox := _gun_part_box(seg)
	if segbox.size.x < 0.0:
		return 2
	var tip := segbox.get_center()
	var ibox := _node_world_aabb(par, true)
	var near := ibox.size.x >= 0.0 and _point_box_dist(tip, ibox) <= SAW_NEAR_M * ws
	var axis := (par.global_transform.basis * Vector3(1.0, 0.0, 0.0)).normalized()
	var mv := absf((ref - rit_prev).dot(axis))
	rit_prev = ref
	var sawing := near and hh.grip_sq and mv > 0.0008 * ws
	if near:
		poke_boxes.append(segbox)
	if sawing:
		rit_stroke += mv / ws
		rit_haptic_t -= delta
		if rit_haptic_t <= 0.0:
			rit_haptic_t = 0.06
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.28, 0.05, 0.0)
		saw_idle = 0.0
		if rit_snd == null or not is_instance_valid(rit_snd) or not rit_snd.playing:
			# only the sawing part of the game's clip, repeated: its end (the cut-through and the piece dropping) waits for the cut
			rit_snd = _fx_play(_anim_stream("player use handsaw", "handsaw"), -2.0, SAW_SND_LOOP_A)
		elif rit_snd.get_playback_position() >= SAW_SND_LOOP_B:
			rit_snd.seek(SAW_SND_LOOP_A)
	elif rit_snd != null and is_instance_valid(rit_snd):
		saw_idle += delta
		if saw_idle > 0.2 or not near:
			rit_snd.stop()
			rit_snd.queue_free()
			rit_snd = null
	if rit_stroke > 0.01:
		_ring_show(tip + Vector3.UP * (0.10 * ws), clampf(rit_stroke / SAW_STROKE_M, 0.0, 1.0), sawing, 0.05)
	else:
		_ring_show(tip + Vector3.UP * (0.10 * ws), -1.0, near, 0.05)
	if rit_stroke < SAW_STROKE_M:
		return 0
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	var sm := seg.get_node_or_null("segment manager")
	if rm == null or sm == null:
		return 2
	var piece := _fx_clone_gun_part(seg as Node3D) if _gun_held_free() else _fx_clone_visual(seg as Node3D)     # (made before the game fades its own piece out)
	for c in piece.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m is StandardMaterial3D:
					var d: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
					d.albedo_color.a = 1.0
					mi.set_surface_override_material(i, d)
	sm.call("HideSegment")
	rm.set("barrelSawedOff", true)
	rm.set("currentShotgunDamage", 2)
	var down := (_gun_xf().basis * Vector3(1.0, 0.0, 0.0)).normalized()
	_fx_fall(piece, down * 0.25 * ws + Vector3.UP * 0.3 * ws, Vector3(3.0, 1.0, 5.0), gun_main.global_position.y - 0.04, 1.8)
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.9, 0.15, 0.0)
	_fx_play(_anim_stream("player use handsaw", "handsaw"), -2.0, SAW_SND_END)     # the cut-through and the piece dropping: now
	if not _titem_consume(par, "handsaw"):
		return 2
	_titem_end(false, "sawed")
	get_tree().create_timer(1.0).timeout.connect(_perm_back)
	print("VRBoot: barrel sawed off by hand")
	return 1
