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
	var ind = load("@MOCKS@/mock_ind29.gd").new(); par.add_child(ind)
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
	var im = load("@MOCKS@/mock_im29.gd").new(); scene.add_child(im)
	var intake = mk_box_branch(Node3D.new(), "briefcase intake", Vector3(1, 1, 1))
	scene.add_child(intake.get_parent()); intake.get_parent().global_position = Vector3(-30, 0, 0)
	im.interaction_intake = intake
	var spawn := Node3D.new(); scene.add_child(spawn); im.itemSpawnParent = spawn
	inter.itemManager = im
	var ii = load("@MOCKS@/mock_ii29.gd").new(); scene.add_child(ii); inter.itemInteraction = ii
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
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_8_BITS; wav.mix_rate = 8000; wav.stereo = false
	var wd := PackedByteArray(); wd.resize(800); wd.fill(128); wav.data = wd
	ii.sound_use_burnerphone = wav; ii.sound_use_adrenaline = wav
	ii.items = im
	ii.hands = load("@MOCKS@/mock_hands.gd").new(); scene.add_child(ii.hands)
	ii.camera = load("@MOCKS@/mock_cam.gd").new(); scene.add_child(ii.camera)
	var free_hands = func():
		rh.grip_sq = false; lh.grip_sq = false
		for i in 6:
			step.call(1)
		vb.item_down.clear(); vb.gun_down.clear(); vb.rit_down.clear()
		rh.holding = false; lh.holding = false
	var far = func():
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(30, 1, 30)); lh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-30, 1, 30)); step.call(3)
	# ---- W: the shotgun's look is prepared once, tiny, then gone
	vb.gun_warm_t = 0.0; vb.gun_warm_done = false; vb.gun_warm_n = 0
	var warm_seen := false
	var warm_scale := 0.0
	for i in 150:
		step.call(1)
		if vb.gun_warm_node != null:
			warm_seen = true
			warm_scale = vb.gun_warm_node.scale.x
	var left_over := 0
	for c in vb.fx_root.get_children():
		if str(c.name).begins_with("VRBootShotgun") and not c.is_queued_for_deletion():
			left_over += 1
	print("W1 warm-up: a tiny copy was drawn=", warm_seen, " (want true) scale/ws=", snappedf(warm_scale / ws, 0.0001), " done=", vb.gun_warm_done, " (want true) copies left=", left_over, " (want 0) gun pairs=", vb.gun_pairs.size(), " (want 0) gun state=", vb.gun_state, " (want 0)")
	# ---- G: the gun: the frame shown on it is also where a squeeze takes it
	(col.get_child(0) as CollisionShape3D).shape.size = Vector3(8.0, 16.0, 3.0)
	vb.shape_cache.clear()
	step.call(4)
	var gb: AABB = vb.gun_rest_box
	put_reach.call(rh, Vector3(3.3, 0.5, -8.0))
	rh.grip_sq = false; step.call(3)
	var axis_d: float = vb._gun_grab_dist(Vector3(3.3, 0.5, -8.0))
	print("G1 hand off the axis (", snappedf(axis_d / ws, 0.01), " m, old limit ", snappedf(vb.GUN_GRAB_M * ws / ws, 0.001), " m) inside the frame: box has it=", gb.has_point(Vector3(3.3, 0.5, -8.0)), " eff dist=", vb._gun_eff_dist(Vector3(3.3, 0.5, -8.0)), " (want 0)")
	rh.grip_sq = true; step.call(2)
	print("G2 squeezed: gun state=", vb.gun_state, " (want 1) hand=", vb.gun_hand == rh)
	vb._gun_release("test"); free_hands.call(); far.call()
	put_reach.call(rh, Vector3(4.6, 0.5, -8.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("G3 squeezed well outside the frame (", snappedf(vb._gun_eff_dist(Vector3(4.6, 0.5, -8.0)) / ws, 2), " m): gun state=", vb.gun_state, " (want 0)")
	free_hands.call(); far.call()
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, 1.0, 0.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("G4 on the axis still works: gun state=", vb.gun_state, " (want 1)")
	vb._gun_release("test"); free_hands.call(); far.call()
	# a squeeze that is ignored is explained in the log (hand busy)
	rh.holding = true
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, 1.0, 0.0)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("G5 busy hand: gun state=", vb.gun_state, " (want 0, and a 'squeeze ... ignored' line above)")
	free_hands.call(); far.call()
	# ---- H: how the pack and the phone sit in the fist
	var pk0 = mk_item(spawn, "cigarettes", Vector3(2.0, 0.0, -4), Vector3(1.0, 1.6, 0.6), Vector3(0, 0, 0))
	im.items_dynamicInteractionArray = [pk0[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	var fwd_item: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	var up_item: Vector3 = vb.item_rb.inverse() * Vector3(0, 1, 0)
	print("H1 pack: carried=", vb.item_br != null, " item axis pointing forward=", fwd_item.snapped(Vector3.ONE * 0.01), " (want 1,0,0) along the fist=", up_item.snapped(Vector3.ONE * 0.01), " (want 0,0,-1) grasp frac z=", snappedf((vb.item_grasp.z - vb.item_loc.position.z) / vb.item_loc.size.z, 0.01), " (want 0.6)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	pk0[0].queue_free()
	# ---- Q: the burner phone: flick it open, put it to the ear, the screen animation and the message
	var gp := Node3D.new(); gp.name = "player item interaction parent"; scene.add_child(gp)
	var gph := Node3D.new(); gph.name = "burner phone"; gp.add_child(gph)
	var gpar := Node3D.new(); gpar.name = "burner phone parent"; gph.add_child(gpar)
	var gpiv := Node3D.new(); gpiv.name = "burner phone pivot"; gpar.add_child(gpiv)
	var gsm := MeshInstance3D.new(); gsm.name = "burner phone screen_main"; gpiv.add_child(gsm)
	var pl := PlaneMesh.new()
	var ui1 := MeshInstance3D.new(); ui1.name = "phone screen_UI"; ui1.mesh = pl; ui1.transform = Transform3D(Basis.from_scale(Vector3(0.015, 1.2, 0.6)), Vector3(0, -0.006, 0)); gsm.add_child(ui1)
	var m1 := StandardMaterial3D.new(); ui1.material_override = m1
	var ui2s := MeshInstance3D.new(); ui2s.name = "phone screen_UI2"; ui2s.mesh = pl; ui2s.transform = ui1.transform; ui2s.visible = false; gsm.add_child(ui2s)
	var m2 := StandardMaterial3D.new(); m2.uv1_scale = Vector3(0.19, 0.19, 0.19); ui2s.material_override = m2
	var phm = load("@MOCKS@/mock_phone.gd").new(); phm.name = "burner phone manager"; scene.add_child(phm)
	var mkphone = func():
		var p = mk_item(spawn, "burner phone", Vector3(1.0, 0.0, -4), Vector3(2.5, 0.4, 1.3), Vector3(0, 0, 0))
		var pv := MeshInstance3D.new(); pv.name = "burner phone pivot"; var pvm := BoxMesh.new(); pvm.size = Vector3(1.2, 0.2, 1.2); pv.mesh = pvm
		p[0].add_child(pv); pv.position = Vector3(-1.2, 0.0, 0.0)
		var sc := MeshInstance3D.new(); sc.name = "burner phone screen"; sc.mesh = pvm; pv.add_child(sc); sc.position = Vector3(1.0, 0.08, 0.02)
		im.items_dynamicInteractionArray = [p[1]]
		vb.shape_cache.clear(); step.call(4)
		put_reach.call(rh, Vector3(1.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
		rh.grip_sq = true; step.call(2); step.call(40)
		return [p, pv, sc]
	var flick = func():
		for i in 4:
			rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis * Basis(Vector3(0, 0, 1), 0.25), rh.grip.global_position); step.call(1)
		step.call(1)
	var remQ: int = ii.removed
	var P1: Array = mkphone.call()
	var piv: Node3D = P1[1]
	var fwdp: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	var upp: Vector3 = vb.item_rb.inverse() * Vector3(0, 1, 0)
	print("Q1 picked the phone: ", vb.item_br != null and str(vb.item_br.get("itemName")), " state=", vb.phone_state, " (want 0) forward=", fwdp.snapped(Vector3.ONE * 0.01), " (want -1,0,0) fist axis=", upp.snapped(Vector3.ONE * 0.01), " (want 0,0,-1) message=", phm.sent)
	flick.call()
	var pui = P1[2].get_children()
	print("Q2 flicked: state=", vb.phone_state, " (want 1) screen copies=", pui.size(), " (want 2) plain visible=", vb.phone_ui != null and vb.phone_ui.visible, " (want true) animated hidden=", vb.phone_ui2 != null and not vb.phone_ui2.visible, " (want true) own material=", vb.phone_ui2 != null and vb.phone_ui2.material_override != m2, " (want true)")
	step.call(35)
	print("Q3 0.55 s on: lid angle=", snappedf(piv.rotation.z, 0.01), " (want about 2.6) hint='", vb.hint_label.text, "' shown=", vb.hint_label.visible, " (want PUT IT TO YOUR EAR / true)")
	step.call(200)
	print("Q4 3 s with the phone away from the ear: state=", vb.phone_state, " (want 1) message=", phm.sent, " (want 0)")
	var hb: Basis = vb.xr_cam.global_transform.basis
	var earp: Vector3 = vb.xr_cam.global_position - hb.y * (0.02 * ws) + hb.x * (0.085 * ws)
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, earp)
	step.call(10)
	print("Q5 phone at the ear 0.16 s: state=", vb.phone_state, " (want 1 still)")
	step.call(25)
	print("Q6 phone at the ear 0.6 s: state=", vb.phone_state, " (want 2) plain hidden=", not vb.phone_ui.visible, " animated shown=", vb.phone_ui2.visible, " scale=", snappedf(m2.uv1_scale.x, 0.01) if false else snappedf((vb.phone_ui2.material_override as StandardMaterial3D).uv1_scale.x, 0.01), " (want about 0.19) message=", phm.sent, " (want 0)")
	step.call(100)
	var sc_mid: float = (vb.phone_ui2.material_override as StandardMaterial3D).uv1_scale.x
	print("Q7 1.6 s into it: message=", phm.sent, " (want 0 yet) scale grows=", sc_mid > 2.0, " (want true) ", snappedf(sc_mid, 0.1))
	step.call(60)
	print("Q8 2.6 s into it: message=", phm.sent, " (want 1)")
	step.call(300)
	print("Q9 the end: used up=", ii.removed - remQ, " (want 1) carry ended=", vb.item_br == null, " (want true) message count=", phm.sent, " (want 1) copies freed=", P1[2].get_children().all(func(n): return n.is_queued_for_deletion()), " (want true) hand free=", not rh.holding)
	free_hands.call(); far.call(); step.call(2)
	# let go before the ear: back on the table, nothing used
	var P2: Array = mkphone.call()
	flick.call()
	step.call(10)
	rh.grip_sq = false; step.call(4)
	print("Q10 let go before the ear: back on the table=", vb.item_br == null and is_instance_valid(P2[0][0]) and not P2[0][0].is_queued_for_deletion(), " (want true) used=", ii.removed - remQ, " (want 1) message=", phm.sent, " (want 1) lid shut again=", snappedf(P2[1].rotation.z, 0.01), " (want 0) copies freed=", P2[2].get_children().all(func(n): return n.is_queued_for_deletion()), " (want true)")
	free_hands.call(); far.call()
	P2[0][0].queue_free()
	# let go while the screen plays: read at once
	var P3: Array = mkphone.call()
	flick.call()
	hb = vb.xr_cam.global_transform.basis
	earp = vb.xr_cam.global_position - hb.y * (0.02 * ws) - hb.x * (0.085 * ws)
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, earp)
	step.call(35)
	var sent0: int = phm.sent
	rh.grip_sq = false; step.call(4)
	print("Q11 left ear + let go while it plays: state was 2, message arrived=", phm.sent - sent0, " (want 1) used=", ii.removed - remQ, " (want 2)")
	free_hands.call(); far.call()
	# ---- R: adrenaline: framed spot, jab, stays stuck
	var ad = mk_item(spawn, "adrenaline", Vector3(-1.0, 0.0, -4), Vector3(3.2, 0.5, 0.5), Vector3(0, 0, 0))
	var cap := MeshInstance3D.new(); cap.name = "adrenaline cap"; var cm := BoxMesh.new(); cm.size = Vector3(0.7, 0.4, 0.4); cap.mesh = cm
	ad[0].add_child(cap); cap.position = Vector3(-1.4, 0.0, 0.0)
	im.items_dynamicInteractionArray = [ad[1]]
	var dl := []
	for k in 4:
		var d = mk_item(spawn, ["beer", "cigarettes", "inverter", "handsaw"][k], Vector3(-6.0 + 4.0 * k, 0.0, -26.0), Vector3(1.4, 1.4, 1.4), Vector3(0, 0.7, 0))
		d[0].get_child(0).isDealerItem = true
		dl.append(d)
	im.itemArray_instances_dealer = [dl[0][0], dl[1][0], dl[2][0], dl[3][0]]
	vb.shape_cache.clear(); step.call(4)
	var remR: int = ii.removed
	put_reach.call(rh, Vector3(-1.0, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2); step.call(30)
	var tipw0: Vector3 = ad[0].global_transform * (vb.adr_local[0] as Vector3)
	var axw0: Vector3 = (ad[0].global_transform.basis * (vb.adr_local[1] as Vector3)).normalized()
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, tipw0 + axw0 * 2.6 - Vector3(0, 0, 0.1 * ws)); step.call(3)
	for i in 8:
		rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + axw0 * 0.25); step.call(1)
	print("R0a jab with the cap still on does nothing: carried=", vb.item_br != null, " (want true) cap state=", vb.adr_cap_state, " (want 0) used=", ii.removed - remR, " (want 0)")
	lh.grip_sq = false; step.call(2)
	var capc: Vector3 = cap.global_transform * cap.mesh.get_aabb().get_center()
	put_reach.call(lh, capc); lh.grip_sq = true; step.call(2)
	print("R0b cap taken by the other hand: state=", vb.adr_cap_state, " (want 1) hand busy=", lh.holding, " (want true)")
	lh.grip_sq = false; step.call(2)
	print("R0b2 let go too early: cap back on=", vb.adr_cap_state == 0, " (want true) cap visible=", cap.visible, " (want true) hand free=", not lh.holding, " (want true)")
	capc = cap.global_transform * cap.mesh.get_aabb().get_center()
	put_reach.call(lh, capc); lh.grip_sq = true; step.call(2)
	put_reach.call(lh, capc + axw0 * 2.0); step.call(2)
	print("R0c cap pulled off: state=", vb.adr_cap_state, " (want 2) cap hidden=", not cap.visible, " (want true) hand free=", not lh.holding, " (want true) fall fx=", vb.fx_list.size())
	lh.grip_sq = false; step.call(2)
	var tipw: Vector3 = ad[0].global_transform * (vb.adr_local[0] as Vector3)
	var axw: Vector3 = (ad[0].global_transform.basis * (vb.adr_local[1] as Vector3)).normalized()
	var arm_pt: Vector3 = tipw + axw * 2.6
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, arm_pt - Vector3(0, 0, 0.1 * ws)); step.call(3)
	var arm_world: Vector3 = lh.grip.global_transform * (Vector3(0.0, 0.0, vb.ADR_ARM_OFF) * ws)
	var framed := false
	for pb in vb.poke_boxes:
		if pb is AABB and (pb as AABB).get_center().distance_to(arm_world) < 0.01:
			framed = true
	vb.poke_boxes.clear(); vb._update_items(0.016)
	for pb in vb.poke_boxes:
		if pb is AABB and (pb as AABB).get_center().distance_to(arm_world) < 0.01:
			framed = true
	print("R1 forearm framed while the syringe is carried: ", framed, " (want true)")
	var nfr := 0
	for i in 8:
		nfr += 1
		rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + axw * 0.25); step.call(1)
		if vb.item_br == null:
			break
	print("R2 jab: used up=", ii.removed - remR, " (want 1) carry ended=", vb.item_br == null, " (want true) stuck copy=", vb.adr_stuck != null, " (want true) item toss in fx=", vb.fx_list.size())
	var tip_stuck: Vector3 = vb.adr_stuck.global_position if vb.adr_stuck != null else Vector3.ZERO
	var lh_shift := Vector3(1.0, 0.5, 0.0)
	lh.grip.global_transform = Transform3D(lh.grip.global_transform.basis, lh.grip.global_position + lh_shift)
	step.call(2)
	print("R3 the syringe moves with the forearm: moved by ", (vb.adr_stuck.global_position - tip_stuck).snapped(Vector3.ONE * 0.01), " (want 1,0.5,0)")
	step.call(230)
	print("R4 after the pulse time it lets go: stuck=", vb.adr_stuck, " (want <null>) fx=", vb.fx_list.size())
	free_hands.call()
	# ---- T: head to the middle of the table at the pulse
	var head0: Vector3 = vb.xr_cam.global_position
	var cen := Vector3.ZERO
	for d in dl:
		cen += (d[0] as Node3D).global_position
	cen /= 4.0
	var hit0: int = ii.hit_count
	vb._adr_hit()
	var moved: Vector3 = vb.xr_cam.global_position - head0
	var want_m: Vector3 = (cen - head0) * vb.ADR_TP_FRAC; want_m.y = 0.0
	print("T1 pulse: effect=", ii.hit_count - hit0, " (want 1) moved=", moved.snapped(Vector3.ONE * 0.01), " want ", want_m.snapped(Vector3.ONE * 0.01), " on=", vb.adr_tp_on, " (want true)")
	vb._adr_steal()
	print("T2 game timing: steal set up=", im.steal_calls, " (want 1)")
	ii.stealing = true; ii.stealing_fs = true
	im.items_dynamicInteractionArray = [dl[0][1], dl[1][1], dl[2][1], dl[3][1]]
	step.call(5)
	print("T3 stealing: on=", vb.steal_on, " (want true) still at the table=", vb.adr_tp_on, " (want true) dealer items stay=", (dl[0][0] as Node3D).position.is_equal_approx(Vector3(-6.0, 0.0, -26.0)), " (want true)")
	# the head is not carried back by the game's own camera movement
	var h_t: Vector3 = vb.xr_cam.global_position
	step.call(30)
	print("T4 stays: ", vb.xr_cam.global_position.is_equal_approx(h_t), " (want true)")
	# take one of the dealer's items: you are back in the seat, the game's 7 s clock stops, nothing else is changed
	var tgt: Vector3 = (dl[0][0] as Node3D).global_position + Vector3(0, 0.5, 0)
	put_reach.call(rh, tgt); rh.grip_sq = false; step.call(3)
	var pk: Array = vb._titem_pick(im, tgt)
	print("T5 nearest takeable item is the dealer's: ", pk[0] == dl[0][1], " (want true)")
	rh.grip_sq = true; step.call(2)
	print("T6 squeezed: carrying=", vb.item_br != null and str(vb.item_br.get("itemName")), " (want beer) stolen=", vb.steal_held, " (want true) the game was NOT told to use it=", not inter.item_presses.has("beer"), " (want true) back in the seat=", not vb.adr_tp_on, " (want true) counter calls=", im.counter_calls, " (want [false]) walk_off=", vb.walk_off)
	# put it back: the game's clock runs again and you go to the table again
	rh.grip_sq = false; step.call(30)
	print("T7 put back: carrying=", vb.item_br == null, " (want true) counter calls=", im.counter_calls, " (want [false, true]) moves to the table again=", vb.adr_tp_re, " (want true)")
	free_hands.call()
	step.call(3)
	print("T8 again at the table: ", vb.adr_tp_on, " (want true)")
	# take the beer again and drink it at the mouth: the game's bookkeeping for a stolen item
	var amt = load("@MOCKS@/mock_amt29.gd").new(); amt.itemName = "beer"
	ii.amounts.array_amounts[0] = amt
	tgt = (dl[0][0] as Node3D).global_position + Vector3(0, 0.5, 0)
	put_reach.call(rh, tgt); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	var mouth: Vector3 = vb.xr_cam.global_position - vb.xr_cam.global_transform.basis.y * (0.06 * ws)
	var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(70))
	var topl: Vector3 = vb.item_loc.position + Vector3(vb.item_loc.size.x * 0.5, vb.item_loc.size.y, vb.item_loc.size.z * 0.5)
	var bpar: Node3D = dl[0][0]
	rh.grip.global_transform = Transform3D(tilt, Vector3.ZERO); step.call(1)
	var cur_top: Vector3 = bpar.global_transform * topl
	rh.grip.global_transform = Transform3D(tilt, rh.grip.global_position + (mouth - cur_top)); step.call(10)
	var rem_b: int = ii.removed
	for i in 140:
		cur_top = bpar.global_transform * topl
		rh.grip.global_transform = Transform3D(tilt, rh.grip.global_position + (mouth - cur_top))
		step.call(1)
		if vb.rit != "":
			break
	print("T9 drunk: rit=", vb.rit, " (want beer_rack) the dealer's slot freed=", ii.hands.removed.has(bpar), " (want true) steal reverted=", im.revert_calls, " (want 1) stealing over=", not ii.stealing, " (want true) fs off=", not ii.stealing_fs, " (want true) home camera=", ii.camera.lerps, " (want [home]) hand pos=", ii.pos_hand == ii.pos_hand_main, " (want true) player grid untouched=", ii.removed - rem_b, " (want 0) amounts: dealer ", amt.amount_dealer, " (want 1) player ", amt.amount_player, " (want 2) turns=", rm.playerCurrentTurnItemArray)
	vb._rit_abort("test")
	free_hands.call(); far.call()
	step.call(3)
	print("T10 no stealing any more: on=", vb.steal_on, " (want false) tp=", vb.adr_tp_on, " (want false) re=", vb.adr_tp_re, " (want false)")
	# the 7 s timeout while you stand at the table: back in the seat
	ii.stealing = false; ii.stealing_fs = false
	vb._adr_tp_begin()
	ii.stealing = true; ii.stealing_fs = true; step.call(3)
	ii.stealing = false; ii.stealing_fs = false; step.call(3)
	print("T11 timeout of the game's clock: back in the seat=", not vb.adr_tp_on, " (want true)")
	quit()
