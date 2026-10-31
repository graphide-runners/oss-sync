#!/usr/bin/env bash
# terraform's fork commit after its setup pull request, run in the fork's checkout (main) once the
# pull request is merged: the CPU-bound jobs (all of checks.yml, and e2e-test-exec) ask for
# graphide-linux-x64-8. Jobs are found by id, whatever runs-on form the setup pull request left.
set -euo pipefail
cls() { local f=$1 n=$2; shift 2; for j in "$@"; do  # JOB asks for graphide-linux-x64-N, whatever form its runs-on has now
  J=$j N=$n perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*)}{my $b=$1; my $l="graphide-linux-x64-$ENV{N}";
    $b =~ s/^(    runs-on: )ubuntu-latest$/$1$l/m; $b =~ s/graphide-linux-x64-\d+\b/$l/g; $b}me' "$f"
  awk -v j="  $j:" -v l="graphide-linux-x64-$n" '$0==j{b=1;next} b&&/^  [^ #]/{exit} b&&index($0,l){ok=1} END{exit !ok}' "$f" || { echo "$f: $j"; exit 1; }
done; }
w=.github/workflows
cls $w/checks.yml 8 unit-tests race-tests e2e-tests consistency-checks automated-defect-checks
cls $w/build.yml 8 e2e-test-exec
git diff --quiet || git commit -qam "graphide-oss: CPU-bound jobs on graphide-linux-x64-8"
