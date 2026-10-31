#!/usr/bin/env bash
# rust-analyzer's fork commit after its setup pull request, run in the fork's checkout (master) once
# the pull request is merged: the build-heavy jobs ask for 8 vCPUs (graphide-ci's resource-shape
# agent cannot raise a CPU-bound job). Jobs are found by id, whatever runs-on form the setup pull
# request left.
set -euo pipefail
cls() { local f=$1 n=$2; shift 2; for j in "$@"; do  # JOB asks for graphide-linux-x64-N, whatever form its runs-on has now
  J=$j N=$n perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*)}{my $b=$1; my $l="graphide-linux-x64-$ENV{N}";
    $b =~ s/^(    runs-on: )ubuntu-latest$/$1$l/m; $b =~ s/graphide-linux-x64-\d+\b/$l/g; $b}me' "$f"
  awk -v j="  $j:" -v l="graphide-linux-x64-$n" '$0==j{b=1;next} b&&/^  [^ #]/{exit} b&&index($0,l){ok=1} END{exit !ok}' "$f" || { echo "$f: $j"; exit 1; }
done; }
w=.github/workflows
cls $w/ci.yaml 8 rust analysis-stats proc-macro-srv clippy miri rust-cross
cls $w/coverage.yaml 8 coverage
cls $w/rustdoc.yaml 8 rustdoc
git diff --quiet || git commit -qam "graphide-oss: build-heavy jobs on 8 vCPUs"
