# Bathroom: intro, CRT, TV
# (Part of the Buckshot Roulette VR mod. Chain position 05: this file extends 04_cigarette.gd; see src/README.md.)
extends "04_cigarette.gd"

var tv_t := 0.0

func _intro() -> Node:
	if interaction == null or not is_instance_valid(interaction):
		return null
	var i = interaction.get("intro")
	if i is Node and is_instance_valid(i):
		return i
	return null

func _crt() -> Node:
	var intro := _intro()
	if intro == null:
		return null
	var c = intro.get("crtManager")
	if c is Node and is_instance_valid(c):
		return c
	return null

# The game would slide the camera over to the TV and start it there. We leave the camera alone and start
# the TV where it stands: same start-up, same buttons, no movement.
func _tv_open() -> void:
	var intro := _intro()
	var crt := _crt()
	if intro == null or crt == null or tv_state != 0 or bath_left or pill_busy:
		return
	tv_state = 1
	tv_t = 0.0
	tv_close_pending = false
	var br = intro.get("intbranch_crt")
	if br is Node:
		br.set("interactionAllowed", false)
	var scr = intro.get("btn_screen")
	if scr is CanvasItem:
		scr.visible = false
	var loop = crt.get("speaker_bootuploop")
	if loop is Node:
		loop.call("play")
	crt.call("Bootup")
	print("VRBoot: TV switched on (no camera move)")

# X on the TV, B / Y, leaving the bathroom or swallowing the pill: the picture goes off.
func _tv_close(from_button: bool) -> void:
	if tv_state == 0:
		return
	if tv_state == 1:
		tv_close_pending = true       # the start-up cannot be stopped half way: it is switched off when it ends
		return
	tv_state = 0
	tv_close_pending = false
	var intro := _intro()
	var crt := _crt()
	if intro == null or crt == null:
		return
	crt.set("has_exited", true)
	crt.set("viewing", false)
	if from_button:
		var be = crt.get("branch_exit")
		if be is Node and is_instance_valid(be) and be.get_parent() != null and be.get_parent().get_child_count() > 1:
			var btn: Node = be.get_parent().get_child(1)
			if btn.has_method("Press"):
				btn.call("Press")
		var sp = crt.get("speaker_buttonpress")
		if sp is Node:
			sp.call("play")
	var board = crt.get("board")
	if board is Node:
		board.call("TurnOffDisplay")
	var bts = intro.get("intbs_crtbuttons")
	if bts is Array:
		for b in bts:
			if b is Node and is_instance_valid(b):
				b.set("interactionAllowed", false)
	var ex = crt.get("exit")
	if ex is Node:
		ex.set("exitAllowed", true)
	if not bath_left and not pill_busy:
		var br = intro.get("intbranch_crt")
		if br is Node:
			br.set("interactionAllowed", true)
		var scr = intro.get("btn_screen")
		if scr is CanvasItem:
			scr.visible = true
	print("VRBoot: TV switched off")

func _update_tv(delta: float) -> void:
	if tv_state == 0:
		return
	var crt := _crt()
	if crt == null or not _in_main_scene():
		tv_state = 0
		return
	if tv_state == 1:
		tv_t += delta
		if bool(crt.get("viewing")):
			tv_state = 2
			print("VRBoot: TV ready - its buttons work")
			if tv_close_pending:
				_tv_close(false)
	elif not bool(crt.get("viewing")):
		tv_state = 0
