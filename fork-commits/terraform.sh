#!/usr/bin/env bash
# terraform's fork commits before its setup pull request, run in the fork's checkout (main). A: no
# macOS or Windows legs (only e2e-test has them, and no job needs it; the darwin and windows
# cross-builds and e2etest-build legs run on Linux and stay). B: the cross-builds ask for
# graphide-linux-x64-8, since the drafter cannot move `runs-on: ${{ inputs.runson }}`; only the
# callee's runs-on changes, so inputs.runson and the ACTIONSOS it feeds stay ubuntu-latest, and
# GRAPHIDE_CI_RUNNER=off takes them back (the drafter's fallback form). terraform.post.sh follows
# the setup pull request.
set -euo pipefail
f=.github/workflows/build.yml
[ "$(grep -cE '^ +- \{ runson: (macos|windows)-latest,' "$f")" = 3 ] || { echo "$f: not 3 macOS/Windows e2e-test rows"; exit 1; }
sed -i -E '/^ +- \{ runson: (macos|windows)-latest,/d' "$f"
[ "$(grep -cE 'runson: (macos|windows)-latest' "$f")" = 0 ] || { echo "$f: a macOS/Windows row is left"; exit 1; }
[ "$(grep -cE '^ +- \{ runson: (ubuntu-latest|graphide-linux-x64-4), goos: linux,' "$f")" = 4 ] || { echo "$f: e2e-test lost a Linux row"; exit 1; }
git commit -qam "graphide-oss: no macOS or Windows legs in e2e-test (graphide-ci serves neither)"

f=.github/workflows/build-terraform-cli.yml
[ "$(grep -cxF '    runs-on: ${{ inputs.runson }}' "$f")" = 1 ] || { echo "$f: runs-on is not inputs.runson"; exit 1; }
sed -i "s#^    runs-on: \${{ inputs.runson }}\$#    runs-on: \${{ vars.GRAPHIDE_CI_RUNNER != 'off' \&\& inputs.runson == 'ubuntu-latest' \&\& 'graphide-linux-x64-8' || inputs.runson }}#" "$f"
[ "$(grep -cF "&& 'graphide-linux-x64-8' || inputs.runson }}" "$f")" = 1 ] || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: cross-builds on graphide-linux-x64-8 (the setup PR cannot move inputs.runson)"
