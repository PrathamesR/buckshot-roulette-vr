# Shared state: the constants and variables that more than one module uses
# (Part of the Buckshot Roulette VR mod. Chain position 00: this file extends Node; see src/README.md.)
extends Node

const Hand = preload("hand.gd")   # one controller (see hand.gd)

const HOME_POS := Vector3(-13.59, 7.323, 0.024)   # the game's "home" camera socket

const HOME_YAW := -1.5707963                       # looking along +X, towards the dealer

# The size gesture's readout counts from these references ("SIZE 100 %" and "HEIGHT +0 CM" = the old defaults).
const REF_SCALE_BIG := 6.6

const REF_SEAT_Y_BIG := 0.62

const REF_SCALE_SMALL := 0.9

const REF_SEAT_Y_SMALL := 0.64

# The real defaults (iteration 13): size 50 % and height +15 cm in that readout.
const DEFAULT_SCALE_BIG := 13.2                    # game units per real metre: table, lobby, restroom (= 6.6 / 0.5)

const DEFAULT_SEAT_BIG := Vector3(0.0, 2.6, 1.37)  # where the head sits relative to the game camera (units): 0.62 + 0.15 m * 13.2

const DEFAULT_SCALE_SMALL := 1.8                   # car intro and menu (= 0.9 / 0.5)

const DEFAULT_SEAT_SMALL := Vector3(0.0, 0.91, 0.12)   # 0.64 + 0.15 m * 1.8

const SIZE_STEP := 0.05                            # pause menu: one press of the size buttons changes the readout by this much (5 %)

const HELP_SIZE := Vector2(11.0, 8.0)

const HELP_PX := Vector2i(1100, 800)

# Look of our own screens: only what the game itself uses (its menu font, black, white, and the green-yellow of its option values)
const UI_FONT_PATH := "res://fonts/fake receipt.otf"

const UI_BLACK := Color(0.0, 0.0, 0.0)

const UI_WHITE := Color(1.0, 1.0, 1.0)

const UI_LIME := Color(0.776471, 0.87451, 0.380392)

const RAY_MAX_UNITS := 3000.0                      # how far the pointer can reach (the lobby door is ~80 away)

const STICK_ON := 0.6

const STICK_OFF := 0.3

const NO_HIT := Vector2(-1.0, -1.0)

const FINGER_ALIASES := ["signature machine button", "release form on table"]   # the waiver and the name machine's keys: touched with a fingertip (the laser works too)

const LASER_ALIASES := ["double yes", "double no"]   # at the table only these still need the pointer

const POKE_PAD_M := 0.02                           # how far off a button still counts as touching it

const GUN_MODEL_GRIP := Vector3(0.01, -2.86, -0.217) # the point of the narrow neck of the stock (behind the trigger guard) that your hand closes around (model units; barrel +Y, up +Z, right +X)

const GUN_CAL_MAX := 0.08                         # ...and how far it may go from the standard place

const ITEM_CARRY := Vector3(0.0, -0.02, -0.09)     # where a carried item sits in the controller's grip frame (real metres)

const ITEM_FOLLOW_RATE := 16.0                     # how quickly a carried item catches up with the hand (per second)

const TITEM_MIN_S := 0.3                           # it cannot be used or put back before it has been held this long

const TITEM_HINTS := {"head": "BRING IT TO YOUR FACE", "gun": "HOLD IT TO THE SHOTGUN", "dealer": "HOLD IT OUT TO THE DEALER", "rit": ""}

const PP_WV_FALLBACK_S := 40.0                     # a waiver nobody picks up for this long can be touched with a fingertip again

const MAG_DWELL_S := 0.5                           # (old) the glass held at the shotgun this long: it breaks and shows the shell

const PHONE_ANIM_B := 6.1                          # ...and the screen is done at 6.1 s

const FLICK_W := 7.5                               # a wrist flick: the hand turns at least this fast (rad/s)

const FLICK_HOLD_S := 0.5                          # an item has to be held this long before a flick counts

const TUT_LONG_K := 0.68                            # (iteration 35) size of the long two-line tutorial words (1 = the other hints)

const PUMP_GRAB_M := 0.07                          # a hand this close (real metres) to the shotgun's pump can take it

const PUMP_PULL_OK := 0.85                         # pulled this far = racked

const GUN_HOLD_TS := 0.02                          # game speed while it waits for you to put the shotgun down

const GUN_PUT_DELAY_S := 0.5                      # after the bang the gun stays in your hand this long (recoil, flash)...

const GUN_PUT_S := 0.6                            # ...then glides this long into the game's own gun, which finishes the job (eject, put on the table)

# The pause menu is drawn by us into its own little 2D viewport and shown on a quad. Like the hands, it
# is passed backwards through the game's colour grading so it appears in the colours it was drawn in.
const PAUSE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D tex : filter_linear;
uniform float tone = 0.9;
uniform float retro = 0.0;
uniform vec3 bcs = vec3(1.49, 0.8, 0.26);
uniform float aces_on = 1.0;
vec3 srgb_to_lin(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 inv_tonemap(vec3 y) {
	if (aces_on < 0.5) {
		return y;
	}
	vec3 yw = clamp(y, vec3(0.0), vec3(0.97)) * 0.78107;
	vec3 qa = vec3(1.0) - yw * 0.983729;
	vec3 qb = vec3(0.0245786) - yw * 0.432951;
	vec3 qc = vec3(0.000090537) + yw * 0.238081;
	vec3 a = (-qb + sqrt(qb * qb + 4.0 * qa * qc)) / (2.0 * qa);
	return a / 1.8;
}
void fragment() {
	// With the retro colours on, the last step rounds every colour down to a level, so a white that comes out
	// a hair under 1.0 would turn light grey: whites are pushed clearly past 1.0, the other colours are exact.
	vec3 t = texture(tex, UV).rgb * mix(tone, 1.0, retro);
	vec3 m = vec3((t.r + t.g + t.b) / 3.0);
	vec3 c2 = m + (t - m) / max(bcs.z, 0.05);
	vec3 c1 = vec3(0.5) + (c2 - vec3(0.5)) / max(bcs.y, 0.05);
	vec3 p = clamp(c1 / max(bcs.x, 0.05), 0.0, 1.0);
	ALBEDO = inv_tonemap(srgb_to_lin(p));
	if (retro > 0.5 && min(t.r, min(t.g, t.b)) > 0.97) {
		ALBEDO = vec3(3.0);
	}
}
"""

var origin: XROrigin3D

var xr_cam: XRCamera3D

var fx_root: Node3D

var left_hand: Hand

var right_hand: Hand

var active_hand: Hand

var dot: MeshInstance3D

var panel_mat: ShaderMaterial

var world_scale := DEFAULT_SCALE_SMALL   # current values; swapped when the regime changes

var seat := DEFAULT_SEAT_SMALL           # x = right, y = up, z = back; game units

var regime_big := false           # true inside the building (table, lobby, restroom)

var scale_big := DEFAULT_SCALE_BIG

var seat_big := DEFAULT_SEAT_BIG

var scale_small := DEFAULT_SCALE_SMALL

var seat_small := DEFAULT_SEAT_SMALL

var panel_visible := true

var monitor_view := true           # setting: the PC monitor shows a copy of your view

var retro_look := true             # setting: the game's 7-level colour rounding is on in the headset

var ui_vp: SubViewport             # a copy of the game's 2D window (no monitor picture in it): the floating panel reads this

var blocker_alpha_raw := 0.0       # opacity of the game's black fade rectangle alone (no logos, no wall fade)

var retro_levels := Vector3.ZERO   # levels per colour the game uses in this scene (zero: none)

var retro_t := 0.0

var t_alive := 0.0

var needs_recenter := true

var recenter_at := 1.5

var glide := true

var prev_cam_pos := Vector3.ZERO

var blackout: MeshInstance3D

var blackout_mat: StandardMaterial3D

var blackout_alpha := 0.0

var mode := ""                    # "table" or "follow"

var anchor_pos := HOME_POS

var anchor_yaw := HOME_YAW

var game_cam: Camera3D

var cur_scene: Node

var interaction: Node             # the game's InteractionManager (null in menus)

var mouse_ray: Node               # the game's MouseRaycast

# --- walking, brackets, scene scans (iteration 4)
var stick_walk := true

var comfort_vignette := true

var hint_dim := false              # faint pulsing [ ] on everything you could click (off: only when pointed at)

var walk_off := Vector3.ZERO      # how far you have walked away from where the game put you

var walk_allowed := false

var walk_idle_t := 99.0           # seconds since your last stick input

var walk_to_table := false        # the game is at the table; you are still on your way there

var walk_to_table_t := 0.0

var hold_for_dealer := false      # you clicked the back-room door: the game's walk no longer carries you

var hold_t := 0.0

var beacon: MeshInstance3D

var beacon_mat: StandardMaterial3D

var assisted := false             # the pointer is currently snapped to a small click target

var turn_dir := 0

var anchor_speed := 0.0           # units/s the game is moving the anchor (scripted walks)

var vignette: MeshInstance3D

var vignette_mat: ShaderMaterial

var bracket: MeshInstance3D

var bracket_im: ImmediateMesh

var shape_cache := {}             # branch instance id -> [[CollisionShape3D, AABB], ...]

var hint_nodes: Array = []        # every "interaction branch" in the main scene

var postfx_nodes: Array = []      # the game's screen-copy post effects (hidden in VR)

var hand_res := {}                # "right_open" / "left_open" / "right_fist" -> Mesh

var poke_in := {}                  # "side|branch id" -> fingertip is inside it right now

var poke_cool := {}                # branch id -> time it may be pressed again

var btn_state := {}                # "side|cap id" -> 0 free, 1 being pushed, 2 clicked (held down), 3 ignored (came from the side)

var btn_prev := {}                 # "side|cap id" -> how deep the fingertip was last frame (fraction of the travel)

var btn_driven := {}               # cap id -> the cap node we moved down with a finger

var btn_held := {}                 # cap id -> time a finger last held it

var poke_boxes: Array = []         # boxes of pressable things a fingertip is close to (brackets)

var gun_state := 0                  # 0 on the table, 1 in your hand (aiming), 2 fired (the game plays the shot), 3 handed back, 4 put it down!, 5 set down

var item_hand: Hand = null          # the hand carrying an item out of the box

var item_node: Node3D = null        # the item (the game's own node)

var item_t := 0.0

var item_slot := -1                 # the free slot the item would go into now

var item_br: Node = null            # the table item's InteractionBranch while a hand carries it (null: it comes out of the box)

var item_home := Transform3D.IDENTITY   # where that item lay on the table

var item_loc := AABB()              # its box (in its own space)

var item_scale := Vector3.ONE

var item_floor_y := 0.0             # the table's height where it lay

var item_handoff := false           # the dealer is taking the handcuffs out of the hand

var item_im: Node = null            # the game's ItemManager (for the grab arbitration)

var grab_gun_ok := false            # the shotgun can be taken now (so it competes with the items for a squeeze)

var grab_items_ok := false          # the same for the table items

var rit := ""                       # the physical part that goes on after an item is used up: beer_rack, beer_wait, examine

var rit_t := 0.0

var rit_hand: Hand = null           # the hand that holds the pump

var rit_pull := 0.0                 # how far the pump is pulled back (model units)

var rit_pulled := false

var rit_final := false              # the beer takes the last shell

var rit_drink := 0.0

var rit_hand2: Hand = null          # the second hand on the magnifying glass

var mag_seen := false               # the shell was seen through the glass: the glass is spent, it has to be broken to go on

var rit_sep0 := 0.0

var rit_stroke := 0.0

var rit_prev := Vector3.ZERO

var rit_haptic_t := 0.0

var rit_snd: AudioStreamPlayer = null

var steal_on := false                # the game lets you take one of the dealer's items right now

var steal_held := false              # the item in your hand is one of the dealer's (stolen)

var adr_tp_on := false               # your head is at the middle of the table (stealing)

var adr_tp_re := false               # an item was put back: move to the table again

var fx_list: Array = []             # things that fall (used-up items, shards, the shell, the sawn-off piece)

var cuffed := false                 # the game has your hands tied

var gun_cal := Vector3.ZERO        # setting: your own nudge of the gun in your hand (real metres, right hand; x is mirrored for the left)

var gun_cal_on := false            # the nudge mode runs (click the stick of the hand that holds the shotgun)

var gun_game := true               # the game knows the shotgun is in your hand (false = only picked up so far: items and the pump still work)

var gun_fire_alias := ""           # the shot waits for the game's own pick-up to settle (a fraction of a second)

var gun_fire_t := 0.0

var gun_sup_w := 0.0               # 0..1: the barrel follows the line between your two hands (the other hand holds the pump)

var gun_sup_ok := false

var gun_sup_hand: Hand = null      # (iteration 37) the other hand holds the gun somewhere along the barrel (any time, any hand)

var gun_sup_down := {}

var gun_pump_hand: Hand = null     # (iteration 37) the hand on the pump of the gun in your hand sits on the pump (it slides with it)

var brief_node: Node = null        # the game's "briefcase machine" (its end-of-game case)

var brief_end0_ok := false

var brief_placed := false

var nm_sign: Node = null           # the game's "signature manager" (name machine + waiver)

var nm_find_t := 0.0

var nm_vis_seen := false           # its key panel was shown once (the name was being typed)

var nm_locked := false             # the name is in: keys and waiver are shut for good

var nm_lock_t := 0.0

var inv_dealer := false             # (iteration 33) the inverter / phone is held with the dealer's own hand shape

var dealer_key := ""               # (iteration 34) ...its entry in hh.poses

var dealer_sp := {}                # ...and its numbers (for this hand)

var tut_loaded := false

var tut_enabled := true            # (iteration 36) the check box on the bathroom sign

var help_check_on := true

var gun_eject_done := false        # the kept gun's shell has been taken out of the sequence

var gun_shell_pending := false     # ...and is shown leaving the gun when the pump is racked

var gun_need_rack := false         # (iteration 33) the gun was kept after a blank: the pump has to be racked before the next shot

var nm_hidden := false

var gun_hand: Hand = null

var gun_prop: Node3D = null         # the shotgun in your hand (ours; the game's one is hidden meanwhile)

var gun_ctl: Node = null            # the game's ShotgunShooting

var gun_main: Node3D = null         # "shotgun main parent"

var gun_branch: Node = null         # the "shotgun" InteractionBranch

var gun_aim := ""                   # "dealer" / "self" / ""

var gun_aim_t := 0.0

var gun_locked := false

var gun_t := 0.0

var gun_recoil := 0.0

var gun_bang_prev := false

var gun_dir_cache := Vector3(0, 0, -1)

var gun_pairs := []                 # [[the game's mesh, our copy of it]] while the game's own gun model is in the hand

var gun_k := 1.0                    # game units per model unit of the gun

var gun_put_t := -1.0               # glide into the game's own gun: -1 = not gliding, counts up from GUN_PUT_DELAY_S

var gun_rest_box := AABB()

var gun_rest_ok := false

var gun_put_label: Label3D

var hint_label: Label3D            # a short line of help floating next to what you touch / carry (doors, items)

var splat: GeometryInstance3D = null    # the game's blood layer (kept hidden: its low-resolution picture is replaced by ours)

var splat_prev := 1.0                   # the game's blood fade last frame (1 = invisible)

var splat_search_t := 0.0

var gun_gy := -3.0                  # where along the barrel (model units) the hand holds the gun right now

var help_hidden_run := false       # the sign was taken down by touch / trigger: hidden for this run only

var restroom_stage := false        # something here must be pressed with a finger: no laser, no hints

var pill_menu_active := false

var pill_yes: Node

var pill_no: Node

# --- iteration 6/7: TV without the camera move, pill bottle in your hand, pause menu
var env_logged := false

var tv_state := 0                  # 0 off, 1 starting up, 2 running

var tv_close_pending := false      # asked to switch off while it was still starting up

var bath_left := false             # you pressed the bathroom door: TV and pills are done with

var pill_node: MeshInstance3D      # the game's pill bottle on the desk

var pill_prop: MeshInstance3D      # the copy in your hand

var pill_hand: Hand

var pill_state := 0                # 0 on the desk, 1 in your hand, 2 sliding back

var pill_busy := false             # swallowed: the game runs its own fade, the bottle stays gone

var kick_on := false               # the back-room / bathroom door sequence is running (you stay where you are)

var kick_bath := false             # ... and it is the bathroom door

var bath_pending := false          # you have just pressed the bathroom door; the kick starts any moment

var kick_leg: MeshInstance3D

var guard_prints := 0

var orig_leg: VisualInstance3D     # the game's own leg mesh (hidden, except while the game kicks the bathroom door)

var orig_leg_on := false

var hand_lit := true               # hands are lit by the game's lights (off: the old flat, always-bright look)

var club_pending := false          # the lobby stays until you have stepped through the door

var club_nodes: Array = []

var pause_open := false

var pause_vp: SubViewport

var pause_mat: ShaderMaterial

# --- world size / height by hand (iteration 11)
var size_gesture := false          # setting: the two-hand gesture is on (off by default since iteration 24: it fired while you held the shotgun)

var size_active := false

var size_label: Label3D

# --- controls sign on the bathroom wall (iteration 11)
var help_sign := true              # setting: show the sign in the bathroom (off once you took it down)

var help_vp: SubViewport

var help_quad: MeshInstance3D

var help_mat: ShaderMaterial

var help_shown := false

var help_hover := false            # the pointing hand's laser is on the sign

var help_hit_dist := INF

var help_px := NO_HIT

var ui_font: Font

var size_use_nodes := false        # fallback: measure the hands from the node positions instead of the raw poses

var bounds_on := false

var gap_bath_open := false

var gap_back_open := false

var wall_fade := 0.0

var map_dump_state := 0            # 0 = not yet, 1 = running, 2 = done

var scan_times: Array = []

var probe_times: Array = []

var ui_size := Vector2(960, 540)

var panel_key := ""

var ui_active := false

var ui_px := NO_HIT

var last_panel_dist := INF

var world_hit := false

var world_hit_dist := INF

var world_hit_pos := Vector3.ZERO
