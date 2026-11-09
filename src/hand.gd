# One VR controller: its nodes and the per-frame state of its buttons, pose and what it holds.
extends RefCounted

var side := ""
var grip: XRController3D
var aim: XRController3D
var visual: Node3D
var laser: MeshInstance3D
var laser_mat: StandardMaterial3D
var was_active := false
var trigger_down := false
var ax_down := false
var by_down := false
var menu_down := false
var stick_click_down := false
var stick_click_ms := -100000
var stick_dir := Vector2i.ZERO
var ray_o := Vector3.ZERO
var ray_d := Vector3(0, 0, -1)
var hover_id := 0
var box_root: Node3D          # the plain placeholder box (hidden once the game's hand is loaded)
var poses := {}               # hand shape name -> MeshInstance3D (open, point, trigger, thumbsup, flip, fist)
var pose := ""                # the shape showing now
var pose_seen := {}
var world_click_sent := false # this trigger pull sent a click to the game (laser clicks are skipped on pressable things)
var grip_sq := false          # grip squeezed (with a little hysteresis)
var thumb_on := false         # the thumb rests on a button or the stick
var touch_ok := false         # this controller reports thumb touch (checked once, after a second or so)
var active_frames := 0
var near_poke := false        # the fingertip is close to something pressable: the hand points by itself
var holding := false          # holding the pill bottle
var pill_down := false        # grip / trigger was squeezed last frame (a pick-up needs a fresh squeeze)
var by_swallow := false       # this B / Y press was used to close the TV or the pause menu
var tip_local := Vector3(0.0267, 0.0181, -0.1363)   # index fingertip in the grip frame (metres)
