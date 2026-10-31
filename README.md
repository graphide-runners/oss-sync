# oss-sync

Graphide shadows public repositories on graphide-ci from forks in the `graphide-oss`
organization (Ben, 2026-10-30). This repository lives in `graphide-runners` so its job never
queues behind the forks' jobs for graphide-oss's 20 hosted runners. Each fork's default branch follows its upstream one first-parent commit at
a time, so the fork's own CI runs once at each of upstream's commits, and graphide-ci's
shadow replays every job of those runs on our runners and compares them. Nothing is written
to any upstream repository.

- `repos.tsv`: the upstream, the fork and the branch.
- `sync.sh UPSTREAM FORK BRANCH`: one step. It waits while a push run of the fork is still
  going, steps to the next upstream commit (skipping ahead when more than 6 behind), picks
  the fork's own commits (its graphide setup pull request, once moved) onto it, and
  force-pushes with a lease.
- `.github/workflows/sync.yml`: `sync.sh` for every fork, every 15 minutes, with each fork's
  write deploy key from the secret `DEPLOY_KEY_<NAME>`. `workflow_dispatch` with `dry_run`
  prints the steps and pushes nothing.
- `setup.sh`: makes the forks once (Actions on, fork workflows on, approval required for
  outside contributors' pull requests, deploy keys, priming 3 commits behind).

- `fork-commits/<name>.sh`: the fork's own commits that go before its setup pull request, as
  scripts run in its checkout (`prime.sh` runs them), so a commit that stops picking cleanly is
  made again. `fork-commits/<name>.post.sh` holds those that must follow the merged setup pull
  request, such as a larger class for named jobs; it finds each job by id, whatever label the
  drafter wrote, and is run by hand in a checkout of the fork.
  - tokio: Loom runs in the fork (guarded on tokio-rs), no macOS or Windows legs, nextest writes
    JUnit. Post: FreeBSD back on GitHub (needs KVM), miri-test on x64-32, build jobs on x64-8.
  - rust-analyzer: CI runs on pushes to master, CI and rustdoc jobs run in the fork (guarded on
    rust-lang), no macOS or Windows legs, nextest writes JUnit. Post: build jobs on x64-8.
  - pydantic: no macOS or Windows legs; each runs-on the drafter refuses becomes a label or one
    matrix key, same legs and names.
  - prettier: Linux legs only with a literal runs-on, the AppArmor sysctl only where it exists,
    lint's independent checks in one step.
  - fastapi: no macOS or Windows legs, their lowest-direct coverage legs on Linux, a literal
    runs-on for test. Post, after three runs at x64-4: test on x64-8.
  - terraform: no macOS or Windows e2e-test legs, cross-builds on x64-8 (the drafter cannot move
    `inputs.runson`). Post: checks.yml and e2e-test-exec on x64-8.
  - vite: Linux legs only, ubuntu-slim jobs ask for ubuntu-latest.
  - gin: Linux test legs only, on x64-8 in the drafter's fallback form; Run Tests and CodeQL run on
    dispatch; the Codecov upload without OIDC.

To add a repository: a line in `repos.tsv`, its secret name in `sync.yml`, then `setup.sh`.
