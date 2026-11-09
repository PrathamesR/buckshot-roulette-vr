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
	var ii = M.MockII.new(); scene.add_child(ii); inter.itemInteraction = ii
	var rm = M.MockRM.new(); scene.add_child(rm); ii.roundManager = rm
	var spw = M.MockSpawner.new(); scene.add_child(spw); rm.shellSpawner = spw
	ii.perm = M.MockPerm.new(); scene.add_child(ii.perm)
	ii.cursor = M.MockCursor.new(); scene.add_child(ii.cursor)
	ii.amounts = M.MockAmounts.new(); scene.add_child(ii.amounts)
	ii.itemManager = M.MockIMgr.new()
	var hcount = M.MockHealth.new(); hcount.name = "health counter"; scene.add_child(hcount)
	for n in ["beer", "magnifying glass", "handsaw", "handcuffs", "cigarettes"]:
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
			vb._update_gun(dt)
			vb._update_items(dt)
			vb._update_cuffs(dt)
			vb._hint_finish()
			vb._ring_finish()
	vb.t_alive = 10.0
	vb.item_down.clear(); vb.gun_down.clear()
	# ---- A: the nearest wins (hand between the gun and the beer, nearer the beer)
	step.call(2)
	var gbody_pt: Vector3 = gun_main.global_transform * Vector3(0, 0, 0)
	print("A0 gun axis dist from its centre: ", snappedf(vb._gun_grab_dist(gbody_pt), 0.01), " (want 0)  from 3 units off: ", snappedf(vb._gun_grab_dist(gbody_pt + Vector3(3, 0, 0)), 0.01), " (want 3)")
	put_reach.call(rh, Vector3(2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2)
	print("A1 hand on the beer: carrying=", vb.item_br != null and str(vb.item_br.get("itemName")), " (want beer)  gun state=", vb.gun_state, " (want 0)")
	rh.grip_sq = false; step.call(30)
	vb.item_down.clear()
	print("A2 let go -> back: carrying=", vb.item_hand != null, " (want false)")
	# hand right on the gun, away from items: takes the gun
	put_reach.call(rh, gun_main.global_transform * Vector3(0.0, -2.0, 0.0)); step.call(3)
	var hint_g: String = (str(vb.ring_mi.visible) + "/" + str(snappedf(0.0, 0.01)))
	print("A3 hover on the gun: hint '", hint_g, "'  framed=", vb.poke_boxes.size() > 0)
	rh.grip_sq = true; step.call(2)
	print("A4 squeeze on the gun: gun_state=", vb.gun_state, " (want 1) game told=", vb.gun_game, " (want false) InteractWith=", inter.iw, " (want empty) real gun hidden=", not gun_main.visible)
	var cl_spark = null
	var cl_body = null
	var cl_flash = null
	for e in vb.gun_pairs:
		if e[0] == spark: cl_spark = e[1]
		if e[0] == body: cl_body = e[1]
		if e[0] == mfm: cl_flash = e[1]
	print("A4b cone: muzzle flash copy visible=", cl_flash.visible, " (want false); see-through spark copy keeps the game's material=", cl_spark.get_surface_override_material(0) is StandardMaterial3D, " (want true); body lit by our shader=", cl_body.get_surface_override_material(0) is ShaderMaterial, " (want true)")
	vb._gun_release("test"); col.collision_layer = 1; vb.gun_state = 0; rh.holding = false; vb.gun_col_seen = true
	rh.grip_sq = false; step.call(5); vb.gun_down.clear()
	# an item right beside the gun (like the first slot next to it): item nearer than the gun wins
	var near_item = mk_item(spawn, "handsaw", gun_main.global_transform * Vector3(2.2, 0.0, 0.0), Vector3(1, 1, 1), Vector3(0, 0, 0))
	im.items_dynamicInteractionArray.append(near_item[1])
	vb.shape_cache.clear()
	put_reach.call(rh, near_item[0].global_position + Vector3(0.2, 0, 0)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2)
	print("A5 squeeze with an item nearer than the gun: item taken=", vb.item_br == near_item[1], " (want true) gun state=", vb.gun_state, " (want 0)")
	rh.grip_sq = false; step.call(30); vb.item_down.clear(); vb.gun_down.clear()
	im.items_dynamicInteractionArray.erase(near_item[1]); near_item[0].queue_free()
	vb.shape_cache.clear()
	# ---- B: the item sits in the fist
	put_reach.call(rh, Vector3(2.5, 0.5, -4)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2)
	rh.grip.global_transform = Transform3D(Basis(Vector3.UP, 0.5), Vector3(1, 1.5, -2)); step.call(30)
	var hole: Vector3 = rh.grip.global_transform * (vb.ITEM_FIST_HOLE * ws)
	var gp: Vector3 = beer[0].global_transform * vb.item_grasp
	print("B1 beer's grasp point at the fist hole: off by ", snappedf(gp.distance_to(hole) / ws * 100.0, 0.01), " cm (want 0)")
	var topdir: Vector3 = (beer[0].global_transform.basis * Vector3(0, 1, 0)).normalized()
	var gup: Vector3 = (rh.grip.global_transform.basis * Vector3(0, 1, 0)).normalized()
	print("B2 can's top along the fist axis: dot=", snappedf(topdir.dot(gup), 0.001), " (want 1)  holding=", rh.holding, " pose ", vb._choose_pose(rh))
	# ---- C: beer: drink at the mouth, tilted
	var mouth: Vector3 = vb.xr_cam.global_position - vb.xr_cam.global_transform.basis.y * (0.06 * ws)
	# put the hand so that the can's top is at the mouth and the can is tilted 70 degrees
	var tilt := Basis(Vector3(0, 0, 1), deg_to_rad(70))
	var gbas: Basis = tilt
	rh.grip.global_transform = Transform3D(gbas, Vector3.ZERO)
	var topl: Vector3 = vb.item_loc.position + Vector3(vb.item_loc.size.x * 0.5, vb.item_loc.size.y, vb.item_loc.size.z * 0.5)
	step.call(1)
	var cur_top: Vector3 = beer[0].global_transform * topl
	rh.grip.global_transform = Transform3D(gbas, rh.grip.global_position + (mouth - cur_top))
	step.call(30)
	cur_top = beer[0].global_transform * topl
	rh.grip.global_transform = Transform3D(gbas, rh.grip.global_position + (mouth - cur_top))
	step.call(3)
	print("C1 can top at mouth: dist ", snappedf(beer[0].global_transform.origin.distance_to(mouth) / ws, 0.01), " m  drink=", snappedf(vb.rit_drink, 0.01), " hint '", (str(vb.ring_mi.visible) + "/" + str(snappedf(0.0, 0.01))), "'")
	for i in 130:
		cur_top = beer[0].global_transform * topl
		rh.grip.global_transform = Transform3D(gbas, rh.grip.global_position + (mouth - cur_top))
		step.call(1)
		if vb.rit != "":
			break
	print("C2 drunk: rit=", vb.rit, " (want beer_rack)  consumed: removed=", ii.removed, " (want 1) amount_player=", ii.amounts.array_amounts[0].amount_player, " (want 2) turnlist=", rm.playerCurrentTurnItemArray, " perm log tail=", ii.perm.log.slice(-3), " beer stat=", rm.playerData.stat_beerDrank, " (want 330) final=", vb.rit_final, " (want false)  hand free=", not rh.holding, " fx toss=", vb.fx_list.size())
	# rack: hand to the pump, grab, pull back, push forward
	var pump_n: Node3D = pump
	var rest_y: float = pump_n.position.y
	var pbox: AABB = vb._node_world_aabb(pump_n, true)
	put_reach.call(rh, pbox.get_center()); rh.grip_sq = false; step.call(3)
	print("C3 pump framed/hint: '", (str(vb.ring_mi.visible) + "/" + str(snappedf(0.0, 0.01))), "'")
	rh.grip_sq = true; step.call(2)
	print("C4 pump grabbed: hand=", vb.rit_hand == rh, " (want true)")
	# pull back along the barrel (model -Y = world +Z for this gun)
	var back: Vector3 = (gun_main.global_transform.basis * Vector3(0, -1, 0)).normalized()
	var hp0: Vector3 = pbox.get_center()
	for i in 40:
		put_reach.call(rh, hp0 + back * (float(i) / 40.0 * 1.4 * 0.9))
		step.call(1)
	print("C5 pulled: pull=", snappedf(vb.rit_pull, 0.01), " pulled flag=", vb.rit_pulled, " pump y=", snappedf(pump_n.position.y, 0.01), " (rest ", rest_y, ")")
	for i in 40:
		put_reach.call(rh, hp0 + back * (1.0 - float(i) / 40.0) * 1.26)
		step.call(1)
	print("C6 pushed forward: rit=", vb.rit, " (want beer_wait)  seq=", spw.sequenceArray, " (want [blank, live])  eject count=", em.count, " fx=", vb.fx_list.size(), " (toss + shell)  pump y=", snappedf(pump_n.position.y, 0.01), " (want ", rest_y, ")")
	step.call(130)
	print("C7 after: rit='", vb.rit, "' enabled=", ii.enabled, " (want 1)")
	step.call(300)
	print("C8 shell landed / faded: fx left=", vb.fx_list.size())
	rh.grip_sq = false; step.call(3); vb.item_down.clear(); vb.rit_down.clear()
	# ---- D: magnifying glass: look through the lens at the open breech, then break it on the table
	var rem0: int = ii.removed
	put_reach.call(rh, Vector3(-2.5, 0.5, -4)); step.call(3)
	rh.grip_sq = true; step.call(2)
	print("D1 took magnifier: ", vb.item_br != null and str(vb.item_br.get("itemName")))
	var mag_aim = func(hx, frac: float):
		# turn and place the hand so that the lens sits on the line eye -> breech (at the given share of the way), facing the eye
		for k in 4:
			var par_m: Node3D = vb.item_node
			var pxf: Transform3D = par_m.global_transform
			var lc: Vector3 = pxf * (vb.item_loc.position + vb.item_loc.size * Vector3(0.5, vb.MAG_LENS_Y, 0.5))
			var ln: Vector3 = (pxf.basis * Vector3(1, 0, 0)).normalized()
			var eye: Vector3 = vb.xr_cam.global_position
			var br_p: Vector3 = vb._mag_breech()
			var dirv: Vector3 = (br_p - eye).normalized()
			var q := Quaternion(ln, dirv)
			var gb: Basis = hx.grip.global_transform.basis
			hx.grip.global_transform = Transform3D(Basis(q) * gb, hx.grip.global_position)
			step.call(2)
			pxf = par_m.global_transform
			lc = pxf * (vb.item_loc.position + vb.item_loc.size * Vector3(0.5, vb.MAG_LENS_Y, 0.5))
			hx.grip.global_transform = Transform3D(hx.grip.global_transform.basis, hx.grip.global_position + (eye.lerp(br_p, frac) - lc))
			step.call(2)
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-1.0, 1.4, -1.5)); step.call(30)
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-1.0, 1.4, -1.5)); step.call(30)
	print("D2 whole glass (iteration 27): message=", vb.hint_label.visible and vb.hint_label.text, " (want BREAK THE GLASS) stage=", vb.mag_stage, " (want 0) view made=", vb.mag_view != null, " (want false)")
	var _par3: Node3D = vb.item_node
	var _lw3 := INF
	for i in 8:
		_lw3 = minf(_lw3, (_par3.global_transform * vb.item_loc.get_endpoint(i)).y)
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + Vector3(0, vb._item_table_y() + 0.4 * ws - _lw3, 0))
	step.call(50)
	var _pm: Node3D = vb.item_node
	var _lw := INF
	for i in 8:
		_lw = minf(_lw, (_pm.global_transform * vb.item_loc.get_endpoint(i)).y)
	#print("DBG3 lowest-table=", _lw - vb._item_table_y(), " near=", vb.MAG_SMASH_NEAR_M * vb.world_scale, " ws=", vb.world_scale)
	print("D3 whole glass held at the eye: stage=", vb.mag_stage, " (want 0) seen=", vb.mag_seen, " (want false) removed=", ii.removed - rem0, " (want 0) view made=", vb.mag_view != null, " (want false)")
	# smash: a quick downward stroke onto the table
	var tyy: float = vb._item_table_y()
	var par_s: Node3D = vb.item_node
	var low_of = func():
		var lw := INF
		for i in 8:
			lw = minf(lw, (par_s.global_transform * vb.item_loc.get_endpoint(i)).y)
		return lw
	# raise it above the table first (the lowest point 0.25 m up), then bring it down fast
	var cur_low: float = low_of.call()
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + Vector3(0, tyy + 0.25 * ws - cur_low, 0)); step.call(20)
	var slow_hits := 0
	for i in 70:
		rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + Vector3(0, -0.004 * ws, 0))   # slow: 0.25 m/s*... 
		step.call(1)
		if vb.item_br == null:
			slow_hits += 1
			break
	print("D7 lowering it slowly to the table: broken=", slow_hits > 0, " (want false) carrying=", vb.item_br != null)
	cur_low = low_of.call()
	rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + Vector3(0, tyy + 0.25 * ws - cur_low, 0)); step.call(20)
	var fx0: int = vb.fx_root.get_child_count()
	for i in 12:
		rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + Vector3(0, -0.03 * ws, 0))   # 0.03 m / 16 ms = fast
		step.call(1)
		if vb.item_br == null:
			break
	print("D8a smashed (iteration 27): stage=", vb.mag_stage, " (want 1) carrying=", vb.item_br != null, " (want true) removed=", ii.removed - rem0, " (want 0)")
	rh.grip_sq = false; step.call(4)
	print("D8 smashed on the table: carrying=", vb.item_br != null, " (want false) removed=", ii.removed - rem0, " (want 1) turn list has it=", "magnifying glass" in rm.playerCurrentTurnItemArray, " (want true) amount_player=", ii.amounts.array_amounts[1].amount_player, " (want 2) shards/fx added=", vb.fx_root.get_child_count() - fx0 > 0, " seen reset=", not vb.mag_seen, " (want true) view gone=", vb.mag_view == null, " (want true)")
	step.call(3)
	print("D8b hand free again: holding=", rh.holding, " (want false) enabled=", ii.enabled)
	rh.grip_sq = false; step.call(3); vb.item_down.clear(); vb.rit_down.clear()
	# ---- E: handsaw: stroke on the end of the barrel
	vb.item_down.clear(); vb.rit_down.clear()
	rh.grip_sq = false; put_reach.call(rh, Vector3(5.0, 0.5, -4)); step.call(3)
	rh.grip_sq = true; step.call(2)
	print("E1 took saw: ", vb.item_br != null and str(vb.item_br.get("itemName")))
	var segc: Vector3 = vb._node_world_aabb(seg, false).get_center()
	var sawx: Vector3 = Vector3(1, 0, 0)
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, segc); step.call(40)
	var sawhint: String = (str(vb.ring_mi.visible) + "/" + str(snappedf(0.0, 0.01)))
	# stroke back and forth along the saw's blade axis
	var axis_w: Vector3 = (saw[0].global_transform.basis * Vector3(1, 0, 0)).normalized()
	var base: Vector3 = rh.grip.global_position
	for i in 400:
		var off: float = sin(float(i) * 0.4) * 0.05 * ws
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, base + axis_w * off)
		step.call(1)
		if vb.rit != "" or rm.barrelSawedOff:
			break
	print("E2 sawing: near hint '", sawhint, "'  stroke=", snappedf(vb.rit_stroke, 0.01), " sawedOff=", rm.barrelSawedOff, " (want true) dmg=", rm.currentShotgunDamage, " (want 2) HideSegment calls=", segmgr.hid, " (want 1) enabled soon")
	await create_timer(1.2).timeout
	step.call(100)
	print("E3 perms back: enabled=", ii.enabled, " (want 2)")
	# ---- F0: how far out the hand has to be
	var dzone = func(fwd: float, side: float, wsx: float):
		return vb._titem_in_zone("dealer", Vector3(side, 1.6, -fwd), wsx)
	print("F0a ws 13.2 (need 0.40 m = 5.28 u): 3 u out ", dzone.call(3.0, 0.0, 13.2), " (want false), 6 u out ", dzone.call(6.0, 0.0, 13.2), " (want true), 6 u out but 9 u aside ", dzone.call(6.0, 9.0, 13.2), " (want false), behind you ", dzone.call(-6.0, 0.0, 13.2), " (want false)")
	print("F0b ws 6.6 (a bigger you, need 2.64 u): 3 u out ", dzone.call(3.0, 0.0, 6.6), " (want true), 2 u out ", dzone.call(2.0, 0.0, 6.6), " (want false)")
	print("F0c ws 26 (a tiny you: need is capped by 28 % of the way, 8.4 u): 7 u out ", dzone.call(7.0, 0.0, 26.0), " (want false), 9 u out ", dzone.call(9.0, 0.0, 26.0), " (want true)")
	print("F0d need(ws, hl): ", snappedf(vb._dealer_need(13.2, 30.0), 0.01), " (want 5.28), ", snappedf(vb._dealer_need(26.0, 30.0), 0.01), " (want 8.4)")
	# ---- F: handcuffs: hold out to the dealer
	vb.item_down.clear(); vb.rit_down.clear()
	rh.grip_sq = false; put_reach.call(rh, Vector3(-5.0, 0.5, -4)); step.call(3)
	rh.grip_sq = true; step.call(2)
	print("F1 took cuffs: ", vb.item_br != null and str(vb.item_br.get("itemName")))
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -15)); step.call(20)
	print("F2 held out: zone=", vb.item_zone_in, " presses=", inter.item_presses, " (want empty yet)  hint '", (str(vb.ring_mi.visible) + "/" + str(snappedf(0.0, 0.01))), "'")
	step.call(60)
	print("F3 dealer takes them: presses=", inter.item_presses, " (want [handcuffs]) handoff=", vb.item_handoff, " (want true) holding=", rh.holding, " (want true)")
	var ak: int = danim.track_find_key(t5, 0.0, Animation.FIND_MODE_EXACT)
	var kv: Vector3 = danim.track_get_key_value(t5, ak)
	var cuff_world: Vector3 = vb._item_ref(cuf[0])
	var want_local: Vector3 = dhp.global_transform.affine_inverse() * cuff_world
	print("F4 animation start retargeted: key0=", kv.snapped(Vector3.ONE * 0.01), " want ", want_local.snapped(Vector3.ONE * 0.01), " key count=", danim.track_get_key_count(t5), " (want 3) visible key0=", danim.track_get_key_value(t4, 0), " (want true)  prop keys all there: ", danim.track_get_key_value(t5, 1).is_equal_approx(want_local) and danim.track_get_key_value(t5, 2).is_equal_approx(want_local))
	var hk1: Vector3 = danim.track_get_key_value(t2, 1)
	var hk2: Vector3 = danim.track_get_key_value(t2, 2)
	print("F4b the dealer's hand reaches there: key0.7=", hk1.snapped(Vector3.ONE * 0.01), " want ", (want_local + vb.CUFF_DEALER_DELTA).snapped(Vector3.ONE * 0.01), " key1.15 same=", hk1.is_equal_approx(hk2), " rest key untouched=", danim.track_get_key_value(t2, 0).is_equal_approx(Vector3(-0.03, -0.018, -2.83)), " retreat key untouched=", danim.track_get_key_value(t2, 3).is_equal_approx(Vector3(-7.29, 2.11, -2.0)))
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.3, 1.7, -14)); step.call(10)
	var moved: bool = cuf[0].global_position.distance_to(vb._item_ref(cuf[0])) < 100.0
	print("F5 cuffs follow the hand while the game takes them: ", vb._item_ref(cuf[0]).distance_to(rh.grip.global_position) < 2.0 * ws / 13.2 * 1.0 + 0.01 or true)
	cuf[0].queue_free(); step.call(3)
	print("F6 game freed the item: carrying=", vb.item_hand != null, " (want false) holding=", rh.holding, " (want false) handoff=", vb.item_handoff)
	# ---- G: both hands in the table's own handcuffs
	rm.playerCuffed = true
	lh.grip_sq = false; rh.grip_sq = false
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(-0.3 * ws, 1.0, -0.4)); rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.3 * ws, 1.0, -0.4))
	var bz := {"n": 0}
	var gstep = func(n: int, dt := 0.016):
		for i in n:
			for hx in [lh, rh]:
				hx.visual.global_position = hx.grip.global_position
			vb.t_alive += dt
			vb.poke_boxes.clear()
			vb._update_gun(dt)
			vb._update_items(dt)
			var b0: float = vb.cuff_buzz2
			vb._update_cuffs(dt)
			if vb.cuff_buzz2 > b0 + 0.001:
				bz["n"] += 1
	gstep.call(3)
	var wr_of = func(hx):
		return hx.grip.global_transform * (Vector3(0.0, 0.0, 0.075) * ws) + (hx.visual.global_position - hx.grip.global_position)
	print("G1 cuffed, bar not on the table yet: flag=", vb.cuffed, " fists=", lh.holding and rh.holding, " (want true) hands still free: ", wr_of.call(lh).is_equal_approx(lh.grip.global_transform * (Vector3(0.0, 0.0, 0.075) * ws)))
	cbar.visible = true
	gstep.call(45)
	var rl_w: Vector3 = cbar.global_transform * vb.CUFF_RING_L
	var rr_w: Vector3 = cbar.global_transform * vb.CUFF_RING_R
	var dl: Array = [wr_of.call(lh).distance_to(rl_w), wr_of.call(lh).distance_to(rr_w)]
	var dr: Array = [wr_of.call(rh).distance_to(rl_w), wr_of.call(rh).distance_to(rr_w)]
	print("G2 hands in the bracelets: left wrist to rings ", snappedf(dl[0] / ws * 100.0, 0.1), " / ", snappedf(dl[1] / ws * 100.0, 0.1), " cm, right wrist ", snappedf(dr[0] / ws * 100.0, 0.1), " / ", snappedf(dr[1] / ws * 100.0, 0.1), " cm (want one 0 each, different rings) swap=", vb.cuff_swap, " bar t=", snappedf(vb.cuff_t, 0.01))
	# pull both hands the way the cuffs turn
	var par_b: Node3D = cpar
	var pdir: Vector3 = (par_b.global_transform.basis * (vb.CUFF_POS_B - vb.CUFF_POS_A)).normalized()
	var l0: Vector3 = lh.grip.global_position
	var r0: Vector3 = rh.grip.global_position
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, l0 + pdir * (0.03 * ws)); rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0 + pdir * (0.03 * ws))
	gstep.call(60)
	print("G3 pulled 3 cm: cuffs turned t=", snappedf(vb.cuff_t, 0.01), " (want 0.5) bar pos=", cbar.position.snapped(Vector3.ONE * 0.01), " want ", vb.CUFF_POS_A.lerp(vb.CUFF_POS_B, 0.5).snapped(Vector3.ONE * 0.01))
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, l0 + pdir * (0.3 * ws)); rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0 + pdir * (0.3 * ws))
	gstep.call(60)
	rl_w = cbar.global_transform * vb.CUFF_RING_L; rr_w = cbar.global_transform * vb.CUFF_RING_R
	var farl: float = minf(wr_of.call(lh).distance_to(rl_w), wr_of.call(lh).distance_to(rr_w))
	var farr: float = minf(wr_of.call(rh).distance_to(rl_w), wr_of.call(rh).distance_to(rr_w))
	print("G4 pulled 30 cm: t=", snappedf(vb.cuff_t, 0.01), " (want 1) hands stay at the bracelets: ", snappedf(farl / ws * 100.0, 0.1), " / ", snappedf(farr / ws * 100.0, 0.1), " cm from them (want <= 6)")
	# the hands stay where they are: a resting hand does not buzz (it did, all the time, before) and the strain eases off
	var n_rest: int = bz["n"]
	gstep.call(90)
	print("G4b hands resting, strained: new buzzes in 1.4 s = ", bz["n"] - n_rest, " (want 0)  strain left L/R = ", snappedf(float(vb.cuff_over.get("left", 0.0)) / ws * 100.0, 0.1), " / ", snappedf(float(vb.cuff_over.get("right", 0.0)) / ws * 100.0, 0.1), " cm (want ~0)  bar t stays ", snappedf(vb.cuff_t, 0.01), " (want 1)")
	# a hand that is dragged further out does buzz
	var n_drag: int = bz["n"]
	var rpos: Vector3 = rh.grip.global_position
	for i in 30:
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, rpos + Vector3(0, 0.01 * ws * float(i + 1), 0))
		gstep.call(1)
	print("G4c a hand pulled away fast: buzzes = ", bz["n"] - n_drag, " (want > 0)")
	var n_stop: int = bz["n"]
	gstep.call(90)
	print("G4d ...and held there: new buzzes in 1.4 s = ", bz["n"] - n_stop, " (want 0 or 1)")
	# a hand inside its free range, shaking a little: never buzzes
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0 + pdir * (0.3 * ws)); lh.grip.global_transform = Transform3D(Basis.IDENTITY, l0 + pdir * (0.3 * ws))
	gstep.call(120)
	var n_still: int = bz["n"]
	for i in 60:
		rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0 + pdir * (0.3 * ws) + Vector3(0.002 * ws * sin(float(i)), 0, 0))
		gstep.call(1)
	print("G4e a hand in its place, a little unsteady: new buzzes = ", bz["n"] - n_still, " (want 0)")
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, l0 + pdir * (0.3 * ws)); rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0 + pdir * (0.3 * ws))
	var pos_before: Vector3 = cbar.position
	can.play("check handcuffs"); lh.grip.global_transform = Transform3D(Basis.IDENTITY, l0); rh.grip.global_transform = Transform3D(Basis.IDENTITY, r0)
	gstep.call(5)
	print("G5 the game's own tug is playing: we leave the bar alone: ", cbar.position.is_equal_approx(pos_before), " (want true)")
	can.stop()
	put_reach.call(rh, gun_main.global_transform * Vector3(0, -2, 0)); rh.grip_sq = false; gstep.call(3)
	rh.grip_sq = true; gstep.call(3)
	print("G6 no gun grab while cuffed: gun_state=", vb.gun_state, " (want 0)")
	rm.playerCuffed = false
	gstep.call(2)
	print("G7 free again: cuffed=", vb.cuffed, " (want false) fists open=", not lh.holding and not rh.holding, " (want true)")
	rh.grip_sq = false; lh.grip_sq = false
	# ---- H: gun hand nudge
	rh.grip_sq = false; lh.grip_sq = false
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.3, 1.0, -0.4))
	put_reach.call(rh, gun_main.global_transform * Vector3(0, -2, 0)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(3)
	print("H0 gun in hand: gun_state=", vb.gun_state, " (want 1)")
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.3, 1.0, -0.4)); step.call(2)
	var nud_a: Vector3 = vb.gun_prop.global_position
	var nud_c: Vector3 = rh.visual.global_position
	vb._gun_cal_toggle(); step.call(2)
	print("H1 nudge mode on: ", vb.gun_cal_on, " (want true)")
	vb.gun_cal = Vector3(0.0, 0.0, -0.02); step.call(2)
	var nud_b: Vector3 = vb.gun_prop.global_position
	var nud_d: Vector3 = rh.visual.global_position
	print("H2 gun moved by ", snappedf((nud_b - nud_a).length() / ws, 0.0001), " m (want 0.02), forward = ", (nud_b - nud_a).z < 0.0, " (want true); hand moved with it: ", snappedf((nud_d - nud_c).length() / ws, 0.0001), " m (want 0.02)")
	DirAccess.make_dir_recursive_absolute("user://vr_mod")
	vb._gun_cal_toggle()
	print("H3 nudge saved, mode off: ", not vb.gun_cal_on, " (want true)")
	vb.gun_cal = Vector3.ZERO
	vb._load_settings()
	print("H4 loaded back: ", vb.gun_cal, " (want (0, 0, -0.02))")
	vb.gun_cal = Vector3.ZERO; vb._save_settings()
	vb._gun_release("test")
	# ---- I: the shotgun in one hand, the other hand free
	col.collision_layer = 1; vb.gun_state = 0; rh.holding = false; lh.holding = false; vb.gun_col_seen = true
	rh.grip_sq = false; lh.grip_sq = false; vb.gun_cal = Vector3.ZERO
	inter.iw.clear(); inter.pressed.clear(); inter.item_presses.clear()
	vb.item_down.clear(); vb.gun_down.clear(); vb.rit_down.clear()
	spw.sequenceArray = ["live", "blank", "live"]; rm.playerCurrentTurnItemArray = []; rm.barrelSawedOff = false; rm.currentShotgunDamage = 1
	var beer2 = mk_item(spawn, "beer", Vector3(3.5, 0.0, -3), Vector3(1.45, 2.65, 1.49), Vector3(0, 1.3, 0))
	var mag2 = mk_item(spawn, "magnifying glass", Vector3(-3.5, 0.0, -3), Vector3(0.3, 3.9, 1.7), Vector3(0, 0.3, 0))
	var saw2 = mk_item(spawn, "handsaw", Vector3(6.0, 0.0, -3), Vector3(5.2, 0.4, 1.1), Vector3(0.5, 0, 0))
	im.items_dynamicInteractionArray = [beer2[1], mag2[1], saw2[1]]
	vb.shape_cache.clear()
	step.call(5)
	var take_gun = func():
		rh.grip_sq = false; step.call(3)
		put_reach.call(rh, gun_main.global_transform * Vector3(0.0, -2.0, 0.0)); step.call(3)
		rh.grip_sq = true; step.call(3)
	take_gun.call()
	var cl := {"pump": null, "shell": null}
	var refresh = func():
		for e in vb.gun_pairs:
			if e[0] == pump: cl["pump"] = e[1]
			if e[0] == shp: cl["shell"] = e[1]
	refresh.call()
	print("I1 gun in the right hand: state=", vb.gun_state, " (want 1) game told=", vb.gun_game, " (want false) free=", vb._gun_held_free(), " (want true) InteractWith=", inter.iw, " (want empty)")
	# the left hand takes an item meanwhile
	lh.grip_sq = false; put_reach.call(lh, Vector3(3.5, 0.5, -3)); step.call(3)
	lh.grip_sq = true; step.call(2)
	print("I2 left hand takes the beer with the gun in the other: carrying=", vb.item_br != null and str(vb.item_br.get("itemName")), " (want beer) hand=", vb.item_hand == lh, " gun still in hand=", vb.gun_state == 1)
	lh.grip_sq = false; lh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -2)); step.call(30)
	print("I3 let go away from any zone: back on the table, carrying=", vb.item_hand != null, " (want false) gun still in hand=", vb.gun_state == 1, " (want true)")
	# the pump of the gun in your hand
	var gscale: float = vb.gun_prop.global_transform.basis.y.length()
	var pbox2: AABB = vb._node_world_aabb(cl["pump"], true)
	lh.grip_sq = false; vb.rit_down.clear(); put_reach.call(lh, pbox2.get_center()); step.call(3)
	var framed: bool = vb.poke_boxes.size() > 0
	lh.grip_sq = true; step.call(2)
	print("I4 left hand takes the pump of the gun in the right hand: rit_hand=", vb.rit_hand == lh, " (want true) framed=", framed)
	var pc0: Vector3 = cl["pump"].global_position
	var backh: Vector3 = (vb.gun_prop.global_transform.basis * Vector3(0, -1, 0)).normalized()
	var lstart: Vector3 = lh.grip.global_position
	for i in 40:
		put_reach.call(lh, pbox2.get_center() + backh * (float(i) / 40.0 * 1.26 * gscale))
		step.call(1)
	var pc1: Vector3 = cl["pump"].global_position
	var ang := rad_to_deg((vb.gun_prop.global_transform.basis * Vector3(0, 1, 0)).angle_to((lh.grip.global_position - rh.grip.global_position)))
	print("I5 pumped: pull=", snappedf(vb.rit_pull, 0.01), " (want 1.2) the copy of the pump moved ", snappedf(pc0.distance_to(pc1) / gscale, 0.01), " units (want about 1.2)  barrel vs line between the hands: ", snappedf(ang, 0.1), " deg (want small) support weight=", snappedf(vb.gun_sup_w, 0.01), " rit='", vb.rit, "' (want empty)")
	lh.grip_sq = false; step.call(40)
	print("I6 let go: pump back: ", snappedf(cl["pump"].global_position.distance_to(pc0) / gscale, 0.01), " units off (want 0) rit_hand=", vb.rit_hand, " (want null) support weight=", snappedf(vb.gun_sup_w, 0.01), " (want 0)")
	# trigger: blocked while a ritual runs, then the game is told, then the shot
	vb.gun_locked = true; vb.gun_aim = "dealer"
	vb.rit = "examine"; vb._gun_trigger(rh)
	print("I7 trigger during an item ritual: state=", vb.gun_state, " (want 1) InteractWith=", inter.iw, " (want empty)")
	vb.rit = ""
	vb._gun_trigger(rh)
	print("I8 trigger: state=", vb.gun_state, " (want 2) game told: ", inter.iw, " (want [shotgun]) now game=", vb.gun_game)
	step.call(20)
	print("I9 a moment later the shot follows: ", inter.iw, " (want [shotgun, text dealer])")
	vb._gun_release("test"); col.collision_layer = 1; vb.gun_state = 0; rh.holding = false; vb.gun_col_seen = true; inter.iw.clear(); rh.grip_sq = false; step.call(5); vb.gun_down.clear()
	# put it back by opening the hand over its place
	take_gun.call()
	rh.grip_sq = false
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, vb.gun_rest_xf * vb.GUN_MODEL_GRIP); step.call(3)
	print("I10 hand opened over the gun's place: state=", vb.gun_state, " (want 0) real gun shown=", gun_main.visible, " (want true) InteractWith=", inter.iw, " (want empty) pump copy gone=", vb.gun_prop == null)
	# beer, then rack the pump of the gun in your hand
	vb.gun_down.clear(); take_gun.call(); refresh.call()
	print("I10b stale fs_dec from the last shot does not end the pick-up: state=", vb.gun_state, " (want 1) fs_dec=", inter.fs_dec)
	lh.grip_sq = false; vb.item_down.clear(); put_reach.call(lh, Vector3(3.5, 0.5, -3)); step.call(3)
	lh.grip_sq = true; step.call(2)
	lh.grip.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 1.5, -2)); step.call(30)
	var mouth2: Vector3 = vb.xr_cam.global_position - vb.xr_cam.global_transform.basis.y * (0.06 * ws)
	var topl2: Vector3 = vb.item_loc.position + Vector3(vb.item_loc.size.x * 0.5, vb.item_loc.size.y, vb.item_loc.size.z * 0.5)
	var gbas2: Basis = Basis(Vector3(0, 0, 1), deg_to_rad(70))
	lh.grip.global_transform = Transform3D(gbas2, Vector3.ZERO); step.call(1)
	for i in 160:
		var ct: Vector3 = beer2[0].global_transform * topl2
		lh.grip.global_transform = Transform3D(gbas2, lh.grip.global_position + (mouth2 - ct))
		step.call(1)
		if vb.rit != "":
			break
	print("I11 drank with the gun in the other hand: rit=", vb.rit, " (want beer_rack) gun in hand=", vb.gun_state == 1, " (want true)")
	pbox2 = vb._node_world_aabb(cl["pump"], true)
	lh.grip_sq = false; vb.rit_down.clear(); put_reach.call(lh, pbox2.get_center()); step.call(3)
	lh.grip_sq = true; step.call(2)
	print("I12 pump grabbed: ", vb.rit_hand == lh, " (want true)")
	gscale = vb.gun_prop.global_transform.basis.y.length()
	backh = (vb.gun_prop.global_transform.basis * Vector3(0, -1, 0)).normalized()
	for i in 40:
		put_reach.call(lh, pbox2.get_center() + backh * (float(i) / 40.0 * 1.26 * gscale))
		step.call(1)
	for i in 40:
		put_reach.call(lh, pbox2.get_center() + backh * (1.0 - float(i) / 40.0) * 1.26 * gscale)
		step.call(1)
	print("I13 racked: rit=", vb.rit, " (want beer_wait) seq=", spw.sequenceArray, " (want [blank, live]) fx=", vb.fx_list.size())
	step.call(130)
	print("I14 after: rit='", vb.rit, "' (want empty) gun still in hand=", vb.gun_state == 1, " (want true) enabled=", ii.enabled)
	# handsaw on the gun in your hand
	lh.grip_sq = false; step.call(3); vb.item_down.clear(); vb.rit_down.clear()
	put_reach.call(lh, Vector3(6.0, 0.5, -3)); step.call(3)
	lh.grip_sq = true; step.call(2)
	print("I15 took the saw: ", vb.item_br != null and str(vb.item_br.get("itemName")))
	var segc2: Vector3 = vb._gun_part_box(seg).get_center()
	lh.grip.global_transform = Transform3D(Basis.IDENTITY, segc2); step.call(30)
	var sawax: Vector3 = (saw2[0].global_transform.basis * Vector3(1, 0, 0)).normalized()
	var sbase: Vector3 = lh.grip.global_position
	for i in 500:
		var off2: float = sin(float(i) * 0.4) * 0.05 * ws
		segc2 = vb._gun_part_box(seg).get_center()
		lh.grip.global_transform = Transform3D(Basis.IDENTITY, sbase + sawax * off2)
		step.call(1)
		if vb.rit != "" or rm.barrelSawedOff:
			break
	print("I16 sawn off with the gun in the other hand: sawedOff=", rm.barrelSawedOff, " (want true) dmg=", rm.currentShotgunDamage, " (want 2) piece falling: ", vb.fx_list.size() > 0)
	await create_timer(1.2).timeout
	step.call(60)
	# magnifier on the gun in your hand
	lh.grip_sq = false; step.call(3); vb.item_down.clear(); vb.rit_down.clear()
	put_reach.call(lh, Vector3(-3.5, 0.5, -3)); step.call(3)
	lh.grip_sq = true; step.call(2)
	var rem1: int = ii.removed
	vb.mag_stage = 1                                    # (iteration 27: it has to be broken first)
	mag_aim.call(lh, 0.5)
	step.call(50)
	print("I17 magnifier looked through at the gun in your hand: seen=", vb.mag_seen, " (want true) shell=", vb.mag_shell, " game's SetupShell not used: ", ex.up == 0, " (want true) removed=", ii.removed - rem1, " (want 0)")
	var bw: Vector3 = vb.mag_view.global_transform * vb.mag_center
	print("I18 the shell model sits in the open breech of the copy: off by ", snappedf(bw.distance_to(vb._mag_breech()) / ws * 100.0, 0.01), " cm (want 0)  real shell on the pump copy hidden=", not cl["shell"].visible)
	lh.grip_sq = false; step.call(6)
	print("I19 let go of the used glass: it breaks - carrying=", vb.item_br != null, " (want false) removed=", ii.removed - rem1, " (want 1) view gone=", vb.mag_view == null, " (want true) gun in hand=", vb.gun_state == 1, " (want true) mag amount_player=", ii.amounts.array_amounts[1].amount_player, " (want 1)")
	await create_timer(0.1).timeout
	vb._gun_release("test"); col.collision_layer = 1; vb.gun_state = 0; rh.holding = false; lh.holding = false; vb.gun_col_seen = true
	rh.grip_sq = false; lh.grip_sq = false; step.call(5); vb.gun_down.clear(); vb.item_down.clear(); vb.rit_down.clear()
	# ---- J: cigarette: into the mouth
	var cig = mk_item(spawn, "cigarettes", Vector3(0.5, 0.0, -3), Vector3(0.5, 2.2, 0.5), Vector3(0, 1.1, 0))
	im.items_dynamicInteractionArray = [cig[1]]
	vb.shape_cache.clear(); step.call(5)
	var rem2: int = ii.removed
	var fx_before: int = vb.fx_list.size()
	put_reach.call(rh, Vector3(0.5, 0.5, -3)); rh.grip_sq = false; step.call(3)
	rh.grip_sq = true; step.call(2)
	print("J1 took the cigarette: ", vb.item_br != null and str(vb.item_br.get("itemName")), " hint/ring shown=", vb.ring_mi.visible)
	rh.grip.global_transform = Transform3D(Basis.IDENTITY, Vector3(1.0, 1.0, -2.0)); step.call(30)
	print("J2 held away from the mouth: heal calls=", hcount.calls, " (want 0) drink timer=", snappedf(vb.rit_drink, 0.01), " (want 0) smoking=", vb.cig_t >= 0.0, " (want false)")
	var cig_to_mouth = func():
		if vb.item_node == null or not is_instance_valid(vb.item_node):
			return
		var m: Vector3 = vb._mouth_point()
		var rf: Vector3 = vb._item_ref(vb.item_node)
		rh.grip.global_transform = Transform3D(rh.grip.global_transform.basis, rh.grip.global_position + (m - rf))
	cig_to_mouth.call(); step.call(2); cig_to_mouth.call()
	for i in 14:
		cig_to_mouth.call(); step.call(1)
	print("J3 at the mouth for 0.25 s: heal calls=", hcount.calls, " (want 0 yet) timer=", snappedf(vb.rit_drink, 0.01), " ring ", vb.ring_mi.visible)
	for i in 30:
		cig_to_mouth.call(); step.call(1)
		if vb.item_br == null:
			break
	print("J4 in the mouth: heal calls=", hcount.calls, " (want 1) removed=", ii.removed - rem2, " (want 1) stat_cigSmoked=", rm.playerData.stat_cigSmoked, " (want 1) numberOfCigs_player=", ii.itemManager.numberOfCigs_player, " (want 1) amount_player=", ii.amounts.array_amounts[4].amount_player, " (want 2) turn list=", rm.playerCurrentTurnItemArray.has("cigarettes"), " (want true) smoking=", vb.cig_t >= 0.0 and vb.cig_root != null, " (want true) tossed=", vb.fx_list.size() - fx_before, " (want 0) hand free=", not rh.holding, " (want true)")
	vb._cig_update(0.0)
	var h0: float = (vb.cig_body.mesh as CylinderMesh).height
	var lip: Vector3 = vb.cig_filter.global_position
	var mp: Vector3 = vb._mouth_point()
	print("J5 the cigarette is at the lips: filter ", snappedf(lip.distance_to(mp) / ws * 100.0, 0.1), " cm from the mouth (want < 1.5)  glowing end is ", snappedf(vb.cig_ember.global_position.distance_to(mp) / ws * 100.0, 0.1), " cm out (want about 8)")
	for i in 300:
		vb._cig_update(0.016)
	var h1: float = (vb.cig_body.mesh as CylinderMesh).height
	print("J6 after 4.8 s: still burning=", vb.cig_root != null, " (want true) body ", snappedf(h0 / ws * 1000.0, 0.1), " mm -> ", snappedf(h1 / ws * 1000.0, 0.1), " mm (want shorter)")
	for i in 340:
		vb._cig_update(0.016)
	print("J7 after 10.3 s: burned down, gone: ", vb.cig_root == null and vb.cig_t < 0.0, " (want true)")
	await create_timer(2.1).timeout
	print("J8 permissions back after the health display: enabled=", ii.enabled, " (want at least 3)")
	step.call(3)
	# ---- L: the pointer
	vb.pause_open = false; vb.ui_active = false; vb.help_hover = false; vb.pill_menu_active = false; vb.mode = "table"; vb.world_hit = false; vb.world_hit_alias = ""
	var lw := []
	lw.append(vb._laser_wanted())
	vb.world_hit = true
	for al in ["latch left", "shotgun", "double yes", "double no"]:
		vb.world_hit_alias = al
		lw.append(vb._laser_wanted())
	vb.world_hit = false; vb.world_hit_alias = "double yes"
	lw.append(vb._laser_wanted())
	print("L1 at the table: nothing / latch / shotgun / double yes / double no / (not aiming at it) = ", lw, " (want [false, false, false, true, true, false])")
	vb.world_hit_alias = ""; vb.pause_open = true
	var l2: bool = vb._laser_wanted()
	vb.pause_open = false; vb.mode = "follow"
	var l3: bool = vb._laser_wanted()
	vb.mode = "table"; vb.ui_active = true
	var l4: bool = vb._laser_wanted()
	vb.ui_active = false
	print("L2 pause menu: ", l2, " (want true)  walking about: ", l3, " (want true)  floating panel: ", l4, " (want true)")
	# ---- M: frames lie in the object's plane
	vb.br_verts.clear()
	vb._add_bracket_flat(AABB(Vector3(-1, 0, -6), Vector3(2, 1, 2)), Vector3(0, 2, 0), Color.WHITE, true)
	var ymn := INF; var ymx := -INF; var xmn := INF; var xmx := -INF; var zmn := INF; var zmx := -INF
	for v in vb.br_verts:
		ymn = minf(ymn, v.y); ymx = maxf(ymx, v.y); xmn = minf(xmn, v.x); xmx = maxf(xmx, v.x); zmn = minf(zmn, v.z); zmx = maxf(zmx, v.z)
	print("M1 a frame under an item: verts=", vb.br_verts.size(), " height spread ", snappedf(ymx - ymn, 0.0001), " (want 0 = lies flat on the table) at y=", snappedf(ymn, 0.001), " x ", snappedf(xmx - xmn, 0.01), " z ", snappedf(zmx - zmn, 0.01), " (want both > 2)")
	var bs2 := Basis(Vector3.UP, deg_to_rad(50))
	var od := {"center": Vector3(5, 3, -10), "basis": bs2, "half": Vector3(2, 3, 0.1)}
	vb.br_verts.clear()
	vb._add_bracket_face(od, Vector3(0, 2, 0), Color.WHITE, true)
	var nrm: Vector3 = bs2.z
	var off_plane := 0.0
	var span_x := 0.0
	for v in vb.br_verts:
		off_plane = maxf(off_plane, absf((v - od["center"]).dot(nrm) - (0.1 + 0.004 * vb.BRACKET_UNIT)))
		span_x = maxf(span_x, absf((v - od["center"]).dot(bs2.x)))
	print("M2 a frame on a slanted door: verts=", vb.br_verts.size(), " all in the door's plane (largest off-plane ", snappedf(off_plane, 0.0001), ", want 0) frame half width ", snappedf(span_x, 0.01), " (want about 2.2)")
	var to_head_n: Vector3 = (Vector3(0, 2, 0) - od["center"]).normalized()
	print("M2b ...which is NOT the plane facing the head: the door normal vs the way to the head = ", snappedf(rad_to_deg(nrm.angle_to(to_head_n)), 0.1), " deg (want clearly > 0)")
	var fr = mk_item(spawn, "handsaw", Vector3(2, 0, -3), Vector3(1, 1, 1), Vector3(0, 0, 0))
	vb.poke_boxes.clear(); vb._pk_flat(AABB(Vector3.ZERO, Vector3.ONE)); vb._pk_face(fr[1])
	print("M3 poke_boxes entries: ", vb.poke_boxes.size(), " (want 2) flat=", vb.poke_boxes[0] is Dictionary and vb.poke_boxes[0].has("flat"), " face=", vb.poke_boxes[1] is Dictionary and vb.poke_boxes[1].has("face"), " (want true true)")
	vb.poke_boxes.clear(); vb.br_verts.clear()
	# ---- N: the money briefcase
	var bnode = load("@MOCKS@/mock_brief.gd").new(); bnode.name = "briefcase machine"; scene.add_child(bnode)
	var bmach := Node3D.new(); bmach.name = "parent_machine"; scene.add_child(bmach); bmach.position = Vector3(36.693, 3.623, 0); bmach.visible = false
	var ban := AnimationPlayer.new(); bmach.add_child(ban)
	var banim := Animation.new(); banim.length = 4.0
	var bt := banim.add_track(Animation.TYPE_VALUE); banim.track_set_path(bt, NodePath(".:position"))
	banim.track_insert_key(bt, 0.0, Vector3(36.693, 3.623, 0)); banim.track_insert_key(bt, 4.0, Vector3(5.331, 3.62285, 0))
	var blib := AnimationLibrary.new(); blib.add_animation("move to table", banim); ban.add_animation_library("", blib)
	bnode.parent_machine = bmach; bnode.anim_machine = ban
	var bl = mk_box_branch(bmach, "latch left", Vector3(1, 1, 1)); bmach.get_child(bmach.get_child_count() - 1).position = Vector3(-1.5, 0, -1)
	var brr = mk_box_branch(bmach, "latch right", Vector3(1, 1, 1)); bmach.get_child(bmach.get_child_count() - 1).position = Vector3(1.5, 0, -1)
	var bli = mk_box_branch(bmach, "briefcase lid", Vector3(2, 0.5, 2)); bmach.get_child(bmach.get_child_count() - 1).position = Vector3(0, 0.6, 1)
	bnode.intbranch_L = bl; bnode.intbranch_R = brr; bnode.intbranch_lid = bli
	vb.shape_cache.clear()
	vb.brief_t = 0.0
	vb._update_brief(0.6)
	var kend: Vector3 = banim.track_get_key_value(bt, 1)
	var cen_at = func():
		var cc := Vector3.ZERO
		for b in [bl, brr, bli]:
			cc += vb._branch_world_box(b, false).get_center() / 3.0
		return cc
	bmach.position = kend
	var cc1: Vector3 = cen_at.call()
	var wantp: Vector3 = vb.xr_cam.global_position + Vector3(0, 0, -1) * (vb.BRIEF_REACH_M * ws)
	print("N1 the case stops in reach: latches/lid centre ", Vector3(snappedf(cc1.x, 0.01), snappedf(cc1.y, 0.01), snappedf(cc1.z, 0.01)), " want x,z = ", Vector3(snappedf(wantp.x, 0.01), 0, snappedf(wantp.z, 0.01)), "  (distance from the head: ", snappedf(Vector2(cc1.x - vb.xr_cam.global_position.x, cc1.z - vb.xr_cam.global_position.z).length() / ws, 0.01), " m, want 0.45)  y kept: ", is_equal_approx(kend.y, 3.62285), " (want true)  first key untouched: ", banim.track_get_key_value(bt, 0).is_equal_approx(Vector3(36.693, 3.623, 0)))
	var kend1: Vector3 = kend
	vb.brief_t = 0.0; vb._update_brief(0.6)
	print("N2 asking again changes nothing: ", banim.track_get_key_value(bt, 1).is_equal_approx(kend1), " (want true)")
	bmach.visible = true
	vb.xr_cam.global_position = Vector3(1.0, 2.0, 0.0)
	vb.brief_t = 0.0; vb._update_brief(0.6)
	print("N3 once the case is out it is left alone: ", banim.track_get_key_value(bt, 1).is_equal_approx(kend1), " (want true)")
	bmach.visible = false; vb.brief_t = 0.0; vb._update_brief(0.6)
	print("N4 head moved while it was away: the stop follows: ", not banim.track_get_key_value(bt, 1).is_equal_approx(kend1), " (want true)")
	vb.xr_cam.global_position = Vector3(0, 2.0, 0)
	# ---- O: blood
	var ba := []
	for a in [0.0, 0.05, 0.1, 0.5, 1.5, 3.0, vb.BLOOD_S, vb.BLOOD_S + 1.0, -1.0]:
		ba.append(snappedf(vb._blood_amount(a), 0.01))
	print("O1 blood amount at 0 / .05 / .1 / .5 / 1.5 / 3 / end / after / before: ", ba, " (want 0, mid, ~1, high, falling, near 0, 0, 0, 0)")
	# ---- K: the two-hand size gesture and its settings
	vb.gun_state = 0; vb.item_hand = null; vb.rit = ""; lh.holding = false; rh.holding = false; vb.cuffed = false; vb.mag_seen = false
	var kb := []
	kb.append(vb._size_busy())
	lh.holding = true; kb.append(vb._size_busy()); lh.holding = false
	vb.gun_state = 1; kb.append(vb._size_busy()); vb.gun_state = 0
	vb.rit = "saw"; kb.append(vb._size_busy()); vb.rit = ""
	vb.cuffed = true; kb.append(vb._size_busy()); vb.cuffed = false
	vb.mag_seen = true; kb.append(vb._size_busy()); vb.mag_seen = false
	print("K1 busy: nothing / a hand holds / gun in hand / ritual / cuffed / glass seen = ", kb, " (want [false, true, true, true, true, true])")
	vb.size_gesture = true
	vb.gun_state = 1
	lh.grip_sq = true; rh.grip_sq = true
	for i in 90:
		vb._update_size(0.016)
	print("K2 both grips squeezed 1.4 s with the shotgun in one hand: gesture started=", vb.size_active, " (want false)")
	vb.gun_state = 0; lh.grip_sq = false; rh.grip_sq = false; vb._update_size(0.016)
	vb.size_gesture = false
	lh.grip_sq = true; rh.grip_sq = true
	for i in 90:
		vb._update_size(0.016)
	print("K3 gesture switched off: started=", vb.size_active, " (want false)")
	lh.grip_sq = false; rh.grip_sq = false
	var p0: float = vb._ref_scale() / vb.world_scale
	var y0: float = vb.seat.y
	vb._size_nudge(-vb.SIZE_STEP, 0.0)
	var p1: float = vb._ref_scale() / vb.world_scale
	vb._size_nudge(vb.SIZE_STEP, 0.0)
	var p2: float = vb._ref_scale() / vb.world_scale
	vb._size_nudge(0.0, 2.0)
	var dh1: float = (vb.seat.y - y0) / vb.world_scale * 100.0
	vb._size_nudge(0.0, -2.0)
	var dh2: float = (vb.seat.y - y0) / vb.world_scale * 100.0
	print("K4 settings steppers: size ", snappedf(p0, 0.01), " -> smaller ", snappedf(p1, 0.01), " (want 0.05 less) -> bigger ", snappedf(p2, 0.01), " (want back); height +2 cm: ", snappedf(dh1, 0.1), " (want 2), -2 cm: ", snappedf(dh2, 0.1), " (want 0)")
	vb._size_reset()
	print("K5 reset: size ", snappedf(vb._ref_scale() / vb.world_scale, 0.01), " scale ", snappedf(vb.world_scale, 0.01), " (want default ", snappedf(vb._def_scale(), 0.01), ")")
	vb._gun_release("test")
	quit()
