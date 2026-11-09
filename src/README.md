# src/ - the mod's modules

GDScript has no partial classes, so the mod is one class built as a **chain of files**: every file `extends` the one before it,
the last one is extended by `vr_boot.gd` (the entry point, which Godot loads as the autoload `VRBoot`). All files together are
one object at run time: any function can use any variable, and calling a function is the same as before the split.
Nothing but the position of the code changed in iteration 39.

| File (in chain order) | Lines | What it holds |
|---|---|---|
| `hand.gd` | 34 | One VR controller (`Hand`): its nodes and per-frame state; `const Hand = preload("hand.gd")` in `00_core.gd` |
| `00_core.gd` | 547 | Shared state: the constants and variables that more than one module uses |
| `01_forward.gd` | 55 | Forward declarations (stubs) for calls that go up the chain |
| `02_common.gd` | 269 | Small shared helpers: aliases, permissions, box maths, mouth point, seat/size references |
| `03_hands.gd` | 633 | The hands: building, shaders, poses, inputs, per-frame visuals |
| `04_cigarette.gd` | 383 | Cigarettes: pack, flick, hold, mouth, burn, smoke |
| `05_bathroom.gd` | 105 | Bathroom: intro, CRT, TV |
| `06_brackets.gd` | 401 | Highlight frames (brackets), branch boxes, game highlight suppression |
| `07_game_scene.gd` | 284 | Scene tracking: game references, anchor, regime, placement, scale |
| `08_pills.gd` | 190 | Bathroom pill bottle |
| `09_fx.gd` | 289 | Visual effects and clones: shatter, toss, shards, animation helpers |
| `10_blood.gd` | 214 | Blood splash after a hit |
| `11_hints.gd` | 184 | On-screen hints, rings, gun label, tutorial messages |
| `12_gun_shell.gd` | 280 | Gun: shell eject, keep-the-gun logic, pump racking |
| `13_name_machine.gd` | 129 | Name machine guard and lowering |
| `14_settings.gd` | 134 | Saved settings, scene scan, diagnostics, probes |
| `15_help_sign.gd` | 255 | Bathroom controls sign and the tutorial check box |
| `16_locomotion.gd` | 326 | Walking, turning, blackout, rig guard, bounds |
| `17_gun_aim.gd` | 408 | Gun: pose, two-hand hold, nudge, aim, trigger, slow-motion boost |
| `18_inverter.gd` | 160 | Inverter item |
| `19_gun_hold.gd` | 771 | Gun: take, release, put down, clone, make, free-hand updates |
| `20_poke.gd` | 544 | Fingertip pressing: TV buttons, briefcase, key machine, click targets |
| `21_map_dump.gd` | 150 | Developer tool: walkable-area map dump |
| `22_adrenaline.gd` | 372 | Adrenaline item and stealing |
| `23_magnifier.gd` | 482 | Magnifying glass item (smash, lens, window onto the shell) |
| `24_phone.gd` | 223 | Burner phone item |
| `25_display.gd` | 270 | Retro colours, PC monitor view |
| `26_handsaw.gd` | 150 | Handsaw item |
| `27_world_size.gd` | 271 | World size and height (gesture, buttons, labels) |
| `28_pause_menu.gd` | 333 | Pause menu |
| `29_medicine.gd` | 265 | Expired medicine item (strip, pills) |
| `30_item_use.gd` | 121 | Using items: tick dispatcher helpers and the beer |
| `31_titem.gd` | 389 | Table items by hand: pick, carry, use, end (dispatcher) |
| `32_doors.gd` | 280 | Doors, bathroom leg kick, club hold |
| `33_items.gd` | 469 | Items on the table: take, carry, drop, hold pose, dealer hand shape |
| `34_pointer.gd` | 441 | Laser pointer, 2D panel, buttons and input |
| `35_paper.gd` | 428 | The waiver / GOD letter (paper) and its reading |
| `36_cuffs.gd` | 295 | Handcuffs and the money briefcase |
| `../vr_boot.gd` | 313 | Entry: the three engine callbacks (`_ready`, `_process`, `_input`) that call everything every frame |

## The rules of the chain
1. A function may call functions of **its own file and of earlier files** directly.
2. To call a function of a **later** file, a stub with the same signature must exist in `01_forward.gd` (the real one, further down,
   overrides it at run time). Only a handful are needed (about 16 today).
3. A variable or constant must be declared **in the earliest file that uses it**. State that more than one file uses lives in `00_core.gd`;
   state used by one file only is declared at the top of that file.
4. New file: name it `NN_name.gd` with `extends "NN-1_previous.gd"`, and make the file that followed it extend the new one
   (or put it last: change the `extends` line of `../vr_boot.gd`).
5. Run `python3 tools/check_modules.py` (from the mod folder): it lists every rule violation. Then run `tests/run.sh` (see `tests/README.md`).

Finding code: functions keep their names; `grep -n "func _gun_pose" src/*.gd` finds it. The order inside a file follows the
old single-file order, so related functions sit together.
