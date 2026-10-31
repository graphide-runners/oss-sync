#!/usr/bin/env bash
# netbox's fork commit, run in the copy's checkout (main). Every runs-on asks for one of our labels:
# the test job (three Python legs against a postgres:18 service, `manage.py test --parallel`) for
# graphide-linux-x64-8, every other job (ubuntu-latest or ubuntu-slim, in all 13 workflows) for
# graphide-linux-x64-4. Nothing else changes, byte for byte. graphide-oss/netbox is a private plain
# copy, not a fork, so a job left on a GitHub-hosted runner would burn the organization's paid
# minutes: the asserts below fail the commit rather than leave one.
set -euo pipefail
d=.github/workflows
total() { grep -h "$1" "$d"/*.yml | wc -l; }
before="$(total 'runs-on:')"
[ "$(grep -h 'runs-on:' "$d"/*.yml | grep -cvE '^    runs-on: ubuntu-(latest|slim)$')" = 0 ] || { echo "$d: a runs-on is not ubuntu-latest or ubuntu-slim"; exit 1; }
grep -qxF '  test:' "$d/ci.yml" || { echo "$d/ci.yml: no test job"; exit 1; }
sed -i '/^  test:$/,/^    runs-on: /s/^    runs-on: ubuntu-latest$/    runs-on: graphide-linux-x64-8/' "$d/ci.yml"
[ "$(grep -c '^    runs-on: graphide-linux-x64-8$' "$d/ci.yml")" = 1 ] || { echo "$d/ci.yml: test job edit missed"; exit 1; }
sed -i -E 's/^    runs-on: ubuntu-(latest|slim)$/    runs-on: graphide-linux-x64-4/' "$d"/*.yml
ours="$(grep -hE '^    runs-on: graphide-linux-x64-(4|8)$' "$d"/*.yml | wc -l)"
[ "$before" = "$ours" ] && [ "$(total 'runs-on:')" = "$before" ] || { echo "$d: edit missed ($before runs-on, $ours on our labels)"; exit 1; }
git commit -qam "graphide-oss: every job on graphide-linux-x64-4, the test job on graphide-linux-x64-8 (a private copy burns paid minutes on GitHub's runners)"
