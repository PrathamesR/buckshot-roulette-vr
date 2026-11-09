#!/usr/bin/env python3
"""Builds the release zip (and the launcher exe) from this repository.

    python3 tools/make_release.py --version 0.39.0            # builds the exe with Go, writes dist/Buckshot-Roulette-VR-0.39.0.zip
    python3 tools/make_release.py --version 0.39.0 --exe path/to/"Buckshot Roulette VR.exe"   # use an exe you already have

The zip is meant to be extracted straight into the game folder:
    Buckshot Roulette VR.exe   override.cfg   READ-ME.txt   vr_mod/vr_boot.gd   vr_mod/src/*.gd   vr_mod/LICENSE
Needs Python 3 and (unless --exe is given) Go 1.20+. It first runs tools/check_modules.py and checks that every file the
module chain extends is present. The game's own files (and vr_mod/hands, which holds the game's hand meshes) are never included.
"""
import argparse, hashlib, os, re, subprocess, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXE_NAME = 'Buckshot Roulette VR.exe'


def build_exe(version, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    exe = os.path.join(out_dir, EXE_NAME)
    env = dict(os.environ, GOOS='windows', GOARCH='amd64', CGO_ENABLED='0')
    cmd = ['go', 'build', '-trimpath', '-ldflags', f'-H=windowsgui -s -w -X main.version={version}', '-o', exe, '.']
    print('building the launcher:', ' '.join(cmd))
    subprocess.run(cmd, cwd=os.path.join(ROOT, 'release', 'launcher'), env=env, check=True)
    return exe


def check_chain():
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'check_modules.py')], capture_output=True, text=True)
    print(r.stdout.strip())
    if r.returncode != 0:
        sys.exit('module chain check failed')
    files = {f for f in os.listdir(os.path.join(ROOT, 'src'))}
    for f in sorted(files):
        if not f.endswith('.gd'):
            continue
        for m in re.finditer(r'^(?:extends|const \w+ = preload\()\s*"([^"]+\.gd)"', open(os.path.join(ROOT, 'src', f), encoding='utf-8').read(), re.M):
            if m.group(1) not in files:
                sys.exit(f'src/{f} refers to {m.group(1)}, which is not in src/')
    first = open(os.path.join(ROOT, 'vr_boot.gd'), encoding='utf-8').readline()
    m = re.match(r'extends "src/([^"]+)"', first)
    if not m or m.group(1) not in files:
        sys.exit('vr_boot.gd does not extend a file of src/')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', required=True, help='e.g. 0.39.0 (no leading v)')
    ap.add_argument('--exe', help='use this launcher exe instead of building one with Go')
    ap.add_argument('--out', default=os.path.join(ROOT, 'dist'))
    a = ap.parse_args()
    check_chain()
    exe = a.exe or build_exe(a.version, os.path.join(a.out, 'build'))
    entries = [(exe, EXE_NAME), (os.path.join(ROOT, 'release', 'override.cfg'), 'override.cfg'),
               (os.path.join(ROOT, 'release', 'READ-ME.txt'), 'READ-ME.txt'),
               (os.path.join(ROOT, 'LICENSE'), 'vr_mod/LICENSE'), (os.path.join(ROOT, 'vr_boot.gd'), 'vr_mod/vr_boot.gd')]
    for f in sorted(os.listdir(os.path.join(ROOT, 'src'))):
        if f.endswith('.gd'):
            entries.append((os.path.join(ROOT, 'src', f), 'vr_mod/src/' + f))
    entries.append((None, 'vr_mod/VERSION'))
    os.makedirs(a.out, exist_ok=True)
    zpath = os.path.join(a.out, f'Buckshot-Roulette-VR-{a.version}.zip')
    with zipfile.ZipFile(zpath, 'w', zipfile.ZIP_DEFLATED) as z:
        for src, name in entries:
            zi = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))     # fixed time: the same input gives the same zip
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            data = (a.version + '\n').encode() if src is None else open(src, 'rb').read()
            z.writestr(zi, data)
    h = hashlib.sha256(open(zpath, 'rb').read()).hexdigest()
    open(os.path.join(a.out, 'SHA256SUMS.txt'), 'w').write(f'{h}  {os.path.basename(zpath)}\n')
    print(f'wrote {zpath} ({os.path.getsize(zpath):,} bytes)\nsha256 {h}')


main()
