#!/usr/bin/env bash
# setup.sh: make graphide-oss's forks from repos.tsv and everything the sync needs, once. Run
# again, it does only what is missing. Needs gh logged in as an owner of graphide-oss (scopes
# repo, admin:org, workflow), ssh-keygen, and this repository's remote (graphide-oss/oss-sync)
# created first.
#
# For each fork: fork upstream's default branch only; Actions on, and every workflow GitHub
# disabled in the fork turned on (a fork starts with them off); "Require approval for all
# external contributors" on fork pull requests, so no outsider's pull request runs a job; a
# write deploy key, its private half straight into oss-sync's secret DEPLOY_KEY_<NAME> and
# never printed or kept. PRIME=N (default 3) moves a new fork's branch N first-parent commits
# back from upstream's tip, so its first push run and the sync's next N steps give the shadow
# N+1 runs at upstream's own commits.
set -euo pipefail

org=graphide-oss
sync_repo="$org/oss-sync"
prime=${PRIME:-3}
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh api "repos/$sync_repo" --jq .full_name >/dev/null || { echo "create $sync_repo first"; exit 1; }
secrets="$(gh secret list --repo "$sync_repo" --json name --jq '.[].name')"

while IFS=$'\t' read -r up fork branch; do
  case "$up" in '' | '#'*) continue ;; esac
  name="${fork#*/}"
  var="DEPLOY_KEY_$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')"
  new=0
  if ! gh api "repos/$fork" --jq .full_name >/dev/null 2>&1; then
    echo "$fork: forking $up"
    gh api -X POST "repos/$up/forks" -f organization="$org" -F default_branch_only=true --jq .full_name >/dev/null
    for _ in $(seq 60); do gh api "repos/$fork/branches/$branch" --jq .name >/dev/null 2>&1 && break; sleep 5; done
    new=1
  fi

  gh api -X PUT "repos/$fork/actions/permissions" -F enabled=true -f allowed_actions=all
  gh api -X PUT "repos/$fork/actions/permissions/fork-pr-contributor-approval" \
    -f approval_policy=all_external_contributors
  gh api "repos/$fork/actions/workflows?per_page=100" \
    --jq '.workflows[] | select(.state == "disabled_fork" or .state == "disabled_manually") | .id' |
    while read -r id; do gh api -X PUT "repos/$fork/actions/workflows/$id/enable"; done

  if ! printf '%s\n' "$secrets" | grep -qx "$var"; then
    echo "$fork: deploy key and $sync_repo secret $var"
    ssh-keygen -q -t ed25519 -N '' -C "oss-sync $fork" -f "$tmp/$name"
    gh api "repos/$fork/keys" -f title=oss-sync -f key="$(cat "$tmp/$name.pub")" -F read_only=false --jq .id >/dev/null
    [ "$(wc -c <"$tmp/$name")" -gt 300 ] || { echo "$fork: key file too short"; exit 1; }
    gh secret set "$var" --repo "$sync_repo" <"$tmp/$name"
    rm -f "$tmp/$name" "$tmp/$name.pub"
  fi

  if [ "$new" = 1 ] && [ "$prime" -gt 0 ]; then
    back="$(gh api "repos/$up/commits?sha=$branch&per_page=1" --jq '.[0].sha')"
    for _ in $(seq "$prime"); do back="$(gh api "repos/$up/commits/$back" --jq '.parents[0].sha')"; done
    echo "$fork: priming at $back, $prime first-parent commits behind upstream"
    gh api -X PATCH "repos/$fork/git/refs/heads/$branch" -f sha="$back" -F force=true --jq .object.sha >/dev/null
  fi
done <"$here/repos.tsv"
