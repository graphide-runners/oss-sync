#!/usr/bin/env bash
# pydantic's commit after its setup pull request, run in the fork's checkout (main): the arm64 legs
# go back to GitHub's ubuntu-24.04-arm. The setup pull request moved them to graphide-linux-arm64-4,
# a class production does not serve (CI_ARM64 off), so they queued for ever and held up the whole
# work queue.
set -euo pipefail
f=.github/workflows/ci.yml
grep -q 'graphide-linux-arm64-' "$f" || { echo "$f: no arm64 label to put back"; exit 1; }
sed -i -E 's/graphide-linux-arm64-[0-9]+/ubuntu-24.04-arm/g' "$f"
git commit -qam "graphide-oss: arm64 legs back on GitHub's ubuntu-24.04-arm" -m "graphide-ci serves no Linux arm64 class yet; the setup pull request moved them anyway."
