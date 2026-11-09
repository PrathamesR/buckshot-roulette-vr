# Using items: tick dispatcher helpers and the beer
# (Part of the Buckshot Roulette VR mod. Chain position 30: this file extends 29_medicine.gd; see src/README.md.)
extends "29_medicine.gd"

const BEER_MOUTH_M := 0.12                         # the can's opening this close (real metres) to your mouth...

const BEER_TILT := 0.8                             # ...and tilted this far (cosine to straight up) = drinking

const BEER_DRINK_S := 1.8                          # drink this long to finish it

# ---- using the items by hand ---------------------------------------------------------------------------------------------
# Returns 1 = used up, 0 = still carrying, 2 = this cannot be done by hand right now (the old "let go in the zone" instead).
func _rit_item_tick(iname: String, hh: Hand, par: Node3D, br: Node, delta: float) -> int:
	match iname:
		"beer":
			return _rit_beer_tick(hh, par, delta)
		"magnifying glass":
			return _rit_mag_tick(hh, par, delta)
		"handsaw":
			return _rit_saw_tick(hh, par, delta)
		"cigarettes":
			return _rit_cig_tick(hh, par, delta)
		"inverter":
			return _rit_inv_tick(hh, par, delta)
		"expired medicine":
			return _rit_med_tick(hh, par, delta)
		"burner phone":
			return _rit_phone_tick(hh, par, delta)
		"adrenaline":
			return _rit_adr_tick(hh, par, delta)
	return 2

func _rit_beer_tick(hh: Hand, par: Node3D, delta: float) -> int:
	var ws := world_scale
	var ref := _item_ref(par)
	var top := par.global_transform * (item_loc.position + Vector3(item_loc.size.x * 0.5, item_loc.size.y, item_loc.size.z * 0.5))
	var axis := (par.global_transform.basis * Vector3(0.0, 1.0, 0.0)).normalized()
	var mouth := xr_cam.global_position - xr_cam.global_transform.basis.y.normalized() * (0.06 * ws)
	var near := top.distance_to(mouth) <= BEER_MOUTH_M * ws
	var ok := near and axis.dot(Vector3.UP) < BEER_TILT
	if ok:
		rit_drink += delta
		rit_haptic_t -= delta
		if rit_haptic_t <= 0.0:
			rit_haptic_t = 0.32
			hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.2, 0.06, 0.0)
	else:
		rit_drink = maxf(rit_drink - delta * 0.6, 0.0)
	if rit_drink > 0.05:
		_ring_show(mouth, clampf(rit_drink / BEER_DRINK_S, 0.0, 1.0), ok, 0.06)    # the ring fills while you drink
	else:
		_ring_show(mouth, -1.0, near, 0.06)
	if rit_drink < BEER_DRINK_S:
		return 0
	var ii = interaction.get("itemInteraction")
	var rm = ii.get("roundManager") if ii != null else null
	if rm == null:
		return 2
	var seq = rm.get("shellSpawner").get("sequenceArray")
	if not (seq is Array) or seq.is_empty():
		return 2
	rit_final = seq.size() == 1
	var pd = rm.get("playerData")
	if pd != null:
		pd.set("stat_beerDrank", int(pd.get("stat_beerDrank")) + 330)
	if not _titem_consume(par, "beer"):
		return 2
	hh.grip.trigger_haptic_pulse("haptic", 0.0, 0.5, 0.15, 0.0)
	_fx_play(_anim_stream("player use beer", "beer"))
	_titem_end(false, "drunk")
	rit = "beer_rack"
	rit_t = 0.0
	rit_pull = 0.0
	rit_pulled = false
	print("VRBoot: beer drunk - now the shotgun has to be racked")
	return 1

# The shell leaves the gun: the game's own bookkeeping (BeerEjection_player counts it, takes it out of the sequence and out of
# what the dealer knows) without its animation (it starts from where the lifted gun would be); the shell itself flies from the
# open breech of the gun on the table.
func _beer_eject() -> void:
	if cur_scene == null:
		return
	var holder := cur_scene.find_child("shell parent_ejecting player side", true, false)
	var em: Node = holder.get_node_or_null("shell eject manager") if holder != null else null
	if em == null:
		return
	var sp = em.get("shellSpawner")
	var seq = sp.get("sequenceArray") if sp != null else null
	if not (seq is Array) or seq.is_empty():
		return
	var state := str(seq[0])
	var port := gun_main.global_position + Vector3.UP * 0.4 if gun_main != null else Vector3.ZERO
	var ex := cur_scene.find_child("shell examine", true, false)
	if ex != null:
		var sh = ex.get("shellParent")
		if sh is Node3D:
			port = _gun_stand_in(sh as Node3D).global_position
	em.call("BeerEjection_player")
	var an = em.get("animator")
	if an is AnimationPlayer:
		(an as AnimationPlayer).stop()
	var mesh = em.get("mesh")
	if mesh is Node3D:
		(mesh as Node3D).visible = false
	if not (mesh is MeshInstance3D) or (mesh as MeshInstance3D).mesh == null:
		return
	var c := MeshInstance3D.new()
	c.mesh = (mesh as MeshInstance3D).mesh
	var nsurf := c.mesh.get_surface_count()
	if nsurf > 0:
		c.set_surface_override_material(0, em.get("mat_brass"))
	if nsurf > 1:
		c.set_surface_override_material(1, em.get("mat_live") if state == "live" else em.get("mat_blank"))
	fx_root.add_child(c)
	c.global_transform = Transform3D(Basis.from_euler(Vector3(-1.5708, -0.741067, 0.0)), port)
	var ws := world_scale
	var right := (_gun_xf().basis * Vector3(1.0, 0.0, 0.0)).normalized()
	_fx_fall(c, right * 0.9 * ws + Vector3.UP * 1.5 * ws, Vector3(7.0, 11.0, 4.0), gun_main.global_position.y - 0.04, 3.5)
	(fx_list[fx_list.size() - 1] as Dictionary)["snd"] = "drop"
	print("VRBoot: shell ejected by hand (", state, ")")
