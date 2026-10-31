#!/usr/bin/env bash
# fastapi's fork commit after its setup pull request, run in the fork's checkout (master): the test
# job asks for graphide-linux-x64-8, so `pytest -n auto` starts 8 workers (2 on GitHub's 4-vCPU
# runner). The plan runs it only after three runs at the setup pull request's x64-4 (the
# equal-vCPU speedup comes first), and only if graphide-ci's resource-shape agent adopted no
# override by then. The job is found by id, whatever runs-on form the setup pull request left.
set -euo pipefail
cls() { local f=$1 n=$2; shift 2; for j in "$@"; do  # JOB asks for graphide-linux-x64-N, whatever form its runs-on has now
  J=$j N=$n perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*)}{my $b=$1; my $l="graphide-linux-x64-$ENV{N}";
    $b =~ s/^(    runs-on: )ubuntu-latest$/$1$l/m; $b =~ s/graphide-linux-x64-\d+\b/$l/g; $b}me' "$f"
  awk -v j="  $j:" -v l="graphide-linux-x64-$n" '$0==j{b=1;next} b&&/^  [^ #]/{exit} b&&index($0,l){ok=1} END{exit !ok}' "$f" || { echo "$f: $j"; exit 1; }
done; }
cls .github/workflows/test.yml 8 test
git diff --quiet || git commit -qam "graphide-oss: test runs on linux-x64-8" -m "pytest -n auto then starts 8 workers (2 on GitHub's 4-vCPU runner)."
