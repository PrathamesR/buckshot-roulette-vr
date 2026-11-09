# Forward declarations (stubs) for calls that go up the chain
# (Part of the Buckshot Roulette VR mod. Chain position 01: this file extends 00_core.gd; see src/README.md.)
extends "00_core.gd"

# Forward declarations: functions that an EARLIER module calls but a LATER module defines. A script cannot call
# a function of a script that extends it, so a stub with the same signature stands here; the real one (further
# down the chain) overrides it at run time. Regenerate with tools/split_check.py if you add a cross-module call.

func _laser_wanted() -> bool:
	return false

func _pause_open() -> void:
	pass

func _pause_close() -> void:
	pass

func _game_ts_stop() -> void:
	pass

func _ensure_gun_pose(hh: Hand) -> void:
	pass

func _item_hold_begin(par: Node3D, iname: String) -> void:
	pass

func _item_hold_apply(hh: Hand, par: Node3D) -> void:
	pass

func _item_ref(par: Node3D) -> Vector3:
	return Vector3.ZERO

func _titem_pick(im: Node, reach: Vector3) -> Array:
	return []

func _titem_consume(par: Node3D, iname: String, toss := true) -> bool:
	return false

func _perm_back() -> void:
	pass

func _titem_end(restore: bool, why: String) -> void:
	pass

func _cuffs_retarget(par: Node3D) -> void:
	pass

func _flicked(hh: Hand, thr: float = FLICK_W) -> bool:
	return false

func _gun_part_vis(o: Node) -> bool:
	return false

func _gun_held_free() -> bool:
	return false
