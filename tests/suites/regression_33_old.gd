extends SceneTree
const M = preload("@MOCKS@/mocks22.gd")
var vb
var inter
func mk_box_branch(parent: Node, alias: String, size: Vector3) -> Node:
	var b = load("@MOCKS@/mock_branch2.gd").new()
	b.interactionAlias = alias
	parent.add_child(b)
	var bd := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
	bx.size = size; cs.shape = bx; bd.add_child(cs); parent.add_child(bd)
	return b
func mk_item(spawn: Node3D, nm: String, pos: Vector3, msize: Vector3, moff: Vector3):
	var par := MeshInstance3D.new(); spawn.add_child(par); par.position = pos
	var ind = load("@MOCKS@/mock_ind.gd").new(); par.add_child(ind)
	var b = mk_box_branch(par, "item", Vector3(1.0, 1.0, 1.0))
	b.itemName = nm
	var vis := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = msize; vis.mesh = bm; vis.position = moff; par.add_child(vis)
	return [par, b]
func _initialize():
	vb = load("@MOD@").new()
	root.add_child(vb); vb.set_process(false); vb.set_physics_process(false)
	vb.fx_root = Node3D.new(); root.add_child(vb.fx_root)
	vb._make_gun_label(); vb._make_hint_label(); vb._make_ring()
	vb.origin = XROrigin3D.new(); vb.xr_cam = XRCamera3D.new(); vb.origin.add_child(vb.xr_cam); root.add_child(vb.origin)
	vb.dot = MeshInstance3D.new(); vb.blackout = MeshInstance3D.new(); vb.vignette = MeshInstance3D.new()
	root.add_child(vb.dot); root.add_child(vb.blackout); root.add_child(vb.vignette)
	vb.left_hand = vb._make_hand("left", Color.BLUE)
	vb.right_hand = vb._make_hand("right", Color.RED)
	var scene := Node3D.new(); scene.name = "main"; root.add_child(scene)
	vb.cur_scene = scene
	inter = load("@MOCKS@/mock_inter23.gd").new(); scene.add_child(inter); vb.interaction = inter
	vb.regime_big = true; vb.world_scale = 13.2; vb.mode = "table"; vb.walk_to_table = false
	var ws := 13.2
	for h in [vb.left_hand, vb.right_hand]:
		h.was_active = true; h.holding = false
	vb.xr_cam.global_position = Vector3(0, 2.0, 0)
	# ---- the gun: a long body along Y, a pump, a cut segment
	var gun_main := Node3D.new(); gun_main.name = "shotgun main parent"; scene.add_child(gun_main)
	gun_main.position = Vector3(0, 0.5, -8)
	gun_main.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90)) * Basis.from_scale(Vector3.ONE * 0.9), Vector3(0, 0.5, -8))   # barrel +Y lies along -Z... (model Y -> world -Z)
	var body := MeshInstance3D.new(); body.name = "shotgun parent new"; gun_main.add_child(body)
	var bm := BoxMesh.new(); bm.size = Vector3(0.45, 13.0, 1.2); body.mesh = bm
	var br = mk_box_branch(body, "shotgun", Vector3(40, 40, 40))     # the huge click box
	var col = body.get_child(body.get_child_count() - 1)
	var pump := MeshInstance3D.new(); pump.name = "shotgun-forearm_003"; var pm := BoxMesh.new(); pm.size = Vector3(0.6, 2.0, 0.6); pump.mesh = pm
	body.add_child(pump); pump.position = Vector3(0, 3.08, 0)
	var shp := MeshInstance3D.new(); shp.name = "shell parent"; var shm := BoxMesh.new(); shm.size = Vector3(0.3, 0.8, 0.3); shp.mesh = shm; pump.add_child(shp); shp.visible = false; shp.position = Vector3(0.5, 0, 0)
	var mflash := Node3D.new(); mflash.name = "muzzle flash"; body.add_child(mflash); mflash.position = Vector3(0, 6.6, 0)
	var mfm := MeshInstance3D.new(); mfm.name = "muzzle flash mesh"; var mfq := QuadMesh.new(); mfm.mesh = mfq; mflash.add_child(mfm)
	var seg := MeshInstance3D.new(); seg.name = "shotgun cut segment"; var sm := BoxMesh.new(); sm.size = Vector3(0.4, 1.0, 0.4); seg.mesh = sm
	body.add_child(seg); seg.position = Vector3(0, 6.2, 0)
	var segmgr = M.MockSeg.new(); segmgr.name = "segment manager"; seg.add_child(segmgr)
	var spark := MeshInstance3D.new(); spark.name = "spark"; var spq := QuadMesh.new(); var spm := StandardMaterial3D.new(); spm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; spq.material = spm; spark.mesh = spq; body.add_child(spark)
	var okm := StandardMaterial3D.new(); okm.albedo_color = Color(0.3, 0.3, 0.3); bm.material = okm
	var gh := MeshInstance3D.new(); gh.name = "dealer hand_shotgun right"; gh.mesh = SphereMesh.new(); gh.visible = false; body.add_child(gh)
	var sg = load("@MOCKS@/mock_sg2.gd").new(); scene.add_child(sg)
	sg.collider_shotgun = col
	sg.speaker_live = load("@MOCKS@/mock_speaker.gd").new(); sg.add_child(sg.speaker_live)
	sg.speaker_blank = load("@MOCKS@/mock_speaker.gd").new(); sg.add_child(sg.speaker_blank)
	inter.shotgun = sg
	vb.hint_nodes.append(br)
	# ---- the game's item machinery
	var im = load("@MOCKS@/mock_im.gd").new(); scene.add_child(im)
	var intake = mk_box_branch(Node3D.new(), "briefcase intake", Vector3(1, 1, 1))
	scene.add_child(intake.get_parent()); intake.get_parent().global_position = Vector3(-30, 0, 0)
	im.interaction_intake = intake
	var spawn := Node3D.new(); scene.add_child(spawn); im.itemSpawnParent = spawn
	inter.itemManager = im
	var ii = load("@MOCKS@/mock_ii27.gd").new(); scene.add_child(ii); inter.itemInteraction = ii
	var rm = M.MockRM.new(); scene.add_child(rm); ii.roundManager = rm
	var spw = M.MockSpawner.new(); scene.add_child(spw); rm.shellSpawner = spw
	ii.perm = M.MockPerm.new(); scene.add_child(ii.perm)
	ii.cursor = M.MockCursor.new(); scene.add_child(ii.cursor)
	ii.amounts = M.MockAmounts.new(); scene.add_child(ii.amounts)
	ii.itemManager = M.MockIMgr.new()
	var hcount = M.MockHealth.new(); hcount.name = "health counter"; scene.add_child(hcount)
	for n in ["beer", "magnifying glass", "handsaw", "handcuffs", "cigarettes", "inverter", "expired medicine"]:
		var a = M.MockAmount.new(); a.itemName = n; ii.amounts.array_amounts.append(a)
	# shell machinery
	var holder := MeshInstance3D.new(); holder.name = "shell parent_ejecting player side"; holder.mesh = SphereMesh.new(); scene.add_child(holder)
	var em = M.MockEject.new(); em.name = "shell eject manager"; holder.add_child(em)
	em.shellSpawner = spw; em.mesh = holder; em.animator = AnimationPlayer.new(); holder.add_child(em.animator)
	var lib := AnimationLibrary.new(); lib.add_animation("RESET", Animation.new()); em.animator.add_animation_library("", lib)
	var ex = M.MockExamine.new(); ex.name = "shell examine"; scene.add_child(ex); ex.shellParent = shp
	# dealer hands animation (the handcuffs hand-over)
	var dh_root := Node3D.new(); dh_root.name = "dealer hands root"; scene.add_child(dh_root)
	var dhp := Node3D.new(); dhp.name = "dealer hands parent"; dh_root.add_child(dhp); dhp.position = Vector3(0, 1, -20)
	var cuffprop := Node3D.new(); cuffprop.name = "handcuffs dealer hand2"; dhp.add_child(cuffprop)
	var dan := AnimationPlayer.new(); dh_root.add_child(dan); dan.root_node = NodePath("..")
	var danim := Animation.new(); danim.length = 3.1
	var t5 := danim.add_track(Animation.TYPE_VALUE); danim.track_set_path(t5, NodePath("dealer hands parent/handcuffs dealer hand2:position"))
	danim.track_insert_key(t5, 0.6, Vector3(1, 1, 1)); danim.track_insert_key(t5, 0.9, Vector3(2, 2, 2))
	var t4 := danim.add_track(Animation.TYPE_VALUE); danim.track_set_path(t4, NodePath("dealer hands parent/handcuffs dealer hand2:visible"))
	danim.track_insert_key(t4, 0.0, false); danim.track_insert_key(t4, 0.6, true); danim.track_insert_key(t4, 0.9, false)
	var hpr := Node3D.new(); hpr.name = "hand parent_right"; dhp.add_child(hpr)
	var t2 := danim.add_track(Animation.TYPE_VALUE); danim.track_set_path(t2, NodePath("dealer hands parent/hand parent_right:position"))
	danim.track_insert_key(t2, 0.0, Vector3(-0.03, -0.018, -2.83)); danim.track_insert_key(t2, 0.7, Vector3(-25.03, -0.018, 0.019)); danim.track_insert_key(t2, 1.14667, Vector3(-25.03, -0.018, 0.019))
	danim.track_insert_key(t2, 1.55, Vector3(-7.29, 2.11, -2.0)); danim.track_insert_key(t2, 2.1, Vector3(-0.03, -8.4, -2.83))
	var dlib := AnimationLibrary.new(); dlib.add_animation("dealer get handcuffed", danim); dan.add_animation_library("", dlib)
	ii.animator_dealerHands = dan
	ii.animator_playerHands = AnimationPlayer.new(); scene.add_child(ii.animator_playerHands)
	var cpar := MeshInstance3D.new(); cpar.name = "player cuff bar"; scene.add_child(cpar); cpar.position = Vector3(-6.0, 1.0, -3.0)
	var cbar := MeshInstance3D.new(); cbar.name = "handcuffs player bar"; cpar.add_child(cbar); cbar.position = vb.CUFF_POS_A; cbar.rotation = vb.CUFF_ROT_A; cbar.visible = false
	var can := AnimationPlayer.new(); can.name = "animator_handcuffs player bar"; cpar.add_child(can)
	var clib := AnimationLibrary.new(); clib.add_animation("RESET", Animation.new()); var chk := Animation.new(); chk.length = 1.0; clib.add_animation("check handcuffs", chk); can.add_animation_library("", clib)
	var dealer := Node3D.new(); dealer.name = "dealer model parent"; scene.add_child(dealer); dealer.global_position = Vector3(0, 0, -30)
	# ---- items on the table
	var beer = mk_item(spawn, "beer", Vector3(2.5, 0.0, -4), Vector3(1.45, 2.65, 1.49), Vector3(0, 1.3, 0))
	var mag = mk_item(spawn, "magnifying glass", Vector3(-2.5, 0.0, -4), Vector3(0.3, 3.9, 1.7), Vector3(0, 0.3, 0))
	var saw = mk_item(spawn, "handsaw", Vector3(5.0, 0.0, -4), Vector3(5.2, 0.4, 1.1), Vector3(0.5, 0, 0))
	var cuf = mk_item(spawn, "handcuffs", Vector3(-5.0, 0.0, -4), Vector3(3.0, 0.6, 3.0), Vector3(0, 0, 0))
	im.items_dynamicInteractionArray = [beer[1], mag[1], saw[1], cuf[1]]
	vb.shape_cache.clear()
	vb.gun_state = 0
	var rh = vb.right_hand
	var lh = vb.left_hand
	var reach_off := Vector3(0.0, 0.0, -0.05) * ws
	var put_reach = func(h, wp: Vector3):
		h.grip.global_transform = Transform3D(Basis.IDENTITY, wp - reach_off)
	var step = func(n: int, dt := 0.016):
		for i in n:
			vb.t_alive += dt
			vb.poke_boxes.clear()
			vb._flick_update(dt)
			vb._update_gun(dt)
			vb._update_items(dt)
			vb._update_cuffs(dt)
			vb._hint_finish()
			vb._ring_finish()
	vb.t_alive = 10.0
	vb.item_down.clear(); vb.gun_down.clear()
	step.call(2)
	var medm = load("@MOCKS@/mock_med.gd").new(); scene.add_child(medm); ii.medicine = medm
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_8_BITS; wav.mix_rate = 8000; wav.stereo = false
	var wd := PackedByteArray(); wd.resize(800); wd.fill(128); wav.data = wd
	ii.sound_use_inverter = wav; ii.sound_use_medicine = wav
	var count_players = func():
		var n := 0
		for c in vb.fx_root.get_children():
			if c is AudioStreamPlayer:
				n += 1
		return n
	var free_hands = func():
		rh.grip_sq = false; lh.grip_sq = false
		for i in 6:
			step.call(1)
		vb.item_down.clear(); vb.gun_down.clear(); vb.rit_down.clear()
		rh.holding = false; lh.holding = false
	# ---- X: the inverter: hold it in one hand, turn the dial with the other
	spw.sequenceArray = ["live", "blank", "live"]
	var inv = mk_item(spawn, "inverter", Vector3(2.0, 0.0, -4), Vector3(2.89, 0.35, 1.68), Vector3(0, -0.1, 0))
	var dial := MeshInstance3D.new(); dial.name = "inverter dial"
	var dbm := BoxMesh.new(); dbm.size = Vector3(0.87, 0.39, 0.87); dial.mesh = dbm
	inv[0].add_child(dial); dial.position = Vector3(0.008, 0.186, 0.037)
	im.items_dynamicInteractionArray = [inv[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2)
	step.call(20)
	var gbr: Basis = rh.grip.global_transform.basis
	var dial_c: Vector3 = dial.global_transform * Vector3.ZERO
	var item_c: Vector3 = vb._item_ref(inv[0])
	var dd1: Vector3 = (dial_c - item_c).normalized()
	print("X1 right hand holds the inverter: ", vb.item_br != null and str(vb.item_br.get("itemName")), " dial found=", vb.inv_dial == dial, " (want true) dial faces the other (left) hand: ", snappedf(dd1.dot(-gbr.x), 0.01), " (want > 0.7)")
	rh.grip_sq = false; step.call(6); vb.item_down.clear()
	put_reach.call(lh, Vector3(2.0, 0.5, -4)); lh.grip_sq = false; step.call(3)
	lh.grip_sq = true; step.call(2); step.call(20)
	var gbl: Basis = lh.grip.global_transform.basis
	dial_c = dial.global_transform * Vector3.ZERO
	item_c = vb._item_ref(inv[0])
	dd1 = (dial_c - item_c).normalized()
	print("X2 left hand holds it: ", vb.item_hand == lh, " (want true) dial faces the other (right) hand: ", snappedf(dd1.dot(gbl.x), 0.01), " (want > 0.7)")
	lh.grip_sq = false; step.call(6); vb.item_down.clear()
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	var axis: Vector3 = (dial.get_parent() as Node3D).global_transform.basis.y.normalized()
	var pivot: Vector3 = dial.global_position
	var uu: Vector3 = axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	var vv: Vector3 = axis.cross(uu).normalized()
	var arc_at = func(pv: Vector3, u1: Vector3, v1: Vector3, theta: float, rad_m: float):
		return pv + (u1 * cos(theta) + v1 * sin(theta)) * rad_m * ws
	put_reach.call(lh, arc_at.call(pivot, uu, vv, 0.0, 0.06)); lh.grip_sq = false; step.call(3)
	var dbox: AABB = vb._node_world_aabb(dial, true)
	var framed_i := false
	for pbx in vb.poke_boxes:
		if typeof(pbx) == TYPE_AABB:
			var pb: AABB = pbx
			if pb.is_equal_approx(dbox):
				framed_i = true
	lh.grip_sq = true; step.call(2)
	print("X3 the other hand at the dial: framed=", framed_i, " (want true) taken=", vb.inv_hand == lh, " (want true) that hand holding=", lh.holding, " (want true)")
	var th := 0.0
	for i in 9:
		th += 0.1
		put_reach.call(lh, arc_at.call(pivot, uu, vv, th, 0.06)); step.call(1)
	print("X4 swept ", snappedf(th, 0.1), " rad around the dial: angle=", snappedf(vb.inv_angle, 0.01), " (want 0.9) dial turned by ", snappedf(dial.rotation.y - vb.inv_rest, 0.01), " (want 0.9*pi/1.07) seq untouched=", spw.sequenceArray == ["live", "blank", "live"], " (want true)")
	lh.grip_sq = false; step.call(2)
	var hand_free_i: bool = not lh.holding and vb.inv_hand == null
	step.call(30)
	print("X5 let go early: hand free=", hand_free_i, " (want true) the dial springs back: angle=", snappedf(vb.inv_angle, 0.01), " (want 0) dial.rotation.y=", snappedf(dial.rotation.y - vb.inv_rest, 0.01), " (want 0) still carried=", vb.item_br != null, " (want true)")
	put_reach.call(lh, arc_at.call(pivot, uu, vv, 0.0, 0.06)); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2)
	var rem_i: int = ii.removed
	var am_i: int = ii.amounts.array_amounts[5].amount_player
	var pl0: int = count_players.call()
	var fx0: int = vb.fx_list.size()
	th = 0.0
	for i in 40:
		th += 0.1
		put_reach.call(lh, arc_at.call(pivot, uu, vv, th, 0.06)); step.call(1)
		if vb.item_br == null:
			break
	print("X6 turned past the end after ", snappedf(th, 0.1), " rad: removed=", ii.removed - rem_i, " (want 1) seq=", spw.sequenceArray, " (want [blank, blank, live])  amount ", am_i, " -> ", ii.amounts.array_amounts[5].amount_player, " (want 3 -> 2) sound=", int(count_players.call()) - pl0, " (want 1) tossed=", vb.fx_list.size() - fx0, " (want 1) hands free=", not lh.holding and not rh.holding, " (want true) carried=", vb.item_br != null, " (want false)")
	free_hands.call()
	# the left hand holds one, the right turns the dial the other way round
	var inv2 = mk_item(spawn, "inverter", Vector3(-2.0, 0.0, -4), Vector3(2.89, 0.35, 1.68), Vector3(0, -0.1, 0))
	var dial2 := MeshInstance3D.new(); dial2.name = "inverter dial"; dial2.mesh = dbm
	inv2[0].add_child(dial2); dial2.position = Vector3(0.008, 0.186, 0.037)
	im.items_dynamicInteractionArray = [inv2[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(lh, Vector3(-2.0, 0.5, -4)); lh.grip_sq = false; step.call(3)
	lh.grip_sq = true; step.call(2); step.call(20)
	axis = (dial2.get_parent() as Node3D).global_transform.basis.y.normalized()
	pivot = dial2.global_position
	uu = axis.cross(Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT).normalized()
	vv = axis.cross(uu).normalized()
	put_reach.call(rh, arc_at.call(pivot, uu, vv, 0.0, 0.05)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	var taken2: bool = vb.inv_hand == rh
	th = 0.0
	for i in 40:
		th -= 0.1
		put_reach.call(rh, arc_at.call(pivot, uu, vv, th, 0.05)); step.call(1)
		if vb.item_br == null:
			break
	print("X7 left holds, right turns the other way (", snappedf(th, 0.1), " rad): taken=", taken2, " (want true) seq=", spw.sequenceArray, " (want [live, blank, live]) item gone=", vb.item_br == null, " (want true)")
	free_hands.call()
	# the hand right at the dial: a twist of the hand turns it
	var inv3 = mk_item(spawn, "inverter", Vector3(6.0, 0.0, -2), Vector3(2.89, 0.35, 1.68), Vector3(0, -0.1, 0))
	var dial3 := MeshInstance3D.new(); dial3.name = "inverter dial"; dial3.mesh = dbm
	inv3[0].add_child(dial3); dial3.position = Vector3(0.008, 0.186, 0.037)
	im.items_dynamicInteractionArray = [inv3[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(6.0, 0.5, -2)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	axis = (dial3.get_parent() as Node3D).global_transform.basis.y.normalized()
	pivot = dial3.global_position
	var tw_grip = func(theta: float):
		var rb := Basis(axis, theta)
		lh.grip.global_transform = Transform3D(rb, pivot - rb * reach_off)
	tw_grip.call(0.0); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2)
	var taken3: bool = vb.inv_hand == lh
	th = 0.0
	for i in 9:
		th += 0.1
		tw_grip.call(th); step.call(1)
	var ang_tw: float = vb.inv_angle
	for i in 30:
		th += 0.1
		tw_grip.call(th); step.call(1)
		if vb.item_br == null:
			break
	print("X8 only twisting the hand at the dial: taken=", taken3, " (want true) after 0.9 rad: angle=", snappedf(ang_tw, 0.01), " (want 0.9) finished=", vb.item_br == null, " (want true) seq=", spw.sequenceArray, " (want [blank, blank, live])")
	free_hands.call()
	# the hand version is not possible: the old way (a model without a dial; no shells)
	var invb = mk_item(spawn, "inverter", Vector3(4.0, 0.0, -6), Vector3(2.89, 0.35, 1.68), Vector3(0, -0.1, 0))
	var r_nodial: int = vb._rit_item_tick("inverter", rh, invb[0], invb[1], 0.016)
	var invc = mk_item(spawn, "inverter", Vector3(4.0, 0.0, -8), Vector3(2.89, 0.35, 1.68), Vector3(0, -0.1, 0))
	var dial4 := MeshInstance3D.new(); dial4.name = "inverter dial"; dial4.mesh = dbm; invc[0].add_child(dial4)
	spw.sequenceArray = []
	var r_noseq: int = vb._rit_item_tick("inverter", rh, invc[0], invc[1], 0.016)
	spw.sequenceArray = ["live", "blank", "live"]
	vb._inv_reset()
	print("X9 no dial in the model -> ", r_nodial, " (want 2); no shells -> ", r_noseq, " (want 2); fallback zones: ", vb.TITEM_FALLBACK, " (want medicine head, inverter gun)")
	# ---- Y: the prescription medicine
	var mk_med = func(pos: Vector3):
		var it = mk_item(spawn, "expired medicine", pos, Vector3(2.84, 0.43, 1.93), Vector3(0, 0, 0))
		var st := MeshInstance3D.new(); st.name = "expired medicine blister pack"
		var stm := BoxMesh.new(); stm.size = Vector3(2.69, 0.19, 1.62); st.mesh = stm
		it[0].add_child(st); st.position = Vector3(-0.0586669, -0.0694825, -0.025259)
		var cp := MeshInstance3D.new(); cp.name = "expired medicine cap"
		var cpm := BoxMesh.new(); cpm.size = Vector3(0.42, 0.15, 0.43); cp.mesh = cpm
		st.add_child(cp); cp.position = Vector3(0.00633597, -0.000937045, 0.0169888)
		return [it[0], it[1], st, cp]
	var md = mk_med.call(Vector3(2.0, 0.0, -4))
	im.items_dynamicInteractionArray = [md[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	var strip: MeshInstance3D = md[2]
	var cap: MeshInstance3D = md[3]
	var rest_pos: Vector3 = strip.position
	print("Y1 picked the medicine: ", vb.item_br != null and str(vb.item_br.get("itemName")), " strip+pill found=", vb.med_strip == strip and vb.med_pill == cap, " (want true) state=", vb.med_state, " (want 0)")
	var xdir: Vector3 = (md[0].global_transform.basis * Vector3(-1, 0, 0)).normalized()
	var send: Vector3 = strip.global_transform * vb.med_end_loc
	put_reach.call(lh, send); lh.grip_sq = false; step.call(3)
	var sbox: AABB = vb._node_world_aabb(strip, true)
	var framed_m := false
	for pbx in vb.poke_boxes:
		if typeof(pbx) == TYPE_AABB:
			var pb2: AABB = pbx
			if pb2.is_equal_approx(sbox):
				framed_m = true
	lh.grip_sq = true; step.call(2)
	print("Y2 the other hand at the end of the strip: framed=", framed_m, " (want true) taken=", vb.med_hand == lh, " (want true)")
	put_reach.call(lh, send + xdir * (0.5 * vb.MED_PULL_LEN)); step.call(2)
	print("Y3 pulled halfway: p=", snappedf(vb.med_p, 0.01), " (want 0.5) strip moved by ", snappedf((strip.position - rest_pos).length(), 0.01), " (want ", snappedf(1.05, 0.01), " along x ", (strip.position - rest_pos).x < 0.0, ")")
	lh.grip_sq = false; step.call(2)
	var free_m: bool = not lh.holding and vb.med_hand == null
	step.call(30)
	print("Y4 let go halfway: hand free=", free_m, " (want true) the strip slides back: p=", snappedf(vb.med_p, 0.01), " (want 0) state=", vb.med_state, " (want 0) pos back=", strip.position.is_equal_approx(rest_pos), " (want true)")
	put_reach.call(lh, send); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2)
	put_reach.call(lh, send + xdir * (0.95 * vb.MED_PULL_LEN)); step.call(2)
	lh.grip_sq = false; step.call(2)
	var st_after: int = vb.med_state
	step.call(25)
	print("Y5 pulled 95% and let go: state=", st_after, " (want 1, out) p=", snappedf(vb.med_p, 0.01), " (want 1) strip at ", strip.position.snapped(Vector3.ONE * 0.01), " (want ", vb.MED_STRIP_OUT.snapped(Vector3.ONE * 0.01), ") tilt=", snappedf(strip.rotation.z, 0.001), " (want ", snappedf(vb.MED_STRIP_ROT, 0.001), ") hand free=", not lh.holding, " (want true)")
	# the flick: the pill pops out into the other hand
	var pcn: Vector3 = cap.global_transform * Vector3.ZERO
	put_reach.call(lh, pcn + Vector3(0.0, 0.1 * ws, 0.0)); lh.grip_sq = false; step.call(40)
	var gbf: Basis = Basis.IDENTITY
	for i in 6:
		lh.grip.global_transform = Transform3D(gbf * Basis(Vector3(1, 0, 0), float(i + 1) * 0.2), lh.grip.global_position); step.call(1)
	lh.grip.global_transform = Transform3D(gbf, lh.grip.global_position)
	var st_f: int = vb.med_state
	step.call(40)
	var pxf_l: Transform3D = vb._med_pill_xf(lh)
	print("Y6 flicked near the strip: state right after=", st_f, " (want 2, flying) now=", vb.med_state, " (want 3, in the hand) pill hidden on the strip=", not cap.visible, " (want true) pill in the palm: ", snappedf(vb.med_pillnode.global_position.distance_to(pxf_l.origin) / ws * 100.0, 0.1), " cm off (want ~0) hand holding=", lh.holding, " (want true)")
	put_reach.call(lh, Vector3(-1.0, 1.2, -2.0)); step.call(3)
	pxf_l = vb._med_pill_xf(lh)
	print("Y7 the pill follows the hand: ", snappedf(vb.med_pillnode.global_position.distance_to(pxf_l.origin) / ws * 100.0, 0.1), " cm off (want ~0) flat on the palm=", snappedf(absf((vb.med_pillnode.global_transform.basis * Vector3(0, 1, 0)).normalized().dot(lh.grip.global_transform.basis.x)), 0.01), " (want 1)")
	# not at the mouth: nothing yet
	var rem_m: int = ii.removed
	var am_m: int = ii.amounts.array_amounts[6].amount_player
	var pl1: int = count_players.call()
	var fx1: int = vb.fx_list.size()
	var to_mouth_pill = func():
		var m: Vector3 = vb._mouth_point()
		lh.grip.global_transform = Transform3D(Basis.IDENTITY, m - Vector3(0.012 * ws, 0.0, -0.045 * ws))
	for i in 12:
		to_mouth_pill.call(); step.call(1)
	print("Y8 pill at the lips 0.2 s: UseMedicine calls=", medm.calls, " (want 0 yet)")
	for i in 40:
		to_mouth_pill.call(); step.call(1)
		if vb.item_br == null:
			break
	print("Y9 eaten: UseMedicine calls=", medm.calls, " (want 1) removed=", ii.removed - rem_m, " (want 1) amount ", am_m, " -> ", ii.amounts.array_amounts[6].amount_player, " (want 3 -> 2) turn list has it=", "expired medicine" in rm.playerCurrentTurnItemArray, " (want true) sound=", int(count_players.call()) - pl1, " (want 1) box tossed=", vb.fx_list.size() - fx1, " (want 1) pill gone=", vb.med_pillnode == null, " (want true) hands free=", not lh.holding and not rh.holding, " (want true)")
	free_hands.call()
	# the flick pulls the strip out (a second box)
	var md2 = mk_med.call(Vector3(-2.0, 0.0, -4))
	im.items_dynamicInteractionArray = [md2[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(-2.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(40)
	var ref2: Vector3 = vb._item_ref(md2[0])
	put_reach.call(lh, ref2 + Vector3(0.0, 0.15 * ws, 0.0)); lh.grip_sq = false; step.call(40)
	for i in 6:
		lh.grip.global_transform = Transform3D(Basis(Vector3(1, 0, 0), float(i + 1) * 0.2), lh.grip.global_position); step.call(1)
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, lh.grip.global_position)
	var auto_f: bool = vb.med_auto
	step.call(30)
	print("Y10 flicked at the box: sliding=", auto_f, " (want true) state=", vb.med_state, " (want 1) p=", snappedf(vb.med_p, 0.01), " (want 1) strip x=", snappedf((md2[2] as Node3D).position.x, 0.01), " (want ", snappedf(vb.MED_STRIP_OUT.x, 0.01), ")")
	# a squeeze at the pill takes it as well; the box is put back with the pill in the hand: all as before
	var pc2: Vector3 = (md2[3] as Node3D).global_transform * Vector3.ZERO
	put_reach.call(lh, pc2); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2); step.call(25)
	var st_sq: int = vb.med_state
	rh.grip_sq = false; step.call(4)
	print("Y11 squeezed at the pill: state=", st_sq, " (want 3) the box put back with the pill in the hand: carried=", vb.item_br != null, " (want false) pill node gone=", vb.med_pillnode == null, " (want true) strip back=", (md2[2] as Node3D).position.is_equal_approx(Vector3(-0.0586669, -0.0694825, -0.025259)), " (want true) pill visible again=", (md2[3] as Node3D).visible, " (want true) hands free=", not lh.holding and not rh.holding, " (want true)")
	free_hands.call()
	var mdb = mk_item(spawn, "expired medicine", Vector3(4.0, 0.0, -6), Vector3(2.84, 0.43, 1.93), Vector3(0, 0, 0))
	print("Y12 a medicine model without a strip: ", vb._rit_item_tick("expired medicine", rh, mdb[0], mdb[1], 0.016), " (want 2, the old way: to the face)")
	# ---- Z: the magnifying glass: smash it, the rest of the glass is a window
	var brk := MeshInstance3D.new(); brk.name = "magnifying glass broken"; scene.add_child(brk); brk.visible = false
	var bam := ArrayMesh.new()
	for sn in ["brass.001", "wood worn.001", "magnifying glass.001"]:
		var ar := []
		ar.resize(Mesh.ARRAY_MAX)
		ar[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)])
		bam.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
		bam.surface_set_name(bam.get_surface_count() - 1, sn)
	brk.mesh = bam
	var mk_mag = func(pos: Vector3):
		var it = mk_item(spawn, "magnifying glass", pos, Vector3(0.3, 3.9, 1.7), Vector3(0, 0.3, 0))
		var ln := MeshInstance3D.new(); ln.name = "magnifying glass lens"
		var lbm := BoxMesh.new(); lbm.size = Vector3(0.11, 1.6296, 1.6296); ln.mesh = lbm
		it[0].add_child(ln); ln.position = Vector3(0.1847, 1.3513, -0.008)
		return [it[0], it[1], ln]
	var smash_down = func(x: float, z: float):
		var y := 7.0
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(x, y, z)); step.call(12)
		for i in 60:
			y -= 0.3
			rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(x, y, z)); step.call(1)
			if vb.mag_stage == 1:
				break
		return y
	spw.sequenceArray = ["live", "blank", "live"]
	var mg = mk_mag.call(Vector3(-2.5, 0.0, -4))
	im.items_dynamicInteractionArray = [mg[1]]
	vb.shape_cache.clear(); step.call(4)
	var remZ: int = ii.removed
	put_reach.call(rh, Vector3(-2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	print("Z1 picked the glass: stage=", vb.mag_stage, " (want 0) message shown=", vb.hint_label.visible and vb.hint_label.text, " (want BREAK THE GLASS) nothing drawn through the glass=", vb.mag_view == null, " (want true)")
	var mat_code: String = vb.MAG_SHADER
	print("Z2 the window shader has the picture of the glass: ", mat_code.contains("uniform sampler2D lens_mask") and mat_code.contains("use_mask"), " (want true)")
	# held in front of the eye, as before: still nothing
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, -2.0)); step.call(40)
	print("Z3 held up to the eye for 0.6 s: stage=", vb.mag_stage, " (want 0) viewing model made=", vb.mag_view != null, " (want false)")
	var yz: float = smash_down.call(-2.5, -4.0)
	var par_m: Node3D = mg[0]
	var bchild: Node = par_m.get_node_or_null("VRBootMagBroken")
	var nfade := 0
	for e in vb.fx_list:
		if bool(e.get("fade", false)):
			nfade += 1
	print("Z4 smashed down onto the table: stage=", vb.mag_stage, " (want 1) the whole glass hidden=", par_m.layers == 0 and (mg[2] as VisualInstance3D).layers == 0, " (want true) the game's broken glass is on it=", bchild != null and (bchild as MeshInstance3D).mesh == bam, " (want true) at the animation offset=", bchild != null and (bchild as Node3D).position.is_equal_approx(vb.MAG_ANIM_OFF), " (want true) visible layer=", bchild != null and (bchild as VisualInstance3D).layers == 1, " (want true) picture of the glass=", vb.mag_mask != null, " (want true) pieces flying=", nfade, " (want >= 22) still in the hand, not used up=", vb.item_br != null and ii.removed == remZ, " (want true)")
	step.call(4)
	var mm: ShaderMaterial = vb.mag_mats[0] if vb.mag_mats.size() > 0 else null
	var lu: Vector3 = mm.get_shader_parameter("lens_u") if mm != null else Vector3.ZERO
	print("Z5 the shell is shown through what is left: model=", vb.mag_view != null and vb.mag_view.visible, " (want true) mask in use=", mm != null and float(mm.get_shader_parameter("use_mask")) == 1.0, " (want true) picture bound=", mm != null and mm.get_shader_parameter("lens_mask") == vb.mag_mask, " (want true) lens_u length=", snappedf(lu.length(), 0.001), " (want ", snappedf(1.0 / (2.0 * 0.8148), 0.001), ")")
	print("Z6 no more message once it is broken: ", not vb.hint_label.visible, " (want true)")
	# the picture itself: a fan of triangles shaped like the glass with its top cut off (the game's data cannot be read headless)
	var ca: Vector3 = vb.mag_lens_c - vb.MAG_ANIM_OFF
	var R: float = vb.mag_lens_rad
	var vs := PackedVector3Array(); var ix := PackedInt32Array()
	vs.append(Vector3(0.0, ca.y, ca.z))
	var n_arc := 48
	for k in n_arc + 1:
		var an: float = deg_to_rad(148.7 + (391.3 - 148.7) * float(k) / float(n_arc))
		vs.append(Vector3(0.0, ca.y + R * sin(an), ca.z + R * cos(an)))
	for k in n_arc:
		ix.append(0); ix.append(k + 1); ix.append(k + 2)
	ix.append(0); ix.append(n_arc + 1); ix.append(1)
	var data: PackedByteArray = vb._mag_raster(vs, ix)
	var N: int = vb.MAG_MASK_N
	var px_at = func(lz: float, ly: float):
		var pcol := int(N * 0.5 + lz * R * (N / (2.0 * R)))
		var prow := int(N * 0.5 + ly * R * (N / (2.0 * R)))
		return data[prow * N + pcol]
	print("Z7 picture of the glass: middle=", px_at.call(0.0, 0.0), " low=", px_at.call(0.0, -0.7), " side=", px_at.call(0.9, 0.0), " just under the cut=", px_at.call(0.0, 0.3), " (want 255 each)  above the cut=", px_at.call(0.0, 0.6), " top=", px_at.call(0.0, 0.8), " outside the rim=", px_at.call(0.95, -0.4), " (want 0 each)")
	# let go: the broken glass falls and fades away (transparency), it is spent
	var kids_before: Array = vb.fx_root.get_children()
	rh.grip_sq = false; step.call(3)
	var props := []
	for c in vb.fx_root.get_children():
		if not (c in kids_before):
			props.append(c)
	var fadet_n := 0
	for e in vb.fx_list:
		if bool(e.get("fadet", false)):
			fadet_n += 1
	print("Z8 let go of the broken glass: removed=", ii.removed - remZ, " (want 1) carried=", vb.item_br != null, " (want false) falling copy of the broken model=", props.size(), " (want 1) fading by transparency=", fadet_n, " (want 1) the broken model in it=", props.size() > 0 and (props[0] as Node).get_child_count() >= 1)
	var tr_max := 0.0
	var scale_ok := true
	print("Z9dbg fx_list=", vb.fx_list.size(), " fadet=", fadet_n, " props=", props.size(), " kids of first=", (props[0] as Node).get_child_count() if props.size() > 0 else -1)
	for i in 260:
		vb._fx_update(0.016)
		for p in props:
			if is_instance_valid(p) and not (p as Node).is_queued_for_deletion():
				if ((p as Node3D).scale - Vector3.ONE).length() > 0.01:
					scale_ok = false
				for ch in (p as Node).get_children():
					if ch is GeometryInstance3D:
						tr_max = maxf(tr_max, (ch as GeometryInstance3D).transparency)
	var props_left := 0
	for p in props:
		if is_instance_valid(p) and not (p as Node).is_queued_for_deletion():
			props_left += 1
	print("Z9 it fades (transparency up to ", snappedf(tr_max, 0.01), ", want > 0.5), never shrinks (scale untouched=", scale_ok, ", want true) and is gone after 4 s: left=", props_left, " (want 0) fx left=", vb.fx_list.size(), " (want 0)")
	free_hands.call()
	# not broken yet: letting go just puts it back
	var mg2z = mk_mag.call(Vector3(-2.5, 0.0, -4))
	im.items_dynamicInteractionArray = [mg2z[1]]
	vb.shape_cache.clear(); step.call(4)
	var remZ2: int = ii.removed
	put_reach.call(rh, Vector3(-2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	rh.grip_sq = false; step.call(4)
	print("Z10 whole glass let go: put back, not used=", vb.item_br == null and ii.removed == remZ2 and not (mg2z[0] as Node).is_queued_for_deletion(), " (want true) layers=", (mg2z[0] as VisualInstance3D).layers, " (want 1)")
	free_hands.call()
	# broken, then the game takes it back (the turn changed): the whole glass is back
	put_reach.call(rh, Vector3(-2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	smash_down.call(-2.5, -4.0)
	var bc2: Node = (mg2z[0] as Node).get_node_or_null("VRBootMagBroken")
	var broke_ok: bool = vb.mag_stage == 1 and bc2 != null
	vb._titem_end(true, "test")
	print("Z11 broken, then taken back by the game: was broken=", broke_ok, " (want true) whole again: layers ", (mg2z[0] as VisualInstance3D).layers, "/", (mg2z[2] as VisualInstance3D).layers, " (want 1/1) broken model removed=", bc2 == null or bc2.is_queued_for_deletion(), " (want true) stage=", vb.mag_stage, " (want 0) mask=", vb.mag_mask == null, " (want true)")
	free_hands.call()
	# the model of the broken glass cannot be found: the glass is not swapped, nothing breaks
	brk.name = "zz"
	var mg3z = mk_mag.call(Vector3(-2.5, 0.0, -4))
	im.items_dynamicInteractionArray = [mg3z[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(-2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(20)
	smash_down.call(-2.5, -4.0)
	print("Z12 no broken model in the game: stage=", vb.mag_stage, " (want 1) glass layers=", (mg3z[0] as VisualInstance3D).layers, " (want 1, not hidden) no picture=", vb.mag_mask == null, " (want true) no broken child=", (mg3z[0] as Node).get_node_or_null("VRBootMagBroken") == null, " (want true)")
	vb._titem_end(false, "test")
	free_hands.call()
	brk.name = "magnifying glass broken"
	quit()
