#!/usr/bin/env bash
# tokio's fork commit after its setup pull request, run in the fork's checkout (master) once the
# pull request is merged. The FreeBSD jobs go back to GitHub's ubuntu-latest (vmactions/freebsd-vm
# runs QEMU and needs /dev/kvm, which graphide-ci's guests lack; `onboard pr` moves them anyway),
# and the build jobs ask for their class: miri-test the whole 32-vCPU VM (nextest runs one test per
# CPU), the rest 8 (graphide-ci's resource-shape agent cannot raise a CPU-bound job). Loom stays on
# the drafter's 4: each Loom job is one single-threaded test. Jobs are found by id, whatever
# runs-on form the setup pull request left.
set -euo pipefail
w=.github/workflows
for j in freebsd-x86_64 freebsd-docs freebsd-i686; do
  J=$j perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*?)    runs-on: [^\n]*\n}{$1    runs-on: ubuntu-latest\n}m' $w/ci.yml
  awk -v j="  $j:" '$0==j{b=1;next} b&&/^  [^ #]/{exit} b&&$0=="    runs-on: ubuntu-latest"{ok=1} END{exit !ok}' $w/ci.yml || { echo "$w/ci.yml: $j"; exit 1; }
done
cls() { local f=$1 n=$2; shift 2; for j in "$@"; do  # JOB asks for graphide-linux-x64-N, whatever form its runs-on has now
  J=$j N=$n perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*)}{my $b=$1; my $l="graphide-linux-x64-$ENV{N}"; $b =~ s/^(    runs-on: )ubuntu-latest$/$1$l/m;
    $b =~ s/^(    runs-on: )\$\{\{ matrix\.os \}\}$/$1\$\{\{ matrix.os == \x27ubuntu-latest\x27 && \x27$l\x27 || matrix.os \}\}/m if $b =~ /os: ubuntu-latest/;
    $b =~ s/graphide-linux-x64-\d+\b/$l/g; $b}me' "$f"
  awk -v j="  $j:" -v l="graphide-linux-x64-$n" '$0==j{b=1;next} b&&/^  [^ #]/{exit} b&&index($0,l){ok=1} END{exit !ok}' "$f" || { echo "$f: $j"; exit 1; }
done; }
cls $w/ci.yml 32 miri-test
cls $w/ci.yml 8 clippy docs minrust test-tokio-full test-workspace-all-features test-workspace-all-features-panic-abort test-integration-tests-per-feature test-parking_lot valgrind test-unstable test-sharded-blocking-queue test-unstable-taskdump check-unstable-mt-counters miri-lib miri-doc asan semver cross-check cross-check-tier3 cross-test-with-parking_lot cross-test-without-parking_lot no-atomic-u64-test no-atomic-u64-check features minimal-versions loom-compile test-hyper test-quinn x86_64-fortanix-unknown-sgx check-redox wasm32-unknown-unknown wasm32-wasip1 wasm32-wasip2 wasm32-unknown-emscripten check-external-types check-fuzzing check-spelling
cls $w/uring-kernel-version-test.yml 8 build
cls $w/stress-test.yml 8 stress-test
git diff --quiet || git commit -qam "graphide-oss: FreeBSD on GitHub; per-job graphide-ci classes" -m "miri-test on 32 vCPUs, the build and test jobs on 8, Loom on the setup pull request's 4."

# The setup pull request moved the arm64 legs to graphide-linux-arm64-4, a class production does
# not serve (CI_ARM64 off): they queued for ever and held up the whole work queue. Back on GitHub's.
f=.github/workflows/ci.yml
grep -q 'graphide-linux-arm64-' "$f" || { echo "$f: no arm64 label to put back"; exit 1; }
sed -i -E 's/graphide-linux-arm64-[0-9]+/ubuntu-24.04-arm/g' "$f"
git commit -qam "graphide-oss: arm64 legs back on GitHub's ubuntu-24.04-arm" -m "graphide-ci serves no Linux arm64 class yet; the setup pull request moved them anyway."
