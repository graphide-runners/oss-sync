#!/usr/bin/env bash
# tokio's fork commits before its setup pull request, run in the fork's checkout (master).
# A: Loom runs in the fork (its jobs are guarded on tokio-rs owning the repository, and they are
# tokio's heaviest tests, about 245 job-minutes a push). B: no macOS or Windows legs (graphide-ci
# serves neither); jobs left with Linux legs only get a literal runs-on, so the drafter moves them
# with their matrix and check names unchanged. C: nextest writes a JUnit report, the per-test times
# graphide-ci's guest scan reads. tokio.post.sh follows the setup pull request.
set -euo pipefail
f=.github/workflows/loom.yml
n="$(grep -c "github.repository_owner == 'tokio-rs' &&" "$f")"
[ "$n" -ge 1 ] || { echo "$f: no tokio-rs owner guard"; exit 1; }
sed -i "s/github.repository_owner == 'tokio-rs' &&/(github.repository_owner == 'tokio-rs' || github.repository_owner == 'graphide-oss') \&\&/" "$f"
[ "$(grep -c "github.repository_owner == 'graphide-oss')" "$f")" = "$n" ] || { echo "$f: edit missed a guard"; exit 1; }
git commit -qam "graphide-oss: Loom runs in this fork

Its jobs are guarded on github.repository_owner == 'tokio-rs'."

f=.github/workflows/ci.yml
[ "$(grep -cxE '          - (windows|macos)-latest' "$f")" = 12 ] || { echo "$f: os lists changed"; exit 1; }
perl -0pi -e 's/^          - (windows|macos)-latest\n//mg; s/^          - \{ os: (windows|macos)-latest, extra_features: "" \}\n//mg;
  s/^          - os: windows-latest\n(            #[^\n]*\n)?            extra_features: "tracing"\n//mg;
  s/^          - target: aarch64-pc-windows-msvc\n            os: windows-11-arm\n//mg; s/^    runs-on: \$\{\{ matrix\.run\.os \}\}$/    runs-on: ubuntu-latest/m;' "$f"
for j in test-tokio-full test-workspace-all-features test-workspace-all-features-panic-abort test-integration-tests-per-feature test-unstable test-hyper test-quinn check-external-types; do
  J=$j perl -0pi -e 's{^(  \Q$ENV{J}\E:\n(?:(?!  \S)[^\n]*\n|\n)*?)    runs-on: \$\{\{ matrix\.os \}\}\n}{$1    runs-on: ubuntu-latest\n}m' "$f"
done
! grep -nE '(os|- ) ?(windows|macos)-|windows-11-arm|matrix\.run\.os' "$f" | grep -v cache-bin || { echo "$f: a leg is left"; exit 1; }
[ "$(grep -c 'runs-on: \${{ matrix.os }}' "$f")" = 4 ] || { echo "$f: runs-on edits missed"; exit 1; }
git commit -qam "graphide-oss: no macOS or Windows legs" -m "graphide-ci serves neither; they would queue on the organization's hosted slots."

[ ! -e .config/nextest.toml ] || { echo ".config/nextest.toml exists upstream now: add the junit profile by hand"; exit 1; }
mkdir -p .config && printf '[profile.default.junit]\npath = "junit.xml"\n' >.config/nextest.toml
git add .config/nextest.toml && git commit -qm "graphide-oss: nextest writes a JUnit report" -m "target/nextest/default/junit.xml; tests and their order unchanged."
