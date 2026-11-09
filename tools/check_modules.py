#!/usr/bin/env python3
"""Checks the module chain of the mod (src/NN_name.gd, each file extends the one before it).

A GDScript file cannot call a function or use a variable of a file that extends it. So:
  * a function may call functions of its own file and of EARLIER files directly;
  * a call to a function of a LATER file needs a stub (same signature) in src/01_forward.gd;
  * a variable or constant must be declared in the earliest file that uses it (shared ones live in src/00_core.gd).
This tool lists every violation, so you know where to move a declaration or add a stub.  Usage:  python3 tools/check_modules.py
Exit code 0 = fine.
"""
import os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KW = ('func ', 'var ', 'const ', 'signal ', 'enum ', 'static func ', 'static var ', '@onready ', '@export ', 'class ')
IDENT = re.compile(r'(?<![\w.])([A-Za-z_]\w*)')


def strip_code(text):
    out = []
    in3 = False
    for line in text.split('\n'):
        i, n, res, q = 0, len(line), [], None
        while i < n:
            c = line[i]
            if in3:
                if line.startswith('"""', i):
                    in3 = False
                    i += 3
                else:
                    i += 1
                continue
            if q:
                if c == '\\':
                    i += 2
                    continue
                if c == q:
                    q = None
                i += 1
                continue
            if line.startswith('"""', i):
                in3 = True
                i += 3
                continue
            if c in '"\'':
                q = c
                i += 1
                continue
            if c == '#':
                break
            res.append(c)
            i += 1
        out.append(''.join(res))
    return '\n'.join(out)


def items(path):
    """top-level items of a file: (kind, name, text)"""
    lines = open(path, encoding='utf-8').read().split('\n')
    starts, in3, depth = [], False, 0
    for i, l in enumerate(lines):
        if not in3 and depth == 0 and l and l[0] not in ' \t#' and l.startswith(KW):
            starts.append(i)
        s = strip_code_line(l, in3, depth)
        in3, depth = s
    res = []
    for k, s in enumerate(starts):
        e = starts[k + 1] if k + 1 < len(starts) else len(lines)
        text = '\n'.join(lines[s:e])
        m = re.match(r'(?:static\s+)?(func|var|const|class|signal|enum)\s+([A-Za-z_]\w*)', text) or re.match(r'@\w+\s+(var)\s+(\w+)', text)
        if m:
            res.append((m.group(1), m.group(2), text))
    return res


def strip_code_line(line, in3, depth):
    i, n, q = 0, len(line), None
    while i < n:
        c = line[i]
        if in3:
            if line.startswith('"""', i):
                in3 = False
                i += 3
            else:
                i += 1
            continue
        if q:
            if c == '\\':
                i += 2
                continue
            if c == q:
                q = None
            i += 1
            continue
        if line.startswith('"""', i):
            in3 = True
            i += 3
            continue
        if c in '"\'':
            q = c
            i += 1
            continue
        if c == '#':
            break
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
        i += 1
    return in3, depth


def signature(text):
    depth, q, seen = 0, None, False
    for p, c in enumerate(text):
        if q:
            if c == q:
                q = None
            continue
        if c in '"\'':
            q = c
        elif c in '([{':
            depth += 1
            seen = True
        elif c in ')]}':
            depth -= 1
        elif c == ':' and depth == 0 and seen:
            return re.sub(r'\s+', ' ', text[:p + 1])
    return text.split('\n')[0]


def main():
    files = sorted(glob.glob(os.path.join(ROOT, 'src', '[0-9][0-9]_*.gd'))) + [os.path.join(ROOT, 'vr_boot.gd')]
    pos = {f: n for n, f in enumerate(files)}
    funcs, decls = {}, {}          # name -> (file index, text)
    per_file = {}
    for f in files:
        its = items(f)
        per_file[f] = its
        for kind, name, text in its:
            if kind == 'func':
                if os.path.basename(f) == '01_forward.gd':
                    continue
                if name in funcs:
                    print('DUPLICATE function', name, 'in', os.path.basename(f), 'and', os.path.basename(files[funcs[name][0]]))
                    sys.exit(1)
                funcs[name] = (pos[f], text)
            elif kind in ('var', 'const'):
                decls[name] = (pos[f], text)
    stubs = {name: text for kind, name, text in per_file[files[1]] if kind == 'func'}
    problems = 0
    for name, text in stubs.items():
        real = funcs.get(name)
        if real is None:
            print('STUB without a real function:', name)
            problems += 1
        elif signature(real[1]) != signature(text):
            print('STUB signature differs for', name, '\n   stub:', signature(text), '\n   real:', signature(real[1]))
            problems += 1
        elif real[0] <= 1:
            print('STUB is not needed (real function is not later):', name)
    for f in files:
        if os.path.basename(f) == '01_forward.gd':
            continue
        for kind, name, text in per_file[f]:
            ids = set(IDENT.findall(strip_code(text)))
            if kind == 'func':
                for g in ids:
                    if g in funcs and g != name and funcs[g][0] > pos[f] and g not in stubs:
                        print(f'{os.path.basename(f)}: {name}() calls {g}() which lives in a later file -> add a stub to src/01_forward.gd')
                        problems += 1
            for d in ids:
                if d in decls and d != name and decls[d][0] > pos[f]:
                    print(f'{os.path.basename(f)}: {name} uses {d}, declared in a later file ({os.path.basename(files[decls[d][0]])}) -> move the declaration up (shared state belongs in src/00_core.gd)')
                    problems += 1
    print('OK: no problems' if problems == 0 else f'{problems} problem(s)')
    sys.exit(1 if problems else 0)


main()
