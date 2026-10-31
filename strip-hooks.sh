#!/usr/bin/env bash
# strip-hooks.sh NAME...: rewrite each fork's setup commit ("Run CI|workflows on Graphide runners")
# without the agent-hook files graphide-ci's drafter adds by default from release 7 (.claude/,
# .cursor/, .mcp.json, .opencode/, AGENTS.md and the rest): a file the setup commit added is
# dropped, one it changed (pydantic's AGENTS.md) goes back to its parent's. The commits after it
# are picked back on, and the branch is force-pushed with a lease, so the fork differs from
# upstream in runs-on and its fork commits only. prettier's eslint fails on the hook plugin.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for name in "$@"; do
  read -r _ fork branch < <(awk -F'\t' -v f="graphide-oss/$name" '$2 == f' "$here/repos.tsv")
  [ -n "${fork:-}" ] || { echo "$name: not in repos.tsv"; exit 1; }
  w="$(mktemp -d)"
  git clone -q --depth 60 --branch "$branch" "git@github.com:$fork.git" "$w"
  g() { git -C "$w" "$@"; }
  g config user.name "graphide-oss sync"
  g config user.email "oss-sync@graphide.com"
  s="$(g log --format=%H -E --grep='^Run (CI|workflows) on Graphide runners' -1)"
  [ -n "$s" ] || { echo "$fork: no setup commit"; rm -rf "$w"; continue; }
  mapfile -t paths < <(g diff-tree --no-commit-id --name-only -r "$s" | grep -v '^\.github/workflows/' || true)
  [ "${#paths[@]}" -gt 0 ] || { echo "$fork: setup commit carries no hook files"; rm -rf "$w"; continue; }
  old="$(g rev-parse HEAD)"
  mapfile -t after < <(g rev-list --reverse "$s..HEAD")
  g checkout -q --detach "$s"
  for p in "${paths[@]}"; do
    if g cat-file -e "$s^:$p" 2>/dev/null; then g checkout -q "$s^" -- "$p"; else g rm -q -- "$p"; fi
  done
  g commit -q --amend --no-edit
  for c in "${after[@]}"; do g cherry-pick --allow-empty "$c" >/dev/null; done
  g push -q --force-with-lease="refs/heads/$branch:$old" origin "HEAD:refs/heads/$branch" </dev/null
  echo "$fork: setup commit without ${#paths[@]} hook file(s), ${#after[@]} later commit(s) picked back on"
  rm -rf "$w"
done
