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
	# ---- gun setup
	var take_gun = func(hand):
		free_hands.call(); far.call(); vb._gun_release("test")
		sg.collider_shotgun.collision_layer = 1; vb.gun_col_seen = true
		spw.sequenceArray = ["blank", "live", "blank"]; rm.barrelSawedOff = false
		hand.grip_sq = false; step.call(3); vb.gun_down.clear()
		put_reach.call(hand, vb._gun_xf() * Vector3(0.0, -2.0, 0.0)); step.call(3)
		hand.grip_sq = true; step.call(3)
	take_gun.call(rh)
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-5.0, 1.5, 2.0)); lh.grip_sq = false
	var cam_p: Vector3 = vb.xr_cam.global_position
	var mouth: Vector3 = vb._mouth_point()
	var aim_case = func(label: String, hand_off: Vector3, tgt: Vector3, err_deg: float, want: String):
		var hp: Vector3 = cam_p + hand_off * ws
		var dirv: Vector3 = (tgt - hp).normalized()
		if err_deg != 0.0:
			dirv = (Basis(Vector3.UP, deg_to_rad(err_deg)) * dirv).normalized()
		var bb := Basis.looking_at(dirv, Vector3.UP)
		rh.grip.global_transform = Transform3D(bb, hp)
		vb.gun_aim = ""; vb.gun_aim_t = 0.0; vb.gun_locked = false
		step.call(60)
		print("A ", label, ": aim='", vb.gun_aim, "' locked=", vb.gun_locked, " (want '", want, "') hand dist=", snappedf(hp.distance_to(cam_p) / ws, 0.01), " m")
	aim_case.call("1 mouth from 50 cm, below", Vector3(0.1, -0.35, -0.35), mouth, 0.0, "self")
	aim_case.call("2 mouth from 25 cm, 6 deg off", Vector3(0.05, -0.2, -0.15), mouth, 6.0, "self")
	aim_case.call("3 mouth from 25 cm, 12 deg off", Vector3(0.05, -0.2, -0.15), mouth, 12.0, "self")
	aim_case.call("4 hand at the chin 15 cm, barrel up into the mouth", Vector3(0.0, -0.14, -0.06), mouth, 0.0, "self")
	aim_case.call("5 from the cheek (20 cm right), across", Vector3(0.2, -0.05, -0.1), mouth, 0.0, "self")
	aim_case.call("6 muzzle ends at the lips, hand 40 cm low", Vector3(0.0, -0.4, -0.12), mouth, 4.0, "self")
	aim_case.call("4b muzzle in the mouth, hand 12 cm from the head", Vector3(0.0, -0.10, -0.07), mouth, 0.0, "self")
	aim_case.call("4c muzzle in the mouth, hand 22 cm low and forward", Vector3(0.02, -0.18, -0.13), mouth + Vector3(0, -0.02 * ws, 0), 8.0, "self")
	aim_case.call("4d barrel in the mouth from the right side, hand 30 cm out", Vector3(0.28, -0.12, -0.06), mouth, 5.0, "self")
	aim_case.call("4e hand 6 cm from the head (grip slid up to the pump), muzzle in the mouth", Vector3(0.0, -0.06, -0.04), mouth, 0.0, "self")
	aim_case.call("4f same, jittering 10 deg", Vector3(0.0, -0.10, -0.07), mouth, 10.0, "self")
	aim_case.call("7 straight ahead (not you)", Vector3(0.1, -0.3, -0.3), cam_p + Vector3(0.1, -0.3, -9.0) * ws, 0.0, "")
	aim_case.call("8 past the head, 40 cm to the side at 60 cm", Vector3(0.1, -0.3, -0.4), cam_p + Vector3(0.5 * 1.0, 0.0, 0.0) * ws + Vector3(0, 0, 0), 0.0, "")
	aim_case.call("9 forward from the hip (not you)", Vector3(0.2, -0.6, -0.2), cam_p + Vector3(0.0, 0.0, -8.0) * ws, 0.0, "")
	rh.grip_sq = false; step.call(4); vb._gun_release("test")
	quit()
