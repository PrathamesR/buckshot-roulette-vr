# Items on the table: take, carry, drop, hold pose, dealer hand shape
# (Part of the Buckshot Roulette VR mod. Chain position 33: this file extends 32_doors.gd; see src/README.md.)
extends "32_doors.gd"

const INV_HOLD_K := 0.62                           # (iteration 37) the inverter (and with it the hand shape that holds it) is shown this much smaller in the hand

const ITEM_GRAB_M := 0.12                          # a hand this close (real metres) to the item box, with the grip squeezed, takes an item out

const ITEM_MIN_CARRY_S := 0.6                      # an item cannot be let go of before the game has set up its slots

const ITEM_FIST_HOLE := Vector3(-0.005, -0.007, -0.035)   # where the closed fist is, from the controller's grip point (real metres, right hand; x mirrored for the left)

const ITEM_BLEND_S := 0.18                         # an item glides into the fist in this time

const ITEM_HOLD_DEFAULT := [Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), Vector3(0, 1, 0)]

# How each item sits in the fist: [where the hand holds it (fractions of the item's box), the item's own axis that points
# forward, the item's own axis that runs along the fist (up)]. Box items and table items alike.
const ITEM_HOLD := {
	"beer": [Vector3(0.5, 0.40, 0.5), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	"cigarettes": [Vector3(0.5, 0.5, 0.6), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	"expired medicine": [Vector3(0.5, 0.5, 0.5), Vector3(-1, 0, 0), Vector3(0, 0, 1)],
	"burner phone": [Vector3(0.70, 0.75, 0.5), Vector3(0, 0, 1), Vector3(-1, 0, 0)],
	"handsaw": [Vector3(0.82, 0.5, 0.5), Vector3(-1, 0, 0), Vector3(0, 0, 1)],
	"magnifying glass": [Vector3(0.5, 0.13, 0.5), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	"handcuffs": [Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	"adrenaline": [Vector3(0.55, 0.5, 0.5), Vector3(0, 0, 1), Vector3(1, 0, 0)],
	"inverter": [Vector3(0.5, 0.5, 0.5), Vector3(1, 0, 0), Vector3(0, 0, 1)]}

# (iteration 33/34) the dealer's own hand shapes for the inverter and the burner phone (his `dealer hand left_inverter` and
# `dealer hand right_phone` meshes, borrowed at run time). Numbers worked out from the game's scene: where the palm is on that
# mesh, how the controller's axes lie on it (mesh: fingers -X, palm -Y, thumb on the Z side), and where the item sits against
# the palm. "base" is the side the mesh is a hand of; the other side gets the mirror image of everything.
const DH_INV_UNIT := 4.41773                       # the hand mesh's units per inverter unit

const DH_INV_P := Vector3(-0.264994, -0.8735, 1.848805)   # the palm's middle (hand mesh space) = the controller's grip point

const DH_INV_T := Vector3(0.0, 0.0, 1.0)           # the thumb axis of that mesh (the mirror plane's normal)

const DH_INV_GT := Basis(Vector3(0.0, 0.0, 1.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))   # hand mesh axes -> grip axes (left hand: fingers -Z, thumb up, palm to +X)

const DH_INV_RB := Basis(Vector3(-0.616867, 0.739176, -0.27036), Vector3(0.707702, 0.370591, -0.601515), Vector3(-0.344433, -0.562389, -0.751721))   # inverter axes -> grip axes (left hand)

const DH_INV_GRASP := Vector3(-0.9513, -0.638816, 0.234716)   # the inverter's point that lies in the palm (slid along so that the dial is clear of the hand)

const DH_PH_UNIT := 1.0                            # the phone hand mesh's units per phone unit

const DH_PH_P := Vector3(-0.019474, 0.395918, -0.615603)

const DH_PH_T := Vector3(0.002784, 0.231544, 0.97282)

const DH_PH_GT := Basis(Vector3(0.12772, 0.002784, 0.991806), Vector3(0.964775, 0.231544, -0.124889), Vector3(-0.229995, 0.97282, 0.026887))   # (right hand: fingers -Z, thumb up, palm to -X)

const DH_PH_RB := Basis(Vector3(-0.275139, -0.370197, 0.887273), Vector3(-0.843785, 0.535312, -0.038305), Vector3(-0.460787, -0.759207, -0.459652))

const DH_PH_GRASP := Vector3(-0.244961, -0.540075, 0.188353)

const DH_PH_C := -0.0425                           # the phone's middle plane along its width (z): the mirror for the other hand

const PHONE_HOLD_K := 0.8                          # the phone shrinks to this much of its table size in the hand (the dealer's phone is small next to his hand)

var item_down := {}                 # hand side -> grip was squeezed last frame

var item_name := ""                 # the item in the hand

var item_grasp := Vector3.ZERO      # the point of it (own space) that the fist closes around

var item_rb := Basis.IDENTITY       # its own axes -> the grip's axes

var item_from := Transform3D.IDENTITY   # where it was when taken (it glides from there into the fist)

func _item_nodes() -> Array:
	if interaction == null or not is_instance_valid(interaction) or not _in_main_scene():
		return []
	var im = interaction.get("itemManager")
	if not (im is Node) or not is_instance_valid(im):
		return []
	var br = im.get("interaction_intake")
	if not (br is Node) or not is_instance_valid(br):
		return []
	return [im, br]

func _update_items(delta: float) -> void:
	if pause_open:
		return
	_fx_update(delta)
	var nodes := _item_nodes()
	if nodes.is_empty():
		if adr_tp_on:
			_adr_tp_end("left the game")
		if item_hand != null:
			_item_end("left the game")
		if rit != "":
			_rit_abort("left the game")
		grab_items_ok = false
		return
	var im: Node = nodes[0]
	var intake: Node = nodes[1]
	item_im = im
	_steal_update(im, delta)
	if rit != "":
		grab_items_ok = false
		_rit_tick(delta)
		return
	if item_hand != null:
		grab_items_ok = false
		if item_br != null or item_handoff:
			_titem_carry(im, delta)
		else:
			_item_carry(im, delta)
		return
	var ws := world_scale
	var tavail := mode == "table" and not walk_to_table and not size_active and (gun_state == 0 or _gun_held_free()) and pill_state == 0 \
		and not _items_locked() and not bool(im.get("moving")) and not cuffed
	grab_items_ok = tavail
	var avail := mode == "table" and not walk_to_table and not size_active and (gun_state == 0 or _gun_held_free()) and _allowed(intake) \
		and not _alias_locked("briefcase intake") and int(im.get("numberOfOccupiedGrids")) < 8 and not cuffed
	var box := _branch_world_box(intake, false)
	for h in [left_hand, right_hand]:
		var hh: Hand = h
		var sq: bool = hh.grip_sq
		var edge: bool = sq and not bool(item_down.get(hh.side, false))
		item_down[hh.side] = sq
		if tavail and hh.was_active and not hh.holding and _titem_try_take(hh, im, edge):
			return
		if not avail or not hh.was_active or box.size.x < 0.0 or hh.holding:
			continue
		var reach := hh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
		var d := _point_box_dist(reach, box)
		if d <= ITEM_GRAB_M * 2.5 * ws:
			_pk_flat(box)                              # frame it: an item can be taken here
		if edge and d <= ITEM_GRAB_M * ws:
			_item_take(hh, im, intake)
			return

func _item_take(hh: Hand, im: Node, intake: Node) -> void:
	var before = im.get("activeItem")
	interaction.set("activeInteractionBranch", intake)
	interaction.call("MainInteractionEvent")
	var it = im.get("activeItem")
	if not (it is Node3D) or not is_instance_valid(it) or it == before or not bool(im.get("moving")):
		print("VRBoot: item box - the game did not hand out an item this time")
		return
	im.set("moving", false)                        # the game's glide towards its own "hand" stops: this hand carries it
	item_hand = hh
	item_node = it
	item_t = 0.0
	item_slot = -1
	item_home = (it as Node3D).transform
	var nm := ""
	if it.get_child_count() > 1:
		nm = str(it.get_child(1).get("itemName"))
	_item_hold_begin(it, nm)
	hh.holding = true
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.6, 0.1, 0.0)
	print("VRBoot: took an item out of the box with the ", hh.side, " hand")

func _item_carry(im: Node, delta: float) -> void:
	var hh := item_hand
	var it := item_node
	if it == null or not is_instance_valid(it) or not it.is_inside_tree() or hh == null or not hh.was_active:
		_item_end("lost it")
		return
	if bool(im.get("moving")):
		_item_end("the game moves it now")           # a slot was clicked with the laser
		return
	item_t += delta
	_item_hold_apply(hh, it)
	var slot := _item_nearest_slot(im, it.global_position)
	if slot != item_slot:
		item_slot = slot
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.04, 0.0)
	if slot >= 0:
		var sb := _item_slot_box(im, slot)
		if sb.size.x >= 0.0:
			_pk_flat(sb)                               # the frame shows where it would go
	if item_t >= ITEM_MIN_CARRY_S and not hh.grip_sq and slot >= 0:
		_item_drop(im, slot)

# The free slot nearest to a point (-1 = none).
func _item_nearest_slot(im: Node, p: Vector3) -> int:
	var grids = im.get("gridParentArray")
	var occ = im.get("gridOccupiedArray")
	var off = im.get("activeItem_offset_pos")
	var par = im.get("itemSpawnParent")
	if not (grids is Array) or not (occ is Array) or not (par is Node3D) or not (off is Vector3):
		return -1
	var best := -1
	var best_d := INF
	for i in grids.size():
		if i < occ.size() and bool(occ[i]):
			continue
		var g = grids[i]
		if not (g is Node3D) or not is_instance_valid(g):
			continue
		var d := ((par as Node3D).global_transform * ((g as Node3D).transform.origin + (off as Vector3))).distance_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

func _item_slot_box(im: Node, i: int) -> AABB:
	var out := AABB()
	out.size = Vector3(-1.0, -1.0, -1.0)
	var grids = im.get("gridParentArray")
	if not (grids is Array) or i < 0 or i >= grids.size():
		return out
	var g = grids[i]
	if not (g is Node3D) or not is_instance_valid(g) or (g as Node3D).get_child_count() < 2:
		return out
	var cs = (g as Node3D).get_child(1).get_child(0) if (g as Node3D).get_child(1).get_child_count() > 0 else null
	if not (cs is CollisionShape3D) or (cs as CollisionShape3D).shape == null:
		return out
	var dm := (cs as CollisionShape3D).shape.get_debug_mesh()
	if dm == null:
		return out
	return (cs as CollisionShape3D).global_transform * dm.get_aabb()

func _item_drop(im: Node, slot: int) -> void:
	var hh := item_hand
	im.set("moving", false)
	im.call("PlaceDownItem", slot)
	if hh != null:
		hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.08, 0.0)
	print("VRBoot: item put into slot ", slot)
	_item_end("placed")


# ================================================================ iteration 22
# ---- boxes and held items -------------------------------------------------------------------------------------------

# The item's own box (in the item node's local space).
func _item_local_aabb(par: Node3D) -> AABB:
	var out := AABB()
	out.size = Vector3(-1.0, -1.0, -1.0)
	var inv := par.global_transform.affine_inverse()
	var meshes: Array = []
	if par is MeshInstance3D:
		meshes.append(par)
	_collect_meshes(par, meshes)
	var first := true
	for o in meshes:
		var mi: MeshInstance3D = o
		if mi.mesh == null or not mi.visible:
			continue
		var bb: AABB = (inv * mi.global_transform) * mi.mesh.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out

# The item goes into the hand: the point of the item that a hand holds (ITEM_HOLD) lands in the closed fist, with the item's
# handle along the fist (the grip's Y axis) and its long side forward.
func _item_hold_begin(par: Node3D, iname: String) -> void:
	item_name = iname
	item_from = par.global_transform
	item_scale = par.global_transform.basis.get_scale()
	var bb := _item_local_aabb(par)
	if bb.size.x < 0.0:
		bb = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	item_loc = bb
	var spec: Array = ITEM_HOLD.get(iname, ITEM_HOLD_DEFAULT)
	var fr: Vector3 = spec[0]
	item_grasp = bb.position + bb.size * fr
	var a: Vector3 = (spec[1] as Vector3).normalized()
	var b: Vector3 = (spec[2] as Vector3).normalized()
	dealer_sp = _dealer_spec(iname, item_hand.side) if item_hand != null else {}
	inv_dealer = not dealer_sp.is_empty() and _ensure_dealer_pose(item_hand, iname)
	dealer_key = ("dealer_" + iname) if inv_dealer else ""
	if not inv_dealer:
		dealer_sp = {}
	if inv_dealer and iname == "burner phone":
		item_scale *= PHONE_HOLD_K
	if inv_dealer and iname == "inverter":
		item_scale *= INV_HOLD_K                  # (iteration 37) the hand shape grows with the item: a smaller inverter, a smaller hand
	if iname == "inverter" and item_hand != null and not inv_dealer:
		# the dial is on one flat side of the inverter: that side has to face the other hand (the right hand holds it with the
		# item's +y toward the left, the left hand the other way round)
		var dl := par.get_node_or_null("inverter dial") as MeshInstance3D
		if dl != null and dl.mesh != null:
			var dc: Vector3 = par.global_transform.affine_inverse() * (dl.global_transform * dl.mesh.get_aabb().get_center())
			if (signf(dc.y - bb.get_center().y) > 0.0) == (item_hand.side == "left"):
				b = -b
			# (iteration 32) the fist holds the end of the long side that is farthest from the dial, the rest points forward
			var far_hi := dc.x < bb.get_center().x
			fr.x = 0.88 if far_hi else 0.12
			item_grasp = bb.position + bb.size * fr
			if far_hi:
				a = -a
				b = -b
	if iname == "burner phone" and item_hand != null and item_hand.side == "left":
		a = -a                                   # (iteration 33) the mirror image: the screen faces the palm side of this hand too
	var c: Vector3 = a.cross(b).normalized()
	a = b.cross(c).normalized()
	var local_b := Basis(a, b, c)
	var grip_b := Basis(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0), Vector3(1.0, 0.0, 0.0))
	item_rb = grip_b * local_b.transposed()
	if inv_dealer:
		item_rb = dealer_sp["rb"]
		item_grasp = dealer_sp["grasp"]
	var up := par.get_parent() as Node3D
	item_floor_y = (up.global_transform * item_home.origin).y if up != null else par.global_position.y
	print("VRBoot: item '", iname, "' in the hand: ", (bb.size * item_scale / world_scale).snapped(Vector3.ONE * 0.001), " m")

func _item_hold_xf(hh: Hand) -> Transform3D:
	var hx := hh.grip.global_transform
	var gb := hx.basis.orthonormalized()
	var hole := Vector3.ZERO if inv_dealer else ITEM_FIST_HOLE
	if hh.side == "left":
		hole.x = -hole.x
	var bs := gb * item_rb * Basis.from_scale(item_scale)
	return Transform3D(bs, hx.origin + gb * (hole * world_scale) - bs * item_grasp)

func _item_hold_apply(hh: Hand, par: Node3D) -> void:
	var tgt := _item_hold_xf(hh)
	var u := clampf(item_t / ITEM_BLEND_S, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	par.global_transform = tgt if u >= 1.0 else item_from.interpolate_with(tgt, u)
	if inv_dealer:
		_dealer_follow(hh)

func _dealer_spec(iname: String, side: String) -> Dictionary:
	var sp := {}
	match iname:
		"inverter":
			sp = {"node": "dealer hand left_inverter", "base": "left", "unit": DH_INV_UNIT, "p": DH_INV_P, "t": DH_INV_T, "gt": DH_INV_GT,
				"rb": DH_INV_RB, "grasp": DH_INV_GRASP, "axis": 0, "c": 0.0}
		"burner phone":
			sp = {"node": "dealer hand right_phone", "base": "right", "unit": DH_PH_UNIT, "p": DH_PH_P, "t": DH_PH_T, "gt": DH_PH_GT,
				"rb": DH_PH_RB, "grasp": DH_PH_GRASP, "axis": 2, "c": DH_PH_C}
		_:
			return {}
	sp["mirror"] = side != str(sp["base"])
	if bool(sp["mirror"]):
		var sx := Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		var ax: int = sp["axis"]
		var sv := Vector3.ONE
		sv[ax] = -1.0
		var gt: Basis = sp["gt"]
		var rb: Basis = sp["rb"]
		sp["gt"] = sx * gt * _refl(sp["t"])
		sp["rb"] = sx * rb * Basis.from_scale(sv)
		var g: Vector3 = sp["grasp"]
		g[ax] = 2.0 * float(sp["c"]) - g[ax]
		sp["grasp"] = g
	return sp

# The dealer's hand shape for an item: borrowed from the game's scene (nothing is copied), put on this hand as one more shape.
func _ensure_dealer_pose(hh: Hand, iname: String) -> bool:
	var key := "dealer_" + iname
	if hh.poses.has(key):
		return true
	if cur_scene == null:
		return false
	var sp := _dealer_spec(iname, hh.side)
	if sp.is_empty():
		return false
	var src := cur_scene.find_child(str(sp["node"]), true, false) as MeshInstance3D
	if src == null or src.mesh == null or src.mesh.get_surface_count() == 0:
		return false
	var mesh: Mesh = src.mesh
	var mi := MeshInstance3D.new()
	mi.name = "VRBoot_" + key + "_" + hh.side
	mi.mesh = mesh
	if bool(sp["mirror"]):
		var n: Vector3 = (sp["t"] as Vector3).normalized()
		var p: Vector3 = sp["p"]
		mi.transform = Transform3D(_refl(n), 2.0 * p.dot(n) * n)
	var mat := _make_hand_material(mesh.surface_get_material(0))
	for i in mesh.get_surface_count():
		mi.set_surface_override_material(i, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	hh.visual.add_child(mi)
	hh.poses[key] = mi
	print("VRBoot: the dealer's hand for the ", iname, " is the ", hh.side, " hand's shape for it")
	return true

func _dealer_follow(hh: Hand) -> void:
	if dealer_sp.is_empty():
		return
	var hx := hh.grip.global_transform
	var gb := hx.basis.orthonormalized()
	var k := item_scale.x / float(dealer_sp["unit"])
	var gtb: Basis = dealer_sp["gt"]
	var pp: Vector3 = dealer_sp["p"]
	var bs := gb * gtb * Basis.from_scale(Vector3.ONE * k)
	hh.visual.global_transform = Transform3D(bs, hx.origin - bs * pp)

func _item_ref(par: Node3D) -> Vector3:
	return par.global_transform * item_loc.get_center()


# ---- who gets the squeeze: the nearest thing (the shotgun's own click box is huge, so it is measured to its axis) ------------

# The table item nearest to a point: [node, distance (world units), box]; node null = none.
func _titem_pick(im: Node, reach: Vector3) -> Array:
	var arr = im.get("items_dynamicInteractionArray")
	var best: Node = null
	var best_d := INF
	var best_box := AABB()
	if arr is Array:
		for e in arr:
			if not is_instance_valid(e) or not (e is Node) or not _allowed(e) or str(e.get("itemName")) == "":
				continue
			if not ((e as Node).get_parent() is Node3D) or ((e as Node).get_parent() as Node3D).get_child_count() < 2:
				continue
			if steal_on and not (((e as Node).get_parent() as Node3D).get_child(0).get("isDealerItem") == true):
				continue                               # (while stealing only the dealer's items can be taken)
			var bx := _branch_world_box(e, true)
			if bx.size.x < 0.0:
				continue
			var d := _point_box_dist(reach, bx)
			if d < best_d:
				best_d = d
				best = e
				best_box = _titem_frame(e, bx)
	return [best, best_d, best_box]

# (iteration 36) The frame drawn round the handsaw and the magnifying glass was far too big (it is the game's whole click box):
# it is cut down to the item's own mesh box (a bit of margin), or scaled down when that is not known.
func _titem_frame(e: Node, bx: AABB) -> AABB:
	var nm := str(e.get("itemName"))
	if nm != "handsaw" and nm != "magnifying glass":
		return bx
	var par := e.get_parent() as Node3D
	var ws := world_scale
	var small := AABB()
	var ok := false
	if par != null:
		var lb := _item_local_aabb(par)
		if lb.size.x > 0.0:
			var xf := par.global_transform
			var first := true
			for ix in 2:
				for iy in 2:
					for iz in 2:
						var cp: Vector3 = xf * (lb.position + Vector3(lb.size.x * ix, lb.size.y * iy, lb.size.z * iz))
						if first:
							small = AABB(cp, Vector3.ZERO)
							first = false
						else:
							small = small.expand(cp)
			small = small.grow(0.012 * ws)
			var cut := bx.intersection(small)
			if cut.size.x > 0.0 and cut.size.y > 0.0 and cut.size.z > 0.0 and cut.get_volume() < bx.get_volume() * 0.8:
				return cut
	var c := bx.get_center()
	var s := bx.size * 0.55
	return AABB(c - s * 0.5, s)


# ---- things that fall: the used-up item, glass shards, the shell, the cut-off piece -------------------------------------------

func _item_end(why: String) -> void:
	if item_handoff:
		_titem_end(false, why)          # (iteration 32) the handcuffs are gone to the dealer: the "being taken" flag must not stay on
		return
	if item_br != null:
		_titem_end(true, why)
		return
	if item_hand != null:
		item_hand.holding = false
	item_hand = null
	item_node = null
	item_slot = -1
	print("VRBoot: item carrying ended (", why, ")")
