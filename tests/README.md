# Offline tests

The mod can be tested without a headset and without the game: these suites load `vr_boot.gd` (the real code) in a headless
Godot and feed it **mock** game objects (a fake shotgun, items, dealer, interaction manager, ...), then print result lines such as
`S3 squeeze on the barrel (16 cm ahead): sup=true (want true)`.

## Run
Needs the Godot 4.1.x editor binary (the game uses 4.1.1; any 4.1.x works) - nothing else.

    tests/run.sh /path/to/Godot_v4.1.1-stable_linux.x86_64                 # all suites, one after the other (~15 min)
    tests/run.sh /path/to/Godot_v4.1.1-stable_linux.x86_64 self_aim_mouth  # one suite

A suite passes when its result lines equal `tests/expected/<suite>.txt` (the baseline taken when the suite was written; object ids
are ignored). The `(want ...)` text in a line says what the author expected; the baseline is what makes a regression visible.
When you change behaviour on purpose, review the diff and update the baseline file.

## Layout
- `suites/*.gd` - the test programs (`extends SceneTree`). `@MOD@` and `@MOCKS@` are replaced by the runner with the paths of
  `vr_boot.gd` and `tests/mocks`.
- `mocks/` - stand-ins for the game's scripts (`mocks22.gd` has most: shotgun, shell spawner, round manager, ...).
- `expected/` - baselines. `project/` - an empty project to run in. The tests write only to their own user folder
  (`app_userdata/vr_mod_tests`), never to the game's.
- Mock rooms are tiny: they check the mod's logic (what is picked, where hands and frames go, when the gun fires), not what it
  looks like. Anything about looks, feel and real tracking still needs the headset.

## Writing a test
Copy the closest suite, keep its set-up part (it builds the mock scene, a gun in the right hand, items on the table, a `step.call(n)`
that runs n frames of the mod's update functions), then print one line per check. Use `put_reach.call(hand, point)` to place a hand
and `hand.grip_sq = true` to squeeze. World units are metres x the world scale (13.2 in these suites).
