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
	ii.sound_use_burnerphone = wav; ii.sound_use_adrenaline = wav; ii.sound_use_inverter = wav
	ii.items = im
	ii.hands = load("@MOCKS@/mock_hands.gd").new(); scene.add_child(ii.hands)
	ii.camera = load("@MOCKS@/mock_cam.gd").new(); scene.add_child(ii.camera)
	var free_hands = func():
		rh.grip_sq = false; lh.grip_sq = false
		for i in 6:
			step.call(1)
		vb.item_down.clear(); vb.gun_down.clear(); vb.rit_down.clear(); vb.pp_down.clear()
		rh.holding = false; lh.holding = false
	var far = func():
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(30, 1, 30)); lh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-30, 1, 30)); step.call(3)
	# ---- C: handcuffs given to the dealer: the "being taken" flag must not stay on
	im.items_dynamicInteractionArray = [cuf[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(-5.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	print("C0 cuffs in the hand: ", vb.item_br != null, " (want true)")
	vb.item_handoff = true
	vb.item_br = null          # (the game has freed its item node: an old, freed branch compares equal to null)
	step.call(3)
	print("C1 after the game took them: handoff=", vb.item_handoff, " (want false) hand=", vb.item_hand == null, " (want true) holding=", rh.holding, " (want false)")
	free_hands.call(); far.call()
	vb.item_handoff = true; vb.item_hand = rh; rh.holding = true
	vb._item_end("test")
	print("C2 _item_end with the flag: handoff=", vb.item_handoff, " (want false) holding=", rh.holding, " (want false)")
	free_hands.call(); far.call()
	vb.gun_state = 0
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, 1.0, 0.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("C3 the gun can be taken: gun state=", vb.gun_state, " (want 1)")
	vb._gun_release("test"); free_hands.call(); far.call()
	# ---- B: the shotgun can be taken while it is to be racked after a beer
	vb.rit = "beer_rack"; vb.rit_t = 0.0; vb.rit_final = false
	rh.grip_sq = false; step.call(2)
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, -3.5, 0.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("B1 beer drunk, hand squeezes the shotgun: gun state=", vb.gun_state, " (want 1) rit=", vb.rit, " (want beer_rack) held free=", vb._gun_held_free(), " (want true)")
	step.call(40)
	var pbox := AABB()
	pbox.size = Vector3(-1, -1, -1)
	for e in vb.gun_pairs:
		if e[0] is Node and str((e[0] as Node).name) == "shotgun-forearm_003":
			pbox = vb._node_world_aabb(e[1], true)
	print("B2 the held gun's pump box exists: ", pbox.size.x >= 0.0, " (want true)")
	lh.grip_sq = false; step.call(2)
	put_reach.call(lh, pbox.get_center())
	lh.grip_sq = false; step.call(3)
	print("B3z before: rit_down=", vb.rit_down, " rit_hand=", vb.rit_hand, " lh holding=", lh.holding, " was_active=", lh.was_active)
	lh.grip_sq = true; step.call(1)
	print("B3y after 1: rit_down=", vb.rit_down, " rit_hand=", vb.rit_hand, " holding=", lh.holding)
	step.call(2)
	print("B3 other hand took the pump: rit_hand=", vb.rit_hand == lh, " (want true) DBG rit=", vb.rit, " rit_t=", vb.rit_t, " lh.holding=", lh.holding, " pump step=", vb._pump_step(0.0, false), " gun_state=", vb.gun_state, " pairs=", vb.gun_pairs.size(), " dist=", vb._point_box_dist(lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws), pbox) / ws)
	var pc0: Vector3 = pbox.get_center()
	var down_dir: Vector3 = (vb._gun_xf().basis * Vector3(0, 1, 0)).normalized()
	for i in 30:
		put_reach.call(lh, lh.grip.global_position + vb.PUMP_TRAVEL * ws * 0.06 * down_dir * 0.0 + Vector3(0, 0, 0) + (-down_dir) * 0.0)
	var pulled := false
	for i in 40:
		var cur: Vector3 = lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
		put_reach.call(lh, cur + down_dir * 0.3 * (1.0 if i < 20 else -1.0))
		step.call(1)
		if vb.rit_pulled:
			pulled = true
	print("B4 pump pulled with the gun in the other hand: pulled=", pulled, " (note: depends on the mock gun's pump axis)")
	vb._pump_reset(); vb._gun_release("test"); vb.rit = ""
	free_hands.call(); far.call()
	vb.rit = "beer_wait"
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, -3.5, 0.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("B5 during the pause after racking: gun state=", vb.gun_state, " (want 0)")
	vb.rit = ""; free_hands.call(); far.call()
	vb.rit = "beer_rack"; vb.rit_hand = lh; lh.grip_sq = true
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, -3.5, 0.0))
	rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2)
	print("B6 while the pump is being pulled on the table: gun state=", vb.gun_state, " (want 0)")
	vb.rit_hand = null; vb.rit = ""; free_hands.call(); far.call()
	# ---- S: how the saw, the phone and the inverter sit in the fist
	var swi = mk_item(spawn, "handsaw", Vector3(5.0, 0.0, -4), Vector3(5.2, 0.4, 1.1), Vector3(0.5, 0, 0))
	im.items_dynamicInteractionArray = [swi[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(5.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	var fwd_s: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	print("S1 saw: carried=", vb.item_br != null, " item axis forward=", fwd_s.snapped(Vector3.ONE * 0.01), " (want -1,0,0) grasp frac x=", snappedf((vb.item_grasp.x - vb.item_loc.position.x) / vb.item_loc.size.x, 0.01), " (want 0.82)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	swi[0].queue_free()
	var inv = mk_item(spawn, "inverter", Vector3(8.0, 0.0, -4), Vector3(2.2, 0.5, 1.3), Vector3(0, 0, 0))
	var dial := MeshInstance3D.new(); dial.name = "inverter dial"; var dm := CylinderMesh.new(); dm.top_radius = 0.3; dm.bottom_radius = 0.3; dm.height = 0.1; dial.mesh = dm
	inv[0].add_child(dial); dial.position = Vector3(0.6, 0.3, 0.0)
	im.items_dynamicInteractionArray = [inv[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(8.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	var fwd_i: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	var gfx: float = (vb.item_grasp.x - vb.item_loc.position.x) / vb.item_loc.size.x
	print("I1 inverter, dial on the +x half: carried=", vb.item_br != null, " forward=", fwd_i.snapped(Vector3.ONE * 0.01), " (want 1,0,0) grasp frac x=", snappedf(gfx, 0.01), " (want 0.12: the end away from the dial)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	dial.position = Vector3(-0.6, 0.3, 0.0)
	put_reach.call(lh, Vector3(8.0, 0.5, -4)); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2); step.call(30)
	var fwd_i2: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	var gfx2: float = (vb.item_grasp.x - vb.item_loc.position.x) / vb.item_loc.size.x
	print("I2 dial on the -x half: forward=", fwd_i2.snapped(Vector3.ONE * 0.01), " (want -1,0,0) grasp frac x=", snappedf(gfx2, 0.01), " (want 0.88)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	# the dial: take it with the other hand, then the hand stays on it
	put_reach.call(rh, Vector3(8.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	vb.item_t = 1.0
	var dw: Vector3 = dial.global_position
	put_reach.call(lh, dw); lh.grip_sq = false; step.call(3)
	print("I2z before squeeze: lh.holding=", lh.holding, " item_hand=", vb.item_hand.side if vb.item_hand != null else "none", " inv_hand=", vb.inv_hand, " gun_state=", vb.gun_state, " dist=", vb._point_box_dist(lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws), vb._node_world_aabb(vb.inv_dial, true)) / ws if vb.inv_dial != null else -1.0)
	lh.grip_sq = true
	for zi in 3:
		step.call(1)
		print("I2y frame ", zi, " lh.holding=", lh.holding, " inv_hand=", vb.inv_hand, " rit_hand2=", vb.rit_hand2 != null, " angle=", vb.inv_angle)
	print("I3a item hand=", vb.item_hand.side if vb.item_hand != null else "none")
	print("I3 dial taken: ", vb.inv_hand == lh, " (want true) DBG inv_hand=", vb.inv_hand, " rit_hand2=", vb.rit_hand2 == lh, " angle=", vb.inv_angle, " item_t=", vb.item_t, " down=", vb.inv_down, " sq=", lh.grip_sq, " zone=", vb.TITEM_ZONES.get("inverter"), " dial=", vb.inv_dial != null, " carried=", vb.item_br != null, " lh.holding=", lh.holding, " was_active=", lh.was_active, " dist=", (vb._point_box_dist(lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws), vb._node_world_aabb(dial, true)) / ws) if vb.inv_dial != null else -1.0)
	if vb.inv_hand == lh:
		var reach0: Vector3 = lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
		put_reach.call(lh, reach0 + Vector3(1.5, 0.0, 0.0))
		for zi in 2:
			lh.visual.transform = Transform3D(Basis.from_scale(Vector3.ONE * ws), Vector3.ZERO)
			step.call(1)
		var reach1: Vector3 = lh.grip.global_transform * (Vector3(0.0, 0.0, -0.05) * ws)
		var wantp: Vector3 = vb.inv_dial.global_transform * vb.inv_grab_loc
		var vis_reach: Vector3 = lh.visual.global_position + (reach1 - lh.grip.global_position)
		print("I4 hand moved 1.5 away: the hand's visual sits on the dial point: off by ", snappedf((lh.visual.global_position - lh.grip.global_position - (wantp - reach1)).length(), 0.001), " (want 0)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	inv[0].queue_free()
	# ---- K: the open pack itself to the mouth
	var pk = mk_item(spawn, "cigarettes", Vector3(2.0, 0.0, -4), Vector3(1.0, 1.6, 0.6), Vector3(0, 0, 0))
	var lid := MeshInstance3D.new(); lid.name = "cigarette box_lid"; lid.mesh = BoxMesh.new(); pk[0].add_child(lid)
	var cg := MeshInstance3D.new(); cg.name = "cigarette box_cigarette"; var cgm := BoxMesh.new(); cgm.size = Vector3(0.1, 1.0, 0.1); cg.mesh = cgm; pk[0].add_child(cg)
	im.items_dynamicInteractionArray = [pk[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	vb.cig_pk_state = 1; vb.cig_pk_anim = 1.0
	step.call(30)
	var mouth: Vector3 = vb._mouth_point()
	var cbx: AABB = vb._node_world_aabb(vb.cig_pk_cig, true)
	var shift: Vector3 = mouth - cbx.get_center()
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + shift)
	step.call(2)
	var cbx2: AABB = vb._node_world_aabb(vb.cig_pk_cig, true)
	print("K00 DBG cig-to-mouth dist after the move: ", snappedf(cbx2.get_center().distance_to(mouth) / ws, 0.001), " m (limit ", vb.CIG_MOUTH_M, ")")
	var healed := false
	for i in 40:
		step.call(1)
		if vb.item_br == null:
			healed = true
			break
	print("K0 DBG state=", vb.cig_pk_state, " cig=", vb.cig_pk_cig != null, " carried=", vb.item_br != null, " rit_t ", vb.rit_drink, " name=", vb.item_name, " hint ", vb.hint_label.text)
	print("K1 open pack held so that the cigarette is at the mouth: smoked=", healed, " (want true) burning=", vb.cig_smoke != null)
	free_hands.call(); far.call()
	# ---- P: the paper letters
	var scn: Node3D = scene
	# the god form
	var rf := Node3D.new(); rf.name = "release form_god"; scn.add_child(rf)
	var gform := MeshInstance3D.new(); gform.name = "release form1_001"; var gfm := BoxMesh.new(); gfm.size = Vector3(2.0, 0.05, 3.0); gform.mesh = gfm; rf.add_child(gform)
	gform.global_transform = Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(80)), Vector3(0, 2.5, -4))
	var gan := AnimationPlayer.new(); gan.name = "animator_god release form"; rf.add_child(gan)
	var galib := AnimationLibrary.new(); var gaa := Animation.new(); gaa.length = 3.0; galib.add_animation("grab form", gaa); gan.add_animation_library("", galib)
	gan.play("grab form")
	vb.pp_god_done = false; vb.pp_scene = scn
	vb._paper_update(0.016)
	print("P1 god form just came up: nothing yet, kind='", vb.pp_kind, "' (want empty) seen timer started=", vb.pp_seen_ms >= 0, " (want true)")
	OS.delay_msec(950)
	vb._paper_update(0.016)
	print("P2 after a second: kind=", vb.pp_kind, " (want god) original hidden=", gform.transparency, " (want 1) copy=", vb.pp_root != null, " slowed=", Engine.time_scale, " (want ", vb.GUN_HOLD_TS, ")")
	for i in 40:
		vb._paper_tick(0.016 * Engine.time_scale)
	var cam_p: Vector3 = vb.xr_cam.global_position
	var cpos: Vector3 = vb.pp_root.global_transform * vb.pp_c
	var nrm: Vector3 = (vb.pp_root.global_transform.basis * vb.pp_f).normalized()
	print("P3 floating in front: distance to head=", snappedf(cpos.distance_to(cam_p) / ws, 0.01), " m (want ~0.43) front faces you=", snappedf(nrm.dot((cam_p - cpos).normalized()), 0.01), " (want ~1) longest side=", snappedf(vb.pp_size[0] * vb.pp_k / ws, 0.01), " .. ", snappedf(vb.pp_size[2] * vb.pp_k / ws, 0.01), " m")
	# take it
	put_reach.call(rh, cpos); rh.grip_sq = false; vb._paper_tick(0.016 * Engine.time_scale); vb.pp_t = 1.0
	rh.grip_sq = true; vb._paper_tick(0.016 * Engine.time_scale)
	print("P4 taken: hand=", vb.pp_hand == rh, " (want true) holding=", rh.holding, " (want true)")
	for i in 60:
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.3 * ws, 1.6, -0.3 * ws) if false else Vector3(0.2, 1.4, -0.4) * 1.0)
		vb._paper_tick(0.016 * Engine.time_scale)
	var cp2: Vector3 = vb.pp_root.global_transform * vb.pp_c
	print("P5 in the fist: paper centre ", snappedf(cp2.distance_to(rh.grip.global_position) / ws, 0.001), " m from the hand (want about ", snappedf(0.04 + 0.38 * 0.0, 0.01), "+half a sheet), hand y=", snappedf(rh.grip.global_position.y, 0.01))
	rh.grip_sq = false; vb._paper_tick(0.016 * Engine.time_scale)
	print("P6 hand opened: kind='", vb.pp_kind, "' (want empty) time back to normal=", Engine.time_scale, " (want 1) hand free=", not rh.holding, " fx entries=", vb.fx_list.size())
	free_hands.call(); far.call()
	# a god form nobody takes
	gform.transparency = 0.0
	vb.pp_god_done = false
	vb._paper_begin("god", gform)
	vb.pp_t = 25.0
	vb._paper_tick(0.016 * Engine.time_scale)
	print("P7 nobody takes it: ended=", vb.pp_kind == "", " (want true) time=", Engine.time_scale, " (want 1)")
	# the waiver
	var wvm := MeshInstance3D.new(); wvm.name = "release form on table"; var wbm := BoxMesh.new(); wbm.size = Vector3(3.0, 0.06, 4.0); wvm.mesh = wbm; scn.add_child(wvm)
	wvm.global_position = Vector3(6.0, 0.1, -2.0)
	var wbr = load("@MOCKS@/mock_branch2.gd").new(); wbr.interactionAlias = "release form on table"; wvm.add_child(wbr)
	var nm = load("@MOCKS@/mock_nm32.gd").new(); scn.add_child(nm)
	nm.parent_waiver = wvm; nm.intrbranch_waiver = wbr
	vb.nm_sign = nm; vb.nm_locked = false
	vb.pp_god_done = true
	print("W0 fingertip on the waiver is off: ", vb._is_finger(wbr) == false, " (want true)")
	far.call()
	vb.pp_down.clear()
	put_reach.call(rh, Vector3(6.0, 0.5, -2.0)); rh.grip_sq = false; vb._paper_update(0.016)
	var framed_w := false
	for pb in vb.poke_boxes:
		if pb is AABB:
			framed_w = true
	rh.grip_sq = true; vb._paper_update(0.016)
	print("W1 squeezed next to the waiver: kind=", vb.pp_kind, " (want waiver) framed first=", framed_w, " hand=", vb.pp_hand == rh, " (want true) game not called yet=", inter.pressed.has("release form on table") == false, " (want true) original hidden=", wvm.transparency, " (want 1)")
	for i in 40:
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, vb.xr_cam.global_position + Vector3(0.2, -0.6, -0.35) * ws)
		vb._paper_tick(0.016)
	print("W2 held low: fired=", vb.pp_fired, " (want false)")
	var ctr: Vector3 = vb.pp_root.global_transform * vb.pp_c
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, vb.xr_cam.global_position + Vector3(0.0, -0.1, -0.15) * ws)
	for i in 60:
		vb._paper_tick(0.016)
		if vb.pp_fired:
			break
	print("W3 brought up to the eyes: fired=", vb.pp_fired, " (want true) game's pick-up called=", inter.pressed.has("release form on table"), " (want true)")
	rh.grip_sq = false; vb._paper_tick(0.016)
	print("W4 hand opened after reading: ended=", vb.pp_kind == "", " (want true) falls=", vb.fx_list.size() > 0, " original still hidden (until the game is done)=", wvm.transparency, " (want 1)")
	free_hands.call(); far.call()
	# put back before reading
	wvm.transparency = 0.0
	vb.pp_hid = {}
	vb.pp_down.clear()
	put_reach.call(rh, Vector3(6.0, 0.5, -2.0)); rh.grip_sq = false; vb._paper_update(0.016); rh.grip_sq = true; vb._paper_update(0.016)
	var kind0: String = vb.pp_kind
	for i in 10:
		vb._paper_tick(0.016)
	rh.grip_sq = false; vb._paper_tick(0.016)
	print("W5 taken and let go at once: kind was ", kind0, " now '", vb.pp_kind, "' (want empty) original back=", wvm.transparency, " (want 0) game called again=", inter.pressed.count("release form on table"), " (want 1 in total)")
	free_hands.call(); far.call()
	# the name is in
	vb.pp_down.clear()
	put_reach.call(rh, Vector3(6.0, 0.5, -2.0)); rh.grip_sq = false; vb._paper_update(0.016); rh.grip_sq = true; vb._paper_update(0.016)
	vb.nm_locked = true
	vb._paper_tick(0.016)
	print("W6 the name went in: ended=", vb.pp_kind == "", " (want true)")
	free_hands.call(); far.call()
	# fallback
	vb.nm_locked = false; vb.pp_fb = false; vb.pp_wv_wait = 41.0
	far.call()
	vb._paper_update(0.016)
	print("W7 nobody picked it up for 40 s: fingertip works again=", vb._is_finger(wbr), " (want true)")
	quit()
