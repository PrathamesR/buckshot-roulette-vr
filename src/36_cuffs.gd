# Handcuffs and the money briefcase
# (Part of the Buckshot Roulette VR mod. Chain position 36: this file extends 35_paper.gd; see src/README.md.)
extends "35_paper.gd"

const BRIEF_REACH_M := 0.45                        # the money briefcase's latches and lid come to this far (real metres) in front of your head

const CUFF_RING_L := Vector3(-0.85, -0.14, 0.82)   # the two bracelets of the game's table handcuffs ("handcuffs player bar" space; estimated from the model)

const CUFF_RING_R := Vector3(1.02, 0.29, -1.08)

const CUFF_POS_A := Vector3(-2.67194, -0.578824, -3.48983)  # the table handcuffs at rest (game animation "check handcuffs", first key)...

const CUFF_POS_B := Vector3(-2.40322, -0.578819, -4.10328)  # ...and yanked (the same animation, second key)

const CUFF_ROT_A := Vector3(0.452717, -1.76437, -0.528809)

const CUFF_ROT_B := Vector3(0.452717, -2.0149, -0.528809)

const CUFF_STILL_M := 0.05                         # a wrist slower than this (real m/s) is resting: the cuffs' reference follows it

const CUFF_RELAX := 2.5                            # ...at this rate (1/s)

const CUFF_PULL_V := 0.06                          # only a hand that moves further out at least this fast (real m/s) buzzes

const CUFF_FREE_M := 0.06                          # a hand may wander this far (real metres) from its bracelet; pulling this far yanks the cuffs fully

const CUFF_BLEND_S := 0.5                          # the hands glide into the bracelets in this time

const CUFF_DEALER_DELTA := Vector3(2.375, -0.5943, -0.2994)  # the dealer's reaching hand minus the cuffs in it (his own animation, game units)

var cuff_node: Node3D = null       # the game's own handcuffs on the table bar: your hands go into them

var cuff_t := 0.0                  # 0 = at rest, 1 = pulled as far as the game's own "check handcuffs" yank

var cuff_rest_ok := false

var cuff_swap := false             # which bracelet goes to which hand (settled when the cuffs go on)

var cuff_blend := 0.0              # the hands glide into the bracelets

var cuff_anch := {}                # per hand: where its wrist was when the cuffs went on (rig space)

var cuff_fist := {}                # hands we closed to a fist for the cuffs

var cuff_buzz2 := 0.0

var brief_end0 := Vector3.ZERO     # where the game's own animation parks the case (kept from the first look)

var brief_t := 0.0

var cuff_prev_w := {}              # each wrist's place last frame (to tell a resting hand from one that pulls)

var cuff_over := {}                # how far past the free range each hand was last frame            # B / Y of the free hand was down last frame (it resets the nudge)

# ---- the dealer takes the handcuffs: his animation starts from where your hand holds them -----------------------------
func _cuffs_retarget(par: Node3D) -> void:
	var ii = interaction.get("itemInteraction") if interaction != null and is_instance_valid(interaction) else null
	if ii == null:
		return
	var an = ii.get("animator_dealerHands")
	if not (an is AnimationPlayer):
		return
	if not (an as AnimationPlayer).has_animation("dealer get handcuffed"):
		return
	var anim: Animation = (an as AnimationPlayer).get_animation("dealer get handcuffed")
	var root := (an as AnimationPlayer).get_node_or_null((an as AnimationPlayer).root_node)
	if anim == null or root == null:
		return
	var ip := -1
	var iv := -1
	var ih := -1
	for i in anim.get_track_count():
		var p := str(anim.track_get_path(i))
		if p.ends_with("handcuffs dealer hand2:position"):
			ip = i
		elif p.ends_with("handcuffs dealer hand2:visible"):
			iv = i
		elif p.ends_with("hand parent_right:position"):
			ih = i
	if ip < 0:
		return
	var node := root.get_node_or_null(NodePath(str(anim.track_get_path(ip)).get_slice(":", 0)))
	if not (node is Node3D) or not ((node as Node3D).get_parent() is Node3D):
		return
	var at := par.global_transform * item_loc.get_center()
	var local: Vector3 = ((node as Node3D).get_parent() as Node3D).global_transform.affine_inverse() * at
	if anim.track_find_key(ip, 0.0, Animation.FIND_MODE_EXACT) < 0:
		anim.track_insert_key(ip, 0.0, local)
	else:
		anim.track_set_key_value(ip, anim.track_find_key(ip, 0.0, Animation.FIND_MODE_EXACT), local)
	for k in anim.track_get_key_count(ip):
		anim.track_set_key_value(ip, k, local)         # (0.6 s: where the game had the cuffs appear out of nowhere, 0.9 s: in his fingers)
	if ih >= 0 and anim.track_get_key_count(ih) >= 3:
		# his right hand reaches (keys at 0.7 s and 1.15 s) to where the cuffs are, plus what his own hand holds them at
		var hand_at: Vector3 = local + CUFF_DEALER_DELTA
		anim.track_set_key_value(ih, 1, hand_at)
		anim.track_set_key_value(ih, 2, hand_at)
	if iv >= 0 and anim.track_get_key_count(iv) >= 1:
		anim.track_set_key_value(iv, 0, true)          # the prop is there from the first moment, in your hand's place

# ---- the money briefcase at the end of the game --------------------------------------------------------------------------------
# The game slides the case onto the middle of the table (far out of reach) and you click its two latches and the lid with the
# laser. Here the end of that slide is moved to where your hands can reach it, and the latches and the lid are touched with a
# fingertip (they are poke targets, see POKE_ALIASES).
func _update_brief(delta: float) -> void:
	brief_t -= delta
	if brief_t > 0.0:
		return
	brief_t = 0.5
	if not _in_main_scene() or cur_scene == null or xr_cam == null or not is_instance_valid(xr_cam) or mode != "table":
		return
	if brief_node == null or not is_instance_valid(brief_node):
		brief_node = cur_scene.find_child("briefcase machine", true, false)
		brief_end0_ok = false
		if brief_node == null:
			brief_t = 2.0
			return
	var bm = brief_node.get("parent_machine")
	var an = brief_node.get("anim_machine")
	if not (bm is Node3D) or not (an is AnimationPlayer):
		return
	if (bm as Node3D).visible or (an as AnimationPlayer).is_playing():
		return                                   # on its way (or here): leave it alone
	_brief_place(bm as Node3D, an as AnimationPlayer)

func _brief_place(bm: Node3D, an: AnimationPlayer) -> void:
	if not an.has_animation("move to table"):
		return
	var anim: Animation = an.get_animation("move to table")
	var ip := -1
	for i in anim.get_track_count():
		if str(anim.track_get_path(i)) == ".:position":
			ip = i
			break
	if ip < 0 or anim.track_get_key_count(ip) < 2:
		return
	var nk := anim.track_get_key_count(ip)
	if not brief_end0_ok:
		brief_end0 = anim.track_get_key_value(ip, nk - 1)
		brief_end0_ok = true
	var c := Vector3.ZERO
	var cnt := 0
	for k in ["intbranch_L", "intbranch_R", "intbranch_lid"]:
		var br = brief_node.get(k)
		if br is Node and is_instance_valid(br):
			var bx := _branch_world_box(br as Node, false)
			if bx.size.x >= 0.0:
				c += bx.get_center()
				cnt += 1
	if cnt < 2:
		return
	c /= float(cnt)
	var dd := _dealer_from_head()
	if dd[0] == Vector3.ZERO:
		return
	var par := bm.get_parent() as Node3D
	var pb := par.global_transform.basis if par != null else Basis.IDENTITY
	var c_end0: Vector3 = c + pb * (brief_end0 - bm.position)     # where those boxes are when the game's own slide ends
	var want: Vector3 = xr_cam.global_position + (dd[0] as Vector3) * (BRIEF_REACH_M * world_scale)
	var shift := Vector3(want.x - c_end0.x, 0.0, want.z - c_end0.z)
	var end_new: Vector3 = brief_end0 + pb.inverse() * shift
	end_new.y = brief_end0.y
	anim.track_set_key_value(ip, nk - 1, end_new)
	if not brief_placed:
		brief_placed = true
		print("VRBoot: money briefcase: its stop is moved to ", snappedf(BRIEF_REACH_M, 0.01), " m in front of you (game had it at ", brief_end0, ")")

# ---- both hands in the game's own handcuffs on the table --------------------------------------------------------------------
# While the game has you cuffed the handcuffs that lie on the table (the game shows them with its own "handcuffs player bar")
# take your hands: each wrist sits in a bracelet. The hands can wander a little around the bracelets; pulling away turns the
# cuffs the way the game's own "check handcuffs" yank does, and beyond that the hands stay in the bracelets with a buzz.
func _cuff_node() -> Node3D:
	if cuff_node != null and is_instance_valid(cuff_node) and cuff_node.is_inside_tree():
		return cuff_node
	cuff_node = null
	if cur_scene != null:
		var n := cur_scene.find_child("handcuffs player bar", true, false)
		if n is Node3D:
			cuff_node = n
	return cuff_node

func _brief_up() -> bool:
	if brief_node == null or not is_instance_valid(brief_node):
		return false
	var bm = brief_node.get("parent_machine")
	return bm is Node3D and is_instance_valid(bm) and (bm as Node3D).visible

func _update_cuffs(delta: float) -> void:
	var on := false
	if interaction != null and is_instance_valid(interaction) and _in_main_scene() and left_hand.was_active and right_hand.was_active:
		var ii = interaction.get("itemInteraction")
		var rm = ii.get("roundManager") if ii != null else null
		if rm != null and bool(rm.get("playerCuffed")):
			on = true
	if on and _brief_up():
		on = false                                     # (iteration 36) the money briefcase is here: the game has the cuffs on, your hands are free for it
	if on != cuffed:
		cuffed = on
		print("VRBoot: your hands are ", "in the handcuffs" if on else "free again")
		cuff_anch.clear()
		cuff_prev_w.clear()
		cuff_over.clear()
		cuff_rest_ok = false
		cuff_blend = 0.0
		cuff_t = 0.0
		if on:
			if item_hand != null:
				_item_end("cuffed")
			for h in [left_hand, right_hand]:
				var hh: Hand = h
				if not hh.holding:
					hh.holding = true                  # a fist, as if clenched
					cuff_fist[hh.side] = true
		else:
			for h in [left_hand, right_hand]:
				var hh: Hand = h
				if bool(cuff_fist.get(hh.side, false)):
					hh.holding = false
			cuff_fist.clear()
	if not on:
		return
	var cn := _cuff_node()
	if cn == null or not cn.visible or origin == null or xr_cam == null or not (cn.get_parent() is Node3D):
		cuff_blend = 0.0                               # (the game has not put them on the table yet)
		return
	var ws := world_scale
	var par := cn.get_parent() as Node3D
	var an := par.get_node_or_null("animator_handcuffs player bar") as AnimationPlayer
	var busy := an != null and an.is_playing() and str(an.current_animation) != "RESET"
	if not cuff_rest_ok:
		var rl: Vector3 = cn.global_transform * CUFF_RING_L
		var rr: Vector3 = cn.global_transform * CUFF_RING_R
		var rgt := xr_cam.global_transform.basis.x
		cuff_swap = (rl - xr_cam.global_position).dot(rgt) > (rr - xr_cam.global_position).dot(rgt)
		cuff_rest_ok = true
	var oinv := origin.global_transform.affine_inverse()
	var wrists := {}
	var offs := {}
	var mean := Vector3.ZERO
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		var wr: Vector3 = hh.grip.global_transform * (Vector3(0.0, 0.0, 0.075) * ws)
		if not cuff_anch.has(hh.side):
			cuff_anch[hh.side] = oinv * wr
		wrists[hh.side] = wr
		var o: Vector3 = wr - origin.global_transform * (cuff_anch[hh.side] as Vector3)
		offs[hh.side] = o
		mean += o * 0.5
	var ax: Vector3 = par.global_transform.basis * (CUFF_POS_B - CUFF_POS_A)
	var dir := ax.normalized() if ax.length() > 0.0001 else Vector3.RIGHT
	var rfree := CUFF_FREE_M * ws
	if not busy:
		var tt := clampf(mean.dot(dir) / rfree, 0.0, 1.0)
		cuff_t = lerpf(cuff_t, tt, 1.0 - exp(-14.0 * delta))
		cn.position = CUFF_POS_A.lerp(CUFF_POS_B, cuff_t)
		cn.rotation = CUFF_ROT_A.lerp(CUFF_ROT_B, cuff_t)
	cuff_blend = minf(cuff_blend + delta / CUFF_BLEND_S, 1.0)
	var k := cuff_blend * cuff_blend * (3.0 - 2.0 * cuff_blend)
	var base_rest: Transform3D = par.global_transform * Transform3D(Basis.from_euler(CUFF_ROT_A) * Basis.from_scale(cn.scale), CUFF_POS_A)
	var pull := 0.0
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		var idx := 0 if hh == left_hand else 1
		if cuff_swap:
			idx = 1 - idx
		var rloc: Vector3 = CUFF_RING_L if idx == 0 else CUFF_RING_R
		var ring_now: Vector3 = cn.global_transform * rloc
		var ring_rest: Vector3 = base_rest * rloc
		var rel: Vector3 = (offs[hh.side] as Vector3) - (ring_now - ring_rest)
		var over := rel.length() - rfree
		var wr_now: Vector3 = wrists[hh.side]
		var wr_prev: Vector3 = cuff_prev_w.get(hh.side, wr_now)
		cuff_prev_w[hh.side] = wr_now
		var wspeed := wr_now.distance_to(wr_prev) / maxf(delta, 0.0001)
		var over_prev := float(cuff_over.get(hh.side, 0.0))
		cuff_over[hh.side] = maxf(over, 0.0)
		if over > 0.0:
			# only a hand that is moving further out is "pulling": one that rests there (or comes to rest) is just in the cuffs
			if (maxf(over, 0.0) - over_prev) / maxf(delta, 0.0001) > CUFF_PULL_V * ws:
				pull = maxf(pull, over / (0.1 * ws))
			rel = rel.normalized() * rfree
		if over > 0.0 and wspeed < CUFF_STILL_M * ws:
			# a hand that rests while it strains: what the cuffs call "where it belongs" slides over to it, so the strain eases off
			# (a hand inside its free range is left alone, so the bar stays where the player turned it)
			var aw: Vector3 = origin.global_transform * (cuff_anch[hh.side] as Vector3)
			aw = aw.lerp(wr_now, 1.0 - exp(-delta * CUFF_RELAX))
			cuff_anch[hh.side] = oinv * aw
		hh.visual.global_position += (ring_now + rel - wr_now) * k
	if pull > 0.0 and k > 0.9:
		cuff_buzz2 -= delta
		if cuff_buzz2 <= 0.0:
			cuff_buzz2 = 0.12
			var amp := clampf(0.15 + 0.45 * pull, 0.15, 0.6)
			left_hand.grip.trigger_haptic_pulse("haptic", 0.0, amp, 0.04, 0.0)
			right_hand.grip.trigger_haptic_pulse("haptic", 0.0, amp, 0.04, 0.0)
