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
	var _tdc := DirAccess.make_dir_recursive_absolute('user://vr_mod'); DirAccess.remove_absolute(vb.TUT_PATH)
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
	var gun_main_n: Node3D = scene.find_child("shotgun main parent", true, false)
	# ---- H: the inverter with the dealer's hand shape (iteration 34: its own numbers, mirrored for the right hand)
	var dhm := MeshInstance3D.new(); dhm.name = "dealer hand left_inverter"; var dbm := BoxMesh.new(); dbm.size = Vector3(10, 4, 4); dhm.mesh = dbm; dhm.visible = false; scene.add_child(dhm)
	var inv = mk_item(spawn, "inverter", Vector3(8.0, 0.0, -4), Vector3(2.2, 0.5, 1.3), Vector3(0, 0, 0))
	var dial := MeshInstance3D.new(); dial.name = "inverter dial"; var dm := CylinderMesh.new(); dm.top_radius = 0.3; dm.bottom_radius = 0.3; dm.height = 0.1; dial.mesh = dm
	inv[0].add_child(dial); dial.position = Vector3(0.0, 0.3, 0.0)
	im.items_dynamicInteractionArray = [inv[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(8.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(30)
	var gbr: Basis = rh.grip.global_transform.basis.orthonormalized()
	var pose_r: String = vb._choose_pose(rh)
	var ipm: MeshInstance3D = rh.poses.get("dealer_inverter")
	var p_in_grip: Vector3 = rh.visual.global_transform * (ipm.transform * vb.DH_INV_P) if ipm != null else Vector3(99, 99, 99)
	var gr_in_grip: Vector3 = inv[0].global_transform * vb.item_grasp
	print("H1 right hand: dealer pose=", vb.inv_dealer, " (want true) pose='", pose_r, "' (want dealer_inverter) palm point at the grip=", snappedf(p_in_grip.distance_to(rh.grip.global_position) / ws, 0.0001), " (want 0) the item's grasp point at the grip=", snappedf(gr_in_grip.distance_to(rh.grip.global_position) / ws, 0.0001), " (want 0)")
	var dial_dir: Vector3 = (inv[0].global_transform.basis * Vector3.UP).normalized()
	var fing_r: Vector3 = ((rh.visual.global_transform.basis * ipm.transform.basis) * Vector3(-1, 0, 0)).normalized()
	var thumb_r: Vector3 = ((rh.visual.global_transform.basis * ipm.transform.basis) * vb.DH_INV_T).normalized()
	print("H2 right hand: dial dir in grip frame=", (gbr.inverse() * dial_dir).snapped(Vector3.ONE * 0.01), " (want x<0: towards the other hand)  fingers (mesh -x) in grip frame=", (gbr.inverse() * fing_r).snapped(Vector3.ONE * 0.01), " (want 0,0,-1)  thumb=", (gbr.inverse() * thumb_r).snapped(Vector3.ONE * 0.01), " mirror child det=", snappedf(ipm.transform.basis.determinant(), 0.01), " (want -1)")
	var hand_det: float = rh.visual.global_transform.basis.determinant()
	print("H3 hand visual is proper (det>0)=", hand_det > 0.0, " scale along x=", snappedf(rh.visual.global_transform.basis.x.length() / ws, 0.0001), " (want ", snappedf(vb.item_scale.x / vb.DH_INV_UNIT / ws, 0.0001), ") INV_GO=", vb.INV_GO, " (want 1.07)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	print("H4 after: dealer pose off=", not vb.inv_dealer, " (want true)  pose back to=", vb._choose_pose(rh), " (want not dealer_inverter) key cleared=", vb.dealer_key == "", " (want true)")
	put_reach.call(lh, Vector3(8.0, 0.5, -4)); lh.grip_sq = false; step.call(3); lh.grip_sq = true; step.call(2); step.call(30)
	var gbl: Basis = lh.grip.global_transform.basis.orthonormalized()
	var dial_dir_l: Vector3 = (inv[0].global_transform.basis * Vector3.UP).normalized()
	var lpm: MeshInstance3D = lh.poses.get("dealer_inverter")
	var fing_l: Vector3 = ((lh.visual.global_transform.basis * lpm.transform.basis) * Vector3(-1, 0, 0)).normalized()
	print("H5 left hand: dial dir in grip frame=", (gbl.inverse() * dial_dir_l).snapped(Vector3.ONE * 0.01), " (want x>0)  mesh not mirrored=", lpm != null and lpm.transform == Transform3D.IDENTITY, " fingers=", (gbl.inverse() * fing_l).snapped(Vector3.ONE * 0.01), " (want 0,0,-1) grasp point at the grip=", snappedf((inv[0].global_transform * vb.item_grasp).distance_to(lh.grip.global_position) / ws, 0.0001), " (want 0)")
	# the dial: the other (right) hand turns it through INV_GO
	vb.item_t = 1.0
	var dw: Vector3 = dial.global_position
	put_reach.call(rh, dw); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(3)
	print("H6 dial taken by the right hand: ", vb.inv_hand == rh, " (want true)")
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	inv[0].queue_free()
	# ---- M: the medicine: opening end forward, easy flick
	var md = mk_item(spawn, "expired medicine", Vector3(2.0, 0.0, -4), Vector3(2.8, 0.4, 1.9), Vector3(0, 0, 0))
	var bl := MeshInstance3D.new(); bl.name = "expired medicine blister pack"; var blm := BoxMesh.new(); blm.size = Vector3(0.9, 0.3, 1.7); bl.mesh = blm
	md[0].add_child(bl); bl.position = Vector3(-0.06, 0.0, 0.0)
	var pl := MeshInstance3D.new(); pl.name = "expired medicine cap"; var plm := BoxMesh.new(); plm.size = Vector3(0.3, 0.2, 0.3); pl.mesh = plm; bl.add_child(pl)
	im.items_dynamicInteractionArray = [md[1]]
	vb.shape_cache.clear(); step.call(4)
	put_reach.call(rh, Vector3(2.0, 0.5, -4)); rh.grip_sq = false; step.call(3); rh.grip_sq = true; step.call(2); step.call(40)
	var fwd_m: Vector3 = vb.item_rb.inverse() * Vector3(0, 0, -1)
	print("M1 medicine: carried=", vb.item_br != null, " forward=", fwd_m.snapped(Vector3.ONE * 0.01), " (want -1,0,0: the lid end points away from you)")
	var sp0: Vector3 = bl.position
	vb.flick_w["right"] = 12.0; vb.flick_t["right"] = 9.0
	step.call(2)
	vb.flick_w["right"] = 0.0
	step.call(25)
	print("M2 the box hand flicks (12 rad/s decays to about 6 by the check: below the old limit 7.5): strip out=", vb.med_state, " (want 1) moved=", (bl.position - sp0).snapped(Vector3.ONE * 0.01), " (want about -2.16 in x)")
	put_reach.call(lh, pl.global_position); lh.grip_sq = false; step.call(3)
	vb.flick_w["right"] = 12.0; vb.flick_t["right"] = 9.0; step.call(2)
	vb.flick_w["right"] = 0.0; step.call(3)
	print("M3 a flick again: the pill is in the other hand: state=", vb.med_state, " (want 2 or 3) hand busy=", lh.holding)
	vb._titem_end(true, "test"); free_hands.call(); far.call()
	md[0].queue_free()
	# ---- G: after the shot the gun stays in the hand when the turn goes on
	var an := AnimationPlayer.new(); scene.add_child(an)
	var alib := AnimationLibrary.new(); var pa := Animation.new(); pa.length = 3.0; alib.add_animation("player place on table after eject", pa)
	var ea := Animation.new(); ea.length = 3.0
	var et1 := ea.add_track(Animation.TYPE_METHOD); ea.track_set_path(et1, NodePath("shell parent_ejecting player side/shell eject manager")); ea.track_insert_key(et1, 1.6, {"method": "BeerEjection_player", "args": []})
	var et2 := ea.add_track(Animation.TYPE_AUDIO); ea.track_set_path(et2, NodePath("rack shotgun")); ea.audio_track_insert_key(et2, 1.0, wav)
	var et3 := ea.add_track(Animation.TYPE_VALUE); ea.track_set_path(et3, NodePath("shotgun main parent:visible")); ea.track_insert_key(et3, 0.0, true)
	alib.add_animation("player eject shell", ea); an.add_animation_library("", alib)
	sg.animator_shotgun = an
	var cases := [["blank at yourself, 2 shells left", "self", false, false, 3, true], ["live at yourself", "self", true, false, 3, false], ["blank at the dealer", "dealer", false, false, 3, false], ["blank at yourself, barrel cut", "self", false, true, 3, false], ["blank at yourself, last shell", "self", false, false, 1, false]]
	var gi := 0
	for cs in cases:
		gi += 1
		free_hands.call(); far.call()
		vb._gun_release("test")
		sg.collider_shotgun.collision_layer = 1; vb.gun_col_seen = true
		spw.sequenceArray = ["blank", "live", "blank"].slice(0, int(cs[4]))
		rm.barrelSawedOff = bool(cs[3])
		rh.grip_sq = false; step.call(3); vb.gun_down.clear()
		put_reach.call(rh, vb._gun_xf() * Vector3(0.0, -2.0, 0.0)); step.call(3)
		rh.grip_sq = true; step.call(3)
		var took: bool = vb.gun_state == 1
		vb.gun_aim = str(cs[1]); vb.gun_locked = true
		vb.gun_game = true; vb.gun_state = 2; vb.gun_t = 0.0; vb.gun_bang_prev = false
		sg.collider_shotgun.collision_layer = 0
		var spk = sg.speaker_live if bool(cs[2]) else sg.speaker_blank
		spk.playing = true
		step.call(3)
		spk.playing = false
		an.play("player place on table after eject")
		step.call(3)
		var kept: bool = vb.gun_keep
		vb.gun_after = 2.0
		sg.collider_shotgun.collision_layer = 1
		step.call(3)
		var holding_again: bool = vb.gun_state == 1 and vb.gun_prop != null and vb.gun_hand == rh and rh.holding
		print("G", gi, " ", cs[0], ": took=", took, " keep=", kept, " (want ", cs[5], ") state after=", vb.gun_state, " in hand again=", holding_again, " (want ", cs[5], ") game gun hidden=", not gun_main_n.visible, " game told for the next shot=", vb.gun_game, " (want false if kept)")
		an.stop()
	# ---- R: a kept gun must be racked before the next shot
	free_hands.call(); far.call(); vb._gun_release("test")
	sg.collider_shotgun.collision_layer = 1; vb.gun_col_seen = true
	spw.sequenceArray = ["blank", "live", "blank"]; rm.barrelSawedOff = false
	rh.grip_sq = false; step.call(3); vb.gun_down.clear()
	put_reach.call(rh, vb._gun_xf() * Vector3(0.0, -2.0, 0.0)); step.call(3)
	rh.grip_sq = true; step.call(3)
	vb.gun_aim = "self"; vb.gun_locked = true; vb.gun_game = true; vb.gun_state = 2; vb.gun_t = 0.0; vb.gun_bang_prev = false
	sg.collider_shotgun.collision_layer = 0
	sg.speaker_blank.playing = true; step.call(3); sg.speaker_blank.playing = false
	an.play("player eject shell"); step.call(3)
	print("R0 kept gun: the game's shell+rack tracks off=", (not ea.track_is_enabled(0)) and (not ea.track_is_enabled(1)) and ea.track_is_enabled(2), " (want true) held-back count=", vb.gun_trk_off.size(), " (want 2)")
	an.seek(1.7, true); step.call(3)
	print("R0b after 1.6 s: shell booked=", vb.gun_eject_done, " (want true) game's ejection called=", em.count, " (want 1) sequence left=", spw.sequenceArray.size(), " (want 2) shell shown=", holder.visible, " (want false) pending=", vb.gun_shell_pending, " (want true)")
	an.play("player place on table after eject"); step.call(3)
	vb.gun_after = 2.0; sg.collider_shotgun.collision_layer = 1; step.call(3)
	print("R0c tracks back on=", ea.track_is_enabled(0) and ea.track_is_enabled(1), " (want true) trk anim cleared=", vb.gun_trk_anim == null, " (want true)")
	print("R1 kept: state=", vb.gun_state, " (want 1) need rack=", vb.gun_need_rack, " (want true)")
	vb.gun_aim = "dealer"; vb.gun_locked = true; inter.iw.clear()
	vb._gun_trigger(rh)
	print("R2 trigger before racking: still held=", vb.gun_state == 1, " (want true) game told=", inter.iw, " (want empty)")
	var rpump = null
	for e in vb.gun_pairs:
		if e[0] == pump: rpump = e[1]
	var rbox: AABB = vb._node_world_aabb(rpump, true)
	var gsc: float = vb.gun_prop.global_transform.basis.y.length()
	var bkh: Vector3 = (vb.gun_prop.global_transform.basis * Vector3(0, -1, 0)).normalized()
	var fx0: int = vb.fx_list.size()
	lh.grip_sq = false; vb.rit_down.clear(); put_reach.call(lh, rbox.get_center()); step.call(3)
	lh.grip_sq = true; step.call(2)
	for i in 40:
		put_reach.call(lh, rbox.get_center() + bkh * (float(i) / 40.0 * 1.26 * gsc)); step.call(1)
	for i in 40:
		put_reach.call(lh, rbox.get_center() + bkh * (1.0 - float(i) / 40.0) * 1.26 * gsc); step.call(1)
	print("R3 racked: need rack=", vb.gun_need_rack, " (want false) shell flew out=", vb.fx_list.size() > fx0, " (want true) pending=", vb.gun_shell_pending, " (want false) tutorial rack done=", vb.tut_seen.has("rack"), " (want true)")
	lh.grip_sq = false; step.call(5)
	vb.gun_aim = "dealer"; vb.gun_locked = true; vb.gun_state = 1; inter.iw.clear()
	vb._gun_trigger(rh)
	print("R4 trigger after racking: game told=", inter.iw, " (want [shotgun])")
	vb._gun_release("test"); free_hands.call(); far.call()
	quit()
