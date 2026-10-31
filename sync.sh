#!/usr/bin/env bash
# sync.sh UPSTREAM FORK BRANCH: move FORK's BRANCH one step along UPSTREAM's first-parent
# history, so the fork's own CI runs once at each of upstream's commits and graphide-ci's
# shadow feeds every run.
#
# - A push run of the fork's BRANCH still going (queued or in progress) is waited for, so each
#   upstream commit gets a whole run and no newer push cancels it. One older than STUCK_SECS
#   (4 hours) no longer holds the fork back.
# - The step is the next first-parent commit after the fork's base (its merge base with
#   upstream). A fork more than MAX_BEHIND (6) commits behind skips ahead to MAX_BEHIND behind.
# - The fork's own commits on BRANCH (its graphide setup pull request, once moved) are picked
#   onto the step, oldest first, merges left out, and the branch is force-pushed with a lease.
#   A pick that conflicts fails this repository loudly; nothing is pushed.
#
# Needs git, gh (GH_TOKEN reads the fork's runs; the fork is public) and GIT_SSH_COMMAND that
# pushes to FORK. DRY_RUN=1 prints the step and pushes nothing.
set -euo pipefail

up=$1 fork=$2 branch=$3
max_behind=${MAX_BEHIND:-6}
stuck_secs=${STUCK_SECS:-14400}
depth=${FETCH_DEPTH:-300}

say() { printf '%s: %s\n' "$fork" "$*"; }

newest_open="$(gh api "repos/$fork/actions/runs?branch=$branch&event=push&per_page=50" \
  --jq '[.workflow_runs[] | select(.status != "completed") | .created_at] | max // ""')"
if [ -n "$newest_open" ]; then
  age=$(($(date +%s) - $(date -d "$newest_open" +%s)))
  if [ "$age" -lt "$stuck_secs" ]; then
    say "a push run is still going (newest started ${age}s ago); waiting"
    exit 0
  fi
  say "a push run has been going ${age}s; stepping anyway"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
g() { git -C "$work" "$@"; }
g init -q
g config user.name "graphide-oss sync"
g config user.email "oss-sync@graphide.com"
g remote add upstream "https://github.com/$up.git"
g remote add origin "git@github.com:$fork.git"
g fetch -q --no-tags --depth="$depth" upstream "$branch"
g fetch -q --no-tags --depth="$depth" origin "$branch"

base="$(g merge-base "upstream/$branch" "origin/$branch" || true)"
if [ -z "$base" ]; then
  g fetch -q --no-tags --deepen=3000 upstream "$branch"
  g fetch -q --no-tags --deepen=3000 origin "$branch"
  base="$(g merge-base "upstream/$branch" "origin/$branch" || true)"
fi
[ -n "$base" ] || { say "no merge base with $up within the fetch; fix by hand"; exit 1; }

mapfile -t ahead < <(g rev-list --first-parent --reverse "$base..upstream/$branch")
if [ "${#ahead[@]}" -eq 0 ]; then
  say "at upstream's tip $(g rev-parse --short "upstream/$branch")"
  exit 0
fi
i=0
[ "${#ahead[@]}" -gt "$max_behind" ] && i=$((${#ahead[@]} - max_behind))
step="${ahead[$i]}"

mapfile -t own < <(g rev-list --reverse --no-merges "upstream/$branch..origin/$branch")
old="$(g rev-parse "origin/$branch")"
if [ "${#own[@]}" -eq 0 ]; then
  head="$step"
else
  g checkout -q --detach "$step"
  for c in "${own[@]}"; do
    if ! g cherry-pick --allow-empty --keep-redundant-commits "$c" >/dev/null 2>&1; then
      say "picking $(g log -1 --format='%h %s' "$c") onto $(g rev-parse --short "$step") conflicts; fix by hand"
      exit 1
    fi
  done
  head="$(g rev-parse HEAD)"
fi

say "$((${#ahead[@]} - i)) behind; stepping to $(g log -1 --format='%h %s' "$step")${own:+ with ${#own[@]} own commit(s)}"
[ "${DRY_RUN:-0}" = 1 ] && exit 0
g push -q --force-with-lease="refs/heads/$branch:$old" origin "$head:refs/heads/$branch"
