# Doors, bathroom leg kick, club hold
# (Part of the Buckshot Roulette VR mod. Chain position 32: this file extends 31_titem.gd; see src/README.md.)
extends "31_titem.gd"

# The back-room door (iteration 9): you walk up to it, then kick it open where you stand.
const DOOR_CENTER := Vector2(-38.3, 0.26)          # the door (x, z)

const DOOR_REACH_M := 2.6                          # closer than this to be able to open it

const KICK_FROM_S := 2.9                           # the game's "enter back room" walk is skipped up to here

const KICK_CAM := Vector2(-48.9678, 0.0290324)     # where the game's camera stands when its leg starts to kick

const KICK_LEN_UNITS := 12.07                      # how far the game's foot travels from KICK_CAM at its furthest

const KICK_PAST_UNITS := 1.4                       # ... which is this much beyond the middle of the door

const KICK_LEG_ON_S := 3.3                         # the leg is shown between these two moments of that animation

const KICK_LEG_OFF_S := 4.1

# The bathroom door (iteration 13): the same treatment. Numbers come from the game's "camera exit bathroom" animation:
# the camera is at about (-149.8, -0.45) when the foot starts, the foot lands at (-138.47, -1.19) on the door.
const BATH_DOOR_CENTER := Vector2(-138.47, -1.19)  # where the foot lands on the door (x, z)

const BATH_FROM_S := 1.15                          # the game's walk to the door is skipped up to here

const BATH_KICK_CAM := Vector2(-149.775, -0.447)   # where the game's camera stands when its leg starts to kick

const BATH_KICK_LEN_UNITS := 11.33                 # how far the foot travels from BATH_KICK_CAM at its furthest

const BATH_KICK_PAST_UNITS := 0.5                  # ... a little beyond the point on the door, so it connects

const BATH_LEG_ON_S := 1.38

const BATH_LEG_OFF_S := 1.82

const CLUB_HIDE_X := -33.0                         # the lobby disappears once you are this far in (past the doorway)

var kick_door := Vector2.ZERO      # where the kick lands (x, z) and the numbers of the current door

var kick_cam := Vector2.ZERO

var kick_len := 12.0

var kick_past := 1.0

var kick_on_s := 0.0

var kick_off_s := 0.0

var kick_head := Vector2.ZERO

var kick_u := Vector2(1.0, 0.0)

var kick_k := 1.0

var kick_leg_scale := Vector3.ONE

var kick_anim: Animation

var kick_trk_pos := -1

var kick_trk_rot := -1

var kick_audio_t := 0.0

var kick_absorb := 0               # frames in which a jump of the game camera is the skip, not a cut

var leg_next_search := 0.0

var club_array: Array

# 1. The door can only be opened when you stand close to it (the game's own "invalid" state, so the
#    bracket turns red and the click is ignored).
# 2. The game answers a click with a camera walk ("camera enter backroom"). Here you stay where you
#    are: the walk is skipped ahead to just before the kick, the game's leg is drawn kicking at the
#    door from where you stand, and the door flies open with its own sound.
# 3. The lobby stays in view until you have actually walked through the doorway.
func _update_door(_delta: float) -> void:
	if not _in_main_scene() or xr_cam == null or not is_instance_valid(xr_cam):
		return
	var intro := _intro()
	if intro == null:
		return
	var can_walk := stick_walk and regime_big and mode == "follow"
	_bathroom_leg(intro)
	var br = intro.get("intbranch_backroomdoor")
	if br is Node and is_instance_valid(br) and not kick_on:
		var head := xr_cam.global_position
		var far := can_walk and Vector2(head.x - DOOR_CENTER.x, head.z - DOOR_CENTER.y).length() > DOOR_REACH_M * world_scale
		if bool(br.get("interactionInvalid")) != far:
			br.set("interactionInvalid", far)
	var ap = intro.get("animator_camera")
	if ap is AnimationPlayer and is_instance_valid(ap):
		var player := ap as AnimationPlayer
		var cur := player.current_animation if player.is_playing() else ""
		if not kick_on:
			if can_walk and cur == "camera enter backroom":
				_kick_start(intro, player, false)
			elif can_walk and cur == "camera exit bathroom":
				_kick_start(intro, player, true)
		elif cur == ("camera exit bathroom" if kick_bath else "camera enter backroom"):
			_kick_update(player)
		else:
			_kick_end()
	if kick_absorb > 0:
		kick_absorb -= 1
		if game_cam != null and is_instance_valid(game_cam):
			prev_cam_pos = game_cam.global_position
	if club_pending:
		var h := xr_cam.global_position
		if h.x > CLUB_HIDE_X:
			_club_release()

# The game's leg is hidden everywhere (it is clutter at the table) - except while it kicks the bathroom door,
# where you are carried along with the game camera so its path fits you.
func _bathroom_leg(intro: Node) -> void:
	var want := false
	var ap = intro.get("animator_camera")
	if ap is AnimationPlayer and is_instance_valid(ap):
		var pl := ap as AnimationPlayer
		if pl.is_playing() and pl.current_animation == "camera exit bathroom":
			var t := pl.current_animation_position
			want = t >= 1.3 and t <= 2.4 and not kick_bath
	if orig_leg == null or not is_instance_valid(orig_leg):
		if t_alive < leg_next_search:
			return
		leg_next_search = t_alive + 2.0
		orig_leg = cur_scene.find_child("player leg", true, false) as VisualInstance3D
	if orig_leg == null or want == orig_leg_on:
		return
	orig_leg_on = want
	orig_leg.layers = 1 if want else 0
	if want:
		print("VRBoot: bathroom door kick - leg shown")

func _kick_start(intro: Node, player: AnimationPlayer, bath := false) -> void:
	kick_on = true
	kick_bath = bath
	bath_pending = false
	kick_door = BATH_DOOR_CENTER if bath else DOOR_CENTER
	kick_cam = BATH_KICK_CAM if bath else KICK_CAM
	kick_len = BATH_KICK_LEN_UNITS if bath else KICK_LEN_UNITS
	kick_past = BATH_KICK_PAST_UNITS if bath else KICK_PAST_UNITS
	kick_on_s = BATH_LEG_ON_S if bath else KICK_LEG_ON_S
	kick_off_s = BATH_LEG_OFF_S if bath else KICK_LEG_OFF_S
	hold_for_dealer = true
	hold_t = 0.0
	guard_prints = 0
	_sync_walk_off()
	kick_anim = player.get_animation("camera exit bathroom" if bath else "camera enter backroom")
	kick_trk_pos = -1
	kick_trk_rot = -1
	if kick_anim != null:
		for i in kick_anim.get_track_count():
			var p := str(kick_anim.track_get_path(i))
			if p == "player leg:position":
				kick_trk_pos = i
			elif p == "player leg:rotation":
				kick_trk_rot = i
	var head := xr_cam.global_position
	kick_head = Vector2(head.x, head.z)
	var to := kick_door - kick_head
	var dist := to.length()
	kick_u = to / dist if dist > 0.05 else Vector2(1.0, 0.0)
	kick_k = clampf((dist + kick_past) / kick_len, 0.3, 1.8)
	# a copy of the game's leg that we place and aim ourselves
	var leg := cur_scene.find_child("player leg", true, false) as MeshInstance3D
	if is_instance_valid(kick_leg):
		kick_leg.queue_free()
	kick_leg = null
	if leg != null and leg.mesh != null:
		kick_leg = MeshInstance3D.new()
		kick_leg.name = "VRBootKickLeg"
		kick_leg.mesh = leg.mesh
		kick_leg.material_override = leg.material_override
		for i in leg.mesh.get_surface_count():
			kick_leg.set_surface_override_material(i, leg.get_surface_override_material(i))
		kick_leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kick_leg.visible = false
		kick_leg_scale = leg.scale
		fx_root.add_child(kick_leg)
	if not bath:
		# the lobby must not vanish under your feet when the game starts its round: hold that back
		_club_hold(intro)
	# skip the camera's walk to the door (it would carry the camera, not you)
	var from_s := BATH_FROM_S if bath else KICK_FROM_S
	player.seek(from_s, true)
	if game_cam != null and is_instance_valid(game_cam):
		prev_cam_pos = game_cam.global_position      # that jump is not a "cut" for the follow code
	if not bath and intro.has_method("PanFilter"):
		intro.call("PanFilter")                      # (the bathroom animation does this itself, later on)
	kick_audio_t = t_alive + 0.2
	kick_absorb = 4
	print("VRBoot: kicking the ", "bathroom" if bath else "back-room", " door from ", snappedf(dist, 0.1),
		" units away (stay put, skipped to ", from_s, " s)")

func _kick_update(player: AnimationPlayer) -> void:
	var t := player.current_animation_position
	if kick_audio_t > 0.0 and t_alive >= kick_audio_t:
		kick_audio_t = 0.0
		_kick_audio_check(t)
	if not is_instance_valid(kick_leg) or kick_anim == null or kick_trk_pos < 0 or kick_trk_rot < 0:
		return
	if t < kick_on_s or t > kick_off_s:
		kick_leg.visible = false
		return
	var pos: Vector3 = kick_anim.value_track_interpolate(kick_trk_pos, t)
	var rot: Vector3 = kick_anim.value_track_interpolate(kick_trk_rot, t)
	# the game's leg path is drawn for a camera standing at KICK_CAM and kicking along +X;
	# move it so it starts at YOUR feet and kicks along the line from you to the door
	var rel := Vector2(pos.x - kick_cam.x, pos.z - kick_cam.y)
	var side := Vector2(-kick_u.y, kick_u.x)
	var xz := kick_head + kick_u * (rel.x * kick_k) + side * rel.y
	var b := Basis(Vector3.UP, atan2(-kick_u.y, kick_u.x)) * Basis.from_euler(rot)
	kick_leg.global_transform = Transform3D(b.scaled(kick_leg_scale), Vector3(xz.x, pos.y, xz.y))
	kick_leg.visible = true

# If the game's animation did not start the kick sound where we skipped to, play it ourselves.
func _kick_audio_check(t: float) -> void:
	var sp := cur_scene.get_node_or_null("speaker parent/kick door to lobby") as AudioStreamPlayer2D
	if sp == null or sp.playing:
		return
	var st = load("res://audio/kick door enter lobby.ogg" if kick_bath else "res://audio/kick door enter backroom.ogg")
	if st is AudioStream and t < 5.0:
		sp.stream = st
		sp.play(t)
		print("VRBoot: started the kick sound by hand at ", snappedf(t, 0.01), " s")

func _kick_end() -> void:
	var was_bath := kick_bath
	kick_on = false
	kick_bath = false
	kick_anim = null
	if is_instance_valid(kick_leg):
		kick_leg.queue_free()
	kick_leg = null
	if was_bath:
		# the game's camera has arrived in the lobby; you are still in the bathroom and walk there yourself
		if game_cam != null and is_instance_valid(game_cam):
			anchor_pos = game_cam.global_position
			prev_cam_pos = game_cam.global_position
		hold_for_dealer = false
		_sync_walk_off()
		print("VRBoot: bathroom door done - you stay where you stand (", snappedf(walk_off.length(), 0.1), " units from the lobby start)")

# Keep the game from hiding the lobby when its round starts (BlockoutManager.HideClub empties onto
# the array we clear here); we hide it ourselves once you are through the door.
func _club_hold(intro: Node) -> void:
	var bo = intro.get("blockout")
	if not (bo is Node) or not is_instance_valid(bo):
		return
	var arr = bo.get("objArray_club")
	if not (arr is Array):
		return
	club_nodes.clear()
	for o in arr:
		if o is Node3D and is_instance_valid(o):
			club_nodes.append(o)
	if club_nodes.is_empty():
		return
	club_array = arr
	arr.clear()
	club_pending = true
	print("VRBoot: lobby stays until you step through the door (", club_nodes.size(), " parts held back)")

func _club_release() -> void:
	club_pending = false
	for o in club_nodes:
		if is_instance_valid(o):
			(o as Node3D).visible = false
	for o in club_nodes:
		if is_instance_valid(o):
			club_array.append(o)
	club_nodes.clear()
	print("VRBoot: through the door - lobby hidden")


# ------------------------------------------------------------------ the game's own highlights and body
