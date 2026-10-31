#!/usr/bin/env bash
# fastapi's fork commits before its setup pull request, run in the fork's checkout (master). Every
# edit stays inside the test job. A: no macOS or Windows legs (graphide-ci serves neither). B: the
# lowest-direct coverage legs those carried run on Linux, for coverage-combine's --fail-under=100.
# C: test's runs-on is a literal label the drafter moves; matrix.os keeps its value for the
# SQLAlchemy step's condition, and check names stay. fastapi.post.sh comes later (see its header).
set -euo pipefail
f=.github/workflows/test.yml
# edit OLD NEW...: inside the test job (escapes such as \n decoded), OLD occurs once and becomes NEW.
edit() { python3 -I -c 'import sys
f, pairs = sys.argv[1], sys.argv[2:]
s = open(f).read()
lo, hi = s.index("\n  test:\n"), s.index("\n  benchmark:\n")
job = s[lo:hi]
for i in range(0, len(pairs), 2):
    old, new = (p.encode().decode("unicode_escape") for p in pairs[i:i + 2])
    c = job.count(old); c == 1 or sys.exit(f"{f}: {c} of {old!r} in the test job")
    job = job.replace(old, new)
open(f, "w").write(s[:lo] + job + s[hi:])' "$f" "$@"; }
row() { printf '          - os: %s\\n            python-version: "%s"\\n            coverage: coverage\\n            uv-resolution: lowest-direct\\n            deprecated-tests: "no-deprecation"\\n' "$1" "$2"; }
edit "$(row macos-latest 3.10)$(row windows-latest 3.12)" '' \
  '      fail-fast: false\n' '        exclude:\n          - os: windows-latest\n          - os: macos-latest\n      fail-fast: false\n'
git commit -qam "graphide-oss: no macOS or Windows legs in this fork" -m "graphide-ci serves neither. The base os list excludes both values (an empty list is invalid), so the Linux include legs keep their names."
edit '        include:\n' "        include:\n$(row ubuntu-latest 3.10)$(row ubuntu-latest 3.12)"
git commit -qam "graphide-oss: the lowest-direct coverage legs run on Linux" -m "They covered Python 3.10/3.12 and pydantic 2.9 for coverage-combine's --fail-under=100."
edit '    runs-on: ${{ matrix.os }}\n' '    runs-on: ubuntu-latest\n'
git commit -qam "graphide-oss: test's runs-on is a label the setup pull request can move" -m "Every leg is ubuntu-latest; matrix.os keeps its value for the SQLAlchemy step's condition."
