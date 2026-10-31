#!/usr/bin/env bash
# Loom runs in the fork too: its six jobs are guarded on tokio-rs owning the repository, and they
# are tokio's heaviest tests (about 245 job-minutes a push). Run in the fork's checkout.
set -euo pipefail
f=.github/workflows/loom.yml
n="$(grep -c "github.repository_owner == 'tokio-rs' &&" "$f")"
[ "$n" -ge 1 ] || { echo "$f: no tokio-rs owner guard"; exit 1; }
sed -i "s/github.repository_owner == 'tokio-rs' &&/(github.repository_owner == 'tokio-rs' || github.repository_owner == 'graphide-oss') \&\&/" "$f"
[ "$(grep -c "github.repository_owner == 'graphide-oss')" "$f")" = "$n" ] || { echo "$f: edit missed a guard"; exit 1; }
git commit -qam "graphide-oss: Loom runs in this fork

Its jobs are guarded on github.repository_owner == 'tokio-rs'."
