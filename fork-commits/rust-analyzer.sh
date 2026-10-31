#!/usr/bin/env bash
# The CI workflow runs on pushes to master too: upstream runs it only on pull requests and the
# merge queue, so a fork that follows master would run one coverage job. Run in the fork's
# checkout.
set -euo pipefail
f=.github/workflows/ci.yaml
grep -qx 'on:' "$f" && grep -qx '  merge_group:' "$f" || { echo "$f: on: block changed"; exit 1; }
sed -i 's/^  merge_group:$/  merge_group:\n  push:\n    branches: [master]/' "$f"
grep -qx '    branches: \[master\]' "$f" || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: CI runs on pushes to master

Upstream runs it on pull requests and the merge queue only."
