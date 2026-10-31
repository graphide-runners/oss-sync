#!/usr/bin/env bash
# rust-analyzer's fork commits before its setup pull request, run in the fork's checkout (master).
# A: CI runs on pushes to master (upstream runs it on pull requests and the merge queue only). B: CI's
# jobs and rustdoc's build run in this fork (each is guarded on rust-lang owning the repository;
# rustdoc's Deploy Docs step and metrics keep their guards). C: no macOS or Windows legs; the three
# matrix jobs get a literal runs-on, so the drafter moves them with check names unchanged. D: nextest
# writes a JUnit report, the per-test times graphide-ci's guest scan reads.
# rust-analyzer.post.sh follows the setup pull request.
set -euo pipefail
f=.github/workflows/ci.yaml
grep -qx 'on:' "$f" && grep -qx '  merge_group:' "$f" || { echo "$f: on: block changed"; exit 1; }
sed -i 's/^  merge_group:$/  merge_group:\n  push:\n    branches: [master]/' "$f"
grep -qx '    branches: \[master\]' "$f" || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: CI runs on pushes to master

Upstream runs it on pull requests and the merge queue only."

g="github.repository == 'rust-lang/rust-analyzer'"
n="($g || github.repository == 'graphide-oss/rust-analyzer')"
for f in .github/workflows/ci.yaml:8 .github/workflows/rustdoc.yaml:1; do
  [ "$(grep -c "^    if: $g" "${f%:*}")" = "${f#*:}" ] || { echo "${f%:*}: guards changed"; exit 1; }
  sed -i "s#^    if: $g#    if: $n#" "${f%:*}"
  [ "$(grep -c "^    if: ($g" "${f%:*}")" = "${f#*:}" ] || { echo "${f%:*}: edit missed"; exit 1; }
done
git commit -qam "graphide-oss: CI and rustdoc jobs run in this fork" -m "Their jobs are guarded on github.repository == 'rust-lang/rust-analyzer'."

f=.github/workflows/ci.yaml
[ "$(grep -cE '^        os: \[ubuntu-latest, windows-latest(, macos-latest)?\]$' "$f")" = 3 ] || { echo "$f: os lists changed"; exit 1; }
sed -i -E 's/^(        os: \[ubuntu-latest), windows-latest(, macos-latest)?\]$/\1]/; s/^    runs-on: \$\{\{ matrix\.os \}\}$/    runs-on: ubuntu-latest/' "$f"
[ "$(grep -c '^        os: \[ubuntu-latest\]$' "$f")" = 3 ] && ! grep -q 'matrix\.os }}$' "$f" || { echo "$f: edit missed"; exit 1; }
git commit -qam "graphide-oss: no macOS or Windows legs" -m "graphide-ci serves neither; they would queue on the organization's hosted slots."

f=.config/nextest.toml
grep -qx '\[profile.default\]' "$f" && ! grep -q junit "$f" || { echo "$f changed"; exit 1; }
printf '\n[profile.default.junit]\npath = "junit.xml"\n' >>"$f"
git commit -qam "graphide-oss: nextest writes a JUnit report" -m "target/nextest/default/junit.xml; tests and their order unchanged."
