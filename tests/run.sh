#!/usr/bin/env bash
# Offline tests: run the mod's code against mock game objects, headless, no headset and no game needed.
#   tests/run.sh /path/to/Godot_v4.1.1-stable_linux.x86_64            # all suites (about 15 minutes)
#   tests/run.sh /path/to/godot two_hand_stolen_items self_aim_mouth   # only these suites
# A suite passes when its result lines (the ones that start with a capital letter and a digit, e.g. "S3 ...") equal tests/expected/<suite>.txt
# (object ids like #123 are ignored). Run suites one after the other, not in parallel: they share one settings file.
GODOT=${1:?usage: tests/run.sh /path/to/godot [suite ...]}
shift
HERE=$(cd "$(dirname "$0")" && pwd)
MOD="$HERE/../vr_boot.gd"
SUITES=("$@")
if [ ${#SUITES[@]} -eq 0 ]; then
  for f in "$HERE"/suites/*.gd; do SUITES+=("$(basename "$f" .gd)"); done
fi
TMP=$(mktemp -d)
fail=0
for s in "${SUITES[@]}"; do
  # the tests' own user folder only (never the game's): app_userdata/vr_mod_tests
  for base in "$HOME/.local/share/godot" "$HOME/Library/Application Support/Godot" "$APPDATA/Godot"; do
    rm -f "$base/app_userdata/vr_mod_tests/vr_mod/vr_tutorial.cfg" 2>/dev/null
  done
  sed "s#@MOD@#$MOD#g;s#@MOCKS@#$HERE/mocks#g" "$HERE/suites/$s.gd" > "$TMP/$s.gd"
  timeout 600 "$GODOT" --headless --path "$HERE/project" -s "$TMP/$s.gd" > "$TMP/$s.out" 2>&1
  grep -E '^[A-Z][0-9a-z]* ' "$TMP/$s.out" | sed -E 's/#-?[0-9]+//g' > "$TMP/$s.res"
  errs=$(grep -c 'SCRIPT ERROR' "$TMP/$s.out")
  if diff -q "$TMP/$s.res" "$HERE/expected/$s.txt" > /dev/null; then
    echo "PASS  $s  (script errors: $errs)"
  else
    echo "FAIL  $s  (script errors: $errs)"; diff "$TMP/$s.res" "$HERE/expected/$s.txt" | head -10; fail=1
  fi
done
rm -rf "$TMP"
exit $fail
