#!/usr/bin/env bash
# pydantic's fork commits before its setup pull request, run in the fork's checkout (main). A: no
# macOS or Windows legs (graphide-ci serves neither; no job is wholly either, so every needs: chain
# stays). B: each runs-on the drafter refuses (an expression, a nested matrix key, or a matrix key
# read elsewhere) becomes a literal label or one matrix key, with the same legs, names and steps.
set -euo pipefail
# edit OLD NEW...: in ci.yml (escapes such as \n decoded), OLD occurs once, or N times when NEW ends
# in @@N, and becomes NEW; OLD as CUT:FIRST|LAST deletes the block from FIRST through LAST.
edit() { python3 -I -c 'import sys
f, pairs = ".github/workflows/ci.yml", sys.argv[1:]
s = open(f).read()
for i in range(0, len(pairs), 2):
    old, new = (p.encode().decode("unicode_escape") for p in pairs[i:i + 2])
    if old.startswith("CUT:"):
        a, b = old[4:].split("|"); i0, i1 = s.find(a), s.find(b)
        s.count(a) == 1 and s.count(b) == 1 and i0 < i1 or sys.exit(f"{f}: no one block {a!r}..{b!r}")
        s = s[:i0] + s[i1 + len(b):]
    else:
        new, _, want = new.partition("@@")
        c = s.count(old); c == int(want or 1) or sys.exit(f"{f}: {c} of {old!r}")
        s = s.replace(old, new)
open(f, "w").write(s)' "$@"; }
edit 'os: [linux, macos, windows]' 'os: [linux]' \
  'CUT:          # macos;\n|            interpreter: 3.11 3.12 3.13 3.14 3.14t 3.15 3.15t\n\n' '' \
  '          - os: windows\n            runs-on: windows-latest\n          - os: macos\n            runs-on: macos-latest\n' '' \
  '          - runs-on: windows-latest\n            os: windows\n          - runs-on: windows-11-arm\n            os: windows_aarch64\n          - runs-on: macos-latest\n            os: macos\n' '' \
  'os: [ubuntu, macos, windows]' 'os: [ubuntu]' 'os: [ubuntu-latest, macos-latest, windows-latest]' 'os: [ubuntu-latest]' \
  "CUT:        include:\n          # test macos intel|python-version: '3.15t'\n" ''
git commit -qam "graphide-oss: no macOS or Windows legs in this fork" -m "graphide-ci serves neither; they held every run open on the org's hosted runners."
pgo="        interpreter: ['3.10', '3.11', '3.12', '3.13', '3.14', '3.14t', '3.15', '3.15t']\n"
inc='        include:\\n          - os: linux\\n            runs-on: ubuntu-latest\\n          - os: %s\\n            runs-on: ubuntu-24.04-arm\\n'
edit "    runs-on: \${{ matrix.runs-on || format('{0}-latest', (matrix.os == 'linux' && 'ubuntu') || matrix.os) }}" '    runs-on: ubuntu-latest' \
  '        platform:\n          - os: linux\n            runs-on: ubuntu-latest\n          - os: linux_aarch64\n            runs-on: ubuntu-24.04-arm\n' '        os: [linux, linux_aarch64]\n' \
  "$pgo" "$pgo$(printf "$inc" linux_aarch64)" \
  '        platform:\n          - runs-on: ubuntu-latest\n            os: linux\n          - runs-on: ubuntu-24.04-arm\n            os: linuw_aarch64\n' "        os: [linux, linuw_aarch64]\n$(printf "$inc" linuw_aarch64)" \
  'matrix.platform.runs-on' 'matrix.runs-on@@2' 'matrix.platform.os' 'matrix.os@@4' \
  '    runs-on: ${{ matrix.os }}-latest' '    runs-on: ubuntu-latest' '    runs-on: ${{ matrix.os }}\n' '    runs-on: ubuntu-latest\n'
git commit -qam "graphide-oss: runs-on the setup pull request can move" -m "Same legs, names and steps; each runs-on is a label or one matrix key."
