# Name machine guard and lowering
# (Part of the Buckshot Roulette VR mod. Chain position 13: this file extends 12_gun_shell.gd; see src/README.md.)
extends "12_gun_shell.gd"

const NM_TABLE_GAP_M := 0.035                      # (iteration 34) the name machine comes down to this far (real metres) above the table...

const NM_LOWER_S := 0.7                            # ...in this time

const NM_HIDE_S := 6.0                             # the name machine is hidden for good this long after the name went in (the game's own put-away takes about 3 s)

var nm_wv_y := 0.0                  # (iteration 35) the waiver pivot height, for the log

var nm_table_y := INF              # (iteration 34) the table's height at the name machine (the waiver lies on it)

var nm_base_pos := Vector3.ZERO

var nm_low_total := 0.0            # how far the machine is brought down (world units)

var nm_low_p := -1.0               # 0..1 how far it has come down (-1 = not started)

var nm_low_node: Node3D = null

# ---- the name machine once the game has begun ------------------------------------------------------------------------------
# The game re-arms every key 0.12 s after it was pressed (SignButton.Press). Enter therefore ends up allowed again right after
# the name went in. With the mouse nothing can reach it (its collider is switched off at that moment), but a fingertip measures
# the key's shape itself: you could press the invisible Enter again and the whole sign-off ran a second time (the machine
# came back, the round was set up again - a buggy game). Here: as soon as the name is in (the game hides its key panel) or the
# waiver is already signed, the keys and the waiver are held shut every frame and not offered to the fingertip any more, and a few
# seconds later (after the game's own put-away) the machine and the waiver are hidden for good.
func _nm_dead(n: Node) -> bool:
	return nm_locked and FINGER_ALIASES.has(_alias_of(n))

# (iteration 34) The game brings the name machine (with the paper in it) up close to your face. Here it comes down onto the table
# (just above it) once it has arrived, so that the keys are in reach of the hands lying on the table. The machine's parent is not
# animated by the game, so it is moved there (and stays moved while the machine goes away again).
func _nm_lower(delta: float) -> void:
	var ws := world_scale
	var mp = nm_sign.get("parent_signatureMachineMainParent")
	var an = nm_sign.get("anim_waiver")
	var wv = nm_sign.get("parent_waiver")
	if not (mp is Node3D) or not is_instance_valid(mp):
		return
	var m3 := mp as Node3D
	if nm_low_node != m3:
		nm_low_node = m3
		nm_base_pos = m3.position
		nm_low_p = -1.0
		nm_low_total = 0.0
		nm_table_y = INF
	if nm_table_y == INF and wv is Node3D and is_instance_valid(wv) and (wv as Node3D).is_visible_in_tree() and not m3.visible:
		nm_table_y = (wv as Node3D).global_position.y          # the waiver lies on the table
		nm_wv_y = nm_table_y
		var ts := _table_surface_y()                            # (iteration 35) the table mesh's own surface is the better number
		if not is_nan(ts):
			nm_table_y = ts
	var par := m3.get_parent() as Node3D
	if par == null or not m3.visible or nm_table_y == INF:
		return
	var playing: bool = an is AnimationPlayer and (an as AnimationPlayer).is_playing() and str((an as AnimationPlayer).current_animation) == "pickup waiver"
	if nm_low_p < 0.0:
		if playing:
			return
		var bx := _node_world_aabb(m3, true)
		if bx.size.x < 0.0:
			return
		nm_low_total = clampf((nm_table_y + NM_TABLE_GAP_M * ws) - bx.position.y, -1.5 * ws, 0.0)
		nm_low_p = 0.0
		print("VRBoot: name machine comes down to the table by ", snapped(-nm_low_total / ws, 0.001), " m (table y ", snappedf(nm_table_y, 0.01),
			", waiver pivot y ", snappedf(nm_wv_y, 0.01), ", machine bottom y ", snappedf(bx.position.y, 0.01), ", top y ", snappedf(bx.end.y, 0.01), ")")
	if nm_low_p < 1.0:
		nm_low_p = minf(nm_low_p + delta / NM_LOWER_S, 1.0)
	var e := smoothstep(0.0, 1.0, nm_low_p)
	m3.position = nm_base_pos + par.global_transform.basis.inverse() * Vector3(0.0, nm_low_total * e, 0.0)

func _name_machine_guard(delta: float) -> void:
	if not _in_main_scene() or cur_scene == null:
		return
	if nm_sign == null or not is_instance_valid(nm_sign):
		nm_find_t -= delta
		if nm_find_t > 0.0:
			return
		nm_find_t = 1.0
		nm_sign = cur_scene.find_child("signature manager", true, false)
		nm_vis_seen = false
		nm_locked = false
		nm_hidden = false
		if nm_sign == null:
			return
	_nm_lower(delta)
	var btn = nm_sign.get("btnParent_signature")
	var shown: bool = btn is CanvasItem and is_instance_valid(btn) and (btn as CanvasItem).visible
	if shown:
		nm_vis_seen = true
	if not nm_locked:
		var rm = nm_sign.get("roundManager")
		var pd = rm.get("playerData") if rm != null else null
		var signed: bool = pd != null and bool(pd.get("hasSignedWaiver"))
		if not (signed or (nm_vis_seen and not shown)):
			return
		nm_locked = true
		nm_lock_t = 0.0
		nm_hidden = false
		print("VRBoot: name machine: the name is in - its keys and the waiver are shut for good")
	nm_lock_t += delta
	var arr = nm_sign.get("intbranches")
	if arr is Array:
		for b in arr:
			if b is Node and is_instance_valid(b) and bool(b.get("interactionAllowed")):
				b.set("interactionAllowed", false)
	var wb = nm_sign.get("intrbranch_waiver")
	if wb is Node and is_instance_valid(wb) and bool(wb.get("interactionAllowed")):
		wb.set("interactionAllowed", false)
	if nm_lock_t < NM_HIDE_S:
		return
	var hid_any := false
	for k in ["parent_signatureMachineMainParent", "parent_separateWaiver", "parent_waiver"]:
		var nd = nm_sign.get(k)
		if nd is Node3D and is_instance_valid(nd) and (nd as Node3D).visible:
			(nd as Node3D).visible = false
			hid_any = true
	var mp = nm_sign.get("parent_signatureMachineMainParent")
	if mp is Node3D and is_instance_valid(mp):
		var gp = (mp as Node3D).get_parent()
		if gp is Node3D and (gp as Node3D).visible and str(gp.name).begins_with("signature machine"):
			(gp as Node3D).visible = false
			hid_any = true
	if hid_any and not nm_hidden:
		nm_hidden = true
		print("VRBoot: name machine: hidden for good")
