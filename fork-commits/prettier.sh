#!/usr/bin/env bash
# prettier's fork commits before its setup pull request, run in the fork's checkout (main). A: Linux
# legs only, runs-on literal so the drafter moves the matrix jobs (their matrix, conditions and
# names stay upstream's). B: the AppArmor sysctl only where it exists (graphide-ci's micro-VM guests
# have none). C, for CI_FANOUT_LINES: lint's independent checks in one step.
set -euo pipefail
rep() { python3 -I -c 'import sys;p,a=sys.argv[1],sys.argv[2:];s=open(p).read()
for o,n in zip(a[::2],a[1::2]):
  c=s.count(o);c==1 or sys.exit(f"{p}: {c} of {o!r}");s=s.replace(o,n)
open(p,"w").write(s)' "$@"; }
d=.github/workflows u=$'          - "ubuntu-latest"\n'
rep $d/dev-test.yml "$u"$'          - "macos-latest"\n          - "windows-latest"\n' "$u"
rep $d/prod-test.yml "$u"$'          - "macos-latest"\n          - "windows-latest"\n' "$u" \
  $'          # Tests on Intel Mac x Node.js 14 ( https://github.com/prettier/prettier/issues/16248 )\n          - os: "macos-15-intel"\n            node: "14"\n        # setup-node does not support Node.js 14 x M1 Mac\n        exclude:\n          - os: "macos-latest"\n            node: "14"\n' '' \
  $'          # - "macos-latest"\n          - "windows-latest"\n' $'          # - "macos-latest"\n' \
  $'        exclude:\n          # Hangs https://github.com/prettier/prettier/pull/18716\n          - os: "windows-latest"\n            browser: "chrome"\n' ''
for f in dev-test.yml:1 prod-test.yml:2; do
  [ "$(grep -c '^    runs-on: \${{ matrix.os }}$' "$d/${f%:*}")" = "${f#*:}" ] || { echo "$f: runs-on changed"; exit 1; }
  sed -i 's/^    runs-on: \${{ matrix.os }}$/    runs-on: ubuntu-latest/' "$d/${f%:*}"
done
git commit -qam $'graphide-oss: Linux legs only\n\nThe macOS and Windows legs cannot run on graphide-ci and queue on the org\'s\nhosted runners. runs-on is the one matrix value left, ubuntu-latest.'
a=/proc/sys/kernel/apparmor_restrict_unprivileged_userns
rep $d/prod-test.yml "      - run: echo 0 | sudo tee $a"$'\n' "      - run: if [ -e $a ]; then echo 0 | sudo tee $a; fi"$'\n'
git commit -qam $'graphide-oss: the AppArmor sysctl only where it exists\n\ngraphide-ci\'s micro-VM guests have no AppArmor: the file is absent and user\nnamespaces already work. On GitHub nothing changes.'
old=; s() { old+="      - name: $1"$'\n'"        run: $2"$'\n\n'; }
s 'Check Dependencies' 'yarn lint:deps'; s 'Check JSDoc Types' 'yarn lint:typecheck'; s 'Lint ESLint' 'yarn lint:eslint'
s 'Lint Prettier' 'yarn lint:prettier'; s Spellcheck 'yarn lint:spellcheck'; s 'Lint Changelog' 'yarn lint:changelog'
s 'Lint "format test"' 'yarn lint:format-test'
q='yarn prettier "{docs,website/versioned_docs/version-stable}/**/*.md" --check'
rep $d/lint.yml "$old""      - name: Lint docs code block"$'\n'"        run: $q"$'\n        env:\n          # Make Prettier throws on embedded format\n          PRETTIER_DEBUG: true\n' \
  $'      - name: Lint (independent checks)\n        run: |\n'"$(printf '          yarn lint:%s\n' deps typecheck eslint prettier spellcheck changelog format-test)"$'\n'"          PRETTIER_DEBUG=true $q"$'\n'
git commit -qam $'graphide-oss: lint\'s independent checks in one step\n\nOne run: step whose lines graphide-ci may run at once (fanout lines).'
