#!/usr/bin/env bash
# prime.sh [N]: put each fork in repos.tsv N (3) first-parent commits behind its upstream's tip,
# with its fork commit (fork-commits/<name>.sh) on top, force-pushed with the operator's git, so
# its first push run and the sync's next N steps give the shadow N+1 runs at upstream's own
# commits. Run once, after setup.sh and before the sync workflow is turned on.
set -euo pipefail
n=${1:-3}
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while IFS=$'\t' read -r up fork branch; do
  case "$up" in '' | '#'*) continue ;; esac
  name="${fork#*/}"
  work="$(mktemp -d)"
  git -C "$work" init -q
  git -C "$work" config user.name "graphide-oss sync"
  git -C "$work" config user.email "oss-sync@graphide.com"
  git -C "$work" fetch -q --no-tags --depth=$((n + 2)) "https://github.com/$up.git" "$branch"
  git -C "$work" checkout -q --detach "FETCH_HEAD~$n"
  base="$(git -C "$work" log -1 --format='%h %s')"
  if [ -x "$here/fork-commits/$name.sh" ]; then (cd "$work" && "$here/fork-commits/$name.sh"); fi
  git -C "$work" push -q --force "git@github.com:$fork.git" "HEAD:refs/heads/$branch" </dev/null
  echo "$fork: at $base$([ -x "$here/fork-commits/$name.sh" ] && echo ", with its fork commit")"
  rm -rf "$work"
done <"$here/repos.tsv"
