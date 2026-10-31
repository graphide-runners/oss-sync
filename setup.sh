#!/usr/bin/env bash
# setup.sh: make graphide-oss's forks from repos.tsv and everything the sync needs, once. Run
# again, it does only what is missing. Needs gh logged in as an owner of graphide-oss (scopes
# repo, admin:org), ssh-keygen, yq (mikefarah's), and this repository
# (graphide-runners/oss-sync) created first.
#
# For each fork: fork upstream's default branch only; Actions on, the workflows a push, pull
# request or call starts on and every other one off; "Require approval for all
# external contributors" on fork pull requests, so no outsider's pull request runs a job; a
# write deploy key, its private half straight into oss-sync's secret DEPLOY_KEY_<NAME> and
# never printed or kept. Then prime.sh, once, and turn the sync workflow on.
set -euo pipefail

org=graphide-oss
# The sync runs in an organization of its own: in this one it would queue behind the forks' jobs
# for the same 20 hosted runners.
sync_repo=graphide-runners/oss-sync
# A new organization has deploy keys off.
gh api -X PATCH "orgs/$org" -F deploy_keys_enabled_for_repositories=true --jq .login >/dev/null
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

gh api "repos/$sync_repo" --jq .full_name >/dev/null || { echo "create $sync_repo first"; exit 1; }
secrets="$(gh secret list --repo "$sync_repo" --json name --jq '.[].name')"

while IFS=$'\t' read -r up fork branch; do
  case "$up" in '' | '#'*) continue ;; esac
  name="${fork#*/}"
  var="DEPLOY_KEY_$(printf '%s' "$name" | tr 'a-z-' 'A-Z_')"
  if ! gh api "repos/$fork" --jq .full_name >/dev/null 2>&1; then
    echo "$fork: forking $up"
    gh api -X POST "repos/$up/forks" -f organization="$org" -F default_branch_only=true --jq .full_name >/dev/null
    for _ in $(seq 60); do gh api "repos/$fork/branches/$branch" --jq .name >/dev/null 2>&1 && break; sleep 5; done
  fi

  gh api -X PUT "repos/$fork/actions/permissions" -F enabled=true -f allowed_actions=all
  gh api -X PUT "repos/$fork/actions/permissions/fork-pr-contributor-approval" \
    -f approval_policy=all_external_contributors
  # Only workflows a push, a pull request or another workflow's call starts are on: cron and
  # event bots (stale, sponsors, translations) and workflow_run followers (docs deploys) are
  # turned off, since Actions on makes every workflow of the fork active.
  gh api "repos/$fork/actions/workflows?per_page=100" --jq '.workflows[] | "\(.id) \(.state) \(.path)"' |
    while read -r id state path; do
      on="$(gh api "repos/$fork/contents/$path?ref=$branch" --jq .content | base64 -d |
        yq -r '.["on"] | ((select(tag=="!!str") | .), (select(tag=="!!seq") | .[]), (select(tag=="!!map") | keys | .[]))' 2>/dev/null || true)"
      if printf '%s\n' "$on" | grep -qxE 'push|pull_request|workflow_call'; then
        [ "$state" = active ] || { gh api -X PUT "repos/$fork/actions/workflows/$id/enable"; echo "$fork: enabled $path"; }
      elif [ "$state" = active ]; then
        gh api -X PUT "repos/$fork/actions/workflows/$id/disable"
        echo "$fork: disabled $path ($(printf '%s' "$on" | tr '\n' ' '))"
      fi
    done

  if ! printf '%s\n' "$secrets" | grep -qx "$var"; then
    echo "$fork: deploy key and $sync_repo secret $var"
    ssh-keygen -q -t ed25519 -N '' -C "oss-sync $fork" -f "$tmp/$name"
    gh api "repos/$fork/keys" -f title=oss-sync -f key="$(cat "$tmp/$name.pub")" -F read_only=false --jq .id >/dev/null
    [ "$(wc -c <"$tmp/$name")" -gt 300 ] || { echo "$fork: key file too short"; exit 1; }
    gh secret set "$var" --repo "$sync_repo" <"$tmp/$name"
    rm -f "$tmp/$name" "$tmp/$name.pub"
  fi
done <"$here/repos.tsv"
