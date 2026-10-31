#!/usr/bin/env bash
# vite's fork commits, run in the fork's checkout (main). A: Linux legs only, so runs-on is the one
# matrix value left as a literal label the setup drafter moves (it leaves a `${{ matrix.os }}` job
# whose key the job also reads, and macOS and Windows cannot run on graphide-ci anyway). B: the
# ubuntu-slim jobs ask for ubuntu-latest (the drafter has no ubuntu-slim mapping, and every test
# leg needs the changed-files gate).
set -euo pipefail
rep() { python3 -I -c 'import sys;p,a=sys.argv[1],sys.argv[2:];s=open(p).read()
for o,n in zip(a[::2],a[1::2]):
  c=s.count(o);c==1 or sys.exit(f"{p}: {c} of {o!r}");s=s.replace(o,n)
open(p,"w").write(s)' "$@"; }
f=.github/workflows/ci.yml
rep $f $'        include:\n          # Active LTS + other OS\n          - os: macos-latest\n            node_version: 24\n          - os: windows-latest\n            node_version: 24\n' '' \
  $'    runs-on: ${{ matrix.os }}\n' $'    runs-on: ubuntu-latest\n'
grep -qx '        os: \[ubuntu-latest\]' $f || { echo "$f: matrix.os is not [ubuntu-latest]"; exit 1; }
git commit -qam $'graphide-oss: Linux legs only\n\nThe macOS and Windows legs cannot run on graphide-ci and queue on the org\'s\nhosted runners. runs-on is the one matrix value left, ubuntu-latest.'
[ "$(grep -c '^    runs-on: ubuntu-slim$' $f)" = 3 ] || { echo "$f: ubuntu-slim jobs changed"; exit 1; }
sed -i 's/^    runs-on: ubuntu-slim$/    runs-on: ubuntu-latest/' $f
git commit -qam $'graphide-oss: ubuntu-slim jobs ask for ubuntu-latest\n\ngraphide-ci\'s setup drafter has no ubuntu-slim mapping; the changed-files\ngate and the two status jobs then move with the rest.'
