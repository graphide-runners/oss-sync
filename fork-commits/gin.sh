#!/usr/bin/env bash
# gin's fork commits before its setup pull request, run in the fork's checkout (master). A: macOS
# leaves the test matrix (no macOS class; nothing needs test), and the Linux legs ask for
# graphide-linux-x64-8 in the drafter's fallback form, since the drafter cannot move them (the
# job's name reads matrix.os); matrix values, the include row keyed on os and check names stay
# upstream's. B: Run Tests and CodeQL also run on dispatch (upstream is quiet; Trivy already does).
# C: the Codecov upload without OIDC (the fork is no Codecov repository, so the upload soft-fails
# either way), so graphide-ci's job feed compiles the test legs.
set -euo pipefail
f=.github/workflows/gin.yml
grep -qxF '        os: [ubuntu-latest, macos-latest]' "$f" || { echo "$f: os list changed"; exit 1; }
[ "$(grep -cxE '          - os: macos-latest|            go-build: ~/Library/Caches/go-build' "$f")" = 2 ] || { echo "$f: no macOS include row"; exit 1; }
grep -qxF '    runs-on: ${{ matrix.os }}' "$f" || { echo "$f: runs-on changed"; exit 1; }
sed -i -e 's/^        os: \[ubuntu-latest, macos-latest\]$/        os: [ubuntu-latest]/' \
  -e '/^          - os: macos-latest$/,/^            go-build: ~\/Library\/Caches\/go-build$/d' \
  -e "s#^    runs-on: \${{ matrix.os }}\$#    runs-on: \${{ vars.GRAPHIDE_CI_RUNNER != 'off' \&\& (matrix.os == 'ubuntu-latest' \&\& 'graphide-linux-x64-8') || matrix.os }}#" "$f"
[ "$(grep -c macos "$f")" = 0 ] && grep -qxF '          - os: ubuntu-latest' "$f" && grep -qF "'graphide-linux-x64-8') || matrix.os }}" "$f" || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: Linux test legs only, on graphide-linux-x64-8 (no macOS on graphide-ci)"

for f in .github/workflows/gin.yml .github/workflows/codeql.yml; do
  [ "$(grep -cx 'on:' "$f")" = 1 ] && ! grep -q workflow_dispatch "$f" || { echo "$f: unexpected on: block"; exit 1; }
  sed -i 's/^on:$/on:\n  workflow_dispatch:/' "$f"; grep -qx '  workflow_dispatch:' "$f" || { echo "$f: edit missed"; exit 1; }
done
git commit -qam "graphide-oss: Run Tests and CodeQL run on dispatch too"

f=.github/workflows/gin.yml
[ "$(grep -cx '      id-token: write' "$f")" = 1 ] && [ "$(grep -cx '          use_oidc: true' "$f")" = 1 ] || { echo "$f: OIDC lines changed"; exit 1; }
sed -i -e '/^      id-token: write$/d' -e '/^          use_oidc: true$/d' "$f"
! grep -qE 'id-token|use_oidc' "$f" || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: Codecov upload without OIDC (the job feed refuses id-token jobs)"
