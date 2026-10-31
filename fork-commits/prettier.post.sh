#!/usr/bin/env bash
# prettier's commit after its setup pull request, run in the fork's checkout (main): actionlint
# (part of its Lint job) knows graphide-ci's labels. Without a config it knows GitHub's own labels
# only and fails every workflow the setup pull request moved ("label graphide-linux-x64-4 is
# unknown").
set -euo pipefail
f=.github/actionlint.yaml
[ ! -e "$f" ] || { echo "$f exists upstream now: add the labels by hand"; exit 1; }
printf 'self-hosted-runner:\n  labels:\n' >"$f"
for n in 2 4 8 16 32; do printf '    - graphide-linux-x64-%s\n' "$n" >>"$f"; done
git add "$f"
git commit -qm "graphide-oss: actionlint knows graphide-ci's runner labels" -m "Its Lint job runs actionlint, which otherwise refuses every self-hosted label."
